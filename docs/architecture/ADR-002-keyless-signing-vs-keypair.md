# ADR-002: Keyless Image Signing via Sigstore vs. Long-lived Key Pair

**Status:** Accepted

**Context:** Container images built by CI must be signed before deployment to
establish a cryptographic chain of custody. Two approaches exist:

1. **Traditional key pair** — a Cosign-generated key pair where the private key
   is stored as a GitHub Actions secret and the public key is committed to the
   repository. Every `cosign sign` invocation uses this static private key.
2. **Keyless signing via Sigstore** — Cosign obtains an ephemeral key pair from
   Sigstore's Fulcio CA, tied to the GitHub Actions OIDC identity token. No
   long-lived key material exists anywhere.

**Decision:** Use keyless signing via Sigstore (Fulcio + Rekor).

**Consequences:**
- **Positive:** No key rotation burden. A compromised CI secret cannot
  retroactively invalidate past signatures because no persistent private key
  exists. The signature is bound to the OIDC identity (repo + workflow + ref),
  making it auditable in Rekor's transparency log.
- **Positive:** Verification uses the OIDC issuer and subject identity rather
  than a public key file, which is more descriptive and harder to confuse.
- **Negative:** Verification requires network access to Rekor's transparency
  log (or a local copy). Air-gapped environments may need a key pair fallback.
- **Negative:** Sigstore infrastructure is a trust dependency. If Fulcio or
  Rekor are unavailable, signing fails. This is acceptable for a portfolio
  project but would need a fallback strategy in production.
- **Accepted trade-off:** We depend on Sigstore's availability and trust model.
  For a portfolio project demonstrating modern practices, this is the correct
  choice — it shows understanding of ephemeral credentials and OIDC-based
  identity, which is the direction the industry is moving.
