# LA-MSPL next GOAL — Phase 0–2 ultra-plan (finish MSPL, allow SE)

**Author:** Ada · **Platform:** Cursor (solo) · **Date:** 2026-08-15
**Bar:** written entirely on **Other Models** (the only ceiling child at the
time of writing). Four recon scouts ran in parallel on **Cursor Models**.
**Status:** PLAN ONLY. Phase 0.25 receipt, Phase 1 slice table, Phase 2 wave
design, Phase 0.4 questions. **Phase 3 is NOT executed here.** No `src/`,
no `R/`, no LOOP kit, no merge, no admit.

This is **LA-MSPL** — Laplace integration with a soft *outer* criterion —
not EVA, not VA, not AGHQ-MSPL.

> **Reader, start here.** The one thing that changed my plan between the
> first draft and this one: I believed there was an unfenced hole where
> `se = TRUE` reached `TMB::sdreport()` on an MSPL fit. **That is false.**
> `R/fit-multi.R:6423` in this tree already sets `sd_rep <- NULL` for
> `estimator == "mspl"` and records a withheld-SE message. MSPL refuses
> standard errors **at the estimator, not at the family**. So "allow SE"
> cannot mean "flip a switch" — it means *name a new private construction
> and measure whether it can even be formed.* The whole plan turns on that.

---

## 1. 🎯 GOAL block

```text
🎯 GOAL
Solo platform: Cursor
Deliverable: one named, internal, non-exported SE construction for LA-MSPL on Poisson and Bernoulli, plus an availability-only feasibility pin measuring whether that construction can be formed at all
HEADLINE: MSPL withholds standard errors at the estimator; we name ONE construction, measure how often it exists and how often its curvature is usable, and we admit nobody
IN PARALLEL: Shannon lane hygiene · construction recon · read-only Codex 36-cell lesson transfer · Poisson/Bernoulli fixture inventory · symbolic SE contract · availability-pin pre-registration · failing tests · one cpp owner · Rose fence · handover
DEFER: calibrated SE · coverage/width/nominal-95% · public vcov()/confint()/profile_targets()/standard_errors() on MSPL · Poisson admit · NEWS covered · public mspl on NB1/NB2/beta/Tweedie · Gaussian SE · penalised profile route · Totoro/DRAC campaign · jackknife · Godambe/sandwich · merging any interval branch · Phase 1B API policy
DISCIPLINE: verify=failing tests before any src/ or R/ edit · compute=local, OMP_NUM_THREADS=1, nothing over 30 min · closure=one construction named, availability + PD rates recorded with every attempt in the denominator, non-PD retained unrepaired, Rose PASS, nobody admitted
```

**Finish line:** an *availability* answer — can the SE be formed, and how
often is the curvature usable. Never a *coverage* answer. Coverage was
already measured on the binary surface and no method passed the gate (§2.4).

**Base:** a NEW lane branch cut from `main` **after [#978](https://github.com/itchyshin/gllvmTMB/pull/978) merges.** Not from
`cursor/mspl-phase4-tapes-planned`. Shannon's WARN (§2.1) makes this
non-negotiable.

---

## 2. Phase 0.25 — orientation receipt

### 2.0 Scout reconciliation — and one correction to me

The four scout receipts were **absent** when I began and **landed while I
was drafting**. I had already swept independently. Reconciliation:

| Scout | Agrees with my sweep? | Net effect |
|---|---|---|
| `_sweep-shannon-mspl-next.md` | Yes, and goes further | **WARN**: 6 open MSPL PRs against a soft cap of 3; #978 CI `IN_PROGRESS`/`UNSTABLE`; 16 branch switches on this worktree in 12 h; do not push while the run is live |
| `_sweep-git-mspl-next.md` | Yes | Adds the reuse/resume/build-the-gap classification and the exact constitution quote placing **SE in Phase 7, not Phase 4** |
| `_sweep-codex-interval-mspl-next.md` | **No — corrects me** | **Refutes my §2.3 hole.** Also supplies the private construction map and the per-cell coverage numbers |
| `_sweep-brain-mspl-next.md` | Partly — my brain query was too shallow | Surfaces **D-112**, **D-135**, **D-141**, and a homonym trap I fell into |

**My error, corrected.** I read `R/fit-multi.R` around the `sd_report =
sd_rep` assignment (line ~6481), found no MSPL guard in the surrounding
lines, and recorded a suspected unfenced `se = TRUE` path as an
*unconfirmed* reading. The Codex scout pointed at the actual guard and I
verified it directly in this tree:

```r
# R/fit-multi.R:6422-6431
sdreport_error <- NULL
sd_rep <- if (identical(estimator, "mspl")) {
  sdreport_error <- paste(
    "LA-MSPL is an experimental point estimator;",
    "standard errors are withheld until repeated-sampling calibration"
  )
  NULL
} else if (isFALSE(control$se)) {
  ...
```

The guard is 58 lines above where I stopped reading. There is no hole.
This deletes an entire work item from the plan and rewrites Q3.

**My second error.** My brain query (`"MSPL standard errors intervals
decision gllvmTMB"`) returned noise and I concluded "no durable vault
decision authorising MSPL standard errors." That conclusion happens to be
right, but I reached it by a query too weak to support it. The brain scout
ran eight queries plus two ledger greps and found the real content: **D-112,
D-135, D-141** (§2.6). One of them — D-135 — creates a live conflict with
the registry that I would have missed entirely (§5, 🔴 FLAG).

### 2.1 Repository, lane, and process state

```sh
git rev-parse HEAD          # f658fb9679863f75ac6a1571a5299c4a617f2292
git branch --show-current   # cursor/mspl-phase4-tapes-planned
git rev-list --left-right --count origin/main...HEAD    # 0  3
gh pr list --state open --limit 20
git log --all --oneline --since="6 hours ago"
~/shinichi-brain/tools/lane_preflight.sh                # via Shannon scout
```

| Fact | Value |
|---|---|
| Worktree | `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` (never Dropbox) |
| Branch / HEAD | `cursor/mspl-phase4-tapes-planned` @ `f658fb96`, clean, 3 ahead of `main`, 0 behind |
| `origin/main` | `2a99af3a` (merge of #977) |
| PR [#978](https://github.com/itchyshin/gllvmTMB/pull/978) | OPEN · MERGEABLE · **UNSTABLE** · ubuntu-latest CI **IN_PROGRESS** · not admitted |
| Stacked prep PRs | [#972](https://github.com/itchyshin/gllvmTMB/pull/972)–[#976](https://github.com/itchyshin/gllvmTMB/pull/976), all OPEN, all still based on the already-merged `cursor/mspl-point-programme-continue`; need human retarget; **do not merge from this lane** |
| Cross-repo evidence | [#955](https://github.com/itchyshin/gllvmTMB/pull/955) drmTMB non-logit findings, OPEN, CI green, evidence-only |
| 🔴 Shannon verdict | **WARN** — 6 open Cursor MSPL PRs vs a soft cap of 3 |
| Foreign lanes live | Codex `codex/lane-b-mspl-interval-feasibility` (PROTECTED) · Claude `claude/mspl-interval-calibration` at `/private/tmp/gllvmtmb-mspl-interval-calibration` · an active `isdm` lane committing in the same window |
| Design numbers | 15 duplicate slots across refs; next free is **117**. Do not mint one from this checkout |

**Process consequence.** Shannon's next-action is *"the next MSPL act is
human merge of #978 after CI."* This GOAL therefore does not start on this
branch. It starts on a new lane cut from `main` once #978 lands, and it
touches none of #972–#976.

### 2.2 What is already earned (do not rebuild)

From `_sweep-git-mspl-next.md` §5 and `R/mspl-registry.R`:

| Family | Public `estimator="mspl"`? | Registry status | Evidence |
|---|---|---|---|
| binomial (logit / probit / cloglog) | yes | `admitted` | `partial_b2_incomplete` |
| gaussian (identity) | yes | `admitted` | `oracle_local` (Hirose pick C, **pinned `sigma_eps`**) |
| poisson (log) | yes — experimental door | `planned` | `phase4_prep` |
| nbinom2 | no — prepare rejects | `excluded` | — |
| nbinom1 / beta / tweedie | no — prepare rejects | **no row** | — |

Verified: `R/mspl.R:182` fences `fam_ids %in% c(0L, 1L, 2L)`; eleven
`test-mspl-*.R` files exist. Phase 0 constitution, Phase 1A provenance,
Phase 2 Bernoulli registry, and Phase 3 Gaussian Hirose are all **reuse** —
closed, not reopened.

Load-bearing from
`docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`: the atom is
**GLM-outer** `½ log det(X*' W X*)` at the fixed-effect-only linear
predictor — explicitly **not** `I_LA(β)` — and the Poisson rate `c = 1` is
an unpinned placeholder that does **not** vanish with `N`.

### 2.3 The SE surface as it actually stands

Three findings, all verified in this tree.

1. **MSPL withholds `sdreport()` at the estimator level**
   (`R/fit-multi.R:6423`, quoted in §2.0). `gllvmTMBcontrol(se = TRUE)` on
   an MSPL fit does not reach the TMB path at all. There is **no hole**.
2. **The post-fit fence is broad.** `.gllvmTMB_n()` /
   `.gllvmTMB_mspl_assert_inference()` fires from 27 call sites —
   `standard_errors()`, `vcov()`, `confint()`, `profile_targets()`,
   `tmbprofile_wrapper()`, `loading_ci()`, `bootstrap_Sigma()`, `getREsd()`,
   `getLV(se = TRUE)`, `predict(se.fit = TRUE)`, `tidy(conf.int = TRUE)` —
   raising `gllvmTMB_mspl_inference_unsupported`.
3. **Phase 1A already built the two-tape scaffolding a construction needs.**
   `R/estimator-provenance.R` carries `criterion_id ∈ {la_ml, va_elbo, reml,
   la_mspl}`, `penalty_eval_id ∈ {off, on, provenance_off}`, and a
   `penalty_off_provenance` tape role. `Q_P` is the active penalised
   objective (`estimator_id = 1`); `Q_0` is the penalty-off Laplace NLL
   (`estimator_id = 2`) and **must never be optimised**.

So "allow SE" is not a fence removal. It is: **name one private
construction on `Q_P` or `Q_0`, and measure whether it can be formed.**

### 2.4 The binary SE lane — read-only lesson transfer (learn, do not absorb)

Source: `codex/lane-b-mspl-interval-feasibility` @ `e91c7b7c` at
`/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB`, read via `git -C` only.
Nothing was checked out, copied, staged, or mutated. Corroborated by
`_sweep-codex-interval-mspl-next.md`, which reached the same worktree
independently.

**The construction map — four different objectives, not four views of one
matrix.**

| Route | Object | Availability | Coverage (joint pass) |
|---|---|---|---|
| Penalised numerical Hessian | `optimHess` on `∇²Q_P(θ̂)`; **not** `sdreport()` | private diagnostic | not gated; **mean-SE / empirical-SD 1.07–1.35** on low-prevalence cloglog |
| Paper-style Wald | `∇²Q_0(θ̂_MSPL)`, evaluated not optimised | 21/36 finite; 15/36 typed `likelihood_hessian_non_pd` | **9 / 36** |
| Penalised profile | Nuisance-reoptimised crossing of `Q_P` | 36/36 after bracket-first bisection | **24 / 36** |
| Unconditional percentile bootstrap | Full penalised refit | 36/36 | **20 / 36** |
| Godambe / sandwich | Additive scores `∇Q_P = Σ u_s` | typed `score_decomposition_unavailable` | never built |
| Delete-one-site jackknife | site-deletion refits | **WITHDRAWN** | Shinichi rejected — do not revive |

Campaign scale: 1,200 shards · 12,000 outer fits · 6,000,000 bootstrap
refits · 108,000 endpoints · 1,159,993 profile-trace rows. Gate was
availability ≥ 0.95 **and** a 90% Wilson coverage interval wholly inside
[0.92, 0.98]. Overall 106/108 availability, 54/108 coverage, 53/108 joint.
Receipt SHA-256 `8232f1a8…c277ea1`.

**Seven lessons this GOAL inherits.**

1. **Availability is cheap; calibration is the gate.** 106/108 versus
   54/108. Profile endpoints reached 36/36 and still failed 12 cells. A
   feasibility pin measures the first and must never be reported as the
   second.
2. **Wald from penalty-off curvature is the weakest route** (9/36) and
   **6,948 non-PD endpoint failures** were retained. Several Wald cells show
   conditional-on-PD coverage near 0.98 while unconditional coverage sits at
   0.52–0.63 — *conditioning on PD lied.*
3. **Overcoverage is failure too.** Profile targets in cell `C011` covered
   **1.000** and failed the 0.98 ceiling.
4. **Bootstrap can collapse catastrophically in saturated mean regimes** —
   `C011` target 3 covered **0.01**. The Poisson analogue is all-zero /
   near-zero traits *and* large-μ; a design that skips either repeats this.
5. **Sandwich is blocked at the estimator, not the family.** TMB's outer
   gradient is total-only, the Laplace log-determinant is added outside
   `joint_nll_penalized`, and the penalties use global `N_eff` and
   `X_mspl`. A Poisson `W = diag(μ)` atom is **also global** — changing
   family does not create per-site scores.
6. **Do not promote a passing subset.** The frozen gate was 36/36; the
   53/108 joint passes are not a public menu.
7. **Poisson information size is `tr(W) = Σμ`, not row count.** A Hessian
   can look PD and still be mis-scaled — the binary warning sign was that
   1.07–1.35 SE/SD ratio.

**Absorb rule: none.** No merge, no rebase, no helper import, no enabling
of any public method from this evidence.

### 2.5 Constitution: SE is Phase 7, not Phase 4

`_sweep-git-mspl-next.md` §4 quotes it exactly. Phase 4 is *"Poisson, then
NB2 and NB1"* with the exit gate *"finite count fits alone do not pass."*
**SE is Phase 7 — Inference and model comparison**, where the four
constructions above are listed as distinct and non-interchangeable,
penalised profiles are *"feasibility only until coverage is calibrated"*,
penalty-off curvature is *"not ordinary ML Wald inference"*, and
sandwich/Godambe is *"blocked until valid additive score units exist."*
Risk 7: *"stop interval promotion on miscoverage, overcoverage, unavailable
intervals, excessive width, or non-positive-definite curvature."*

Note the ordering consequence: this GOAL reaches into **Phase 7 while
Phase 4's own exit gate is unmet** (Poisson has a public door and a tape,
but no multi-seed point evidence and an unpinned `c`). That is defensible
only because the deliverable is availability, not inference — and it is
exactly why "no admit" is non-negotiable here.

### 2.6 Brain — three decisions that bind, one that conflicts

From `_sweep-brain-mspl-next.md` (8 MCP queries + 2 ledger greps), plus my
own two `search_notes` calls:

| ID | Content | Effect here |
|---|---|---|
| **D-112** (2026-08-01) | 0.6 ships **recovery-only** intervals; post-0.6 invests in capabilities, **not** coverage | Reinforces availability-only scope. Do not imply calibrated coverage |
| **D-141** (2026-08-11) | *"The live LA-MSPL Fir B2 campaign remains PROTECTED and cannot be used as a pilot"* | B2 is not admission or SE evidence |
| **D-135** (2026-08-09) | binomial probit/cloglog is 0.7.0, but Design 252 §7 *"MSPL stays logit-only, even in 0.7.1"* is **not overridden** | 🔴 **Conflicts with the registry** — see §5 |
| DR34 distillation | LA-MSPL is a research programme; evidence supports no default, no fallback, no general-family capability, **no calibrated inference** | Blocks every claim this GOAL might drift toward |

**Homonym trap** (I nearly walked into it): "Lane B" in the vault is mostly
*drmTMB Mission Control interval-feasible cells*, not
`codex/lane-b-mspl-interval-feasibility`. Those cells are **not** MSPL SE
evidence. The branch name itself is absent from the vault.

**The vault does not authorise a Cursor SE slice.** Poisson admit, any
public `mspl` on the four fenced families, Gaussian or Poisson SE, a Totoro
campaign, and NEWS `covered` all need a fresh G0 — the brain and the tapes
handover agree on that list exactly.

---

## 3. Phase 1 — SLICE TABLE

Bar policy (receipt: Cursor Models 38%, Other Models 45%): **scout and recon
on Cursor Models; math, SE, and admit judgment on Other Models.** The
mechanical R/test work sits on Cursor Models; the sole cpp owner sits on
Other Models because a `src/` edit against a penalised tape is a judgment
call.

| # | Member (role) | Slice | Model | Bar | Time | Dep |
|---|---|---|---|---|---:|---|
| A1 | **Shannon** (coordination) | Re-verify at G0 that #978 is **merged**, the new lane is cut from post-#978 `main`, #972–#976 are untouched, WIP is back under the soft cap, and the Codex + Claude interval worktrees are unmutated. **Blocks everything** | composer-2.5-fast | Cursor Models | 0.5 h | — |
| A2 | **Boole/Emmy** (construction recon) | Map every existing private and public SE-shaped path on post-#978 `main`: the `R/fit-multi.R:6423` withholding branch, the 27 `.gllvmTMB_n()` sites, `estimator-provenance` tape roles, `warm_sd_report`, checkpoint restore. Deliver a table of *what exists*, *what is fenced*, and *what would have to be built* for one named construction | cursor-grok-4.6-high-fast | Cursor Models | 1.5 h | A1 |
| A3 | **Jason** (Codex lesson transfer, READ-ONLY) | Extend `_sweep-codex-interval-mspl-next.md` into a Poisson-facing lessons note: which of the six routes is even *formable* for a Poisson tape, and which of the seven §2.4 lessons has a Poisson analogue. **`git -C` only; mutate nothing; stage nothing** | composer-2.5-fast | Cursor Models | 1.0 h | A1 |
| A4 | **Curie** (fixture inventory) | Inventory the 11 `test-mspl-*.R` files. Identify Poisson and Bernoulli fixtures small enough for a local availability pin under 30 min at `OMP_NUM_THREADS=1`. Report exact dimensions and a **measured** time estimate. Must include an all-zero/near-zero cell **and** a large-μ cell (§2.4 lesson 4) | composer-2.5-fast | Cursor Models | 1.0 h | A1 |
| B1 | **Gauss + Noether** (symbolic SE contract) | Write the symbolic→R→TMB table for what an MSPL standard error *is*: `∇²Q_P` vs `∇²Q_0` vs `I_LA(β)`; why the GLM-outer atom is not an information matrix; what unpinned `c = 1` does to the Poisson curvature scale (it does not vanish with `N`, so the band is systematically narrow and does not converge to an ML SE). **Must be able to conclude that no defensible SE object exists** | claude-opus-5-thinking-high | **Other Models** | 2.0 h | A2, A3 |
| B2 | **Fisher + Curie** (pin pre-registration) | Pre-declare, **before any fit runs**: construction = the Q1/Q3 pick; metrics = construction completes / Hessian PD / all SEs finite; every attempt in the denominator; non-PD retained unrepaired (no pseudoinverse, no eigenvalue clip, no nearest-PD, no substitution). Explicitly pre-declare that **no** coverage, width, or nominal-95% quantity is computed. Write the HOLD conditions | gpt-5.6-sol-medium | **Other Models** | 1.5 h | A3, A4, B1 |
| — | **🔴 CHECKPOINT 1** | 6 agents reported. Ada reconciles. Shinichi sees the symbolic contract and the pre-registered metrics **before** any edit | — | — | — | A1–B2 |
| C1 | **Curie** (test author — FAILING FIRST) | Write every test red before C2/C3 touch anything: the withholding branch stays intact; all 27 public refusals stay closed; the new internal construction is unreachable from any exported surface; the availability-pin tests. **Poison the opposite tape** so a silent `Q_P`/`Q_0` swap cannot pass (the Codex lane's own guard) | cursor-grok-4.6-high-fast | Cursor Models | 2.0 h | CP1 |
| C2 | **Gauss** (⚠ SOLE `src/gllvmTMB.cpp` OWNER) | The only agent permitted to open `src/`. Expected scope **zero** — the construction should be R-side numerical (`optimHess`-shaped) on an existing tape. If C2 concludes no `src/` edit is needed, C2 says so and edits nothing. A `src/` edit requires re-consent at CP2 | claude-opus-5-thinking-high | **Other Models** | 2.0 h | C1 |
| C3 | **Emmy** (R-side implementer — NO `src/`) | Implement the named construction as an internal, non-exported diagnostic behind an internal flag; record it in `estimator_provenance`; leave `R/fit-multi.R:6423` and all 27 refusals **untouched and tested**. **May not open `src/gllvmTMB.cpp`** | cursor-grok-4.6-high-fast | Cursor Models | 2.5 h | C1 |
| — | **🔴 CHECKPOINT 2** | 3 agents reported. Tests red-then-green; withholding branch intact; nobody admitted | — | — | — | C1–C3 |
| D1 | **Rose + Ada** (fence audit + closeout) | Rose fence: no admit, no NEWS `covered`, no public SE dispatch, public door still three families, prepare fence still `{0,1,2}`, no register promotion, **no D-135 drift** (§5). Then after-task + Melissa plan-actual + LOOP checkpoint + handover + lane-split refresh | gpt-5.6-sol-medium | **Other Models** | 1.5 h | CP2 |
| — | **🔴 CHECKPOINT 3** | Rose PASS or HOLD. Handover written | — | — | — | D1 |

**Totals.** 10 agents. Max **6** at any checkpoint (CP1 = 6, CP2 = 3,
CP3 = 1). Wall ≈ 5.5 h overlapped; ≈ 15.5 agent-hours. Exactly **one**
`src/gllvmTMB.cpp` owner (C2), whose expected edit count is zero. Bar split:
**6 slices on Cursor Models** (all recon plus mechanical R/test work),
**4 on Other Models** (all math, SE, and admit judgment).

---

## 4. Phase 2 — wave design and gates

### Wave A (A1–A4, parallel, Cursor Models)

Pure recon, writing only to `docs/dev-log/research/`. No `R/`, no `src/`,
no test file. A1 is a hard blocker: if #978 has not merged, or WIP is still
at 6 open PRs, the GOAL does not start.

*Gate:* A2 returns a definite construction inventory; A4 returns a
**measured** local time estimate including both a zero-inflated and a
large-μ Poisson cell.

### Wave B (B1–B2, parallel, Other Models)

Judgment. B1 must be able to conclude *"no defensible SE object exists for
Poisson at `c = 1`"* — if the symbolic contract cannot be written, the pin
does not proceed and CP1 returns HOLD. B2 must pre-register metrics
**before** any fit; a metric chosen after seeing output is a Risk-3
selective-evidence violation, and the Codex lane's conditional-on-PD Wald
result (§2.4 lesson 2) is the concrete demonstration of how that goes wrong.

*Gate (CHECKPOINT 1):* proceed only if (i) B1's contract names what the
number **is not**, (ii) B2's metrics are availability-only and
pre-registered, and (iii) Shinichi's Q1/Q2/Q3 answers are on record.

### Wave C (C1 → C2/C3, Cursor + Other Models)

Strictly ordered. **C1 alone first**, until every test is red. Then C2 and
C3 in parallel on disjoint files — C2 owns `src/gllvmTMB.cpp` and nothing
else; C3 owns `R/` and may not open `src/`. This is the "five people editing
gllvmTMB.cpp at once" failure the tapes GOAL deferred, and it stays
deferred.

*Gate (CHECKPOINT 2):* every C1 test demonstrably red before and green
after; `R/fit-multi.R:6423` unchanged; all 27 refusals still closed; no
registry row changed status; nothing touched under `NEWS.md`,
`docs/design/35-validation-debt-register.md`, or `vignettes/`.

### Wave D (D1, Other Models)

Rose fence, then closeout. Rose must be able to return HOLD.

*Gate (CHECKPOINT 3):* Rose PASS, after-task enumerating every file touched,
handover written, lane-split refreshed, check-log appended.

---

## 5. TEAM RAISED

**🔴 FLAG — a conflict, not a question. D-135 versus the registry.**
The brain scout found D-135 (accepted 2026-08-09) recording that Design 252
§7's *"MSPL stays logit-only, even in 0.7.1"* is **not overridden** by the
binomial probit/cloglog work. But `R/mspl-registry.R` carries **three**
`admitted` binomial rows — logit, probit, **and** cloglog — with evidence
`partial_b2_incomplete`. Either the vault decision is stale or the registry
over-admits two links. I am not resolving this: it predates this GOAL, it
touches an `admitted` status, and changing either side is a decision, not a
cleanup. **Consequence for this plan:** if Q2 is answered "Bernoulli
included", the pin runs on **logit only** unless Shinichi says otherwise —
because a cloglog availability number would attach evidence to a cell whose
admission the vault disputes. Rose (D1) checks that no drift occurs in
either direction. Worth its own small G0 later.

**Gauss (TMB / numerics).** The GLM-outer atom is `½ log det(X*' W X*)` at
the fixed-effect-only predictor, so a Hessian of the penalised objective at
the MSPL point mixes a Laplace-marginal block with a penalty block that is
not an information matrix for anything. Calling its square root a "standard
error" without qualification is the single most likely wording failure of
this GOAL. Worse for Poisson: `c = 1` does not vanish with `N`, so the
penalty's contribution to curvature does **not** attenuate — the band is
systematically narrow and will not converge to an ML SE as data grow. The
binary lane's measured SE/SD ratio of 1.07–1.35 is the same disease in a
family that at least had a derived rate.

**Fisher + Curie (validation).** 106/108 availability against 54/108
coverage is the whole argument for scoping to availability. Every attempted
fit stays in the denominator — non-convergence, non-PD Hessian, non-finite
SE, timeout are rows, not exclusions. And the Codex lane proved that
conditioning on PD actively misleads: Wald cells at 0.98 conditional versus
0.52–0.63 unconditional. Overcoverage would be a failure too, which is one
more reason not to compute coverage here at all.

**Rose + Noether (claims).** `planned ≠ admitted`; `absent ≠ planned`; and
*"an SE was formed"* ≠ *"an SE is valid"*. Noether adds that Gaussian is a
distinct hazard: its Hirose route **pins `sigma_eps`**, so its free
parameter block differs from Poisson's and Bernoulli's and an availability
number there would not be comparable. That is why the Ada default excludes
Gaussian.

**Jason (prior art).** No third-party MSPL uncertainty theory exists for
Poisson or NB GLLVMs under Laplace. Sterzinger & Kosmidis supports the
historical logistic curvature *diagnostic*, not public inference for this
extension. The 2026 factor-analysis paper explicitly notes that vanilla
Akaike/Hirose penalties have *"questionable finite-sample properties in
estimation, inference and model selection"* — i.e. even the matched Gaussian
theory warns about exactly the quantity this GOAL is probing.

**Shannon (coordination) — WARN.** Six open Cursor MSPL PRs against a soft
cap of three; #978 CI in flight and UNSTABLE; 16 branch switches on this
worktree in 12 hours. The largest process risk in this GOAL is not the math
— it is a stray merge or `git add -A` that pulls a prep PR into the SE lane.
Hence A1 as a hard blocker and a fresh branch from post-#978 `main`.

---

## 6. Phase 0.4 — three questions for Shinichi

### Q1 — What does "allow SE" mean?

MSPL withholds `sdreport()` at the estimator (`R/fit-multi.R:6423`), so
this is not a switch. Three readings:

- **(a)** name **one internal, non-exported construction** and measure
  whether it can be *formed* for Poisson and Bernoulli — availability and
  PD rates only; every public method stays fail-closed;
- **(b)** **public `se = TRUE`** returning penalised-objective SEs behind a
  loud non-calibration warning;
- **(c)** **public `vcov()` / `confint()`** for MSPL.

**RECOMMENDATION: (a).** The Codex campaign spent 1,200 shards and 6,000,000
bootstrap refits to conclude that the *best* of four routes reaches 24/36
and the curvature-based route reaches 9/36 with 6,948 retained non-PD
failures. Option (b) would publish, on two families with no campaign at all,
a construction close to the one that scored worst on the only family that
does have a campaign. Option (c) is `RETRACTED` in the Codex landing table.
D-112 also parks the coverage chase package-wide, and (b)/(c) would quietly
restart it.

**IF YOU DO NOT MIND** — one word is enough: *(a)*, *(b)*, or *(c)*. If you
pick (b) or (c) I rewrite the slice table before anything runs, because the
gate, the compute, and the reviewer set all change.

### Q2 — Which families and links does the pin cover?

- **(a)** Poisson + Bernoulli **logit only**;
- **(b)** Poisson only;
- **(c)** Poisson + all three Bernoulli links;
- **(d)** all of the above plus Gaussian.

**RECOMMENDATION: (a).** Bernoulli logit is the *calibration anchor* — we
already know from the Codex campaign roughly what its availability should
look like, so if our pin disagrees with 106/108, the pin itself is wrong and
we find that out cheaply. Poisson is the actual new question. **Logit only**
because of the D-135 conflict in §5: attaching an availability number to
probit or cloglog would put evidence on cells whose admission the vault
disputes. Gaussian is excluded because its pinned `sigma_eps` makes it a
different free block.

**IF YOU DO NOT MIND** — *(a)*, *(b)*, *(c)*, or *(d)*. If you want probit
and cloglog in, that is fine, but please also tell me whether D-135 is stale
— otherwise I would be generating evidence I cannot cite.

### Q3 — Which construction does the pin use?

The Codex lane built four. Given Q1 = (a), we implement exactly one:

- **(a)** penalised numerical Hessian — `optimHess` on `∇²Q_P(θ̂)`, the
  active objective;
- **(b)** penalty-off likelihood curvature — `∇²Q_0` evaluated (never
  optimised) at the MSPL point;
- **(c)** both, reported side by side as separate typed diagnostics;
- **(d)** penalised profile.

**RECOMMENDATION: (c), both.** They fail differently and that difference is
the finding: on binary, the penalty-off route produced 15/36 non-PD and
9/36 joint coverage, while the penalised route was available but mis-scaled
(SE/SD 1.07–1.35). Running one alone cannot distinguish *"Poisson curvature
is unusable"* from *"this particular tape is unusable."* Both are cheap —
neither refits — so the marginal cost over one is small. **Not (d):** the
profile route is the expensive one, its binary verdict is already known
(24/36, and it still failed), and it would push this GOAL past the 30-minute
local budget into campaign territory.

**IF YOU DO NOT MIND** — *(a)*, *(b)*, *(c)*, or *(d)*. If compute is
tighter than I think, (b) alone is the more informative single pick, because
`Q_0` is where the non-PD failures actually appeared.

---

## 7. Ada default (if you say nothing)

1. **Learn the binary SE method, do not absorb it.** `git -C` reads only.
   Zero files taken, zero commits touched, branch untouched. The transfer is
   the seven lessons in §2.4, in prose.
2. **Poisson + Bernoulli-logit availability pin.** One or both curvature
   constructions on `Q_P` / `Q_0`; metrics are construction-completes,
   Hessian-PD, SEs-finite; every attempt in the denominator; non-PD retained
   unrepaired. Internal, non-exported, behind an internal flag. Local,
   `OMP_NUM_THREADS=1`, nothing over 30 minutes.
3. **`R/fit-multi.R:6423` and all 27 public refusals stay exactly as they
   are**, and are pinned by tests.
4. **No admit.** Poisson stays `planned`; binomial and gaussian keep their
   current rows and evidence strings; NB2 stays `excluded`; NB1 / beta /
   Tweedie keep no row.
5. **No NEWS `covered`.** No validation-debt-register promotion.
6. **No public `mspl` on NB1 / NB2 / beta / Tweedie.** Prepare fence stays
   `family_id ∈ {0, 1, 2}`.
7. **No Gaussian SE** (pinned `sigma_eps`, different free block).
8. **No profile, no bootstrap, no sandwich, no jackknife.**
9. **D-135 left alone**, flagged for its own G0.

---

## 8. HARD STOPS

Any one of these stops the GOAL and returns to Shinichi.

1. **Touching `codex/lane-b-mspl-interval-feasibility` or
   `claude/mspl-interval-calibration`** in any way other than `git -C`
   reads — no checkout, no fetch into this lane, no cherry-pick, no rebase,
   no staging of any file from either worktree.
2. **Any calibrated-SE, coverage, width, or nominal-95% claim.**
   Availability is the only measurable in scope.
3. **Enabling any public MSPL inference dispatch** — `vcov()`, `confint()`,
   `standard_errors()`, `profile_targets()`, `tmbprofile_wrapper()`,
   `loading_ci()`, `bootstrap_Sigma()`, `getREsd()`, `getLV(se = TRUE)`,
   `predict(se.fit = TRUE)`, `tidy(conf.int = TRUE)`.
4. **Modifying the `R/fit-multi.R:6423` withholding branch.**
5. **Optimising the penalty-off tape `Q_0`**, or treating the MSPL point as
   an ML estimate.
6. **Repairing a non-PD Hessian** — no pseudoinverse, no eigenvalue clip, no
   nearest-PD, no substituting the penalised Hessian for the penalty-off
   one, no adaptive grid widening.
7. **Flipping any registry row to `admitted`**, adding a `planned` row for
   NB1 / beta / Tweedie, or moving NB2 off `excluded`.
8. **Writing NEWS `covered`** or promoting a validation-debt-register row.
9. **Widening the prepare fence** beyond `family_id ∈ {0, 1, 2}`.
10. **A second editor of `src/gllvmTMB.cpp`.** C2 is the sole owner and is
    expected to edit nothing.
11. **Any `src/` or `R/` edit before its failing test is red.**
12. **Totoro, DRAC, or any run over 30 minutes.** Local only,
    `OMP_NUM_THREADS=1`. A campaign needs its own G0 and receipt.
13. **Merging #972–#976, or starting before #978 is merged.**
14. **`git add -A`**, repo-root `LOOP/`, Dropbox paths, or minting a design
    number from this checkout.
15. **Jackknife, Godambe, or sandwich.** Jackknife is rejected by Shinichi;
    sandwich is structurally blocked by the absent per-unit score
    decomposition, and Poisson's global atom does not cure it.
16. **Touching the D-135 / probit / cloglog question** (§5 🔴 FLAG).
17. **Phase 1B API policy.**
18. **Reporting "an SE was formed" as "MSPL has standard errors."**

---

## 9. Paste-ready `/goal` prompt — **AFTER G0 ONLY**

> Do not paste until Shinichi has answered Q1, Q2, Q3 **and** #978 has
> merged. The text below shows the Ada defaults (a / a / c) substituted.

```text
/goal

You are Ada running the LA-MSPL "allow SE" GOAL. Solo platform: Cursor.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap  (never Dropbox)
BASE: a NEW lane branch cut from `main` AFTER PR #978 has merged. Not from
      cursor/mspl-phase4-tapes-planned. If #978 is not merged, STOP and report.
BINDING PLAN: docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md
CONSTITUTION: docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md
SCOUTS (read all four): docs/dev-log/research/_sweep-{shannon,git,brain,codex-interval}-mspl-next.md
LANE MAP: docs/dev-log/handover/2026-07-25-active-lane-split.md

READ FIRST — the fact the plan turns on:
  MSPL withholds TMB::sdreport() AT THE ESTIMATOR (R/fit-multi.R:6423), not at the
  family. There is NO unfenced se=TRUE hole. "Allow SE" therefore means: name ONE
  private construction and measure whether it can be FORMED. It is not a switch.

G0 ANSWERS (Shinichi, 2026-08-15):
  Q1 = (a) one internal, non-exported construction; availability + PD only; all public methods stay fail-closed
  Q2 = (a) Poisson + Bernoulli LOGIT ONLY; no probit/cloglog (D-135 conflict); no Gaussian (pinned sigma_eps)
  Q3 = (c) BOTH curvature constructions as separate typed diagnostics: penalised numerical
           Hessian on Q_P, and penalty-off curvature Q_0 evaluated (never optimised) at the MSPL point

🎯 GOAL
Solo platform: Cursor
Deliverable: one named, internal, non-exported SE construction for LA-MSPL on Poisson and Bernoulli-logit, plus an availability-only feasibility pin measuring whether it can be formed at all
HEADLINE: MSPL withholds standard errors at the estimator; we name the construction, measure how often it exists and how often its curvature is usable, and we admit nobody
IN PARALLEL: Shannon lane hygiene · construction recon · read-only Codex lesson transfer · Poisson/Bernoulli fixture inventory · symbolic SE contract · availability-pin pre-registration · failing tests · one cpp owner · Rose fence · handover
DEFER: calibrated SE · coverage/width/nominal-95% · public vcov()/confint()/standard_errors()/profile_targets() · Poisson admit · NEWS covered · public mspl on NB1/NB2/beta/Tweedie · Gaussian SE · probit/cloglog · penalised profile · bootstrap · Totoro/DRAC · jackknife · Godambe/sandwich · merging any interval branch · Phase 1B API policy
DISCIPLINE: verify=failing tests before any src/ or R/ edit · compute=local, OMP_NUM_THREADS=1, nothing over 30 min · closure=construction named, availability + PD rates recorded with every attempt in the denominator, non-PD retained UNREPAIRED, Rose PASS, nobody admitted

WAVES (max 6 agents per checkpoint; exactly ONE src/gllvmTMB.cpp owner):
  Wave A — A1 Shannon (HARD BLOCKER: #978 merged? WIP under cap? interval worktrees clean?)
           | A2 construction recon | A3 Codex lesson transfer, git -C READ ONLY
           | A4 fixture inventory (MUST include an all-zero/near-zero AND a large-mu Poisson cell)
                                                                              [Cursor Models]
  Wave B — B1 Gauss+Noether symbolic SE contract (must be able to conclude NO defensible SE object
             exists) | B2 Fisher+Curie pin pre-registration, metrics fixed BEFORE any fit
                                                                              [Other Models]
  🔴 CHECKPOINT 1 (6 reported) — Ada reconciles; HOLD if B1 cannot write the contract
  Wave C — C1 failing tests FIRST, alone, all red (poison the opposite tape so a silent Q_P/Q_0
             swap cannot pass) | then C2 sole src/ owner (expect ZERO edits) and C3 R-side only,
             may not open src/gllvmTMB.cpp
  🔴 CHECKPOINT 2 (3 reported) — red-then-green; R/fit-multi.R:6423 untouched; 27 refusals still
             closed; no registry status changed
  Wave D — D1 Rose fence (must be able to return HOLD; check for D-135 drift) + after-task
           + plan-actual + LOOP checkpoint + handover + lane-split + check-log   [Other Models]
  🔴 CHECKPOINT 3 — Rose PASS or HOLD

LOOP kit: docs/dev-log/lanes/<new-lane>/LOOP/  — never repo-root LOOP/.

HARD STOPS (any one returns to Shinichi):
  never check out or mutate codex/lane-b-mspl-interval-feasibility or
  claude/mspl-interval-calibration (git -C reads only) · no calibrated-SE / coverage / width /
  nominal-95% claim · no public MSPL inference dispatch · do not modify R/fit-multi.R:6423 ·
  never optimise the penalty-off tape Q_0 · never repair a non-PD Hessian (no pseudoinverse,
  eigenvalue clip, nearest-PD, or substitution) · no admit, no new planned row, NB2 stays
  excluded · no NEWS covered · no register promotion · prepare fence stays family_id in {0,1,2} ·
  one cpp owner · no src/ or R/ edit before a red test · local only, OMP=1, nothing over 30 min ·
  do not merge #972-#976 · never git add -A · no design-number minting · no jackknife / Godambe /
  sandwich · do not touch the D-135 probit/cloglog question · no Phase 1B API policy ·
  never report "an SE was formed" as "MSPL has standard errors"
```

---

## 10. Non-claims

This document does not claim: that an MSPL standard error is valid,
calibrated, or publishable; that any family or link is admitted; that the
GLM-outer atom is `I_LA(β)`; that `c = 1` is a derived rate; that any Codex
binary evidence transfers to Poisson; that Sterzinger–Kosmidis (2023) or
Sterzinger–Kosmidis–Moustaki (2026) covers count-family GLLVM MSPL
inference; that Laplace is exact for any of these families; that the D-135
conflict is resolved; or that this GOAL satisfies Phase 4's exit gate, which
it does not and does not attempt to.

## 11. Out of scope here

Phase 3 execution, LOOP kit authoring, any `src/` or `R/` edit, any merge,
any admission, NEWS, the validation-debt register, Totoro/DRAC, the Phase 1B
API policy, EVA/VA/AGHQ, structured tiers (`phylo_*`, `spatial_*`,
`animal_*`, `kernel_*`), mixed families, the D-135 link question, and the
Codex branch's own OWED theory task (whether a non-jackknife
estimator-defined pivot exists — that is Claude's, per its handover).
