#include <TMB.hpp>
#include "column_prior.hpp"

template<class Type>
Type objective_function<Type>::operator() () {
  DATA_SPARSE_MATRIX(Ainv);
  DATA_INTEGER(estimated_rho);
  DATA_MATRIX(U);
  DATA_VECTOR(lambda);
  DATA_VECTOR(inv_d);
  DATA_SCALAR(logdet_K_base);

  PARAMETER_MATRIX(B);
  PARAMETER_VECTOR(theta);
  PARAMETER(eta_rho);

  const int C = B.cols();
  const int n_chol = C * (C + 1) / 2;
  if (theta.size() != n_chol) error("theta has wrong packed Cholesky length");

  matrix<Type> L(C, C);
  L.setZero();
  int idx = 0;
  for (int j = 0; j < C; ++j) L(j, j) = exp(theta(idx++));
  for (int j = 0; j < C; ++j)
    for (int i = j + 1; i < C; ++i) L(i, j) = theta(idx++);

  Type rho = invlogit(eta_rho);
  Type quad = gll_column_coef_quad(B, L, Ainv, estimated_rho, U, lambda, inv_d, rho);
  Type logdet_sigma = Type(0);
  for (int j = 0; j < C; ++j) logdet_sigma += Type(2) * log(L(j, j));

  Type logdet_K = logdet_K_base;
  if (estimated_rho == 1)
    for (int i = 0; i < lambda.size(); ++i)
      logdet_K += log(Type(1) - rho + rho * lambda(i));

  Type nll = Type(0.5) * (Type(B.rows() * C) * log(Type(2) * M_PI) +
    Type(B.rows()) * logdet_sigma + Type(C) * logdet_K + quad);
  REPORT(quad);
  REPORT(rho);
  return nll;
}

