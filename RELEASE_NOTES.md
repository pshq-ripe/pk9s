# pk9s v1.00

Lightweight Kubernetes TUI written in Perl — ultra-fast alternative to K9s.

## Features

### TUI (Tickit)
- Interactive terminal UI with resource tables
- Keyboard navigation (j/k, arrows, g/G, Home/End)
- Status coloring (Running=green, Pending=yellow, Error=red)
- Auto-refresh with configurable interval
- Help overlay (?) with all keybindings

### Scoped Fuzzy Search
- Press `/` to enter search mode
- Search within current view (default)
- Cross-view search with `all:` prefix (e.g., `all:nginx`)
- Real-time filtering as you type
- ANSI bold highlighting of matching text

### Kubernetes Operations
- **Edit** (`e`) — Open resource in $EDITOR, dry-run, apply
- **Port-forward** (`f`) — Fork background process, track by PID
- **Rollout restart** (`R`) — Restart deployments/daemonsets/statefulsets
- **Delete** (`d`) — Confirm before deletion
- **Logs** (`l`) — Stream pod logs with scroll

### AI Integration (Phase 5)
- SQLite context store for cluster state
- Ollama AI sidecar for diagnostics
- Press `a` to analyze with local LLM

### Plugin System
- JSON-based plugin architecture
- Custom CRD handlers and keybindings
- Community-extensible

## Keybindings

| Key | Action |
|-----|--------|
| `j`/`↓` | Move down |
| `k`/`↑` | Move up |
| `g`/`Home` | Jump to top |
| `G`/`End` | Jump to bottom |
| `Tab` | Switch view |
| `Shift+Tab` | Previous view |
| `r` | Refresh |
| `/` | Search |
| `?` | Help |
| `e` | Edit resource |
| `f` | Port-forward |
| `R` | Rollout restart |
| `d` | Delete resource |
| `l` | View logs |
| `a` | AI analysis |
| `q` | Quit |

## Installation

```bash
# Clone repository
git clone https://github.com/pshq-ripe/pk9s.git
cd pk9s

# Install dependencies
cpanm --installdeps .

# Run
perl -Ilib bin/pk9s
```

## Requirements

- Perl 5.30+
- kubectl configured
- Tickit (for TUI)

## Test Results

- **154 tests passing**
- 12 test files
- 9 modules

## License

MIT
