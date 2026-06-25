package pk9s::Ops;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {
        kubectl => $args{kubectl},
    };
    return bless $self, $class;
}

sub get_logs {
    my ($self, $name, $namespace, %args) = @_;
    my $tail = $args{tail} // 100;
    my @cmd = ('logs', $name, '--tail=' . $tail);
    push @cmd, '--namespace', $namespace if $namespace;
    push @cmd, '--previous' if $args{previous};

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);

    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }

    return { logs => $stdout // '' };
}

sub delete_resource {
    my ($self, $type, $name, $namespace) = @_;
    return { error => "not implemented" };
}

sub rollout_restart {
    my ($self, $type, $name, $namespace) = @_;
    return { error => "not implemented" };
}

sub edit_resource {
    my ($self, $type, $name, $namespace) = @_;
    return { error => "not implemented" };
}

sub port_forward {
    my ($self, $type, $name, $namespace, $ports) = @_;
    return { error => "not implemented" };
}

sub kill_portforward {
    my ($self, $pid) = @_;
    return { success => 1 };
}

1;
