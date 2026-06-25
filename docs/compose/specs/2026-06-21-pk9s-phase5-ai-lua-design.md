# pk9s Phase 5: AI Integration & Lua Plugins — Design Spec

## [S1] Goal

Add AI-assisted diagnostics and community plugin system to pk9s. Users can get instant LLM analysis of cluster issues and extend pk9s with Lua plugins for custom CRDs and actions.

## [S2] Components

### [S2.1] SQLite Context Store

**Purpose:** Store session history, commands, and cluster events for AI context.

**Schema:**
```sql
CREATE TABLE context (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    type TEXT NOT NULL,  -- 'command', 'event', 'error', 'resource'
    namespace TEXT,
    resource_type TEXT,
    resource_name TEXT,
    data TEXT NOT NULL,
    session_id TEXT
);

CREATE TABLE commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    command TEXT NOT NULL,
    stdout TEXT,
    stderr TEXT,
    exit_code INTEGER,
    duration_ms INTEGER
);
```

**Storage:** `~/.pk9s/context.db`

**Operations:**
- `log_command($cmd, $stdout, $stderr, $exit_code, $duration)` — store command execution
- `log_event($type, $namespace, $resource, $data)` — store cluster event
- `get_context($resource, $limit)` — retrieve recent context for AI
- `clear_old($days)` — cleanup old entries

### [S2.2] AI Sidecar

**Purpose:** Send context to local LLM for diagnostics.

**Flow:**
1. User presses `a` on selected resource (or `A` for global analysis)
2. Gather context:
   - Recent logs via `kubectl logs`
   - Resource events via `kubectl describe`
   - Related resources (pods for deployment, etc.)
   - Recent commands from SQLite
3. Build prompt with context
4. Send to Ollama API: `http://localhost:11434/api/generate`
5. Display response in overlay

**API Integration:**
```perl
sub analyze_resource {
    my ($self, $type, $name, $namespace) = @_;
    
    # Gather context
    my $logs = $self->get_logs($name, $namespace, tail => 50);
    my $events = $self->get_events($type, $name, $namespace);
    my $describe = $self->describe_resource($type, $name, $namespace);
    
    # Build prompt
    my $prompt = build_diagnostic_prompt(
        type => $type,
        name => $name,
        logs => $logs,
        events => $events,
        describe => $describe,
    );
    
    # Call Ollama
    my $response = call_ollama(
        model => 'qwen2.5:7b',
        prompt => $prompt,
    );
    
    return $response;
}
```

**Keybindings:**
- `a` — Analyze selected resource
- `A` — Analyze cluster health (global)

### [S2.3] Lua Plugin System

**Purpose:** Allow community extensions without modifying Perl core.

**Plugin Directory:** `~/.pk9s/plugins/`

**Plugin Interface:**
```lua
-- ~/.pk9s/plugins/fluxcd.lua
return {
    name = "fluxcd",
    version = "1.0.0",
    description = "FluxCD integration for pk9s",
    
    resources = {
        {
            api = "kustomization.toolkit.fluxcd.io",
            columns = {"Name", "Ready", "Age", "Status", "Message"},
            extract = function(item)
                return {
                    item.metadata.name,
                    item.status.conditions[1].status,
                    item.metadata.creationTimestamp,
                    item.status.conditions[1].reason,
                    item.status.conditions[1].message,
                }
            end,
        },
        {
            api = "helmrelease.helm.toolkit.fluxcd.io",
            columns = {"Name", "Ready", "Age", "Status"},
            extract = function(item)
                return {
                    item.metadata.name,
                    item.status.conditions[1].status,
                    item.metadata.creationTimestamp,
                    item.status.conditions[1].reason,
                }
            end,
        },
    },
    
    actions = {
        r = {
            label = "Reconcile",
            cmd = "flux reconcile kustomization %s -n %s",
            confirm = true,
        },
        s = {
            label = "Suspend",
            cmd = "flux suspend kustomization %s -n %s",
            confirm = true,
        },
        u = {
            label = "Resume",
            cmd = "flux resume kustomization %s -n %s",
            confirm = true,
        },
    },
    
    keybindings = {
        ["R"] = "r",  -- Capital R for reconcile
    },
}
```

**Plugin Loader:**
```perl
package pk9s::Plugin;

sub load_plugins {
    my ($class, $dir) = @_;
    $dir //= "$ENV{HOME}/.pk9s/plugins";
    
    my @plugins;
    for my $file (glob("$dir/*.lua")) {
        my $plugin = eval { load_lua_plugin($file) };
        warn "Failed to load $file: $@" if $@;
        push @plugins, $plugin if $plugin;
    }
    
    return @plugins;
}

sub load_lua_plugin {
    my ($file) = @_;
    # Use Inline::Lua to execute plugin file
    # Return plugin hashref
}
```

## [S3] New Modules

### pk9s::Context (lib/pk9s/Context.pm)
```perl
package pk9s::Context;

sub new {
    my ($class, %args) = @_;
    my $db_path = $args{db_path} // "$ENV{HOME}/.pk9s/context.db";
    # Initialize SQLite connection
}

sub log_command { ... }
sub log_event { ... }
sub get_context { ... }
sub clear_old { ... }
```

### pk9s::AI (lib/pk9s/AI.pm)
```perl
package pk9s::AI;

sub new {
    my ($class, %args) = @_;
    return bless {
        context => $args{context},
        model => $args{model} // 'qwen2.5:7b',
        endpoint => $args{endpoint} // 'http://localhost:11434',
    }, $class;
}

sub analyze_resource { ... }
sub analyze_cluster { ... }
sub build_prompt { ... }
sub call_ollama { ... }
```

### pk9s::Plugin (lib/pk9s/Plugin.pm)
```perl
package pk9s::Plugin;

sub new {
    my ($class, %args) = @_;
    return bless {
        plugins => [],
        lua => undef,  # Inline::Lua instance
    }, $class;
}

sub load_plugins { ... }
sub get_resources { ... }
sub get_actions { ... }
sub execute_action { ... }
```

## [S4] App.pm Changes

### New state fields:
```perl
_context => undef,     # pk9s::Context instance
_ai => undef,          # pk9s::AI instance
_plugins => undef,     # pk9s::Plugin instance
_ai_view => 0,         # boolean
_ai_response => '',    # AI response text
_ai_scroll => 0,       # scroll position
```

### New keybindings:
```perl
'a' => sub { $self->_analyze_resource() },
'A' => sub { $self->_analyze_cluster() },
'p' => sub { $self->_list_plugins() },
```

### New methods:
- `_analyze_resource()` — gather context, call AI, show response
- `_analyze_cluster()` — global analysis
- `_render_ai()` — render AI response overlay
- `_list_plugins()` — show loaded plugins
- `_execute_plugin_action($key)` — execute plugin action

## [S5] Dependencies

### Required:
- `DBI` + `DBD::SQLite` — SQLite database
- `HTTP::Tiny` — HTTP requests to Ollama API
- `JSON::PP` — JSON encoding/decoding

### Optional:
- `Inline::Lua` — Lua plugin execution (can fallback to simple hash-based plugins)

## [S6] Test Plan

### Unit tests:
1. `t/09-context.t` — SQLite context store operations
2. `t/10-ai.t` — AI prompt building, mock Ollama calls
3. `t/11-plugin.t` — Plugin loading, resource extraction

### Integration tests:
4. `t/12-app-ai.t` — AI analysis flow in App.pm

## [S7] Implementation Order

1. Create `pk9s::Context` module with SQLite operations
2. Unit tests for Context.pm
3. Create `pk9s::AI` module with Ollama integration
4. Unit tests for AI.pm
5. Create `pk9s::Plugin` module with basic plugin loading
6. Unit tests for Plugin.pm
7. Add AI state fields to App.pm
8. Implement `_analyze_resource` and `_render_ai`
9. Implement plugin integration in App.pm
10. Integration tests
11. Final verification

## [S8] Fallback Strategy

If `Inline::Lua` is not available:
- Use simple YAML/JSON-based plugin definitions
- Parse plugin files with `YAML::Tiny` or `JSON::PP`
- Limit plugin capabilities to column definitions and shell commands

## [S9] Security Considerations

- Ollama runs locally only (no external API calls)
- Plugin commands run in sandbox (no direct shell access)
- Context database encrypted at rest (optional)
- User must explicitly enable AI features
