# Pre-registered gate — Design 85 §11 Gate 3, VA joint-fit known-DGP recovery

**Written 2026-07-30, BEFORE the campaign is launched.** Nothing in this document may be edited
after the run starts. If the result disagrees with the expectation recorded here, **the expectation
was wrong — not the gate.** Design 85 §11: *"Gates are sequential. A later gate cannot compensate
for a failed earlier gate, and tolerances cannot be widened after seeing the result."*

## Why this run exists

Maintainer decision 2026-07-30: gllvmTMB 0.6 ships an opt-in, hard-fenced `engine = "va"`
(`docs/dev-log/2026-07-30-va-ships-in-06-reversal.md`, `LOOP/GOAL.md` Amendment 4). Admission is
**not** granted by that decision — it is granted by Gate 3, as written.

**Gate 3 has been attempted once and failed on execution, not on the estimator.** The 2026-07-20
audit (`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`) records that the runner *selected rank
by ML before fitting VA* — *"that is the Gate-4 hand-off design, not the required fixed-rank Gate-3
known-DGP comparison"* — and its Fisher/Curie lens concluded *"the pilot cannot be promoted because
the sequential recovery gate was not run as declared and failed fits must remain in the
denominator."* This design fixes exactly those two defects: **fixed rank, full denominator.**

## Sequential prerequisites — state before starting

| gate | status | evidence |
|---|---|---|
| **Gate 0** — scope/coordinate freeze | **PASS** | `test-va-r3-prototype.R`, `NOT_CRAN=true`: data contract asserted, `unique = TRUE` and `structured = TRUE` rejected, rank-deficient rejected |
| **Gate 1** — algebra and autodiff | **PASS** | same run: 352 passed, 0 failed, **0 skipped**. ⚠ Without `NOT_CRAN` the run reports 183 passed / 8 skipped and still looks clean — the 8 skips *are* Gate 1 |
| **Gate 2** — low-dimensional O3 references | **PASS** | `test-aghq-o3-scalar-spike.R`, `test-aghq-o3-q2-coupled-spike.R`, `test-aghq-o3-gllvmtmb-unit-hook.R`, `test-aghq-golden.R`, `test-aghq-r2-reference-harness.R`, `NOT_CRAN=true`: **1,469 passed, 0 failed, 0 error, 0 skipped**. §11's posterior-moment clause is asserted directly at `test-va-r3-prototype.R:973-975` — `mean_rmse < 0.05`, `median(cov_rel) < 0.10`, `max(cov_rel) < 0.25`, matching the gate's thresholds exactly |

**Scope note, so this is not over-read.** I line-verified §11 Gate 2's **third** clause (VA means and
covariance against O3 posterior moments) against the named assertions above. Clauses 1–2 (the
one-node joint-Laplace `1e-6` identity at `q = 1/2`, and the optimised quadrature ELBO not exceeding
the O3 marginal log-likelihood by more than `1e-6`) are covered by the three O3 spike files, which
passed with zero failures, but I did **not** line-map each clause to its assertion. Recorded as
PASS-with-scope-note rather than an unqualified PASS.

**Gates 0, 1 and 2 all hold, so Gate 3 may be run.** Had any failed, Gate 3 would not start —
§11 forbids a later gate compensating for an earlier one.

## Estimands — declared before the run

Design 85 §11 Gate 3: *"Primary targets are `beta`, `Sigma_B`, and fitted probabilities. Raw
`Lambda` is secondary and aligned; raw scores are not recovery targets."*

1. **`beta`** — the fixed-effect vector.
2. **`Sigma_B` = `Lambda Lambda'`** — the between-unit covariance. Reported **stratified**, because a
   single scalar over `p(p+1)/2` entries carrying only `pq - q(q-1)/2` free parameters is dominated
   by near-null off-diagonals: **(a)** diagonal, **(b)** off-diagonals with `|Sigma_B| >= 0.1`,
   **(c)** near-zero off-diagonals.
3. **fitted probabilities** — `plogis(eta)` on the observed cells.

**Secondary, aligned, not a gate:** raw `Lambda` after rotation alignment. **Not a target:** raw
scores.

**Reported beside every target, never as a filter:** the **signed** scale
`kappa = tr(Sigma_hat_B) / tr(Sigma_B)`. An unsigned error metric cannot distinguish contraction
from inflation, and `rel_frob > 10` requires `||Sigma_hat||_F > 9||Sigma||_F`, so it is structurally
blind to a contracting estimator.

## Fixed truths — NOT redrawn per seed

The existing grid draws `Lt <- matrix(rnorm(p*q, 0, 0.6))` **per seed**, so its error metric
estimates error *averaged over a prior on `Lambda`*, not error at a fixed truth. Gate 3 therefore
uses **three pre-declared `Lambda_0`**, generated once from `set.seed(20260730)` and frozen to disk
as `dev/va-gate3/truths.rds` before any fit:

| truth | construction | regime |
|---|---|---|
| `T-weak` | entries scaled so `max|Lambda_0| = 0.35` | weak signal |
| `T-mid` | entries scaled so `max|Lambda_0| = 0.70` | the grid's nominal scale |
| `T-strong` | entries scaled so `max|Lambda_0| = 1.40` | strong signal / near-separation |

Only the **data** is redrawn across seeds. `beta_0` is frozen alongside each `Lambda_0`.

## Design

- **Rank: FIXED at the planted `q`. No ML rank selection anywhere in the loop.** This is the single
  defect that caused the 2026-07-20 NO-GO.
- **`q` in {1, 2}** — Gate 3 is titled *"joint-fit known-DGP recovery at `q = 1/2`"* and is defined
  over exactly these. `q = 4` is **out of scope**: advancing from `q=1/q=2` references to `q=4/q=6`
  stress is what the 2026-07-20 audit refused.
- **`p` in {8, 20, 80}** — a declared design factor. §11 requires "a predeclared multi-seed known-DGP
  design" and does not fix `p`; adding it **widens no tolerance** and closes a structural gap (below).
- **`n` in {100, 400}** — the fence is `n >= 100`.
- **Seeds: 1:40 per cell**, declared now.
- **Family:** binomial-logit, `latent(..., unique = FALSE)`, **`n_trials = 1` (Bernoulli)** — see the
  2026-07-31 amendment immediately below, which supersedes the blocking correction that follows it.

### ✅ AMENDED 2026-07-31 — the blocker below is RESOLVED by maintainer decision

`docs/dev-log/2026-07-31-gate0-scope-extension-and-s11-departure.md` records a **fresh Gate 0 scope
freeze** extending the data contract to **`n_trials >= 1`**, on the ground that the hazard which
justified excluding Bernoulli — unguarded separation at pure 0/1 responses — is now guarded by
`.va_r3_check_separation()` (landed `08010b02`). A3 names binary JSDM as VA's purpose, so the
campaign runs **Bernoulli**, the regime that motivates the engine.

Two further amendments from the same decision:

- **`q ∈ {1, 2, 4}`** — the fence rises to `q <= 4`, **earned** by extending this design rather than
  asserted. `q <= 4` ships **only if the `q = 4` cells pass on their own terms**; a pass at
  `q ∈ {1,2}` does not license it. `q = 6` stays out of scope.
- **The `RMSE_ml` rule is chosen after both variants are seen** — an **explicit, recorded departure
  from §11**, mitigated by pre-declaring the admissible set to exactly two rules **now**:
  **R1 (raw)**, every replicate with finite output, no exclusions; and **R2 (paired exclusion)**,
  dropping replicates where **ML** is degenerate by the two-sided detector (`rel_frob > 10` or
  `kappa < 1/3`), applied identically to both arms so the comparison stays paired. **No third rule
  may be introduced later**, both are computed and reported for every cell, and whichever is chosen
  the other is published beside it. Nothing else moves — not the `0.05` tolerance, the 5%
  axis-collapse rate, the truths, the seeds, the cells, or the denominator.

Revised size: 3 truths × **3 `q`** × 3 `p` × 2 `n` × 40 seeds = 2,160 datasets × 3 arms =
**6,480 fits**.

**The text below is retained as the dated record of why the original design was blocked. It is
superseded on `n_trials` and on `q`; its reasoning about Gate 0's sequencing still stands.**

### 🔴 BLOCKING CORRECTION — `n_trials = 1` would fail Gate 0 by construction

This document originally specified `n_trials = 1` (Bernoulli). That is **outside Design 85's data
contract and is an explicit Gate 0 NO-GO.** Verified against the source:

- **§2:** *"The data are **complete multi-trial binomial** data: `n_it ∈ {2,3,…}` … There are no
  response masks, case weights, offsets, fractional successes, **single-trial Bernoulli rows**, or
  trait-specific links."*
- **Gate 0 NO-GO list:** *"any implicit `Psi`, changed loading transform, missing cell, **trial count
  below two**, or parked VA source copied without a fresh derivation audit."*

Gates are sequential and Gate 3 cannot compensate for a failed Gate 0. A Bernoulli campaign would
therefore have produced a result that **could never be admitted**, however it came out. Corrected to
`n_trials = 5` (multi-trial, inside the contract). The three frozen truths are unaffected.

### 🔴 …and the correction exposes a scope contradiction that is the MAINTAINER'S to resolve

Three positions in this repository are mutually inconsistent:

1. **Design 85 §2 / Gate 0** — Bernoulli is *excluded*; trial count below two is a NO-GO.
2. **`main`'s validator** — `R/va-r3-proto.R:210-212` *admits* `n_trials >= 1`. The relaxation from
   `>= 2` landed via `4dcf3d80` (PR #797), **and the separation guard written to protect it did
   not** (`docs/dev-log/2026-07-30-va-branch-reconciliation.md`).
3. **The motivating use case** — decisions.md **A3** names VA's purpose as *"high-$d$ **binary**
   JSDM … the regime where Laplace genuinely degrades (5+ latent factors)"*. Binary means
   presence/absence, i.e. **Bernoulli** — precisely what Design 85's contract excludes.

**So a Gate-3 campaign that is *valid* cannot cover the regime that motivates the engine, and a
campaign that covers that regime cannot be admitted.** This is not resolvable by an agent. It needs
one of: (a) ship `engine="va"` fenced to **multi-trial only** (`n_trials >= 2`), and say plainly that
binary JSDM — the headline use case — is **not** covered; (b) extend the contract to Bernoulli, which
requires a **fresh Gate 0 scope freeze** and the separation guard landed first, since separation is
endemic to sparse binary data; or (c) something else Shinichi decides.

**The campaign does not run until this is resolved.** Recorded rather than chosen.

### ⚠ A second risk to the pass rule's meaning, found during the smoke

The pass rule is *"VA … no more than `0.05` worse in absolute terms than ML."* Debugging the smoke
cell (5 extra seeds, in-memory, not persisted) found `ml_laplace` `kappa` ranging from **3.1 to
1,430**, with **every** seed reporting `convergence = 0, pdHess = TRUE` — including the catastrophic
ones. This is the same family as the pre-existing 12%-degeneracy-under-clean-status finding.

If `RMSE_ml` is outlier-dominated, *"no more than 0.05 worse than ML"* becomes **trivially passable**
— VA would clear a bar that ML itself is failing. A gate that a broken comparator makes easy is not a
gate. **How `RMSE_ml` handles its own degenerate replicates must be decided before any verdict is
read**, and it must be decided *now*, not after seeing the numbers (§11: tolerances cannot be widened
after the fact). Flagged for the maintainer.
- **Arms, all on byte-identical data:** `va_gh` (`eval_method = "gh"`, H = 15) · `va_jj`
  (`eval_method = "jj"`) · **`ml_laplace`** (the shipped engine, `unique = FALSE`) as the comparator
  Gate 3's pass rule is written against.

**Why both VA arms.** The estimator choice is currently **open**: Rose's adversarial gate rejected
GH-over-JJ after disaggregation showed JJ is the less-biased arm at large `p`
(`2026-07-30-gate01-status-and-estimator-open.md`), and Rose's structural objection was that Gate 3
*"sweeps neither `p` nor `n`, so it cannot discriminate between the tiers."* Declaring `p` and `n`
as factors and running both arms removes that objection **without touching the pass rule**.

Cell count: 3 truths × 2 `q` × 3 `p` × 2 `n` × 40 seeds = 1,440 datasets × 3 arms = **4,320 fits.**

## The pass rule — quoted, not paraphrased

> *"VA passes only if its `Sigma_B` relative Frobenius RMSE is no more than `0.05` worse in absolute
> terms than ML and no planted axis collapses in more than 5% of otherwise healthy, non-separated
> replicates."*

Operationalised, and frozen:

1. **RMSE criterion.** `RMSE_arm = sqrt(mean_over_seeds( (||Sigma_hat_B - Sigma_B||_F / ||Sigma_B||_F)^2 ))`.
   **PASS iff `RMSE_va - RMSE_ml <= 0.05`** in absolute terms, per cell.
2. **Axis-collapse criterion.** A planted axis has collapsed when its aligned singular value falls
   below `10%` of its planted value. **PASS iff the collapse rate is `<= 5%`** among replicates that
   are otherwise healthy and non-separated.
3. **Denominator.** *Every attempted fit* is in the denominator. A fit that errors, fails to
   converge, or is rejected by a guard counts as a **failure**, not a hole. §11 NO-GO: *"failed fits
   are excluded from denominators."*
4. **MCSE** is reported for every rate and every RMSE, computed **between replicates**, never by
   pooling `Sigma_B` entries as independent trials.
5. **Health is recovery against the known truth, never convergence.** §11 NO-GO: *"success is
   declared from convergence rate alone."* Both engines report `converged = TRUE` on degenerate fits.

## Declared in advance: what would FAIL this gate

- `RMSE_va - RMSE_ml > 0.05` in any in-fence cell.
- Axis collapse above 5% in any in-fence cell.
- Any post-hoc change to a truth, a seed set, a cell, or a tolerance in this document.
- Any exclusion of attempted fits from a denominator.
- A guard silently rejecting fits: `R/va-r3-proto.R:1271`'s
  `variance_domain_ok <- max_projected_variance <= 4` is a hard `admitted = FALSE`.

### ⚠ The guard was measured before the campaign, and it is asymmetric — binding constraints

Measured on the existing 2,880-row grid (recomputed this session, not read from `RESULTS.md`):

| arm | `failed_variance_domain` | rate |
|---|---:|---|
| `gtmb_gh` | 93 / 640 | **14.5%** |
| `gtmb_jj` | 0 / 320 | **0.0%** |

On matched bernoulli cells (same `n,p,q,seed`), **84 of 320 (26.25%)** are cells where **GH is
flagged by the variance gate specifically on data where JJ, fitted to the identical data, reports
healthy**. GH's rejected rows are its most-inflated ones — median trace ratio **3.96** against
**1.45** when healthy. JJ's own contraction makes it close to structurally immune to ever tripping
this gate, independent of whether its fit is any good.

**Therefore, binding on this campaign:**

1. **No filtering on `status == "healthy"` or `health$admitted`, anywhere.** Such a filter would
   silently delete GH's high-variance tail while leaving JJ untouched — manufacturing exactly the
   result the campaign exists to test. Fitted `Lambda`, `v_by_obs` and the ELBO are fully populated
   regardless of admission, so nothing requires it.
2. **`admitted` is not a health signal at `n_starts = 1`.** It collapses the variance-domain check
   with a multi-start-agreement check; at `n_starts = 1` it can **never** be `TRUE` regardless of fit
   quality. A status-based rule would delete the whole campaign.
3. **Record the continuous `max_projected_variance` and `variance_domain_ok` as separate columns**,
   not the collapsed `status`/`admitted` pair. The value already exists at
   `r$v$engine_result$health$max_projected_variance` (`R/approximation-engine.R:133`) and is dropped
   by the existing `run-grid.R` `row()` helper — which is why `grid.csv` carries no such column and
   no threshold sensitivity is derivable from it without re-fitting.
4. **The `<= 4` threshold is NOT relaxed.** It is frozen by prior maintainer-level decision
   (`docs/dev-log/handover/2026-07-26-codex-handover-va-variance-gate-close.md`: *"The `<= 4` gate
   remains frozen. This result does not authorize a threshold relaxation"*). Recording the continuous
   value makes later sensitivity analysis possible without changing any shipped behaviour now.
5. `guard_rejected` remains a **recorded outcome inside the denominator**, never a dropped row.

**Context, reported not re-verified (AGENT-INFERRED for this campaign's purposes):** a prior
independent measurement on multi-trial binomial fixtures with a validated brute-force truth ladder
found **no break at 4** — the ELBO stayed a valid negative-gap lower bound through observed variance
`8.674`, with the *instrument* rather than the ELBO failing only at `22.19`. Separately, the guard
fires on `gaussian_anchor` and `poisson`, whose closed forms are exact for any `v`, so its only
imaginable quadrature-domain justification cannot apply there. Both are recorded as background for
whoever revisits the threshold; **neither licenses changing it here.**

## Expectations, recorded so they can be wrong

**AGENT-INFERRED, not evidence.** From the existing grid: `va_jj` contracts (`kappa < 1`), worst at
small `p` (`kappa ~ 0.50` at `n=400, p=8`) and mildest at large `p` (`~0.93` at `p=80`); `va_gh`
inflates mildly and flatly (`kappa ~ 1.07-1.21`). I therefore expect **`va_gh` to pass at small `p`
and `va_jj` to pass at large `p`**, with neither dominating — a crossover, not a winner. If instead
one arm passes everywhere, that expectation was wrong and the design was too weak to see it.

Compute: **LOCAL** (D-50). Results stay local; never GitHub artifacts.

> Related: `docs/design/85-highdim-nongaussian-va-formal-contract.md` §§10–11 ·
> `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md` ·
> `docs/dev-log/2026-07-30-va-ships-in-06-reversal.md` ·
> `docs/dev-log/2026-07-30-gate01-status-and-estimator-open.md` ·
> `docs/dev-log/2026-07-30-rose-default-tier-reversal-gate.md`
