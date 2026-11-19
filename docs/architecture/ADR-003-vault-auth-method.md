# ADR-003: Vault Authentication Method — JWT/OIDC vs. Static Token

**Status:** Accepted

**Context:** The CI pipeline needs to retrieve secrets from HashiCorp Vault.
Two approaches were considered:

1. **Static `VAULT_TOKEN`** — generate a Vault token manually, store it as a
   GitHub Actions secret, and pass it to `hashicorp/vault-action` via the
   `token` input. Simple to set up, widely documented.

2. **JWT/OIDC auth method** — configure Vault's JWT auth method to trust
   GitHub Actions' OIDC provider. The workflow requests a short-lived OIDC
   identity token from GitHub, presents it to Vault, and Vault issues an
   ephemeral Vault token scoped to the configured policy and TTL.

**The critical insight:** Storing a `VAULT_TOKEN` as a GitHub secret is
*moving* a secret, not eliminating one. The question is: what's the meaningful
security improvement over just storing the database password as a GitHub secret?
The answer is narrow — only policy enforcement and audit logging. The credential
itself is still long-lived and static.

JWT/OIDC eliminates the static credential entirely:
- No `VAULT_TOKEN` with a long TTL exists anywhere
- The OIDC token GitHub issues is bound to the specific repo and to the job's
  context; for the deploy job that is its GitHub environment
  (`sub: repo:Ignatius-Kevin-Wijaya/devsecops-hardened-pipeline:environment:kind-ci`)
- Vault tokens issued have a 5-minute TTL and are automatically revoked
- A leaked token is useless within minutes; a leaked static Vault token
  remains valid until manually rotated

**Decision:** Use the JWT/OIDC auth method. The role is bound to the `kind-ci`
environment of this repository, so no other repository, and no job outside that
environment, can obtain credentials even if it attempts to authenticate.

**Update (Nov 2026):**

- *Environment subject, not branch.* The role was first bound to
  `repo:…:ref:refs/heads/main`. That could never match the deploy job: a job that
  uses a GitHub environment presents `repo:…:environment:<name>` whatever its
  branch, and a tag-triggered release would present `ref:refs/tags/…` anyway.
  The role is now bound to the environment subject. Every release run shows the
  difference: the deploy job logs in through the environment-bound role, and a
  role with the old branch binding rejects the same token.
- *In-job Vault.* No Vault server was reachable from GitHub-hosted runners, so the
  login step could never run. The deploy job now starts a dev-mode Vault,
  configures it with `vault/config/jwt-auth-config.sh`, revokes the root token,
  and only then logs in with the job's OIDC token. The job reads
  `secret/ci/demo` and checks that reads outside `secret/ci/` are denied. This
  proves the OIDC exchange, the role binding and the policy. It does not prove
  the availability of a real Vault; the same script configures one.
- *Database secrets engine removed.* The policy no longer grants
  `database/creds/ci-role`; nothing in the project uses a database.

**Consequences:**
- **Positive:** No persistent credential stored anywhere — not in GitHub
  secrets, not in the Vault token accessor database with a long TTL
- **Positive:** Every credential request is tied to a specific, auditable
  GitHub Actions OIDC identity in Vault's audit log
- **Positive:** TTL enforcement is automatic — credentials cannot persist
  beyond the job lifetime
- **Negative:** Requires Vault to be network-accessible from GitHub Actions
  runners and the JWT auth method to be configured before first use
- **Negative:** Local development cannot use the same auth path — developers
  need a separate Vault auth method (e.g., userpass or approle)
- **Accepted trade-off:** The operational complexity of configuring JWT auth
  once is far outweighed by the elimination of static long-lived credentials.
