---
name: flux-gitops-ops
description: Perform Flux GitOps operations: pull, branch, commit, merge, reconcile
---

# Flux GitOps Operations

Standard workflow for GitOps repository operations.

## Standard Flow

```bash
# 1. Pull main
git pull origin main

# 2. Create feature branch
git checkout -b feat/<TICKET-ID>/<description>

# 3. Make changes
# ... edit files ...

# 4. Commit and push
git add .
git commit -m "feat: description"
git push origin feat/<TICKET-ID>/<description>

# 5. Create MR (user does this manually)

# 6. After merge, pull main
git pull origin main

# 7. Force reconcile if needed
KUBECONFIG=~/.kube/<config>.yaml flux reconcile kustomization <name> -n <namespace>
```

## Important Rules

- **Always pull main first** before creating feature branch
- **Never sign as co-author** - user explicitly requested this
- **Feature branch naming**: `feat/<TICKET-ID>/<short-description>`
- **Force reconcile** when immediate effect is needed

## Kubeconfig for Flux

```bash
# Production
export KUBECONFIG=~/.kube/old-svm-k8s-prod.yaml

# Non-production (new)
export KUBECONFIG=~/.kube/k8s-pc-nonprod.yaml
```

## Reconcile Commands

```bash
# Reconcile specific kustomization
flux reconcile kustomization <name> -n <namespace>

# Reconcile git source
flux reconcile source git <name> -n <namespace>

# Watch reconciliation progress
watch kubectl get kustomization -n <namespace>
```
