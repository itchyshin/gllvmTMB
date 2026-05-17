# Design audit — per-trait link-residual variance for mixed-family extractors

**Date**: 2026-05-17
**Authors**: Boole + Fisher + Gauss (engine implications); Ada (orchestration)
**Triggered by**: maintainer 2026-05-17 in-flight discussion during M1-PR-B1 review.

This audit captures the design rationale for the **per-trait
link-residual variance** as implemented in
`link_residual_per_trait()` (`R/extract-sigma.R:99`). The
function returns the per-trait scalar added to the diagonal of
the latent-scale Σ when `link_residual = "auto"`. Current values:

| Family | Link residual $\sigma^2_d$ |
|---|---|
| `gaussian` (identity) | 0 |
| `binomial` (logit) | $\pi^2 / 3 \approx 3.290$ |
| `binomial` (probit) | $1$ |
| `binomial` (cloglog) | $\pi^2 / 6 \approx 1.645$ |
| `Poisson` (log) | $\log(1 + 1/\hat\mu_t)$ |
| `nbinom2` (log) | $\psi_1(\hat\phi_t)$ (trigamma) |
| `Gamma` (log) | $\psi_1(1/\hat{\text{disp}}_t)$ |
| `Tweedie` (log) | $\log(1 + \hat\phi_t \hat\mu_t^{p-2})$ |
| `Beta` (logit) | $\psi_1(a) + \psi_1(b)$ |
| `betabinomial` (logit) | $\psi_1(a) + \psi_1(b) + \pi^2/3$ |
| `delta_lognormal` | $\hat\sigma^2_{\text{logn}} + \pi^2/3$ |
| (others) | per family-registry table |

The split is **distribution-specific (binomial-family) +
observation-level (other families)**. This audit explains why,
revisiting the 2017 Nakagawa-Johnson-Schielzeth paper
(*J. R. Soc. Interface* 14: 20170213) and a 2026-05-15 email
from Roberto Cerina (Univ. Amsterdam) that surfaced a Jensen-
inequality bias in the paper's bias-corrected $1/(np(1-p))$
recommendation.

## §1 — Background: two candidate residual variances for binomial

The 2017 paper distinguishes two latent-scale residual
variances for binomial-logit GLMMs:

1. **Distribution-specific** $\sigma^2_d = \pi^2/3$ — the
   variance of the logistic distribution underlying the logit
   link. Constant; depends only on the link function.
2. **Observation-level** $\sigma^2_\epsilon = 1/(n p (1-p))$ —
   the delta-method approximation to the Gaussian-approximate
   variance of $\hat p$ on the logit scale. Depends on $n$ and
   $p$.

The 2017 paper recommends **observation-level** for univariate
$R^2$ / ICC reporting (Section 7 of the paper, esp. Table 2),
on the grounds that $\pi^2/3$ "pretends every dataset has the
same noise floor regardless of $n$ and $p$".

## §2 — Maintainer's reconsidered position (2026-05-17)

The maintainer (Shinichi Nakagawa, co-author of the 2017 paper)
revisited this decision during M1.4 review and concluded that
$\pi^2/3$ is the better default for multi-trait GLLVMs.

Reasons captured in conversation (Ada, 2026-05-17):

1. **Common scale across families**. The gllvmTMB
   vision-item-5 differentiator is latent-scale correlations on
   mixed-family fits. For correlations between traits to be
   interpretable as relationships among latent processes, every
   trait's residual must live on a comparable scale.
   - $\pi^2/3$ (logit), $1$ (probit), $\pi^2/6$ (cloglog) are
     link-defined constants — well-defined population properties.
   - $1/(np(1-p))$ varies with the sample's $n$ and $p$, so two
     binary traits at different prevalences would receive
     different residual allocations, distorting their implied
     correlation.

2. **Invariance to ascertainment**. Latent-scale heritability /
   repeatability / correlation is invariant to selective sampling
   that shifts $p$. Observation-scale is not. The de Villemereuil,
   Schielzeth, Nakagawa & Morrissey (2016, *Genetics*) framework
   for exact heritability on the data scale uses the latent-scale
   formulation as the primitive object.

3. **The "you can't observe the latent scale" objection**. Applies
   to every latent-variable model (factor analysis, IRT, SEM,
   GLMM). Not a real objection to the framework — the latent
   scale is a modeling construct, and the model + link function
   define it operationally.

## §3 — Roberto Cerina's finding (Jensen bias in the 2017 paper)

A 2026-05-15 email from Roberto Cerina (Asst. Prof., Univ. of
Amsterdam) to Paul Johnson identified a **technical error in the
2017 paper's bias-corrected $\sigma^2_\epsilon$ recommendation**
that's independent of the conceptual choice in §2.

### Setup

For a binomial-logit GLMM with random intercept
$b_j \sim \mathcal{N}(0, s_b)$, the residual variance on the
logit scale is, by the law of total variance:

$$s_{\text{res}} = E_b\!\left[\,\mathrm{Var}\!\left[\mathrm{logit}(p_i) \mid b_j\right]\right] \approx E_b\!\left[\,\frac{1}{n_i\, p_i\,(1-p_i)}\,\right]$$

where $p_i = \mathrm{logit}^{-1}(\alpha + b_j)$.

### The 2017 paper's recommendation

Replace $p_i$ with a 2nd-delta-method bias-corrected estimate
$\tilde p = \mathrm{logit}^{-1}(\alpha + \tfrac{1}{2}\sigma^2_\tau \cdot (\cdot))$
and plug into:

$$\hat s_{\text{res}} = \frac{1}{n_i\, \tilde p\,(1-\tilde p)}$$

### Roberto's diagnosis

This is **a function of an expectation**, not **an expectation
of a function**. Since $1/(p(1-p))$ is convex in $p$ on $(0,1)$,
Jensen's inequality gives

$$E_b\!\left[\frac{1}{p_i(1-p_i)}\right] \;\;\geq\;\; \frac{1}{E_b[p_i]\,(1-E_b[p_i])}$$

with strict inequality whenever $\mathrm{Var}_b[p_i] > 0$. **The
paper's plug-in formula systematically underestimates the true
residual variance.** The 2nd-delta-method bias correction fixes
Jensen for the link function $\mathrm{logit}^{-1}$ (which is
non-linear), but does not fix Jensen for the variance function
$1/(p(1-p))$ (which is also non-linear). Two distinct Jensens;
the paper handles only one.

Roberto's empirical observation: the per-observation average
$\frac{1}{N}\sum_i 1/(n_i \hat p_i (1-\hat p_i))$ gives "wildly
larger" values than the plug-in. This is precisely the bias gap
manifesting.

### Correct empirical estimator

Use the per-observation average across the fitted $\hat p_i$
values:

$$\hat s_{\text{res}} = \frac{1}{N} \sum_{i=1}^N \frac{1}{n_i\, \hat p_i\,(1-\hat p_i)}$$

This is the right empirical analogue of $E_b[\cdot]$ for the
fitted model, and it does not suffer from the Jensen bias of the
plug-in.

### Q2 (n_i handling) and Q3 (empirical comparison)

- **Q2**: per-observation $n_i$ is handled naturally by the
  empirical average (each observation contributes $1/(n_i \hat p_i(1-\hat p_i))$).
- **Q3**: the empirical average IS the "true" residual variance
  for the model + data, up to first-order delta-method
  approximation. The plug-in is biased downward.

## §4 — Why gllvmTMB sidesteps both issues

The current `link_residual_per_trait()` implementation uses
$\pi^2/3$ for binomial-logit (and analogous link-defined constants
for probit / cloglog). **The package does not compute
$1/(np(1-p))$ at all.** It therefore:

- (a) avoids the cross-family commensurability problem in §2 by
  using a common-scale constant for binomial;
- (b) avoids the Jensen-bias trap in §3 because there is no
  per-observation plug-in to mis-handle.

This is, retroactively, an additional reason to keep $\pi^2/3$
as the binomial default in `link_residual_per_trait()`.

## §5 — What this means for the M1 fixes

- **M1.6 `extract_repeatability` formula fix** (this PR): the
  fix is `vW = sd_W^2 + link_residual_per_trait(fit)`. For
  binomial traits this adds $\pi^2/3$ to the W-tier variance,
  which is the **correct latent-scale repeatability denominator**
  per Nakagawa & Schielzeth (2010) and consistent with the design
  in §2. **The fix does not rely on $1/(np(1-p))$ at any point**
  — Roberto's Jensen-bias finding does not affect us.
- **M1.3 / M1.4 extractor validations** (PR #153, merged): same
  argument. Both extractors use `link_residual_per_trait()` for
  the diagonal addition; no plug-in $1/(np(1-p))$ surface.
- **M1.7 / M1.8 follow-ups**: when bootstrap_Sigma's
  `link_residual = "auto"` propagation is fixed (M1.8), the
  same machinery applies — no exposure to the Jensen bias.

## §6 — Future opt-in (post-M1, design-doc territory)

A future small PR may add `link_residual = "observation"` as a
**third user option** alongside `"auto"` (current default) and
`"none"`:

- `"auto"` (default): distribution-specific for binomial-family
  + observation-level (existing $\log(1+1/\mu)$ etc.) for Poisson
  / NB / Gamma. Current behaviour.
- `"none"`: no addition. Raw $\Sigma_{\text{shared}} +
  \mathrm{diag}(\Psi)$. Existing.
- `"observation"`: **NEW**. For binomial-family, use the
  per-observation average $\frac{1}{N}\sum 1/(n_i \hat p_i(1-\hat p_i))$
  — Roberto's corrected estimator, not the 2017 paper's plug-in.
  For non-binomial: same as `"auto"`. Intended for univariate
  $R^2$ reporting where the data-scale interpretation matters.

This is a small future PR (~50 lines + design note). **Not in
M1 scope.** Logged for post-CRAN cycle or as a discrete
pre-CRAN PR if requested.

## §7 — Suggested actions for the literature

If Shinichi + Paul are inclined, this finding (§3) is publishable
as a brief technical note ("Correction to the bias-corrected
$\sigma^2_\varepsilon$ for binomial GLMMs") — short, technical,
useful for the literature. The fix is one-line algebra (plug-in
→ empirical average); the misimpression has presumably
propagated in derived work and the methods literature for the
last ~8 years. A correction note would:

- give the corrected estimator + a 1-paragraph proof
- show one worked example demonstrating the bias direction
  + magnitude
- credit Roberto for the diagnosis

This is an academic communication, not a gllvmTMB PR — flagged
here purely so the audit trail is complete.

## §8 — References

- Nakagawa S, Johnson PCD, Schielzeth H (2017). *The coefficient
  of determination $R^2$ and intra-class correlation coefficient
  from generalized linear mixed-effects models revisited and
  expanded.* J. R. Soc. Interface **14**: 20170213.
- Nakagawa S, Schielzeth H (2010). *Repeatability for Gaussian
  and non-Gaussian data: a practical guide for biologists.*
  Biol. Rev. **85**: 935–956.
- de Villemereuil P, Schielzeth H, Nakagawa S, Morrissey MB
  (2016). *General methods for evolutionary quantitative genetic
  inference from generalized mixed models.* Genetics
  **204**: 1281–1294.
- Cerina R (2026-05-15, personal communication to Paul Johnson),
  *Question on $R^2$ for binomial logit* — identifying the
  Jensen-inequality bias in the 2017 plug-in $\sigma^2_\varepsilon$.

## Cross-references in repo

- `R/extract-sigma.R:99` — `link_residual_per_trait()` (the
  function the design pivots on).
- `R/extract-repeatability.R:127` — M1.6 fix lands here.
- `docs/design/35-validation-debt-register.md` — register rows
  MIX-03..MIX-08, plus the (future) row for `link_residual =
  "observation"` opt-in.
- `tests/testthat/test-link-residual-15-family-fixture.R` —
  per-family link-residual correctness (already `covered`).
