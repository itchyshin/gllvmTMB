# Design 109 — Bound tightness versus parameter recovery in the binomial VA objective

Status: analysis note (research-only). No package behaviour is claimed or changed.
Scope: `inst/tmb/gllvmTMB_va_r3.cpp`, `family == 1` (binomial-logit),
`eval_method ∈ {0 = Gauss-Hermite, 1 = Jaakkola-Jordan/Pólya-Gamma}`.
Provenance markers: **PROVED** (derived here), **KNOWN** (literature, recalled — verify
before publication), **AGENT-INFERRED** (my inference, not proved), **CONJECTURE**.

---

## Question

Holding engine, data, seeds, optimiser and starting values fixed and changing only the
evaluator, the *looser* bound (JJ) recovers the true `Sigma_B = Lambda Lambda'` better
than the *tighter* one (GH) on 20 of 20 paired seeds. Optimiser and starting-value
artefacts have been cleared: cross-evaluating gives `f_GH(theta_JJ) < f_GH(theta_GH)` on
6/6 seeds, i.e. GH genuinely found a better GH optimum.

Four questions:

1. Is there a principled reason a looser bound gives better point recovery of `Sigma_B`?
2. What is the sign and monotonicity, in `v`, of the JJ gap `g(mu, v)`, and what does
   maximising `-n(E + g)` instead of `-n E` do to the fitted `v` and hence to `Lambda Lambda'`?
3. Is "tighter bound ⇒ better parameter estimates" a theorem, folklore, or false?
4. What accuracy claim is honestly supportable?

**Short answer.** (1) Yes, and the reason is exact and elementary: the bias of a
bound-maximiser depends on the **gradient** of the gap, not its **level**. Tightness is a
level statement; bias is a derivative statement; no inequality connects them. (2) The JJ
gap is zero at `v = 0` and increasing in `v`, so `-n g` is literally a **penalty on the
latent variance**, hence a **shrinkage penalty on `Lambda`**. (3) False in general, with a
constructive counterexample, and known-false in the literature. (4) The proposed claim is
not supportable and one half of it is contradicted by our own timings.

**One correction to the brief up front.** The brief offers, as a candidate mechanism, that
JJ's over-estimate of `E[softplus]` acts as "an inflation of the fitted latent variance
that partially cancels VA's known variance shrinkage." **The sign is backwards.** The JJ
gap enters the objective as `-n g(mu, v)` with `g` increasing in `v`; it is a *penalty* on
`v`, not an inflation of it. JJ makes the fitted variational covariance `S_i` **smaller**
than GH's, not larger — it makes VA's posterior-variance under-dispersion *worse*. What it
partially cancels is a different, opposite-signed quantity: the **inflation of the
loadings** that follows from under-stated `S_i`. Conflating `S_i` (variational posterior
variance) with `Sigma_B` (prior/between-unit covariance) is the trap in this problem, and
the whole result turns on keeping them apart.

---

## Setup and notation

From the template (lines 214–354). Prior `z_i ~ N(0, I_q)` — the KL at line 262 is against
the standard normal, so **all scale lives in `Lambda`**, and `Sigma_B = Lambda Lambda'`
(line 228) is a *derived* quantity, not a free parameter.

Linear predictor and its variational moments (lines 295–313):

    eta_it   = x_it' beta + lambda_t' z_i
    mu_it    = x_it' beta + lambda_t' m_i
    v_it     = lambda_t' S_i lambda_t = || L_i' lambda_t ||^2 ,   S_i = L_i L_i'

Objective (lines 319–354), with `n_it` trials:

    ELBO(theta, {m_i, S_i}) = sum_{i,t} [ c_it + y_it mu_it - n_it Psi(mu_it, v_it) ]
                              - sum_i KL( N(m_i, S_i) || N(0, I) )
    KL_i = 0.5 ( tr S_i + m_i'm_i - logdet S_i - q )

Write `phi(x) = log(2 cosh(x/2))`, so that

    softplus(x) = log(1 + e^x) = phi(x) + x/2 ,
    phi'(x)     = (1/2) tanh(x/2) ,
    phi''(x)    = (1/4) sech^2(x/2) = sigma(x)(1 - sigma(x)) = sigma'(x) .

The two evaluators are then, with `eta ~ N(mu, v)` and `xi = sqrt(mu^2 + v)`:

    Psi_GH(mu, v) = E[ phi(eta) ] + mu/2                       (lines 45–79)
    Psi_JJ(mu, v) = phi(xi)      + mu/2                        (lines 96–113)

`Psi_GH` is the exact expectation up to quadrature error; the small-`v` branch at lines
63–66 is its heat-kernel expansion, and the JJ small-`xi^2` branch at lines 105–110 is the
Taylor series of `phi`. Both are numerically faithful to the closed forms above, so the
mathematics below applies to what the code actually computes.

Define the **JJ gap**

    g(mu, v) := Psi_JJ(mu, v) - Psi_GH(mu, v) = phi(sqrt(E[eta^2])) - E[phi(eta)] .

Two derived scalars will do all the work:

    Psi_mu := d Psi / d mu     ("the fitted mean function")
    w      := 2 * d Psi / d v  ("the working weight")

For the two evaluators, with `lambda_JJ(xi) := tanh(xi/2) / (2 xi)`:

| | `Psi_mu` | `w = 2 Psi_v` |
|---|---|---|
| GH | `E[sigma(eta)]` | `E[sigma'(eta)]` |
| JJ | `1/2 + lambda_JJ(xi) mu` | `lambda_JJ(xi)` |

(GH's `Psi_v = (1/2) E[phi''(eta)]` is Price's theorem / the heat equation
`∂_v E[f] = (1/2) E[f'']`; JJ's follows from `∂ phi(xi)/∂ v = phi'(xi)/(2 xi)`.)

**Stationarity conditions.** Differentiating the ELBO (exact, both evaluators):

    (S)  S_i^{-1} = I + sum_t n_it w_it lambda_t lambda_t'
    (M)  m_i      = sum_t r_it lambda_t ,          r_it := y_it - n_it Psi_mu,it
    (L)  sum_i r_it m_i = ( sum_i n_it w_it S_i ) lambda_t

**PROVED.** These three lines contain the entire mechanism. (S) says the working weight
`w` sets the variational precision. (L) says the loadings solve a
*score = shrinkage × loading* equation whose shrinkage matrix is `sum_i n_it w_it S_i`.
The evaluator enters only through `Psi_mu` and `w`.

---

## The JJ gap g(mu, v)

Let `h(u) := phi(sqrt(u))` for `u >= 0`, so `Psi_JJ = h(mu^2 + v) + mu/2` and
`Psi_GH = E[h(eta^2)] + mu/2`. Then

    g(mu, v) = h(E[eta^2]) - E[h(eta^2)]

is exactly the **Jensen gap of the concave function `h` applied to `eta^2`**.

**(G1) Non-negativity and exactness at `v = 0` — PROVED.** `h` is concave on `u >= 0`
(this *is* the Jaakkola–Jordan construction: their bound is the tangent line to `h` in
`u = x^2`). Jensen gives `g >= 0`. At `v = 0`, `eta^2` is degenerate and `g = 0`.
Equivalently, the tangent-line form `T_xi(x) = phi(xi) + (lambda_JJ(xi)/2)(x^2 - xi^2)`
satisfies `phi <= T_xi` pointwise, and `xi^2 = E[eta^2]` is exactly the choice that kills
the linear term — which is why the code needs no separate variational `xi`.

**(G2) The `v`-derivative — PROVED.**

    ∂g/∂v = (1/2) [ lambda_JJ(xi) - E[sigma'(eta)] ] ,   xi = sqrt(mu^2 + v).

There is a clean **pointwise** inequality behind this:

    sigma'(x) <= lambda_JJ(x)   for all x
    ⟺ (1/4) sech^2(x/2) <= tanh(x/2)/(2x)
    ⟺ |x| <= 2 sinh(|x|/2) cosh(|x|/2) = sinh|x|      ✔ (equality only at x = 0)

So the JJ working weight dominates the *pointwise* logistic curvature everywhere.

**(G3) The slope at `v = 0` — PROVED, and this is the sharpest single result here.**
Expanding both sides to first order in `v`:

    ∂g/∂v |_{v=0} = h'(mu^2) - (1/2) sigma'(mu)
                  = tanh(mu/2)/(4 mu) - 1/(8 cosh^2(mu/2))
                  = ( sinh(mu) - mu ) / ( 8 mu cosh^2(mu/2) )   >= 0,

with **equality if and only if `mu = 0`**, and strictly increasing in `|mu|`.

This is the load-bearing formula of the note. It says: **the JJ gap's dependence on the
latent variance vanishes exactly at balanced prevalence (`p = 1/2`) and grows with
prevalence imbalance.** Any real effect attributable to the JJ gap must therefore scale
with `|mu|`. That is a falsification handle (see the last section).

**(G4) Large-`v` behaviour — PROVED.** `phi(x) = |x|/2 + log(1 + e^{-|x|})`, so with `mu`
fixed and `v -> infinity`, `Psi_JJ ≈ sqrt(v)/2 + mu/2` while
`Psi_GH ≈ E|eta|/2 + mu/2 ≈ sqrt(v/(2 pi)) + mu/2`. Hence

    g(mu, v) ~ ( 1/2 - 1/sqrt(2 pi) ) sqrt(v) ≈ 0.1011 sqrt(v)  ->  infinity,

increasing and unbounded in `v`.

**(G5) Global monotonicity in `v` — AGENT-INFERRED, not proved.** I can set the problem up
exactly but not close it. Let `H(mu, v) = h(mu^2 + v)` and `Phi(mu, v) = E[phi(eta)]`.
`Phi` solves the heat equation `∂_v Phi = (1/2) ∂_mu^2 Phi` with initial data `phi(mu)`;
and

    ∂_v H - (1/2) ∂_mu^2 H = -2 mu^2 h''(mu^2 + v) =: s(mu, v) >= 0 ,

so `H` is a **supersolution** with the same initial data — which re-proves (G1) by the
parabolic comparison principle, elegantly. The gap `D = H - Phi` then solves an
inhomogeneous heat equation with **non-negative source `s` and zero initial data**, so
`D >= 0` by Duhamel. Differentiating, `u := ∂_v D` solves the same equation with source
`∂_v s = -2 mu^2 h'''` and initial data `u(mu, 0) = s(mu, 0) >= 0`. Since `h''' > 0` for
large argument (`h'(u) ~ u^{-1/2}/4`), the source term for `u` is **not** sign-definite,
and the comparison principle does not close the argument.

What is established: `∂g/∂v >= 0` at `v = 0` (G3), `∂g/∂v > 0` asymptotically (G4), and
`g >= 0` everywhere with `g(mu, 0) = 0` (G1). What is not established: monotonicity at
intermediate `v`. **CONJECTURE:** `∂g/∂v >= 0` for all `mu, v >= 0`, equivalently
`lambda_JJ(sqrt(mu^2+v)) >= E[sigma'(eta)]`. This is a two-variable scalar inequality and
is checkable in a few lines of deterministic quadrature — no simulation, no fitting. **It
should be checked before any of this is published**, because most of what follows uses it.

---

## Effect on the fitted latent variance

Take (G5) as holding (it is proved at the endpoints). Then `w_JJ = lambda_JJ(xi)` exceeds
`w_GH = E[sigma'(eta)]` at matched `(mu, v)`, and (S) gives immediately

    S_i^{-1}(JJ) = I + sum_t n_it w_it^{JJ} lambda_t lambda_t'
                ⪰ I + sum_t n_it w_it^{GH} lambda_t lambda_t' = S_i^{-1}(GH)

i.e. **`S_i(JJ) ⪯ S_i(GH)` in the Loewner order — JJ's fitted variational covariance is
uniformly smaller.** PROVED given (G5), at matched `theta` (the full result is a fixed
point, since `w` depends on `v` which depends on `S`, but the map `w ↑ ⇒ S ↓` is monotone
and the direction survives).

This is worth stating flatly because it kills the brief's candidate mechanism:

> **The looser bound does not inflate the fitted latent variance. It deflates it.**
> JJ makes VA's best-known pathology — under-estimation of posterior variance
> (**KNOWN**: Blei, Kucukelbir & McAuliffe 2017; Giordano, Broderick & Jordan 2018;
> Turner & Sahani 2011) — *strictly worse*, not better.

The same inequality has a second reading through `Psi_mu`. Near `mu = 0`,

    Psi_mu^{JJ} - 1/2 ≈ mu · lambda_JJ(sqrt(v))
    Psi_mu^{GH} - 1/2 ≈ mu · E[sigma'(sqrt(v) Z)]

so JJ's fitted mean function is **steeper** — it attenuates less for latent uncertainty.
Both channels say the same thing in different words: **JJ behaves as if the latent
variance were smaller than it is. It systematically under-corrects for latent
uncertainty.** That is what the extra looseness *is*, mechanically.

---

## Effect on Sigma_B

### The general principle: bias tracks the gap's gradient, not its level

Let `F_b(theta) = l(theta) - G_b(theta)` be any lower bound on a target `l`, with gap
`G_b >= 0`. Let `theta_b = argmax F_b` and `theta* = argmax l`. First-order conditions give
`∇l(theta_b) = ∇G_b(theta_b)`, and Taylor-expanding about `theta*`:

    theta_b - theta*  ≈  [ -∇^2 l(theta*) ]^{-1} ∇G_b(theta*)                (★)

**PROVED, and it is the answer to question 1.** The displacement of the bound-maximiser
depends on `∇G_b`, **not** on `G_b`. Two immediate corollaries:

- A bound with a *constant* gap — however enormous — returns the **exact** maximiser.
- Between two bounds `G_1 <= G_2` pointwise, nothing whatsoever follows about
  `‖∇G_1‖` versus `‖∇G_2‖`. Constructive counterexample: `G_1(theta) = eps + a'theta`,
  `G_2(theta) = C` with `C` large. `G_1 < G_2` everywhere, yet `G_1` biases the estimate by
  `a` and `G_2` biases it by zero.

So "tighter ⇒ better recovery" is not merely unproved; it is **false as stated**, for
reasons that require no probability theory at all.

Now apply (★) to our two objectives. Let `F_GH` and `F_JJ` be the *profiled* objectives
(inner-maximised over `{m_i, S_i}`). Both are lower bounds on the true marginal
log-likelihood `l`. Write

    G_GH(theta) = l - F_GH  =  sum_i KL( q_i^GH || p(z_i | y_i; theta) )     (the VA gap)
    G_JJ(theta) = l - F_JJ  =  G_GH(theta) + Delta(theta),   Delta >= 0.

By the envelope theorem, up to a second-order inner term
`delta_inner = F_GH(theta) - ELBO_GH(theta, omega*_JJ) >= 0` which vanishes to first order
when the two inner optima are close:

    Delta(theta)  ≈  sum_{i,t} n_it * g( mu_it(theta), v_it(theta) ) .

Then

    theta_GH - theta* ≈ I_n^{-1} ∇G_GH ,
    theta_JJ - theta* ≈ I_n^{-1} ( ∇G_GH + ∇Delta ) .

**Therefore JJ recovers `Sigma_B` better than GH if and only if `∇Delta` points opposite to
`∇G_GH` along the `Sigma_B` directions, and does not overshoot.** That is the whole
explanation. It is not an anomaly; it is a two-wrongs-cancel arithmetic identity waiting to
be checked in the right coordinates.

### Sign of the JJ term: Delta is a shrinkage penalty on Sigma_B — PROVED near the origin

Scale `Lambda -> c Lambda`. Then `v_it = lambda_t' S_i lambda_t` scales as `c^2`. Since
`g` is increasing in `v` (proved at `v = 0` by (G3), and asymptotically by (G4)),

    ∂ Delta / ∂ c  >  0    whenever some mu_it ≠ 0.

**The JJ objective is the GH objective minus a penalty that increases with the magnitude of
`Sigma_B`.** It is a *regulariser*, in the exact technical sense: `F_JJ = F_GH - Delta` with
`Delta` a non-negative, increasing function of `‖Sigma_B‖`. The strongest clean version:
at `Lambda = 0` the two objectives agree in value, and

    ∂(F_GH - F_JJ)/∂v |_{v=0}
        = sum_{i,t} n_it ( sinh(mu_it) - mu_it ) / ( 8 mu_it cosh^2(mu_it/2) ) > 0

unless every linear predictor sits exactly at `p = 1/2`. **PROVED.**

The stationarity equations say the same thing without any appeal to gaps. In (L),

    lambda_t = ( sum_i n_it w_it S_i )^{-1} sum_i r_it m_i ,

both sides move JJ's loadings **down** relative to GH's:

- *Denominator.* In the scalar `q = 1` case, `s_i = 1/(1 + n sum_t w_it lambda_t^2)`, so
  `w_it s_i = 1 / ( 1/w_it + n sum_t lambda_t^2 )`, which is **increasing in `w`**. JJ's
  larger `w` therefore yields a larger shrinkage factor even after `S_i` shrinks in
  response. **PROVED (scalar case).**
- *Numerator.* JJ's steeper `Psi_mu` (less attenuation) means a *smaller* `lambda` suffices
  to reproduce the observed between-unit heterogeneity — the standard attenuation
  arithmetic run backwards. **AGENT-INFERRED** (sign argument, not a theorem, because
  `r_it` and `m_i` are jointly determined).

Both channels agree:

> **Prediction P1 (sharp, falsifiable): `‖Sigma_B(JJ)‖ < ‖Sigma_B(GH)‖`, seed by seed.**

### What the empirical result therefore implies about GH

Combining P1 with the reported fact that JJ recovers `Sigma_B` better on 20/20 paired
seeds forces one conclusion:

> **GH — the exact-expectation, tightest available VA objective — must be
> *over-estimating* `Sigma_B`.** JJ's extra shrinkage moves it back toward the truth.

There is a coherent mechanism for GH over-estimating `Sigma_B` here, and it runs through
(S) and (L). Gaussian VA under-disperses the posterior: `S_i` is smaller than the true
`Var(z_i | y_i)` (**KNOWN**). In (L) the shrinkage matrix is `sum_i n_it w_it S_i`. An
under-stated `S_i` under-states the shrinkage, so `lambda_t` must come out **too large** to
balance the equation, and `Sigma_B = Lambda Lambda'` is inflated. JJ's larger `w` partially
restores the missing shrinkage. **AGENT-INFERRED** — the exact marginal score is
`sum_i E_{p(z|y)}[(y - n sigma(eta)) z_i]`, not a residual-minus-curvature form, so this is
a sign heuristic, not a theorem. But it is the only mechanism I can construct that is
consistent with both P1 and the 20/20 observation, and it makes P1 testable.

Note also the statistics: 20/20 on a paired sign test is `p ≈ 2e-6`. This is a
**systematic shift**, exactly what a deterministic bias-cancellation produces, and *not*
what noise produces. But a systematic shift in the right direction says nothing about
whether the shift is the *right size* — an over-shrinking evaluator that overshoots the
truth by less than GH overshoots it in the other direction still wins 20/20. That
distinction is the difference between a method and a coincidence.

---

## Is tighter-is-better a theorem?

**It is folk belief, and it is false in general.** Three levels of answer.

**1. False as stated — PROVED.** By (★), the bias of a bound-maximiser is
`[-∇^2 l]^{-1} ∇G_b`. Pointwise ordering of gaps (`G_1 <= G_2` everywhere) implies nothing
about the ordering of `‖∇G_1‖` and `‖∇G_2‖` at the optimum. The counterexample above is
two lines long. A perfectly flat gap of size `10^6` recovers the MLE exactly; a gap of size
`10^{-6}` with a steep slope in one coordinate biases that coordinate. Tightness is a
`sup`-norm statement about levels; estimation bias is a statement about derivatives. There
is no inequality relating them, and there cannot be.

**2. What *is* true — PROVED.** *Uniform* tightness does control estimation error. If
`sup_theta G_b(theta) <= eps` and `l` is `alpha`-strongly concave near `theta*`, then
`l(theta*) - l(theta_b) <= 2 eps` and hence
`‖theta_b - theta*‖ <= sqrt(4 eps / alpha)`. Note this is a **uniform**, not a
**pointwise-comparative**, hypothesis: it says a bound that is tight *everywhere* is safe.
It does *not* say that, of two loose bounds, the tighter one is safer. Our situation is the
second, not the first: `G_GH` is not small — it is the Gaussian-VA KL gap, `O(1)` per unit,
and it does not vanish as `N -> infinity` with `T` fixed.

**3. Known-false in the literature — KNOWN (recalled from knowledge; verify citations
before publication).**

- **Rainforth, Kosiorek, Le, Maddison, Igl, Wood & Teh (2018), "Tighter Variational Bounds
  are Not Necessarily Better", ICML.** The canonical title for exactly this claim. Their
  mechanism differs from ours (they show the IWAE bound's tightening destroys the
  signal-to-noise ratio of the *inference network's* gradient estimator, `SNR ~ 1/sqrt(K)`),
  but the conclusion — that the folk implication is false — is established.
- **Turner & Sahani (2011), "Two problems with variational expectation maximisation for
  time-series models."** Shows that the VB bound's bias systematically and structurally
  distorts *parameter* estimates, and that the distortion does not simply shrink with a
  tighter bound. This is the closest prior in spirit to what we are seeing.
- **Blei, Kucukelbir & McAuliffe (2017, JASA).** VI systematically underestimates posterior
  variance. **Giordano, Broderick & Jordan (2018, JMLR)**, linear-response VB: MFVB means
  can be accurate while covariances are badly wrong, and a *correction* is required.
- **Alemi, Poole, Fischer, Dillon, Saurous & Murphy (2018), "Fixing a Broken ELBO";
  Cremer, Li & Duvenaud (2018), "Inference Suboptimality in VAEs"; Domke & Sheldon (2018),
  "Importance Weighting and Variational Inference".** All make the same decoupling point:
  the ELBO's *value* and the quality of the thing you actually care about are different
  objects.
- **Breslow & Clayton (1993, JASA)** for the classic result that approximate-likelihood
  methods bias **variance components** for binary data — the relevant precedent that
  approximation error in this model class lands squarely on the covariance parameters.
  **Hui, Warton, Ormerod, Haapaniemi & Taskinen (2017, JCGS)** for VA in GLLVMs specifically;
  **Ormerod & Wand (2012, JCGS)** and **Hall, Ormerod & Wand (2011, Statist. Sinica)** for
  Gaussian VA in GLMMs. **Jaakkola & Jordan (2000, Stat. & Comput.)** for the bound;
  **Polson, Scott & Windle (2013, JASA)** for its Pólya-Gamma identity.
- The "two wrongs make a right" pattern also has precedent in the h-likelihood/PQL
  literature, where adding a *correct* higher-order correction to a biased approximation
  can make the estimate worse because it removes a cancellation.

**Reframing.** Our result is therefore **not an anomaly**. It is the expected behaviour of
a bound family whose gaps differ in curvature, in a model where the approximation error is
known to concentrate on the covariance parameters. The honest headline is not "JJ is
better"; it is **"bound tightness did not predict recovery, as theory says it need not."**

---

## Verdict on the accuracy claim

**The claim "this engine is the best and potentially fastest in relation to accuracy" is
not supportable. Do not make it, in any hedged form.** Taking a hostile reviewer's seat:

**(a) The speed half is contradicted by our own data.** Our measurements say VA is *slower*
than Laplace at every tested `n`, with worse scaling (`n^1.9`–`n^2.7` versus `n^0.98`).
A claim containing the word "fastest" against measurements showing "slower at every tested
`n`, and diverging" is not a hedge — it is a misstatement. "Potentially fastest" is worse
than "fastest", because the reviewer reads "potentially" as an unsupported claim wearing a
hat. Either it is faster (measured, with the ladder shown) or it is not. Here it is not.

**(b) The accuracy half rests on one cell.** 20 seeds, one family (binomial-logit), one
estimand (`Sigma_B`), one DGP, one `(N, T, q)`, one prevalence regime. And in a template
whose own header states it "supplies no public fitting method, marginal likelihood, rank
selection, REML adjustment, or TMB random-parameter path." A single-cell result cannot
carry a surface-wide superlative. "Best" also has no referent: best against *what*?
Laplace, adaptive GQ and MCMC were not compared on this estimand in this design.

**(c) The finding is evidence against us, not for us.** Read plainly: *our most principled,
tightest evaluator recovers `Sigma_B` worst.* The derivation above says why — the VA
objective carries a systematic, sign-identified bias in `Sigma_B`, and the looser bound's
second error happens to cancel part of the first. A reviewer will write: "The authors do
not demonstrate accuracy. They demonstrate that their best-justified objective is biased,
and select the variant whose additional error offsets it on this data-generating process."
That reading is correct, and we should reach it before the reviewer does.

**(d) The cancellation is predicted to be *unstable*, by our own algebra.** (G3) says the JJ
gap's `v`-slope is exactly zero at `mu = 0`. So at balanced prevalence the mechanism
switches off and the advantage must disappear. A calibration that depends on prevalence,
`n`, `T`, `q` and true `‖Sigma_B‖` is a **coincidence at a design point**, not a property of
the method — until a sweep shows otherwise.

**(e) The cross-evaluation test cleared the optimiser and convicted the objective.**
`f_GH(theta_JJ) < f_GH(theta_GH)` on 6/6 is good work and it removes the boring
explanation. But note precisely what it establishes: GH's *optimiser* is fine, therefore the
problem is GH's *objective*. That evidence is neutral-to-negative for an accuracy claim
about the VA engine as a whole.

### What IS supportable

1. **A scoped descriptive statement.** "In a paired 20-seed binomial-logit study at
   [stated `N`, `T`, `q`, prevalence, true `Sigma_B`], the Jaakkola–Jordan evaluator
   attained lower `Sigma_B` error than Gauss–Hermite on 20/20 seeds (sign test
   `p ≈ 2e-6`)." Facts, with the design attached, and no generalisation.
2. **The negative methodological result** — which is the genuinely publishable part:
   "bound tightness did not translate into better `Sigma_B` recovery, consistent with the
   known failure of the tighter-is-better implication (Rainforth et al. 2018; Turner &
   Sahani 2011)."
3. **The mechanism**, *conditional on* P1 and the signed-bias check below passing:
   "the JJ gap acts as a shrinkage penalty on `‖Sigma_B‖` that partially offsets the
   Gaussian-VA objective's upward bias in the loadings."
4. **The honest speed statement**: VA is slower than Laplace across the tested range and
   scales worse. If VA has a role, the argument must be something other than speed —
   e.g. a specific inference product Laplace does not deliver — and that argument has not
   been made here.

### What is NOT supportable

"Best", "fastest", "most accurate", "best accuracy-per-second", "state of the art", and any
sentence in which JJ's win is presented as a *property of the engine* rather than as a
bias-cancellation observed at one design point. Also not supportable: any claim that the
looser bound gives better **uncertainty** quantification — the derivation says the opposite
(`S_i(JJ) ⪯ S_i(GH)`, so JJ's posterior variances are *more* under-dispersed). If JJ were
ever adopted, standard errors would need an explicit warning, not a promotion.

---

## What would falsify this

Each item is cheap, deterministic where possible, and the predicted direction is stated so
a null or reversed result is unambiguous. Items 1–3 use quantities the template already
`REPORT`s.

**1. Check the conjecture (G5) first — no fitting required.** Evaluate
`lambda_JJ(sqrt(mu^2+v)) - E[sigma'(eta)]` on a grid of `(mu, v)` by deterministic
quadrature. *Prediction: non-negative everywhere.* If it goes negative anywhere in the
region the fits actually visit, the monotonicity premise fails and everything downstream of
(G5) must be withdrawn. **This is the gate; do it before anything else.**

**2. Report the SIGNED bias, not the loss.** The study reports "recovers better", which is a
loss. Report `mean(trace(Sigma_B_hat) - trace(Sigma_B))` and the elementwise signed bias for
each evaluator. *Prediction (P1 + mechanism):
`trace(Sigma_B_hat, GH) > trace(Sigma_B) >~ trace(Sigma_B_hat, JJ)`, and
`trace(Sigma_B_hat, JJ) < trace(Sigma_B_hat, GH)` on every one of the 20 seeds.*
**If JJ's trace exceeds GH's on any appreciable fraction of seeds, the entire shrinkage
account in this note is wrong and should be discarded.** This is the single most
informative number in the whole exercise and it costs nothing — the fits already exist.

**3. Compare `S_flat` directly.** *Prediction: `S_i(JJ) ⪯ S_i(GH)` unit by unit, and
`v_by_obs(JJ) < v_by_obs(GH)`.* Both are already reported (lines 363–366). A reversal here
falsifies the working-weight inequality empirically even if (G5) holds pointwise.

**4. Prevalence sweep — the mechanism's own kill switch.** Set intercepts so every trait
sits at `p = 1/2` (`mu ≈ 0`), holding everything else fixed. By (G3), `∂g/∂v|_{v=0} = 0`
there. *Prediction: the JJ–GH difference in `Sigma_B` collapses toward zero and the 20/20
advantage disappears.* Then sweep prevalence outward; *the advantage should grow with
`|mu|` like `(sinh mu - mu)/(8 mu cosh^2(mu/2))`.* **If the advantage persists undiminished
at balanced prevalence, the JJ gap is not the cause and this note is refuted.**

**5. The ridge control — the experiment that decides "method" versus "coincidence".** Add an
explicit penalty `c * trace(Lambda Lambda')` to the **GH** objective and tune `c`.
*Prediction: some `c` reproduces JJ's `Sigma_B` recovery.* If it does, JJ has **no special
status** — it is an implicit, uncontrolled ridge, and the honest conclusion is "the VA
objective needs a penalty on `Sigma_B`", which is a different (and better) paper. If no `c`
reproduces it, JJ is doing something a scalar ridge cannot, and that is worth reporting.

**6. The Böhning ordering test — the signature of a coincidence.** Add a third evaluator:
the Böhning bound, `w = 1/4` uniformly, which is looser than JJ (since
`lambda_JJ(xi) <= 1/4` for all `xi`, with equality only at `xi = 0`). Shrinkage should then
order strictly: **GH < JJ < Böhning**. *Prediction: Böhning over-shrinks and lands past the
truth, so recovery error is **U-shaped** in looseness.* A U-shape proves the win is a
calibration accident at a design point, not "looser is better". A monotone
"looser-is-always-better" ordering would instead falsify the shrinkage account and demand a
different explanation. This is ~5 lines in the same template and it is, in my view, the
highest-value single addition to the study.

**7. Scale/shape decomposition.** Split `Sigma_B` error into scale (trace) and shape
(correlation matrix). *Prediction: JJ wins almost entirely on scale and roughly ties on
shape*, because the mechanism is a magnitude penalty. If JJ wins on *shape* too, something
other than shrinkage is operating.

**8. The `T` asymptotic.** The Gaussian-VA gap per unit shrinks as the number of traits `T`
grows (more information per unit ⇒ more Gaussian posterior); it does **not** shrink with
`N` at fixed `T`. *Prediction: the JJ advantage shrinks as `T` grows with `N` fixed.* If it
persists or grows with `T`, the "GH's VA gap is the thing JJ cancels" story is wrong.

**9. Quadrature adequacy — the boring check that must be done anyway.** Confirm the GH
result is stable in the number of nodes (e.g. 20 vs 50 vs 100) and that the `v <= 1e-6`
polynomial branch (lines 68–78) is not being hit at the optimum. *Prediction: no change.*
If GH moves with node count, "GH is effectively exact" is false and the comparison is
between two approximations, not between exact and bound. Cheap, and a reviewer will ask.

---

### Honest statement of what I could not do

I could not prove global monotonicity of `g` in `v` (item G5); I proved it at `v = 0`, in
the `v -> infinity` limit, and established the exact PDE structure that makes it plausible,
but the parabolic comparison argument does not close because `h''' > 0` at large argument.
Everything from "Effect on the fitted latent variance" onward is conditional on that
inequality, which is why it is falsification item 1.

I also could not *prove* the direction of GH's `Sigma_B` bias. The forced-conclusion
argument ("if P1 holds and JJ wins 20/20, GH must over-estimate") is logically sound but
depends on P1, and the supporting mechanism (under-dispersed `S_i` under-states the
shrinkage in (L)) is a sign heuristic, not a theorem. **The study already has the data to
settle it in one line — report the signed trace bias.** Until that number is in hand, this
note explains a *direction*, not a *magnitude*, and none of it should appear in any
user-facing or public claim.
