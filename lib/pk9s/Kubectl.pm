package pk9s::Kubectl;
use strict;
use warnings;
use JSON::PP;
use IPC::Open3;
use Symbol 'gensym';

sub new {
    my ($class, %args) = @_;
    my $self = {
        kubectl => $args{kubectl} || 'kubectl',
        context => $args{context} || undef,
    };
    return bless $self, $class;
}

sub execute {
    my ($self, @args) = @_;
    
    my @cmd = ($self->{kubectl});
    push @cmd, '--context', $self->{context} if $self->{context};
    push @cmd, @args;
    
    my ($stdout, $stderr) = $self->_run(@cmd);
    
    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }
    
    my $data = eval { decode_json($stdout) };
    if ($@) {
        return { error => "JSON decode failed: $@" };
    }
    
    return $data;
}

sub _get {
    my ($self, $resource, %args) = @_;
    my @cmd = ('get', $resource, '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub get_pods                    { $_[0]->_get('pods', @_[1..$#_]) }
sub get_deployments             { $_[0]->_get('deployments', @_[1..$#_]) }
sub get_services                { $_[0]->_get('services', @_[1..$#_]) }
sub get_configmaps              { $_[0]->_get('configmaps', @_[1..$#_]) }
sub get_secrets                 { $_[0]->_get('secrets', @_[1..$#_]) }
sub get_persistentvolumeclaims  { $_[0]->_get('persistentvolumeclaims', @_[1..$#_]) }
sub get_serviceaccounts         { $_[0]->_get('serviceaccounts', @_[1..$#_]) }
sub get_namespaces              { $_[0]->_get('namespaces') }
sub get_nodes                   { $_[0]->_get('nodes') }
sub get_persistentvolumes       { $_[0]->_get('persistentvolumes') }
sub get_statefulsets            { $_[0]->_get('statefulsets', @_[1..$#_]) }
sub get_daemonsets              { $_[0]->_get('daemonsets', @_[1..$#_]) }
sub get_replicasets             { $_[0]->_get('replicasets', @_[1..$#_]) }
sub get_jobs                    { $_[0]->_get('jobs', @_[1..$#_]) }
sub get_cronjobs                { $_[0]->_get('cronjobs', @_[1..$#_]) }
sub get_ingresses               { $_[0]->_get('ingresses', @_[1..$#_]) }
sub get_networkpolicies         { $_[0]->_get('networkpolicies', @_[1..$#_]) }
sub get_resourcequotas          { $_[0]->_get('resourcequotas', @_[1..$#_]) }
sub get_limitranges             { $_[0]->_get('limitranges', @_[1..$#_]) }
sub get_roles                   { $_[0]->_get('roles', @_[1..$#_]) }
sub get_clusterroles            { $_[0]->_get('clusterroles') }
sub get_rolebindings            { $_[0]->_get('rolebindings', @_[1..$#_]) }
sub get_clusterrolebindings     { $_[0]->_get('clusterrolebindings') }
sub get_storageclasses          { $_[0]->_get('storageclasses') }

sub get_logs {
    my ($self, %args) = @_;
    my $name = delete $args{name} or return {};
    my @cmd = ('logs', $name, '--tail=' . ($args{tail} // 100));
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    push @cmd, '--previous' if $args{previous};
    push @cmd, '-c', $args{container} if $args{container};
    my ($stdout, $stderr) = $self->_run(@cmd);
    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }
    return { logs => $stdout // '' };
}

sub get_describe {
    my ($self, %args) = @_;
    my $resource = delete $args{resource} or return {};
    my $name = delete $args{name};
    my @cmd = ('describe', $resource);
    push @cmd, $name if $name;
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    my ($stdout, $stderr) = $self->_run(@cmd);
    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }
    return { output => $stdout // '' };
}

sub get_top_pods {
    my ($self, %args) = @_;
    my @cmd = ('top', 'pods', '--no-headers');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    push @cmd, '--containers' if $args{containers};
    my ($stdout, $stderr) = $self->_run(@cmd);
    return { output => $stdout // '', error => $stderr };
}

sub _run {
    my ($self, @cmd) = @_;
    
    my $err = gensym;
    my $pid = open3(my $stdin, my $stdout, $err, @cmd);
    
    my $out = do { local $/; <$stdout> };
    my $err_out = do { local $/; <$err> };
    
    close $stdin;
    close $stdout;
    close $err;
    
    waitpid($pid, 0);
    
    return ($out, $err_out);
}

1;
