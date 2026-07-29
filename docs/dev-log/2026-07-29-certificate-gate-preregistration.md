# Pre-registered gate — Gaussian `Sigma_unit` diagonal profile interval

**Written 2026-07-29, BEFORE the confirmatory campaign was launched.** Nothing in this document
may be edited after the run starts. If the result disagrees with the expectation recorded here,
the expectation was wrong — not the gate.

## Why this run exists

This is **confirmatory, not exploratory**. The 2026-07-17 D-43 panel
(`docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`, commit `dd80244a`) already adjudicated this
cell at pooled N≈15k and returned **BOTH CELLS CERTIFY, 3-0**, with d1-n150 coverage 0.9477
(band 0.9440) and d2-n150 0.9461 (band 0.9424).

Two things make a re-run necessary anyway:

1. **The raw is gone.** `~/gllvm_work/results/` on Totoro is empty. The per-rep covered/converged
   flags the panel's two lenses independently recomputed from no longer exist, so the summary
   survives but the reproduction does not.
2. **That panel never reached `main`**, so the package's own record still carries the earlier 5k
   WITHHELD result as if it were current.

Because the expected answer is already known, pre-registration matters *more* here, not less: a
confirmatory run is exactly where a gate is most tempting to soften after the fact.

## Estimand

`V_t = Sigma_unit[t,t] = (Lambda Lambda^T)[t,t] + psi[t]` — the total between-unit variance for
trait `t`, under a **diagonal** `Sigma_unit` specification, gaussian family.

## Route under test

`profile_total` — a genuine chi-square_1 profile on `log(V_t)`, via
`gllvmTMB:::.profile_ci_total_variance()` → `.profile_ci_via_refit()`.

Recorded for the avoidance of doubt: `.profile_ci_via_refit()` runs its **own** `stats::uniroot`
and never calls `.profile_bounds()` or `TMB::tmbprofile()` — it only mentions the former in a
comment (`R/profile-derived.R`). The 2026-07-28 interval fixes (`e34176eb`, `26ac8301`, `bb4862bb`)
therefore do **not** sit on this path, and do not invalidate the prior measurements.

`wald_t_logsd` (log-SD delta-Wald) is co-computed as a **diagnostic only**. It is not on the
certificate path and no gate applies to it.

## Cells

| cell | family | d | n_units | n_traits |
|---|---|---|---|---|
| d1-n150 | gaussian | 1 | 150 | `M3_DEFAULT_N_TRAITS` |
| d2-n150 | gaussian | 2 | 150 | `M3_DEFAULT_N_TRAITS` |

`n_units = 50` cells are **out of scope** — the certificate was always scoped to n ≥ 150.
Binomial, nbinom2 and ordinal stay **FENCED** and are not re-scored here (binomial sits at a
psi = 0 boundary with 0.77–0.92 coverage; it is a known non-certifying cell).

## Replication and seeds

- **20,000 reps per cell.**
- Seeds are drawn fresh for this run. The prior 15k raw no longer exists, so this campaign is
  **self-contained** — no pooling with historical reps, no reuse of a previous seed window.

## The gate

- **Gate: `coverage >= 0.94`.** Not 0.95. This is a maintainer decision taken 2026-07-29.
- **Lower band = `coverage - 2 * MCSE`**, with `MCSE = sqrt(p * (1 - p) / n_reps)`.
  This treats each rep as a single Bernoulli — the maximum-variance case — so the band is an
  upper-bounded worst case that cannot shrink under intra-rep correlation.
- **Decision rule: CERTIFY only if the lower band clears 0.94 for BOTH cells.**
  If either cell's band falls below 0.94, the disposition is **WITHHELD** — for both.

## What would make this WITHHELD

Recorded in advance so the answer cannot be reverse-engineered from the data:

- Either cell's lower band < 0.94.
- Coverage materially below the 0.9461–0.9477 the 15k run reported, i.e. outside what the new
  MCSE explains — that would mean the prior result was not reproducible and the whole route is
  in question, which is a **larger** finding than a failed gate.
- A convergence or `ci_available` rate low enough that the covered/eligible denominator is not
  the population the claim is about.

## Prohibited after launch

- Relaxing the gate below 0.94.
- Switching to a one-sided band, or to 1·MCSE, to rescue a marginal cell.
- Dropping a failing cell from the claim and certifying the survivor.
- Pooling these reps with any historical run.
- Restating the result as nominal or unconditional 95% coverage. The 2026-07-17 record's own
  instruction stands: *"Do NOT restate the number as unconditional or nominal-0.95 coverage; the
  gate is `coverage >= 0.94`."*

## Expectation (falsifiable, recorded in advance)

At 20,000 reps and p ≈ 0.946, `MCSE ≈ 0.0016`, so `2*MCSE ≈ 0.0032`.
Carrying the 15k point estimates forward, the expected bands are **d1 ≈ 0.9445** and
**d2 ≈ 0.9429** — both clearing 0.94, d2 thinly. **If d2's band lands below 0.94, the gate is not
met and the certificate is withheld**, regardless of how close it comes.

## Adjudication

A **D-43 panel of three fresh agents**, default NOT-DONE, under distinct lenses (statistical ·
pooling and reproducibility · claims and scope). **Two or more withholds blocks the claim.**
The panel adjudicates; it does not flip any public surface. Any flip is the maintainer's act.

## Data handling

Raw per-rep output stays **LOCAL on Totoro** (D-50) — never a GitHub artifact. **Retain it this
time**: the entire reason this run exists is that the last raw set was lost.
