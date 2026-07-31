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
- **Family:** binomial-logit, `latent(..., unique = FALSE)`, `n_trials = 1`.
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
  `variance_domain_ok <- max_projected_variance <= 4` is a hard `admitted = FALSE`. **Its reachability
  under the three declared truths must be measured and reported before the campaign**, because if it
  rejects `T-strong` it truncates the gate's own strong-signal arm. (Slice S3 owns this.)

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
