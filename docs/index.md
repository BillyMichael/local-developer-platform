# Local Developer Platform

Welcome to the Local Developer Platform documentation. This platform provides a complete, self-contained development environment running on Kubernetes.

## What is the Local Developer Platform?

The Local Developer Platform (LDP) is a GitOps-managed Kubernetes platform that brings together essential development tools:

- **Version Control**: Gitea for Git repository hosting
- **CI/CD**: ArgoCD for GitOps-based continuous delivery
- **Developer Portal**: Backstage for service catalog and developer experience
- **Authentication**: Authelia with LDAP for single sign-on
- **Infrastructure**: Crossplane for infrastructure as code
- **Storage**: CloudNativePG for PostgreSQL, MinIO for object storage

## Quick Links

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } **Getting Started**

    ---

    Learn how to set up and run the platform locally

    [:octicons-arrow-right-24: Getting Started](getting-started/overview.md)

-   :material-kubernetes:{ .lg .middle } **Add a Helm Chart**

    ---

    Step-by-step guide to adding new applications to the platform

    [:octicons-arrow-right-24: Adding Helm Charts](guides/adding-helm-charts.md)

-   :material-chart-arc:{ .lg .middle } **Architecture**

    ---

    Understand how the platform components work together

    [:octicons-arrow-right-24: Architecture Overview](architecture/overview.md)

</div>

## Platform Components

| Category | Components | Description |
|----------|------------|-------------|
| **Core** | Traefik, Cert-Manager, External-Secrets | Ingress, TLS, and secrets management |
| **Auth** | Authelia, LLDAP | Authentication and directory services |
| **VCS** | Gitea | Git repository hosting |
| **Orchestration** | ArgoCD, Crossplane, Kargo | GitOps and infrastructure management |
| **Portal** | Backstage | Developer portal and service catalog |
| **Storage** | CloudNativePG, MinIO | Database and object storage |
