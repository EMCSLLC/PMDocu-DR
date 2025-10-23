# 🚦 PMDocu-DR Preflight Summary

**Timestamp (UTC):** {{ timestamp_utc }}
**Execution Mode:** `WhatIf={{ whatif_mode }}`
**Preference State:** `WhatIfPreference={{ whatif_pref }}`
**Result:** `{{ result }}`

---

### 🧩 Scripts Tested
| Script | Status |
|---------|--------|
| scripts/Build-GovDocs.ps1 | ✅ Simulated |
| scripts/sign-gpg.ps1 | ✅ Simulated |
| scripts/verify-hash.ps1 | ✅ Simulated |
| scripts/Validate-EvidenceSchemas.ps1 | ✅ Simulated |

---

### ⚙️ Environment
| Key | Value |
|-----|--------|
| OS | {{ environment.os }} |
| PowerShell | {{ environment.ps_version }} |
| Hostname | {{ environment.hostname }} |

---

**Log File:** [{{ log_file }}]({{ log_file }})
**Schema Version:** `{{ schema_version }}`

---

_Generated automatically by `scripts/Run-Preflight.ps1`
and validated against `schemas/PreflightSummary.schema.json`_
