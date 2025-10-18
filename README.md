# PMDocu-DR

Documentation and Digital Record System.

---

## 🧭 CI Status

| Workflow | Status | Description |
|-----------|--------|--------------|
| 🪶 **Build README** | [![Build README](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-readme.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-readme.yml) | Auto-generates `README.md` from `README.template.md`, injects repository name, logs evidence, and commits automatically in CI. |
| 🧹 **Build and Sign Docs** | [![Build and Sign Docs](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-docs.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-docs.yml) | Converts Markdown → PDF → Signs → Uploads artifacts. Skips rebuild if no `.md` changes detected. |
| 🔏 **Verify Signatures** | [![Verify Signatures](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/verify-signature.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/verify-signature.yml) | Verifies Authenticode + GPG signatures and SHA-256 hashes for all build artifacts. |
| 🧩 **Lint PowerShell** | [![Lint PowerShell](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/lint-powershell.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/lint-powershell.yml) | Runs `PSScriptAnalyzer` using repo-defined compliance rules. |
| 📝 **Lint Markdown** | [![Lint Markdown](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/lint-markdown.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/lint-markdown.yml) | Validates Markdown formatting via `markdownlint-cli2` using PMDocu-DR rule set. |

---

## 🧩 Overview

**PMDocu-DR** is a documentation and digital record automation framework designed to enforce
traceable, auditable, and reproducible project documentation pipelines.

It supports Markdown-to-PDF conversion, GPG and Authenticode signing, evidence logging, and CI compliance validation
with automated workflows, retention policies, and air-gapped operation support.

---

### 🔍 Core Features

- Automated Markdown → PDF → GPG/Authenticode signing pipeline
- PowerShell-based compliance checks (`PSScriptAnalyzer`)
- Markdown linting via `markdownlint-cli2`
- CI workflows for build, verify, lint, and evidence collection
- 30-day artifact retention and JSON-encoded audit evidence
- Full support for manual verification via `workflow_dispatch`

---

### 📜 Evidence and Audit Policy

| **Evidence Type** | **Location** | **Retention (days)** | **Purpose** |
|--------------------|--------------|----------------------|--------------|
| Build Results | `docs/_evidence/BuildResult-*.json` | 30 | Markdown → PDF build results |
| Signature Verifications | `docs/_evidence/VerifyResult-*.json` | 30 | GPG / SHA-256 verification logs |
| Lint Reports | `docs/_evidence/AnalyzerReport-*.json` | 30 | PowerShell / Markdown lint results |
| README Builds | `docs/_evidence/ReadmeBuild-*.json` | 30 | Readme generation and commit trace |

> **Note:** All evidence artifacts follow PMDocu-DR’s compliance schema
> and can be archived or synchronized with governance systems for long-term audit retention.

---

**Version:** `v1.0`
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Next Review:** `2026-04` *(Semi-Annual Compliance Audit)*

