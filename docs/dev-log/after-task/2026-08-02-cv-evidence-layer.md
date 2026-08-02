# After-task — held-out CV evidence layer, canonical fixture, block-conditional recovery (2026-08-02)

## 1. Goal

Build the first three items from the HMSC cross-package scout
(`docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`): a held-out
cross-validation layer with per-family predictive metrics, a canonical known-truth fixture, and
block-conditional recovery tests. **Internal only — no new export, no public predictive claim.**

## 2. Implemented

Eight new files, 2,320 lines, on `claude/evidence-cv-20260802` in a worktree cut from
`origin/main` @ `d58552e8`. Nothing existing was modified.

- `R/cv-internal.R` — `.cv_check_cv_supported()`, `.cv_make_folds()`, `.cv_mask_response()`,
  `.cv_run()`, `.cv_baselines()` + helpers.
- `R/cv-metrics.R` — `.cv_join_truth()`, `.cv_score()`, `.cv_logscore()`.
- `R/data-cv-fixture.R`, `data-raw/cv-fixture.R`, `inst/extdata/cv-fixture.rds` — known-truth
  fixture, 50 sites × 10 species × **5 traits**, d = 2, 1,865 rows, in four family variants
  sharing one linear predictor.
- `dev/cv-evidence.R` — evidence harness with an honesty fence printed on every run and
  `preflight`/`smoke`/`task`/`summarise` CLI modes (SLURM `--task-id` hooks retained).
- `tests/testthat/test-cv-internal.R`, `tests/testthat/test-block-conditional-recovery.R`.

**Mechanism (nothing new in the engine).** Held-out cells are set to `NA` and the model refit with
`miss_control(response = "include")`, which gates those rows out of the likelihood via
`is_y_observed`; `predict_missing()` then predicts them. Both primitives already existed and were
already tested.

**Evidence produced.** 12 cells (4 families × 3 seeds, 5 folds each) in 162.6 s. **60 folds
attempted, 54 scored, 6 excluded as `degenerate`** (non-PD sdreport: gaussian 4, nbinom2 2).
Per-family scored rows are therefore **unequal**: gaussian 55, nbinom2 65, poisson 75, binomial 75.
A cell's top-level `status` is `"ok"` when *any* fold succeeds, so "12/12 ok" is **not** the same as
"all folds scored" — an earlier draft of this report made exactly that error.

| family | folds scored | beats trait-null | beats stacked-SDM null | median Δ vs trait-null | vs env-null |
|---|---|---|---|---|---|
| gaussian | 11/15 | 100.0% | 100.0% | +68.1 | +46.3 |
| poisson | 15/15 | 98.7% | 97.3% | +29.4 | +16.2 |
| nbinom2 | 13/15 | 100.0% | 78.5% | +13.6 | +4.9 |
| binomial | 15/15 | 66.7% | 40.0% | +0.8 | −0.2 |

Excluded folds are **not** systematically worse (gaussian mean LogScore −309.4 degenerate vs −310.3
scored; nbinom2 −968.6 vs −962.6), and a manual refit of a degenerate gaussian fold gave Δ vs
null_trait = +347.2 against +368.3 for a scored fold — direction unchanged. So the exclusions bias
the *denominator*, not the sign.

### What these numbers do NOT show — three caveats that bound the claim

Established by adversarial verification, and load-bearing:

1. **The deltas measure a site×trait random effect, not the d = 2 ordination — now MEASURED, not
   just suspected.** `simulate_site_trait()` builds η_sit = α_t + x_s′β_t + u_st with **no species
   term**, and this fixture uses `sigma2_eps = 1e-6`, so within a (site, trait) cell the linear
   predictor is constant across species with a median of **8 near-exact replicates** (range 3–10).
   The third null (`null_diag` = `~ 0 + trait + indep(0 + trait | site)`, a per-trait **diagonal**
   site effect with no cross-trait covariance) was built and the full grid re-run. Result:

   | family | Δ vs trait-null | Δ vs stacked-SDM null | **Δ vs DIAGONAL null** |
   |---|---|---|---|
   | gaussian | +68.14 (100%) | +46.30 (100%) | **+0.26 (65%)** |
   | poisson | +29.42 (99%) | +16.24 (97%) | **+0.51 (64%)** |
   | nbinom2 | +13.63 (100%) | +4.93 (78%) | **+1.05 (69%)** |
   | binomial | +0.77 (67%) | −0.21 (40%) | **+0.38 (55%)** |

   **The cross-trait covariance ΛΛᵀ buys essentially nothing on this DGP.** The entire apparent
   advantage was "the model has a site random effect at all". Fractions positive fall to 0.55–0.69,
   barely above a coin flip.

   **Why, and what it implies for the fixture design.** The DGP *does* carry cross-trait structure
   (`Lambda_B`, `psi_B`), so this is not an absence of signal — it is that with ~8 species
   replicating each (site, trait) cell, the site×trait effect is already pinned by the replicates,
   so there is nothing left for cross-trait borrowing to contribute. **Borrowing strength across
   traits should only pay when per-cell replication is low.** A fixture with ~1 species per site
   would be the design that can actually detect an ordination benefit, and is the recommended next
   step. Until then, **no claim should be made about what the latent ordination buys.**
2. **The binomial row is confounded and must not be read as "latent doesn't help for binary".**
   For single-trial Bernoulli the package maps `theta_diag_B`/`s_B` **off**, so the binomial "latent
   model" fits Σ_B = ΛΛᵀ (rank 2, no Ψ, 14 free parameters) while the others fit ΛΛᵀ + diag(ψ)
   (gaussian 20, poisson 19, nbinom2 24). The DGP sets ψ_B = 0.3 on every trait — which the
   binomial model **structurally cannot represent**. That row mixes misspecification with Bernoulli
   information loss. An earlier draft of this report cited it as reproducing the Norberg et al.
   2019 / Zurell et al. 2020 pattern; **that reading is withdrawn** — it is not a clean test.
3. **The quantity is conditional on co-observed cells.** The main model's density is conditional on
   site modes informed by the other ~7 observed species at that site; the nulls have no latent
   layer. Δ is therefore a conditional-vs-marginal comparison, not two comparable conditionals.

Binomial AUC: pooled per-fold 0.575–0.666 across all 15 folds; **no orientation bug**. The
per-trait range 0.389–0.771 reflects n ≈ 74 per cell (SE ≈ 0.068), so per-trait AUC should be
reported with n rather than as a bare range.

## 3a. Decisions and Rejected Alternatives

- **Fresh worktree off `origin/main`.** The main checkout sits on a branch **639 commits behind**
  main with a parked stash; codex and cursor lanes are live. Rejected: working in place.
- **Internal + `dev/` only.** Avoids AGENTS.md's six-item Definition of Done for new exports and
  the validation-debt register row (both gate on *advertised* capability). The check-log entry is
  **not** exempt (Design Rule 7) and was written. Rejected: shipping `cv_gllvmTMB()` now.
- **Cell-wise folds only; site-wise and marginalisation deferred.** `predict()` returns the
  predictor at empirical-Bayes **modes**, so a masked site would give g⁻¹(x′β), not a marginal.
  Integrating `rr_B` alone would not fix it — η also carries `s_B`, `p_phy`, `Lambda_W`,
  `Lambda_spde`, `Lambda_phy`. Rejected: calling site-wise folds "marginal prediction".
- **Fixture moved 3 → 5 traits.** See §9.
- **Stacked-SDM null instead of the planned "per-species intercept-only".** In this stacked-trait
  layout the latter collapses to `~ 0 + trait`. The env-but-no-latent null is the comparison the
  JSDM benchmark literature actually scores against.
- **A THIRD null was added mid-flight — adaptive deviation, not drift.** The approved plan specified
  two nulls. Adversarial verification then showed that both are dominated by "the model has a site
  random effect at all", because this DGP carries no species term. `.cv_null_formula_diag()` adds
  `value ~ 0 + trait + indep(0 + trait | site)` — a per-trait **diagonal** site effect with no
  cross-trait covariance — and `dLogScore_vs_null_diag`. **Only this delta isolates what ΛΛᵀ
  buys.** Without it the headline number is close to tautological, so the scope change was
  necessary rather than optional; it is recorded here for plan-vs-actual reconciliation.
- **Grid run locally, not on Totoro.** The compute question was asked at scope time, as doctrine
  requires. Totoro was checked and is live (384 cores, idle, no Duo needed), but the grid runs in
  **162.6 s**; deploying a TMB toolchain there would cost more than it saves. D-50 is respected
  either way: results are LOCAL and nothing ran on GitHub Actions. A materially larger sweep (e.g.
  50 seeds) would flip this call.

## 4. Files Touched

Created (all new, all untracked before commit):
`R/cv-internal.R`, `R/cv-metrics.R`, `R/data-cv-fixture.R`, `data-raw/cv-fixture.R`,
`inst/extdata/cv-fixture.rds`, `dev/cv-evidence.R`,
`tests/testthat/test-cv-internal.R`, `tests/testthat/test-block-conditional-recovery.R`,
`docs/dev-log/after-task/2026-08-02-cv-evidence-layer.md` (this file), plus a `check-log.md` entry.

Modified: **none.** `devtools::document()` incidentally added a trailing newline to
`man/plot_anisotropy.Rd`; that is unrelated churn on another lane's file and was reverted.

## 5. Checks Run

| Check | Result |
|---|---|
| `devtools::document()` | OK; **NAMESPACE unchanged**, no new `man/` page (no `@export` anywhere) |
| `test-cv-internal.R` (heavy) | 119 expectations, **0 failures** |
| `test-block-conditional-recovery.R` (heavy) | 11 expectations, **0 failures**, ~15 s |
| `test-missing-response-gaussian.R` (the foundation gate) | 42 expectations, 0 failures, 1 documented warning |
| Evidence grid | 12 cells, **60 folds attempted / 54 scored / 6 degenerate**, 162.6 s |
| Smoke before grid | green after two defects were fixed (§9) |
| Parse check, all new R files | OK |
| **Adversarial verification** (fresh Opus, independent) | 3 defects + 1 blocking mis-report found; 4 items VERIFIED; verdict **safe as internal evidence with the three §2 caveats** |
| Independent metric recomputation | brute-force pairwise AUC 0.6537532 = Mann–Whitney 0.6537532 = harness 0.6537532; Brier 0.2331902 matches; `sum(dbinom(y, 1, p, log = TRUE))` = −245.8839 = harness LogScore |
| Full `devtools::test()` | **359 files, 8,611 pass, 0 fail, 0 error, 795 skipped** — green |

## 6. Tests of the Tests

Evidence the assertions can actually fail:

- **Block-conditional negative control** — fixing `theta_rr_B` at zero instead of truth produces an
  nll gap of **215** against a required minimum of 5, proving `map` binds and the design has power.
  Margins are not knife-edge (max abs error 0.078 vs tolerance 0.15; relative Frobenius 0.206 vs
  0.40).
- **The fold guard fired on a real defect** — it rejected every fold of the original 3-trait/d=2
  fixture as `degenerate`. The guard was right and the fixture was wrong (§9). A guard that has
  caught a genuine problem is not inert.
- **The smoke caught its own harness bug** — `n_folds = 1` holds out every cell; the guard refused
  it rather than returning a broken partition.
- **The fold-balance assertion failed and was left failing** by its author rather than weakened;
  the root cause was then fixed in the code (§9).
- **Truth-source regression test** — fits on masked data, confirms the sentinel really is 0 inside
  the fit, then asserts the joined truth is the pre-mask value. It fails if anyone rewires the
  scorer to read `fit$tmb_data$y`.

## 7a. Issue Ledger

- **[#800](https://github.com/itchyshin/gllvmTMB/issues/800)** — materially advanced, not edited.
  Its "the latent-variable comparison has to be built" verdict now has a built artifact: a
  known-truth fixture plus block-conditional recovery tests. Whether to post this is the
  maintainer's call.
- No issue opened or closed. No PR opened.

## 8. Consistency Audit

- No `@export` in any new file; NAMESPACE byte-identical; `dev/` and `data-raw/` are
  `.Rbuildignore`d (`:21-22`), so the added package surface is two internal `R/` files, one cached
  `.rds`, and two test files.
- No file owned by the codex or cursor lanes was touched; `capability-surface.html` untouched; the
  parked profile stash untouched. All six planned paths were confirmed collision-free across every
  branch before work started.
- The reported quantity is named identically in the code (`meta$quantity`), the harness fence, the
  roxygen, and this report: **conditional plug-in log predictive density** — not lppd, not marginal.

## 9. What Did Not Go Smoothly

Three adversarial review rounds ran on the plan before any code, and **each found blocking defects
in the previous round's fixes.**

1. **v1** — the truth-source trap (masked cells carry a sentinel zero; a scorer reading
   `fit$tmb_data$y` would score every held-out cell against 0 and produce plausible, meaningless
   numbers), and the false claim that site-wise folds give marginal predictions.
2. **v2** — my own fix was wrong twice over. I proposed joining truth on `model_row`, which indexes
   a stacked frame a wide-format caller never holds; and I proposed a sentinel-invariance test that
   was **tautological** — `is_y_observed` is *derived from* the NA pattern, so "fill with two
   different values, then NA them" yields two byte-identical data frames. The correct test already
   existed in the repo.
3. **Implementation** — the fixture's first cut generated non-Gaussian variants as *deterministic
   transforms* of the Gaussian draw (binomial hard-thresholded at the mean). Held-out AUC would
   have been ≈1 by construction and the cached truth would not have described three of four
   variants.
4. **The 3-trait fixture was over-parameterised.** With ordinary `latent()` carrying a diagonal Ψ,
   Σ = ΛΛᵀ + diag(ψ) needs `T·d − d(d−1)/2 + T` free parameters against `T(T+1)/2` unique entries:
   T=3, d=2 → **8 vs 6**. Models converged but the Hessian was not PD and every fold was rejected.
   Moved to 5 traits (14 vs 15). The arithmetic is now documented in `R/data-cv-fixture.R`.
   *Related:* this also explains why binomial appeared fine at T=3 while gaussian did not — for
   single-trial Bernoulli the package maps the diagonal Ψ **off**, dropping the count to 5 ≤ 6.
5. **Fold sizes were systematically imbalanced** (213/213/213/213/210). `sample()` permutes which
   cell gets which label but not the label *frequencies*, so with equal per-trait row counts the
   same low-index folds absorbed the remainder on every trait's deal and the imbalance compounded.
   Fixed by carrying the round-robin offset across traits.
6. Minor: a `byrue`/`byrow` typo of mine, and a `rm` in a command that tripped the permission gate.

**The through-line:** every failure mode in this arc was of the same kind — something that would
have produced *confident, plausible, wrong numbers*. None would have been caught by "does it run".

## 10. Known Residuals

- **`rcmdcheck(args = "--as-cran")` has NOT been run.** Release-cleanliness is not claimed.
  (`devtools::test()` is green — 359 files, 8,611 pass, 0 fail — but that is the fast suite; the
  heavy-gated tests are among the 795 skips, and were run separately per file.)
- **Roxygen coverage of internals is partial** — `R/cv-internal.R` has 13 top-level functions and
  5 documented blocks; `R/cv-metrics.R` 7 and 3. Legal (undocumented internals need no `man/`
  page) but short of the house convention that internals still carry
  `@param`/`@return`/`@keywords internal`/`@noRd`.
- **The third null is not built.** A diagonal `indep(0 + trait | site)` baseline is required before
  any statement about what the *latent ordination* buys, because this DGP has no species term (§2
  caveat 1). Until it exists, the deltas are evidence for a site random effect only. **This is the
  single most important follow-up.**
- **Asymmetric degeneracy guard** — `.cv_run()` applies the non-PD check to the main model only
  (`R/cv-internal.R:653`); the nulls are filtered on `opt$convergence == 0` alone (`:496-503`).
  Verification found the nulls non-degenerate in the folds it refit, so no manifest bias, but the
  asymmetry should be symmetrised or stated in-code.
- **`.cv_score_one()` uses `sum(ls, na.rm = TRUE)` with `n = nrow(sub)`** rather than the non-NA
  count (`R/cv-metrics.R:297`). With 0 NAs across all 270 stored rows this is not manifest, but an
  NA mismatch would silently sum different row sets between model and null.
- **The identification margin is thin** — T=5, d=2 gives 14 free vs 15 unique, and 6/60 folds still
  went non-PD even though the full-data fit is PD. A larger trait count would give more slack.
- **`.cv_run()` is long-format only** (aborts on wide input, `R/cv-internal.R:598`). The wide
  `(original_row, trait)` join key is correct by construction and was demonstrated on a real wide
  fit, but it is not exercised end-to-end by `.cv_run()`.
- **Site-wise folds, MC marginalisation, and conditional (Schur-complement) prediction are
  deferred**, fenced in the plan and in the harness scope block.
- **`n_trials` is fixed at 1** in `.cv_join_truth()`; genuine multi-trial (`cbind(succ, fail)` /
  `weights =`) counts cannot be reconstructed from the fitted object. Out of scope, documented.
- The plan's verification item "extend the sentinel-invariance construction to a whole-unit mask"
  was **not** done — whole-unit masking is site-wise CV, which Decision 3 defers. Cell-wise CV is
  covered by the existing gate plus the truth-source regression test. Recorded rather than quietly
  dropped.
- **Nothing is committed or pushed.** The worktree holds the arc; landing it is the maintainer's
  call.

## 11. Team Learning

- **Memory receipt.** Recalled before scouting: brain `search_notes(search_all_projects = true)`
  surfaced `DR3-gllvm-jsdm-2026-07-01` and the 2026-07-28 Bolker note, which changed the shape of
  the task (the landscape was already on file, so the scout aimed at package internals instead).
  The prior-work sweep then found that **two of the three items were largely already built** —
  `miss_control(response = "include")` + `predict_missing()` are the CV primitive, and
  `simulate_site_trait()` already provides a parameterised known-truth DGP used in 91 test files.
  Without the sweep this arc would have rebuilt both.
- **The reusable technique:** for "add capability X", the expensive, non-duplicable step is reading
  the target repo's *tests and fixtures*, not its documentation. Both genuinely new ideas here —
  block-conditional recovery, and the discipline of caching data + truth rather than fitted objects
  — came from reading `Hmsc`'s test directory and this package's own fixture module.
- **A guard that fires is worth more than a guard that passes.** The sdreport PD check earned its
  keep by rejecting our own fixture design, and the fold-balance assertion earned its keep by
  failing. Both were left failing rather than weakened, which is why they were useful.
- **Line numbers from a stale checkout are a trap.** The plan was written against a checkout 639
  commits behind main; every *fact* held on current main but every *citation* had moved. Re-verify
  citations in the worktree, not the checkout you planned in.

## 12. Cross-Product Coverage

- **gllvmTMB** — primary target.
- **GLLVM.jl** — the capability gap (no held-out predictive evaluation) is engine-agnostic and
  applies to the twin. Not surveyed here.
- **drmTMB / hsquared** — the block-conditional recovery pattern generalises to any TMB model with
  separable parameter blocks and is a candidate for both. The `map = factor(rep(NA, n))` mechanism
  is TMB-level, not gllvmTMB-specific.
- **Vault** — cross-team note filed at `memory/HMSC scout (2026-07-29) …` and committed; this arc's
  outcome should be appended there so the next session recalls rather than re-scouts.
