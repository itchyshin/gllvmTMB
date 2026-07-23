// gllvmTMB_eva.cpp -- standalone Design 86 research prototype.
//
// This is not the shipped engine.  It implements only the Gate-1 EVA algebra
// with ordinary (not TMB-random) variational coordinates.

#include <TMB.hpp>
#include <cmath>
#include <vector>

template <class Type>
Type eva_softplus(const Type &x) {
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type max_x = CppAD::CondExpGe(x, zero, x, zero);
  return max_x + logspace_add(zero, -abs_x);
}

template <class Type>
Type eva_invlogit(const Type &x) {
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type e = exp(-abs_x);
  Type upper = Type(1.0) / (Type(1.0) + e);
  Type lower = e / (Type(1.0) + e);
  return CppAD::CondExpGe(x, zero, upper, lower);
}

template <class Type>
Type objective_function<Type>::operator()() {
  DATA_VECTOR(y);
  DATA_MATRIX(X);
  DATA_IVECTOR(unit_id);
  DATA_IVECTOR(trait_id);
  DATA_INTEGER(N);
  DATA_INTEGER(T);
  DATA_INTEGER(q);
  DATA_INTEGER(family); // 0 = test-only Gaussian; 1 = Bernoulli-logit
  DATA_SCALAR(gaussian_sd);

  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(theta_rr);
  PARAMETER_MATRIX(a);
  PARAMETER_MATRIX(log_A_diag);
  PARAMETER_MATRIX(A_off);

  const int n_obs = y.size();
  const int n_off = q * (q - 1) / 2;
  const int theta_expected = T * q - q * (q - 1) / 2;
  if (family != 0 && family != 1)
    error("gllvmTMB_eva: family must be 0 (Gaussian) or 1 (Bernoulli)");
  if (N <= 0 || T <= 0 || q <= 0 || q > T || n_obs != N * T)
    error("gllvmTMB_eva: require a complete N by T fixture with 1 <= q <= T");
  if (X.rows() != n_obs || unit_id.size() != n_obs || trait_id.size() != n_obs ||
      X.cols() != beta.size() || theta_rr.size() != theta_expected ||
      a.rows() != N || a.cols() != q || log_A_diag.rows() != N ||
      log_A_diag.cols() != q || A_off.rows() != N || A_off.cols() != n_off)
    error("gllvmTMB_eva: fixture and parameter dimensions do not agree");
  if (family == 0 && !(asDouble(gaussian_sd) > 0.0))
    error("gllvmTMB_eva: Gaussian standard deviation must be positive");
  for (int p = 0; p < beta.size(); ++p)
    if (!std::isfinite(asDouble(beta(p)))) error("gllvmTMB_eva: non-finite beta coordinate");
  for (int k = 0; k < theta_rr.size(); ++k)
    if (!std::isfinite(asDouble(theta_rr(k)))) error("gllvmTMB_eva: non-finite loading coordinate");
  for (int i = 0; i < N; ++i) {
    for (int k = 0; k < q; ++k) {
      if (!std::isfinite(asDouble(a(i, k)))) error("gllvmTMB_eva: non-finite variational mean");
      if (!std::isfinite(asDouble(log_A_diag(i, k)))) error("gllvmTMB_eva: non-finite log-Cholesky diagonal");
      if (asDouble(log_A_diag(i, k)) > 700.0 || asDouble(log_A_diag(i, k)) < -700.0)
        Rf_error("gllvmTMB_eva: log-Cholesky diagonal is outside the finite exponential domain at unit %d coordinate %d", i, k);
    }
    for (int k = 0; k < n_off; ++k)
      if (!std::isfinite(asDouble(A_off(i, k)))) error("gllvmTMB_eva: non-finite Cholesky off-diagonal");
  }

  std::vector<int> count(N * T, 0);
  for (int r = 0; r < n_obs; ++r) {
    int i = unit_id(r), t = trait_id(r);
    if (i < 0 || i >= N || t < 0 || t >= T)
      error("gllvmTMB_eva: unit_id or trait_id is out of range");
    if (!std::isfinite(asDouble(y(r)))) error("gllvmTMB_eva: non-finite response");
    if (family == 1 && !(asDouble(y(r)) == 0.0 || asDouble(y(r)) == 1.0))
      error("gllvmTMB_eva: Bernoulli responses must be exactly zero or one");
    for (int p = 0; p < X.cols(); ++p)
      if (!std::isfinite(asDouble(X(r, p)))) error("gllvmTMB_eva: non-finite design coordinate");
    count[i * T + t] += 1;
  }
  for (int cell = 0; cell < N * T; ++cell)
    if (count[cell] != 1) error("gllvmTMB_eva: every cell must occur exactly once");

  matrix<Type> Lambda(T, q);
  Lambda.setZero();
  for (int j = 0; j < q; ++j) {
    for (int t = j; t < T; ++t) {
      if (t == j) Lambda(t, j) = theta_rr(j);
      else {
        int pos = j * T - (j + 1) * j / 2 + t - 1 - j;
        Lambda(t, j) = theta_rr(q + pos);
      }
    }
  }

  vector<Type> kl_by_unit(N); kl_by_unit.setZero();
  vector<Type> mu_by_obs(n_obs); mu_by_obs.setZero();
  vector<Type> v_by_obs(n_obs); v_by_obs.setZero();
  Type expected_loglik = Type(0.0);
  Type total_kl = Type(0.0);
  const Type log_two_pi = log(Type(2.0) * Type(3.141592653589793238462643383279502884));
  const Type gaussian_var = gaussian_sd * gaussian_sd;

  for (int i = 0; i < N; ++i) {
    matrix<Type> Li(q, q); Li.setZero();
    for (int k = 0; k < q; ++k) {
      Li(k, k) = exp(log_A_diag(i, k));
      if (!std::isfinite(asDouble(Li(k, k))))
        Rf_error("gllvmTMB_eva: non-finite Cholesky diagonal at unit %d coordinate %d", i, k);
    }
    int cursor = 0;
    for (int col = 0; col < q; ++col)
      for (int row = col + 1; row < q; ++row) Li(row, col) = A_off(i, cursor++);
    Type trace_A = Type(0.0), mean_sq = Type(0.0), logdet_A = Type(0.0);
    for (int row = 0; row < q; ++row) {
      mean_sq += a(i, row) * a(i, row);
      logdet_A += Type(2.0) * log_A_diag(i, row);
      for (int col = 0; col <= row; ++col) trace_A += Li(row, col) * Li(row, col);
    }
    kl_by_unit(i) = Type(0.5) * (trace_A + mean_sq - logdet_A - Type(q));
    if (!std::isfinite(asDouble(kl_by_unit(i))))
      Rf_error("gllvmTMB_eva: non-finite KL at unit %d", i);
    total_kl += kl_by_unit(i);

    for (int r = 0; r < n_obs; ++r) {
      if (unit_id(r) != i) continue;
      int t = trait_id(r);
      Type mu = Type(0.0);
      for (int p = 0; p < X.cols(); ++p) mu += X(r, p) * beta(p);
      for (int k = 0; k < q; ++k) mu += Lambda(t, k) * a(i, k);
      Type v = Type(0.0);
      for (int col = 0; col < q; ++col) {
        Type projection = Type(0.0);
        for (int row = col; row < q; ++row) projection += Li(row, col) * Lambda(t, row);
        v += projection * projection;
      }
      mu_by_obs(r) = mu;
      v_by_obs(r) = v;
      if (!std::isfinite(asDouble(mu)))
        Rf_error("gllvmTMB_eva: non-finite linear predictor at unit %d trait %d", i, t);
      if (!std::isfinite(asDouble(v)))
        Rf_error("gllvmTMB_eva: non-finite projected variance at unit %d trait %d", i, t);
      if (family == 1) {
        Type p = eva_invlogit(mu);
        expected_loglik += y(r) * mu - eva_softplus(mu) - Type(0.5) * p * (Type(1.0) - p) * v;
      } else {
        Type residual = y(r) - mu;
        expected_loglik += -Type(0.5) * (log_two_pi + Type(2.0) * log(gaussian_sd)
          + (residual * residual + v) / gaussian_var);
      }
    }
  }

  Type ell_eva = expected_loglik - total_kl;
  Type negative_ell_eva = -ell_eva;
  if (!std::isfinite(asDouble(negative_ell_eva)))
    Rf_error("gllvmTMB_eva: non-finite EVA objective");
  REPORT(Lambda);
  REPORT(mu_by_obs);
  REPORT(v_by_obs);
  REPORT(kl_by_unit);
  REPORT(expected_loglik);
  REPORT(total_kl);
  REPORT(ell_eva);
  REPORT(negative_ell_eva);
  return negative_ell_eva;
}
