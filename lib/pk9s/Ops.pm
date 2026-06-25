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
    my @cmd = ('delete', $type, $name);
    push @cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);

    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }

    return { success => 1, message => $stdout };
}

sub rollout_restart {
    my ($self, $type, $name, $namespace) = @_;
    my @cmd = ('rollout', 'restart', "$type/$name");
    push @cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@cmd);

    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }

    return { success => 1, message => $stdout };
}

sub edit_resource {
    my ($self, $type, $name, $namespace) = @_;

    my @get_cmd = ('get', $type, $name, '-o', 'yaml');
    push @get_cmd, '--namespace', $namespace if $namespace;

    my ($stdout, $stderr) = $self->{kubectl}->_run(@get_cmd);

    if ($stderr && $stderr =~ /error/i) {
        return { error => $stderr };
    }

    require File::Temp;
    my ($fh, $tempfile) = File::Temp::tempfile(SUFFIX => '.yaml', UNLINK => 0);
    print $fh $stdout;
    close $fh;

    my $editor = $ENV{EDITOR} || 'vim';
    system($editor, $tempfile);

    my @dry_cmd = ('apply', '--dry-run=client', '-f', $tempfile);
    push @dry_cmd, '--namespace', $namespace if $namespace;

    my ($dry_out, $dry_err) = $self->{kubectl}->_run(@dry_cmd);

    if ($dry_err && $dry_err =~ /error/i) {
        return { error => "Dry-run failed: $dry_err", tempfile => $tempfile };
    }

    my @apply_cmd = ('apply', '-f', $tempfile);
    push @apply_cmd, '--namespace', $namespace if $namespace;

    my ($apply_out, $apply_err) = $self->{kubectl}->_run(@apply_cmd);

    unlink $tempfile;

    if ($apply_err && $apply_err =~ /error/i) {
        return { error => $apply_err };
    }

    return { success => 1, message => $apply_out };
}

sub port_forward {
    my ($self, $type, $name, $namespace, $ports) = @_;

    my @cmd = ($self->{kubectl}{kubectl});
    push @cmd, '--context', $self->{kubectl}{context} if $self->{kubectl}{context};
    push @cmd, 'port-forward', "$type/$name", $ports;
    push @cmd, '--namespace', $namespace if $namespace;

    my $pid = fork();

    if (!defined $pid) {
        return { error => "Fork failed: $!" };
    }

    if ($pid == 0) {
        exec(@cmd);
        exit 1;
    }

    return { pid => $pid, ports => $ports };
}

sub kill_portforward {
    my ($self, $pid) = @_;
    kill 'TERM', $pid;
    waitpid($pid, 0);
    return { success => 1 };
}

1;
