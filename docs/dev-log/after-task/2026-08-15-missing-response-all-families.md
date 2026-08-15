# After Task: Missing responses for ALL distributions + first predict_missing() accuracy evidence

**Branch**: `claude/missing-all-families-20260815`
**Date**: `2026-08-15`
**Roles (engaged)**: `Ada (orchestration) / Curie (simulation) / r-package-engineer (tests) / Rose (close) / Melissa (reconcile)`

## 1. Goal

Shinichi (2026-08-15): *"We want to have all distributions and responses =
include missing responses."* Triggered by Montoya et al. 2026 (bioRxiv
2026.05.27.728209, "P3CA" — phylogenetic probabilistic PCA whose EM imputes
missing trait values, validated against Rphylopars on imputation MSE).
Outcome-first arc: every admitted family carries retained per-family
missing-response evidence (Laplace + VA), plus the first accuracy evidence for
`predict_missing()` and a fenced comparator study. Plan:
`~/.claude/plans/immutable-finding-cosmos.md`.

## 2. Implemented

1. **Multinomial NA admission** (the one family that hard-refused masked
   responses). `expand_multinomial_response()` no longer aborts on NA
   categorical values: an NA propagates NA into all K−1 one-hot indicator
   rows, so the standard response-missingness machinery masks ("include") or
   removes ("drop") the contrast group as one unit — group-uniform by
   construction, which is precisely the invariant the C++ anchor gate
   (`is_anchor && is_y_observed`, src/gllvmTMB.cpp) requires. No `src/`
   change was needed: the likelihood gate was mask-ready all along.
2. **Tier-3b equivalence sweep** in
   `tests/testthat/test-missing-response-nongaussian.R`: the include==drop +
   sentinel contract extended from {poisson, nbinom2, binomial} to
   lognormal, Gamma, nbinom1, tweedie, Beta, student, truncated_poisson,
   truncated_nbinom2, delta_lognormal, delta_gamma, ordinal_probit, and
   betabinomial (cbind two-column response). With the pre-existing gaussian
   files and the new multinomial test, **all 17 admitted families now have
   retained masked-response evidence under Laplace**.
3. **First-ever masked-cell accuracy evidence** (Design 70 §E.2 target S1 —
   previously "no code, no runs"): `dev/missing-accuracy-*.R`,
   `dev/missing-accuracy/arc0-cells.csv` + `RESULTS.md`.
4. **VA arm**: `tests/testthat/test-va-missing-response.R` parametrised
   across the scalar-VA cells (see §4; child-slice report).
5. **Comparator harness** (`dev/missing-accuracy-rung1-phylo-h2h.R`):
   gllvmTMB (`phylo_latent`, primary `unique = TRUE` + labelled
   misspecified-lean) vs `p3ca_reimpl` vs Rphylopars — PRE-RUN ONLY;
   the full grid is D-139-gated on Shinichi (G2).

## 3. Files Changed

- `R/gllvmTMB.R` — two NA-refusal sites in `expand_multinomial_response()`
  replaced with NA-propagation (comments document the group-uniform contract).
- `tests/testthat/test-multinomial-missing-response.R` — NEW.
- `tests/testthat/test-missing-response-nongaussian.R` — Tier-3b block.
- `tests/testthat/test-va-missing-response.R` — scalar-cell parametrisation.
- `dev/missing-accuracy-dgp.R`, `dev/missing-accuracy-arc0-recovery.R`,
  `dev/missing-accuracy-rung1-phylo-h2h.R`, `dev/missing-accuracy/` — NEW.
- `dev/missing-allfam-recon-map.md` — S0 inventory (family registry, masked
  coverage, fit shapes).
- `docs/design/35-validation-debt-register.md` — (close slice) MIS/VA row
  updates.

## 3a. Decisions and Rejected Alternatives

- **Marginalisation, not imputation, stays the estimation mechanism.** P3CA's
  EM-imputation and our cell-wise drop are two routes to the same
  observed-data ML under MAR/ignorability; nothing to change in the engine.
- **Identity comparisons in Tier-3b band at 2e-2 (Sigma) and exclude
  boundary-collapsed `theta_diag_B`.** Measured basis: |ΔlogLik| ≤ 2.5e-6
  (mostly ~1e-9) across all eleven new families while Sigma wobbles
  5e-3..9e-3 in flat directions (nbinom1, tweedie, truncated_poisson) and
  ordinal's unique-tier log-SDs move 0.58 at ΔlogLik = 8e-9. The logLik
  equality IS the mask invariant; the identity band guards gross divergence.
- **Comparator provenance**: `p3ca()` is absent from CRAN mvMORPH 1.2.1,
  GitHub master, AND branch `Paola-devel` @ `321e6ea8` (v1.2.2, installed
  and checked) — the paper's Data Availability outruns the public code. Per
  the approved fallback ladder the P3CA arm is a **labelled
  reimplementation** of eqs 6–14 with a mandatory self-check against the
  analytical complete-data solution; it is never presented as the authors'
  code. Rejected: silently comparing against Rphylopars only.
- **ML matched across all comparator arms** (paper used REML) — matched
  estimators beat replicating their exact setting.
- Rejected: chasing P3CA's p≫n regime (3,669 traits) — out of scope by plan.

## 4. Checks Run

- `devtools::test(filter = "missing-response-nongaussian")` → **15 tests,
  74 assertions, 0 failures** (1 pre-existing binomial runaway warning on
  the original fixture, untouched).
- `devtools::test(filter = "multinomial-missing-response")` → 9/9 pass:
  group-uniform mask, accounting = 5 cells × (K−1), include==drop logLik
  1e-6 + par 1e-4, predict_missing finite.
- Regression over `missing-response|miss-control|multinomial|missing-data`
  filters → 493 assertions passing outside the VA file that a child slice
  was still editing mid-run (its own final state is reported separately).
- Arc-0 accuracy probe: **80/80 fits converged**, ~1 min wall (est. 18 min),
  reproducibility re-run bit-identical (seed 1201).
- VA arm final: `devtools::test(filter = "va-missing-response")` → **136
  assertions, 0 failures** — 18/18 scalar cells exact-sentinel-invariant
  (tolerance = 0 on fn/gr; masked `expected_loglik_by_obs` exactly 0) and
  admitted under a ~15% include-mask. `betabinomial_logit` and
  `delta_gamma_log` are health-gate-marginal (multi-start objective range
  2e-6..1e-5, finite gradients — dispersion polish fragility, not a masking
  defect), recorded in-test, not hidden.
- (Pending at write time: h2h pre-run self-check.)

## 5. Tests of the Tests

- The multinomial test was written BEFORE the fence lift and failed with the
  refusal message — the lift is proven by the same test flipping to green.
- Tier-3b tolerances were set from a measured per-family diagnostic
  (include-vs-drop |ΔlogLik|, Sigma and par diffs), not guessed; the
  diagnostic script is reproducible from the test helpers.
- Accuracy probe carries a must-beat baseline (trait-mean fill), a
  complete-data oracle upper bound, and a bit-reproducibility re-run.

## 6. Consistency Audit

- The capability board's structural row "missing responses — Laplace yes /
  VA PUBLIC PARTIAL" remains TRUE and now under-states Laplace evidence
  (family-wise, not just mechanism-wise). Register updates in the close
  slice keep vocabulary: testthat-backed rows may move toward `covered`;
  dev-script accuracy evidence lands `partial` (register rule: `covered`
  requires test assertions).
- The 2026-07-27 rescue branch `claude/lvb-modelA-extend` contains a
  smaller nbinom1-only extension of the same loop (NB2-style DGP, guards
  removed); this lane supersedes it — flagged so it is not revived on top.

## 7. Roadmap Tick

Design 59 Phase 1 ("the easy win") is now COMPLETE at family granularity
under Laplace. Design 70 §E.2 S1 moves from "no code, no runs" to first
numbers. DECISIONS.md 2026-08-01 ("finish missing data", #332 sequencing)
advanced.

## 7a. GitHub Issue Ledger

- No issue closures claimed in this slice. (PR to reference this report.)

## 8. What Did Not Go Smoothly

- Four initial Tier-3b failures were over-strict identity comparisons on
  flat/boundary directions, not mask defects — resolved by measurement
  (diagnostic sweep), documented in-file.
- mvMORPH source build initially failed on the missing `/opt/gfortran`
  toolchain; fixed with a scoped `R_MAKEVARS_USER` pointing FLIBS at
  Homebrew gcc — no persistent config change.
- `p3ca()` is not actually in the public mvMORPH despite the paper's Data
  Availability statement (checked three refs) — handled by the pre-approved
  fallback ladder.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **The gate-outside-family-dispatch design paid off exactly as intended**:
  extending "all families accept masked responses" cost tests, not engine
  code — and for the one refusing family the fix was deleting a fence, not
  writing a likelihood.
- **Measure before loosening**: the failing identity comparisons were
  diagnosed with a per-family numeric sweep first; the tolerances now cite
  their own evidence.
- **Verify comparator existence before promising a head-to-head** — a
  paper's availability claim is not a shipped function.

## 10. Known Limitations And Next Actions

- `predict_missing()` remains point-only (no SEs/intervals) — the predictor
  side (`imputed()`) ships EBLUP SEs; closing that asymmetry is a DEFERRED
  design packet, not built here.
- Accuracy evidence is dev-script (`partial`), gaussian+poisson, n=50×p=25,
  MCAR + two structured-MAR mechanisms; no MNAR arm, no interval claim.
- VA masked evidence stays fenced per VA-10 wording until the register
  slice lands; multinomial-VA does not exist (Design 110).
- The h2h full grid (6 cells × 10 seeds) awaits the G2 pre-run approval.
- MSPL still refuses masks by design (FIML-MSPL deferred; unchanged).
