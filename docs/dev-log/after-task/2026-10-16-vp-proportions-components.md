# After Task: VP() and extract_proportions() count every computable variance component (#1395, #1399)

**Branch**: `claude/b16-L1-vp-components` (red proof: `claude/b16-L1-vp-components-red-proof`)
**Date**: `2026-10-16`
**Roles (engaged)**: Emmy, Fisher, Gauss, Curie, Rose, Pat (each run as an independent review lens with adversarial verification)

## 1. Goal

Make the two variance-share functions count every active variance component they can compute, and say by name which ones they leave out. Before this change:

- `extract_proportions()` omitted the Gaussian residual $\sigma^2_\varepsilon$. A fit whose variance was 70-84% residual therefore reported `shared_unit = 1` (#1399).
- `VP()` silently dropped `(1 | group)` intercepts, cluster2, multi-kernel, spatial, temporal and slope tiers, then renormalised what was left (#1395).

## 2. Implemented

- **Residual in `extract_proportions()`.** The function now has a `residual` component: $\sigma^2_\varepsilon$ for every trait whose modal family is Gaussian (slot 1) or lognormal (slot 2 when both families are present). It is counted under either `link_residual` value. It is also counted when the engine fixed $\sigma_\varepsilon$ because a per-row diagonal term is present, since the fixed value still enters the likelihood. On the #1399 data the shares now equal `VP()`'s to 1e-8.
- **New `VP()` columns.**
  - `diag_cluster2` ($\psi_{c2}^2$).
  - One `kernel_<name>` column per tier of a multi-kernel fit (`rowSums(Lambda_kernel[, , r]^2)`), counted the same way as the single-kernel `phylo_rr` column.
  - One `re_int_<group>` column per `(1 | group)` term ($\sigma_k^2$, the same in every trait, because the intercept has no trait index; `src/gllvmTMB.cpp` 3462-3467).
  - On the #1395 data, `re_int_study` is 0.73-0.80, the largest component, as the issue expected.
- **Classed warnings for what is left out.** Both functions warn about every active component they do not partition, with classes `gllvmTMB_vp_component_omitted` / `gllvmTMB_proportions_component_omitted`. Both share the parent class `gllvmTMB_variance_component_omitted`. The warning names each component, and the `"omitted_components"` attribute repeats the names.
  - `VP()` leaves out four kinds of component:
    - random-slope terms, intercepts included, whose variance changes with the covariate;
    - response-column slopes and coefficients;
    - `meta_V()` sampling variance, which differs by observation;
    - spatial fields and temporal states. These have stationary per-trait variances, but converting them (SPDE scale; `extract_temporal()`) is not done here and stays a follow-up.
  - `extract_proportions()` additionally leaves out `(1 | group)`, propto and multi-kernel terms. The warning points to `VP()` for those.
  - Each warning carries a next step specific to the kind of tier it names. A slope-only `phylo_slope(x | g)` is labelled without an intercept, and a column slope points to `extract_Sigma(level = "column_slope")`.
- **Julia fits.** `VP()` refuses a Julia bridge fit with a classed `gllvmTMB_julia_gate` error. `main` failed there with an opaque "argument is of length zero", and an intermediate draft of this branch returned an empty matrix.
- **Interval machinery** (so intervals stay centred on the extractor's estimate):
  - The Wald reconstruction `.proportions_components_at()` reads `residual` from `report(par)$sigma_eps`.
  - `.proportion_target_fn()` now reads every parameter block through the TMB map (`obj$env$parList()`), so fixed and tied entries come back at full length. These include a binary trait's pinned Psi, the zero lower triangle of a diagonal `phylo_indep()` block, `indep(common = TRUE)` ties and `lambda_constraint` pins. Indexing the free vector by trait had read another trait's value whenever a block was partly fixed (pre-existing, found in review). A first attempt refused such fits instead, and review showed that this also refused fits whose targets had been exact.
  - $\sigma^2_\varepsilon$ always enters the denominator. A residual whose numerator is constant in $\theta$ follows the `link_residual` convention in both the Wald and the profile route: the estimate, method `"(unavailable)"`. That covers a structurally zero residual (non-Gaussian trait) and a fixed $\sigma_\varepsilon$.
  - `confint(parm = "proportion:residual")` is accepted.
  - The internal re-calls of `extract_proportions()` raise the omitted-component warning once per request.
- **Plot.** `plot(type = "variance")` labels and colours `Residual`.

## 3. Files Changed

- `R/output-methods.R`: `VP()` plus the shared helpers `.variance_share_residual_slots()`, `.variance_share_residual_per_trait()`, `.variance_share_kernel_tiers()`, `.variance_share_active_tiers()` and `.variance_share_warn_omitted()`. Roxygen prose updated.
- `R/extract-omega.R`: `extract_proportions()` body and roxygen prose. `@examples` not edited.
- `R/proportions-ci.R`: the Wald `residual` case and the warning de-duplication.
- `R/profile-derived.R`: the `.proportion_target_fn()` residual terms and the partly-fixed-block guard.
- `R/z-confint-gllvmTMB.R`: the `.proportion_components()` vocabulary and the `confint()` roxygen component list.
- `R/plot-gllvmTMB.R`: the `Residual` label and palette entry.
- `man/VP.Rd`, `man/extract_proportions.Rd`, `man/confint.gllvmTMB_multi.Rd`: regenerated by `devtools::document()`.
- `tests/testthat/test-vp-components-1395-1399.R`: new, 14 tests.
- `tests/testthat/test-profile-proportions.R`: its OLRE fixture's component set gains `residual`.
- `docs/dev-log/after-task/2026-10-16-vp-proportions-components.md`: this report.
- **Not edited:**
  - `NEWS.md`: the lane rule puts NEWS lines in the PR body.
  - `NAMESPACE`: `document()` with roxygen2 8.0.0 rewrites the three hand-edited `S3method(stats::sigma, …)` lines from #1407. That edit is unrelated, so it was left as it is.
  - `docs/dev-log/check-log.md`, `docs/design/35-validation-debt-register.md` (rows EXT-32, EXT-34) and `docs/design/06-extractors-contract.md`: shared files, kept out of a file-disjoint lane. They are follow-ups (§10).

## 3a. Decisions and Rejected Alternatives

- **Count a fixed $\sigma_\varepsilon$.**
  - Rationale: the engine fixes $\sigma_\varepsilon$ at $10^{-3}\,\mathrm{sd}(y)$, where $y$ pools all traits on the raw scale (`R/fit-multi.R` 7224-7226). It does this whenever a diagonal term has one row per observation, including the default `latent()` Psi with one observation per unit and trait. The fixed value still enters the likelihood (`src/gllvmTMB.cpp` 3501-3509, 3563). It is negligible only when traits share a scale. For a trait 1000-fold smaller than another it was 43-57% of that trait's variance; for lognormal traits a raw-scale SD is used as a log-scale SD.
  - Rejected: the first version excluded it as "a stabiliser". The Gauss lens showed that this brought back the #1399 symptom (`score shared_unit = 1.000`), and both verifiers confirmed it.
  - Confidence: high.
- **`extract_proportions()` warns about `(1 | group)`, propto and multi-kernel instead of adding them.**
  - Rationale: the lane's fix direction for #1399 covers the residual. Adding these components would also widen the `confint(parm = "proportion:…")` vocabulary and the Wald and profile rebuilds.
  - Rejected: adding them in this PR.
  - Confidence: medium. Whether to add them is a question for Shinichi (§10).
- **Random-slope terms are omitted with a warning, not split into an intercept part.**
  - Rationale: the variance of $b_0 + b_1 x$ depends on $x$. An "intercept share" exists only at $x = 0$, so it depends on how $x$ is centred.
  - Rejected: reporting the intercept rows as a unit-level column.
  - Confidence: medium-high.

## 4. Checks Run

R 4.5.3 (conda-forge), TMB 1.9.23 and roxygen2 8.0.0 in a cloud session. `NOT_CRAN=true` throughout. `options(Matrix.warnDeprecatedCoerce = 2)` as in `tests/testthat.R`.

- **Forcing test.**
  - On base `aec24e16` (installed), each behavioural test fails for the issue's reason. The tests that pass on base are regression guards: a fully partitioned fit, and the two-slot residual that `main` already handled. Exact counts are in the PR body.
  - On this branch, every expectation passes.
- **Directly affected suites** (`test-ordiplot-VP`, `test-extract-omega`, `test-proportions-cluster-components`, `test-mixed-response-sigma`, `test-plot-gllvmTMB`, `test-structured-rho-workflow`, `test-gapclose-next-steps`, `test-mspl-api`, `test-lme4-style-weights`): see the PR body for the final run on the last commit.
- **Heavy proportion tests** (`GLLVMTMB_HEAVY_TESTS=true`: `test-proportions-ci`, `test-profile-proportions`, `test-profile-derived-curves`): see the PR body for the final run.
- **`devtools::test()`, full suite.**
  - Result: 29,330 pass, 42 fail, 5 error, 900 skip.
  - The 23 failing tests are identical, test for test, to `devtools::test()` on a clean base worktree with the same filter. They are local environment issues: dev-tool manifests, process groups, UTM/PROJ, and vdiffr graphics drift. None of them involves variance shares.
  - The three vdiffr snapshots differ the same way on base, and the variance-partition SVG from base and from the fix is byte-identical.
- **`R CMD check --no-manual`**: see the PR body.

## 5. Tests of the Tests

- **Failure before the fix.** Every new behavioural test fails on base, as listed above.
- **Review-driven repairs.** The Curie lens found two vacuous assertions, and both were fixed:
  - The plot check now matches the residual's own colour, because an unmatched manual-scale level is drawn grey50, not `NA`.
  - The temporal check matches the label, because every warning mentions `extract_temporal()`.
- **Boundary and combination cases added.**
  - The Gaussian+lognormal two-slot residual.
  - Two `(1 | group)` terms, propto and two kernel tiers in one fit, with exact shares.
  - A fixed $\sigma_\varepsilon$ on mixed-scale traits.
  - A mixed Gaussian+binomial fit with a partly fixed `theta_diag_B`: exact profile targets, and Wald rows `"(unavailable)"` for the binomial traits' residual.
  - A diagonal `phylo_indep()` block: an exact profile target.
  - A slope-only `phylo_slope()` label.
  - One response-column slope term.
  - A Julia fit.

## 6. Consistency Audit

- `rg -n "extract_proportions|VP\(" R/ man/ vignettes/`: the internal callers are `R/proportions-ci.R`, `R/profile-derived.R`, `R/profile-derived-curves.R` and `R/plot-gllvmTMB.R`. No vignette calls either function.
- `rg -n "link_residual\"\)" R/z-confint-gllvmTMB.R`: the vocabulary and the roxygen list now both include `residual`.
- **Stale statements not fixed here, because they are in shared files:**
  - `docs/design/35-validation-debt-register.md` EXT-32 still says `VP()`'s residual column is "legacy", and EXT-34 lists the old component set.
  - The local-only snapshot `tests/testthat/_snaps/plot-visual-snapshots/dispatcher-variance-partition-plot.svg` will need a reviewed regeneration on the maintainer's machine. Its OLRE fixture now shows a thin `Residual` band for the fixed $\sigma_\varepsilon$. It cannot be regenerated faithfully here, because this environment's graphics stack already differs on base.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

- #1399 and #1395: addressed by the fix PR (`refs` only).
- Red proof: the companion `[red proof, do not merge]` PR.
- No issue was created. The pre-existing defects found by review are listed in §10 for the maintainer to file or assign.

## 8. What Did Not Go Smoothly

- The first design excluded the fixed $\sigma_\varepsilon$ to keep the existing OLRE fixtures' component sets unchanged. Review showed that this hid a real and sometimes large variance and reintroduced the #1399 symptom. Exact accounting of the fitted model is the safer default, and test churn should not drive a statistical choice.
- CRAN, Posit and r2u are blocked from the session, so R and its dependencies came from conda-forge. `nadiv`, `DHARMa`, `detectseparation`, `galamm`, `gllvm` and `JuliaCall` are missing, so tests that need them skipped.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Gauss**: Caught the blocking issue. The "negligible stabiliser" is $10^{-3}$ of the pooled raw-scale SD. It is applied on the log scale for lognormal traits, so it can dominate a small-scale or lognormal trait. Watch for any summary that drops a mapped-but-present likelihood term.
- **Fisher**: Verified that the Wald and profile rebuilds reproduce the extractor at the MLE for Gaussian, lognormal, two-slot and OLRE fits. Found the pre-existing misindexing of partly fixed per-trait blocks in `.proportion_target_fn()`, which the new residual would have inherited. In the second round, showed that refusing those fits was too blunt, which led to the map-aware rebuild. Also found the degenerate Wald interval for a structurally zero residual.
- **Emmy**: Found that one response-column slope term raised two omission labels, one of them wrongly "phylogenetic". Found that Julia fits now fell through to an empty matrix.
- **Curie**: Found the two vacuous assertions and the untested two-slot and multi-term branches.
- **Rose / Pat**: Found that "random slopes" hid the dropped intercept variance, and that "Mirrors `gllvm::VP()`" contradicted the new text, because `gllvm::VP()` partitions fixed effects. Also found that the hint "use `extract_Sigma()`" led nowhere for `(1 | group)` terms.

## 10. Known Limitations And Next Actions

- **Maintainer decision.** Should `extract_proportions()` also add `(1 | group)`, propto and multi-kernel components? That would need the `confint(parm = "proportion")` vocabulary and the Wald and profile rebuilds extended to them.
- **Pre-existing, outside this lane.**
  - `R/fit-multi.R` 7224-7226 fixes $\sigma_\varepsilon$ from the pooled raw-scale SD even for lognormal traits, where it acts on the log scale. This can wreck lognormal OLRE fits.
  - Phylogenetic and kernel shares assume a unit-diagonal source matrix. Dense `vcv =`, pedigree and user kernels are not rescaled.
  - The proportion bootstrap rebuilds `(1 | group)` as the internal `re_int()` keyword (review finding, unverified here).
- **Possible later additions to `VP()`:**
  - temporal states, using `extract_temporal()`'s per-trait variances;
  - spatial fields, using the stationary Matérn variance $1/(4\pi\kappa^2)$ times the field-scale diagonal. This needs its own validation, because the finite-mesh variance inflates near the boundary.
- Update the validation-debt rows EXT-32 and EXT-34 and the check-log entry when the shared docs next move.
