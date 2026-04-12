# ADR-001: Deployment Target Selection

**Status:** Accepted  
**Context:** Need a Kubernetes target for OPA/Gatekeeper work without 
running up Azure costs during development.  
**Decision:** Use kind locally for cluster policy work; Azure Container 
Apps for deployed artifacts.  
**Consequences:** AKS-specific features (node pools, Azure CNI) won't 
be demonstrated. Trade-off accepted — cost constraint is real.
