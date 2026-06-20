package pk9s::Config;
use strict;
use warnings;
use JSON::PP;

my %DEFAULTS = (
    kubectl   => 'kubectl',
    context   => undef,
    namespace => 'default',
    editor    => $ENV{EDITOR} || 'vim',
    log_level => 'info',
);

sub new {
    my ($class, %args) = @_;
    my $self = { %DEFAULTS };

    if ($args{file} && -f $args{file}) {
        open my $fh, '<', $args{file} or die "Cannot open $args{file}: $!";
        my $json = do { local $/; <$fh> };
        close $fh;

        my $data = eval { decode_json($json) };
        if ($data && ref $data eq 'HASH') {
            @$self{keys %$data} = values %$data;
        }
    }

    return bless $self, $class;
}

sub get {
    my ($self, $key) = @_;
    return $self->{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
}

sub all {
    my ($self) = @_;
    return %$self;
}

1;
