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
