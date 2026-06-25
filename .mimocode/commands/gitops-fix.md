---
description: Fix GitOps issue with proper git workflow
---

# GitOps Fix Workflow

Standardized workflow for fixing GitOps issues.

## Arguments

$1 - Repository path
$2 - Ticket ID (e.g., DEV-12345)
$3 - Description of fix

## Procedure

1. Navigate to repository
2. Pull main: `git pull origin main`
3. Create feature branch: `git checkout -b feat/$2/$3`
4. Apply fixes
5. Commit: `git commit -m "fix: $3"`
6. Push: `git push origin feat/$2/$3`
7. Report MR ready (user creates MR manually)

## Rules

- Never add co-author to commits
- Always pull main first
- Use feature branch naming convention
- Commit message: `fix: <description>` or `feat: <description>`
