# After Task: Scale-aware AGHQ tau (#847)

## 1. Goal

Give default-grammar pure single-trial Bernoulli users an explicit experimental
scale-aware loading ridge whose scale comes from an unpenalised multi-start
AGHQ pilot, while preserving the package default and making every fallback and
claim boundary visible.

## 2. Implemented

- `gllvmTMBcontrol(aghq_ridge = "auto")` now selects a two-stage 9-node
  multi-start AGHQ route. Conflicting node/start controls are replaced with a
  warning; explicit `aghq = FALSE` is rejected because a Laplace pilot would
  directly contradict the calibrated method.
- A valid pilot supplies the capped scale. A valid auto final fit is returned;
  an invalid pilot or final fit triggers an independently started `tau = 2`
  fit. `fit$aghq$ridge_auto` retains the pilot, raw/used scale, cap, selection,
  and fallback reason.
- Numeric and `Inf` ridge controls retain the established single-fit path. The
  package default remains `tau = 2`.
- The strict Totoro selection campaign returned `NO_CAP_PASSED_SELECTION`; no
  default confirmation was run. The narrower posthoc transparent-fallback
  sensitivity is retained as MIS-36 evidence, explicitly not as a broad
  estimator-accuracy result.

## Mathematical Contract

For a valid unpenalised 9-node multi-start AGHQ pilot with `p` traits and `q`
latent axes,

\[
\tau_{\mathrm{raw}} = \max\left(1,
  \frac{\|\widehat\Lambda_{\mathrm{pilot}}\|_F}{\sqrt{pq}}\right),
\qquad
\tau_{\mathrm{used}} = \min(6, \tau_{\mathrm{raw}}).
\]

The final objective adds
`||Lambda||_F^2 / (2 * tau_used^2)` to the negative AGHQ objective. This is a
MAP point, not an ML estimate. The pure Bernoulli default grammar is admitted
only because every automatic B-tier Psi coordinate is mapped off and the R and
C++ eligibility predicates agree that no free `s_B` random block remains.

## 4. Files Touched

- Engine/API: `R/fit-multi.R`, `src/gllvmTMB.cpp`, `R/gllvmTMB.R`,
  `R/aghq-auto-ridge.R`.
- Tests: `tests/testthat/test-aghq-auto-psi-equivalence.R`,
  `tests/testthat/test-aghq-auto-ridge.R`.
- Evidence: `dev/aghq-evidence/28-tau-rescore.*`,
  `dev/aghq-evidence/29-tau-cap-totoro.R`,
  `dev/aghq-evidence/30-tau-cap-analyse.R`,
  `dev/aghq-evidence/31-tau-transparent-fallback.R`, and
  `docs/dev-log/artifacts/aghq-tau-847/`.
- Public/developer docs: `NEWS.md`, `R/gllvmTMB.R`, regenerated
  `man/gllvmTMBcontrol.Rd`, `docs/design/35-validation-debt-register.md`
  (MIS-36), `docs/dev-log/2026-08-01-scale-aware-tau-ultra-plan.md`, this
  report, the recovery checkpoint, and `docs/dev-log/check-log.md`.
- Example cascade: the only new runnable example is the pure control-constructor
  call in `R/gllvmTMB.R` / `man/gllvmTMBcontrol.Rd`. No README, article,
  vignette, formula grammar, export, `_pkgdown.yml`, or generated site file
  required a change; all were verified clean in the final diff.

## 3a. Decisions and Rejected Alternatives

> **Decision**: Keep fixed `tau = 2` as the package default and expose auto tau
> only through an explicit experimental value. **Rationale**: the preregistered
> selection gate returned `NO_CAP_PASSED_SELECTION`. **Rejected alternative**:
> a default flip or disjoint confirmation after no cap qualified. **Confidence**:
> high.

> **Decision**: Use only unpenalised 9-node multi-start AGHQ as the scale
> yardstick and as the final estimator. **Rationale**: plain Laplace was in the
> intended basin in only 0--1% of the hardest stored fits, and the campaign arms
> all used this AGHQ estimator. **Rejected alternative**: Laplace pilot or a
> caller-selected lower-node/single-start final fit. **Confidence**: high.

> **Decision**: On an unusable pilot or auto final fit, return an independently
> started fixed-2 fit with a warning and provenance. **Rationale**: the posthoc
> sensitivity used that exact transparent policy and the maintainer authorised
> scoped positive evidence as implementation permission. **Rejected
> alternative**: blocking every unsupported attempt or silently returning the
> pilot-dependent result. **Confidence**: medium for the narrow avoidance claim,
> low for any accuracy extrapolation.

## 5. Checks Run

- Focused public/helper auto-tau tests — PASS, 58 expectations including a live
  public default-grammar fit.
- Focused `NOT_CRAN=true` AGHQ equivalence/control/surface/multistart/runaway
  files — PASS; the exact auto-Psi equivalence file passed 90 expectations.
- `INPUT=/private/tmp/29-tau-cap-selection.csv OUTPUT=docs/dev-log/artifacts/aghq-tau-847/31-transparent-fallback Rscript --vanilla dev/aghq-evidence/31-tau-transparent-fallback.R`
  — PASS; locked MD5 `3399541e3b944c858e7d7b7c9f836f00`, package SHA
  `54d6f366e972643c663be9645ed598aa98e81869`, strict recheck
  `NO_CAP_PASSED_SELECTION`, auto used 135/600, six-cell macro loading delta
  `+0.002819895`.
- `TMPDIR=/private/tmp Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  — PASS; `man/gllvmTMBcontrol.Rd` regenerated. Existing AIC/BIC roxygen notices
  were unchanged and outside this lane.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, no problems.
- `Rscript --vanilla -e 'pkgdown::build_site(new_process = FALSE, install = FALSE)'`
  — PASS with network/cache access; reference metadata and the complete site
  built. The first sandboxed run stopped only at the CRAN hostname/cache gate.
- Full `NOT_CRAN=true devtools::test()` — auto-tau work PASS; package total
  reported three current-main failures: the newly merged
  `lambda-constraint-suggest.Rmd` method allowlist mismatch, the recorded
  spatial convergence fixture, and the recorded local ellipse snapshot drift.
  None overlaps this branch.
- Strict `devtools::check(args = "--no-manual", error_on = "warning")` — 12m09s,
  `1 error / 1 warning / 2 notes`; testthat `FAIL 1 / WARN 2 / SKIP 822 / PASS
  8190`. The only test failure was the same current-main ellipse snapshot. The
  warning was sandboxed CRAN/Bioconductor index access plus pre-existing
  `some::` test code; notes were clock verification and `xcrun_db` detritus.
- `git diff --check` — PASS.

## 6. Tests of the Tests

- `test-aghq-auto-psi-equivalence.R`: failure-before-fix and feature-combination;
  default `latent()` previously retained structural `s_B` and was fenced from
  AGHQ. It checks objective/AD-gradient equality at optima and perturbations for
  three links and ranks 1/2, plus the free-Psi rejection boundary.
- `test-aghq-auto-ridge.R`: boundary and feature-combination; it covers invalid
  strings, explicit Laplace contradiction, conflicting node/start replacement,
  cap/floor algebra, invalid pilot fallback, valid-pilot/invalid-final fallback,
  out-of-scope fallback, independent fallback starts, provenance, and a live
  public default-grammar fit.
- The pre-fix bite is also the campaign result: strict pilot-dependent auto tau
  fails selection, preventing a false default promotion.

## 7a. Issue Ledger

- #847: implementation and evidence lane addressed by this PR; close only after
  GitHub CI and merge.
- #877: prerequisite runaway-warning PR already merged at `bca04b29`.
- Current-main article allowlist, spatial fixture, and ellipse snapshot failures
  are explicitly not reassigned to #847.

## 8. Consistency Audit

- `rg -n 'aghq_ridge|ridge_auto|scale-aware|tau = 2|tau=2' R man README.md NEWS.md vignettes docs/design _pkgdown.yml`
  — PASS; source, Rd, NEWS, and MIS-36 agree on formula, cap, default, estimator,
  fallback, and claim boundary.
- `rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S' R/gllvmTMB.R man/gllvmTMBcontrol.Rd NEWS.md docs/design/35-validation-debt-register.md`
  — PASS; no stale notation in touched public prose.
- `rg -n 'gllvmTMB_wide|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(' NEWS.md R/gllvmTMB.R man/gllvmTMBcontrol.Rd`
  — PASS; matches were existing explicit deprecation/migration text, not new
  primary syntax.
- `tail -8 man/gllvmTMBcontrol.Rd` and `grep -c '^\\keyword' man/gllvmTMBcontrol.Rd`
  — PASS; the rendered example is intact and no malformed keyword tags exist.
- Rose pre-publish verdict: PASS. The experimental claim maps to MIS-36, public
  prose states IN/PARTIAL/OUT scope, defaults/formals agree, and no export or
  pkgdown-index change occurred.
- Final adversarial implementation review: READY after forcing the calibrated
  final estimator, binding the posthoc analysis to strict provenance checks,
  adding candidate-failure fallback coverage, and regenerating Rd.

## 7. Roadmap Tick

N/A. This closes issue #847's bounded estimator-control lane; no ROADMAP phase
status was changed.

## 9. What Did Not Go Smoothly

The strict campaign rejected the original default-change hypothesis, so the
work had to separate the negative preregistered result from a narrower posthoc
capability. The first posthoc script trusted arm labels too much; adversarial
review required it to lock the raw MD5/package SHA and re-run the full strict
validator. The first wrapper also allowed caller-selected node/start settings
on the final fit and initially lacked a candidate-failure test. Full package
testing was long and surfaced three current-main failures unrelated to this
lane; they were classified rather than absorbed.

## 10. Known Residuals

- MIS-36 remains `opt-in / partial`: the measured avoidance grid is logit,
  `p = 6`, `q = 2`, and `n = 100/400/1600`. Other links and dimensions are
  warned extrapolations, not covered accuracy claims.
- The policy is MAP point estimation. `logLik()`, AIC, BIC, interval calibration,
  structured/source/W/slope tiers, mixed families, and broad loading accuracy
  remain outside scope.
- Valid pilots were sparse and the auto result was used in only 135/600
  replicates. The fixed-2 fallback is therefore a central public path.

## 11. Team Learning

- **Ada** kept the negative default gate separate from the positive opt-in
  capability and preserved the 10-hour bounded arc.
- **Gauss/Noether** required one estimator contract from pilot through final fit
  and machine-readable provenance for every fallback.
- **Curie/Fisher** retained failed/nonconverged fits in denominators, separated
  the preregistered selection from the posthoc sensitivity, and rejected a broad
  accuracy claim despite positive avoidance evidence.
- **Rose** aligned NEWS, Rd, the validation register, and the generated site.
- **Grace/Shannon** kept compute on Totoro, integrated current main, and left
  unrelated main failures and generated snapshots untouched.

## 12. Cross-Product Coverage

- **Covered**: default and explicit loadings-only ordinary unit-tier latent
  Bernoulli grammar; exact eligibility equivalence spans logit/probit/cloglog and
  `q = 1/2`; auto-tau outcome evidence is logit `p = 6`, `q = 2`,
  `n = 100/400/1600`.
- **Boundary-tested**: free automatic Psi, non-Bernoulli scope, invalid pilot,
  invalid final fit, conflicting node/start controls, numeric `tau`, `Inf`, and
  explicit Laplace contradiction.
- **This arc does NOT cover**: mixed families, multi-trial binomial,
  source/structured/W/slope tiers, multinomial, interval calibration, broad rank/dimension grids,
  and likelihood-based comparison of MAP fits.

## Next Actions

- Open the narrow PR, wait for its R-CMD-check, and merge only after green. The
  current-main article allowlist and local spatial/snapshot failures belong to
  their existing lanes and must not be fixed here.
