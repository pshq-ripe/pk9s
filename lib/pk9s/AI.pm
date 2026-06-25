package pk9s::AI;
use strict;
use warnings;
use JSON::PP;
use HTTP::Tiny;

sub new {
    my ($class, %args) = @_;
    return bless {
        context => $args{context},
        kubectl => $args{kubectl},
        model => $args{model} // 'qwen2.5:7b',
        endpoint => $args{endpoint} // 'http://localhost:11434',
    }, $class;
}

sub analyze_resource {
    my ($self, $type, $name, $namespace) = @_;

    my $logs = $self->_get_logs($name, $namespace);
    my $events = $self->_get_events($type, $name, $namespace);
    my $describe = $self->_describe($type, $name, $namespace);

    my $prompt = $self->build_prompt(
        type => $type,
        name => $name,
        namespace => $namespace,
        logs => $logs,
        events => $events,
        describe => $describe,
    );

    return $self->call_ollama($prompt);
}

sub analyze_cluster {
    my ($self) = @_;

    my $pods = $self->_get_problem_pods();
    my $events = $self->_get_recent_events();

    my $prompt = $self->build_cluster_prompt(
        pods => $pods,
        events => $events,
    );

    return $self->call_ollama($prompt);
}

sub build_prompt {
    my ($self, %args) = @_;

    my $prompt = "You are a Kubernetes expert. Analyze the following issue and provide a diagnosis.\n\n";
    $prompt .= "Resource: $args{type}/$args{name}\n";
    $prompt .= "Namespace: $args{namespace}\n\n";

    if ($args{logs}) {
        $prompt .= "=== Recent Logs ===\n$args{logs}\n\n";
    }

    if ($args{events}) {
        $prompt .= "=== Recent Events ===\n$args{events}\n\n";
    }

    if ($args{describe}) {
        $prompt .= "=== Resource Description ===\n$args{describe}\n\n";
    }

    $prompt .= "Please provide:\n";
    $prompt .= "1. Root cause analysis\n";
    $prompt .= "2. Recommended fix\n";
    $prompt .= "3. Commands to resolve the issue\n";

    return $prompt;
}

sub build_cluster_prompt {
    my ($self, %args) = @_;

    my $prompt = "You are a Kubernetes expert. Analyze the cluster health.\n\n";

    if ($args{pods}) {
        $prompt .= "=== Problem Pods ===\n$args{pods}\n\n";
    }

    if ($args{events}) {
        $prompt .= "=== Recent Events ===\n$args{events}\n\n";
    }

    $prompt .= "Provide:\n";
    $prompt .= "1. Summary of issues\n";
    $prompt .= "2. Priority actions\n";
    $prompt .= "3. Commands to investigate\n";

    return $prompt;
}

sub call_ollama {
    my ($self, $prompt) = @_;

    my $http = HTTP::Tiny->new(timeout => 30);

    my $url = "$self->{endpoint}/api/generate";
    my $payload = encode_json({
        model => $self->{model},
        prompt => $prompt,
        stream => JSON::PP::false,
    });

    my $response = $http->post($url, {
        headers => { 'Content-Type' => 'application/json' },
        content => $payload,
    });

    if (!$response->{success}) {
        return { error => "Ollama request failed: $response->{status} $response->{reason}" };
    }

    my $data = eval { decode_json($response->{content}) };
    if ($@) {
        return { error => "Failed to parse Ollama response: $@" };
    }

    return { response => $data->{response} // '' };
}

sub _get_logs {
    my ($self, $name, $namespace) = @_;
    return '' unless $self->{kubectl};

    my @cmd = ('logs', $name, '--tail=50');
    push @cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);
    return $stdout // '';
}

sub _get_events {
    my ($self, $type, $name, $namespace) = @_;
    return '' unless $self->{kubectl};

    my @cmd = ('get', 'events', '--sort-by=.lastTimestamp');
    push @cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);
    return $stdout // '';
}

sub _describe {
    my ($self, $type, $name, $namespace) = @_;
    return '' unless $self->{kubectl};

    my @cmd = ('describe', $type, $name);
    push @cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);
    return $stdout // '';
}

sub _get_problem_pods {
    my ($self) = @_;
    return '' unless $self->{kubectl};

    my ($stdout, $stderr) = $self->{kubectl}->_run('get', 'pods', '--all-namespaces', '--field-selector=status.phase!=Running,status.phase!=Succeeded');
    return $stdout // '';
}

sub _get_recent_events {
    my ($self) = @_;
    return '' unless $self->{kubectl};

    my ($stdout, $stderr) = $self->{kubectl}->_run('get', 'events', '--all-namespaces', '--sort-by=.lastTimestamp');
    return $stdout // '';
}

1;
