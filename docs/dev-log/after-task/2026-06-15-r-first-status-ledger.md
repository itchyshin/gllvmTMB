# After Task: R-First Bridge And REML Status Ledger

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Rose / Hopper / Pat`

## 1. Goal

Make the public status surfaces reflect the new R-first strategy: `gllvmTMB`
stays the user-facing source of truth, `GLLVM.jl` is the bridge target and
acceleration engine, REML remains Gaussian-only, and AI-REML is a later exact
Gaussian design reference rather than a non-Gaussian Laplace claim.

## 2. Implemented

- Added a README `Current Status` row for the partial `engine = "julia"`
  bridge.
- Added a README boundary note for bridge breadth, paired-checkout gating,
  CI/CI-status requirements, and the AI-REML wording boundary.
- Updated the ASReml/AI-REML design note so it no longer says REML is purely
  post-0.2.0. The note now states the current Gaussian-only pilot and keeps
  AI-REML as a later exact Gaussian acceleration candidate only.

## 3. Files Changed

- `README.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-r-first-status-ledger.md`

## 3a. Decisions And Rejected Alternatives

Decision: add a compact README row instead of a new public article. Rationale:
the immediate problem was claim discoverability, not a new tutorial. Rejected
alternative: promote a broad bridge article now; the bridge is still partial and
paired-checkout-gated. Confidence: high for wording; low for any release/tag
claim, which remains blocked.

## 4. Checks Run

- `rg -n "full capability|complete bridge|bridge complete|all families supported|non-Gaussian REML|AI-REML|engine = \"julia\"|R-Julia bridge|cbind\\(successes" README.md NEWS.md docs/design/43-asreml-speed-techniques.md docs/design/35-validation-debt-register.md`:
  expected hits only in explicit boundary/status rows.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`:
  `91 pass`, `14 skip`, `0 fail`, `0 warn` in `2.0s`.

## 5. Tests Of The Tests

No code path changed. The bridge test was rerun as a smoke guard because the
edited README row describes the same bridge surface.

## 6. Consistency Audit

The README, NEWS, validation-debt register, and ASReml speed note now agree on
the high-risk claims: the Julia bridge is partial; REML is Gaussian-only;
non-Gaussian REML is deferred; AI-REML is not a label for non-Gaussian Laplace
models.

## 7. Roadmap Tick

This is the first R-first ledger slice after Rose's strategy audit. It does not
change capability status; it makes current capability boundaries visible from
the README.

## 7a. GitHub Issue Ledger

No GitHub issue was mutated; pushing/commenting is maintainer-gated. This maps
to the bridge gate-drift and cross-repo claim-governance rows.

## 8. What Did Not Go Smoothly

The AI-REML note was stale in a subtle way: it was directionally cautious but
still said REML had not landed. That would invite the wrong correction later, so
the wording now distinguishes the landed Gaussian pilot from future AI-REML
experiments.

## 9. Team Learning

Ada: R-first sequencing needs public status rows, not only working code.

Rose: PASS WITH NOTES — the README is now safer, but a fuller capability matrix
still belongs in a dedicated issue/ledger before release.

Hopper: the bridge row should stay payload-centered: R payload, labels,
objective/logLik, CI or CI-status, and failure messages.

Pat: an applied user can now see from the homepage that `engine = "julia"` is
partial and gated, without reading the development NEWS first.

## 10. Known Limitations And Next Actions

Next slices: turn the bridge status into issue-led rows, continue R-side
post-fit and missingness gaps, and reconcile the dashboard `GLLVM.jl` worktree
with the paired integration checkout before broad bridge claims.
