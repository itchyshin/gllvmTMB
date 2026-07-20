# Codex handover — Design 85 VA decision closed NO-GO

**Date:** 2026-07-20  
**Branch:** `codex/va-r3-prototype-20260720`  
**Decision:** retain Laplace; do not run q4/q6 or implement a VA API

## Read first

1. `AGENTS.md`
2. `docs/design/85-highdim-nongaussian-va-formal-contract.md`
3. `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`
4. `docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md`

## Decision outcome (branch complete; merge pending)

The internal q1/q2 reference and prototype algebra is coherent, but the pilot
did not establish the frozen fixed-rank Gate 3. Final classification is 22/24
applicable healthy q1 fits and 19/25 q2 fits, with eight applicable optimiser
failures. The runner also combined the Gate-3 fixed-rank comparison with the
Gate-4 ML rank hand-off. The correct decision is NO-GO before high-dimensional
stress. No q4/q6, 100-, or 500-replicate campaign ran.

## Landing state

PR #777 is the landing vehicle. Treat this handover as pre-merge until the
exact PR head passes the Windows, macOS, and Ubuntu matrix and the merge commit
exists on `main`. The final closeout must record those identifiers; a local or
single-platform pass is not a merged state.

## Boundaries

- No VA, AGHQ, or non-Gaussian REML public claim.
- No public API, NEWS, README, vignette, roxygen/Rd, validation-register, or
  release-rung change.
- Do not tune gates or rerun the same campaign.
- Do not touch CI-11, multinomial/tier-2a, Ayumi, Bartlett, or the entangled
  `docs/dev-log/check-log.md` worktree as part of this closed arc.
- Reopen inference-engine research only after a genuinely new evidence source
  and a separately approved formal plan.

## Next safe action

Return to the maintainer's existing 0.6 queue and reconcile its already-complete
latent-rank article row before choosing the next bounded package slice. Keep
CI-11 in its existing Mission Control state until the remaining Ayumi receipt;
this VA closeout neither closes nor replaces it.
