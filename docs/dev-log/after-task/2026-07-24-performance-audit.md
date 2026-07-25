# After Task: BIRDBASE-Relevant Performance-Audit Baseline

**Branch:** `codex/performance-audit-20260724`
**Date:** 2026-07-24
**Status:** completed baseline; no package change proposed

## 1. Goal

Determine whether Ayumi's approximately eight-hour BIRDBASE campaign should
be treated as evidence of an obvious gllvmTMB C++ defect, while retaining the
scientific multi-start safeguards. This phase was to establish a reproducible
benchmark receipt and a narrow review target, not to change a likelihood.

## 2. Implemented

- Added a non-shipped, receipt-writing benchmark harness for the mixed-family,
  ordinary-plus-phylogenetic latent route.
- Corrected its grouping after the initial smoke: both tiers are now on
  `species`, matching the relevant BIRDBASE structure.
- Ran a single-core Totoro species-by-trait scale ladder through 200 x 27
  (5,400 rows), with one start, five BFGS starts, and an exact-model warm
  start.
- Conducted an independent source review of likely TMB/C++ hot paths.

## 3. Mathematical / API Contract

No formula grammar, likelihood, parameterisation, exported API, or user-facing
documentation changed. The benchmark preserves the ordinary and phylogenetic
latent tiers but is rank-1 synthetic engineering evidence, not a recovery
study or a claim about Ayumi's fitted biological parameters.

## 3a. Decisions and Rejected Alternatives

- **Decision**: treat the completed receipt as a workflow-performance
  baseline, not evidence of a native-code defect. **Rationale**: five BFGS
  trajectories dominate total time at 200 x 27, while fixed-vector TMB
  micro-times are small; the independent source review found no dense phylo
  inverse. **Rejected alternative**: a speculative C++ rewrite, because no
  measured native hot path yet has an objective/gradient/report parity target.
  **Confidence**: medium.
- **Decision**: retain five starts and the convergence safeguards. **Rationale**:
  their role is basin selection and numerical diagnosis. **Rejected
  alternative**: reduce starts to shorten runtime, because that would change
  the scientific fitting protocol rather than improve it. **Confidence**:
  high.

## 4. Files Touched

- `dev/benchmark-two-tier-mixed.R`: non-shipped reproducible benchmark runner.
- `docs/dev-log/2026-07-24-performance-audit-plan.md`: approved audit contract.
- `docs/dev-log/check-log.md`: append-only commands and timing receipts.
- This after-task report.

## 5. Checks Run

- Mixed-family fixture: passed with heavy tests enabled.
- Phylogenetic mixed-family extractor fixture: passed with heavy tests enabled.
- Local species-level smoke (20 x 3): all one/five/warm BFGS fits converged.
- Totoro ladder: all recorded BFGS fits converged through 200 x 27. At that
  scale the one-start/five-start/warm totals were 77.092/598.939/2.707 s.
- `TMB::benchmark(..., n = 10)` was saved for objective, gradient, sparse
  Hessian, and Cholesky operations at the warm optimum.

`devtools::check()`, `pkgdown::check_pkgdown()`, and documentation generation
were not run: no package source, exports, roxygen, or rendered user surface
changed. No performance patch exists to validate for numerical parity.

## 6. Tests of the Tests

No test suite was added because this is a developer-only benchmark, not a new
package feature. The runner exercised two existing validated mixed-family
fixtures first, then wrote restart histories, dimensions, controls, session
information, and TMB micro-timing so a future result can be independently
checked.

## 7. Roadmap Tick

N/A: this developer-only evidence phase changes no `ROADMAP.md` row, status
chip, or progress bar.

## 7a. Issue Ledger

The current `itchyshin/gllvmTMB` open-issue list was inspected. Issue #705
(matrix-free/Hutchinson REML feasibility) is not this mixed-family Laplace
audit; no existing issue was updated and no new issue was created because this
phase made no package change. Ayumi's external BIRDBASE_pcm issue #3 received
the already-approved request for a timing receipt; it is not a gllvmTMB tracker
issue.

## 8. Consistency Audit

The report distinguishes total optimizer elapsed time from fixed-parameter
TMB micro-times, and distinguishes this synthetic rank-1 ladder from Ayumi's
rank-2, 5,397-species, mixed-family analysis. No capability claim or example
cascade is implicated. The initial crossed smoke receipt remains in the
append-only check log and is explicitly marked superseded for structural
comparability by the species-level ladder.

Command and verdict:

```sh
rg -n "performance-audit|benchmark-two-tier-mixed|BIRDBASE" dev docs/dev-log
```

Verdict: every result-bearing reference is confined to the developer harness,
plan, check log, or this report; no user-facing package claim was introduced.

## 9. What Did Not Go Smoothly

The first smoke used a crossed site-by-species grouping and therefore was not
structurally comparable enough for Ayumi's all-species formula. The harness
was corrected before scale evidence was interpreted. Remote compilation also
needed an isolated Totoro R library and removal of macOS-built objects; neither
altered the shared runtime. The current synthetic generator is rank-1 only.

## 10. Known Residuals

The ladder omits BIRDBASE data, rank 2, ordinal/lognormal families, parallel
starts, and native-symbol profiling. Warm-start speed here is for the exact
same model and cannot be assumed for a response-set change. The existing
`docs/dev-log/known-limitations.md` was not changed because this phase adds no
package capability or known behavioural limitation.

## 11. Team Learning

**Gauss / Noether:** the focused source review found no active dense
phylogenetic inverse. Expected Laplace random-effect Hessian/factorisation,
per-long-row latent assembly, family dispatch/ordinal cutpoint construction,
sparse phylogenetic quadratic forms, and report materialisation are candidates
for measurement, not defects.

**Jason:** the H-squared speed result comes from a specialised Gaussian REML
eigen route, so it is a useful warning to measure first but does not transfer
automatically to this mixed-family Laplace GLLVM.

**Rose:** the first crossed smoke was retained as historical evidence but
explicitly superseded for structural comparability; the receipt now separates
optimizer totals from TMB fixed-vector micro-times.

## 12. Cross-Product Coverage

N/A: this is a developer-only timing harness. It adds no package feature whose
family, covariance, parser, or documentation cross-product needs coverage. It
does NOT cover any new response-family, engine, REML, penalty, missing-data,
aggregation, formula-grammar, or user-documentation cell.

## 13. Next Actions and Handoff

No code is ready to merge. The audit branch contains only developer evidence
and should remain separate from the active Claude worktree. Ayumi already has
the timing-receipt request; she should keep five starts and the gradient gate.
If a follow-up is authorised, begin with the frozen BIRDBASE benchmark rather
than a general C++ rewrite.
