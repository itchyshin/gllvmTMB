# Recon: existing coverage/interval machinery for the VA coverage campaign

**Read-only recon. No code changed.** Worktree `/private/tmp/gllvmtmb-va-lane2`
(branch `claude/va-lane2`). Every claim below is `grep`/`Read`-verified with
file:line; items not found list the search tried.

## 1. Existing coverage/simulation harnesses

### `coverage_study()` — `R/coverage-study.R:1-372`
- **Status: withdrawn internal prototype** (line 1: "Withdrawn internal
  prototype (2026-07-23)"; `@noRd`, not exported). Docs explicitly forbid
  treating it as evidence of calibration (lines 3-6, citing Design 75).
- **What it does** (function body `:123-342`): for a `gllvmTMB_multi` fit,
  simulates `n_reps` parametric-bootstrap response datasets via
  `stats::simulate(fit, nsim = n_reps)` (line 184), refits the *same formula*
  via `.reconstruct_multi_formula()` (defined `R/bootstrap-sigma.R:16-30`),
  computes CIs per requested `methods` (`c("wald","profile")`, line 127) via
  `stats::confint()` on the refit, and scores whether the interval covers the
  **original fit's own point estimate** (not an external ground truth) —
  i.e. it is a parametric-bootstrap *self-consistency* check, not a recovery
  study against a planted truth.
- **Scoring**: `.ci_covers()` (`:22-27`) requires both bounds finite (an
  `is.finite()` guard added specifically because `(-Inf, Inf)` used to score
  100% coverage, per the comment at `:17-21` — a documented past bug).
  Non-finite bounds are excluded from the denominator (`n_excluded`, `:310`),
  and failed refits are excluded entirely (`n_failed`, tracked but not in the
  coverage denominator) — this exclusion is *why* the docstring at `:41-44`
  says it cannot certify calibration.
- **Seeds**: single `seed` arg, `set.seed()` once before generating all
  `n_reps` sim datasets from one RNG stream (`:178-180`) — not a
  multi-seed/parallel design.
- **Parallelism: none.** Straight `for` loop (`:203-270`), one refit at a
  time, no `future`/`parallel`/`mclapply`.
- **Not usable for VA**: it dispatches through `stats::confint()`
  (`S3::confint.gllvmTMB_multi`), and gates on `inherits(fit,
  "gllvmTMB_multi")` (`:132-134`) — a VA fit is classed `gllvmTMB_va`
  (`R/va-routing.R:432`, confirmed in §3 below), so this harness rejects VA
  fits outright, by construction, before any campaign-specific work would be
  needed.

### `bootstrap_Sigma()` — `R/bootstrap-sigma.R` (full file; header `:1-5`)
- Percentile-bootstrap CIs for `Sigma_unit`/`Sigma_unit_obs`/correlations/
  communality/ICC. Same simulate-refit-extract pattern as `coverage_study()`
  but scores **interval width/percentile bounds**, not coverage against a
  truth — it is the CI-production route `coverage_study()` audits, not itself
  a coverage-measurement harness.
- **Does parallelise**: docstring `:75-79` — "Multicore is dispatched via
  `future` + `future.apply`; pass `n_cores >= 2`" with L'Ecuyer-CMRG seed
  streams for reproducibility (not bit-identical across core counts).
- Same structural blocker for VA: built for `gllvmTMB_multi`-classed fits
  refit via `gllvmTMB()`/`.reconstruct_multi_formula()`, not the VA route.

### `dev/cross-family-coverage.R` — full multi-seed coverage-certification harness
- **This is the closest existing template for a real campaign.** Header
  (`:1-25`) states it explicitly: "self-contained, multi-seed
  coverage-CERTIFICATION harness ... against an ANALYTICALLY-KNOWN truth" —
  i.e. planted-truth recovery, not self-consistency.
- Driven by env vars + CLI flags for sharded, seeded runs:
  `XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=pilot
  --shard=$SLURM_ARRAY_TASK_ID --n-shards=100 --n-sim=200
  --seed-base=20260718` (`:26-28`) — this is a ready-made **Totoro/DRAC
  shard-and-aggregate pattern** (one shard per array task, seed-base offset).
  A `xfc_smoke()` in-process smoke entry point also exists (`:29-30`).
- Every number it produces is banner-tagged `XFC_BANNER <- "MEASURED, NOT
  certified -- awaiting D-43 panel"` (`:32`) — the house discipline for an
  opt-in, unpromoted campaign. **This is the pattern the VA campaign should
  copy verbatim** (banner string + D-43 panel gate before any promotion).
- `.xfc_can_redraw()` (`:47-53`) is a reusable gate-check pattern: it looks
  up an internal package function (`.check_simulate_unconditional`) via
  `getFromNamespace`, robust to `load_all()` vs installed — worth reusing to
  gate the VA campaign on whatever VA-analogous redraw check exists.

### `dev/aghq-evidence/24-coverage-cell.R` and `25-coverage-fixedtruth.R`
- **The most directly reusable driver skeleton for a Totoro run.** Both are
  self-contained scripts (no package `source()` beyond
  `library(gllvmTMB)`/`library(parallel)` + a sourced SE-delta helper) that:
  - read `CV_CORES`/`CV_SEEDS`/library path from env vars (`:34-38` in both
    files — `AGHQ_LIB`, `CV_OUT`, `CV_CORES` default 140, `CV_SEEDS` default
    200),
  - define a `mk()` data-generating function that plants a known `Lambda`/
    latent structure and simulates response data (`:40-47` in `24-...R`),
  - dispatch across seeds with `parallel::mclapply` at up to 140 cores (fits
    within the stated <=100-core Totoro budget if `CV_CORES` is turned down).
  - **`25-coverage-fixedtruth.R` is a bug-fix iteration on `24-...R`**: its
    header (`:47-51`) documents that `24-...R` redrew `Lambda` fresh every
    seed, which "makes the reported coverage a quantity marginalised over a
    Gaussian prior on Lambda" — exactly Failure Mode 1 (favourable/confounded
    DGP) in the campaign brief. `25-...R` fixes `Lambda` once per truth id
    and only resamples data per seed. **Use `25-...R`'s fixed-truth pattern,
    not `24-...R`'s, as the DGP template** — it is a documented instance of
    the same class of bug the VA brief warns against.
  - Both report coverage **conditional on an available interval**, with
    availability rate printed alongside (comment block `:26-30` in both) —
    i.e. they already implement the "three distinct events: no fit; fit but
    no SE; fit with SE" discipline the campaign brief needs for VA (which
    frequently has `pdHess = FALSE` or no calibrated SE at all).
  - Both validate their own SE instrument via empirical SE/SD-across-seeds
    before trusting any coverage number (comment `:20-25`) — a check the VA
    campaign should replicate, since a VA Schur-complement SE could be wrong
    in the same "measuring the Jacobian, not the engine" way.

## 2. What is already settled (do not re-measure)

Summarized from `docs/design/35-validation-debt-register.md` rows CI-08/CI-10/
CI-11 (line refs below) — this is **Laplace-engine** evidence; nothing here
certifies VA.

- **CI-08** (`:411`, ~120 lines of addenda) — `coverage_study()`'s own
  ≥94% gate: **`partial`, most cells below gate.** Only Gaussian d=1/d=3
  cleared in the original M3.3 grid (13/15 cells failed, 236/3000 refits
  failed). A separate, later `profile_total` route (NOT `coverage_study()`,
  the exported `.profile_ci_total_variance()`) cleared a pre-registered
  ≥0.94 gate for gaussian d=1/d=2 at n=150 (0.9467/0.9467, D-43 3-0 CERTIFY),
  but **scope-fenced**: two-sided only, marginal average, conditional on
  convergence, floor 0.94 **never nominal 0.95**, and the psi target (as
  opposed to `Sigma_unit_diag`) **fails** on the same run (0.9384/0.8653).
  CLAUDE.md's live snapshot additionally records the 2026-07-19 Bartlett
  re-score: opt-in Bartlett-corrected χ²₁ crit lifted gaussian
  `Sigma_unit_diag` n≥150 coverage to 0.9486-0.9529 — still **WITHHELD**,
  D-43 unanimous, because all four 2·MCSE lower bands are <0.95.
- **CI-10** (`:413`) — mixed-family intervals: `blocked` (profile) /
  `partial` (Wald/bootstrap calibration). Former mixed-family profile
  prototype withdrawn after failing its own gate.
- **CI-11** (`:414`) — internal profile route matrix / refusal ledger:
  `covered`, but explicitly **"not interval calibration"** — it only
  certifies that the typed-refusal policy table matches behavior.
- **Net takeaway for this campaign**: gllvmTMB has **zero** certificate that
  reaches nominal 0.95 for any Sigma-type target on the shipped Laplace
  engine, and its best certified route (`.profile_ci_total_variance()`) is
  unexported-then-fenced, two-sided-only, and floor-gated at 0.94. The VA
  campaign should not implicitly benchmark against "0.95 achieved elsewhere
  in this package" — it hasn't been, anywhere, yet.

## 3. Existing interval machinery for the shipped (Laplace) engine

- **`confint.gllvmTMB_multi()`** — `R/z-confint-gllvmTMB.R:1551` (definition),
  three-method API documented `:6-11`: `method = "profile"` (default, via
  `TMB::tmbprofile()` + `uniroot`, `R/profile-ci.R`), `"wald"` (from
  `sd_report`), `"bootstrap"` (via `bootstrap_Sigma()`). Dispatch table for
  parm classes at `:13-24` (Sigma-type tokens, `Lambda`/`Lambda:i,j`, derived
  summaries `icc`/`phylo_signal`/`communality:*`/etc., plain fixed effects).
- **`loading_ci()`** — `R/loading-ci.R:1-40+`. Per-entry Wald CI on raw or
  standardized loadings via delta method: numerical Jacobian
  `J = ∂vec(Λ)/∂theta` (or `∂vec(rho)/∂theta`) combined with
  `fit$sd_report$cov.fixed` (the TMB Hessian-based covariance) — **the same
  algebraic family as the Schur-complement idea in the VA brief**, but here
  applied to the *full* fixed covariance rather than a fixed-block Schur
  complement, and explicitly **confirmatory-fits-only** (rotation must be
  pinned by a `lambda_constraint`, `:29-36`).
- **`confint.gllvmTMB_va()`** — `R/va-methods.R:184` — **errors by design**:
  "calibrated = FALSE: the inverse variational Hessian is not calibrated
  frequentist uncertainty" (per task brief; file confirmed to exist and
  contain the VA confint entry point at this line).
- **Validation status**: none of `profile`/`wald`/`bootstrap` for the
  Laplace engine has a clean 0.95 certificate (§2). `loading_ci()`'s own
  calibration is not addressed by CI-08/CI-10/CI-11 at all — PR #924 (per
  `docs/design/va-conditioning-audit-vs-gllvm.md:316-354`) touched
  `loading_ci`/`loading-ci-bootstrap`/etc. for a standardized-loading
  inference fix but that PR's scope is disjoint from VA (confirmed there:
  zero `R/va-r3-proto.R`/`R/approximation-engine.R`/`R/va-routing.R`
  touches, zero "variational"/"va_r3" grep hits in its 6 changed R files).
- **`.va_r3_fixed_information_blocked()`** (per task brief,
  `R/va-r3-proto.R` ~1463-1471) is present and unit-tested per the task
  brief but was not independently re-read in this pass — not needed for the
  recon question (it is the mechanism, not a coverage harness).

## 4. Cheapest existing script to adapt as the campaign driver

**`dev/aghq-evidence/25-coverage-fixedtruth.R`** is the best starting point:

- fixed-truth DGP already avoids Failure Mode 1 (favourable/confounded DGP);
- already implements the three-way fit-outcome accounting (no fit / fit,
  no SE / fit with SE) needed for VA's `calibrated = FALSE` refusal path;
- already implements an SE/SD self-validation check before trusting any
  coverage number — directly transferable to auditing whether
  `.va_r3_fixed_information_blocked()`'s Schur-complement SE matches the
  empirical across-seed SD (the oracle-floor style check Failure Mode 2
  demands);
- already parallelises via `parallel::mclapply` with an env-var core count,
  fits the `<=100 cores` Totoro constraint by lowering `CV_CORES`;
- would need, for this campaign specifically: (a) a second arm that fits via
  the VA route and pulls the Schur-complement SE instead of
  `stats::confint()`'s Laplace routes, (b) a model-mismatch guard so the
  gllvm-side comparator (if run) is fit to the same `unique = FALSE` model
  per the brief's Failure Mode 2, and (c) both `rel_frob` **and** a
  variance/psi-recovery metric per replicate, per Failure Mode 3.

`dev/cross-family-coverage.R`'s sharded CLI (`--mode=pilot --shard=N
--n-shards=100 --seed-base=...`) is the better template if the campaign
needs SLURM-array-style sharding across more than one Totoro batch; its
`XFC_BANNER` unpromoted-evidence string is worth copying verbatim into
whatever script is chosen.

## Searches tried that found nothing relevant

- `grep -rn "gllvm_work\|va-lane2" dev/` for an already-deployed VA-specific
  coverage script under `dev/` — no VA-specific coverage driver exists yet;
  the closest analogues are the AGHQ/cross-family scripts cited above.
- No `dev/va-speed/*coverage*` file exists (only conditioning/speed research
  notes, e.g. `dev/va-speed/21-WHY-GLLVM-IS-FAST.md`, cited in
  `docs/design/va-conditioning-audit-vs-gllvm.md`).
