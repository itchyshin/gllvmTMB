#include <TMB.hpp>

// Private Design 98 deterministic q = 2 tensor-GH marginal objective.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(y);
  DATA_VECTOR(gh_nodes);
  DATA_VECTOR(gh_weights);
  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(loading_free);

  const int n = y.rows();
  const int traits = y.cols();
  const int q = 2;
  const int order = gh_nodes.size();

  if (traits < q || beta.size() != traits ||
      loading_free.size() != 2 * traits - 1)
    error("Design 98 GH dimension mismatch");
  if (order < 1 || gh_weights.size() != order)
    error("Design 98 GH nodes and weights must have equal positive length");

  Type weight_sum = Type(0);
  for (int h = 0; h < order; h++) {
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

  matrix<Type> posterior_mean(n, q);
  matrix<Type> posterior_covariance(n, 3);
  posterior_mean.setZero();
  posterior_covariance.setZero();
  Type nll = Type(0);
  for (int i = 0; i < n; i++) {
    vector<Type> log_terms(order * order);
    Type log_integral = Type(0);
    bool first = true;
    int grid_cursor = 0;
    for (int r = 0; r < order; r++) {
      for (int s = 0; s < order; s++) {
        Type term = log(gh_weights(r)) + log(gh_weights(s));
        for (int t = 0; t < traits; t++) {
          const Type eta =
            beta(t) +
            loading(t, 0) * gh_nodes(r) +
            loading(t, 1) * gh_nodes(s);
          term += y(i, t) * eta - logspace_add(Type(0), eta);
        }
        log_terms(grid_cursor++) = term;
        if (first) {
          log_integral = term;
          first = false;
        } else {
          log_integral = logspace_add(log_integral, term);
        }
      }
    }
    Type mean1 = Type(0), mean2 = Type(0);
    Type second11 = Type(0), second12 = Type(0), second22 = Type(0);
    grid_cursor = 0;
    for (int r = 0; r < order; r++) {
      for (int s = 0; s < order; s++) {
        const Type posterior_weight =
          exp(log_terms(grid_cursor++) - log_integral);
        mean1 += posterior_weight * gh_nodes(r);
        mean2 += posterior_weight * gh_nodes(s);
        second11 += posterior_weight * gh_nodes(r) * gh_nodes(r);
        second12 += posterior_weight * gh_nodes(r) * gh_nodes(s);
        second22 += posterior_weight * gh_nodes(s) * gh_nodes(s);
      }
    }
    posterior_mean(i, 0) = mean1;
    posterior_mean(i, 1) = mean2;
    posterior_covariance(i, 0) = second11 - mean1 * mean1;
    posterior_covariance(i, 1) = second12 - mean1 * mean2;
    posterior_covariance(i, 2) = second22 - mean2 * mean2;
    nll -= log_integral;
  }

  matrix<Type> Sigma = loading * loading.transpose();
  REPORT(loading);
  REPORT(Sigma);
  REPORT(posterior_mean);
  REPORT(posterior_covariance);
  return nll;
}
