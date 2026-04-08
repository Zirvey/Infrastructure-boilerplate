# Kubernetes Guide

Complete reference for Kubernetes usage in this project.

---

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Kustomize Overlays](#kustomize-overlays)
- [Base Manifests](#base-manifests)
- [Environment Overlays](#environment-overlays)
- [ArgoCD Integration](#argocd-integration)
- [Common Operations](#common-operations)
- [Scaling](#scaling)
- [Monitoring](#monitoring)
- [Best Practices](#best-practices)

---

## Overview

Kubernetes is used for orchestrating containerized workloads in production. This project uses:

- **Kustomize** for environment-specific manifest generation
- **Base + Overlay pattern** for DRY configurations
- **ArgoCD** for GitOps-based continuous delivery
- **Health checks** (liveness + readiness probes)
- **Resource limits** on all containers

---

## Directory Structure

```
kubernetes/
├── base/                        # Base manifests (shared across environments)
│   ├── kustomization.yaml       # Kustomize entry point
│   ├── namespace.yaml           # Application namespace
│   ├── deployment.yaml          # Deployment with probes & limits
│   └── service.yaml             # ClusterIP service
├── overlays/                    # Environment-specific patches
│   ├── dev/
│   │   └── kustomization.yaml   # Dev overlay (1 replica, low resources)
│   ├── staging/
│   │   └── kustomization.yaml   # Staging overlay (2 replicas, medium)
│   └── prod/
│       └── kustomization.yaml   # Prod overlay (5 replicas, high resources)
├── apps/                        # ArgoCD application definitions
│   └── web-app/
│       └── application.yaml     # ArgoCD Application CR
└── infrastructure/              # Platform infrastructure components
    └── argocd/
        └── project.yaml         # ArgoCD AppProject
```

---

## Kustomize Overlays

Kustomize lets you customize raw YAML files without templating:

### Base Configuration

`kubernetes/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: application

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml

commonLabels:
  managed-by: kustomize
  app.kubernetes.io/part-of: infrastructure-boilerplate
```

### How Overlays Work

Each overlay:
1. References the base manifests
2. Applies environment-specific patches
3. Changes namespace, names, replicas, resources

---

## Base Manifests

### Deployment

The base deployment includes:

- **Replicas:** 2 (overridden per environment)
- **Container:** `your-registry/app:latest`
- **Port:** 3000
- **Resource requests:** 256Mi / 250m CPU
- **Resource limits:** 512Mi / 500m CPU
- **Liveness probe:** HTTP GET `/health` on port 3000
- **Readiness probe:** HTTP GET `/health` on port 3000
- **ConfigMap reference:** `app-config`

### Service

- **Type:** ClusterIP
- **Port:** 80 → 3000 (targetPort)
- **Selector:** `app: web-app`

---

## Environment Overlays

### Dev (`overlays/dev/`)

| Setting | Value |
|---------|-------|
| Namespace | `application-dev` |
| Replicas | 1 |
| Memory request | 128Mi |
| Memory limit | 256Mi |
| CPU request | 100m |
| CPU limit | 250m |

### Staging (`overlays/staging/`)

| Setting | Value |
|---------|-------|
| Namespace | `application-staging` |
| Replicas | 2 |
| Memory request | 256Mi |
| Memory limit | 512Mi |
| CPU request | 250m |
| CPU limit | 500m |

### Production (`overlays/prod/`)

| Setting | Value |
|---------|-------|
| Namespace | `application-prod` |
| Replicas | 5 |
| Memory request | 1Gi |
| Memory limit | 2Gi |
| CPU request | 500m |
| CPU limit | 1000m |
| Strategy | RollingUpdate (maxUnavailable: 0, maxSurge: 1) |

---

## ArgoCD Integration

### Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/infrastructure-boilerplate.git
    targetRevision: HEAD
    path: kubernetes/overlays/dev  # Change per environment
  destination:
    server: https://kubernetes.default.svc
    namespace: application-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Sync Policies

| Policy | Description |
|--------|-------------|
| `automated.prune` | Delete resources no longer in Git |
| `automated.selfHeal` | Revert manual changes back to Git state |
| `retry` | Retry failed syncs with backoff |

---

## Common Operations

### Using the Makefile

```bash
make k8s-deploy       # Apply manifests (auto-selects overlay)
make k8s-delete       # Delete all resources
make k8s-status       # Show all resources
make k8s-portforward  # Port-forward service to localhost:3000
```

### Manual Commands

```bash
# Apply base manifests
kubectl apply -f kubernetes/base/

# Apply with Kustomize (recommended)
kubectl apply -k kubernetes/overlays/dev

# View resources
kubectl get all -n application

# Describe a pod
kubectl describe pod -l app=web-app -n application

# View logs
kubectl logs -l app=web-app -n application -f

# Port-forward
kubectl port-forward svc/app-service 3000:3000 -n application

# Scale manually
kubectl scale deployment app-deployment --replicas=5 -n application
```

### Render Kustomize Output (dry-run)

```bash
# See the final manifests without applying
kubectl kustomize kubernetes/overlays/dev

# Or save to file
kubectl kustomize kubernetes/overlays/dev > rendered-dev.yaml
```

---

## Scaling

### Horizontal Pod Autoscaler (HPA)

For auto-scaling based on CPU/memory:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
  namespace: application
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Pod Disruption Budget (PDB)

For production availability:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
  namespace: application-prod
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web-app
```

---

## Monitoring

### Resource Metrics

```bash
# Check pod resource usage
kubectl top pods -n application

# Check node capacity
kubectl top nodes
```

### Health Checks

The deployment includes both liveness and readiness probes:

| Probe | Purpose | Initial Delay | Period |
|-------|---------|--------------|--------|
| Liveness | Restart if app is deadlocked | 30s | 10s |
| Readiness | Remove from service if not ready | 5s | 5s |

---

## Best Practices

1. **Use Kustomize, not Helm** — for simpler use cases; Helm for complex chart dependencies
2. **Always set resource requests and limits** — prevents noisy neighbor problems
3. **Use health probes** — liveness and readiness on every deployment
4. **Pin image tags** — never use `:latest` in production
5. **Run as non-root** — set `runAsNonRoot: true` in securityContext
6. **Drop all capabilities** — `capabilities.drop: ["ALL"]`
7. **Use NetworkPolicies** — default-deny, then explicit allow
8. **Separate namespaces per environment** — prevents cross-env interference
9. **Use ArgoCD for production** — GitOps over manual `kubectl apply`
10. **Review manifests in CI** — kubeconform + OPA policies validate on every PR
