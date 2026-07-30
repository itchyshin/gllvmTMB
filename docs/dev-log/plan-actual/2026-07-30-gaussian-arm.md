# Plan vs actual — the gaussian arm of Slice 1 (Melissa reconciliation)

Date: 2026-07-30. Reconciler: Melissa (via Claude). Lane: `claude/vgh-pluralism-20260730`.
Plan: `~/.claude/plans/gaussian-arm-of-slice-quirky-elephant.md` (approved after re-scope).
Close-out: `docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`.

Six axes: scope · evidence/verification · model routing · safety gates · public claims ·
handoff state. Material deviations only; wording and ordering changes are not drift.

## Slice-by-slice

| slice (planned) | actual | tag |
|---|---|---|
| **S0** comparability gate (Sonnet·high) | Ran. PASS — Laplace 60, VGH 79 identified, difference exactly 19; `extract_Sigma_B()` == `Λ̂Λ̂'` bit-identical; 6.4 s so the Totoro trigger never fired | **as planned** |
| **S1** pooled-φ + failing-first test (Sonnet·medium) | Ran. Six touch points as specified, plus a `phi_floor`; deliberate break confirmed the test fails; default path bit-for-bit identical | **as planned** |
| **A** collapse test, multi-start both arms (Sonnet·high) | Ran, 24 cells. **Adaptive deviation:** VGH could not be multi-started (no start argument), so the plan's "multi-start both arms" was met on the Laplace side only (`n_init = 5`) and mitigated by the mutual-comparison design. Later closed properly by the adversarial pass, which built a start-injectable copy and ran 8 random starts per cell | **adaptive** — recorded in the result doc |
| **B** degeneracy falsification (Sonnet·high) | **Converted** to a reachability negative result. The comparison was vacuous because gaussian *Laplace* does not degenerate, so there was no comparator. Ran 36 Laplace-only fits instead of a two-arm comparison | **adaptive** — justified in `2026-07-30-gaussian-has-no-degeneracy-tail.md` |
| **C** corrections (inline) | Ran, and **scope changed**: the planned charge (a "category error" in the 2026-07-29 docs) proved false on inspection, so C became one real correction (the engine mis-attribution) plus additive addenda, plus a retraction of my own charge | **adaptive** — the change is a correction of the plan's own premise |
| **SV** mechanical verify (Haiku·low) | **Substituted.** Not fired as a standalone slice; its content (all cells present, no all-NA, counts match, no cell at `maxit`) was implemented as the integrity block inside `gaussian-collapse-analyse.R` and reported in every run. Two workflow scope-agents also ran on Haiku·low | **adaptive** — covered, but not by the planned mechanism |
| **S7** adversarial claim gate (**Opus·high**) | Ran, and **it refuted a claim** — the no-tail headline. Verdicts: collapse SURVIVES (1 sub-claim wounded), df WOUNDED, no-tail REFUTED AS STATED, metric-artifact SURVIVES. Fired late (after two results had already landed) rather than as the gate before them | **drift → then remediated.** See below |
| **S8** close: after-task + handover + reconcile (Sonnet·medium) | Ran. After-task passes `closeout.py check`; handover written after `handoff_gate.sh`; this file | **as planned** |

## Unplanned work (maintainer-initiated, post-approval)

Three tasks arrived from the maintainer after plan approval and were executed as workflows:
the `d = 1` shape-collapse fix, the stale-`$elbo` back-port, and the `q = 1` test coverage.
**Not drift** — user-initiated scope, each verified to the same standard (failing-first test,
bit-for-bit backward compatibility, independent adversarial pass).

## Material deviations

**DRIFT — S7 fired late.** The plan placed the adversarial claim gate *before* the results were
relied on ("this output is what later slices rest on"). In fact `2026-07-30-gaussian-has-no-degeneracy-tail.md`
and `2026-07-30-gaussian-collapse-test-result.md` were both written, committed **and pushed**
before S7 ran — and S7 then refuted the first one's headline. The ordering was noticed and the
gate fired unprompted, but the sequence meant a refuted claim sat in `origin` for roughly an hour,
and a directed cross-lane note in `check-log.md` carried the bad number to another lane in the
interim. Remediated: headline withdrawn and replaced, the check-log note corrected in place rather
than appended, and no external claim was made from it. **Route to: Rose (closeout/claims).**
*Process fix worth considering: for a lane whose output is a claim, treat "committed" and
"adversarially gated" as the same gate, not sequential ones.*

**ADAPTIVE — the whole arm was re-scoped before approval**, from a 3×3 accuracy grid (324 fits)
to three cheaper tests, on the same-objective finding. Approved explicitly by the maintainer via
`AskUserQuestion` plus a pasted GOAL block. Cheaper and answers a non-vacuous question.

**ADAPTIVE — the maintainer's chosen "fixed-at-truth" second matching arm was dropped** as
unreachable from the public API (`log_sigma_eps` is mapped off only under conditions that are not
control arguments). Substituted with the `d_ll`-collapse test, which is falsifiable rather than
assumed. Recorded in the plan and the result doc, but note this **changed something the maintainer
had explicitly selected** — surfaced in-session rather than silently swapped.

**ADAPTIVE — `devtools::check()` and the full `devtools::test()` were not run.** The plan's
verification list included the narrow tests, not a full check, so this is not a dropped slice —
but it is a real evidence gap, declared in the after-task §5 and §10 and in the PR's review asks.
Cause: two workflows and a background campaign were concurrently active.

**NO DRIFT on safety gates.** `R/` and `src/` byte-identical to `main`; `NEWS.md` and
`check_gllvmTMB()` untouched; no self-merge on a PR outside the low-risk set; Codex lanes and the
LA/AGHQ/ridge lane fenced; the one finding belonging to another lane was raised, not acted on;
compute stayed local per D-50 with the Totoro trigger measured and unfired; nothing deleted.

**NO DRIFT on public claims.** No claim reached a public surface (no `NEWS.md`, no roxygen, no
article). Two claims were retracted before any external use. The `AGENT-INFERRED` tag on the
saturation mechanism was carried until it was *derived*, then upgraded with the derivation shown.

## Model routing — actual

| tier | planned | actual |
|---|---|---|
| Haiku / scout | 1 (SV) | 2 (recon sweep; two workflow scope-agents) |
| Sonnet / build | 4 | 9 across 3 workflows + 3 standalone |
| Opus / ceiling | 1 (S7) | 1 (S7) — the claim gate, as planned |

**Child budget.** The plan declared 6 post-checkpoint children. Actual is higher, because three
maintainer-initiated tasks arrived after approval, each dispatched as its own workflow. Each new
task is its own checkpoint under the fan-out rule, so this is **not** a budget breach — but it is
worth recording that a plan's child budget does not survive mid-arc scope additions, and nobody
re-declared it. Exactly one Opus child across the whole session.

## Recurring-class candidates for `PLAN-DRIFT-LEDGER.md`

1. **"Adversarial gate scheduled but fired after the artifact shipped."** Second-order effect here
   was a wrong number reaching another lane's message bus. Candidate for a hard ordering rule.
2. **"Child budget not re-declared when the maintainer adds scope mid-arc."** Benign this time;
   would hide a real overrun on a longer arc.
3. **"Verification slice absorbed into a script rather than fired as planned"** (SV). Covered in
   substance, but the routing receipt cannot see it, so a mechanical-verify slice looks skipped.
