# 🧾 CI Compliance Matrix — v1.3 (2025-10-18)

**Project:** PMDocu-DR
**Purpose:** Defines continuous-integration compliance, automated validation, evidence retention, and audit traceability.

---

## 🧩 Overview
All workflows produce machine-readable JSON evidence in `docs/_evidence/`.
Conditional logic prevents redundant runs while still preserving compliance traces.
Each workflow can be run manually via `workflow_dispatch` for audit reviews.

---

## 🧭 Workflow Summary

| **Workflow** | **Purpose** | **Frequency** | **Evidence Artifact** | **Retention** | **Compliance Notes** |
|---------------|-------------|----------------|------------------------|----------------|----------------------|
| 🕒 **Nightly Validation** | Validate repository structure and evidence integrity using `Fix-RepoStructure.ps1 -AutoTree`. | Nightly at 02:00 UTC (plus manual trigger) | `nightly-evidence.zip` (GitHub Actions Artifact) | 30 days (auto-expire) | Ensures file layout, templates, and evidence logs remain compliant with PMDocu-DR baseline. |
| 🧹 **Build and Sign Docs** | `.github/workflows/build-docs.yml` | Converts Markdown → PDF, signs outputs, uploads artifacts. Auto-skips if no `.md` changes detected. | `push`, `pull_request`, `workflow_dispatch` | 📄 `docs/releases/*.pdf`  📜 `docs/_evidence/BuildResult-*.json` | Build/sign errors → fail • Warnings fail if `fail_on_warning = true` |
| 🔏 **Verify Signatures** | `.github/workflows/verify-signature.yml` | Validates Authenticode + GPG signatures and SHA-256 hashes for all artifacts. | `push`, `pull_request`, `workflow_dispatch` | 📜 `docs/_evidence/VerifyResult-*.json` | Any invalid/missing signature → fail |
| 🧩 **Lint PowerShell** | `.github/workflows/lint-powershell.yml` | Runs PSScriptAnalyzer using repo rules (`config/PSScriptAnalyzerSettings.psd1`). Skips if no `.ps1` changes; still logs “skipped” evidence. | `push`, `pull_request`, `workflow_dispatch` | 📜 `docs/_evidence/AnalyzerReport-*.json` | Any `Error` severity issue → fail |
| 📝 **Lint Markdown** | `.github/workflows/lint-markdown.yml` | Executes `markdownlint-cli2` with repo rules (`config/.markdownlint.json`). Skips if no `.md` changes; always emits report. | `push`, `pull_request`, `workflow_dispatch` | 📜 `docs/_evidence/MarkdownReport-*.json` | Any lint error → fail |
| 🪶 **Build README** | `.github/workflows/build-readme.yml` | Rebuilds `README.md` from `README.template.md`, commits changes, records evidence. | `push`, `pull_request`, `workflow_dispatch` | 📜 `docs/_evidence/ReadmeBuild-*.json` | Template/render error → fail |
| 🧪 **Evidence Integrity Tests** | `.github/workflows/tests.yml` | Validates all JSON evidence for integrity and readability; runs weekly and on-demand. | `workflow_dispatch`, `schedule` (Mon 06:00 UTC) | 📜 `docs/_evidence/EvidenceIntegrity-*.json` | Any invalid/unreadable JSON file → fail |

---

## 🧾 Evidence Retention Policy

| **Artifact Type** | **Location** | **Retention (days)** | **Purpose** |
|--------------------|--------------|----------------------|--------------|
| Build Artifacts (PDFs) | `docs/releases/*.pdf` | 30 | Source-to-document traceability |
| Signature Verification Reports | `docs/_evidence/VerifyResult-*.json` | 30 | Cryptographic integrity audit |
| PowerShell Analyzer Reports | `docs/_evidence/AnalyzerReport-*.json` | 30 | Script style and security compliance |
| Markdown Lint Reports | `docs/_evidence/MarkdownReport-*.json` | 30 | Documentation format compliance |
| README Build Evidence | `docs/_evidence/ReadmeBuild-*.json` | 30 | Automated README trace record |
| Evidence Integrity Reports | `docs/_evidence/EvidenceIntegrity-*.json` | 30 | Confirms all JSON evidence is valid and readable |

> **Note:** Retention may be extended to 90 days for governance archive runs.

---

## 🏁 Compliance Notes
- All workflows are **reproducible** and **auditable** via manual dispatch.
- Each stage writes JSON evidence before exit (success or fail).
- Conditional execution prevents unnecessary jobs but never omits evidence.
- The system remains fully functional in air-gapped mode using local certs.
- Evidence JSON is structured for machine parsing in future Gov-Compliance tooling.

---

### 🔄 Continuous Evidence Validation (Control ID: CI-AUT-002)

Beginning October 2025, PMDocu-DR incorporates an automated nightly workflow (**🕒 Nightly Validation**) to verify repository structure and evidence integrity.
This control ensures that required compliance directories remain intact, evidence logs are generated and verified (`RepoTree*.txt`, `RepoStructureFix*.log`), and
compressed artifacts are uploaded automatically to GitHub Actions for 30-day retention.

This mechanism operates independently of build, lint, and signing pipelines, providing continuous assurance that documentation artifacts remain complete,
traceable, and compliant with PMDocu-DR’s baseline configuration standards.


---

**Revision:** `v1.3 – 2025-10-18`
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Next Review:** `2026-04` (Semi-Annual Compliance Audit)
