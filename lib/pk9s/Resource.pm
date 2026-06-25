package pk9s::Resource;
use strict;
use warnings;
use Time::Local 'timegm';

sub new {
    my ($class, %args) = @_;
    my $self = {
        name      => $args{name}      || '',
        namespace => $args{namespace} || 'default',
        type      => $args{type}      || 'unknown',
        status    => $args{status}    || 'Unknown',
        ready     => $args{ready}     || '-',
        age       => $args{age}       || '-',
        raw       => $args{raw}       || {},
    };
    return bless $self, $class;
}

sub name      { return $_[0]->{name} }
sub namespace { return $_[0]->{namespace} }
sub type      { return $_[0]->{type} }
sub status    { return $_[0]->{status} }
sub ready     { return $_[0]->{ready} }
sub age       { return $_[0]->{age} }
sub raw       { return $_[0]->{raw} }

sub normalize {
    my ($class, $raw, $type) = @_;
    
    my %args = (
        raw  => $raw,
        type => $type,
    );
    
    my $meta = $raw->{metadata} // {};
    $args{name}      = $meta->{name} // '';
    $args{namespace} = $meta->{namespace} // 'default';
    $args{age}       = $class->_calc_age($meta->{creationTimestamp});
    
    if ($type eq 'pod') {
        $args{status} = $raw->{status}{phase} // 'Unknown';
        my @containers = @{$raw->{status}{containerStatuses} // []};
        my $ready = grep { $_->{ready} } @containers;
        $args{ready} = "$ready/" . scalar(@containers) if @containers;
    }
    elsif ($type eq 'deployment') {
        my $replicas = $raw->{spec}{replicas} // 1;
        my $ready    = $raw->{status}{readyReplicas} // 0;
        my $updated  = $raw->{status}{updatedReplicas} // 0;
        my $avail    = $raw->{status}{availableReplicas} // 0;
        $args{status} = $ready == $replicas ? 'Running' : 'Pending';
        $args{ready}  = "$ready/$replicas";
        $args{extra}  = { updated => $updated, available => $avail };
    }
    elsif ($type eq 'statefulset') {
        my $replicas = $raw->{spec}{replicas} // 1;
        my $ready    = $raw->{status}{readyReplicas} // 0;
        $args{status} = $ready == $replicas ? 'Running' : 'Pending';
        $args{ready}  = "$ready/$replicas";
    }
    elsif ($type eq 'daemonset') {
        my $desired   = $raw->{status}{desiredNumberScheduled} // 0;
        my $ready     = $raw->{status}{numberReady} // 0;
        $args{status} = $ready == $desired ? 'Running' : 'Pending';
        $args{ready}  = "$ready/$desired";
    }
    elsif ($type eq 'replicaset') {
        my $replicas = $raw->{spec}{replicas} // 1;
        my $ready    = $raw->{status}{readyReplicas} // 0;
        $args{status} = $ready == $replicas ? 'Running' : 'Pending';
        $args{ready}  = "$ready/$replicas";
    }
    elsif ($type eq 'job') {
        my $succeeded = $raw->{status}{succeeded} // 0;
        my $failed    = $raw->{status}{failed} // 0;
        my $running   = $raw->{status}{active} // 0;
        $args{status} = $failed > 0 ? 'Failed' : ($running > 0 ? 'Running' : ($succeeded > 0 ? 'Complete' : 'Pending'));
        $args{ready}  = $running > 0 ? "active=$running" : "succeeded=$succeeded";
    }
    elsif ($type eq 'cronjob') {
        $args{status} = $raw->{spec}{suspend} ? 'Suspended' : 'Active';
        my $last = $raw->{status}{lastScheduleTime} // '';
        $args{ready} = $last ? 'Last: ' . _short_time($last) : '-';
    }
    elsif ($type eq 'service') {
        $args{status} = 'Active';
        $args{ready}  = '-';
        my $type_str = $raw->{spec}{type} // 'ClusterIP';
        $args{extra} = { type => $type_str };
    }
    elsif ($type eq 'ingress') {
        my @rules = @{$raw->{spec}{rules} // []};
        my $host = $rules[0]{host} // '-';
        $args{status} = 'Active';
        $args{ready}  = $host;
    }
    elsif ($type eq 'configmap') {
        $args{status} = 'Active';
        my $keys = scalar keys %{$raw->{data} // {}};
        $args{ready} = "$keys keys";
    }
    elsif ($type eq 'secret') {
        $args{status} = $raw->{type} // 'Opaque';
        my $keys = scalar keys %{$raw->{data} // {}};
        $args{ready} = "$keys keys";
    }
    elsif ($type eq 'persistentvolumeclaim') {
        $args{status} = $raw->{status}{phase} // 'Pending';
        my $size = $raw->{spec}{resources}{requests}{storage} // '-';
        $args{ready} = $size;
    }
    elsif ($type eq 'persistentvolume') {
        $args{status} = $raw->{status}{phase} // 'Available';
        my $capacity = $raw->{spec}{capacity}{storage} // '-';
        $args{ready} = $capacity;
    }
    elsif ($type eq 'namespace') {
        $args{status} = $raw->{status}{phase} // 'Active';
        $args{ready}  = '-';
    }
    elsif ($type eq 'serviceaccount') {
        $args{status} = 'Active';
        my $secrets = scalar @{$raw->{secrets} // []};
        $args{ready} = "$secrets secrets";
    }
    elsif ($type eq 'networkpolicy') {
        $args{status} = 'Active';
        my @podsel = keys %{$raw->{spec}{podSelector}{matchLabels} // {}};
        $args{ready} = @podsel ? join(',', @podsel) : 'all pods';
    }
    elsif ($type eq 'resourcequota') {
        $args{status} = 'Active';
        my @hard = keys %{$raw->{spec}{hard} // {}};
        $args{ready} = scalar(@hard) . ' quotas';
    }
    elsif ($type eq 'limitrange') {
        $args{status} = 'Active';
        my @limits = @{$raw->{spec}{limits} // []};
        $args{ready} = scalar(@limits) . ' limits';
    }
    elsif ($type eq 'role') {
        $args{status} = 'Active';
        my @rules = @{$raw->{rules} // []};
        $args{ready} = scalar(@rules) . ' rules';
    }
    elsif ($type eq 'clusterrole') {
        $args{status} = 'Active';
        my @rules = @{$raw->{rules} // []};
        $args{ready} = scalar(@rules) . ' rules';
    }
    elsif ($type eq 'rolebinding') {
        $args{status} = 'Active';
        my @subjects = @{$raw->{subjects} // []};
        $args{ready} = scalar(@subjects) . ' subjects';
    }
    elsif ($type eq 'clusterrolebinding') {
        $args{status} = 'Active';
        my @subjects = @{$raw->{subjects} // []};
        $args{ready} = scalar(@subjects) . ' subjects';
    }
    elsif ($type eq 'storageclass') {
        $args{status} = 'Active';
        $args{ready}  = $raw->{provisioner} // '-';
    }
    
    return $class->new(%args);
}

sub _calc_age {
    my ($class, $timestamp) = @_;
    return '-' unless $timestamp;
    
    my @parts = split /[-T:]/, $timestamp;
    return '-' unless scalar @parts >= 6;
    
    my $then = eval { timegm($parts[5], $parts[4], $parts[3], $parts[2], $parts[1] - 1, $parts[0]) };
    return '-' unless defined $then;
    
    my $now = time();
    my $diff = $now - $then;
    return '-' if $diff < 0;
    
    my $days = int($diff / 86400);
    return "${days}d" if $days > 0;
    my $hours = int($diff / 3600);
    return "${hours}h" if $hours > 0;
    return '<1h';
}

sub _short_time {
    my ($ts) = @_;
    $ts =~ s/\.\d+Z//;
    $ts =~ s/T/ /;
    return $ts;
}

1;
