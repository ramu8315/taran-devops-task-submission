#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAMESPACE="${NAMESPACE:-score-api}"
RELEASE_NAME="${RELEASE_NAME:-score-api}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"

TERRAFORM_DIR="${ROOT_DIR}/terraform"

echo
echo "============================================================"
echo " TaranDM Score API - CLEAN ENVIRONMENT"
echo "============================================================"

# ------------------------------------------------------------
# Confirm destructive operation
# ------------------------------------------------------------

read -r -p "Remove existing deployment and Minikube cluster? [y/N] " CONFIRM

if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# ------------------------------------------------------------
# Remove Helm release
# ------------------------------------------------------------

echo
echo "==> Removing Helm release..."

if helm status "${RELEASE_NAME}" \
    -n "${NAMESPACE}" >/dev/null 2>&1; then

    helm uninstall \
        "${RELEASE_NAME}" \
        -n "${NAMESPACE}"

    echo "Helm release removed."
else
    echo "Helm release not found. Skipping."
fi

# ------------------------------------------------------------
# Destroy Terraform resources
# ------------------------------------------------------------

echo
echo "==> Destroying Terraform resources..."

if [[ -d "${TERRAFORM_DIR}" ]]; then

    terraform -chdir="${TERRAFORM_DIR}" init \
        -input=false \
        -reconfigure

    if terraform -chdir="${TERRAFORM_DIR}" state list \
        >/dev/null 2>&1; then

        terraform -chdir="${TERRAFORM_DIR}" destroy \
            -auto-approve \
            -input=false \
            -var="basic_auth_password=dummy-password" \
            -var="image_repository=score-api" \
            -var="image_tag=local" \
            -var="namespace=${NAMESPACE}" \
            -var="ingress_host=score-api.local"

        echo "Terraform resources destroyed."
    else
        echo "No Terraform resources found. Skipping."
    fi
else
    echo "Terraform directory not found. Skipping."
fi

# ------------------------------------------------------------
# Remove namespace if anything remains
# ------------------------------------------------------------

echo
echo "==> Removing Kubernetes namespace..."

if kubectl get namespace "${NAMESPACE}" \
    >/dev/null 2>&1; then

    kubectl delete namespace "${NAMESPACE}" \
        --wait=true \
        --timeout=120s

    echo "Namespace removed."
else
    echo "Namespace not found. Skipping."
fi

# ------------------------------------------------------------
# Remove Terraform local state
# ------------------------------------------------------------

echo
echo "==> Cleaning Terraform state..."

rm -rf "${TERRAFORM_DIR}/.terraform"

rm -f \
    "${TERRAFORM_DIR}/terraform.tfstate" \
    "${TERRAFORM_DIR}/terraform.tfstate.backup"

echo "Terraform state/cache cleaned."
echo ".terraform.lock.hcl preserved."

# ------------------------------------------------------------
# Delete Minikube cluster
# ------------------------------------------------------------

echo
echo "==> Deleting Minikube cluster..."

if minikube status \
    -p "${MINIKUBE_PROFILE}" \
    >/dev/null 2>&1; then

    minikube delete \
        -p "${MINIKUBE_PROFILE}"

    echo "Minikube cluster deleted."
else
    echo "Minikube cluster not found. Skipping."
fi

# ------------------------------------------------------------
# Complete
# ------------------------------------------------------------

echo
echo "============================================================"
echo " CLEANUP COMPLETED"
echo "============================================================"
echo
echo "Environment is ready for a fresh deployment."
echo
echo "Run:"
echo "  ./scripts/deploy.sh"