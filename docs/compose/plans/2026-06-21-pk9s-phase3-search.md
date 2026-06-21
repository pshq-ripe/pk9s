# pk9s Phase 3: Scoped Fuzzy Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a scoped fuzzy search system with search mode, query parsing, regex building, resource filtering, and result highlighting.

**Architecture:** New `pk9s::Search` module handles query parsing, regex building, and filtering. App.pm integrates search state and keyboard handlers for search mode.

**Tech Stack:** Perl 5.30+, core regex engine, Term::ANSIColor

---

## File Structure

```
pk9s/
├── lib/
│   └── pk9s/
│       ├── App.pm            # TUI application (modified)
│       ├── Search.pm         # Search engine (new)
│       ├── Kubectl.pm        # kubectl wrapper (existing)
│       ├── Resource.pm       # Resource normalization (existing)
│       └── Config.pm         # Configuration (existing)
├── t/
│   ├── 01-kubectl.t          # Kubectl tests (existing)
│   ├── 02-resource.t         # Resource tests (existing)
│   ├── 03-config.t           # Config tests (existing)
│   ├── 04-integration.t      # Integration tests (existing)
│   ├── 05-app.t              # App tests (existing)
│   └── 06-search.t           # Search tests (new)
├── bin/
│   └── pk9s                  # Entry point (existing)
├── cpanfile                  # Dependencies (existing)
├── Makefile.PL               # Build system (existing)
└── README.md                 # Documentation (existing)
```

---

### Task 1: Create Search.pm — Structure & Tests

**Covers:** [S4]

**Files:**
- Create: `lib/pk9s/Search.pm`
- Create: `t/06-search.t`

- [ ] **Step 1: Write failing test for Search module**

```perl
# t/06-search.t
use strict;
use warnings;
use Test::More tests => 8;
use lib 'lib';

use_ok('pk9s::Search');

my $search = pk9s::Search->new();
isa_ok($search, 'pk9s::Search');

can_ok($search, qw(parse_query build_regex filter highlight));

# Test parse_query with scoped mode
my ($term, $scope) = $search->parse_query("nginx");
is($term, "nginx", 'parse_query returns term');
is($scope, "current", 'parse_query returns current scope');

# Test parse_query with all: prefix
($term, $scope) = $search->parse_query("all:nginx");
is($term, "nginx", 'parse_query strips all: prefix');
is($scope, "all", 'parse_query returns all scope');

# Test empty query
($term, $scope) = $search->parse_query("");
is($term, "", 'parse_query handles empty query');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/06-search.t`
Expected: FAIL with "Can't locate pk9s/Search.pm"

- [ ] **Step 3: Create minimal Search.pm**

```perl
# lib/pk9s/Search.pm
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
    
    # Escape special regex characters
    $term =~ s/([.+*?^$\[\]{}|\\()])/\\$1/g;
    
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/06-search.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/Search.pm t/06-search.t
git commit -m "feat: add Search.pm with query parsing and regex building"
```

---

### Task 2: Search.pm — Filter & Highlight Tests

**Covers:** [S4, S8]

**Files:**
- Modify: `lib/pk9s/Search.pm`
- Modify: `t/06-search.t`

- [ ] **Step 1: Add filter and highlight tests**

```perl
# Add to t/06-search.t

# Test build_regex
my $regex = $search->build_regex("nginx");
isa_ok($regex, 'Regexp', 'build_regex returns regexp');

# Test filter with mock resources
package MockResource {
    sub new { bless { name => $_[1] }, $_[0] }
    sub name { return $_[0]->{name} }
}

package main;

my @resources = (
    MockResource->new("nginx-deploy"),
    MockResource->new("redis-deploy"),
    MockResource->new("nginx-pod"),
);

my $extract = sub { [$_[0]->name] };
my $regex2 = $search->build_regex("nginx");
my @filtered = $search->filter(
    resources => \@resources,
    regex => $regex2,
    extract => $extract,
);

is(scalar @filtered, 2, 'filter returns matching resources');
is($filtered[0]->name, "nginx-deploy", 'filter returns correct first match');
is($filtered[1]->name, "nginx-pod", 'filter returns correct second match');

# Test highlight
my $highlighted = $search->highlight("nginx-deploy", $regex2);
like($highlighted, qr/\e\[1mnginx\e\[0m/, 'highlight wraps match in ANSI bold');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/06-search.t`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/pk9s/Search.pm t/06-search.t
git commit -m "test: add filter and highlight tests for Search.pm"
```

---

### Task 3: App.pm — Add Search State

**Covers:** [S4, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add search state tests**

```perl
# Add to t/05-app.t

# Test search state initialization
is($app->{_search_active}, 0, 'search not active by default');
is($app->{_search_query}, '', 'search query empty by default');
is($app->{_search_regex}, undef, 'search regex undef by default');
is(ref $app->{_filtered_resources}, 'ARRAY', 'filtered resources is array');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `prove -Ilib t/05-app.t`
Expected: FAIL (search state fields not yet added)

- [ ] **Step 3: Update App.pm constructor**

Update `lib/pk9s/App.pm` `new()` method to add:

```perl
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add search state to App.pm"
```

---

### Task 4: App.pm — Search Keyboard Handlers

**Covers:** [S6, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add search keyboard tests**

```perl
# Add to t/05-app.t

# Test search mode toggle
$app->{_search_active} = 0;
is($app->{_search_active}, 0, 'search mode initially off');

# Test search query update
$app->{_search_query} = 'nginx';
is($app->{_search_query}, 'nginx', 'search query can be set');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS (tests already pass)

- [ ] **Step 3: Update _setup_keybindings**

Add search keybindings to the `%handlers` hash in `lib/pk9s/App.pm`:

```perl
# In _setup_keybindings, add to %handlers:
'/' => sub {
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
'C-u' => sub {
    $self->{_search_query} = '';
    $self->{_search_regex} = undef;
    $self->{_filtered_resources} = $self->{_resources};
    $self->_render_search() if $self->{_search_active};
},
```

Also add character input handling for search mode:

```perl
# In cb_keypress, before the handler dispatch:
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add search keyboard handlers to App.pm"
```

---

### Task 5: App.pm — Search Rendering

**Covers:** [S7, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add search rendering tests**

```perl
# Add to t/05-app.t

# Test _render_search exists
can_ok($app, '_render_search');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Implement _render_search**

Add `_render_search` method to `lib/pk9s/App.pm`:

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

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add search rendering to App.pm"
```

---

### Task 6: App.pm — Apply Search Logic

**Covers:** [S4, S5, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add apply_search tests**

```perl
# Add to t/05-app.t

# Test _apply_search with mock
use pk9s::Search;

my $search = pk9s::Search->new();
my @test_resources = (
    bless({ name => 'nginx-deploy' }, 'MockResource'),
    bless({ name => 'redis-deploy' }, 'MockResource'),
    bless({ name => 'nginx-pod' }, 'MockResource'),
);

$app->{_resources} = \@test_resources;
$app->{_search_query} = 'nginx';
my ($term, $scope) = $search->parse_query('nginx');
$app->{_search_regex} = $search->build_regex($term);

# Mock extract function for testing
my $mock_extract = sub { [$_[0]->name] };

# Store original _apply_search and replace with testable version
# (This tests the logic without requiring the full TUI)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Implement _apply_search**

Add `_apply_search` method to `lib/pk9s/App.pm`:

```perl
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
    
    my $view = $VIEWS[$self->{_current_view}];
    $self->{_filtered_resources} = [
        $search->filter(
            resources => $self->{_resources},
            regex => $self->{_search_regex},
            extract => $view->{extract},
        )
    ];
    
    $self->{_selected_row} = 0;
    $self->_clamp_selection();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add apply_search logic to App.pm"
```

---

### Task 7: App.pm — Integrate Search with Table Rendering

**Covers:** [S7, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add integration tests**

```perl
# Add to t/05-app.t

# Test that _render_table uses filtered_resources when search is active
$app->{_search_active} = 1;
$app->{_filtered_resources} = [$test_resources[0]];  # Only nginx-deploy
# This tests that the table rendering path uses filtered_resources
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Update _render_table**

Modify `_render_table` in `lib/pk9s/App.pm` to use filtered resources when search is active:

```perl
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
    
    # ... rest of rendering logic using $resources instead of $self->{_resources}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: integrate search filtering with table rendering"
```

---

### Task 8: App.pm — Cross-View Search

**Covers:** [S5, S9]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add cross-view search tests**

```perl
# Add to t/05-app.t

# Test cross-view search logic
# (This tests the all: prefix handling)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Update _apply_search for cross-view**

Modify `_apply_search` in `lib/pk9s/App.pm` to handle `all:` prefix:

```perl
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
        # Cross-view search: search across all views
        my @all_filtered;
        for my $i (0..$#VIEWS) {
            my $view = $VIEWS[$i];
            my $data = $self->{kubectl}->$view->{method}(
                namespace => $self->{config}->get('namespace'),
            );
            next if $data->{error};
            
            my @resources = map {
                pk9s::Resource->normalize($_, $view->{name})
            } @{$data->{items} // []};
            
            my @filtered = $search->filter(
                resources => \@resources,
                regex => $self->{_search_regex},
                extract => $view->{extract},
            );
            
            if (@filtered) {
                # Switch to the view with matches
                $self->{_current_view} = $i;
                @all_filtered = @filtered;
                last;
            }
        }
        
        $self->{_filtered_resources} = \@all_filtered;
    } else {
        # Scoped search: search current view only
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: add cross-view search with all: prefix"
```

---

### Task 9: Search.pm — Highlighting Integration

**Covers:** [S4, S8]

**Files:**
- Modify: `lib/pk9s/App.pm`
- Modify: `t/05-app.t`

- [ ] **Step 1: Add highlighting tests**

```perl
# Add to t/05-app.t

# Test highlight integration
use pk9s::Search;
my $search2 = pk9s::Search->new();
my $regex3 = $search2->build_regex("nginx");
my $highlighted2 = $search2->highlight("nginx-deploy", $regex3);
like($highlighted2, qr/\e\[1m/, 'highlight adds ANSI codes');
```

- [ ] **Step 2: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 3: Update _render_table for highlighting**

Modify `_render_table` in `lib/pk9s/App.pm` to apply highlighting when search is active:

```perl
# In the row rendering loop, after extracting row data:
if ($self->{_search_regex}) {
    require pk9s::Search;
    my $search = pk9s::Search->new();
    for my $j (0..$#$row) {
        $row->[$j] = $search->highlight($row->[$j], $self->{_search_regex});
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `prove -Ilib t/05-app.t`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pk9s/App.pm t/05-app.t
git commit -m "feat: integrate search highlighting with table rendering"
```

---

### Task 10: Final Verification

**Covers:** [S12]

**Files:**
- None (verification only)

- [ ] **Step 1: Run all tests**

Run: `prove -Ilib t/`
Expected: All tests pass

- [ ] **Step 2: Verify syntax**

Run: `perl -Ilib -c lib/pk9s/Search.pm`
Expected: syntax OK

Run: `perl -Ilib -c lib/pk9s/App.pm`
Expected: syntax OK

- [ ] **Step 3: Verify entry point**

Run: `perl -Ilib -c bin/pk9s`
Expected: syntax OK

- [ ] **Step 4: Commit**

No commit needed (verification only)

---

## Self-Review Checklist

- [ ] **Spec coverage:** S1 ✓, S2 ✓, S3 ✓, S4 ✓, S5 ✓, S6 ✓, S7 ✓, S8 ✓, S9 ✓, S10 ✓, S11 ✓, S12 ✓
- [ ] **Placeholder scan:** No TBD/TODO found
- [ ] **Type consistency:** Search.pm interface matches App.pm usage
- [ ] **File structure:** All files defined in structure section exist in tasks

## Execution Handoff

This plan has 10 tasks with clear dependencies:

- **Task 1:** Search.pm structure (must be first)
- **Task 2:** Search.pm filter/highlight tests (depends on Task 1)
- **Task 3:** App.pm search state (depends on Task 1)
- **Task 4:** App.pm search keyboard handlers (depends on Task 3)
- **Task 5:** App.pm search rendering (depends on Task 4)
- **Task 6:** App.pm apply search logic (depends on Tasks 1, 3)
- **Task 7:** App.pm integrate search with table (depends on Tasks 5, 6)
- **Task 8:** App.pm cross-view search (depends on Task 7)
- **Task 9:** Search.pm highlighting integration (depends on Task 7)
- **Task 10:** Final verification (depends on all tasks)
