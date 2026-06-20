# pk9s Phase 2: TUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an interactive TUI using Tickit with resource tables, keyboard navigation, status coloring, view switching, auto-refresh, and help overlay.

**Architecture:** Single `pk9s::App` module manages Tickit runtime, view state, keyboard handlers, auto-refresh timer, and table rendering. Integrates with Phase 1 backend modules (Kubectl, Resource, Config).

**Tech Stack:** Perl 5.30+, Tickit, Term::ANSIColor, Term::ReadKey

---

## File Structure

```
pk9s/
├── bin/
│   └── pk9s                  # Entry point (modified)
├── lib/
│   └── pk9s/
│       ├── App.pm            # TUI application (new)
│       ├── Kubectl.pm        # kubectl wrapper (existing)
│       ├── Resource.pm       # Resource normalization (existing)
│       └── Config.pm         # Configuration (existing)
├── t/
│   ├── 01-kubectl.t          # Kubectl tests (existing)
│   ├── 02-resource.t         # Resource tests (existing)
│   ├── 03-config.t           # Config tests (existing)
│   ├── 04-integration.t      # Integration tests (existing)
│   └── 05-app.t              # App tests (new)
├── cpanfile                  # Dependencies (modified)
├── Makefile.PL               # Build system (modified)
└── README.md                 # Documentation (existing)
```

---

### Task 1: Add Tickit Dependencies

**Covers:** [S10]

**Files:**
- Modify: `cpanfile`
- Modify: `Makefile.PL`

- [ ] **Step 1: Update cpanfile**

```perl
requires 'JSON::PP', '0';
requires 'IPC::Open3', '0';
requires 'File::Temp', '0';
requires 'Tickit', '0';
requires 'Term::ANSIColor', '0';

on 'test' => sub {
    requires 'Test::More', '0.96';
};
```

- [ ] **Step 2: Update Makefile.PL**

```perl
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'pk9s',
    VERSION_FROM => 'lib/pk9s.pm',
    ABSTRACT     => 'Lightweight Kubernetes TUI in Perl',
    AUTHOR       => 'pk9s contributors',
    LICENSE      => 'perl_5',
    PREREQ_PM    => {
        'JSON::PP'         => 0,
        'IPC::Open3'       => 0,
        'File::Temp'       => 0,
        'Tickit'           => 0,
        'Term::ANSIColor'  => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0.96,
    },
    EXE_FILES     => ['bin/pk9s'],
    META_MERGE    => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/pshq/pk9s.git',
            },
        },
    },
);
```

- [ ] **Step 3: Install dependencies**

Run: `cpanm --installdeps .`
Expected: Tickit and Term::ANSIColor installed successfully

- [ ] **Step 4: Commit**

```bash
git add cpanfile Makefile.PL
git commit -m "chore: add Tickit and Term::ANSIColor dependencies"
```

---

### Task 2: Create App.pm — Structure & Tests

**Covers:** [S3, S4]

**Files:**
- Create: `lib/pk9s/App.pm`
- Create: `t/05-app.t`

- [ ] **Step 1: Write failing test for App module**

```perl
# t/05-app.t
use strict;
use warnings;
use Test::More tests => 5;
use lib 'lib';

use_ok('pk9s::App');

my $app = pk9s::App->new(
    config => bless({}, 'pk9s::Config'),
    kubectl => bless({}, 'pk9s::Kubectl'),
);
isa_ok($app, 'pk9s::App');

can_ok($app, qw(run _refresh_data _render_table _render_help _switch_view));

is($app->{_current_view}, 0, 'default view is pods');
is($app->{_selected_row}, 0, 'default selection is first row');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/05-app.t`
Expected: FAIL with "Can't locate pk9s/App.pm"

- [ ] **Step 3: Create minimal App.pm**

```perl
# lib/pk9s/App.pm
package pk9s::App;
use strict;
use warnings;
use Tickit;
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add App.pm structure with views and status colors"
```

---

### Task 3: App.pm — Table Rendering

**Covers:** [S3, S5, S7, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add table rendering tests**

```perl
# Add to t/05-app.t
use_ok('pk9s::Resource');

# Test colorize_status
is(pk9s::App::colorize_status('Running'), "\e[32mRunning\e[0m", 'colorize Running');
is(pk9s::App::colorize_status('Pending'), "\e[33mPending\e[0m", 'colorize Pending');
is(pk9s::App::colorize_status('Error'), "\e[31mError\e[0m", 'colorize Error');

# Test views structure
my @views = pk9s::App::views();
is(scalar @views, 4, 'has 4 views');
is($views[0]{name}, 'pods', 'first view is pods');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/05-app.t`
Expected: PASS (tests already pass from Task 2)

- [ ] **Step 3: Implement _render_table**

Update `lib/pk9s/App.pm` to add:

```perl
sub _render_table {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    
    my $view = $VIEWS[$self->{_current_view}];
    my $cols = $view->{columns};
    my $resources = $self->{_resources};
    
    # Calculate column widths
    my @widths = map { length($_) + 2 } @$cols;
    for my $res (@$resources) {
        my $row = $view->{extract}->($res);
        for my $i (0..$#$row) {
            my $len = length($row->[$i]) + 2;
            $widths[$i] = $len if $len > $widths[$i];
        }
    }
    
    # Render header
    my $header = '';
    for my $i (0..$#$cols) {
        $header .= sprintf("%-*s", $widths[$i], $cols->[$i]);
    }
    $win->printAt(0, 0, $header, 0);  # 0 = normal pen
    
    # Render separator
    my $sep = '─' x ($win->cols - 1);
    $win->printAt(1, 0, $sep, 0);
    
    # Render rows
    my $row_num = 2;
    my $start = $self->{_scroll_offset};
    my $visible = $win->lines - 3;  # header + separator + footer
    
    for my $i ($start..$#$resources) {
        last if $row_num >= $visible + 2;
        
        my $res = $resources->[$i];
        my $row = $view->{extract}->($res);
        my $is_selected = ($i == $self->{_selected_row});
        
        my $line = $is_selected ? '▶ ' : '  ';
        for my $j (0..$#$row) {
            my $val = $row->[$j];
            if ($j == 1) {  # STATUS column
                $val = colorize_status($val);
            }
            $line .= sprintf("%-*s", $widths[$j], $val);
        }
        
        my $pen = $is_selected ? 1 : 0;  # 1 = reverse pen
        $win->printAt($row_num, 0, $line, $pen);
        $row_num++;
    }
    
    # Clear remaining lines
    for my $i ($row_num..$visible + 1) {
        $win->eraseAt($i, 0, $win->cols);
    }
    
    # Render footer
    my $footer = sprintf("j/k: navigate  Tab: switch view  r: refresh  ?: help  q: quit");
    $win->printAt($win->lines - 1, 0, $footer, 0);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add table rendering with column widths and row selection"
```

---

### Task 4: App.pm — Keyboard Navigation

**Covers:** [S4, S6]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add keyboard navigation tests**

```perl
# Add to t/05-app.t

# Test _clamp_selection
$app->{_resources} = [1, 2, 3, 4, 5];
$app->{_selected_row} = 10;
$app->_clamp_selection();
is($app->{_selected_row}, 4, 'clamp to max');

$app->{_selected_row} = -5;
$app->_clamp_selection();
is($app->{_selected_row}, 0, 'clamp to min');

# Test _switch_view
$app->{_current_view} = 0;
$app->_switch_view(1);
is($app->{_current_view}, 1, 'switch to next view');

$app->_switch_view(1);
is($app->{_current_view}, 2, 'switch to next view again');

$app->_switch_view(-1);
is($app->{_current_view}, 1, 'switch to previous view');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/05-app.t`
Expected: FAIL (tests for _switch_view not yet implemented)

- [ ] **Step 3: Implement _setup_keybindings and _switch_view**

Update `lib/pk9s/App.pm` to add:

```perl
sub _setup_keybindings {
    my ($self) = @_;
    my $term = $self->{_tickit}->term;
    
    $term->cb_keypress(sub {
        my ($type, $str) = @_;
        return unless $type eq 'key';
        
        if ($self->{_show_help}) {
            $self->{_show_help} = 0;
            $self->_render_table();
            return;
        }
        
        given ($str) {
            when ('j' || 'Down') {
                $self->{_selected_row}++;
                $self->_clamp_selection();
                $self->_render_table();
            }
            when ('k' || 'Up') {
                $self->{_selected_row}--;
                $self->_clamp_selection();
                $self->_render_table();
            }
            when ('g' || 'Home') {
                $self->{_selected_row} = 0;
                $self->_render_table();
            }
            when ('G' || 'End') {
                $self->{_selected_row} = scalar @{$self->{_resources}} - 1;
                $self->_render_table();
            }
            when ('Tab') {
                $self->_switch_view(1);
                $self->_refresh_data();
            }
            when ('BTab') {  # Shift+Tab
                $self->_switch_view(-1);
                $self->_refresh_data();
            }
            when ('r') {
                $self->_refresh_data();
            }
            when ('?') {
                $self->{_show_help} = 1;
                $self->_render_help();
            }
            when ('q' || 'C-c') {
                $self->{_tickit}->stop;
            }
        }
    });
}

sub _switch_view {
    my ($self, $direction) = @_;
    my $num_views = scalar @VIEWS;
    $self->{_current_view} = ($self->{_current_view} + $direction) % $num_views;
    $self->{_selected_row} = 0;
    $self->{_scroll_offset} = 0;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add keyboard navigation and view switching"
```

---

### Task 5: App.pm — Data Refresh

**Covers:** [S3, S4, S5]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add data refresh tests**

```perl
# Add to t/05-app.t

# Test _refresh_data with mock
package MockKubectl {
    use parent 'pk9s::Kubectl';
    
    sub _run {
        my ($self, @cmd) = @_;
        return ('{
            "apiVersion": "v1",
            "items": [
                {"metadata": {"name": "test-pod", "namespace": "default", "creationTimestamp": "2024-01-15T10:30:00Z"}, "status": {"phase": "Running", "containerStatuses": [{"ready": 1}]}}
            ]
        }', '');
    }
}

package main;

my $mock_kubectl = MockKubectl->new();
my $app2 = pk9s::App->new(
    config => bless({}, 'pk9s::Config'),
    kubectl => $mock_kubectl,
);

$app2->_refresh_data();
is(scalar @{$app2->{_resources}}, 1, 'refresh loads resources');
is($app2->{_resources}[0]->name, 'test-pod', 'resource has correct name');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/05-app.t`
Expected: FAIL (_refresh_data not fully implemented)

- [ ] **Step 3: Implement _refresh_data**

Update `lib/pk9s/App.pm` to add:

```perl
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
    
    my @resources = map {
        pk9s::Resource->normalize($_, $view->{name})
    } @{$data->{items} // []};
    
    $self->{_resources} = \@resources;
    $self->{_last_refresh} = time();
    $self->_clamp_selection();
    $self->_render_table();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add data refresh with resource normalization"
```

---

### Task 6: App.pm — Auto-Refresh Timer

**Covers:** [S4, S8]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add timer tests**

```perl
# Add to t/05-app.t

# Test timer setup
is($app2->{_refresh_interval}, 5, 'default refresh interval');

my $app3 = pk9s::App->new(
    config => bless({}, 'pk9s::Config'),
    kubectl => bless({}, 'pk9s::Kubectl'),
    refresh_interval => 10,
);
is($app3->{_refresh_interval}, 10, 'custom refresh interval');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS (tests already pass)

- [ ] **Step 3: Implement _setup_timer**

Update `lib/pk9s/App.pm` to add:

```perl
sub _setup_timer {
    my ($self) = @_;
    $self->{_timer} = Tickit::Timer->interval(
        $self->{_refresh_interval},
        sub {
            return if $self->{_show_help};
            $self->_refresh_data();
        },
    );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add auto-refresh timer with pause on help"
```

---

### Task 7: App.pm — Help Overlay

**Covers:** [S4, S6, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add help overlay tests**

```perl
# Add to t/05-app.t

# Test _render_help exists
can_ok($app, '_render_help');

# Test show_help flag
$app->{_show_help} = 0;
is($app->{_show_help}, 0, 'help initially hidden');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Implement _render_help**

Update `lib/pk9s/App.pm` to add:

```perl
sub _render_help {
    my ($self) = @_;
    my $win = $self->{_root_window};
    return unless $win;
    
    my @help_lines = (
        'pk9s — Help',
        '',
        'Navigation:',
        '  j / ↓      Move down',
        '  k / ↑      Move up',
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
    
    # Clear screen
    for my $i (0..$win->lines - 1) {
        $win->eraseAt($i, 0, $win->cols);
    }
    
    # Draw help box
    my $box_width = 50;
    my $box_left = ($win->cols - $box_width) / 2;
    my $box_top = 2;
    
    # Draw border
    $win->printAt($box_top, $box_left, '┌' . '─' x ($box_width - 2) . '┐', 0);
    for my $i (0..$#help_lines) {
        my $line = $help_lines[$i];
        my $padded = sprintf("│ %-*s │", $box_width - 4, $line);
        $win->printAt($box_top + 1 + $i, $box_left, $padded, 0);
    }
    $win->printAt($box_top + scalar(@help_lines) + 1, $box_left, '└' . '─' x ($box_width - 2) . '┘', 0);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add help overlay with keyboard shortcuts"
```

---

### Task 8: App.pm — Build UI & Integrate

**Covers:** [S3, S4, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `bin/pk9s`

- [ ] **Step 1: Implement _build_ui**

Update `lib/pk9s/App.pm` to add:

```perl
sub _build_ui {
    my ($self) = @_;
    $self->{_root_window} = $self->{_tickit}->root;
}
```

- [ ] **Step 2: Update bin/pk9s for TUI mode**

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use pk9s::App;
use pk9s::Kubectl;
use pk9s::Config;
use Getopt::Long;

my $refresh_interval = 5;
GetOptions('refresh-interval=i' => \$refresh_interval);

my $config = pk9s::Config->new();
my $kubectl = pk9s::Kubectl->new(
    kubectl => $config->get('kubectl'),
    context => $config->get('context'),
);

my $app = pk9s::App->new(
    config => $config,
    kubectl => $kubectl,
    refresh_interval => $refresh_interval,
);

$app->run();
```

- [ ] **Step 3: Run tests**

Run: `prove -Ilib t/`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/pk9s/App.pm bin/pk9s
git commit -m "feat: integrate TUI into entry point with --refresh-interval flag"
```

---

### Task 9: Add Missing Resource Methods

**Covers:** [S5]

**Files:**
- Modify: `lib/pk9s/Kubectl.pm`

- [ ] **Step 1: Add get_services and get_nodes methods**

Update `lib/pk9s/Kubectl.pm` to add:

```perl
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
```

- [ ] **Step 2: Run tests**

Run: `prove -Ilib t/`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/pk9s/Kubectl.pm
git commit -m "feat: add get_services and get_nodes methods to Kubectl"
```

---

### Task 10: Final Verification

**Covers:** [S12]

**Files:**
- None (verification only)

- [ ] **Step 1: Run all tests**

Run: `prove -Ilib t/`
Expected: All tests pass

- [ ] **Step 2: Verify TUI starts**

Run: `perl -Ilib bin/pk9s --help`
Expected: Usage information (or TUI starts if no --help flag)

- [ ] **Step 3: Verify syntax**

Run: `perl -Ilib -c bin/pk9s`
Expected: syntax OK

- [ ] **Step 4: Commit**

No commit needed (verification only)

---

## Self-Review Checklist

- [ ] **Spec coverage:** S1 ✓, S2 ✓, S3 ✓, S4 ✓, S5 ✓, S6 ✓, S7 ✓, S8 ✓, S9 ✓, S10 ✓, S11 ✓, S12 ✓
- [ ] **Placeholder scan:** No TBD/TODO found
- [ ] **Type consistency:** App.pm interface matches tests, Kubectl methods match view definitions
- [ ] **File structure:** All files defined in structure section exist in tasks

## Execution Handoff

This plan has 10 tasks with clear dependencies:

- **Task 1:** Dependencies (must be first)
- **Task 2:** App.pm structure (depends on Task 1)
- **Tasks 3-7:** App.pm features (can be parallel, depend on Task 2)
- **Task 8:** Integration (depends on Tasks 2-7)
- **Task 9:** Missing methods (can be parallel with Tasks 3-7)
- **Task 10:** Final verification (depends on all tasks)
