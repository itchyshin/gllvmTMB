# Tree-axis article correction: numerical-gate checkpoint

Date: 2026-08-30. Status: **INCOMPLETE; community optimizer gate failed**.
No corrected article has been published or claimed complete. The approved BFGS
follow-up also failed: it returned an impossible objective and was stopped.
Section 14 records the latest evidence and remaining scope decision.

## 1. Goal

Correct both worked models in `where-does-the-tree-go`: add ordinary species
latent covariance alongside phylogenetic morphology covariance; retain the
community coefficient comparison and add ordinary site residual covariance.
The reviewed Ultra Plan was explicitly approved before implementation.

## 2. Implemented

### Mathematical contract

No public R API, likelihood, formula grammar, family or NAMESPACE changes.
Morphology has one observation for each of six traits in 80 species, with
species-level fixed elevation effects and two rank-two covariance sources:
`A %x% (Lambda_phy Lambda_phy^T + Psi_phy)` and
`I %x% (Lambda_non Lambda_non^T + Psi_non)` under species-major stacking.
Both diagonal companions are estimated. The ordinary per-cell diagonal absorbs
independent Gaussian variation; the separate observation scale is mapped off
and fixed to the existing numerical stabilizer.

The community fixture has 150 sites and 50 species, pathway fixed means/slopes,
IID versus phylogenetic species intercept/slope deviations, and rank-two site
covariance with its own diagonal. The coefficient mixture is
`rho K + (1-rho) diag(diag(K))`, not residual site association. Residual
association does not establish direct ecological interactions.

## 3a. Decisions and Rejected Alternatives

Retain both rank-two species sources and their diagonal companions; do not add
population replication. Keep the coefficient comparison plus site covariance.
Use actual internal optimizer attempts rather than ineffective single-start
jitter. Reject seed hunting, lowering the convergence requirement, and selecting
only successful starts. No rank-one sensitivity fits or inference campaign.

## 4. Files Touched

- `vignettes/articles/where-does-the-tree-go.Rmd`: article correction in progress;
  no render or publication admitted at this checkpoint.
- `dev/tree-axis-latent/fixture.R`: frozen seeds, matrices, data and formulas.
- `dev/tree-axis-latent/run-fit.R`: bounded-ID runner with retained actual
  optimizer attempts and covariance snapshots; no engine modifications.
- `dev/tree-axis-latent/check-article.R`: no-fit exact DGP, public argument,
  extractor and morphology plot checks against saved receipts.
- `dev/tree-axis-latent/validate.R`: fail-closed post-processing and negative
  controls; it does not refit models.
- `dev/tree-axis-latent/evidence/2026-08-30-validation.json`: compact evidence.
- `docs/dev-log/plans/2026-08-30-tree-axis-latent.md`: approved plan and receipts.
- This report and additive `docs/dev-log/check-log.md` checkpoint.
- Ignored `.unlazy/tree-axis-latent/`: acceptance ledger and continuation state.

Raw receipts, frozen executed scripts, install log, source hashes and session
information are retained at `/private/tmp/gllvm-tree-axis-latent-20260830/`.
The installed package is isolated under that directory's `library/`.
No README, NEWS, ROADMAP, design-register, roxygen or generated Rd edits are
needed for the current incomplete phase; none is claimed updated.

## 5. Checks Run

- `git fetch origin main codex/tree-axis-latent-handover-20260830`: main verified
  at `9c265e76b54ea0f238d5487066964dd81e897f65`; handover at `739213bfd`.
- Source `R CMD INSTALL --preclean --no-multiarch` into isolated library:
  passed in 84.574 seconds; four compiler warnings retained in `install.log`.
- Fixture construction: canaries 20 species x 6 traits and 50 sites x 20
  species; targets 80 x 6 and 150 x 50. All three loading matrices have rank 2.
- Engine/source covariance agreement: maximum errors `2.76e-11` and
  `2.69e-12`. The normalized source design has rank 2 and condition numbers
  1.278 and 1.341. This is algebraic compatibility, not recovery evidence.
- `testthat::test_file("tests/testthat/test-phylo-tree-precision.R",
  reporter="summary", stop_on_failure=TRUE)`: 21 assertions passed.
- C1/C2: optimizer convergence zero, maximum gradients `1.86e-5` and
  `1.76e-4`; fitting times 0.787 and 1.464 seconds. Both Gaussian scale maps
  and fixed values passed. Shared-plus-diagonal identities hold to `1.1e-16`.
- M1: all three optimizer attempts pass. Relative objective spread
  `6.11e-11`; largest component relative difference 1.90%, below 10%.
- M2: convergence codes `(1,1,0)`, with two `false convergence (8)` stops.
  All gradients are below 0.002; objective spread `4.19e-11`, largest covariance
  difference `6.95e-5`. **Fails the all-three-code-zero gate.**
- M3: convergence codes `(0,0,1)`, with one `false convergence (8)` stop.
  All gradients are below 0.003; objective spread `8.55e-10`, largest covariance
  difference `1.11e-5`. **Fails the all-three-code-zero gate.**
- W1: morphology long/wide objective difference `6.11e-11`; fitted difference
  `2.97e-11` response SD. Passed.
- `validate.R --self-test`: rejects corrupt gradient, decomposition and fixture
  provenance against the positive C1 control. Passed without fits.
- `pkgdown::check_pkgdown()`: passed, no problems found.
- `validate.R` correctly exits 1 for the failed community gates. W2/W3 remain
  unrun; the article render, full package check and CI are not claimed passed.

The fixed budget used **12 optimizer attempts in six model calls**. S1-S6
identify the second/third attempts inside the M calls; they are evidence aliases,
not extra fits. The remaining two wide calls are held. No failures were dropped,
no thresholds changed, and no seeds or models changed after fitting.

## 6. Tests of the Tests

The validator's positive canary passes; modified copies with a gradient above
the unchanged screen, a corrupted diagonal decomposition, and a wrong fixture
checksum each fail. Actual community stopping-code failures also produce a
red ledger rather than a success token. Additional saved-object negative
controls reject a perturbed restart covariance and duplicate wide-data keys. The optimizer tracing is process-local,
blocks an attempt beyond each call's quota, and reconstructs each report using
the package's own TMB evaluation sequence. Reconstructed selected covariances
must agree with the returned fit before any stability comparison is accepted.

## 7. Roadmap Tick and Design Docs

No design contract or roadmap row is changed. Existing coefficient scope remains
partial (FG-20); this incomplete composition example is not new recovery evidence.
No validation-register status has been promoted.

### pkgdown and publication

Metadata passes. Full article rendering is held at the failed scientific gate;
it would execute additional community fits. No push, PR update, CI dispatch,
merge or deployment has occurred. PR1229 remains the protected draft handover.
Its earlier Ubuntu success is not evidence for this correction or three OSes.

## 7a. Issue Ledger

PR1229 and the six older open PRs were inspected for ownership. No issue/PR was
created, commented on, closed or merged. Ayumi's earlier issue was precedent
for the requested model structure, not authority to run its analyses.

## 8. Consistency Audit

The final source review permits retention as an explicitly incomplete draft,
not publication. `check-article.R` independently passes exact equality of the
whole article fixture to the frozen fixture, all six public call signatures,
and saved-M1 public outputs/plots. The two morphology/axis figures were visually
inspected from a no-fit PDF. Community plots remain unrendered; full HTML/mobile
layout and figure review are pending. The exact scans are in the check-log. No new package capability or empirical
recovery claim is admitted from this phase. The tree-axis distinction, Gaussian
scope, single species observation, and separation of coefficient covariance
from residual association remain protected. Exact stale-wording scan results
will be appended after the source draft is complete.

## 9. What Did Not Go Smoothly

Before freezing, review caught invalid diagonal construction, a zero-matrix
Cholesky, overlapping seeds, and rank-one site loadings. These were repaired
before any fit. The proposed `n_init=1` jitter was ineffective; actual distinct
starts use the supported `n_init=3` route with separate retained attempt records.

The first canary runner incorrectly coerced the data-frame `fitted()` result to
numeric. Original receipts were preserved; public outputs were repaired from
saved objects without refitting, in separate MD5-bound artifacts. Passing a full
parameter vector to `parList()` also produced a warning; no-argument extraction
reads the fixed Gaussian scale correctly. Subsequent runner receipts use both
correct public/extraction contracts.

The first article draft hand-copied the simulation incorrectly (including an
IID diagonal where the phylogenetic diagonal must follow A), changed predictor
scaling, hid all required helpers, and passed unsupported top-level `se=FALSE`.
Root rejected that draft before rendering or fitting; the current source embeds
the frozen construction visibly and uses `control=gllvmTMBcontrol(se=FALSE)`.
The independently executed no-fit check verifies exact full fixture equality
and public argument matching. These source defects did not alter the fitted
fixture or trigger another fit.

The community optimization flags remain unresolved. Low gradients and stable
covariances do not erase the explicitly approved convergence gate.

## 10. Known Residuals

M1's estimated phylogenetic diagonal is near zero despite positive planted
values. M3's estimated rho is about `2.35e-7`, close to the IID endpoint, despite
planted rho 0.60; the IID/phylogenetic NLL difference is only `4.41e-7`.
These are one-realization point estimates, not recovery evidence. With `se=FALSE`,
Hessian/uncertainty evidence is unavailable, not a failed Hessian test.

## 11. Team Learning

**Gauss/Noether/Fisher** verified the tree source scale, additive composition,
Gaussian map, and valid report reconstruction for each optimizer attempt. They
rejected an interpretation of the community failure as proof the model is
mathematically unsupported. They recommended a separately approved BFGS
adjudication with unchanged data, model and numerical gates.

**Darwin/Pat** kept the response matrix and biological questions central: no
within-species interpretation, no causal reading of site residual association,
and no universal empirical C3/C4 latitude trend from a synthetic fixture.

**Rose** required actual failing acceptance checks, explicit fit counts, public
extractor routes, and separate Ubuntu versus three-OS versus deployed-page
status. Root verification found and corrected harness defects before admitting
its results. Rose/Pat's final delta review found no source blocker to the incomplete
checkpoint. Their residual-matrix label and one-realization qualifier comments
were addressed. Species trajectories in the held third figure are explicitly
planted, not fitted random-effect modes: the public API supplies coefficient
covariance but not those individual modes. Full rendered figure/prose review
remains pending.

## 12. Cross-Product Coverage

This phase checks native Gaussian ML with both species covariance sources and
coefficient-plus-site covariance on two frozen designs. It does NOT cover
non-Gaussian coefficient models, mixed families, spatial sources, Julia,
REML/MSPL, uncertainty calibration, recovery across replicates, or deployment.
No new likelihood/family/keyword/estimator was implemented, so a new recovery
campaign is neither required nor authorized for this article correction.

## 13. Next action and approval boundary

The bounded source draft and no-fit checks are retained. Recommend
exactly six additional optimizer attempts: the two community models each with
three BFGS starts through supported `optimizer="optim"` and
`optArgs=list(method="BFGS")`, preserving the fixture, jitter, seeds, ML target
and all acceptance thresholds. The current nlminb calls took 60.9 and 137.2
seconds; BFGS runtime is unknown, so propose a five-minute cap per model call.
This requires explicit approval because it exceeds the agreed attempt budget.
It can address the stopping-code issue, not certify rho recovery or precision.
No such follow-up has been launched. Later landing also retains its explicit
approval gate.

## 14. Approved BFGS follow-up and numerical stop

Shinichi approved six further attempts and automatic continuation if they pass.
Before starting, Gauss/Noether checked the supported BFGS route and trace
normalization, and a no-fit quadratic unit test verified unchanged raw returns,
exact entry starts and the three-call cap. B2 was estimated at 1-5 minutes and
run with a 300-second external cap.

B2 attempt 1 returned code zero and NLL `-5.34842345053399e29`. For this exact
Gaussian marginal, covariance `V >= sigma_eps^2 I` implies NLL at least
`7500 * (log(0.0008459331) + log(2*pi)/2) = -46,170.9882`. The result violates
a mathematical bound; it is not a better fit, a rho boundary, or a biological
finding. Finite parameters reached absolute magnitudes of 46.46. Root stopped
the verified B2 process group during attempt 2 after 76.514 seconds. B3 and the
wide fits were not launched. No numerical threshold, seed or model changed.

The retained per-attempt files prove two starts entered, one returned, and one
was interrupted. Both starts match the corresponding original M2 starts exactly.
A terminal coordinator receipt records the interruption with `fit=NULL`; no
completed B2 fit is invented. Across this task 14 outer optimizer attempts have
entered: the earlier 12 plus these two. Four approved BFGS attempts and two
original wide attempts remain unstarted, but the numerical stop gate takes
precedence over spending that remainder.

The validator retains original M2/M3 failures separately from new primary
B2/B3 evidence. Missing or failed BFGS results cannot inherit their selected
fits. It now also rejects an objective violating the Gaussian lower bound;
that additional negative control passes. The overall ledger correctly fails.

Method review advises stopping further fits and any community interpretation.
A separate, bounded numerical investigation is the next consequential choice;
no new engine/API or campaign is implied. Neither dropping the second example
nor relaxing its gates counts as completing the approved two-example goal.
No publication, PR change, CI dispatch, merge or deployment occurred.

A final no-fit diagnostic, `dev/tree-axis-latent/check-gaussian-likelihood.R`,
checks the original M2/M3 objectives independently. For site-major stacking,
`V = I_n (x) R + (X Sigma_b X^T) (x) K`, with fitted
`R = Sigma_site + sigma_eps^2 I_p`. Whitening R and diagonalizing the two
remaining factors evaluates the Gaussian determinant and quadratic form
without a TMB objective call or any optimization. Gauss/Noether verified the
algebra and ordering requirements. Oracle-minus-retained NLL differences are
`1.370699e-8` and `-2.982233e-9`; no new acceptance threshold is introduced.
This supports the original objective's interpretation while leaving its
convergence gate unresolved. The full two-example delivery still requires a
separately authorized numerical-debugging step before more article fits.
