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
