# Session Handoff → next Claude: Lane B — structured × X_lv (orthogonal Model A extension)

**Meta:** 2026-07-16 PM · from Claude (Lane B) · to the next Claude · branch
`claude/lvb-modelA-extend` (worktree `~/gllvm_work/lvb-modelA-extend`, off `claude/release-0.5.0`
@ 48a66b93). **You are picking up Lane B — the X_lv / Model A extension arc. Lane A (Sigma_unit
coverage) and Lane C (categorical/multinomial) run in parallel; do NOT touch their files.**

> **You are Claude, resuming Lane B.** Read this doc, then the after-task report it links, then
> spawn Rose before any public claim. Everything below is branch-staged / dev-only — **nothing is
> merged or advertised.**

## Goals / mission
gllvmTMB 0.5→0.6 "cover everything" dev cycle (release at 0.6, D-42). Lane B extends the
already-certified orthogonal **Model A** (`latent(0+trait|unit,d=K,lv=~x)` + a SEPARATE orthogonal
source term; estimand `B_lv = Λ_B·α^T`, register `LV-09` = `partial`) to the genuinely-open cells:
**rank-2 Gaussian · non-Gaussian families · animal/spatial/kernel sources.** NO new likelihood, NO
grammar keyword — compose existing capabilities.

## Critical Context (read or you WILL go wrong)
1. **This is NOT the interacting `phylo_latent(lv=~x)` model.** That arc (a new TMB likelihood) was
   maintainer-DEFERRED on 2026-07-06 (Design 76 §7 UPDATE; 07-08/07-09 handovers) — a 3-member
   plan-review caught the near-miss. **Do not build it.** Lane B extends the orthogonal Model A.
2. **`B_lv` is a MEAN coefficient → Wald is the correct interval, NOT profile.** Real Totoro coverage
   (rank-2 Gaussian, n≈407): **Wald 0.953 (nominal ✓)**, profile-chisq 0.914–0.916 (UNDER-covers),
   t-df 0.919. Verified real (not an optimizer artifact). The profile/log-SD/t-df doctrine is for
   **variance components** (Lane A's world), NOT this mean coefficient. Report rank-2 Gaussian as
   Wald-based with profile under-coverage flagged.
3. **OPTIMIZER: use the DEFAULT optimizer for non-Gaussian.** `optimizer="optim"/BFGS` gives a non-PD
   Hessian on hard likelihoods (Poisson/Gamma/nbinom2 → `pdHess=FALSE`, NA SEs); the default `nlminb`
   gives `pdHess=TRUE` + clean SEs, identical recovery (verified). Gaussian is unaffected. The current
   harnesses use BFGS — **switch non-Gaussian harnesses/tests to the default optimizer before any
   non-Gaussian interval claim.**
4. **Coverage harnesses load `library(gllvmTMB)` = installed stock 0.5.0.** So a family the guard
   newly admits (Poisson) is STILL rejected by the installed package → its coverage smoke shows
   `converged=FALSE`. **To run a non-Gaussian campaign you must `R CMD INSTALL` this worktree's package
   first** (on Totoro / locally). The admission code itself works under `load_all`/`devtools::test`.

## What Was Accomplished (all verified by REAL fits; see the after-task report for detail)
- **S0 frontier** (3 fronts, real fits) — `docs/dev-log/artifacts/model-a-extend/frontier.md`.
- **S1 rank-2 Gaussian:** recovery test passes (heavy); coverage harness `dev/modelA-rank2-coverage.R`
  → **Wald 0.953 nominal** on Totoro (n≈407).
- **S3 kernel + animal:** compose + recover B_lv (0.18); harness `dev/modelA-source-coverage.R`;
  coverage running on Totoro. **spatial marginal** (fits intermittently, weak recovery ~0.25) — no test.
- **S2 Poisson ADMITTED** (maintainer-authorized 2026-07-16): guard lifted in `R/lv-predictor.R`,
  `test-lv-native-nongaussian-guard.R` flipped (Poisson→accept; all others still reject),
  `test-lv-modelA-poisson.R` + `dev/modelA-poisson-coverage.R` added.
- **Non-Gaussian family diagnostics** (parallel Workflow): **Gamma + Beta cleanly admittable** (engine
  handles them, recovery 0.08 / 0.18, pdHess=TRUE with default optimizer); **nbinom2 HOLD** (recovers
  point but SEs unreliable + dispersion confound).

## Current Working State
- **Working:** rank-2 Gaussian coverage (Wald 0.953); Poisson admission code (verified on disk);
  Gamma/Beta admittability evidence; the optimizer finding; frontier for all 3 fronts.
- **In progress (BACKGROUND, crosses session boundary):** the Totoro Gaussian campaign — rank-2
  ~96/100 done, **kernel + animal still running** (~1–1.5 h to full 500/cell), `tmux lvbcov` on
  Totoro, results at `~/gllvm_work/lvb-modelA-extend/results/` (Totoro-side) — **NOT pulled to the
  Mac yet.** Two build agents (Poisson, spatial) had a slow `checkConsistency` tail; their FILE
  deliverables are already on disk (this session's agents die when the session ends — no loss).
- **Blocked / gated:** Gamma+Beta admission code (maintainer per-family sign-off); Poisson coverage
  campaign (needs the modified pkg installed on Totoro); nbinom2 (SE fix); spatial (richer fixture);
  ordinal (Lane C). No LV-05/09 promotion or public wording until Rose audit on final numbers.

## Key Decisions & Rationale
- **Extend Model A, not the interacting model** (maintainer, 2026-07-16) — the interacting arc is
  deferred/obsolete.
- **Per-family admission, no inheritance** (Design 76 §2.3): each family gets its own guard-lift +
  recovery + ADEMP gate. Poisson done; Gamma/Beta staged; nbinom2/ordinal held.
- **Reuse Lane A's `profile_ci_lv_effects()` READ-ONLY** (`R/profile-derived.R:1591`, `gllvmTMB:::`) —
  never edit it (Lane A's file). A new B_lv profile route, if built, goes in a NEW `R/profile-lv.R`.
- **Interval = natural-scale Wald-z** (hero for the B_lv mean coefficient); profile is a
  reported comparison, not the certifier here.

## Landing State (git ledger)
| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/lvb-modelA-extend` (Lane B code + docs) @ this handover | y (this commit) | **n** | none | **CARRIED-OVER** |
| Totoro Gaussian campaign (kernel/animal) | n/a (compute) | n/a | — | **RUNNING** — pull + summarise next session |
| Gamma/Beta/Poisson coverage campaigns | n/a | — | — | **NOT STARTED** (need pkg install; default optimizer) |

**CARRIED-OVER — why not landed / how to resume:** the branch holds **unsigned code** (Poisson family
admission — a maintainer discussion-checkpoint). **Do NOT push/PR/merge without Shinichi's per-family
sign-off.** It is committed LOCALLY on this Mac; a same-machine Claude resume sees it. If a fresh
checkout or Codex must resume, **push is the human's call** (say so). `results/` is **never-committed**
(heavy sim output) — the Totoro copy is the source of truth.

## Next Immediate Steps (ordered)
1. **Pull + summarise the Totoro Gaussian campaign** once `results/DONE.flag` appears (or kernel/animal
   hit 100/100): `ssh totoro 'cd ~/gllvm_work/lvb-modelA-extend && Rscript dev/modelA-source-coverage.R
   summarise results/modelA-source-coverage'`. Expect kernel/animal Wald ≈ nominal like rank-2.
2. **S5 Rose claim audit** on the final coverage numbers — the gate before ANY LV-09 promotion/wording.
3. **Admit Gamma + Beta** (same pattern as Poisson, DEFAULT optimizer): guard-lift in `R/lv-predictor.R`
   + flip guard test + recovery test + harness.
4. **Poisson coverage:** `R CMD INSTALL` this worktree on Totoro, add `modelA-poisson-coverage.R` (fixed
   to default optimizer) to the campaign.
5. nbinom2 SE fix; spatial richer-fixture frontier; ordinal → Lane C coordination.

## Blockers / Open Questions
- Per-family admission sign-off (Gamma/Beta) is Shinichi's call.
- Totoro core coordination with Lane A's n_sim=5000 grid (see the check-log directed note — stagger).
- Push/PR of the Lane B branch is the human's call (unsigned code).

## Gotchas & Failed Approaches (do NOT retry)
- **Do NOT rebuild the interacting `phylo_latent(lv=~x)` model** — deferred/obsolete.
- **Totoro detached launches:** inline `ssh→xargs→sh -c` with nested quoting is fragile AND doesn't
  persist. Use a **launcher-script file under `tmux`** (`dev/totoro-launch-modelA-coverage.sh` pattern
  + `run_campaign.sh`). And **don't panic-`pkill`** on a low proc count — verify with `pgrep -f exec/R`
  + CSV mtime first (I once killed a healthy campaign; another time nearly killed Lane A's job).
- **Socket path:** the Totoro ControlMaster socket is `~/.ssh/cm-*totoro*` (the `cm-` PREFIX, not a
  `cm/` subdir). Passwordless; do NOT ask to open a session. (Fixed in AGENTS.md.)
- **Don't claim profile is the B_lv interval hero** — it under-covers (0.916); Wald is (0.953).

## How to Resume
Read in order: **this doc → `docs/dev-log/after-task/2026-07-16-modelA-extend-arc-kickoff.md` →
`docs/dev-log/artifacts/model-a-extend/frontier.md` → the check-log 2026-07-16 PM notes.** Then pull
the Totoro campaign (Step 1), spawn **Rose** before any coverage claim.

**One-command resume (paste in an authenticated terminal at `~/gllvm_work/lvb-modelA-extend`):**
```
claude "Rehydrate from docs/dev-log/handover/2026-07-16-lvb-modelA-claude-handover.md + the after-task report, then continue with the Next Immediate Steps: pull+summarise the Totoro Gaussian campaign, then Rose-audit the coverage numbers. Do NOT build the interacting phylo_latent(lv=~x) model; do NOT touch Lane A/C files; use the DEFAULT optimizer for non-Gaussian."
```

## Mission-control summary
| repo · branch · state | what shipped this arc (Lane B) | next by leverage |
|---|---|---|
| gllvmTMB · `claude/lvb-modelA-extend` (branch-staged, unmerged) | Extend orthogonal Model A: rank-2 Gaussian coverage **Wald 0.953 nominal** (profile under-covers — real); **Poisson admitted**; Gamma/Beta admittable; optimizer + package-install findings; frontier for 3 fronts | **1** pull+summarise Totoro kernel/animal · **2** Rose audit · **3** admit Gamma/Beta (default opt) · **4** Poisson coverage (install pkg) · **5** nbinom2/spatial/ordinal held |
