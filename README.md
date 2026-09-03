# TaranDM Score API — DevOps Take-Home

This repository packages the provided Score API as a configurable Helm release, provisions its
Kubernetes Secret with Terraform, and deploys/verifies the result on a fresh Minikube cluster.

The supplied `app/` directory is intentionally left unchanged.

## Architecture

```text
                         +----------------------+
                         |      Minikube        |
                         |                      |
curl --> Ingress ------> | Service              |
                         |    |                 |
                         |    v                 |
                         | Deployment            |
                         |    |                 |
                         |    v                 |
                         | Score API             |
                         |    |                 |
                         |    +--> Secret        |
                         +----------------------+

Terraform
  ├── creates namespace
  ├── creates score-api-auth Secret
  └── installs Helm chart

Helm
  ├── Deployment
  ├── Service
  ├── Ingress
  ├── probes
  ├── resources
  └── configurable environment
```

## Prerequisites

The assignment expects:

- Docker
- Minikube
- kubectl
- Helm
- Terraform
- curl

Absolutely. Since the assignment explicitly requires **Docker, Minikube, kubectl, Helm, Terraform, and curl**, I recommend installing and validating them in this order.

The commands below are for a typical **Ubuntu 22.04/24.04 server**.

## 1. Update Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
```

Install basic utilities:

```bash
sudo apt install -y \
  curl \
  wget \
  git \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https
```

Validate:

```bash
curl --version
git --version
unzip -v | head -1
```

---

# 2. Install Docker

### Remove conflicting old packages

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
```

### Add Docker repository

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker:

```bash
sudo apt update

sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

### Enable Docker

```bash
sudo systemctl enable --now docker
```

Check:

```bash
sudo systemctl status docker --no-pager
```

You want:

```text
Active: active (running)
```

### Test Docker

```bash
sudo docker run --rm hello-world
```

You should see:

```text
Hello from Docker!
```

### Allow your user to run Docker without sudo

```bash
sudo usermod -aG docker "$USER"
```

Then:

```bash
newgrp docker
```

Test:

```bash
docker version
docker run --rm hello-world
```

You should now be able to use Docker without `sudo`.

---

# 3. Install kubectl

Download the latest stable kubectl:

```bash
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
```

Install:

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Remove downloaded file:

```bash
rm kubectl
```

Validate:

```bash
kubectl version --client
```

You should get something like:

```text
Client Version: v1.xx.x
```

Also:

```bash
kubectl --help >/dev/null && echo "kubectl OK"
```

---

# 4. Install Minikube

Download the latest Minikube binary:

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

Install:

```bash
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

Remove downloaded file:

```bash
rm minikube-linux-amd64
```

Validate:

```bash
minikube version
```

You should see:

```text
minikube version: v...
```

### Start Minikube using Docker

Because Docker is already installed:

```bash
minikube start --driver=docker
```

Check:

```bash
minikube status
```

Expected:

```text
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

Check Kubernetes:

```bash
kubectl get nodes
```

Expected:

```text
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   ...   v1.xx.x
```

---

# 5. Install Helm

Add the Helm repository:

```bash
curl https://baltocdn.com/helm/signing.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
```

```bash
sudo apt-get install -y apt-transport-https --no-install-recommends
```

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
```

Install:

```bash
sudo apt update
sudo apt install -y helm
```

Validate:

```bash
helm version
```

You should see:

```text
version.BuildInfo{Version:"v3...."}
```

Check Helm can communicate with Kubernetes:

```bash
helm list -A
```

It is fine if this returns no releases.

---

# 6. Install Terraform

Add HashiCorp repository:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
```

```bash
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
```

Install:

```bash
sudo apt update
sudo apt install -y terraform
```

Validate:

```bash
terraform version
```

Expected:

```text
Terraform v1.x.x
on linux_amd64
```

---

# 7. Validate curl

You already installed it in Step 1.

Run:

```bash
curl --version
```

Then test internet connectivity:

```bash
curl -I https://www.google.com
```

You should receive an HTTP response such as:

```text
HTTP/2 200
```

---

# 8. Final prerequisite validation

This is the **most important step**.

Run:

```bash
echo "===== Docker ====="
docker --version

echo "===== Minikube ====="
minikube version

echo "===== kubectl ====="
kubectl version --client

echo "===== Helm ====="
helm version --short

echo "===== Terraform ====="
terraform version

echo "===== curl ====="
curl --version | head -1
```

You should have all six:

```text
Docker       ✅
Minikube     ✅
kubectl      ✅
Helm         ✅
Terraform    ✅
curl         ✅
```

---

# 9. Validate that the tools actually work together

Don't stop at version checks. For your assignment, run these:

### Docker

```bash
docker run --rm hello-world
```

### Minikube

```bash
minikube status
```

### Kubernetes

```bash
kubectl get nodes
```

Expected:

```text
minikube   Ready
```

### Helm → Kubernetes

```bash
helm list -A
```

### Terraform

```bash
terraform -help >/dev/null && echo "Terraform OK"
```

### curl

```bash
curl -I https://example.com
```

---

# 10. Enable Minikube Ingress

Your assignment requires the application to be accessed through **Ingress**, so enable it now:

```bash
minikube addons enable ingress
```

Check:

```bash
kubectl get pods -n ingress-nginx
```

Wait until the controller is running:

```bash
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=available \
  deployment/ingress-nginx-controller \
  --timeout=180s
```

Expected:

```text
deployment.apps/ingress-nginx-controller condition met
```

Then:

```bash
minikube ip
```

You should get something like:

```text
192.168.49.2
```

---

# 11. Final one-command prerequisite check

Once everything is installed, this is a useful check to keep:

```bash
for cmd in docker minikube kubectl helm terraform curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "PASS: $cmd"
    else
        echo "FAIL: $cmd"
    fi
done
```

Expected:

```text
PASS: docker
PASS: minikube
PASS: kubectl
PASS: helm
PASS: terraform
PASS: curl
```

Then:

```bash
echo "===== Kubernetes ====="
kubectl get nodes

echo "===== Minikube ====="
minikube status

echo "===== Ingress ====="
kubectl get pods -n ingress-nginx
```
## Quick start

From the repository root:

```bash
export BASIC_AUTH_PASSWORD='devsecret'
./scripts/deploy.sh
```

The script:

1. Starts Minikube if it is not already running.
2. Enables the Minikube NGINX Ingress addon.
3. Builds `score-api:local` from the supplied `app/Dockerfile`.
4. Loads the image into Minikube.
5. Runs `helm lint`.
6. Runs `terraform init` and `terraform validate`.
7. Applies Terraform, which creates the namespace and Secret and installs the Helm release.
8. Waits for the deployment and ingress controller.
9. Calls `GET /healthz` through Ingress.
10. Calls authenticated `POST /decision` through Ingress and validates the response.

The script uses `devsecret` only as a local convenience default. For a real environment,
set `BASIC_AUTH_PASSWORD` explicitly.

## Manual verification

Get the Minikube IP:

```bash
minikube ip
```

Then call the health endpoint:

```bash
curl --resolve score-api.local:80:$(minikube ip)   http://score-api.local/healthz
```

Expected shape:

```json
{"status":"ok","version":"local"}
```

Call the authenticated decision endpoint:

```bash
curl --resolve score-api.local:80:$(minikube ip)   -u score:devsecret   -H 'Content-Type: application/json'   -X POST   http://score-api.local/decision   -d '{"client_id":"CL-0001","amount":1500}'
```

`CL-0001` is documented by the supplied application as an `APPROVE` case.

## Configuration

The application settings are exposed through Helm values:

| Value | Default | Purpose |
|---|---|---|
| `replicaCount` | `1` | Number of application replicas |
| `image.repository` | `score-api` | Image repository/name |
| `image.tag` | `local` | Image tag |
| `service.type` | `ClusterIP` | Kubernetes Service type |
| `service.port` | `80` | Service port |
| `service.targetPort` | `8080` | Container port |
| `env.logLevel` | `INFO` | Application log level |
| `env.serviceVersion` | `local` | Version returned by `/healthz` |
| `ingress.enabled` | `true` | Enable Ingress |
| `ingress.className` | `nginx` | Ingress class |
| `ingress.host` | `score-api.local` | Hostname |
| `resources.*` | see values.yaml | CPU/memory requests and limits |

The password is deliberately **not** a Helm value. Terraform creates the Kubernetes Secret and Helm
references it with `secretKeyRef`.

## Terraform

The Terraform module uses the local kubeconfig and Minikube context by default:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform validate
```

Required variable:

```text
basic_auth_password
```

Example:

```bash
terraform -chdir=terraform apply   -var='basic_auth_password=devsecret'
```

Terraform state can contain sensitive values because Kubernetes Secret data is represented in state.
For a real shared environment, protect the Terraform backend/state with appropriate access controls
and encryption.

## Helm

Render the chart locally:

```bash
helm lint helm/score-api

helm template score-api helm/score-api   --set auth.existingSecret=score-api-auth
```

## Kubernetes checks

```bash
kubectl get all -n score-api
kubectl get secret -n score-api
kubectl get ingress -n score-api
kubectl describe ingress -n score-api
kubectl get pods -n score-api
```

The container runs as UID 1000 and the chart preserves non-root execution with an explicit pod and
container security context.

## Design decisions

### Helm owns application deployment

Helm is responsible for Kubernetes manifests and application-level configuration. This keeps the
chart reusable across customer, environment, resource and ingress variations.

### Terraform owns infrastructure wiring

Terraform creates the namespace and Secret and installs the Helm release. The Secret is created
before the release, so the workload never has to embed credentials in `values.yaml`.

### Secret handling

`BASIC_AUTH_PASSWORD` is injected with:

```yaml
valueFrom:
  secretKeyRef:
    name: ...
    key: password
```

No password is committed to Git.

### Health and readiness

Both probes use `/healthz`, which is unauthenticated and has no external dependency. This makes it
appropriate for Kubernetes liveness/readiness checks.

### Local image strategy

Minikube receives the locally built image with:

```bash
minikube image load score-api:local
```

`IfNotPresent` prevents Kubernetes from attempting to pull the local image from a remote registry.

### Ingress verification

The script uses curl's `--resolve` option so `score-api.local` can be tested against the current
Minikube IP without modifying `/etc/hosts`.

## Limitations / production extensions

This exercise intentionally stays small. In a production deployment I would additionally consider:

- TLS certificates and HTTPS-only ingress
- NetworkPolicy
- PodDisruptionBudget
- HorizontalPodAutoscaler
- admission/policy controls
- image signing and vulnerability scanning
- external secret management rather than a Terraform-managed static password
- remote, encrypted Terraform state
- CI pipeline stages for tests, image scanning, Helm lint/template and Terraform validation/plan
- environment-specific values and release promotion

These are deliberately outside the minimum take-home scope.

## Presentation

See `PRESENTATION.md` for the short walkthrough used to explain the design and deployment flow.
