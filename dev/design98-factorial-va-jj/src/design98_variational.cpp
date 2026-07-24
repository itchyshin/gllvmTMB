#include <TMB.hpp>

// Private Design 98 q = 2 variational objective.
// method_id: 0 = QD, 1 = QF, 2 = JD, 3 = JF.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y);
  DATA_INTEGER(method_id);
  DATA_VECTOR(gh_nodes);
  DATA_VECTOR(gh_weights);
  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(loading_free);
  PARAMETER_MATRIX(mean);
  PARAMETER_MATRIX(chol_free);

  const int n = y.rows();
  const int traits = y.cols();
  const int q = 2;
  const bool full = (method_id == 1 || method_id == 3);
  const bool direct = (method_id == 0 || method_id == 1);
  const int expected_chol_cols = full ? 3 : 2;

  if (method_id < 0 || method_id > 3)
    error("Design 98 method_id must be 0, 1, 2, or 3");
  if (traits < q || beta.size() != traits ||
      loading_free.size() != 2 * traits - 1 ||
      mean.rows() != n || mean.cols() != q ||
      chol_free.rows() != n || chol_free.cols() != expected_chol_cols)
    error("Design 98 variational dimension mismatch");
  if (gh_nodes.size() < 1 || gh_nodes.size() != gh_weights.size())
    error("Design 98 GH nodes and weights must have equal positive length");

  Type weight_sum = Type(0);
  for (int h = 0; h < gh_weights.size(); h++) {
    if (asDouble(gh_weights(h)) <= 0.0)
      error("Design 98 GH weights must be positive");
    weight_sum += gh_weights(h);
  }
  if (fabs(asDouble(weight_sum) - 1.0) > 1e-12)
    error("Design 98 GH weights must sum to one");
  for (int i = 0; i < n; i++)
    for (int t = 0; t < traits; t++)
      if (asDouble(y(i, t)) != 0.0 && asDouble(y(i, t)) != 1.0)
        error("Design 98 requires complete Bernoulli responses");

  matrix<Type> loading(traits, q);
  loading.setZero();
  loading(0, 0) = exp(loading_free(0));
  loading(1, 0) = loading_free(1);
  loading(1, 1) = exp(loading_free(2));
  int cursor = 3;
  for (int t = 2; t < traits; t++) {
    loading(t, 0) = loading_free(cursor++);
    loading(t, 1) = loading_free(cursor++);
  }

  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    const Type a = chol_free(i, 0);
    const Type b = full ? chol_free(i, 1) : Type(0);
    const Type c = full ? chol_free(i, 2) : chol_free(i, 1);
    const Type l11 = exp(a);
    const Type l22 = exp(c);
    const Type s11 = l11 * l11;
    const Type s12 = l11 * b;
    const Type s22 = b * b + l22 * l22;

    for (int t = 0; t < traits; t++) {
      const Type mu = beta(t) +
        loading(t, 0) * mean(i, 0) +
        loading(t, 1) * mean(i, 1);
      const Type variance =
        loading(t, 0) * loading(t, 0) * s11 +
        Type(2) * loading(t, 0) * loading(t, 1) * s12 +
        loading(t, 1) * loading(t, 1) * s22;

      Type observation = Type(0);
      if (direct) {
        Type regular = Type(0);
        const Type sd_safe = sqrt(
          CppAD::CondExpLt(
            variance, Type(1e-8), Type(1e-8), variance
          )
        );
        for (int h = 0; h < gh_nodes.size(); h++) {
          const Type eta = mu + sd_safe * gh_nodes(h);
          regular += gh_weights(h) *
            logspace_add(Type(0), eta);
        }
        const Type probability = invlogit(mu);
        const Type second = probability * (Type(1) - probability);
        const Type fourth = second * (
          Type(1) - Type(6) * probability +
          Type(6) * probability * probability
        );
        const Type series =
          logspace_add(Type(0), mu) +
          Type(0.5) * variance * second +
          variance * variance * fourth / Type(8);
        const Type expected_softplus =
          CppAD::CondExpLt(
            variance, Type(1e-8), series, regular
          );
        observation = y(i, t) * mu - expected_softplus;
      } else {
        const Type r = mu * mu + variance;
        const Type root_safe = sqrt(
          CppAD::CondExpLt(r, Type(1e-8), Type(1e-8), r)
        );
        const Type regular =
          -log(Type(2)) - log(cosh(root_safe / Type(2)));
        const Type series =
          -log(Type(2)) - r / Type(8) + r * r / Type(192);
        const Type smooth =
          CppAD::CondExpLt(r, Type(1e-8), series, regular);
        observation = smooth + (y(i, t) - Type(0.5)) * mu;
      }
      nll -= observation;
    }

    const Type kl = Type(0.5) * (
      s11 + s22 +
      mean(i, 0) * mean(i, 0) +
      mean(i, 1) * mean(i, 1) -
      Type(2) * (a + c) - Type(2)
    );
    nll += kl;
  }

  matrix<Type> Sigma = loading * loading.transpose();
  REPORT(loading);
  REPORT(Sigma);
  return nll;
}
