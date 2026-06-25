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

sub get_pods {
    my ($self, %args) = @_;
    my @cmd = ('get', 'pods', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub get_deployments {
    my ($self, %args) = @_;
    my @cmd = ('get', 'deployments', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub get_services {
    my ($self, %args) = @_;
    my @cmd = ('get', 'services', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
}

sub get_nodes {
    my ($self, %args) = @_;
    my @cmd = ('get', 'nodes', '--output=json');
    return $self->execute(@cmd);
}

sub get_configmaps {
    my ($self, %args) = @_;
    my @cmd = ('get', 'configmaps', '--output=json');
    push @cmd, '--namespace', $args{namespace} if $args{namespace};
    return $self->execute(@cmd);
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
