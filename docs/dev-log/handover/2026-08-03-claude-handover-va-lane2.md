# Session Handoff: gllvmTMB VA lane 2 — collapse shipped, hybrid refuted, coverage pilot NO-GO, head-to-head WON

**Meta:** 2026-08-03 · from Claude Code (solo) · branch `claude/va-lane2` · worktree
`/private/tmp/gllvmtmb-va-lane2` · 17 commits off `origin/main` @ `5bf18ab3`

---

## Critical Context

**1. Two arms beat gllvm, and it is finally properly powered.** 12 paired seeds, model-matched
(`unique = FALSE` on both sides), shared oracle floor verified. At N=1000: our AC+collapse is
**1.76× faster** at statistically indistinguishable accuracy, and our warm/GH arm is
**significantly more accurate** (median rel_frob 0.060 vs gllvm's 0.173, wins 11/12,
Wilcoxon p=0.001) at 6.6× the time. This **vindicates retracted claim 18** — pairing is what
did it, since the arms share each dataset so the 0.13–0.46 per-seed spread cancels.
**Speed caveat that must travel with the number:** the log shows `load median 1.1 spread 16.5`
with another R process at close — my own concurrent campaigns were on Totoro. Accuracy is
unaffected by load; **treat 1.76× as indicative until re-measured on a quiet box.**

**2. The coverage campaign is NO-GO and must not be launched as designed.** The Step-0 pilot
found two blockers that would each have produced a confident wrong answer at 1000 seeds. Both
are fixable; **neither is fixed.** See Blockers below.

**3. The VA→LA hybrid is REFUTED. Do not resume it.** It reverses at scale (1.12× faster at
N=200 → **0.84×, i.e. slower**, at N=1000), there was no convergence failure to rescue, and
profiling explains why a near-perfect seed could never have helped (below).

**4. VA may scale superlinearly — the premise of this whole arc is in question.** Two
independent harnesses agree: the hybrid ladder measured VA growing **14× for a 5× N increase**
(~N^1.6), and the coverage pilot's oracle cell had one VA fit exceed **350 s at n=5000** where
n=400 took **2.44 s** (12.5× the units, >100× the time). If VA's advantage narrows with N, the
question is not whether its intervals cover but whether it is worth using at scale. **Settle
this before building further.**

---

## What Was Accomplished

| # | result | status |
|---|---|---|
| 1 | **Warm route REFUTED then REPAIRED.** Collapsed ψ 3/3 seeds (0.0001/0.2427/0.0000 vs planted 0.6); diagnosed as a log-scale attracting boundary (∂f/∂log σ = (∂f/∂σ)·σ); fixed by resetting only the variance coordinates. 12.3× at identical accuracy. | LANDED `43341784` |
| 2 | **A_i collapse IMPLEMENTED**, gated (AC + all-probit + complete data + constant `n_trials` + single dense tier), opt-in. Objective moves ≤6.9e-12 against the maintainer's 1e-8 falsifier; 45–57% of the outer problem removed; **3.81× at N=1000**. 16/16 tests. | LANDED `07af7df3` |
| 3 | **Head-to-head vs gllvm**, 12 paired seeds — see Critical Context 1. | LANDED `47c8549a` |
| 4 | **Four VA interval routes** (Wald-Schur, sandwich, bootstrap, profile) as instruments. Adversaries caught two silent-wrongness defects: a sandwich with no stationarity gate returning plausible SEs from a `par` 4–6 orders off-optimum, and a bootstrap 0/1-index bug making **every replicate fail silently**. 83 + 1027 tests pass. | LANDED `32ecfb15` |
| 5 | **`getREsd()` + `predict(se.fit=)`** on the SHIPPING Laplace engine — the only user-facing capability of the day. 269 tests pass across touched + neighbouring suites. | LANDED `6b1f3eb1` |
| 6 | **`fixed_idx` extended** to `log_sigma`/`log_sd_tier` in both information routes; additive by construction. | LANDED `e11abd6e` |
| 7 | **A_i closed form is PUBLISHED PRIOR ART** (dr25) — corrected from "ours to take first" before it reached a commit message. | LANDED `4ebbcb59` |
| 8 | **VA is 5.8× faster than our own Laplace** (matched model, 3 seeds) — the arc's founding premise, measured for the first time. LA is ~26% more accurate. | LANDED `f3df8193` |
| 9 | **Hybrid REFUTED at scale**; mode-seeding works (lands on identical optimum, +1.6–2.1pp) but cannot change the sign. | LANDED `f9e0a602` |
| 10 | **Coverage pilot NO-GO** — two blockers. | LANDED `e11abd6e` |

**Corrections that mattered more than any build:** three claims retracted or reframed by
checking a *competing explanation* rather than the arithmetic — the ψ=0 DGP, the possibly-
ignored warm start, the possibly-scrambled seed. Each took minutes; each changed what a number
meant. `36-seed-ordering-check.R` is the template.

---

## Current Working State

- **Working:** everything in the table above; VA suite 1027 passing, 0 failing.
- **In progress:** nothing. The Laplace cost-profiling fleet COMPLETED (`695450d2`); its
  verdict is `docs/design/laplace-cost-profile.md` and ledger claims 42-45. All 21 previously
  carried-over `dev/va-speed/` paths are now committed; the working tree is CLEAN.
- **Blocked:** the coverage campaign (below). Nothing else.

### The profiling finding — read this, it closes the loop

At N=2500, q=5 (total 1012 s, 674 outer iterations, 12,500 random effects):

| phase | s | % |
|---|---|---|
| `nlminb` (outer optimisation) | 783.9 | **77.4** |
| `sdreport` | 223.3 | **22.1** |
| `MakeADFun` (tape build) | 5.5 | 0.5 |
| R overhead | 0.013 | ~0 |

**⚠ CORRECTED 2026-08-03 after the fleet completed (`695450d2`, ledger claims 42–45). An
earlier draft of this section asserted that the warm start "helped iteration 1 of 674" because
TMB already warm-starts its inner solve. THAT WAS WRONG — do not propagate it.**

The verified numbers, from two independent methods (Rprof and explicit instrumentation)
agreeing to within a percentage point, across N ∈ {250, 1000, 2500} × q ∈ {2, 5}:

| phase | share |
|---|---|
| `nlminb` (outer optimisation + sparse Cholesky) | **58–59%**, rising to ~77% as **q** grows |
| **`TMB::sdreport`** | **38.7% (Rprof) / 39.6% (instrumented)** |
| `MakeADFun` tape build | ~2% |
| R-side overhead | <1% |

`nlminb` + `sdreport` are ~97–98% of cold wall time. The optimiser's share climbs with the
**latent dimension q**, not with N at fixed q; `sdreport`'s *relative* share shrinks even as its
absolute cost grows ~33× across the grid.

**THE LEVER: `se = FALSE` saves 22–39% of wall time at ZERO statistical cost**, low effort, and
the path is already gated. Every user who wants only point estimates is paying ~40% for
standard errors they never use. This is the single highest-value, lowest-risk speed result of
the arc.

**The corrected hybrid reconciliation (claim 45):** the warm start **does** cut iterations by
**~40%**. The arithmetic closes exactly — 40% of the optimiser's 58% share ≈ **23%**, precisely
the 23–24% LA-stage saving the hybrid campaign measured. The gain was real; it was absorbed by
`sdreport`'s 39% (which no warm start can touch) plus the VA sub-fit's own cost. Same
conclusion about the hybrid, better reason — and the better reason is what makes `se = FALSE`
visible as the actual lever.

**Ranked levers:** (1) `se = FALSE` on demand — 22–39%, free, low effort. (2) Avoid
`sdreport`'s internal nested tape rebuild — ~0.5–1pp, inside `TMB::sdreport` itself, high
effort. (3) Attack the sparse-Cholesky per-iteration cost — largest payoff, but statistically
free **only** via solver-level work, never via looser tolerances. (4) The hybrid — a curiosity;
do not invest. (5) R-side overhead — not a lever at any size tested.

Conditioning (`21-WHY-GLLVM-IS-FAST.md`, `va-conditioning-audit-vs-gllvm.md`) remains the route
to fewer iterations, and the loadings-diagonal pinning is the one gllvm choice we do not match —
but note it attacks the 58% phase, whereas `se = FALSE` attacks 39% for almost no work.

---

## Key Decisions & Rationale

1. **A_i collapse: GO, framed implementation-first.** The closed form is published (dr25); the
   defensible claim is "first to implement a known closed form the reference implementation
   leaves on the table", never "first to derive".
2. **Nothing promoted.** `default_tier` stays `"gh"`; `R/integration-fence.R` untouched;
   `confint.gllvmTMB_va`/`vcov.gllvmTMB_va` still error, with a regression test asserting it.
3. **LA-Bootstrap deferred, not cancelled** — 55% of campaign compute, no oracle floor, weakest
   power, and it does not bear on the primary question. Revisit only if Tier 1 shows Wald
   under-covering *and* the sandwich fails to rescue it.
4. **Totoro budget raised to 150 cores** (maintainer, this session), up from 100.
5. **Every claim states its regime** — the arc's primary discipline, ledger claim 21.

---

## Landing State

`handoff_gate.sh` reported unlanded state; every item is resolved below.

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `claude/va-lane2` @ `47c8549a` (17 commits) | y | **n** | none | **CARRIED-OVER** |
| `dev/va-speed/38-*`, `39-*`, `40-profile-*`, `41-*`, `42-iter-count-check.R` + `docs/design/laplace-cost-profile.md` | y (`695450d2`) | n | none | **LANDED** (was carried-over; fleet finished) |
| `worktree-agent-a001dee2509c89dc2` / `-a283d56f6868709e7` / `-a6930931ce81e02da`, 1 unpushed each | y | n | none | **CARRIED-OVER** (agent scratch worktrees; inspect before reusing) |

**Why not landed, and how to resume:**

- **`claude/va-lane2` unpushed** — this is fenced research (nothing promoted), and lane 1's
  predecessor was likewise unpushed until merged via PR #933. Results stay LOCAL (D-50).
  Resume: `cd /private/tmp/gllvmtmb-va-lane2 && git log --oneline 5bf18ab3..HEAD`
  To push: `git push -u origin claude/va-lane2` — **maintainer's call, not automatic.**
- **The 21 uncommitted `dev/va-speed/` paths** — they belong to the **still-running** profiling
  fleet; committing mid-write would capture a half-finished state. Once it stops:
  `cd /private/tmp/gllvmtmb-va-lane2 && git add dev/va-speed/38-* dev/va-speed/39-* dev/va-speed/40-profile-* dev/va-speed/41-* dev/va-speed/42-iter-count-check.R && git commit`
  The ladder `.rds` files are the valuable part — do not discard them.

---

## Next Immediate Steps

1. **Ship `se = FALSE` on demand** -- the profiling fleet's headline: 22-39% of wall time at
   ZERO statistical cost, low effort, path already gated. Highest value/risk ratio in the arc.
2. **Settle whether VA scales superlinearly.** A clean VA-vs-LA N-ladder, several seeds,
   N ∈ {250, 1000, 2500}, on a **quiet** Totoro. This is the arc's founding premise and two
   harnesses now question it. Cheap, and everything else depends on it.
3. **Fix coverage blocker 1** — the health gate's absolute `gradient_tolerance = 1e-4`
   (`R/va-r3-proto.R:2452`). Make it relative or N-scaled. **This gate has now rejected good
   fits twice today** (also claim 33), so it is a real calibration defect, not a one-off.
4. **Fix coverage blocker 2** — `.total_variance_spec()` (`R/profile-derived.R:702`) silently
   returns `rep(0, n_traits)` when `theta_diag_B` is absent. Make it **error**, then either give
   the design's LA formula a `unique = TRUE` tier or drop V_j and score `Sigma_jj`.
5. **Re-run Step-0**, then Tiers 1+2 only (~75 min at 150 cores). Bootstrap stays deferred.
6. **Re-measure the 1.76× on a quiet box** before it is quoted anywhere.

---

## Blockers / Open Questions

- 🔴 **Coverage blocker 1 — VA-Wald yields 0/30 healthy fits at BOTH primary cells** (n=150,
  n=400), while the *out-of-regime* n=50 stress cell yields 23/30. Not a fitting failure: all
  4 starts converge with objectives agreeing to 6+ s.f. (n=150 seed 1: 1401.228740 on all
  four), but `max|gradient|` ∈ [1e-4, 7e-4] against a fixed absolute 1e-4 bar, so <3 of 4
  starts clear it. `n_starts` accepts only 1/3/4, so "more starts" is not a lever.
- 🔴 **Coverage blocker 2 — LA-Profile computes the WRONG ESTIMAND, silently.** Returns
  `Sigma_jj`, not `V_j = Sigma_jj + psi_j`, because `theta_diag_B` is absent from the design's
  fit and the psi contribution silently becomes zero. Point-estimate gaps track the planted
  `psi_j ~ U(0.3,0.5)` almost exactly. Explains the coverage collapse 0.517 → 0.300 → 0.096.
- ❓ **Does VA scale superlinearly?** (step 2 above). Load-bearing for the whole arc.
- ❓ **Push `claude/va-lane2`?** Maintainer's call.

---

## Gotchas & Failed Approaches

- **Do NOT resume the VA→LA hybrid.** Refuted at scale; and TMB already warm-starts its inner
  solve, so a mode seed helps 1 iteration of 674.
- **Do NOT re-attempt `init_strategy` as a warm-start hook** — it seeds `log_phi_*` only, a
  no-op for binomial. The real hooks are `control$start_from` and `control$vgh_warm_start`.
- **`profile_variational = TRUE` is a clear loser** — 27.7 s vs 2.75 s at N=250, 128.5 s vs
  29.1 s at N=1000.
- **`Rscript --vanilla` implies `--no-environ`**, so `~/.Renviron` is ignored and `gllvm`
  (in `~/R/lib`) is invisible. **Always pass `R_LIBS_USER=$HOME/R/lib` explicitly on Totoro.**
  This killed one campaign launch today.
- **Always include an untimed warm-up** — the TMB template compiles on first use and a run
  without one put a 25 s compile inside the first timed arm.
- **`extract_Sigma()` returns a LIST (`$Sigma`, `$R`) and needs `level=`**, not `part=` alone.
- **A metric blind to the failure mode is not a check** — the arm that *collapsed* a variance
  scored **better** on `rel_frob` (0.345 vs 0.377).
- **"VA gets informative per-unit uncertainty" is NOT a differentiator** — gllvm shows the
  identical AC-constancy and Poisson-informativeness in its own implementation (ledger 35).

---

## How to Resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && git log --oneline 5bf18ab3..HEAD && git status --porcelain
ssh -o BatchMode=yes totoro 'cut -d" " -f1-3 /proc/loadavg'   # quiet box before ANY timing
```

Read in order: this file → `dev/va-speed/20-CLAIMS-LEDGER.md` (41 rows; **check status before
citing anything**) → `docs/design/va-capability-worklist.md` → `docs/design/va-interval-coverage-campaign.md`.

**Never build from the Dropbox checkout (PROTECTED, D-112).** Totoro: `ssh -o BatchMode=yes
totoro`, lane at `~/gllvm_work/va-lane2`, ≤150 cores, `OPENBLAS_NUM_THREADS=1`,
`R_LIBS_USER=$HOME/R/lib`. Results LOCAL (D-50).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-03-claude-handover-va-lane2.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
