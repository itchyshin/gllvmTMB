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

## Next safest action

Perform the final adversarial source review of the corrected signed-Hessian
contract and the parent terminal projection.  If it passes, commit this exact
slice, create a fresh no-build preflight packet, reread its production
validator, and then seek/record the bounded one-shot smoke authorization.  Do
not turn the compiled fixture into evidence about the ecological estimator.
