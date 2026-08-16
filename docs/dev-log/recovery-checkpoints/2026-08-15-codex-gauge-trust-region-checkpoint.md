# Gauge trust-region lifecycle checkpoint

**Branch:** `codex/isdm-bfgs-exact-gradient` at `9d9ef568cfbd3f360b2e688abc1703dd9cc8ef52`.

## Scope and boundary

This is the separately named Paper 1 gauge-coordinate trust-region lane.  It
does not alter the likelihood, fixture, seed, thresholds, MSPDE V3 predecessor,
or any sealed MNCB/BFGS/gauge-no-fit root.  No TMB build, fit, optimiser,
smoke, recovery calculation, or empirical result ran in this phase.

## Current uncommitted slice

- Gauge map design links to the trust-region execution design.
- New pure contracts: sign-orbit, trust-region grid, callback adapter, and
  filesystem/terminal shape.
- New tests: sign-orbit, trust-region pure grid, adapter, smoke contract, and
  V3-live child staging writer.
- New runner: `run-paper1-spde-slope-gauge-trust-region.R` now contains two
  isolated children.  The first authenticates a disposable token-only stage,
  refuses a preloaded same-basename DLL, byte-locks the historical V3 validator,
  and atomically writes its receipt.  The second requires that receipt before
  its single `MakeADFun`, runs the full sign-orbit and trust-region contracts,
  retains an ordered callback audit, and releases the object while the DLL stays
  resident.  It has no parent materializer or scientific-root write path yet.

## Commands run

- Six pure/mock test files passed: map/no-fit callback, sign-orbit,
  trust-region grid, adapter, smoke contract, and runner staging.
- The new runner parsed successfully; its only direct factory seam is the
  worker child, with no outer optimiser or DLL-unload path.
- `git diff --check` passed.
- Read-only inspection of the sealed V3 state confirmed
  `random = c("s_B", "g_spde_slope")`,
  `g_spde_slope = 118 x 1 x 2`, `n_lhs_cols_spde_lat = 2`, and
  `d_spde_slope = 1`.

## Next safest action

Implement the parent materializer and exact root validator against the
already-tested child receipts.  It must launch the disposable V3 child outside
the scientific packet stage, reread/copy its validated receipt, then launch the
separate clean worker; it must stage/rename atomically and revalidate the final
root before printing.  Do not execute either child against the real TMB object
until implementation, adversarial tests, independent review, clean commit, and
no-build preflight are complete.

## 2026-08-15 parent-seal increment

- Split preflight receipt/provenance validation from phase-specific inventory
  validation.  A terminal packet now retains all preflight bindings while using
  an exact terminal inventory selected from retained marker, V3-child, and
  worker evidence.
- Added terminal projection and root-aware sealing helpers.  The production
  sealer writes a fresh ledger, atomically replaces the manifest, rereads the
  packet, and invokes the root validator before it returns.
- Added a typed `GAUGE_TRUST_REGION_TERMINAL_EVIDENCE_HOLD`.  It is valid only
  when replay of the retained worker evidence fails; a valid worker/result
  cannot be relabelled, and nested evidence-HOLD worker records fail closed.
- Focused pure/mock sign, trust-region, adapter, smoke-contract, runner, and
  materializer tests all pass; `git diff --check` passes.  No child process,
  TMB build, fit, smoke, recovery calculation, or scientific root write ran.

## 2026-08-15 lifecycle and compiled-fixture increment

- The parent materializer now has an injectable supervised `processx` launcher,
  a direct-child 1800-second deadline, an exclusive claim, a receipt-bound
  marker, V3-child/worker process receipts, terminal manifest replacement, and
  a reread plus root-aware terminal validation before it reports success.
  Synthetic tests cover valid worker/no-worker and partial-worker terminal
  packets, parent-unwind cleanup, stale stage rejection, a real clean isolated
  `Rscript` exit, and a one-second parent deadline.  None of these tests uses
  TMB or a scientific root.
- Added a compiled 22-coordinate TMB fixture with a two-column random SPDE
  slope block.  It has no optimiser and writes only a temporary test DLL.  It
  passed the full transformed sign-orbit relation
  `Q_signed = S^T Q S`, gauge-map replay, and callback-audit checks.  This
  corrected the former single-state Hessian comparison, which incorrectly
  required `Q = S^T Q S` rather than comparing the signed state.
- The focused suite now consists of seven files (pure map/sign/trust/adapter/
  terminal/runner/materializer plus the compiled fixture) and passed.  All
  seven R sources parse and `git diff --check` passes.  Compiler warnings are
  upstream RcppEigen unused-variable warnings; the compiled fixture completed.
- No MSPDE V3 validation child, gauge worker, preflight root, scientific
  attempt, fit, recovery calculation, or empirical run has occurred.  The
  source tree is still intentionally uncommitted.

## 2026-08-15 source-gate correction

The preceding entries are a contemporaneous record of the earlier uncommitted
slice at `9d9ef568cfbd3f360b2e688abc1703dd9cc8ef52`; they are not current source
state.  The initial source gate was committed as
`91dc35eec4654bc0dcd68be997f36e5a670ef7db`.  Its post-commit independent review
found a Frobenius-norm implementation drift and two missing worker bindings:
the sealed object-order map and the retained live no-fit replay.  This source
gate correction applies the declared Frobenius metric, validates/retains the
full no-fit receipt and its sealed-state binding, and is accompanied by the
focused seven-file green suite.  The next safe action is an independent
re-review of the committed correction; only then may a no-build preflight be
considered.  No V3 live child, scientific preflight packet, worker, fit,
recovery calculation, or empirical run has occurred.

## 2026-08-15 sealed-preflight and unsealed-smoke forensic update

The source gate was subsequently committed through
`99644e4e705f8b042cd43a44cc3358889e89a034`. Its final correction binds the
exact retained V3 replay DLL path and MD5 (`7797c4674e4758fca2da27151e5c2508`)
to the locked V3 ledger before no-build preflight. The first generated packet
from `ace72ec1` was unconsumed and is preserved at
`/private/tmp/PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1_SUPERSEDED_ace72ec1`;
it was superseded because its receipt did not bind the DLL.

The fresh `99644e4` preflight passed with no TMB construction and both
independent reviewers verified its exact ten-file inventory, immutable V3
state/DLL/control/source bindings, and unconsumed status. The single
predeclared smoke was then launched (3--10 minute estimate, 1800-second hard
deadline). The canonical root is now **consumed and unsealed**: it retains the
empty claim directory, valid receipt-bound marker (parent PID 96103), and
valid V3 live-child receipt (PID 96237,
`GAUGE_TRUST_REGION_V3_LIVE_VALID / closeout_recomputed`), but no worker
receipt, worker process receipt, terminal ledger, or terminal manifest.

This is a post-claim infrastructure/provenance failure, not a numerical,
curvature, candidate, trust-region, recovery, or ecological-model outcome. The
retained bytes cannot establish whether the worker began. Do not rerun, repair,
reseal, or backfill this root. Any next action requires a separately named
successor design and explicit review; it must not portray this attempt as
numerical non-admission.
