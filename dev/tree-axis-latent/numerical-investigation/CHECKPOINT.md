# Numerical investigation checkpoint — 2026-08-30

Full tree-axis article goal INCOMPLETE. This is a durable checkpoint for a fresh
continuation, not a permission to launch extra fits or publish the article.

Worktree: /Users/z3437171/.codex/worktrees/dca1/gllvmTMB
Branch: codex/tree-axis-latent-correction-20260830
PR1229 remains at739213bfd, OPEN/DRAFT; no correction pushed/merged/deployed.
Read the approved plan, latest after-task sections15+, latest check-log, and
.unlazy/tree-axis-latent/{GATES,STATE}. The handover packet remains the initial
execution contract. Do not reuse or clean the dirty mission-control checkout.

User approved a focused numerical investigation. Root isolated cancellation
in atomic::matinv(L L') inside the native full coefficient Gaussian prior.
The private column_prior.hpp helper now solves L directly, preserving source
precision/spectral routing, rho scaling, all parameter maps and reports.
Production build passed;14 compiled regression assertions and fixed-point
checks passed. Initial attribute-only test failure retained. Gauss/Noether
qualified arithmetic sign-off; Rose/Pat consistency sign-off. Neither is
optimizer/recovery/article sign-off. Separate spatial_dep arithmetic stays
outside scope. No new API/model/estimator was introduced.

Scratch receipts /private/tmp/gllvm-tree-axis-latent-20260830:
- library/: immutable original DLL; repaired-library/: rebuilt repair.
- original fit-M2/M3 and B2 failure receipts remain immutable.
- repair-install.log80.627s, repair-fixed-points.log2.107s.
- repair-regression.log failedattrs19.837s; rerunlog14pass19.469s.
- repair-bad-marginal.log30.517s recordsNaN andinnergrad3.77e30.
  Do not spend more probes on this unusable BFGS point.
Compact numerical JSON committed under dev/tree-axis-latent/evidence/.
Frozen fixture MD5=6c3bae640dd86491171cb20fbb56b0e4; do not modify it.

14 outer attempts have entered (13returned,1interrupted), zero added in this
investigation. Remaining old slots are4BFGS+2wide, NOT authorization to widen.
Recommended approval request: replace these with8 repaired-source nlminb
attempts (IID3starts, phylo3starts, thenwide1each onlyiflonggatespass), maximum
total22. Estimated1-3min IID,2-5min phylo,1-3min eachwide;5min hardcap percall.
No thresholds, truth/seed starts, rank, diagonal or model changes. BFGS abandoned
as a proposed route, but failures stay in the ledger. This request is pending.

After approval create immutable new fit IDs/result directory and preserve all
original starts/instrumentation. Review existing runner (currentlyB2/B3 use
optim) and validator (currentlyB2/B3 primary) before adapting to new receipts;
do not overwrite old evidence or inherit their pass flags. No new fits until
approval. Wide/long acceptance unchanged. Same-source morphology continuity
may need a no-outer objective check because coefficient code should be inactive.
Then complete original render/package/docs/3OS/landing/deployed gates; no full
check or article render has yet been run. One primary render allowance remains.

Lifecycle checker reported >1compaction for this task: use a fresh continuation
with this checkpoint before another substantial block. Do not auto-create that
task without explicit user request. Lease expires4h; refresh preflight/lease and
current origin/main in the next lane, and coordinate PR1229 exclusive ownership.

## Superseding continuation checkpoint — approved block executed in 7c88

The eight-fit approval WAS received: "Approve the eight fits in a fresh task."
Do not repeat the earlier approval request. It replaced the six unspent slots;
cumulative ceiling22, historical14, new6, TOTAL20 entered and19 returned plus
the historical interrupted BFGS attempt. Two conditional wide slots remain
unspent, but are NOT currently admissible: both long models must pass first.

Continuation branch: codex/tree-axis-latent-repaired-20260830 in
/Users/z3437171/.codex/worktrees/7c88/gllvmTMB, preserving2e10e3fb history.
Fresh immutable evidence: /private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88.
The original library/results remain unchanged.118 package source files matched
saved build source; header and DLL hashes matched. Exact starts matched M2/M3.

N2 IID:58.828s; codes1/1/1, all false convergence(8). Gradients
.0043860533/.0009118015/.0033501513 pass; relative objective spread1.392637e-10,
maximum covariance relative difference8.15e-5 pass. CODE GATE FAILS.
N3 phylogenetic:137.751s; codes0/0/0; gradients
.002551996/.003354453/.002265040; objective spread9.236701e-11;
all long-model gates pass. No recovery/inference signoff is implied.
Morphology M1 three starts plus W1: repaired-source no-outer continuity PASS
in1.126s; objective differences<=9.10e-13; covariance unchanged.

validate.R --repaired exits1 correctly: long_pass=FALSE, morphology_pass=TRUE.
NW2/NW3 not launched; no article render, full package check, CI/push/PR mutation,
merge or deployment. The successful primary-render allowance remains unspent.
The complete two-example article goal remains INCOMPLETE; do not drop the IID
comparison or select a favoured start, and do not relax code/gradient gates.

Gauss/Noether qualified runner review passed after fixture/start guard fixes.
Validator positive plus five mock negative controls pass, with no new fits.
Metadata passes. The after-task structure passes; combined acceptance checker
correctly refuses completion because article gates remain unmet. Local proof:
dev/tree-axis-latent/evidence/2026-08-30-repaired-nlminb.json and after-task§16.

Next safe recommendation: a bounded independent exact-Gaussian objective AND
score check at saved IID endpoints to diagnose false convergence before any
more outer fits. This is a recommendation, not a new approved investigation,
and it must not probe the unusable extreme BFGS endpoint. No more same-settings
retries, new optimizer, modified threshold, changed DGP or campaign authorized.
PR1229 remains the draft candidate at739213bfd; landing approval stays separate.
CARRIED-OVER: local correction history plus this checkpoint intentionally
unmerged/unpushed because G2 fails. Resume by reading this newest section,
the evidence JSON and after-task§16, not by restarting any admitted fit ID.

N3 selected rho=1.501305e-7 versus planted0.60. Its numerical pass is not
rho recovery or evidence of a phylogenetic effect. Fisher/Gauss retained this
limit explicitly; the near-diagonal source boundary is a diagnostic lead,
not biological interpretation or authority to alter the frozen fixture.

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

## 19. Gaussian cell integration repair APPROVED

Shinichi approved: "Approve the scoped Gaussian cell-effect integration repair,
including output and uncertainty compatibility, then the staged 12-fit validation
block with ceiling 33. Preserve all frozen models, starts, stabilizers and
acceptance gates. Landing still requires separate approval."

This supersedes the earlier no-production-edit restriction for this scoped repair.
The source localization review identifies a same-model Gaussian convolution of
ordinary per-cell s_B with observation noise; it does NOT prove a CHOLMOD defect.
Keep Psi and the fixed stabilizer separate in reports and covariance components.
Reconstruct conditional s_B/eta and full uncertainty (conditional variance plus
propagated variance). Other model routes retain their existing evaluation.

Current count21 entered,20 returned plus1 historical interruption. New block:
three morphology long starts, three IID community long starts, three phylogenetic
community long starts, then their three wide fits only after applicable long
gates pass (both community long models before either community wide). Total12
new slots; ceiling33. No fits before likelihood/score/output compatibility review.
Fresh immutable fit IDs and directory are required. Original gates and all old
failures remain. Full two-example article goal and separate landing gate remain.

Preflight2026-08-30: owned7c88 branch; origin/main fetched and verified
9c265e76b54ea0f238d5487066964dd81e897f65. PR1229 OPEN/DRAFT at739213bfd,
unchanged remote head; other listed PRs predate this scoped continuation.

Implementation/compatibility gate PASS before any new outer fit. New library:
/private/tmp/gllvm-tree-axis-latent-20260830/cell-library. Evidence directory:
/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88.
Build85.323s (estimate1-3min,cap180s). Unit1 passed with a test-only parList
warning; unit2 hyperparameter test failed because reports were read after
sdreport's numerical Hessian changed tape state. Unit3 captures reports before
sdreport (as production does), unchanged formulas/tolerances: clean68 assertions
in1.699s. All preceding logs retained. Fixed checks1 and2 cover10 saved endpoints
and5 tiny perturbations per evaluator, zero outer optimization. Fixed checks2
passed6.139s, retaining20 identical old/new warnings for existing unsupported
newdata prediction tiers; training fitted values and supported outputs agree.
At h1e-6 directional derivative: native old.015043042, collapsed.006994469,
oracle.007000835, analytic.006999691. Max endpoint NLL difference~2.1e-8.

Initial manifest accidentally serialized source hashes without path names,
making source loops vacuous. It remains provenance.json as FAILED provenance.
Corrected provenance-v2.json is path-keyed; guards require the exact118-file
source set before checking every SHA256. Reviewer independently verified all
source hashes, DLL hash and frozen fixture. Gauss/Noether prefit review PASS;
this is neither optimizer nor article signoff. No API/engine/stabilizer/gate
changed. Count remains21 before G1. New fit IDs G1/G2/G3/GW1/GW2/GW3.

## 20. Twelve-fit validation and article render PASS

All G1/G2/G3 three-start and GW1/GW2/GW3 wide gates pass, count33/33.
Receipt: cell-integration-7c88/validation-G1-G2-G3-GW1-GW2-GW3.rds.
All68 focused compiled assertions and old/new/oracle compatibility checks
passed before fits. Source committed853daf5f0. Primary article render passed
with exactly3 separately authorized first-start fits; presentation rebuilds1–3
use saved fitted objects and prohibit all optimizer calls. Full package check
is running; local browser and final consistency review underway. No additional
standalone fit is authorized. Next: finish local/package checks, prepare
existing draftPR1229 and exact-final-head manual three-OS checks. Landing
requires separate approval. Full deployed two-example goal remains incomplete.

Package check1 completed22.6min with11 failures:7 raw-Xcoef predicateerrors,
1 mapped-placeholder warmstartcopy,3 rho finite-difference failures on a model
without ordinary cell effects. Fixing scoped output/eligibility regressions;
comparing unchanged old/new rho tests. Frozen article inputs must be proved
identical without newouterfits; old33fitreceipts/manifest remain immutable.
No packagepass/push/CI yet. All failures retained.

## 21. Compatibility regressions fixed; second package check running

Fresh cell-library-v2 buildPASS82.413s. R/fit-multi.R passes normalized
xcoef_fixed into eligibility; R/init-warmstart.R copies reconstructed cell
means when source s_B was analytically integrated. Five relevant test files
pass3.414s with NOT_CRAN=true. All6 frozenpayloads and12starts match old/new
exactly (zero tapes/optimizers); currentarticle provenancebridge passes3.041s.
Gauss confirms executableDLLsections/dynamiclinkage byte-identical; differing
UUID/N_OSOobjecttimestamp/signature metadata is being bound in bridge2.

Three coefficient-only rho FD failures were traced to native finite-difference
precision loss at a false-converged nearly singular covariance. Both DLLs fail
nativeFD at SAMEendpoint; analytic scores match independentdenseGaussian within
8.77e-6<5e-4. Corrected unit tests retain seed/data,3rhos,h1e-4,tolerance5e-4,
use declaredwell-conditionednativeFD plus exactsavedboundary againstdenseoracle.
No production optimizer/likelihood change or articlegatewaiver. TargettestPASS
3.139s. All oldfailures retained, including originalpackagecheck1ERROR/3NOTEs.

Secondfullpackagecheck running session94317 under1800scap, estimated20–30min.
No additionalstandalonearticlefit allowed; count33/33 plus3primaryrenderfits
(separateallowance). ExistingPR1229 stillremoteunchanged/draft. Next finish
package/continuityreview, commitrecords, extendPR and exact-headthreeOSCI.
Landingapproval and deployedverification stillrequired.

Second packagecheckPASS1363.420s:0errors/0warnings/3documentednotes;15975assertions
pass,0fail. Sourceidentityagainstcheckedpackageverified. Alllocalarticle/package
preparationgatespass; next extendexistingdraftPR1229 and exact-final-headmanual
3OSCI. No merge/deploy withoutseparatelandingapproval. Count33/33unchanged.

## 22. Windows CI warning regression — active diagnostic continuation

Candidate f2dd63b12 local gates passed. Manual three-OS33332985540 failed
Windows only: two no-warning assertions in animal coefficient equivalence;
all numerical route comparisons passed. macOS/Ubuntu and routine PR Ubuntu
passed. Failure/log hashes retained in evidence/2026-08-30-windows-warning.json.
Both old/current unchanged targeted tests pass122 assertions locally in
3.502s/2.418s; no causal source fix identified. Existing reviewer owns test-only
logging of the original nonfinite Windows trial, with all assertions and
evaluations preserved. Root owns logs/PR/CI. Do not suppress warnings, change
fixture/starts/controls, or spend article fits. Production remains f2dd63b12;
33/33 standalone slots spent. Continue diagnostic CI, then fix only on evidence;
landing and deployed verification remain separately gated.

## 23. Exact Windows failure evidence and unapproved next repair

Manual33335896752 at d1e2ce3fc failedWindows again (macOS/Ubuntu and routine
PR33335891536 pass). Captured full-bar animal fit and alias: code1, false
convergence8, gradient0.963. Exact Gaussian likelihood finite at failedtrial,
both old/current nativeDLLs NaN. Endpoint is also not an optimum under exact
calculation (gradient0.799). No warning/threshold waiver is defensible.

Savedpointscript, rawcoordinates and compacthashes are now durable under
numerical-investigation/windows-coefficient-* and evidence/2026-08-30-
windows-saved-points.json. Root/Noether bounded check complete, no more probes.
All33standalone slots spent; no additional outerfit ran in this diagnostic.

Read WINDOWS-COEFFICIENT-PROPOSAL.md next. It proposes same-model noncentred
nonspatial Gaussian coefficient coordinates, including physical output/start/
uncertainty compatibility, before8staged articlefits (requestedceiling41) and
1revised primaryrender. THIS REQUEST IS NOT YET APPROVED. No production or
assertion changes made. Retain all frozen models, starts, stabilizers/gates.
Existing draftPR1229 remainsunmerged; no landingauthority. Dirtymissioncontrol
untouched. Current local records will be committed; avoid a docs-only push
that would spend anotherfullUbuntuCI before a consequential repair decision.

Closeout: fetched origin/main255cedd6cc7af6792cc794712c33853f17fc51ec after
PR1230 workflow-only merge. Shannon WARN; no new owned-file collision.
CARRIED-OVER: codex/tree-axis-latent-repaired-20260830, local evidence commit
ahead of draftPR1229 because the coefficient repair/ceiling41 is unapproved.
Resume: read WINDOWS-COEFFICIENT-PROPOSAL.md, verify new user authority and
claim this lane before implementation. Do not reuse ceiling33 as new slots.

## 2026-08-30 — Coefficient standardization approved

Shinichi approved the finalized proposal: scoped coefficient-standardization
repair, output/uncertainty compatibility, eight additional standalone fits
(cumulative ceiling41), and one revised primary article render (three fits,
separately counted). All frozen settings and acceptance gates are unchanged.
Landing requires separate approval. This supersedes the proposal-only status,
not the retained failures. Starting count33; eight slots remain.

Execute the existing ultra-plan, without another planning/approval round:
1. Gauss implements src/gllvmTMB.cpp, R/fit-multi.R and R/init-warmstart.R.
2. Noether prepares independent saved-point/output/uncertainty checks and
   audits consumer compatibility; core code and test files have separate owners.
3. Root binds source/fixtures/starts and immutable receipts, then runs three
   starts for each community long model; only both passing admit two wide fits.
4. Revised primary render, focused/full package checks, bounded reviews,
   exact-head three-OS CI and PR1229 preparation follow; landing stays gated.

Reused existing agents, no new committee. Existing Gauss/Noether proposal
review supplies the plan review. Root owns build/run serialization. No agent
may independently spend standalone fits or launch builds. Estimates: build
1–3min; fixed-point checks under60s each; eight articlefits2–5min total,
five-minute cap per call; render1–3min; package20–30min; CI20–75min. Stop and
report overruns. Local bounded work; DRAC/Totoro only if needed, existing
ControlMaster only, no campaigns.

Prior work reused: ad89a9dc6 saved Gaussian oracle and Windows coordinates,
cell-integration compatibility/output helpers, existing frozen fixture and
runner. Fresh origin/main255cedd6c has no overlapping production changes.
Brain search for tree-axis/Gaussian returned unrelated material; local
checkpoint/proposal are technical truth. Deterministic brain log/decision
search for noncent/column-standard/tree-axis had no relevant hit. No new
literature or novelty claim; no sibling implementation is imported.

Coefficient prefit gates PASS: freshinstall85.778s;84 compiled fixed-point,
physical start/map/warmstart/output/uncertainty assertions2.092s;four retained
morphology points1.959s,objective deltas<7e-12;234 focused animal/rho assertions
4.952s. The formerWindows test retains no-warning assertions and nowchecks
code0/gradient<1e-2 using alreadycomputed gradients. First fixed-point run
2.144s had two names-only testdifferences and one expectedweightwarning;
retained and corrected onlytestbookkeeping. No production change afterbuild.
Gauss/Noether prefitreviewPASS; source/DLL manifest and gate bound. No new
standalonearticlefit yet; count33/41. Ready Q2 thenQ3; wideconditional.

All8 coefficient-standardization standalone attempts passed: Q2three22.383s,
Q3three49.325s,QW2one6.378s,QW3one16.443s. Everycode0; longmaxgradients
.003522236/.003911533; relativeobjectivespread4.04e-12/6.01e-11; allshared,
unique,total/coefficient/sourcecovariance gatespass. WideNLLdifferences0/
4.21e-11,fittedresponseSDdifferences0/6.08e-11. Immutablevalidation-Q2-Q3-QW2-QW3
receiptPASS withfreshnegativecontrols. Count41/41 (40returned+1historical
interruption); no morestandalonefits. Revisedprimaryrender is separately
approved3first-start fits, nowrunning. Gauss finalsource/math reviewPASS.

Revised primary render COMPLETED PASS41.375s with3separately authorized
first-startfits; presentation-onlyrender1PASS12.724s,zerooptimizer calls.
check-coefficient-article.R PASS: exactfrozenDGP,sixcalls/starts,source/DLL,
primaryfit/HTMLreceipts verified withzero fits/plots/renders. Currentarticle
SHA2562ae642a05451b6568d8017c5f852a0893dc6695f6ca7f0189ab85102792e7052;
HTML2666a646bbeb366eb37254abe2759a79842b240c910a9a78f41c57c2baa9c733.
Desktop1440/mobile390: nooverflow,20MathMLequations,4loadedfigures withalttext,
noJSerrors. All4renderedfigures inspected. Fittedrho3.11e-7 vsplanted0.60
retains explicitnon-recovery interpretation. Forty-one standalone attempts
spent; newprimary3 andpriorprimary3 accounted separately. C5passes.
Fullpackagecheckrunning session71789,1800scap,estimate20–30min. CI/landing
stillunmet. Roseprepublishreview foundstalerender-status tail, nowcorrected;
publicsource/API/scopeauditPASS. No production,model,start,tolerancechanges.


Full local package check COMPLETED PASS in 1327.051 s: 0 errors, 0 R CMD check
warnings, 3 notes (clock verification, existing logLik namespace note, xcrun_db).
Test summary: 16067 PASS, 0 FAIL, 54 WARN, 1190 SKIP. All 54 warning headers
and messages match the previous passing local check exactly; skips are unchanged.
The 92 added assertions are the 84 new coordinate checks and 8 convergence
checks. All 881 R/native/header/help/test files compared with the checked
source archive match the worktree. Receipts: package-check-1.rds,
package-source-comparison.json and package-warning-comparison.json under the
coefficient-standardization evidence root. No further fit or render was run.
Existing draft PR1229 will receive the final candidate; exact-head manual
three-OS CI remains required. Landing and live deployment remain unapproved.
