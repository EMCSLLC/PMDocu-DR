# 🧩 Governance Bootstrap Checklist

**Project:** PMDocu-DR
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Revision:** v1.1 – 2025-10-17
**Next Review:** 2026-04 (Semi-Annual Compliance Audit)

---

## 🧭 Purpose

This checklist defines the initial repository bootstrap process for governance and compliance readiness.
It ensures that all essential configuration files, analyzers, workflows, and signing mechanisms are established before the first official release.

All tasks must be verified and signed off before tagging the baseline version (e.g., `v1.0-Gov-Baseline`).

---

## ✅ 1. Repository Initialization

| **Requirement** | **Verification Step** | **Status / Reviewer Initials / Date** |
|------------------|-----------------------|--------------------------------------|
| Repo created with correct name and license (`LICENSE.md`) | Confirm repository visibility and LICENSE file are correct | |
| `.gitignore` and `.gitattributes` present | Ensure standard patterns and UTF-8 normalization rules are included | |
| Default branch protection rules configured | Verify branch protection for `main` branch is enabled (review + CI required) | |
| `VERSION` file created | Confirm version matches project tag | |

---

## 🧩 2. Configuration Baselines

| **Component** | **File / Path** | **Verification Step** | **Status / Reviewer / Date** |
|----------------|------------------|------------------------|-------------------------------|
| PowerShell Analyzer Config | `config/PSScriptAnalyzerSettings.psd1` | Validate syntax, severity levels, and custom noun rules | |
| Markdown Linter Config | `config/.markdownlint.json` | Verify JSON validity and allowed HTML elements | |
| Formatter Defaults | `defaults/formatter.conf.yml` | Confirm indentation, spacing, and whitespace policies | |
| Build Defaults | `defaults/build.conf.yml` | Confirm standard Pandoc build options and footer/header paths | |

---

## 🔏 3. Signing & Certificate Setup

| **Task** | **Verification Step** | **Status / Reviewer / Date** |
|-----------|----------------------|-------------------------------|
| Local development certificate created (`CN=PMDocu Local Dev`) | Confirm certificate exists in `Cert:\CurrentUser\My` and Root/TrustedPublisher stores | |
| Timestamp server reachable (if online) | Verify fallback to local timestamp if offline | |
| Signing script operational | Run `tools/Sign-Repo.ps1 -ListOnly` and verify no missing signatures | |
| Certificate reuse policy documented | Confirm self-signed cert reuse across sessions for reproducibility | |

---

## 🧰 4. Workflow Verification

| **Workflow** | **File** | **Check** | **Status / Reviewer / Date** |
|---------------|-----------|-----------|-------------------------------|
| 🧹 Build & Sign Docs | `.github/workflows/build-docs.yml` | Executes successfully; PDFs appear in `docs/releases` | |
| 🔏 Verify Signatures | `.github/workflows/verify-signature.yml` | Produces valid signature evidence under `docs/_evidence` | |
| 🧩 Lint PowerShell | `.github/workflows/lint-powershell.yml` | Analyzer output created, no errors | |
| 📝 Lint Markdown | `.github/workflows/lint-markdown.yml` | Markdown report created, no linting violations | |

---

## 🗂️ 5. Evidence Directories

| **Directory** | **Purpose** | **Verification Step** | **Status / Reviewer / Date** |
|----------------|-------------|------------------------|-------------------------------|
| `docs/_evidence/` | Stores JSON evidence for all workflows | Confirm directory structure exists and is Git-tracked via `.gitkeep` | |
| `docs/releases/` | Contains signed PDF outputs | Verify directory structure and release build accessibility | |
| `docs/gov/` | Houses governance documentation | Confirm index, matrix, and checklist files exist and lint cleanly | |

---

## 🏁 6. Baseline Tag and Review

| **Action** | **Verification Step** | **Status / Reviewer / Date** |
|-------------|----------------------|-------------------------------|
| All CI workflows pass in strict mode | Execute each manually with `workflow_dispatch` mode=`strict` | |
| Evidence checklist completed | Verify `docs/gov/CI-Evidence-Checklist.md` filled and signed | |
| Compliance Matrix validated | Confirm `docs/gov/CI-Compliance-Matrix.md` updated and current | |
| Governance README verified | Confirm interlinks resolve correctly and all docs build cleanly | |
| Create signed tag `v1.1-Gov-Baseline` | Push tag and verify artifact retention policies applied | |

---

### 🕒 Nightly Validation and Evidence Assurance

**Control Reference:** CI-AUT-002
**Control Title:** Automated Structural Validation and Evidence Retention

**Description:**
The PMDocu-DR repository executes a nightly GitHub Actions workflow named **🕒 Nightly Validation** that validates repository folder structure and evidence integrity using PowerShell scripts `Fix-RepoStructure.ps1` and `Update-RepoTree.ps1`.

The workflow performs the following automated controls:
1. Confirms core compliance directories exist (`docs/_templates`, `docs/_evidence`, `docs/releases`, `scripts`).
2. Generates a timestamped `RepoTree.txt` and logs structure results to `docs/_evidence/`.
3. Verifies that required evidence files (`RepoTree*.txt` and `RepoStructureFix*.log`) are present before artifact packaging.
4. Uploads a compressed evidence archive (`nightly-evidence-<timestamp>.zip`) to GitHub Actions as a 30-day retention artifact.

**Validation Output:**
- Workflow: `.github/workflows/nightly-validate.yml`
- Evidence Artifact: `nightly-validation-logs`
- Retention: 30 days
- Manual Trigger: Supported via `workflow_dispatch`

**Compliance Outcome:**
Provides continuous verification of documentation integrity, ensuring traceable audit artifacts are generated nightly without modifying the repository contents.

---

#### 🧾 Baseline Snapshot Recordkeeping (Sub-Control CI-AUT-002-A)

**Purpose:**
To maintain a timestamped, immutable record of PMDocu-DR’s CI compliance status.
Each successful nightly validation generates a Markdown snapshot (`Baseline-YYYYMMDD.md`)
capturing control results, commit hash, and evidence references from the `_evidence` directory.

**Implementation:**
- Script: `scripts/Write-BaselineSnapshot.ps1`
- Workflow: `.github/workflows/nightly-validate.yml`
- Output Path: `docs/releases/`
- Snapshot Contents:
  - Date, branch, and commit hash
  - Validation summary for `CI-AUT-001` (Build & Sign Docs) and `CI-AUT-002` (Nightly Validation)
  - Latest evidence file references (`RepoTree*.txt`, `RepoStructureFix*.log`, `SignResult*.json`)
  - Compliance outcome statement

**Verification:**
Each baseline file is created automatically by the final step of the nightly workflow
when validation passes. The resulting Markdown file serves as an immutable
point-in-time proof of continuous compliance and CI integrity.

**Audit Outcome:**
Confirms automated recordkeeping of CI state for each validation cycle,
supporting audit traceability and providing long-term assurance that
repository structure, documentation, and signing workflows remain functional and compliant.


## 🧾 Notes

- Once baseline is approved, export all `/docs/gov/` and `/docs/_evidence/` contents to offline archive media.
- Each future release should re-run this checklist when adding or modifying workflows, certificate handling, or analyzer configurations.

---

**Reviewer:** _________________________
**Date:** _________________________
**Approval Signature:** _________________________
