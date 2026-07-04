# check-host-inventory

Generate an infrastructure SBOM: OS, installed packages, kernel modules, Docker images, USB devices, listening ports.

Unlike `check-sbom` (which scans a code project's dependencies), this scans the **host system** itself.

## Use case

- Server inventory for compliance (EU CRA, NIS2)
- CVE scanning of production infrastructure
- Drift detection between expected and actual state
- Integration with Ansible for automated remediation

## Prerequisites

- `python3` (required)
- `syft` (optional, for CycloneDX SBOM generation)
- `grype` (optional, for CVE scanning with `--scan` flag)
- `docker` (optional, for Docker image inventory)

## Usage

```bash
# Inventory only (fast)
check-host-inventory.sh

# Inventory + CVE scan (slow, downloads vulnerability DB)
check-host-inventory.sh --scan
```

## Integration with Ansible

The host-inventory check provides the tooling. Ansible provides the orchestration:

```yaml
# In your Ansible playbook:
- name: Run host inventory scan
  command: /usr/local/bin/check-host-inventory.sh --scan
  register: scan_result

- name: Notify on critical CVEs
  uri:
    url: "http://localhost:8123/api/services/notify/broadcast"
    # ...
  when: scan_result.rc == 1
```

## Output

- `.tmp/host-inventory.json` - system inventory (packages, Docker, USB, ports)
- `.tmp/host-sbom.json` - CycloneDX SBOM of OS packages (if syft available)
- `.tmp/docker-sboms/` - per-image CycloneDX SBOMs
- `.tmp/host-cves.json` - CVE scan results (with --scan flag)

## Severity

Fails (exit 1) when critical CVEs are found with `--scan` flag.

## References

- Source: `checks/universal/security/check-host-inventory.sh`
- [syft](https://github.com/anchore/syft)
- [grype](https://github.com/anchore/grype)
- [CycloneDX](https://cyclonedx.org/)
