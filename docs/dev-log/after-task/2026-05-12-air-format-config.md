# After-Task: Add `air.toml` + CONTRIBUTING note + advisory CI workflow (Option D)

## Goal

Add Air R-formatter configuration to gllvmTMB, matching the
discipline drmTMB already exercises in practice (running
`air format` as part of pre-commit checks). Maintainer initially
said C (local-only), then corrected to **Option D** (both A + C):
local discipline **plus** a CI check workflow. The CI job runs in
**advisory mode** (`continue-on-error: true`) during the trial
period because the existing codebase has not yet been run through
`air format`; flipping to blocking is a separate PR after the
initial reformat.

The trial-period rationale (still applies under Option D): the CI
job becomes a visibility signal first, an enforcement gate second.
Once the existing source is reformatted in a dedicated PR, the
`continue-on-error: true` line in the workflow is removed and the
gate becomes blocking.

After-task report added at branch start per the `CONTRIBUTING.md`
rule.

## Implemented

- **`air.toml`** (NEW) -- minimal Air configuration at repo root:
  80-char line width, two-space indent, space indent style.
  Default-ish settings; the file's presence is the signal to
  editor integrations (Positron, RStudio, VS Code) to format
  R / Rmd files on save.
- **`CONTRIBUTING.md`** "Code Formatting" (NEW section) --
  instruction to run `air format .` before pushing, with the
  macOS / Linux installer command, a pointer to the project's
  install page for Windows, and a paragraph explaining the
  advisory-CI status during the trial.
- **`.github/workflows/air-format.yaml`** (NEW) -- CI workflow
  that runs `air format --check .` on every PR and every push to
  `main`. During the trial period the job is
  `continue-on-error: true`, so the check is visible without
  blocking merges. Workflow is also `workflow_dispatch`-able for
  manual runs.
- **`docs/dev-log/after-task/2026-05-12-air-format-config.md`**
  (NEW, this file).

The PR does **not** run `air format .` on the existing codebase.
That would be a separate, larger PR; mixing the config addition
with a wholesale reformat would make the diff impossible to
review. Per the trial design, we add the config + advisory CI
first, then a dedicated reformat PR flips the workflow to
blocking. The advisory CI run on this very PR will likely report
existing-source formatting drift -- that is expected and not a
defect.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette content, or pkgdown navigation change.
Tooling config + one CONTRIBUTING section.

## Files Changed

- `air.toml` (new)
- `CONTRIBUTING.md` (modified)
- `.github/workflows/air-format.yaml` (new)
- `docs/dev-log/after-task/2026-05-12-air-format-config.md` (new)

## Checks Run

- Pre-edit lane check: 0 open PRs at branch start; no Codex push
  on `CONTRIBUTING.md` or root-level config; safe to edit.
- Sister-package comparison: drmTMB also has no `air.toml` and no
  CI format workflow; their `air format` discipline is enforced by
  the after-task-audit habit (`air format ...: passed.` lines in
  their reports). gllvmTMB now has slightly more scaffolding than
  drmTMB (the `air.toml` file makes the rules explicit), but the
  enforcement model is the same (local only).
- The `[format]` keys used (`line-width`, `indent-style`,
  `indent-width`) are documented in Air's reference; defaults
  would be acceptable, but writing them explicitly makes the
  intent visible and the editor integration deterministic.

## Tests Of The Tests

N/A for a tooling-config PR. The implicit "test" is the next
non-trivial source-touching PR -- if Codex's Phase 1a row 2
(`covariance-correlation.Rmd`) or Phase 3 implementation lands and
the rendered diff is consistent with the `air.toml` rules, the
config is doing its job silently. If diffs show inconsistent
indentation or line wraps, the discipline is not catching enough
and we escalate to a CI check.

## Consistency Audit

```sh
rg -n "air.toml|air format" CONTRIBUTING.md README.md docs/design AGENTS.md CLAUDE.md
```

verdict: the new CONTRIBUTING.md "Code Formatting" section is the
only Air reference in user-facing prose; no contradictory wording
elsewhere.

```sh
rg -n "## Code Formatting|## Development Checks" CONTRIBUTING.md
```

verdict: both headings exist exactly once, in the order
"Code Formatting" → "Development Checks". The reader path goes
from formatting (cheap, local) → check / test / document
(slower, more thorough).

## What Did Not Go Smoothly

Nothing significant. The earlier ambiguity ("running a day before
you start on C") resolved into the trial-period design recorded
above. No bumps in the implementation.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** specified the trial-period framing:
  install C, observe for a day, decide whether to escalate.
- **Grace (CI / pkgdown / CRAN)** does not engage on this PR
  because Option C is explicitly NOT a CI change. If we escalate
  to Option A later, Grace owns that follow-up workflow.
- **Pat (applied user / new contributor)** is the implicit
  beneficiary: the CONTRIBUTING note explains both the install
  command and the discipline, so a new contributor can adopt the
  habit without spelunking through drmTMB.
- **Jason (landscape / source-map)** checked the sister-package
  practice; the gap (gllvmTMB had no Air config) is what this PR
  closes.

## Known Limitations

- The PR does not reformat the existing codebase. Air may report
  drift on currently-checked-in files; that is intentional and
  out of scope. A separate "initial Air pass" PR can run
  `air format .` over `R/`, `tests/`, `vignettes/`, `NEWS.md`
  once we've decided the rules are stable.
- The `air.toml` settings (80-char width, two-space indent) match
  R community conventions but are not yet aligned with drmTMB's
  actual practice (drmTMB has no `air.toml`, so they use Air's
  built-in defaults). If we want a one-rule-set-across-packages
  shape, we can normalise later.
- Windows install path is a pointer to Air's project page rather
  than a one-liner because the Windows installer is not a single
  curl-and-execute step. Acceptable trade-off for the trial.

## Next Actions

1. Maintainer reviews / merges (self-merge eligible: tooling
   config + CONTRIBUTING + advisory CI workflow, no source
   behavior change).
2. Open a separate "initial Air reformat" PR running `air format .`
   over `R/`, `tests/`, `vignettes/`, `NEWS.md`. That PR's CI
   advisory check should turn green for the first time, which is
   the signal to flip `continue-on-error: false` in the same PR
   (making the gate blocking).
3. After step 2 lands, the workflow is a real gate. Codex's
   Phase 1a row 2 and Phase 3 implementation PRs will be the
   first PRs to be formatted-from-the-start.
4. Optional later: tighten `air.toml` rules if a project-wide
   convention shifts (line width, indent, etc.). Today's config
   is conservative R-community defaults.
