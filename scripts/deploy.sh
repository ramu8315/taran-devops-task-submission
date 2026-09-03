#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-score-api}"
IMAGE_TAG="${IMAGE_TAG:-local}"
NAMESPACE="${NAMESPACE:-score-api}"
INGRESS_HOST="${INGRESS_HOST:-score-api.local}"
BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-devsecret}"
CLIENT_ID="${CLIENT_ID:-CL-0001}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required." >&2
    exit 1
  }
}

for cmd in docker minikube kubectl helm terraform curl; do
  require_cmd "$cmd"
done

echo "==> Starting Minikube if needed"
if ! minikube status -p minikube --output=json 2>/dev/null | grep -q '"Host": "Running"'; then
  minikube start
fi

echo "==> Enabling Minikube ingress"
minikube addons enable ingress

echo "==> Building ${IMAGE_REPOSITORY}:${IMAGE_TAG}"
docker build -t "${IMAGE_REPOSITORY}:${IMAGE_TAG}" "${ROOT_DIR}/app"

echo "==> Loading image into Minikube"
minikube image load "${IMAGE_REPOSITORY}:${IMAGE_TAG}"

echo "==> Validating Helm chart"
helm lint "${ROOT_DIR}/helm/score-api"

echo "==> Initializing Terraform"
terraform -chdir="${ROOT_DIR}/terraform" init -input=false

echo "==> Validating Terraform"
terraform -chdir="${ROOT_DIR}/terraform" validate

echo "==> Applying Terraform"
terraform -chdir="${ROOT_DIR}/terraform" apply   -auto-approve   -input=false   -var="basic_auth_password=${BASIC_AUTH_PASSWORD}"   -var="image_repository=${IMAGE_REPOSITORY}"   -var="image_tag=${IMAGE_TAG}"   -var="namespace=${NAMESPACE}"   -var="ingress_host=${INGRESS_HOST}"

echo "==> Waiting for deployment"
kubectl rollout status   "deployment/score-api"   -n "${NAMESPACE}"   --timeout=180s

echo "==> Waiting for ingress controller"
kubectl wait   --namespace ingress-nginx   --for=condition=available   deployment/ingress-nginx-controller   --timeout=180s

MINIKUBE_IP="$(minikube ip)"

curl_with_host() {
  curl --fail --silent --show-error     --resolve "${INGRESS_HOST}:80:${MINIKUBE_IP}"     "$@"
}

echo "==> Checking GET /healthz"
HEALTH_RESPONSE="$(curl_with_host "http://${INGRESS_HOST}/healthz")"
echo "${HEALTH_RESPONSE}"

python3 - "${HEALTH_RESPONSE}" <<'PY'
import json
import sys

body = json.loads(sys.argv[1])
assert body.get("status") == "ok", body
PY

echo "==> Checking POST /decision"
DECISION_RESPONSE="$(
  curl_with_host     -u "score:${BASIC_AUTH_PASSWORD}"     -H "Content-Type: application/json"     -X POST     "http://${INGRESS_HOST}/decision"     -d "{\"client_id\":\"${CLIENT_ID}\",\"amount\":1500}"
)"
echo "${DECISION_RESPONSE}"

python3 - "${DECISION_RESPONSE}" <<'PY'
import json
import sys

body = json.loads(sys.argv[1])
assert body.get("client_id") == "CL-0001", body
assert body.get("decision") == "APPROVE", body
assert body.get("state") == "FINISHED", body
assert isinstance(body.get("score"), (int, float)), body
PY

echo
echo "SUCCESS: Score API is deployed and verified through Ingress."
