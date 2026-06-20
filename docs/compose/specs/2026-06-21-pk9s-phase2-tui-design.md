# pk9s Phase 2: TUI Design Specification

## [S1] Problem

Phase 1 delivered the backend (Kubectl, Resource, Config modules) with a simple printf output. Users need an interactive terminal UI to navigate Kubernetes resources efficiently — with keyboard navigation, status coloring, multiple views, and auto-refresh.

## [S2] Solution overview

Build an interactive TUI using Tickit that provides:
- Formatted resource tables with scrolling
- Keyboard navigation (j/k/arrows)
- Status-based coloring (Running=green, Error=red, etc.)
- View switching between pods, deployments, services, and nodes
- Auto-refresh with configurable interval
- Help overlay showing keyboard shortcuts

## [S3] Architecture

### Core component

```
┌─────────────────────────────────────────────────┐
│                    pk9s                         │
├─────────────┬─────────────┬─────────────────────┤
│  Backend    │    TUI      │   (Phase 3+)        │
│  (Phase 1)  │  (Phase 2)  │                     │
├─────────────┼─────────────┼─────────────────────┤
│ Kubectl.pm  │ App.pm      │                     │
│ Resource.pm │ (Tickit)    │                     │
│ Config.pm   │             │                     │
└─────────────┴─────────────┴─────────────────────┘
         │               │
         ▼               ▼
    K8s API         Terminal
    (kubectl)       (user)
```

### Data flow

1. **App.pm** initializes Tickit runtime and registers event handlers
2. **Keyboard events** trigger navigation, view switching, or refresh
3. **Auto-refresh timer** periodically calls `refresh_data()`
4. **refresh_data()** uses Kubectl module to fetch resources
5. **Resources** are normalized via Resource module
6. **Table renderer** draws resources with status coloring
7. **Help overlay** toggles visibility on `?` keypress

## [S4] App.pm Structure

Single module `pk9s::App` that manages:
- **Tickit runtime** — event loop, screen management
- **View state** — current view (pods/deployments/services/nodes), selected row, scroll offset
- **Keyboard handler** — j/k/arrows for navigation, q for quit, r for refresh, ? for help, Tab for view switching
- **Auto-refresh timer** — configurable interval (default 5s)
- **Table renderer** — draws resource table with status coloring

### Public interface

```perl
my $app = pk9s::App->new(
    config => $config,      # pk9s::Config instance
    kubectl => $kubectl,    # pk9s::Kubectl instance
);
$app->run();  # Enters Tickit event loop
```

### Internal methods

- `_build_ui()` — Create Tickit widgets (root window, table, status bar)
- `_setup_keybindings()` — Register keyboard handlers
- `_setup_timer()` — Configure auto-refresh interval
- `_refresh_data()` — Fetch and normalize resources for current view
- `_render_table()` — Draw resource table with coloring
- `_render_help()` — Draw help overlay
- `_switch_view($direction)` — Switch to next/previous view
- `_clamp_selection()` — Ensure selected row is within bounds

## [S5] Views

| View | Resource Method | Columns |
|------|-----------------|---------|
| Pods | `get_pods()` | NAME, STATUS, READY, AGE |
| Deployments | `get_deployments()` | NAME, READY, UP-TO-DATE, AVAILABLE, AGE |
| Services | `get_services()` | NAME, TYPE, CLUSTER-IP, EXTERNAL-PORT, AGE |
| Nodes | `get_nodes()` | NAME, STATUS, ROLES, AGE, VERSION |

### View data structure

```perl
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
    # ... deployments, services, nodes
);
```

## [S6] Keyboard Controls

| Key | Action |
|-----|--------|
| `j` / `↓` | Move selection down |
| `k` / `↑` | Move selection up |
| `g` / `Home` | Jump to first row |
| `G` / `End` | Jump to last row |
| `Tab` | Switch to next view |
| `Shift+Tab` | Switch to previous view |
| `r` | Manual refresh |
| `?` | Toggle help overlay |
| `q` / `Ctrl+C` | Quit |

## [S7] Status Coloring

| Status | Color | ANSI Code |
|--------|-------|-----------|
| Running | Green | `\e[32m` |
| Pending | Yellow | `\e[33m` |
| Error/Fail | Red | `\e[31m` |
| Succeeded | Blue | `\e[34m` |
| Unknown | White | `\e[0m` |

### Implementation

```perl
use Term::ANSIColor;

my %STATUS_COLORS = (
    Running   => 'green',
    Pending   => 'yellow',
    Error     => 'red',
    Failed    => 'red',
    Succeeded => 'blue',
    Unknown   => 'white',
);

sub colorize_status {
    my ($status) = @_;
    my $color = $STATUS_COLORS{$status} || 'white';
    return colored($status, $color);
}
```

## [S8] Auto-Refresh

- Default interval: 5 seconds
- Configurable via `--refresh-interval N` command-line flag
- Pause auto-refresh when help overlay is open
- Show "Last refreshed: HH:MM:SS" in footer
- Manual refresh (`r` key) resets the timer

### Timer implementation

```perl
use Tickit::Timer;

sub _setup_timer {
    my ($self) = @_;
    $self->{timer} = Tickit::Timer->interval(
        $self->{refresh_interval},
        sub { $self->_refresh_data() },
    );
}
```

## [S9] Screen Layout

```
┌─────────────────────────────────────────────────────────────┐
│ pk9s v0.01 — Pods                            [Auto: 5s]    │
├─────────────────────────────────────────────────────────────┤
│ NAME                          STATUS    READY    AGE       │
│ ─────────────────────────────────────────────────────────── │
│ nginx-abc123-def              Running   1/1      2d        │
│ nginx-xyz789-ghi  ▶          Running   1/1      1d        │
│ redis-pod-12345               Pending   0/1      5m        │
│ ...                                                        │
├─────────────────────────────────────────────────────────────┤
│ j/k: navigate  Tab: switch view  r: refresh  ?: help  q: quit │
└─────────────────────────────────────────────────────────────┘
```

### Help overlay

```
┌─────────────────────────────────────────────────────────────┐
│ pk9s — Help                                                │
├─────────────────────────────────────────────────────────────┤
│ Navigation:                                                │
│   j / ↓      Move down                                     │
│   k / ↑      Move up                                       │
│   g / Home   Jump to top                                   │
│   G / End    Jump to bottom                                │
│                                                            │
│ Views:                                                     │
│   Tab        Next view                                     │
│   Shift+Tab  Previous view                                 │
│                                                            │
│ Actions:                                                   │
│   r          Refresh data                                  │
│   ?          Toggle this help                              │
│   q          Quit                                          │
├─────────────────────────────────────────────────────────────┤
│ Press any key to close                                     │
└─────────────────────────────────────────────────────────────┘
```

## [S10] Dependencies

Add to `cpanfile`:

```perl
requires 'Tickit', '0';
requires 'Term::ANSIColor', '0';
```

Add to `Makefile.PL`:

```perl
PREREQ_PM => {
    'Tickit' => 0,
    'Term::ANSIColor' => 0,
    # ... existing deps
},
```

## [S11] Non-goals

- No mouse support in v1
- No split panes or multi-window layout
- No customizable keybindings
- No plugin integration (Phase 5)

## [S12] Success criteria

- TUI starts and renders resource table within 500ms
- Keyboard navigation is responsive (< 50ms input latency)
- Auto-refresh updates data without flickering
- Status colors are accurate and readable
- Help overlay is clear and complete
- Graceful handling of cluster connection failures
