// gllvmTMB_va.cpp -- STANDALONE, EXPERIMENTAL variational-approximation (VA)
// proof-of-mechanism template. Phase 1 of Design 72
// (docs/design/72-variational-approximation-feasibility.md).
//
// THIS IS NOT THE PRODUCTION ENGINE. It does NOT touch src/gllvmTMB.cpp,
// its DLL, or its R path. It is a self-contained second DLL whose only job
// is to answer one question: does a mean-field diagonal Gaussian VA ELBO
// converge on the same small-n non-Gaussian random-slope fixtures where the
// Laplace inner Hessian goes non-PD -- WITHOUT collapsing the variance
// components toward zero?
//
// Model (deliberately the minimal GLLVM-adjacent structure that reproduces an
// LA non-PD skip, NOT the full GLLVM):
//
//   For groups g = 1..G each carries a latent 2-vector
//       u_g = (u_g0, u_g1) ~ N(0, Sigma),   Sigma a 2x2 UNSTRUCTURED matrix
//   (random intercept + random slope, the "dep"-style full-unstructured
//   covariance that drives the PHY-18 / SPA-10 non-PD inner-Hessian skips).
//
//   Linear predictor for observation i in group g(i):
//       eta_i = beta0 + beta1 * x_i + u_{g,0} + u_{g,1} * x_i
//
// VA replaces TMB's Laplace integration of u: instead of putting u in the
// `random=` argument (an inner Newton mode-find + inner Hessian factorisation
// -- the thing that goes non-PD), we treat the variational parameters
//   q(u) = prod_{g,k} N(m_{g,k}, s_{g,k}^2)         (mean-field DIAGONAL)
// as ORDINARY MakeADFun parameters and maximise a single smooth ELBO.
// We return the NEGATIVE ELBO to minimise.
//
// ELBO = sum_i E_q[ log p(y_i | u) ]  -  sum_g KL( q(u_g) || N(0, Sigma) )
//
// Closed-form data terms (variational mean of eta: mu_i = (X beta + Z m)_i,
// variational variance of eta: v_i = (Z.^2)(s.^2)_i):
//   gaussian:  E_q[log p] = -0.5*( log(2*pi*phi) + ((y-mu)^2 + v)/phi )
//   poisson(log): E_q[log p] = y*mu - exp(mu + v/2) - lgamma(y+1)
//
// KL for a per-group prior u_g ~ N(0, Sigma) (2x2) and q_g = N(m_g, diag(s_g^2)):
//   KL = 0.5*( tr(Sigma^{-1} diag(s_g^2)) + m_g' Sigma^{-1} m_g
//              - log det diag(s_g^2) + log det Sigma - d )
// so  -KL = 0.5*( sum log s_g^2 - tr(Sigma^{-1} diag s_g^2)
//                 - m_g' Sigma^{-1} m_g + d - log det Sigma ).
// Sigma is kept GENERAL (a dense d x d built from a log-Cholesky) so a later
// slice can swap in a sparse structured precision without reworking the KL.

// Compiled standalone with TMB::compile("gllvmTMB_va.cpp") into its OWN DLL
// (R_init is generated automatically from the file base name); it is NOT
// linked into the package DLL and never shares symbols with src/gllvmTMB.cpp.
#include <TMB.hpp>

template <class Type>
Type objective_function<Type>::operator()()
{
  // ---- DATA ----------------------------------------------------------------
  DATA_VECTOR(y);          // length n response
  DATA_MATRIX(X);          // n x p fixed-effect design (col 0 = intercept)
  DATA_IVECTOR(group);     // length n, 0-based group index for each obs
  DATA_MATRIX(Z);          // n x d latent design within a group's u-vector
                           //   (col 0 = 1 [intercept], col 1 = x [slope])
  DATA_INTEGER(n_group);   // G
  DATA_INTEGER(d);         // latent dimension per group (= 2 here)
  DATA_INTEGER(family);    // 0 = gaussian, 1 = poisson(log)

  // ---- PARAMETERS ----------------------------------------------------------
  PARAMETER_VECTOR(beta);        // p fixed effects
  PARAMETER(log_phi);            // gaussian dispersion (log sd); ignored if poisson
  // Variational parameters (ORDINARY parameters -- NOT random):
  PARAMETER_MATRIX(m);           // n_group x d variational means
  PARAMETER_MATRIX(log_s);       // n_group x d variational log-sds
  // Prior covariance Sigma (d x d) via a log-Cholesky parameterisation:
  //   L lower-triangular, diag entries = exp(theta_diag) (positive),
  //   off-diagonal entries free. Sigma = L L'.
  PARAMETER_VECTOR(L_diag);      // length d  (log of Cholesky diagonal)
  PARAMETER_VECTOR(L_offdiag);   // length d*(d-1)/2 (Cholesky strict lower)

  int n = y.size();

  // ---- Build Sigma = L L' and Sigma^{-1}, log det Sigma --------------------
  matrix<Type> L(d, d);
  L.setZero();
  {
    int k = 0;
    for (int j = 0; j < d; j++) {
      L(j, j) = exp(L_diag(j));
      for (int i2 = j + 1; i2 < d; i2++) {
        L(i2, j) = L_offdiag(k++);
      }
    }
  }
  matrix<Type> Sigma = L * L.transpose();
  matrix<Type> Sigma_inv = Sigma.inverse();
  // log det Sigma = 2 * sum(log diag(L)) = 2 * sum(L_diag)
  Type logdet_Sigma = Type(0.0);
  for (int j = 0; j < d; j++) logdet_Sigma += Type(2.0) * L_diag(j);

  Type nll = Type(0.0);   // negative ELBO

  // ---- KL term: sum_g KL( q(u_g) || N(0, Sigma) ) --------------------------
  // nll += KL  (we minimise negative ELBO = -dataterm + KL)
  for (int g = 0; g < n_group; g++) {
    vector<Type> mg(d), s2g(d);
    Type sum_log_s2 = Type(0.0);
    for (int k = 0; k < d; k++) {
      mg(k) = m(g, k);
      Type sk = exp(log_s(g, k));
      s2g(k) = sk * sk;
      sum_log_s2 += Type(2.0) * log_s(g, k);   // log s^2
    }
    // tr(Sigma^{-1} diag(s2g)) = sum_k Sigma_inv(k,k) * s2g(k)
    Type tr_term = Type(0.0);
    for (int k = 0; k < d; k++) tr_term += Sigma_inv(k, k) * s2g(k);
    // m_g' Sigma^{-1} m_g
    Type quad = Type(0.0);
    for (int a = 0; a < d; a++)
      for (int b = 0; b < d; b++)
        quad += mg(a) * Sigma_inv(a, b) * mg(b);
    Type KL_g = Type(0.5) * (tr_term + quad - sum_log_s2 + logdet_Sigma - Type(d));
    nll += KL_g;
  }

  // ---- Data term: sum_i E_q[ log p(y_i | u) ] ------------------------------
  // Variational mean of eta and variance of eta per observation.
  vector<Type> Xbeta = X * beta;
  for (int i = 0; i < n; i++) {
    int g = group(i);
    Type mu = Xbeta(i);   // E_q[eta_i]
    Type v = Type(0.0);   // Var_q[eta_i]
    for (int k = 0; k < d; k++) {
      Type z = Z(i, k);
      mu += z * m(g, k);
      Type sk = exp(log_s(g, k));
      v += z * z * sk * sk;
    }
    Type dataterm = Type(0.0);
    if (family == 0) {
      // gaussian: phi = sd^2
      Type phi = exp(Type(2.0) * log_phi);
      Type resid = y(i) - mu;
      dataterm = -Type(0.5) * (log(Type(2.0) * M_PI * phi) +
                               (resid * resid + v) / phi);
    } else if (family == 1) {
      // poisson(log): closed-form Gaussian expectation of the log-likelihood
      dataterm = y(i) * mu - exp(mu + Type(0.5) * v) - lgamma(y(i) + Type(1.0));
    }
    nll -= dataterm;
  }

  // ---- Reports -------------------------------------------------------------
  ADREPORT(beta);
  REPORT(Sigma);
  REPORT(logdet_Sigma);
  // Recovered standard deviations + correlation of the prior (for the table)
  vector<Type> sd_prior(d);
  for (int k = 0; k < d; k++) sd_prior(k) = sqrt(Sigma(k, k));
  REPORT(sd_prior);
  if (d >= 2) {
    Type corr01 = Sigma(0, 1) / (sd_prior(0) * sd_prior(1));
    REPORT(corr01);
  }

  return nll;
}
