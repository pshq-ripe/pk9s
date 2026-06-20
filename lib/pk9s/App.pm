package pk9s::App;
use strict;
use warnings;
use Term::ANSIColor;

my @VIEWS = (
    {
        name => 'pods',
        label => 'Pods',
        method => 'get_pods',
        columns => ['NAME', 'STATUS', 'READY', 'AGE'],
        extract => sub {
            my ($resource) = @_;
            return [
                $resource->name,
                $resource->status,
                $resource->ready,
                $resource->age,
            ];
        },
    },
    {
        name => 'deployments',
        label => 'Deployments',
        method => 'get_deployments',
        columns => ['NAME', 'READY', 'UP-TO-DATE', 'AVAILABLE', 'AGE'],
        extract => sub {
            my ($resource) = @_;
            return [
                $resource->name,
                $resource->ready,
                '-',
                '-',
                $resource->age,
            ];
        },
    },
    {
        name => 'services',
        label => 'Services',
        method => 'get_services',
        columns => ['NAME', 'TYPE', 'CLUSTER-IP', 'EXTERNAL-PORT', 'AGE'],
        extract => sub {
            my ($resource) = @_;
            return [
                $resource->name,
                '-',
                '-',
                '-',
                $resource->age,
            ];
        },
    },
    {
        name => 'nodes',
        label => 'Nodes',
        method => 'get_nodes',
        columns => ['NAME', 'STATUS', 'ROLES', 'AGE', 'VERSION'],
        extract => sub {
            my ($resource) = @_;
            return [
                $resource->name,
                $resource->status,
                '-',
                $resource->age,
                '-',
            ];
        },
    },
);

my %STATUS_COLORS = (
    Running   => 'green',
    Pending   => 'yellow',
    Error     => 'red',
    Failed    => 'red',
    Succeeded => 'blue',
    Unknown   => 'white',
);

sub new {
    my ($class, %args) = @_;
    my $self = {
        config => $args{config},
        kubectl => $args{kubectl},
        _current_view => 0,
        _selected_row => 0,
        _scroll_offset => 0,
        _resources => [],
        _show_help => 0,
        _refresh_interval => $args{refresh_interval} || 5,
        _last_refresh => 0,
    };
    return bless $self, $class;
}

sub run {
    my ($self) = @_;
    require Tickit;
    Tickit->import;
    $self->{_tickit} = Tickit->new;
    $self->_build_ui();
    $self->_setup_keybindings();
    $self->_setup_timer();
    $self->_refresh_data();
    $self->{_tickit}->run;
}

sub _build_ui {
    my ($self) = @_;
    # Will be implemented in Task 3
}

sub _setup_keybindings {
    my ($self) = @_;
    # Will be implemented in Task 4
}

sub _setup_timer {
    my ($self) = @_;
    # Will be implemented in Task 6
}

sub _refresh_data {
    my ($self) = @_;
    # Will be implemented in Task 5
}

sub _render_table {
    my ($self) = @_;
    # Will be implemented in Task 3
}

sub _render_help {
    my ($self) = @_;
    # Will be implemented in Task 7
}

sub _switch_view {
    my ($self, $direction) = @_;
    # Will be implemented in Task 4
}

sub _clamp_selection {
    my ($self) = @_;
    my $max = scalar @{$self->{_resources}} - 1;
    $self->{_selected_row} = 0 if $self->{_selected_row} < 0;
    $self->{_selected_row} = $max if $self->{_selected_row} > $max;
}

sub colorize_status {
    my ($status) = @_;
    my $color = $STATUS_COLORS{$status} || 'white';
    return colored($status, $color);
}

sub views { return @VIEWS }

1;
