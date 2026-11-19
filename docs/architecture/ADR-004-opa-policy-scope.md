# ADR-004: Gatekeeper Policy Scope — Admission Guardrails vs. Cryptographic Verification

**Status:** Accepted

**Context:** The project needs an admission-control layer that complements CI
security checks. Gatekeeper is strong at evaluating Kubernetes object structure
at admission time, but it does not natively perform Cosign signature validation
for container images without extra components or external data providers.

**Decision:** Use Gatekeeper for three cluster-side guardrails:

1. Require `runAsNonRoot: true`
2. Require CPU and memory resource limits
3. Require images to come from the trusted registry and be pinned by digest

Cosign signature verification remains in the deploy workflow before any manifest
is rendered or applied. The trusted-image Gatekeeper policy starts in `dryrun`
mode, then moves to deny once the cluster baseline is clean and all workloads
deploy by digest.

**Update (Nov 2026):** The trusted-image constraint is now `deny`, like the other
two. The only cluster is the throwaway kind cluster from ADR-006, which has no
existing workloads to baseline. Admission tests run on every push and pull
request and again in every release, so each policy is shown both admitting the
real manifest and denying the violation it targets. The constraints match
cluster-wide; a shared cluster should exclude its system and add-on namespaces.

**Consequences:**

- **Positive:** The cluster enforces structural manifest policy even if a team
  bypasses part of the CI pipeline.
- **Positive:** Registry allowlisting plus digest pinning gives a practical,
  enforceable provenance control without pretending Gatekeeper alone verifies
  cryptographic signatures.
- **Positive:** The audit-to-enforce transition follows the curriculum's
  governance model and reduces the chance of breaking existing workloads.
- **Negative:** Signature verification is split across layers: CI verifies
  Cosign, while Gatekeeper verifies registry and digest provenance only.
- **Accepted trade-off:** Full in-cluster signature validation would require
  additional components and operational overhead that are out of scope for this
  portfolio project.
