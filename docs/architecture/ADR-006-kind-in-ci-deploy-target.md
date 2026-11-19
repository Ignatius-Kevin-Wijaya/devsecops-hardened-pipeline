# ADR-006: Deployment Target — a kind Cluster Inside the Release Job

**Status:** Accepted. Supersedes [ADR-001](ADR-001-deployment-target.md).

**Context:** ADR-001 chose Azure Container Apps for deployed artifacts. That path
was never built: `deploy.yml` was never called, and its deploy step only printed
a message, so the last stage of the pipeline could not be shown working. A
persistent cluster would cost money while idle and would need stored cluster
credentials, which this project avoids everywhere else.

**Decision:** The release workflow creates a kind cluster inside the deploy job.
In that job it:

1. verifies the Cosign signature and the CycloneDX SBOM attestation;
2. logs in to an in-job Vault with the job's GitHub OIDC token (ADR-003);
3. installs Gatekeeper with this repository's constraints, all in `deny` (ADR-004);
4. runs the admission tests: a tag-only image and a foreign image are rejected,
   and so is the real manifest with `runAsNonRoot` or resource limits removed;
5. applies the signed, digest-pinned manifest, waits for the rollout and smoke
   tests the Service.

The cluster disappears with the runner. The same `scripts/ci/kind-up.sh` and
`scripts/ci/admission-tests.sh` also run on every push and pull request, against
a placeholder digest, so policy changes are tested before a release.

**Consequences:**

- **Positive:** Every release proves the whole chain on real Kubernetes, from
  signature verification to an HTTP response, and the proof is in the run log.
- **Positive:** No cluster credentials are stored, and it costs nothing.
- **Positive:** Gatekeeper policy changes are tested on every pull request.
- **Negative:** Nothing stays running, so there is no environment to visit after
  the run. Cloud deployment (Terraform-managed EKS, GitOps) is the separate
  `gitops-k8s-platform` project.
- **Negative:** kind is not a managed cluster: no cloud load balancer, cloud IAM
  or node pools.
- **Negative:** Image pull credentials come from the job's `GITHUB_TOKEN` and
  expire with it. A long-lived cluster would need a public package or another
  pull mechanism.
