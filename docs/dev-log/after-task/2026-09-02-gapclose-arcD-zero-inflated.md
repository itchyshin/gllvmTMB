# After Task: ARC D1 — zero-inflated families `zi_poisson()`, `zi_nbinom2()`, `zi_binomial()`

**Date:** 2026-09-02
**Branch:** `claude/gapclose-arcD-zi-20260902` (stacked on `claude/gapclose-20260902`, PR #1239); worktree outside Dropbox
**Roles engaged:** Ada (orchestration), Gauss/Curie/Boole (builder), a fresh Opus Gauss/Noether/Fisher/Boole adversarial reviewer, Melissa (reconcile). Builders ran as fresh-context Sonnet children; recon on Sonnet after a Haiku scout stalled.

## 1. Goal

Port the first user-facing capability the Julia twin added first (owner decision 2026-09-02: parity
both ways for user-facing capabilities, D-204): true zero-inflated count and binomial families, so an
ecologist with excess zeros no longer has to leave the package or misuse a delta/hurdle family.

## 2. Mathematical contract

Mixture at zero for each family, per trait t with zero-inflation probability π_t = logit⁻¹(logit_zi_t):
P(y = 0) = π_t + (1 − π_t)·f(0 | μ, φ); P(y = k > 0) = (1 − π_t)·f(k | μ, φ), with f the Poisson,
NB2 (gllvmTMB's per-trait `phi_nbinom2` convention) or binomial(N) density, the zero branch computed
with `logspace_add`. The count linear predictor `eta` carries the fixed effects, `latent()` and the
whole covariance grid; the zero part is per-trait intercept-only (Design 62 Decision 2). E[y] =
(1 − π_t)·μ. Laplace only: `integration = "va"`, AGHQ and MSPL refuse the three families (Designs
105/106/108). `zi_binomial()` is admitted only when at least one row per trait carries trials ≥ 2,
because the single-trial mixture collapses to one parameter. Family ids 17/18/19. Full table:
`dev/gapclose/arcD/alignment-zi.md`.
AGHQ **declines** zi fits to plain Laplace with a reason-specific warning (the same mechanism as every
other ineligible model); VA and MSPL refuse.

## 3. Findings and files

23 files, +2008/−19 in commit `7e043040a`, plus the review round `52043b3db` (18 files, +866/−61): `src/gllvmTMB.cpp` (three cases, `logit_zi` parameter
vector mapped per trait), `R/families.R` (constructors), `R/enum.R`, `R/fit-multi.R` (admission,
starting values from the observed zero excess, parameter map), `R/dispersion-trait-map.R`,
`R/methods-gllvmTMB.R` (`fitted()`, `simulate()`), `R/predictive-diagnostics.R` (mixture-CDF
randomized-quantile residuals), `R/diagnose.R` (boundary note when π < 0.01 or > 0.95),
`R/integration-fence.R` and the AGHQ/MSPL registries (refusals), `NAMESPACE`, `man/`, `NEWS.md`,
`docs/design/02-family-registry.md` (14 slots), `docs/design/03-likelihoods.md`,
`docs/design/35-validation-debt-register.md` (FAM-21/22/23 `partial`), the capability ledger rows
with aliases `zip`/`zinb`/`zib` (matched to GLLVM.jl's rows), tests `test-zi-families.R` (26) and
`test-zi-recovery.R` (13 + a 5-seed variant behind `GLLVMTMB_HEAVY_TESTS`). Also fixed
`tools/parity_ledger.R` silently dropping 7 Julia rows inside an HTML-comment table.

## 4. Checks run

Builder: density identity vs an R mixture (max error 0, 0, 5.1e-13), finite-difference gradients
(1.9e-8, 1.3e-8, 3.9e-6), parser/refusal/mixed-family tests, known-DGP recovery (rank-1, 6 traits;
zi_poisson n = 150: intercepts 0.079, zi 0.066, loadings rel. Frobenius 0.124; zi_nbinom2 n = 400:
0.070 / 0.034 / 0.194, phi median 19% with 2/6 traits above the 30% bar; zi_binomial n = 150, N = 10:
0.077 / 0.071 / 0.237), 20 neighbouring test files re-run green. Orchestrator re-run via
`devtools::test(filter = "zi-")`: 26/26 and 13/13 (+1 heavy skip); ledger `--check` 77 rows /
0 unmapped; parity CLOSURE PASS. Opus adversarial review (Gauss/Noether/Fisher/Boole, fresh): **PASS-WITH-CORRECTIONS, 0 blocking,
6 required, 6 suggestions** — the density, phi convention, per-trait `logit_zi` indexing, masking,
gradient and mixture CDF all held against independent R computations (0 / 2.1e-14 / 1.1e-13); the
findings were about the surrounding surface: the rootogram refused zi count families, the 14-slot
`link_residual_rule` was unimplemented (so `extract_Sigma()` returned NA on zi traits), AGHQ was
documented as refusing when it declines to Laplace, the FAM-22 caveat understated (2/6 traits exceed
the 30% phi bar on each of three seeds) and no phi-runaway detector existed, the help-page example did
not converge, and the single-seed recovery bars were breached on 3 of 4 extra seeds. All were fixed in
`52043b3db` by the same builder (n raised to 200/250 so the bars hold across seeds 101–404, heavy
5-seed block now asserts `zi` and loadings, `boundary_phi_nbinom2` detector, `predict(newdata)` applies
(1 − π)). Orchestrator re-run against the development package after the fixes: `test-zi-families` 42,
`test-zi-recovery` 13 (+1 heavy skip), `test-extract-sigma` 34, `test-extract-sigma-table` 65,
`test-predictive-diagnostics` 158, `test-integration-fence` 57 — all FAIL 0; the families help page's
check-visible examples (38 expressions, `\donttest` on, `\dontrun` off) all run and the zero-inflated
example converges (code 0). Full suite and R CMD check: run at merge time on the rebased branch
(R/ and src/ changed); CI on the stacked PR provides the ubuntu check.

## 5. Tests of the tests

The density-identity test would fail on any mis-typed f(0) (it compares the TMB objective with an
independent R sum); the gradient test would fail on a wrong derivative; the mixed-family test with a
plain `poisson` trait between two zi traits pins the per-trait `logit_zi` indexing; the single-trial
`zi_binomial` refusal is asserted with its named alternative; the VA refusal is asserted per family.

## 6. Consistency and documentation audit

Alignment table ↔ C++ ↔ roxygen ↔ NEWS ↔ Design 02/03 ↔ register ↔ ledger checked by the builder and
by the Opus reviewer (see §4). No register codes on reader-facing surfaces (grep).

## 7. Design and pkgdown

Design 02 gains three family sections with all 14 slots; Design 03 gains the three likelihoods;
`docs/design/capability-status.md` regenerated (77 rows). Reference pages for the three constructors
with runnable examples. **Roadmap tick:** none (ROADMAP tracks no family list).

## 8. GitHub issue ledger

Closes the "zero-inflated families" item of `dev/gapclose/B3-issues.md` (issue 1) once merged;
GLLVM.jl's ADEMP campaign (6,000 fits on Totoro) is the oracle for a later multi-seed comparison.

## 9. What did not go smoothly

- The first (Haiku) recon scout produced nothing in two hours and was replaced by a Sonnet recon
  with an incremental-write rule, which finished in five minutes.
- The orchestrator's first re-run used `testthat::test_file()` against the installed 0.7.1 and
  reported every ZI test as skipped; only `devtools::test(filter=)` loads the development tree.
- Two agents fixed the same parity-tool parser bug in two worktrees; the ARC D commit is canonical and
  the duplicate is stashed.
- `zi_nbinom2` dispersion recovery misses the 30% bar on 2/6 traits at n = 400 (single seed); the
  register row states it rather than the bar being loosened.

## 10. Team learning

**Gauss:** write the zero branch with `logspace_add` and test the objective against an R mixture at
fixed parameters before any recovery run. **Curie:** a recovery test must state its bars before the
run and report misses as misses. **Boole:** an identifiability rule belongs in the constructor's
refusal, not in a footnote. **Ada:** a stalled scout is a two-hour cost; give scouts a tool budget
and an incremental-write rule from the start.

## 11. Limitations and next action

- Register rows are `partial`: single-seed recovery, no intervals on `zi`, no coverage evidence.
- Not built (later decisions): covariates or random effects on the zero part; VA/AGHQ/MSPL routes;
  cumulative-logit ordinal, `select_lv()`, LRT/`anova`, `ordination_uncertainty()` (B3 issues 2–4).
- 🔴 New TMB likelihoods are HIGH-RISK: maintainer sign-off before merge (draft PR, stacked on #1239).
- Next: multi-seed recovery on Totoro (pre-run ≤ 30 min) then a DRAC job array, compared with the
  GLLVM.jl ADEMP campaign, before any row moves from `partial`.
