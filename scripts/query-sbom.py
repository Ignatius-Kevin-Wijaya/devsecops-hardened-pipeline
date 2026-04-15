#!/usr/bin/env python3
import json
import sys


def query_sbom(sbom_path: str) -> None:
    with open(sbom_path) as f:
        sbom = json.load(f)

    components = sbom.get("components", [])
    print(f"SBOM contains {len(components)} components")

    openssl_versions = [
        f"{c.get('name')}=={c.get('version', 'unknown')}"
        for c in components
        if "openssl" in c.get("name", "").lower()
    ]

    if openssl_versions:
        print(f"OpenSSL components found: {', '.join(openssl_versions)}")
    else:
        print("No openssl component found in SBOM")

    flask_versions = [
        f"{c.get('name')}=={c.get('version', 'unknown')}"
        for c in components
        if c.get("name", "").lower() == "flask"
    ]
    if flask_versions:
        print(f"Flask: {', '.join(flask_versions)}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: query-sbom.py <sbom.cyclonedx.json>")
        sys.exit(1)
    query_sbom(sys.argv[1])
