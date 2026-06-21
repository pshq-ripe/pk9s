# pk9s Phase 3: Scoped Fuzzy Search Design Specification

## [S1] Problem

Phase 2 delivered the TUI with resource tables and keyboard navigation. Users need efficient filtering to find specific resources in large clusters — especially when viewing 100+ pods or deployments.

## [S2] Solution overview

Build a scoped fuzzy search system that provides:
- Search mode activated by `/` key
- Scoped filtering within current view (default)
- Cross-view search with `all:` prefix
- Real-time filtering as user types
- Result highlighting with ANSI bold/underline
- Match counter showing current position

## [S3] Architecture

### Core component

```
┌─────────────────────────────────────────────────┐
│                    pk9s                         │
├─────────────┬─────────────┬─────────────────────┤
│  Backend    │    TUI      │   Search Engine     │
│  (Phase 1)  │  (Phase 2)  │   (Phase 3)         │
├─────────────┼─────────────┼─────────────────────┤
│ Kubectl.pm  │ App.pm      │ Search.pm           │
│ Resource.pm │ (Tickit)    │ (regex engine)      │
│ Config.pm   │             │                     │
└─────────────┴─────────────┴─────────────────────┘
         │               │               │
         ▼               ▼               ▼
    K8s API         Terminal       Local filtering
    (kubectl)       (user)         (in-memory)
```

### Data flow

1. **User presses `/`** — App.pm enters search mode
2. **User types query** — Search.pm parses and builds regex
3. **Search.pm filters** — Returns filtered resource list
4. **App.pm renders** — Draws filtered results with highlighting
5. **User presses Escape/Enter** — Search mode exits, filter persists
6. **User presses `/` again** — Can modify or clear filter

## [S4] Search.pm Module

New module `pk9s::Search` that handles:
- **Query parsing** — extract scope prefix (`all:` or default)
- **Regex building** — convert user input to Perl regex (escape special chars)
- **Resource filtering** — filter resources in-memory
- **Result highlighting** — mark matching characters

### Public interface

```perl
my $search = pk9s::Search->new();

# Parse query and get search term + scope
my ($term, $scope) = $search->parse_query("all:nginx");
# $term = "nginx", $scope = "all"

# Build regex from search term
my $regex = $search->build_regex("plsy");
# $regex = qr/plsy/i

# Filter resources
my @filtered = $search->filter(
    resources => \@resources,
    regex => $regex,
    columns => $view->{columns},
    extract => $view->{extract},
);

# Highlight matching text
my $highlighted = $search->highlight("nginx-deploy", $regex);
# $highlighted = "\e[1mnginx\e[0m-deploy"
```

## [S5] Search Modes

| Mode | Syntax | Behavior |
|------|--------|----------|
| Scoped (default) | `plsy` | Filter resources in current view matching "plsy" |
| Cross-view | `all:plsy` | Search across all views, switch to matching view |

### Query parsing rules

1. If query starts with `all:` — cross-view mode, search term is everything after `:`
2. Otherwise — scoped mode, entire query is search term
3. Empty query — clear filter, show all resources

## [S6] Keyboard Controls

| Key | Action |
|-----|--------|
| `/` | Enter search mode |
| `Escape` | Exit search mode (keep filter) |
| `Enter` | Exit search mode (keep filter) |
| `Backspace` | Delete last character |
| Any printable char | Append to search query |
| `Ctrl+U` | Clear search query |

## [S7] Screen Layout

### Normal mode

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

### Search mode

```
┌─────────────────────────────────────────────────────────────┐
│ pk9s v0.01 — Pods                            [Auto: 5s]    │
├─────────────────────────────────────────────────────────────┤
│ NAME                          STATUS    READY    AGE       │
│ ─────────────────────────────────────────────────────────── │
│ nginx-abc123-def              Running   1/1      2d        │
│ nginx-xyz789-ghi  ▶          Running   1/1      1d        │
│ ...                                                        │
├─────────────────────────────────────────────────────────────┤
│ / plsy                                               [2/12] │
└─────────────────────────────────────────────────────────────┘
```

## [S8] Implementation Details

### Query parsing

```perl
sub parse_query {
    my ($self, $query) = @_;
    
    if ($query =~ /^all:(.*)$/) {
        return ($1, 'all');
    }
    
    return ($query, 'current');
}
```

### Regex building

```perl
sub build_regex {
    my ($self, $term) = @_;
    
    # Escape special regex characters
    $term =~ s/([.+*?^$\[\]{}|\\()])/\\$1/g;
    
    # Convert * to .* for glob-style matching
    $term =~ s/\*/.*/g;
    
    # Build case-insensitive regex
    return qr/$term/i;
}
```

### Resource filtering

```perl
sub filter {
    my ($self, %args) = @_;
    my $resources = $args{resources};
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
```

### Result highlighting

```perl
sub highlight {
    my ($self, $text, $regex) = @_;
    
    return $text unless $regex;
    
    # Highlight matching text with ANSI bold
    $text =~ s/($regex)/\e[1m$1\e[0m/g;
    
    return $text;
}
```

## [S9] Integration with App.pm

### State additions

```perl
sub new {
    my ($class, %args) = @_;
    my $self = {
        # ... existing fields ...
        _search_active => 0,
        _search_query => '',
        _search_regex => undef,
        _filtered_resources => [],
    };
    return bless $self, $class;
}
```

### Keyboard handler additions

```perl
# In _setup_keybindings
'/' => sub {
    $self->{_search_active} = 1;
    $self->{_search_query} = '';
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
```

### Search rendering

```perl
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
```

## [S10] Dependencies

Add to `cpanfile`:

```perl
requires 'Regexp::List', '0';  # Optional: for advanced regex operations
```

No new dependencies required — uses core Perl regex engine.

## [S11] Non-goals

- No fuzzy matching (partial/fuzzy) in v1 — exact substring match only
- No search history persistence
- No search result navigation (arrow keys to jump between matches)
- No regex mode (user input is always treated as literal, not regex)

## [S12] Success criteria

- Search activates within 100ms of pressing `/`
- Filtering 500 resources completes in < 50ms
- Search query updates in real-time as user types
- Highlighting is accurate and readable
- Cross-view search correctly switches to matching view
- Filter persists after exiting search mode
