#include <TMB.hpp>

// Private Design-94 prototype.  This translation unit is not included by the
// package build and has no connection to src/gllvmTMB.cpp.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y);
  DATA_VECTOR(intercept);
  DATA_MATRIX(loading);
  PARAMETER_MATRIX(mean);
  PARAMETER_MATRIX(log_sd);

  const int n = y.rows();
  const int traits = y.cols();
  const int q = loading.cols();
  if (intercept.size() != traits || loading.rows() != traits ||
      mean.rows() != n || mean.cols() != q ||
      log_sd.rows() != n || log_sd.cols() != q) error("Design-94 dimension mismatch");

  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < traits; j++) {
      Type mu = intercept(j);
      Type variance = Type(0);
      for (int k = 0; k < q; k++) {
        mu += loading(j, k) * mean(i, k);
        Type sd = exp(log_sd(i, k));
        variance += loading(j, k) * loading(j, k) * sd * sd;
      }
      Type xi = sqrt(mu * mu + variance + Type(1e-12));
      Type omega = tanh(xi / Type(2)) / (Type(4) * xi);
      Type log_sigma_xi = -log(Type(1) + exp(-xi));
      Type constant = log_sigma_xi - xi / Type(2) + omega * xi * xi;
      Type kappa = y(i, j) - Type(0.5);
      Type bound = constant + kappa * mu - omega * (mu * mu + variance);
      nll -= bound;
    }
    for (int k = 0; k < q; k++) {
      Type sd = exp(log_sd(i, k));
      nll += Type(0.5) * (mean(i, k) * mean(i, k) + sd * sd - Type(1) - Type(2) * log_sd(i, k));
    }
  }
  return nll;
}
