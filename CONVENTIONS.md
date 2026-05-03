# Tool & Component Naming Conventions

This project follows a strict naming convention for tools, components, and internal steps (quality gates) to ensure consistency across the ecosystem and compatibility with reporting systems.

## 1. The 4-Element Formula

Every tool or component name, as well as every internal quality gate, is constructed using four elements:
`domain`-`flavor`-`intent`-`method`

| Element | Description | Examples |
|:---|:---|:---|
| **Domain** | What is it running on/targeting? | `code`, `libs`, `artifact`, `workload`, `docs`, `meta`, `configuration` |
| **Flavor** | Specialization/Language/Format | `cpp`, `c`, `typescript`, `python`, `generic`, `docker`, `yaml`, `markdown`, `makefile` |
| **Intent** | What is it doing/finding? | `vulnerability`, `license`, `version`, `syntax`, `todo`, `functionality`, `policy`, `loc`, `complexity`, `quality` |
| **Method** | The method used | `audit`, `detect`, `lint`, `processor`, `test`, `scan`, `validate`, `measure`, `build`, `format` |

### Naming Formats:
- **CLI/Project Name**: `kebab-case` (e.g., `code-cpp-vulnerability-scan`)
- **Reporting Type**: `snake_case` (e.g., `code_cpp_vulnerability_scan`)
- **Pipeline Gating**: `UPPER_SNAKE_CASE` (e.g., `CODE_CPP_VULNERABILITY_SCAN`)

---

## 2. Step Naming (Internal Quality Gates)

Within `cpm`, the steps executed during `cpm lint` or `cpm check` follow this same formula.

| Old Name | New Standardized Step Name |
|:---|:---|
| `format-code` | `code-cpp-syntax-format` |
| `format-yaml` | `code-yaml-syntax-format` |
| `format-md` | `docs-markdown-syntax-format` |
| `lint-code` | `code-cpp-syntax-lint` |
| `complexity` | `code-cpp-complexity-measure` |
| `comment-ratio` | `code-cpp-comment-measure` |
| `lint-makefile` | `configuration-makefile-policy-validate` |
| `sast-security` | `code-generic-vulnerability-scan` |

---

## 3. Development Workflow (Zero-Boilerplate)

### Step 1: Scaffolding
Use the convention to name your new project:
```bash
cpm new code-cpp-syntax-lint
```

### Step 2: Zero-Boilerplate Execution
`cpm` uses internal defaults for all steps. When you run `cpm lint`, it will output results using the standardized step names:
```bash
cpm lint
# Output:
# ✓ code-cpp-syntax-format
# ✓ code-cpp-complexity-measure
# ...
```

### Step 3: Customization (Eject)
If you need to override a specific step's behavior, use `cpm eject` to see the underlying configurations, or add an override in `cpm.toml` using the standardized step name.
