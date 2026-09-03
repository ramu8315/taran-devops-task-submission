# Take-home: deploy the Score API to Kubernetes

We build **TaranDM**, a credit-risk decision platform mainly for banks and financial
institutions. It is a set of services we deploy both as SaaS and as PaaS, so every install has
to be customizable through Helm values — customer, environment, resources, ingress, secrets.

This take-home is a small sample of that work. We give you one service (not TaranDM itself) and
a working Dockerfile. Treat it as a stand-in for a TaranDM service: package it, parameterize it,
and get it running on Kubernetes the way you would ship something we operate.

Any AI usage is permitted. You do not need to change the application code.

## What you get

- [`app/`](app/) — the **Score API**: `GET /healthz` (open) and `POST /decision` (HTTP basic
  auth). Config via `LOG_LEVEL` and `BASIC_AUTH_PASSWORD`. No database. See
  [`app/README.md`](app/README.md).
- A working, non-root `Dockerfile`. You only run the build.

## What to build

### Helm chart

Your own chart for the Score API. It should cover Deployment, Service, Ingress, liveness and
readiness probes against `/healthz`, and reasonable resource requests and limits. Environment
comes from values; `BASIC_AUTH_PASSWORD` comes from a Secret (never from `values.yaml`).

### Terraform

Terraform creates the secrets and installs your Helm chart on the cluster.

### Pipeline

A bash script (or similar) that deploys to minikube and checks the result:

- start or use minikube
- build the image and load it
- apply Terraform (secrets + chart install)
- hit the endpoints through Ingress and check they return what we expect
  - `GET /healthz` is ok
  - `POST /decision` authenticates and gives a decision

### README

How to run it and how to verify it.

## Deliverables

A git repository (or an archive) containing your chart, Terraform, pipeline, and README. Keep
the provided `app/` folder as-is.

A short presentation of the solution.
