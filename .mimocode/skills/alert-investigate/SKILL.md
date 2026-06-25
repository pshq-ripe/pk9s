---
name: alert-investigate
description: Investigate and resolve monitoring alerts from Grafana/Alertmanager
---

# Alert Investigation

Diagnose monitoring alerts and determine root cause.

## Common Alert Types

1. **RabbitMQ Connection** - Service cannot connect
2. **RabbitMQ Queue Backlog** - Messages accumulating
3. **Pod Restart Loop** - CrashLoopBackOff
4. **HTTP 5xx Errors** - Backend errors
5. **Certificate Expiry** - TLS certificates expiring

## Investigation Steps

### 1. Identify Alert Source
```bash
# Check Grafana alerts
# Check Alertmanager
# Review Splunk logs if available
```

### 2. Check Affected Resources
```bash
KUBECONFIG=~/.kube/<config>.yaml kubectl get pods -n <namespace>
KUBECONFIG=~/.kube/<config>.yaml kubectl logs -n <namespace> <pod-name> | tail -50
```

### 3. Check Related Services
```bash
# For RabbitMQ alerts
KUBECONFIG=~/.kube/<config>.yaml kubectl get secret <secret> -n <namespace> -o yaml

# For HTTP errors
KUBECONFIG=~/.kube/<config>.yaml kubectl get ingress -n <namespace>
```

### 4. Determine Fix
- Password mismatch → Update secret
- Queue backlog → Check consumers
- CrashLoopBackOff → Check logs, restart
- Certificate → Renew or update

## Exit Condition

Root cause identified, fix applied or documented.
