## DevOps Sample Node.js App

### Overview

A lightweight Node.js application. It features basic web endpoints, Prometheus metrics integration, and is designed for Kubernetes deployment and CI/CD pipeline demonstrations.

### Features

- Express.js web server
- Prometheus metrics integration
- Readiness and liveness probe endpoints
- Customizable port via environment variable

### Prerequisites

- Node.js (v22.1.0)


# DevOps Sample Node.js App & CI/CD Pipeline
This ****repository**** contains a sample Node.js application, a comprehensive CI/CD pipeline built with GitHub Actions and uses GitHub Container Registry, and the necessary Kubernetes manifests packaged as a Helm chart for deployment. This document outlines the technical decisions and implementation details for the key components of this project, addressing all requirements of the DevOps task.

## 1. Architecture Overview
The architecture is designed around modern GitOps and DevSecOps principles to create a secure, automated, and auditable path to production.

CI (Continuous Integration): A pull request to the main branch triggers the BuildAndScan pipeline (main.yml). This pipeline runs static code analysis (SAST), Helm chart validation, and builds a temporary Docker image to scan for vulnerabilities. It acts as a quality gate; no code can be merged if these checks fail.

CD (Continuous Deployment): The release process is initiated by creating and merging a pull request from the main branch to the release branch. The release branch must be set as the base branch for the PR. This merge acts as the manual approval for a production deployment and triggers the ReleaseToArgoCD pipeline (release.yml).

Release Pipeline: This workflow builds the official, production-ready Docker image, tags it, and pushes it to the GitHub Container Registry (GHCR).

GitOps Hand-off: The final step of the release pipeline is to make an automated commit back to the release branch. This commit updates the image.tag in the Helm chart's values.yaml file. This action is the critical link that makes the process declarative, recording the exact version being deployed directly in the source of truth.

GitOps Sync: ArgoCD, which is constantly watching the release branch, detects this new commit. It reads the updated Helm chart and automatically syncs the Kubernetes cluster to match this desired state, deploying the new application version.

Observability: A Prometheus monitoring stack, installed in the cluster, automatically discovers the running application via a ServiceMonitor and scrapes its /metrics endpoint for real-time performance data.

## 2. Helm Chart Decisions
The application is packaged as a Helm chart located in the /sampleapp directory.

### a. Workload Choice: Deployment
A Kubernetes Deployment was chosen over a StatefulSet.

Justification: The Node.js application is stateless. It does not store any critical data or session information in its own memory. Even the Prometheus metrics counter is considered observability state, which is designed to be ephemeral and aggregated by an external system (Prometheus). A Deployment is the standard and most efficient way to manage stateless, scalable applications.

### b. Kubernetes Manifest Features
The Helm chart utilizes several key Kubernetes features for robustness and security:

Probes: readinessProbe and livenessProbe are configured in values.yaml and point to the /ready and /live endpoints in app.js. This ensures Kubernetes can manage the pod's lifecycle effectively.

Service & Ingress: A ClusterIP Service exposes the application within the cluster, and an Ingress resource manages external access.

Pod Quality of Service (QoS): The deployment.yaml sets CPU and memory requests and limits to the same value. This configuration assigns the pod the Guaranteed QoS class. This is the highest priority class, meaning Kubernetes will not evict this pod , making it ideal for critical production workloads.

### c. Security Context Explained
A restrictive securityContext is defined in values.yaml to harden the container at runtime by adhering to the principle of least privilege.

runAsNonRoot: true / runAsUser: 1000: This is the most critical setting. It prevents the container from running as the root user, drastically reducing the potential impact of a container breakout vulnerability.

readOnlyRootFilesystem: true: Mounts the container's filesystem as read-only. An attacker who gains access cannot modify application files.

capabilities: { drop: ["ALL"] }: Linux capabilities are fine-grained permissions. This setting drops all potential special permissions, ensuring the container can only perform basic operations.

allowPrivilegeEscalation: false: Prevents a process inside the container from gaining more privileges than its parent process, closing another potential attack vector.

## 3. CI/CD Pipeline Strategy
A two-pipeline strategy is implemented using GitHub Actions to separate validation from deployment.

main.yml (BuildAndScan): This is the quality gate. Triggered on every Pull Request to main, it performs all critical security checks before code is merged. This "shift-left" approach catches issues early.

release.yml (ReleaseToArgoCD): This is the release automation. Triggered only by a merge from main to the release branch, it builds the official production image, pushes it to GHCR, and performs the GitOps hand-off.

### a. Versioning Strategy
The image tag is generated using a date-run_number format (e.g., 23072025-11). This strategy is sufficient for this project as it guarantees that every image pushed by the release pipeline has a unique and traceable identifier. For more complex projects, a Semantic Versioning (v1.2.3) strategy, often triggered by Git tags, could be adopted, but the current method is robust for a continuous deployment model.

### b. DevSecOps Scans Explained
This project uses a multi-layered security scanning approach. While GitHub provides excellent native tools like Dependabot for dependency alerts, explicitly integrating scanners into the pipeline provides more control and enforces blocking behavior, failing the build if critical issues are found.

CodeQL (SAST): This is a Static Application Security Testing tool that analyzes the source code itself. It understands the application's logic to find bugs like insecure data handling or injection vulnerabilities before the code is even built.

Trivy (Vulnerability & Misconfiguration Scanner): Trivy is used for several checks that analyze the application's components and configuration, not the source code logic.

Dependency Scan (trivy fs): Scans package-lock.json for known vulnerabilities (CVEs) in third-party libraries.

Secrets Scan (trivy fs --scanners secret): Scans the repository for any accidentally committed secrets like API keys or passwords.

IaC Scan (trivy config): Scans the Helm chart templates for security misconfigurations.

Container Image Scan (trivy image): Scans the final Docker image for vulnerabilities in the base OS and other installed packages.

## 4. Deployment Strategy: GitOps with ArgoCD
A GitOps model using ArgoCD was chosen for deploying to production.

Repository Strategy: ArgoCD is configured to monitor the application repository directly. For a project of this scale, this "monorepo" approach is simpler and provides a clear correlation between the application code and its deployment configuration.

Deployment Process: The deployment is fully declarative. The CD pipeline's final step is to update the desired state in the release branch. ArgoCD then ensures the cluster's live state matches this desired state.

Self-Healing: The ArgoCD Application is configured with selfHeal: true. This means if any manual changes are made to the application's resources in the cluster, ArgoCD will automatically detect the drift and revert it, enforcing Git as the single source of truth.

Extending to More Environments: This single-environment pattern can be easily extended. For a dev -> stage -> prod lifecycle, we would create develop and staging branches. We would then create two more ArgoCD Application manifests: one watching the develop branch to deploy to a dev namespace, and another watching the staging branch to deploy to a staging namespace. The promotion between environments would be managed by pull requests between these Git branches.

you can find the ArgoCD application definition in the argo/ directory, inside the argo-app.yml file.

## 5. Bonus: Observability with Prometheus
To provide full observability into the running application, a complete monitoring stack was deployed.

Installation: The kube-prometheus-stack Helm chart was used to deploy Prometheus (for metrics collection) and Grafana (for visualization) into a dedicated monitoring namespace.

Persistence: The Prometheus deployment was configured with a PersistentVolumeClaim to ensure that all collected metrics data is stored safely on disk and survives any pod restarts.

Service Discovery: A ServiceMonitor resource was added to the application's Helm chart. This is the modern, standard way to declaratively tell the Prometheus Operator how to find and scrape the application's /metrics endpoint.

Prometheus and Statelessness: This setup perfectly complements the stateless application architecture. The application pods can be created and destroyed, and their internal metrics counters can reset without any data loss. Prometheus is the stateful component that scrapes this ephemeral data, aggregates it, and stores it long-term, providing a stable and accurate view of the entire system's health.

I have also provided a sample Grafana dashboard, which is located at grafana/.
