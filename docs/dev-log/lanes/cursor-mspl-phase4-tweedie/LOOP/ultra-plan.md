# Ultra-plan — cursor-mspl-phase4-tweedie (G0 implied by parent dispatch 2026-08-15)

```text
🎯 GOAL
Solo: Cursor
Deliverable: Tweedie LA-MSPL planned-only prep (power/dispersion + mass-at-zero ≠ Poisson all-zero)
HEADLINE: pin Tweedie zeros and (φ, p) as a different object from Poisson all-zero
IN PARALLEL: none — this lane owns only LOOP + research note + oracles
DEFER: registry rows; prepare widen; C++ tape; live estimator=mspl; NEWS covered; SE; campaign
DISCIPLINE: planned only; no src/; no R/mspl.R; verify by logs; structured test counts
```

## Lane pre-flight

PLATFORM: cursor | LANE: `cursor/mspl-phase4-tweedie` |
WORKTREE: `/private/tmp/gllvmtmb-mspl-phase4-tweedie` |
BASE: `cursor/mspl-point-programme-continue` @ `43b928a4` |
PROTECTED: `codex/lane-b-mspl-interval-feasibility`.
Do not claim sibling Phase-4 files (Poisson note/oracles/registry).

## Prior-work receipt

On the base tip: Poisson Phase-4 prep is already `planned` /
`phase4_prep` for `poisson:log:ordinary:q{1,2}`. Gaussian ordinary
is `admitted` / `oracle_local`. Prepare still rejects every
`family_id` outside `{0,1}`. Tweedie is `family_id` 6
(`log_phi_tweedie`, `logit_p_tweedie`, \(p=1+\mathrm{invlogit}\)).

Constitution Phase 4 is Poisson then NB1/NB2. **Tweedie sits in
Phase 5** (point masses and shape parameters). This lane does
*not* promote Tweedie into Phase 4 admission. It writes the
prep that stops anyone treating Tweedie zeros as Poisson
all-zero, or transplanting \(W=\mathrm{diag}(\mu)\).

## HARD STOP (pause and ask Shinichi)

- Widen `.gllvmTMB_mspl_prepare()` beyond `family_id %in% {0,1}`
- Flip any cell to `admitted`
- Edit `R/mspl.R`, `R/mspl-registry.R`, or `src/`
- Live `gllvmTMB(..., estimator = "mspl")` on Tweedie
- NEWS “covered”; Totoro/DRAC campaign; SE / intervals
- Repo-root `LOOP/`

## Arcs (binding)

| ID | Arc | Gate |
|---|---|---|
| A0 | LOOP kit on this worktree/branch | none |
| A1 | Research note: \(W=\mu^{2-p}/\varphi\); mass-at-zero ≠ Poisson all-zero; kill list | none |
| A2 | Pure-R oracles E1–E8 + prepare/registry fence; structured counts | none |
| A3 | Verify by log; after-task; commit / push / PR | PR is outward-facing; authorized by dispatch |

## Runtime mandate

Keep working until A0–A3 land or HARD STOP. No campaign. No
prepare widen. Registry mutation is out of OWN and out of scope.
