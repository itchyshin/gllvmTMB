#include <TMB.hpp>

// Private Design-96 smoke template; deliberately outside the package src/.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y);
  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(loading_free);
  PARAMETER_MATRIX(mean);
  PARAMETER_MATRIX(log_sd);
  const int n = y.rows(), traits = y.cols(), q = 2;
  if (traits < q || beta.size() != traits || loading_free.size() != 2 * traits - 1 ||
      mean.rows() != n || mean.cols() != q || log_sd.rows() != n || log_sd.cols() != q)
    error("Design-96 dimension or q=2 identification mismatch");
  for (int i = 0; i < n; i++) for (int t = 0; t < traits; t++)
    if (asDouble(y(i, t)) != 0.0 && asDouble(y(i, t)) != 1.0)
      error("Design-96 requires complete Bernoulli 0/1 responses");
  matrix<Type> loading(traits, q); loading.setZero();
  loading(0, 0) = exp(loading_free(0));
  loading(1, 0) = loading_free(1); loading(1, 1) = exp(loading_free(2));
  int cursor = 3;
  for (int t = 2; t < traits; t++) { loading(t, 0) = loading_free(cursor++); loading(t, 1) = loading_free(cursor++); }
  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    for (int t = 0; t < traits; t++) {
      Type mu = beta(t), variance = Type(0);
      for (int k = 0; k < q; k++) { Type sd = exp(log_sd(i, k)); mu += loading(t, k) * mean(i, k); variance += loading(t, k) * loading(t, k) * sd * sd; }
      Type xi = sqrt(mu * mu + variance);
      Type omega = CppAD::CondExpLt(xi, Type(1e-6), Type(0.125) - xi * xi / Type(96), tanh(xi / Type(2)) / (Type(4) * xi));
      Type constant = -log(Type(1) + exp(-xi)) - xi / Type(2) + omega * xi * xi;
      nll -= constant + (y(i, t) - Type(0.5)) * mu - omega * (mu * mu + variance);
    }
    for (int k = 0; k < q; k++) { Type sd = exp(log_sd(i, k)); nll += Type(0.5) * (mean(i, k) * mean(i, k) + sd * sd - Type(1) - Type(2) * log_sd(i, k)); }
  }
  REPORT(loading);
  return nll;
}
