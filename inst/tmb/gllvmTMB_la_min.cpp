// gllvmTMB_la_min.cpp -- MINIMAL Laplace comparator for the Phase-1 VA
// proof-of-mechanism (Design 72). STANDALONE, EXPERIMENTAL.
//
// This is the apples-to-apples Laplace counterpart of inst/tmb/gllvmTMB_va.cpp:
// the SAME random-intercept + random-slope model with the SAME unstructured
// 2x2 group covariance Sigma, but integrated with TMB's Laplace approximation
// (the latent u in the `random=` argument -> inner Newton mode-find + inner
// Hessian factorisation). It exists ONLY so the benchmark can run BOTH methods
// on byte-identical simulated data and observe where the Laplace inner Hessian
// goes non-PD. It is NOT the production engine and does NOT touch
// src/gllvmTMB.cpp. Compiled standalone via TMB::compile() into its own DLL.
//
// Model:
//   u_g = (u_g0, u_g1) ~ N(0, Sigma)         Sigma 2x2 unstructured (LL')
//   eta_i = beta0 + beta1*x_i + u_{g,0} + u_{g,1}*x_i
//   y_i ~ gaussian(eta, phi)  OR  poisson(exp(eta))
//
// The marginal NLL is -sum_i log p(y_i|u) + sum_g 0.5*(u_g' Sigma^{-1} u_g
// + log det Sigma + d log 2pi), with u declared random so TMB applies Laplace.

#include <TMB.hpp>

template <class Type>
Type objective_function<Type>::operator()()
{
  DATA_VECTOR(y);
  DATA_MATRIX(X);
  DATA_IVECTOR(group);
  DATA_MATRIX(Z);
  DATA_INTEGER(n_group);
  DATA_INTEGER(d);
  DATA_INTEGER(family);   // 0 = gaussian, 1 = poisson(log)

  PARAMETER_VECTOR(beta);
  PARAMETER(log_phi);
  PARAMETER_VECTOR(L_diag);     // log Cholesky diagonal of Sigma
  PARAMETER_VECTOR(L_offdiag);  // strict-lower Cholesky entries
  PARAMETER_MATRIX(u);          // n_group x d LATENT effects (RANDOM)

  int n = y.size();

  matrix<Type> L(d, d);
  L.setZero();
  {
    int k = 0;
    for (int j = 0; j < d; j++) {
      L(j, j) = exp(L_diag(j));
      for (int i2 = j + 1; i2 < d; i2++) L(i2, j) = L_offdiag(k++);
    }
  }
  matrix<Type> Sigma = L * L.transpose();
  matrix<Type> Sigma_inv = Sigma.inverse();
  Type logdet_Sigma = Type(0.0);
  for (int j = 0; j < d; j++) logdet_Sigma += Type(2.0) * L_diag(j);

  Type nll = Type(0.0);

  // Latent prior: -log p(u_g) for each group.
  for (int g = 0; g < n_group; g++) {
    vector<Type> ug(d);
    for (int k = 0; k < d; k++) ug(k) = u(g, k);
    Type quad = Type(0.0);
    for (int a = 0; a < d; a++)
      for (int b = 0; b < d; b++)
        quad += ug(a) * Sigma_inv(a, b) * ug(b);
    nll += Type(0.5) * (quad + logdet_Sigma + Type(d) * log(Type(2.0) * M_PI));
  }

  // Observation likelihood.
  vector<Type> Xbeta = X * beta;
  for (int i = 0; i < n; i++) {
    int g = group(i);
    Type eta = Xbeta(i);
    for (int k = 0; k < d; k++) eta += Z(i, k) * u(g, k);
    if (family == 0) {
      Type sd = exp(log_phi);
      nll -= dnorm(y(i), eta, sd, true);
    } else if (family == 1) {
      Type lambda = exp(eta);
      nll -= dpois(y(i), lambda, true);
    }
  }

  REPORT(Sigma);
  vector<Type> sd_prior(d);
  for (int k = 0; k < d; k++) sd_prior(k) = sqrt(Sigma(k, k));
  REPORT(sd_prior);
  if (d >= 2) {
    Type corr01 = Sigma(0, 1) / (sd_prior(0) * sd_prior(1));
    REPORT(corr01);
  }
  return nll;
}
