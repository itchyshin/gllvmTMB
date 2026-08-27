# After Task: Cross-Family Predictor-Informed Latent Correlations

Status: **PRE-LANDING REPAIRED CANDIDATE.** Candidate
`2350c5d0cd3c0a705a7fc0f1b01be06a19be9eff` passed the Gauss/Emmy and
Rose/Grace reviews, but Noether/Fisher found that its saturated automatic-`Psi`
rank-3 route was over-parameterised. The repaired tree adds the necessary
parameter-dimension guard, preserves specific formula-error priority, narrows
the article to the identified loadings-only rank-3 model, and passes the exact
current-source full package check. All three reviewers must now assess the new
frozen commit before protected landing.

## 1. Goal

Admit one complete-response ordinary unit-tier predictor-informed `latent()`
block across registered native response families, including ranks 2 and 3,
while reporting rotation-invariant cross-trait correlation and predictor
effects. Keep general rank-2/rank-3 recovery and interval calibration partial
unless retained campaign evidence earns stronger wording.

## 2. Implemented

### Mathematical contract

For unit `i`, latent rank `K`, and one numeric unit predictor row `M_i`,

\[
z_i = M_i\alpha + e_i, \qquad e_i \sim N(0, I_K),
\]

\[
\Sigma_{shared}=\Lambda\Lambda^\top, \qquad
\Sigma=\Lambda\Lambda^\top+\Psi, \qquad
B_{lv}=\Lambda\alpha^\top.
\]

`B_lv` and `Sigma_shared` are invariant to a common latent-axis rotation and
are the cross-fit scientific targets. Raw `alpha`, raw `Lambda`, signed axes,
and individual latent scores are not cross-fit acceptance targets.

Registered native family/link rows now compose in one predictor-informed
ordinary unit-tier block. Loadings-only `unique = FALSE` admits ranks through
the number of logical responses. Automatic diagonal `Psi` additionally
requires that rotation-adjusted free loadings plus the diagonal slots actually
estimated by the engine do not exceed the available covariance moments.
Admission remains bounded to complete responses, one untransformed numeric
unit predictor, no fixed RHS, no extra covariance tier, no response mask, no
REML, canonical links, and native TMB. Source-specific terms, Julia
calibration, fixed `X + X_lv`, factors, broader masks, profile/bootstrap, and
structured predictors remain outside this slice.

Gaussian and lognormal observation scales have separate family slots only
when both families coexist. Gaussian uses a raw-response standard deviation;
lognormal uses a log-response standard deviation. Each slot remains shared
within its family. This is not a new per-trait residual-scale model.

The upgraded Tier-1 article fits a five-family loadings-only rank-3 example, shows the same
model in long and wide syntax, extracts cross-family correlations and `B_lv`,
and explains the associational and evidence boundaries. The retained
all-family canary covers native family IDs 0--15 in one rank-3 fit; the
multinomial coupled response is exercised in the five-family fit because its
trial-weight representation is structurally different.

The proposed production recovery campaign remains unrun: 400 planned, 0
started, 0 attempted, and 400 planned-not-started. Two measured pre-run fits
are feasibility checks only. General arbitrary-composition recovery therefore
remains `partial`; no new interval claim was made.

## 4. Files Touched

### Engine and R consumers

- `src/gllvmTMB.cpp`
- `R/lv-predictor.R`
- `R/fit-multi.R`
- `R/gllvmTMB.R`
- `R/predictive-diagnostics.R`
- `R/methods-gllvmTMB.R`
- `R/family-cdf-args.R`
- `R/output-methods.R`
- `R/diagnose.R`
- `R/profile-targets.R`
- `R/brms-sugar.R`

### Tests and developer evidence harness

- `tests/testthat/test-lv-cross-family-predictor-bridge.R`
- `tests/testthat/test-cross-family-lv-recovery-harness.R`
- `tests/testthat/test-mixed-gaussian-lognormal-scale.R`
- `tests/testthat/test-family-cdf-args-1080.R`
- `tests/testthat/test-lv-native-nongaussian-guard.R`
- `tests/testthat/test-lv-mixed-family-first-cell.R`
- `tests/testthat/test-lv-family-boundary-guard.R`
- `tests/testthat/test-lv-parser-guard.R`
- `dev/cross-family-lv-predictor/all-family-canary.R`
- `dev/cross-family-lv-predictor/continuous-scale-canary.R`
- `dev/cross-family-lv-predictor/five-family-canary.R`
- `dev/cross-family-lv-predictor/recovery-campaign.R`
- `dev/cross-family-lv-predictor/summarise-recovery.R`

### Design, evidence, and status

- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/plans/2026-08-27-cross-family-lv-correlation-predictor-ultra-plan.md`
- every file under `docs/dev-log/artifacts/cross-family-lv-predictor/`
- `NEWS.md`

### Reader and generated surfaces

- `vignettes/articles/cross-family-correlations.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/multinomial.Rmd`
- `vignettes/articles/explaining-latent-ecological-axes.Rmd`
- `_pkgdown.yml`
- `man/gllvmTMB.Rd`
- `man/latent.Rd`

### Closeout

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-27-cross-family-lv-predictor-bridge.md`
- `docs/dev-log/plan-actual/2026-08-27-cross-family-lv-predictor-bridge.md`
- `docs/dev-log/handover/2026-08-27-cross-family-lv-predictor-bridge.md`

`README.md`, `ROADMAP.md`, `docs/dev-log/known-limitations.md`, `NAMESPACE`,
`DESCRIPTION`, and the public function signatures were inspected and remain
unchanged. This slice changes admitted composition and an internal likelihood
parameter shape, not the formula spelling or exported API.

## 3a. Decisions and Rejected Alternatives

- **Decision**: compose registered family/link rows instead of maintaining a
  named-family allow-list. **Rationale**: family likelihoods already exist and
  the parser can enforce a finite structural boundary. **Rejected alternative**:
  duplicate another named-family campaign before removing the artificial
  guard. **Confidence**: high.
- **Decision**: use separate Gaussian and lognormal family-scale slots only in
  joint fits. **Rationale**: raw and log response scales cannot share one
  nuisance parameter, while pure-family and within-family sharing are existing
  contracts. **Rejected alternative**: silently retain one joint scale or
  broaden to per-trait observation scales. **Confidence**: high.
- **Decision**: report `B_lv` and `Lambda Lambda^T`, not raw latent axes, across
  fits. **Rationale**: the former are rotation-invariant. **Rejected
  alternative**: accept raw `alpha` or `Lambda` recovery. **Confidence**: high.
- **Decision**: land without the optional Totoro r200 campaign and retain broad
  recovery as partial. **Rationale**: the approved plan distinguishes the
  bounded implementation milestone from claim-bearing campaign evidence, and
  ordered integration should not be fenced indefinitely by optional remote
  work. **Rejected alternative**: imply that two pre-run fits earn recovery, or
  launch remote compute without the exact requested authority. **Confidence**:
  high.
- **Decision**: keep family 16 in its coupled multinomial representation rather
  than forcing it into the scalar all-family stress data. **Rationale**: its
  contrast rows and trial weights are structural, not a scalar-family row.
  **Rejected alternative**: distort the DGP to make one nominal “all family”
  call. **Confidence**: high.

## 5. Checks Run

- Pure construction/helper suites: new bridge 9 pass; family boundary 5 pass;
  native non-Gaussian 26 pass.
- Main fit suites: mixed-scale 21 pass; mixed first-cell 82 pass; family CDF 40
  pass; parser guard 231 pass after one preserved stale-regexp failure; sanity
  multi 65 pass.
- Downstream consumer suites: lognormal, saturation, suppression, simulation,
  proportions, mixed-response unique, matrix-lognormal, and profile-target
  tests passed, with only their declared heavy skips.
- Live continuous-scale canary: two diagnostic/failed attempts were retained;
  the DGP-corrected third attempt passed in 9.21 seconds with separate finite
  scale slots.
- Loadings-only rank-2/rank-3 five-family and all-family route-health fits
  passed. A rank-3 automatic-`Psi` fit also converged, but independent review
  revoked it as evidence because the decomposition was over-parameterised; the
  failed scientific attempt remains in its receipt. The all-family RDS is 924 bytes with SHA-256
  `7ab904...c15` as recorded in its receipt.
- The earlier automatic-`Psi` article render passed numerically in about 2.5
  minutes and produced 92,886 bytes but was superseded by the identifiability
  review. The corrected loadings-only render passed in about 1.5 minutes and
  produced 93,452 bytes; convergence was 0, `pdHess` true, `B_lv` and
  correlations finite, and the intended unsupported ordinal route refused.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: passed with three
  pre-existing aghq S3-tag messages; regenerated both changed Rd files.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed.
- First full `devtools::check(args = "--no-manual")`: failed after 20m44.4s
  because five new campaign-harness tests sourced `dev/` from the built
  package; 15,149 tests passed before the five attributable errors.
- Source harness replay: 19 expectations passed. Synthetic built-package
  absence control: five intentional skips, zero failures.
- Repeated pre-review full check: 20m26.9s, 0 errors, 0 warnings, 3 notes (environmental
  clock, pre-existing `logLik` namespace note, temporary `xcrun_db`).
- First post-identifiability-repair full check: 20m36.8s, four attributable
  failures after 15,143 passes. Three rotation-invariance tests and one
  offset-guard test used unrelated saturated automatic-`Psi` fixtures.
- Focused fixture repair: `test-lv-effects-rotation.R` and
  `test-offset-guard.R` passed 16/16 assertions.
- Final repaired full check: 21m23.1s, 0 errors, 0 warnings, 3 notes
  (environmental clock, pre-existing `logLik` namespace note, temporary
  `xcrun_db`).
- Completion audit moved the dimension gate after formula/design validation so
  typed offset and malformed-formula errors retain priority; the affected
  bridge/parser/offset/rotation/mixed replay passed 341/341 assertions.
- Exact-current-source full check after that move: 20m12.3s, 0 errors, 0
  warnings, 3 notes (environmental clock, pre-existing `logLik` namespace
  note, temporary `xcrun_db`). This is the claim-bearing local package gate.
- `git diff --check 870944744...2350c5d`: passed after Rose/Grace identified
  and the lane removed 10 trailing spaces in four new Markdown records.
- Public register-code test passed. Generated Rd spot checks found zero
  `\\keyword` entries in each changed help file, as intended.

Exact consistency scans and verdicts:

```sh
rg -n 'all families|all registered|arbitrary|recovery|calibrat|per-trait|family-scale|Gaussian.*lognormal|lognormal.*Gaussian' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd man/latent.Rd vignettes/articles/cross-family-correlations.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/multinomial.Rmd vignettes/articles/explaining-latent-ecological-axes.Rmd docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md
# Verdict: touched surfaces consistently separate route health, named retained evidence, family-shared scales, and partial broad recovery/calibration.

rg -n 'raw (`alpha`|`Lambda`)|cross-fit' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd man/latent.Rd vignettes/articles/cross-family-correlations.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/multinomial.Rmd vignettes/articles/explaining-latent-ecological-axes.Rmd docs/design/73-predictor-informed-latent-scores.md
# Verdict: raw axes appear only with warnings/boundaries; B_lv and shared covariance are the cross-fit targets.

rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S|diag\\(U\\)|diag\\(S\\)' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd man/latent.Rd vignettes/articles/cross-family-correlations.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/multinomial.Rmd vignettes/articles/explaining-latent-ecological-axes.Rmd docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md
# Verdict: no stale S/U covariance notation in touched surfaces.

rg -n 'FG-[0-9]+|FAM-[0-9]+|MIX-[0-9]+|LV-[0-9]+|CI-[0-9]+' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd man/latent.Rd vignettes/articles/cross-family-correlations.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/multinomial.Rmd vignettes/articles/explaining-latent-ecological-axes.Rmd
# Verdict: no internal validation row IDs on reader-facing surfaces; dedicated test also passed.

rg -n -C 3 'gllvmTMB\\(' vignettes/articles/cross-family-correlations.Rmd vignettes/articles/covariance-correlation.Rmd vignettes/articles/multinomial.Rmd vignettes/articles/explaining-latent-ecological-axes.Rmd R/gllvmTMB.R
# Verdict: touched long calls name trait explicitly; wide calls use traits() and the same gllvmTMB() entry point.
```

The first attempt at the raw-axis scan incorrectly used shell-interpreted
backticks and exited nonzero; it was retained and rerun with literal-safe
single quotes as shown above.

## 6. Tests of the Tests

- Failure-before-fix: named family/rank guards rejected healthy rank-2/rank-3
  compositions before implementation; the bridge tests would catch restoring
  the artificial allow-list.
- Feature combination: five-family predictor-informed tests combine registered
  response likelihoods, rank 3, `B_lv`, shared covariance, and multinomial
  expansion in one fit.
- Boundary: tests reject ranks above logical responses, over-parameterised
  automatic-`Psi` ranks, noncanonical links,
  explicit extra unit-tier diagonal companions, nonconstant predictors,
  response masks, REML, extra tiers, and malformed multinomial expansion.
- Failure-before-fix: unequal Gaussian/lognormal scales exposed the one-slot
  likelihood defect; consumer tests would catch incorrect slot selection in
  prediction, simulation, CDF residuals, variance partitioning, diagnostics,
  or profile labels.
- Failure-before-fix: the first full package check demonstrated that a
  source-relative `dev/` test fails in a built package. The repaired test both
  executes 19 source expectations and cleanly skips five developer-only tests
  when the harness is absent.
- Prophylactic: the immutable r200 harness freezes seed bijection, source pin,
  no-overwrite attempt records, and planned/started denominator reconciliation;
  the production campaign itself was not run.

## 8. Consistency Audit

The reader story, generated help, NEWS, Designs 01/03/61/73, and validation
register agree: composition and route health are admitted; existing named
rank-1 evidence remains valid; arbitrary rank-2/rank-3 recovery and intervals
remain partial. `LV-06`, `LV-07`, and `LV-08` remain blocked. No exported
signature, NAMESPACE, package dependency, or formula spelling changed.

The project-local Rose pre-publish checklist contains stale references to a
“4 x 5” grid and public register IDs. The current `AGENTS.md` overrides those
points: the canonical surface is a 5 x 3 source-by-mode grid, and reader-facing
surfaces state plain-language boundaries without internal row IDs. The audit
used the current contract.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed. The internal validation rows `FG-18` and
`LV-05` remain `partial`; this is a bounded implementation/status slice, not an
umbrella milestone promotion.

## 7a. Issue Ledger

Open issues were searched for `latent predictor family correlation` and
`predictor-informed LV`. Issue #945 concerns per-row family changes within one
trait and is not the complete-response one-family-per-logical-response route
implemented here. Issue #941 concerns multi-source integrated biodiversity
data and is also outside scope. No relevant issue was closed or created, and
no external comment was needed.

## 9. What Did Not Go Smoothly

The first continuous fixture lacked shared innovation and produced a singular
fit; the failed attempt was retained and the DGP, not the estimator, was
corrected. A parser test contained a stale error regexp. The campaign harness
needed two local contract repairs before its focused test passed, then the full
package check exposed the additional source-tarball path defect. The first
consistency scan also contained shell-interpreted backticks. Rose/Grace found
10 trailing spaces because the earlier whitespace check covered only the last
commit rather than the full base-to-candidate diff. Every failure is recorded;
none was silently tuned away.

## 11. Team Learning

**Ada** kept the route finite: implementation admission, route health, and
claim-bearing recovery were treated as separate gates. The reusable lesson is
to land an honest partial capability instead of making optional remote compute
an indefinite integration lock.

**Gauss and Emmy** found that Gaussian and lognormal cannot share an observation
scale across their different measurement scales, then verified the exact
family-slot shape and every downstream consumer. They also protected the
existing within-family sharing contract from accidental per-trait broadening.

**Noether and Fisher** required `B_lv` and shared covariance as the scientific
targets, logical-response rank accounting, explicit all-attempt denominators,
and no transfer from named rank-1 evidence to arbitrary compositions. Their
first exact-candidate review failed the saturated automatic-`Psi` rank-3 route;
the resulting dimension guard and claim repair require a fresh exact-head
review.

**Boole and Pat** shaped the Tier-1 article around a biological question, early
long/wide calls, interpretable predictor effects, and a plain-language boundary
box rather than internal status codes.

**Rose and Grace** caught the built-package-only test-path failure and the full
base-diff trailing whitespace that narrower checks missed. They verified the
unrun production denominator and required exact-head CI before any landing
claim.

**Jason** reconciled prior GLLVM.jl and gllvmTMB evidence so this lane did not
repeat the 3,800/4,000-attempt family campaigns or borrow unsupported bridge
calibration.

## 10. Known Residuals

- General rank-2/rank-3 arbitrary-composition recovery is unearned: 400
  production attempts remain planned-not-started.
- Within-family Gaussian or lognormal traits share one observation scale; data
  with materially different units inside one family may require rescaling or a
  different model.
- Broad masks, missing LV predictors, factor intervals, fixed `X + X_lv`, REML,
  noncanonical links, extra tiers, structured sources, Julia calibration,
  profile/bootstrap, and correlation intervals remain outside scope.
- The immediate next action is protected PR CI on Ubuntu, macOS, and Windows,
  normal merge, exact-main verification, and lease release. The fixed-rho
  `phylo_coef()` lane may then rebase once and begin TDD.
- Any future R200 campaign starts as a fresh evidence task from the exact
  `1cb4d33a...` source pin or writes a new measured pre-run receipt.

## 12. Cross-Product Coverage

This task changes only the native `gllvmTMB` ordinary unit-tier route. It
**does NOT cover** structured-source or extra-tier LV predictors, REML,
fixed-effect `X + X_lv`, response masks, missing or factor LV predictors,
profile/bootstrap inference, calibrated arbitrary-composition intervals, or
per-trait observation scales within one family. The
existing R-to-Julia bridge remains a separate complete-response loadings-only
point route with optional uncalibrated Wald plumbing; no Julia profile,
bootstrap, calibration, or mixed-family interval claim follows. `GLLVM.jl` was
used only through source-pinned historical evidence and was not edited or run.
No `drmTMB`, `DRM.jl`, sister-package API, remote compute artifact, public
release, or CRAN surface changed. The fixed-rho `phylo_coef()` programme is a
separate coefficient-engine task and remains fenced until this lane lands and
releases its two shared R paths.
