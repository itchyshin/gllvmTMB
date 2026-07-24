# Design 92 — private VA-first Bernoulli-logit foundation

## Purpose

Design 92 is a small, independent implementation exercise.  It implements a
mean-field Gaussian variational approximation (VA) for an intercept-only,
Bernoulli-logit GLLVM with one latent dimension.  Its purpose is to establish a
testable mathematical baseline before any q=2 or extended variational
approximation (EVA) work is attempted.

This is not a continuation, repair, rescore, or interpretation of Designs
86--91.  It uses no `gllvm` result as evidence and makes no claim about
gllvmTMB, upstream `gllvm`, approximation accuracy, recovery, calibration, or
public capability.  There is no package API, C++, TMB, documentation, or
release change.

## Contract

For fixed trait intercepts \(b_t\), fixed q=1 loadings \(\lambda_t\), and
latent prior \(u_i\sim N(0,1)\), use the mean-field variational family
\(q_i=N(m_i,s_i^2)\), where \(s_i=\exp(\ell_i)>0\).  The implemented ELBO is

\[
\mathcal L(m,\ell)=
\sum_{i,t}E_{q_i}\left[y_{it}(b_t+\lambda_tu_i)-
\log\{1+\exp(b_t+\lambda_tu_i)\}\right]
-\frac12\sum_i\{m_i^2+s_i^2-1-2\ell_i\}.
\]

The expectation is evaluated with deterministic Gauss--Hermite quadrature,
not a Taylor approximation.  The analytic gradients are

\[
\frac{\partial\mathcal L}{\partial m_i}=
\sum_t\lambda_t E_{q_i}(y_{it}-p_{it})-m_i,
\qquad
\frac{\partial\mathcal L}{\partial\ell_i}=
\sum_t\lambda_ts_iE_Z\{Z(y_{it}-p_{it})\}+1-s_i^2,
\]

where \(p_{it}=\operatorname{logit}^{-1}(b_t+\lambda_t(m_i+s_iZ))\).

## Admission checks

The private prototype must pass a scalar `integrate()` oracle comparison,
analytic versus central-difference gradients, trait-permutation invariance,
an ELBO-versus-direct-log-marginal bound, q=2 diagonal algebra, and a
deterministic small-fixture optimizer stationarity check.  Failure stops this
design.  A passing VA baseline permits planning a separate EVA equation-and-
oracle design; it does not authorize EVA implementation.

The q=2 extension fixes \(q_i=N_2(m_i,\operatorname{diag}(s_{i1}^2,s_{i2}^2))\).
For each trait, the linear predictor remains univariate normal with mean
\(b_t+\lambda_t^\top m_i\) and variance
\(\sum_k\lambda_{tk}^2s_{ik}^2\), so its expectation remains a cheap
one-dimensional quadrature.  This is the first rank at which the mean-field
restriction is substantively tested.

## EVA preparation only

The prototype also exposes the Bernoulli-logit log-likelihood through its first
four derivatives.  This is a tested algebraic kernel for a later EVA derivation,
not an EVA objective, fit, or claim.  A future EVA design must independently
specify its expansion point, retained terms, constants, covariance treatment,
and oracle before this kernel is used in an estimator.
