# TaranDM Score API — DevOps Take-Home

This repository packages the supplied TaranDM Score API as a configurable Kubernetes deployment using **Docker, Helm, Terraform and Minikube**.

The solution provides:

* Containerized Score API using the supplied `app/` implementation
* Configurable Helm chart
* Kubernetes Deployment, Service and Ingress
* Liveness and readiness probes
* CPU and memory requests/limits
* Runtime environment configuration
* Kubernetes Secret for `BASIC_AUTH_PASSWORD`
* Terraform-managed namespace, Secret and Helm release
* Automated deployment and end-to-end verification using `scripts/deploy.sh`
* Manual verification steps for Kubernetes resources and API endpoints

The supplied `app/` directory is intentionally left unchanged.

---

## 1. Architecture

```text
                         +-----------------------------+
                         |          Minikube           |
                         |                             |
curl                      |   NGINX Ingress            |
  |                       |        |                    |
  | HTTP Host:            |        v                    |
  | score-api.local       |   Kubernetes Service       |
  +---------------------->|        |                    |
                          |        v                    |
                          |   Deployment               |
                          |        |                    |
                          |        v                    |
                          |   Score API Pod            |
                          |        |                    |
                          |        v                    |
                          | Kubernetes Secret          |
                          | score-api-auth             |
                          +-----------------------------+

Terraform
   |
   +--> Namespace
   |
   +--> Kubernetes Secret
   |       |
   |       +--> BASIC_AUTH_PASSWORD
   |
   +--> Helm Release
           |
           +--> Deployment
           +--> Service
           +--> Ingress
           +--> Probes
           +--> Resources
           +--> Environment
```

### Request flow

```text
Client
  |
  | GET /healthz
  | POST /decision
  v
NGINX Ingress
  |
  v
score-api Service
  |
  v
score-api Deployment
  |
  v
Score API container :8080
```

---

## 2. Repository Structure

```text
taran-devops-task-submission/
│
├── README.md
├── TOOLS_INSTALL.md
├── TASK.md
├── PRESENTATION.md
│
├── app/
│   ├── Dockerfile
│   ├── README.md
│   ├── pyproject.toml
│   ├── uv.lock
│   └── score_api/
│       ├── __init__.py
│       ├── config.py
│       └── server.py
│
├── helm/
│   └── score-api/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── ingress.yaml
│           ├── service.yaml
│           └── serviceaccount.yaml
│
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── versions.tf
│
└── scripts/
    └── deploy.sh
```

---

## 3. Prerequisites

See [`TOOLS_INSTALL.md`](TOOLS_INSTALL.md) for installing and verifying the required tools on Ubuntu.

The deployment requires:

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

Verify the tools are available:

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

# 4. End-to-End Execution

## 4.1 Clone or extract the repository

From the repository root:

```bash
cd taran-devops-task-submission
```

Confirm the repository structure:

```bash
ls
```

Expected:

```text
README.md
TOOLS_INSTALL.md
TASK.md
PRESENTATION.md
app
helm
terraform
scripts
```

---

## 4.2 Make the deployment script executable

```bash
chmod +x scripts/deploy.sh
```

Optional syntax validation:

```bash
bash -n scripts/deploy.sh
```

Expected:

```text
# no output indicates successful syntax validation
```

---

## 4.3 Run the automated deployment

Execute:

```bash
./scripts/deploy.sh
```

The script prompts securely for the application password:

```text
==> Enter Basic Auth password
Enter BASIC_AUTH_PASSWORD:
```

Enter a password when prompted.

The password is **not stored in `values.yaml` and is not committed to Git**.

Do not put the password directly into the repository.

---

# 5. What `deploy.sh` Does

The deployment script performs the complete deployment and verification workflow.

## Step 1 — Check required commands

The script verifies:

```text
docker
minikube
kubectl
helm
terraform
curl
python3
base64
```

If any command is missing, execution stops with an error.

---

## Step 2 — Prompt for authentication password

The script securely prompts for:

```text
BASIC_AUTH_PASSWORD
```

The password is stored only in the shell process during execution.

The script also removes sensitive variables during cleanup:

```bash
unset BASIC_AUTH_PASSWORD
unset K8S_PASSWORD
unset POD_PASSWORD
```

---

## Step 3 — Start Minikube

If the Minikube cluster is not running:

```bash
minikube start -p minikube
```

If it is already running, the existing cluster is reused.

---

## Step 4 — Enable NGINX Ingress

The script enables the Minikube ingress addon:

```bash
minikube addons enable ingress -p minikube
```

This provides the NGINX Ingress Controller used by the application.

---

## Step 5 — Build the Docker image

The application image is built from the supplied application:

```bash
docker build \
  -t score-api:local \
  app
```

The image is therefore built locally without requiring an external container registry.

---

## Step 6 — Load the image into Minikube

The locally built image is loaded into Minikube:

```bash
minikube image load score-api:local -p minikube
```

The Helm chart uses:

```yaml
image:
  repository: score-api
  tag: local
  pullPolicy: IfNotPresent
```

`IfNotPresent` prevents Kubernetes from unnecessarily attempting to pull the local image from a remote registry.

---

## Step 7 — Validate the Helm chart

The script runs:

```bash
helm lint helm/score-api
```

Expected:

```text
1 chart(s) linted, 0 chart(s) failed
```

---

## Step 8 — Initialize Terraform

The script initializes Terraform:

```bash
terraform -chdir=terraform init -input=false
```

Terraform uses the local Kubernetes/Minikube context.

---

## Step 9 — Validate Terraform

The script runs:

```bash
terraform -chdir=terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

---

## Step 10 — Apply Terraform

Terraform creates the required infrastructure:

```text
Namespace
Kubernetes Secret
Helm Release
```

The script passes the runtime password to Terraform:

```bash
-var="basic_auth_password=${BASIC_AUTH_PASSWORD}"
```

It also passes:

```text
image_repository
image_tag
namespace
ingress_host
```

The Kubernetes Secret is explicitly replaced on each deployment:

```bash
-replace="kubernetes_secret_v1.score_api_auth"
```

This ensures the current password entered at runtime is written to the Kubernetes Secret.

---

# 6. Secret Handling

The password is intentionally **not a Helm value**.

Terraform creates:

```text
score-api-auth
```

with:

```text
password
```

The Helm Deployment references the Secret using:

```yaml
valueFrom:
  secretKeyRef:
    name: score-api-auth
    key: password
```

The application receives the password as:

```text
BASIC_AUTH_PASSWORD
```

The expected authentication username is:

```text
score
```

Therefore:

```text
Username: score
Password: value entered when deploy.sh starts
```

### Important

Do **not** add the password to:

```text
helm/score-api/values.yaml
```

Do **not** commit:

```text
terraform.tfvars
```

or any other file containing the password.

The repository `.gitignore` excludes Terraform variable/state files and common secret files.

---

# 7. Secret Verification Performed by `deploy.sh`

After Terraform applies the Secret, the script retrieves the Kubernetes Secret and decodes it internally.

Conceptually:

```bash
kubectl get secret score-api-auth \
  -n score-api \
  -o jsonpath='{.data.password}' | base64 -d
```

The decoded value is compared with the password entered at the beginning of the script.

The password itself is not printed.

Expected:

```text
==> Secret verification: PASS
```

---

# 8. Restart Application to Load Updated Secret

Kubernetes environment variables populated through:

```yaml
valueFrom:
  secretKeyRef:
```

are loaded when the Pod starts.

Therefore, after updating the Secret, the script explicitly restarts the Deployment:

```bash
kubectl rollout restart deployment/score-api -n score-api
```

It then waits for the rollout:

```bash
kubectl rollout status \
  deployment/score-api \
  -n score-api \
  --timeout=180s
```

Expected:

```text
deployment "score-api" successfully rolled out
```

---

# 9. Pod Secret Verification

After the rollout, the script identifies the Score API Pod and verifies that the Pod received the current password.

It checks:

```text
BASIC_AUTH_PASSWORD
```

inside the running container.

Expected:

```text
==> Pod Secret verification: PASS
```

This verifies the complete chain:

```text
Runtime password
      |
      v
Terraform variable
      |
      v
Kubernetes Secret
      |
      v
Pod environment variable
      |
      v
Score API
```

---

# 10. Ingress Readiness

The script waits for the NGINX Ingress Controller:

```bash
kubectl wait \
  --namespace ingress-nginx \
  --for=condition=available \
  deployment/ingress-nginx-controller \
  --timeout=180s
```

It then retrieves the current Minikube IP:

```bash
minikube ip -p minikube
```

Example:

```text
192.168.49.2
```

---

# 11. Automated `/healthz` Verification

The script calls:

```text
GET /healthz
```

through the Kubernetes Ingress.

It uses curl's `--resolve` option:

```bash
curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

This allows the hostname:

```text
score-api.local
```

to resolve to the current Minikube IP without modifying `/etc/hosts`.

The script retries the request if the Ingress or application is still becoming ready.

Expected response:

```json
{
  "status": "ok",
  "version": "local"
}
```

The script validates that:

```text
status == ok
```

Expected:

```text
==> /healthz: PASS
```

---

# 12. Automated `/decision` Verification

The script then calls:

```text
POST /decision
```

using Basic Authentication.

Username:

```text
score
```

Password:

```text
BASIC_AUTH_PASSWORD
```

Request body:

```json
{
  "client_id": "CL-0001",
  "amount": 1500
}
```

The request is sent through the Ingress:

```text
curl
  |
  v
score-api.local
  |
  v
NGINX Ingress
  |
  v
Service
  |
  v
Score API Pod
```

The script validates:

* `client_id` matches the requested client
* `decision` is either `APPROVE` or `DECLINE`
* `state` is `FINISHED`
* `score` is numeric
* `decision_id` exists

Example successful response:

```json
{
  "decision_id": "02e152a3-2501-46a5-8561-4798100a6d87",
  "client_id": "CL-0001",
  "amount": 1500.0,
  "score": 0.1712,
  "decision": "APPROVE",
  "state": "FINISHED"
}
```

Expected:

```text
==> /decision: PASS
```

---

# 13. Expected Final Result

A successful execution ends with:

```text
============================================================
SUCCESS: Score API deployed and verified successfully.
============================================================

Endpoints verified:
  GET  http://score-api.local/healthz
  POST http://score-api.local/decision

Client ID : CL-0001
Amount    : 1500
```

This confirms:

```text
Docker Build
     |
     v
Minikube Image
     |
     v
Terraform
     |
     +--> Namespace
     |
     +--> Kubernetes Secret
     |
     +--> Helm Release
             |
             +--> Deployment
             +--> Service
             +--> Ingress
     |
     v
Pod Ready
     |
     v
Ingress Ready
     |
     +--> GET /healthz       PASS
     |
     +--> POST /decision     PASS
```

---

# 14. Manual Verification

The automated script performs the full validation. The following commands can also be used to independently verify the deployment.

---

## 14.1 Check Minikube

```bash
minikube status
```

Expected:

```text
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

Get the IP:

```bash
minikube ip
```

Example:

```text
192.168.49.2
```

---

## 14.2 Check Kubernetes Namespace

```bash
kubectl get namespace score-api
```

Expected:

```text
NAME        STATUS   AGE
score-api   Active   123m
```

---

## 14.3 Check All Application Resources

```bash
kubectl get all -n score-api
```

Expected resources include:

```text
NAME                             READY   STATUS    RESTARTS   AGE
pod/score-api-76c7445bbb-frn9l   1/1     Running   0          69m

NAME                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/score-api   ClusterIP   10.100.41.69   <none>        80/TCP    124m

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/score-api   1/1     1            1           124m

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/score-api-648f999f75   0         0         0       85m
replicaset.apps/score-api-69b8755948   0         0         0       78m
replicaset.apps/score-api-76c7445bbb   1         1         1       69m
replicaset.apps/score-api-78c5b48cb7   0         0         0       73m
```

---

## 14.4 Check Pod Status

```bash
kubectl get pods -n score-api
```

Expected:

```text
NAME                         READY   STATUS    RESTARTS   AGE
score-api-76c7445bbb-frn9l   1/1     Running   0          69m
```

The important values are:

```text
READY     1/1
STATUS    Running
```

---

## 14.5 Check Deployment

```bash
kubectl get deployment score-api -n score-api
```

Expected:

```text
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
score-api   1/1     1            1           125m
```

Check rollout:

```bash
kubectl rollout status deployment/score-api -n score-api
```

Expected:

```text
deployment "score-api" successfully rolled out
```

---

# 15. Manual Secret Verification

List the Secret:

```bash
kubectl get secret -n score-api
```

Expected:

```text
NAME                              TYPE                 DATA   AGE
score-api-auth                    Opaque               1      70m
```

To inspect the Base64-encoded Secret value:

```bash
kubectl get secret score-api-auth \
  -n score-api \
  -o jsonpath='{.data.password}'

echo
```

Example:

```text
VGVzdEAxMjM=
```

Kubernetes Secret data is Base64 encoded.

To decode it manually:

```bash
kubectl get secret score-api-auth \
  -n score-api \
  -o jsonpath='{.data.password}' | base64 -d

echo
```

**Do not run this on a shared terminal or screen-share if the password must remain confidential.**

A safer comparison approach is:

```bash
read -r -s -p "Enter expected password: " EXPECTED_PASSWORD
echo

ACTUAL_PASSWORD="$(
  kubectl get secret score-api-auth \
    -n score-api \
    -o jsonpath='{.data.password}' | base64 -d
)"

if [[ "$EXPECTED_PASSWORD" == "$ACTUAL_PASSWORD" ]]; then
  echo "Secret verification: PASS"
else
  echo "Secret verification: FAIL"
fi

unset EXPECTED_PASSWORD ACTUAL_PASSWORD
```

---

# 16. Manual Pod Secret Verification

Identify the Pod:

```bash
kubectl get pods \
  -n score-api \
  -l app.kubernetes.io/name=score-api
```

Set the Pod name:

```bash
POD_NAME="$(kubectl get pods \
  -n score-api \
  -l app.kubernetes.io/name=score-api \
  -o jsonpath='{.items[0].metadata.name}')"
```

Verify that the environment variable exists:

```bash
kubectl exec \
  -n score-api \
  "$POD_NAME" \
  -- printenv BASIC_AUTH_PASSWORD
```

This prints the password, so use it only in a controlled environment.

Alternatively, compare it without displaying the password:

```bash
read -r -s -p "Enter expected password: " EXPECTED_PASSWORD
echo

POD_PASSWORD="$(
  kubectl exec \
    -n score-api \
    "$POD_NAME" \
    -- printenv BASIC_AUTH_PASSWORD
)"

if [[ "$EXPECTED_PASSWORD" == "$POD_PASSWORD" ]]; then
  echo "Pod Secret verification: PASS"
else
  echo "Pod Secret verification: FAIL"
fi

unset EXPECTED_PASSWORD POD_PASSWORD POD_NAME
```

---

# 17. Manual Service Verification

Check the Service:

```bash
kubectl get service score-api -n score-api
```

Expected:

```text
NAME        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
score-api   ClusterIP   10.100.41.69   <none>        80/TCP    127m
```

Check the endpoints:

```bash
kubectl get endpoints score-api -n score-api
```

Expected output should contain the Pod IP and port:

```text
NAME        ENDPOINTS          AGE
score-api   10.244.0.18:8080   127m
```

This confirms:

```text
Service :80
    |
    v
Pod :8080
```

---

# 18. Manual Ingress Verification

Check the Ingress:

```bash
kubectl get ingress -n score-api
```

Expected:

```text
NAME        CLASS   HOSTS             ADDRESS        PORTS   AGE
score-api   nginx   score-api.local   192.168.49.2   80      127m
```

Describe it:

```bash
kubectl describe ingress score-api -n score-api
```

Verify:

```text
  Host             Path  Backends
  ----             ----  --------
  score-api.local
                   /   score-api:http (10.244.0.18:8080)
```

---

# 19. Manual `/healthz` API Verification

Get the Minikube IP:

```bash
MINIKUBE_IP="$(minikube ip)"
```

Call:

```bash
curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

Expected:

```json
{"status":"ok","version":"local"}
```

For verbose HTTP verification:

```bash
curl -v \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

Expected:

```text
HTTP/1.1 200 OK
```

---

# 20. Manual `/decision` API Verification

Enter the same password used when running `deploy.sh`:

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

Expected response:

```json
{"decision_id":"451bb2d3-1e74-437b-8d71-67c669ae0c6c",
"client_id":"CL-0001",
"amount":1500.0,
"score":0.1712,
"decision":"APPROVE",
"state":"FINISHED"}
```

The exact `decision_id` and `score` may vary.

Verify the response contains:

```text
client_id = CL-0001
decision   = APPROVE or DECLINE
state      = FINISHED
score      = numeric value
decision_id = present
```

Remove the password from the current shell:

```bash
unset PASSWORD
```

---

# 21. Test Authentication Failure

To confirm Basic Authentication is enforced, intentionally use an incorrect password:

```bash
curl -i \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  -u "score:incorrect-password" \
  -H "Content-Type: application/json" \
  http://score-api.local/decision \
  -d '{"client_id":"CL-0001","amount":1500}'
```

The application should reject the request.

Expected HTTP status:

```text
{"description":"Unauthorized",
"status":401,
"message":"Invalid credentials."}
```

This confirms that `/decision` is protected by Basic Authentication.

---

# 22. Test Health Endpoint Without Authentication

The health endpoint should work without credentials:

```bash
curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

Expected:

```json
{
  "status": "ok",
  "version": "local"
}
```

This is also why `/healthz` is suitable for Kubernetes liveness and readiness probes.

---

# 23. Helm Verification

Validate the chart:

```bash
helm lint helm/score-api
```

Render the manifests locally:

```bash
helm template score-api helm/score-api \
  --set auth.existingSecret=score-api-auth
```

To inspect the deployed Helm release:

```bash
helm list -n score-api
```

Expected:

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
score-api       score-api       1               2026-09-03 18:48:43.269739788 +0800 +08 deployed        score-api-0.1.0 1.0.0
```

Inspect Helm values:

```bash
helm get values score-api -n score-api
```

The Kubernetes password should **not** appear as a Helm value.

---

# 24. Terraform Verification

Initialize Terraform:

```bash
terraform -chdir=terraform init
```

Validate:

```bash
terraform -chdir=terraform validate
```

Inspect the Terraform plan:

```bash
terraform -chdir=terraform plan \
  -var="basic_auth_password=<runtime-password>"
```

Apply:

```bash
terraform -chdir=terraform apply \
  -var="basic_auth_password=<runtime-password>"
```

The normal recommended path remains:

```bash
./scripts/deploy.sh
```

because the script handles the complete workflow and verification.

---

# 25. Terraform State Security

The Kubernetes Secret is represented in Terraform state.

Therefore, although the password is not stored in:

```text
values.yaml
```

or committed directly to Git, sensitive data can exist in Terraform state.

For a real shared environment:

* Use a remote Terraform backend
* Encrypt Terraform state
* Restrict state access
* Use appropriate IAM/RBAC
* Avoid exposing state files
* Enable state locking where supported
* Prefer an external secret-management solution for production credentials

The local take-home implementation intentionally keeps Terraform state local and simple.

---

# 26. Configuration

The Helm chart exposes application configuration through `values.yaml`.

| Value                 | Default           | Purpose                        |
| --------------------- | ----------------- | ------------------------------ |
| `replicaCount`        | `1`               | Number of application replicas |
| `image.repository`    | `score-api`       | Container image repository     |
| `image.tag`           | `local`           | Container image tag            |
| `image.pullPolicy`    | `IfNotPresent`    | Image pull policy              |
| `service.type`        | `ClusterIP`       | Kubernetes Service type        |
| `service.port`        | `80`              | Service port                   |
| `service.targetPort`  | `8080`            | Application container port     |
| `env.logLevel`        | `INFO`            | Application log level          |
| `env.serviceVersion`  | `local`           | Version returned by `/healthz` |
| `ingress.enabled`     | `true`            | Enable Ingress                 |
| `ingress.className`   | `nginx`           | Ingress class                  |
| `ingress.host`        | `score-api.local` | Ingress hostname               |
| `resources.requests`  | See `values.yaml` | CPU/memory requests            |
| `resources.limits`    | See `values.yaml` | CPU/memory limits              |
| `auth.existingSecret` | `score-api-auth`  | Existing Kubernetes Secret     |
| `auth.passwordKey`    | `password`        | Secret key                     |

The password is deliberately excluded from Helm values.

---

# 27. Custom Deployment Parameters

`deploy.sh` supports environment variable overrides.

Default values are:

```bash
IMAGE_REPOSITORY=score-api
IMAGE_TAG=local
NAMESPACE=score-api
INGRESS_HOST=score-api.local
CLIENT_ID=CL-0001
DECISION_AMOUNT=1500
```

For example:

```bash
IMAGE_TAG=test \
CLIENT_ID=CL-0002 \
DECISION_AMOUNT=5000 \
./scripts/deploy.sh
```

Or:

```bash
NAMESPACE=taran-test \
INGRESS_HOST=taran.local \
./scripts/deploy.sh
```

The password is always entered interactively by the script.

---

# 28. Kubernetes Security Controls

The Helm chart includes non-root container execution.

The Pod runs using:

```text
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
```

The container also disables privilege escalation:

```text
allowPrivilegeEscalation: false
```

and drops Linux capabilities:

```text
capabilities:
  drop:
    - ALL
```

The Service Account does not automatically mount its token:

```text
automountServiceAccountToken: false
```

These controls reduce the container's runtime privileges.

---

# 29. Resource Management

The Deployment defines resource requests and limits.

Example:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

This provides Kubernetes with:

* Scheduling requirements
* CPU limits
* Memory limits
* More predictable resource consumption

---

# 30. Health Probes

Both Kubernetes probes use:

```text
/healthz
```

Liveness:

```text
GET /healthz
```

Readiness:

```text
GET /healthz
```

The endpoint is unauthenticated and does not require an external dependency, making it appropriate for Kubernetes health checking.

---

# 31. Troubleshooting

## 31.1 Check Minikube

```bash
minikube status
```

If it is not running:

```bash
minikube start
```

---

## 31.2 Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
```

Expected:

```text
ingress-nginx-controller-xxxxx   1/1   Running
```

If required:

```bash
minikube addons enable ingress
```

---

## 31.3 Check Application Pod

```bash
kubectl get pods -n score-api
```

If the Pod is not running:

```bash
kubectl describe pod -n score-api <pod-name>
```

Check logs:

```bash
kubectl logs -n score-api <pod-name>
```

---

## 31.4 Check Deployment

```bash
kubectl rollout status deployment/score-api -n score-api
```

If rollout fails:

```bash
kubectl describe deployment score-api -n score-api
```

---

## 31.5 Check Service Endpoints

```bash
kubectl get endpoints score-api -n score-api
```

If there are no endpoints, inspect:

```bash
kubectl get pods -n score-api --show-labels
```

and:

```bash
kubectl describe service score-api -n score-api
```

---

## 31.6 Check Ingress

```bash
kubectl get ingress -n score-api
```

Then:

```bash
kubectl describe ingress score-api -n score-api
```

Verify:

```text
Host: score-api.local
Backend: score-api:80
```

---

## 31.7 Check Image

Verify the image exists locally:

```bash
docker images | grep score-api
```

Verify it is available to Minikube:

```bash
minikube image ls | grep score-api
```

If necessary:

```bash
docker build -t score-api:local app
minikube image load score-api:local
```

---

# 32. Authentication Troubleshooting

If `/healthz` works but `/decision` returns:

```text
401 Unauthorized
```

check the Secret:

```bash
kubectl get secret score-api-auth \
  -n score-api \
  -o jsonpath='{.data.password}' | base64 -d

echo
```

Then verify the Pod received the current Secret value.

Remember that environment variables populated from a Kubernetes Secret are loaded when the Pod starts.

Therefore, after changing the Secret:

```bash
kubectl rollout restart deployment/score-api -n score-api
```

Then:

```bash
kubectl rollout status deployment/score-api -n score-api
```

The `deploy.sh` script performs this restart automatically.

The application expects:

```text
Username: score
Password: BASIC_AUTH_PASSWORD
```

Do not use a different username.

---

# 33. Complete Manual Verification Sequence

After deployment, the following sequence provides a concise end-to-end verification.

### 1. Minikube

```bash
minikube status
```

### 2. Pods

```bash
kubectl get pods -n score-api
```

### 3. Deployment

```bash
kubectl rollout status deployment/score-api -n score-api
```

### 4. Service

```bash
kubectl get service score-api -n score-api
```

### 5. Endpoints

```bash
kubectl get endpoints score-api -n score-api
```

### 6. Secret

```bash
kubectl get secret score-api-auth -n score-api
```

### 7. Ingress

```bash
kubectl get ingress -n score-api
```

### 8. Health

```bash
MINIKUBE_IP=$(minikube ip)

curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  http://score-api.local/healthz
```

Expected:

```json
{"status":"ok","version":"local"}
```

### 9. Decision

```bash
read -r -s -p "Enter BASIC_AUTH_PASSWORD: " PASSWORD
echo

curl \
  --resolve "score-api.local:80:${MINIKUBE_IP}" \
  -u "score:${PASSWORD}" \
  -H "Content-Type: application/json" \
  http://score-api.local/decision \
  -d '{"client_id":"CL-0001","amount":1500}'

unset PASSWORD
```

Expected:

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

---

# 34. Design Decisions

## Helm owns application deployment

Helm is responsible for Kubernetes application resources:

```text
Deployment
Service
Ingress
ServiceAccount
Probes
Resource configuration
Environment configuration
```

This keeps the application deployment reusable and configurable.

---

## Terraform owns infrastructure wiring

Terraform is responsible for:

```text
Namespace
Kubernetes Secret
Helm Release
```

The Secret is created by Terraform and referenced by the Helm Deployment.

This separates infrastructure provisioning from application manifests.

---

## Secret is not a Helm value

The authentication password is intentionally not placed in:

```text
values.yaml
```

Instead:

```text
Terraform
   |
   v
Kubernetes Secret
   |
   v
secretKeyRef
   |
   v
BASIC_AUTH_PASSWORD
```

This avoids committing the credential into Helm configuration.

---

## Local image strategy

The exercise uses a local image:

```text
score-api:local
```

The image is:

1. Built with Docker
2. Loaded into Minikube
3. Referenced by Kubernetes with `IfNotPresent`

This avoids the need for an external image registry for the take-home exercise.

---

## Ingress verification

The script uses:

```bash
curl --resolve
```

instead of modifying:

```text
/etc/hosts
```

This allows:

```text
score-api.local
```

to be routed to the current Minikube IP during verification.

---

# 35. Production Extensions

This take-home implementation intentionally remains small.

For a production deployment, I would additionally consider:

* HTTPS/TLS-only Ingress
* Managed certificate lifecycle
* NetworkPolicies
* PodDisruptionBudget
* HorizontalPodAutoscaler
* Kubernetes admission/policy controls
* Image vulnerability scanning
* SBOM generation
* Image signing and verification
* External Secret Management
* Centralized logging and monitoring
* Prometheus/Grafana observability
* Centralized audit logging
* Remote encrypted Terraform state
* CI/CD pipeline gates
* Terraform plan approval
* Helm template validation
* Environment-specific values
* Deployment promotion between environments
* Backup and disaster-recovery strategy
* Stronger authentication mechanism for production APIs

These items are intentionally outside the minimum scope of this exercise.

---

# 36. Cleanup

To remove the Kubernetes deployment:

```bash
terraform -chdir=terraform destroy
```

Terraform will remove the resources it manages.

Alternatively, to remove the namespace directly:

```bash
kubectl delete namespace score-api
```

To stop Minikube:

```bash
minikube stop
```

To completely delete the Minikube cluster:

```bash
minikube delete
```

---

# 37. Final Validation Checklist

Before submitting the solution, verify:

```text
[ ] README.md present
[ ] TOOLS_INSTALL.md present
[ ] TASK.md present
[ ] PRESENTATION.md present
[ ] Supplied app/ unchanged
[ ] Docker image builds successfully
[ ] Image loaded into Minikube
[ ] Helm lint passes
[ ] Terraform init passes
[ ] Terraform validate passes
[ ] Namespace created
[ ] Kubernetes Secret created
[ ] Password not stored in values.yaml
[ ] Helm release deployed
[ ] Deployment available
[ ] Pod Running
[ ] Pod is Ready
[ ] Service has endpoints
[ ] Ingress created
[ ] NGINX Ingress Controller running
[ ] GET /healthz returns HTTP 200
[ ] /healthz returns status=ok
[ ] POST /decision requires authentication
[ ] POST /decision returns HTTP 200 with valid credentials
[ ] decision_id is present
[ ] client_id matches request
[ ] decision is APPROVE or DECLINE
[ ] state is FINISHED
[ ] score is numeric
```

---

# 38. One-Command Deployment and Verification

The intended developer workflow is:

```bash
cd taran-devops-task-submission

chmod +x scripts/deploy.sh

./scripts/deploy.sh
```

Enter the requested password when prompted.

The script then performs:

```text
Prerequisite checks
        |
        v
Start Minikube
        |
        v
Enable Ingress
        |
        v
Build Docker image
        |
        v
Load image into Minikube
        |
        v
Helm lint
        |
        v
Terraform init
        |
        v
Terraform validate
        |
        v
Terraform apply
        |
        +----> Namespace
        |
        +----> Kubernetes Secret
        |
        +----> Helm Release
                    |
                    +--> Deployment
                    +--> Service
                    +--> Ingress
        |
        v
Verify Secret
        |
        v
Restart Deployment
        |
        v
Verify rollout
        |
        v
Verify Pod received Secret
        |
        v
Wait for Ingress
        |
        v
GET /healthz
        |
        v
POST /decision
        |
        v
Validate API response
        |
        v
SUCCESS
```

This is the primary end-to-end execution path for the take-home submission.

---

# 39. Presentation

See [`PRESENTATION.md`](PRESENTATION.md) for the short walkthrough covering:

* Architecture
* Docker image strategy
* Helm design
* Terraform responsibilities
* Secret handling
* Kubernetes deployment
* Ingress routing
* Automated verification
* Design decisions
* Production considerations

---

## Summary

The solution demonstrates a complete local DevOps deployment workflow for the TaranDM Score API:

```text
Application
    |
    v
Docker
    |
    v
Minikube
    |
    +--------------------+
    |                    |
    v                    v
 Terraform              Helm
    |                    |
    +--------+-----------+
             |
             v
       Kubernetes
             |
             +--> Secret
             |
             +--> Deployment
             |
             +--> Service
             |
             +--> Ingress
             |
             v
          Score API
             |
             +--> GET /healthz
             |
             +--> POST /decision
```

The deployment is reproducible through:

```bash
./scripts/deploy.sh
```

and independently verifiable using the manual Kubernetes and API verification commands documented above.