# Short Presentation — TaranDM Score API

## 1. Objective

Package the supplied Score API so the same service can be configured and deployed consistently
across different environments.

The implementation uses:

- Docker for the application image
- Helm for Kubernetes packaging/configuration
- Terraform for Secret creation and Helm installation
- Minikube + NGINX Ingress for local verification

## 2. Repository structure

```text
app/                    # supplied application, unchanged
helm/score-api/         # Kubernetes packaging
terraform/              # Secret + Helm release
scripts/deploy.sh       # build, deploy and smoke test
README.md               # runbook
```

## 3. Deployment flow

```text
Docker build
    |
    v
Minikube image load
    |
    v
Terraform
  |            v           v
Secret      Helm release
              |
              v
       Deployment + Service
              |
              v
           Ingress
```

The deployment script is deliberately idempotent for the local workflow: it reuses a running
Minikube cluster and applies the desired Terraform/Helm state.

## 4. Configuration model

Helm values control:

- image
- replicas
- resources
- log level
- service version
- service ports
- ingress hostname
- probe timings

The authentication password is intentionally different: it is created as a Kubernetes Secret by
Terraform and referenced by the Deployment. It is never stored in `values.yaml`.

## 5. Kubernetes workload

The chart provides:

- Deployment
- ClusterIP Service
- NGINX Ingress
- liveness probe
- readiness probe
- resource requests/limits
- non-root security context
- service account with token automount disabled

Both probes call `/healthz`.

## 6. Verification

The pipeline validates:

```text
GET /healthz
    -> HTTP success
    -> JSON status == "ok"

POST /decision
    -> HTTP Basic authentication
    -> client_id == CL-0001
    -> decision == APPROVE
    -> state == FINISHED
```

The calls are made through the Ingress rather than directly to the Pod or through port-forwarding.

## 7. Security choices

- Application image already runs as UID 1000.
- Chart explicitly requires non-root execution.
- Container drops Linux capabilities.
- Privilege escalation is disabled.
- Password is injected from a Secret.
- No credentials are committed to Git.
- Terraform password variable is marked sensitive.
- Terraform state should be protected in real deployments.

## 8. Production evolution

For a real TaranDM platform, the next layer would include:

- TLS and certificate automation
- external secret manager
- NetworkPolicy
- HPA/PDB
- image signing/scanning and SBOM
- CI quality/security gates
- remote encrypted Terraform state
- environment-specific promotion

The take-home deliberately avoids these additions to keep the solution focused and easy to review.
