---
name: rabbitmq-troubleshoot
description: Troubleshoot RabbitMQ connections, queues, and authentication issues
---

# RabbitMQ Troubleshooting

Diagnose and resolve RabbitMQ connectivity and queue issues.

## Common Issues

1. **Connection Attempt Alerts** - Service cannot connect to RabbitMQ
2. **Queue Backlog** - Messages accumulating without consumers
3. **Password Mismatch** - Secret password doesn't match RabbitMQ password

## Diagnostic Steps

### 1. Check RabbitMQ Pods
```bash
KUBECONFIG=~/.kube/<config>.yaml kubectl get pods -n <namespace> | grep rabbit
```

### 2. Check Logs
```bash
KUBECONFIG=~/.kube/<config>.yaml kubectl logs -n <namespace> <rabbit-pod> | tail -100
```

### 3. Check Secrets
```bash
KUBECONFIG=~/.kube/<config>.yaml kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.password}' | base64 -d
```

### 4. Check Queue Status
```bash
# Via port-forward
KUBECONFIG=~/.kube/<config>.yaml kubectl port-forward svc/rabbitmq 15672:15672 -n <namespace>
# Then access http://localhost:15672
```

## Password Reset

If password mismatch:
1. Get current password from RabbitMQ
2. Update Kubernetes secret
3. Restart affected pods

```bash
kubectl rollout restart deployment/<deployment> -n <namespace>
```

## Exit Condition

- Connection alerts resolved
- Queue backlog cleared
- Consumers active on all queues
