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
        _search_active => 0,
        _search_query => '',
        _search_regex => undef,
        _filtered_resources => [],
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
    $self->{_root_window} = $self->{_tickit}->root;
}

sub _setup_keybindings {
    my ($self) = @_;
    my $term = $self->{_tickit}->term;

    my %handlers = (
        'j'     => sub { $self->_key_down() },
        'Down'  => sub { $self->_key_down() },
        'k'     => sub { $self->_key_up() },
        'Up'    => sub { $self->_key_up() },
        'g'     => sub { $self->_key_home() },
        'Home'  => sub { $self->_key_home() },
        'G'     => sub { $self->_key_end() },
        'End'   => sub { $self->_key_end() },
        'Tab'   => sub { $self->_switch_view(1); $self->_refresh_data(); },
        'BTab'  => sub { $self->_switch_view(-1); $self->_refresh_data(); },
        'r'     => sub { $self->_refresh_data() },
        '?'     => sub { $self->{_show_help} = 1; $self->_render_help(); },
        'q'     => sub { $self->{_tickit}->stop },
        'C-c'   => sub { $self->{_tickit}->stop },
        '/'     => sub {
            $self->{_search_active} = 1;
            $self->{_search_query} = '';
            $self->{_search_regex} = undef;
            $self->{_filtered_resources} = $self->{_resources};
            $self->_render_search();
        },
        'Escape' => sub {
            $self->{_search_active} = 0;
            $self->_render_table();
        },
        'Enter' => sub {
            $self->{_search_active} = 0;
            $self->_apply_search();
            $self->_render_table();
        },
        'C-u'   => sub {
            $self->{_search_query} = '';
            $self->{_search_regex} = undef;
            $self->{_filtered_resources} = $self->{_resources};
            $self->_render_search() if $self->{_search_active};
        },
    );

    $term->cb_keypress(sub {
        my ($type, $str) = @_;
        return unless $type eq 'key';

        if ($self->{_show_help}) {
            $self->{_show_help} = 0;
            $self->_render_table();
            return;
        }

        if ($self->{_search_active}) {
            if (length($str) == 1 && $str =~ /[[:print:]]/) {
                $self->{_search_query} .= $str;
                $self->_apply_search();
                $self->_render_search();
                return;
            }
            if ($str eq 'Backspace') {
                $self->{_search_query} =~ s/.$//;
                $self->_apply_search();
                $self->_render_search();
                return;
            }
        }

        my $handler = $handlers{$str};
        $handler->() if $handler;
    });
}

sub _key_down {
    my ($self) = @_;
    $self->{_selected_row}++;
    $self->_clamp_selection();
    $self->_render_table();
}

sub _key_up {
    my ($self) = @_;
    $self->{_selected_row}--;
    $self->_clamp_selection();
    $self->_render_table();
}

sub _key_home {
    my ($self) = @_;
    $self->{_selected_row} = 0;
    $self->_render_table();
}

sub _key_end {
    my ($self) = @_;
    $self->{_selected_row} = scalar @{$self->{_resources}} - 1;
    $self->_render_table();
}

sub _setup_timer {
    my ($self) = @_;
    require Tickit::Timer;
    Tickit::Timer->import;
    $self->{_timer} = Tickit::Timer->interval(
        $self->{_refresh_interval},
        sub {
            return if $self->{_show_help};
            $self->_refresh_data();
        },
    );
}

sub _refresh_data {
    my ($self) = @_;
    my $view = $VIEWS[$self->{_current_view}];

    my $method = $view->{method};
    my $data = $self->{kubectl}->$method(
        namespace => $self->{config}->get('namespace'),
    );

    if ($data->{error}) {
        $self->{_resources} = [];
        return;
    }

    my $type = $view->{name};
    $type =~ s/s$//;

    my @resources = map {
        pk9s::Resource->normalize($_, $type)
    } @{$data->{items} // []};

    $self->{_resources} = \@resources;
    $self->{_last_refresh} = time();
    $self->_clamp_selection();
    $self->_render_table();
}

sub _render_table {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;

    my $view = $VIEWS[$self->{_current_view}];
    my $cols = $view->{columns};
    my $resources = $self->{_resources};

    my @widths = map { length($_) + 2 } @$cols;
    for my $res (@$resources) {
        my $row = $view->{extract}->($res);
        for my $i (0..$#$row) {
            my $len = length($row->[$i]) + 2;
            $widths[$i] = $len if $len > $widths[$i];
        }
    }

    my $header = '';
    for my $i (0..$#$cols) {
        $header .= sprintf("%-*s", $widths[$i], $cols->[$i]);
    }
    $win->printAt(0, 0, $header, 0);

    my $sep = '─' x ($win->cols - 1);
    $win->printAt(1, 0, $sep, 0);

    my $row_num = 2;
    my $start = $self->{_scroll_offset};
    my $visible = $win->lines - 3;

    for my $i ($start..$#$resources) {
        last if $row_num >= $visible + 2;

        my $res = $resources->[$i];
        my $row = $view->{extract}->($res);
        my $is_selected = ($i == $self->{_selected_row});

        my $line = $is_selected ? '▶ ' : '  ';
        for my $j (0..$#$row) {
            my $val = $row->[$j];
            $val = sprintf("%-*s", $widths[$j], $val);
            if ($j == 1) {
                $val = colorize_status($val);
            }
            $line .= $val;
        }

        my $pen = $is_selected ? 1 : 0;
        $win->printAt($row_num, 0, $line, $pen);
        $row_num++;
    }

    for my $i ($row_num..$visible + 1) {
        $win->eraseAt($i, 0, $win->cols);
    }

    my $footer = sprintf("j/k: navigate  Tab: switch view  r: refresh  ?: help  q: quit");
    $win->printAt($win->lines - 1, 0, $footer, 0);
}

sub _render_search {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;

    my $query = $self->{_search_query};
    my $count = scalar @{$self->{_filtered_resources}};
    my $total = scalar @{$self->{_resources}};

    my $line = sprintf("/ %-50s [%d/%d]", $query, $count, $total);
    $win->printAt($win->lines - 1, 0, $line, 0);
}

sub _render_help {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    
    my $box_width = 50;
    my $sep_line = "\x{2500}" x ($box_width - 2);
    
    my @help_lines = (
        'pk9s — Help',
        '',
        'Navigation:',
        '  j / \x{2193}      Move down',
        '  k / \x{2191}      Move up',
        '  g / Home   Jump to top',
        '  G / End    Jump to bottom',
        '',
        'Views:',
        '  Tab        Next view',
        '  Shift+Tab  Previous view',
        '',
        'Actions:',
        '  r          Refresh data',
        '  ?          Toggle this help',
        '  q          Quit',
        '',
        'Press any key to close',
    );
    
    for my $i (0..$win->lines - 1) {
        $win->eraseAt($i, 0, $win->cols);
    }
    
    my $box_left = ($win->cols - $box_width) / 2;
    my $box_top = 2;
    
    $win->printAt($box_top, $box_left, "\x{250c}" . $sep_line . "\x{2510}", 0);
    
    for my $i (0..$#help_lines) {
        my $line = $help_lines[$i];
        my $padded;
        
        if ($line eq '' && ($i == 1 || $i == $#help_lines - 1)) {
            $padded = "\x{251c}" . $sep_line . "\x{2524}";
        } else {
            $padded = sprintf("\x{2502} %-*s \x{2502}", $box_width - 4, $line);
        }
        $win->printAt($box_top + 1 + $i, $box_left, $padded, 0);
    }
    
    $win->printAt($box_top + scalar(@help_lines) + 1, $box_left, "\x{2514}" . $sep_line . "\x{2518}", 0);
}

sub _switch_view {
    my ($self, $direction) = @_;
    my $num_views = scalar @VIEWS;
    $self->{_current_view} = ($self->{_current_view} + $direction) % $num_views;
    $self->{_selected_row} = 0;
    $self->{_scroll_offset} = 0;
}

sub _clamp_selection {
    my ($self) = @_;
    my $max = scalar @{$self->{_resources}} - 1;
    $self->{_selected_row} = 0 if $self->{_selected_row} < 0 || $max < 0;
    $self->{_selected_row} = $max if $max >= 0 && $self->{_selected_row} > $max;
}

sub colorize_status {
    my ($status) = @_;
    my $color = $STATUS_COLORS{$status} || 'white';
    return colored($status, $color);
}

sub views { return @VIEWS }

1;
