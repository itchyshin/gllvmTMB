#ifndef GLLVMTMB_DETAIL_COLUMN_PRIOR_HPP
#define GLLVMTMB_DETAIL_COLUMN_PRIOR_HPP

// Private implementation shared with compiled regression tests. Requires TMB.
// Gaussian matrix-normal quadratic; B has source rows and coefficient columns.
// L is the lower-triangular, nonsingular coefficient covariance factor.
template <class Type>
Type gll_column_coef_quad(const matrix<Type>& B, const matrix<Type>& L,
                         const Eigen::SparseMatrix<Type>& Ainv,
                         int estimated_rho, const matrix<Type>& U,
                         const vector<Type>& lambda,
                         const vector<Type>& inv_d, Type rho) {
  const int n = B.rows();
  const int C = B.cols();
  // Whiten with the parameterized Cholesky factor directly. Forming
  // and inverting L * L' squares its condition number and can turn
  // this Gaussian quadratic negative through cancellation.
  // L * Bwhite.row(i)' = B.row(i)' gives Bwhite = B * L^{-T}.
  matrix<Type> Bwhite(n, C);
  Bwhite.setZero();
  for (int i = 0; i < n; ++i)
    for (int j = 0; j < C; ++j) {
      Type value = B(i, j);
      for (int l = 0; l < j; ++l) value -= L(j, l) * Bwhite(i, l);
      Bwhite(i, j) = value / L(j, j);
    }
  Type quad = Type(0);
  if (estimated_rho == 1) {
    matrix<Type> W(n, C);
    W.setZero();
    for (int j = 0; j < C; ++j)
      for (int r = 0; r < n; ++r)
        for (int i = 0; i < n; ++i)
          W(r, j) += U(i, r) *
            inv_d(i) * Bwhite(i, j);
    for (int j = 0; j < C; ++j)
      for (int r = 0; r < n; ++r) {
        Type s_r = Type(1) - rho +
          rho * lambda(r);
        quad += W(r, j) * W(r, j) / s_r;
      }
  } else {
    matrix<Type> AinvB = Ainv * Bwhite;
    for (int j = 0; j < C; ++j)
      for (int i = 0; i < n; ++i)
        quad += Bwhite(i, j) * AinvB(i, j);
  }
  return quad;
}

#endif
