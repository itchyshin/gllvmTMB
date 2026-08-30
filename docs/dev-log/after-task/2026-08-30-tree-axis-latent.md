# Tree-axis article correction: validation and publication record

Date: 2026-08-30. Current status: **approved coefficient-standardization repair
in progress; its new validation has not yet run. The preceding cell repair
passed twelve fits, the article render and local package check, but Windows
CI failed. Landing/deployment remain gated**. No corrected article has been published or claimed complete.
Sections1–19 retain historical failures and superseded checkpoints verbatim.
Sections20 onward record the approved Gaussian integration and final evidence.

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

## 15. Approved numerical investigation and localized repair

Shinichi approved the focused investigation with "Yes please go ahead".
This extends the historical docs-only phase to one arithmetic repair in the
existing native coefficient prior, not a new API, engine or statistical model.
Root owns source and integration; the Terra worker wrote the compiled
regression fixture/test, and Gauss/Noether reviewed the mathematical identity,
AD arithmetic, source routing and unchanged reports/maps. The fitted
covariance Sigma_b=L_b L_b' remains reported; the density now whitens directly
with L_b before applying sparse or spectral source precision.

At the saved BFGS random state, the old coefficient prior contributed
-4.332790e27, while direct triangular evaluation gave+2.218243e26. The repaired
native joint is+3.91118954034858e26 versus oracle+3.91118954034824e26. Healthy
M2/M3 objective differences are-5.09e-11 and+1.17e-9. These checks confirm
arithmetic and continuity, not optimizer convergence or recovery. The extreme
bad-outer replay still returns NaN with inner gradient3.774888e30: retained as
an unusable inner-mode calculation, never an article endpoint. It took30.517s
against an under30s estimate and60s hard cap; no repetition was attempted.

The repaired package installed in a separate library in80.627s (estimate1-3min,
cap5min), with four compiler warnings retained. No outer fits ran; count stays
14. The first compiled regression run took19.837s and failed only gradient
array attributes; numeric values agreed. Root fixed the test's vector comparison
and ensured FreeADFun precedes DLL unload. The rerun result is recorded below.

Existing raw receipts and the original installed DLL were not overwritten.
Compact evidence is dev/tree-axis-latent/evidence/2026-08-30-numerical-repair.json;
new scripts live under dev/tree-axis-latent/numerical-investigation/. The
likelihood note and private helper explain the same-model calculation. A
similar spatial_dep inverse pattern was noticed but is deliberately outside
this repair and needs a separate bounded review. No new public capability is
advertised; inference and recovery coverage are unchanged.

Gauss/Noether recommend eight repaired-source nlminb attempts (3+3 long starts,
then1+1 wide if long gates pass), replacing unspent old slots, total ceiling22.
This concrete next block requires approval under the existing fit-budget gate.
All pending package checks, article render, exact-commit three-OS CI, landing
approval and deployed-page verification remain pending. No PR/push/merge/deploy
was performed; PR1229 stays an unmerged draft. Full goal remains INCOMPLETE.

Compiled regression rerun:14 assertions passed in19.469s; three Eigen compiler
warnings and TMB's three-pointer cleanup notice retained. After-task structural
check passes, but the combined checker exits1 because G2-G8 are still unmet;
this is an incomplete checkpoint, not an after-task completion certificate.

## 16. Fresh continuation: eight repaired-source attempts approved

The user explicitly approved "Approve the eight fits in a fresh task."
This replaces six unspent old slots with eight repaired-source nlminb attempts;
14 attempts had already entered and the cumulative ceiling is 22. The frozen
fixture MD5 remains 6c3bae640dd86491171cb20fbb56b0e4. Source task 01a05267 released
its lease; root claimed only the correction paths in isolated 7c88/gllvmTMB,
on codex/tree-axis-latent-repaired-20260830. SSH fetch verified main9c265e76;
PR1229 remains OPEN/DRAFT at739213bfd. No other lane was changed.

The same-model numerical repair is inherited from2e10e3fb. This continuation
changes only developer validation and its records, not package R/C++ source,
parameter maps, starts, frozen data, thresholds, API or advertised capability.
Hash verification matched118 source files against the saved build checkout,
the private installed/worktree header, and its compiled installed DLL.
Fresh receipts live at /private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88.

New runner IDs are N2/N3 (three nlminb starts each), and NW2/NW3 (one each,
conditional on both new long receipts passing). Historical IDs are closed to
execution. A fixed result directory and atomic per-ID admission prevent reruns;
every entering start is checked against the original M2/M3 optimizer_calls.
All six original long-start gates are retained. New validation never borrows
historical M2/M3 or BFGS pass flags. Failed and interrupted historical attempts
remain untouched. The morphology continuity check re-evaluates all three M1
starts and W1 with no outer optimization.

Files changed in this continuation: run-fit.R, validate.R, validate-repaired.R,
check-morphology-continuity.R and test-repaired-validator.R under
dev/tree-axis-latent/, this after-task report, the approved plan and check-log.
Compact final evidence and numerical CHECKPOINT.md are updated at closeout.
No example file, generated Rd, README, NEWS, ROADMAP or namespace changed in
this continuation. No convention cascade or validation-debt promotion applies.

Gauss/Noether performed the bounded runner review. They caught missing
pre-admission fixture checking and a missing final wide-start identity guard;
both were corrected before fits. Their final static review found no remaining
P0-P3 findings. This review qualifies runner logic, not optimizer outcomes.
Root applied the prose-style and after-task checks for the next maintainer:
the arithmetic repair must not be confused with a validated article model.

Tests of the tests: the existing validator rejected altered gradients,
decomposition, fixture and impossible Gaussian NLL. Separate clearly labelled
mock receipts passed a positive control and rejected a nonzero start code,
wide-start drift, missing provenance, missing long model and altered covariance.
No mock fit is biological evidence and no optimizer ran in these controls.

Morphology continuity passed in1.126s (estimate<1min,60s cap): NLL differences
at most9.10e-13, unchanged source/shared/unique covariance, gradients below1e-2.
The IID N2 call completed in58.828s (estimate1-3min,300s cap), with codes1/1/1,
all reporting false convergence(8). This fails the unchanged all-start gate.
The phylogenetic N3 call was estimated2-5min with300s cap; final results follow.

The full two-example goal is still INCOMPLETE. Wide fits, numerical
interpretation, article render, full package checks, final three-OS CI and
publication cannot be admitted through a failed long-model gate. No public
claim, PR mutation, push, merge or deployment has occurred. The one successful
primary render allowance remains unspent. ROADMAP: N/A; no row changed.
Issue ledger: inspected existing PR1229 and the seven-open-PR census; no new
issue or comment was sent. Landing still requires separate approval.

Final block verdict: N3 completed in137.751s with codes0/0/0 and all long gates
passing. Its largest gradient is.003354453 and objective spread9.236701e-11.
N2 fails only the convergence-code gate: gradient, objective agreement and
covariance agreement all pass (max covariance relative difference8.15e-5).
There are now20 cumulative entries (14 historical+6 new),19 returned plus the
historical interrupted BFGS attempt. NW2/NW3 remain unspent and inadmissible.
No overrun occurred. Validation exits1, LONG_PASS=FALSE, MORPHOLOGY_PASS=TRUE.
Compact evidence: dev/tree-axis-latent/evidence/2026-08-30-repaired-nlminb.json.

The next recommendation is an independent exact-Gaussian objective/score check
at saved IID endpoints before any more optimizer attempts. It is not approval
for new fits or for changing thresholds. The repaired prior passed its earlier
arithmetic checks; the current evidence does not establish why nlminb emits
false convergence. This distinction preserves both the arithmetic evidence
and the failed optimizer screen. No inference about biological truth follows.

All changed scripts parse; metadata passes; git diff --check passes. The
structural after-task checker passes but exits1 at the full acceptance ledger,
which deliberately retains unmet article/package/CI/deployment gates. A
one-off summary-export command initially had a parse typo; it was corrected
without rerunning a fit. The global lifecycle audit flags older sessions;
it is not a reason to relabel this numerical block or the full goal complete.

N3 selected rho=1.501305e-7 versus planted0.60. Its numerical pass is not
rho recovery or evidence of a phylogenetic effect. Fisher/Gauss retained this
limit explicitly; the near-diagonal source boundary is a diagnostic lead,
not biological interpretation or authority to alter the frozen fixture.

## 2026-08-30 — saved-endpoint diagnostic authority clarified

Coordinator confirms that the exact-Gaussian saved-endpoint value/gradient
check is covered by Shinichi's prior "Yes please go ahead" numerical-investigation
approval. Earlier text proposing another authorization is superseded; no new
permission is needed for this bounded no-optimizer diagnostic. No new fit block,
model/seed/truth/threshold/API/engine change or interpretive waiver is authorized.
Reuse check-gaussian-likelihood.R's covariance algebra; compare independent
analytic scores and directional finite differences at all six saved N2/N3
endpoints with repaired TMB values/scores. Estimate5-30s, process cap30s.

### Authorized endpoint diagnostic completed — no optimizer calls

The coordinator clarified that this diagnostic is within the existing focused
numerical-investigation approval; the earlier proposed reauthorization is
superseded. Reused check-gaussian-likelihood.R's exact Gaussian covariance.
endpoint-score.R projects the two-column site design with a thin QR, evaluates
the same marginal density and differentiates it analytically in the native
parameter coordinates. Raw loading diagonals, log coefficient-Cholesky
diagonals, log unique SDs and logistic rho have distinct correct chain rules.
Gauss/Noether reviewed row-major ordering, QR covariance blocks and derivatives
before execution; unknown parameter blocks are rejected explicitly.

Command: OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
R_LIBS=/private/tmp/gllvm-tree-axis-latent-20260830/repaired-library
python3 /private/tmp/gllvm-tree-axis-latent-20260830/bounded.py 30
/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88/endpoint-score.log
Rscript --vanilla dev/tree-axis-latent/endpoint-score.R

Exit0,2.645s (estimate5-30s,cap30s). All six saved N2/N3 endpoints were checked;
zero outer optimizer calls, cumulative attempts unchanged at20. Independent
QR minus inherited spectral value <=2.73e-11; QR minus repaired TMB value
<=2.09e-8; analytic score minus TMB score <=1.43e-8. Independent directional
central differences agree within1.68e-6 at h=1e-4 and1.14e-6 at h=1e-5.
These are measured discrepancies, not new article acceptance thresholds.
Covariance reconstruction and source/order provenance checks all passed.

This diagnostic finds no endpoint objective/gradient defect. It does not
explain the optimizer trajectory, erase false-convergence(8), establish rho
recovery, or admit the two wide fits. No extreme BFGS point was revisited.
The full article still fails G2. Added source: dev/tree-axis-latent/endpoint-score.R;
compact evidence: dev/tree-axis-latent/evidence/2026-08-30-endpoint-score.json.
All raw endpoint RDS/JSON receipts and the process log remain in the immutable
continuation evidence directory. No new optimizer or production repair follows
from these results without a separate consequential decision.

### Precise next consequential choice — NOT YET AUTHORIZED

Gauss/Noether recommend one controlled diagnostic optimizer call: use nlminb
with the independent exact-Gaussian objective AND analytic score, byte-identical
N2 start1, and identical original bounds/scales/controls/maps. Retain the full
value/gradient evaluation trace. It changes only evaluator arithmetic for a
private diagnostic; it introduces no production engine/API and is not a new
estimator or an article substitute. Estimate10-60s, external60s cap (based on
2.645s for the six-endpoint diagnostic); stop/report an overrun.

This is ONE additional optimizer attempt requiring explicit authority. It must
not borrow the two conditional-wide slots: cumulative ceiling would increase
from22 to23, with20 already entered. No BFGS, tolerance change, changed fixture,
changed start, or further retry is proposed. Oracle code0 at the same solution
would support evaluator/path sensitivity; code1 would show it survives evaluator
replacement, not prove non-identifiability. A different solution requires review.
In every case N2 remains failed until the actual package route independently
passes its original gates; no wide fit or article interpretation is unlocked
by a private-oracle result alone. No diagnostic optimizer call has been run.

Copy-ready decision: "Approve one exact-Gaussian oracle nlminb diagnostic from
the frozen N2 start1, with unchanged controls and a60-second cap; add one attempt
without borrowing wide slots (ceiling23). No production changes or gate waiver."

## 2026-08-30 — single exact-Gaussian oracle attempt explicitly approved

User: "Approve one exact-Gaussian oracle `nlminb` diagnostic from the frozen IID
start, with unchanged controls and a 60-second cap. Raise the ceiling to 23
without borrowing wide slots. No production changes or gate waiver."
This supersedes the earlier pending-approval paragraph. Cumulative before20;
exactly one diagnostic attempt admitted, ceiling23. The two wide slots remain
conditional and untouched. Estimate10-60s, external60s cap. Use exact N2 start1,
original eval.max2000/iter.max1500, default bounds/scale/tolerances; replace only
the evaluator with the previously reviewed exact Gaussian value/analytic score.
Retain every evaluation and terminal return. No package source or API edits.

## 17. Approved single-oracle optimizer diagnostic — completed

The user approved one independent exact-Gaussian nlminb attempt from the frozen
IID start, unchanged controls,60s cap, cumulative ceiling23 without borrowing
the wide slots. That approval supersedes the prior pending-authorization text.
The isolated lease was reclaimed; main remained9c265e76, and the existing PR
census was unchanged. No production R/C++/header/API or article source changed.

`dev/tree-axis-latent/oracle-nlminb.R` loads only the hash-bound pure Gaussian
algebra from endpoint-score.R, never its endpoint execution loop. It verifies
the source/DLL/fixture hashes and N2 receipt MD5, and matches its start exactly
to N2-start1 and historical M2-start1. The original package argument builder
sets eval.max2000 and iter.max1500; empty optArgs retains default bounds,
scale and tolerances. The Gaussian stabilizer and all maps are unchanged.
Gauss/Noether reviewed controls, algebra loading, single admission and trace.

Command: OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
R_LIBS=/private/tmp/gllvm-tree-axis-latent-20260830/repaired-library
python3 /private/tmp/gllvm-tree-axis-latent-20260830/bounded.py 60
/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88/oracle-N2-start1.log
Rscript --vanilla dev/tree-axis-latent/oracle-nlminb.R

Exit0,2.571s wall process time (estimate10-60s,cap60s),1.094702s optimizer time.
Exactly one optimizer entered and returned. It returned code0, "relative
convergence (4)",253 iterations; NLL5039.69128021751, max analytic gradient
.001182399. nlminb reports269 function and254 gradient evaluations. The actual
trace contains270 objective and254 gradient calls (the initial objective is
additional),524 records total, all finite, no warnings/errors. The atomic
admission and every evaluation record survive independently of final summaries.

Against the three saved package endpoints, exact-Gaussian NLL differences are
-7.961235e-7,-1.561357e-7,-8.863844e-8. Unit covariance relative-norm differences
are at most4.295e-5 and coefficient covariance differences at most4.119e-6.
This is a closely matching endpoint under the unchanged optimizer/start/control
settings with a different evaluator. It supports evaluator/path sensitivity;
it does not identify the mechanism, prove identifiability, or justify deleting
failed package convergence codes. N2 remains FAILED; NW2/NW3 remain blocked.
No article, recovery or inference acceptance is granted by this private oracle.

Cumulative attempts:21 entered,20 returned plus the historical interrupted
BFGS attempt; ceiling23. Exactly the two conditional-wide slots remain unused.
No further optimizer run, publication, push, merge, deployment or production
repair occurred. Compact evidence is
`dev/tree-axis-latent/evidence/2026-08-30-oracle-nlminb.json`; raw receipts and
trace are under repaired-nlminb-7c88/oracle-N2-start1/. The full article goal
remains incomplete at G2. Existing fixed-endpoint diagnostics are evidence,
not permissions to replace the package route or loosen its gates.

Final reviewer independently checked all524 evaluation records and terminal receipt;
no remaining record defects. No additional endpoint check is warranted for this
narrow conclusion. Native numerical-stopping investigation is a separate scope;
no derivative defect or specific production repair has been established.
Oracle script parse and git diff --check pass; production source, frozen fixture
and article are unchanged. After-task structure passes; combined checker still
exits1 because the full article acceptance ledger remains unmet.

## 2026-08-30 — twelve-point repeatability diagnostic authorized

Coordinator authorizes max12 fixed parameter-point evaluations, no outer
optimizer, same failed IID endpoint, unchanged controls,60s process cap.
Frozen endpoint: N2 start1; direction: its saved independent analytic gradient
normalized to unit Euclidean length. Matrix fixed before execution: six fresh
tapes at steps0,0,+1e-4,-1e-4,+1e-6,-1e-6; one reused tape at steps
0,+1e-4,-1e-4,+1e-6,-1e-6,0. Every tape begins from the same retained parameter
list; fresh means newly constructed tape, not zero latent effects. TMB's existing
random.start=last.par.best[random] and inner Newton controls are unchanged.
Each point pairs fn/gr at that exact outer vector; after-fn mode/joint/score
are saved BEFORE gr changes state. Record full modes, inner scores, values,
outer gradients, oracle differences and inferred half-logdet contribution.
Estimate5-60s, external60s cap. No solution search or selected-fit replacement.
If no actionable cause is located, stop with one concrete next choice.

## 18. Twelve-point repeatability result — source localization still owed

The authorized repeatability check completed in5.234s, exit0, below the60s cap
(estimate5-60s). Exactly12 declared fixed parameter points were evaluated;
zero outer optimizer calls. The count remains21 entered out of ceiling23.
No production code, optimizer/inner controls, frozen data or gates changed.

Command: OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
R_LIBS=/private/tmp/gllvm-tree-axis-latent-20260830/repaired-library
python3 /private/tmp/gllvm-tree-axis-latent-20260830/bounded.py 60
/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88/repeatability.log
Rscript --vanilla dev/tree-axis-latent/repeatability.R

Baseline repetitions agree exactly. Matched fresh/reused objective values
agree within7.276e-12 and gradients within1.420e-13. Inner scores are at most
1.458e-8. Therefore this local matrix finds no material state-reuse effect.
TMB-oracle objective discrepancies vary across the tiny perturbations, reaching
2.028e-8, while analytic outer gradients agree within1.549e-8. At h=1e-6,
TMB objective differences imply directional derivatives.0150394/.0150430;
the independent Gaussian value gives.007000835 and its base analytic score
.006999691. At h=1e-4, TMB gives.007012532 versus oracle.007000062.
This is evidence of local marginal-value precision loss at small steps.
It does not identify a log-determinant bug or another production expression.
No gate waiver, model interpretation or alternative selected fit follows.

Gauss/Noether reviewed the predeclared matrix, unchanged default inner-state
policy, and correct separation of after-fn and after-gr modes before launch.
They independently reviewed all12 retained results and found no record defect.
All full modes, inner scores, outer values/scores and oracle differences are
retained in repaired-nlminb-7c88/repeatability-N2-start1/receipt.rds.
Source: dev/tree-axis-latent/repeatability.R. Compact evidence:
dev/tree-axis-latent/evidence/2026-08-30-repeatability.json. Script parse and
git diff --check pass; no package/article/production source changed.

Stop condition honored: these points locate a numerical precision issue but
not an actionable production expression. No additional probes ran. One concrete
next choice is a bounded source-localization audit of the existing native
Gaussian marginal-value arithmetic, using these saved12 points and the exact
oracle. It must identify a file:line cause and an algebraically equivalent
repair proposal BEFORE production edits; if none can be localized, report that
and stop. No warm-start, tolerance or stabilizer change, new engine/API, extra
fit, or gate waiver is authorized. A specific patch is not yet justified.
The existing goal/acceptance ledger remains authoritative; creating another
goal would not resolve G2. Full two-example delivery remains INCOMPLETE.
## 20. Approved Gaussian integration: implementation checkpoint

Full article goal remains incomplete. Shinichi approved scoped ordinary-cell
Gaussian integration including output/uncertainty compatibility and12 staged
fits, ceiling33. The native template and R fitter preserve all frozen outer
parameters, starts and stabilizer; eligible cell effects are integrated exactly
and reconstructed for predictions. getREsd adds conditional variance to the
ADREPORT variance of each reconstructed mean. Other paths retain their existing
evaluation. No new API, engine, estimator or inference coverage claim.

Build passed85.323s. Final focused compiled tests:68 assertions, clean1.699s,
including mean/random and estimated-Psi uncertainty; prior test-only warnings
and stale-report test failure retained. Saved-point checks passed6.139s with
complete118-file/DLL/fixture binding. An initial unnamed-hash JSON manifest was
rejected and retained; v2 enforces named paths and full source-set equality.
Newdata warnings are unchanged unsupported-tier warnings, now captured; no
broader newdata capability is claimed. Gauss/Noether independently reviewed
source, likelihood identity, uncertainty, restored validator safeguards and
prefit evidence. Core implementation by Gauss; bounded tests by Curie; root
integrates outputs and receipts. All previous biological/numerical caveats stand.

Example files changed: none yet. Frozen fixture unchanged; article unchanged.
Code/help cascade: R/re-uncertainty.R and man/getREsd.Rd synchronized. This is
a prefit implementation checkpoint, not the final11-section completion report
or a substitute for original pending article/package/3OS/landing/deployed gates.

## 21. Frozen fits and rendered article

All twelve newly approved standalone fits passed: three starts for each of
morphology, IID community and phylogenetic community, then one wide fit for
each. Cumulative count33/33 includes the retained historical interruption;
32 attempts returned. No old failure was replaced. Maximum gradients were
0.001096, 0.003523 and 0.001336 respectively; maximum covariance relative
norm differences were0.061234,0.0000443 and0.00000314, below0.10.
Long/wide normalized objective differences were0,0 and6.072e-11; fitted
response differences were0,0 and3.067e-11 response SD. All convergence codes
were0 and objective-spread/finite-value gates passed. This is numerical
agreement, not successful recovery of every planted covariance component.

The separately approved primary article render ran exactly three first-start
fits, matching saved G1/G2/G3 starts, and passed in41.714s. Three presentation
rebuilds reused those fitted objects with every optimizer call prohibited.
They fixed MathML, figure title/caption clipping, mobile equation overflow,
alt text, tables and scientific-notation display. The original render and all
presentation receipts remain separate immutable records. Desktop1440px and
mobile390px checks found no document overflow, broken images or browser errors.

The sole changed public example is
vignettes/articles/where-does-the-tree-go.Rmd. Both long and wide calls,
simulation/equations, public extracts, four figures and interpretation now
agree. All covariance components remain. The fitted rho near zero and nearly
zero morphology phylogenetic Psi are explicit limitations. Planted species
curves are labelled as planted; residual association is not causal interaction.
R/re-uncertainty.R and man/getREsd.Rd remain synchronized; no API/grammar/default
convention changed. README, NEWS, navigation and other examples require no
syntax cascade. The broader FG-20 coefficient capability remains partial.

Curie performed bounded reader/figure review and caught malformed scientific
notation; sprintf fixes it without changing fitted values. Gauss/Noether
prefit review covers the likelihood and first-order uncertainty identity.
Final package/consistency and exact-head CI results are recorded separately.
This phase does NOT cover general recovery, interval calibration, non-Gaussian
collapse, REML, missing/repeated cells, or newdata prediction tiers that were
already unsupported. No source or optimizer gate has been relaxed.

Final current-article checker passed1.873s with zero fit/optimizer calls,
checking all6 formulas, controls, seeds, frozen generated data,118 source hashes,
DLL and final article/HTML/primary-fit receipt binding. An initial dependency
path failure is retained; corrected invocation uses R_LIBS without hiding the
existing dependency library. Final presentation3 took12.801s. Structural
checker check_after_task() passes; full acceptance remains open for package,
CI, landing and deployment. Reader-surface PVT-02 issue is unchanged on main,
not introduced by this correction.

Final bounded Rose review PASS: no unresolved P0/P1/P2 findings. It verified article/source/help/defaults/capability boundaries and current no-fit checker. Package and cross-platform evidence remain separate.

## 22. Full package check caught compatibility regressions

Package check1 completed1353.213s (22.6min), within the1800s cap, with1ERROR
and3NOTEs. Test totals:15913 pass,11 failures,55 warnings,1190 skips under
the unchanged default non-heavy suite. Seven failures arise from passing raw
atomic Xcoef_fixed into the new predicate expecting its normalized list; one
from copying mapped s_B placeholders rather than reconstructed conditional
means for start_method="indep". Three estimated-rho finite-difference failures
require baseline comparison; they have no ordinary cell effects, so Gaussian
cell integration is inactive. All failures and warnings retained. No package
pass, push or CI admission is claimed. Repair of the two compatibility paths
and no-optimizer continuity proof for frozen article inputs are underway.

Compatibility follow-up: fresh cell-library-v2 build passes82.413s. The predicate
now receives normalized xcoef_fixed; start_from copies reconstructed means for
integrated Gaussian s_B and retains legacy shape/finite guards. Five affected
regression files pass3.414s with NOT_CRAN=true, including the original failing
Xcoef/SE/warm-start tests. A first direct test_file invocation skipped CRAN-only
exclusions and is retained as partial, not used as proof of the fixed failures.
Curie's two no-tape captures and comparison prove all6 frozen model inputs,
maps/random blocks/RNG states and all12 deterministic starts byte-identical
across old and new libraries. No additional article optimizer call ran.

The unchanged rho regression passes against the old library and fails against
the repaired one. Its retained fitted endpoint has code1 false convergence and
coefficient covariance condition about2.16e11. Both DLLs fail native finite
differences at that SAME endpoint. Repaired analytic-vs-dense exact Gaussian
score discrepancy is8.77e-6 (old3.35e-6), below the unchanged5e-4 tolerance;
dense analytic-vs-FD discrepancy is3.22e-10. Thus the reference finite difference
loses precision; this is not evidence of a wrong repaired analytic derivative.
The boundary failure and limitations remain recorded. A corrected unit test
uses a declared well-conditioned native-FD point plus the difficult endpoint
against the independent dense oracle, keeping3rho values,h1e-4,5e-4 tolerance.
This changes no frozen article fit/acceptance gate and makes no general
near-boundary optimizer-reliability claim. Full package check remains pending.

Gauss independently reviewed the corrected derivative tests: covariance packing,
observation order and Gaussian score trace agree; all three probes/steps/bounds
are unchanged. Target file passes3.139s without warnings. Final bridge2 adds24
captured-versus-retained input assertions and independently rechecks all DLL
executable/data/linkage bytes, permitting only recorded build metadata changes.
The bridge and article checker pass4.199s/3.423s without model evaluations.
Old manifests, original bridge and failures remain immutable. No generalized
near-boundary optimizer claim follows from the unit-test correction.

Gauss final durable-bridge review PASS: independently reran binary audit and source bridge, including24retained input bindings and all12starts. No cachedpassflag inheritance; originalbridgev1 remains. Package2/CI/landing/deployment still separate.

Team learning from package regression: checking named s_B consumers was not
enough; generic parameter-copy loops also need reconstructed effects. Public
constraint inputs must be normalized before internal eligibility predicates.
A derivative reference must be numerically reliable at its chosen point:
retain difficult endpoints, and compare against independent marginal algebra
rather than infer derivative failure from cancelling likelihood differences.
These are focused test lessons, not new permissions or weaker acceptance gates.

## 23. Local package and article preparation complete; landing not authorized

Second full devtools::check completed1363.420s within its1800s cap:0ERRORS,
0WARNINGS,3NOTEs. Tests:15975PASS,0FAIL,54WARN,1190SKIP under the unchanged
normal non-heavy suite. Test warnings are retained in testthat.Rout; none is
an R CMD check warning. Both regular and donttest examples, package vignette
rebuild, compiled-code checks and documentation consistency pass. The three
notes are unavailable remote-clock verification, an existing unqualified
logLik call in deviance.gllvmTMB_multi (verified on origin/main), and macOS
xcrun_db compiler detritus. No note was hidden or check setting weakened.

All package R/native/header/Rd/test sources were byte-compared against the
checked source tree; package-check-2-source-identity.json records the count.
The article has independently passed its primary run, all6 long/wide call
checks,4figure/desktop/mobile review, and post-compatibility source/DLL/input/
start continuity. Code is at008a679e1; remaining edits record evidence only.

Gauss/Noether likelihood and derivative-reference reviews, Curie bounded
reader/test checks and Rose consistency review pass. Shannon coordination:
owned7c88 lane only; existing draftPR1229 is the target. Newly activePR1230
changes only pkgdown.yaml, not this scope; no merge ordering conflict found.
Main remains9c265e76. Dirty mission-control checkout was never used or cleaned.

The exact-final-commit three-OS verdict will be recorded in PR1229's body and
its linked workflow receipt, without moving the commit being checked merely
to record that result. This local closeout does NOT authorize landing and is
not a completed deployed-correction claim. Main deployment and live verification
of both examples remain required after separate maintainer approval.

## 24. Windows CI failure: no landing or completion claim

At candidate f2dd63b12, manual run33332985540 passed full macOS and Ubuntu
package checks; Windows failed two no-warning assertions in the unchanged
animal coefficient/slope equivalence test. All equivalence assertions passed.
The routine Ubuntu PR check also passed. Detailed counts and immutable log
hashes are recorded in evidence/2026-08-30-windows-warning.json.

The last baseline three-platform run passed this unchanged test. Local old
and current libraries each pass all122 assertions without fit warnings in
3.502s/2.418s. Current local endpoints converge with small gradients but
covariance near a boundary; the fixture plants no coefficient effects. This
is context, not proof that the Windows warning is harmless. Both bars use the
prior-arithmetic repair; neither uses Gaussian cell integration. The transient
Windows trial is not yet available, so no source fix or test relaxation is
justified. Capture limitations are explicitly retained in the evidence file.

Gauss/Noether review is continuing through the existing review_runner. The
next scoped action observes existing evaluations in the exact failing test,
without changing models, seeds, starts, controls, assertions, or evaluation
counts. This is routine package diagnostics, not another article fit block.
The full two-example/deployed-article goal, all frozen numerical gates, and
separate landing approval remain in force. G7 is failed, G8 is unstarted.

Diagnostic logging now changes only tests/testthat/helper-column-coef-animal.R
and tests/testthat/test-column-coef-animal-equivalence.R. Existing122 assertions
pass2.754s with0warnings. Pure-R smoke0.626s proves one fake nonfinite objective
return is logged, warning delivery is preserved, and namespace binding restored.
No additional real optimizer or objective/gradient evaluation was introduced.
Root reviewed exact call order and original expectations. R parsing and
git diff --check pass. After-task structure passes; its completion checker
correctly fails because G7/G8 remain unmet. No ABANDONED or pass waiver applied.
No production/article/fixture source change, recompile or article rerender.
Next manual CI is expected20–75min, with existing75min job cap, to capture
the Windows trial; this is not a claimed repair or a blind rerun.

## 25. Saved Windows trial and consequential next choice

The diagnostic CI repeated the Windows failure and captured both a nonfinite
trial and a false-converged endpoint (code1, gradient0.963). Exact Gaussian
comparison shows the trial covariance is valid and its likelihood finite;
both retained native libraries fail there. At the endpoint, even the exact
gradient is0.799. The no-warning assertions must not be relaxed. Native
evaluation remains unstable for this near-singular coefficient covariance;
triangular whitening repaired the negative-prior defect but did not remove
the badly scaled centred random-effect Hessian. We do not claim that one
exclusive floating-point operation has been isolated.

Gauss/Noether reviewed the exact marginal value/gradient algebra and recommends
standardizing the coefficients inside the existing Gaussian native engine,
with B=U L', unchanged source covariance and physical-B outputs. The precise
proposal lists starts/maps, warm starts, uncertainty, existing-output consumers,
source fences and validation gates. It is not implemented or authorized.

Evidence: dev/tree-axis-latent/evidence/2026-08-30-windows-saved-points.json;
reproducible script and coordinates in numerical-investigation/windows-
coefficient-{evaluate.R,trial.R.txt}; full local evidence windows-trial-2/.
Two pre-tape capture-signature failures and the invalid earlier capture field
remain explicit. Successful current/old checks each took1.106s and used no
outer optimizer. No private extreme BFGS point was revisited.

The next consequential request is scoped coefficient reparameterization,
eight additional standalone article attempts (33 to41), and one revised
primary render with3first-start fits accounted separately. No fresh fit is
authorized by this report. Morphology would receive no-outer continuity
checks; all original community gates and conditional-wide sequencing remain.
Routine package tests/docs/CI and PR1229 remain required, with landing still
separately gated. Restored DRAC/Totoro availability is not new fit authority
and cannot clear Windows. The full two-example deployed article is unfinished.

Closeout: Shannon coordination review WARN: Windows remains failed and the
repository has seven open PRs, but no new collision was found for this owned
lane. PR1230 merged only the pkgdown workflow runtime update; freshly fetched
origin/main is 255cedd6cc7af6792cc794712c33853f17fc51ec. This lane did not
modify that workflow or the dirty mission-control checkout. PR1229 stays draft
at diagnostic commit d1e2ce3fc. The saved-point evidence and proposal are
CARRIED-OVER as one local checkpoint commit, deliberately not pushed: another
full Ubuntu run would not repair the known Windows failure. Resume by reading
WINDOWS-COEFFICIENT-PROPOSAL.md and checking the actual user approval before
any implementation or additional fit. Current authority remains ceiling33.

## 26. Approved coefficient-standardization repair

Shinichi approved the finalized repair, output/uncertainty compatibility,
eight additional standalone fits (ceiling41), and one revised primary article
render. Preserve all frozen settings and acceptance gates; landing separate.
Gauss owns the three core files; Noether owns independent tests and read-only
output review; the existing validation worker owns the immutable runner.
Root owns build/fit serialization, documentation, rendering and PR preparation.
The existing ultra-plan is being executed, not reopened for another approval.
At entry33standalone attempts are spent; no new fit or build has yet run.

Coefficient prefit gates PASS: freshinstall85.778s;84 compiled fixed-point,
physical start/map/warmstart/output/uncertainty assertions2.092s;four retained
morphology points1.959s,objective deltas<7e-12;234 focused animal/rho assertions
4.952s. The formerWindows test retains no-warning assertions and nowchecks
code0/gradient<1e-2 using alreadycomputed gradients. First fixed-point run
2.144s had two names-only testdifferences and one expectedweightwarning;
retained and corrected onlytestbookkeeping. No production change afterbuild.
Gauss/Noether prefitreviewPASS; source/DLL manifest and gate bound. No new
standalonearticlefit yet; count33/41. Ready Q2 thenQ3; wideconditional.
