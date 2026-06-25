---
name: velero-backup-monitor
description: Monitor Velero backup operations and measure restore times
---

# Velero Backup & Restore Monitor

Track backup status and measure restore durations.

## Check Backup Status

```bash
KUBECONFIG=~/.kube/<config>.yaml velero backup get -n velero
KUBECONFIG=~/.kube/<config>.yaml velero backup describe <backup-name> -n velero
```

## Check Restore Status

```bash
KUBECONFIG=~/.kube/<config>.yaml velero restore get -n velero
KUBECONFIG=~/.kube/<config>.yaml velero restore describe <restore-name> -n velero
```

## Monitor Backup Progress

```bash
# Watch backup status
watch kubectl get backups -n velero

# Check backup logs
velero backup logs <backup-name> -n velero
```

## Measure Restore Time

1. Note start time
2. Monitor restore status
3. Calculate duration when complete

## Common Kubeconfigs

- Production: `~/.kube/old-svm-k8s-prod.yaml`
- Non-production: `~/.kube/k8s-pc-nonprod.yaml`

## Exit Condition

All backups completed successfully, restore time documented.
