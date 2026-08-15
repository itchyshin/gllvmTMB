#include <TMB.hpp>

template<class Type>
Type objective_function<Type>::operator() () {
  DATA_VECTOR(y);
  PARAMETER_VECTOR(b_fix);
  PARAMETER_VECTOR(theta_diag_B);
  PARAMETER(log_kappa);
  PARAMETER_VECTOR(theta_rr_spde_slope);
  PARAMETER_VECTOR(s_B);
  PARAMETER_ARRAY(g_spde_slope);

  Type nll = Type(0);
  for (int j = 0; j < b_fix.size(); ++j) {
    nll += Type(0.5) * b_fix(j) * b_fix(j);
  }
  for (int j = 0; j < theta_diag_B.size(); ++j) {
    nll += Type(0.5) * theta_diag_B(j) * theta_diag_B(j);
  }
  nll += Type(0.5) * log_kappa * log_kappa;

  for (int j = 0; j < theta_rr_spde_slope.size(); ++j) {
    nll += Type(0.25) * theta_rr_spde_slope(j) * theta_rr_spde_slope(j);
  }
  for (int j = 0; j < s_B.size(); ++j) {
    nll += Type(0.5) * s_B(j) * s_B(j);
  }
  for (int i = 0; i < g_spde_slope.dim[0]; ++i) {
    for (int lhs = 0; lhs < g_spde_slope.dim[2]; ++lhs) {
      Type value = g_spde_slope(i, 0, lhs);
      nll += Type(0.5) * value * value;
    }
  }

  vector<Type> eta(3);
  for (int i = 0; i < 3; ++i) {
    eta(i) = theta_rr_spde_slope(i) * g_spde_slope(i, 0, 0) +
      theta_rr_spde_slope(i + 3) * g_spde_slope(i, 0, 1);
    nll += Type(0.5) * (y(i) - eta(i)) * (y(i) - eta(i));
  }
  REPORT(eta);
  return nll;
}
