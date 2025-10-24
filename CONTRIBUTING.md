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

You can enable this via GitHub CLI with a helper script:

```powershell
pwsh -NoProfile -File tools/Enable-BranchProtection.ps1 `
  -Repo "EMCSLLC/PMDocu-DR" `
  -Branch "main" `
  -Checks @(
    'Lint PowerShell',
    'Pester Tests',
    'Evidence Schema Validation',
    'Preflight (WhatIf)'
  ) `
  -RequiredApprovals 1
```

Notes:
- Requires GitHub CLI installed and authenticated: `gh auth login`.
- The helper does a single automatic retry if the API call flakes.
- Update the `-Checks` list if CI job names change.

## Lint rules of note

- The repo uses a single analyzer config: `config/PSScriptAnalyzerSettings.psd1`.
- Long lines: PSAvoidLongLines is enabled with `MaximumLineLength = 300` to accommodate generated Markdown content.
- Spacing: Consistent whitespace around operators is enforced; run the formatter task if needed.

## Tips

- If the Problems panel shows stale errors, try: “PowerShell: Restart Session” in VS Code
- Prefer `shell: pwsh` in GitHub Actions (no separate setup step needed)
- Evidence and docs live under `docs/_evidence` and `docs/gov` respectively
