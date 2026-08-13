# Binary LA-MSPL estimator

Status: Lane B implementation and validation contract for the planned gllvmTMB 0.7 release.

## Purpose and boundary

Binary species matrices routinely contain rare and ubiquitous traits. A fixed
design may then have complete or quasi-complete separation, while an estimated
latent block creates additional loading and covariance directions that an
ordinary GLM detector cannot inspect. The planned 0.7 release therefore separates two
opt-in operations:

1. `screen_control(separation = "fixed")` certifies fixed-design separation
   before fitting; and
2. `gllvmTMB(..., estimator = "mspl")` fits a softly penalised Laplace point
   estimator on the admitted binary GLLVM surface.

Neither operation deletes species, chooses latent rank, or runs automatically.
`estimator = "ml"` remains the unchanged default. LA-MSPL is not described as
ordinary MAP, Firth regression, bias reduction, or calibrated inference.

The research gap is deliberately narrow. Fixed-design binomial GLM separation
has Jeffreys/Firth solutions; Sterzinger and Kosmidis (2023) treat mixed-effects
logistic models with covariance boundaries; and high-dimensional logistic
regression has separate recent theory. The case extended here is a binary
GLLVM whose latent variables and loadings are estimated inside the Laplace
objective.

## Symbolic estimator

For contributing row (i),

\[
y_i\in\{0,1\},\qquad
\eta_i=x_i^\top\beta+a_i(\Lambda)^\top u,
\qquad u\sim N(0,I).
\]

The admitted surface requires a zero normalized offset. Let
\(X_*=X_{\mathrm{fix}}K\) be the derivative design for the independent free
fixed-effect coordinates after TMB maps, ties, and pinned values are resolved.
The estimator maximizes

\[
Q_{LA}=\ell_{LA}
+c_n\,\frac12\log\det(X_*^\top W_g(\beta)X_*)
-c_n V_{\mathrm{loading}}
-c_n V_{\mathrm{covariance}},
\qquad
c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}.
\]

Here \(N_{\mathrm{eff}}\) is the number of single-trial Bernoulli rows and
\(p_{\mathrm{free}}\) counts independent penalised outer coordinates, never
Laplace-integrated scores. The fixed-only expected-information weights are

\[
\begin{aligned}
w_{\mathrm{logit}}(\eta)&=\mu(1-\mu),\\
w_{\mathrm{probit}}(\eta)&=
  \frac{\phi(\eta)^2}{\Phi(\eta)\Phi(-\eta)},\\
w_{\mathrm{cloglog}}(\eta)&=
  \frac{a^2}{\exp(a)-1},\quad a=\exp(\eta).
\end{aligned}
\]

No positive weight floor is permitted. The determinant uses the fail-closed,
numerically guarded weighted-maxvol atom in
`src/lane_b_jeffreys_maxvol_atomic_v8.h`, with direct positive Cauchy-Binet
checks on tractable designs. Its a-posteriori bounds certify the inverse and
maximum-volume exchange decisions; they are not a formal interval certificate
for every returned value, gradient, and Hessian entry.

For an ordinary loading row \(\lambda_t\),

\[
V_{\mathrm{loading}}=\sum_t
\left\{\sqrt{1+\lVert\lambda_t\rVert^2}-1\right\}.
\]

For spatial fits, \(r=\sqrt{8}/\kappa\) and \(r_0\) is the RMS distance of
the distinct observed sites from their centroid. The range coordinate is
\(\log(r/r_0)\). `spatial_indep()` also penalises each independently free
marginal log-SD once,

\[
\log\sigma_t=-\tfrac12\log(4\pi)-\log\kappa-\log\tau_t,
\]

while `spatial_latent()` applies the row-radial penalty to reference-scale
loadings

\[
B=\Lambda_{spde}/\{\sqrt{4\pi}\kappa\}.
\]

Every covariance coordinate uses
\(v(x)=\sqrt{1+x^2}-1\). The reference coordinates make the spatial penalty
comparable across coordinate units; finite-mesh covariance is retained as a
separate reported quantity rather than silently substituted for the continuum
reference scale.

## Finiteness statement

On the ideal real-arithmetic, unclipped, complete-Bernoulli surface, assume:

- `X_*` has full column rank and at least one column;
- exactly one admitted latent/spatial block is active;
- every finite spatial coordinate produces a positive-definite finite-mesh
  precision and an algebraically valid whitening; and
- at least one finite admissible parameter point exists.

For logit, probit, and complementary log-log links, each Bernoulli conditional
log-pmf is concave and bounded above. After Gaussian whitening the inner
negative Hessian is \(H=I+A^\top W_yA\succeq I\), so the normalized Laplace
log likelihood is bounded above. Along every divergent fixed-effect direction,
all supported expected-information weights vanish on the affected tails;
Cauchy-Binet and full rank then give

\[
\log\det(X_*^\top W_gX_*)\longrightarrow-\infty.
\]

The radial loading, marginal-SD, and log-range penalties tend to infinity on
their divergent paths. Thus the penalised Laplace objective is coercive over
the admitted outer coordinates and attains a finite global maximum.

This is an existence result for the specified Laplace objective. It does not
establish uniqueness, a positive latent rank, rank recovery, bias reduction,
consistency, asymptotic normality, ML efficiency, standard-error calibration,
confidence intervals, or hypothesis tests. In compiled binary64 arithmetic,
typed atom failures and any final complementary-log-log tail-extension contact
fail closed; numerical finiteness alone is not the theorem.

## Proof obligations discharged by the implementation

The proof was reviewed before the TMB implementation and its obligations were
then checked against the resolved parameter map. The live status is:

| Obligation | Implementation evidence | Status |
|---|---|---|
| Exact Bernoulli log-pmf on the MSPL branch | The MSPL likelihood bypasses the legacy probability clamp and uses link-specific stable log-pmfs; ML retains its historical branch unchanged. | Discharged for finite evaluated points; any cloglog tail extension is counted and fails the promotion gate. |
| Full-rank free fixed design | `X_* = X_fix K` is constructed after fixed values, ties, and maps; rank loss and guarded-atom failures stop before a fit is returned. | Discharged on the admitted resolved design. |
| Every divergent ordinary loading coordinate is penalised once | The lower-triangular free loading pack is expanded to trait rows and receives the row-radial penalty; map/tie and objective-decomposition tests check the count and scale. | Discharged for the ordinary admitted pack. |
| Exclusive outer and random blocks | Preflight rejects predictor-informed latent means, slopes, extra random effects, free Bernoulli Psi, extra covariance tiers, grouped trials, and response masks. The resolved random block must be exactly `z_B`, `omega_spde`, or `omega_spde_lv`. | Discharged by fail-loud construction tests. |
| Penalty-off Laplace decomposition | A second ML tape is evaluated at the MSPL outer point; the fresh penalised tape value must equal the penalty-off value plus all reported penalty terms within the stated numerical tolerance. | Discharged for every returned fit. |
| Spatial reference coordinates | The fitted penalty and reports use the same marginal SD or loading scale and the same dimensionless log-range ratio; independent oracles recover those coordinates. | Algebraic transform discharged. |
| Positive-definite, correctly normalised finite-mesh spatial precision over the entire parameter domain | Admitted mesh fixtures and all three links pass construction, Hessian, decomposition, and marginal-coordinate oracles. | Still a premise of the conditional spatial theorem, not a universal analytic proof for every possible user mesh. |

Therefore the ordinary theorem applies to the ideal objective implemented by
the admitted MSPL branch, subject to the explicit binary64 fail-closed
contract. Spatial existence remains conditional in exactly the sense stated
above; passing simulation cells can promote an empirical spatial regime but
cannot turn the finite-mesh premise into an unconditional theorem.

## Public contract

Admitted for planned 0.7 promotion:

- complete, unweighted, single-trial Bernoulli rows;
- one common logit, probit, or complementary log-log link;
- a full-rank resolved fixed design and all-zero offset;
- native TMB Laplace integration; and
- exactly one of ordinary `latent(d = 1:2, unique = FALSE)`, standalone
  `spatial_indep()`, or standalone `spatial_latent(d = 1:2, unique = FALSE)`.

Deferred: FIML, grouped binomial, mixed families/links, predictor-informed
latent means, extra random effects, random slopes, free Bernoulli Psi, `d > 2`,
phylogenetic/animal/kernel tiers, anisotropy, spatiotemporal models, VA, AGHQ,
Julia MSPL, rank selection, and general inference.

An MSPL fit has class `c("gllvmTMB_mspl", "gllvmTMB_multi", "gllvmTMB")`.
Point extraction and prediction remain available after their structure-specific
tests. `logLik()`, AIC, BIC, LRT/`anova()`, profiles, `vcov()`, `confint()`,
`standard_errors()`, and bootstrap interval surfaces fail with typed errors.
The penalty-off Laplace value at the MSPL point is stored as provenance, not
exposed as a maximized likelihood.

`loading_ridge` is an integration-neutral alias for the existing loading ridge.
That ridge is a Gaussian-prior MAP regularizer. It remains a comparator because
finite estimates do not imply minimum prediction or estimation risk. Public
ridge-plus-MSPL is an error; the combined arm exists only inside the frozen B2
ablation harness.

## Validation layers

The release evidence has four layers:

1. B0 overlap/complete/quasi certificates and fixed-design map/offset tests;
2. symbolic-to-C++ objective decomposition, map/tie checks, independent
   Cauchy-Binet determinant oracles, and spatial reference-scale oracles;
3. compiled logit/probit/cloglog fits for ordinary q=1:2,
   `spatial_indep()`, and spatial-latent q=1:2, with ML no-op parity; and
4. the retained-attempt B2 campaign under `inst/sim/lane-b/`, including rare
   and ubiquitous tails, column permutations, ridge and hybrid ablations,
   multistart stationarity, covariance/range recovery, and whole-unit
   prediction. Post-launch adjudication additionally requires healthy agreeing
   alternate starts and forms independent link-by-structure spatial family
   gates. It verifies every raw shard against its completion SHA-256 receipt
   and makes the exact 24-cell trait-order audit a mandatory gate for ordinary,
   spatial, and overall promotion. The immutable spatial v1 table is recomputed
   from those authenticated attempts and must match the stored table exactly.
   The exact-B0 validator separately binds the archived v3 source receipt to
   the four immutable launch-file hashes; it does not compare historical B0
   evidence with subsequently repaired adjudicator source.
   These additions can only withhold an
   immutable v1 cell pass. The one
   documented exception is a metric repair: the approved relative-Frobenius
   covariance statistic supersedes the runner's elementwise diagnostic while
   keeping the frozen threshold unchanged.

Multistart covariance agreement uses the retained scientific-order matrices:
`||Sigma_alt - Sigma_primary||_F / max(1, ||Sigma_primary||_F) <= 1e-4`.
The immutable ledger's maximum elementwise difference remains diagnostic and is
not the promotion statistic.

Simulation campaigns run on Totoro or DRAC, never GitHub Actions. Promotion
requires the frozen cellwise gates in `inst/sim/lane-b/README.md`; a finite
optimizer return by itself does not pass.

## References and provenance

- Sterzinger P, Kosmidis I. 2023. Maximum softly-penalized likelihood for mixed
  effects logistic regression. *Statistics and Computing* 33:53.
  <https://doi.org/10.1007/s11222-023-10217-3>.
- Kosmidis I, Firth D. 2021. Jeffreys-prior penalty, finiteness and shrinkage in
  binomial-response generalized linear models. *Biometrika* 108:71-82.
  <https://doi.org/10.1093/biomet/asaa052>.
- Kosmidis I, Schumacher D. `detectseparation`: fixed-design GLM separation
  detection software. It is not a GLLVM or GLMM MSPL fitter.
- Sterzinger P, Kosmidis I, Moustaki I. 2026. Maximum Softly Penalized
  Likelihood in Factor Analysis. *Psychometrika* 91:494-507.
  <https://doi.org/10.1017/psy.2026.10092>. Its logistic-factor extension is
  future work, not proof for this estimator.
- Sterzinger P, Kosmidis I. 2026. Diaconis-Ylvisaker prior penalized likelihood
  for \(p/n\to\kappa\in(0,1)\) logistic regression. arXiv:2311.07419v3.
  <https://doi.org/10.48550/arXiv.2311.07419>. This motivates the ridge
  comparison; it supplies no GLMM/GLLVM theory.
- van der Veen B, Hui FKC, Hovstad KA, O'Hara RB. 2023. Concurrent ordination:
  Simultaneous unconstrained and constrained latent variable modelling.
  *Methods in Ecology and Evolution* 14:683-695.
  <https://doi.org/10.1111/2041-210X.14035>.

The guarded determinant implementation was developed in this Lane B work;
it was not copied from `brglm2`, `detectseparation`, or another package.
