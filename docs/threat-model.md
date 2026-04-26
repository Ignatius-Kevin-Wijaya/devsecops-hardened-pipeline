# Threat Model

## Assets

- Source code and workflow definitions in this repository
- Container images pushed to the registry
- SBOM artifacts and Cosign attestations
- Deployment-time credentials issued by Vault
- Kubernetes manifests and the cluster admission policy set

## Threat Actors

- External attacker reading public git history for leaked credentials
- Malicious contributor or compromised dependency attempting source-level injection
- Registry attacker attempting to swap or replay container images
- Overprivileged CI job or third-party action consuming secrets it should not have
- Cluster operator or application team accidentally deploying an unsafe manifest

## Control Mapping

| Threat | Primary control | What it does not solve |
| --- | --- | --- |
| Secret committed to git | Gitleaks in pre-commit and full-history CI scan | Cannot rotate secrets for you after exposure |
| Unsafe data flow in app code | Semgrep custom taint rule | Does not prove runtime exploitability |
| Vulnerable packages and insecure manifests | Trivy image and IaC scanning | Cannot guarantee the scanned tag is what runs unless deployment is pinned by digest |
| Unknown component inventory | Syft CycloneDX SBOM | Does not itself block deployment |
| Image tampering after push | Cosign keyless signing and verify-before-deploy | Does not protect unsigned images if verification is skipped |
| Static CI secret sprawl | Vault JWT auth with short-lived credentials | Still depends on Vault availability and correct auth role binding |
| Insecure runtime manifests | Gatekeeper admission policies | Does not replace upstream CI checks or cryptographic signature verification |

## Residual Risk

- The deploy workflow renders a pinned manifest but does not include live cluster credentials in this repository.
- Gatekeeper enforces manifest-time policy but signature verification still happens in CI before deploy rather than inside the cluster.
- GitHub-hosted runners and third-party actions remain part of the trust boundary even with pinned SHAs and minimal permissions.
- The sample application is intentionally small, so the SAST and runtime policy coverage demonstrates patterns more than broad application attack surface.
