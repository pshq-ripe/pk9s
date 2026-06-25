# pk9s Phase 4: Kubernetes Operations — Implementation Plan

## Overview

11 tasks to implement resource operations (edit, port-forward, rollout, delete, logs).

## Task 1: Create pk9s::Ops Module Structure

**Goal:** Create `lib/pk9s/Ops.pm` with `new()` constructor and basic structure.

**Files:**
- `lib/pk9s/Ops.pm` (create)

**Tests:**
- Verify module loads
- Verify constructor works

**Commit:** `feat: create Ops.pm module structure`

---

## Task 2: Implement get_logs Method

**Goal:** Add `get_logs` to Ops.pm with kubectl logs integration.

**Files:**
- `lib/pk9s/Ops.pm` (modify)

**Tests:**
- Mock kubectl logs output
- Verify return format

**Commit:** `feat: implement get_logs in Ops.pm`

---

## Task 3: Implement delete_resource Method

**Goal:** Add `delete_resource` to Ops.pm.

**Files:**
- `lib/pk9s/Ops.pm` (modify)

**Tests:**
- Mock kubectl delete
- Verify success/error handling

**Commit:** `feat: implement delete_resource in Ops.pm`

---

## Task 4: Implement rollout_restart Method

**Goal:** Add `rollout_restart` to Ops.pm with rollout status monitoring.

**Files:**
- `lib/pk9s/Ops.pm` (modify)

**Tests:**
- Mock rollout restart
- Mock rollout status

**Commit:** `feat: implement rollout_restart in Ops.pm`

---

## Task 5: Implement edit_resource Method

**Goal:** Add `edit_resource` to Ops.pm with temp file, dry-run, and apply flow.

**Files:**
- `lib/pk9s/Ops.pm` (modify)

**Tests:**
- Mock kubectl get -o yaml
- Verify temp file creation
- Mock dry-run success/failure

**Commit:** `feat: implement edit_resource in Ops.pm`

---

## Task 6: Implement port_forward Method

**Goal:** Add `port_forward` to Ops.pm with background process forking.

**Files:**
- `lib/pk9s/Ops.pm` (modify)

**Tests:**
- Mock fork + exec
- Verify PID tracking

**Commit:** `feat: implement port_forward in Ops.pm`

---

## Task 7: Unit Tests for Ops.pm

**Goal:** Create comprehensive unit tests for all Ops.pm methods.

**Files:**
- `t/07-ops.t` (create)

**Tests:** 15+ tests covering all methods

**Commit:** `test: add unit tests for Ops.pm`

---

## Task 8: Add Operations State to App.pm

**Goal:** Add new state fields and keybindings to App.pm.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- Add `_portforwards`, `_log_view`, `_log_lines`, `_log_scroll`, `_confirm_action`
- Add keybindings: `e`, `f`, `F`, `R`, `d`, `l`
- Update help overlay with new keybindings

**Commit:** `feat: add operations state and keybindings to App.pm`

---

## Task 9: Implement _edit_resource and _delete_resource in App.pm

**Goal:** Implement edit and delete flows with confirmation prompts.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- `_edit_resource()` — orchestrate edit flow
- `_delete_resource()` — show confirmation, execute on 'y'
- `_render_confirm()` — render confirmation prompt
- `_handle_confirm()` — handle y/n input

**Commit:** `feat: implement edit and delete operations in App.pm`

---

## Task 10: Implement _view_logs and _port_forward in App.pm

**Goal:** Implement log overlay and port-forward management.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- `_view_logs()` — fetch and display logs
- `_render_logs()` — render log overlay with scrolling
- `_port_forward()` — prompt for ports, fork process
- `_list_portforwards()` — show/kill port-forwards
- Update `_tickit->on_finish` to kill port-forwards on quit

**Commit:** `feat: implement log view and port-forward in App.pm`

---

## Task 11: Integration Tests

**Goal:** Create integration tests for all operations flows.

**Files:**
- `t/08-app-ops.t` (create)

**Tests:** 10+ tests covering:
- Keybinding triggers correct method
- Confirmation flow works
- Log overlay renders
- Port-forward tracked

**Commit:** `test: add integration tests for operations`

---

## Task 12: Final Verification

**Goal:** Run all tests, verify syntax, confirm all operations work.

**Files:** None (verification only)

**Commands:**
```bash
prove -Ilib t/
perl -Ilib -c lib/pk9s/Ops.pm
perl -Ilib -c lib/pk9s/App.pm
perl -Ilib -c bin/pk9s
```

**Commit:** None (verification only)
