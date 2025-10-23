---

title: "CI Archive Rotation Operator Guide"
author: "EMCSLLC / PMDocu-DR Project Lead"
date: 2025-10-21
----------------

# 🗄️ CI Archive Rotation (CI-EV-05)

**Workflow:** `.github/workflows/archive-rotation.yml`
**Frequency:** Annually (January 2, 03:00 UTC) or manual trigger
**Owner:** Compliance & Records Custodian
**Purpose:** Automates evidence cleanup, schema validation, manifest signing, and archive creation.

---

## 🧩 Overview

This workflow maintains long-term compliance integrity by:

* Backing up all current evidence (`docs/_evidence/`)
* Validating every JSON evidence file against its schema (enforcing **Draft-07**)
* Signing and hashing the `EvidenceArchiveManifest.json` using the EMCSLLC Compliance GPG key
* Bundling a complete annual archive (`EvidenceArchive_<YEAR>.zip`)
* Uploading artifacts to GitHub with 90-day retention

The rotation process ensures that all compliance artifacts remain **verifiable, signed, and traceable** year over year.

---

## ⚙️ Workflow Steps

| **Step**                        | **Script / Action**                      | **Description**                                                                                                                   |
| ------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 🧹 **Cleanup Evidence**         | `scripts/Cleanup-Evidence.ps1`           | Backs up and removes transient evidence JSONs. Revalidates schemas after cleanup.                                                 |
| 🧮 **Validate Schemas**         | `scripts/Validate-EvidenceSchemas.ps1`   | Checks all schemas for JSON Schema Draft-07 compliance and validates all evidence JSONs.                                          |
| 🗄️ **Create Archive Manifest** | `scripts/Create-ArchiveManifest.ps1`     | Compiles a full index of evidence JSONs, signs the manifest (GPG), hashes it (SHA-256), and creates `EvidenceArchive_<YEAR>.zip`. |
| 🔏 **Sign Manifest**            | Inline GPG (CI Secret `GPG_PRIVATE_KEY`) | Detached ASCII signature using EMCSLLC Compliance Key (`0B57BB923F762D1E`).                                                       |
| 📦 **Upload Artifacts**         | `actions/upload-artifact@v4`             | Stores the signed manifest and `.zip` archive with 90-day retention.                                                              |
| 🪶 **Update Evidence Badge**    | Optional commit step                     | Updates `docs/_evidence/evidence-status.svg` in main branch.                                                                      |

---

## 🧾 Operator Notes

* **Trigger:** Normally runs automatically on schedule (`Jan 2`), but can also be run manually from GitHub Actions.

* **Key Material:**
  Ensure that the repository secret `GPG_PRIVATE_KEY` is configured with the private key for signing.
  Example:

  ```
  GPG_PRIVATE_KEY: (base64 or ASCII-armored key block)
  ```

* **Schema Compliance:**
  All schemas in `/schemas/` must reference

  ```
  "$schema": "http://json-schema.org/draft-07/schema#"
  ```

  or the run will report `ENFORCEMENT=FAIL`.

* **Retention Policy:**
  Archive artifacts remain available for **90 days**, while local backups under `docs/_archive/backup_evidence_*.zip` are retained indefinitely (governed by repository storage policy).

---

## 🔍 Post-Run Verification Checklist

| ✅ Item                                                                           | Description |
| -------------------------------------------------------------------------------- | ----------- |
| ✔ Evidence backup created under `docs/_archive/backup_evidence_<timestamp>.zip`. |             |
| ✔ Manifest file `EvidenceArchiveManifest.json` present in `docs/_archive/`.      |             |
| ✔ Matching `.asc` (signature) and `.sha256` hash files exist.                    |             |
| ✔ Archive bundle `EvidenceArchive_<YEAR>.zip` created successfully.              |             |
| ✔ Manifest passes schema validation (`Validate-EvidenceSchemas.ps1`).            |             |
| ✔ GitHub workflow logs show `STATUS=SUCCESS`.                                    |             |
| ✔ (Optional) Updated evidence badge committed to `main`.                         |             |

---

## 🧮 Example Outputs

| File                                            | Description                       |
| ----------------------------------------------- | --------------------------------- |
| `docs/_archive/EvidenceArchiveManifest.json`    | Annual manifest (Draft-07 schema) |
| `docs/_archive/EvidenceArchiveManifest.asc`     | Detached ASCII signature          |
| `docs/_archive/EvidenceArchiveManifest.sha256`  | Manifest hash file                |
| `docs/_archive/EvidenceArchive_2025.zip`        | Bundled annual evidence archive   |
| `docs/_evidence/SchemaValidation_*.json`        | Validation result evidence        |
| `docs/_archive/backup_evidence_<timestamp>.zip` | Backup before cleanup             |

---

## 🔒 Compliance Reference

**Control ID:** `CI-EV-05`
**Title:** *Evidence Archive Lifecycle Review*
**Objective:** Ensure signed, validated, and fully indexed archive of all evidence artifacts for each compliance year.
**Review Trigger:** Missing or invalid manifest, missing signatures, or schema enforcement failure ⇒ `REVIEW_REQUIRED`.

---

## 🧾 CI-EV-05 Audit Evidence Summary

| Year | Evidence Archive         | Manifest Signature | Validation Status | Reviewer     | Verified Date  |
| ---- | ------------------------ | ------------------ | ----------------- | ------------ | -------------- |
| 2025 | EvidenceArchive_2025.zip | ✅ Valid            | ✅ PASS            | *(Initials)* | *(MM/DD/YYYY)* |
| 2026 | EvidenceArchive_2026.zip | ⬜ Pending          | ⬜ Pending         |              |                |
| 2027 | EvidenceArchive_2027.zip | ⬜ Pending          | ⬜ Pending         |              |                |

---

**Revision:** `v1.0 — 2025-10-21`
**Maintainer:** EMCSLLC / PMDocu-DR Project Lead
**Next Review:** `2026-01-15` (Post-rotation verification)
