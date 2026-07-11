# After-task — 8 documentation-honesty ship-blockers fixed (0.5.0)

**Date:** 2026-07-11
**Author:** Claude (with Shinichi)
**Scope:** the 8 surviving overclaims on public/shipped doc surfaces that the
member audit (`wf_e5d09cbb`) flagged as must-fix-before-honest-0.5.0 and that
PR #746 does NOT address. Doc/roxygen only; no code-behaviour, API, or family
change.

## What changed (13 files)

1. `R/brms-sugar.R` + `man/latent.Rd` — `@param lv` no longer claims "no runtime
   support implemented yet" (false); states the true regime: ordinary unit-tier
   Gaussian + pure binomial fit (C1 `partial`, LV-02 covered), structured
   `*_latent(lv=)` fail loud (LV-07 blocked).
2. `R/kernel-helpers.R` + `man/profile_cross_rho_ci.Rd` — retitled "sensitivity
   interval"; description no longer says "confidence interval"; added an explicit
   "coverage has not been calibrated; do not report as a validated CI" fence
   (COE-04 partial).
3. `vignettes/articles/response-families.Rmd` + `mixed-family-extractors.Rmd` —
   every "pending a convergence fix" / "awaits a fix" / "landing on a convergence
   boundary" replaced with "route-only / uncalibrated (CI-08/CI-10) / not
   advertised". The old framing was itself false: the register (MIX-10 / FAM-17
   addendum, 2026-07-05) records the "boundary" as a phantom `pdHess` read, 6/6
   seeds converge, "no convergence fix is warranted".
4. `_pkgdown.yml` — `categorical()` / `cumulative_logit()` moved out of "Response
   families" into a new "Predictor-model families (imputation)" group (they are
   `mi()` predictor-model tags, per `R/missing-predictor.R`); added a desc fencing
   the exported-but-fail-loud constructors (FAM-16/18/19).
5. `vignettes/articles/morphometrics.Rmd` — removed a duplicated/garbled
   blockquote and a duplicate H2 header.
6. `vignettes/articles/joint-sdm.Rmd` — removed the stale "there is no estimated
   Psi" paragraph; kept the correct "the unit-level `latent()` term estimates
   Psi_B", consistent with the ICC formula (psi_B in the denominator).
7. `R/spde-keyword.R` + `man/spde.Rd` — removed two references to the
   non-existent `vignette("spde-vs-glmmTMB")`.
8. `R/plot-gllvmTMB.R` + `man/plot.gllvmTMB_multi.Rd` — added a "recovery-grade,
   not coverage-calibrated (CI-08/CI-10)" caveat to the black-border/star
   correlation-significance markup (roxygen desc, plot caption, and `.Rd`).

## Judgment calls made conservatively (open for the maintainer)

- (2) `profile_cross_rho_ci` — strengthened the honesty *wording* but left it
  exported in its current reference group; the fuller option is `@keywords
  internal` + a register row.
- (4) moved the mis-filed predictor tags + added a fencing desc, but left the full
  covered-vs-blocked family *partition* to coordinate with PR #746's pkgdown reorg.

## Checks

- Adversarial verify pass (independent agent, grounded in docs/design/35 + 61):
  **8/8 PASS**, no surviving or newly-introduced overclaim; every roxygen/man pair
  in sync.
- `git grep` for the stale phrases over `R/ vignettes/ man/` (excl. design docs):
  zero hits. NAMESPACE untouched (S3 registrations intact).

## Follow-up

- **Codex, before submission:** run a real `devtools::document()` — a source-load
  `roxygenise()` mis-registers this package's S3 methods (turns `S3method()` into
  `export()`), so the 4 `man/.Rd` here were hand-synced to the roxygen source;
  `document()` will reproduce them identically and is the toolchain-correct path.
- The **systemic** fix the audit recommends (author the "recovery-grade, coverage
  not calibrated" fence once as a shared roxygen `@section` and reference it across
  every interval-returning function doc) is the highest-leverage next step — not
  done here; blocker 8 is one instance of it.
