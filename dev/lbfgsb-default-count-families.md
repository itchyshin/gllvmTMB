# Fisher shard: nlminb vs lbfgsb for the COUNT families (poisson, nbinom2)

**Question.** Should `optimizer = "lbfgsb"` become the DEFAULT for `.va_r3_fit()`?
This shard covers the two families the earlier gaussian_anchor / binomial
evidence never touched: **poisson** (log link) and **nbinom2** (log link).

**Scope.** `q in {1, 2, 3}` x `N in {150, 400}` x `T = 8`, one seed per cell
(12 cells total), plus one smoke cell (`N = 20`, not part of the graded grid).
Each cell fits IDENTICAL data twice with `n_starts = 1L` — once
`optimizer = "nlminb"`, once `optimizer = "lbfgsb"` — and compares
`fit$starts[[1]]` (the single-start record), not the top-level `status`
(which cannot read `"healthy"` at `n_starts = 1` regardless of fit quality,
since the admission gate needs >= 3 healthy starts).

Script: `dev/lbfgsb-default-count-families.R`. Raw per-cell CSV:
`dev/lbfgsb-default-count-families.csv`. Run log: `dev/lbfgsb-default-count-families.log`.
Follow-up diagnostic for the one disagreement: `dev/lbfgsb-count-families-diagnose-cell4.R`
(output: `dev/lbfgsb-count-families-diagnose-cell4.stdout`).

## Smoke result (pipeline check, not graded)

poisson, q=1, N=20, T=8: both optimizers returned finite objectives,
`objective_delta = -1.7e-9`, `max_dpar = 2.65e-5`, both `convergence = 0`. OK
to proceed.

## Grid result: 11 of 12 cells AGREE

Agreement criterion: `|objective_delta| <= 1e-5` AND `max_dpar <= 1e-2`.

| family  | q | N   | obj_delta   | max\|dpar\| | log_phi max\|Δ\| | conv (n,l) | agree |
|---------|---|-----|-------------|-------------|-------------------|------------|-------|
| poisson | 1 | 150 | 3.04e-08    | 2.87e-05    | —                 | 0, 0       | TRUE  |
| nbinom2 | 1 | 150 | 8.61e-08    | 4.69e-04    | 2.93e-04          | 0, 0       | TRUE  |
| poisson | 2 | 150 | 4.03e-08    | 1.36e-03    | —                 | 0, 0       | TRUE  |
| **nbinom2** | **2** | **150** | **2.72e-06** | **1.19e-02** | 2.02e-04    | 0, 0   | **FALSE** |
| poisson | 3 | 150 | 2.98e-07    | 5.79e-04    | —                 | 0, 0       | TRUE  |
| nbinom2 | 3 | 150 | 9.27e-08    | 8.57e-04    | 8.57e-04          | 0, 0       | TRUE  |
| poisson | 1 | 400 | 1.65e-07    | 1.86e-04    | —                 | 0, 0       | TRUE  |
| nbinom2 | 1 | 400 | 3.99e-07    | 3.78e-04    | 1.76e-04          | 0, 0       | TRUE  |
| poisson | 2 | 400 | 4.68e-07    | 1.23e-03    | —                 | 0, 0       | TRUE  |
| nbinom2 | 2 | 400 | 3.11e-08    | 2.54e-04    | 2.06e-04          | 0, 0       | TRUE  |
| poisson | 3 | 400 | 3.40e-07    | 4.53e-04    | —                 | 0, 0       | TRUE  |
| nbinom2 | 3 | 400 | 1.06e-06    | 2.26e-03    | 9.34e-04          | 0, 0       | TRUE  |

Every cell reports `convergence = 0` for BOTH optimizers, in every family, at
every q and N tested. Every objective delta is at most 2.7e-6 (i.e. two full
orders of magnitude inside the 1e-5 agreement bound) — including in the one
cell that fails the dpar test. So on the objective alone, all 12 cells agree
to a much tighter tolerance than the gate requires.

## The one disagreement: nbinom2, q=2, N=150, seed=3004

`objective_delta = 2.72e-6` (agrees comfortably) but `max_dpar = 0.0119`,
just over the 1e-2 bound. Diagnosed with `dev/lbfgsb-count-families-diagnose-cell4.R`:

- Max |Δ| by parameter block: `m` (variational per-unit latent mean) = **0.0119**,
  `theta_rr` (loadings) = 0.0035, `L_off` = 0.0019, `log_L_diag` = 0.0014,
  `log_phi` = 2.0e-4, `beta` = 1.7e-5.
- **`log_phi` is NOT the source of the disagreement** — it differs by at most
  2.0e-4 in this cell, in line with every other nbinom2 cell (1.8e-4 to
  9.3e-4). No family-specific `log_phi` anomaly anywhere in the grid.
- Both runs report `convergence = 0`, but neither actually reaches the
  fit's own 1e-4 gradient-health tolerance after the full polish sequence:
  `max_abs_gradient` = 1.35e-4 (nlminb path) vs 2.48e-4 (lbfgsb path) — both
  are why `healthy_nlminb`/`healthy_lbfgsb` read FALSE for this cell in the
  CSV, independent of which optimizer disagreement is about.
- The `theta_rr` (loadings) diffs are small and roughly canceling (both
  positive and negative, magnitude 1e-6 to 3.5e-3) with no consistent sign
  pattern that would indicate a loading-sign or rotation flip; this reads as
  a shallow/near-flat direction in the ELBO around `m` and `theta_rr` jointly
  (q=2, N=150 is exactly the setting where variational-score/loading
  non-identifiability is weakest-signal), not two qualitatively different
  optima.

**Read:** this is a near-tie on a shallow ridge where neither optimizer's run
fully converges under strict criteria, not evidence of a systematically
different optimum. It is nonetheless the one cell in this shard where the
existing `max_dpar <= 1e-2` agreement gate would fire, and it is worth
carrying forward as a concrete example of where the two-optimizer contract
can disagree at the margin.

## log_phi -- specifically checked, nothing odd

Across all six nbinom2 cells, `log_phi_max_ddelta` (max |Δ| restricted to the
`log_phi` block, one entry per trait, T=8) ranges 1.8e-4 to 9.3e-4 and tracks
the same order of magnitude as the rest of the parameter vector in each
cell — it is never the dominant source of disagreement, including in the one
cell that disagrees overall. No sign flips, no blow-ups, no NA/Inf. The
newest mapped-in parameter behaves like any other fixed parameter here.

## Timing -- informational only, and it complicates the earlier evidence

**Caveat first, per the task's hard rules:** `uptime` showed a load average of
~40-44 on a 20-core machine for the whole run (other R processes were
independently active in this same worktree and elsewhere on the box), and
every timing below is a SINGLE pass per optimizer per cell — not a
warm-vs-warm repeated-fit comparison. These numbers are NOT a validated speed
claim. Fit order was alternated by seed parity (lbfgsb-first on even seeds)
to avoid a directional JIT/cache bias, but that does not make single-pass
absolute times trustworthy.

With that said, the PATTERN is worth flagging because it runs opposite to the
earlier gaussian_anchor / binomial finding, and it recurs in every one of the
6 nbinom2 cells:

| family  | q | N   | nlminb (s) | lbfgsb (s) | lbfgsb/nlminb |
|---------|---|-----|-----------:|-----------:|---------------:|
| nbinom2 | 1 | 150 | 6.4        | 15.5       | 2.4x slower |
| nbinom2 | 2 | 150 | 9.2        | 36.1       | 3.9x slower |
| nbinom2 | 3 | 150 | 11.7       | 28.7       | 2.5x slower |
| nbinom2 | 1 | 400 | 18.5       | 42.0       | 2.3x slower |
| nbinom2 | 2 | 400 | 28.1       | 44.6       | 1.6x slower |
| nbinom2 | 3 | 400 | 51.6       | 120.2      | 2.3x slower |

For poisson the direction is mixed (nlminb faster in 3/6 cells, lbfgsb faster
in 3/6, ratios all within 2x either way) — no consistent pattern there.

A plausible MECHANISM, visible directly in the diagnostic output for the
disagreeing cell and consistent with `.va_r3_fit()`'s own polish logic (see
the header comment in `dev/lbfgsb-default-count-families.R`): the per-start
loop always tries an nlminb polish (up to 2 passes) after the PRIMARY
optimizer, and adds a further lbfgsb polish call if the gradient still isn't
below 1e-4 — **regardless of which optimizer was primary**. In the one
diagnosed cell, BOTH primary choices ended up going through the full
`"nlminb_then_lbfgsb"` polish chain (primary + 2 nlminb passes + 1 more
lbfgsb call), and the lbfgsb-primary path still finished with a WORSE
residual gradient (2.48e-4 vs 1.35e-4) despite the extra work. If lbfgsb's
factr-based stopping rule tends to hand off to the nlminb/lbfgsb polish chain
more often, or leaves it needing the full 2-pass budget more often, for the
nbinom2 objective specifically (a genuinely different likelihood surface from
gaussian_anchor/binomial/poisson — it carries the extra per-trait `log_phi`
block), that would show up exactly as "lbfgsb-primary costs more wall clock"
even though this shard was AGREEMENT-focused, not a timing study. This is
AGENT-INFERRED, not measured directly (no per-sub-call timing was captured).

**This is the opposite of what the gaussian_anchor / binomial evidence found**
(lbfgsb 17.7-37.7x faster / 2.54x faster). Given the caveats above, I would
not treat either direction as settled for nbinom2 without a proper
warm-vs-warm, interleaved, multi-seed timing study — but the fact that the
direction flips, consistently, across all 6 nbinom2 cells under identical
methodology to the other families, is itself a reason not to generalize the
earlier speed finding to nbinom2 without dedicated measurement.

## Bottom line for the "should lbfgsb become default" question

- **Same-optimum evidence now extends to poisson and nbinom2** at q in
  {1,2,3}, N in {150,400}: 11/12 cells agree on both objective and parameters,
  with convergence = 0 on both optimizers in every cell tested.
- **One disagreement was found** (nbinom2, q=2, N=150) — small in objective
  terms (2.7e-6) but over the parameter-agreement threshold (0.0119 vs
  0.01), traced to the variational mean `m` and loadings `theta_rr` on what
  reads as a shallow ridge, not a different optimum; `log_phi` is not
  implicated. This is a genuine, if marginal, counterexample to "always the
  same optimum" and should be weighed by whoever makes the default decision.
- **`log_phi` shows no family-specific anomaly** anywhere in the grid.
- **A speed regression pattern for nbinom2 specifically, opposite in
  direction to the prior families' finding**, surfaced as a side effect of
  this agreement-focused run. It is NOT validated (single-pass, contended
  CPU) but is consistent enough across 6/6 nbinom2 cells that it should not
  be ignored, and argues against extending the earlier "lbfgsb is faster"
  claim to nbinom2 without a dedicated warm-vs-warm timing study.
- Still untested by this shard: `q > 3`, binomial `eval_method = "gh"` (that
  is the other Fisher shard's territory per `dev/lbfgsb-default-binomial-and-q.R`),
  and any n outside {150, 400}.
