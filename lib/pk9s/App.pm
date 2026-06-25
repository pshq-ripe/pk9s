package pk9s::App;
use strict;
use warnings;

use Term::ANSIColor;

my @VIEWS = (
    # Core
    { name => 'namespaces',        label => 'Namespaces',         method => 'get_namespaces',             columns => ['NAME', 'STATUS', 'AGE'],                extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->age ] } },
    { name => 'pods',              label => 'Pods',               method => 'get_pods',                   columns => ['NAME', 'STATUS', 'READY', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'services',          label => 'Services',           method => 'get_services',               columns => ['NAME', 'TYPE', 'READY', 'AGE'],          extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'configmaps',        label => 'ConfigMaps',         method => 'get_configmaps',             columns => ['NAME', 'KEYS', 'AGE'],                   extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->age ] } },
    { name => 'secrets',           label => 'Secrets',            method => 'get_secrets',                columns => ['NAME', 'TYPE', 'KEYS', 'AGE'],           extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'serviceaccounts',   label => 'ServiceAccounts',    method => 'get_serviceaccounts',        columns => ['NAME', 'SECRETS', 'AGE'],                extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->age ] } },
    # Workloads
    { name => 'deployments',       label => 'Deployments',        method => 'get_deployments',            columns => ['NAME', 'READY', 'STATUS', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'statefulsets',      label => 'StatefulSets',       method => 'get_statefulsets',           columns => ['NAME', 'READY', 'STATUS', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'daemonsets',        label => 'DaemonSets',         method => 'get_daemonsets',             columns => ['NAME', 'READY', 'STATUS', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'replicasets',       label => 'ReplicaSets',        method => 'get_replicasets',            columns => ['NAME', 'READY', 'STATUS', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'jobs',              label => 'Jobs',               method => 'get_jobs',                   columns => ['NAME', 'STATUS', 'READY', 'AGE'],        extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'cronjobs',          label => 'CronJobs',           method => 'get_cronjobs',               columns => ['NAME', 'STATUS', 'SCHEDULE', 'AGE'],     extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    # Networking
    { name => 'ingresses',         label => 'Ingresses',          method => 'get_ingresses',              columns => ['NAME', 'HOST', 'STATUS', 'AGE'],         extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'networkpolicies',   label => 'NetworkPolicies',    method => 'get_networkpolicies',        columns => ['NAME', 'PODS', 'STATUS', 'AGE'],         extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    # Config
    { name => 'resourcequotas',    label => 'ResourceQuotas',     method => 'get_resourcequotas',         columns => ['NAME', 'QUOTAS', 'STATUS', 'AGE'],       extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'limitranges',       label => 'LimitRanges',        method => 'get_limitranges',            columns => ['NAME', 'LIMITS', 'STATUS', 'AGE'],       extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    # Storage
    { name => 'persistentvolumeclaims', label => 'PVCs',           method => 'get_persistentvolumeclaims', columns => ['NAME', 'STATUS', 'CAPACITY', 'AGE'],    extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'persistentvolumes',      label => 'PVs',            method => 'get_persistentvolumes',      columns => ['NAME', 'STATUS', 'CAPACITY', 'AGE'],    extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
    { name => 'storageclasses',         label => 'StorageClasses',  method => 'get_storageclasses',         columns => ['NAME', 'PROVISIONER', 'STATUS', 'AGE'], extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    # RBAC
    { name => 'roles',                 label => 'Roles',            method => 'get_roles',                  columns => ['NAME', 'RULES', 'STATUS', 'AGE'],       extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'clusterroles',          label => 'ClusterRoles',     method => 'get_clusterroles',           columns => ['NAME', 'RULES', 'STATUS', 'AGE'],       extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'rolebindings',          label => 'RoleBindings',     method => 'get_rolebindings',           columns => ['NAME', 'SUBJECTS', 'STATUS', 'AGE'],    extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    { name => 'clusterrolebindings',   label => 'ClusterRoleBindings', method => 'get_clusterrolebindings', columns => ['NAME', 'SUBJECTS', 'STATUS', 'AGE'],    extract => sub { [ $_[0]->name, $_[0]->ready, $_[0]->status, $_[0]->age ] } },
    # Nodes
    { name => 'nodes',                label => 'Nodes',             method => 'get_nodes',                  columns => ['NAME', 'STATUS', 'VERSION', 'AGE'],     extract => sub { [ $_[0]->name, $_[0]->status, $_[0]->ready, $_[0]->age ] } },
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
        _portforwards => {},
        _log_view => 0,
        _log_lines => [],
        _log_scroll => 0,
        _confirm_action => undef,
        _context => undef,
        _ai => undef,
        _plugins => undef,
        _ai_view => 0,
        _ai_response => '',
        _ai_scroll => 0,
        _metrics_view => 0,
        _metrics_lines => [],
        _metrics_scroll => 0,
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
    $self->_init_context();
    $self->_init_plugins();
    $self->_refresh_data();
    $self->{_tickit}->run;
}

sub _init_context {
    my ($self) = @_;
    require pk9s::Context;
    $self->{_context} = pk9s::Context->new();

    require pk9s::AI;
    $self->{_ai} = pk9s::AI->new(
        context => $self->{_context},
        kubectl => $self->{kubectl},
    );
}

sub _init_plugins {
    my ($self) = @_;
    require pk9s::Plugin;
    $self->{_plugins} = pk9s::Plugin->new();
    $self->{_plugins}->load_plugins();
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
        'q'     => sub {
            require pk9s::Ops;
            my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
            for my $pid (keys %{$self->{_portforwards}}) {
                $ops->kill_portforward($pid);
            }
            $self->{_tickit}->stop;
        },
        'C-c'   => sub {
            require pk9s::Ops;
            my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
            for my $pid (keys %{$self->{_portforwards}}) {
                $ops->kill_portforward($pid);
            }
            $self->{_tickit}->stop;
        },
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
            $self->_render_table();
        },
        'C-u'   => sub {
            $self->{_search_query} = '';
            $self->{_search_regex} = undef;
            $self->{_filtered_resources} = $self->{_resources};
            $self->_render_search() if $self->{_search_active};
        },
        'e'     => sub { $self->_edit_resource() },
        'f'     => sub { $self->_port_forward() },
        'F'     => sub { $self->_list_portforwards() },
        'R'     => sub { $self->_rollout_restart() },
        'd'     => sub { $self->_delete_resource() },
        'l'     => sub { $self->_view_logs() },
        'L'     => sub { $self->_view_logs_full() },
        'm'     => sub { $self->_view_metrics() },
        'a'     => sub { $self->_analyze_resource() },
        'A'     => sub { $self->_analyze_cluster() },
        'p'     => sub { $self->_list_plugins() },
    );

    $term->cb_keypress(sub {
        my ($type, $str) = @_;
        return unless $type eq 'key';

        if ($self->{_show_help}) {
            $self->{_show_help} = 0;
            $self->_render_table();
            return;
        }

        if ($self->{_log_view}) {
            if ($str eq 'j' || $str eq 'Down') {
                $self->{_log_scroll}++ if $self->{_log_scroll} < scalar @{$self->{_log_lines}} - 1;
                $self->_render_logs();
                return;
            }
            if ($str eq 'k' || $str eq 'Up') {
                $self->{_log_scroll}-- if $self->{_log_scroll} > 0;
                $self->_render_logs();
                return;
            }
            if ($str eq 'q' || $str eq 'Escape') {
                $self->{_log_view} = 0;
                $self->_render_table();
                return;
            }
            if ($str eq 'G') {
                $self->{_log_scroll} = scalar @{$self->{_log_lines}} - 1;
                $self->_render_logs();
                return;
            }
            if ($str eq 'g') {
                $self->{_log_scroll} = 0;
                $self->_render_logs();
                return;
            }
            return;
        }

        if ($self->{_metrics_view}) {
            if ($str eq 'j' || $str eq 'Down') {
                $self->{_metrics_scroll}++ if $self->{_metrics_scroll} < scalar @{$self->{_metrics_lines}} - 1;
                $self->_render_metrics();
                return;
            }
            if ($str eq 'k' || $str eq 'Up') {
                $self->{_metrics_scroll}-- if $self->{_metrics_scroll} > 0;
                $self->_render_metrics();
                return;
            }
            if ($str eq 'q' || $str eq 'Escape') {
                $self->{_metrics_view} = 0;
                $self->_render_table();
                return;
            }
            return;
        }

        if ($self->{_ai_view}) {
            if ($str eq 'j' || $str eq 'Down') {
                $self->{_ai_scroll}++ if $self->{_ai_scroll} < scalar @{$self->{_ai_lines}} - 1;
                $self->_render_ai();
                return;
            }
            if ($str eq 'k' || $str eq 'Up') {
                $self->{_ai_scroll}-- if $self->{_ai_scroll} > 0;
                $self->_render_ai();
                return;
            }
            if ($str eq 'q' || $str eq 'Escape') {
                $self->{_ai_view} = 0;
                $self->_render_table();
                return;
            }
            return;
        }

        if ($self->{_confirm_action}) {
            $self->_handle_confirm($str);
            return;
        }

        if ($self->{_search_active}) {
            if (length($str) == 1 && $str =~ /[[:print:]]/) {
                $self->{_search_query} .= $str;
                $self->_apply_search();
                $self->_render_search();
                $self->_render_table();
                return;
            }
            if ($str eq 'Backspace') {
                $self->{_search_query} =~ s/.$//;
                $self->_apply_search();
                $self->_render_search();
                $self->_render_table();
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

    # Use filtered resources when search is active
    my $resources = $self->{_search_active} 
        ? $self->{_filtered_resources} 
        : $self->{_resources};

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

    my $search = $self->{_search_regex} ? do { require pk9s::Search; pk9s::Search->new() } : undef;

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
            $val = $search->highlight($val, $self->{_search_regex}) if $search;
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
        '  /          Search',
        '  e          Edit resource',
        '  d          Delete resource',
        '  f          Port-forward',
        '  F          List port-forwards',
        '  R          Rollout restart',
        '  l          View logs (last 100)',
        '  L          Full logs + describe',
        '  m          Metrics (requests/limits)',
        '  a          AI analyze resource',
        '  A          AI analyze cluster',
        '  p          List plugins',
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
    $self->{_search_active} = 0;
    $self->{_search_query} = '';
    $self->{_search_regex} = undef;
    $self->{_filtered_resources} = [];
}

sub _clamp_selection {
    my ($self) = @_;
    my $list = $self->{_search_active} ? $self->{_filtered_resources} : $self->{_resources};
    my $max = scalar @$list - 1;
    $self->{_selected_row} = 0 if $self->{_selected_row} < 0 || $max < 0;
    $self->{_selected_row} = $max if $max >= 0 && $self->{_selected_row} > $max;
}

sub _apply_search {
    my ($self) = @_;
    
    require pk9s::Search;
    my $search = pk9s::Search->new();
    
    my ($term, $scope) = $search->parse_query($self->{_search_query});
    
    if (length($term) == 0) {
        $self->{_search_regex} = undef;
        $self->{_filtered_resources} = $self->{_resources};
        return;
    }
    
    $self->{_search_regex} = $search->build_regex($term);
    
    if ($scope eq 'all') {
        my $found = 0;
        for my $i (0..$#VIEWS) {
            my $view = $VIEWS[$i];
            my $method = $view->{method};
            my $data = $self->{kubectl}->$method(
                namespace => $self->{config}->get('namespace'),
            );
            next if $data->{error};
            
            my $type = $view->{name};
            $type =~ s/s$//;
            
            my @resources = map {
                pk9s::Resource->normalize($_, $type)
            } @{$data->{items} // []};
            
            my @filtered = $search->filter(
                resources => \@resources,
                regex => $self->{_search_regex},
                extract => $view->{extract},
            );
            
            if (@filtered) {
                $self->{_current_view} = $i;
                $self->{_filtered_resources} = \@filtered;
                $self->{_resources} = \@resources;
                $found = 1;
                last;
            }
        }
        
        $self->{_filtered_resources} = [] unless $found;
    } else {
        my $view = $VIEWS[$self->{_current_view}];
        $self->{_filtered_resources} = [
            $search->filter(
                resources => $self->{_resources},
                regex => $self->{_search_regex},
                extract => $view->{extract},
            )
        ];
    }
    
    $self->{_selected_row} = 0;
    $self->_clamp_selection();
}

sub _edit_resource {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    my $type = $view->{name};
    $type =~ s/s$//;
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    require pk9s::Ops;
    my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
    my $result = $ops->edit_resource($type, $res->name, $self->{config}->get('namespace'));

    if ($result->{success}) {
        $self->_refresh_data();
    } elsif ($result->{error}) {
        $self->{_confirm_action} = { type => 'error', message => $result->{error} };
        $self->_render_confirm();
    }
}

sub _delete_resource {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    my $type = $view->{name};
    $type =~ s/s$//;
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    $self->{_confirm_action} = {
        type => 'delete',
        resource_type => $type,
        resource_name => $res->name,
        namespace => $self->{config}->get('namespace'),
    };
    $self->_render_confirm();
}

sub _rollout_restart {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    my $type = $view->{name};
    $type =~ s/s$//;
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    $self->{_confirm_action} = {
        type => 'restart',
        resource_type => $type,
        resource_name => $res->name,
        namespace => $self->{config}->get('namespace'),
    };
    $self->_render_confirm();
}

sub _view_logs {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    return unless $view->{name} eq 'pods';
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    my $result = $self->{kubectl}->get_logs(
        name => $res->name,
        namespace => $self->{config}->get('namespace'),
        tail => 100,
    );

    if ($result->{logs}) {
        $self->{_log_view} = 1;
        $self->{_log_lines} = [split(/\n/, $result->{logs})];
        $self->{_log_scroll} = 0;
        $self->_render_logs();
    }
}

sub _view_logs_full {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    return unless $view->{name} eq 'pods';
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    my @lines;
    push @lines, "=== Logs: " . $res->name . " ===";
    push @lines, "Namespace: " . ($self->{config}->get('namespace') // 'default');
    push @lines, "Status: " . $res->status;
    push @lines, "";

    my $result = $self->{kubectl}->get_logs(
        name => $res->name,
        namespace => $self->{config}->get('namespace'),
        tail => 200,
    );

    if ($result->{logs}) {
        my @log_lines = split(/\n/, $result->{logs});
        push @lines, @log_lines;
    } else {
        push @lines, "(no logs available)";
    }

    push @lines, "";
    push @lines, "=== Describe ===";
    push @lines, "";

    my $desc = $self->{kubectl}->get_describe(
        resource => 'pod',
        name => $res->name,
        namespace => $self->{config}->get('namespace'),
    );

    if ($desc->{output}) {
        push @lines, split(/\n/, $desc->{output});
    }

    $self->{_log_view} = 1;
    $self->{_log_lines} = \@lines;
    $self->{_log_scroll} = 0;
    $self->_render_logs();
}

sub _view_metrics {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    return unless $view->{name} eq 'pods';
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    my @lines;
    push @lines, "=== Resource Requests/Limits: " . $res->name . " ===";
    push @lines, "";

    my $raw = $res->raw;
    if ($raw && $raw->{spec} && $raw->{spec}{containers}) {
        for my $c (@{$raw->{spec}{containers}}) {
            push @lines, "Container: " . ($c->{name} // 'unknown');
            my $req = $c->{resources}{requests};
            my $lim = $c->{resources}{limits};

            if ($req) {
                push @lines, "  Requests: CPU=" . ($req->{cpu} // '-') . "  MEM=" . ($req->{memory} // '-');
            }
            if ($lim) {
                push @lines, "  Limits:   CPU=" . ($lim->{cpu} // '-') . "  MEM=" . ($lim->{memory} // '-');
            }
            push @lines, "" if $req || $lim;
        }
    } else {
        push @lines, "(no resource info in spec)";
    }

    push @lines, "";
    push @lines, "=== Live Metrics (top pods) ===";
    push @lines, "";

    my $top = $self->{kubectl}->get_top_pods(
        namespace => $self->{config}->get('namespace'),
    );

    if ($top->{output}) {
        my @top_lines = split(/\n/, $top->{output});
        for my $line (@top_lines) {
            push @lines, $line if $line =~ /$res->name/;
        }
        if (!grep { /$res->name/ } @top_lines) {
            push @lines, "(pod not found in metrics)";
        }
    } else {
        push @lines, "(metrics-server not available)";
    }

    $self->{_metrics_view} = 1;
    $self->{_metrics_lines} = \@lines;
    $self->{_metrics_scroll} = 0;
    $self->_render_metrics();
}

sub _port_forward {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    my $view = $VIEWS[$self->{_current_view}];
    my $type = $view->{name};
    $type =~ s/s$//;
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    require pk9s::Ops;
    my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
    my $result = $ops->port_forward($type, $res->name, $self->{config}->get('namespace'), '8080:80');

    if ($result->{pid}) {
        $self->{_portforwards}{$result->{pid}} = {
            cmd => "$type/" . $res->name,
            port => $result->{ports},
            start_time => time(),
        };
    }
}

sub _list_portforwards {
    my ($self) = @_;
    my @pids = keys %{$self->{_portforwards}};
    if (!@pids) {
        $self->{_confirm_action} = { type => 'info', message => 'No active port-forwards' };
        $self->_render_confirm();
        return;
    }
    my $msg = "Active port-forwards:\n";
    for my $pid (@pids) {
        my $pf = $self->{_portforwards}{$pid};
        $msg .= "  PID $pid: $pf->{cmd} :$pf->{port}\n";
    }
    $msg .= "\nPress 'k' to kill all, any other key to close";
    $self->{_confirm_action} = { type => 'portforwards', message => $msg };
    $self->_render_confirm();
}

sub _render_confirm {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    return unless $self->{_confirm_action};

    my $action = $self->{_confirm_action};
    my $msg = $action->{message} // '';

    if ($action->{type} eq 'delete') {
        $msg = "Delete $action->{resource_type} $action->{resource_name}? (y/N)";
    } elsif ($action->{type} eq 'restart') {
        $msg = "Restart rollout for $action->{resource_type} $action->{resource_name}? (y/N)";
    }

    my $line = $win->lines - 1;
    $win->printAt($line, 0, sprintf("%-*s", $win->cols, $msg), 0);
}

sub _handle_confirm {
    my ($self, $key) = @_;
    return unless $self->{_confirm_action};

    my $action = $self->{_confirm_action};

    if ($action->{type} eq 'delete' && $key eq 'y') {
        require pk9s::Ops;
        my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
        $ops->delete_resource($action->{resource_type}, $action->{resource_name}, $action->{namespace});
        $self->{_confirm_action} = undef;
        $self->_refresh_data();
        return;
    }

    if ($action->{type} eq 'restart' && $key eq 'y') {
        require pk9s::Ops;
        my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
        $ops->rollout_restart($action->{resource_type}, $action->{resource_name}, $action->{namespace});
        $self->{_confirm_action} = undef;
        $self->_refresh_data();
        return;
    }

    if ($action->{type} eq 'portforwards' && $key eq 'k') {
        require pk9s::Ops;
        my $ops = pk9s::Ops->new(kubectl => $self->{kubectl});
        for my $pid (keys %{$self->{_portforwards}}) {
            $ops->kill_portforward($pid);
            delete $self->{_portforwards}{$pid};
        }
    }

    $self->{_confirm_action} = undef;
    $self->_render_table();
}

sub _render_logs {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    return unless $self->{_log_view};

    for my $i (0..$win->lines - 1) {
        $win->eraseAt($i, 0, $win->cols);
    }

    my $max_lines = $win->lines - 2;
    my $start = $self->{_log_scroll};
    my $end = $start + $max_lines;
    $end = scalar @{$self->{_log_lines}} - 1 if $end >= scalar @{$self->{_log_lines}};

    my $row = 0;
    for my $i ($start..$end) {
        my $line = $self->{_log_lines}[$i] // '';
        $win->printAt($row, 0, substr($line, 0, $win->cols), 0);
        $row++;
    }

    my $footer = sprintf("j/k: scroll  g/G: top/bottom  q/Escape: close  [%d-%d/%d]",
        $start + 1, $end + 1, scalar @{$self->{_log_lines}});
    $win->printAt($win->lines - 1, 0, $footer, 0);
}

sub _render_metrics {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    return unless $self->{_metrics_view};

    for my $i (0..$win->lines - 1) {
        $win->eraseAt($i, 0, $win->cols);
    }

    my $max_lines = $win->lines - 2;
    my $start = $self->{_metrics_scroll};
    my $end = $start + $max_lines;
    $end = scalar @{$self->{_metrics_lines}} - 1 if $end >= scalar @{$self->{_metrics_lines}};

    my $row = 0;
    for my $i ($start..$end) {
        my $line = $self->{_metrics_lines}[$i] // '';
        $win->printAt($row, 0, substr($line, 0, $win->cols), 0);
        $row++;
    }

    my $footer = sprintf("j/k: scroll  q/Escape: close  [%d-%d/%d]",
        $start + 1, $end + 1, scalar @{$self->{_metrics_lines}});
    $win->printAt($win->lines - 1, 0, $footer, 0);
}

sub _analyze_resource {
    my ($self) = @_;
    return unless $self->{_resources} && @{$self->{_resources}};
    return unless $self->{_ai};

    my $view = $VIEWS[$self->{_current_view}];
    my $type = $view->{name};
    $type =~ s/s$//;
    my $res = $self->{_resources}[$self->{_selected_row}];
    return unless $res;

    my $result = $self->{_ai}->analyze_resource($type, $res->name, $self->{config}->get('namespace'));

    if ($result->{response}) {
        $self->{_ai_view} = 1;
        $self->{_ai_lines} = [split(/\n/, $result->{response})];
        $self->{_ai_scroll} = 0;
        $self->_render_ai();
    } elsif ($result->{error}) {
        $self->{_ai_view} = 1;
        $self->{_ai_lines} = ["Error: $result->{error}", "", "Make sure Ollama is running:", "  ollama serve", "  ollama pull qwen2.5:7b"];
        $self->{_ai_scroll} = 0;
        $self->_render_ai();
    }
}

sub _analyze_cluster {
    my ($self) = @_;
    return unless $self->{_ai};

    my $result = $self->{_ai}->analyze_cluster();

    if ($result->{response}) {
        $self->{_ai_view} = 1;
        $self->{_ai_lines} = [split(/\n/, $result->{response})];
        $self->{_ai_scroll} = 0;
        $self->_render_ai();
    } elsif ($result->{error}) {
        $self->{_ai_view} = 1;
        $self->{_ai_lines} = ["Error: $result->{error}", "", "Make sure Ollama is running:", "  ollama serve", "  ollama pull qwen2.5:7b"];
        $self->{_ai_scroll} = 0;
        $self->_render_ai();
    }
}

sub _render_ai {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    return unless $self->{_ai_view};

    for my $i (0..$win->lines - 1) {
        $win->eraseAt($i, 0, $win->cols);
    }

    my $max_lines = $win->lines - 2;
    my $start = $self->{_ai_scroll};
    my $end = $start + $max_lines;
    $end = scalar @{$self->{_ai_lines}} - 1 if $end >= scalar @{$self->{_ai_lines}};

    my $row = 0;
    for my $i ($start..$end) {
        my $line = $self->{_ai_lines}[$i] // '';
        $win->printAt($row, 0, substr($line, 0, $win->cols), 0);
        $row++;
    }

    my $footer = sprintf("j/k: scroll  q/Escape: close  [%d-%d/%d]",
        $start + 1, $end + 1, scalar @{$self->{_ai_lines}});
    $win->printAt($win->lines - 1, 0, $footer, 0);
}

sub _list_plugins {
    my ($self) = @_;
    return unless $self->{_plugins};

    my @plugins = $self->{_plugins}->get_plugins();

    if (!@plugins) {
        $self->{_ai_view} = 1;
        $self->{_ai_lines} = [
            "No plugins loaded.",
            "",
            "To install plugins, create JSON files in:",
            "  ~/.pk9s/plugins/",
            "",
            "Example plugin format:",
            '{',
            '  "name": "fluxcd",',
            '  "version": "1.0.0",',
            '  "resources": [...],',
            '  "actions": {...}',
            '}',
        ];
        $self->{_ai_scroll} = 0;
        $self->_render_ai();
        return;
    }

    my @lines = ("Loaded Plugins:", "");
    for my $plugin (@plugins) {
        push @lines, "  $plugin->{name} v$plugin->{version}";
        push @lines, "    $plugin->{description}" if $plugin->{description};
        push @lines, "";
    }

    $self->{_ai_view} = 1;
    $self->{_ai_lines} = \@lines;
    $self->{_ai_scroll} = 0;
    $self->_render_ai();
}

sub colorize_status {
    my ($status) = @_;
    my $color = $STATUS_COLORS{$status} || 'white';
    return colored($status, $color);
}

sub views { return @VIEWS }

1;
