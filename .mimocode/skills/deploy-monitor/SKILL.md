---
name: deploy-monitor
description: Monitor production deployments and rollback if issues detected
---

# Production Deployment Monitor

Watch deployment progress and react to issues.

## Monitor Rollout

```bash
# Check rollout status
KUBECONFIG=~/.kube/<config>.yaml kubectl rollout status deployment/<name> -n <namespace>

# Check pods
KUBECONFIG=~/.kube/<config>.yaml kubectl get pods -n <namespace> -l app=<name>

# Check events
KUBECONFIG=~/.kube/<config>.yaml kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Watch for Issues

- CrashLoopBackOff
- ImagePullBackOff
- OOMKilled
- High restart count

## Rollback Command

```bash
KUBECONFIG=~/.kube/<config>.yaml kubectl rollout undo deployment/<name> -n <namespace>
```

## Force Reconcile (Flux)

```bash
KUBECONFIG=~/.kube/<config>.yaml flux reconcile kustomization <name> -n <namespace>
```

## Exit Condition

Deployment successful, pods running, no errors in logs.
