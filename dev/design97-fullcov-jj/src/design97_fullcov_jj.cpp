#include <TMB.hpp>

// Private Design-97 full-covariance q=2 JJ objective. It is not part of the
// package compilation or public interface.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y); PARAMETER_VECTOR(beta); PARAMETER_VECTOR(loading_free);
  PARAMETER_MATRIX(mean); PARAMETER_MATRIX(chol_free);
  const int n = y.rows(), traits = y.cols(), q = 2;
  if (traits < q || beta.size() != traits || loading_free.size() != 2 * traits - 1 ||
      mean.rows() != n || mean.cols() != q || chol_free.rows() != n || chol_free.cols() != 3)
    error("Design-97 q=2 dimension mismatch");
  for (int i = 0; i < n; i++) for (int t = 0; t < traits; t++)
    if (asDouble(y(i, t)) != 0.0 && asDouble(y(i, t)) != 1.0) error("Design-97 requires complete Bernoulli responses");
  matrix<Type> L(traits, q); L.setZero(); L(0, 0) = exp(loading_free(0));
  L(1, 0) = loading_free(1); L(1, 1) = exp(loading_free(2)); int cursor = 3;
  for (int t = 2; t < traits; t++) { L(t, 0) = loading_free(cursor++); L(t, 1) = loading_free(cursor++); }
  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    Type l11 = exp(chol_free(i, 0)), l21 = chol_free(i, 1), l22 = exp(chol_free(i, 2));
    Type s11 = l11 * l11, s12 = l11 * l21, s22 = l21 * l21 + l22 * l22;
    for (int t = 0; t < traits; t++) {
      Type mu = beta(t) + L(t, 0) * mean(i, 0) + L(t, 1) * mean(i, 1);
      Type variance = L(t, 0) * L(t, 0) * s11 + Type(2) * L(t, 0) * L(t, 1) * s12 + L(t, 1) * L(t, 1) * s22;
      Type r = mu * mu + variance;
      // The profiled omega terms cancel. This series has derivative -1/8 at r=0.
      Type root_safe = sqrt(CppAD::CondExpLt(r, Type(1e-8), Type(1e-8), r));
      Type regular = -log(Type(2)) - log(cosh(root_safe / Type(2)));
      Type series = -log(Type(2)) - r / Type(8) + r * r / Type(192);
      Type smooth = CppAD::CondExpLt(r, Type(1e-8), series, regular);
      nll -= smooth + (y(i, t) - Type(.5)) * mu;
    }
    nll += Type(.5) * (s11 + s22 + mean(i, 0) * mean(i, 0) + mean(i, 1) * mean(i, 1) - Type(2) * chol_free(i, 0) - Type(2) * chol_free(i, 2) - Type(2));
  }
  REPORT(L); return nll;
}
