# Claude → Claude handover, 2026-07-28

You are Claude, picking up the **VA/EVA + AGHQ lane** of `gllvmTMB`.
Author: Claude, 2026-07-27/28 session. Lane: `claude/va-wiring-20260726`
(**PR #798, CI GREEN**), worktree `/private/tmp/gllvmtmb-va-wiring-20260726`.

**Read the one-page morning brief first:**
`docs/dev-log/2026-07-28-morning-brief.md`. This document is the detail behind it.

---

## Mission control

| | |
|---|---|
| **repo** | `gllvmTMB` · `main` at `dc10fa6a` |
| **PR #799** | **MERGED** (maintainer signed off) — diagnostic fix + `res` soft-deprecation |
| **PR #798** | **OPEN, CI GREEN**, 15 commits, awaiting review. No API change, no export |
| **suite** | `FAIL 0 · WARN 2 · SKIP 782 · PASS 7710` |
| **hygiene** | NAMESPACE diff 0 · `src/gllvmTMB.cpp`, `R/gllvmTMB.R` untouched · nothing exported |
| **estimation route** | Laplace remains the ONLY user-reachable route. VA/EVA are internal research |
| **decision made** | **Invest in Laplace + AGHQ. Freeze VA.** |
| **next arc** | Settle the 59/70 identifiability question (~2 h 20 m), then AGHQ-LA at q ≤ 3 |

## ⚠ Multi-lane — do not narrow the pointer

This repo runs **multiple fenced lanes**. `docs/dev-log/handover/2026-07-25-active-lane-split.md`
remains the START HERE map and lists every lane. This handover covers **only** the
VA/EVA + AGHQ lane. Carried forward, unchanged and still owned elsewhere:

* **Eta simulation / Design-100** — Codex, `/private/tmp/gllvmtmb-design100-progress-oracle`.
  Claude must not run, edit, claim or absorb it.
* **Design-103** — Codex, closed `TECHNICAL_PARTIAL`, local-only, no public claim.
* **HVT-1** — `ORACLE_NOT_CERTIFIED`; next numerical-method arc needs Shinichi's approval.
* **0.6 release / M5** and **Profile / Tier-2a** — separate handovers; re-derive from git.
* **Standing interest (Shinichi, 2026-07-25):** EVA is cut from 0.6 to 0.7 and Codex-owned.
  Picking it up is a lane-reassignment decision, not agent initiative.

## Goals / mission

`gllvmTMB` = multivariate stacked-trait GLLVMs with phylogenetic and spatial
extensions. First CRAN release is **0.6.0**, not 1.0. The ultimate goal behind
this lane was **LA/VA parity**; that goal was **redirected** on evidence this
session — see *Decisions*.

## What was accomplished

**PR #799 (merged, `dc10fa6a`)**

1. **A real detection bug fixed.** A collapsed variance component passed every
   check: `check_gllvmTMB()` printed `near_zero_psi_unit … PASS … 0.0006826` for
   a component whose *variance* was `4.7e-7` against siblings near 1.0. Two blind
   spots — the threshold is `1e-4` on the **sd** scale (demanding variance
   `< 1e-8`), and `pdHess` is structurally blind because `psi` is on the log
   scale. Detection is now relative to siblings.
2. **`start_method = "res"` soft-deprecated** on 89 fit-pairs.
3. **Two negative results recorded** (below).

**PR #798 (open, green)** — three deliverables, all with evidence:

| deliverable | evidence |
|---|---|
| per-family **registry** | 4 of 16 families; proven by porting **nbinom2** through it — one entry + one likelihood branch reusing the existing GH helper via a shifted call, ~20 edits |
| **calibrated VA SEs** | `se_profile` covers **0.935–0.950** vs nominal 0.95; naive `se_conditional` under-covers everywhere (0.885–0.910). Block-diagonal Schur replaced a **5.45 GB** dense Hessian → **9.1 s / 220 MB** at n=5397, verified against dense to **1.5e-10** |
| **Ayumi-scale second opinion** | n=5397: Laplace `rel_frob` 0.167 / atten 0.875 · VA-GH **0.103 / 0.949** |

Plus `optimizer = "auto"` routing per family **and per tier**, and the AGHQ q=2
transfer test (below).

## Key decisions & rationale

**Invest in Laplace + AGHQ; freeze VA.** The deciding argument was **coverage,
not accuracy**: AGHQ is a refinement layer on the Laplace objective, so it
inherits all 16 families, phylogeny, spatial and missing data. VA reaches 4 of
16, rejects `structured` and `missing`, and covers **2 of Ayumi's 27 responses**.
VA-GH recovers `Sigma_B` best and *still* cannot express her model.

Measured support:

| | Laplace | AGHQ | cost |
|---|---|---|---|
| q=1, n=2000, 3 seeds | 0.8968 | **0.9507** | 1.67× |
| q=2, n=2000, **5/5 seeds** | 0.9215 | **1.0438** | 3.40× |

`c_full` = **1.064** at q=2 vs a predicted 1.02–1.04 band; the kill rule
(`< 1.01`), written **before** the run, was cleared. **The q=1 result transfers.**

**`optimizer` routes per TIER, not per family** — binomial's tiers point in
opposite directions (jj → `lbfgsb` 2.54×; **gh → `nlminb`, because `lbfgsb` is
1.7× slower there**). A family-level choice would have slowed the accurate tier.

## Current working state

* **Working:** everything above; suite green; PR #798 CI green.
* **In progress:** none. The arc is closed.
* **Blocked:** nothing.

## Files created / modified

47 files vs `origin/main`. Highlights (full list: `git diff --name-only origin/main...HEAD`):

* `R/va-r3-proto.R` — registry (`optimizer_by_tier`), `.va_r3_latent_posterior()`,
  `.va_r3_fixed_information()` + `_blocked()`, `.va_r3_variational_index_map()`,
  `.va_r3_resolve_optimizer()`, `n_starts`, nbinom2
* `R/approximation-engine.R` · `inst/tmb/gllvmTMB_va_r3.cpp` (nbinom2 branch)
* `tests/testthat/test-va-r3-prototype.R` (+~350 assertions)
* `docs/dev-log/2026-07-28-morning-brief.md` ← **read first**
* `docs/dev-log/after-task/2026-07-27-va-parity-tier1-close.md`
* `docs/design/109-bound-tightness-vs-recovery.md` · `110-pg-closed-form-updates.md`
* `dev/aghq-crux-q2-transfer.R` + `dev/aghq-q2-seed1{1..5}.csv` (TEST C)
* `dev/aghq-scope-{gap,cost,accuracy-crux}.md`
* `dev/r2-fragility-resolution.csv` · `dev/lbfgsb-default-*.{R,csv,md}`
* On `main` via #799: `dev/relative-collapse-vs-59of70.*`,
  `dev/lambda-spectrum-vs-degeneracy.*`, and their two write-ups
* This handover + the CLAUDE.md snapshot edit

## Next immediate steps

1. **Review / merge PR #798** — green, no API change, not in the
   discussion-checkpoint set. Your call.
2. **Arc 0 — settle the identifiability question (~2 h 20 m).** Three hypotheses
   about the 59/70 have died. The survivor: those fits may be **well-converged
   optima of models the data does not identify**, in which case
   `convergence == 0` and `pdHess = TRUE` are *true statements*, **no fit-side
   diagnostic can flag them**, and the deliverable is an **identifiability
   warning**, not a better estimator.
   Test: for the 16 degenerate + 16 healthy cells already re-fitted in
   `dev/lambda-spectrum-vs-degeneracy.csv` (on `main`), measure multi-start
   agreement and profile curvature along the trailing eigenvector of
   `Lambda_B Lambda_B'`. **The healthy group is the mandatory control.**
   Reuse the refit fixture in `dev/lambda-spectrum-vs-degeneracy.R`.
   **Do this before building anything** — it changes what "better" means.
3. **Then AGHQ-LA as an opt-in refinement, q ≤ 3.** Days, not weeks: the O3 spike
   reproduces our joint TMB Laplace objective to **1.4e-9** at one node, so it is
   an outer layer, not a new template. Node ladder converges by **k = 5–9**.

## Blockers / open questions

* **AGHQ overshoots at q=2** (attenuation 1.044 vs Laplace's 0.92 undershoot).
  Acceptance must be `|attenuation − 1|`, **not** "higher is better"; the sign
  flip from q=1's 0.951 is unexplained at 5 seeds.
* **Cost model:** 3.40× at q=2, not the 1.67× measured at q=1.
* **`H^q`:** 81 nodes at q=2, **2,401 at q=4** — low-q only.
* The **59/70 remains undiagnosed** after three failed hypotheses.

## Gotchas / failed approaches — do not repeat

* **`profile=`, not `random=`**, if VA is ever unfrozen: `random=` adds a Laplace
  log-determinant and **silently changes the objective**.
* **Closed-form Pólya-Gamma** is verified sound (gradient `1.55e-15` at the fixed
  point, monotone) but **JJ-only**, so it accelerates the arm that recovers
  *worst*. Not worth building while VA is frozen.
* **Do not re-propose the GLMM/BLUP start** — built, measured, reverted as a
  4/4 → 0/4 regression (`10b742f2`). It still sounds right.
* **Never time from a single sequential pass.** ~3× first-fit penalty. One
  binomial pair read **16.4×** with the cold start included and **2.54×**
  warm-vs-warm.
* **`lbfgsb` needs `factr = 1e-12/.Machine$double.eps`.** With optim's *default*
  `factr` it terminates in ~24 ms at an objective 125–151 worse, reporting
  `convergence = 0`, 3/3 reps at N=1600.
* **Do not assert `dense$status == "ok"`** — dense-Hessian PD-ness is
  BLAS-dependent (passes macOS, failed Linux CI). Guarded, not weakened.
* **Three silently vacuous verifications** were found: `grepl("converged", …)`
  matching `"not_converged"`; a comparison auto-dispatch turned into
  blocked-vs-blocked; a suite running new tests against a stale namespace. **Check
  that a test can still fail.**
* **Editing files under a running job breaks it** — a signature change cost a
  6815 s fit its SE step. Twice this session.
* **Control defects:** three were found in one script (missing family filter →
  byte-identical groups; blanket seed exclusion → empty control; exact `(n,p,q)`
  matching → 1 control cell). **Always inspect the control before the result.**

## Corrections issued this session

Five claims retracted, four of them the author's own:

| claim | reality |
|---|---|
| "L-BFGS-B is 16× at n=800" | 0.9× as a *polish*; 17.7–37.7× as the *primary* optimiser |
| "VA cannot fit n=5397" | It can — ~500 s, `convergence = 0`. A budget wall, not a capability wall |
| "gllvm profiles the variational block" | They do not — same joint optimisation, no `random=` |
| "we use gllvm's most expensive covariance" | Their latent default is `unstructured`, same as ours |
| "lbfgsb should be the default" | 1.7× **slower** on binomial-gh, 2.4× on nbinom2 |
| after-task §6a: 59/70 is "the same failure mode" | **Refuted** — 0/22 flagged; corrected in place on `main` |

## How to resume

```bash
cd /private/tmp/gllvmtmb-va-wiring-20260726
git fetch origin && git status -sb
```

Read, in order: `docs/dev-log/2026-07-28-morning-brief.md` → this file →
`docs/dev-log/handover/2026-07-25-active-lane-split.md` (lane map) →
`docs/dev-log/after-task/2026-07-27-va-parity-tier1-close.md`.

Spawn the **Rose** lens before any public or capability claim.

**One-command resume — paste in your own authenticated terminal, from the repo root:**

```
claude "Rehydrate from docs/dev-log/2026-07-28-morning-brief.md and docs/dev-log/handover/2026-07-28-claude-handover.md plus the CLAUDE.md Live Phase Snapshot, then start Arc 0: settle whether the campaign's 59/70 degenerate fits are genuine optima of unidentified models or failed optimisations, using multi-start agreement and trailing-eigenvector profile curvature on the 16+16 cells in dev/lambda-spectrum-vs-degeneracy.csv. The healthy group is the mandatory control. Do not touch R/diagnose.R in this arc. Do not build AGHQ until this rules."
```

Autonomous variant: same prompt with `claude -p "…" --max-budget-usd <cap>`.

## Scope limits on the evidence

VA admits 4 of 16 families, binomial **logit** only, and rejects `structured`,
`missing` and incomplete cells. Coverage evidence is beta-only, q=2, p=8,
n ∈ {150,400}, 25 seeds. AGHQ numbers are one DGP, 3–5 seeds, one OS, one BLAS,
partly on a contended machine. `devtools::check()` and pkgdown were **not** run.
