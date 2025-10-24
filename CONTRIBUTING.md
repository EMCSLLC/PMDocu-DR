# Contributing to PMDocu-DR

Thanks for contributing! This guide explains the local workflow, Git hooks, and CI checks so you can get fast feedback and clean PRs.

## Local workflow

- Create a feature branch: `feature/short-desc` (or `fix/short-desc` for hotfixes)
- Make small commits; the repo runs helpful hooks:
  - `pre-commit` (PowerShell):
    - Normalizes spacing in staged `.ps1` files
    - Runs PSScriptAnalyzer with fixes using `config/PSScriptAnalyzerSettings.psd1`
    - Blocks commit if any Error-level issues remain
  - `pre-push` (PowerShell, warn-only):
    - Runs `scripts/Run-Preflight.ps1 -WhatIf`
    - Prints a warning on failure but does not block the push

To install hooks locally, run once:

```powershell
pwsh -NoProfile -File tools/Enable-GitHooks.ps1
```

To bypass hooks in emergencies, you can use `--no-verify` on commit/push.

## Linting and formatting

- Editor: VS Code uses the single ruleset at `config/PSScriptAnalyzerSettings.psd1`
- Tasks: `Lint All PowerShell` and `Format All PowerShell` use the same ruleset
- Keep format placeholders tight (e.g., `{0}`), and avoid curly quotes in code

## Tests and preflight

- Pester tests live under `tests/`
- Preflight (safe dry run):

```powershell
pwsh -NoProfile -File scripts/Run-Preflight.ps1 -WhatIf
```

## CI checks (PRs)

- Lint PowerShell (Error-level findings fail the job)
- Pester Tests (publishes JUnit results)
- Evidence Schema Validation (WhatIf)
- Preflight (WhatIf, publishes evidence)

Artifacts are uploaded to help reviewers (e.g., analyzer reports, evidence JSON/MD).

## Branch protections (recommended)

Protect `main` and require these checks before merge:
- Lint PowerShell
- Pester Tests
- Evidence Schema Validation
- Preflight (WhatIf)

## Tips

- If the Problems panel shows stale errors, try: “PowerShell: Restart Session” in VS Code
- Prefer `shell: pwsh` in GitHub Actions (no separate setup step needed)
- Evidence and docs live under `docs/_evidence` and `docs/gov` respectively
