# After Task: Robust Modeling Starts And Diagnostics

**Branch**: `codex/rr-residual-starts-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Fisher / Curie / Emmy / Pat / Grace / Rose / Shannon`

## 1. Goal

Implement the first practical slice of the comprehensive robust-modeling
roadmap: preserve difficult fits when inference machinery degrades,
record start and restart provenance, expose machine-readable fit-health
diagnostics, and commit a source-of-truth roadmap/design scaffold before
larger M3.3a/M3.4 simulations or reader-facing convergence teaching.

## 2. Implemented

- Added `check_gllvmTMB()`, a stable table-returning diagnostic helper
  for `gllvmTMB_multi` fits. It reports optimizer convergence, maximum
  gradient, `sdreport()` availability, `pdHess`, maximum fixed-effect
  SE, restart-history availability, selected restart, and simple
  boundary flags.
- Fitted objects now retain `restart_history`, `start_provenance`,
  `sdreport_error`, and `fit_health`.
- `TMB::sdreport()` is wrapped in `tryCatch()`. A fit can now return
  with `sd_report = NULL` plus an explicit degraded-inference status
  instead of crashing at the standard-error step.
- `gllvmTMBcontrol(se = FALSE)` intentionally skips `TMB::sdreport()`
  and keeps the point-estimate fit for bootstrap/profile uncertainty
  workflows when Hessian-based SEs are not the right tool.
- Multi-start attempts now store one row per restart, including start
  method, optimizer, jitter scale, objective, convergence, message,
  elapsed time, iteration/evaluation counts where available, success,
  and selected status.
- Residual starts and simpler-model starts remain opt-in through
  `gllvmTMBcontrol(start_method = ...)` and `start_from`. Jittered
  restarts re-clamp `log_phi*` starts to the defensive `[log(0.01),
  log(100)]` interval.
- Optimizer controls now forward user-supplied `optim()` and `nlminb()`
  arguments more faithfully while preserving conservative defaults.
- `gllvmTMB_diagnose()` now points users toward `check_gllvmTMB()`,
  start strategies, optimizer fallback, and profile/bootstrap
  inference for interpretable `Sigma` targets when Hessian diagnostics
  are weak.
- `docs/design/49-robust-modeling-roadmap.md` now records the full
  robust-modeling program, including the standing team table,
  `pdHess` policy, start-value ladder, target-explicit inference
  policy, M3.3a pilot gates, family stress lanes, comparator program,
  profile/bootstrap plan, plotting/HPC lanes, pkgdown article plan,
  branch split, and definition of done.

## 3. Files Changed

Implementation:

- `R/fit-multi.R`
- `R/diagnose.R`
- `R/gllvmTMB.R`
- `R/init-warmstart.R`
- `R/methods-gllvmTMB.R`
- `NAMESPACE`

Tests:

- `tests/testthat/test-gllvmTMBcontrol.R`
- `tests/testthat/test-start-method-residual.R`
- `tests/testthat/test-sanity-multi.R`
- `tests/testthat/test-stage39-multi-start.R`

Documentation and generated help:

- `man/check_gllvmTMB.Rd`
- `man/gllvmTMBcontrol.Rd`
- `NEWS.md`
- `_pkgdown.yml`
- `ROADMAP.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/48-m3-4-boundary-regimes.md`
- `docs/design/49-robust-modeling-roadmap.md`

Coordination and closeout:

- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-19-173400-codex-checkpoint.md`
- `docs/dev-log/after-task/2026-05-19-robust-modeling-starts-diagnostics.md`

## 3a. Mathematical Contract

No TMB likelihood, family, formula grammar, covariance keyword, or
model parameterization changed in this slice. The statistical contract
added here is diagnostic and provenance-oriented:

- `pdHess = FALSE` is treated as an inference and identifiability
  warning, not automatic proof that point estimates or
  rotation-invariant covariance summaries are unusable.
- `se = FALSE` skips curvature-based SE calculation by design. The fit
  object remains available for point summaries, diagnostics, and
  bootstrap/profile uncertainty.
- Start methods are opt-in. The selected fit is still chosen by the
  optimizer objective among attempted starts.
- Residual starts seed reduced-rank loadings and latent scores from a
  grouped residual matrix, rotated into the engine's lower-triangular
  loading convention.
- Simpler-fit starts copy only same-shaped TMB parameter blocks from a
  prior `gllvmTMB` fit.
- Raw `Lambda` and raw `psi` remain diagnostic targets until
  simulation evidence supports stronger inference claims. Promotion
  evidence should focus on interpretable targets such as
  `Sigma = Lambda Lambda^T + Psi`, trait correlations, communality,
  repeatability, and variance shares.

## 3b. Decisions and Rejected Alternatives

**Decision**: add `check_gllvmTMB()` as a table helper rather than
expanding printed output from `gllvmTMB_diagnose()` only.
**Rationale**: M3 simulations and future articles need stable columns.
**Rejected alternative**: parse human-readable warning messages.
**Confidence**: high.

**Decision**: preserve fits when `sdreport()` fails.
**Rationale**: point estimates and rotation-invariant summaries may be
useful even when curvature-based inference is unsafe.
**Rejected alternative**: abort every fit at the SE step.
**Confidence**: high.

**Decision**: add `gllvmTMBcontrol(se = FALSE)` now, before the PR.
**Rationale**: hard models may need point estimates first and
bootstrap/profile uncertainty second, matching the drmTMB workflow.
**Rejected alternative**: make users wait for `sdreport()` to fail or
manually edit fit objects before bootstrapping.
**Confidence**: high.

**Decision**: keep residual starts, simpler starts, and optimizer
fallback opt-in.
**Rationale**: McGillycuddy/glmmTMB-style advice supports trying
multiple starts and BFGS, but `gllvmTMB` needs target-explicit evidence
before making automatic policy changes.
**Rejected alternative**: silently switch starts or optimizers after a
warning.
**Confidence**: high.

## 4. Checks Run

- `git status --short --branch`
  - Outcome: branch `codex/rr-residual-starts-2026-05-19` with the
    expected robust-modeling files modified.
- `gh pr list --state open --limit 20`
  - Outcome: no open PR rows printed before editing shared files.
- `git log --all --oneline --since="6 hours ago"`
  - Outcome: recent M3 / CI merges inspected, including PRs #199
    through #205.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Outcome: regenerated `NAMESPACE`, `man/gllvmTMBcontrol.Rd`, and
    `man/check_gllvmTMB.Rd`.
- `Rscript --vanilla -e 'invisible(parse(file="R/fit-multi.R")); invisible(parse(file="R/diagnose.R")); invisible(parse(file="R/methods-gllvmTMB.R")); cat("parse ok\n")'`
  - Outcome: `parse ok`.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); cat("load_all ok\n")'`
  - Outcome: `load_all ok`.
- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi")'`
  - Outcome: 14 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test(filter = "stage39-multi-start")'`
  - Outcome: 15 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-diagnose")'`
  - Outcome: 10 passed, 0 failed, 0 warnings, 0 skipped after replacing
    deprecated `"B"` / `"W"` aliases in `gllvmTMB_diagnose()`.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMBcontrol|start-method-residual|multi-start-sdreport-consistency")'`
  - Outcome: 60 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'devtools::test()'`
  - Outcome: 0 failed, 19 warnings, 14 skipped, 1875 passed; duration
    1669.3 s. Slow points included `phylo-q-decomposition` (666.9 s)
    and `profile-ci` (352.1 s).
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  - Outcome: rerun after adding `gllvmTMBcontrol(se = FALSE)`;
    regenerated `man/gllvmTMBcontrol.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMBcontrol|sanity-multi")'`
  - Outcome: 54 passed, 0 failed, 0 warnings, 0 skipped.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Outcome: `No problems found.`
- `git diff --check`
  - Outcome: clean.

## 5. Tests of the Tests

- `test-start-method-residual.R` pins the residual-factor helper on a
  known low-rank residual matrix and checks finite, non-default,
  lower-triangular starts.
- `test-start-method-residual.R` fits a small Gaussian latent+unique
  model with `start_method = "res"` and verifies the latent and unique
  starts are actually changed.
- `test-start-method-residual.R` fits a small Gaussian model with
  `start_method = "indep"` and verifies the simpler-fit warm start
  copies GLMM pieces while leaving the unmatched latent block at the
  historical default.
- `test-stage39-multi-start.R` now checks restart-history cardinality,
  selected-restart uniqueness, and provenance consistency.
- `test-sanity-multi.R` checks the `check_gllvmTMB()` schema and a
  forced degraded `sdreport()` object. The deterministic in-fit TMB
  failure fixture is still missing, which is why DIA-09 is `partial`,
  not `covered`.
- `test-sanity-multi.R` now checks `gllvmTMBcontrol(se = FALSE)` on a
  fitted object: point estimates remain, `sd_report` is `NULL`, and
  `check_gllvmTMB()` reports the skipped-SE state as an `sdreport` WARN.

## 6. Consistency Audit

- `rg "\bS_B\b|\bS_W\b|\\bf S" .`
  - Outcome: hits only historical/dev-log/check-log/protocol/audit
    notes; no new touched public files reintroduced legacy S notation.
- `rg -n "gllvmTMB\(" R vignettes README.md NEWS.md docs/design`
  - Outcome: this lane's new `R/diagnose.R` example has
    `trait = "trait"` and `unit = "site"`; Design 48 snippets are
    schematic design prose, not runnable long-format examples.
- `rg "in prep|in preparation" docs vignettes`
  - Outcome: hits only existing historical/internal records; no new
    robust-modeling docs introduced foundational in-prep claims.
- `rg "\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(" vignettes`
  - Outcome: no hits.
- `rg "meta_known_V" README.md NEWS.md docs vignettes`
  - Outcome: existing intended alias/deprecation/history hits only; no
    new robust-modeling docs present `meta_known_V` as primary syntax.
- `rg "gllvmTMB_wide" README.md NEWS.md docs vignettes`
  - Outcome: existing soft-deprecation/history hits only; no new
    robust-modeling docs present `gllvmTMB_wide()` as primary syntax or
    claim removal while exported.

## 7. Roadmap Tick

M3 overall remains `3/8`. M3.4 changed from
`Boundary-regime mitigations and diagnostics` to
`Robust modeling: starts, pdHess, fit health, and boundary diagnostics`,
with status still partial. The row now points to MIS-16..MIS-20,
DIA-08, DIA-09, DIA-10, and Design 49.

## 8. What Did Not Go Smoothly

The full test suite was slow but completed after letting
`phylo-q-decomposition` and `profile-ci` finish. This is a useful
Grace lesson: local full validation is feasible here, but it is a
half-hour operation and should be scheduled deliberately.

The first diagnostic test run also surfaced old `"B"` / `"W"`
communality aliases inside `gllvmTMB_diagnose()`. That was unrelated
to the new helper but worth fixing in the same diagnostic lane because
the warnings would otherwise make convergence output feel noisier than
necessary.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept this as Branch 0 plus the first Branch A slice: checkpoint
the existing start lane, preserve the current branch, then add durable
diagnostic/provenance infrastructure before opening wider simulation or
article work. No spawned subagents were running; these are standing
review perspectives applied within this branch.

**Boole** shaped the API surface: `check_gllvmTMB()` is a plain table
with stable columns, while `gllvmTMB_diagnose()` stays human-facing.
The start controls remain explicit through `gllvmTMBcontrol()` rather
than hidden policy.

**Gauss** kept the numerical contract focused on optimizer state,
gradient, objective, `sdreport()`, and `pdHess`. The branch does not
change the TMB likelihood, and it does not call residual starts
validated simply because a model converges.

**Noether** kept the target distinction visible: raw `Lambda` and raw
`psi` are diagnostic until target-explicit evidence supports them;
`Sigma`, correlations, communality, repeatability, and variance shares
are the interpretation targets that matter for promotion evidence.

**Fisher** guarded the inference language. `pdHess = FALSE` now blocks
naive Wald inference, not the whole fitted object, and the roadmap
points toward profile/bootstrap evidence for nonlinear targets.

**Curie** kept tests narrow and CRAN-safe: the new tests pin contracts,
provenance, and degraded diagnostics without trying to prove
convergence-rate superiority inside unit tests.

**Emmy** watched object structure. The new fields live on the fitted
object and are reusable by simulations, extractors, future plotting
helpers, and pkgdown articles without changing existing extractor
contracts.

**Pat** kept the user pathway simple: after a hard fit, the reader can
call `check_gllvmTMB(fit)` and see what to try next instead of
interpreting one binary convergence flag.

**Grace** ran the full local suite after the focused checks. The branch
now has local full-suite evidence plus pkgdown, but still needs 3-OS CI
before merge.

**Rose** checked claim discipline across NEWS, ROADMAP, validation
debt, and design docs. The branch says which items are implemented,
partial, or evidence-pending.

**Shannon** checked coordination before shared-file edits: no open PR
rows were returned, recent merges were inspected, and the live
coordination board records the active lane.

## 10. Known Limitations And Next Actions

- DIA-09 stays `partial`: diagnostics degrade cleanly on a forced
  degraded object, but a deterministic in-fit `sdreport()` failure
  fixture is still needed before marking the row covered.
- Full local `devtools::test()` completed, but 3-OS CI is still required
  before merge.
- Residual starts, simpler-model starts, multistart, and optimizer
  fallback are implemented or wired as opt-in tools, not promoted
  defaults.
- Multicore bootstrap should be a first-class teaching and artifact
  path in the next inference lane: users with many laptop cores should
  be able to get uncertainty after `se = FALSE` without hidden refit
  failures or seed ambiguity.
- Next slice: run the M3.3a target-explicit pilot with fit-health
  metadata, selected restart, start method, optimizer, `pdHess`,
  `sdreport()` status, and refit-failure fields.
- Next docs slice: draft
  `vignettes/articles/convergence-start-values.Rmd` only after the
  diagnostic schema survives pilot use.
