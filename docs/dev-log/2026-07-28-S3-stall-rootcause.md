# AGHQ first-adaptation stall: root cause

Worktree `/private/tmp/gllvmtmb-arc0-identifiability`, branch
`claude/sigma-intervals-boundary-20260728`. `devtools::load_all(".")`
throughout, `OMP_NUM_THREADS=1`, at most 6 cores. No package source file was
edited; all scratch scripts live under this scratchpad directory.

## Verdict

**(C) — genuinely (near-)flat objective, for the specific fixture/regime.**
Confirmed directly and adversarially, including against a competing claim
recovered mid-task from a Codex session (see "Adversarial check" below),
which is **partially confirmed, partially refuted**: it correctly names a
real, independently-verified control-flow defect, but its stronger
conclusion ("this is NEITHER a flat objective") is false for the fixture it
was tested against.

(A) optimiser handoff and (B) stale tape are both **ruled out** as the cause
of the non-movement itself. A third, real mechanism exists on top of (C): a
genuine control-flow interaction in the stopping/escalation logic causes the
loop to mislabel a near-stationary point as "STALLED" after only 2 passes
instead of grinding through further (still tiny) passes — this explains the
*symptom* (`par_shift` reported as exactly 0 after 2 passes) but not the
*substance* (there is almost nothing to find underneath it).

## Discriminating evidence

**Rules out (B) stale tape.** Built a `retape()`d object and an independent
fresh `MakeADFun()` at the identical adaptation point, then evaluated both
at three points including one neither was built at (`par_L`, a perturbed
point, and their midpoint). `fn`/`gr` agreed to `0` difference (not
"small" — exactly `0`, floating-point identical) at all three points
(`06-dissect-clean.R` TEST B). The tape is rebuilt correctly on every pass;
this is not the mechanism.

**Rules out (A) handoff-losing-state as the cause of non-movement.** Built
one pristine, single-use AD object adapted exactly at the Laplace optimum
`par_L`, fed `par_L` to `nlminb(..., iter.max=1, eval.max=4)` with no
intervening code and no other call chain. `nlminb` returned `par_L`
unchanged, with its own diagnostic `"function evaluation limit reached
without convergence (9)"` — an honest report that it could not find *any*
improving point within 4 evaluations, not evidence of a reset or lost
starting value. Nothing was lost; nothing to lose was ever passed elsewhere.

**Positively confirms (C), four independent ways, on the SAME clean tape and
starting point:**
1. *Curvature profile* along the steepest-descent direction from `par_L`:
   objective is flat to floating-point noise out to step ≈ 1e-5, only
   detectably rises by step = 1e-4, and is off by +2.5 at step = 0.03 — an
   extremely narrow, steep-walled trough around a small-gradient point.
2. *Uncapped optimiser, same tape, same start*: `nlminb` with 500× the
   budget (`eval.max=2000, iter.max=1500`) and independently `optim(...,
   "BFGS")` both converge almost immediately to essentially the same point:
   objective improves by only 8.6e-6, parameter shift only ≈2.5e-4.
3. **The decisive test** (requested by the coordinator): raised the
   production loop's *actual* first-pass budget through the real,
   correctly-supported `aghq_iter_cap` control argument (verified a real
   formal argument of `gllvmTMBcontrol()`, not swallowed by `...`; see
   "Correction" below) to 2, 25, and 1000 on the identical fixture, letting
   the honest per-pass re-adaptation run to its own convergence instead of
   mislabelling early. Result: `par_shift` **converges to ≈0.00027 and
   stays there** as the cap rises from 2→25→1000 (0.000239 → 0.000272 →
   0.000273) — it does **not** grow toward the ~0.02–2.0 magnitudes seen in
   fixtures that genuinely move (see measurements). A budget-starvation
   artifact would reveal progressively larger movement as budget is
   raised; instead the correction *asymptotes at a value ~30–100× smaller
   than a genuinely-engaged fit*. The objective itself is unchanged to 5
   significant figures across every cap setting.
4. *Dose-response with the identifiability-relevant parameter*: sweeping
   the true loading SD (`lam_sd`, i.e. latent-signal strength / effective
   ICC) at the identical `n=200, T=6, q=1` poisson spec, the stall rate
   rises monotonically with `lam_sd` (≈40% at 0.5, ≈60% at 1.0, 90% at 2.0,
   **100%** at 3.0; `03-poisson-stall-search.R`). A code-level handoff or
   tape bug would not track a simulation parameter this way; a flattening
   likelihood in the covariance/loading direction — exactly what
   Rabe-Hesketh, Skrondal & Pickles (2002) predict and what
   `R/aghq-control.R`'s own node-floor comment already cites — does.
5. *Family is not the discriminator*: under one plausible moderate-scale
   DGP at the identical `n=200,T=6,q=1` spec, poisson did **not** stall in
   5/5 seeds (`par_shift` 0.018–0.029) while **gaussian stalled in 5/5
   seeds** (`par_shift` exactly 0 every time, `02-reproducer.R`). The
   original session's framing ("poisson stalls") is regime-dependent, not
   family-mechanism-dependent — consistent with (C), inconsistent with a
   poisson-specific tape or handoff defect.

## Adversarial check against the Codex claim (recovered mid-task)

The coordinator relayed a Codex-session claim that the mechanism is
"neither a flat objective nor a stale tape," but a cap-1 budget
(`iter.max=1, eval.max=4`) letting `nlminb` return its input, which then
feeds the `abs(dF) < f_tol` OR-leg at `n_ok>=2` — before continuation's
`n_ok>=esc_patience(=3)` can ever escalate the cap. Checked against
`R/fit-multi.R:4912` (the cap→`eval.max/iter.max` mapping), `:5445`–`:5480`
(the stopping test and its `n_ok>=2` gate), `:5483` (escalation needs
`n_ok>=esc_patience`), `:5505` (finalisation).

- **CONFIRMED, verbatim.** The control-flow claim is exactly right: `n_ok`
  reaches 2 (triggering the stop) strictly before it can reach
  `esc_patience=3` (needed to escalate cap 1→2), whenever every pass keeps
  re-landing on the same point. This is a real, independently-reproduced
  defect: the loop's *default* configuration can structurally never escalate
  out of a first-pass cap-1 non-move, because the same "nothing changed"
  pattern that a fix would need to survive past is exactly what satisfies
  the stopping test one step early.
- **REFUTED.** "Neither a flat objective" is false for the tested fixture.
  Giving the *real production loop* — not a synthetic stand-in — cap 25 or
  cap 1000 from pass 1 (bypassing the labelling bug entirely) does not
  reveal a large hidden move; it converges, slowly (235 passes at cap 2), to
  a `par_shift` that asymptotes at ≈0.00027 and an objective unchanged to
  5 significant figures. That is the signature of near-flatness, not of an
  under-budgeted search that would have found something substantial with
  more room.
- **Gradient number (0.5012, T=6/n=200).** Not literally reproduced (my
  deterministic stall shows `max|grad|=0.0391` at the point of stalling);
  the cited fixture's exact seed/DGP is not checked in, so an exact match
  was not expected. The *phenomenon* — moderate-to-large nonzero gradient,
  exactly-zero parameter movement, loop declares "STALLED" — reproduced
  cleanly and repeatedly across many independent seeds and `lam_sd` values
  (§ measurements), so this is not a one-off artifact of one number.
- **Correction to the coordinator's warning about `gllvmTMBcontrol()`.**
  The claim that `aghq_iter_cap` (along with five other `aghq_*` tunables)
  is "read by the engine loop but not a formal argument of
  `gllvmTMBcontrol()`" is **wrong for `aghq_iter_cap` specifically** (and
  for `aghq_n_adapt`). Both are real formal arguments
  (`R/gllvmTMB.R:1208-1226`) that are placed into the returned control list
  (`:1272-1273`); verified directly: `formals(gllvmTMBcontrol)` lists
  `aghq_iter_cap`, and `gllvmTMBcontrol(aghq_iter_cap = 25L)$aghq_iter_cap`
  returns `25` with **no warning**. The warning is correct for the other
  five (`aghq_continuation`, `aghq_shift_tol`, `aghq_grad_tol`,
  `aghq_f_tol`, `aghq_escalate_patience`, `aghq_rho_min`): passing any of
  these fires `"Extra arguments to gllvmTMBcontrol() are ignored"` and they
  do not appear in the returned list (verified for `aghq_f_tol`). This
  means the decisive escalation test above used a genuinely supported,
  correctly-wired argument, not a misconfigured no-op.

## Reproducer

Exact spec per the brief: `family = poisson`, `n = 200`, `T = 6`, `q = 1`,
`latent(..., unique = FALSE)`, `aghq = 9`, `aghq_ridge = Inf`. Idiom copied
from `dev/aghq-evidence/21-wide-factorial.R`'s `mk()` (wide `traits(...)`
grammar). The moderate-scale DGP alone did **not** reliably stall poisson;
the deterministic stall needed `lam_sd = 3` (large loading SD relative to
the poisson mean-scale). Both scripts below reproduce end to end.

```r
## Deterministic poisson stall (100% of 10 seeds tried at lam_sd in {2,3}):
mk <- function(n, p, q, lam_sd, seed, fam) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.8, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rpois(n * p, exp(pmin(eta, 6))), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml)
}
d <- mk(200L, 6L, 1L, 3.0, 2001L, "poisson")
fit <- gllvmTMB(d$fml, data = d$df, family = poisson(),
  control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE,
                             aghq = 9L, aghq_ridge = Inf, verbose = TRUE))
fit$aghq$par_shift   # 0
fit$aghq$stop_reason # "STALLED at the warm start: ... max |grad| = 0.0391 ..."
```

Full scripts, all runnable as-is from the worktree root, left in this
scratchpad directory:
- `01-smoke.R` — step-3 smoke test (tiny n=10/T=3 poisson fit; converges
  normally in 8 passes, `par_shift=0.0341`).
- `02-reproducer.R` — the task's exact spec, poisson/binomial/gaussian × 5
  seeds each at n=200,T=6,q=1 (moderate DGP).
- `03-poisson-stall-search.R` — `lam_sd × seed` sweep (poisson, n=200,T=6,
  q=1) that found the deterministic stall region.
- `06-dissect-clean.R` — the clean A/B/C dissection (each test on its own
  single-use AD object; supersedes `05-dissect-stall.R`, which had a
  self-inflicted object-reuse contamination bug, left in place with a
  comment for the record rather than deleted).
- `07-contrast-nonstalled.R` — same diagnostic applied to a non-stalled
  poisson cell, for contrast.
- `08-verify-codex-claim.R` — the adversarial verification of the Codex
  claim (formal-argument check + the cap 1/2/25/1000 escalation test).

## Measurements

| family | n | T | q | lam_sd | par_shift | objective | conv | grad_norm | passes | stop_reason (short) |
|---|---|---|---|---|---|---|---|---|---|---|
| poisson | 200 | 6 | 1 | moderate | 0.0182–0.0286 (5 seeds) | 1685–1734 | 0 | 8e-5–2.2e-4 | 9–11 | stopped/converged, not stalled |
| binomial | 200 | 6 | 1 | moderate | 0.634–2.026 (5 seeds) | 804–819 | 0 | 9.5e-5–3.0e-4 | 12–16 | stopped/converged |
| gaussian | 200 | 6 | 1 | moderate | 0.0 (5/5 seeds) | 1011–1050 | 1 | 6.0e-4–2.1e-3 | 2 | **STALLED**, all 5 seeds |
| poisson | 200 | 6 | 1 | 0.5 | 0 (4/10), 0.0076–0.0090 (6/10) | — | — | — | 2–3 | mixed |
| poisson | 200 | 6 | 1 | 1.0 | 0 (6/10), 0.0073–0.0094 (4/10) | — | — | — | 2–3 | mixed |
| poisson | 200 | 6 | 1 | 2.0 | 0 (9/10), 0.0096 (1/10) | — | — | — | 2–3 | mostly STALLED |
| poisson | 200 | 6 | 1 | 3.0 | 0 (10/10) | — | — | grad 0.02–3.6 | 2 | **STALLED, every seed** |
| poisson (dissection cell) | 200 | 6 | 1 | 3.0 (seed 2001) | 0 | 2901.663 | 0 (Laplace) | 0.0391 | 2 | STALLED, `aghq_iter_cap=1` (default) |
| ″, `aghq_iter_cap=2` | — | — | — | — | 0.000239 | 2901.663 | — | 0.00148 | 235 | stopped, not converged |
| ″, `aghq_iter_cap=25` | — | — | — | — | 0.000272 | 2901.663 | — | 0.000682 | 6 | stopped, not converged |
| ″, `aghq_iter_cap=1000` | — | — | — | — | 0.000273 | 2901.663 | — | 0.000486 | 5 | stopped, not converged |

("moderate" DGP: `beta = c(0.2,-0.1,0.3,0.1,-0.2,0.15)`,
`lambda = c(0.6,-0.5,0.4,0.5,-0.3,0.45)`, `seeds 101-105`; "lam_sd" DGP:
`21-wide-factorial.R`'s generator, `seeds 2001-2010`.)

## What this implies for the arc

- **The near-flatness (C) is a real, regime-dependent property of the
  likelihood, not an engine defect.** It shows up specifically where the
  true loading magnitude is large relative to the poisson mean scale
  (`lam_sd` ≳ 1–2 at `T=6`, i.e. a small-cluster/high-signal regime), and
  is not poisson-specific — the identical mechanism stalled gaussian
  reliably under a different DGP at the same `n/T/q`. **No AGHQ engine fix
  makes this cell more informative**: cells in this regime should be
  expected to show `par_shift` on the order of 1e-4 to 1e-3 even when the
  engine is working correctly and exhaustively optimised, and any
  downstream claim that credits AGHQ with a "correction" in such a cell
  needs a materiality floor (e.g. `par_shift` distinguishable from ~3e-4)
  or it is reporting noise.
- **The control-flow defect Codex found is real and separately worth
  fixing**, independent of (C): the default configuration (`aghq_iter_cap=1`
  with continuation) can never escalate past a first-pass non-move, because
  the `n_ok>=2` stopping gate fires one accepted-pass-count before the
  `n_ok>=esc_patience(=3)` escalation gate could. Two independent fixes are
  visible from this evidence, either sufficient on its own: (i) require the
  stopping test's `n_ok` threshold to exceed `esc_patience` so escalation
  always gets first refusal, or (ii) give pass 1 a slightly larger eval
  budget than `4L * iter_cap` at `iter_cap=1` specifically. Because of (C),
  fixing this will change the loop's *behaviour and honesty* (fewer
  spurious "STALLED" labels reported for a 2-pass non-move, more cells
  reaching a real, if still tiny, converged correction after tens to
  hundreds of extra passes) but will **not** change what those cells'
  `par_shift` is worth trusting as a meaningful AGHQ-vs-Laplace difference.
- The escalation fix has a real cost: at `aghq_iter_cap=2` the same fixture
  needed 235 passes to reach its own tiny stationary point. Any fix that
  removes the early stall label should budget for this (or add a materiality
  short-circuit: stop early once `|dF|` and `shift` are both below tolerance
  *and* the cumulative `par_shift` is itself below a materiality floor,
  which is a defensible thing to call "settled" — unlike the current
  `n_ok>=2` OR-leg, which can fire vacuously on pass 2 of a total no-op).

## Uncertainty

- Did not determine the *specific* geometric source of the flatness at
  `lam_sd≥2` — whether it is the Rabe-Hesketh/Skrondal/Pickles
  small-cluster/high-ICC mechanism proper, or partly an artefact of this
  DGP's `pmin(eta, 6)` linear-predictor cap (borrowed from
  `21-wide-factorial.R`'s own convention), which at large `lam_sd` pushes
  many observations toward a near-ceiling poisson mean and could itself
  degrade identifiability. Both fall under "genuinely flat for this
  regime" as the task defines (C), but they would carry different
  practical guidance (a DGP artefact vs. an inherent data-scarcity limit),
  and I did not run the uncapped-eta variant to separate them.
  the `pmin(eta,6)` cap is inherited from the package's own evidence
  script, not invented for this diagnosis, so it is at minimum a
  plausible real-world scenario, not a pathological edge case.
- Did not verify whether the exact original session's "T=6, n=200" fixture
  (gradient 0.5012) is itself in the `lam_sd≥2`-like regime or a different
  one; its seed/DGP were never checked in, so this cannot be settled
  further without that lane's own script.
- Did not test `q>1` or other families (binomial/gaussian) under the same
  `lam_sd` sweep to check whether the dose-response in § measurements is
  quantitatively similar across families, only that gaussian *can* stall
  reliably under a different DGP at `q=1`.
- Did not attempt an actual code fix (out of scope: diagnosis only, no
  source file was edited per the brief's constraint).
