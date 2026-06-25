# pk9s Phase 4: Kubernetes Operations — Design Spec

## [S1] Goal

Add live resource management capabilities to pk9s TUI. Users can edit, port-forward, rollout restart, delete resources, and stream logs directly from the interface.

## [S2] Operations

### [S2.1] Edit Resource (`e` key)

**Flow:**
1. User presses `e` on selected resource
2. Fetch resource YAML via `kubectl get <type> <name> -o yaml`
3. Write to temp file (`/tmp/pk9s-edit-XXXXXX.yaml`)
4. Open `$EDITOR` (vim default) with temp file
5. On editor exit:
   - Dry-run: `kubectl apply --dry-run=client -f <tempfile>`
   - If dry-run OK → apply: `kubectl apply -f <tempfile>`
   - If dry-run fails → show error, ask user to re-edit or cancel
6. Clean up temp file

**Keybindings:**
- `e` — Edit selected resource
- After edit, return to TUI

**Error handling:**
- Dry-run failure shows error message at bottom
- User can press `e` again to re-edit, `Escape` to cancel

### [S2.2] Port-Forward (`f` key)

**Flow:**
1. User presses `f` on selected pod/service
2. Prompt for ports: `Forward (local:remote)? ` (default: first container port)
3. Fork port-forward process in background:
   ```bash
   kubectl port-forward <type>/<name> <local>:<remote> -n <namespace>
   ```
4. Track PID in `_portforwards` hash
5. Display active port-forwards in status bar

**Keybindings:**
- `f` — Port-forward selected resource
- `F` — List/kill active port-forwards

**Process management:**
- Use `fork()` + `exec()` for background process
- Store PID, command, start time in hash
- On `q` (quit), kill all port-forward processes
- `F` shows list, user selects by number to kill

### [S2.3] Rollout Restart (`R` key)

**Flow:**
1. User presses `R` on selected deployment/daemonset/statefulset
2. Confirm: `Restart rollout for <name>? (y/N)`
3. Execute: `kubectl rollout restart <type>/<name> -n <namespace>`
4. Monitor: `kubectl rollout status <type>/<name> -n <namespace>`
5. Show progress in status bar

**Keybindings:**
- `R` — Rollout restart
- During monitoring, `Escape` cancels watching (process continues)

### [S2.4] Delete Resource (`d` key)

**Flow:**
1. User presses `d` on selected resource
2. Confirm: `Delete <type> <name>? (y/N)`
3. If confirmed: `kubectl delete <type> <name> -n <namespace>`
4. Refresh data

**Keybindings:**
- `d` — Delete with confirmation
- Any key other than `y` cancels

### [S2.5] Logs (`l` key)

**Flow:**
1. User presses `l` on selected pod
2. Fetch logs: `kubectl logs <pod> -n <namespace> --tail=100`
3. Display in full-screen overlay (similar to help)
4. User can scroll with `j`/`k`
5. Press `q` or `Escape` to close

**Keybindings:**
- `l` — View logs (pods only)
- `j`/`k` — Scroll logs
- `q`/`Escape` — Close log view

## [S3] New Module: pk9s::Ops

Create `lib/pk9s/Ops.pm` to encapsulate operations:

```perl
package pk9s::Ops;

sub new {
    my ($class, %args) = @_;
    return bless { kubectl => $args{kubectl} }, $class;
}

sub edit_resource {
    my ($self, $type, $name, $namespace) = @_;
    # Returns: { success => 1 } or { error => "...", tempfile => "..." }
}

sub port_forward {
    my ($self, $type, $name, $namespace, $ports) = @_;
    # Returns: { pid => $pid } or { error => "..." }
}

sub rollout_restart {
    my ($self, $type, $name, $namespace) = @_;
    # Returns: { success => 1 } or { error => "..." }
}

sub delete_resource {
    my ($self, $type, $name, $namespace) = @_;
    # Returns: { success => 1 } or { error => "..." }
}

sub get_logs {
    my ($self, $name, $namespace, %args) = @_;
    # Returns: { logs => "..." } or { error => "..." }
}

sub kill_portforward {
    my ($self, $pid) = @_;
    # Kill port-forward process
}
```

## [S4] App.pm Changes

### New state fields:
```perl
_portforwards => {},     # { pid => { cmd, start_time, port } }
_log_view => 0,          # boolean
_log_lines => [],        # array of log lines
_log_scroll => 0,        # scroll position
_confirm_action => undef, # { type => 'delete'|'restart', ... }
```

### New keybindings:
```perl
'e' => sub { $self->_edit_resource() },
'f' => sub { $self->_port_forward() },
'F' => sub { $self->_list_portforwards() },
'R' => sub { $self->_rollout_restart() },
'd' => sub { $self->_delete_resource() },
'l' => sub { $self->_view_logs() },
```

### New methods:
- `_edit_resource()` — orchestrate edit flow
- `_port_forward()` — prompt and fork port-forward
- `_list_portforwards()` — show/kill port-forwards
- `_rollout_restart()` — confirm and restart
- `_delete_resource()` — confirm and delete
- `_view_logs()` — show log overlay
- `_render_logs()` — render log lines
- `_render_confirm()` — render confirmation prompt

## [S5] Test Plan

### Unit tests (`t/07-ops.t`):
1. `edit_resource` creates temp file with YAML
2. `edit_resource` returns error on dry-run failure
3. `port_forward` forks process and returns PID
4. `get_logs` returns log output
5. `delete_resource` executes kubectl delete

### Integration tests (`t/08-app-ops.t`):
1. Keybinding `e` triggers edit flow
2. Keybinding `d` shows confirmation
3. Keybinding `l` shows log overlay
4. Port-forward tracked in `_portforwards`
5. Quit kills all port-forward processes

## [S6] Dependencies

No new CPAN modules required. Uses:
- `File::Temp` (core) for temp files
- `POSIX` (core) for `WNOHANG` in process reaping
- `Tickit` (existing) for TUI

## [S7] Implementation Order

1. Create `pk9s::Ops` module with all methods
2. Unit tests for Ops.pm
3. Add state fields to App.pm
4. Add keybindings to App.pm
5. Implement `_edit_resource`
6. Implement `_delete_resource`
7. Implement `_rollout_restart`
8. Implement `_view_logs` + `_render_logs`
9. Implement `_port_forward` + `_list_portforwards`
10. Integration tests
11. Final verification
