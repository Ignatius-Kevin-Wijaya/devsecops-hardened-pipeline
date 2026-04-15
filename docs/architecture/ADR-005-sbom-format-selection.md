# ADR-005: SBOM Format Selection — CycloneDX vs. SPDX

**Status:** Accepted

**Context:** Syft supports multiple SBOM output formats. The two dominant
standards are CycloneDX and SPDX. A format must be selected for the SBOM
generated and attested to each container image.

**SPDX:**
- Originally designed for license compliance use cases; broader legal toolchain
  support
- SPDX 2.x is well-established; SPDX 3.0 adds vulnerability linking but
  toolchain support is still maturing
- SPDX JSON and SPDX tag-value formats are common; the JSON format is
  machine-readable but more verbose

**CycloneDX:**
- Designed specifically for security use cases from the start; VEX (Vulnerability
  Exploitability eXchange) integration is a first-class feature
- Richer vulnerability data linking: components in CycloneDX can reference CVEs
  and VEX statements directly within the SBOM document
- Widely supported by vulnerability scanners (Trivy, Grype) and policy tools
- JSON format is compact, well-documented, and straightforward to query with jq
  or Python

**Decision:** Use CycloneDX JSON format via Syft's `cyclonedx-json` output.

**Consequences:**
- **Positive:** Vulnerability scanners can consume the SBOM directly to answer
  fleet-wide CVE exposure queries (e.g., "which images contain log4j?")
- **Positive:** VEX statements can be embedded or linked for documented risk
  acceptances — this is the senior-level differentiator in SBOM workflows
- **Positive:** The `scripts/query-sbom.py` script demonstrates reading component
  data programmatically, validating the SBOM is machine-consumable
- **Negative:** If the primary requirement were license compliance auditing, SPDX
  would have stronger toolchain support for that workflow
- **Accepted trade-off:** For a security-focused pipeline, CycloneDX's
  vulnerability-centric design is the correct choice. License compliance is out
  of scope for this project.
