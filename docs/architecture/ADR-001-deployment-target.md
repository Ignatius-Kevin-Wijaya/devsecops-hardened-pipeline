# ADR-001: Deployment Target Selection

**Status:** Superseded by [ADR-006](ADR-006-kind-in-ci-deploy-target.md)  
**Context:** Need a Kubernetes target for OPA/Gatekeeper work without 
running up Azure costs during development.  
**Decision:** Use kind locally for cluster policy work; Azure Container 
Apps for deployed artifacts.  
**Consequences:** AKS-specific features (node pools, Azure CNI) won't 
be demonstrated. Trade-off accepted — cost constraint is real.  
**Outcome:** The Azure Container Apps deploy was never built. ADR-006 moves
the deploy to a kind cluster created inside the release job.
