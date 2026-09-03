#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-score-api}"
IMAGE_TAG="${IMAGE_TAG:-local}"
NAMESPACE="${NAMESPACE:-score-api}"
INGRESS_HOST="${INGRESS_HOST:-score-api.local}"
CLIENT_ID="${CLIENT_ID:-CL-0001}"
DECISION_AMOUNT="${DECISION_AMOUNT:-1500}"

SECRET_NAME="score-api-auth"
DEPLOYMENT_NAME="score-api"
MINIKUBE_PROFILE="minikube"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: '$1' is required but was not found in PATH." >&2
        exit 1
    }
}

cleanup() {
    unset BASIC_AUTH_PASSWORD
    unset K8S_PASSWORD
    unset POD_PASSWORD
}

trap cleanup EXIT

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

echo "==> Checking required commands"

for cmd in docker minikube kubectl helm terraform curl python3 base64; do
    require_cmd "$cmd"
done

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

echo
echo "==> Enter Basic Auth password"

read -r -s -p "Enter BASIC_AUTH_PASSWORD: " BASIC_AUTH_PASSWORD
echo

if [[ -z "${BASIC_AUTH_PASSWORD}" ]]; then
    fail "BASIC_AUTH_PASSWORD cannot be empty."
fi

# ---------------------------------------------------------------------------
# Minikube
# ---------------------------------------------------------------------------

echo
echo "==> Starting Minikube if needed"

if ! minikube status \
        -p "${MINIKUBE_PROFILE}" \
        --output=json 2>/dev/null |
        grep -q '"Host": "Running"'; then

    minikube start -p "${MINIKUBE_PROFILE}"
fi

echo "==> Enabling Minikube Ingress"

minikube addons enable ingress -p "${MINIKUBE_PROFILE}"

# ---------------------------------------------------------------------------
# Build image
# ---------------------------------------------------------------------------

echo
echo "==> Building ${IMAGE_REPOSITORY}:${IMAGE_TAG}"

docker build \
    -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    "${ROOT_DIR}/app"

echo "==> Loading image into Minikube"

minikube image load \
    "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    -p "${MINIKUBE_PROFILE}"

# ---------------------------------------------------------------------------
# Helm validation
# ---------------------------------------------------------------------------

echo
echo "==> Validating Helm chart"

helm lint "${ROOT_DIR}/helm/score-api"

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------

echo
echo "==> Initializing Terraform"

terraform \
    -chdir="${ROOT_DIR}/terraform" \
    init \
    -input=false

echo "==> Validating Terraform"

terraform \
    -chdir="${ROOT_DIR}/terraform" \
    validate

echo "==> Applying Terraform"

terraform \
    -chdir="${ROOT_DIR}/terraform" \
    apply \
    -auto-approve \
    -input=false \
    -replace="kubernetes_secret_v1.score_api_auth" \
    -var="basic_auth_password=${BASIC_AUTH_PASSWORD}" \
    -var="image_repository=${IMAGE_REPOSITORY}" \
    -var="image_tag=${IMAGE_TAG}" \
    -var="namespace=${NAMESPACE}" \
    -var="ingress_host=${INGRESS_HOST}"

# ---------------------------------------------------------------------------
# Verify Kubernetes Secret
# ---------------------------------------------------------------------------

echo
echo "==> Verifying Kubernetes Secret"

K8S_PASSWORD="$(
    kubectl get secret "${SECRET_NAME}" \
        -n "${NAMESPACE}" \
        -o jsonpath='{.data.password}' |
        base64 -d
)"

if [[ "${BASIC_AUTH_PASSWORD}" == "${K8S_PASSWORD}" ]]; then
    echo "==> Secret verification: PASS"
else
    fail "Secret verification failed: password does not match."
fi

unset K8S_PASSWORD

# ---------------------------------------------------------------------------
# Restart application
#
# Secret values exposed through env.valueFrom are loaded when the Pod starts.
# Restarting ensures the Pod receives the current Secret value.
# ---------------------------------------------------------------------------

echo
echo "==> Restarting deployment to load updated Secret"

kubectl rollout restart \
    deployment/"${DEPLOYMENT_NAME}" \
    -n "${NAMESPACE}"

echo "==> Waiting for deployment rollout"

kubectl rollout status \
    deployment/"${DEPLOYMENT_NAME}" \
    -n "${NAMESPACE}" \
    --timeout=180s

# ---------------------------------------------------------------------------
# Verify Pod received Secret
# ---------------------------------------------------------------------------

echo
echo "==> Verifying Pod received updated Secret"

POD_NAME="$(
    kubectl get pods \
        -n "${NAMESPACE}" \
        -l app.kubernetes.io/name="${DEPLOYMENT_NAME}" \
        -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${POD_NAME}" ]]; then
    fail "Unable to find Score API Pod."
fi

POD_PASSWORD="$(
    kubectl exec \
        -n "${NAMESPACE}" \
        "${POD_NAME}" \
        -- printenv BASIC_AUTH_PASSWORD
)"

if [[ "${BASIC_AUTH_PASSWORD}" == "${POD_PASSWORD}" ]]; then
    echo "==> Pod Secret verification: PASS"
else
    fail "Pod password does not match Kubernetes Secret."
fi

unset POD_PASSWORD
unset POD_NAME

# ---------------------------------------------------------------------------
# Ingress readiness
# ---------------------------------------------------------------------------

echo
echo "==> Waiting for Ingress controller"

kubectl wait \
    --namespace ingress-nginx \
    --for=condition=available \
    deployment/ingress-nginx-controller \
    --timeout=180s

MINIKUBE_IP="$(minikube ip -p "${MINIKUBE_PROFILE}")"

echo "==> Minikube IP: ${MINIKUBE_IP}"
echo "==> Ingress host: ${INGRESS_HOST}"

# ---------------------------------------------------------------------------
# Curl helper
# ---------------------------------------------------------------------------

curl_with_host() {
    curl \
        --fail \
        --silent \
        --show-error \
        --connect-timeout 5 \
        --max-time 15 \
        --resolve "${INGRESS_HOST}:80:${MINIKUBE_IP}" \
        "$@"
}

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

echo
echo "==> Checking GET /healthz"

HEALTH_RESPONSE=""

for attempt in {1..12}; do

    if HEALTH_RESPONSE="$(
        curl_with_host \
            "http://${INGRESS_HOST}/healthz"
    )"; then

        echo "${HEALTH_RESPONSE}"
        break
    fi

    echo "Waiting for Ingress/application readiness (${attempt}/12)..."
    sleep 5
done

if [[ -z "${HEALTH_RESPONSE}" ]]; then
    fail "/healthz check failed."
fi

python3 - "${HEALTH_RESPONSE}" <<'PY'
import json
import sys

try:
    body = json.loads(sys.argv[1])
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON response: {exc}")

if body.get("status") != "ok":
    raise SystemExit(f"Unexpected health response: {body}")
PY

echo "==> /healthz: PASS"

# ---------------------------------------------------------------------------
# Decision API
# ---------------------------------------------------------------------------

echo
echo "==> Checking POST /decision"

DECISION_RESPONSE="$(
    curl_with_host \
        -u "score:${BASIC_AUTH_PASSWORD}" \
        -H "Content-Type: application/json" \
        "http://${INGRESS_HOST}/decision" \
        -d "{\"client_id\":\"${CLIENT_ID}\",\"amount\":${DECISION_AMOUNT}}"
)"

echo "${DECISION_RESPONSE}"

python3 - "${DECISION_RESPONSE}" "${CLIENT_ID}" <<'PY'
import json
import sys

try:
    body = json.loads(sys.argv[1])
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid JSON response: {exc}")

expected_client_id = sys.argv[2]

if body.get("client_id") != expected_client_id:
    raise SystemExit(f"Unexpected client_id: {body}")

if body.get("decision") not in {"APPROVE", "DECLINE"}:
    raise SystemExit(f"Unexpected decision: {body}")

if body.get("state") != "FINISHED":
    raise SystemExit(f"Unexpected state: {body}")

if not isinstance(body.get("score"), (int, float)):
    raise SystemExit(f"Invalid score: {body}")

if not body.get("decision_id"):
    raise SystemExit(f"Missing decision_id: {body}")
PY

echo "==> /decision: PASS"

# ---------------------------------------------------------------------------
# Final result
# ---------------------------------------------------------------------------

echo
echo "============================================================"
echo "SUCCESS: Score API deployed and verified successfully."
echo "============================================================"
echo
echo "Endpoints verified:"
echo "  GET  http://${INGRESS_HOST}/healthz"
echo "  POST http://${INGRESS_HOST}/decision"
echo
echo "Client ID : ${CLIENT_ID}"
echo "Amount    : ${DECISION_AMOUNT}"