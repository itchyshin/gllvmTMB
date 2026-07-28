# After-task — the AGHQ integration-engine arc (2026-07-28)

Lane `claude/aghq-engine-20260728` · PR #801 (open, **not merged**) · base `main` @ `72c2e53d`
· 26 commits · 119+ files.

## 1. Goal

Give `gllvmTMB` a correct integration engine. Started as "Arc 0: settle whether the
campaign's 59/70 degenerate fits are genuine optima of unidentified models or failed
optimisations"; the maintainer lifted that fence mid-session and redirected to building
AGHQ across all 16 families, then sharpened the target to **beta, sigma and rho** — the
three quantities users read.

## 2. Implemented

* **AGHQ quadrature inside the TMB template**, reusing the existing `obs_loglik` lambda
  verbatim (`src/gllvmTMB.cpp:1994`, single call site `:2363`) — family-agnostic by
  construction; **no per-family engine code exists or should be written**.
* **Control surface**: `gllvmTMBcontrol(aghq = FALSE | "auto" | k)` plus `aghq_ridge`,
  `aghq_iter_cap`, `aghq_n_adapt`, `aghq_multistart`, `allow_nongaussian_reml`.
* **A weakly-informative ridge on the loadings** (`aghq_ridge = 2`), as an exact gradient
  adjustment — no template change, no recompile, no loss of AD exactness.
* **Start selection**, so AGHQ no longer inherits a runaway Laplace warm start.
* **Structural gate** (`R/aghq-gate.R`) routing on **computed treewidth**, not keywords.
* **Adaptive controller** (`R/aghq-control.R`): node floor 5, per-family-per-tier
  optimiser routing; 0 of 21 routes can emit `lbfgsb` without `factr`.
* **Engine-consistent reporting** (`R/aghq-report.R`): cross-engine AIC comparison warns.
* **`ordinal_probit`'s `1e-12` floor** → log-scale guard (it *bound* at quadrature nodes).
* **Non-Gaussian REML opened as Cox–Reid**, opt-in and warned.

## 3a. Decisions and rejected alternatives

Eleven entries in `docs/dev-log/decisions.md`. Load-bearing:

* **AGHQ becomes the main engine — reversing "stay Laplacian" (2026-05-15)**, whose grounds
  misread the literature's `n_i` as sites rather than **traits per site**.
* **AGHQ ships OPT-IN; Laplace stays default.** Flipping changes every user's numbers while
  touching no export, so `R CMD check` cannot catch it.
* **Rejected: post-hoc refinement.** It cannot move a parameter estimate, so it cannot be an
  engine. AGHQ is optimised *through*.
* **Rejected: more nodes as the small-n fix.** The integral is exact to 1.2e-09 at k=25.
* **Cox–Reid is a validated NEGATIVE here** — ~1%, wrong direction.
* **Rejected: Chung et al. (2013) log-gamma prior** — it guards the *zero* boundary; our
  runaway is the opposite direction.

## 4. Files touched

`R/fit-multi.R` · `R/gllvmTMB.R` · `R/aghq-gate.R` · `R/aghq-control.R` ·
`R/aghq-report.R` · `R/methods-gllvmTMB.R` · `src/gllvmTMB.cpp` ·
`tests/testthat/test-aghq-surface.R` · `test-aghq-golden.R` · `test-tmb-ad-safe-clamps.R` ·
`dev/aghq-evidence/` (25+ scripts and results) · `dev/aghq-r-reference.R` ·
`dev/aghq-families/` · `docs/dev-log/decisions.md` · `CLAUDE.md` · the handover · this report.
Full list: `git diff --name-only origin/main...HEAD`.

## 5. Checks run

* **Gaussian exactness** — Laplace is exact for a gaussian latent-linear model, so AGHQ must
  reproduce it with no free parameters: **+6.25e-13, identical at k=3 and k=9**. Re-checked
  after every engine edit.
* **Brute-force oracle** — `stats::integrate()` on a model small enough to integrate
  directly: agreement to **1.2e-09 at k=25**; the R reference reproduces gllvmTMB's own
  Laplace objective to **5.2e-08**.
* **Laplace path byte-identical** on 4 cells (max |par diff| = 0).
* Suites: `test-aghq-surface` 35/0 · `test-aghq-golden` 5/0 (3 skip) ·
  `test-tmb-ad-safe-clamps` 7/0. **Full `devtools::test()` and CI were still running at
  close** — see Residuals.
* **Compute**: 954-fit Totoro campaign (120 cores) + a killed 450-core-hour H4 campaign.

## 6. Tests of the tests

* Deliberately mis-centred the adaptation → Gaussian exactness went **k-dependent**
  (7.4e-4 at k=3). Reverted, re-measured.
* Disabled the accept test → the runaway reproduced exactly (F 235.78 → 238.76,
  `‖Σ_B‖_F` 45 → 2496, adaptation errored at pass 13). Reverted.
* Cross-engine AIC guard verified **both ways** — silent within an engine, loud across.
* Ridge invariance checked against a deliberately non-orthogonal negative control
  (17.1 red, 1e-15 green).
* **A vacuity caught in a draft**: the pass that rolls back a rejected step re-lands on
  `par_best`, so both convergence legs would have passed vacuously one pass after a
  failure. Guarded with `n_ok >= 2`.

## 7a. Issue ledger

PR #801 open, **not merged**. No issues filed. The blocking defect is in Residuals.

## 8. Consistency audit

`CLAUDE.md` snapshot refreshed with a START-HERE pointer; the multi-lane split map is
carried forward, not overwritten. `decisions.md` carries every reversal *as* a reversal.
Nothing exported; NAMESPACE untouched; Laplace default unchanged.

## 9. What did not go smoothly

**Seven corrections, most of them mine.** They are the reason to trust what remains.

| claim | reality |
|---|---|
| the quadrature contract (fold `exp(u'u)` into the weights) | **mine, and wrong** — made the grid unvalidatable by any independent check |
| "AGHQ prefers the degenerate optimum", 12/12 | **vacuous by construction** — the fitted point IS the MLE |
| "two errors cancelling" | **refuted** — a two-population mixture: 30 converged fits at 0.810 plus 10 non-converged blow-ups |
| the runaway is separation-driven | true for Laplace (12/40); **false for AGHQ** (1/40) |
| a ridge on Λ is not rotation-invariant | **wrong** — `‖ΛQ‖_F = ‖Λ‖_F` |
| "the template runs away where the reference does not" | an artefact of the **warm start** |
| withdrawing the σ/ρ claim, then restoring it | the restoration leaned on a restriction **I had authored** — see D-43 |

Also: I oversubscribed the shared laptop to **load 227 on 20 cores** while Codex was on it,
and had to be told; and I declared four healthy background jobs dead using
`pgrep -f Rscript`, which cannot see R (it runs as `exec/R`).

## 10. Known residuals

1. **🔴 A real defect, and the only merge blocker.** With the ridge on, the shipped
   configuration returns a **MAP point with ML curvature**: `logLik` sits off its own
   maximum and the gradient diagnostic cannot converge.
2. **The capability claim is WITHHELD** — D-43 returned **two NOT-DONE** (scope, method).
3. **No coverage evidence at all**, for any configuration. This is what the project gates on.
4. **The correctness evidence is not automated** — it lives in manually run scripts.
5. **Family axis unmeasured**: binomial-only plus gaussian as an exactness control;
   **14 of 16 families unexercised** under quadrature. Harness built, never run.
6. **`s_B` fenced**, so poisson/gaussian *default* `latent()` models are uncovered (binary
   defaults are covered — single-trial Bernoulli has auto-Psi pinned off).
7. **The flat direction is penalised, not fixed.**
8. Full `devtools::test()` and CI unresolved at close.

## 11. Team learning

* **Validate where the answer is KNOWN, then descend.** The maintainer's design, and the
  single reason an intractable picture became legible.
* **Never summarise a mixture with a median.** A reported "97% bias" was two modes, 1.030
  and >2, with the median describing neither.
* **Eliminate before treating, and make each exclusion a measurement.**
* **A better approximation is not automatically a better estimate.**
* **k=1 agreement proves plumbing, never quadrature** — k=1 *is* Laplace.
* **Gaussian exactness is necessary but not sufficient** — it tests normalisation, not node
  placement.
* **A fresh adversarial panel catches what the author cannot.** D-43 found a defence I had
  manufactured — "`Laplace+ridge` is not a route anyone can run" — when I had created that
  restriction myself in ~12 lines.

Four entries added to `memory/WHAT-WORKS.md`; the durable finding is in the brain as
*"AGHQ exposes a flat likelihood direction in GLLVMs — the runaway is bimodal, not biased."*

## 12. Cross-product coverage

Binomial-logit only, plus gaussian as an exactness control. Two shapes (p=6 q=2, p=4 q=1),
q ≤ 2, one DGP, 30 seeds/cell. No phylogenetic, spatial, kernel or REML models under
quadrature — those are fenced by design and state their reason. Cross-repo: the two-lever
finding transfers *from* drmTMB but **the Cox–Reid half does not transfer back** — measured
negative in this parameterisation, which is itself a result the drmTMB lane should know.
