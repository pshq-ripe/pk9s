---
description: Quick cluster health check across all namespaces
---

# Cluster Status Check

Perform rapid cluster health assessment.

## Arguments

$1 - Kubeconfig name (prod/nonprod)
$2 - Optional: specific namespace

## Procedure

1. Set KUBECONFIG based on argument
2. List all kustomizations and their status
3. List all helmreleases and their status
4. Check for pods in error states
5. Report summary

## Kubeconfig Mapping

- `prod` → `~/.kube/old-svm-k8s-prod.yaml`
- `nonprod` → `~/.kube/k8s-pc-nonprod.yaml`
- `old-nonprod` → `~/.kube/old-svm-k8s-nonprod.yaml`

## Output

```
=== Cluster Status ===
Kustomizations: X/Y ready
HelmReleases: X/Y deployed
Problem Pods: X
```
