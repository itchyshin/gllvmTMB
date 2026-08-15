# A1b — Root cause of the C011 pinning: numerical bug or intrinsic optimum?

Slice A1b of the approved ultra-plan. READ-ONLY: no fits were run; the campaign root,
the repo, and every branch are untouched. Analysis script: `05_pinning_root_cause.R`
(this directory); extracted per-case columns: `a1b_C011_full.csv`, `a1b_C007_full.csv`,
`a1b_C003_full.csv` (columns `outer_id, objective, b1, b2, b3` from
`/private/tmp/mspl-coverage-production-8b23cfd2-eqLdNa/outer-fit-rows.csv`, comma-split
fields 9, 15, 17, 18, 19). All source-code line numbers refer to the campaign's own
pinned commit `8b23cfd2078bbac409f229a4d9f87df8b35ab147`
(`production-receipt.txt: source_sha`), read via `git show 8b23cfd2:<path>` and saved
alongside as `src_gllvmTMB.cpp`, `src_maxvol_atomic_v8.h`, `src_mspl.R`,
`src_fit-multi.R`, `src_run-mspl-coverage-calibration.R`; the saved copies' line
numbers equal the originals'.

---

## VERDICT

**INTRINSIC (fence).** The pinned value is the exact, penalty-determined finite
optimum of the MSPL objective under quasi-complete separation. When a trait's 24-row
response column is **all ones** (which the C011 DGP produces ~94% of the time for
trait 3), the data's entire information about that trait reduces to the discrete
success count k = 24; the loading collapses to zero; and the penalized objective for
that intercept separates into a deterministic univariate function whose unique root
is **b = 1.5964000447**. The estimator is doing exactly what Sterzinger–Kosmidis soft
penalization is designed to do — return a finite estimate where the ML estimate is
+infinity — and no software change can recover the truth 2.05 from an all-ones column.
The catastrophic undercoverage is a *bootstrap inconsistency at the separation
boundary*, not an estimator bug: parametric resamples from the collapsed fit are
themselves all-ones with probability 0.841, so ~78–84% of bootstrap refits land on
the same atom and the percentile interval has almost no width around a centre that is
biased by construction.

Every bug signature the task listed was tested and is absent; every intrinsic
signature was tested and is present, quantitatively, to 6–8 decimal places. Detail
below.

---

## Task 1 — The pinned value, exactly

### 1.1 Full-precision cluster analysis (script `05_pinning_root_cause.R`, section "empirical clusters")

C011 (cloglog × high_prevalence), 1000 outer fits, `a1b_C011_full.csv`:

| coordinate | modal cluster (4 dp) | n/1000 | full-precision mean | within-cluster SD |
|---|---|---:|---|---|
| b_fix_3 (truth 2.05) | 1.5964 | **929** | 1.59639878 | 1.82e-5 |
| b_fix_2 (truth 1.60) | 1.5964 | 463 | 1.59639658 | 3.15e-5 |
| b_fix_2 | 1.1230/1.1231 | 156+71 | 1.12302993 | 2.51e-5 |
| b_fix_1 (truth 1.00) | 0.8956 | 185 | 0.89564681 | 6.52e-7 |
| b_fix_1 | 0.7250 | 174 | 0.72501363 | 2.74e-5 |
| b_fix_1 | 1.1230 | 113 | 1.12301537 | 1.07e-5 |
| b_fix_1 | 0.5805 | 97 | 0.58045505 | **4.0e-15** |
| b_fix_1 | 0.4505 | 56 | 0.45053163 | **2.3e-16** |

**The same value is shared across different seeds/datasets — but it is NOT a code
constant.** The distinguishing observation is that the pinning is not one value: it
is a *discrete family* of values, and each one is hit by many independent datasets
(some clusters agree across datasets to 1e-15, i.e. bit-level). A clamp or box bound
produces one value; a count-indexed family of six-plus values, each reproduced
across datasets, is the signature of an optimum whose location depends on the data
only through a discrete sufficient statistic. Section 1.2 identifies that statistic.

Exact ties across coordinates (same file): `b_fix_2 == b_fix_3` to <1e-6 in **452**
fits, `b_fix_1 == b_fix_2` in 88, all three equal in 12 — explained in 1.2 (two
saturated columns solve the *same* univariate problem, hence land on the *same* root).

### 1.2 Every cluster is a count-attractor of the collapsed objective

Claim: with loading row λ_j = 0, the MSPL objective separates per trait into

  Q_j(b) = k_j·log p1(b) + (24 − k_j)·log p0(b) + (c_n/2)·log w(b),   c_n = 2·sqrt(6/72)

where k_j = number of ones in trait j's 24-row column, p1/p0 are the link's Bernoulli
probabilities and w its expected-information weight (`src/gllvmTMB.cpp:201-249`,
`252-290`). Why this is exact when all λ = 0: the Laplace determinant over the 24
site scores is log det(I) = 0; V_loading is the row-radial pseudo-Huber at 0
(`src/gllvmTMB.cpp:293-323`), which is 0 with zero gradient; the Jeffreys term
factorises because X_mspl is the 72×3 trait-indicator design, so
log det(Xᵀ W X) = Σ_j log(24·w(b_j)); and sites are exchangeable, so only the count
k_j enters. p_free = 3 intercepts + 3 free loadings = 6 (`src/gllvmTMB.cpp:1088-1090`:
`expected_p_free = X_mspl.cols() + theta_rr_B.size()`), N_eff = 72, giving
**c_n = 0.577350269189626** (`src/gllvmTMB.cpp:3056`).

Solving dQ_j/db = 0 by `uniroot` at tol eps^0.75 (script, function `attractor`)
gives, for cloglog: k=24 → **1.59640004471**, k=23 → 1.12301287919, k=22 →
0.89564704752, k=21 → 0.72499012112, k=20 → 0.58045495529, k=19 → 0.45053164111.
Match against the empirical clusters above:

| link | k | theory | empirical cluster mean | |dev| |
|---|---:|---|---|---|
| cloglog | 24 | 1.59640004 | 1.59639878 (b3, n=929) | 1.3e-6 |
| cloglog | 23 | 1.12301288 | 1.12302993 (b2) | 1.7e-5 |
| cloglog | 22 | 0.89564705 | 0.89564681 (b1) | 2.4e-7 |
| cloglog | 21 | 0.72499012 | 0.72501363 (b1) | 2.4e-5 |
| cloglog | 20 | 0.58045496 | 0.58045505 (b1) | 9.1e-8 |
| cloglog | 19 | 0.45053164 | 0.45053163 (b1) | 9.0e-9 |
| probit | 24 | 2.36293512 | 2.36292884 (C007 b3, n=484) | 6.3e-6 |
| probit | 23 | 1.65372788 | 1.65376382 (C007 b3) | 3.6e-5 |
| probit | 20 | 0.94825108 | 0.94825111 (C007 b1) | 3.3e-8 |
| logit | 24 | 4.43246352 | 4.43245643 (C003 b3, n=50) | 7.1e-6 |
| logit | 22 | 2.27610560 | 2.27611018 (C003 b3, n=71) | 4.6e-6 |
| logit | 21 | 1.86769046 | 1.86769126 (C003 b3) | 8.0e-7 |

A1's "modal probit value 2.3629 (48.4%)" and "modal logit value 2.2761 (7.1%)" are the
probit k=24 and **logit k=22** attractors respectively — the same mechanism at every
link, differing only in which count is typical (see Task 3/DGP below). Residual
deviations of 1e-5–1e-8 are optimizer stopping tolerance (nlminb "relative
convergence (4)" in `message`, plus the MSPL rescue's scaled-score ceiling of 1e-4,
`R/fit-multi.R:5391-5403`), not data variation — several clusters agree across
datasets at 1e-15 while sitting 9e-8 from my independently-computed root.

### 1.3 The stored objective proves the collapse is total

For **703/1000** C011 fits, *all three* coordinates sit on count-attractors. For
those rows the collapsed model predicts the stored penalized objective (column
`objective`, field 15) with **no free quantities**:

  nll = −Σ_j [k_j·log p1(b_j) + (24−k_j)·log p0(b_j)] − (c_n/2)·Σ_j [log 24 + log w(b_j)]

Stored vs predicted for the first 12 fully-pinned rows: max |diff| = **2.1e-11**
(e.g. outer_id 1: stored 5.64511710277, predicted 5.64511710277; script output
"Stored vs collapsed-model predicted objective"). The fitted model at these optima
IS the collapsed model — Λ = 0, LA correction 0, likelihood a pure count binomial —
to within 1e-11 of the C++ template's own arithmetic.

### 1.4 Comparison values

- **Truth**: 2.05. Not the pin. The pin sits 0.4536 below it — that IS the bias.
- **0**: not the pin.
- **Starting value**: for Bernoulli rows b_fix starts at `lm.fit(X_fix, y)`
  (`R/fit-multi.R:2947-2949`, the fall-through branch — none of the multi-trial /
  log-link / beta / ordinal branches at 2924-2946 apply to Bernoulli), i.e. the
  trait's raw mean: **1.0 for an all-ones column**. Start ≠ pin, so the optimizer
  demonstrably moves; the "flat objective never left" bug signature is absent.
- **Any code constant**: the MSPL cloglog constants are `cut = log(1e-4) ≈ −9.21`
  and `hi = 690` (`src/gllvmTMB.cpp:221,230`); atom tolerances are 1e-10/1e-14
  (`src/lane_b_jeffreys_maxvol_atomic_v8.h:571`). Nothing in the code equals 1.5964,
  and the probit/logit pins (2.3629, 4.4325, 2.2761…) equal no constant either.

## Task 2 — Bounds and clamps: none apply

- **nlminb box constraints**: `.gllvmTMB_nlminb_call_args`
  (`R/fit-multi.R:6998-7015`) forwards `lower`/`upper` only if present in the user's
  `control$optArgs`; the campaign runner passes no `optArgs`
  (`run-mspl-coverage-calibration.R:402-410`: only `n_init = 1L, init_jitter = 0,
  se = FALSE, warn_runaway = FALSE`). **Unbounded optimisation.**
- **Weight floor**: none. `src/gllvmTMB.cpp:199` ("No probability or information
  floor is used"), confirmed by reading `gll_mspl_log_weight` (201-249): the weight
  is computed *in log space* throughout, so it cannot underflow to zero; the guarded
  C1 logarithmic tail engages only at **eta > 690** and every crossing is counted
  (`mspl_cloglog_weight_tail_extension_count`, `src/gllvmTMB.cpp:3062-3065`,
  REPORTed at 3119-3121). Design 88's "no positive weight floor is permitted"
  (docs/design/88-binary-mspl-estimator.md:67 on the branch) is honoured in code.
- **Maxvol atom**: `src/lane_b_jeffreys_maxvol_atomic_v8.h` contains rank/
  certification tolerances (`rank_clear = 1e-10, rank_zero = 1e-14`, line 571;
  certification thresholds 1e-12/1e-9, lines 745-746) and one representation guard
  (line 900 zeroes a basis-ratio entry whose log-gain is below
  `log(denorm_min) ≈ −744`) — none is a weight floor, and none is active anywhere
  near the pin: at b = 1.5964 the cloglog weight is **w = 0.176362**
  (log w = −1.735219), a perfectly conditioned value.
- **eta clamps in the likelihood**: the cloglog log-pmf switches branches at
  `cut = log(1e-4)` and `hi = 690` (`src/gllvmTMB.cpp:263,272`); the pin at 1.5964
  is deep inside the ordinary direct branch.

**Conclusion**: the pinned value equals no bound, no clamp threshold, and no start.
The smoking-gun bug signature does not exist.

## Task 3 — Saturation hypothesis, quantitatively

The *underflow* version of the saturation hypothesis is **refuted**; the
*separation* version is **confirmed**.

- w_cloglog(eta) falls below `.Machine$double.eps` at eta = 3.7749 (a = 43.6)
  (script, `f_under`), but the pin is at 1.5964 where w = 0.176 — and the code
  stores log w, so even eta = 100 (log w = −2.7e43… i.e. 2·eta − e^eta, a large
  negative but exactly representable number) would not underflow. The guarded tail
  and its counter engage only beyond eta = 690. **No degenerate/flat objective from
  weight underflow exists at or near the pin**, and the fail-closed atom path is not
  activated (its status is REPORTed per fit — `mspl_atom_status`,
  `src/gllvmTMB.cpp:3069,3123` — but not exported into any campaign CSV: neither
  `outer-fit-rows.csv` nor `summary.csv` has an atom/tail column; noted as a data
  gap, though nothing turns on it given 1.3).
- What actually saturates is the **response**: under the C011 DGP
  (`run-mspl-coverage-calibration.R:373-390`: eta = beta_j + lambda_j·z_site,
  beta = (1.00, 1.60, 2.05), lambda = (0.8, −0.55, 0.35), mu = -expm1(-exp(eta))),
  the probability that trait 3's 24-row column is ALL ones is
  **0.9384** (2e6-draw MC, script section "DGP"), trait 2: 0.4943, trait 1: 0.0325.
  Compare the observed all-ones-attractor masses: **b3 92.9%, b2 46.3%, b1 3.4%**.
  Probit trait 3: predicted 0.5248 vs observed 48.4%. Logit trait 3: predicted
  0.0481 vs observed 5.0% at the logit k=24 attractor 4.4325. **The link ordering of
  the pinning rate (cloglog > probit > logit) is exactly the link ordering of
  P(all-ones column) at these truths** — cloglog's mu(2.05) = 0.99958 vs probit's
  0.9798 vs logit's 0.8859 — not a link-specific numerical defect.
- The Jeffreys log-det never becomes −Inf/degenerate at the optimum: each diagonal
  entry is 24·w(b_j) with w in [0.088, 0.18] at the observed attractors.

## Task 4 — The two verdicts, discriminated

Bug signatures (all ABSENT):
1. pin = code constant / bound / clamp — **no** (Task 1.4, Task 2);
2. pin = start value (optimizer never moved) — **no** (start 1.0, pin 1.5964);
3. weight underflow producing a flat objective — **no** (w = 0.176 at the pin);
4. single universal pinned value — **no** (a k-indexed family, six+ members).

Intrinsic signatures (all PRESENT):
1. **value varies with the data, but only through a discrete sufficient statistic**:
   six distinct cloglog attractors, ten predicted, each matching its k-root to
   1e-6–1e-8 (Task 1.2);
2. **objective genuinely maximised there**: the stationarity equation
   k·dlogp1 + (24−k)·dlogp0 + (c_n/2)·dlogw = 0 is solved by the empirical values
   (that IS gradient = 0 in the collapsed direction), and the fit machinery enforces
   scaled gradient ≤ 1e-4 on acceptance (`R/fit-multi.R:5391-5403`, MSPL BFGS
   rescue); the stored objective equals the analytic optimum value to 1e-11 (1.3);
3. **penalty-vs-likelihood balance is explicit**: at k = 24 the likelihood score is
   24·a·e^{−a}/(1−e^{−a}) (pure upward pull toward +∞) and only the penalty score
   (c_n/2)·(2 − a/(1−e^{−a})) opposes it; the root exists *because* of the penalty —
   remove it and the estimate diverges (that is the pre-MSPL ML failure mode this
   estimator was built to fix);
4. **moves predictably with c_n** (computed, script tail): cloglog k=24 attractor =
   **1.715161 at c_n/2, 1.596400 at c_n, 1.466704 at 2·c_n**; probit k=24: 2.595651 /
   2.362935 / 2.115937. A clamp would not move.

**Decomposed gradient contributions** were computable from stored quantities
(1.2–1.3 above), so the one-hour B0 refit experiment is **not needed to reach the
verdict**. As a cheap *confirmation* (optional): refit ~10 C011 datasets with the
template's `p_free` doubled/halved (or a dev knob scaling `mspl_c_n`) and check
b_fix_3 lands at 1.466704 / 1.715161 to 4 decimals; and dump `Lambda_B` to confirm
the loading collapse (loadings are not in any campaign CSV — the one stored-data gap
in this analysis; the 1e-11 objective identity makes Λ = 0 a near-certainty but the
direct read would close it). A secondary observation for that run: the minority
clusters that match no λ=0 attractor (0.59330, 0.47023, 1.13865, 1.15321, … —
within-cluster SD ~1e-14) are consistent with count-determined attractors of the
*non-collapsed* (λ ≠ 0) branch, which are also dataset-independent given k by site
exchangeability — AGENT-INFERRED, unverified, and immaterial to the verdict.

## Task 5 — What follows under the (established) verdict

**No fix exists in the estimator.** For an all-ones column the ML estimate is +∞ and
*any* data-independent penalty yields some finite deterministic value; changing the
penalty moves the atom (Task 4.4) but cannot recover 2.05 from data whose likelihood
is monotone in b. Kosmidis & Firth (2021) — cited in Design 88's references — prove
finiteness under Jeffreys-type penalties; finiteness is the feature. Design 88
already states the honest boundary: "finite estimates do not imply minimum prediction
or estimation risk" (docs/design/88-binary-mspl-estimator.md, Public contract
section). Note the campaign's *bootstrap intervals are themselves an internal
evidence surface* — the public contract already makes `confint()`/bootstrap surfaces
fail with typed errors — so the fence lands on the evidence/promotion side, not on a
shipped API.

Concrete fence (S1, feeding the A3 design):
1. **Trigger, computable at fit time from the data alone**: a trait column with
   k = 0 or k = 24 (saturated), or within the near-separated band. This corrects
   A1-Q4's "no observable distinguishes C011 at fit time" — no observable *in the
   stored campaign files* does, but the response matrix itself does, trivially, and
   Design 88's own `screen_control(separation = "fixed")` is the shipped pre-fit
   certifier of exactly this condition. C011's pocket is 92.9%-triggered by it.
2. **Fence semantics**: for a saturated coordinate, the MSPL point estimate is
   penalty-determined (report it as such — a labelled "separation-finite" estimate),
   and *bootstrap/percentile intervals for that coordinate are inadmissible*: the
   resampling distribution is atomic (P(resample re-saturates) = mu_pin^24 = 0.841
   here), so the interval measures optimizer noise, not sampling uncertainty. The
   campaign's own profile intervals in the same cells covered at 1.000 (A1 Q1/Q5) —
   if any interval is reported under saturation, it must be profile-shaped, and
   flagged conservative.
3. **What re-measurement a penalty change would force**: any c_n or penalty-form
   modification relocates every count-attractor, so the full 12-case coverage grid
   would need to be re-run; given (1)–(2), that spend is not warranted for C011's
   pocket — the pocket is a *fence*, not a *tuning target*.
4. **Literature note**: the lane's own docs record no cloglog-at-extreme-prevalence
   discussion from Sterzinger & Kosmidis beyond the general citations
   (grep over the branch's docs/ found S&K only in Design 88's reference list,
   the estimator-programme note, and the method-map; nothing prevalence-specific).
   S&K 2023 treat mixed-effects *logistic* models; the cloglog severity ranking here
   is fully explained by the DGP event probability (Task 3), needing no
   link-specific theory.

## One-line mechanism summary

At high prevalence under cloglog, ~94% of simulated trait-3 columns are all ones;
the MSPL loading collapses to 0, the objective separates, and the intercept lands on
the deterministic root of 24·dlogp1 + (c_n/2)·dlogw = 0 at 1.5964000447 — a finite
Firth-type estimate under quasi-complete separation, 0.454 below the truth 2.05;
parametric bootstrap resamples re-saturate 84% of the time and reproduce the same
atom, so the percentile interval is a needle centred on the bias — coverage 0.010.
