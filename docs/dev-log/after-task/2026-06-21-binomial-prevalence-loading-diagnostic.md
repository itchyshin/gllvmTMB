# After Task: binomial prevalence/loading diagnostic for `check_gllvmTMB()`

Branch: `codex/ayumi-binary-diagnostics-20260621`  
Issue: [#523](https://github.com/itchyshin/gllvmTMB/issues/523)  
Author: Codex (Ada)

## 1. Goal

Add the package-side diagnostic requested by Ayumi-495/urbanisation_map#3:
when a near-constant binomial indicator drives a dominant loading, the
machine-readable `check_gllvmTMB()` table should surface the root cause and point
users toward removing or re-coding that indicator, not only toward lowering
latent rank.

## 2. Mathematical Contract

No likelihood, TMB engine, formula grammar, family, NAMESPACE, or fitted-model
parameterisation changed. This is an additive post-fit diagnostic over existing
fit objects.

For binomial rows, the new screen computes, per trait:

- observed prevalence `sum(y) / sum(n_trials)` on observed binomial rows;
- fitted-probability saturation share from `report$eta` passed through the
  existing family/link-aware inverse-link helper;
- maximum absolute fitted loading for that trait across fitted latent blocks;
- relative loading size against the fitted loading scale.

`binomial_prevalence_loading` warns only when prevalence is near-constant and
the trait also has a dominant loading or saturated fitted probabilities. It does
not prove formal separation, calibrate interval coverage, change optimisation,
or alter the likelihood.

## 3. Files Changed

- `R/diagnose.R`: adds helper functions, four threshold arguments to
  `check_gllvmTMB()`, the new `binomial_prevalence_loading` row, and a
  conditional weak-axis action when the binomial row warns.
- `tests/testthat/test-sanity-multi.R`: adds a deterministic mocked fit for the
  near-constant binary / dominant-loading failure mode.
- `man/check_gllvmTMB.Rd`: regenerated argument and scope documentation.
- `NEWS.md`: adds a dated development bullet for #523 with IN/PARTIAL scope.
- `docs/design/35-validation-debt-register.md`: updates DIA-08 to include the
  binomial prevalence/loading/saturation screen.
- This after-task report and the paired `docs/dev-log/check-log.md` entry.

## 4. Checks Run

- `air format R/diagnose.R tests/testthat/test-sanity-multi.R` -> no output,
  no formatting failure.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> completed after
  package load. It rewrote `man/check_gllvmTMB.Rd`; unrelated roxygen link
  churn in `man/add_utm_columns.Rd`, `man/extract_correlations.Rd`,
  `man/gllvmTMB-package.Rd`, `man/make_mesh.Rd`, `man/phylo_latent.Rd`, and
  `man/reexports.Rd` was removed from this branch.
- `Rscript --vanilla -e 'devtools::test(filter = "sanity-multi", stop_on_failure = TRUE)'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]`.
- Real synthetic Ayumi-shaped smoke fit:
  `gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2),
  family = binomial(link = "probit"), control = gllvmTMBcontrol(se = FALSE,
  n_init = 2, init_jitter = 0.05))` on 9 binary traits with a 94 percent
  prevalent sentinel indicator -> `weak_axis_unit` WARN and
  `binomial_prevalence_loading` WARN with
  `item9 prevalence=0.94; max_loading=13.2; relative_loading=20; saturated_fit=0.94`.
- `Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'`
  -> `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3405 ]`, duration 512.9s.
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`
  -> `0 errors | 1 warning | 0 notes`, duration 5m 15.3s. The warning was
  reported at package-install check stage; the quiet check output did not leave
  a discoverable `gllvmTMB.Rcheck` directory with the expanded warning text, and
  this branch touches no compiled code.
- `tail -5 man/check_gllvmTMB.Rd` -> help topic ends with the intended
  `check_gllvmTMB(fit)` example close.
- `grep -c '^\\keyword' man/check_gllvmTMB.Rd` -> `0`.
- `gh pr list --state open --repo itchyshin/gllvmTMB` -> no open PRs listed.

## 5. Tests of the Tests

The mocked test builds a minimal `gllvmTMB_multi` object where `item4` is
near-constant and has a much larger fitted loading than the other traits. It
asserts that exactly one `binomial_prevalence_loading` row appears, that the row
WARNs, that the reported value names the sentinel trait, and that both the new
row and the `weak_axis_unit` action point to the near-constant binary indicator.

The smoke fit exercises the real `gllvmTMB()` -> TMB -> `check_gllvmTMB()` path
rather than only mocked internals. It reproduced the issue shape: a 94 percent
prevalent binary trait with a dominant loading and saturated fitted
probabilities.

## 6. Consistency Audit

- `rg -n "binomial_prevalence_loading|binary_prevalence_thresh|binary_saturation_prob_thresh|binary_saturation_share_thresh|loading_relative_thresh" R tests man NEWS.md docs/design/35-validation-debt-register.md`
  -> hits only in the implementation, test, generated Rd, NEWS, and DIA-08.
  Verdict: the new user-facing arguments and row name are documented and tested
  without spreading to unrelated files.
- `rg -n "near-constant binomial|near-constant binary|remove or re-code|lowering rank" R tests man NEWS.md docs/design/35-validation-debt-register.md`
  -> hits in the new warning/action text, test expectations, NEWS, and DIA-08.
  Verdict: the action language is aligned with the issue diagnosis.
- `rg -n "formal separation|calibrate interval|calibrat.*coverage|change the fitted likelihood|formula grammar|engine" NEWS.md R/diagnose.R docs/design/35-validation-debt-register.md`
  -> the new NEWS/Rd text explicitly says this does not prove formal separation,
  calibrate interval coverage, or change the fitted likelihood; broader existing
  NEWS/register hits are historical context.
  Verdict: public wording stays diagnostic-only.
- `rg -n "DIA-08|DIA-10|check_gllvmTMB\\(|binomial_prevalence_loading|near-constant" README.md ROADMAP.md NEWS.md docs/design docs/dev-log/known-limitations.md _pkgdown.yml R/diagnose.R man/check_gllvmTMB.Rd tests/testthat/test-sanity-multi.R`
  -> existing README/ROADMAP diagnostic references remain broad; the new row is
  scoped to NEWS, DIA-08, Rd, implementation, and tests.
  Verdict: no README, ROADMAP, pkgdown navigation, or known-limitations edit is
  required for this narrow diagnostic row.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` status chip or progress bar changed. This is a narrow
DIA-08 diagnostic hardening slice, not a roadmap phase change.

## 8. GitHub Issue Ledger

- Inspected package issue [#523](https://github.com/itchyshin/gllvmTMB/issues/523):
  this branch is the direct package-side fix and should close #523 when merged.
- Commented earlier on Ayumi-495/urbanisation_map#3 with the planned package-side
  diagnostic and linked #523.
- Commented earlier on Ayumi-495/urbanisation_map#1 recommending a final-indicator
  prevalence/loading QC artifact.
- Opened Ayumi-495/urbanisation_map#4 as a draft PR adding that QC artifact to
  the map repo. That PR is separate from this package fix.

## 9. What Did Not Go Smoothly

- `devtools::document()` spent several minutes in package load and regenerated
  unrelated Rd link-format churn. Those unrelated generated changes were removed
  so the branch remains a five-file package diagnostic slice plus closeout files.
- The first synthetic smoke fit used a `review` grouping column but the current
  long-format default expects `site`; rerunning with a `site` column exercised the
  intended path.

## 10. Team Learning

- **Ada (orchestration)**: kept the Ayumi repo patch and gllvmTMB package fix as
  separate PRs. That avoided mixing exploratory-map workflow changes with package
  diagnostic code.
- **Boole (R API / diagnostics surface)**: the new thresholds are explicit
  arguments on `check_gllvmTMB()`, but the default behavior remains additive; no
  formula grammar or fitting syntax changed.
- **Curie (testing)**: the deterministic mocked fit gives a fast regression
  guard, while the synthetic smoke fit checks the real fitted-object route.
- **Fisher (inference)**: the row is deliberately an identifiability/inference
  warning, not a proof of separation or a calibrated uncertainty claim.
- **Rose (consistency)**: the closeout scans caught wording scope and kept
  unrelated roxygen churn out of the diff.
- **Grace (reproducibility)**: full `devtools::test()` passes locally before the
  full check gate; any full-check env failures will be recorded separately.

## 11. Known Limitations and Next Actions

- The diagnostic is heuristic. It flags a risky combination of prevalence,
  loading dominance, and fitted-probability saturation; it does not run a formal
  separation test.
- The row reports the worst trait in `value`; it does not yet return a full
  per-trait QC table. That richer table is better suited to user reports such as
  Ayumi-495/urbanisation_map#4.
- Next package action: open a focused draft PR and keep it in review until CI
  and maintainer review clear the diagnostic change.
