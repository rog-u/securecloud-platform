# Anduril Cloud Infrastructure Engineer — Portfolio Project

## Project: SecureCloud Platform

A production-grade, security-hardened Azure infrastructure platform built to host a
**mission telemetry ingestion service** — a Python API that receives, stores, and serves
sensor/device data. The application is intentionally simple; the point is the security
posture around it: who can reach it, how it's deployed, what monitors it, and how changes
to it are gated.

This mirrors the real problem Anduril solves: protecting mission-critical data pipelines
where a misconfiguration isn't just a compliance finding — it's an operational risk.

**Repository:** `securecloud-platform` (public GitHub)

---

## What We're Building

```
[ Edge Device / Simulator ]
          |
          v (HTTPS, authenticated)
   [ Application Gateway (public subnets) ]   <-- ingress, AGIC-managed routing
          |
          v (port 8000, NSG-gated)
   [ AKS Cluster (private subnets) ]          <-- telemetry API pods
          |
          v (port 5432, K8s service)
   [ PostgreSQL StatefulSet (AKS) ]           <-- Azure Disk PVC (persistent, POSIX-safe)
          |
   [ Private VNet ]                            <-- network boundary
          |
   [ Defender for Cloud / Azure Policy ]       <-- watching everything
          |
   [ GitHub Actions CI/CD ]                    <-- the only way code ships
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
| 1 | Terraform, Azure VNet, NSGs, NAT Gateway, VNet Flow Logs, Log Analytics, Azure Blob Storage (remote state) |
| 2a | Azure Kubernetes Service (AKS), Azure CNI, Azure Container Registry (ACR), Application Gateway Ingress Controller (AGIC), Kubernetes StatefulSet, Kubernetes PersistentVolumeClaim, Azure Disk (managed-csi), PostgreSQL containerization |
| 2b | Kubernetes RBAC, Pod Security Standards, Network Policies, Kyverno, Workload Identity, Key Vault CSI Driver, kube-bench |
| 3 | Microsoft Defender for Cloud, Azure Policy, Azure Monitor, Azure Activity Log, Python (azure-sdk), Azure Functions |
| 4 | GitHub Actions, Checkov (IaC SAST), Trivy (container scanning), Gitleaks, SBOM generation, OIDC federated credentials |

**Core themes for resume bullet points:**
- Infrastructure as Code (IaC) — Terraform on Azure
- Cloud Security Posture Management (CSPM) — Defender for Cloud
- Kubernetes security hardening (AKS)
- Automated compliance and drift remediation — Azure Policy
- Secure software supply chain / CI/CD
- Azure networking (VNet, NSGs, NAT Gateway, private endpoints)
- Python microservice development and containerization (FastAPI)

---

## Phase 0 — Telemetry API (Python) [COMPLETE]

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

## Phase 1 — Secure Azure Networking Foundation [COMPLETE]

Build the network foundation using Terraform. This proves IaC proficiency, deep cloud
networking knowledge, and the "automate everything" mandate — all required qualifications.

### Concepts
- Terraform project structure (modules, remote state, provider versioning)
- Azure Resource Groups: logical containers for all resources (billing, RBAC, lifecycle)
- VNet design: public/private subnet segmentation
- NAT Gateway: outbound internet for private resources without inbound exposure
- Network Security Groups (NSGs): Azure's combined Security Group + NACL (stateful + subnet-level)
- NSG priority rules: lower number = evaluated first; default deny-all at 65500
- VNet Flow Logs: full packet metadata audit trail → Log Analytics Workspace (replaced NSG flow logs, which Azure retired June 2025)
- Azure Blob Storage: Terraform remote state backend (locking via blob lease — no separate table needed)

### Checklist
- [x] Run `terraform/bootstrap`: create Storage Account + container for remote state
- [x] Update `backend.tf` with the storage account name; run `terraform init`
- [x] Create Resource Group, VNet (`10.0.0.0/16`)
- [x] Create 3 public subnets + 3 private subnets
- [x] Create dedicated postgres subnet with delegation to Azure Container Instances
- [x] Deploy NAT Gateway + public IP; associate with all private subnets + postgres subnet
- [x] Create app-tier NSG: allow port 8000 inbound from public subnets only; deny all else
- [x] Create db-tier NSG: allow port 5432 inbound from private subnets only; deny all else
- [x] Associate NSGs with private subnets and postgres subnet
- [x] Enable VNet Flow Logs → Storage Account → Traffic Analytics → Log Analytics Workspace (30-day retention)
- [x] Upgrade azurerm provider 3.x → 4.x (required for VNet flow logs; NSG flow log creation blocked by Azure June 2025)
- [x] Tag all resources with Project, Environment, ManagedBy labels
- [x] Run `terraform plan` — verify no unintended changes

### Key Decisions Made
- azurerm provider upgraded from ~3.0 to ~4.0 mid-build (breaking change: `subscription_id` now required in provider block)
- VNet flow logs instead of NSG flow logs (Azure blocked new NSG flow log creation June 30, 2025)
- Data source on existing `NetworkWatcher_eastus2` (Azure allows only 1 Network Watcher per region)
- `prevent_deletion_if_contains_resources = false` in provider features (Traffic Analytics auto-creates data collection resources that block RG deletion)
- PostgreSQL subnet delegated to `Microsoft.ContainerInstance/containerGroups` for ACI deployment (Phase 2a preparation)

---

## Phase 2a — AKS Cluster + Deploy App [COMPLETE]

Deploy AKS, stand up the database, and get the telemetry API running end-to-end.
Focus is on a working deployment — security hardening comes in Phase 2b.

### Concepts
- AKS with private cluster (API server not exposed to internet)
- Azure CNI networking: pods get VNet IPs directly (unlike kubenet where pods are NAT'd behind the node IP)
- Azure Container Registry (ACR): private image registry, integrated with AKS via managed identity
- Application Gateway Ingress Controller (AGIC): Azure-native L7 ingress add-on; watches Kubernetes Ingress objects and rewrites App Gateway routing rules automatically. Requires Reader on RG + Contributor on App Gateway + Network Contributor on App Gateway subnet — all managed via Terraform role assignments.
- Kubernetes StatefulSet: the standard K8s primitive for stateful workloads; each pod gets a stable identity and a dedicated persistent volume
- PersistentVolumeClaim (PVC) backed by Azure Disk (`managed-csi`): Azure Disk is a block device (ext4) and supports POSIX file ownership — required by PostgreSQL. Azure Files (SMB) does not support POSIX ownership and cannot be used for PostgreSQL data directories.
- Kubernetes Secrets: credentials stored in cluster (upgrade to Key Vault in Phase 2b)
- Multi-platform Docker builds: AKS nodes are AMD64; Mac Apple Silicon is ARM64 — images must be built with `--platform linux/amd64`

### Key Decisions & Issues Resolved
- **ACI → StatefulSet migration**: PostgreSQL was initially deployed as Azure Container Instance with Azure Files storage. Azure Files (SMB) does not support POSIX `chown` — PostgreSQL crashed with `wrong ownership` on the data directory. Replaced with a K8s StatefulSet + Azure Disk PVC which supports proper POSIX permissions.
- **AGIC role assignments missing**: AGIC's managed identity was not granted Azure RBAC permissions on deploy, causing 403 crash loops and an empty App Gateway backend pool. Added three `azurerm_role_assignment` resources to the AKS Terraform module so they are created automatically on every deploy.
- **ARM64 image**: `docker pull postgres:16-alpine` on Apple Silicon pulls the ARM variant. AKS nodes are x86_64. Fix: `docker buildx build --platform linux/amd64`.
- **NSG blocking postgres**: Added inbound rule on the db-tier NSG allowing port 5432 from the AKS subnet CIDR.

### Checklist
- [x] Create Terraform module `modules/aks/` for the AKS cluster
- [x] Deploy AKS cluster (`azurerm_kubernetes_cluster`) in private subnets with `private_cluster_enabled = true`
- [x] Enable Azure CNI networking; pods get real VNet IPs
- [x] Create Azure Container Registry (ACR) via Terraform; attach to AKS via kubelet managed identity (AcrPull)
- [x] Build and push telemetry API image to ACR (`--platform linux/amd64`)
- [x] Push `postgres:16-alpine` (AMD64) to ACR
- [x] Deploy Application Gateway in public subnets; enable AGIC add-on on AKS
- [x] Add AGIC role assignments to Terraform: Reader (RG), Contributor (App Gateway), Network Contributor (App Gateway subnet)
- [x] Write Kubernetes manifests: `Deployment`, `Service`, `Ingress` for the telemetry API
- [x] Deploy PostgreSQL as Kubernetes StatefulSet with Azure Disk PVC (10Gi, `managed-csi`)
- [x] Create Kubernetes Service for postgres (ClusterIP, port 5432)
- [x] Store credentials in Kubernetes Secret (`DATABASE_URL`, `API_KEY`, `POSTGRES_USER`, `POSTGRES_PASSWORD`)
- [x] Confirm end-to-end: `curl http://20.109.156.186/health` → `{"status":"ok"}`
- [x] Verify NAT Gateway handles pod outbound traffic

---

## Phase 2b — Kubernetes Security Hardening

Lock down the cluster. Every item here is a security control you can discuss in the interview.

### Concepts
- Workload Identity: pod-level Azure AD identity (replaces stored credentials; Azure equivalent of AWS IRSA)
- Key Vault CSI Driver: mount Azure Key Vault secrets as files in pods (no secrets in etcd)
- Kubernetes RBAC: least-privilege roles and service accounts
- Pod Security Standards (restricted mode): blocks privileged containers, host networking, etc.
- Kubernetes Network Policies: microsegmentation at the pod level (default-deny + explicit allow)
- Kyverno: admission controller for policy-as-code (block `latest` tags, require resource limits, etc.)
- kube-bench: CIS Kubernetes Benchmark scanner

### Checklist
- [ ] Enable Workload Identity + OIDC issuer on the AKS cluster
- [ ] Migrate database credentials from Kubernetes Secret → Azure Key Vault + CSI Driver (PostgreSQL container credentials)
- [ ] Create federated identity credential for the telemetry API service account
- [ ] Disable default service account token automounting cluster-wide
- [ ] Apply Pod Security Standards: label the telemetry namespace with `enforce: restricted`
- [ ] Create RBAC roles: `cluster-admin` only for break-glass, `developer` role scoped to telemetry namespace
- [ ] Write Network Policies: default-deny all ingress/egress in telemetry namespace, then allow only: ingress from AGIC on port 8000, egress to PostgreSQL on port 5432, egress to DNS on port 53
- [ ] Install Kyverno via Helm; write policies: block privileged containers, require resource limits, disallow `latest` image tag, require `readOnlyRootFilesystem`
- [ ] Run `kube-bench` against the cluster; document findings and remediate any FAILs
- [ ] Verify end-to-end still works after all hardening (no broken connectivity)

---

## Phase 3 — Security Monitoring & Automated Remediation

Add detection and response using Azure-native security services plus Python automation.
Demonstrates CSPM, threat detection, and programming ability.

### Concepts
- Microsoft Defender for Cloud: CSPM + threat protection (equivalent of GuardDuty + Security Hub)
- Defender for Containers: runtime threat detection for AKS (malicious exec, crypto mining, etc.)
- Azure Policy: continuous compliance evaluation and drift detection (equivalent of AWS Config)
- Azure Activity Log: full control-plane audit trail (equivalent of CloudTrail)
- Log Analytics Workspace: central log aggregation and KQL queries (already deployed in Phase 1)
- Azure Functions + azure-sdk (Python): serverless automated remediation
- Azure Monitor Alerts: trigger on policy violations or Defender findings

### Checklist
- [ ] Enable Microsoft Defender for Cloud on the subscription (Servers, Containers, Key Vault, Storage, DNS plans)
- [ ] Enable Defender for Containers on the AKS cluster (runtime threat detection)
- [ ] Enable the CIS Azure Foundations Benchmark initiative in Defender for Cloud
- [ ] Configure Azure Activity Log diagnostic settings → Log Analytics Workspace
- [ ] Assign built-in Azure Policies via Terraform:
  - Deny NSGs that allow port 22 inbound from `*`
  - Deny public IP creation (except in designated public subnets)
  - Require TLS 1.2 minimum on storage accounts
  - Deny AKS clusters without Network Policy enabled
- [ ] Write Python Azure Function: triggered by Azure Monitor alert when Policy detects a non-compliant NSG; auto-remediates by removing the offending rule via azure-sdk
- [ ] Create Azure Monitor Alert rules: fire on HIGH/CRITICAL Defender recommendations and Policy non-compliance events
- [ ] Write Python script (`audit_identity.py`) using azure-sdk: report service principals with Owner role, identities with no activity in 90 days, app registrations with expiring credentials
- [ ] Write sample KQL queries for the Log Analytics Workspace: top denied flows, top talkers, anomalous traffic patterns
- [ ] Deploy all monitoring config via Terraform; no manual portal changes

---

## Phase 4 — Secure CI/CD Pipeline & Supply Chain

Build a GitHub Actions pipeline that enforces security gates on every PR and push.
The pipeline is the only path code takes to production — no `kubectl apply` from laptops.

### Concepts
- GitHub Actions: pipeline as code (build → scan → push → deploy)
- OIDC-based Azure auth in CI (federated credential — no long-lived `AZURE_CLIENT_SECRET` in repo secrets)
- Checkov: static analysis of Terraform for misconfigurations (IaC SAST)
- Trivy: container image vulnerability scanning
- Gitleaks: secret detection in git history and commits
- SBOM (Software Bill of Materials): `syft` for supply chain visibility
- Branch protection rules: require passing checks before merge

### Checklist
- [ ] Configure GitHub OIDC → Azure AD federated credential for the CI service principal
- [ ] Create `.github/workflows/ci.yml` — single pipeline with stages:
  - **Lint & Validate:** `terraform fmt -check`, `terraform validate`
  - **IaC Security:** Checkov scan on all Terraform; fail on HIGH/CRITICAL
  - **Secrets Scan:** Gitleaks on push; block merge on detected secrets
  - **Container Build & Scan:** build image, Trivy scan, fail on CRITICAL CVEs
  - **Push to ACR:** on green scan, push tagged image to ACR
  - **Deploy to AKS:** rolling update via `kubectl set image` (or Helm upgrade)
- [ ] Generate SBOM for the telemetry API image using `syft`; upload as pipeline artifact
- [ ] Add branch protection rules on `main`: require PR review + all status checks passing before merge
- [ ] Add `pre-commit` hooks: `terraform fmt`, `terraform validate`, `checkov`, `gitleaks`
- [ ] Document supply chain controls in `README.md` (maps to CMMC/FedRAMP awareness)
- [ ] Final review: `terraform plan` clean, all pipeline checks green, no findings unaddressed

---

## Final Deliverables

- [ ] Public GitHub repo with clean commit history showing incremental progress
- [ ] Architecture diagram covering all phases (mermaid or draw.io)
- [ ] Top-level `README.md` summarizing the project, threat model addressed, and design decisions
- [ ] Cost estimate section (shows operational awareness)
- [ ] `SECURITY.md` documenting every control implemented and why

---

## Talking Points for the Interview

| What you built | How it maps to Anduril's JD |
|---|---|
| Telemetry ingestion API in Python (FastAPI), containerized | "Solid programming/scripting ability in Python" + real workload to protect |
| Azure VNet with public/private subnets, NSGs, NAT Gateway, VNet flow logs | "Firm understanding of public cloud networking principles" |
| Terraform modules with Azure Blob remote state, provider upgrades | "Strong hands-on experience with IaC" |
| AKS private cluster + Azure CNI + AGIC + private endpoints | "Experience hardening and monitoring Kubernetes clusters (AKS)" |
| Workload Identity + Key Vault CSI + RBAC + Network Policies + Kyverno | "Kubernetes security hardening" at depth |
| Defender for Cloud + Azure Policy + automated remediation | "Cloud security posture management (CSPM) or threat detection tooling" |
| Python Azure Function auto-remediation + audit_identity.py | "Solid programming/scripting ability in Python" (security automation) |
| GitHub Actions + Checkov + Trivy + OIDC + ACR deploy | "Familiarity with CI/CD pipelines and securing the software supply chain" |
| CIS Azure Benchmark + SBOM + SSDF controls | "Knowledge of compliance frameworks (FedRAMP, SOC 2, CMMC)" |
