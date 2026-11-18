# A4 — BCa with a Non-Jackknife Acceleration, for `estimator = "mspl"`

Slice A4 of the ultra-plan. Read-only: derivation and specification only, no
fitting, no implementation, no analysis of the raw campaign files (that is
A1's scope). This note inspects only the column headers of the four raw
files, never their contents.

Fitted-object constraint carried in from the task brief and treated as given
throughout: `estimator = "mspl"`'s objective

$$
Q_{LA}(\beta,\Lambda,\Sigma) \;=\; \ell_{LA}(\beta,\Lambda,\Sigma)
\;+\; c_n\cdot \tfrac12\log\det\!\big(X_*^{\mathsf T} W_g(\beta)\, X_*\big)
\;-\; c_n\, V_{\text{loading}} \;-\; c_n\, V_{\text{covariance}},
\qquad c_n = 2\sqrt{p_{\text{free}}/N_{\text{eff}}}
$$

has a Jeffreys log-determinant term that mixes every row of the design
jointly, and its TMB `joint_nll_penalized` report excludes the outer Laplace
log-determinant. **The fitted object therefore exposes no per-unit (per-site,
per-observation) score or gradient decomposition.** This single fact is the
load-bearing constraint for everything below.

---

## Q1. The BCa construction, exactly

**Setup.** Let $\theta$ be a scalar target functional of the MSPL fit (a
loading, a $\Sigma$-tier SD, a correlation, etc.), $\hat\theta$ its point
estimate from the outer (non-bootstrap) MSPL fit, and
$\{\hat\theta^{*}_1,\dots,\hat\theta^{*}_B\}$ the $B$ parametric bootstrap
replicates already produced by the campaign. Let $\hat G$ denote their
empirical CDF, $\Phi/\Phi^{-1}$ the standard-normal CDF/quantile, and
$z^{(\alpha)}=\Phi^{-1}(\alpha)$.

**Endpoints.** For a nominal two-sided interval of level $1-2\alpha$
(Efron 1987, §2, eqs. (2.3)–(2.4), pp. 172–173; Efron & Tibshirani 1993,
*An Introduction to the Bootstrap*, ch. 14, eq. (14.10), p. 185; DiCiccio &
Efron 1996, *Statistical Science* 11(3), §3, eqs. (3.4)–(3.5)):

$$
\hat\theta^{*}_{\text{lo}} = \hat G^{-1}\!\Big(\Phi\big(\hat z_0 + \tfrac{\hat z_0+z^{(\alpha)}}{1-\hat a\,(\hat z_0+z^{(\alpha)})}\big)\Big),
\qquad
\hat\theta^{*}_{\text{hi}} = \hat G^{-1}\!\Big(\Phi\big(\hat z_0 + \tfrac{\hat z_0+z^{(1-\alpha)}}{1-\hat a\,(\hat z_0+z^{(1-\alpha)})}\big)\Big)
$$

i.e. the interval is $\big(\hat\theta^{*}(\alpha_1),\,\hat\theta^{*}(\alpha_2)\big)$
where $\hat\theta^{*}(\cdot)=\hat G^{-1}(\cdot)$ is the empirical percentile
function of the $B$ replicates and $\alpha_1,\alpha_2$ are the two
$\Phi(\cdot)$ expressions above. Setting $\hat a=0$ collapses this to the
**BC** (bias-corrected, non-accelerated) interval already measured at 2/36 in
the campaign; setting $\hat a=\hat z_0=0$ collapses it to the plain
**percentile** interval (20/36).

**Bias-correction constant.**

$$
\hat z_0 \;=\; \Phi^{-1}\!\Big(\hat G(\hat\theta)\Big) \;=\; \Phi^{-1}\!\Big(\#\{b:\hat\theta^{*}_b < \hat\theta\}/B\Big)
$$

(Efron & Tibshirani 1993, eq. (14.14), p. 186). This needs only the stored
replicate vector and the outer point estimate — nothing per-unit. **$\hat z_0$
is unaffected by the no-per-unit-score constraint** and is already computable
today; it is not the object of this memo (the campaign's BC-normal variant,
17/36, already uses a bias correction, just paired with a normal-quantile
rather than a BCa endpoint map).

**Acceleration constant, canonical (jackknife) form.** With $\hat\theta_{(i)}$
the leave-one-out re-estimate deleting unit $i$ ($i=1,\dots,n$) and
$\hat\theta_{(\cdot)}=n^{-1}\sum_i\hat\theta_{(i)}$:

$$
\hat a \;=\; \frac{\sum_{i=1}^{n}\big(\hat\theta_{(\cdot)}-\hat\theta_{(i)}\big)^{3}}
{6\Big\{\sum_{i=1}^{n}\big(\hat\theta_{(\cdot)}-\hat\theta_{(i)}\big)^{2}\Big\}^{3/2}}
$$

(Efron & Tibshirani 1993, eq. (14.15), p. 186). **This is the formula the
maintainer has rejected for this package** — it is reproduced here only to
fix notation; §Q2 covers what can replace it.

**What each ingredient measures, per Efron (1987) and DiCiccio & Efron
(1996).** $\hat z_0$ corrects for median bias of $\hat\theta$ relative to
$\theta$ on the bootstrap scale. $\hat a$ corrects for the fact that the
standard error of $\hat\theta$ is not, in general, constant in $\theta$: on
the normalizing/variance-stabilizing scale $\phi=h(\theta)$ that BCa's
derivation assumes exists (Efron 1987, §2, model
$\hat\phi \sim N(\phi - z_0\sigma(\phi),\,\sigma(\phi)^2)$ with
$\sigma(\phi)=1+a\phi$), $a$ is the rate of change of that standard error
with the parameter, on a standardized scale. In the regular-parametric case
this rate of change is shown to equal, to the relevant asymptotic order,
one-sixth the (standardized) skewness of the score statistic at $\hat\theta$
— this equivalence is what makes routes (i) and the infinitesimal jackknife
in Q2 candidates at all, and it is also why they inherit the per-unit-score
requirement.

---

## Q2. Non-jackknife routes to $\hat a$

### (i) Closed form: one-sixth the standardized skewness of the score in the least-favorable family

**Construction.** Efron (1987, §5–6, "the least-favorable family
acceleration") shows that for a regular one-parameter (or curved
one-parameter) sub-family through $\hat F$ chosen in the direction that
carries all the Fisher information for $\theta$ (the *least favorable
direction*), the acceleration equals, to second order,

$$
a \;=\; \frac{1}{6}\,\frac{E\big[\,l'(\hat\theta)^3\,\big]}{E\big[\,l'(\hat\theta)^2\,\big]^{3/2}}
$$

where $l'(\theta)=\partial/\partial\theta\,\log f(X;\theta)$ is the score.
Its sample analogue, built from the per-observation score contributions
$l'_i(\hat\theta)=\partial/\partial\theta\log f(X_i;\hat\theta)$, $i=1,\dots,n$,
is

$$
\hat a_{\text{score}} \;=\; \frac{1}{6}\cdot
\frac{n^{-1}\sum_i l'_i(\hat\theta)^{3}}
{\big\{n^{-1}\sum_i l'_i(\hat\theta)^{2}\big\}^{3/2}}
\qquad
\text{(sample skewness of the per-unit score at } \hat\theta \text{)}.
$$

This is the standard "exponential-family" closed form discussed in
DiCiccio & Romano (1988, *JRSS-B* 50(3), 338–354, §4) and in DiCiccio &
Efron (1996, §3), and it is the analytic ($n\to\infty$ finite-difference
limit) counterpart of the jackknife formula in Q1 — Efron (1987, §6) shows
the two agree to $O(n^{-1})$.

**What it needs.** Per-observation (per-unit) score contributions
$l'_i(\hat\theta)$ evaluated at the fitted MSPL parameter, so their sample
third and second moments can be formed.

**Verdict for MSPL.** **Blocked.** This is precisely the per-unit score
decomposition the task brief states does not exist for this estimator: the
Jeffreys log-determinant term $\tfrac12\log\det(X_*^{\mathsf T}W_g(\beta)X_*)$
is a joint function of the whole design (not a sum of per-row terms after
differentiation contributes a term that itself does not decompose additively
in a simple per-unit way without forming $\partial/\partial\theta$ of a
matrix log-determinant summed against $(X_*^{\mathsf T}W_gX_*)^{-1}$, which
is again a global object), and the penalties $V_{\text{loading}}$,
$V_{\text{covariance}}$ are functions of the *global* $c_n=2\sqrt{p_{\text{free}}/N_{\text{eff}}}$
and the full loading/covariance blocks, not of one unit at a time. Even
setting aside the Jeffreys term, `joint_nll_penalized`'s TMB `REPORT`/`ADREPORT`
surface — per the task brief — excludes the outer Laplace log-determinant, so
even the *Laplace-approximated marginal likelihood piece* of $Q_{LA}$ does
not currently expose a per-row gradient that could be read off and cubed.
**Route (i) requires exactly what has already been ruled unavailable.**

### (ii) Empirical skewness of the existing bootstrap replicate distribution

**Construction.** Use the sample skewness of the stored replicates
$\{\hat\theta^{*}_b\}_{b=1}^{B}$ themselves as a stand-in for $6a$:

$$
\hat a_{\text{boot-skew}} \;=\; \frac16\cdot
\frac{B^{-1}\sum_b(\hat\theta^{*}_b-\bar\theta^{*})^{3}}
{\big\{B^{-1}\sum_b(\hat\theta^{*}_b-\bar\theta^{*})^{2}\big\}^{3/2}}.
$$

**What it needs.** Only the stored replicate vector for the target — no
refitting, no per-unit anything.

**Verdict for MSPL.** **Not blocked by the per-unit constraint — but its
statistical justification is weaker than routes (i)/(iv) and should be
labelled a heuristic, not a validated BCa acceleration.** Efron's own
derivation ties $a$ to how the *standard error of $\hat\theta$ changes with
the true parameter value* (the derivative of $\sigma(\phi)$ in the
normalizing-transformation model of Q1), not to the skewness of $\hat\theta$'s
sampling/bootstrap distribution at the single fitted value. The two are
related — a nonzero $a$ typically induces a skewed bootstrap distribution —
but the bootstrap distribution's skewness also picks up any non-normality
that has nothing to do with $a$ (small-sample skewness of $\hat\theta$ under
a *fixed*-SE, non-normal-but-non-accelerated family, or boundary/support
effects such as a variance component being clipped near zero). **UNVERIFIED**:
I could not confirm a citation that establishes
$\hat a_{\text{boot-skew}}$ as asymptotically equivalent to the canonical
$\hat a$ to the same order that the jackknife/score forms are; what would
settle this is checking DiCiccio & Efron (1996, §2–3) and Efron (1987, §6)
directly for whether they derive (or explicitly warn against) using raw
bootstrap-distribution skewness as a plug-in for $a$, versus only using it as
a diagnostic that $a\neq0$ is plausible. Treat $\hat a_{\text{boot-skew}}$ as
an **exploratory sensitivity check**, not as grounds for a covered-interval
claim, unless/until that is settled.

### (iii) Parametric/simulation estimate by resimulating at (and near) the fitted parameter

**Construction.** Because $a$ is, by the normalizing-model derivation in Q1,
the (standardized) rate of change of $\hat\theta$'s sampling SE with the true
parameter, it can be estimated directly by simulation without ever forming a
per-unit score: refit the full MSPL objective (Jeffreys term, penalties, and
all) on parametric-bootstrap samples generated at two or more perturbed
"true" parameter values $\theta_0+\delta$ and $\theta_0-\delta$ in a
neighbourhood of $\hat\theta$ (or, following Efron 1987's own suggestion for
parametric problems, at the fitted family perturbed along the direction of
interest), estimate $\widehat{\mathrm{se}}(\delta)$ from each perturbed
bootstrap ensemble, and take a finite-difference / regression estimate of
$d\log \widehat{\mathrm{se}}/d\theta$ at $\hat\theta$, converting to $a$ via
the standardized-derivative relation in the normalizing-transformation model.
This is the same operation as an *iterated/double bootstrap* used elsewhere
in the literature to estimate acceleration-like quantities without a
jackknife (Efron 1987, remark on parametric alternatives to the jackknife,
§6; the general double-bootstrap machinery is in Hall 1992, *The Bootstrap
and Edgeworth Expansion*, ch. 3, and Booth & Hall 1994, *Biometrika* 81(2),
331–340, on choosing the number of bootstrap replications for
acceleration-type corrections — **UNVERIFIED**: I have not re-derived the
exact finite-difference-to-$a$ conversion formula from a primary source
inside this task's scope, so no such formula is asserted here beyond the
qualitative construction; what would settle it is reading Efron (1987, §6)
and Hall (1992, ch. 3) directly before this is specified for implementation).

**What it needs.** The whole fitted MSPL objective as a function that can be
evaluated/optimized at a perturbed generating parameter — i.e. exactly the
same capability the 6,000,000-refit campaign already exercises (full outer
+ bootstrap refits), just organized around a small grid of *perturbed*
generating parameters rather than one. It needs **no per-unit score** at any
point: the objective is treated as a black box that returns $\hat\theta^{*}$
given a seed and a generating parameter.

**Verdict for MSPL.** **Not blocked.** This route operates entirely on the
already-demonstrated capability (refit MSPL at a given generating parameter,
observe the replicate distribution) and never touches the interior of
$Q_{LA}$. It is the only route in this enumeration that is both (a) not
blocked by the missing per-unit decomposition and (b) grounded in the
quantity Efron's derivation actually defines ($a$ as an SE-vs-$\theta$
derivative), rather than a proxy for it. Its cost is new simulation — see
Q4.

### (iv) ABC (approximate bootstrap confidence) intervals

**Construction.** ABC intervals (Efron 1987, §7; DiCiccio & Efron 1992,
*Biometrika* 79(2), 231–245, "More accurate confidence intervals in
exponential families"; Efron & Tibshirani 1993, ch. 22; DiCiccio & Efron
1996, §5) obtain $z_0^{ABC}$ and $a^{ABC}$ **analytically**, without any
resampling, by taking numerical directional derivatives of the estimator
$\hat\theta=t(\hat F)$ along the empirical influence function: for each
unit $i$, the (rescaled) empirical influence value

$$
U_i \;=\; \lim_{\varepsilon\to0}\frac{t\big((1-\varepsilon)\hat F+\varepsilon\,\delta_{X_i}\big)-\hat\theta}{\varepsilon}
$$

is used to build a "least-favorable" one-parameter perturbation of $\hat F$
in the direction $\sum_i U_i\,\delta_{X_i}$, and $a^{ABC}$ is essentially the
same skewness-of-influence-values construction as route (i), obtained via
finite-difference perturbation of $t(\cdot)$ rather than a full leave-one-out
refit — i.e. ABC is a *cheaper way to compute the same influence-function
quantity that the jackknife estimates*, not a different quantity.

**What it needs.** Per-unit empirical influence values $U_i$, which in turn
require perturbing the estimating equations/objective one observation's
weight at a time and reading off the resulting $\partial\hat\theta/\partial
w_i$ — i.e. a per-unit decomposition of how the objective responds to
reweighting individual rows.

**Verdict for MSPL.** **Blocked, for the same reason as (i).** $U_i$ is
exactly a directional derivative of the MSPL objective with respect to a
single unit's weight; the Jeffreys log-determinant term
$\log\det(X_*^{\mathsf T}W_g(\beta)X_*)$ couples every row through the shared
design/weight matrix, so a one-row reweighting perturbs a *global* quadratic
form, not an additive per-unit term, and the excluded outer Laplace
log-determinant in the TMB report means even the likelihood piece cannot be
differentiated per-row from what is currently reported. ABC additionally
needs the **Fisher information / curvature** of the least-favorable family at
$\hat\theta$ (a second-derivative object), which raises the same reporting
gap. ABC is explicitly a jackknife-free method in the literature, but for
*this* estimator it fails for the identical structural reason route (i)
fails, not because it needs a jackknife per se.

### Named but flagged: the infinitesimal jackknife (IJ)

For completeness, since the constraints ask that it be named if technically
distinct: the infinitesimal jackknife estimates the same influence values
$U_i$ as ABC via a single linearization,
$U_i \approx -\big[\partial^2 Q/\partial\theta^2\big]^{-1}\partial Q_i/\partial\theta$,
using the curvature of the *fitted* objective plus per-unit score
contributions $\partial Q_i/\partial\theta$ (Efron & Tibshirani 1993, ch. 21,
"empirical influence functions"; Jaeckel 1972 for the IJ itself). It is
technically distinct from the delete-one-site jackknife the maintainer
rejected — no refits at all, one linearization at the existing fit — but (a)
it needs precisely the per-unit $\partial Q_i/\partial\theta$ that is blocked
here for the same reason as (i)/(iv), and (b) it is unmistakably
jackknife-adjacent (same influence-function target, same name family).
**Per the task constraints, this route is not proposed for use and would
require explicit maintainer approval before even being scoped**, independent
of the fact that it is also blocked by the missing per-unit decomposition.

---

## Q3. Verdict

**Yes — there is exactly one viable non-jackknife acceleration route for
this estimator, and it is route (iii), the parametric perturbation/resimulation
estimate.**

- (i) closed-form score skewness — **blocked** (needs per-unit scores; the
  Jeffreys term and the excluded outer log-determinant remove them).
- (iv) ABC — **blocked** (needs per-unit empirical influence, same
  structural cause as (i), plus curvature of a least-favorable family).
- infinitesimal jackknife — **blocked** for the same reason as (i)/(iv), and
  in any case jackknife-adjacent and out of scope without separate approval.
- (ii) bootstrap-distribution skewness — **not blocked**, computable today,
  but its equivalence to the canonical $a$ is **UNVERIFIED** here; recommend
  it only as a zero-cost exploratory diagnostic (is a nonzero acceleration
  plausible at all in a given cell?), never as the basis of a covered-interval
  claim.
- (iii) parametric perturbation — **not blocked**, and grounded in the
  quantity $a$ is actually defined to be (the standardized SE-vs-$\theta$
  derivative), because it treats the whole MSPL refit as a black box, which
  is exactly the operation the existing 6,000,000-refit campaign already
  performs at scale. This is the recommended route.

Justification for preferring (iii) over (ii): (ii) is cheap but is a proxy
for a different (related but not identical) quantity, with no citation found
in this pass that establishes the needed asymptotic equivalence; using it to
license a coverage claim would risk repeating the pattern already on record
in this repository of a diagnostic being read as more than it is (cf. the
2026-05-31 rotation-variant-`psi` correction and the *n_boot = 10* coverage
correction noted in the project's own handover history — both cases of a
proxy quantity being over-interpreted). (iii) costs new simulation but
answers the question BCa's theory actually asks.

## Q4. Zero-compute or new simulation?

**The recommended route, (iii), requires NEW simulation — it cannot be
evaluated by re-expressing the existing 6,000,000 stored bootstrap refits.**
Route (iii) needs refits generated at *perturbed generating parameters*
$\theta_0\pm\delta$ in a neighbourhood of $\hat\theta$; the stored campaign
bootstraps were all generated at the single fitted parameter (that is what a
parametric bootstrap is), so no re-expression of the stored replicate vectors
recovers the SE-vs-$\theta$ derivative the route needs. A new, smaller
simulation (a smaller $B$ at each of a few perturbation points $\delta$,
followed by a finite-difference/regression step across those points) would
be required; sizing and design of that simulation is outside this read-only
slice's scope.

**Route (ii), by contrast, is exactly a zero-new-compute re-expression of
the existing archive**, confirmed by inspecting (headers only, per
instruction) the four raw files at
`/private/tmp/mspl-coverage-production-8b23cfd2-eqLdNa/`:

- `bootstrap-attempts-wide.csv` header includes
  `seed, status, convergence, objective, estimator_id, unconditional_redraw, b_fix_1, b_fix_2, b_fix_3, elapsed_seconds, objective_role`,
  keyed by `cluster, case_id, case_number, regime, link, outer_id, shard_id`
  — i.e. per-attempt bootstrap replicate values (`b_fix_1..3`, presumably
  the three target quantities under study) for every bootstrap draw under
  each outer fit.
- `outer-fit-rows.csv` has the identical `b_fix_1..3`/`status`/`convergence`
  columns but is keyed at the `outer_id` level only (one row per original,
  non-bootstrap fit) — this supplies $\hat\theta$ for computing both
  $\hat z_0$ (already unblocked, Q1) and $\hat a_{\text{boot-skew}}$.
- `endpoint-rows.csv` stores the already-computed interval endpoints per
  `method`/`target` (`truth, estimate, lower, upper, covers, available`) —
  useful for comparing a prospective BCa gate result against the six
  variants already measured, but not itself a source of new acceleration
  information.
- `profile-traces.csv` stores penalised-profile bracket/threshold traces —
  irrelevant to $z_0$/$a$.

None of the four files carries any per-unit (per-site/per-observation)
column — every key is at the `cluster/case/outer/shard/attempt` grain, never
below it. **This is an independent, file-level confirmation of the
constraint stated in the task brief**: there is nothing in the stored
campaign artifacts from which a per-unit score or influence value could be
recovered even in principle, which is exactly why routes (i), (iv), and the
IJ are blocked rather than merely inconvenient. So: $\hat z_0$ and
$\hat a_{\text{boot-skew}}$ can both be computed today, at zero new compute,
by re-expressing `bootstrap-attempts-wide.csv` (for the $B$ replicates per
cell/target) against `outer-fit-rows.csv` (for $\hat\theta$) — but per Q3,
that combination yields the **heuristic** BCa variant, not the theoretically
licensed one. A credible BCa gate measurement needs route (iii)'s new
simulation.

## Q5. Expected interaction with the two known failure regimes

**Regime 1 — widespread overcoverage (percentile 20/36, basic 14/36, normal
15/36, BC-normal 17/36 all failing on the high side in most of their
non-passing cells, per the campaign summary).** BCa's two corrections target
the *shape* of the bootstrap distribution — its median offset ($z_0$) and
how its spread scales with $\theta$ ($a$) — not its overall *dispersion*
relative to the true sampling distribution of $\hat\theta$. If, as the
overcoverage pattern suggests, the bootstrap replicate distribution is simply
too spread out relative to the true finite-sample distribution of $\hat\theta$
under this penalised, boundary-interacting estimator (a scale problem — e.g.
induced by the ridge/penalty terms behaving differently across bootstrap
draws than across the true repeated-sampling distribution), then **BCa would
be expected to be largely neutral to that overcoverage**: shifting and
re-stretching *which* percentiles of the same over-dispersed replicate
distribution get reported does not shrink the replicate distribution itself.
The modest gain already seen from bias-correction alone (BC-normal 17/36 vs.
plain normal 15/36) suggests BCa may nudge a few more cells over the gate by
fixing genuine skew/bias contamination that coexists with the dispersion
problem, but it is not expected to be a fix for overcoverage that is
fundamentally a variance-inflation issue. The penalised-profile method's
lead (24/36) — which does not resample the same joint-Laplace object at all
— is the stronger evidence that the overcoverage problem is more structural
than shape-correctable.

**Regime 2 — the cloglog x high-prevalence undercoverage pocket.** This is
the canonical case BCa's acceleration term was built for: a fitted quantity
pushed toward a boundary (high prevalence under `cloglog` compresses the
achievable linear-predictor range and skews the finite-sample distribution
of loadings/covariance parameters sharply), where the true standard error of
$\hat\theta$ changes rapidly as $\theta$ moves toward the boundary — i.e.
genuine, non-zero acceleration. **BCa (with a validly estimated $a$) would be
expected to help here specifically**, and more so than $z_0$-only correction,
because boundary-driven skew is exactly what DiCiccio & Efron's motivating
examples (and Efron 1987's own boundary/skewed-family illustrations) target.
The caveat is the crux of this whole memo: this expected benefit is
conditional on $a$ being estimated by a route that is actually licensed for
that job. $z_0$ alone (already unblocked) may recover some of the
undercoverage through bias correction, but the literature attributes the
larger share of the correction in boundary-skewed cases to $a$, not $z_0$ —
so realizing the expected benefit in this regime is the strongest argument
in this memo for funding route (iii)'s new simulation rather than settling
for the zero-cost heuristic (ii).

---

### Sources cited

- Efron, B. (1987). Better bootstrap confidence intervals. *Journal of the
  American Statistical Association*, 82(397), 171–185.
- Efron, B., & Tibshirani, R. J. (1993). *An Introduction to the Bootstrap*.
  Chapman & Hall. Ch. 14 (BCa), Ch. 21 (empirical influence functions), Ch.
  22 (ABC and other computational shortcuts).
- DiCiccio, T. J., & Efron, B. (1996). Bootstrap confidence intervals.
  *Statistical Science*, 11(3), 189–228.
- DiCiccio, T. J., & Romano, J. P. (1988). A review of bootstrap confidence
  intervals. *Journal of the Royal Statistical Society, Series B*, 50(3),
  338–354.
- DiCiccio, T. J., & Efron, B. (1992). More accurate confidence intervals in
  exponential families. *Biometrika*, 79(2), 231–245.
- Hall, P. (1992). *The Bootstrap and Edgeworth Expansion*. Springer. Ch. 3
  (iterated/double bootstrap).
- Booth, J. G., & Hall, P. (1994). Monte Carlo approximation and the
  iterated bootstrap. *Biometrika*, 81(2), 331–340.
- Jaeckel, L. A. (1972). The infinitesimal jackknife. Bell Labs Memorandum
  (cited via Efron & Tibshirani 1993, ch. 21, for the IJ construction).

Page/section numbers above are given to the precision I could confidently
recall; any marked **UNVERIFIED** in the body should be checked against the
primary source before being relied on for an implementation decision.
