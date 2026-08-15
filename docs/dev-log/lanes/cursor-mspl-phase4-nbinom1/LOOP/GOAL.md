# GOAL — cursor-mspl-phase4-nbinom1 (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`) and the landed point-continue kit
(`cursor-mspl-point-continue`) are historical for *this* lane — do
not reopen their GOALs. Point-continue PR #971 remains the stack
base, not this lane's science editor.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Review amendment — 2026-08-15

Shinichi authorized a bounded rewrite of the copied note and oracles
to repair PR #976's blocking NB1 information error. This amendment
supersedes only the earlier copy-not-rewrite fence: use exact Fisher
information from the `size = mu / phi` pmf, label
\(\mu/(1+\varphi)\) quasi/IRLS only, and use R/TMB success probability
\(1/(1+\varphi)\). Every admission fence below remains unchanged.

## Mission

```text
Solo: Cursor
Deliverable: land sibling nbinom1 Phase-4 prep on this isolated
worktree — (A) copied derivation note; (B) copied pure-R oracles;
(C) LOOP kit; (D) stacked PR. Do not rewrite the science.
HEADLINE: Var = μ + φμ vs Poisson vs NB2; no registry row; no prepare widen
DEFER: rewrite of sibling note/oracles; registry row; prepare widen;
      C++ tape; estimator="mspl" on nbinom1; admit; merge; SE; NEWS
DISCIPLINE: copy-not-rewrite; OMP=1; verify by logs; never git add -A; no root LOOP/
```

## Headline

Carry the sibling NB1 information algebra
\(\operatorname{Var}=\mu+\varphi\mu\) versus Poisson and NB2 onto
`cursor/mspl-phase4-nbinom1` with a LOOP kit — without a registry
row, without prepare widening, without admission.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-phase4-nbinom1`.
- Branch `cursor/mspl-phase4-nbinom1` (from
  `cursor/mspl-point-programme-continue`).
- Lane LOOP only under
  `docs/dev-log/lanes/cursor-mspl-phase4-nbinom1/LOOP/`.
- Science files began as sibling copies; the review amendment above
  authorizes only the exact-information and probability-convention
  repair.
- Do NOT edit `R/mspl.R`, `src/`, `.gllvmTMB_mspl_prepare()`,
  or add/admit an nbinom1 registry row.
- Do NOT implement SE / intervals / NEWS covered / C++.
- Do NOT merge. Stacked PR only.
- Local tests only; `OMP_NUM_THREADS=1`.
- Never `git add -A`. Stage explicit paths. Never write repo-root `LOOP/`.

## Authoritative WHAT

- Sibling science (do not rewrite):
  `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom1-prep.md`
  `tests/testthat/test-mspl-nbinom1-phase4-oracles.R`
- Programme constitution Phase 4:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Definition of done

1. **(A)** Research note present and byte-identical to the sibling
   shared-worktree file (no nbinom1 registry row).
2. **(B)** Oracles present and passing; structured expect counts
   recorded from the test log; no live `estimator = "mspl"`.
3. **(C)** LOOP kit under this lane folder.
4. **(D)** Explicit-path commit + push + stacked PR on #971.
   No merge.

Finish line is **not** admission.
