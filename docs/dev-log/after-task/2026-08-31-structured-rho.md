# Structured source strength: implementation and evidence checkpoint

**Status:** local candidate acceptance, 2026-08-31. The final scoped documentation-repair audit is recorded separately; this is not merge or release readiness.
**Branch:** `codex/structured-term-rho-20260831`, worktree `87fa`.
**Ownership:** root is the only implementation writer. Specialist reviews were
bounded and read-only. The final independent panel reviewed candidate
`db68f7732`: two Terra-high reviewers and one Sol-high mathematical reviewer.
The later package delta is exactly three roxygen paragraphs and their Rd text,
with identical executable R expressions and separate validation.

## 1. Goal

Complete the approved fixed-plus-estimated structured-rho arc in
`dev/structured-rho/PLAN.md`, preserving ordinary components, resolved source
scales and coefficient defaults. Fixed support alone does not close the goal.
No push, merge, release, version bump, publication or other-repository edits
are authorized. The frozen recovery study and approved extra package check are complete.
Independent reviews found no unresolved numerical or API defect.

## 2. Implemented

Canonical phylo, animal, kernel and spatial indep/dep/latent helpers accept a trailing
`rho = 1`. Numeric values fix source strength; `NULL` estimates it in admitted
replicated multivariate Gaussian models. Omitted and explicit one preserve the
legacy route, including multi-kernel models. Spatial range remains separately estimated.
Deprecated aliases retain old calls but give canonical replacements for new
attenuation. New attenuation admits one structured trait-intercept block;
folded latent Psi shares its source strength. No terms or ranks are removed.

Simulation redraws the full attenuated source covariance. Known-level prediction
uses the same contribution. `extract_Sigma()` preserves its existing fields and
adds source-strength metadata without materializing a large dense covariance.
Old source-allocation summaries and unsafe refit/interval routes give typed
limitations. Existing supported endpoint simulation is unchanged; previously
unsupported endpoint folded-Psi simulation and known-level prediction now work.

Estimated rho requires native Gaussian ML, at least two traits, complete
replicate vectors, at least two vectors per source group, every modeled group
observed, positive source diagonals and observed between-group contrast. It
retains observation residual variance and rejects competing/unproved covariance
configurations. Estimated latent models require rank one and at least four
traits. Boundary scores and weak-loading flags are descriptive diagnostics,
not identification proofs or confidence intervals.

## 3. Mathematical Contract

For the legacy-resolved marginal source covariance K, including existing scale
and conditioning, D = diag(diag(K)) and K_rho = rho K + (1-rho)D. The complete
source trait covariance is K_rho tensor (Lambda Lambda' + Psi). Ordinary random
components and Gaussian observation residuals remain separate.

| Mathematical quantity | Implementation | Interpretation |
| --- | --- | --- |
| K and D | Legacy source resolver; selected inverse of full sparse Q | Preserve modeled labels and marginal variances, including retained ancestors |
| Dense K_rho | Mixture before precision/determinant; spectral form for estimation | No new normalization |
| Sparse source score | sqrt(rho) g_aug[j] + sqrt(1-rho) sqrt(D[j]) e[j] | IID scores live on modeled source levels; replication follows afterward |
| rho = logistic(eta) | Separate `eta_structured_rho`, initialized at zero | Start at .5 independently of simulation truth; coefficient rho is untouched |
| Lambda Lambda' + Psi | Both fields and both components share rho | Source attenuation does not remove trait variance components |

At fixed zero or one, inactive fields and their priors are mapped off. Stable
square-root logistic weights avoid loss of the complementary field near a
boundary. The common-variance propto route keeps its legacy resolution.

When D = I, the identity

K_rho tensor S + I tensor T = K_rho' tensor [(rho/rho') S]
+ I tensor [T + (1-rho/rho') S]

holds whenever the alternatives are admissible. Thus successful optimization
does not identify free rho alongside unrestricted ordinary covariance on the
same units. Separating sources and separating Lambda from Psi are different
questions. A triangular loading convention does not settle the latter.

## 3a. Decisions and Rejected Alternatives

Do not reuse coefficient-rho storage or add arbitrary multi-source estimation.
Do not replace marginal covariance by inverse tip-only precision or reciprocal
precision diagonals. Do not silently reroute common variance through a different
source scale. New attenuation is fenced before Julia, VA, MSPL, AGHQ and
augmented-slope dispatch. No rho intervals or new spatial allocation definitions
are introduced. The immutable retained-study estimator has not been replaced
following the pilot: later interval and single-trait guards do not change its
six-trait admitted fits.

## 4. Files Touched

The complete path/hash/size inventory is `dev/structured-rho/changed-files.csv`;
raw ignored datasets and full check directories stay local. Individual gate
receipts record the source and installed-package versions actually used.

Implementation: `R/structured-rho.R`, `R/structured-rho-spatial.R`, `R/brms-sugar.R`, `R/animal-keyword.R`,
`R/kernel-keywords.R`, `R/gllvmTMB.R`, `R/fit-multi.R`, `src/gllvmTMB.cpp`,
`R/methods-gllvmTMB.R`, `R/extract-sigma.R`, `R/extract-omega.R`,
`R/output-methods.R`, `R/bootstrap-sigma.R`, `R/loading-ci-bootstrap.R`,
`R/extract-two-psi-cross-check.R`, `R/profile-ci.R`, `R/profile-derived.R`,
`R/phylo-signal-ci.R`. Tests include the structured-rho helpers and ten test files,
plus the explicitly activated package-check counting helper.

Design/status files: `AGENTS.md`, `CLAUDE.md`, formula grammar, likelihood and
extractor contracts, validation-debt register, this report and check-log.
`dev/structured-rho/` holds the approved plan, math, gates, independent runners,
frozen manifests, separate attempt ledger, pilot report and retained evidence.
The ignored `.unlazy/structured-rho/GATES.md` mirrors the tracked gate ledger.

Generated help: animal_dep, animal_indep, animal_latent, kernel_latent,
phylo_dep, phylo_indep, phylo_latent, spatial_dep, spatial_indep, spatial_latent,
bootstrap_Sigma, extract_Sigma, extract_phylo_signal, extract_proportions,
simulate.gllvmTMB_multi, predict.gllvmTMB_multi, VP, tmbprofile_wrapper and
profile_ci_phylo_signal. Each name denotes its `man/*.Rd` file.

Example cascade: the new `vignettes/articles/structured-source-strength.Rmd`
and existing `vignettes/articles/api-keyword-grid.Rmd` are the only article
files changed. `_pkgdown.yml` adds navigation; NEWS adds an unreleased scope
entry. Roxygen parameter/description changes and generated help agree. README,
ROADMAP, `docs/design/00-vision.md` and known-limitations were scanned and needed
no structured-rho correction. The closed where-does-the-tree-go,
covariance-correlation, cross-family-correlations and spatial-models articles
remain untouched. Coefficient defaults and unrelated softmax wording are intact.

## 5. Checks Run

Exact commands, expected markers, candidate hashes, exit codes and logs are in
`dev/structured-rho/evidence/` and the tracked GATES.md. The scoped oracles used
`install-spatial-sparse-02` (21.050 seconds), following the sparse spatial compile
in 83.291 seconds. The complete final regression check built candidate db68f7732.
Its later help-only repair is documented below; no repaired full-check pass is claimed.

| Evidence | Outcome |
| --- | --- |
| Pure admission and covariance contracts | Estimation contract passes 15 assertions, including unused groups, replication and two-trait minimum; parser/covariance contract passes 67 |
| Independent Gaussian marginal likelihood | 60 fixed and 100 estimated parameter points; covariance, maps and numerical gradients pass, including common variance, ancestors, unit_obs and long/wide NULL |
| Workflow | 221 assertions; whole-Psi simulation covariance, known-level prediction, metadata and typed limitations pass |
| Ordinary components / exclusions | 18 assertions; fixed ordinary components preserved and unsupported augmented slopes rejected |
| Family equivalence | 1,116 evaluated points and 24 preserved legacy rejections; 5,628 assertions across endpoints and native family/source/form combinations |
| Legacy compatibility | 14 baseline/omitted/one cases match active payloads, maps, parameters, gradients, likelihood, covariance, fitted output and supported seeded simulation |
| Actual engineering fits | Fifteen attempts: original7 plus8 spatial. All returned fits meet numerical criteria; the8 spatial JSON wrappers failed after saving valid RDS, retained and checked without refitting |
| Interval limitations | Eight assertions, including the direct phylogenetic-signal interval bypass; no profile or fit executed |
| Frozen study metrics | 12 source/form resolutions and independent dense observation-covariance error checks pass |
| Teaching | Five article renders,22 fits total; latest phylogenetic plus spatial long/wide render passes in 21.987 seconds with 6 optimizer calls, all convergence zero. Grid render uses zero fits |
| First full local check | Exit zero in 1,533.295 seconds; no errors or package-check warnings, three notes. Testthat: 22,558 passes, 54 warnings, 1,190 skips |
| Original repair check | Failed after 238.255 seconds in metadata checking because counting startup printed messages. Build/install passed; tests did not run |
| Approved extra full check | Exit0 in 1456.340 seconds:0 errors,1 Rd-link warning,3 notes; testthat FAIL0/WARN54/SKIP1190/PASS23875. All3908 optimizer entries counted |
| Scoped documentation repair | Three roxygen paragraphs and three generated spatial Rd files; actual cross-reference check has zero unresolved links, exact usage/parameter delta, identical parsed R code. rd-repair-02 passes in 2.048 seconds |

Tolerances were fixed before outcomes: pure covariance 1e-12, scaled Gaussian
NLL 1e-8, finite-difference gradient 2e-5 (step 1e-5); family NLL 1e-7,
gradient 2e-5 and predictor 1e-6; simulation covariance six Monte Carlo SEs.
No tolerance was relaxed to obtain a pass. Point-object checks replace outer
optimization with one objective evaluation and are not recovery fits.

Budgets spent: pre-run12/12; engineering15/192; retained2400/2400; teaching
22/24. Both originally allowed full-check runs are spent. The maintainer
explicitly approved one extra full check, hard1800 seconds; it completed in
1456.340 seconds. Regression counting is separate: pass01 logged3889 test
optimizer entries with build/example counts unmeasured; repair01 logged two
build-vignette entries. The fixed logger passed the actual metadata validator
with exact expected stdout, empty stderr and zero optimizer calls. The final
full run records 3908 optimizer entries:3889 tests,15 examples and 4 vignette
build/rebuild calls. No fits were rerun for the help-only repair.

The24-attempt pilot took 34.408 seconds. After measured approval, all 2376
remaining frozen attempts returned in 982.008 seconds on Totoro,12 workers,
BLAS one. Across2400 attempts,2248 met the numerical rule and 152 exceeded
maximum gradient .01. All returned with convergence zero, PD Hessians and
one optimizer entry; no timeout, restart, missing result or substituted seed.
Raw archive SHA256 is85b5821e455695de39f76aad0ffae9ffd565abe11b02bfd3a983f35ddc38e3d3.
Local raw evidence and the remote task store preserve every result. The
supplemental remainder launcher was outside the pilot bundle; its executing
hash is retained and matches the reviewed transferred script. Frozen package,
fit script and fixtures were checked unchanged before launch.

Fisher's source/mode verdict is retained in reviews/fisher-retained-20260831.md:
bounded passes for animal dep and kernel indep/dep/latent-plus-Psi; partial for
the other eight source/mode regimes. Phylogenetic downward bias, loadings-only
variability, conditional-success summaries and failure denominators remain
explicit. No spatial recovery, interval calibration or loading/Psi-separation
recovery follows from this campaign.

Spatial source verification adds184 assertions, including 42 independent
Gaussian likelihood/joint-gradient points, unequal Psi, near endpoints,
geometry controls, simulation covariance and long/wide parity. Fixed-family
spatial comparison adds1128 assertions. The likelihood retains sparse
projections and computes location diagonals with sparse solves; descriptive
geometry uses at most64 locations. Ancillary diagnostic failures are reported
without discarding fits. At rho zero, kappa remains in D(kappa) and a range/scale
confounding warning is attached.

## 6. Tests of the Tests

Independent controls detect whole-Psi omission, reciprocal-precision diagonal
mistakes, conditioning on retained ancestors, and the ordinary-covariance
non-identification identity. Public negative tests exposed NULL deletion by a
shared formula walker, unused-source contrast, alternate-dispatch bypasses,
unsupported augmented slopes, the raw-rho profile route, the direct signal-CI
route and the missing two-trait minimum. Each repaired defect has a retained
red/green record. Complex rho already failed correctly; its added test did not
justify an implementation change, and the redundant attempted change was removed.

Prelaunch review caught an absent residual-SD field in the study metric that
would have silently produced zero covariance error. Scalar validation and an
independent dense covariance calculation now protect the metric. Harness-only
failures included unsupported testthat arguments, wrong sparse-source routing
assumptions and a checker subtracting fitted data frames; these were corrected
without refitting, changing seeds or loosening tolerances.

## 7. Roadmap Tick

N/A. No roadmap status or version changed. This arc closes at the locally
validated candidate required by the approved plan. STR-RHO-FIX and
STR-RHO-WORKFLOW have local software coverage; STR-RHO-EST and STR-RHO-SPA
remain partial for recovery. Main integration and three-OS CI from the
package-wide Definition of Done are explicitly subsequent landing requirements,
outside this authorization.

## 7a. Issue Ledger

Ownership census inspected PRs 1209, 1198, 1077, 1070, 1065 and 981. None was
changed or commented on. The six-hour all-ref history showed this lane's checkpoints; the sole active lease is `codex:structured-rho-87fa`. Older refs
contain unrelated register/grid work; their diffs were read before updating
only this lane's rho entries. No duplicate design number was allocated.
No new issue or PR was created; the user's explicit plan defines this work.

## 8. Consistency Audit

The keyword grid remains five sources by three modes; scalar and unique remain
modifiers. Coefficient defaults remain phylo/kernel NULL and animal/spatial one.
The article presents ordinary variance separately from source strength, uses
`condition_on_RE = FALSE`, and shows both long and `traits(...)` wide calls.
Its estimate near .34 from generating .6 is explicitly not a recovery claim.
Following the maintainer clarification, the article distinguishes flexible
phylogenetic/non-phylogenetic covariance components from the proportional
components in the single-rho mixture. Source rho one is not variance share one.
The subsequently supplied PDF was read; TUTORIAL-READING.md records its range/attenuation distinction. The maintainer then explicitly approved uniform spatial attenuation; SPATIAL-ADDENDUM.md records that scope change. Coefficient defaults remain unchanged.
Source metadata and typed limitations are synchronized with help and contracts.

Exact scans and outcomes are in check-log. Source, documentation and script
whitespace checks pass. Raw retained logs and rendered HTML keep their original
trailing whitespace and hashes; a whole-artifact whitespace pass is not claimed. The first
check's unqualified logLik note is present in baseline methods-gllvmTMB.R:2914;
the other notes concern time verification and xcrun temporary detritus. Test
warnings and skips remain visible. No three-OS or publication check is claimed.
Report shape is checked separately from scientific acceptance. All eight
parent gates now have retained evidence and named review; shape alone did not
close them.

## 9. What Did Not Go Smoothly

All 12 pre-run fits returned, but macOS memory collection failed and the wrapper
statuses remain failures. Four estimated strengths were near zero in the frozen
40-tip regime. Independent likelihood and physical-score checks support the
boundary behavior; they do not turn weak recovery into success. No seeds or
models were replaced. The pilot also retains its single numerical failure.

Package-check accounting caused two distinct mistakes: rcmdcheck cleared the
first runner's R_TESTS, leaving example counts unmeasured; explicitly restoring
startup then exposed trace messages to metadata checking. R's example cleanup
also deletes global variables. The logger now lives in options and installs
silently. A versioned amendment was made during the repair build before any
example process; no process was restarted. The full repair still failed on the
message issue, and its allowance is spent. The original receipts and noisy
startup versions are retained. The extra full check completed within its approved ceiling.

## 10. Known Residuals

The original common-propto extractor limitation at rho one remains unchanged.
Spatial prediction supports known locations only. The completed frozen spatial
study classifies 14 estimated-rho cells as partial and two irregular-long,
rho=0.3 cells as blocked; no cell passes the joint rho/range recovery gate.
This does not establish universal non-identifiability, but it rules out a broad
spatial recovery claim. Rho intervals remain unsupported. All authorized
campaign work is complete.

The full check on db68f7732 retained one warning for three malformed Rd links.
The exact help-only repair passes the actual cross-reference validator and
source/help synchronization checks. Executable R, TMB, tests and examples did
not change. No package install/example/test rerun followed that delta; Rose
accepted this explicitly bounded documentation exception. The three notes
(time verification, pre-existing unqualified logLik and xcrun detritus) remain.
This is a locally validated candidate, not an exact-repaired full-check pass,
three-OS proof, merge, publication or release. No new compute is requested.

## 11. Team Learning

**Ada/root:** source resolution and downstream behavior needed one owner across
R and TMB. Keep source/package hash dependencies explicit and preserve budget
categories. The check instrumentation should have been exercised against R's
actual metadata and example drivers before spending a full repair run.

**Gauss/Noether:** bounded Sol-high review checked dense spectral and sparse
augmented math. It found unused-level contrast, unit_obs alignment, stable
boundary weights, augmented-slope admission and the study residual-field issue.
Generic rank-one identification does not imply good finite-sample recovery.

**Boole/Pat:** bounded Terra-high review found alias/walker/dispatch bypasses,
refit losses, interval exposure and the ignored simulation argument spelling.
It reviewed pilot deadlines/provenance and the new teaching path. The initial
counting review inspected repository cleanup only; runtime R cleanup and
startup output also required direct tests. The option-backed logger lifetime
was subsequently re-reviewed, without fits or edits by the reviewer.

**Downstream inventory:** Luna-medium read-only inspection mapped consumers and
old tests; it was not a final mathematical or candidate review. No unengaged
specialist is credited with signoff. The final panel receipts are
reviews/final-math-20260831.md, final-api-20260831.md and final-audit-20260831.md.
The API reviewer withdrew an initial commit-label objection after checking
file hashes; tested uncommitted bytes were preserved in receipt manifests.
Rose found the Rd links and accepted the precise scoped repair. Earlier report text is preserved verbatim
in `dev/structured-rho/report-history-before-local-checkpoint.md`.

## 12. Cross-Product Coverage

The evidence covers one attenuated phylo/animal/kernel/spatial trait-intercept block,
indep/common/dep and both latent-Psi choices, fixed endpoints/interior strengths,
admitted Gaussian estimation, dense/sparse sources, retained ancestors,
replication, long/wide input, simulation, known-level prediction and extraction.
Fixed family equivalence is software evidence; the two Poisson fit pairs do not
establish Poisson recovery. Existing rho-one and coefficient behavior have
separate baseline comparisons. Ordinary components are preserved for fixed rho;
unsupported competing estimated covariance is rejected rather than simplified.

This arc does NOT cover rho intervals, non-Gaussian recovery, or any broader
spatial recovery claim beyond the named partial/blocked frozen Gaussian cells;
new ancestral prediction, new grouping levels, Julia,
VA, MSPL, AGHQ, augmented slopes, missing/incomplete estimated-rho observations,
multiple attenuated sources or estimated latent ranks above one. It does NOT
cover universal latent/Psi identification, general recovery beyond the frozen
source regimes, exact-candidate three-OS checks, merge or publication. The last
two landing requirements are subsequent work, outside this authorization.

Spatial validation harness issues: one initial Eigen RHS type mismatch was
repaired before compilation passed. A sparse projection exposed base t()
dispatch in R; using Matrix::t() repaired it. The fixed-family reference initially
lost Psi for delta/ordinal phylogenetic paths; the reference now encodes the
same full covariance through dep, preserving spatial Psi. No tolerance changed.
One accidentally launched no-op labelled spatial-wide-point-01 is explicitly
NOT-A-TEST and supplies no acceptance evidence. Actual long/wide tests pass.
Eight engineering fit outputs saved correctly as RDS, then failed JSON encoding
of the original formula call; wrappers remain failed, RDS numerical checks pass,
and the serializer was repaired without rerunning a fit.

Final documentation-validator repair: rd-repair-01 incorrectly demanded an
empty raw checkRdContents result even for an unchanged, unrelated S3 topic
whose optional value diagnostic is silent in R CMD check. rd-repair-02 requires
no issue in the three edited topics and proves every other diagnostic topic
byte-for-byte unchanged. The actual all-topic cross-reference check passes.
No numerical tolerance or fit result was changed.
