# External audit response -- 2026-05-15

The maintainer shared an external code/architecture/statistical-design
audit of gllvmTMB on 2026-05-15 (after Phase 1b items 1-5 had merged
into main earlier the same day). The audit was unusually thorough:
~30 numbered findings, ranked by severity, with a comparison to
drmTMB's current state for several items. This document records
the triage, the maintainer's scope decision, and the resulting
PR plan.

The audit's full text lives in this repository's conversation
log (2026-05-15). The headlines and triage below distil it into
actionable items.

## P0 (critical correctness)

### Multi-start `obj$report()` / `sdreport(obj)` consistency with `fit$opt$par`

The audit's #1 concrete concern. **Verified real by code
inspection** (~30 min) before patching:

`R/fit-multi.R:1700-1702` (pre-fix):

```r
opt <- best_opt                            # picks best across n_init restarts
rep <- obj$report()                        # uses obj$env$last.par (LAST eval)
sd_rep <- TMB::sdreport(obj, ...)          # uses last.par.best (fragile)
```

`obj$report()` with no args defaults to `obj$env$last.par`. After
the multi-start loop, that is whatever the FINAL restart's
optimizer touched last -- NOT `best_opt$par`. When restart 1
wins but restart N (N > 1) runs last (common with `n_init >= 2`
and a lucky early restart), every downstream extractor reading
`fit$report` (`extract_Sigma`, `extract_correlations`,
`extract_communality`, `extract_phylo_signal`, ordination,
communality, repeatability, `plot.gllvmTMB_multi`, ...)
consumed report values for restart N's params while `fit$opt$par`
and `fit$opt$objective` were from restart 1.

`sdreport(obj)` partially defended via TMB's `last.par.best`
tracking but was fragile in pathological cases (a restart's
optimizer transiently visited a better point and walked away).

**Status**: fixed as **PR #116** (queued). Three-step pinch of
TMB's internal state to `opt$par`: `obj$fn(opt$par)` ->
`obj$env$last.par.best <- obj$env$last.par` ->
`obj$report()` + `TMB::sdreport(obj, par.fixed = opt$par, ...)`.
Bundled regression test
`tests/testthat/test-multi-start-sdreport-consistency.R`
explicitly verifies `fit$report`, `fit$sd_report$par.fixed`,
`logLik(fit)`, and `extract_Sigma()` are all self-consistent
with `fit$opt$par`. 17 expectations, 5 tests, `skip_on_cran()`
gated.

Existing `test-stage39-multi-start.R` did not catch this: it
only checked `fit$opt$convergence == 0L` and
`is.finite(-fit$opt$objective)`. Neither verified report /
sd_report consistency with `fit$opt$par`.

## Items already addressed by today's earlier merges

The audit was written before today's morning wave of Phase 1b
merges. These items the audit lists as "the right next work" are
now in main:

| Audit item | PR (merged earlier 2026-05-15) |
|---|---|
| `extract_correlations(link_residual = "auto")` default | #101 |
| `check_auto_residual()` safeguard | #104 |
| `check_identifiability()` Procrustes-aligned diagnostic | #105 |
| Mixed-family extractor tests + 15-family fixture | #106 |
| `mu_t` Beta/betabinomial clamp (Gauss correctness flag) | #100 |
| drmTMB cross-team learning scan | #109 |

The auditor's view was several hours stale on these points -- not
a fault of the audit, just timing.

## P1 (API surface / docs alignment)

### P1a -- `profile_targets()` + `confint(method = c("wald", "profile", "bootstrap"))`

**Finding**: `confint.gllvmTMB_multi` returns Wald via `tidy()`
for fixed effects, but the package has sophisticated
profile-likelihood machinery (`tmbprofile_wrapper`,
`profile_ci_*` family). API mismatch.

**Reference implementation** (per Explore scout 2026-05-15
documented in `docs/dev-log/audits/2026-05-15-drmtmb-cross-team-scan.md`):
drmTMB's `R/profile.R` exposes `profile_targets(object,
ready_only = FALSE)` returning a tidy data frame with
controlled vocabularies for `target_type`,
`profile_note`, and `transformation`. `confint.drmTMB()`
consults this inventory and routes between Wald and profile.

**Plan**: PR after P0 merges. Mirror drmTMB's controlled
vocabulary exactly so the broader TMB-package family stays
consistent. gllvmTMB-specific additions: a
`latent_rotation_ambiguous` `profile_note` entry for
rotation-invariant derived quantities, and
`lambda_packed` / `repeatability_logit` `transformation`
entries.

### P1b -- README "ML / REML" softening + stable-core feature matrix

**Finding**: `README.md:23` and `README.md:291` say "ML / REML
estimates" but no user-facing REML switch exists.
`gllvmTMBcontrol()` has no `reml` argument. `NEWS.md:131` is
already honest ("REML is not yet implemented; planned for a
post-0.2.0 release as a Gaussian-only feature"). The README
needs to match.

**Audit-recommended addition**: a Stable-core feature matrix in
the README. Rows: features (Gaussian latent + unique, binomial /
Poisson / NB2 latent, mixed-family Sigma extraction,
link_residual = "auto" in all extractors, profile CIs for
direct vs derived quantities, family-aware simulation,
random slopes, spatial latent, dense known V). Columns:
stable / experimental / planned.

**Plan**: PR after P0 merges. Docs-only.

### P1c -- This audit-response doc + decisions.md ratification

**Status**: this document itself. Plus a `decisions.md` entry
ratifying the partial-reset scope decision below.

## P2 (queued for Phase 1b validation milestone)

The audit asks for two larger pieces that the existing roadmap
already queued under the Phase 1b validation milestone:

- **Family-aware `simulate.gllvmTMB_multi()`**: currently
  Gaussian-noise-only with conditional fallback for non-Gaussian
  fits. Audit's recommendation is to make it family-aware
  (binomial -> rbinom, Poisson -> rpois, ordinal -> threshold,
  delta -> Bernoulli + positive component). Phase 5.5 will
  exercise this through the simulation grid.

- **Family-aware `predict.gllvmTMB_multi()`**: currently
  uses `object$family$linkinv` which is wrong for mixed-family,
  ordinal-probit (need category probabilities), and delta
  models (need presence probability + positive-component mean +
  unconditional mean separately). Audit's recommendation is
  `type = c("link", "mean", "prob", "category", "presence", "positive_mean", "variance")`.

Both are pre-CRAN scope items per the Phase 5 plan and the
Phase 5.5 external-validation sprint. Not blocking the current
Phase 1c work.

The third P2 item is `confint_inspect(fit, parm)` -- already
planned in the Phase 1b validation milestone per the
TMB-report-driven scope updates from earlier today.

## P3 (deferred to post-CRAN / Phase 6)

- **C++ template modularization** (audit item: `src/gllvmTMB.cpp`
  is becoming too large). Defer. Once random slopes + more
  spatial/phylogenetic layers enter, modularise into
  `covariance_rr.hpp`, `covariance_diag.hpp`,
  `covariance_phylo.hpp`, `covariance_spde.hpp`,
  `likelihood_families.hpp`, `likelihood_ordinal.hpp`,
  `likelihood_delta.hpp`, `reports.hpp`. Audit explicitly says
  "becoming too large", not "currently broken".

- **Storage controls** (`gllvmTMBcontrol(keep_tmb_object =
  FALSE)`). Mirror drmTMB's pattern. Useful for serialised-fit
  size but not blocking; Phase 6.

- **Dense known-V threshold warning**. Add a size-threshold
  warning when `known_V` is dense and large. Minor; bundle with
  Phase 5 polish.

- **Random slopes** (Phase 1c-slope in the original roadmap).
  Audit explicitly says: don't add until P0 + P1 + P2 + Phase 1b
  validation milestone are stable.

## Maintainer scope decision (2026-05-15)

Asked via AskUserQuestion: how should the audit reshape
priorities? Options were `full reset` / `partial reset` /
`P0 only`. Maintainer chose **partial reset**:

> Let the 6 in-flight docs PRs (#110-#115) merge as CI clears
> (they're docs-only, don't touch audit's R-code surface).
> After they land, pause new article ports. Pivot to P0 fix ->
> P1 (profile_targets + confint API + README softening + feature
> matrix) -> Phase 1b validation milestone. Resume Phase 1c
> article ports only after that.

Also: the P0 fix ships with its regression test bundled in the
same PR (rather than a follow-up PR). Mirrors the
CONTRIBUTING.md "check the check" discipline.

## Sequencing locked

1. **Step 1 (now -> ~next hour)**: 6 in-flight docs PRs land
   (#110 + #112 already merged; #111, #113, #114, #115 rebased
   + force-pushed; CI re-running).

2. **Step 2 (immediately after Step 1)**: P0 (PR #116) lands.

3. **Step 3 (after P0)**: P1a / P1b / P1c sub-PRs sequentially.

4. **Step 4 (after P1)**: Phase 1b validation milestone (Fisher
   coverage study + `confint_inspect()` adopting drmTMB's
   controlled vocabulary).

5. **Step 5 (after validation milestone)**: resume Phase 1c
   article ports (remaining 6 articles, including
   `simulation-verification.Rmd` as the 4th new pedagogy
   article).

## What this audit-response does NOT change

- **No C++ modularization** (audit P3; defer post-CRAN).
- **No storage controls** (audit P3; defer post-CRAN).
- **No new Phase 1c article ports** beyond #110-#115 (the wave
  that's landing right now).
- **No new Phase 1c-viz visualization work**.
- **No random-slope work** (Phase 1c-slope holds).
- **No simulate.gllvmTMB_multi() / predict.gllvmTMB_multi()
  family-aware rewrite**. Both are real scope items but Phase
  5.5 / pre-CRAN, not this replan.

## Cross-references

- Active plan: `/Users/z3437171/.claude/plans/please-have-a-robust-elephant.md`
  (revised 2026-05-15 with the audit-driven section).
- drmTMB cross-team scan (PR #109, merged):
  `docs/dev-log/audits/2026-05-15-drmtmb-cross-team-scan.md`.
  drmTMB's `profile_targets()` controlled-vocabulary pattern is
  the reference for P1a.
- Strategic roadmap context:
  `docs/dev-log/decisions.md`. Today's entry below this one
  ratifies the partial-reset scope decision.
