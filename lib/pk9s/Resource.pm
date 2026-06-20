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
    
    if ($type eq 'pod') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = $raw->{status}{phase} // 'Unknown';
        $args{age}       = $class->_calc_age($raw->{metadata}{creationTimestamp});
        
        my @containers = @{$raw->{status}{containerStatuses} // []};
        my $ready = grep { $_->{ready} } @containers;
        $args{ready} = "$ready/" . scalar(@containers) if @containers;
    }
    elsif ($type eq 'deployment') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = 'Running';
        $args{age}       = $class->_calc_age($raw->{metadata}{creationTimestamp});
        
        my $replicas = $raw->{status}{replicas} // 0;
        my $ready    = $raw->{status}{readyReplicas} // 0;
        $args{ready} = "$ready/$replicas" if $replicas;
    }
    elsif ($type eq 'service') {
        $args{name}      = $raw->{metadata}{name} // '';
        $args{namespace} = $raw->{metadata}{namespace} // 'default';
        $args{status}    = 'Active';
        $args{ready}     = '-';
    }
    
    return $class->new(%args);
}

sub _calc_age {
    my ($class, $timestamp) = @_;
    return '-' unless $timestamp;
    
    my @parts = split /[-T:]/, $timestamp;
    my $then = timegm($parts[5], $parts[4], $parts[3], $parts[2], $parts[1] - 1, $parts[0]);
    my $now = time();
    my $days = int(($now - $then) / 86400);
    
    return "${days}d" if $days > 0;
    my $hours = int(($now - $then) / 3600);
    return "${hours}h" if $hours > 0;
    return '<1h';
}

1;
