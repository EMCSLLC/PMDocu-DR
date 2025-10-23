---

title: "CI Compliance Matrix"
author: "EMCSLLC / PMDocu-DR Project Lead"
date: 2025-10-19
----------------

# 🧾 CI Compliance Matrix - v1.4 (2025-10-19)

**Project:** PMDocu-DR
**Purpose:** Defines continuous-integration compliance, automated validation, evidence retention, and audit traceability.
**Revision:** v1.4 – 2025-10-19
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Next Review:** 2026-04 (Semi-Annual Compliance Audit)

---

| Workflow | Status | Description |
|-----------|--------|--------------|
| 🧹 **Build and Sign Docs** | [![Build](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-docs.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-docs.yml) | Builds Markdown → PDF → GPG-signs output |
| 🔏 **Verify Signatures** | [![Verify](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/verify-signature.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/verify-signature.yml) | Verifies GPG and SHA-256 artifacts |
| 🧩 **Lint PowerShell** | [![Lint](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/powershell-lint.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/powershell-lint.yml) | Static analysis of PowerShell code using PSScriptAnalyzer (read-only) |
| 🧹 **Auto-Format PowerShell** | [![Format](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/powershell-format.yml/badge.svg)](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/powershell-format.yml) | Auto-fixes style issues and commits safe formatting updates |

---
## 🔗 Verification & Evidence Chain

The PowerShell CI workflows operate as an integrated evidence pipeline, ensuring every code and documentation artifact is continuously verified against the compliance baseline.

| Stage | Process | Output Evidence | Validation Method |
|--------|----------|------------------|--------------------|
| **1️⃣ Lint (CI-PS-01)** | Static analysis of all `.ps1` scripts using `PSScriptAnalyzer`. | `PSScriptAnalyzer.log` | Must pass without critical or high-severity findings. |
| **2️⃣ Format (CI-PS-02)** | Auto-fix and normalization of script structure, indentation, and spacing. | `PSScriptAnalyzerFix.log` | Verifies against ruleset `config/PSScriptAnalyzerSettings.psd1`. |
| **3️⃣ Schema Enforcement (CI-PS-03)** | Confirms every evidence JSON aligns with **Draft-07** schema. | `SchemaValidation_*.json` | Must achieve `status: SUCCESS` or trigger review. |
| **4️⃣ Evidence Verification (CI-PS-04)** | Validates that each schema has matching evidence JSONs. | `FileCheckSummary_*.json` / `.md` | Confirms completeness of audit evidence. |
| **5️⃣ Governance Docs Build** | Converts Markdown to PDF and digitally signs with GPG. | `BuildGovDocsResult_*.json` | Validated against `BuildGovDocsResult.schema.json`. |
| **6️⃣ Archive & Rotation** | Bundles verified evidence into archival ZIPs for long-term retention. | `EvidenceArchiveManifest.json` | Signed and hashed for immutability. |

### 🔒 End-to-End Integrity Guarantee
Each stage both **generates** and **validates** evidence artifacts:
- JSON schemas enforce consistency across reports.
- Draft-07 validation ensures CI/CLI compatibility.
- GPG signatures verify authenticity of build outputs.
- Evidence summaries (`*.json` + `.md`) document the full validation chain.

Together, these steps create a **verifiable audit trail**—from raw PowerShell source to signed compliance artifacts—supporting external review, long-term archival, and reproducibility.

---

## ⚙️ Evidence Controls Summary

| **Control ID** | **Control Name**                         | **Primary Script / Workflow**          | **Purpose**                                                                     |
| -------------- | ---------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------------- |
| **CI-EV-01**   | Automated Evidence Validation            | `scripts/Validate-EvidenceSchemas.ps1` | Validates all evidence JSON files and enforces JSON Schema Draft‑07 compliance. |
| **CI-EV-02**   | Archive Manifest Signing & Validation    | `scripts/Create-ArchiveManifest.ps1`   | Creates signed + hashed manifest and annual evidence archive.                   |
| **CI-EV-03**   | Evidence Test Summary Reporting          | `scripts/Collect-PesterSummary.ps1`    | Aggregates Pester and CI test results into validated evidence JSON.             |
| **CI-EV-04**   | Governance Document Build & Verification | `scripts/Build-GovDocs.ps1`            | Converts governance Markdown to signed PDFs and validates integrity.            |
| **CI-EV-05**   | Evidence Archive Lifecycle Review        | `scripts/Create-ArchiveManifest.ps1`   | Performs final retention, completeness, and annual archive validation.          |

---

## 🧩 Overview

All workflows produce machine-readable JSON evidence in `docs/_evidence/`.
Conditional logic prevents redundant runs while still preserving compliance traces.
Each workflow can be run manually via `workflow_dispatch` for audit reviews.

## 🧭 Workflow Summary

| **Workflow**                    | **Purpose**                                                                                   | **Frequency**                                                                                                                               | **Evidence Artifact**                            | **Retention**                                                    | **Compliance Notes**                                                                        |
| ------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 🕒 **Nightly Validation**       | Validate repository structure and evidence integrity using `Fix-RepoStructure.ps1 -AutoTree`. | Nightly at 02:00 UTC (plus manual trigger)                                                                                                  | `nightly-evidence.zip` (GitHub Actions Artifact) | 30 days (auto-expire)                                            | Ensures file layout, templates, and evidence logs remain compliant with PMDocu-DR baseline. |
| 🧹 **Build and Sign Docs**      | `.github/workflows/build-docs.yml`                                                            | Converts Markdown → PDF, signs outputs, uploads artifacts. Auto-skips if no `.md` changes detected.                                         | `push`, `pull_request`, `workflow_dispatch`      | 📄 `docs/releases/*.pdf`  📜 `docs/_evidence/BuildResult-*.json` | Build/sign errors → fail • Warnings fail if `fail_on_warning = true`                        |
| 🔏 **Verify Signatures**        | `.github/workflows/verify-signature.yml`                                                      | Validates Authenticode + GPG signatures and SHA-256 hashes for all artifacts.                                                               | `push`, `pull_request`, `workflow_dispatch`      | 📜 `docs/_evidence/VerifyResult-*.json`                          | Any invalid/missing signature → fail                                                        |
| 🧩 **Lint PowerShell**          | `.github/workflows/lint-powershell.yml`                                                       | Runs PSScriptAnalyzer using repo rules (`config/PSScriptAnalyzerSettings.psd1`). Skips if no `.ps1` changes; still logs “skipped” evidence. | `push`, `pull_request`, `workflow_dispatch`      | 📜 `docs/_evidence/AnalyzerReport-*.json`                        | Any `Error` severity issue → fail                                                           |
| 📝 **Lint Markdown**            | `.github/workflows/lint-markdown.yml`                                                         | Executes `markdownlint-cli2` with repo rules (`config/.markdownlint.json`). Skips if no `.md` changes; always emits report.                 | `push`, `pull_request`, `workflow_dispatch`      | 📜 `docs/_evidence/MarkdownReport-*.json`                        | Any lint error → fail                                                                       |
| 🪶 **Build README**             | `.github/workflows/build-readme.yml`                                                          | Rebuilds `README.md` from `README.template.md`, commits changes, records evidence.                                                          | `push`, `pull_request`, `workflow_dispatch`      | 📜 `docs/_evidence/ReadmeBuild-*.json`                           | Template/render error → fail                                                                |
| 🧪 **Evidence Integrity Tests** | `.github/workflows/tests.yml`                                                                 | Validates all JSON evidence for integrity and readability; runs weekly and on-demand.                                                       | `workflow_dispatch`, `schedule` (Mon 06:00 UTC)  | 📜 `docs/_evidence/EvidenceIntegrity-*.json`                     | Any invalid/unreadable JSON file → fail                                                     |

---

## 🧾 Evidence Retention Policy

| **Artifact Type**              | **Location**                              | **Retention (days)** | **Purpose**                                      |
| ------------------------------ | ----------------------------------------- | -------------------- | ------------------------------------------------ |
| Build Artifacts (PDFs)         | `docs/releases/*.pdf`                     | 30                   | Source-to-document traceability                  |
| Signature Verification Reports | `docs/_evidence/VerifyResult-*.json`      | 30                   | Cryptographic integrity audit                    |
| PowerShell Analyzer Reports    | `docs/_evidence/AnalyzerReport-*.json`    | 30                   | Script style and security compliance             |
| Markdown Lint Reports          | `docs/_evidence/MarkdownReport-*.json`    | 30                   | Documentation format compliance                  |
| README Build Evidence          | `docs/_evidence/ReadmeBuild-*.json`       | 30                   | Automated README trace record                    |
| Evidence Integrity Reports     | `docs/_evidence/EvidenceIntegrity-*.json` | 30                   | Confirms all JSON evidence is valid and readable |

> **Note:** Retention may be extended to 90 days for governance archive runs.

---

## 🧾 Evidence Integrity, Validation & Testing Summary Reporting

| Control ID   | Control Name                                       | Implementation                                                                                                                                                                                                                                               | Evidence Artifact                                                                                                                                              | Review Trigger                                                                                                              |
| ------------ | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **CI-EV-01** | Automated Evidence Validation                      | `scripts/Validate-EvidenceSchemas.ps1` enforces JSON Schema **Draft-07** compliance and validates all evidence JSON files before archival.                                                                                                                   | `docs/_evidence/SchemaValidation_*.json`                                                                                                                       | Any missing, invalid, or non-Draft-07 schema sets `STATUS=REVIEW_REQUIRED`                                                  |
| **CI-EV-02** | Archive Manifest Signing & Validation              | `scripts/Create-ArchiveManifest.ps1` compiles a manifest of all evidence JSONs, validates it against `schemas/EvidenceArchiveManifest.schema.json`, signs it with GPG and emits SHA-256; bundles everything into `docs/_archive/EvidenceArchive_<YEAR>.zip`. | `docs/_archive/EvidenceArchiveManifest.json` (+ `.asc`, `.sha256`), `docs/_archive/EvidenceArchive_<YEAR>.zip`                                                 | Missing or invalid signature/hash, schema validation failure, `file_index` mismatch, or timestamp drift ⇒ `REVIEW_REQUIRED` |
| **CI-EV-03** | Evidence Test Summary Reporting                    | `scripts/Collect-PesterSummary.ps1` aggregates test results from CI (unit, integration, and governance tests) into a single schema-validated JSON record (`TestSummaryResult_*.json`).                                                                       | `docs/_evidence/TestSummaryResult_*.json`                                                                                                                      | Any failed, missing, or incomplete test set; schema validation errors ⇒ `REVIEW_REQUIRED`                                   |
| **CI-EV-04** | Governance Document Build & Signature Verification | `scripts/Build-GovDocs.ps1` converts approved Markdown governance sources to PDF, producing build evidence (`BuildGovDocsResult_*.json`). Each PDF is signed and hashed via `scripts/sign-gpg.ps1` and `scripts/verify-hash.ps1`.                            | `docs/_evidence/BuildGovDocsResult_*.json`, `docs/_evidence/SignResult_*.json`, `docs/_evidence/VerifyResult_*.json`, `docs/releases/*.pdf`, `.asc`, `.sha256` | Any failed build, missing signature or hash, or schema validation error ⇒ `REVIEW_REQUIRED`                                 |
| **CI-EV-05** | Evidence Archive Lifecycle Review                  | `scripts/Create-ArchiveManifest.ps1` compiles all active evidence JSONs into a signed and hashed manifest and bundles the annual archive. Retention and completeness validated against schema.                                                               | `docs/_archive/EvidenceArchiveManifest.json`, `.asc`, `.sha256`, and `docs/_archive/EvidenceArchive_<YEAR>.zip`                                                | Missing manifest, invalid schema, absent signatures/hashes, or incomplete `file_index` ⇒ `REVIEW_REQUIRED`                  |

---

### 🧾 CI-EV-01 — Automated Evidence Validation

#### Operator Notes

* **Inputs:** All JSON evidence artifacts under `docs/_evidence/`.
* **Outputs:** Schema validation summary (`SchemaValidation_*.json`) written to `docs/_evidence/`.
* **Validation:** Enforces JSON Schema **Draft-07** compliance and validates each evidence file against its schema under `/schemas`.
* **Enforcement Rule:** Any missing, invalid, or non-Draft-07 schema sets `STATUS=REVIEW_REQUIRED`.
* **Frequency:** Runs automatically during each CI workflow (`Evidence Integrity Tests`).
* **Owner:** Compliance / CI Automation Engineer.

#### Quick Review Checklist

* ✔ All evidence JSONs validate successfully (`VALID=100%`, `STATUS=SUCCESS`).
* ✔ `SchemaValidation_*.json` present in `docs/_evidence/` with proper timestamp.
* ✔ `draft_enforcement.status` = `PASS` and `standard` = `draft-07`.
* ✔ `review_reasons` array empty in evidence output.
* ✔ No placeholder results.
* ✔ CI summary shows `STATUS=SUCCESS` and `ENFORCEMENT=PASS`.

---

### 🗄️ CI-EV-02 — Archive Manifest Signing & Validation

#### Operator Notes

* **Inputs:** All validated evidence JSON files from `docs/_evidence/`.
* **Outputs:** `EvidenceArchiveManifest.json` (schema-validated), `.asc`, `.sha256`, and annual `EvidenceArchive_<YEAR>.zip`.
* **Validation:** Validates manifest against `schemas/EvidenceArchiveManifest.schema.json` (Draft-07).
* **Security:** Must be signed using **EMCSLLC Compliance Key** with detached ASCII signature.
* **Frequency:** Weekly and pre-release; annual rotation.
* **Owner:** Release / Records Custodian.

#### Quick Review Checklist

* ✔ Manifest JSON validates successfully.
* ✔ GPG signature (`.asc`) and SHA-256 hash verify cleanly.
* ✔ `file_index` count matches number of evidence JSONs.
* ✔ UTC timestamps in ISO-8601 format.
* ✔ Signer subject and thumbprint match Compliance Key.
* ✔ Annual `.zip` archive includes manifest, signatures, hashes, and evidence.
* ✔ Validation result shows `status = SUCCESS`.
* ✔ No `review_reasons` reported.

---

### ✅ Compliance Controls Overview

| Control ID        | Workflow                                                                                                     | Status                    | Description                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------- | -------------------------------------------------------------------------------------- |
| 🧩 **CI-AUT-001** | [🔏 Build & Sign Docs](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/build-docs.yml)                | Build Docs Status         | Automates Markdown → PDF → GPG signing and verification.                               |
| 🧩 **CI-AUT-002** | [🕒 Nightly Validation](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/nightly-validate.yml)         | Nightly Validation Status | Validates structure and evidence nightly; enforces integrity of audit artifacts.       |
| 🧩 **CI-AUT-003** | [🧪 Evidence Integrity Tests](https://github.com/EMCSLLC/PMDocu-DR/actions/workflows/evidence-integrity.yml) | Evidence Integrity Status | Weekly validation ensuring all evidence JSON remains structurally valid and compliant. |

---
---

### 🕒 Update & Regeneration Notes

_This document is automatically validated and rebuilt by the **Build-GovDocs.ps1** process during each CI cycle._

- **Schema enforcement:** All evidence schemas (`schemas/*.schema.json`) must declare `"$schema": "http://json-schema.org/draft-07/schema#"`.
- **Evidence validation:** The latest run of `Validate-EvidenceSchemas.ps1` and `Verify-EvidenceFiles.ps1` is logged in `docs/_evidence/`.
- **Build traceability:** Each PDF and JSON output contains timestamped metadata and GPG signatures.

_Last updated automatically by **Build-GovDocs.ps1** on `2025-10-23 01:18:51 UTC` during CI run._

---

---

**Revision:** `v1.4 – 2025-10-19`
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Next Review:** `2026-04` (Semi-Annual Compliance Audit)

