# Design 94 — private Jaakkola--Jordan variational C++ prototype

## Decision

NotebookLM research identified the Pólya--Gamma interpretation of the
Jaakkola--Jordan quadratic logistic bound as a stronger candidate than an
uncontrolled Taylor EVA correction: it is a genuine lower-bound construction
for Bernoulli-logit models under its variational assumptions.  This design
implements only that narrow bound as an unexported TMB prototype.

The target is fixed intercepts and fixed q=2 loadings, with per-unit diagonal
Gaussian variational means and standard deviations.  There is no global
parameter estimation, package dispatch, public interface, `src/gllvmTMB.cpp`
change, recovery claim, or upstream parity claim.

## Contract

Let \(\eta_{it}=b_t+\lambda_t^\top u_i\),
\(q_i=N_2(m_i,\operatorname{diag}(s_i^2))\), and
\(\mu_{it}=b_t+\lambda_t^\top m_i\),
\(v_{it}=\sum_k\lambda_{tk}^2s_{ik}^2\).  With
\(\kappa_{it}=y_{it}-1/2\), \(\xi_{it}=\sqrt{\mu_{it}^2+v_{it}+10^{-12}}\),
and \(\omega(\xi)=\tanh(\xi/2)/(4\xi)\), the observation lower bound is

\[
B_{it}=\log\sigma(\xi_{it})-\xi_{it}/2+
\omega(\xi_{it})\xi_{it}^2+
\kappa_{it}\mu_{it}-\omega(\xi_{it})(\mu_{it}^2+v_{it}).
\]

The prototype minimizes \(-\sum B_{it}+\mathrm{KL}\{q(u)\Vert N(0,I)\}\).
The epsilon keeps the C++ expression finite at zero mean and variance; because
the bound holds for every positive \(\xi\), it remains a valid bound, while
the independent R oracle uses the same convention.

## Admission checks

The C++ objective and gradient must match an independent pure-R oracle; the
bound must not exceed the quadrature ELBO for a fixed q; and a small deterministic
optimization must reach a finite, stationary result.  The test uses an
`nlminb` phase followed by deterministic BFGS refinement: `nlminb`'s relative
convergence signal alone need not satisfy an absolute gradient criterion.
Failure ends this
prototype.  A pass is `experimental` developer evidence only, not admission of
an EVA/VA feature.
