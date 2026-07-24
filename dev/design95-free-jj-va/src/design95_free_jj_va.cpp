#include <TMB.hpp>

// Private Design-95 prototype. This file is intentionally outside src/ and is
// not part of gllvmTMB's package compilation or public fitting path.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y);
  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(loading_free);
  PARAMETER_MATRIX(mean);
  PARAMETER_MATRIX(log_sd);

  const int n = y.rows();
  const int traits = y.cols();
  const int q = 2;
  if (traits < q || beta.size() != traits || loading_free.size() != 2 * traits - 1 ||
      mean.rows() != n || mean.cols() != q || log_sd.rows() != n || log_sd.cols() != q)
    error("Design-95 dimension or q=2 identification mismatch");
  for (int i = 0; i < n; i++)
    for (int trait = 0; trait < traits; trait++)
      if (asDouble(y(i, trait)) != 0.0 && asDouble(y(i, trait)) != 1.0)
        error("Design-95 requires complete Bernoulli 0/1 responses");

  matrix<Type> loading(traits, q);
  loading.setZero();
  loading(0, 0) = exp(loading_free(0));
  loading(1, 0) = loading_free(1);
  loading(1, 1) = exp(loading_free(2));
  int cursor = 3;
  for (int trait = 2; trait < traits; trait++) {
    loading(trait, 0) = loading_free(cursor++);
    loading(trait, 1) = loading_free(cursor++);
  }

  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    for (int trait = 0; trait < traits; trait++) {
      Type mu = beta(trait);
      Type variance = Type(0);
      for (int k = 0; k < q; k++) {
        Type sd = exp(log_sd(i, k));
        mu += loading(trait, k) * mean(i, k);
        variance += loading(trait, k) * loading(trait, k) * sd * sd;
      }
      Type xi = sqrt(mu * mu + variance);
      Type omega_small = Type(0.125) - xi * xi / Type(96);
      Type omega_regular = tanh(xi / Type(2)) / (Type(4) * xi);
      Type omega = CppAD::CondExpLt(xi, Type(1e-6), omega_small, omega_regular);
      Type log_sigma_xi = -log(Type(1) + exp(-xi));
      Type constant = log_sigma_xi - xi / Type(2) + omega * xi * xi;
      Type kappa = y(i, trait) - Type(0.5);
      nll -= constant + kappa * mu - omega * (mu * mu + variance);
    }
    for (int k = 0; k < q; k++) {
      Type sd = exp(log_sd(i, k));
      nll += Type(0.5) * (mean(i, k) * mean(i, k) + sd * sd - Type(1) - Type(2) * log_sd(i, k));
    }
  }
  REPORT(loading);
  return nll;
}
