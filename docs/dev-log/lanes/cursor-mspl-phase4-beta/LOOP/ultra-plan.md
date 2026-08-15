# Ultra-plan — cursor-mspl-phase4-beta (G0 implied by Shinichi 2026-08-15)

```text
🎯 GOAL
Solo: Cursor
Deliverable: Beta logit Phase-4 PREP (derivation + pure-R oracles + LOOP)
HEADLINE: μ→0/1 + precision algebra for Beta; no atom transplants
IN PARALLEL: sibling family-prep lanes own their files
DEFER: admit; prepare widen; C++; SE; NEWS covered; beta-binomial
DISCIPLINE: planned only; verify by logs; explicit git paths
```

## Lane pre-flight

PLATFORM: cursor | LANE: `cursor/mspl-phase4-beta` |
WORKTREE: `/private/tmp/gllvmtmb-mspl-phase4-beta` |
BASE: `cursor/mspl-point-programme-continue` @ `43b928a4` |
PROTECTED: `codex/lane-b-mspl-interval-feasibility`.
Do not use Dropbox. Do not edit the point-continue worktree.

## Prior-work receipt

On the start tip: Poisson Phase-4 note + oracles + `planned`
registry rows (`phase4_prep`); Gaussian ordinary `admitted` /
`oracle_local`. Prepare fence still `family_id %in% {0,1}`.
No Beta MSPL atom, oracles, or registry row exists.

Programme constitution lists Beta under **Phase 5** (bounded means
and shape parameters), after Poisson/NB in Phase 4. This lane is
*prep* in the parallel family batch Shinichi asked for. It does
not admit Beta and does not jump the Poisson admission gate.

## HARD STOP (pause and ask Shinichi)

- Flip Beta (or any family) `planned` → `admitted`
- Widen `.gllvmTMB_mspl_prepare()` to `family_id == 7`
- C++ tape / live `estimator = "mspl"` on Beta
- Transplant Bernoulli \(W_g\) / \(V_{\mathrm{loading}}\), Poisson
  \(W=\operatorname{diag}(\mu)\), or Gaussian Hirose \(1/\psi\)
- NEWS “covered”; SE / intervals; Totoro/DRAC campaign
- Edit sibling family files or the shared registry in this lane
- Repo-root `LOOP/`

## Arcs (binding)

| ID | Arc | Gate |
|---|---|---|
| B0 | LOOP kit on this isolated worktree | none |
| B1 | Beta derivation note (logit μ→0/1 + precision) | none for planned |
| B2 | Pure-R oracles E1–E8 + structured counts | none; HARD STOP on admit |
| B3 | After-task + PR | merge is human; no self-merge of high-risk |

## Locked decisions

1. Mean-precision Beta: \(a=\mu\phi\), \(b=(1-\mu)\phi\),
   \(\operatorname{logit}(\mu)=\eta\), \(\phi=\exp(\texttt{log_phi_beta})=1/\sigma^2\).
2. Information atoms are derived for *this* likelihood. Same logit
   link as Bernoulli does **not** transfer \(W_g=\mu(1-\mu)\).
3. This lane does not land registry rows (shared file; parallel lanes).
4. No C++. `git diff -- src/ R/mspl.R R/mspl-registry.R` stays empty.
