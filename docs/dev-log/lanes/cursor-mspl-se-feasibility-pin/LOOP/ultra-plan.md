# Ultra-plan — cursor-mspl-se-feasibility-pin (FROZEN at G0)

Binding copy. Full Phase 0–2 text lives at
`docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md`.
Shinichi 2026-08-15: *"everything in this plan is pre-approved OK? -
keep going"*. Do not re-interview.

## Locked answers

| Q | Pick | Meaning |
|---|---|---|
| Q1 | (a) | Internal non-exported construction. Availability + PD only. Public methods stay fail-closed. |
| Q2 | (a) | Poisson + Bernoulli **logit only**. |
| Q3 | (c) | Both: `optimHess` on \(Q_P\); \(Q_0\) evaluated at the MSPL point, never optimised. |

## What "se=TRUE pin" means here

`R/fit-multi.R` already sets `sd_rep <- NULL` for `estimator == "mspl"`.
There is no unfenced `TMB::sdreport()` hole. The pin therefore:

1. Fits with `gllvmTMBcontrol(se = TRUE)` to prove the public door
   still withholds.
2. Forms the two private curvature diagnostics.
3. Records typed status (`available` / `non_pd` / `nonfinite` /
   `error`). Non-PD is retained unrepaired.
4. Never reports coverage, width, or nominal 95%.

## Construction (do not copy Codex helpers)

- \(Q_P\): `fit$tmb_obj` (`estimator_id = 1`).
- \(Q_0\): `fit$mspl$unpenalized_tmb_obj` (`estimator_id = 2`), already
  built by Phase 1A for provenance. Evaluate only.
- Numerical Hessian via `stats::optimHess` + existing
  `.gllvmTMB_profile_tmb_checkpoint()` restore.
- Sandwich is structurally blocked (no additive scores). Profile and
  bootstrap are out of the 30-minute local budget.

## Waves (this overnight run, sequential in one conductor)

| Arc | Work | Gate |
|---|---|---|
| A0 | LOOP kit | committed under this folder |
| A1 | Shannon + branch from tapes (#978 not yet merged) | no #972–#976; no Codex absorb |
| A2 | Teacher extract (`git -C`) | no helper copy |
| A3 | Estimand pick | Q3 = (c) written down |
| A4 | Failing tests first | RED before `R/` |
| A5 | Implement pin in new `R/` file; **no `src/`** | public fence intact |
| A6 | Targeted tests | GREEN or exact RED checkpoint |
| A7 | Rose / Shannon / Melissa closeout | no admit |
| A8 | Open SE-pin PR | do not merge #972–#976 |
| A9 | Squash-merge #978 when CI green | authorised |
| A10 | Squash-merge SE-pin PR when CI green | authorised |
| A11 | Morning brief `2026-08-16-cursor-handover-se-pin.md` | |

## HARD STOPS (unchanged)

planned → admitted · NEWS covered · public mspl on NB1/NB2/beta/Tweedie ·
merge #972–#976 · Codex absorb / repo-root `LOOP/` · gaussian SE campaign ·
Totoro >30 min · second cpp editor · calling GLM-outer \(I_{LA}(\beta)\) ·
transplant Bernoulli/Gaussian \(c\) onto Poisson · public `vcov()` ·
repair non-PD Hessian · optimise \(Q_0\).
