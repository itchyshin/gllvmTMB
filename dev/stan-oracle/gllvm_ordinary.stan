// gllvm_ordinary.stan
//
// Independent Stan oracle for the ordinary Gaussian GLLVM, long format,
// one grouping level, Sigma_unit = Lambda Lambda' + diag(psi).
//
// Implements EXACTLY the joint log-density boxed in
//   dev/stan-oracle/model-spec.md  section 7.1
// and nothing else.  Three density terms, no priors, all normalising
// constants retained (`_lpdf` form, never the `~` shorthand).
//
// Derived only from model-spec.md.  No file under src/ was read.
//
// NOTE ON NAMING: the spec calls the number of traits `T`.  `T` is reserved in
// the Stan language (truncation syntax `T[a, b]`), so it is spelled `n_t` here.

data {
  int<lower=1> N;                          // long-format rows
  int<lower=2> n_t;                        // traits   (spec: T)
  int<lower=1> n_u;                        // units    (spec: n_u)
  int<lower=1> K;                          // latent rank (spec: K = d)

  array[N] int<lower=1, upper=n_t> tt;     // trait index t(i) of row i
  array[N] int<lower=1, upper=n_u> uu;     // unit  index l(i) of row i
  vector[N] y;                             // response
}

parameters {
  // ---- theta (spec section 5) --------------------------------------------
  vector[n_t] mu;                          // trait-specific intercepts, 0 + trait
                                           // unconstrained; no reference level

  matrix[n_t, K] Lambda;                   // loadings, T x K.
                                           // DELIBERATELY an unconstrained plain
                                           // matrix: spec section 6.2 forbids
                                           // imposing the lower-triangular /
                                           // positive-diagonal ROTATION CONVENTION
                                           // as a constrained type, because that
                                           // would change the measure and hence
                                           // the density being compared.

  vector<lower=0>[n_t] psi;                // unique VARIANCES psi_t > 0
                                           // (spec section 4.2 fixes psi = variance)

  real<lower=0> sigma_eps;                 // residual SD, ONE scalar shared across
                                           // all traits and all rows (spec section 2)

  // ---- latent blocks, held fixed for the oracle check (spec section 4) ----
  matrix[n_u, K] z;                        // latent factor scores, ~ N(0, 1)
  matrix[n_u, n_t] q;                      // unique components,   ~ N(0, psi_t)
}

model {
  // ---- linear predictor (spec section 3) ---------------------------------
  // eta_i = mu_{t(i)} + lambda_{t(i)}' z_{l(i)} + q_{l(i), t(i)}
  vector[N] eta;
  for (i in 1:N) {
    eta[i] = mu[tt[i]]
             + dot_product(Lambda[tt[i]], z[uu[i]])
             + q[uu[i], tt[i]];
  }

  // ---- (D) data / Gaussian observation term, N terms ---------------------
  // y_i ~ N(eta_i, sigma_eps^2); Stan takes an SD, so sigma_eps directly.
  target += normal_lpdf(y | eta, sigma_eps);

  // ---- (Z) latent-score term, n_u * K terms ------------------------------
  // z_{lk} ~ N(0, 1); variance FIXED at 1, not a parameter.
  target += std_normal_lpdf(to_vector(z));

  // ---- (Q) unique / diagonal-Psi term, n_u * n_t terms -------------------
  // q_{lt} ~ N(0, psi_t) with psi_t a VARIANCE, so the SD is sqrt(psi_t).
  for (t in 1:n_t) {
    target += normal_lpdf(col(q, t) | 0, sqrt(psi[t]));
  }

  // No priors.  No Jacobian adjustments.  Nothing else.
}

generated quantities {
  // Reporting only; never used in the density (spec section 3).
  matrix[n_t, n_t] Sigma_unit = Lambda * Lambda';
  for (t in 1:n_t) {
    Sigma_unit[t, t] += psi[t];
  }
}
