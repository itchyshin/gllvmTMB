# VA-warm-started Laplace ("superfast LA") — measured, adjudicated, closed

**THE ANSWER.** Yes: seeding the shipped Laplace engine's `b_fix` and `theta_rr_B`
from a VA fit (via the existing, tested `vgh_warm_start` hook, with `z_B` left
unseeded and no log-scale variance coordinate to reset in this cell) reaches the
identical cold-Laplace optimum in 3 of 3 seeds, so it is not the AC→GH collapse
bug recurring. Including the cost of the VA fit itself, the hybrid is only a
median **1.09× faster** than cold Laplace (range 1.04–1.10×, 3 seeds) — far below
the maintainer's optimistic ~3× Amdahl ceiling — because most of cold LA's wall
time is not concentrated in reaching good `b_fix`/loadings starting values. This
is a real but modest win on one local-desktop regime, not "superfast LA," and it
is not something to ship as-is: it currently only exists as a script-only
monkeypatch of an internal, non-exported function.

## Regime

N=250, T=20, q=2, `family = binomial(link = "probit")`, model
`cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = q, unique = FALSE)`
(loadings-only tier — no diagonal Ψ, no dispersion parameter). 3 seeds, paired,
interleaved, order-rotated across VA/LA/Hybrid, with an untimed warm-up run first
(TMB template compilation is otherwise counted inside the first timed arm). Local
Mac desktop, ambient load median 10.6 (spread 1.3) during the timed loop. VA arm:
`gllvmTMB:::.va_r3_fit(eval_method = "ac", collapse_variational_cov = TRUE, H =
15, n_starts = 1)`. This is a 3-seed, single-machine, single-cell measurement —
only the *ratios* should be read as evidence across machines, and even the
ratios carry real seed-to-seed spread (see below).

Script: `dev/va-speed/33-va-warmstart-la.R`. Raw result:
`dev/va-speed/33-va-warmstart-la-result.rds`. Recon consumed:
`docs/design/va-warmstart-la-recon.md`. Nothing here is committed (per D-50 and
this task's instructions).

## The numbers

Per-arm, per-seed (secs = wall time; Hybrid secs **includes** the VA fit;
`rf` = `rel_frob(Sigma_hat, Sigma_true)`; `trace_hat` = tr(Σ̂); `obj` = minimized
objective — NOT comparable in scale between VA's negative-ELBO and LA/Hybrid's
negative log-lik):

| seed | arm    | secs  | rf      | trace_hat | obj       | landed |
|------|--------|-------|---------|-----------|-----------|--------|
| 1    | VA     | 4.16  | 0.24939 | 15.2833   | 7697.875  | NA     |
| 1    | LA     | 23.59 | 0.11177 | 18.4499   | 7471.453  | NA     |
| 1    | Hybrid | 22.23 | 0.11178 | 18.4497   | 7471.453  | TRUE   |
| 2    | VA     | 3.53  | 0.18620 | 25.1093   | 7216.185  | NA     |
| 2    | LA     | 23.89 | 0.17659 | 30.1135   | 6945.222  | NA     |
| 2    | Hybrid | 21.71 | 0.17660 | 30.1133   | 6945.222  | TRUE   |
| 3    | VA     | 4.10  | 0.12870 | 16.4210   | 7601.090  | NA     |
| 3    | LA     | 20.78 | 0.13803 | 18.4774   | 7392.537  | NA     |
| 3    | Hybrid | 19.98 | 0.13802 | 18.4773   | 7392.537  | TRUE   |

Medians: VA 4.10 s (rf 0.1862) | cold LA 23.59 s (rf 0.1380) | Hybrid 21.71 s
(rf 0.1380). VA/LA reproduces the earlier committed measurement almost exactly
(commit `f3df8193`: VA 4.10 s / rf 0.1862, LA 23.93 s / rf 0.1380) — cross-checks
the harness.

**Planted variance, corrected.** The DGP plants a real Σ_true = ΛΛᵀ. The
script's own summary printed a single number, `sum(diag(mk(1L, N0)$Sigma_true))
= 19.2993`, and the first draft of this deliverable wrongly generalized it as
"across seeds." **That is wrong and is corrected here**: because `seed` reseeds
the loadings draw itself (not just the scores), Σ_true's trace genuinely differs
by seed — **19.30 / 28.26 / 17.19** for seeds 1/2/3 (independently recomputed
from the DGP code, and confirmed by two independent adversarial reviewers). The
per-seed `rel_frob` scoring inside the actual loop is unaffected (it closes over
each seed's own `Sigma_true`), so the accuracy/no-collapse conclusions below are
sound — but any reader comparing a `trace_hat` to "19.30" for seeds 2 or 3 was
being misled. Read against the correct per-seed truth, LA's `trace_hat` (18.45,
30.11, 18.48) and Hybrid's (18.45, 30.11, 18.48) each track their own seed's
truth (19.30, 28.26, 17.19) to within roughly 5–13%, both markedly closer than
VA's `trace_hat` (15.28, 25.11, 16.42), consistent with the already-established
"LA ~26% more accurate than VA" finding.

**Hybrid vs cold LA**, per seed: seed 1 23.59/22.23 = 1.06×, seed 2
23.89/21.71 = 1.10×, seed 3 20.78/19.98 = 1.04×. Median ratio 23.593/21.709 =
**1.09×**.

**Where the saving comes from.** Subtracting each seed's *own standalone* VA
time from that seed's Hybrid time gives an estimated "LA-only portion" of
~16–18 s against cold LA's ~21–24 s, i.e. roughly a 23–24% reduction in the
Laplace-specific wall time from warm-starting `b_fix` + `theta_rr_B` and skipping
`z_B`. **This is flagged, not asserted as precise**: it substitutes the
standalone VA arm's wall time (measured at a different point in the rotation,
under a slightly different ambient load) for the VA cost actually embedded
inside the Hybrid run, which was never independently instrumented. Two
adversarial reviewers caught this and it is corrected here — treat "~23–24%"
as an estimate, not a directly measured quantity. Whatever its exact size, that
saving is largely eaten by the ~4 s VA fit added back into the total, leaving
the modest ~1.09× net figure above. This is in the same direction as, and
smaller in magnitude than, the package's own VGH-precedent finding
(`R/fit-multi.R`, lines ~4265–4268) that a loadings-only warm start "buys
Laplace only 5–14% fewer outer iterations" for a *different* engine (VGH) —
correcting a citation slip in an earlier draft, which had misattributed that
quote to the neighbouring `z_B`-harmful-when-seeded lines (~4279–4284).

## Same optimum?

**Yes, in 3/3 seeds, unambiguously**, and this holds up under three independent
adversarial re-runs (two of which independently re-executed the script on the
live repo and reproduced the timing pattern and the exact per-seed numbers to
4–5 significant figures). Per-seed `delta_obj` (Hybrid − cold LA) was
0.0000/0.0000/0.0000 and `delta_rf` was +0.00001/+0.00000/−0.00002 — both far
inside the script's own 1e-2 (obj) / 5e-3 (rf) thresholds, and far tighter than
the AC→GH scar tissue's own failure scale (19–52 nats apart). No collapse and no
different-optimum bug of the AC→GH kind occurred here.

## Was the boundary-reset lesson needed here?

**No — this exact matched cell is structurally immune to it, and that immunity
is a scope limit, not a general clearance.** `unique = FALSE` means there is no
diagonal Ψ tier (`theta_diag_B`) in play; `names(fva$best$par)` confirmed no
`log_sd_tier` entry exists for this cell, and the script printed a no-op
"nothing to reset" message before every run. There was therefore no log-scale
variance coordinate for the AC→GH-style attracting-boundary failure to attach
to. **This does not clear the general hybrid technique** — if the maintainer
extends this to a `unique = TRUE` model, `theta_diag_B` becomes live and the
reset-only-the-variance-tier discipline from the earlier scar tissue would need
to actually fire and be re-verified there. It has not been.

## Defects found by adversarial review, and their disposition

Three independent adversarial passes (one re-derivation-only, two re-execution
on the live repo) returned **QUALIFIED** in all three cases — no FATAL defect
survived, and none of the primary conclusions (same optimum in 3/3 seeds, ~1.09×
net speedup, VA ~5.8× faster but ~26% less accurate, no collapse) were
overturned or withdrawn.

- **SERIOUS (confirmed by 2 of 3 reviewers, fixed in this document):** the
  "Sigma_true trace = 19.2993 across seeds" line was a single-seed number
  (`mk(1L, N0)`) wrongly generalized to all three seeds, which actually differ
  by ~46% (19.30/28.26/17.19). Corrected above. This did **not** affect the
  underlying `rel_frob`/no-collapse conclusions, which use each seed's own true
  Σ correctly inside the loop — only the narrative gloss around `trace_hat` was
  wrong.
- **MINOR (confirmed, fixed in this document):** the "~23–24% LA-only portion"
  figure is an estimate built by subtracting a *different run's* standalone VA
  time, not a directly instrumented measurement of the VA cost embedded inside
  Hybrid. Now flagged as such above rather than stated with unwarranted
  precision.
- **MINOR (confirmed, fixed in this document):** a citation slip attributed the
  VGH "5–14% fewer outer iterations" quote to the wrong line range
  (`R/fit-multi.R:4279-4284`, which actually holds the *z_B*-harmful finding);
  the quote is at ~4265–4268. Corrected above.
- **MINOR (noted, not fixed — inherent to the shipped engine, out of this
  task's scope):** the shipped `vgh_warm_start` hook's own "did it land"
  assertion (`R/fit-multi.R:4307-4312`) only checks `theta_rr_B` against the
  value it was just assigned from (a near-tautological check), and has no
  equivalent assertion for `b_fix` at all. Independent length checks
  (`length(beta) == length(b_fix) == 20` for this cell) corroborate that
  `b_fix` did land, but the harness's own `landed = TRUE` column is weaker
  evidence than it looks. This is pre-existing package code this task did not
  introduce or need to fix; flagged for anyone building a real
  `control$va_warm_start=` feature on top of this hook later.
- **MINOR (noted, scope-limited, not a defect in the measurement itself):** the
  same-optimum demonstration necessarily runs in the one cell that is
  structurally immune to the exact collapse mechanism it is checked against
  (see boundary-reset section above). Disclosed, not hidden, but worth
  repeating here so the top-line claim is not over-read as general.

## Second question: LA point estimate + VA standard error

**As posed, this is unsound and should not be built.** A standard error
describes the sampling variability of the *specific estimator being reported*.
The Laplace and VA point estimates are different random variables with
different bias and finite-sample behaviour — that is exactly what this
document's own numbers demonstrate (VA's own accuracy, rf ≈ 0.19 median, is
worse than LA's, rf ≈ 0.14 median, at this regime). Pairing an LA centre with a
VA-derived width produces an interval governed by neither estimator's actual
sampling distribution: it is not "LA's uncertainty measured cheaply," it is a
number with no clean interpretation. This matches the package's own existing,
shipped design decision (Design 85 §10, `R/va-methods.R`) that VA's
inverse-Hessian is not calibrated frequentist uncertainty, and that
`vcov`/`confint`/`logLik` intentionally error on VA fits rather than silently
return something that would look comparable to Laplace's numbers but is not.
This deliverable deliberately did **not** build the unsound version.

**The sound cousin, left undone, correctly.** The checkable question is
whether VA machinery can cheaply *approximate Laplace's own* standard errors —
same target (LA's `sdreport()`-based SEs), cheaper route — rather than
substituting a different estimator's uncertainty. That is a real derivation
exercise (deriving and validating a VA-based approximation to LA's own
information matrix, then comparing the ratio to real `sdreport()` output
honestly), not something reachable inside this task's local, small-fit budget.
It was left undone rather than faked, and is a candidate for a future,
separately scoped task.

## Bottom line

Nothing here is promoted. `default_tier` stays `"gh"`; the script, RDS, and this
document are local per D-50 and were not committed. The insertion point used is
a script-only runtime monkeypatch of the internal `.vgh_build_warm_start()` (via
namespace unlock/assign/restore, `on.exit`-guarded) — not a package change, and
not something to ship without a real `control$va_warm_start=`-shaped feature
mirroring `vgh_warm_start`'s existing, tested shape.
