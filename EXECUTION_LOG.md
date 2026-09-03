~/work/taran-devops-task-submission$ ./scripts/deploy.sh
==> Checking required commands

==> Enter Basic Auth password
Enter BASIC_AUTH_PASSWORD:

==> Starting Minikube if needed
😄  minikube v1.39.0 on Ubuntu 24.04 (kvm/amd64)
✨  Automatically selected the docker driver
📌  Using Docker driver with root privileges
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🚜  Pulling base image v0.0.51 ...
🔥  Creating docker container (CPUs=2, Memory=3072MB) ...
📦  Preparing Kubernetes v1.37.0 on containerd 2.3.4 ...
🔗  Configuring CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
==> Enabling Minikube Ingress
💡  ingress is an addon maintained by Kubernetes. For any concerns contact minikube on GitHub.
You can view the list of minikube maintainers at: https://github.com/kubernetes/minikube/blob/master/OWNERS
    ▪ Using image registry.k8s.io/ingress-nginx/controller:v1.15.1
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.9
    ▪ Using image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.9
🔎  Verifying ingress addon...
🌟  The 'ingress' addon is enabled

==> Building score-api:local
[+] Building 1.7s (16/16) FINISHED                                                                                                                                  docker:default
 => [internal] load build definition from Dockerfile                                                                                                                          0.0s
 => => transferring dockerfile: 1.07kB                                                                                                                                        0.0s
 => [internal] load metadata for ghcr.io/astral-sh/uv:0.11.2                                                                                                                  0.9s
 => [internal] load metadata for docker.io/library/python:3.13-slim@sha256:7ce4b6dfe35e55397b7cda544f8a13f191b7ae28dc5aad71fe664dbc9bc2623f                                   1.5s
 => [internal] load .dockerignore                                                                                                                                             0.0s
 => => transferring context: 86B                                                                                                                                              0.0s
 => FROM ghcr.io/astral-sh/uv:0.11.2@sha256:c4f5de312ee66d46810635ffc5df34a1973ba753e7241ce3a08ef979ddd7bea5                                                                  0.0s
 => => resolve ghcr.io/astral-sh/uv:0.11.2@sha256:c4f5de312ee66d46810635ffc5df34a1973ba753e7241ce3a08ef979ddd7bea5                                                            0.0s
 => [internal] load build context                                                                                                                                             0.0s
 => => transferring context: 252B                                                                                                                                             0.0s
 => [builder 1/5] FROM docker.io/library/python:3.13-slim@sha256:7ce4b6dfe35e55397b7cda544f8a13f191b7ae28dc5aad71fe664dbc9bc2623f                                             0.0s
 => => resolve docker.io/library/python:3.13-slim@sha256:7ce4b6dfe35e55397b7cda544f8a13f191b7ae28dc5aad71fe664dbc9bc2623f                                                     0.0s
 => CACHED [runtime 2/5] RUN groupadd --gid 1000 score     && useradd --uid 1000 --gid score --no-create-home --shell /usr/sbin/nologin score                                 0.0s
 => CACHED [builder 2/5] COPY --from=ghcr.io/astral-sh/uv:0.11.2 /uv /bin/uv                                                                                                  0.0s
 => CACHED [builder 3/5] WORKDIR /app                                                                                                                                         0.0s
 => CACHED [builder 4/5] COPY pyproject.toml uv.lock ./                                                                                                                       0.0s
 => CACHED [builder 5/5] RUN uv sync --frozen --no-dev                                                                                                                        0.0s
 => CACHED [runtime 3/5] COPY --from=builder /opt/venv /opt/venv                                                                                                              0.0s
 => CACHED [runtime 4/5] WORKDIR /app                                                                                                                                         0.0s
 => CACHED [runtime 5/5] COPY --chown=score:score score_api ./score_api                                                                                                       0.0s
 => exporting to image                                                                                                                                                        0.1s
 => => exporting layers                                                                                                                                                       0.0s
 => => exporting manifest sha256:bda2c4eb5bc25bb4e775ce405acd6e98be360405188f8dc1e8c8dc73e6b77f25                                                                             0.0s
 => => exporting config sha256:23a0987d48997302df4b4f58e18f1a8898666178d6197c69a9f87274d499a5be                                                                               0.0s
 => => exporting attestation manifest sha256:148c94a4f9e11e18510e79eaa21d17b1ff9013f792d546546ef620cd57bdb561                                                                 0.0s
 => => exporting manifest list sha256:bd7a3d019b461b03d2926d13cc0915334c612b7c78e9c048a04b2e4e994a0242                                                                        0.0s
 => => naming to docker.io/library/score-api:local                                                                                                                            0.0s
 => => unpacking to docker.io/library/score-api:local                                                                                                                         0.0s
==> Loading image into Minikube

==> Validating Helm chart
==> Linting /home/ar152036/work/taran-devops-task-submission/helm/score-api
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

==> Initializing Terraform
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/helm from the dependency lock file
- Reusing previous version of hashicorp/kubernetes from the dependency lock file
- Installing hashicorp/helm v2.17.0...
- Installed hashicorp/helm v2.17.0 (signed by HashiCorp)
- Installing hashicorp/kubernetes v2.38.0...
- Installed hashicorp/kubernetes v2.38.0 (signed by HashiCorp)


Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
==> Validating Terraform
Success! The configuration is valid.

==> Applying Terraform

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # helm_release.score_api will be created
  + resource "helm_release" "score_api" {
      + atomic                     = false
      + chart                      = "./../helm/score-api"
      + cleanup_on_fail            = false
      + create_namespace           = false
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + manifest                   = (known after apply)
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "score-api"
      + namespace                  = "score-api"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + reset_values               = false
      + reuse_values               = false
      + skip_crds                  = false
      + status                     = "deployed"
      + timeout                    = 180
      + values                     = [
          + <<-EOT
                "auth":
                  "existingSecret": "score-api-auth"
                "env":
                  "logLevel": "INFO"
                  "serviceVersion": "local"
                "image":
                  "repository": "score-api"
                  "tag": "local"
                "ingress":
                  "host": "score-api.local"
            EOT,
        ]
      + verify                     = false
      + version                    = "0.1.0"
      + wait                       = true
      + wait_for_jobs              = false
    }

  # kubernetes_namespace_v1.score_api will be created
  + resource "kubernetes_namespace_v1" "score_api" {
      + id                               = (known after apply)
      + wait_for_default_service_account = false

      + metadata {
          + generation       = (known after apply)
          + name             = "score-api"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # kubernetes_secret_v1.score_api_auth will be created
  + resource "kubernetes_secret_v1" "score_api_auth" {
      + binary_data_wo                 = (write-only attribute)
      + data                           = (sensitive value)
      + data_wo                        = (write-only attribute)
      + id                             = (known after apply)
      + type                           = "Opaque"
      + wait_for_service_account_token = true

      + metadata {
          + generation       = (known after apply)
          + name             = "score-api-auth"
          + namespace        = "score-api"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ingress_host = "score-api.local"
  + namespace    = "score-api"
  + release_name = "score-api"
kubernetes_namespace_v1.score_api: Creating...
kubernetes_namespace_v1.score_api: Creation complete after 0s [id=score-api]
kubernetes_secret_v1.score_api_auth: Creating...
kubernetes_secret_v1.score_api_auth: Creation complete after 0s [id=score-api/score-api-auth]
helm_release.score_api: Creating...
helm_release.score_api: Creation complete after 7s [id=score-api]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

ingress_host = "score-api.local"
namespace = "score-api"
release_name = "score-api"

==> Verifying Kubernetes Secret
==> Secret verification: PASS

==> Restarting deployment to load updated Secret
deployment.apps/score-api restarted
==> Waiting for deployment rollout
Waiting for deployment "score-api" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "score-api" rollout to finish: 1 old replicas are pending termination...
deployment "score-api" successfully rolled out

==> Verifying Pod received updated Secret
==> Pod Secret verification: PASS

==> Waiting for Ingress controller
deployment.apps/ingress-nginx-controller condition met
==> Minikube IP: 192.168.49.2
==> Ingress host: score-api.local

==> Checking GET /healthz
{"status":"ok","version":"local"}
==> /healthz: PASS

==> Checking POST /decision
{"decision_id":"1d4396af-ed9c-4033-8c78-d68cb4f9d96f","client_id":"CL-0001","amount":1500.0,"score":0.1712,"decision":"APPROVE","state":"FINISHED"}
==> /decision: PASS

============================================================
SUCCESS: Score API deployed and verified successfully.
============================================================

Endpoints verified:
  GET  http://score-api.local/healthz
  POST http://score-api.local/decision

Client ID : CL-0001
Amount    : 1500