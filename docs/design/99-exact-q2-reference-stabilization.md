```text
🎯 GOAL
PLATFORM: Codex | CONTINUING FROM: Design 98 terminal TECHNICAL_INCOMPLETE
DESIGN: 99 | ESTIMATED ARC: 6–10 hours | HANDS TO: fresh Codex task

Deliver a new, private, reproducible q=2 Bernoulli-logit marginal-likelihood
reference based on response-pattern-compressed adaptive Gaussian–Hermite
quadrature, independently certified by direct two-dimensional integration,
two optimization routes, two loading charts, and a fresh information ladder.

HEADLINE: determine whether a stable, finite, chart-invariant exact-reference
optimum can be established before any further VA/JJ discrimination work.

IN PARALLEL: provenance/source freeze; symbolic quadrature contract;
independent oracle; optimizer and chart diagnostics; fixture/information audit;
failure-resilient execution plumbing.

DEFER: Design-98 reruns, rescoring, or reinterpretation; VA/JJ/EVA factorials;
package APIs; src/gllvmTMB.cpp; structured priors; campaigns; GitHub Actions
compute; DRAC; public claims; merge, push, PR, or package integration.

DISCIPLINE: Design 99 is a new one-shot research design. It receives fresh
fixtures, seeds, starts, thresholds, UUIDs, telemetry, and output roots.
A failed gate stops the design. No result may repair Design 98 retrospectively.
The implementation is pure R; Design 99 adds and compiles no C++.
```

# Design 99 — exact q=2 reference stabilization

## Status and decision question

**Status:** maintainer approved, pending Gate-0 review. Implementation, fixture
materialization, optimization, and numerical evaluation require Gate-0
approval. The implementation is pure R and has no compilation step.

Design 99 asks one question:

> Can a finite, stationary, quadrature-converged and chart-invariant
> marginal-likelihood reference be established for one fresh intercept-only
> q=2 Bernoulli-logit model?

The only positive terminal label is `BOUNDED_ORACLE_PASS`. It means that the
private reference passed this contract on the three named fixture prefixes. It
does not admit any variational estimator, package path, public capability,
campaign, calibration claim, or retrospective explanation.

## Immutable predecessor boundary

Design 98 is terminal at `TECHNICAL_INCOMPLETE`. Its contract, sources,
fixtures, inputs, payloads, records, logs, summaries, UUID and closeout are
historical evidence and are read-only.

The Design-99 runtime must satisfy all of the following:

1. it must not source, import, execute, deserialize, copy, transform, optimize
   from, or numerically evaluate any file under
   `dev/design98-factorial-va-jj/`;
2. it must not use a Design-98 fixture, seed, start, coordinate, loading,
   response matrix, quadrature rule, compiled object, payload or result as a
   Design-99 input;
3. it must not write under a Design-98 path;
4. it may read the Design-98 contract and terminal prose during human review,
   and Gate 0 may hash named predecessor files solely to prove byte identity;
   those hashes are provenance, never runtime data;
5. a runtime manifest, source file or input JSON containing a Design-98 runtime
   path writes `PROVENANCE_STOP` and stops before fixture creation or fits.

No Design-99 result changes the meaning of any Design-98 record.

## Scope

### In

- one private intercept-only Bernoulli-logit latent model;
- \(T=6\) traits and \(q=2\) standard-normal latent dimensions;
- one fresh nested fixture with \(N=128,512,2048\);
- exact response-pattern compression;
- conditional-mode adaptive tensor Gaussian-Hermite quadrature (AGH);
- route-specific \(H=9\)/\(H=15\) optimization, exactly one \(H=31\) polish,
  and \(H=21,31\) certification;
- direct integration of the Fisher-identity marginal score;
- two independent optimization routes, two loading charts, three frozen
  invariant starts and two compactness guards;
- independent nested integration and independent bounded-domain cubature;
- private invariant estimates \(\beta\), \(\Sigma=\Lambda\Lambda^\top\), its
  two positive eigenvalues, and population-marginal probabilities.
- a pure-R implementation with no new or reused C++.

### Out

VA, JJ, EVA, ELBOs, Laplace comparisons, fixed-global contrasts, q4/q6,
rank selection, covariates, offsets, observation weights, missing responses,
other families, structured priors, phylogeny, spatial terms, long-format
package mapping, `src/gllvmTMB.cpp`, public R APIs, `logLik()` or AIC/BIC
claims, intervals, calibration, coverage, power, campaigns, package
integration, pkgdown and release work are out.

## Model and exact marginal target

For unit \(i\), trait \(t\in\{1,\ldots,6\}\), and latent vector
\(u_i\in\mathbb R^2\),

\[
u_i\sim N_2(0,I_2),\qquad
Y_{it}\mid u_i\sim\operatorname{Bernoulli}(p_{it}),
\]
\[
\operatorname{logit}(p_{it})=\eta_{it}
=\beta_t+\lambda_t^\top u_i.
\]

Let \(y\in\{0,1\}^6\) denote one response pattern. Define the complete-data
log kernel, including the normalized Gaussian prior,

\[
h_y(u;\theta)
=\sum_{t=1}^6
\left[y_t\eta_t(u)-\operatorname{softplus}\{\eta_t(u)\}\right]
-\frac12u^\top u-\log(2\pi),
\]

where \(\theta\) denotes the 17 identified chart coordinates. The exact pattern
probability and sample log likelihood are

\[
\pi_y(\theta)=\int_{\mathbb R^2}\exp\{h_y(u;\theta)\}\,du,
\]
\[
\ell_N(\theta)=\sum_{y\in\{0,1\}^6}n_y\log\pi_y(\theta),
\qquad \sum_y n_y=N.
\]

The Bernoulli term contains no omitted combinatorial constant. The
\(-\log(2\pi)\) prior constant is mandatory in every objective and oracle.

### Response-pattern compression

Pattern compression is exact because every unit has the same intercept-only
linear predictor, the same \(\Lambda\), the same \(N_2(0,I_2)\) prior, no
offset, no weight and no missing trait. The implementation must aggregate all
rows into a length-64 integer count vector, retaining zeros. Pattern coding is
frozen as

\[
\operatorname{code}(y)=\sum_{t=1}^6 y_t2^{6-t},
\]

so trait 1 is the most-significant bit and codes run from 0 through 63. The
implementation must verify that coding and decoding are exact and that
reconstructing the rowwise likelihood from the counts agrees to `<1e-12` at
Gate-1 test coordinates.

Any later addition of unit-specific design information invalidates compression
and lies outside Design 99.

## Conditional mode and curvature

For each pattern \(y\), let

\[
\hat u_y(\theta)=\arg\max_u h_y(u;\theta).
\]

Writing \(p_t(u)=\operatorname{logit}^{-1}
\{\beta_t+\lambda_t^\top u\}\),

\[
g_y(u;\theta)=\nabla_u h_y(u;\theta)
=\Lambda^\top\{y-p(u)\}-u,
\]
\[
Q_y(u;\theta)=-\nabla_u^2h_y(u;\theta)
=I_2+\Lambda^\top W(u)\Lambda,
\]
\[
W(u)=\operatorname{diag}\{p_t(u)[1-p_t(u)]\}.
\]

Because \(Q_y\succeq I_2\), \(h_y\) is strictly concave and the conditional
mode is unique. A non-positive-definite \(Q_y\), minimum eigenvalue below
`1 - 1e-10`, or multiple numerical modes is an implementation failure, not a
scientific result.

The mode solver is damped Newton:

\[
u^{(k+1)}=u^{(k)}+\alpha_kQ_y(u^{(k)})^{-1}g_y(u^{(k)}),
\qquad \alpha_k\in\{1,1/2,1/4,\ldots\}.
\]

It starts at \(u=0\). Backtracking accepts the first step that gives a finite
strict increase in \(h_y\); it stops after at most 50 Newton iterations or 30
halvings per iteration. A mode is healthy only when

- \(\|g_y(\hat u_y)\|_\infty<10^{-10}\);
- the squared Newton decrement
  \(g_y^\top Q_y^{-1}g_y<10^{-12}\);
- all iterates, kernels, scores, Hessians and Cholesky factors are finite;
- every accepted step increases \(h_y\);
- \(\lambda_{\min}(Q_y)\ge 1-10^{-10}\).

All 64 patterns must pass at every certified global coordinate, including
patterns absent from the realized fixture.

## Normalized-\(N(0,1)\) adaptive tensor GH

### Frozen quadrature convention

For order \(H\), the one-dimensional nodes and weights
\(\{z_h,w_h\}_{h=1}^H\) approximate expectation under a standard normal:

\[
\int_{\mathbb R}f(z)\phi(z)\,dz
\approx\sum_{h=1}^Hw_hf(z_h),
\qquad w_h>0,\qquad \sum_hw_h=1.
\]

These are normalized-\(N(0,1)\) nodes. Generate them with
`statmod::gauss.quad.prob()` from `statmod` version `1.5.2`, sort nodes in
strictly ascending order with weights carried by the same permutation, and
freeze SHA-256 hashes of the ordered nodes and weights in every task input.
Tensor enumeration is column-major with the first tensor coordinate varying
fastest. If physicists' Hermite roots \(x_h\) are used in an independent test,
that test must apply \(z_h=\sqrt2x_h\) and normalize the physicists' weights by
\(\sqrt\pi\). No other hidden \(\sqrt2\), \(\pi^{-1/2}\), or
\(-\log\pi\) convention is permitted.

At the conditional mode, set

\[
Q_y=Q_y(\hat u_y;\theta),\qquad
A_yA_y^\top=Q_y^{-1},
\]

where \(A_y\) is the lower-triangular Cholesky factor with positive diagonal.
For a tensor node \(z_{rs}=(z_r,z_s)^\top\), define

\[
u_{y,rs}=\hat u_y+A_yz_{rs}.
\]

Changing variables and expressing the integral as a standard-normal
expectation gives

\[
\pi_y(\theta)
=|A_y|E_{Z\sim N_2(0,I_2)}
\left[
\frac{\exp\{h_y(\hat u_y+A_yZ;\theta)\}}{\phi_2(Z)}
\right].
\]

Therefore the order-\(H\) adaptive approximation is

\[
\widehat\pi_{y,H}(\theta)
=\sum_{r=1}^H\sum_{s=1}^H
w_rw_s\exp\{a_{y,rs,H}(\theta)\},
\]
\[
a_{y,rs,H}
=h_y(u_{y,rs};\theta)
-\log\phi_2(z_{rs})+\log|A_y|,
\]
\[
-\log\phi_2(z_{rs})
=\log(2\pi)+\tfrac12z_{rs}^\top z_{rs}.
\]

Equivalently,

\[
a_{y,rs,H}
=h_y(u_{y,rs};\theta)
+\log(2\pi)+\tfrac12z_{rs}^\top z_{rs}
+\log|A_y|.
\]

Every pattern integral must use log-sum-exp over
\(\log w_r+\log w_s+a_{y,rs,H}\). The objective is

\[
\widehat\ell_{N,H}(\theta)
=\sum_y n_y\log\widehat\pi_{y,H}(\theta).
\]

The prior normalization inside \(h_y\), the division by \(\phi_2(z)\), and
the Jacobian \(|A_y|\) are all required. Gate 1 must fail deliberately when
each is removed or when the \(\sqrt2\) convention is changed.

Pinheiro and Bates (1995), Liu and Pierce (1994), and Rabe-Hesketh et al.
(2005) motivate the adaptive-quadrature construction and its use in latent
variable models. They are motivation and provenance, not validation: the
Design-99 algebra tests and independent numerical oracles remain the validating
evidence.

The named primary sources are Pinheiro and Bates (1995), “Approximations to
the log-likelihood function in the nonlinear mixed-effects model”; Liu and
Pierce (1994), “A note on Gauss-Hermite quadrature”; and Rabe-Hesketh,
Skrondal, and Pickles (2005), “Maximum likelihood estimation of limited and
discrete dependent variable models with nested random effects.”

## Exact Fisher score and the finite-rule derivative

The exact marginal score obeys Fisher's identity:

\[
\nabla_\theta\log\pi_y(\theta)
=E_\theta\left[
\nabla_\theta\log p(y,u;\theta)\mid y
\right].
\]

For interpretable loading coordinates,

\[
s_{\beta_t}(y,u)=y_t-p_t(u),
\qquad
s_{\lambda_{tk}}(y,u)=\{y_t-p_t(u)\}u_k.
\]

Chart-coordinate scores follow only by the explicit chain rule in the chart
section below. The directly integrated order-\(H\) Fisher score is the
normalized weighted mean of these complete-data scores:

\[
\widehat s_{y,H}^{F}(\theta)
=
\frac{\sum_{r,s}w_rw_s
\exp(a_{y,rs,H})s(y,u_{y,rs};\theta)}
{\sum_{r,s}w_rw_s\exp(a_{y,rs,H})},
\]
\[
\widehat S_{N,H}^{F}(\theta)
=\sum_y n_y\widehat s_{y,H}^{F}(\theta).
\]

The adaptive nodes \(\hat u_y(\theta)+A_y(\theta)z\) depend on \(\theta\).
Consequently,

\[
\widehat S_{N,H}^{F}(\theta)
\ne
\nabla_\theta\widehat\ell_{N,H}(\theta)
\]

in general at finite \(H\). The left side approximates the exact Fisher score;
the right side is the derivative of a theta-dependent finite quadrature rule
and includes derivatives of the mode, curvature and transformation. They may
converge to the same exact score as \(H\) increases, but they are not silently
interchangeable.

Design 99 must record both:

1. the full finite-rule derivative
   \(\nabla_\theta\widehat\ell_{N,H}\), differentiating through re-adaptation;
2. the directly integrated Fisher score \(\widehat S_{N,H}^{F}\).

Route A uses the first. Route B uses the second. Agreement at certification
orders is a gate, not an assumed identity.

Gate 1 verifies the chain-rule score against the independently configured
Richardson and direct-integration checks below; the motivating literature is
not a substitute for those tests.

## Loading charts and compactness guards

### Invariant target

The likelihood is invariant under \(\Lambda\mapsto\Lambda R\) for orthogonal
\(R\). Raw loadings are never compared across charts. The targets are

\[
\beta,\qquad \Sigma=\Lambda\Lambda^\top,\qquad
\operatorname{eig}_+(\Sigma),\qquad
\bar p_t=E_{U\sim N_2(0,I_2)}
\operatorname{logit}^{-1}(\beta_t+\lambda_t^\top U).
\]

### Polar anchor chart

For a row \(\lambda_t\), write

\[
\lambda_t=r_t(\cos\alpha_t,\sin\alpha_t),\qquad 0<r_t<C.
\]

For ordered anchor pair \((a,b)\), rotation and reflection are fixed by

\[
\alpha_a=0,\qquad 0<\alpha_b<\pi.
\]

The remaining four angles lie in \((-\pi,\pi)\). The unconstrained chart maps
are

\[
\beta_t=6\tanh(b_t/6),
\qquad
r_t=C\,\operatorname{logit}^{-1}(\rho_t),
\]
\[
\alpha_b=\pi\operatorname{logit}^{-1}(\gamma_b),
\qquad
\alpha_t=\pi\tanh(\gamma_t)\quad(t\notin\{a,b\}).
\]

The chart has \(6+6+5=17\) free coordinates. Stable implementations of
`tanh`, `plogis`, `log1p` and log-Jacobian calculations are mandatory.

Given a full-rank loading matrix \(L\), conversion to chart \((a,b)\) is:

1. \(e_1=L_{a\cdot}/\|L_{a\cdot}\|\);
2. choose the unit vector \(e_2\perp e_1\) with
   \(L_{b\cdot}e_2>0\);
3. set \(R=(e_1,e_2)\) and \(L^{(a,b)}=LR\);
4. extract row radii and `atan2` angles, then apply the inverse maps.

The conversion is undefined if the anchor row has zero norm or the ordered
anchor minor is singular. Such an endpoint fails that chart.

The two frozen charts are:

- `C12`: ordered anchors \((1,2)\);
- `C34`: ordered anchors \((3,4)\).

The only compactness guards are `cap4` (\(C=4\)) and `cap8` (\(C=8\)).
Admission requires their invariant endpoints to agree. No \(C=2\) task or
other diagnostic cap is part of Design 99. At an admitted endpoint:

- \(\max_t|\beta_t|<4.8\);
- \(\max_tr_t<3.2\);
- \(\min_tr_t>0.02\);
- the anchor sine satisfies \(\sin(\alpha_b)>0.05\);
- no raw chart coordinate has absolute value above 12.

These are interiority gates, not post-hoc regularization. A cap-active or
chart-singular optimum stops; it is not reported as a finite reference.

### Chain rule

For use in the Fisher score,

\[
\frac{\partial\beta_t}{\partial b_t}
=1-\tanh^2(b_t/6),
\qquad
\frac{\partial r_t}{\partial\rho_t}
=C\,\sigma(\rho_t)\{1-\sigma(\rho_t)\},
\]
\[
\frac{\partial\lambda_t}{\partial\rho_t}
=\frac{\partial r_t}{\partial\rho_t}
(\cos\alpha_t,\sin\alpha_t),
\]
\[
\frac{\partial\lambda_t}{\partial\alpha_t}
=r_t(-\sin\alpha_t,\cos\alpha_t),
\]
\[
\frac{\partial\alpha_b}{\partial\gamma_b}
=\pi\sigma(\gamma_b)\{1-\sigma(\gamma_b)\},
\qquad
\frac{\partial\alpha_t}{\partial\gamma_t}
=\pi\{1-\tanh^2(\gamma_t)\}.
\]

Gate 1 must compare every transformed-coordinate score component with
Richardson differences. A zero or missing chain factor is a global algebra
failure.

## Fresh DGP and nested fixture

Set

\[
\beta^\star=(-0.70,-0.35,-0.10,0.20,0.45,0.70)
\]

and

\[
\Lambda^\star=
\begin{pmatrix}
0.80&0\\
0.20&0.70\\
-0.60&0.25\\
0.20&-0.75\\
0.25&0.60\\
-0.35&-0.45
\end{pmatrix}.
\]

Both frozen anchor minors are nonzero:

\[
\det\Lambda^\star_{\{1,2\}}=0.56,\qquad
\det\Lambda^\star_{\{3,4\}}=0.40.
\]

Use

```r
beta_truth <- c(-0.70, -0.35, -0.10, 0.20, 0.45, 0.70)
Lambda_truth <- rbind(
  c( 0.80,  0.00),
  c( 0.20,  0.70),
  c(-0.60,  0.25),
  c( 0.20, -0.75),
  c( 0.25,  0.60),
  c(-0.35, -0.45)
)
RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
set.seed(9902401)
u_truth <- matrix(rnorm(2048 * 2), nrow = 2048, ncol = 2)
eta_truth <- sweep(u_truth %*% t(Lambda_truth), 2, beta_truth, "+")
p_truth <- plogis(eta_truth)
y_full <- matrix(
  rbinom(2048 * 6, size = 1, prob = as.vector(p_truth)),
  nrow = 2048,
  ncol = 6
)
```

R's `as.vector()` consumes `p_truth` column-major, and
`matrix(..., nrow = 2048, ncol = 6)` reconstructs that same unit-by-trait
layout. No alternate loop order is equivalent for the frozen RNG stream.

Freeze these nested prefixes without rejection or redraw:

- `N128`: rows 1–128;
- `N512`: rows 1–512;
- `N2048`: rows 1–2048.

No separation repair, pattern balancing, filtering or response resimulation is
allowed. Every prefix must have finite complete binary responses and both
outcomes in every trait. Failure writes `MECHANICAL_STOP` and stops. Record
SHA-256 for `serialize(y, NULL, version = 2)` for each prefix and for the full
latent draw. Latents are DGP provenance only and are unavailable to fitting.

The nested ladder changes sample size and the empirical pattern distribution
together. It is a dependent-prefix stress test, not a causal information
intervention, replicated recovery experiment, or calibration study. Parameter
recovery need not improve monotonically.

## Three frozen invariant starts

Starts are defined as invariant \((\beta,\Lambda)\) objects and converted
mechanically into both charts and both guard values. Conversion failure is a
test failure; chart-specific hand tuning is forbidden. Their frozen names are
`fixed`, `spectral`, and `truth`.

Let

\[
\Lambda_{\mathrm{fixed}}=
\begin{pmatrix}
.45&0\\
.10&.40\\
-.20&.15\\
.20&-.10\\
-.12&-.25\\
.15&.18
\end{pmatrix},
\]

For each fixture prefix, define the clipped empirical intercept

\[
\tilde\beta_t=
\operatorname{logit}
\left[\min\{0.98,\max(0.02,\bar y_t)\}\right].
\]

The `fixed` start is
\(\beta_{\mathrm{fixed}}=\tilde\beta\) with
\(\Lambda_{\mathrm{fixed}}\) above.

The deterministic `spectral` start uses
\(\beta_{\mathrm{spectral}}=\tilde\beta\). Form the six-trait empirical Pearson
correlation matrix, replace non-finite off-diagonal entries by zero and the
diagonal by one, symmetrize it, and project it to positive semidefinite form by
setting negative eigenvalues to zero. Order eigenpairs by decreasing
eigenvalue, break exact ties by the original eigenvector column order, anchor
each retained eigenvector's sign by making its first nonzero entry positive,
and construct the rank-two loading factor from the leading two eigenvectors
and square roots of their nonnegative eigenvalues. Multiply that factor by
`0.45`. The exact PSD-corrected matrix, eigenpairs, sign choices and resulting
loading matrix are frozen in each fixture input.

The `truth` start is the prospective truth-near invariant start

\[
\beta_C
=0.9\beta^\star+(0.05,-0.04,0.03,-0.02,0.01,-0.05),
\]
\[
\Lambda_C
=0.9\Lambda^\star+
\begin{pmatrix}
0.02&0\\
-0.01&0.015\\
0.01&-0.01\\
-0.015&0.02\\
0.01&0.015\\
-0.02&-0.01
\end{pmatrix}.
\]

The `truth` label means the invariant pair \((\beta_C,\Lambda_C)\). All three
invariant starts are mechanically rotated into `C12` and `C34`;
the cap changes only the inverse chart coordinates, never the invariant start.

Every start remains in the denominator. No added start, jitter, retry from a
failed coordinate, truth restart, chart-specific start, threshold change or
optimizer-control change is permitted after the one-shot run begins.

## Two optimization routes

Both routes operate on the mean negative log likelihood

\[
\bar L_{N,H}(\theta)=-\widehat\ell_{N,H}(\theta)/N.
\]

They use pattern compression, freshly solve all conditional modes whenever
\(\theta\) changes, and retain every phase as a separate immutable task.

### Route A — finite-rule objective

Route A minimizes \(\bar L_{N,H}\) using its full finite-rule derivative,
including the dependence of conditional modes and curvature on \(\theta\).

For each start and guard:

1. optimize at \(H=9\) with `nloptr::nloptr()`, algorithm
   `NLOPT_LN_BOBYQA`, raw chart-coordinate bounds `[-12, 12]`,
   `xtol_rel = 1e-8`, `ftol_abs = 1e-10`, `maxeval = 2000`, and
   `print_level = 0`;
2. consume that endpoint and optimize at \(H=15\) with
   `stats::optim(method = "BFGS")`, the Richardson finite-rule gradient
   specified below, `maxit = 500`, and `reltol = 1e-10`;
3. consume the H15 endpoint in exactly one allowed \(H=31\)
   `stats::optim(method = "BFGS")` polish using the same gradient,
   `maxit = 200`, and `reltol = 1e-12`;
4. evaluate the resulting endpoint at \(H=21\) and \(H=31\) for
   certification. No additional H31 optimization, retry or fallback is
   permitted.

Every finite-rule derivative is computed with
`numDeriv::grad(method = "Richardson", method.args = list(eps = 1e-5,
d = 1e-4, zero.tol = sqrt(.Machine$double.eps), r = 4, v = 2))`, using
the installed frozen `numDeriv` source recorded in the manifest. Independent
symmetric finite-difference checks use
\(h_j=10^{-5}\max(1,|\theta_j|)\).

A nonzero optimizer code or warning is recorded and is accepted only if every
independent mode, finiteness, stationarity, quadrature, interiority and
agreement gate passes. An optimizer error is always unhealthy.

### Route B — directly integrated Fisher score

Route B solves

\[
\widehat S^F_{N,H}(\theta)/N=0
\]

using a custom pure-R damped-Newton root method. Its symmetric
finite-difference score Jacobian uses
\(h_j=10^{-5}\max(1,|\theta_j|)\). Each Newton system is solved by SVD with
relative singular-value cutoff `1e-10`; a singular retained system or
condition number above `1e12` is unhealthy.

At the current \(\theta\), set

\[
d_j=\max(1,|\theta_j|).
\]

After the SVD solve produces the raw Newton step \(\delta\), compute

\[
m=\max_j\frac{|\delta_j|}{d_j}.
\]

If \(m>1\), replace \(\delta\) by \(\delta/m\); otherwise leave it unchanged.
Backtracking applies \(\alpha\) to this scaled \(\delta\), so the accepted
candidate is \(\theta+\alpha\delta\).

Let \(s=\widehat S^F_{N,H}(\theta)/N\). Starting with \(\alpha=1\), halve at
most 30 times and accept only under the Armijo score-norm decrease

\[
\|s_{\mathrm{new}}\|_\infty
\le (1-10^{-4}\alpha)\|s\|_\infty.
\]

Failure to accept a step is unhealthy. For each start and guard:

1. solve at \(H=15\), with at most 100 iterations;
2. consume that endpoint in exactly one allowed \(H=31\) score polish, with
   at most 50 iterations;
3. evaluate the resulting endpoint at \(H=21\) and \(H=31\) for
   certification. No H9 score fit, additional H31 solve, retry or fallback is
   permitted.

Route B stops only when the scaled mean-score infinity norm is `<1e-7`.
A singular solve, condition number above `1e12`, or failure to accept a step
within 30 halvings is unhealthy.

The two routes are independent optimizer paths. Route B must not call Route
A's optimizer or use Route A's terminal coordinate except in final
adjudication.

## Scaling and stationarity

Stationarity is assessed in the interpretable local chart coordinates

\[
\xi=(\beta_1,\ldots,\beta_6,
\log r_1,\ldots,\log r_6,
\alpha_b,\{\alpha_t:t\notin(a,b)\}).
\]

Let \(s_j=\max(1,|\xi_j|)\). A candidate passes final stationarity only when,
at \(H=31\),

\[
\max_j s_j
\left|\frac{\partial[-\widehat\ell_{N,31}]}{N\partial\xi_j}\right|
<10^{-7},
\]

\[
\max_j s_j
\left|\frac{-\widehat S^F_{N,31,j}}{N}\right|<10^{-7},
\]

and the maximum scaled discrepancy between the two score definitions is
`<1e-6`.

The scaled Hessian of the mean negative log likelihood must be finite, have no
eigenvalue below `-1e-8`, and have condition number `<1e8` after restriction
to the 17 identified chart coordinates. A candidate must also have no
improving damped Newton/trust step larger than `1e-9` per unit.

An optimizer success code or small relative objective change alone never
certifies stationarity.

## Quadrature convergence thresholds

At every candidate endpoint:

- `abs(ell31 - ell21) / N < 1e-8`;
- maximum scaled mean-score difference H21 versus H31 `<1e-6`, separately
  for the finite-rule derivative and Fisher score;
- maximum observed-pattern `abs(log_pi31 - log_pi21) < 1e-7`;
- maximum observed-pattern posterior-score difference `<5e-6`.

H9 is a Route-A optimization aid and supplies no evidence. H15 supplies only a
candidate. Each route has exactly one prospectively allowed H31 polish; its
result is then evaluated at H21 and H31 for certification. If that polished
endpoint is not stationary at H31, the attempt fails. The node ladder is not
extended and no second H31 rescue optimization is allowed inside Design 99.

## Independent direct-integration oracles

Certification uses two implementations that share only \((y,\beta,\Lambda)\)
and stable scalar `softplus`:

1. **Nested oracle:** use nested `stats::integrate()` calls directly over
   \((-\infty,\infty)^2\), with `subdivisions = 1000`,
   `rel.tol = 1e-11`, and `abs.tol = 1e-13`. It uses no conditional mode,
   adaptive-GH nodes, adaptive transformation or AGH log-weight helper.
2. **Cubature oracle:** use `cubature::hcubature()` from `cubature` version
   `2.1.4.1` directly on \([-10,10]^2\), with `relTol = 1e-11`,
   `absTol = 1e-13`, and `maxEval = 5e6`. It uses no AGH nodes, conditional
   mode, conditional Hessian or AGH log-weight helper.

For the cubature truncation, record the standard-normal union bound

```r
B0 <- 4 * pnorm(-10, lower.tail = TRUE)
```

for probability mass outside \([-10,10]^2\). Because the Bernoulli likelihood
is at most one, the omitted pattern-probability mass is at most `B0`.
For every cubature pattern estimate, define
`lower_bound = estimate - error - B0` and require both
`lower_bound > 0` and `B0 / lower_bound < 1e-8`. This makes the
omitted-tail log effect smaller than the comparison tolerance; failure is
`QUADRATURE_STABILITY_STOP`.

The loading-score tail is bounded separately. In invariant
\((\beta,\Lambda)\) coordinates define

```r
B1 <- 2 * dnorm(10) +
  sqrt(2 / pi) * 2 * pnorm(-10, lower.tail = TRUE)
```

because \(|y_t-p_t|\le1\) and the complement of the square is contained in the
union of the two coordinate-tail events. Use `B0` for each of the six beta
score components and `B1` for each of the twelve loading-score components,
forming the nonnegative 18-vector \(b_{\mathrm{inv}}\).

For each chart, let

\[
J_{\mathrm{chart}}
=\frac{\partial(\beta,\operatorname{vec}\Lambda)}
       {\partial\theta^\top}.
\]

Transform the tail bound with the absolute local chain-rule Jacobian:

\[
b_{\mathrm{chart}}
=|J_{\mathrm{chart}}|^\top b_{\mathrm{inv}}.
\]

Every component of \(b_{\mathrm{chart}}\) must be `<5e-7`, one tenth of the
`5e-6` score-comparison tolerance. For a cubature chart-score estimate
\(\widehat s_j\) with transformed reported numerical error \(e_j\), retain

\[
[\widehat s_j-e_j-b_{\mathrm{chart},j},
 \widehat s_j+e_j+b_{\mathrm{chart},j}]
\]

as its certified lower/upper score interval. All nested/cubature/AGH score
comparisons use these lower and upper intervals, including the tail bound,
rather than comparing point estimates alone. Tail-bound or interval failure is
`QUADRATURE_STABILITY_STOP`.

Both oracles evaluate all observed patterns at every representative H31
endpoint and all 64 patterns at the final N2048 endpoint. Each oracle's
reported absolute numerical error must be at most one tenth of the comparison
tolerance.

AGH passes the independent oracle gate only when:

- weighted total log-likelihood disagreement is `<1e-8` per unit;
- maximum scaled mean-score disagreement is `<5e-6`;
- maximum pattern log-integral disagreement is `<1e-7`;
- nested and cubature oracles agree within the same bounds.

Across all 64 patterns, independently verify

\[
\left|\sum_y\pi_y(\theta)-1\right|<10^{-10},
\qquad
\left\|\sum_y\nabla_\theta\pi_y(\theta)\right\|_\infty<10^{-8}.
\]

Oracle disagreement is retained as `QUADRATURE_STABILITY_STOP`; the most
attractive engine is never selected post hoc.

## Cross-start, cross-route, cross-chart and cross-guard agreement

Within each route/chart/fixture cell, all six endpoints from three starts and
two guards must be mechanically healthy. All six—not a convenient subset—must
satisfy:

- objective disagreement `<1e-9` per unit;
- beta maximum disagreement `<1e-3`;
- Sigma maximum disagreement `<5e-3`;
- population-marginal-probability disagreement `<1e-4`.

Only then may the cell evaluator select the endpoint with the largest
mechanically certified H31 log likelihood. Exact numerical ties use
`cap4 < cap8`, then `fixed < spectral < truth`. The dependent oracle runs
after this selection, and an oracle failure fails the cell without fallback.

Across Route A and Route B, across `C12` and `C34`, and across guards \(C=4\)
and \(C=8\), all representative invariant endpoints must meet the same four
agreement thresholds.

Population probabilities use an independent H31 normalized-\(N(0,1)\) tensor
rule and must themselves pass an H21/H31 difference `<1e-7`.

## Identifiability diagnostics

Enumerate the 64 model pattern probabilities in the frozen integer-code order,
drop code 63, and form the \(63\times17\) Jacobian with respect to
\(\xi\). Verify it independently by Richardson differences.

At every representative endpoint record:

- numerical rank under relative singular-value thresholds
  \(10^{-6},10^{-8},10^{-10}\);
- largest and smallest singular values;
- reciprocal condition number;
- the weakest right-singular direction;
- a symmetric profile in that direction at standardized displacements
  \(0,\pm0.25,\pm0.5,\pm1,\pm2\).

N2048 admission requires rank 17 at `1e-8`, Jacobian reciprocal condition
number `>1e-8`, and scaled observed-information condition number `<1e8`.
Values between `1e-8` and `1e-6` are reported as weak-identification warnings
even when admission remains possible. Cap-active, chart-dependent, rank-lost
or flatter-than-`1e-8` per-unit profile behavior yields
`WEAK_OR_NONIDENTIFIED_REFERENCE`.

The N128 and N512 diagnostics are reported without claiming that changes are
caused only by information.

## Symbolic-to-execution alignment

| Symbol in prose | Numerical object / keyword | DGP draw | Recovery output | Truth value |
|---|---|---|---|---|
| \(Y_{it}\) | 64-pattern count vector plus frozen response matrix | Bernoulli draw from \(p_{it}\) | fixture hashes and pattern counts | generated from seed 9902401 |
| \(u_i\) | unavailable to fit; prior integration variable | column-major \(N_2(0,I_2)\) draw | DGP hash only | standard normal |
| \(\beta\) | six bounded chart intercepts | fixed in linear predictor | cross-route/chart beta | \((-0.70,-0.35,-0.10,0.20,0.45,0.70)\) |
| \(\Lambda\) | chart-specific radii and angles | fixed in linear predictor | never compared raw across charts | matrix frozen above |
| \(\Sigma\) | `Lambda %*% t(Lambda)` | implied by \(\Lambda^\star\) | invariant cross-route/chart matrix | \(\Lambda^\star\Lambda^{\star\top}\) |
| \(\hat u_y\) | damped-Newton conditional mode | not drawn | per-pattern mode/score/decrement | unique numerical target |
| \(Q_y\) | negative conditional Hessian | not drawn | eigenvalues and Cholesky | \(I+\Lambda^\top W\Lambda\) |
| \(\pi_y\) | AGH, nested integral and cubature | implied pattern probability | three-way log-integral comparison | exact integral target |
| \(\ell_N\) | pattern-count weighted log probabilities | implied by fixture | route objective and oracle objective | exact marginal target |
| \(S_N^F\) | directly integrated Fisher score | not drawn | route-B score and oracle score | zero at an interior optimum |
| \(\bar p_t\) | independent H31 population integral | implied marginal prevalence | invariant cross-route/chart value | integral under DGP |

No row may be deleted or left without a recovery output during implementation.

## Frozen task graph and timeouts

One `preflight` control task gates creation of the real UUID and scientific
graph but is not itself a scientific task. After preflight passes, the real
graph has exactly 208 immutable scientific tasks:

1. Route A has 108 optimizer-phase tasks:
   `N{128,512,2048} × chart{12,34} ×
   start{fixed,spectral,truth} × guard{cap4,cap8} × phase{H9,H15,H31}`.
   Each A-H15 task depends on its matching A-H9 task, and each A-H31 task
   depends on its matching A-H15 task.
2. Route B has 72 optimizer-phase tasks:
   `N{128,512,2048} × chart{12,34} ×
   start{fixed,spectral,truth} × guard{cap4,cap8} × phase{H15,H31}`.
   Each B-H31 task depends on its matching B-H15 task.
3. There are 12 cell-evaluator tasks, one per `N × route × chart` cell. Each
   depends on its six final endpoints: three starts times two guards, using
   A-H31 for Route A and B-H31 for Route B.
4. There are 12 oracle tasks, each depending on one cell evaluator.
5. There are three N-evaluator tasks. Each depends on the four oracle tasks
   for its N: two routes times two charts.
6. One finalizer depends on all three N evaluators.

Thus `108 + 72 + 12 + 12 + 3 + 1 = 208`.

The frozen wall-time limits are:

| Task class | Timeout |
|---|---:|
| preflight | 600 s |
| A-H9 at N128 / N512 / N2048 | 1800 / 3600 / 7200 s |
| A-H15 at N128 / N512 / N2048 | 3600 / 7200 / 14400 s |
| A-H31 at N128 / N512 / N2048 | 3600 / 7200 / 14400 s |
| B-H15 at N128 / N512 / N2048 | 3600 / 7200 / 14400 s |
| B-H31 at N128 / N512 / N2048 | 3600 / 7200 / 14400 s |
| cell evaluator | 300 s |
| oracle | 1800 s |
| N evaluator | 300 s |
| finalizer | 300 s |

A cell evaluator may select a representative only after every endpoint from
all three starts and both guards is present, mechanically healthy, and passes
the within-cell agreement checks. Mechanically failed endpoints remain in the
denominator and prevent selection. The dependent oracle then certifies only
that selected representative. Oracle failure fails the cell; it never falls
back to another start or endpoint. The sole admission exception is the
prospectively classified N128 finite-information/noninterior optimization
outcome defined at G5. If that exception alone prevents selection, the cell
evaluator still writes its expected terminal, its dependent oracle writes an
expected dependency-blocked terminal, and the N128 evaluator may classify the
result `DIAGNOSTIC_N128_NONINTERIOR`. The exception never relaxes a
fixed-coordinate quadrature or oracle requirement.

## Gate sequence

### G0 — frozen contract and isolation

- Only new Design-99 private paths and this contract may change.
- Predecessor and package/public paths are byte-identical.
- The exact GOAL, sources planned, thresholds, DGP, RNG, starts, charts,
  guards, task DAG, compute route and terminal labels are frozen.
- Gauss and Noether approve the symbolic alignment; Rose approves isolation.

No implementation, fixture draw or numerical evaluation precedes G0 approval.

### G1 — algebra and tests of the tests

Without scientific fitting:

- verify normalized GH moments and weight sums at H9/H15/H21/H31;
- verify two independently written pure-R objective paths agree `<1e-11`;
- verify transformed finite-rule gradients and Fisher scores against
  Richardson differences to relative error `<1e-6`;
- verify chart round trips and invariant Sigma equality `<1e-12`;
- verify response compression equality `<1e-12`;
- verify conditional gradient/Hessian formulas and strict concavity;
- verify Gaussian-integrand exactness;
- verify all 64 probabilities sum to one and probability derivatives sum to
  zero at at least three bounded coordinates;
- include failure-before-fix tests for the prior constant,
  \(-\log\phi_2(z)\), \(\log|A_y|\), \(\sqrt2\), chart chain factors and
  theta-dependent finite-rule versus Fisher-score distinction.

Any G1 failure writes `MECHANICAL_STOP` and stops before fixture creation or
fits.

### G2 — fixture, provenance, supervision and non-evidence smoke

- create one UUID and immutable manifest;
- freeze source/toolchain/RNG/quadrature checksums;
- create and hash N128/N512/N2048 prefixes;
- pass crash, timeout, malformed, partial, duplicate, interruption,
  orphan-resume and aggregation-only fault tests;
- run one separately marked deterministic `NON_EVIDENCE` synthetic invocation
  smoke and projected-full-graph benchmark in a separate output root. Neither
  may use the real seed, fixture, UUID or result root.

Any global fixture, provenance or supervision failure writes
`PROVENANCE_STOP` or `MECHANICAL_STOP`, as applicable, and stops. Smoke and
benchmark output are never scientific evidence.

### G3 — fixed-coordinate quadrature and oracle stress

At truth and all frozen starts, for both charts and both guards, evaluate the
route-specific H9/H15/H21/H31 objectives, both scores, all conditional modes,
nested integration and cubature. Apply the algebra, mode, convergence and
oracle gates.

Failure yields `QUADRATURE_STABILITY_STOP` or `MECHANICAL_STOP` and stops
before free optimization.

### G4 — chart, guard and local-identification admission

At truth and fixed stress coordinates, evaluate both chart Jacobians, guard
profiles, anchor minors and weakest directions. If chart conversion,
interiority, rank or conditioning fails prospectively, write
`WEAK_OR_NONIDENTIFIED_REFERENCE` and stop before free optimization.

### G5 — N128

Run both routes, both charts, three starts and guards \(C=4,8\). Every
fixed-coordinate quadrature and oracle mechanic must pass, every attempted
task remains in the denominator, and every optimization endpoint is retained.

N128 optimization is diagnostic. A result that is prospectively classified as
finite-information/noninterior may fail N128-only interiority, identification,
stationarity, start-agreement, route-agreement, chart-agreement or cap4/cap8
agreement without blocking `BOUNDED_ORACLE_PASS`. The record must name the
failed checks. Every expected optimizer-phase and cell-evaluator terminal must
exist. If a cell cannot select solely for one of these prospectively allowed
reasons, its oracle must write an expected dependency-blocked terminal rather
than disappear or run on a fallback. The N128 evaluator then records
`DIAGNOSTIC_N128_NONINTERIOR`; this is an N-evaluator classification, never a
global terminal label.

This exception cannot absorb a provenance, mechanical, fixed-coordinate
quadrature/oracle, infrastructure, missing-terminal or malformed-terminal
failure, and it cannot be applied retrospectively to another failure mode.

### G6 — N512

Repeat the full graph using only the frozen N512 prefix and its own empirical
components of the fixed and spectral starts. No N128 endpoint is a restart. It
may be recorded as an additional diagnostic coordinate only. N512 must pass
every numerical, identification, chart, guard, stationarity, optimizer,
agreement and oracle gate; the N128 diagnostic exception does not apply.

### G7 — N2048

Repeat the full graph using only the frozen N2048 prefix. N2048 must pass every
numerical, identification, chart, guard, stationarity, optimizer, agreement
and oracle gate. Additionally require the N2048 Jacobian/information gates,
all-64-pattern independent oracle checks, and final invariant interiority. The
N128 diagnostic exception does not apply.

### G8 — adjudication and closeout

Aggregate immutable terminals without constructing an objective or launching
a worker. Apply the truth table below, retain every failure, obtain independent
mathematical, numerical, provenance and mechanical reviews, and write the
plan-versus-actual, check-log, after-task and handover records.

## Gate truth table

Apply the first matching row from top to bottom:

For this table, a prospectively classified N128
finite-information/noninterior diagnostic is not a chart, identification or
optimizer failure. The exception applies only at N128 and only after all
fixed-coordinate quadrature/oracle mechanics and all provenance, mechanical
and task-integrity requirements pass. Its expected oracle dependency-blocked
terminal is the only allowed dependency-blocked terminal.

| Condition | Terminal label | Further work |
|---|---|---|
| Contract, source boundary, provenance inventory or one-shot isolation invalid | `PROVENANCE_STOP` | stop; no estimator result |
| Host, process-launch, filesystem, timeout or external infrastructure prevents a required task from obtaining a valid terminal | `INFRASTRUCTURE_INCOMPLETE` | retain partial evidence only; do not reinterpret as a numerical result |
| An expected terminal is absent, malformed or dependency-blocked, except an oracle terminal explicitly blocked by its allowed N128 diagnostic cell | `TECHNICAL_INCOMPLETE` | retain partial evidence only |
| Fixture, RNG, pattern coding, symbolic algebra, derivative, fixed-coordinate conditional mode or task schema is invalid | `MECHANICAL_STOP` | stop; no redraw, repair or fit interpretation |
| H21/H31 convergence or nested/cubature/AGH objective or score agreement fails | `QUADRATURE_STABILITY_STOP` | stop; do not add nodes or choose an oracle |
| A required chart conversion, compactness, rank, information or profile gate fails, excluding only the declared N128 diagnostic | `WEAK_OR_NONIDENTIFIED_REFERENCE` | stop; no finite-reference claim |
| An optimizer endpoint is unhealthy, H31 stationarity fails, a cell cannot select, or required start, guard, route or cross-chart agreement fails, excluding only the declared N128 diagnostic | `OPTIMIZER_HEALTH_STOP` | stop; do not add starts, retry, loosen gates or fall back |
| G0–G4, G6 and G7 pass exactly, every expected G5 terminal exists, and G5 either passes or contains only declared N128 diagnostic blocks | `BOUNDED_ORACLE_PASS` | close Design 99; any VA/JJ work needs a separately approved design |

No majority vote, attractive subset, relaxed rescore or fallback label may
override this ordering.

## Accuracy reporting without an accuracy gate

At every representative endpoint report:

- beta RMSE;
- maximum absolute Sigma error;
- RMSE of the six population-marginal probabilities;
- both positive covariance eigenvalues;
- H31 log likelihood at truth and at the fitted endpoint.

These are descriptive on one nested fixture. No truth-error cutoff enters
`BOUNDED_ORACLE_PASS`, because numerical-reference admission is not a
single-fixture recovery or calibration claim.

## Failure-resilient telemetry and one-shot rule

Before a scientific task runs, exclusively create
`dev/design99-exact-reference/results/REAL_RUN.json`. It contains the one
UUID, contract hash, base commit, creation time and reserved status. Its
existence forbids a second scientific root.

The frozen real output root is `dev/design99-exact-reference/results/`.

Every phase is a separate process with immutable input, dependency IDs,
source/input hashes, PID, host, start time, five-second heartbeat, stdout,
stderr, wall time, raw chart coordinates, transformed invariants, objective,
both scores, Hessian/condition diagnostics, modes, quadrature/oracle metrics,
optimizer code, warnings, error, signal and exit status. Terminal JSON is
exclusive-create and never overwritten.

Failed, timed-out, signaled, malformed, duplicate or orphaned tasks are not
retried. Resume may aggregate completed records and launch only never-started
dependency-valid tasks. The finalizer has no objective-construction, fixture,
optimizer or worker-launch path.

## Compute rule

This Gate-0 task performs no fixture draw, numerical evaluation or fit. Design
99 is pure R and has no compilation action. Maintainer approval of this plan
authorizes the local mechanics, deterministic non-evidence benchmark, local
real run when the projected full graph is at most 45 minutes, and Totoro real
run only when that projection exceeds 45 minutes. No additional compute gate
or Totoro approval is required.

- G1–G4 and the non-evidence smoke run locally with
  `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1` and one numerical-library
  thread per process;
- before the real UUID, benchmark the projected full real graph using a
  separate deterministic `NON_EVIDENCE` synthetic fixture and output root;
  this benchmark must never use the real seed, fixture, UUID or result root;
- if the projected full real graph is `<=45 minutes`, run the one-shot ladder
  locally;
- if it exceeds `45 minutes`, route the one-shot ladder to Totoro before
  creating the real UUID, using the existing standing-authority ControlMaster,
  at most eight concurrent single-thread processes and never more than 32
  cores for this design;
- no compute runs on a login node;
- no DRAC;
- no GitHub Actions simulation/reference compute and no campaign artifact;
- outputs remain local and in the private Design-99 result packet.

Compute routing is fixed before the one-shot UUID. An already launched task is
never migrated or replayed.

## Claim boundary

`BOUNDED_ORACLE_PASS` means only:

> On the fresh Design-99 q=2 intercept-only Bernoulli fixture and its three
> nested prefixes, the private response-pattern-compressed AGH reference met
> every fixed-coordinate mode, quadrature and independent-oracle gate; N512
> and N2048 met every optimizer, chart, compactness, stationarity and
> local-identification gate; and N128 either met those optimization gates or
> retained only the prospectively allowed finite-information/noninterior
> diagnostic.

It does not mean:

- Design 98 is repaired, explained, rescored or contradicted;
- VA, JJ or EVA is correct or ready to test;
- the q=2 model is calibrated across repeated fixtures;
- q4/q6 or sparse high-dimensional behavior is covered;
- package integration, public likelihood claims, rank selection, inference or
  release work is authorized.

Any later VA/JJ discriminator begins as a new approved design with its own
fresh goal, fixtures, thresholds, UUID and compute gate.
