#!/usr/bin/env bash
# Create a throwaway kind cluster with Gatekeeper and this repository's
# admission policies, and wait until every constraint actually denies requests.
#
# Used by CI (admission tests on every push and PR) and by the release deploy
# job. Every download is pinned to a version and checked against a SHA-256.
set -euo pipefail

KIND_VERSION="v0.33.0"
KIND_SHA256="aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d"
KUBECTL_VERSION="v1.36.4"
KUBECTL_SHA256="8b8f088da2dab964f853b38464033b1be15ede2839eca751482357c45abdd05a"
NODE_IMAGE="kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed"
GATEKEEPER_VERSION="v3.23.1"
GATEKEEPER_SHA256="3c178abe6de4dcdcd2810c2945468a0d7a15ccf0036e324b73308643e94d6f72"

CLUSTER_NAME="${CLUSTER_NAME:-devsecops-ci}"
APP_NAMESPACE="${APP_NAMESPACE:-devsecops-demo}"
POLICY_DIR="${POLICY_DIR:-policies/gatekeeper}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

log() { printf '\n==> %s\n' "$*"; }

# wait_for <description> <timeout-seconds> <command...>
wait_for() {
  local what=$1 timeout=$2
  shift 2
  local deadline=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      echo "Timed out after ${timeout}s waiting for ${what}" >&2
      return 1
    fi
    sleep 2
  done
}

# fetch_verified <url> <sha256> <destination>
fetch_verified() {
  curl -sSfL --retry 3 "$1" -o "$3"
  echo "$2  $3" | sha256sum --check --quiet -
}

install_tools() {
  log "Installing kind ${KIND_VERSION} and kubectl ${KUBECTL_VERSION}"
  local tmp
  tmp=$(mktemp -d)
  fetch_verified "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" \
    "$KIND_SHA256" "$tmp/kind"
  fetch_verified "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    "$KUBECTL_SHA256" "$tmp/kubectl"
  mkdir -p "$BIN_DIR"
  install -m 0755 "$tmp/kind" "$tmp/kubectl" "$BIN_DIR/"
  rm -rf "$tmp"
  export PATH="$BIN_DIR:$PATH"
  # Later workflow steps find the same binaries first.
  if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$BIN_DIR" >>"$GITHUB_PATH"; fi
  kind version
  kubectl version --client
}

create_cluster() {
  log "Creating kind cluster ${CLUSTER_NAME}"
  kind create cluster --name "$CLUSTER_NAME" --image "$NODE_IMAGE" --wait 120s
}

install_gatekeeper() {
  log "Installing Gatekeeper ${GATEKEEPER_VERSION}"
  local manifest
  manifest=$(mktemp --suffix .yaml)
  fetch_verified "https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml" \
    "$GATEKEEPER_SHA256" "$manifest"
  kubectl apply -f "$manifest"
  # One webhook replica: every admission request reaches the same pod, so once
  # it enforces the constraints, every later request gets the same answer.
  kubectl -n gatekeeper-system scale deployment/gatekeeper-controller-manager --replicas=1
  kubectl -n gatekeeper-system rollout status deployment/gatekeeper-controller-manager --timeout=180s
  kubectl -n gatekeeper-system rollout status deployment/gatekeeper-audit --timeout=180s
}

apply_policies() {
  log "Applying ConstraintTemplates from ${POLICY_DIR}/templates"
  kubectl apply -f "$POLICY_DIR/templates/"
  local template crd
  for template in "$POLICY_DIR"/templates/*.yaml; do
    # Gatekeeper names each constraint CRD after the template.
    crd="$(kubectl get -f "$template" -o jsonpath='{.metadata.name}').constraints.gatekeeper.sh"
    wait_for "CRD ${crd}" 120 kubectl get crd "$crd"
    kubectl wait --for=condition=established --timeout=60s "crd/${crd}"
  done

  log "Applying constraints from ${POLICY_DIR}/constraints"
  kubectl apply -f "$POLICY_DIR/constraints/"
}

# A Deployment that breaks all three policies at once.
violating_deployment() {
  cat <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gatekeeper-readiness-probe
spec:
  selector:
    matchLabels: {app: gatekeeper-readiness-probe}
  template:
    metadata:
      labels: {app: gatekeeper-readiness-probe}
    spec:
      containers:
        - name: probe
          image: docker.io/library/nginx:latest
EOF
}

all_constraints_deny() {
  local out
  if out=$(violating_deployment | kubectl apply --dry-run=server -n "$APP_NAMESPACE" -f - 2>&1); then
    return 1
  fi
  grep -q 'require-trusted-image-digest' <<<"$out" &&
    grep -q 'require-runasnonroot' <<<"$out" &&
    grep -q 'require-resource-limits' <<<"$out"
}

wait_for_enforcement() {
  log "Creating namespace ${APP_NAMESPACE}"
  kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  # Gatekeeper's webhook fails open while it is not ready, so wait until it
  # really denies before any test relies on it.
  log "Waiting until every constraint denies a violating Deployment"
  wait_for "all constraints to enforce" 180 all_constraints_deny
  kubectl get constraints
}

install_tools
create_cluster
install_gatekeeper
apply_policies
wait_for_enforcement
log "Cluster ${CLUSTER_NAME} is ready and Gatekeeper enforces every constraint"
