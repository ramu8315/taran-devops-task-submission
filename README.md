# TaranDM Score API — DevOps Take-Home

This solution containerizes and deploys the supplied TaranDM Score API to Kubernetes using **Docker, Helm, Terraform and Minikube**.

The supplied `app/` directory is intentionally unchanged.

## 1. Solution Overview

```text
                         Minikube
                            |
                       NGINX Ingress
                            |
                            v
                     score-api Service
                            |
                            v
                    score-api Deployment
                            |
                            v
                       Score API
                            |
                            v
                   Kubernetes Secret
                    score-api-auth

Terraform
   ├── Namespace
   ├── Kubernetes Secret
   └── Helm Release

Helm
   ├── Deployment
   ├── Service
   ├── Ingress
   ├── Probes
   ├── Resources
   └── Environment configuration
```

### Request flow

```text
curl
  |
  v
Ingress
  |
  v
Service
  |
  v
Score API Pod :8080
```

---

## 2. Repository Structure

```text
taran-devops-task-submission/
├── README.md                  # Project overview and deployment instructions
├── TOOLS_INSTALL.md           # Required tools installation and verification
├── EXECUTION_LOG.md           # Successful deployment and verification evidence
├── TASK.md                    # Original assignment requirements
│
├── app/                       # Provided Score API application
│   ├── Dockerfile             # Application container image
│   ├── pyproject.toml         # Python project configuration
│   ├── uv.lock                # Dependency lock file
│   └── score_api/             # Score API source code
│
├── helm/
│   └── score-api/             # Custom Helm chart
│       ├── Chart.yaml
│       ├── values.yaml        # Configurable deployment values
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── serviceaccount.yaml
│           └── _helpers.tpl
│
├── terraform/                 # Infrastructure and deployment automation
│   ├── main.tf                # Namespace, Secret and Helm release
│   ├── variables.tf           # Terraform input variables
│   ├── providers.tf           # Kubernetes/Helm providers
│   ├── versions.tf            # Terraform/provider versions
│   └── outputs.tf             # Terraform outputs
│
└── scripts/
    ├── deploy.sh              # End-to-end deployment and verification
    └── clean.sh               # Removes deployment and resets local environment
```

---

## 3. Prerequisites

Required tools:

```text
Docker
Minikube
kubectl
Helm
Terraform
curl
python3
base64
```

Installation and version verification:

**[`TOOLS_INSTALL.md`](TOOLS_INSTALL.md)**

Verify the tools:

```bash
docker --version
minikube version
kubectl version --client
helm version
terraform version
curl --version
python3 --version
base64 --version
```

---

## 4. End-to-End Deployment

From the repository root:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script securely prompts for:

```text
BASIC_AUTH_PASSWORD
```

The password is **not stored in `values.yaml` or committed to Git**.

### `deploy.sh` performs

1. Checks required tools.
2. Starts Minikube if required.
3. Enables the NGINX Ingress addon.
4. Builds `score-api:local`.
5. Loads the image into Minikube.
6. Runs `helm lint`.
7. Runs Terraform `init` and `validate`.
8. Creates the Kubernetes namespace and Secret and installs the Helm release.
9. Verifies the Kubernetes Secret.
10. Restarts the Deployment to load the current Secret value.
11. Waits for the Deployment rollout.
12. Verifies the Pod received the Secret.
13. Waits for the Ingress controller.
14. Tests `GET /healthz`.
15. Tests authenticated `POST /decision`.
16. Validates the API response.

A successful run ends with:

```text
============================================================
SUCCESS: Score API deployed and verified successfully.
============================================================
```

---

## 5. Manual Verification

### Kubernetes resources

```bash
kubectl get all -n score-api
kubectl get secret -n score-api
kubectl get ingress -n score-api
kubectl get endpoints score-api -n score-api
```

Verify the Pod:

```bash
kubectl get pods -n score-api
```

Expected:

```text
READY   STATUS
1/1     Running
```

Verify the Deployment:

```bash
kubectl rollout status deployment/score-api -n score-api
```

---

## 6. API Verification

Get the Minikube IP:

```bash
MINIKUBE_IP=$(minikube ip)
```

### Health check

```bash
curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

Expected:

```json
{"status":"ok","version":"local"}
```

### Decision API

Enter the password used during deployment:

```bash
read -r -s -p "Enter BASIC_AUTH_PASSWORD: " PASSWORD
echo
```

Call the API:

```bash
curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  -u "score:${PASSWORD}" \
  -H "Content-Type: application/json" \
  http://score-api.local/decision \
  -d '{"client_id":"CL-0001","amount":1500}'
```

Expected response shape:

```json
{
  "decision_id": "...",
  "client_id": "CL-0001",
  "amount": 1500.0,
  "score": 0.1712,
  "decision": "APPROVE",
  "state": "FINISHED"
}
```

The exact `decision_id` and score may vary.

Clean up the password variable:

```bash
unset PASSWORD
```

---

## 7. Authentication Verification

`/decision` requires Basic Authentication.

Username:

```text
score
```

Password:

```text
BASIC_AUTH_PASSWORD
```

An invalid password should return:

```text
401 Unauthorized
```

Example:

```bash
curl -i \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  -u "score:incorrect-password" \
  -H "Content-Type: application/json" \
  http://score-api.local/decision \
  -d '{"client_id":"CL-0001","amount":1500}'
```

---

## 8. Key Design Decisions

### Secret Management

The password is managed by Terraform as a Kubernetes Secret and injected into the Pod using `secretKeyRef`.

```text
Runtime password
      |
      v
Terraform
      |
      v
Kubernetes Secret
      |
      v
Pod environment
      |
      v
BASIC_AUTH_PASSWORD
```

The password is not a Helm value.

### Helm

Helm manages application resources and configuration:

* Deployment
* Service
* Ingress
* Probes
* Resources
* Environment configuration
* ServiceAccount

### Terraform

Terraform manages infrastructure wiring:

* Namespace
* Kubernetes Secret
* Helm release

### Local Image

The application is built locally as:

```text
score-api:local
```

and loaded into Minikube. `IfNotPresent` prevents an unnecessary registry pull.

### Health Checks

Both liveness and readiness probes use:

```text
GET /healthz
```

---

## 9. Security and Kubernetes Configuration

The Deployment includes basic container hardening:

```text
runAsNonRoot: true
runAsUser: 1000
allowPrivilegeEscalation: false
capabilities: drop ALL
automountServiceAccountToken: false
```

CPU and memory requests/limits are also defined in the Helm chart.

---

## 10. Execution Evidence

A successful deployment execution log is provided separately:

**[`EXECUTION_LOG.md`](EXECUTION_LOG.md)**

It contains the actual deployment and verification output for reviewer reference.

Sensitive credentials are excluded or masked.

---

## 11. Production Considerations

For production deployment, the following would be considered:

* HTTPS/TLS
* NetworkPolicies
* External Secret Management
* Image vulnerability scanning and signing
* SBOM
* HPA and PodDisruptionBudget
* Centralized monitoring and logging
* Remote encrypted Terraform state
* CI/CD security and approval gates

These are outside the minimum scope of this take-home exercise.

---

## 12. Quick Start

For a reviewer who already has the prerequisites installed:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Enter the password when prompted.

The script performs the deployment and validates:

```text
Helm
  ↓
Terraform
  ↓
Kubernetes
  ↓
Ingress
  ↓
/healthz       PASS
  ↓
/decision      PASS
```

**Result: TaranDM Score API deployed and end-to-end verified.**

## 13. Cleanup / Reset

`scripts/clean.sh` provides a clean reset of the local TaranDM environment before a fresh deployment.

When executed, it removes:

* Existing **Helm release** (`score-api`)
* **Terraform-managed resources**, including the Kubernetes Secret and Helm release
* Kubernetes **`score-api` namespace** and any remaining resources
* Local **Terraform state and `.terraform` cache**
* Existing **Minikube cluster**

The Terraform provider lock file (`.terraform.lock.hcl`) is preserved.

Run:

```bash
chmod +x scripts/clean.sh
./scripts/clean.sh
```

After cleanup, perform a fresh deployment:

```bash
./scripts/deploy.sh
```

> **Note:** `clean.sh` is intended for local testing and reproducibility. It is not required for the normal deployment workflow.
