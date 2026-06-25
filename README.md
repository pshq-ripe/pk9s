# pk9s

**Lightweight Kubernetes TUI written in Perl** — an alternative to [K9s](https://github.com/derailed/k9s) for sysadmins who want fast startup, minimal resource usage, and easy modification.

```
┌──────────────────────────────────────────────────────────────┐
│  pk9s v0.01                                                  │
├──────────────────────────────────────────────────────────────┤
│  NAME           STATUS    READY    AGE                       │
│ ─────────────────────────────────────────────────────────────│
│ ▶ nginx-pod     Running   1/1      3d                        │
│  redis-pod      Running   1/1      5d                        │
│  api-pod        Pending   0/1      1h                        │
│                                                              │
│  j/k: navigate  Tab: switch view  /: search  ?: help  q: quit│
└──────────────────────────────────────────────────────────────┘
```

## Features

### Phase 1: Backend
- kubectl wrapper with JSON output parsing
- Resource normalization (pods, deployments, services, nodes, configmaps)
- Configuration management (config file support)
- IPC::Open3 for fork/pipe management

### Phase 2: TUI
- Interactive terminal UI with [Tickit](https://metacpan.org/pod/Tickit)
- Resource table rendering with status coloring
- Keyboard navigation (j/k, arrows, Home/End)
- View switching (Tab/Shift+Tab)
- Auto-refresh with configurable interval
- Help overlay (?)

### Phase 3: Fuzzy Search
- Vim-style `/` activation
- Scoped search: `pod:nginx` filters pods matching "nginx"
- Cross-view search: `all:redis` searches across all resource types
- Real-time filtering as you type
- Character highlighting in matches

### Phase 4: Kubernetes Operations
- **Edit** (`e`): Open resource in $EDITOR, dry-run, apply
- **Delete** (`d`): Confirmation prompt before deletion
- **Port-forward** (`f`): Background process with PID tracking
- **Rollout restart** (`R`): Restart deployments with confirmation
- **Logs** (`l`): View pod logs with scrolling

### Phase 5: AI Integration & Plugins
- **AI Analysis** (`a`/`A`): Send context to local Ollama for diagnostics
- **Plugin System** (`p`): JSON-based plugins for custom CRDs
- **Context Store**: SQLite database for session history

## Keybindings

| Key | Action |
|-----|--------|
| `j` / `↓` | Move down |
| `k` / `↑` | Move up |
| `g` / `Home` | Jump to top |
| `G` / `End` | Jump to bottom |
| `Tab` | Next view |
| `Shift+Tab` | Previous view |
| `/` | Search |
| `e` | Edit resource |
| `d` | Delete resource |
| `f` | Port-forward |
| `F` | List port-forwards |
| `R` | Rollout restart |
| `l` | View logs |
| `a` | AI analyze resource |
| `A` | AI analyze cluster |
| `p` | List plugins |
| `r` | Refresh data |
| `?` | Help |
| `q` | Quit |

## Views

| View | Columns |
|------|---------|
| Pods | NAME, STATUS, READY, AGE |
| Deployments | NAME, READY, UP-TO-DATE, AVAILABLE, AGE |
| Services | NAME, TYPE, CLUSTER-IP, EXTERNAL-PORT, AGE |
| Nodes | NAME, STATUS, ROLES, AGE, VERSION |
| ConfigMaps | NAME, KEYS, AGE |

## Installation

### Prerequisites

```bash
# Perl 5.26+ (usually pre-installed on Linux)
perl -v

# kubectl configured with cluster access
kubectl cluster-info
```

### Install Dependencies

```bash
# Using cpanm (recommended)
cpanm --installdeps .

# Or using cpan
cpan JSON::PP IPC::Open3 File::Temp Tickit Term::ANSIColor

# For AI features
cpan DBI DBD::SQLite HTTP::Tiny
```

### Install pk9s

```bash
# Clone repository
git clone https://github.com/pshq/pk9s.git
cd pk9s

# Run directly
./bin/pk9s

# Or install system-wide
perl Makefile.PL
make
sudo make install
```

## Usage

### Basic Usage

```bash
# Start with default settings
./bin/pk9s

# Custom refresh interval (default: 5 seconds)
./bin/pk9s --refresh-interval 10

# Use specific kubeconfig
KUBECONFIG=~/.kube/prod.yaml ./bin/pk9s
```

### Search

```
/nginx          # Search for "nginx" in current view
pod:nginx       # Search only pods for "nginx"
all:redis       # Search across all views for "redis"
```

### Operations

```
# Edit a resource
Select resource → press 'e' → edit in vim → save → dry-run → apply

# Delete a resource
Select resource → press 'd' → confirm with 'y'

# Port-forward
Select pod → press 'f' → enter ports (e.g., 8080:80)

# View logs
Select pod → press 'l' → scroll with j/k → press 'q' to close
```

### AI Analysis

```bash
# Start Ollama
ollama serve

# Pull a model
ollama pull qwen2.5:7b

# In pk9s, select a resource and press 'a'
```

## Plugins

### Plugin Directory

```
~/.pk9s/plugins/
├── fluxcd.json
├── velero.json
└── custom.json
```

### Plugin Format

```json
{
  "name": "fluxcd",
  "version": "1.0.0",
  "description": "FluxCD integration for pk9s",
  "resources": [
    {
      "api": "kustomization.toolkit.fluxcd.io",
      "columns": ["Name", "Ready", "Age", "Status"]
    }
  ],
  "actions": {
    "r": {
      "label": "Reconcile",
      "cmd": "flux reconcile kustomization %s -n %n",
      "confirm": true
    },
    "s": {
      "label": "Suspend",
      "cmd": "flux suspend kustomization %s -n %n",
      "confirm": true
    }
  }
}
```

### Example: Velero Plugin

```json
{
  "name": "velero",
  "version": "1.0.0",
  "description": "Velero backup management",
  "resources": [
    {
      "api": "backup.velero.io",
      "columns": ["Name", "Status", "Age"]
    }
  ],
  "actions": {
    "b": {
      "label": "Create Backup",
      "cmd": "velero backup create %s",
      "confirm": true
    },
    "d": {
      "label": "Describe",
      "cmd": "velero backup describe %s",
      "confirm": false
    }
  }
}
```

## Configuration

### Config File

Create `~/.pk9s/config.json`:

```json
{
  "kubectl": "/usr/local/bin/kubectl",
  "context": "production",
  "namespace": "default",
  "editor": "vim",
  "log_level": "info"
}
```

### Environment Variables

```bash
export KUBECONFIG=~/.kube/prod.yaml
export EDITOR=vim
```

## Architecture

```
pk9s/
├── bin/
│   └── pk9s              # Entry point
├── lib/
│   ├── pk9s.pm           # Version
│   └── pk9s/
│       ├── App.pm        # TUI application (views, keybindings, rendering)
│       ├── Kubectl.pm    # kubectl wrapper (execute, get_*)
│       ├── Resource.pm   # Resource normalization
│       ├── Config.pm     # Configuration management
│       ├── Search.pm     # Fuzzy search engine
│       ├── Ops.pm        # K8s operations (edit, delete, port-forward)
│       ├── Context.pm    # SQLite context store
│       ├── AI.pm         # Ollama AI integration
│       └── Plugin.pm     # JSON plugin loader
├── t/
│   ├── 01-kubectl.t      # Kubectl module tests
│   ├── 01-kubectl-mock.t # Mock kubectl tests
│   ├── 02-resource.t     # Resource normalization tests
│   ├── 03-config.t       # Config module tests
│   ├── 04-integration.t  # Integration tests
│   ├── 05-app.t          # App module tests
│   ├── 06-search.t       # Search module tests
│   ├── 07-ops.t          # Operations tests
│   ├── 08-app-ops.t      # App operations tests
│   ├── 09-context.t      # Context store tests
│   ├── 10-ai.t           # AI module tests
│   └── 11-plugin.t       # Plugin module tests
├── docs/
│   └── compose/
│       ├── specs/        # Design specifications
│       └── plans/        # Implementation plans
├── cpanfile              # Perl dependencies
├── Makefile.PL           # Build configuration
└── README.md             # This file
```

## Development

### Running Tests

```bash
# Run all tests
prove -Ilib t/

# Run specific test
prove -Ilib t/05-app.t

# Verbose output
prove -Ilib -v t/
```

### Test Coverage

```
t/01-kubectl-mock.t .. ok (6 tests)
t/01-kubectl.t ....... ok (5 tests)
t/02-resource.t ...... ok (12 tests)
t/03-config.t ........ ok (5 tests)
t/04-integration.t ... ok (4 tests)
t/05-app.t ........... ok (72 tests)
t/06-search.t ........ ok (13 tests)
t/07-ops.t ........... ok (8 tests)
t/08-app-ops.t ....... ok (8 tests)
t/09-context.t ....... ok (8 tests)
t/10-ai.t ............ ok (6 tests)
t/11-plugin.t ........ ok (7 tests)

Files=12, Tests=154
Result: PASS
```

### Adding New Resources

1. Add `get_<resource>` method to `lib/pk9s/Kubectl.pm`
2. Add normalization to `lib/pk9s/Resource.pm`
3. Add view definition to `lib/pk9s/App.pm`
4. Add tests to `t/02-resource.t` and `t/05-app.t`

### Creating Plugins

See [Plugin Format](#plugin-format) above. Place JSON files in `~/.pk9s/plugins/`.

## Comparison with K9s

| Feature | pk9s | K9s |
|---------|------|-----|
| Language | Perl | Go |
| Startup | <100ms | ~500ms |
| Memory | ~10MB | ~50MB |
| Installation | `git clone` + `./bin/pk9s` | Binary download |
| Modification | Edit source directly | Recompile |
| Plugin System | JSON files | Go plugins |
| AI Integration | Built-in (Ollama) | External |

## Roadmap

- [x] Phase 1: Backend (kubectl wrapper, JSON parsing)
- [x] Phase 2: TUI (Tickit, views, navigation)
- [x] Phase 3: Fuzzy Search (scoped, cross-view, highlighting)
- [x] Phase 4: K8s Operations (edit, delete, port-forward, logs)
- [x] Phase 5: AI & Plugins (Ollama, SQLite, JSON plugins)
- [ ] Phase 6: Multi-cluster support
- [ ] Phase 7: Custom resource views
- [ ] Phase 8: Metrics integration

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Commit Convention

```
feat: add new feature
fix: fix bug
docs: update documentation
test: add tests
refactor: refactor code
```

## Acknowledgments

- [K9s](https://github.com/derailed/k9s) — inspiration for this project
- [Tickit](https://metacpan.org/pod/Tickit) — terminal UI library
- [Ollama](https://ollama.ai/) — local LLM runtime

## Support

- Issues: [GitHub Issues](https://github.com/pshq/pk9s/issues)
- Discussions: [GitHub Discussions](https://github.com/pshq/pk9s/discussions)
