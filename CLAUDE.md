# SecureCloud Platform — Project Context

Portfolio project targeting Anduril Cloud Infrastructure Engineer (Security) role.
A security-hardened Azure platform hosting a Python telemetry ingestion API.
The app is intentionally simple — all effort goes into the security layer.

## Stack
- **App:** Python 3.12, FastAPI, SQLAlchemy async, asyncpg, PostgreSQL
- **IaC:** Terraform (azurerm provider ~4.0), remote state in Azure Blob Storage
- **Cloud:** Azure (eastus2) — switching from AWS mid-build
- **Future:** AKS, Defender for Cloud, Azure Policy, GitHub Actions CI/CD

## Repo Structure
```
app/                    FastAPI telemetry API (Phase 0 — DONE)
  main.py               Routes: POST /telemetry, GET /telemetry/{id}, GET /health
  models.py             Pydantic + SQLAlchemy models
  database.py           Async engine, session dep, init_db()
terraform/
  bootstrap/            Run ONCE first — creates Azure Blob state backend
  backend.tf            Storage account: sctfstate7608358f1d574d (securecloud-tfstate-rg)
  modules/network/      VNet, subnets, NSGs, NAT GW, flow logs, Log Analytics
Dockerfile              Multi-stage, non-root user (python:3.12-slim)
docker-compose.yml      Local dev: api + postgres
PROJECT_PLAN.md         Full phase checklist with concepts and resume skills
```

## Azure Resources (eastus2)
- Resource Group: `securecloud-dev-rg`
- VNet: `10.0.0.0/16`, 3 public + 3 private subnets
- NAT Gateway for private subnet egress
- NSG app tier: port 8000 from public subnets only
- NSG db tier: port 5432 from private subnets only
- VNet flow logs → Log Analytics Workspace (data source: NetworkWatcher_eastus2 in NetworkWatcherRG; NSG flow logs retired by Azure June 2025)
- Terraform state: `securecloud-tfstate-rg` / storage account `sctfstate7608358f1d574d` / container `tfstate`

## Phase Status
- [x] Phase 0 — Python API (working locally via docker-compose)
- [x] Phase 1 — Azure networking (Terraform apply complete)
- [ ] Phase 2 — AKS cluster + deploy app
- [ ] Phase 3 — Defender for Cloud, Azure Policy, flow logs, Python remediation
- [ ] Phase 4 — GitHub Actions CI/CD, Checkov, Trivy, Gitleaks, ACR

## Key Decisions
- Azure over AWS (both in Anduril JD; user prefers Azure)
- Single NAT Gateway (dev cost saving; production would be zone-redundant)
- Flow logs via data source on existing NetworkWatcher_eastus2 (Azure allows only 1 per region)
- App auth: X-API-Key header (simple; upgrade to managed identity in Phase 2)

## Run Order
```bash
# Local dev
docker-compose up --build

# Bootstrap (once)
cd terraform/bootstrap && terraform init && terraform apply

# Infrastructure
cd terraform && terraform init && terraform apply
```
