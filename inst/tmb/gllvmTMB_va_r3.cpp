// gllvmTMB_va_r3.cpp -- standalone, research-only Gaussian VA objective.
//
// This template implements Design 85 only.  It is deliberately separate from
// the shipped gllvmTMB engine and supplies no public fitting method, marginal
// likelihood, rank selection, REML adjustment, or TMB random-parameter path.

#include <TMB.hpp>
#include <cmath>
#include <vector>

// Stable softplus in the exact max/log1p form required by Design 85.  The
// only exponential has a non-positive argument, including on AD tapes.
template <class Type>
Type va_r3_softplus(const Type &x)
{
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type max_x = CppAD::CondExpGe(x, zero, x, zero);
  // TMB's logspace_add is its AD-safe implementation of
  // log(exp(0) + exp(-abs_x)) = log1p(exp(-abs_x)).
  return max_x + logspace_add(zero, -abs_x);
}

// Stable inverse logit used only to form softplus derivatives in the small-v
// expansion.  As above, exp() is evaluated only at a non-positive argument.
template <class Type>
Type va_r3_invlogit(const Type &x)
{
  Type zero = Type(0.0);
  Type abs_x = CppAD::CondExpGe(x, zero, x, -x);
  Type e = exp(-abs_x);
  Type upper = Type(1.0) / (Type(1.0) + e);
  Type lower = e / (Type(1.0) + e);
  return CppAD::CondExpGe(x, zero, upper, lower);
}

// E[softplus(mu + sqrt(v) Z)] by physicists' Gauss-Hermite quadrature.
//
// At small v, the heat-kernel expansion
//   f + v f''/2 + v^2 f''''/8 + v^3 f^(6)/48 + O(v^4)
// is a polynomial in v.  Thus AD never differentiates sqrt(v) at zero.  The
// GH branch receives max(v, threshold), and the outer CondExp selects the
// polynomial branch when v <= threshold.  At 1e-6 the omitted value term is
// O(1e-24) and the omitted first derivative is O(1e-18) for softplus.
template <class Type>
Type va_r3_softplus_expectation(const Type &mu,
                                const Type &v,
                                const vector<Type> &gh_nodes,
                                const vector<Type> &gh_weights)
{
  const Type threshold = Type(1e-6);
  const Type one = Type(1.0);

  Type p = va_r3_invlogit(mu);
  Type pq = p * (one - p);
  Type p2 = p * p;
  Type p3 = p2 * p;
  Type p4 = p2 * p2;
  Type f2 = pq;
  Type f4 = pq * (one - Type(6.0) * p + Type(6.0) * p2);
  Type f6 = pq * (one - Type(30.0) * p + Type(150.0) * p2
                  - Type(240.0) * p3 + Type(120.0) * p4);
  Type expansion = va_r3_softplus(mu)
    + v * f2 / Type(2.0)
    + v * v * f4 / Type(8.0)
    + v * v * v * f6 / Type(48.0);

  Type safe_v = CppAD::CondExpGt(v, threshold, v, threshold);
  Type scale = sqrt(Type(2.0) * safe_v);
  Type weighted_sum = Type(0.0);
  for (int h = 0; h < gh_nodes.size(); ++h) {
    weighted_sum += gh_weights(h) *
      va_r3_softplus(mu + scale * gh_nodes(h));
  }
  const Type sqrt_pi = sqrt(Type(3.141592653589793238462643383279502884));
  Type quadrature = weighted_sum / sqrt_pi;

  return CppAD::CondExpGt(v, threshold, quadrature, expansion);
}

template <class Type>
Type objective_function<Type>::operator()()
{
  // Data are long-format complete cells. unit_id and trait_id are zero-based.
  DATA_VECTOR(y);
  DATA_VECTOR(n_trials);
  DATA_MATRIX(X);
  DATA_IVECTOR(unit_id);
  DATA_IVECTOR(trait_id);
  DATA_INTEGER(N);
  DATA_INTEGER(T);
  DATA_INTEGER(q);
  DATA_VECTOR(gh_nodes);
  DATA_VECTOR(gh_weights);
  DATA_INTEGER(family);            // 0 = Gaussian anchor; 1 = binomial-logit
  DATA_SCALAR(gaussian_sd);        // fixed observation SD for family == 0

  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(theta_rr);      // live-engine packing; raw diagonal first
  PARAMETER_MATRIX(m);             // N x q variational means
  PARAMETER_MATRIX(log_L_diag);    // N x q log Cholesky diagonals
  PARAMETER_MATRIX(L_off);         // N x q(q-1)/2 strict-lower entries

  const int n_obs = y.size();
  const int n_off = q * (q - 1) / 2;
  const int theta_expected = T * q - q * (q - 1) / 2;

  // Defensive dimension/scope checks. The R adapter performs the richer
  // pre-construction validation required by Design 85.
  if (family != 0 && family != 1)
    error("gllvmTMB_va_r3: family must be 0 (Gaussian) or 1 (binomial)");
  if (N <= 0 || T <= 0 || q <= 0 || q > T)
    error("gllvmTMB_va_r3: require N > 0, T > 0, and 1 <= q <= T");
  if (n_obs != N * T)
    error("gllvmTMB_va_r3: the research objective requires exactly N*T cells");
  if (n_trials.size() != n_obs || unit_id.size() != n_obs ||
      trait_id.size() != n_obs || X.rows() != n_obs)
    error("gllvmTMB_va_r3: response-side data dimensions do not agree");
  if (X.cols() != beta.size())
    error("gllvmTMB_va_r3: ncol(X) must equal length(beta)");
  if (theta_rr.size() != theta_expected)
    error("gllvmTMB_va_r3: theta_rr has the wrong live-packed length");
  if (m.rows() != N || m.cols() != q ||
      log_L_diag.rows() != N || log_L_diag.cols() != q ||
      L_off.rows() != N || L_off.cols() != n_off)
    error("gllvmTMB_va_r3: variational parameter dimensions do not agree");
  if (gh_nodes.size() <= 0 || gh_weights.size() != gh_nodes.size())
    error("gllvmTMB_va_r3: GH nodes and weights must have the same positive length");
  if (family == 0 && !(asDouble(gaussian_sd) > 0.0))
    error("gllvmTMB_va_r3: gaussian_sd must be positive for the Gaussian anchor");

  // Check that the long data contain each unit-trait cell exactly once.
  std::vector<int> cell_count(N * T, 0);
  for (int r = 0; r < n_obs; ++r) {
    int i = unit_id(r);
    int t = trait_id(r);
    if (i < 0 || i >= N || t < 0 || t >= T)
      error("gllvmTMB_va_r3: unit_id or trait_id is out of range");
    cell_count[i * T + t] += 1;
    if (!std::isfinite(asDouble(y(r))) || !std::isfinite(asDouble(n_trials(r))))
      error("gllvmTMB_va_r3: y and n_trials must be finite");
    if (family == 1) {
      double yd = asDouble(y(r));
      double nd = asDouble(n_trials(r));
      if (nd < 2.0 || std::floor(nd) != nd || yd < 0.0 || yd > nd ||
          std::floor(yd) != yd)
        error("gllvmTMB_va_r3: binomial cells require integer n >= 2 and 0 <= y <= n");
    }
  }
  for (int cell = 0; cell < N * T; ++cell) {
    if (cell_count[cell] != 1)
      error("gllvmTMB_va_r3: every unit-trait cell must occur exactly once");
  }
  for (int h = 0; h < gh_weights.size(); ++h) {
    if (!std::isfinite(asDouble(gh_nodes(h))) ||
        !std::isfinite(asDouble(gh_weights(h))) ||
        !(asDouble(gh_weights(h)) > 0.0))
      error("gllvmTMB_va_r3: GH nodes must be finite and weights finite and positive");
  }
  for (int r = 0; r < X.rows(); ++r) {
    for (int p = 0; p < X.cols(); ++p) {
      if (!std::isfinite(asDouble(X(r, p))))
        error("gllvmTMB_va_r3: X must be finite");
    }
  }

  // Exact live-engine reconstruction: raw diagonal, then strict lower
  // triangle column-by-column. Strict upper triangle remains zero.
  matrix<Type> Lambda(T, q);
  Lambda.setZero();
  vector<Type> lam_diag = theta_rr.head(q);
  vector<Type> lam_lower = theta_rr.tail(theta_rr.size() - q);
  for (int j = 0; j < q; ++j) {
    for (int t = j; t < T; ++t) {
      if (t == j) {
        Lambda(t, j) = lam_diag(j);
      } else {
        int pos = j * T - (j + 1) * j / 2 + t - 1 - j;
        Lambda(t, j) = lam_lower(pos);
      }
    }
  }
  matrix<Type> Sigma_B = Lambda * Lambda.transpose();

  // Materialise each unit Cholesky only as a q x q work matrix. S is never
  // inverted and its determinant is never formed. Flattened L/S reports are
  // for algebra tests and diagnostics only.
  matrix<Type> L_flat(N, q * q);
  matrix<Type> S_flat(N, q * q);
  L_flat.setZero();
  S_flat.setZero();
  vector<Type> kl_by_unit(N);
  kl_by_unit.setZero();

  for (int i = 0; i < N; ++i) {
    matrix<Type> Li(q, q);
    Li.setZero();
    for (int k = 0; k < q; ++k)
      Li(k, k) = exp(log_L_diag(i, k));
    int off_pos = 0;
    for (int col = 0; col < q; ++col) {
      for (int row = col + 1; row < q; ++row) {
        Li(row, col) = L_off(i, off_pos);
        ++off_pos;
      }
    }

    Type trace_S = Type(0.0);
    Type mean_sq = Type(0.0);
    Type logdet_S = Type(0.0);
    for (int row = 0; row < q; ++row) {
      mean_sq += m(i, row) * m(i, row);
      logdet_S += Type(2.0) * log_L_diag(i, row);
      for (int col = 0; col <= row; ++col)
        trace_S += Li(row, col) * Li(row, col);
    }
    kl_by_unit(i) = Type(0.5) *
      (trace_S + mean_sq - logdet_S - Type(q));
    if (!std::isfinite(asDouble(kl_by_unit(i))))
      Rf_error("gllvmTMB_va_r3: non-finite KL coordinate at unit %d", i);

    matrix<Type> Si = Li * Li.transpose();
    for (int row = 0; row < q; ++row) {
      for (int col = 0; col < q; ++col) {
        L_flat(i, row * q + col) = Li(row, col);
        S_flat(i, row * q + col) = Si(row, col);
      }
    }
  }

  vector<Type> expected_loglik_by_unit(N);
  vector<Type> expected_loglik_by_obs(n_obs);
  vector<Type> softplus_expectation_by_obs(n_obs);
  vector<Type> mu_by_obs(n_obs);
  vector<Type> v_by_obs(n_obs);
  expected_loglik_by_unit.setZero();
  expected_loglik_by_obs.setZero();
  softplus_expectation_by_obs.setZero();
  mu_by_obs.setZero();
  v_by_obs.setZero();

  const Type log_two_pi = log(Type(2.0) *
    Type(3.141592653589793238462643383279502884));
  const Type gaussian_var = gaussian_sd * gaussian_sd;

  for (int r = 0; r < n_obs; ++r) {
    int i = unit_id(r);
    int t = trait_id(r);

    Type mu = Type(0.0);
    for (int p = 0; p < X.cols(); ++p)
      mu += X(r, p) * beta(p);
    for (int k = 0; k < q; ++k)
      mu += Lambda(t, k) * m(i, k);

    // v_it = ||L_i' lambda_t||^2, without forming S_i.
    Type v = Type(0.0);
    for (int col = 0; col < q; ++col) {
      Type projected = Type(0.0);
      projected += exp(log_L_diag(i, col)) * Lambda(t, col);
      int off_pos = 0;
      for (int prior_col = 0; prior_col < col; ++prior_col)
        off_pos += q - prior_col - 1;
      for (int row = col + 1; row < q; ++row) {
        projected += L_off(i, off_pos + row - col - 1) * Lambda(t, row);
      }
      v += projected * projected;
    }
    if (!std::isfinite(asDouble(mu)))
      Rf_error("gllvmTMB_va_r3: non-finite mu coordinate at unit %d trait %d", i, t);
    if (!std::isfinite(asDouble(v)))
      Rf_error("gllvmTMB_va_r3: non-finite variance projection at unit %d trait %d", i, t);

    Type ell = Type(0.0);
    if (family == 0) {
      Type residual = y(r) - mu;
      ell = -Type(0.5) *
        (log_two_pi + Type(2.0) * log(gaussian_sd)
         + (residual * residual + v) / gaussian_var);
    } else {
      Type n = n_trials(r);
      Type log_choose = lgamma(n + Type(1.0))
        - lgamma(y(r) + Type(1.0))
        - lgamma(n - y(r) + Type(1.0));
      Type softplus_expectation =
        va_r3_softplus_expectation(mu, v, gh_nodes, gh_weights);
      softplus_expectation_by_obs(r) = softplus_expectation;
      ell = log_choose + y(r) * mu - n * softplus_expectation;
    }
    if (!std::isfinite(asDouble(ell)))
      Rf_error("gllvmTMB_va_r3: non-finite expected log-likelihood at unit %d trait %d", i, t);

    mu_by_obs(r) = mu;
    v_by_obs(r) = v;
    expected_loglik_by_obs(r) = ell;
    expected_loglik_by_unit(i) += ell;
  }

  Type expected_loglik = expected_loglik_by_unit.sum();
  Type total_kl = kl_by_unit.sum();
  Type elbo = expected_loglik - total_kl;
  Type negative_elbo = -elbo;
  if (!std::isfinite(asDouble(negative_elbo)))
    error("gllvmTMB_va_r3: non-finite negative ELBO");

  REPORT(Lambda);
  REPORT(Sigma_B);
  REPORT(m);
  REPORT(L_flat);
  REPORT(S_flat);
  REPORT(mu_by_obs);
  REPORT(v_by_obs);
  REPORT(expected_loglik_by_obs);
  REPORT(softplus_expectation_by_obs);
  REPORT(expected_loglik_by_unit);
  REPORT(kl_by_unit);
  REPORT(expected_loglik);
  REPORT(total_kl);
  REPORT(elbo);
  REPORT(negative_elbo);

  return negative_elbo;
}
