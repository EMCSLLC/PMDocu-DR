# {{REPO_NAME}}

Documentation and Digital Record System

---

## 🧭 CI Status

| Workflow | Status | Description |
|-----------|--------|--------------|
| 🪶 **Build README** | [![Build README](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/build-readme.yml/badge.svg)](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/build-readme.yml) | Auto-generates `README.md` from this template, injects repo metadata, commits automatically, and logs evidence. |
| 🧹 **Build & Sign Docs** | [![Build & Sign Docs](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/build-docs.yml/badge.svg)](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/build-docs.yml) | Converts Markdown → PDF → Signs with GPG → Verifies SHA-256 → Uploads signed artifacts. |
| 🔏 **Verify Signatures** | [![Verify Signatures](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/verify-signature.yml/badge.svg)](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/verify-signature.yml) | Re-verifies Authenticode, GPG signatures, and SHA-256 hashes for all release artifacts. |
| 🧩 **Lint PowerShell** | [![Lint PowerShell](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/lint-powershell.yml/badge.svg)](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/lint-powershell.yml) | Runs `PSScriptAnalyzer` across all scripts and modules for style, security, and compatibility issues. |
| 📝 **Lint Markdown** | [![Lint Markdown](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/lint-markdown.yml/badge.svg)](https://github.com/{{REPO_OWNER}}/{{REPO_NAME}}/actions/workflows/lint-markdown.yml) | Validates Markdown formatting and heading consistency using `markdownlint-cli2` and PMDocu-DR ruleset. |

---

## 🧩 Overview

**{{REPO_NAME}}** is a documentation and digital-record automation framework that enforces
traceable, auditable, and reproducible project documentation pipelines.

It supports Markdown-to-PDF conversion, GPG and Authenticode signing, evidence logging, and CI compliance validation
with automated workflows, retention policies, and air-gapped operation support.

---

### 🔍 Core Features

- Automated **Markdown → PDF → GPG/Authenticode signing** pipeline
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
| README Builds | `docs/_evidence/ReadmeBuild-*.json` | 30 | README generation and commit trace |

> **Note:** All evidence artifacts follow the PMDocu-DR compliance schema
> and can be archived or synchronized with governance systems for long-term audit retention.

---

**Version:** `v{{VERSION}}`
**Maintainer:** {{REPO_OWNER}} / PMDocu-DR Project Lead
**Generated:** `{{BUILD_DATE}}`
**Next Review:** `{{NEXT_REVIEW}}` *(Semi-Annual Compliance Audit)*
