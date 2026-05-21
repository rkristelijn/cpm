# cpm sbom

Generate a Software Bill of Materials (CycloneDX format).

## Usage

```bash
cpm sbom
```

## Supported ecosystems

| Language | Tool used |
|----------|-----------|
| JS/TS | @cyclonedx/cyclonedx-npm |
| Rust | cargo-cyclonedx |
| Go | cyclonedx-gomod |
| Java | cyclonedx-maven-plugin |
| PHP | cyclonedx-php-composer |

## Output

Generates `sbom.json` in CycloneDX format. Use for supply chain transparency and compliance (ISO 27001, SOC 2).
