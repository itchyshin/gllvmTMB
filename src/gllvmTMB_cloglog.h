#ifndef GLLVMTMB_CLOGLOG_H
#define GLLVMTMB_CLOGLOG_H

// Shared stable binomial-cloglog kernel.  This header is included by the main
// TMB template and by the no-optimiser compiled-tail test template.
template <class Type>
Type gll_cloglog_clamp(Type x, Type lower, Type upper)
{
  x = CppAD::CondExpLt(x, lower, lower, x);
  return CppAD::CondExpGt(x, upper, upper, x);
}

template <class Type>
Type gll_log_cloglog_p(Type eta)
{
  // log(1 - exp(-exp(eta))) without constructing a probability on the
  // ordinary scale.  This is deliberately separate from gll_log1mexp(): its
  // near-zero input guard is correct for an already-logarithmic probability,
  // but would incorrectly flatten the cloglog left tail, where log(p) ~ eta.
  //
  // CppAD::CondExp evaluates both branches.  Therefore every branch uses an
  // evaluation argument bounded to the range in which its arithmetic stays
  // finite, while the selected left branch retains the original eta and slope.
  const Type left_cut = Type(-20.0);
  // 700 sits just below the double-precision exp() overflow boundary.  It is
  // an evaluation-only cap, so every representable ordinary tail (including
  // eta = 40) retains its exact binomial failure contribution and derivative.
  const Type right_cut = Type(700.0);
  Type eta_left = CppAD::CondExpGt(eta, left_cut, left_cut, eta);
  Type lambda_left = exp(eta_left);
  Type left_series = Type(1.0) - lambda_left / Type(2.0) +
    lambda_left * lambda_left / Type(6.0) -
    lambda_left * lambda_left * lambda_left / Type(24.0);
  Type left = eta_left + log(left_series);

  Type eta_mid = gll_cloglog_clamp(eta, left_cut, right_cut);
  Type lambda_mid = exp(eta_mid);
  Type middle = log(Type(1.0) - exp(-lambda_mid));

  Type not_left = CppAD::CondExpLe(eta, left_cut, left, middle);
  return CppAD::CondExpGe(eta, right_cut, Type(0.0), not_left);
}

template <class Type>
Type gll_dbinom_cloglog(Type y, Type n, Type eta)
{
  // Keep the binomial(k-of-n) contract while evaluating both tails on the
  // log scale.  The right-tail evaluation cap is temporary numerical support:
  // it prevents exp(eta) from overflowing an AD branch; it is not a
  // probability floor or an ordinary-range likelihood modification.
  const Type right_cut = Type(700.0);
  Type eta_q = CppAD::CondExpGt(eta, right_cut, right_cut, eta);
  Type log_choose = lgamma(n + Type(1.0)) - lgamma(y + Type(1.0)) -
    lgamma(n - y + Type(1.0));
  return log_choose + y * gll_log_cloglog_p(eta) -
    (n - y) * exp(eta_q);
}

#endif
