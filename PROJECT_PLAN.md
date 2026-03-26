# Anduril Cloud Infrastructure Engineer — Portfolio Project

## Project: SecureCloud Platform

A production-grade, security-hardened Azure infrastructure platform built to host a
**mission telemetry ingestion service** — a Python API that receives, stores, and serves
sensor/device data. The application is intentionally simple; the point is the security
posture around it: who can reach it, how it's deployed, what monitors it, and how changes
to it are gated.

This mirrors the real problem Anduril solves: protecting mission-critical data pipelines
where a misconfiguration isn't just a compliance finding — it's an operational risk.

**Timeline:** ~4 weeks (starting March 25, 2026)
**Repository:** `securecloud-platform` (public GitHub)

---

## What We're Building

```
[ Edge Device / Simulator ]
          |
          v (HTTPS, authenticated)
   [ Telemetry API (Python) ]     <-- the application
          |
          v
   [ Azure Database for PostgreSQL ]  <-- persistent store
          |
   [ AKS Cluster ]               <-- where the app runs
          |
   [ Private VNet ]              <-- network boundary
          |
   [ Defender for Cloud / Sentinel ]  <-- watching everything
          |
   [ GitHub Actions CI/CD ]      <-- the only way code ships
```

### The Telemetry API (Python)
A minimal REST service with three endpoints:
- `POST /telemetry` — ingest a sensor reading (authenticated via API key header)
- `GET /telemetry/{id}` — retrieve a stored reading
- `GET /health` — liveness probe for Kubernetes

The app itself is ~150 lines of Python. Everything else in this project is the infrastructure
and security controls protecting it. That's the story you tell in the interview:
*"The app is simple on purpose — I wanted every hour spent on this project to go toward
the security layer, not the business logic."*

---

## Resume Skills & Technologies (add after each phase)

| Phase | Skills to Add to Resume |
|-------|------------------------|
| 0 | Python, FastAPI, REST API design, Docker, containerization |
| 1 | Terraform, Azure VNet, NSGs, NAT Gateway, Network Watcher Flow Logs, Azure Blob Storage (remote state) |
| 2 | Azure Kubernetes Service (AKS), Kubernetes RBAC, Pod Security Standards, Network Policies, Kyverno, Workload Identity |
| 3 | Microsoft Defender for Cloud, Azure Policy, Azure Monitor, Azure Activity Log, Python (azure-sdk), Azure Functions |
| 4 | GitHub Actions, Checkov (IaC SAST), Trivy (container scanning), Gitleaks, SBOM generation, ACR (Azure Container Registry) |

**Core themes for resume bullet points:**
- Infrastructure as Code (IaC) — Terraform on Azure
- Cloud Security Posture Management (CSPM) — Defender for Cloud
- Kubernetes security hardening (AKS)
- Automated compliance and drift remediation — Azure Policy
- Secure software supply chain / CI/CD
- Azure networking (VNet, NSGs, NAT Gateway, routing)
- Python microservice development and containerization (FastAPI)

---

## Phase 0 — Telemetry API (Python)
**Before Week 1 | March 28**

Build the application first so every infrastructure decision has something real to protect.
This also gives the CI/CD pipeline a real container to scan and directly demonstrates the
Python scripting ability listed as a required qualification.

### Concepts
- FastAPI: modern Python REST framework with automatic OpenAPI docs
- SQLAlchemy + `asyncpg`: async PostgreSQL driver
- Pydantic: request/response validation and schema enforcement
- API key authentication via `X-API-Key` header middleware
- Multi-stage Dockerfile: build deps in one stage, run with `python:3.12-slim` (minimal image)
- `docker-compose` for local development

### Checklist
- [x] Initialize project: `requirements.txt` with FastAPI, SQLAlchemy, asyncpg, pydantic, uvicorn
- [x] Write Pydantic models: `TelemetryCreate` (input) and `TelemetryResponse` (output)
- [x] Write `POST /telemetry` route: validate body, insert row to DB, return created record
- [x] Write `GET /telemetry/{id}` route: fetch by UUID, return 404 if not found
- [x] Write `GET /health` route: return `{ "status": "ok" }`
- [x] Add API key middleware: reject requests missing `X-API-Key` header (except `/health`)
- [x] Write database schema: single `telemetry` table (`id`, `device_id`, `value`, `timestamp`, `created_at`)
- [x] Write multi-stage `Dockerfile`: install deps in builder stage, copy only needed files to slim final stage
- [x] Confirm image runs locally: `docker-compose up` + `curl` the endpoints
- [x] Write `docker-compose.yml` for local dev (api + postgres)

---

## Phase 1 — Secure Azure Networking Foundation
**Week 1 | April 1**

Build the network foundation using Terraform. This proves IaC proficiency, deep cloud
networking knowledge, and the "automate everything" mandate — all required qualifications.

### Concepts
- Terraform project structure (modules, remote state)
- Azure Resource Groups: logical containers for all resources (billing, RBAC, lifecycle)
- VNet design: public/private subnet segmentation
- NAT Gateway: outbound internet for private resources without inbound exposure
- Network Security Groups (NSGs): Azure's combined Security Group + NACL (stateful + subnet-level)
- NSG priority rules: lower number = evaluated first; default deny-all at 65500
- Network Watcher Flow Logs: full packet metadata audit trail → Log Analytics Workspace
- Azure Blob Storage: Terraform remote state backend (locking via blob lease — no separate table needed)

### Checklist
- [ ] Run `terraform/bootstrap`: create Storage Account + container for remote state
- [ ] Update `backend.tf` with the storage account name; run `terraform init`
- [ ] Create Resource Group, VNet (`10.0.0.0/16`)
- [ ] Create 3 public subnets + 3 private subnets
- [ ] Deploy NAT Gateway + public IP; associate with all private subnets
- [ ] Create app-tier NSG: allow port 8000 inbound from public subnets only; deny all else
- [ ] Create db-tier NSG: allow port 5432 inbound from private subnets only; deny all else
- [ ] Associate NSGs with private subnets
- [ ] Enable Network Watcher + NSG Flow Logs → Log Analytics Workspace (30-day retention)
- [ ] Run `terraform plan` — verify no unintended changes
- [ ] Tag all resources with Project, Environment, ManagedBy labels
- [ ] Write `README.md` for Phase 1 with architecture diagram (draw.io or mermaid)

---

## Phase 2 — Hardened AKS Cluster
**Week 2 | April 8**

Deploy a production-hardened Azure Kubernetes Service cluster and run the telemetry API on it.
AKS is the Azure equivalent of EKS — covering the preferred qualification directly.

### Concepts
- AKS with private cluster (no public API server endpoint)
- Azure CNI networking: pods get VNet IPs (unlike kubenet where pods are NAT'd)
- Workload Identity: pod-level Azure AD identity (replaces AWS IRSA concept)
- Kubernetes RBAC: least-privilege roles and service accounts
- Pod Security Standards (restricted mode)
- Kubernetes Network Policies: default-deny all, explicit allow rules
- Kyverno admission controller for policy-as-code
- Azure Database for PostgreSQL Flexible Server in private subnet

### Checklist
- [ ] Deploy AKS cluster via Terraform (`azurerm_kubernetes_cluster`) in private subnets
- [ ] Set `private_cluster_enabled = true` (no public API server)
- [ ] Enable Azure CNI; set pod subnet to private subnet range
- [ ] Enable Workload Identity + OIDC issuer on the cluster
- [ ] Disable default service account token automounting cluster-wide
- [ ] Apply Pod Security Standards: label namespaces with `enforce: restricted`
- [ ] Create RBAC roles: `cluster-admin` only for break-glass, `developer` role scoped to namespace
- [ ] Install Kyverno; write policies: block privileged containers, require resource limits, disallow `latest` image tag
- [ ] Write Network Policies: default-deny all ingress/egress per namespace, allow only necessary paths
- [ ] Deploy Azure Database for PostgreSQL Flexible Server in private subnet with private endpoint
- [ ] Deploy the telemetry API to AKS: `Deployment`, `Service`, `ConfigMap`, `Secret` (via Azure Key Vault CSI driver)
- [ ] Confirm end-to-end: `curl POST /telemetry` through the load balancer reaches the DB
- [ ] Run `kube-bench` against the cluster; document and remediate any FAIL findings
- [ ] Update `README.md` with AKS security architecture section

---

## Phase 3 — Security Monitoring & Automated Remediation
**Week 3 | April 15**

Add detection and response using Azure-native security services plus a Python Azure Function
for automated remediation. Demonstrates CSPM, threat detection, and programming ability.

### Concepts
- Microsoft Defender for Cloud: CSPM + threat protection (equivalent of GuardDuty + Security Hub)
- Azure Policy: continuous compliance evaluation and drift detection (equivalent of AWS Config)
- Azure Activity Log: full control-plane audit trail (equivalent of CloudTrail)
- Log Analytics Workspace: central log aggregation and query (equivalent of CloudWatch Logs)
- Azure Functions + azure-sdk (Python): serverless automated remediation
- Azure Monitor Alerts: trigger on policy violations or Defender findings

### Checklist
- [ ] Enable Microsoft Defender for Cloud on the subscription (all resource types)
- [ ] Enable the CIS Azure Foundations Benchmark in Defender for Cloud
- [ ] Enable Azure Activity Log diagnostic settings → Log Analytics Workspace
- [ ] Assign built-in Azure Policy: deny NSGs that allow port 22 inbound from `*`
- [ ] Write Python Azure Function: triggered by Azure Monitor alert when Policy finds a violation; auto-remediate by removing the offending NSG rule
- [ ] Create Azure Monitor Alert rule: fire on any HIGH/CRITICAL Defender recommendation
- [ ] Write Python script (`audit_identity.py`) using azure-sdk: report service principals with Owner role, identities with no activity in 90 days, missing MFA enforcement
- [ ] Deploy all monitoring config via Terraform; no manual portal changes
- [ ] Update `README.md` with monitoring architecture and sample findings

---

## Phase 4 — Secure CI/CD Pipeline & Supply Chain
**Week 4 | April 22**

Build a GitHub Actions pipeline that enforces security gates on every PR and push.

### Concepts
- GitHub Actions: pipeline as code
- Checkov: static analysis of Terraform for misconfigurations (IaC SAST)
- Trivy: container image vulnerability scanning
- Gitleaks: secret detection in git history and commits
- SBOM (Software Bill of Materials): `syft` for supply chain visibility
- OIDC-based Azure auth in CI (no long-lived credentials in secrets)
- Azure Container Registry (ACR): private image registry
- Branch protection rules: require passing checks before merge

### Checklist
- [ ] Create `.github/workflows/terraform-security.yml`: run Checkov on all Terraform on every PR; fail on HIGH/CRITICAL findings
- [ ] Create `.github/workflows/secrets-scan.yml`: run Gitleaks on every push; block merge on detected secrets
- [ ] Create `.github/workflows/container-scan.yml`: build the telemetry API image, run Trivy scan, fail on CRITICAL CVEs
- [ ] Configure GitHub OIDC → Azure AD federated credential (no `AZURE_CLIENT_SECRET` in repo secrets)
- [ ] Create Azure Container Registry (ACR); on green scan push image to ACR and deploy to AKS via `kubectl rollout`
- [ ] Generate SBOM for the telemetry API image using `syft`; upload as pipeline artifact
- [ ] Add branch protection rules: require PR review + all status checks passing before merge to `main`
- [ ] Add `pre-commit` hooks: `terraform fmt`, `terraform validate`, `checkov`, `gitleaks`
- [ ] Document supply chain controls in `README.md` (maps to CMMC/FedRAMP awareness)
- [ ] Final review: `terraform plan` clean, all pipeline checks green, no findings unaddressed

---

## Final Deliverables (end of month)

- [ ] Public GitHub repo with clean commit history showing incremental progress
- [ ] Architecture diagram covering all 4 phases
- [ ] Top-level `README.md` summarizing the project, threat model addressed, and design decisions
- [ ] Cost estimate section (shows operational awareness)
- [ ] `SECURITY.md` documenting the controls implemented and why

---

## Talking Points for the Interview

| What you built | How it maps to Anduril's JD |
|---|---|
| Telemetry ingestion API in Python (FastAPI), containerized | "Solid programming/scripting ability in Python" + real workload to protect |
| Azure VNet with public/private subnets, NSGs, NAT Gateway, flow logs | "Firm understanding of public cloud networking principles" |
| Terraform modules with Azure Blob remote state | "Strong hands-on experience with IaC" |
| AKS private cluster + RBAC + Kyverno + Workload Identity | "Experience hardening and monitoring Kubernetes clusters (AKS)" |
| Defender for Cloud + Azure Policy | "Cloud security posture management (CSPM) or threat detection tooling" |
| Python Azure Function auto-remediation | "Solid programming/scripting ability in Python" |
| GitHub Actions + Checkov + Trivy + OIDC + ACR deploy | "Familiarity with CI/CD pipelines and securing the software supply chain" |
| CIS Azure Benchmark + SBOM + SSDF controls | "Knowledge of compliance frameworks (FedRAMP, SOC 2, CMMC)" |
