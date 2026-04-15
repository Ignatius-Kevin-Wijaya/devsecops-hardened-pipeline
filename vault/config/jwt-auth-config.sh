#!/usr/bin/env bash
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
GITHUB_REPO="${GITHUB_REPO:-Ignatius-Kevin-Wijaya/devsecops-hardened-pipeline}"
BOUND_AUDIENCES="${BOUND_AUDIENCES:-https://github.com/Ignatius-Kevin-Wijaya}"

echo "==> Enabling JWT auth method"
vault auth enable jwt 2>/dev/null || echo "JWT auth already enabled"

echo "==> Configuring JWT auth with GitHub OIDC issuer"
vault write auth/jwt/config \
  oidc_discovery_url="https://token.actions.githubusercontent.com" \
  bound_issuer="https://token.actions.githubusercontent.com"

echo "==> Writing CI pipeline policy"
vault policy write ci-pipeline vault/config/vault-policy.hcl

echo "==> Creating JWT role for GitHub Actions"
vault write auth/jwt/role/github-actions \
  role_type="jwt" \
  bound_audiences="${BOUND_AUDIENCES}" \
  bound_claims_type="glob" \
  bound_claims="{\"sub\": \"repo:${GITHUB_REPO}:ref:refs/heads/main\"}" \
  user_claim="sub" \
  policies="ci-pipeline" \
  ttl="5m" \
  max_ttl="10m"

echo ""
echo "==> JWT auth configured. Workflow can now authenticate with:"
echo "    method: jwt"
echo "    role:   github-actions"
echo "    url:    \$VAULT_ADDR"
