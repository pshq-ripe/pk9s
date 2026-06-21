package pk9s::Search;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {};
    return bless $self, $class;
}

sub parse_query {
    my ($self, $query) = @_;
    
    if ($query =~ /^all:(.*)$/) {
        return ($1, 'all');
    }
    
    return ($query, 'current');
}

sub build_regex {
    my ($self, $term) = @_;
    return undef unless defined $term && length $term;
    
    # Escape special regex characters (except *)
    $term =~ s/([.+?^\$\[\]{}|\\()])/\\$1/g;
    
    # Convert * to .* for glob-style matching
    $term =~ s/\*/.*/g;
    
    # Build case-insensitive regex
    return qr/$term/i;
}

sub filter {
    my ($self, %args) = @_;
    my $resources = $args{resources} || [];
    my $regex = $args{regex};
    my $extract = $args{extract};
    
    return @$resources unless $regex;
    
    my @filtered;
    for my $res (@$resources) {
        my $row = $extract->($res);
        my $match = grep { /$regex/ } @$row;
        push @filtered, $res if $match;
    }
    
    return @filtered;
}

sub highlight {
    my ($self, $text, $regex) = @_;
    
    return $text unless $regex;
    
    # Highlight matching text with ANSI bold
    $text =~ s/($regex)/\e[1m$1\e[0m/g;
    
    return $text;
}

1;
