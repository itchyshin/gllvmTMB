# Claude → Claude handover, 2026-07-28 — the AGHQ engine lane

You are Claude, picking up the **AGHQ integration-engine lane** of `gllvmTMB`.
Author: Claude, 2026-07-28 session. Lane: `claude/aghq-engine-20260728`,
worktree `/private/tmp/gllvmtmb-arc0-identifiability`, base `main` @ `72c2e53d`.
**20 commits, not yet pushed, no PR open.**

---

## Mission control

| | |
|---|---|
| **repo** | `gllvmTMB` · `main` @ `72c2e53d` (PR #798 and #799 both merged) |
| **lane** | `claude/aghq-engine-20260728` · 20 commits · 119 files vs `main` |
| **what shipped** | AGHQ as an **opt-in** integration engine + a weakly-informative ridge on the loadings |
| **default** | **UNCHANGED — Laplace.** `aghq = FALSE`. No existing user's numbers move |
| **suites** | `test-aghq-surface` 35/0 · `test-aghq-golden` 5/0 (3 skip) · `test-tmb-ad-safe-clamps` 7/0 |
| **the invariant** | Gaussian exactness **+6.25e-13, identical at k=3 and k=9** — re-checked after every engine edit |
| **NOT done** | the **family axis** of the routing map; the **D-43 panel** (running when this was written) |
| **rung** | NOT READY. Nothing exported, NAMESPACE untouched, no capability claim made |

## ⚠ Multi-lane — do not narrow the pointer

`docs/dev-log/handover/2026-07-25-active-lane-split.md` remains the START-HERE map and
lists every lane. This handover covers **only** the AGHQ engine lane. Carried forward,
unchanged and still owned elsewhere:

* **Eta simulation / Design-100** — Codex, `/private/tmp/gllvmtmb-design100-progress-oracle`.
* **Design-103** — Codex, closed `TECHNICAL_PARTIAL`, local-only.
* **HVT-1** — `ORACLE_NOT_CERTIFIED`.
* **0.6 release / M5** and **Profile / Tier-2a** — separate handovers; re-derive from git.
* **Codex is ALSO USING THE LOCAL MACHINE.** Cap local cores hard (≤6–8) and prefer Totoro.
  This session oversubscribed the laptop to load 227 on 20 cores and had to be told.

## Goals / mission

`gllvmTMB` = multivariate stacked-trait GLLVMs with phylogenetic and spatial extensions.
First CRAN release is **0.6.0**, not 1.0. This lane's goal: give the package a **correct
integration engine**. The maintainer's framing, adopted: the parameters that matter are
**beta, sigma and rho**.

---

## The headline result

Descending from large `n` at FIXED traits-per-site (validate where the answer is known,
then walk down — the maintainer's design, and the single reason any of this became
legible):

```
ratio = ||Lambda_hat|| / ||Lambda_true||   ·   1.000 = unbiased   ·   T = 4, q = 1
     n  |  LAPLACE  |  AGHQ
  3200  |   0.794   |  1.0021    <- the anchor
   800  |   0.810   |  1.063
   200  |   0.836   |  1.967
```

**Laplace carries a flat ~21% downward bias that sixteen-fold more data does not touch**
— its error is O(1/T), in observations per CLUSTER, not per sample. **AGHQ converges to
truth.**

And the four-arm comparison (Totoro, 954 fits, 30 seeds/cell, p=6 q=2 binomial),
`|sigma − 1| / rho error`, smaller better:

```
     n | Laplace(shipped) | Laplace+ridge | AGHQ+none    | AGHQ+ridge
   100 |  0.175 / 0.310   | 0.053 / 0.223 | 0.197/0.233  | 0.043 / 0.230
   200 |  0.191 / 0.305   | 0.140 / 0.204 | 0.063/0.224  | 0.040 / 0.225
   400 |  0.149 / 0.155   | 0.105 / 0.130 | 0.070/0.121  | 0.054 / 0.120
  1600 |  0.118 / 0.087   | 0.138 / 0.091 | 0.012/0.075  | 0.011 / 0.062
```

**The defensible claim, and do not strengthen it:**

> AGHQ corrects an integral error that no amount of data removes. A weakly-informative
> ridge on the loadings removes a small-sample runaway that no amount of quadrature
> removes. Together, **against the Laplace default gllvmTMB ships today**, they give the
> best latent-SD and correlation recovery at every sample size tested.

The comparator must be named. Against a *hypothetical* penalised Laplace (which exists
in no package), Laplace+ridge edges rho at n ≤ 200. That is an **attribution** point, not
grounds to withdraw the claim — see `decisions.md` 2026-07-28, both entries.

**Component attribution (2×2, holding the other fixed).** They fix DIFFERENT regimes,
which is why they compose rather than duplicate:

| | contributes at n=100 | at n=1600 |
|---|---|---|
| AGHQ (to sigma) | +0.010 | **+0.126** |
| ridge (to sigma) | **+0.154** | +0.0006 |

And **AGHQ alone**, with no penalty, already cuts the divergent-fit rate **50% → 13%** at
n=100 and beats Laplace on rho at every n.

---

## What was accomplished

* **AGHQ quadrature kernel inside the TMB template**, reusing the existing `obs_loglik`
  lambda verbatim (`src/gllvmTMB.cpp:1994`, single call site `:2363`) — **family-agnostic
  by construction, no per-family code exists or should be written**.
* **Reachable control surface**: `gllvmTMBcontrol(aghq = FALSE | "auto" | k)`, plus
  `aghq_ridge`, `aghq_iter_cap`, `aghq_n_adapt`, `aghq_multistart`,
  `allow_nongaussian_reml`. 5/5 malformed inputs abort naming the valid forms.
* **The ridge** (`aghq_ridge = 2`), on by default when AGHQ is on. Exact gradient
  adjustment — no template change, no recompile, no loss of AD exactness.
* **Start-selection fix**: AGHQ no longer blindly inherits a runaway Laplace warm start.
* **Structural gate** (`R/aghq-gate.R`) routing on **computed treewidth**, never keywords.
* **Adaptive controller** (`R/aghq-control.R`): node floor 5, per-family-per-tier
  optimiser routing; 0 of 21 routes can emit `lbfgsb` without `factr`.
* **Engine-consistent reporting** (`R/aghq-report.R`): cross-engine AIC comparison WARNS,
  verified both ways (silent within an engine, loud across).
* **`ordinal_probit`'s `1e-12` floor** replaced with a log-scale guard — it was harmless
  under Laplace but BOUND at quadrature nodes.
* **Non-Gaussian REML opened as Cox–Reid**, opt-in and warned.

## Key decisions & rationale

All in `docs/dev-log/decisions.md`, 2026-07-28 (nine entries). The load-bearing ones:

1. **AGHQ becomes the main engine — reversing "stay Laplacian" (2026-05-15).** The old
   ruling misread the literature's `n_i` as sites rather than **traits per site**.
2. **AGHQ ships OPT-IN; Laplace stays the default.** Flipping it changes every user's
   numbers while touching no export, so `R CMD check` cannot catch it.
3. **The claim is a CORRECT LIKELIHOOD**, not better estimates *per se*.
4. **Cox–Reid is a validated NEGATIVE here** — moved ~1%, wrong direction, because it
   adjusts 4 intercepts against 480 observations while the variance lives in `Λ`.
5. **Routing is (T, M, family)**, and the campaign measures **lever sizes**, not pass/fail.

## Current working state

* **Working:** everything above; suites green; the Gaussian-exactness invariant holds.
* **In progress:** the **D-43 panel** (3 fresh lenses) was running at handover —
  check `dev/aghq-evidence/D43-lens{1,2,3}-*.md`.
* **Blocked:** nothing.

## Files created / modified

119 files vs `origin/main`; `git diff --name-only origin/main...HEAD` for the full list.

* `R/fit-multi.R` — AGHQ loop, ridge, start selection, Cox–Reid gate
* `R/gllvmTMB.R` · `R/aghq-gate.R` · `R/aghq-control.R` · `R/aghq-report.R` ·
  `R/methods-gllvmTMB.R` · `src/gllvmTMB.cpp`
* `tests/testthat/test-aghq-surface.R` · `test-aghq-golden.R` · `test-tmb-ad-safe-clamps.R`
* `dev/aghq-evidence/` — 20+ scripts and result files; `05-descend-RESULT.txt` and
  `totoro-suite-inc.csv` are the two that carry the headline
* `dev/aghq-r-reference.R` — standalone pure-R AGHQ fitter, **validated to 5.2e-08 against
  gllvmTMB's own Laplace**; the independent oracle. NOT a shipping route
* `dev/aghq-families/` — 16-family harness, **built but never run**
* `docs/dev-log/decisions.md` · `CLAUDE.md` · this handover

## Next immediate steps

1. **Read the D-43 panel verdicts.** Two NOT-DONE withholds the claim. Do not advertise
   anything until they are in.
2. **Run the family axis** — `dev/aghq-families/`, 16 families × 8 seeds, on **Totoro**
   (`~/h4_work`, deploy pattern in `dev/aghq-evidence/totoro-suite.R`). Gaussian is the
   harness's own positive control: **its AGHQ lever must measure ~zero, or the harness is
   wrong, not the family.**
3. **Push the branch and open a PR.** Nothing is pushed yet.
4. Then, and only then, consider the capability-surface ENGINE column.

## Blockers / open questions

* **`s_B` is fenced**, so AGHQ does not cover poisson/gaussian **default** `latent()`
  models. Binary defaults ARE covered (single-trial Bernoulli has auto-Psi pinned off,
  `R/fit-multi.R:4683-4705`). The prize is smaller than it first looked.
* **No coverage/interval evidence.** The "correct likelihood" claim is justified by LRT/AIC/CI
  resting on it, but **coverage itself is unmeasured** — and coverage is what this project
  actually gates on. A coverage run was written (`13-coverage.R`) and killed for machine load.
* **`aghq = "auto"` is implemented but is not the default**, and the (T, M, family) map
  needed to make it principled is only half-measured.
* The **flat likelihood direction is not fixed, only penalised.** At a converged optimum,
  sweeping k = 5/9/15/21 moves the objective < 0.01 nll while the argmin's `‖Σ_B‖_F`
  wanders 13.3 / 45.5 / 119.3 / 38.6.

## Gotchas / failed approaches — do not repeat

* **k = 1 agreement proves PLUMBING, never quadrature** — k=1 *is* Laplace. The earlier
  spike's celebrated `1.4e-9` was exactly this mistake.
* **Gaussian exactness is necessary but NOT sufficient.** A gaussian integrand IS the GH
  kernel after adaptation, so any correctly-normalised rule reproduces it. It tests
  normalisation, not node placement. The non-Gaussian oracle is the real test.
* **Never summarise a mixture with a median.** A reported "97% bias" was two modes —
  50% of fits at 1.030, 50% past 2 — with the median describing neither.
* **The norm hides the failure.** It is ELEMENTWISE: one loading explodes (96.6% of squared
  error in one element) while the **median element is shrunk**. Norm and elementwise point
  in opposite directions.
* **Adaptation must be continuous.** Frozen nodes drove `‖Σ_B‖_F` from 4.43 to **4.1e7**
  in one pass. `aghq_iter_cap` defaults to 1 for that reason.
* **Do not compare objective values across re-adapted tapes** — the old stopping rule did,
  mixing parameter progress with quadrature-error change; it was non-monotone and 5–9
  orders above its own threshold.
* **Cox–Reid does not transfer** from drmTMB's scalar-RE case. Measured, negative.
* **`lbfgsb` needs `factr = 1e-12/.Machine$double.eps`** or it stops in ~24 ms at an
  objective 125–151 worse, reporting `convergence = 0`.
* **`pgrep -f Rscript` reports 0 for healthy R jobs** — R runs as `exec/R`. This session
  declared four live jobs dead on that basis.
* **Shell `nohup &` inside the Bash tool does not survive**; use the harness's tracked
  background mode, and **write results incrementally**.

## Corrections issued this session

Seven, most of them the author's own — the reason to trust the rest:

| claim | reality |
|---|---|
| the quadrature contract (fold `exp(u'u)` into the weights) | **mine, and wrong** — made the grid unvalidatable by any independent check |
| "AGHQ prefers the degenerate optimum" (12/12) | **vacuous by construction** — the fitted point IS the MLE, so the result was guaranteed |
| "two errors cancelling" explains Laplace's small-n adequacy | **refuted** — it is a two-population mixture: 30 converged fits at 0.810 plus 10 NON-converged blow-ups |
| the runaway is separation-driven | true for Laplace (12/40, ρ=0.80); **false for AGHQ** (1/40) |
| a ridge on Λ is not rotation-invariant | **wrong** — `‖ΛQ‖_F = ‖Λ‖_F`; verified against a non-orthogonal negative control |
| "the template runs away where the reference does not" | an artefact of the **warm start**, not the quadrature |
| withdrawing the σ/ρ claim after seeing Laplace+ridge | **over-correction** — the claim is true against the shipped comparator |

## How to resume

```bash
cd /private/tmp/gllvmtmb-arc0-identifiability
git fetch origin && git status -sb
```

Read, in order: **this file** → `docs/dev-log/decisions.md` (2026-07-28 entries) →
`docs/dev-log/handover/2026-07-25-active-lane-split.md` (lane map) →
`dev/aghq-evidence/05-descend-RESULT.txt` and `totoro-suite-inc.csv`.

The durable cross-repo finding is in the brain:
`memory/AGHQ exposes a flat likelihood direction in GLLVMs — the runaway is bimodal, not biased.md`.

**Spawn the Rose lens before any public or capability claim, and read the D-43 verdicts first.**

**One-command resume — paste in your own authenticated terminal:**

```
claude "Rehydrate from docs/dev-log/handover/2026-07-28-claude-handover-aghq-engine.md plus the CLAUDE.md snapshot, then: (1) read the D-43 panel verdicts in dev/aghq-evidence/D43-lens*.md and honour them — two NOT-DONE withholds the claim; (2) run the 16-family axis from dev/aghq-families/ on Totoro, 8 seeds, with gaussian as the positive control whose AGHQ lever must measure ~zero; (3) push the branch and open a PR. Do NOT flip the aghq default, do NOT claim any family works because the engine dispatches to it, and cap local cores at 6 because Codex shares the machine."
```

## Scope limits on the evidence

Binomial-logit only, plus gaussian as an exactness control. Two shapes (p=6 q=2 and
p=4 q=1), q ≤ 2, one DGP (loadings ~ N(0,1), intercepts ~ N(0.3,0.4), balanced, complete,
no covariates). 30 seeds per cell. **No coverage or interval evidence at all.** Fourteen of
sixteen families are unexercised under quadrature. `devtools::check()` and pkgdown were
**not** run.
