# After Task: Design 91 Gate 2 paired EVA/VA smoke stop

## 1. Goal

Run exactly four fresh, source-locked, row-and-trait-support-conditioned
Bernoulli-logit q=2 fixtures on Totoro, fitting each once by upstream EVA and
VA.  The sole decision was whether every predeclared receipt met the frozen
numerical-health rule and therefore permitted the atlas.

## 2. Implemented

The isolated Totoro library loaded CRAN `gllvm` 2.0.13 with TMB 1.9.21.  Four
fresh fixtures and eight immutable method-labelled receipts were copied back to
the Design-91 worktree, where their support predicates and checksums were
verified.  The paired smoke failed its all-healthy criterion: EVA was healthy
in 2/4 attempts and VA in 2/4.  The atlas was not launched.

### Mathematical Contract

The frozen Design-91 DGP, grid, q=2 loading orientation, quadrature-calibrated
intercepts, support condition, methods, seeds, controls, and health threshold
were unchanged.  Every fixture had both response levels in every row and
trait.  There is no public API, likelihood, grammar, family, or gllvmTMB C++
change.

## 3. Files Changed

- `dev/design91-eva-va-envelope/fixtures/*.rds` — four newly generated,
  support-qualified frozen fixtures.
- `dev/design91-eva-va-envelope/results/smoke/*.{json,rds}` and `manifest.json`
  — eight immutable EVA/VA receipts and their classified manifest.
- `dev/design91-eva-va-envelope/source-lock.json` — isolated Totoro library,
  binary checksums, R, and TMB receipt.
- `docs/design/91-upstream-eva-va-row-support-envelope.md` — terminal
  Gate-2 observation and boundary.
- `docs/dev-log/check-log.md` and this after-task report — durable stop record.

No package source, README, NEWS, ROADMAP, vignettes, Rd files, pkgdown files,
validation-debt rows, or public documentation changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: stop rather than start the 1,536-attempt atlas.
  **Rationale**: the all-healthy paired-smoke rule was false (4/8 receipts
  healthy; EVA 2/4; VA 2/4).  **Rejected alternative**: treating a healthy
  paired arm as a rescue, changing starts, or relaxing the gradient threshold
  would contradict the frozen gate.  **Confidence**: high.
- **Decision**: describe only the observed paired outcomes.
  **Rationale**: one healthy companion receipt does not identify the cause of
  another arm's failure.  **Rejected alternative**: an EVA-versus-VA accuracy
  or reliability conclusion would require a different design and oracle.
  **Confidence**: high.

## 4. Checks Run

- Source-install preflight: fresh CRAN `fishMod`, `alabama`, and `nloptr` were
  installed only into `/home/snakagaw/gllvmtmb_design91/rlib`; `gllvm` loaded
  there as version 2.0.13 with TMB 1.9.21.
- `shasum -a 256 .../gllvm/DESCRIPTION .../gllvm.so` — recorded the fresh
  installed hashes in `source-lock.json`.
- `OPENBLAS_NUM_THREADS=1 D91_GLLVM_LIB=... D91_AUTHORIZE_SMOKE=YES Rscript
  --vanilla dev/design91-eva-va-envelope/run-smoke.R` on Totoro — completed
  four fixtures and eight fits with exit status 0.
- Local receipt audit — PASS: 8 JSON receipts, four fixture RDS files, every
  row and trait support predicate true, and 4/8 healthy receipts.
- `shasum -a 256 dev/design91-eva-va-envelope/fixtures/*.rds
  dev/design91-eva-va-envelope/results/smoke/*.json
  dev/design91-eva-va-envelope/results/smoke/*.rds` — recorded fixture and
  receipt hashes for retention.

## 5. Tests of the Tests

The smoke exercised the acceptance side of the closed-gate guard and the
feature combination of row-and-trait support with both approximation methods.
The earlier Gate-0/1 static verifier exercised the rejection side by refusing
an unauthorized smoke.  The result classification used raw receipts rather
than selecting a best start or method.

## 6. Consistency Audit

`rg -n -i 'Design 8[6-9]|Design 90|gllvmTMB|parity|recovery|calibration' docs/design/91-upstream-eva-va-row-support-envelope.md dev/design91-eva-va-envelope`
returned intended historical fences and prohibited-claim language only.

`rg -n -i 'method.?=.?(EVA|VA)|row.?support|trait.?support|D91_AUTHORIZE_SMOKE' docs/design/91-upstream-eva-va-row-support-envelope.md dev/design91-eva-va-envelope`
returned the frozen method, support, and gate declarations only.

## 7. Roadmap Tick

N/A — Design 91 is a private upstream packet, not a package-roadmap change.

## 8. What Did Not Go Smoothly

The fresh library made dependency gaps visible: `fishMod`, `alabama`, then
`nloptr` had to be installed before `gllvm` could load.  The first dependency
installer invocation lacked its private-library environment variable and
stopped before installation; the corrected command installed only into the
isolated library.  These were setup events, not fixture or fit attempts.

## 9. Team Learning

Gauss — the new support condition prevented the prior all-zero-row warning but
did not guarantee numerical health, so support is an estimand boundary rather
than a cure.  Fisher — paired receipts were useful diagnostically: they showed
mixed method-specific and shared unhealthy outcomes without establishing why.
Rose — fresh dependencies, binary hashes, fixture checksums, and retained
failures made the stop auditable.  Jason — the narrow ordinary q=2 API target
was executable in the released source, but source availability is not a
reliability claim.

## 10. Known Limitations and Next Actions

This terminal smoke does not establish EVA or VA correctness, comparative
accuracy, broad reliability, recovery, calibration, or gllvmTMB feasibility.
The full atlas is prohibited under this contract.  Any future work must be a
separately approved design with a materially new target; it may cite this stop
but may not alter, rescore, or reuse this packet as prospective evidence.

## GitHub Issue Ledger

No issue was inspected, created, or closed.  This private upstream result does
not create a public package task or claim.
