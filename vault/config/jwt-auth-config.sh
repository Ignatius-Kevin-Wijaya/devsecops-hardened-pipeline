#!/usr/bin/env bash
# Configure Vault's JWT auth method to trust GitHub Actions OIDC tokens.
#
# The role is bound to the deploy job's GitHub environment. A job that uses an
# environment presents the subject repo:<owner>/<repo>:environment:<name>, so a
# branch-scoped binding (ref:refs/heads/main) would never match it.
#
# The release workflow runs this against an in-job dev-mode Vault; the same
# script configures a real Vault.
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_ADDR
GITHUB_REPO="${GITHUB_REPO:-${GITHUB_REPOSITORY:-Ignatius-Kevin-Wijaya/devsecops-hardened-pipeline}}"
BOUND_ENVIRONMENT="${BOUND_ENVIRONMENT:-kind-ci}"
BOUND_AUDIENCES="${BOUND_AUDIENCES:-https://github.com/Ignatius-Kevin-Wijaya}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Enabling JWT auth method"
vault auth enable jwt 2>/dev/null || echo "JWT auth already enabled"

echo "==> Configuring JWT auth with GitHub OIDC issuer"
vault write auth/jwt/config \
  oidc_discovery_url="https://token.actions.githubusercontent.com" \
  bound_issuer="https://token.actions.githubusercontent.com"

echo "==> Writing CI pipeline policy"
vault policy write ci-pipeline "${SCRIPT_DIR}/vault-policy.hcl"

echo "==> Creating JWT role for GitHub Actions"
vault write auth/jwt/role/github-actions \
  role_type="jwt" \
  bound_audiences="${BOUND_AUDIENCES}" \
  bound_subject="repo:${GITHUB_REPO}:environment:${BOUND_ENVIRONMENT}" \
  user_claim="sub" \
  policies="ci-pipeline" \
  ttl="5m" \
  max_ttl="10m"

echo ""
echo "==> JWT auth configured. A job in the '${BOUND_ENVIRONMENT}' environment can authenticate with:"
echo "    method: jwt"
echo "    role:   github-actions"
echo "    url:    \$VAULT_ADDR"
