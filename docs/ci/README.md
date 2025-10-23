# 🧾 PMDocu-DR

**Documentation & Digital Record System** — Automates Markdown-to-PDF conversion, GPG signing, SHA-256 verification, and schema-validated evidence tracking for compliance and audit workflows.

---

## 🧭 Continuous Integration Overview

PMDocu-DR includes two complementary CI workflows to ensure document integrity, signature validity, and schema compliance for all governance evidence.

| Workflow                        | Filename                                    | Purpose                                                                                                                                                                               | Typical Runtime |
| ------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| 🧪 **Evidence Integrity Tests** | `.github/workflows/evidence-integrity.yml`  | Full weekly or manual compliance run. Builds all governance Markdown → PDF, signs artifacts, verifies hashes, validates all JSON evidence, and regenerates the evidence status badge. | ~3–5 min        |
| ⚡ **Evidence Quick-Check**      | `.github/workflows/evidence-quickcheck.yml` | Lightweight developer pre-check for feature branches. Skips document rebuilds and badge generation, verifying only existing signatures and schema validity.                           | ~30–60 sec      |

---

## 🧾 Evidence Integrity Tests (Full Compliance)

**Trigger:** Manual dispatch or scheduled Mondays 06:00 UTC
**Runner:** `windows-latest`

**Workflow Summary**

1. 🧾 **Build Governance Docs** — Converts all Markdown → PDF (`Build-GovDocs.ps1`).
2. 🔍 **Verify Signatures** — Runs GPG + SHA-256 validation (`verify-hash.ps1`).
3. 🧪 **Schema Tests** — Executes strict Pester tests for all evidence types (`Test-ValidateEvidenceSchemas.ps1`).
4. 📜 **Upload Evidence Reports** — Archives `SchemaValidation_*.json` for audit trace.
5. 🏷️ **Generate Status Badge** — Updates compliance badge in README.

**Outputs**

* `docs/_evidence/BuildGovDocsResult_*.json`
* `docs/_evidence/VerifyResult_*.json`
* `docs/_evidence/SchemaValidation_*.json`
* `/docs/badges/evidence-status.svg` (for README display)

---

## ⚡ Evidence Quick-Check (Developer Validation)

**Trigger:**

* On push to `dev` or `feature/*` branches
* On pull request
* Manual dispatch

**Workflow Summary**

1. 🔍 **Verify Existing Docs** — Checks `.pdf` files in `docs/releases/` for valid `.sha256` and `.asc`.
2. 🧪 **Validate Evidence Schemas** — Runs `Test-ValidateEvidenceSchemas.ps1` (fast mode).
3. 📜 **Upload Quick Report** — Short-retention artifact `quick-evidence-validation`.

**Purpose**

* Early detection of schema drift or signature mismatches.
* Confirms JSON evidence includes environment metadata (`os`, `ps_version`, `hostname`).
* Keeps developer feedback loops under 1 minute.

---

## 📘 Evidence Chain Summary

| Evidence Type                 | Producer Script                        | Schema                                       | Description                                      |
| ----------------------------- | -------------------------------------- | -------------------------------------------- | ------------------------------------------------ |
| 🔏 **SignResult**             | `scripts/sign-gpg.ps1`                 | `schemas/SignResult.schema.json`             | GPG signature generation + SHA-256 hash creation |
| 🔍 **VerifyResult**           | `scripts/verify-hash.ps1`              | `schemas/VerifyResult.schema.json`           | Verification of signed PDFs and hash alignment   |
| 🧾 **BuildGovDocsResult**     | `scripts/Build-GovDocs.ps1`            | `schemas/BuildGovDocsResult.schema.json`     | Markdown → PDF conversion trace                  |
| 🧮 **SchemaValidationResult** | `scripts/Validate-EvidenceSchemas.ps1` | `schemas/SchemaValidationResult.schema.json` | Aggregated validation of all evidence JSONs      |

Each evidence artifact now embeds:

```json
"environment": {
  "os": "Windows Server 2022",
  "ps_version": "7.5.1",
  "hostname": "GITHUB-RUNNER-WIN"
}
```

---

## 🛡️ Compliance Assurance

All generated evidence and validation outputs are uploaded as GitHub artifacts for retention and audit review.
The **badge status** automatically updates to reflect the latest validation outcome:

| Badge       | Meaning                                        |
| ----------- | ---------------------------------------------- |
| 🟩 **PASS** | All evidence files validated successfully.     |
| 🟥 **FAIL** | One or more schema or signature checks failed. |

---

## 🏷️ Compliance Badge

Embed the compliance badge in your main `README.md` or project landing page:

```markdown
![Evidence Status](docs/badges/evidence-status.svg)
```

The badge is automatically updated by the **Evidence Integrity Tests** workflow after every full validation run.

---

## 💻 Local Developer Guide

Developers can manually run all major evidence operations using PowerShell (v5.1+ or v7+). Ensure `gpg` and `pandoc` are available in your PATH.

### 🔏 Sign a Document

```powershell
pwsh -NoProfile -File scripts/sign-gpg.ps1 -InputFile docs/releases/ChangeRequest.pdf
```

Generates:

* `ChangeRequest.pdf.asc` (signature)
* `ChangeRequest.sha256` (hash)
* `docs/_evidence/SignResult_*.json`

### 🔍 Verify a Signed Document

```powershell
pwsh -NoProfile -File scripts/verify-hash.ps1 -InputFile docs/releases/ChangeRequest.pdf
```

Confirms GPG signature + hash alignment.

### 🧾 Build Governance Docs (Markdown → PDF)

```powershell
pwsh -NoProfile -File scripts/Build-GovDocs.ps1
```

Converts all `.md` files in `docs/gov/` to PDFs under `docs/releases/` and generates `BuildGovDocsResult_*.json`.

### 🧮 Validate All Evidence Schemas

```powershell
pwsh -NoProfile -File scripts/Validate-EvidenceSchemas.ps1
```

Runs JSON schema validation against all evidence files in `docs/_evidence/`, producing `SchemaValidation_*.json`.

### 🧪 Run Full Pester Evidence Tests

```powershell
Invoke-Pester -Path tests/Test-ValidateEvidenceSchemas.ps1 -Output Detailed
```

Executes complete schema and environment verification suite locally.

---

## 🧰 Troubleshooting & Recovery

### 🧩 Missing GPG Keys

If signing fails with a *"no secret key"* error:

1. Confirm your private key is imported with `gpg --list-secret-keys`.
2. Import it manually:

   ```powershell
   gpg --import path/to/private.asc
   ```
3. Re-run the signing script with `-KeyID` if multiple keys exist.

### ⚠️ Schema Validation Errors

If evidence JSON fails schema validation:

1. Open the referenced file under `docs/_evidence/`.
2. Check for typos, missing properties, or invalid timestamp formats.
3. Run:

   ```powershell
   pwsh -NoProfile -File scripts/Validate-EvidenceSchemas.ps1
   ```
4. Review output for `INVALID` entries.

### 🧾 Corrupted or Missing Evidence Files

If a `.json`, `.asc`, or `.sha256` file is missing:

1. Re-run the corresponding generator script:

   * `sign-gpg.ps1` for missing signatures or hashes.
   * `verify-hash.ps1` for missing verification results.
   * `Build-GovDocs.ps1` for missing PDF outputs.
2. Ensure `docs/_evidence/` exists and is writable.

### 🧮 Pandoc or Font Errors

If Pandoc fails to convert Markdown → PDF:

* Verify `pandoc` and `xelatex` are installed.
* Confirm `DejaVu Sans` (Windows) or `Liberation Sans` (Linux) is available.
* Reinstall with:

  ```powershell
  choco install pandoc miktex -y
  ```

### 🧰 General Recovery Command

To rebuild everything cleanly:

```powershell
Remove-Item docs/_evidence/*.json -Force
pwsh -NoProfile -File scripts/Build-GovDocs.ps1
pwsh -NoProfile -File scripts/Validate-EvidenceSchemas.ps1
```

---

## 🔄 Governance Evidence Lifecycle (Universal Display)

```
📝 Markdown Source (.md)
   ↓
📄 Build PDFs (Build-GovDocs.ps1)
   ↓
🔏 GPG Sign & Hash (sign-gpg.ps1)
   ↓
🔍 Verify Signatures (verify-hash.ps1)
   ↓
🧮 Schema Validation (Validate-EvidenceSchemas.ps1)
   ↓
🧪 Evidence Testing (Test-ValidateEvidenceSchemas.ps1)
   ↓
🏷️ Badge Generation (Generate-EvidenceStatusBadge.ps1)
   ↓
📦 Audit & Archive (docs/_evidence/ + GitHub Artifacts)
```

<!--
Original Mermaid diagram preserved for documentation tools:
```mermaid
graph TD
A[Markdown Source Files] --> B[Build PDFs]

B --> C[GPG Sign & Hash]
C --> D[Verify Signatures]
D --> E[Validate Schemas]
E --> F[Evidence Testing]
F --> G[Generate Badge]
G --> H[Archive + Artifacts]

````
-->

**Flow Summary:**
1. Markdown files are converted into PDFs.
2. Each file is signed with GPG and hashed.
3. Signatures and hashes are verified.
4. JSON evidence is validated against schemas.
5. Pester tests confirm compliance and environment integrity.
6. A badge and evidence artifacts are generated for audit retention.

---

## 🗓️ CI Evidence Retention Policy

To maintain verifiable, traceable audit trails while optimizing storage:

| Retention Tier | Scope | Duration | Storage Path | Purpose |
|----------------|--------|-----------|---------------|----------|
| ⚡ **Quick Check** | Developer feature or pull request runs | **5 days** | GitHub artifact `quick-evidence-validation` | Fast validation during development |
| 🧪 **Integrity Tests** | Weekly compliance runs on `main` | **30 days** | GitHub artifact `evidence-validation-report` | Formal compliance record for recent runs |
| 🗄️ **Governance Archive** | Quarterly or annual export | **365 days** | `docs/_archive/*.zip` | Long-term audit trail for regulatory or retention policy requirements |

### ♻️ Export Command Example
To create an annual archive bundle for governance review:
```powershell
Compress-Archive -Path docs/_evidence/* -DestinationPath docs/_archive/EvidenceArchive_$(Get-Date -Format yyyy).zip -Force
````

Each archive should include a signed manifest (optional) and can be digitally notarized or retained offline per organizational policy.

---

**PMDocu-DR** — Enabling trusted, verifiable, and auditable digital documentation for secure compliance pipelines.
