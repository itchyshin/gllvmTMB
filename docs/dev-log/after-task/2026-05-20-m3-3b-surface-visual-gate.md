# After Task: M3.3b Surface-Admission And Diagnostic-Report Gate

**Branch**: `codex/m3-3b-surface-visual-gate-2026-05-20`
**Date**: `2026-05-20`
**Roles (engaged)**: `Ada / Fisher / Curie / Florence / Pat / Grace / Rose / Shannon / Jason`

## 1. Goal

Turn the M3.3b continuation into a concrete gate before more compute:
each candidate surface must name its target, interval method, fit mode,
failure ledger, and diagnostic report before entering an r50 or r200
grid. The same closeout binds issue #217 (surface admission) and #218
(diagnostic visualization / Florence gate) so inference and plots do
not drift apart.

## 2. Implemented

- Added `docs/design/50-m3-3b-surface-admission.md`, the normative
  M3.3b surface-admission contract.
- Updated `docs/design/44-m3-3-inference-replacement.md` so the older
  "M3.3b" profile-subset label is historical, not the current meaning.
- Added an M3 diagnostic-report gate to
  `docs/design/46-visualization-grammar.md`.
- Updated `ROADMAP.md` so the next M3 step points to Design 50 and the
  Florence diagnostic-report gate.
- Updated validation-debt rows EXT-13, CI-08, and CI-10 without
  changing their statuses.
- Used two read-only parallel scouts: one for #217 surface admission
  and one for #218 diagnostic visualization. No subagent edited files.

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change.

## 3. Files Changed

- `docs/design/50-m3-3b-surface-admission.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/design/46-visualization-grammar.md`
- `docs/design/35-validation-debt-register.md`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-m3-3b-surface-visual-gate.md`

## 3a. Decisions and Rejected Alternatives

Decision: combine #217 and #218 into one spec PR.

Rationale: the surface-admission gate and diagnostic-report gate share
the same target, method, fit-mode, and failure-ledger columns. Splitting
them would make it easier for plots to display a different target than
the admission gate uses.

Rejected alternative: run the next NB2 stress grid immediately.
Confidence: high. The existing evidence says the target contract is
still the bottleneck, not compute availability.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt,url`
  -> no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago" | head -40`
  -> reviewed recent M3.3 / board commits through `8ad6e16`.
- `gh run list --repo itchyshin/gllvmTMB --limit 5 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt`
  -> latest main R-CMD-check and pkgdown were green before this branch.
- `gh issue comment 217 --repo itchyshin/gllvmTMB --body-file -`
  -> posted branch checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/217#issuecomment-4498443559`.
- `gh issue comment 218 --repo itchyshin/gllvmTMB --body-file -`
  -> posted branch checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/218#issuecomment-4498445342`.
- `git diff --check`
  -> clean.
- `rg -n 'Design 50|M3.3b|surface-admission|diagnostic report|Florence|#217|#218|EXT-13|CI-08|CI-10' ROADMAP.md docs/design/35-validation-debt-register.md docs/design/44-m3-3-inference-replacement.md docs/design/46-visualization-grammar.md docs/design/50-m3-3b-surface-admission.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-05-20-m3-3b-surface-visual-gate.md`
  -> expected hits in roadmap, validation debt, Design 44, Design 46,
  Design 50, check-log, coordination board, and this after-task report.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`

## 5. Tests of the Tests

N/A. This is a design, roadmap, and process-specification change; it
adds no R tests, likelihood code, formula grammar, family code, or
runnable examples.

## 6. Consistency Audit

- `rg -n 'Former M3.3b label|profile-likelihood subset|surface-admission' docs/design/44-m3-3-inference-replacement.md docs/design/50-m3-3b-surface-admission.md ROADMAP.md`
  -> confirmed Design 44 now marks the old profile-subset label as
  historical while Design 50 and ROADMAP own current M3.3b surface
  admission.
- `rg -n 'known-phi|n_boot = 0|point-estimate evidence|coverage evidence' docs/design/50-m3-3b-surface-admission.md docs/design/46-visualization-grammar.md ROADMAP.md docs/design/35-validation-debt-register.md`
  -> confirmed known-phi diagnostics are labelled as point-estimate
  evidence only, not coverage evidence.

## 7. Roadmap Tick

**Roadmap tick**: M3.3 stays red and M3 progress stays `3/8`.
`ROADMAP.md` now records Design 50 as the M3.3b surface-admission gate
and Design 46 as the M3 diagnostic-report / Florence gate before more
r50/r200 compute.

## 7a. GitHub Issue Ledger

- Inspected open issues #217 and #218. Issue #216 was already closed
  by PR #219.
- Commented on #217 with the Design 50 branch checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/217#issuecomment-4498443559`.
- Commented on #218 with the diagnostic-report / Florence-gate branch
  checkpoint:
  `https://github.com/itchyshin/gllvmTMB/issues/218#issuecomment-4498445342`.
- #217 and #218 remain open. This PR advances both but does not close
  either, because no surface has yet been admitted/rejected with new
  evidence and no rendered diagnostic report exists yet.

## 8. What Did Not Go Smoothly

Design 44 had an older meaning of `M3.3b` as an optional
profile-likelihood subset. The roadmap and issues had already moved
the term to "surface admission", so the same label meant two different
things until this cleanup.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: orchestration improved once issue tracker, roadmap, and after-task
report were treated as one ledger. This lane used parallel read-only
scouting but kept the write path single-owner.

Fisher: the admissible target is total `Sigma_unit[tt]`; `psi` and
known-phi point ratios remain diagnostic until target-explicit coverage
evidence clears the gate.

Curie: the next compute slice must preserve replicate/trait grain,
failed fits, CI missingness, bootstrap failures, and worker/artifact
provenance.

Florence: diagnostic figures belong before scaling, not after. A plot
can fail the gate even when the run completes if it hides weak cells or
mixes targets.

Pat: the report has to tell a reader what failed and why. A single
summary table is not enough for high-dimensional latent/covariance
diagnostics.

Grace: CI pacing stayed clean. The previous board-only main R-CMD-check
and pkgdown runs were green before this branch started.

Rose: EXT-13, CI-08, and CI-10 remain partial. The spec changes the
decision process, not the evidence status.

Shannon: no open PR overlap was present at lane start; the coordination
board was updated before edits.

Jason: drmTMB's issue-driven surface gate and rendered-report discipline
translates cleanly here, but gllvmTMB needs stricter visualization
because latent rank, covariance target, and fit failures are easier to
hide.

## 10. Known Limitations And Next Actions

- Build the dev-facing M3 diagnostic-report scaffold.
- Run the smallest NB2 point-only stress map that separates
  `fit_phi_mode`, variance scale, sample size, and rank.
- Decide whether fixed-phi bootstrap needs a mapped-parameter refit
  path before any known-phi coverage claim.
- Keep #217 and #218 open until real evidence and a rendered report
  exist.
