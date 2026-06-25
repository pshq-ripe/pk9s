# pk9s Phase 5: AI Integration & Lua Plugins — Implementation Plan

## Overview

11 tasks to implement AI diagnostics and Lua plugin system.

## Task 1: Create pk9s::Context Module

**Goal:** Create SQLite context store for session history and events.

**Files:**
- `lib/pk9s/Context.pm` (create)

**Methods:**
- `new(%args)` — Initialize with db_path
- `log_command($cmd, $stdout, $stderr, $exit_code, $duration)`
- `log_event($type, $namespace, $resource, $data)`
- `get_context($resource, $limit)`
- `clear_old($days)`

**Dependencies:** DBI, DBD::SQLite

**Commit:** `feat: create Context.pm module for SQLite context store`

---

## Task 2: Unit Tests for Context.pm

**Goal:** Create comprehensive unit tests for Context.pm.

**Files:**
- `t/09-context.t` (create)

**Tests:** 10+ tests covering all methods

**Commit:** `test: add unit tests for Context.pm`

---

## Task 3: Create pk9s::AI Module

**Goal:** Create AI sidecar module with Ollama integration.

**Files:**
- `lib/pk9s/AI.pm` (create)

**Methods:**
- `new(%args)` — Initialize with context, model, endpoint
- `analyze_resource($type, $name, $namespace)`
- `analyze_cluster()`
- `build_prompt(%args)`
- `call_ollama($prompt)`

**Dependencies:** HTTP::Tiny, JSON::PP

**Commit:** `feat: create AI.pm module with Ollama integration`

---

## Task 4: Unit Tests for AI.pm

**Goal:** Create unit tests with mocked Ollama responses.

**Files:**
- `t/10-ai.t` (create)

**Tests:** 8+ tests covering prompt building and API calls

**Commit:** `test: add unit tests for AI.pm`

---

## Task 5: Create pk9s::Plugin Module

**Goal:** Create plugin loader module.

**Files:**
- `lib/pk9s/Plugin.pm` (create)

**Methods:**
- `new(%args)` — Initialize
- `load_plugins($dir)`
- `get_resources()`
- `get_actions($resource)`
- `execute_action($action, $resource, $namespace)`

**Commit:** `feat: create Plugin.pm module for Lua plugin loading`

---

## Task 6: Unit Tests for Plugin.pm

**Goal:** Create unit tests with sample plugin.

**Files:**
- `t/11-plugin.t` (create)
- `t/fixtures/sample.lua` (create)

**Tests:** 6+ tests covering plugin loading and execution

**Commit:** `test: add unit tests for Plugin.pm`

---

## Task 7: Add AI State to App.pm

**Goal:** Add new state fields and keybindings to App.pm.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- Add `_context`, `_ai`, `_plugins`, `_ai_view`, `_ai_response`, `_ai_scroll`
- Add keybindings: `a`, `A`, `p`
- Update help overlay

**Commit:** `feat: add AI state and keybindings to App.pm`

---

## Task 8: Implement _analyze_resource in App.pm

**Goal:** Implement AI analysis flow with overlay rendering.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- `_analyze_resource()` — gather context, call AI, show overlay
- `_render_ai()` — render AI response with scrolling

**Commit:** `feat: implement AI analysis in App.pm`

---

## Task 9: Implement Plugin Integration in App.pm

**Goal:** Implement plugin loading and action execution.

**Files:**
- `lib/pk9s/App.pm` (modify)

**Changes:**
- `_load_plugins()` — load plugins on startup
- `_list_plugins()` — show plugin overlay
- `_execute_plugin_action($key)` — execute plugin action
- Integrate plugin resources into views

**Commit:** `feat: implement plugin integration in App.pm`

---

## Task 10: Integration Tests

**Goal:** Create integration tests for AI and plugin flows.

**Files:**
- `t/12-app-ai.t` (create)

**Tests:** 8+ tests covering analysis and plugin execution

**Commit:** `test: add integration tests for AI and plugins`

---

## Task 11: Final Verification

**Goal:** Run all tests, verify syntax, confirm all features work.

**Files:** None (verification only)

**Commands:**
```bash
prove -Ilib t/
perl -Ilib -c lib/pk9s/Context.pm
perl -Ilib -c lib/pk9s/AI.pm
perl -Ilib -c lib/pk9s/Plugin.pm
perl -Ilib -c lib/pk9s/App.pm
perl -Ilib -c bin/pk9s
```

**Commit:** None (verification only)
