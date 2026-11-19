#!/usr/bin/env bash
# Admission tests against a cluster prepared by kind-up.sh.
#
# Each case takes the real Deployment manifest, changes one thing, and sends it
# to the API server as a server-side dry run, so Gatekeeper makes the decision
# and nothing is created or pulled.
#
# Usage: admission-tests.sh <trusted-image-ref>
#   trusted-image-ref  an image from the trusted registry, pinned by digest.
#                      Dry runs never pull, so the digest does not have to exist.
set -euo pipefail

TRUSTED_IMAGE="${1:?usage: admission-tests.sh <registry/repository@sha256:digest>}"
APP_NAMESPACE="${APP_NAMESPACE:-devsecops-demo}"
MANIFEST="${MANIFEST:-k8s/deployment.yml}"
CONTAINER="${CONTAINER:-app}"

if [[ "$TRUSTED_IMAGE" != *@sha256:* ]]; then
  echo "trusted-image-ref must be pinned by digest: $TRUSTED_IMAGE" >&2
  exit 2
fi
DIGEST="${TRUSTED_IMAGE##*@}"
TAG_ONLY_IMAGE="${TRUSTED_IMAGE%@*}:v0.0.0" # same repository, referenced by tag
FOREIGN_IMAGE="docker.io/library/nginx@${DIGEST}" # pinned, but not from the trusted registry
CONTAINER_PATH="/spec/template/spec/containers/0"

failures=0

with_image() {
  kubectl set image --local -f "$MANIFEST" "${CONTAINER}=$1" -o yaml
}

without_field() {
  with_image "$TRUSTED_IMAGE" |
    kubectl patch --local -f - --type=json -p "[{\"op\": \"remove\", \"path\": \"$1\"}]" -o yaml
}

dry_run() {
  kubectl apply --dry-run=server -n "$APP_NAMESPACE" -f - 2>&1
}

report() {
  printf '%-5s %s\n' "$1" "$2"
  sed 's/^/        /' <<<"$3"
}

# expect_admitted <case> <manifest>
expect_admitted() {
  local out
  if out=$(dry_run <<<"$2"); then
    report PASS "$1: admitted" "$out"
  else
    report FAIL "$1: expected admission" "$out"
    failures=$((failures + 1))
  fi
}

# expect_denied <case> <expected message fragment> <manifest>
expect_denied() {
  local out
  if out=$(dry_run <<<"$3"); then
    report FAIL "$1: admitted, expected denial" "$out"
    failures=$((failures + 1))
  elif grep -qF -- "$2" <<<"$out"; then
    report PASS "$1: denied" "$out"
  else
    report FAIL "$1: denied, but not with \"$2\"" "$out"
    failures=$((failures + 1))
  fi
}

echo "Admission tests in namespace ${APP_NAMESPACE} (server-side dry run)"
echo

expect_admitted "Trusted registry, pinned by digest" \
  "$(with_image "$TRUSTED_IMAGE")"
expect_denied "Trusted registry, tag only" "must be pinned by digest" \
  "$(with_image "$TAG_ONLY_IMAGE")"
expect_denied "Foreign registry, pinned by digest" "must come from an approved registry prefix" \
  "$(with_image "$FOREIGN_IMAGE")"
expect_denied "runAsNonRoot removed" "[require-runasnonroot]" \
  "$(without_field "${CONTAINER_PATH}/securityContext/runAsNonRoot")"
expect_denied "Resource limits removed" "[require-resource-limits]" \
  "$(without_field "${CONTAINER_PATH}/resources/limits")"

echo
if ((failures > 0)); then
  echo "${failures} admission test(s) failed"
  exit 1
fi
echo "All admission tests passed"
