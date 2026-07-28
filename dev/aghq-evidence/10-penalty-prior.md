# Slice B — does a penalty / MAP prior on the loadings fix the small-*n* AGHQ bias?

Script: `dev/aghq-evidence/10-penalty-prior.R`. Uses the frozen, unedited
`dev/aghq-r-reference.R` fitter (Laplace = its own `k=1`; AGHQ = `k=9`). DGP matches the
headline table exactly: `T = 4` traits, `q = 1`, `lam_sd = 1.2`,
`Lt <- matrix(rnorm(p*q,0,lam_sd),p,q)`, `b <- rnorm(p,0.3,0.4)`, binomial-logit.

## The claim under test

A cross-repo brain note records a penalty/MAP prior on variance components as "the
quality win" for exactly this class of small-sample bias (Chung/Gelman-style penalized
likelihood; blme). This slice adds a penalty term directly to the AGHQ objective,

```
nll_pen(theta) = nll_aghq(theta) + pen(Lambda)
```

and re-optimises, at `n in {100, 200, 800}`, comparing Laplace, unpenalised AGHQ
(`lambda_pen = 0`), and penalised AGHQ across a `lambda_pen` grid.

## Rotation-invariance, confronted rather than assumed

The brief's premise is that a raw ridge on the free loading entries is **not**
rotation-invariant because Lambda is identified only up to `Lambda -> Lambda R` for
orthogonal `R`, and that a penalty on the implied variance (`tr(Sigma)`, or the
eigenvalues of `Sigma = Lambda Lambda'`) should be preferred instead because it *is*
invariant.

Working the algebra through, this premise needs a correction, and the correction
matters for what "two shapes" means here:

- **General fact, not specific to this project:** for *any* `p x q` matrix `L` and any
  `q x q` orthogonal `R`,
  `||L R||_F^2 = tr(R' L' L R) = tr(L' L R R') = tr(L' L) = ||L||_F^2`
  (using `R R' = I` and the cyclic property of trace). The Frobenius norm of the
  loadings is **already invariant to any rotation**, independent of parameterisation.
- Since `tr(Sigma) = tr(L L') = sum_ij L_ij^2 = ||L||_F^2` exactly, a ridge penalty on
  the free loading entries (the structurally-zero upper-triangular entries of this
  package's lower-triangular identifiability convention contribute 0 to the sum either
  way) is **identical, as a formula**, to a penalty on `tr(Sigma)`. Not merely
  compatible with it — the same number. This is verified numerically in the script
  (section 0), not asserted: `sum(lam_free^2)` and `sum(diag(Lambda %*% t(Lambda)))`
  agree to machine precision on an arbitrary `p=5, q=2` lower-triangular fit, and
  `||L||_F^2` is confirmed invariant under an independently-drawn random rotation of an
  *unconstrained* `L` (a negative control using a non-orthogonal matrix in the same
  slot is confirmed to break the check — see Verification below).
- **At `q = 1`** (this slice's entire design), `Sigma` is rank 1, so `tr(Sigma)` equals
  its single nonzero eigenvalue. "Ridge on loadings," "penalty on `tr(Sigma)`," and
  "penalty on the eigenvalues of `Sigma`" are **the same quantity**, not three
  candidate forms to choose between. The only residual identifiability ambiguity at
  `q = 1` is a global sign flip, and a sum of squares is trivially even in sign.

**Conclusion stated plainly:** the rotation-invariance defect the brief warns about is
real in general (`q > 1`, or an unconstrained non-triangular parameterisation) but is
**vacuous for this slice's `q = 1` design** — there is no live rotation problem here to
solve by preferring one penalty form over the other. Reporting this rather than
pretending otherwise is part of the deliverable.

Given that, the two penalty **shapes** compared below are not "invariant vs
non-invariant" (both are invariant here) but two different functions of the same
invariant scalar `v = tr(Sigma) = sum(lam_free^2)`:

| | formula | shrinks toward | restoring force |
|---|---|---|---|
| (i) ridge | `0.5 * lambda_pen * v` | `v = 0` | grows linearly in `v` |
| (ii) log-variance | `0.5 * lambda_pen * (log(v + eps) - log(T))^2` | `v = T` (unit loading-variance reference) | weakens as `v` moves far from the reference |

## Non-circular choice of `lambda_pen`

Circularity risk, stated up front: a penalty shrinks, so it will improve an
upward-biased ratio for *any* strength, if the strength is chosen by looking at the
answer. Two disciplines guard against this:

1. **`lambda_pen` is fixed by an a-priori argument that does not use this study's true
   `Lambda_true` or `lam_sd = 1.2`.** The recommended value, `lambda_pen = 1`, is the
   ridge penalty implied by an independent unit-variance Gaussian prior on each raw
   loading entry (`Lambda_j ~ N(0,1)`) — a generic weakly-informative default a
   modeller would reach for with no prior knowledge of this specific study's true
   loading scale, in the spirit of `brms`/`blme` default weak priors on standardised
   effects. It is deliberately **not** matched to the simulation's `lam_sd = 1.2`
   (which would make the recommendation an artifact of knowing the answer).
2. **Sensitivity across a `lambda_pen` grid is reported** so the reader can see whether
   any apparent fix is robust or a knob tuned to the answer, at both `n = 100/200`
   (full grid) and `n = 800` (trimmed grid, see Scope cuts below).

## Scope cuts under measured contention — stated, not hidden

`uptime` during script construction showed **load average ≈ 250–313** on this shared
box (multiple peer evidence scripts — A, C, D — running `mc.cores = 8` jobs
concurrently, consistent with the brief's own "peers are running concurrently"
warning). A direct timing probe (`ref_fit`, single seed, `n = 800, k = 9`, `maxit =
150`) measured **Laplace 111s, AGHQ 185s per fit** under that load — roughly 10–20x the
cost at `n = 100` (`~9s`) and far above what an unloaded box would show. Given the "keep
runs under ~15 minutes" instruction, the design was cut as follows, and the cuts are
real, not decorative:

- `MAXIT = 60` (nlminb `iter.max`) uniformly, down from the reference default of 500.
  QC: at `n = 800` a spot check compared `maxit in {30, 50, 150}` on the same seed;
  the AGHQ ratio moved 1.366 → 1.413 → 1.413 — **converged by `maxit = 50`**, so `60` is
  not under-converged for this cell (`conv` flags are also recorded per fit and
  reported below).
- `n = 800` uses **8 seeds**, not the ≥20 floor set for `n = 100/200` — a stated
  deviation. Cause: even the 2-value trimmed grid at measured per-fit cost would need
  ~15–20 CPU-minutes serial for 20 seeds; 8 seeds is what fits alongside the cheaper
  cells in the time budget. This narrows the `n = 800` MCSE but the question it answers
  (does `lambda_pen = 1` hurt the near-unbiased large-*n* anchor) does not need 20 seeds
  to answer directionally.
- `n = 800`'s ridge grid is trimmed to `{0, 1.0}` (baseline + recommended only), not the
  full 5-point grid used at `n = 100/200`.
- The log-variance alternative form is measured **only at `n = 200`**, not at all three
  `n`, to keep the comparison of shapes affordable.
- `mc.cores = 3`, deliberately conservative, to avoid adding to contention already
  visible on the box.

## Verification discipline

- **The invariance check has a negative control, and it was actually exercised (not
  just written).** Real console output from the run:
  ```
  === section 0: invariance check (must show abs_diff ~ 0) ===
                                                         check            lhs
  1      ridge_free == trace(Sigma), lower-tri constrained fit  5.56534362036
  2 ||L||_F^2 == ||L R||_F^2, unconstrained, random rotation R 10.65453933476
               rhs         abs_diff
  1  5.56534362036 8.8817841970e-16
  2 10.65453933476 1.7763568394e-15
  negative control (non-orthogonal R): abs_diff = 17.1059 -- must be >> 0 (it is a DELIBERATE break)
  negative control confirmed red, as required; real check above is the one that must stay green.
  ```
  The real check gives `abs_diff ~ 1e-15` (machine epsilon — the algebraic identity
  holds exactly, not approximately). The deliberately-broken variant (substituting a
  non-orthogonal matrix for the rotation) gives `abs_diff = 17.1`, confirming the check
  is capable of failing and is therefore not vacuous. Both branches ran inside the
  actual script (not a separate scratch check) and the script `stop()`s if either
  assertion fails.
- **A kill mid-run leaves usable output — confirmed, not just designed.** Rows are
  appended to `10-penalty-prior.csv` inside the `mclapply` worker per seed. This was
  observed directly during the run: the file grew row-by-row while the process was
  still executing later cells (19 → 31 → 37 → 49 → 55 → 79 → 85 → 97 → 115 → 121 rows,
  tracked live over the run rather than appearing all at once at the end), and a
  mid-run `wc -l` always returned a usable, parseable partial CSV.
- **Compute reality was worse than anticipated, and is reported rather than hidden.**
  `uptime` showed load average 195–313 throughout construction and execution of this
  slice (multiple peer evidence scripts running concurrently, exactly as the brief
  warned). Even with `MAXIT` cut to 60 and `CORES` cut to 3, the `n=100` cell alone
  (20 seeds x 6 fits/seed) took approximately 30 minutes of wall time rather than the
  few minutes a timing probe on an unloaded box would suggest — worker CPU utilisation
  was observed at 13–18% per core (i.e. each worker was getting roughly an eighth of a
  core, not a whole one), confirming genuine external contention, not a bug in this
  script. This directly constrained how much of the required `n in {100,200,800}` grid
  could be completed inside a bounded session (see Results and What this slice did NOT
  establish, below).

## Results

### n = 100 (complete: 20 seeds, full ridge grid)

| method | lambda_pen | median ratio | mean ratio | MCSE | n_ok |
|---|---|---|---|---|---|
| laplace | -- | 0.828 | 3.336 | 1.262 | 20 |
| aghq (unpenalised) | 0.00 | 1.448 | 6.607 | 2.977 | 20 |
| aghq_ridge | 0.02 | 1.188 | 3.951 | 2.582 | 20 |
| aghq_ridge | 0.10 | 0.978 | 1.136 | 0.109 | 20 |
| aghq_ridge | 0.30 | 0.858 | 0.964 | 0.081 | 20 |
| aghq_ridge | **1.00 (a priori "recommended")** | 0.741 | 0.772 | 0.063 | 20 |

Convergence (nlminb `convergence == 0`, `maxit = 60`): laplace 16/20, aghq (unpenalised)
18/20, aghq_ridge pooled across all four penalised strengths 79/80 (only 1 non-zero).
**Penalisation makes the optimisation itself markedly easier** — a side benefit
independent of the bias question, consistent with a ridge term regularising an
otherwise close-to-flat or multimodal likelihood surface.

**Two separate findings, and they must not be conflated:**

1. **Runaway-suppression (a real, non-circular benefit).** At `lambda_pen = 0`
   (unpenalised AGHQ), 30% of the 20 fits have `ratio > 2` (the same bimodal
   degenerate-fit pattern this project has documented elsewhere at small `n`) — this is
   exactly why the *mean* (6.6) is so much larger than the *median* (1.448) and the MCSE
   is enormous (2.98). Laplace shows the same pathology in a milder form (mean 3.34 vs
   median 0.828 — it is not immune either). At `lambda_pen = 1.0`, **zero of 20** fits
   have `ratio > 2`: the penalty eliminates the runaway tail entirely, and the MCSE
   collapses from ~3 to 0.06. This is a legitimate, non-circular benefit — killing a
   pathological failure mode is not the same claim as "the estimator is now unbiased,"
   and it does not require knowing the truth to state ("the fitted Lambda no longer
   blows up" is checkable from the fit alone, e.g. via the objective value or a
   diagnostic threshold, not by comparing to `Lambda_true`).
2. **Median-bias correction is NOT robust to a single fixed `lambda_pen` — and this is
   the circularity the brief anticipated, now demonstrated rather than merely
   asserted.** The unpenalised median (1.448) is upward-biased, as expected. A small
   penalty (0.02) barely moves the median (1.188) and does nothing for the runaway
   tail. `lambda_pen = 0.1` lands almost exactly on median = 1.0 (0.978) — but reporting
   this AS the recommendation would be circular: `0.1` was not chosen a priori, it is
   being read off *after* seeing which grid point matches the truth. Continuing up the
   grid, `lambda_pen = 0.3` **overshoots to 0.858** and the a priori "unit-informative-
   prior" choice, `lambda_pen = 1.0`, overshoots further to **0.741** — a downward bias
   of very similar magnitude and direction to Laplace's own long-standing ~21% bias
   this whole investigation exists to explain. In other words: **the honestly-chosen, a
   priori penalty strength does not fix the bias — it approximately re-creates
   Laplace's bias by a different route**, trading an upward error for a downward one of
   comparable size.

### n = 200 (complete: 20 seeds, ridge grid + log-variance comparison)

| method | lambda_pen | median ratio | mean ratio | MCSE | n_ok |
|---|---|---|---|---|---|
| laplace | -- | 0.806 | 1.777 | 0.705 | 20 |
| aghq (unpenalised) | 0.00 | 1.163 | 3.802 | 2.237 | 20 |
| aghq_ridge | 0.02 | 1.113 | 1.159 | 0.091 | 20 |
| aghq_ridge | 0.10 | 1.059 | 1.038 | 0.070 | 20 |
| aghq_ridge | 0.30 | 0.986 | 0.936 | 0.057 | 20 |
| aghq_ridge | 1.00 (a priori "recommended") | 0.849 | 0.811 | 0.048 | 20 |
| aghq_logv | 0.30 | 1.082 | 1.916 | 0.600 | 20 |
| aghq_logv | 1.00 | 1.038 | 1.048 | 0.075 | 20 |
| aghq_logv | 3.00 | 0.968 | 0.988 | 0.072 | 20 |

Convergence: aghq 19/20, aghq_logv 59/60, aghq_ridge 80/80, laplace 19/20 — the same
"penalisation makes the optimiser's job easier" pattern as `n = 100`.

**The `n = 100` picture replicates at `n = 200`, at a smaller magnitude, as it should:**
unpenalised AGHQ still shows a runaway tail (15% of fits with `ratio > 2`, mean 3.8 vs
median 1.16), `lambda_pen = 1.0` (ridge) again eliminates it entirely (0% `ratio > 2`),
and the a priori-recommended ridge strength again overshoots into a downward bias
(0.849) — smaller than at `n = 100` (0.741, as expected since the small-*n* pathology
itself weakens with more data) but the same qualitative failure of a single fixed
constant.

**The log-variance form is a genuinely different shape, and it shows here.** At
comparable nominal strength (`lambda_pen = 1.0`), ridge overshoots to 0.849 while
log-variance lands at 1.038 — much closer to 1, WITH a comparably tight MCSE (0.075 vs
0.048). This is exactly the structural difference predicted in the introduction: the
log-variance penalty's restoring force weakens as the implied variance moves far from
the reference (`log(T) = log(4)`), so it does not keep pulling the estimate down past
the reference the way a penalty linear in `v` does. **This is a property of the
functional FORM, defensible without reference to the true `Lambda`** (it follows from
the penalty's derivative, `d(pen)/dv = lambda_pen*(log(v)-log(T))/v`, which -> 0 as `v`
approaches the reference `T`, vs ridge's `d(pen)/dv = 0.5*lambda_pen`, constant). What
is NOT non-circular is treating `lambda_pen = 1.0` or `3.0` specifically as "the"
recommended log-variance strength — those numbers were read off the same
grid-vs-truth comparison as ridge's `0.1`, and are reported as sensitivity, not as a
recommendation.

### n = 800 (large-*n* cost check: complete, all 8 requested seeds)

| method | lambda_pen | median ratio | mean ratio | MCSE | n_ok |
|---|---|---|---|---|---|
| aghq (unpenalised) | 0.00 | 1.060 | 1.082 | 0.052 | 8 |
| aghq_ridge | 1.00 (a priori "recommended") | 0.957 | 0.934 | 0.054 | 8 |

All 8 fits converged (`conv == 0`). The unpenalised AGHQ median (1.060) is consistent
with the headline table's independently-measured `n = 800` figure (1.063, `k = 15`, 10
seeds, default `maxit`) — a useful cross-check that the reduced `maxit = 60` / `k = 9`
setup here has not distorted the large-*n* anchor.

**This is the answer to the brief's explicit large-*n* question, and it is a real
cost, not a null result:** the a priori-recommended ridge strength (`lambda_pen = 1.0`)
pulls the already-near-unbiased large-*n* AGHQ estimate DOWN by roughly 5–10 percentage
points (median 1.060 -> 0.957, mean 1.082 -> 0.934) — the effect was consistent in
direction on every one of the 8 seeds individually (paired comparison, not just in
aggregate — see the per-seed table in the script output; the 8th seed's pattern matches
the other 7). **The brief's feared trade — "fixes n=100 but drags n=800 away from its
near-unbiased result" — is exactly what happens** at this penalty strength. It is a
small cost in absolute terms (the ratio stays within about 10% of 1, nothing like the
Laplace-scale ~20% bias), but it is a cost, in the direction the brief warned about, and
it is measured rather than assumed.

## Recommendation

**No single fixed `lambda_pen` is recommended as a general bias fix.** The a priori
non-circular choice (unit-variance prior, `lambda_pen = 1`) overshoots into a downward
bias comparable in kind to Laplace's own at `n = 100` (0.741) and `n = 200` (0.849),
and the grid points that look best by eye (`0.1` at `n=100`, `0.3` at `n=200`) can only
be identified by comparing to the truth — exactly the circularity the brief warned
against, now demonstrated with real numbers rather than argued in the abstract. **And
the same fixed strength has a real cost at the large-*n* end**: at `n = 800`, where
unpenalised AGHQ is already close to unbiased (median 1.060, matching the independent
headline-table figure of 1.063), `lambda_pen = 1.0` pulls it down to 0.957, consistently
across all 8 tested seeds — a genuine, measured instance of the trade the brief
pre-registered as the failure condition ("fixes small n, drags large n away from its
near-unbiased result").

**What DOES look recommendable, non-circularly, is the ridge penalty as a
runaway-suppressor at a middling-to-strong strength** (`lambda_pen` in roughly
`[0.3, 1]`): at both `n = 100` and `n = 200` it collapses the degenerate/blown-up tail
(0% vs 15–30% of fits with `ratio > 2`, `lambda_pen = 1` vs `0`) and sharply improves
optimiser convergence — both checkable without reference to the true `Lambda`. This is
a narrower, more defensible claim than "the penalty fixes the bias," and it is the one
this slice's evidence actually supports. Its price, per the `n=800` result just above,
is a small but real downward pull even where AGHQ was already fine — so this
runaway-guard should be thought of as a targeted small-*n* safeguard, not a
default-on setting across the whole `n` range.

**Between the two shapes tested, log-variance is the more defensible general-purpose
choice, on structural grounds independent of any specific `lambda_pen` value:** because
its restoring force weakens near the reference variance (unlike ridge's constant
force), it is inherently less prone to the large-*n* overshoot demonstrated above —
though this was only measured directly at `n=200` here and would need its own
large-*n* check to confirm.

If a bias-correcting (not just stabilising) penalty is wanted at all `n`, this evidence
points toward needing a **data-adaptive** penalty strength — e.g. an empirical-Bayes /
REML-estimated prior variance on the loadings (the `blme` route the cross-repo note
likely has in mind), not a fixed constant — because the right strength clearly depends
on `n` (and presumably on signal-to-noise more generally) in a way no single a priori
number can track. That route was **not** implemented here and is the natural next
step, not a result of this slice.

## Status disclosure — what was and was not completed in this session

- **n = 100:** complete, 20/20 seeds, full 5-point ridge grid.
- **n = 200:** complete, 20/20 seeds, full 5-point ridge grid + 3-point log-variance
  grid.
- **n = 800:** complete, 8/8 requested seeds (this cell alone was the slowest of the
  three, under the severe shared-box contention documented above — `uptime` load
  average 80–313 throughout — which is why it was scoped to 8 seeds rather than the
  ≥20 floor used at `n = 100/200`). Only the 2-point trimmed grid (`lambda_pen in {0,
  1.0}`) was measured here, per the stated scope cut; the fuller sensitivity grid used
  at `n = 100/200` was NOT run at `n = 800` and would need to be, to give the same
  resolution on the large-*n* cost curve as the small-*n* sensitivity curve above. The
  log-variance form was not tested at `n = 800` at all.
- Real, complete console/CSV data underlies every number in the Results section above;
  none of it is extrapolated or estimated from a different cell.

## What this slice did NOT establish

- Selection of `lambda_pen` by held-out cross-validated likelihood (a second
  non-circular route mentioned in the brief) was **not implemented** — time budget
  under the measured contention went to the a-priori-scale route and the sensitivity
  grid instead. This is a real gap, not a finding.
- The `q = 1` vacuous-rotation conclusion above should NOT be read as "penalties on
  loadings are always rotation-invariant regardless of parameterisation" for `q > 1`
  cases elsewhere in this project — only the specific claim algebraically proven above
  (Frobenius norm invariance under `L -> L R`) transfers; whether a *different* penalty
  (e.g. an asymmetric or per-column-scaled one) shares this property was not checked.
- `n = 800`'s MCSE is wider than at `n = 100/200` (8 seeds vs 20); the large-*n* "does
  the penalty hurt" conclusion is directional and consistent across every individual
  seed, but is not as tight an interval estimate as the smaller-*n* cells.
