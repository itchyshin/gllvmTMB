# Mathematical specification — ordinary Gaussian GLLVM, long format, one grouping level, `Sigma_unit = Lambda Lambda' + diag(psi)`

**Purpose.** A complete, self-contained mathematical statement of the model, sufficient to
implement it in Stan without ever reading `gllvmTMB`'s implementation. This document is an
**independent oracle**: it was derived only from published GLLVM / factor-analysis
formulations and from `gllvmTMB`'s *user-facing* design prose and generated roxygen
documentation. **No file under `src/` was read, and no R file that constructs a TMB
objective was read.** Sources are listed in §10; things that could not be pinned down
without reading the implementation are listed in §11 and must be resolved by
*measurement or maintainer statement*, not by inspection of the C++.

Author role: Noether (math-vs-specification alignment).
Date: 2026-08-03.

---

## 0. The one thing to read first — marginal vs. hierarchical

With `Sigma = Lambda Lambda' + diag(psi)` there are two formulations that induce the
**same marginal law for the observed data** but are **different probability models over
different variables**:

**(a) Marginal / integrated form.**

$$
u_\ell \;\sim\; \mathcal{N}_T\!\left(\mathbf{0},\; \Lambda\Lambda^\top + \Psi\right),
\qquad \Psi = \operatorname{diag}(\psi_1,\dots,\psi_T),
$$

with $u_\ell$ the only latent object. The joint density is over $(\theta, u)$ and contains
**two** density terms (data + one $T$-variate normal per unit).

**(b) Hierarchical / conditional-independence form.**

$$
z_\ell \sim \mathcal{N}_K(\mathbf{0}, I_K),
\qquad
q_\ell \sim \mathcal{N}_T(\mathbf{0}, \Psi),
\qquad
u_\ell = \Lambda z_\ell + q_\ell ,
$$

with $z_\ell$ and $q_\ell$ independent. The joint density is over $(\theta, z, q)$ and
contains **three** density terms (data + $z$ + $q$).

They agree marginally because $\operatorname{Var}(\Lambda z_\ell + q_\ell) =
\Lambda\Lambda^\top + \Psi$. They **do not** agree pointwise: (a) evaluated at a given
$u_\ell$ and (b) evaluated at a given $(z_\ell, q_\ell)$ are numbers on different sample
spaces, of different dimension ($T$ vs. $K+T$ per unit), and are not equal even when
$u_\ell = \Lambda z_\ell + q_\ell$.

### RESOLUTION (binding for this oracle)

> **A fixed-parameter joint-density check MUST use the HIERARCHICAL form (b).**

Three reasons, in decreasing order of force:

1. **It is the model the package's own user-facing prose defines.** The design prose
   states the reduced-rank term generatively on the *linear predictor*, not on a marginal
   covariance: $\eta_{it} = \mu_t + \boldsymbol\lambda_t^\top \mathbf{u}_{g(i)}$ with
   $\mathbf{u}_\ell \sim \mathcal{N}(\mathbf{0}, I_K)$
   (`docs/design/04-random-effects.md`, "Reduced-rank reparameterisation"), and the
   diagonal companion separately as an *additive* per-`(unit, trait)` effect
   $\eta_{it} = \cdots + v_{\ell t}$, $v_{\ell t}\sim\mathcal N(0,\psi_t)$ (same file,
   "Trait-diagonal $\Psi$"). The `lv` section writes the assembled predictor explicitly as
   $\eta_{it} = X_{it}\beta + \lambda_t^\top z_i + q_{it}$
   (`docs/design/01-formula-grammar.md` §"Predictor-informed latent-score means").
   $\Sigma = \Lambda\Lambda^\top + \Psi$ is described as what the engine *reports* /
   *implies*, i.e. a derived read-out (`extract_Sigma()`), not the sampling statement.
2. **A Laplace-based engine has no choice.** An objective built with
   `TMB::MakeADFun(random = ...)` is by construction a **joint** negative log-density over
   parameters *and* the random-effect vector, which is then integrated. Whatever the
   random-effect vector is, the objective evaluates a joint density of form (b)-type
   (data term plus one density per latent block). There is no marginal $u$ in the
   objective to compare against; the marginal $\Sigma$ appears only after integration.
   Therefore a *pointwise* joint-density comparison only exists in form (b).
3. **Form (a) silently loses the discriminating power we are buying.** The whole point of
   an independent oracle is to catch an error in *how the pieces are assembled* — a wrong
   $\Lambda$ orientation, a dropped or double-counted $\Psi$, a mis-indexed $z$, a
   variance-vs-SD slip in either block. Form (a) collapses $\Lambda$ and $\psi$ into one
   matrix before the density is evaluated, so a large class of assembly errors (e.g.
   $\Lambda$ transposed with a compensating change elsewhere, or $z$ attached to the wrong
   unit) can cancel and go undetected. Form (b) exposes each block separately.

**Consequences for the comparison protocol.**

- The Stan program must take $z$ (dimension $n_u \times K$) and $q$ (dimension
  $n_u \times T$) as *inputs* (data, or parameters held at fixed values), **not** integrate
  them out. The oracle returns $\log p(y, z, q \mid \theta)$ at a fixed
  $(\theta, z, q)$.
- The comparison target must be the joint density *before* Laplace integration, at the
  same fixed $(\theta, z, q)$. Comparing a Stan joint against an integrated marginal
  log-likelihood is a category error and will not agree.
- The two sides must agree on the **latent parameterisation**: if the engine happens to
  store the diagonal companion as $u$-space quantities rather than as an independent
  $q$ block, the mapping must be stated and the fixed values transported through it. If
  the mapping cannot be established without reading `src/`, the correct action is to ask
  the maintainer or to measure it, **not** to peek. (See §11, item 3.)
- **Normalising constants:** the specification below includes *all* Gaussian normalising
  constants ($-\tfrac12\log(2\pi)$ per univariate term). If the comparison target drops
  constants, subtract the known constant offset analytically rather than editing the
  oracle. The offset is fixed and derived in §7.3.
- **No Jacobian adjustments.** All densities below are on the **natural scale**
  ($\sigma_\varepsilon > 0$, $\psi_t > 0$, $\lambda_{kk} > 0$). Internal log/exp
  reparameterisations are an implementation detail and contribute a Jacobian only if one
  is doing a change of variables in a *sampler*. A fixed-parameter density check must
  contain **no** Jacobian term on either side. In Stan, use `target +=
  normal_lpdf(...)`, never the `~` sampling-statement shorthand (which drops constants),
  and declare the fixed quantities in `data` or `transformed data` so no automatic
  constraint Jacobian is introduced.

---

## 1. Data layout and index sets

Long format: **one row per `(unit, trait)` cell**
(`docs/design/01-formula-grammar.md`, "Long-format trait-stacked grammar";
`docs/design/03-likelihoods.md`, "Multi-trait stacking").

| index | ranges over | meaning |
|---|---|---|
| $i = 1,\dots,N$ | rows of the long data frame | one observation |
| $t = 1,\dots,T$ | traits | which trait row $i$ measures |
| $\ell = 1,\dots,n_u$ | units (the single grouping level; e.g. `site`) | which unit row $i$ belongs to |
| $k = 1,\dots,K$ | latent axes ($K = $ `d`) | latent factor index |

Two index maps are given as data:

$$
t(i) \in \{1,\dots,T\}, \qquad \ell(i) \in \{1,\dots,n_u\}.
$$

The design does **not** require balance: $N$ need not equal $n_u T$, and units may have
missing trait cells. Every row contributes exactly one data-density term.

The model as specified here has **no covariates** beyond the trait-specific intercepts.
(The general fixed-effect grammar is `value ~ 0 + trait + (0 + trait):x`; the model in
scope is `value ~ 0 + trait + latent(0 + trait | unit, d = K)`. Adding covariates changes
only §3 and is noted there.)

---

## 2. Observation model

Family: `gaussian()`, identity link
(`docs/design/03-likelihoods.md` §"Gaussian": "Parameters: `mu` (identity), `sigma` (log)";
"Density: $y_i \sim \mathcal N(\mu_i, \sigma^2)$").

$$
y_i \;\mid\; \eta_i,\ \sigma_\varepsilon
\;\sim\; \mathcal{N}\!\left(\eta_i,\; \sigma_\varepsilon^2\right),
\qquad i = 1,\dots,N,
$$

independently across rows given the latent variables. Identity link, so $\mu_i = \eta_i$.

**$\sigma_\varepsilon$ is a single scalar shared across all traits and all rows.** It is
*not* per-trait. This is explicit in the user-facing documentation: "Gaussian and lognormal
responses have one residual scale parameter, `sigma_eps`… No per-row `indep`,
Gaussian/lognormal present → One shared `sigma_eps` across Gaussian/lognormal rows.
*Not* per-trait." (`man/gllvmTMB.Rd`, §"Per-trait residual variance: when does it
activate?"). Per-trait residual variances appear only if a per-row `indep(0 + trait | obs)`
term is added, which the model in scope does not have.

Note the notation convention carried through this document
(`docs/design/03-likelihoods.md` §"Notation"): $\mathcal{N}(a, b)$ takes **$b$ as a
variance**; Stan's `normal_lpdf(y | mu, sigma)` takes an **SD**. Every conversion below is
written out explicitly to remove any chance of a variance/SD slip.

---

## 3. Linear predictor

$$
\boxed{\;
\eta_i \;=\; \mu_{t(i)}
\;+\; \sum_{k=1}^{K} \lambda_{t(i),k}\, z_{\ell(i),k}
\;+\; q_{\ell(i),\,t(i)}
\;}
$$

equivalently, writing the `(unit, trait)` cell explicitly,

$$
\eta_{\ell t} \;=\; \mu_t \;+\; \boldsymbol\lambda_t^\top z_\ell \;+\; q_{\ell t},
\qquad
\boldsymbol\lambda_t^\top = (\lambda_{t1},\dots,\lambda_{tK}) = \text{row } t \text{ of } \Lambda .
$$

Term by term:

1. **$\mu_t$ — trait-specific intercepts.** The `0 + trait` fixed-effect term produces $T$
   intercepts, one per trait level, with **no** global intercept and **no** contrast
   coding (`docs/design/01-formula-grammar.md`: "`value ~ 0 + trait` # T trait-specific
   intercepts"). In Stan this is a plain length-$T$ unconstrained vector indexed by
   `t[i]`; do **not** build a treatment-contrast design matrix.
2. **$\boldsymbol\lambda_t^\top z_\ell$ — the reduced-rank (shared) latent contribution.**
   $z_\ell \in \mathbb{R}^K$ is the vector of latent factor scores for unit $\ell$;
   $\Lambda \in \mathbb{R}^{T\times K}$ is the loadings matrix, so
   $\boldsymbol\lambda_t$ is the length-$K$ loadings vector of trait $t$. This is exactly
   the form given in `docs/design/04-random-effects.md`:
   $\eta_{it} = \mu_t + \boldsymbol\lambda_t^\top\mathbf u_{g(i)}$,
   $\mathbf u_\ell \sim \mathcal N(\mathbf 0, I_K)$.
3. **$q_{\ell t}$ — the independent per-`(unit, trait)` component ("unique" / diagonal
   $\Psi$ companion).** One scalar per `(unit, trait)` cell, with trait-specific variance.
   `docs/design/04-random-effects.md` §"Trait-diagonal $\Psi$": $\eta_{it} = \cdots +
   v_{\ell t}$, $v_{\ell t}\sim\mathcal N(0,\psi_t)$.

**The unit-level random effect and its decomposition.** Define the per-unit random-effect
vector $u_\ell \in \mathbb{R}^T$ by $u_{\ell t} = \boldsymbol\lambda_t^\top z_\ell +
q_{\ell t}$, i.e.

$$
u_\ell \;=\; \Lambda z_\ell \;+\; q_\ell ,
\qquad
\eta_{\ell t} = \mu_t + u_{\ell t}.
$$

This is the "latent + unique" structure. Because $z_\ell \perp q_\ell$,

$$
\operatorname{Var}(u_\ell)
= \Lambda \operatorname{Var}(z_\ell) \Lambda^\top + \operatorname{Var}(q_\ell)
= \Lambda I_K \Lambda^\top + \Psi
= \boxed{\;\Lambda\Lambda^\top + \operatorname{diag}(\psi_1,\dots,\psi_T)\;}
\;=\; \Sigma_{\text{unit}} ,
$$

which is the package's headline decomposition
(`docs/design/01-formula-grammar.md` §"The ordinary `latent()` decomposition rule";
`docs/design/00-vision.md`; `AGENTS.md` covariance-grid section; `man/latent.Rd`
`@details`). **This identity is a derived consequence of the specification, not part of
it.** The Stan program never forms $\Sigma_{\text{unit}}$; it may compute it as a
generated quantity for reporting.

**With covariates (out of scope, for completeness):** the fixed part generalises to
$\eta_i = x_i^\top\beta + \boldsymbol\lambda_{t(i)}^\top z_{\ell(i)} + q_{\ell(i),t(i)}$
with $x_i^\top\beta$ built from `0 + trait + (0 + trait):x`. Nothing in §4–§7 changes.

---

## 4. Distribution of every latent quantity

Exhaustive list. There are exactly two latent blocks.

### 4.1 Latent factor scores $z$

$$
z_{\ell k} \;\stackrel{\text{iid}}{\sim}\; \mathcal{N}(0,\,1),
\qquad \ell = 1,\dots,n_u,\quad k = 1,\dots,K,
$$

equivalently $z_\ell \sim \mathcal{N}_K(\mathbf 0, I_K)$ independently across units.

**The variance is fixed at exactly 1 and is not a parameter.** This is the standard GLLVM
/ factor-analysis normalisation: the scale of the latent axes is absorbed into $\Lambda$,
so leaving $\operatorname{Var}(z)$ free would make the model unidentified. The design prose
states it directly: $\mathbf u_\ell \sim \mathcal N(\mathbf 0, I_K)$
(`docs/design/04-random-effects.md`), and again in the `lv` extension,
$e_i \sim N(0, I_K)$ (`docs/design/01-formula-grammar.md`).

Stan: `target += std_normal_lpdf(to_vector(z));` — with all constants, this is
$-\tfrac{n_u K}{2}\log(2\pi) - \tfrac12\sum_{\ell,k} z_{\ell k}^2$.

### 4.2 Unique / diagonal-$\Psi$ components $q$

$$
q_{\ell t} \;\sim\; \mathcal{N}\!\left(0,\; \psi_t\right),
\qquad \ell = 1,\dots,n_u,\quad t = 1,\dots,T,
$$

independent across **both** $\ell$ and $t$, and independent of $z$. Here $\psi_t > 0$ is
the **variance** of trait $t$'s unique component; write $\psi_t = \sigma_{\psi,t}^2$ with
$\sigma_{\psi,t} > 0$ the corresponding SD, which is what Stan's `normal_lpdf` wants.

> **NOTATION WARNING — resolved by fiat here, flagged in §11.** The repository's prose is
> internally inconsistent about whether "$\psi$" denotes a variance or its square root.
> `docs/design/00-vision.md` and `AGENTS.md` write the decomposition as
> `Sigma = Lambda Lambda^T + diag(psi)` — $\psi$ a **variance**.
> `docs/design/04-random-effects.md` writes
> $\Psi = \operatorname{diag}(\psi_1^2,\dots,\psi_T^2)$ with $\psi_t^2 = \exp(2\tilde\psi_t)$
> — there $\psi_t$ is an **SD** and $\psi_t^2$ the variance. The spatial analogue writes
> $\operatorname{diag}(\psi_{\text{spde},t})$ with $\psi_{\text{spde},t}=\tau_t^{-2}$, a
> **variance** again. **This document uses $\psi_t$ = VARIANCE throughout** (the
> vision/AGENTS convention), and always writes the SD explicitly as
> $\sigma_{\psi,t} = \sqrt{\psi_t}$ wherever a density is evaluated. Any comparison
> harness must fix the convention on both sides *before* transporting numbers; a
> variance-for-SD substitution is precisely the kind of error this oracle exists to
> catch, and it will not announce itself as an error — it will just disagree.

If `common = TRUE` were used, all $\psi_t$ collapse to one shared value $\psi$
(`man/latent.Rd`: "`TRUE` ties the default ordinary diagonal $\Psi$ companion to one
shared variance across traits"). The model in scope uses `common = FALSE` (the default),
so there are $T$ free $\psi_t$.

### 4.3 There are no other latent quantities

No residual random effect beyond $\varepsilon$ (which is not a separate block — it is the
Gaussian observation noise of §2); no observation-level random effect; no phylogenetic,
spatial, kernel, `meta_V`, `unit_obs`, or `cluster` block. The model in scope has exactly
one grouping level.

Total number of latent scalars integrated over (in the real engine) or held fixed (in the
oracle check): $n_u(K + T)$.

---

## 5. Fixed parameters

$$
\theta \;=\; \bigl(\ \mu_1,\dots,\mu_T,\ \ \Lambda,\ \ \psi_1,\dots,\psi_T,\ \ \sigma_\varepsilon\ \bigr).
$$

Support: $\mu_t \in \mathbb{R}$; $\Lambda \in \mathbb{R}^{T\times K}$ subject to §6;
$\psi_t > 0$; $\sigma_\varepsilon > 0$.

Parameter counts (free, after the §6 rotation constraint):

| block | count |
|---|---|
| intercepts $\mu$ | $T$ |
| loadings $\Lambda$ | $TK - \tfrac{K(K-1)}{2}$ |
| unique variances $\psi$ | $T$ (or $1$ if `common = TRUE`) |
| residual SD $\sigma_\varepsilon$ | $1$ |

The loadings count is stated in `docs/design/04-random-effects.md`: "$T\cdot K -
K(K-1)/2$ free parameters (instead of $T\cdot K$), which is the standard
rotation-resolution convention from factor analysis."

**No priors.** This is a likelihood specification. In Stan, the `model` block contains only
the terms of §7; adding any prior changes the number being compared.

---

## 6. Identifiability constraints on $\Lambda$ — which are requirements, which are conventions

Three logically distinct things get conflated in the literature; keep them separate.

### 6.1 REQUIREMENT — the latent scale must be fixed

$\operatorname{Var}(z_\ell) = I_K$ is a genuine identifiability **requirement**, not a
convention. Without it, $(\Lambda, \operatorname{Var}(z)) \mapsto (\Lambda C^{-1},
C\operatorname{Var}(z)C^\top)$ leaves the likelihood unchanged for any invertible $C$, and
nothing is estimable. Fixing $\operatorname{Var}(z) = I_K$ removes the scale part of that
indeterminacy. **Must be imposed. Not negotiable. Already imposed in §4.1.**

### 6.2 CONVENTION — the rotation constraint on $\Lambda$

After §6.1, an orthogonal rotation indeterminacy remains: for any $K\times K$ orthogonal
$Q$ ($QQ^\top = I_K$),

$$
\Lambda \mapsto \Lambda Q, \qquad z_\ell \mapsto Q^\top z_\ell
$$

leaves $\eta$, the likelihood, $\operatorname{Var}(z)=I_K$, **and**
$\Lambda\Lambda^\top$ all unchanged. So $\Lambda\Lambda^\top$ (hence
$\Sigma_{\text{unit}}$) is identified, but $\Lambda$ itself is identified **only up to
rotation** (`docs/design/04-random-effects.md` §"Rotation invariance").

`gllvmTMB` resolves this the standard factor-analytic way
(`docs/design/04-random-effects.md` §"Internal parameterisation", citing the
`glmmTMB::rr()` parameterisation of McGillycuddy, Popovic, Bolker & Warton 2025,
*J. Stat. Softw.* **112**(1)):

- $\Lambda$ is **lower-triangular in its leading $K\times K$ block**: the $K(K-1)/2$
  upper-triangular entries are **zero**, i.e. $\lambda_{tk} = 0$ for $k > t$ when
  $t \le K$;
- the $K$ diagonal entries are **strictly positive**: $\lambda_{kk} > 0$
  (implemented internally on the log scale, $\lambda_{kk} = \exp(\tilde\lambda_{kk})$ —
  an *implementation* detail, not part of the density);
- the remaining lower-triangular and rectangular entries ($t > K$, all $k$; and
  $t \le K$, $k < t$) are **unconstrained reals**.

This is a **CONVENTION**, in a precise sense: it selects one representative from each
rotation orbit. It changes *which* $\Lambda$ you get back, never the value of the
likelihood, never $\Lambda\Lambda^\top$, never any fitted or predicted quantity. Any other
rotation-resolving choice (varimax, oblimin, the $\Lambda^\top\Psi^{-1}\Lambda$-diagonal
convention of classical factor analysis, or none at all) yields the same fit.

**For the oracle check this matters concretely:**

- The Stan program **must not** impose the triangular constraint as a truncation, a
  transform, or a `positive_ordered`/`cholesky_factor` type. Doing so would change the
  measure and thus the density. Feed $\Lambda$ in as **data** (a plain $T\times K$
  matrix), already satisfying the convention if you like, and evaluate the density as
  written.
- The $-\infty$/rejection behaviour that a constrained *type* would give you is a sampling
  concern, irrelevant to a fixed-parameter evaluation.
- Two engines that adopt **different** rotation conventions will still agree on
  $\log p(y, z, q\mid\theta)$ **only if** you transport $(\Lambda, z)$ jointly through the
  same $Q$: $\Lambda\to\Lambda Q$ requires $z\to Q^\top z$. If you rotate $\Lambda$ and
  forget $z$, the joint density changes (through $\eta$) even though the *marginal*
  likelihood would not. This is a real trap for a joint-density check and is a further
  argument for form (b): it makes the coupling visible.

### 6.3 CONVENTION (weaker) — column sign

Even with the triangular structure, replacing column $k$ of $\Lambda$ by its negation and
$z_{\cdot k}$ by its negation is invariant. The "positive diagonal" requirement in §6.2
fixes this. Purely a labelling choice.

### 6.4 REQUIREMENT — rank and the $\Lambda\Lambda^\top$ / $\Psi$ split

- **$K < T$.** The engine rejects $K \ge T$ at parse time: at $K \ge T$ the loadings matrix
  is over-parameterised and the rotation-resolution constraint stops binding
  (`docs/design/04-random-effects.md` §"Rank deficiency";
  `docs/design/01-formula-grammar.md` writes "rank $K < T$").
  **Requirement** for a meaningful fit; the density is still well-defined at $K \ge T$, so
  a check may technically evaluate it, but do not.
- **Ledermann-type counting.** For $\Lambda\Lambda^\top + \Psi$ to be an identified
  *decomposition* (rather than merely a valid covariance), one needs
  $TK - \tfrac{K(K-1)}{2} + T \le \tfrac{T(T+1)}{2}$. The package documents the practical
  version of this concern as a fragility, not a hard gate: the total covariance is usually
  interpretable (their "level 2") while the split into $\Lambda\Lambda^\top$ and $\Psi$ is
  "fragile" ("level 3"), `docs/design/04-random-effects.md` §"Phylogenetic identifiability
  levels", and the same file warns that a spurious extra factor can pass `pdHess` while
  being noise. **Irrelevant to a fixed-parameter density check** (which never estimates
  anything) but essential context for interpreting any recovery study built on top of it.
- **Positivity.** $\psi_t > 0$ and $\sigma_\varepsilon > 0$ are requirements of the
  density. $\psi_t \to 0$ is a documented boundary case (a degenerate point mass;
  `docs/design/04-random-effects.md` §"Variance near zero"). Choose fixed values well away
  from zero for the check.

### 6.5 What is NOT constrained

$\Psi$ is diagonal by definition of the term, not by a constraint; the intercepts $\mu$
are unconstrained (there is no sum-to-zero or reference-level constraint, because the
grammar is `0 + trait`); and $z$, $q$ are unconstrained reals as *inputs* to the check.

---

## 7. The full joint log-density

### 7.1 Statement

Let $\theta = (\mu, \Lambda, \psi, \sigma_\varepsilon)$ as in §5, and let $z \in
\mathbb{R}^{n_u\times K}$, $q\in\mathbb{R}^{n_u\times T}$ be the fixed latent inputs. With

$$
\eta_i = \mu_{t(i)} + \boldsymbol\lambda_{t(i)}^\top z_{\ell(i)} + q_{\ell(i),t(i)} ,
$$

the joint log-density is the sum of **three** distinct density terms:

$$
\boxed{
\begin{aligned}
\log p\bigl(y, z, q \mid \theta\bigr)
=\;& \underbrace{\sum_{i=1}^{N}
   \left[-\tfrac12\log(2\pi) - \log\sigma_\varepsilon
         - \frac{(y_i - \eta_i)^2}{2\sigma_\varepsilon^2}\right]}_{\text{(D) data / Gaussian observation term}} \\[4pt]
 &+ \underbrace{\sum_{\ell=1}^{n_u}\sum_{k=1}^{K}
   \left[-\tfrac12\log(2\pi) - \tfrac12 z_{\ell k}^2\right]}_{\text{(Z) latent-score term, } \mathcal N(0,1)} \\[4pt]
 &+ \underbrace{\sum_{\ell=1}^{n_u}\sum_{t=1}^{T}
   \left[-\tfrac12\log(2\pi) - \tfrac12\log\psi_t
         - \frac{q_{\ell t}^2}{2\psi_t}\right]}_{\text{(Q) unique / diagonal-}\Psi\text{ term, } \mathcal N(0,\psi_t)}
\end{aligned}}
$$

**Number of distinct density terms in the joint: 3** — one data term (D) and two
latent-variable terms (Z, Q). (Under the *marginal* formulation (a) it would be 2; that
difference is itself a useful tripwire that the right formulation is in use.)

Note $\log\sqrt{\psi_t} = \tfrac12\log\psi_t$, written out to make the variance-vs-SD
handling unambiguous: in Stan the third term is
`normal_lpdf(q[l, t] | 0, sqrt(psi[t]))`, **not** `normal_lpdf(q[l, t] | 0, psi[t])`.

### 7.2 Equivalent vectorised Stan form

```stan
target += normal_lpdf(y | eta, sigma_eps);          // (D), N terms
target += std_normal_lpdf(to_vector(z));            // (Z), n_u * K terms
for (t in 1:T)
  target += normal_lpdf(q[, t] | 0, sqrt(psi[t]));  // (Q), n_u * T terms
```

with `eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], z[uu[i]]) + q[uu[i], tt[i]]`.
Use `normal_lpdf` (constants included), not `y ~ normal(...)` (constants dropped).

### 7.3 Constant offset, if the comparison target drops constants

The total constant is

$$
C \;=\; -\tfrac12\bigl(N + n_u K + n_u T\bigr)\log(2\pi).
$$

A target that drops all normalising constants returns $\log p - C$. A target that keeps
the $\log\sigma$ and $\log\psi$ terms but drops $2\pi$ (the usual TMB `dnorm(..., true)`
behaviour keeps *everything*, so this is unlikely) would differ by $C$ exactly. Establish
which by evaluating both sides at two different parameter values and checking that the
**difference of differences** is zero — that is the constant-free comparison and it should
be attempted first, before chasing an absolute match.

### 7.4 What the marginal form would give (for reference only — do not use)

$$
\log p(y, u \mid \theta) =
\sum_{i=1}^{N}\log\phi\!\left(y_i;\ \mu_{t(i)} + u_{\ell(i),t(i)},\ \sigma_\varepsilon^2\right)
+ \sum_{\ell=1}^{n_u} \log \phi_T\!\left(u_\ell;\ \mathbf 0,\ \Lambda\Lambda^\top + \Psi\right),
$$

with $\phi_T$ the $T$-variate normal density. Two terms. Correct as a *model*, useless as
a *check* — see §0.

---

## 8. Symbol table

| Symbol | Meaning | Dimension | Support / constraint |
|---|---|---|---|
| $N$ | number of long-format rows | scalar | positive integer |
| $T$ | number of traits | scalar | integer $\ge 2$ |
| $n_u$ | number of units (levels of the grouping factor) | scalar | positive integer |
| $K$ (`d`) | latent rank | scalar | integer, $1 \le K < T$ |
| $y_i$ | response for row $i$ | $N$ | $\mathbb{R}$ |
| $t(i)$ | trait index of row $i$ | $N$ | $\{1,\dots,T\}$ |
| $\ell(i)$ | unit index of row $i$ | $N$ | $\{1,\dots,n_u\}$ |
| $\mu_t$ | trait-specific intercept | $T$ | $\mathbb{R}$ (unconstrained; no reference level) |
| $\Lambda = (\lambda_{tk})$ | loadings matrix | $T \times K$ | $\lambda_{tk}=0$ for $k>t$, $t\le K$; $\lambda_{kk}>0$; else $\mathbb{R}$ (§6.2, convention) |
| $\boldsymbol\lambda_t$ | loadings of trait $t$ (row $t$ of $\Lambda$) | $K$ | as above |
| $\psi_t$ | unique **variance** of trait $t$ | $T$ | $\psi_t > 0$ |
| $\sigma_{\psi,t}$ | $=\sqrt{\psi_t}$, unique SD of trait $t$ | $T$ | $>0$ |
| $\Psi$ | $\operatorname{diag}(\psi_1,\dots,\psi_T)$ | $T \times T$ | diagonal, positive definite |
| $\sigma_\varepsilon$ | residual SD, **shared across all traits and rows** | scalar | $>0$ |
| $z_{\ell k}$ | latent factor score, unit $\ell$, axis $k$ | $n_u \times K$ | $\mathbb{R}$; $\sim\mathcal N(0,1)$, variance FIXED at 1 |
| $q_{\ell t}$ | unique component, unit $\ell$, trait $t$ | $n_u \times T$ | $\mathbb{R}$; $\sim\mathcal N(0,\psi_t)$ |
| $u_{\ell t}$ | total unit-level random effect $=\boldsymbol\lambda_t^\top z_\ell + q_{\ell t}$ | $n_u \times T$ | derived; $\operatorname{Var}(u_\ell)=\Sigma_{\text{unit}}$ |
| $\eta_i$ | linear predictor for row $i$ | $N$ | derived, $\mathbb{R}$ |
| $\Sigma_{\text{unit}}$ | $\Lambda\Lambda^\top + \Psi$ | $T\times T$ | derived; positive definite |
| $\theta$ | $(\mu,\Lambda,\psi,\sigma_\varepsilon)$ | — | §5 |
| $C$ | $-\tfrac12(N+n_uK+n_uT)\log 2\pi$ | scalar | §7.3 |

---

## 9. Minimal reference implementation sketch (Stan, fixed-parameter oracle)

```stan
data {
  int<lower=1> N; int<lower=2> T; int<lower=1> n_u; int<lower=1> K;
  array[N] int<lower=1,upper=T> tt;      // trait index per row
  array[N] int<lower=1,upper=n_u> uu;    // unit index per row
  vector[N] y;
  // fixed parameters
  vector[T] mu;
  matrix[T, K] Lambda;                   // plain matrix: NO constrained type
  vector<lower=0>[T] psi;                // VARIANCES
  real<lower=0> sigma_eps;               // shared residual SD
  // fixed latent values
  matrix[n_u, K] z;
  matrix[n_u, T] q;
}
generated quantities {
  real lp;
  {
    vector[N] eta;
    for (i in 1:N)
      eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], z[uu[i]]) + q[uu[i], tt[i]];
    lp = normal_lpdf(y | eta, sigma_eps)
       + std_normal_lpdf(to_vector(z));
    for (t in 1:T)
      lp += normal_lpdf(col(q, t) | 0, sqrt(psi[t]));
  }
}
```

Everything is `data`; nothing is a `parameter`; therefore no constraint Jacobians exist and
`lp` is exactly the boxed expression of §7.1. (If instead you want Stan to *sample*, move
$\theta, z, q$ to `parameters`, put the same three terms in `model` via `target +=`, and
accept the constraint Jacobians on `psi` and `sigma_eps` — but then the reported `lp__` is
**no longer** comparable term-for-term, which is the whole reason the oracle version puts
everything in `data`.)

---

## 10. Sources used

**Repository design prose and generated documentation (user-facing semantics only):**

- `docs/design/04-random-effects.md` — §"Reduced-rank reparameterisation (`latent(...)`)"
  (the $\eta_{it} = \mu_t + \lambda_t^\top u_{g(i)}$, $u_\ell\sim\mathcal N(0,I_K)$
  statement); §"Internal parameterisation" (lower-triangular, positive diagonal,
  $TK-K(K-1)/2$ free parameters); §"Rotation invariance"; §"Trait-diagonal $\Psi$
  (`unique(...)`)" ($v_{\ell t}\sim\mathcal N(0,\psi_t^2)$, additive on $\eta$);
  §"Paired with `latent(...)`" ($\Sigma_g = \Lambda\Lambda^\top+\Psi$);
  §"Boundary cases and identifiability" ($K\ge T$ rejected; $\psi\to0$; spurious factors;
  identifiability levels 1–3).
- `docs/design/01-formula-grammar.md` — §"The ordinary `latent()` decomposition rule"
  (default-fold rule; $K<T$); §"Predictor-informed latent-score means"
  (the explicit assembled predictor $\eta_{it} = X_{it}\beta + \lambda_t^\top z_i +
  q_{it}$, $z_i = M_i\alpha + e_i$, $e_i\sim N(0,I_K)$ — the clearest statement in the
  repo that the model is hierarchical on $\eta$); §"Long-format trait-stacked grammar"
  (`0 + trait` = $T$ trait-specific intercepts; one row per `(unit, trait)`).
- `docs/design/03-likelihoods.md` — §"Notation" ($\mathcal N(a,b)$ takes a variance);
  §"Multi-trait stacking" (per-row likelihood, $\mu_i=g^{-1}(\eta_i)$, Laplace over the
  latent block); §"Gaussian" (identity link, $y_i\sim\mathcal N(\mu_i,\sigma^2)$,
  `sigma` on the log scale internally).
- `docs/design/00-vision.md` and `AGENTS.md` (covariance-grid section) — the canonical
  spelling `Sigma = Lambda Lambda^T + diag(psi)`; `latent()` carries its diagonal $\Psi$
  companion by default; the 5×3 keyword grid.
- `man/latent.Rd` (roxygen `@details`/`@arguments`) — `unique = TRUE` is the default and
  auto-includes the diagonal $\Psi$ companion; `common = TRUE` ties $\Psi$ to one shared
  variance; `d` = number of latent factors.
- `man/unique_keyword.Rd` — the diagonal companion's user-facing meaning and its
  soft-deprecated status relative to `indep()`.
- `man/gllvmTMB.Rd` §"Per-trait residual variance: when does it activate?" — the decisive
  statement that Gaussian fits without a per-row `indep` carry **one shared `sigma_eps`**,
  not a per-trait residual.

**External literature:**

- Warton, Blanchet, O'Hara, Ovaskainen, Taskinen, Walker & Hui (2015), "So Many Variables:
  Joint Modeling in Community Ecology", *TREE* **30**(12) — the GLLVM formulation
  $\eta_{ij} = \alpha_i + \beta_{0j} + \lambda_j^\top z_i$ with $z_i\sim N(0,I_K)$ and the
  induced low-rank residual covariance $\Lambda\Lambda^\top$.
- Hui, Taskinen, Pledger, Foster & Warton (2015), "Model-based approaches to unconstrained
  ordination", *Methods Ecol. Evol.* **6**(4) — latent-variable ordination, the
  $\operatorname{Var}(z)=I$ normalisation and the rotation indeterminacy.
- Niku, Hui, Taskinen & Warton (2019), "gllvm: Fast analysis of multivariate abundance data
  with generalized linear latent variable models", *Methods Ecol. Evol.* **10**(12), and
  Niku et al. (2017, *JABES*) — the standard constraint that the upper triangle of
  $\Lambda$ is zero with positive diagonal, used precisely to fix rotation.
- McGillycuddy, Popovic, Bolker & Warton (2025), "Parsimoniously Fitting Large Multivariate
  Random Effects in glmmTMB", *J. Stat. Softw.* **112**(1) — the `rr()` reduced-rank
  parameterisation that `gllvmTMB`'s design prose says it adapts.
- Classical factor analysis for $\Sigma = \Lambda\Lambda^\top + \Psi$, rotation
  indeterminacy, the Ledermann bound, and Heywood cases: Bollen (1989), *Structural
  Equations with Latent Variables*; Mulaik (2010), *Foundations of Factor Analysis*
  (both cited by `docs/design/01-formula-grammar.md` itself).

**Not used, by design:** `src/gllvmTMB.cpp` and everything else under `src/`; `R/eva-proto.R`;
`R/aghq-gate.R`; `R/fit-multi.R`; and any other R file that builds a TMB objective.

---

## 11. Open items — could NOT be determined without reading `src/`

These are stated as *unknowns*, not guesses. Each needs a maintainer statement or an
empirical measurement, not source inspection.

1. **Is $\psi$ stored/reported as a variance or an SD?** The prose contradicts itself
   (see the notation warning in §4.2): `00-vision.md`/`AGENTS.md` say `diag(psi)` (variance),
   `04-random-effects.md` says $\Psi = \operatorname{diag}(\psi_t^2)$ with
   $\psi_t^2=\exp(2\tilde\psi_t)$ (so their $\psi_t$ is an SD). This document commits to
   **variance**, but the harness must confirm which convention `extract_Sigma()` and any
   engine-side fixed-parameter hook use before transporting numbers. A factor-of-$\psi$
   disagreement will look like a model error and is not one.
2. **The exact row/column orientation and index order of $\Lambda$ and of the latent-score
   vector as the engine stores them** (e.g. whether the per-unit latent block is laid out
   unit-major or axis-major, and whether the reported loadings are $T\times K$ or its
   transpose). §3 fixes the *mathematics* unambiguously ($\boldsymbol\lambda_t^\top z_\ell$
   with $\Lambda$ being $T\times K$), which is all the oracle needs; but any harness that
   *transports* fixed values between the two implementations must establish the storage
   order. Determine it from the documented shape of `extract_Sigma()` / the loadings
   extractor output, or from the maintainer — not from the C++.
3. **Whether the engine's random-effect vector is literally $(z, q)$ or some reparameterised
   equivalent.** The design prose describes both blocks generatively, which is what §0
   relies on; but a joint-density comparison needs the *engine-side* latent vector to be
   pinned to the same fixed values. If the engine's block is not $(z,q)$ but, say, $u$
   with $\Sigma$ formed directly, then the hierarchical joint of §7.1 is not pointwise
   comparable and the check must be re-scoped (e.g. compare marginal likelihoods after
   integration, at the cost of the discriminating power argued in §0.3). **This is the
   single item most likely to invalidate the comparison, and it must be answered by the
   maintainer or by measurement before the check is trusted.**
4. **Constant-term convention of the comparison target** (whether $2\pi$ terms are kept).
   Resolve empirically via the difference-of-differences check in §7.3.
5. **Whether the diagonal companion added by default under `unique = TRUE` is attached at
   exactly the same grouping factor as the `latent()` term** in all code paths. The prose
   says yes for the ordinary unit-tier case in scope ("`latent(0 + trait | site, d = 2)`
   # `Lambda_B Lambda_B^T + Psi_B`", one grouping factor), and the model in scope has only
   one grouping level, so this is very likely a non-issue — but it is an assumption, not
   something the prose proves.
6. **Whether $\sigma_\varepsilon$ is truly free (not mapped off or pinned) in this exact
   configuration.** `man/gllvmTMB.Rd` states it is auto-suppressed only when a *per-row*
   `indep(0 + trait | obs)` term is present, which this model does not have, so it should
   be free. Confirm by checking that the fitted object reports a finite, non-stabiliser
   `sigma_eps` — an output-level check, no source reading required.
