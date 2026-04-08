# Architecture

This document provides visual and descriptive architecture diagrams for the Infrastructure Boilerplate project.

---

## High-Level System Architecture

```mermaid
graph TB
    subgraph Developer
        Dev[Developer Workstation]
        Make[Makefile CLI]
    end

    subgraph CI/CD
        GH[GitHub]
        Actions[GitHub Actions]
        Lint[Lint & Format]
        Security[Security Scan]
        Build[Docker Build]
        TFPlan[Terraform Plan]
        TFApply[Terraform Apply]
    end

    subgraph AWS Cloud
        VPC[VPC / Network]
        EC2[EC2 Instances]
        EKS[EKS Cluster]
        S3[S3 Buckets]
        RDS[RDS Database]
    end

    subgraph Configuration
        Ansible[Ansible]
    end

    subgraph GitOps
        ArgoCD[ArgoCD]
        K8s[Kubernetes Workloads]
    end

    subgraph Observability
        Prometheus[Prometheus]
        Grafana[Grafana]
        Loki[Loki]
    end

    Dev -->|git push| GH
    GH -->|trigger| Actions
    Actions --> Lint
    Actions --> Security
    Actions --> Build
    Actions --> TFPlan
    Actions --> TFApply
    TFApply --> VPC
    TFApply --> EC2
    TFApply --> EKS
    TFApply --> S3
    TFApply --> RDS
    EC2 --> Ansible
    EKS --> ArgoCD
    ArgoCD --> K8s
    K8s --> Prometheus
    K8s --> Loki
    Prometheus --> Grafana
    Loki --> Grafana
    Make -->|local dev| Dev
```

---

## CI/CD Pipeline Flow

```mermaid
flowchart LR
    A[git push] --> B{Lint & Validate}
    B -->|pass| C{Security Scan}
    B -->|fail| FAIL[❌ PR Blocked]
    C -->|pass| D[Terraform Plan]
    C -->|fail| FAIL
    D -->|PR| COMMENT[💬 Plan as PR Comment]
    D -->|merge| E[Build Docker Image]
    E --> F[Push to Registry]
    F --> G[Terraform Apply dev]
    G --> H{Approval Gate}
    H -->|approve| I[Terraform Apply staging]
    I --> J{Approval Gate}
    J -->|approve| K[Terraform Apply prod]
    K --> L[ArgoCD Sync]
    L --> M[Slack Notification]
```

---

## Kubernetes Deployment Flow (GitOps)

```mermaid
flowchart TD
    A[Developer pushes K8s manifests] --> B[ArgoCD detects changes]
    B --> C{Sync Policy}
    C -->|auto| D[ArgoCD applies manifests]
    C -->|manual| E[Engineer clicks Sync]
    D --> F[Kube-API Server]
    E --> F
    F --> G[Controller Manager]
    G --> H[Scheduler]
    H --> I[Kubelet on Node]
    I --> J[Container Runtime pulls image]
    J --> K[Pod starts]
    K --> L[Health checks pass]
    L --> M[Service routes traffic]
```

---

## Network Topology (AWS)

```
┌─────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                                           │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Public Sub A │  │ Public Sub B │                        │
│  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │                        │
│  │              │  │              │                        │
│  │  ┌────────┐  │  │  ┌────────┐  │                        │
│  │  │  NLB   │  │  │  NAT GW  │  │                        │
│  │  └────────┘  │  │  └────┬───┘  │                        │
│  └──────────────┘  └───────┼───────┘                        │
│                            │                                │
│  ┌──────────────┐  ┌───────▼───────┐                        │
│  │ Private Sub A│  │ Private Sub B │                        │
│  │ 10.0.10.0/24 │  │ 10.0.20.0/24  │                        │
│  │              │  │               │                        │
│  │  ┌────────┐  │  │  ┌────────┐   │                        │
│  │  │  App   │  │  │  │  App   │   │                        │
│  │  │ Server │  │  │  │ Server │   │                        │
│  │  └────────┘  │  │  └────────┘   │                        │
│  └──────────────┘  └───────────────┘                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │ Isolated A   │  │ Isolated B   │                        │
│  │ 10.0.30.0/24 │  │ 10.0.40.0/24 │                        │
│  │              │  │              │                        │
│  │  ┌────────┐  │  │  ┌────────┐  │                        │
│  │  │  RDS   │  │  │  RDS     │  │                        │
│  │  │ Primary│  │  │  Replica │  │                        │
│  │  └────────┘  │  │  └────────┘  │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Monitoring Stack Architecture

```mermaid
graph LR
    subgraph Kubernetes Cluster
        App[Application Pods]
        Node[Node Exporter]
        cAdvisor[cAdvisor]
    end

    subgraph Monitoring Namespace
        Prometheus[Prometheus Server]
        AlertMgr[Alertmanager]
        Loki[Loki]
    end

    subgraph External
        Grafana[Grafana Dashboard]
        PagerDuty[PagerDuty]
        Slack[Slack Alerts]
    end

    App -->|metrics /metrics| Prometheus
    Node -->|metrics :9100| Prometheus
    cAdvisor -->|metrics :4194| Prometheus
    App -->|logs| Loki
    Prometheus --> AlertMgr
    AlertMgr --> PagerDuty
    AlertMgr --> Slack
    Prometheus --> Grafana
    Loki --> Grafana
```

---

## Secret Management Flow

```mermaid
flowchart LR
    Dev[Developer] -->|creates| Plaintext[secrets.yml]
    Plaintext -->|sops -e| Encrypted[secrets.enc.yml]
    Encrypted -->|committed to| Git[Git Repository]
    Git -->|CI/CD pipeline| Decrypt[sops -d]
    Decrypt -->|injected as| Env[Environment Variables]
    Decrypt -->|mounted as| Vol[K8s Secrets Volume]
    Env --> App[Application]
    Vol --> App
```
