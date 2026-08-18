# Attribution of `binomial_prevalence_loading`'s 25% false-positive rate (issue #1098)

Analysis of two existing CSVs, no new fitting. Reproducible via
`OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/heywood/fp-attribution.R`
(pool 2's path is outside the repo per D-50; override with the `POOL2_CSV`
env var if it moves).

## The shipped rule (confirmed by reading `R/diagnose.R:485-590`)

```
extreme_prevalence = prevalence >= 0.9 | prevalence <= 0.1      (prevalence_thresh)
dominant_loading   = relative_loading >= 8                       (loading_relative_thresh)
saturated_fit      = saturation_share >= 0.5                     (saturation_share_thresh)
runaway_loading    = relative_loading >= 25                      (loading_runaway_thresh)
extreme_magnitude  = max_loading_unit >= 6                       (loading_absolute_thresh)

flag = (extreme_prevalence & (dominant_loading | saturated_fit))
       | runaway_loading
       | extreme_magnitude
```

The prompt's paraphrase is exact; no threshold or disjunction differs from
the source.

## Fidelity check (mandatory, done first)

`extreme_magnitude` is defined on `max_loading_unit` (unit tiers only,
`R/diagnose.R:384-421`), not the pooled `max_loading` both CSVs record.
Read each generator directly:

- `dev/heywood/fp-sweep.R` (pool 1): single formula term
  `latent(0 + trait | site, d = q, unique = FALSE)`.
- `dev/design108-stage8/laplace-silent-divergence.R` (pool 2): single
  formula term `latent(0 + trait | site, d = q, unique = FALSE)`.

Neither grid ever fits a structured/SPDE/phylo/kernel tier. With only a
unit-level latent term present, the pooled `max_loading` and
`max_loading_unit` are identical by construction, so `max_loading` in both
CSVs is a **valid, exact** proxy for `max_loading_unit` — not an
approximation, and no rows need to be excluded or flagged.

This was verified empirically as well: reconstructing `runaway_loading |
extreme_magnitude` from pool 2's raw columns and comparing against the real
`check_status` recorded by an actual `check_gllvmTMB()` call
(`laplace-silent-divergence.R:257-261`) gives **0 mismatches across all
1,200 binomial_probit fits**. This is exact **up to co-firing, not exact
in the strong sense of directly observing every arm**: pool 2 does not
record prevalence, so `extreme_prevalence` cannot be checked directly, only
inferred by subtraction (any WARN unexplained by `runaway_loading` or
`extreme_magnitude` must be the prevalence branch — and none is; see
below). This inference is safe here for a DGP-level reason, not merely an
absence of counterexamples: the DGP's intercept is `B ~ N(0, 0.3)`, and for
a probit fit with latent contribution `Lambda . Z`, the marginal prevalence
for a trait with realized loading vector `Lam` is `Phi(B / sqrt(1 +
||Lam||^2))`. At `sigma_lambda = 3`, `q = 2`, `E[||Lam||^2] = 18`, so the
argument's scale is `sqrt(19) ~ 4.36`; a Monte Carlo over the DGP's own
`(B, Lam)` distribution (200,000 draws, matching `sigma_lambda = 3`,
`q = 2`) gives prevalence mean 0.5000, SD 0.044, range `[0.14, 0.85]` —
`P(prevalence >= 0.9 or <= 0.1)` was 0 in that simulation. This is *why*
the subtraction inference is practically safe, not merely observed to hold
in this one pool: `extreme_prevalence` (the 0.9/0.1 gate) is essentially
unreachable under this DGP's own probability model, so co-firing with it
is not a live confound. That match also confirms, as a side effect, that
the prevalence-gated branch never independently contributes a WARN in
pool 2 (see below).

**Caveat on pool 1's own `row_status_now` column**: it is NOT used as
ground truth. It reads "PASS" or `NA` for every one of 3,944 usable
binomial rows, including rows with `rl_max` in the thousands — impossible
under the current full rule. This is consistent with `row_status_now`
having been captured *before* `runaway_loading` / `extreme_magnitude`
existed (this sweep's own header frames the question as "if a runaway
loading is allowed to flag on its own" — i.e. this sweep is itself the
calibration evidence that later produced those two arms). Pool 1 is
therefore analysed by reconstructing the **current** full rule from its raw
columns (`rl_argmax_extreme_prev`, `rl_max`, `rl_argmax_saturation`,
`max_loading`), extending `fp-analyse.R`'s own `old_flag()` reconstruction
of the prevalence branch with the two later arms at shipped thresholds.

## Pool 1 — the heywood sweep (`dev/heywood/fp-sweep-full.csv`)

7,200 rows total; 4,320 binomial; 3,944 usable (no fit error, `rl_max`
present).

**Surprise flagged per instructions, not silently absorbed**:
`extreme_prevalence` fires on **0/3,944** rows. `rl_argmax_prev` ranges
0.200–0.807 — never within [0, 0.1] or [0.9, 1]. This is a DGP property,
not a harness bug: the intercept is `B ~ N(0, 0.3)` on the logit scale by
design, and the sweep's own stated purpose (its header comment) is to
isolate the loading-only arms from the prevalence gate. **The
prevalence-gated branch is structurally untestable in pool 1** — nothing
below should be read as "the prevalence branch doesn't cause FPs," only
"this pool cannot speak to it."

Using `fp-analyse.R`'s own classification (healthy `rel_frob<=0.5`,
degenerate `>=5`, middle band unused):

| | n | WARN | FPR/TPR |
|---|---|---|---|
| healthy | 551 | 0 | 0.0000 |
| degenerate | 1,465 | 1,425 | 0.9727 |

**Zero false positives.** Arm breakdown on degenerate: runaway-only 0,
magnitude-only 14, both 1,411, missed 40 — `extreme_magnitude` is a
superset of `runaway_loading` here (fires whenever runaway fires, plus 14
more).

Using pool 2's native cutoff (`rel_frob<=10` healthy) for a like-for-like
comparison: healthy n=2,499, WARN=1 (FPR 0.0004); degenerate n=1,445,
flagged 1,424 (TPR 0.9855). Still effectively zero FPs.

## Pool 2 — design108 stage8 grid (issue #897's own pool)

1,200 binomial_probit fits, all status OK.

**Reproduction of #897's 232/928 = 25%**: confirmed exactly.
`rel_frob <= 10` (the convention this generator's own header already uses
for `silent_divergent`, matching `dev/degeneracy/DETECTOR.md`) selects
**n = 928**, of which **WARN = 232**, FPR = **0.2500** — an exact match,
integer-for-integer.

Attribution within the 928 (subtraction method — `runaway_loading` and
`extreme_magnitude` are exactly computable from `rl_max`/`max_loading`;
anything left over is attributed to the prevalence branch, which is exact
up to co-firing since prevalence itself is unrecorded here — see the
Fidelity check section above for why that inference is safe on this DGP):

| | fires | fires ONLY | 
|---|---|---|
| runaway_loading | 0 | 0 |
| extreme_magnitude | 232 | 232 |
| prevalence-branch | 0 (by construction: WARN − runaway − magnitude = 0) | 0 |

**`extreme_magnitude` alone accounts for all 232 false positives.**
`runaway_loading` fires on zero of the 928 healthy fits (it does fire
elsewhere — 162 times across the full 1,200-row pool, entirely within the
272 degenerate fits). No prevalence-branch contribution, for the same
reason as pool 1: `B ~ N(0, 0.3)` on the probit scale keeps prevalence away
from the 0.9/0.1 gate.

**Mechanism, by `sigma_lambda` (the DGP's true loading SD)**:

| sigma_lambda | n | WARN | FPR |
|---|---|---|---|
| 0.7 (mild) | 494 | 19 | 0.0385 |
| 3.0 (#847's ridge-failure regime) | 434 | 213 | 0.4908 |

| arm | n | WARN | FPR |
|---|---|---|---|
| default | 328 | 151 | 0.4604 |
| ridge2 (`aghq_ridge=2`) | 600 | 81 | 0.1350 |

`extreme_magnitude` is judged on an **absolute** link-scale value
(`max_loading_unit >= 6`), with no reference to the DGP's true loading
scale. At `sigma_lambda = 3`, the true loadings are genuinely large. This
is regime/effect-size dependence, not a units problem in the #851/#855
sense: the probit link fixes the residual (liability) scale at exactly 1
by construction, so there is no free response scale for latent
standardisation to push into Lambda here — see
`dev/heywood/fp-scale-dependence.md` for the corrected mechanism note (an
earlier draft mis-filed this under the #851/#855 units-dependence class;
that framing does not hold for a fixed-residual-variance link). The
`aghq_ridge=2` remedy cuts the FPR roughly 3.4x (0.46 -> 0.135) but does
not eliminate it.

**Ruling out the obvious alternative: is "healthy" itself the
scale-dependent thing, not the detector?** `rel_frob <= 10` is a
*relative* recovery-error bound, and `||Sigma_true||_F` itself grows
roughly `sigma_lambda^2`-fold (~9x) from `sigma_lambda = 0.7` to `3.0`. A
competing explanation for the whole finding above is that the SAME
relative bound admits absolutely larger reconstruction error at large
scale, so the population being labelled "healthy" is itself less
accurately recovered there — making the false-positive story an artefact
of a scale-dependent LABEL rather than evidence about the detector. This
is checked directly, not merely asserted away: re-running the identical
attribution under `rel_frob <= 0.5` — a band ten times tighter, chosen
specifically to defuse this alternative — gives **n=422, WARN=91,
FPR=0.2156**, essentially unchanged from the native-cutoff figure of
0.2500. Tightening the health boundary by an order of magnitude does not
make the false positives disappear, so the finding is not an artefact of
where `rel_frob`'s cutoff is drawn.

## Do the two pools agree?

**No — they disagree sharply, and the disagreement itself is the finding.**
Both pools identify the same *arm* as responsible wherever it fires at all
(`extreme_magnitude`, never `runaway_loading` or the prevalence branch, in
the healthy population of either pool). But the **rate** differs by two
orders of magnitude: pool 1 has essentially 0% FPR (0/551 or 1/2,499
depending on cutoff) versus pool 2's 25%. These are different DGPs and the
difference is explainable, not paradoxical: pool 1's loading SD is fixed at
0.7 (`homog`) or a two-group sparse mix (`sparse50`/`75`, max SD 1.0) —
never large. Pool 2 deliberately crosses `sigma_lambda in {0.7, 3.0}` to
reach `#847`'s already-documented ridge-failure regime, and essentially all
of the FP mass sits in the `sigma_lambda=3.0` cells (49% FPR there vs 3.9%
at `sigma_lambda=0.7`, matching pool 1's near-zero result at
its own mild loading scale). **Do not transport pool 1's "0% FPR" headline
without qualification: it was measured at a loading scale roughly a third
to a seventh of the value now known to break the absolute-magnitude arm.**

## What this implies for a fix

**Target `extreme_magnitude` (`loading_absolute_thresh`)** — it is the
sole driver of every false positive found in either pool. The mechanism
is a fixed absolute constant standing in for a hidden prior on plausible
latent effect size, blind to the DGP's true loading scale — regime/
effect-size dependence, not the response-scale/units-dependence this
repo's #851/#855 scale-dependent-constants class otherwise describes (see
`dev/heywood/fp-scale-dependence.md` for why that class's usual device
does not transfer to a fixed-residual-variance link like probit).
`runaway_loading` and the prevalence branch contribute nothing to
the FP rate in either pool (though pool 1 cannot test the prevalence
branch at all, and pool 2's degenerate subset shows `runaway_loading` does
carry real signal there — 162/272 = 59.6% of pool 2's degenerate fits fire
it — so it should not be removed, only left alone).

Sensitivity trade-off, sweeping `loading_absolute_thresh` on pool 2 (the
pool with a non-trivial FP rate to trade against), holding
`runaway_loading` fixed at 25:

| tau | FPR (healthy, n=928) | TPR (degenerate, n=272) |
|---|---|---|
| 6 (shipped) | 0.2500 | 1.0000 |
| 8 | 0.1552 | 0.9963 |
| 10 | 0.1175 | 0.9706 |
| 15 | 0.0905 | 0.9118 |
| 20 | 0.0636 | 0.9007 |
| 25 | 0.0366 | 0.8934 |
| 30 | 0.0226 | 0.8860 |
| 40 | 0.0022 | 0.8419 |
| 50 | 0.0000 | 0.7904 |
| 100 | 0.0000 | 0.6654 |

There is no threshold that is free — every reduction in FPR trades away
detection on the degenerate pool: `tau=25` (matching the existing
`runaway_loading` value, so the two arms would fire at the same level)
still leaves FPR at 3.66% but TPR falls to 89.34%; `tau=50` reaches 0% FPR
at the cost of dropping TPR to 79.04%, i.e. 1 in 5 genuinely degenerate
fits would go unflagged. Pool 1's own healthy population tolerates any of
these tau values trivially (FPR stays <=0.04% throughout, since its true
loading scale never approached the failure regime) — pool 1 offers no
useful constraint on where to set tau, only pool 2 does.

**A single fixed constant cannot be made regime-free by re-tuning alone**
— this sweep only trades one point on one ROC curve for another; it does
not touch the underlying mechanism (a fixed prior on plausible latent
effect size, applied to a regime that is not itself fixed across DGPs). A
structural fix is harder here than the usual #851/#855 device: this is
effect-size dependence on a link (probit) whose residual scale is already
fixed by construction, not response-scale dependence, so the class's
per-fit rescaling (`tau -> tau * sd(y_t)`) has no Bernoulli analogue, and
judging the loading against a quantile of the fit's own distribution
collapses into the existing `loading_relative_thresh` ratio arm. See
`dev/heywood/fp-scale-dependence.md`'s "What would actually fix it"
section — this analysis establishes which arm to target and what a pure
threshold move costs; it does not establish that a structural fix of the
usual kind is even available for this arm.

## Why: an oracle exceedance calculation, not just a correlation

The `sigma_lambda` mechanism table above shows a correlation (FPR rises
with true loading SD); `dev/heywood/fp-scale-dependence.md` derives an
independent, falsifiable prediction for it and checks it against
measurement. Summary (full derivation and the `pnorm()`-based computation
there): pool 2 draws `Lambda_true` entrywise `N(0, sigma_lambda^2)` over a
`p*q`-entry matrix (`q=2`; `p in {12,27}`, so 24 or 54 iid entries), so an
**oracle** using the true (not fitted) loadings has exceedance probability
`1 - [2*Phi(c/sigma_lambda) - 1]^(p*q)` at threshold `c`. At
`sigma_lambda = 3`: `P(max|Lambda_true| >= 6)` is **0.6729 (p=12) to 0.9191
(p=27)**, falling to **0.1685 to 0.3398** at threshold 8. This matches the
measured FPR at threshold 8 closely (0.2420 vs oracle 0.1685 at `p=12`;
0.3321 vs oracle 0.3398 at `p=27`) and over-predicts at threshold 6, which
is expected — the oracle is unconditional on recovery quality while the
measured FPR conditions on `rel_frob<=10`, and fitted loadings are not
identical to their true values. The point is not decimal-place agreement;
it is that a mechanism derived independently of the measured data predicts
the same order of magnitude and the same qualitative shape (steep rise
with `sigma_lambda` and `p`; roughly halves from threshold 6 to 8) that
was actually measured.

## An unmeasured caveat: probit-only evidence

`extreme_magnitude` is gated on `family_id == 1L` (binomial) for every
link, but both calibration pools here fit **probit exclusively**. Logit
loadings run larger than probit loadings for the same underlying model
(the standard logistic/probit variance-matching ratio, commonly cited as
`~1.6-1.8`) — so a fixed threshold is reached by a *smaller* true effect
size on the logit link than on probit, meaning **the FPR measured here
should be read as a lower bound for logit fits**, not a transportable
number. No logit evidence exists in either pool; see the roxygen caveat
added alongside this retune.

## Is "false positive" the right frame? (checking DIA-08's own framing)

`docs/design/35-validation-debt-register.md`'s DIA-08 row treats this
screen as an **inference/identifiability warning**, not a point-estimate
correctness check. At `sigma_lambda = 3`, `q = 2`, a trait's true
per-entry latent contribution has SD `sqrt(q) * sigma_lambda ~ 4.24` on
the probit scale — deep into quasi-separation territory, where a WARN
could be *correct* behaviour (flagging a genuinely fragile fit) even when
the point estimate (`Sigma`) happens to recover well by the `rel_frob`
metric. Pool 2 records `convergence` and `pdHess` (it does **not** record
standard errors — no SE/`se` column exists in this CSV, so that half of
the check cannot be answered here). Reporting what is available, for the
232 flagged healthy fits versus the 696 passed healthy fits:

| | n | convergence==0 | pdHess==TRUE | both |
|---|---|---|---|---|
| flagged (WARN) | 232 | 229 (98.71%) | 227 (97.84%) | 224 (96.55%) |
| passed (PASS) | 696 | 692 (99.43%) | 609 (87.50%) | 605 (86.93%) |

This does **not** resolve the question either way. Both groups report
clean optimizer signals in the large majority of cases — if anything, the
flagged group has a *higher* rate of positive-definite Hessians than the
passed group, the opposite of what "flagged fits are more broken" would
predict. That is not surprising: quasi-separation is exactly the regime
where an optimizer converges cleanly and reports a PD Hessian while the
information matrix is nonetheless poorly conditioned in a direction
`convergence`/`pdHess` cannot see — which is precisely why `rel_frob`
(point-estimate recovery) and an SE-based identifiability check are
different questions, and why this pool's absence of an SE column leaves
the DIA-08 framing question genuinely open rather than settled by this
check. Resolving it would need refitting a sample of the 232 flagged
fits with SE computation and checking calibration — not attempted here.
