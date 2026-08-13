# After Task: Lane B binary separation screening and LA-MSPL

**Branch**: `codex/lane-b-mspl-20260808`
**Date**: 2026-08-08
**Roles (engaged)**: Ada, Boole, Gauss, Noether, Fisher, Curie, Jason, Rose, Grace

## 1. Goal

Ship an opt-in binary-response Lane B for the planned gllvmTMB 0.7 release:
fixed-design separation screening (B0), LA-MSPL point estimation (B1), and a
frozen simulation campaign that determines the exact promoted scope (B2).
`estimator = "ml"` must remain unchanged. The admitted surface is deliberately
narrow: complete single-trial Bernoulli responses with logit, probit, or
complementary-log-log links and only the ordinary or explicitly validated
spatial latent structures.

## 2. Implemented

### Mathematical contract

For observed Bernoulli rows (r), the admitted ordinary model is

\[
Y_r \sim \operatorname{Bernoulli}\{g^{-1}(x_r^\top\beta+
\lambda_{t(r)}^\top z_{i(r)})\}, \qquad z_i\sim N_q(0,I_q),
\]

with \(g\) equal to logit, probit, or complementary log-log. LA-MSPL minimises

\[
Q(\theta)=-\ell_{\mathrm{LA}}(\theta)
-c_n\,\frac12\log\det(X_*^\top W_g(\beta)X_*)
+c_n\sum_t\{\sqrt{1+\|\lambda_t\|^2}-1\}+c_n V_{\mathrm{cov}},
\]

where \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), \(X_*=XK\)
is the resolved fixed-effect design after maps and ties, and \(W_g\) is the
expected-information weight for the selected link. The spatial covariance
penalty is expressed in the continuous-reference coordinates documented in
`docs/design/88-binary-mspl-estimator.md`.

This is not Firth estimation, generic MAP tuning, rank selection, or general
GLMM/GLLVM inference. It does not make the unpenalised MLE exist; it defines a
finite softly penalised point estimator. The 0.7 surface excludes FIML,
grouped binomial data, mixed families, `q > 2`, phylogenetic/animal/kernel
tiers, VA/AGHQ/Julia MSPL, and ordinary likelihood-based model comparison or
interval inference for MSPL fits.

Implemented components:

- B0 opt-in fixed-design certificates through
  `screen_control(separation = "fixed")` and `screen_table(...,
  "separation")`.
- B1 top-level `estimator = c("ml", "mspl")`; ML remains the default and its
  objective branch is unchanged.
- A fail-closed, numerically guarded weighted-max-volume
  Jeffreys-information atom, stable binary
  link kernels, global row-radial loading penalty, spatial reference-coordinate
  penalty, penalty-off Laplace provenance tape, stationary-point checks, and
  typed fail-closed numerical gates.
- Hard method fences for AIC/BIC/LRT/likelihood-based comparisons and
  uncalibrated interval routes on MSPL fits.
- A frozen four-arm B2 campaign: ML, existing loading ridge, MSPL, and the
  harness-private MSPL-plus-loading-ridge ablation. Every attempt and failure
  is retained. A post-launch adjudicator conjoins the immutable v1 gates with
  exact realized B0 strata, healthy alternate starts, multistart agreement,
  and independent spatial link-by-structure family gates. Those added gates can
  only withhold. One documented metric correction replaces the runner's
  elementwise covariance diagnostic with the approved relative-Frobenius
  statistic at the same frozen threshold.

**B2 promotion result**: pending completion and adjudication of the frozen
Totoro campaign. This report must not be treated as final until this paragraph
is replaced with the cellwise verdict and evidence paths.

The Fir/Totoro estimator source was frozen before the final review-only repair
round. A direct file comparison against the Fir source snapshot found the B2
harness files byte-identical. The only later changes in estimator files were:
class-or-estimator recognition for inference fences (`R/mspl.R`), one diagnostic
wording change (`R/fit-multi.R`), comments that narrow the numerical-certificate
claim, and a direct-template rejection of nonzero offsets (`src/gllvmTMB.cpp`).
Every B2 dataset has an exact zero offset, so the evaluated objective and its
derivatives are unchanged on the frozen campaign surface. This equivalence must
remain part of the final B2 provenance receipt.

The later B0 wrapper repair likewise changes only indeterminate (`NA`)
detector returns. The frozen exact B0 campaign produced zero `NOT_CHECKED`
results and only scalar, non-missing logical certificates, so none of its
72,000 classifications changes; the final provenance receipt must record this
source difference and its no-effect condition.

| File | Frozen Fir SHA-256 | Final working-tree SHA-256 | Semantic difference |
|---|---|---|---|
| `R/mspl.R` | `8772194c01c2807498a5a9fec2419367c3f96e573a232ddf40cfc060d71bb58b` | `ef736ecc873be02934362aeed853c8ae2346576b36355b70f056699a17c68d11` | Conservative class-or-tag inference fence only |
| `R/fit-multi.R` | `47bdac133e1af60e6cc91cf748eee7da7efc4c862d5c328522c39e80fab6f9f5` | `b71eb807f5504da137133870a6fc0c086fa7aa0a7b2b217a055e1083532fd6eb` | Diagnostic wording only |
| `src/gllvmTMB.cpp` | `9a5ba6ea482956886a9d3c6ab28fae89608730a0ccbe0397ae95312c1d5f59ae` | `7cd478d5d9b37fde05280e6bcec53324e9ec684ec0eefad2ac451c7af6427874` | Comment plus nonzero-offset rejection; zero-offset objective unchanged |
| `src/lane_b_jeffreys_maxvol_atomic_v8.h` | `c1ee80a5f64746862ab81710ddc144e4d40645178096f05785c2f10e08f203b4` | `dc129f92f9b6da27e7ea418fbb9dc05f960bb89b3eb3b4d3fc2b012b9a2676df` | Comments only |

At launch, the main B2 runner and targeted quasi supplement were byte-identical
between Totoro/Fir and the working tree (`155ed5e0...e8e` and
`601341b1...1432`, respectively). During monitoring, the frozen targeted-quasi
wrapper was found to leave completed lock files behind because top-level
`on.exit()` did not clean them. Raw attempts and completion receipts were
unaffected, and aggregation does not use the lock directory. The shipping
wrapper now explicitly removes the lock on both success and failure; the frozen
Fir keeper may still contain those harmless stale lock files.

## 4. Files Touched

Implementation and API:

- `src/gllvmTMB.cpp`
- `src/lane_b_jeffreys_maxvol_atomic_v8.h`
- `R/mspl.R`
- `R/screen-separation.R`
- `R/gllvmTMB.R`
- `R/fit-multi.R`
- `R/screen-gllvmTMB.R`
- `R/methods-gllvmTMB.R`
- `R/aghq-report.R`
- `R/bootstrap-sigma.R`
- `R/standard-errors.R`
- `R/vcov-coef.R`
- `R/z-confint-gllvmTMB.R`
- `DESCRIPTION`

Tests and B2 harness:

- `tests/testthat/test-mspl-api.R`
- `tests/testthat/test-screen-separation.R`
- `tests/testthat/test-mspl-simulation-contract.R`
- `inst/sim/lane-b/`

Reader and package documentation:

- `NEWS.md`
- `inst/CITATION`
- `_pkgdown.yml`
- `vignettes/articles/behavioural-syndromes.Rmd` (unrelated deterministic
  BFGS iteration-budget repair required by the full article rebuild)
- `vignettes/articles/pre-fit-response-screening.Rmd`
- `vignettes/articles/mspl-binary-jsdm.Rmd`
- `man/gllvmTMB.Rd`
- `man/gllvmTMB_multi-methods.Rd`
- `man/gllvmTMBcontrol.Rd`
- `man/screen_control.Rd`
- `man/screen_gllvmTMB.Rd`
- `man/screen_table.Rd`

Design, evidence, and handoff:

- `docs/design/03-likelihoods.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/88-binary-mspl-estimator.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-08-08-202656-codex-lane-b-mspl-checkpoint.md`
- `docs/dev-log/recovery-checkpoints/2026-08-08-214650-codex-lane-b-b2-checkpoint.md`
- `docs/dev-log/recovery-checkpoints/2026-08-09-010041-codex-lane-b-mspl-checkpoint.md`
- this report

## 3a. Decisions and Rejected Alternatives

- **Decision**: expose `estimator = "mspl"` as an opt-in top-level estimator
  and preserve `estimator = "ml"` as the default. **Rationale**: the estimator
  changes the objective and belongs beside ML/REML, not inside numerical
  controls. **Rejected alternative**: automatic activation after a screen or a
  control-only switch, because that would silently change the estimand.
  **Confidence**: high.
- **Decision**: apply the Jeffreys and loading penalties globally on the
  admitted parameter surface. **Rationale**: detector-targeted penalties would
  define a discontinuous, unproved estimator. **Rejected alternative**: penalise
  only traits flagged by B0. **Confidence**: high.
- **Decision**: use a rotation- and trait-permutation-invariant row-radial
  loading penalty. **Rationale**: componentwise penalties depend on arbitrary
  loading coordinates. **Rejected alternative**: transplant the 2023 GLMM
  covariance-Cholesky Huber penalty, which does not match the reduced-rank
  loading geometry. **Confidence**: medium-high; the finite-point theorem is
  new for this GLLVM surface and does not prove rank interiority.
- **Decision**: keep the existing loading ridge as a separate empirical arm
  and test an MSPL-plus-ridge hybrid privately. **Rationale**: ridge and MSPL
  target different objectives; finite existence does not imply minimum MSE or
  best prediction. **Rejected alternative**: remove ridge as theoretically
  redundant. **Confidence**: high for the ablation design; final redundancy
  verdict depends on B2.
- **Decision**: defer FIML-MSPL and general inference. **Rationale**: mask-wise
  information scaling and interval calibration require separate evidence.
  **Rejected alternative**: broaden 0.7 from finite point estimation to missing
  responses and Wald inference. **Confidence**: high.

## 5. Checks Run

The final command ledger will be inserted after the frozen B2 campaign and
exact-source closeout checks. Completed checks already include focused B0/B1
tests, full package tests, source-tarball `R CMD check`, affected-article
renders, pkgdown validation, independent Jeffreys-information oracles, nested
Laplace decomposition checks, and ordinary/spatial smoke grids. Exact commands,
counts, and final 3-OS evidence remain to be recorded here.

Interim whole-package checks on the pre-adjudication source are green:

```sh
Rscript --vanilla -e 'devtools::test(reporter="summary", stop_on_failure=TRUE)'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'Sys.setenv(R_LIBS_USER="/private/tmp/gllvmtmb-lane-b-r-lib"); .libPaths(c("/private/tmp/gllvmtmb-lane-b-r-lib", .libPaths())); pkgdown::build_articles(lazy = FALSE)'
```

The full test suite passed with only declared heavy/optional skips and two
pre-existing `gllvm` comparator warnings. `pkgdown::check_pkgdown()` found no
problems. The complete article estate rebuilt successfully from a clean
current-source installation after the deterministic BFGS budget repair noted
below. The source-package `R CMD check` subprocess reached `Status: OK`; all of
these checks will be rerun after the B2-driven prose and register update.

## 6. Tests of the Tests

- `test-screen-separation.R` combines supported binary links with complete,
  quasi-complete, overlap, constant, rank-deficient, map/tie, and optional
  dependency failure paths. It also forces indeterminate detector outcomes and
  complete-vs-quasi subtypes to verify that neither can be misreported as a
  certificate. These are boundary and feature-combination tests.
- `test-mspl-api.R` pairs every admitted syntax with neighbouring rejected
  syntax, verifies ML parity, checks numerical fail-closed statuses, exercises
  all three links and ordinary/spatial structures, and compares objective
  components to independent calculations. These satisfy boundary,
  feature-combination, and failure-before-fix rules.
- `test-mspl-simulation-contract.R` checks immutable manifests, seeds, attempt
  retention, private-hybrid state refresh, queue resumability, and promotion
  gates. It verifies raw SHA-256 receipts and rejects tampered shards,
  row-count mismatches, incomplete permutation ledgers, and failed permutation
  comparisons. Its strict spatial tests pair the all-cell acceptance path with
  rejection of unhealthy alternate starts, immutable-v1 failure, and an
  incomplete attempt ledger. A separate counterexample has elementwise
  covariance differences below `1e-4` but a relative Frobenius gap above the
  threshold; the strict ordinary/spatial/quasi adjudicator rejects it. The
  hybrid refresh test would have caught the stale-report defect in
  which parameters changed but `Lambda`/`Sigma` and diagnostics still described
  the pre-ridge MSPL point.
- The external positive Cauchy-Binet and multiprecision oracles would have
  caught the catastrophic finite-wrong scaled-QR/MGS Jeffreys determinant that
  differed by about 711,000 at the frozen cloglog adversarial point.

## 7. Roadmap Tick

N/A at this checkpoint. The separate 0.7 release lane owns version and roadmap
ceremony; this branch supplies a bounded feature for that release. Revisit after
B2 adjudication.

## 7a. Issue Ledger

- Inspected closed issue
  [#523](https://github.com/itchyshin/gllvmTMB/issues/523), the package-side
  record of Ayumi's near-universal binomial-probit runaway-loading example.
  B0 generalises its diagnostic-only response, while B1 adds an opt-in point
  estimator; the issue remains correctly closed because its narrower requested
  diagnostic landed in PR #524.
- Inspected open capability-board issue
  [#340](https://github.com/itchyshin/gllvmTMB/issues/340). Its current text
  correctly calls binary pre-fit screening advisory and treats
  `docs/design/35-validation-debt-register.md` as authoritative. The Lane B
  register rows, not the issue body, will hold the final B2 verdict until the
  board is next deliberately refreshed.
- Search also classified #843, #847, #897, #946, and #947 as adjacent but not
  Lane B ownership: they concern AGHQ/ridge starts, ordinal degeneracy,
  cloglog-offset admission, or LA+ridge model selection. No issue was closed or
  edited, and no new issue was created during this implementation lane.

## 8. Consistency Audit

A pre-B2 prose pass found no Lane B overclaim, deprecated formula syntax,
legacy covariance notation, or foundational “in preparation” citation. It also
manually confirmed that every Lane B long-format `gllvmTMB()` call supplies
`trait = "trait"`, while wide examples use `traits(...)`, and that the six
changed Rd topics have normal tails with no malformed keyword tags. The exact
`rg` commands and one-line verdicts are recorded verbatim in
`docs/dev-log/check-log.md` under the 2026-08-09 Lane B entry.

This audit is provisional because B2 may narrow the promoted cells and alter
reader-facing scope. Repeat the same scans after the cellwise verdict and add
estimator-by-link-by-structure claim checks before closeout.

## 9. What Did Not Go Smoothly

- The first Jeffreys determinant prototypes were mathematically equivalent in
  exact arithmetic but numerically wrong on separated cloglog rays. Repeated
  adversarial counterexamples exposed column-order, row-scale, mixed-scale,
  and basis-switch failures. The final atom uses a numerically guarded
  weighted max-volume representation with exact-rank and multiprecision
  adjudication. Its a-posteriori certificate covers inverse/exchange decisions,
  not a formal interval enclosure for every returned value or derivative.
- A scaled-QR oracle itself failed catastrophically at the hardest frozen
  point. Positive Cauchy-Binet evaluation on the stored-double design showed
  the compiled atom was correct and the supposed independent oracle was not.
- The required full article rebuild initially stopped in the unrelated
  `behavioural-syndromes.Rmd` example. Its BFGS optimizer returned code zero at
  the default 100 iterations but retained raw maximum gradient `0.03161177`,
  above the article's `0.01` health gate. Giving that documented fit 1,000
  iterations and `reltol = 1e-12` preserved objective `5750.598` while reducing
  the raw gradient to `0.0001606655`; `sdreport()` and the positive-definite
  Hessian remained green. This article-only stability repair allowed the full
  article estate to render without changing package defaults.
- The public story initially blurred finite penalised estimates, resolved
  separation, bias reduction, and calibrated inference. The final scope keeps
  those distinct.
- A final B0 audit found that an `NA` detector outcome could previously fall
  through to `PASS / overlap`, while an `NA` complete-vs-quasi subtype could be
  labelled quasi-complete. Both indeterminate certificates now fail closed as
  `NOT_CHECKED / solver_failure`; valid logit, probit, and cloglog results are
  unchanged.
- The B2 campaign is computationally large and highly heterogeneous; slower
  separated cells dominate wall time even with 120 single-threaded Totoro
  workers. Frozen thresholds and source are being preserved rather than
  relaxed for convenience.
- A pre-B2 requirement audit found that the immutable spatial recovery table
  ignored alternate-start health and had no link-by-structure family verdict.
  The fit campaign already retained both starts, so the repair belongs in a
  stricter post-launch adjudicator. It does not alter a fit, threshold, seed, or
  fixture and cannot turn an immutable v1 failure into a pass.
- The frozen ledger stored an elementwise covariance gap, not the approved
  relative Frobenius multistart statistic. The full primary and alternate
  covariance vectors were already retained, so the post-launch adjudicator now
  computes the exact approved statistic without changing fits. The same audit
  found that quasi provenance validation compared archived Fir hashes with the
  later adjudication machine; it now verifies the summary against its frozen
  state and the frozen runtime against the signed preparation receipt.
- A final Curie audit found that the mandatory permutation surface was stored
  but not conjoined to any headline, and that aggregation recorded shard hashes
  without verifying them. The strict adjudicator now requires the exact
  permutation ledger and every comparison before ordinary, spatial, or overall
  promotion, and independently binds every raw shard to its ID, completion
  status, row count, and SHA-256 receipt before trusting either summary. The
  immutable spatial v1 table is recomputed from those authenticated attempts
  and must exactly match the stored table, preventing a changed stored pass
  from reviving a v1 failure.
- A continuation audit found that exact-B0 provenance was incorrectly compared
  with the current, legitimately repaired harness rather than the immutable v3
  launch source. The validator now binds the archived completion receipt to its
  four versioned launch hashes. Acceptance and tampering tests protect that
  separation without changing any B0 classification or campaign artifact.

## 10. Known Residuals

- B2 promotion is pending; all public scope must follow the frozen cellwise
  verdict rather than the intended design.
- B0 proves fixed-design separation only. A clean B0 certificate does not rule
  out loading, variance, or joint divergent paths.
- LA-MSPL returns a softly penalised point estimate; it does not restore the
  unpenalised MLE and does not yet provide calibrated Wald, profile, bootstrap,
  LRT, AIC, or BIC inference.
- FIML, grouped binomial, mixed families, `q > 2`, phylogenetic/animal/kernel
  structures, VA/AGHQ/Julia MSPL, and rank selection are deferred.
- The ordinary theorem is proved for the fenced ideal objective. Spatial
  existence remains conditional on the admitted finite-mesh precision and
  parameterisation premises.
- A pre-existing public extractor issue was discovered but not widened into
  Lane B: `extract_Sigma(level = "spatial")` omits intercept-only
  `spatial_indep`, and the spatial-latent branch reports raw field-scale rather
  than continuum-marginal covariance. B2 uses the correct direct construction;
  the public extractor needs a separate bounded repair.
- Next: finish and aggregate Totoro B2, update the validation register and
  reader claims cell by cell, rerun exact-source tests/documentation/pkgdown,
  obtain 3-OS checks, complete this report and check log, then hand the bounded
  feature to the 0.7 release lane.

## 11. Team Learning

**Ada** kept the lane bounded to opt-in complete-Bernoulli point estimation and
separated implementation, proof, API, validation, and documentation work while
preserving one integration branch and one frozen compute source.

**Boole** located the estimator at the top-level API, preserved positional
compatibility, resolved the existing REML selector, and defined the typed
method fences and user-visible provenance needed for an experimental estimator.

**Gauss** placed the Jeffreys term inside the TMB tape, derived stable
link-specific information weights, separated the primary and penalty-off
Laplace tapes, and iterated the determinant atom until the adversarial numerical
contracts were met.

**Noether** checked the ordinary coercivity proof, narrowed the spatial theorem
to explicit finite-mesh premises, and repeatedly found counterexamples to
over-broad numerical certificates. This prevented finite optimizer output from
being mistaken for a theorem or a valid numerical result.

**Fisher** separated point finiteness, identifiability, prediction, MSE, and
repeated-sampling inference. Fisher kept ridge in the empirical comparison,
withheld likelihood comparison and interval APIs, and strengthened B2 to use
paired non-inferiority evidence rather than point summaries.

**Curie** specified the immutable ADEMP manifests, attempt ledger, whole-unit
prediction target, paired aggregation, and Totoro sharding. Curie also insisted
that every failure and alternate start remain in the denominators.

**Jason** mapped the relevant GLM, GLMM, factor-analysis, high-dimensional
logistic, and ecology evidence and kept each citation inside its actual theorem
scope.

**Rose** found premature “validated” wording, 0.6/0.7 drift, free-Psi ambiguity,
an incomplete spatial example, screening contradictions, offset-boundary drift,
estimator-unqualified method documentation, and remaining inference surfaces
that bypassed the point-only fence. The current audit is blocked pending those
repairs, completed B2 adjudication, and a final re-audit.

**Grace** owns the remaining exact-source package build/check and 3-OS evidence.
Those final gates have not yet run on the post-B2 source.

## 12. Cross-Product Coverage

This arc covers the estimator-by-link-by-structure product only for opt-in
Laplace MSPL point estimation on complete, single-trial Bernoulli data with
logit, probit, or complementary-log-log links. The candidate structure cells
are ordinary `latent()` and the separately adjudicated `spatial_indep()` and
`spatial_latent()` surfaces, with `q = 1` or `q = 2` where applicable. The B2
campaign crosses these cells with prevalence tail, loading strength, fixed
design dimension, estimator arm, and independent alternate starts; ordinary
and spatial promotion is deliberately cellwise rather than inherited across
providers.

It does NOT cover FIML or response masks, grouped/multi-trial binomial data,
mixed families, nonzero offsets, `q > 2`, ordinary extra random-effect blocks,
predictor-informed latent means, random slopes, `dep()` or standalone ordinary
`indep()`, phylogenetic/animal/kernel providers, VA/AGHQ/Julia integration,
REML, rank selection, tuned penalty strengths, or general inference. It also
does NOT transfer ordinary evidence to spatial structures, logit evidence to
probit/cloglog, point-estimation evidence to Wald/profile/bootstrap coverage,
or finite stationary output to an identifiability or rank-interiority claim.
