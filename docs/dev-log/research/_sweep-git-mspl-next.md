# Sweep: git recon — MSPL next (Phase 0.25)

**Date:** 2026-08-15  
**Role:** read-only git recon (Cursor Models bar). No `src/`. No commit.  
**Workspace:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`  
**Constitution (Phase 4 / 5 / SE only):**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

Classification for every next move: **reuse** / **resume** / **build-the-gap**.

## 1. Commands cited

```sh
git status -sb
# ## cursor/mspl-phase4-tapes-planned...origin/cursor/mspl-phase4-tapes-planned
# (working tree clean)

git log --oneline -15
# f658fb96 docs(mspl): Wave 5 closeout for tapes-planned #978
# 57ae6983 feat(mspl): add five GLM-outer tapes and open the Poisson public door
# b1271cca docs(mspl): scaffold tapes-planned LOOP kit
# 2a99af3a Merge pull request #977 from itchyshin/cursor/mspl-phase4-prep-goal
# a14c8dfd test(mspl): pin the Phase-4 family fence
# 4fba4789 docs(mspl): record Phase-4 prep-goal verifier counts
# 77b37a7a docs(mspl): scaffold Phase-4 prep-goal LOOP kit
# cb126576 Merge pull request #971 from itchyshin/cursor/mspl-point-programme-continue
# … (Gaussian point + Poisson planned rows on main)

git worktree list
# this WT: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap  f658fb96  [cursor/mspl-phase4-tapes-planned]
# family prep WTs still live: mspl-phase4-{poisson,tweedie,nbinom2,beta,nbinom1}
# PROTECTED SE: /Users/z3437171/.codex/worktrees/8e9d/gllvmTMB  e91c7b7c  [codex/lane-b-mspl-interval-feasibility]
# Claude interval WT: /private/tmp/gllvmtmb-mspl-interval-calibration  0e05ed6f  [claude/mspl-interval-calibration]

gh pr view 978 --json state,mergedAt,url
# {"mergedAt":null,"state":"OPEN","url":"https://github.com/itchyshin/gllvmTMB/pull/978"}

# extra recon (same sitting; still read-only)
git rev-parse HEAD origin/main
# f658fb9679863f75ac6a1571a5299c4a617f2292
# 2a99af3a12b9d65c7f20754cf21604968780e639

git rev-list --left-right --count origin/main...HEAD
# 0	3   (0 behind main, 3 ahead)

gh pr view 978 --json title,baseRefName,mergeable,statusCheckRollup
# OPEN · base main · MERGEABLE · ubuntu-latest (release) IN_PROGRESS
# https://github.com/itchyshin/gllvmTMB/actions/runs/31903637769

ls docs/dev-log/after-task/*mspl*
```

## 2. Live git facts

| Item | Fact |
|---|---|
| Branch | `cursor/mspl-phase4-tapes-planned` @ `f658fb96` |
| `origin/main` | `2a99af3a` = merge of #977 (prep-goal kit). #971 already on main as `cb126576`. |
| This branch vs main | **3 commits, MERGEABLE.** Files: `src/gllvmTMB.cpp`, `R/mspl.R`, `R/mspl-registry.R`, five-atom note, public-door + fenced-tape tests, LOOP, after-task, handover. |
| Working tree | clean |
| PR #978 | **OPEN, not merged.** CI still running. Nobody admitted. |
| #972–#976 | still OPEN; base still `cursor/mspl-point-programme-continue`; MERGEABLE. Do **not** merge from this lane. |
| Codex SE | `codex/lane-b-mspl-interval-feasibility` @ `e91c7b7c` — PROTECTED. Classify only. |

## 3. After-task inventory (`docs/dev-log/after-task/*mspl*`)

| File | What it closed | Next implication |
|---|---|---|
| `2026-08-14-laplace-mspl-estimator-programme.md` | Phase 0 constitution | Binding Phase 4 / 5 / 7 (SE) text |
| `2026-08-14-mspl-arc-1a-provenance-parity.md` | Phase 1A | **reuse** — do not reopen |
| `2026-08-08-lane-b-binary-mspl.md` | Binary point surface | **reuse** for Bernoulli; SE stays isolated |
| `2026-08-15-mspl-catchup-phase2-phase3prep.md` | Phase 2 registry + Phase 3 prep | **reuse** |
| `2026-08-15-mspl-gaussian-psi-uniqueness-map.md` | Uniqueness pick C | **reuse** |
| `2026-08-15-mspl-gaussian-hirose-implement.md` | Gaussian Hirose `admitted` / `oracle_local` | **reuse** — Phase 3 ordinary closed |
| `2026-08-15-mspl-point-continue.md` | #971 A+B+C: Gaussian multi-seed + Poisson *planned* rows | **reuse** kit; Poisson still not admitted |
| `2026-08-15-mspl-poisson-phase4-prep.md` | Poisson derivation + E1–E7 oracles | **reuse** notes/oracles |
| `2026-08-15-mspl-phase4-prep-goal.md` | #971–#976 verifier counts; #977 merged | **resume** human retarget of #972–#976 |
| `2026-08-15-mspl-phase4-tapes-planned.md` | Five GLM-outer tapes + Poisson public door | **resume** #978 merge only |

Closed kits (do not reopen): `cursor-mspl-catchup`, `cursor-mspl-gaussian`, `cursor-mspl-point-continue`, `cursor-mspl-phase4-prep-goal`. Tapes GOAL is **LANDED** on #978, not on `main`.

## 4. Constitution — Phase 4 / 5 / SE only

Quoted from §11 and §6 of the 2026-08-14 programme.

**Phase 4 — Poisson, then NB2 and NB1.** One family and one boundary at a time. Poisson first: derive the information atom and coercivity for all-zero / near-zero designs; distinguish exposure/offset from information size. NB next: mean-boundary penalties are not dispersion \(0\) or \(\infty\) penalties; NB1 and NB2 do not inherit each other. **Exit gate:** family-specific symbolic/TMB oracles, healthy and boundary DGPs, recovery, prediction, and penalty sensitivity. **Finite count fits alone do not pass.**

**Phase 5 — Ordinal, multinomial, and other distribution parameters.** Order: ordinal-probit/logit; multinomial contrasts; beta / beta-binomial; Tweedie; truncated and delta/hurdle. Each cell gets its own boundary definition and evidence row. Issue #897 (ordinal degeneracy detector) **cannot** be used as MSPL evidence without a new MSPL-specific calibration. **Exit gate:** no shared-family claim.

**SE is not Phase 4 or 5.** It is **Phase 7 — Inference and model comparison.** Four constructions are distinct and must not be treated as interchangeable: penalized-objective profile (feasibility only until coverage); penalty-off likelihood curvature at the MSPL point (not ordinary ML Wald); estimator-refit bootstrap (needs known-DGP coverage); sandwich/Godambe (blocked until valid additive score units). `logLik` / AIC / BIC / LRT stay prohibited. §6: the Codex interval branch is **provisional** — 36/36 penalized-profile crossings, 12,000 bootstrap refits, penalty-off Wald on 21/36 targets (15 NPD). **No schema-v2 repeated-sampling coverage verdict.** Interval coverage is an inference-phase estimand only (§12).

## 5. reuse / resume / build-the-gap

### Reuse (already earned; do not rebuild)

- Phase 0 constitution; Phase 1A provenance; Phase 2 Bernoulli registry; Phase 3 Gaussian Hirose + uniqueness + 64/64 multi-seed point grid (`oracle_local`, not `covered`).
- Poisson Phase-4 *prep*: derivation note, E1–E7 oracles, `planned` / `phase4_prep` rows — on `main` via #971.
- Five-atom GLM-outer research note and fenced C++ tapes — on this branch / #978. Atom is GLM-outer \(\tfrac12\log\det(X^\top WX)\) at fixed-only \(\eta\), **not** \(I_{\mathrm{LA}}(\beta)\).
- Bernoulli 2-arg Jeffreys and Gaussian Hirose numeric paths and rates. Do not transplant \(c=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) or \(\sqrt{2/N}\) onto Poisson/NB.
- Binary point fences (Design 88). Codex interval artefacts are evidence to *read*, not a Cursor merge source.

### Resume (in flight; no new science)

1. **#978** — human review / merge when CI green. Poisson stays `planned`. This lane’s NEXT is merge, not a new tape.
2. **#972–#976** — prep notes/oracles only; CLEAN vs `main` and one commit behind (`cb126576`). Human retarget base → `main`. Do not merge from the tapes lane. Do not rebase onto #978.
3. **Codex `lane-b-mspl-interval-feasibility`** — resume only inside that worktree. Cursor classifies; does not absorb, rebase, or open Gaussian/Poisson SE.

### Build-the-gap (constitution exit not earned)

These are **new G0** items. None of them is authorized by the landed tapes GOAL.

| Gap | Why it is a gap | Smallest honest next |
|---|---|---|
| **Phase 4 Poisson exit** | Public door + GLM-outer tape ≠ admission. No multi-seed Poisson point grid. \(c=1\) unpinned. Laplace coercivity still OPEN in the prep note. Finite Poisson MSPL fits (the public-door smoke) **do not pass** the Phase 4 exit gate. | After #978 is on `main`: new GOAL for paired LA-ML vs LA-MSPL Poisson *point* smoke (`se=FALSE`), still `planned`. Admit / NEWS `covered` stay later G0. |
| **Phase 4 NB2 then NB1** | Constitution order is Poisson *then* NB. Tapes exist and stay fenced. NB2 is `excluded`. NB1 has no registry row. Public `mspl` still errors. | Do not open the door. After Poisson evidence (not merely the tape), a later G0 may unpin NB2/NB1 *prep→door* separately. They do not inherit Poisson’s atom or rate. |
| **Phase 5** | Constitution order starts at ordinal, then multinomial, then beta / Tweedie. Beta and Tweedie have fenced tapes + prep oracles only — that is **not** Phase 5. No ordinal/multinomial MSPL cell. #897 is not MSPL evidence. | Do not start Phase 5. Do not promote beta/Tweedie because the C++ hook exists. |
| **SE / Phase 7** | No schema-v2 coverage. Binary interval branch is PROTECTED and incomplete (15/36 NPD Wald). Gaussian SE and Poisson SE were explicitly deferred by every 2026-08-15 after-task. Sandwich is blocked. | Leave SE on Codex Lane B. New G0 required before any Cursor SE slice. |

## 6. Recommended next (this sitting)

**Resume #978.** Watch CI; merge is human. Do not admit Poisson. Do not merge #972–#976 from this lane. Do not touch `src/`. Do not open a Phase 4 evidence GOAL, a Phase 5 cell, or any SE slice without a fresh G0.

If Shinichi wants the next *scientific* lane after #978 lands, the constitution-shaped pick is **build-the-gap: Poisson Phase-4 point evidence** (paired, `se=FALSE`, still `planned`), not NB door, not ordinal, not intervals.
