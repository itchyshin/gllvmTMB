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
