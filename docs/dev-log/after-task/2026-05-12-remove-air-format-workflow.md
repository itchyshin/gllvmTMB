# After-Task: Remove air-format CI workflow; local discipline only (Option B)

## Goal

Stop the persistent advisory `air-format` CI failure on every PR.
Maintainer chose **Option B** (delete the workflow; keep local
`air format` discipline) over Option A (do the initial reformat
of 105 files) on 2026-05-12 ~14:00 MT.

Reason for the choice: the advisory CI failure was visual noise
on every PR -- a permanent red signal that didn't actually
indicate a problem the PR introduced -- and the alternative
(format the whole repo in one big mechanical PR) was high-effort
for low marginal value at current package size. The sister
package drmTMB also has no CI format gate; their discipline is
local-only via the after-task-audit habit. This PR aligns
gllvmTMB's setup with that pattern.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`.github/workflows/air-format.yaml`** (DELETED). The advisory
  CI check is gone. Future PRs no longer show the red `air-format`
  entry in the Checks tab.
- **`CONTRIBUTING.md`** "Code Formatting" section: removed the
  paragraph describing the advisory CI gate. Now reads as a
  pure local-discipline rule: developers run `air format .`
  before pushing; no CI enforcement. Matches the drmTMB practice
  explicitly.
- **`docs/dev-log/after-task/2026-05-12-remove-air-format-workflow.md`**
  (NEW, this file).

What stays:

- **`air.toml`** (kept) -- the Air config at the repo root. Editor
  integrations (Positron, RStudio, VS Code) pick it up so format-
  on-save still works. The file's presence also documents the
  project's preferred style (80-char line width, two-space indent).
- **CONTRIBUTING's instruction** to run `air format .` before
  pushing -- the local discipline is the gate.

What is NOT in this PR (out of scope):

- The initial reformat of 105 files (Option A) is **rejected**
  by this PR's maintainer decision. If a future PR wants to do
  it, that's a separate decision.
- Removing `air.toml` -- the config file stays useful for local
  format-on-save even without CI.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. CI workflow
deletion + one paragraph rewrite in `CONTRIBUTING.md`.

## Files Changed

- `.github/workflows/air-format.yaml` (deleted)
- `CONTRIBUTING.md`
- `docs/dev-log/after-task/2026-05-12-remove-air-format-workflow.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 3 open PRs (#39 Codex sweep, #40 Claude
  naming, #41 Claude Tier-2 audit). None of those touch
  `.github/workflows/air-format.yaml` or the `CONTRIBUTING.md`
  "Code Formatting" section. Safe.
- Sister-package reference: drmTMB has no
  `.github/workflows/air-format.yaml`; the only workflows in their
  `.github/workflows/` are `R-CMD-check.yaml` and `pkgdown.yaml`.
  This PR brings gllvmTMB to the same shape.
- The local Air install is verified working (`/opt/homebrew/bin/air`
  v0.9.0); the local discipline in `CONTRIBUTING.md` is callable.

## Tests Of The Tests

The "test" of this PR is that future PRs no longer show the
`air-format` row in their Checks tab and the visual red signal
on every PR goes away. Specifically:

- PR #39 (Codex sweep) was opened while the workflow was active;
  its Checks tab includes a failing `air-format` job. That entry
  stays on the historical run (GitHub doesn't retroactively
  remove finished workflow runs).
- The **next** PR opened after this one merges should show only
  `R-CMD-check / ubuntu-latest (release)`,
  `R-CMD-check / macos-latest (release)`,
  `R-CMD-check / windows-latest (release)` (and a `pkgdown`
  workflow_run on main pushes), no `air-format`.

If a future PR still shows an `air-format` entry after this PR
merges, the workflow file was not actually deleted; check
`git ls-files .github/workflows/` on main post-merge.

## Consistency Audit

```sh
ls .github/workflows/
```

post-edit verdict: `R-CMD-check.yaml` and `pkgdown.yaml`.
`air-format.yaml` is gone.

```sh
rg -n "air-format|air format --check|continue-on-error: true" .github/ CONTRIBUTING.md docs/design
```

post-edit verdict: no remaining references to the CI gate. The
only mentions of `air format` are the local-discipline instruction
in `CONTRIBUTING.md`.

```sh
rg -n "Air format|air format" NEWS.md README.md
```

post-edit verdict: no mentions (pre-edit: also no mentions; the
NEWS entry for PR #29 did not name the workflow specifically, so
no NEWS edit is needed).

## What Did Not Go Smoothly

Nothing. Tiny PR. The harder part was the maintainer's prior
decision (Option B over Option A); the implementation is just
file deletion + one paragraph rewrite.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** correctly rejected Option A (the
  105-file initial reformat) when its cost-benefit was poor.
  PR #29's original setup of advisory CI was a reasonable
  compromise at the time; reverting it now that we have data
  ("every PR shows red, nobody acts on it") is correct.
- **Grace (CI / pkgdown / CRAN)** notes that the active workflow
  count drops from three to two (`R-CMD-check`, `pkgdown`),
  matching the drmTMB / sdmTMB setup. CI cost drops slightly.
- **Pat (applied user / new contributor)** is the beneficiary:
  a new contributor opening a PR no longer sees a red `air-format`
  signal that's unrelated to anything they did.
- **Rose (cross-file consistency)** confirms no other doc claims
  CI enforces formatting (no NEWS entry, no README mention).

## Known Limitations

- Removing the workflow removes the *signal* that pre-existing
  source isn't formatted. The local `air format .` discipline
  catches new drift on the per-developer side; if a developer
  forgets, format drift accumulates silently.
- The advisory CI did serve as a permanent reminder that the
  initial reformat was deferred. Without it, the deferral is now
  recorded only in this after-task report.
- Future re-introduction of a CI gate (if drift accumulates) is
  cheap: re-add `.github/workflows/air-format.yaml`. The
  decision to remove now is not irreversible.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: CI workflow
   removal + CONTRIBUTING paragraph rewrite + after-task; no
   source code change.
2. After merge, the next PR opened should have a cleaner Checks
   tab (only `R-CMD-check` + pkgdown).
3. The PR #36 after-task report (where the Rendered-Rd spot-check
   was codified) still names "advisory air-format" as a CI gate;
   that historical record stays as-is. Going forward, the
   protocol doc and CONTRIBUTING are the authoritative source.
