# 73/74 split-instrumented result — seed-1 blow-up: does it reproduce?

Cell for both tasks: N=120, T=10, q=1, binomial-probit, n_trials=6, our arm
`eval_method="ac"`, `collapse_variational_cov=TRUE`, `unique=FALSE`, SEEDS 1:8
(default `n_starts=4`). Task A plants PSI=0.6 in the DGP (misspecified fit,
matching `71-split25.R`); Task B is identical except PSI=0 (correctly
specified). Full per-seed data: `dev/va-speed/73-split-instrumented.rds`,
`dev/va-speed/74-spec-discriminator.rds`. Scripts and raw run logs are beside
this file.

## Methodology notes (both required by the coordinator mid-task)

- **Warm-up added.** `71-split25.R` had no untimed warm-up, unlike its sibling
  `57-gllvm-scaling.R:74-78`. Both 73 and 74 add one: an untimed, discarded
  fit at N=40, seed=999, for BOTH arms, before any timed run.
- **Run order randomised and reported.** Seed execution order was
  `1, 2, 7, 6, 5, 8, 4, 3` (permutation seed 20260805, identical in both
  scripts) — recorded per-row as `run_order_position`. Seed 1 ran FIRST in
  both timed loops, which makes it the most exposed seed to any residual
  first-call cost, not the least.
- **Load caveat.** Totoro ran another agent's (Fisher's) `75-clean-ladder.R`
  parallel campaign throughout both runs: `/proc/loadavg` read ~24.6–25.6
  (1-min avg) before, during, and after both timed loops (full readings in
  the meta blocks below and in the raw logs). My jobs are single-threaded,
  serial, on a 384-core box (~25 busy cores), so headline contamination risk
  is low, but this is stated, not assumed away. The evaluation/iteration
  counts below are trace-based and load-independent; only the wall-clock
  columns carry this caveat.
- **Trace target corrected.** The brief suggested
  `trace(nlminb, where = asNamespace("gllvmTMB"))`. Verified empirically
  (see history in this session) that this is wrong for this codebase:
  `get("nlminb", envir = asNamespace("gllvmTMB"), inherits = FALSE)` errors
  "object not found" — there is no local `nlminb`/`optim` binding in
  gllvmTMB's own namespace frame. Every optimiser call in
  `R/va-r3-proto.R` is explicitly `stats::nlminb(...)` / `stats::optim(...)`,
  which always resolves directly against `stats`'s own namespace and never
  consults a calling package's local bindings. The working target, verified
  to give non-zero, structurally exact counts (12 nlminb + 4 optim calls for
  4 starts × up to 3 nlminb + 1 L-BFGS-B each, matching the polish-loop logic
  read from source) is `trace(nlminb, where = asNamespace("stats"))` /
  `trace(optim, where = asNamespace("stats"))`. Both scripts verify non-zero
  counts on a throwaway fit before running any seed that counts, per the
  brief's fail-closed instruction.

## Task A — misspecified (PSI=0.6 planted, `unique=FALSE` fit)

Run order: 1, 2, 7, 6, 5, 8, 4, 3. Loadavg at start of timed loop: `25.51 20.67 9.80`; at end: `25.43 20.82 9.96`.

| seed | run pos | ours wall (s) | status | polish | nlminb calls | optim calls | iters | fn evals | gr evals | ms/fn eval | gllvm wall (s) |
|---:|---:|---:|:---|:---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 0.754 | healthy | nlminb_then_lbfgsb | 12 | 4 | 386 | 604 | 407 | 1.248 | 0.092 |
| 2 | 2 | 0.779 | healthy | nlminb_then_lbfgsb | 12 | 4 | 419 | 639 | 440 | 1.219 | 0.112 |
| 3 | 8 | 0.801 | healthy | nlminb_then_lbfgsb | 12 | 4 | 427 | 666 | 446 | 1.203 | 0.093 |
| 4 | 7 | 0.715 | healthy | nlminb_then_lbfgsb | 12 | 4 | 384 | 570 | 407 | 1.254 | 0.114 |
| 5 | 5 | 0.723 | healthy | nlminb_then_lbfgsb | 12 | 4 | 380 | 589 | 401 | 1.228 | 0.091 |
| 6 | 4 | 0.733 | healthy | nlminb_then_lbfgsb | 12 | 4 | 380 | 593 | 402 | 1.236 | 0.094 |
| 7 | 3 | 0.745 | healthy | nlminb_then_lbfgsb | 12 | 4 | 417 | 601 | 436 | 1.240 | 0.100 |
| 8 | 6 | 0.753 | healthy | nlminb_then_lbfgsb | 12 | 4 | 406 | 597 | 427 | 1.261 | 0.102 |

Wall (ours): median 0.749s, range 0.715–0.801s (max/min = 1.12x). fn_total:
median 599, range 570–666 (1.17x). Every one of the 8 seeds, at every one of
the 4 multi-starts, needed the full polish loop and escalated to L-BFGS-B
(`n_nlminb_calls=12`, `n_optim_calls=4`, no exceptions) — call-count structure
is completely uniform across seeds.

## Task B — correctly specified (PSI=0, `unique=FALSE` fit)

Run order: 1, 2, 7, 6, 5, 8, 4, 3 (same permutation). Loadavg at start of timed loop: `24.85 21.83 11.38`; at end: `24.94 21.90 11.46`.

| seed | run pos | ours wall (s) | status | polish | nlminb calls | optim calls | iters | fn evals | gr evals | ms/fn eval | gllvm wall (s) |
|---:|---:|---:|:---|:---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 0.777 | healthy | nlminb_then_lbfgsb | 12 | 4 | 379 | 585 | 399 | 1.328 | 0.092 |
| 2 | 2 | 0.784 | healthy | nlminb_then_lbfgsb | 12 | 4 | 406 | 607 | 429 | 1.292 | 0.112 |
| 3 | 8 | 0.775 | healthy | nlminb_then_lbfgsb | 12 | 4 | 383 | 596 | 405 | 1.300 | 0.101 |
| 4 | 7 | 0.821 | healthy | nlminb_then_lbfgsb | 12 | 4 | 441 | 627 | 463 | 1.309 | 0.108 |
| 5 | 5 | 0.748 | healthy | nlminb_then_lbfgsb | 12 | 4 | 381 | 584 | 403 | 1.281 | 0.125 |
| 6 | 4 | 0.825 | healthy | nlminb_then_lbfgsb | 12 | 4 | 415 | 650 | 439 | 1.269 | 0.098 |
| 7 | 3 | 0.782 | healthy | nlminb_then_lbfgsb | 12 | 4 | 410 | 600 | 430 | 1.303 | 0.103 |
| 8 | 6 | 0.770 | healthy | nlminb_then_lbfgsb | 12 | 4 | 398 | 613 | 421 | 1.256 | 0.181 |

Wall (ours): median 0.779s, range 0.748–0.825s (1.10x). fn_total: median 603,
range 584–650 (1.11x). Same uniform call-count structure: 12 nlminb + 4 optim
calls at every seed.

## Verdicts

**(a) Does the 25.5s blow-up reproduce? NO.** Across both the misspecified
(Task A, PSI=0.6) and correctly-specified (Task B, PSI=0) cells, all 8 seeds
land in a narrow band (0.715–0.825s combined range across both tasks, well
under a 1.2x spread within either task). Seed 1 is not an outlier in either
run — in Task A it is the 2nd-fastest of 8; in Task B it is the 2nd-fastest of
8 (by fn_total) / mid-pack by wall-clock. Seed 1 also ran FIRST in the
execution order in both tasks, so if any residual first-call cost had
survived the warm-up, seed 1 was the seed most exposed to it — and it still
shows nothing. The evaluation counts (the load-independent primary metric)
confirm this is not a load artefact: fn_total for seed 1 (604 in Task A, 585
in Task B) sits inside the same range as every other seed. The most likely
explanation, consistent with the coordinator's diagnosis, is that the
original 71-split25.R measurement had no warm-up and seed 1 — which ran
first in that 1:3 script — absorbed the one-time TMB-compile / first-call
setup cost that this script's warm-up now pays separately and untimed.

**(b) Conditioning vs. evaluation cost — moot as posed, but the trace still
characterises the cost.** There is no 25x-blow-up seed to split into
"more iterations at similar per-iteration cost" vs. "similar iterations at
exploding per-iteration cost" — the premise (one anomalous seed) did not
hold. What the trace does show, uniformly across all 16 fits (8 seeds × 2
tasks): every single multi-start (all 4, every seed, every task) needed the
full 2-pass nlminb polish loop and then escalated to L-BFGS-B
(`n_nlminb_calls=12`, `n_optim_calls=4` with zero variance across all 16
runs). Per-evaluation cost is flat at ~1.2–1.3 ms/fn-eval across every seed
in both tasks — no seed shows an elevated per-evaluation cost either. So
within this cell, whatever gap exists between our AC arm and gllvm's wall
time (~0.72–0.83s vs ~0.09–0.18s, roughly 7–8x) is a uniform property of the
cell/arm, not a seed-specific pathology, and this instrumented run has
nothing further to say about conditioning vs. evaluation cost since there is
no split to make.

**(c) Does it survive correct specification? N/A — nothing to survive, and
correct specification changes nothing qualitative.** Since Task A showed no
blow-up once warm-up was controlled, Task B cannot show a blow-up
"vanishing." As a secondary check, Task B (PSI=0, correctly specified) and
Task A (PSI=0.6, misspecified) are statistically indistinguishable: wall
medians 0.779s vs 0.749s, fn_total medians 603 vs 599, identical uniform
call-count structure (12 nlminb + 4 optim, every seed, both tasks). Correct
specification does not measurably change this cell's optimisation cost in
either direction. Combined with (a), the original 25.5s/0.75s report is not
explained by misspecification either — it is explained by the missing
warm-up.

## Bottom line

The headline finding that motivated a loadings reparameterisation (seed 1 at
~25x the other seeds) does not reproduce under a warm-up-controlled,
randomised-order, traced re-measurement. Instrumentation is solid (verified
non-zero before every run; call counts are exact and load-independent) and
shows a uniform, unremarkable optimisation pattern across all 16 fits run
here. This does not by itself certify `71-split25.R`'s original run as wrong
(a warm-up gap is the most likely explanation, not a proven one — the
original process/environment was not re-inspected), but it means the
~25x-outlier claim should not be relied on without re-confirming it under
warm-up control, and a ~23-file loadings reparameterisation aimed at fixing a
seed-specific blow-up would currently be chasing a finding that did not
reproduce here.
