# A2 — VA point-estimate attenuation at the fenced cells

## Purpose

`gllvmTMB`'s variational (VA) engine is about to expose loadings and latent
scores to users. The codebase currently only says point estimates "may be
attenuated" — a search of the two files the task named as background turns up
five mentions, all qualitative:

- `R/va-intervals.R:67` — "if VA's point estimate is attenuated"
- `R/va-intervals.R:310` — "VA is documented to attenuate point estimates on
  discrete data"
- `R/va-intervals.R:661,663` — "If VA's point estimate is attenuated -- the
  documented..."
- `R/va-intervals.R:1086` — "attenuation of the point estimate itself"
- `docs/design/va-intervals-status.md:21` — "VA's documented point-estimate
  attenuation on discrete data"

None of these cites a number. This slice measures one, at the cells
`R/integration-fence.R` actually admits, for the loadings (via the
rotation-invariant `Sigma = Lambda Lambda^T`) and for the per-unit latent
scores.

## Grid

Confirmed against `.gllvmTMB_integration_fence_limits()`
(`R/integration-fence.R:46-56`) before coding:

| family     | link (fence-admitted) | q_max | p_max | n_min | unique |
|------------|------------------------|-------|-------|-------|--------|
| gaussian   | identity               | 2     | 80    | 100   | FALSE  |
| binomial   | logit                  | 2     | 80    | 100   | FALSE  |
| poisson    | log                    | 2     | 80    | 100   | FALSE  |

Measurement grid (inside the fence on every axis):

- **families**: `gaussian_anchor`, `binomial`, `poisson` (the exact
  `.va_r3_fit()` family strings; `gaussian_anchor` is the VA-R3 name for the
  fence's "gaussian")
- **links**: identity / logit / log respectively (passed explicitly, matching
  the table above)
- **n**: 150, 400
- **q**: 2 (`Q0` in the shared lib)
- **p** (responses/traits): 8 (`T0` in the shared lib)
- **unique**: `FALSE` (fence requirement; also `psi = FALSE`, no separate
  diagonal tier)
- **seeds**: 50 per cell, disjoint seed streams per (family, n) cell
  (`base_seed <- 20261100 + fam_idx*10000 + n_idx*1000`), so no seed is
  reused across cells
- **n_starts**: 4 (the shipped multi-start health-gate default; only fits
  that reach `status == "healthy"` / `health$admitted == TRUE` are scored)
- 6 cells x 50 seeds = 300 fits total, run locally in ~4.2 minutes on 8
  cores (`mclapply`; per-cell wall time 7–163s, poisson n=400 the outlier —
  more expensive per fit at larger n, confirmed not pathological: 50/50
  healthy, fit time range 16–53s, no runaway) — far below the ~5000-fit
  Totoro threshold, so this stayed on the Mac per the task's compute
  guidance.

## Method

**Reused, not reinvented.** The DGP uses the same distributional
construction of `Lambda`/`z`/`x`/`beta` as the production DGP in
`dev/va-speed/40-step0-pilot.R` / `dev/va-speed/80-arcB0-timed-pilot.R`
(diag(Lambda) ~ U(0.7,1.3), sub-diagonal ~ U(-0.5,0.5), remaining rows ~
N(0, 0.7^2), `beta_true ~ N(0, 0.5^2)`, `z`/`x ~ N(0,1)`,
`eta = outer(x, beta_true) + z %*% t(Lambda)`). One honest deviation: to let
a single `sim_cell(seed, family, N0)` serve all three families, the
Gaussian-only `psi_true <- runif(T0, PSI_LO, PSI_HI)` draw was moved to
AFTER `beta_true`/`z`/`x`/`eta` (the original pilots draw it before
`beta_true`), so this is not a byte-identical RNG stream against the
original scripts for a shared seed — only the same distributions in a
different draw order. The three families are branched only at the final
response-generation step so the same latent structure produces a Gaussian,
Bernoulli, or Poisson observation:

- **gaussian_anchor**: `y = eta + N(0, psi_true)`, `psi_true ~ U(0.3, 0.5)`
  per trait (identical to the existing pilots)
- **binomial**: `y = Bernoulli(plogis(eta))` (`n_trials = 1` throughout —
  the fence admits binomial-logit, and Bernoulli is its `n_trials = 1` case)
- **poisson**: `y = Poisson(exp(eta))`

The fit call is `gllvmTMB:::.va_r3_fit()` with `unique = FALSE, psi = FALSE,
n_starts = 4`, the family/link pairs in the Grid table, and
`estimate_gaussian_sd = TRUE` for the Gaussian arm only (inert for the other
two families — `R/va-r3-proto.R:2016-2021` already keys `log_sigma`'s free
map off the per-row family code, not this flag). The TMB DLL is warm-loaded
once in the parent process before `mclapply` forks
(`gllvmTMB:::.va_r3_load_dll()`), per the existing harnesses' documented
reason (avoids concurrent recompilation races).

**Health gate.** Only fits with `va_fit$health$admitted == TRUE` and
`va_fit$status == "healthy"` (the shipped three-start agreement + gradient
gate) are scored. Unhealthy fits are counted in the yield denominator and
reported, not silently dropped.

**Lambda recovery — no rotation step needed for this target.** `Sigma_hat =
va_fit$report$Sigma_B`, the `T x T` matrix the TMB template already computes
and `REPORT()`s (`inst/tmb/gllvmTMB_va_r3.cpp:730,1034`) — read directly off
the returned fit object, not recomputed by hand. Under the fence's `unique =
FALSE` parameterisation, `Lambda`'s first `q` rows carry a structural zero
above the diagonal and a FREE (unconstrained, sign-unrestricted) real
diagonal (`inst/tmb/gllvmTMB_va_r3.cpp:713-723`; confirmed identical in the
R-side `.va_r3_unpack_theta_rr()`). That constraint pins the rotation
entirely; the only indeterminacy left is a per-column SIGN flip, to which
`Sigma_jj = diag(Sigma)` is invariant by construction
(`Lambda diag(s) diag(s) Lambda' = Lambda Lambda'` for `s in {-1,+1}^q`). So
comparing `Sigma_hat_jj` to `Sigma_true_jj` needs no Procrustes step — this
is *stronger* than the generic "loadings are identified up to rotation"
case, because the fence's constraint has already removed the rotational
freedom that a free (e.g. `factanal`-style) loading matrix would have.

**Latent-score recovery — Procrustes-aligned correlation, primary; canonical
correlation, cross-check.** `m_hat = va_fit$latent$scores`, the `N x q`
variational-posterior-mean matrix that `.va_r3_latent_posterior()` reads
straight out of `best$par` (`R/va-r3-proto.R:1433-1470`) — again the
package's own sanctioned read-out, not a hand rebuild. The same per-column
sign indeterminacy that affects `Lambda` propagates here (a column sign flip
in `Lambda` must be undone by the matching sign flip in `z`), so `m_hat` is
aligned to the planted `z` via **orthogonal Procrustes**
(Schönemann 1966: `R = svd(t(m_hat) %*% z)$u %*% t(svd(...)$v)`,
`m_aligned = m_hat %*% R`) before computing the per-axis Pearson correlation
`cor(m_aligned[,k], z[,k])`, averaged over the `q = 2` axes. Procrustes is
the general tool here (any orthogonal alignment, of which a pure sign flip
is a special case), so it is the right choice whether the residual
indeterminacy is exactly a sign flip or close to it. **Canonical correlation**
(`stats::cancor(m_hat, z)`, invariant to any invertible linear
reparameterisation of either axis set, a strictly more permissive
transform than Procrustes allows) is recorded alongside as an independent
cross-check; the two agreeing is itself informative (it would say the
recovered axes are related to truth by close to an orthogonal map, not a
more general shear).

**Attenuation ratio — two statistics, for a stated reason.** The smoke test
(below) found that a naive per-trait ratio `Sigma_hat_jj / Sigma_true_jj`,
pooled over traits and seeds, is dominated by a handful of extreme values
(up to ~25x) that trace *exactly* to traits with a near-zero planted
`Sigma_true_jj` (e.g. 0.02–0.06) — a small absolute estimation error divided
by a near-zero denominator, confirmed by inspecting `sigma_true_jj` side by
side with the outlying ratios across 6 additional probe seeds. This is a
property of the ratio statistic at small denominators, not a fit failure
(those same seeds' fits were `healthy`, and the OTHER 7 traits' ratios in
each such seed were unremarkable). Two statistics are therefore reported:

1. **Per-trait ratio**, pooled over all (seed x trait) pairs in a cell,
   summarised by **median and IQR** (robust to the small-denominator
   blow-ups) — the literal quantity the task named
   ("per-trait diagonal `Sigma_jj` is the natural target").
2. **Trace ratio**, `sum(Sigma_hat_jj) / sum(Sigma_true_jj)` per seed, then
   summarised across seeds — insensitive to any single small-denominator
   trait because it is a ratio of sums, not a sum/mean of ratios. This is
   **not a new metric invented for this task**: it is the *exact* convention
   `R/integration-fence.R`'s own `n_min = 100` justification already cites
   ("the GH arm's signed scale `tr(Sigma_hat)/tr(Sigma_true)` is 4.302 at
   n = 40"), traced to `dev/totoro-grid/run-grid.R:137`
   (`rr$attenuation <- sum(diag(Sb)) / sum(diag(Sig_true))`), a related
   but distinct prior campaign (broader family/n/p/q sweep, `gllvm::gllvm()`
   comparator arms, a simpler intercept-only DGP, no fenced-cell focus).
   Reusing its exact definition keeps this measurement's headline number
   comparable to that existing evidence rather than adding a third,
   incommensurable "attenuation" convention to the codebase.

The **trace ratio is the headline number** for the reason above (numerically
stable, and directly comparable to the fence's own cited evidence); the
per-trait median/IQR is reported alongside as the more granular, task-named
quantity, with its small-denominator caveat stated rather than hidden.

## Smoke test (mandatory discipline, run before the grid)

`00-attenuation-smoke.R`: 1 seed, n=150, each of the 3 families — all
`healthy`, all outputs finite and in-range. `01-attenuation-smoke-n400-and-binom-probe.R`:
confirmed n=400 also healthy for all 3 families, then ran 6 additional
binomial n=150 seeds specifically to inspect the large per-trait ratios seen
in the first smoke seed (binomial trait 6, ratio 12.7). Every large ratio
across all 7 probe seeds paired with a `sigma_true_jj` under 0.07 (vs. a
typical planted range of 0.3–2.7) — the division-instability explanation
above, not a health-gate or reporting bug. Logs:
`dev/va-usability/00-smoke.log`, `dev/va-usability/01-smoke-n400-binom-probe.log`.

## Results

Full grid log: `dev/va-usability/10-grid.log`. Aggregate: `dev/va-usability/A2-summary.csv`.
Raw per-seed fits (one `.rds` per cell, all 50 seeds each): `dev/va-usability/raw/A2-<family>_n<N>.rds`.

Health-gate yield was 48/50 (96%) for gaussian n=150 and 50/50 (100%) for
every other cell — 298/300 fits admitted by the shipped multi-start gate.

| family (link) | n | yield | trace ratio: mean (sd) | trace ratio: median [IQR] | per-trait ratio: median [IQR] | latent-score corr: mean (sd) | cancor mean |
|---|---|---|---|---|---|---|---|
| gaussian (identity) | 150 | 48/50 | 1.009 (0.092) | 1.000 [0.934, 1.085] | 0.999 [0.867, 1.126] | 0.937 (0.020) | 0.937 |
| gaussian (identity) | 400 | 50/50 | 0.979 (0.057) | 0.978 [0.942, 1.028] | 0.988 [0.908, 1.055] | 0.944 (0.016) | 0.944 |
| binomial (logit)    | 150 | 50/50 | 0.670 (0.167) | 0.664 [0.533, 0.746] | 0.703 [0.453, 1.140] | 0.587 (0.078) | 0.579 |
| binomial (logit)    | 400 | 50/50 | 0.582 (0.099) | 0.592 [0.518, 0.654] | 0.656 [0.462, 0.954] | 0.593 (0.071) | 0.589 |
| poisson (log)       | 150 | 50/50 | 1.022 (0.097) | 0.996 [0.949, 1.100] | 1.012 [0.841, 1.163] | 0.887 (0.029) | 0.886 |
| poisson (log)       | 400 | 50/50 | 0.985 (0.069) | 0.976 [0.937, 1.035] | 0.982 [0.894, 1.099] | 0.890 (0.038) | 0.889 |

("trace ratio" = `sum(Sigma_hat_jj)/sum(Sigma_true_jj)` per seed, then
summarised across the 50 seeds; "per-trait ratio" = the same quantity but
per (seed, trait) pair, pooled across all 8 traits x 50 seeds, so its IQR is
wider — it carries the small-denominator noise described in Method.
Procrustes-aligned latent-score correlation and canonical correlation
(`cancor_mean`) agree to within 0.008 in every cell, supporting that the
residual estimation "error" in the latent scores is well described by an
orthogonal transform, not some more general distortion.)

**Gaussian and Poisson: no material point-estimate attenuation.** Both
families' trace ratio sits at 0.98–1.02 across n=150/400 — statistically
indistinguishable from unbiased recovery of the loading-implied variance,
and it tightens (sd 0.092→0.057 gaussian, 0.097→0.069 poisson) as n grows
from 150 to 400, the signature of ordinary finite-sample noise rather than a
persistent bias. Latent-score recovery is strong: r ≈ 0.94 (gaussian),
r ≈ 0.89 (poisson).

**Binomial: substantial attenuation that does NOT shrink with n.** The
trace ratio is 0.670 (n=150) and 0.582 (n=400) — the loading-implied
variance is recovered at roughly 58–67% of truth. The shift from n=150 to
n=400 (mean difference 0.088) is about 3x the combined seed-to-seed standard
error of the two cell means (`sqrt((0.167/sqrt(50))^2 + (0.099/sqrt(50))^2)
≈ 0.027`), so the larger-n cell is if anything MORE attenuated, not less —
the opposite of what finite-sample noise would predict, and consistent
with a genuine bias that persists asymptotically rather than a small-n
artefact. Latent-score recovery is correspondingly weaker: r ≈ 0.59 at both
n, versus ≈ 0.89–0.94 for the other two families.

**Why binomial and not gaussian/poisson: the family registry already
predicts this.** `gaussian_anchor` and `poisson`'s VA objective uses an
EXACT closed-form expectation (`R/va-r3-proto.R:1165-1176` — "no bound is
needed"; `:1200-1211` — "exact, the log-normal mean"), so there is no
bound-induced bias mechanism for either. `binomial`'s DEFAULT tier (what
`family = "binomial"` resolves to with no `eval_method` override, i.e. what
an ordinary user gets) is `"jj"`, the Jaakkola-Jordan/Polya-Gamma
**bound** (`R/va-r3-proto.R:1178-1198` — `expectation = "bound"`, chosen by
default for speed over the exact `"gh"` quadrature tier). A bound that is
not tight is exactly the mechanism that would produce a persistent,
non-vanishing point-estimate bias, which is what the trace ratio shows.
This measurement did not compare the `"gh"` (exact quadrature) tier for
binomial — that would isolate whether the attenuation is specifically a
property of the JJ bound or of the binomial family more broadly, and is a
natural next slice but was out of this task's scope.

**Cross-check against prior art.** The trace-ratio statistic reuses the
exact definition `dev/totoro-grid/run-grid.R:137` already established
(`sum(diag(Sb))/sum(diag(Sig_true))`, there also named `attenuation`) and
that `R/integration-fence.R`'s own `n_min = 100` justification cites (4.302
at n=40, an INFLATION, for a different DGP/arm). This measurement does not
attempt to reconcile the two numbers — different DGP (no covariate term
there), different n, different eval_method (H=15 there vs this task's
default H=61) — but the shared metric definition means a future slice could
extend either grid onto the other's axis without inventing a third
convention.

## Honest limitations

- 50 seeds/cell gives a stable point estimate and spread for THIS purpose
  (citing a number in the docs), but this is not a calibration-grade
  campaign — no 2×MCSE claim is made, and no coverage statement follows
  from it.
- The per-trait ratio is genuinely unstable at small true `Sigma_jj`; it is
  reported as a distribution (median/IQR), not a single number, and should
  not be read trait-by-trait without also checking `Sigma_true_jj`.
- The DGP's fixed-effect design (`~ 0 + trait + trait:x`) and its specific
  `Lambda`/`psi`/`beta` amplitude are the same production DGP the existing
  pilots use; a materially different amplitude regime (e.g. much weaker
  loadings throughout, or a different `x` distribution) is not covered by
  this number.
- Only `p = 8`, `q = 2`, `n in {150, 400}` were measured; the fence admits
  up to `p = 80` and this slice says nothing about attenuation at larger
  `p`.
- "No material attenuation" for gaussian/poisson is a property of THOSE
  TWO families' exact-expectation VA objective
  (`R/va-r3-proto.R:1165-1176,1200-1211`), not a general claim that VA point
  estimates are unbiased. Binomial's default `"jj"` tier is the only
  bound-based route measured here; other bound/quadrature tiers this
  package implements for other families (e.g. `nbinom2`'s quadrature,
  `binomial_probit`'s `"gh"`/`"ac"`) are outside the fence and outside this
  measurement, so this result should not be read as "bound-based families
  attenuate, exact ones don't" beyond the three cells actually measured.

## The one-sentence number

At the fenced VA cells (n=150/400, q=2, p=8, 50 seeds/cell, `unique = FALSE`):
gaussian-identity and poisson-log recover the loading-implied variance
`Sigma_jj` with no material attenuation (trace ratio 0.98–1.02, latent-score
correlation 0.89–0.94), while the default binomial-logit route (the
Jaakkola-Jordan bound) attenuates `Sigma_jj` to 58–67% of its planted value
— worse at n=400 than n=150, not better — with latent-score recovery only
r ≈ 0.59.
