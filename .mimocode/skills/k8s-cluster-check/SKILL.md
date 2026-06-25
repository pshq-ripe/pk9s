---
name: k8s-cluster-check
description: Check Kubernetes cluster health across kustomizations, helmreleases, pods, and namespaces
---

# Kubernetes Cluster Health Check

Perform comprehensive cluster health assessment using kubeconfig.

## Usage

```
KUBECONFIG=~/.kube/<config>.yaml kubectl get kustomization -n <namespace>
KUBECONFIG=~/.kube/<config>.yaml kubectl get helmrelease -n <namespace>
KUBECONFIG=~/.kube/<config>.yaml kubectl get pods -n <namespace>
```

## Common Kubeconfigs

- `~/.kube/old-svm-k8s-prod.yaml` - Production cluster
- `~/.kube/old-svm-k8s-nonprod.yaml` - Non-production (old)
- `~/.kube/k8s-pc-nonprod.yaml` - Non-production (new)

## Health Check Steps

1. **Check Kustomizations** - Verify all kustomizations are ready (True)
2. **Check HelmReleases** - Verify all helmreleases are deployed
3. **Check Pods** - Look for CrashLoopBackOff, Error, or Pending pods
4. **Check Events** - Review recent warning events

## Output Format

```
Namespace | Resource | Status | Ready | Age
----------|----------|--------|-------|----
flux-system | infrastructure | True | 5/5 | 3d
```

## Exit Condition

All kustomizations=True, all helmreleases=deployed, no pods in error state.
