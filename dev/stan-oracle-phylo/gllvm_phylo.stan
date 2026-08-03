// gllvm_phylo.stan
//
// Independent Stan oracle for the PHYLOGENETIC reduced-rank latent Gaussian
// GLLVM, long format, loadings-only:
//
//     value ~ 0 + trait + phylo_latent(species, d = K, unique = FALSE)
//
// Implements EXACTLY the joint log-density boxed in
//   dev/stan-oracle-phylo/model-spec-phylo.md  section 8.1
// and nothing else.  TWO density terms -- (D) data and (G) phylogenetic latent
// scores -- no priors, all normalising constants retained (`_lpdf` form, never
// the `~` shorthand), including the parameter-free -K/2 * log|A| carried inside
// multi_normal_cholesky_lpdf (spec section 8.3).
//
// Derived only from model-spec-phylo.md (plus dev/stan-oracle/gllvm_ordinary.stan
// as a HARNESS template).  No file under src/, no TMB-building R file, and
// neither tmb-side-phylo.md nor dev/stan-oracle/tmb-side.R was read.
//
// HIERARCHICAL form (spec section 0): the latent scores G are an explicit block
// and are NOT integrated out.  The marginal (Lambda Lambda') (x) A form is
// singular at K < T and has no density at all.
//
// A enters as DATA, through its lower Cholesky factor L_A (A = L_A L_A').  A is
// never inverted; the quadratic form g' A^{-1} g and the log-determinant are
// both obtained from the triangular solve inside multi_normal_cholesky_lpdf.
//
// NOTE ON NAMING: the spec calls the number of traits `T`.  `T` is reserved in
// the Stan language (truncation syntax `T[a, b]`), so it is spelled `n_t` here.
// The spec's `S` (species / tree tips) is spelled `S`.

data {
  int<lower=1> N;                          // long-format rows
  int<lower=2> n_t;                        // traits          (spec: T)
  int<lower=1> S;                          // species / tips  (spec: S)
  int<lower=1> K;                          // phylo latent rank (spec: K = d)

  array[N] int<lower=1, upper=n_t> tt;     // trait   index t(i) of row i
  array[N] int<lower=1, upper=S>   ss;     // species index s(i) of row i
  vector[N] y;                             // response

  // Lower Cholesky factor of the phylogenetic CORRELATION matrix A (spec s.5).
  // Supplied as data -- fixed input, not a modelled object, and never
  // re-derived from the tree on this side.
  cholesky_factor_cov[S] L_A;
}

transformed data {
  vector[S] zeros_S = rep_vector(0, S);
}

parameters {
  // ---- theta (spec section 6) --------------------------------------------
  vector[n_t] mu;                          // trait-specific intercepts, 0 + trait
                                           // unconstrained; no reference level

  matrix[n_t, K] Lambda;                   // phylogenetic loadings, T x K.
                                           // DELIBERATELY an unconstrained plain
                                           // matrix: spec section 7.2 forbids
                                           // imposing the lower-triangular /
                                           // positive-diagonal ROTATION CONVENTION
                                           // as a constrained Stan type, because
                                           // that would change the measure and
                                           // hence the density being compared.

  real<lower=0> sigma_eps;                 // residual SD, ONE scalar shared across
                                           // all traits and all rows (spec s.2)

  // NOTE: there is NO psi block.  unique = FALSE is loadings-only (spec s.3.3),
  // and there is NO free phylogenetic variance/scale parameter (spec s.4.3):
  // it would be exactly non-identified against Lambda.

  // ---- latent block, held fixed for the oracle check (spec section 0) -----
  matrix[S, K] G;                          // phylogenetic latent scores,
                                           // species x axis; TIPS-ONLY
                                           // (the augmented-node variant of
                                           // spec section 8.5 is a DIFFERENT
                                           // sample space and is not this file)
}

model {
  // ---- linear predictor (spec section 3) ---------------------------------
  // eta_i = mu_{t(i)} + lambda_{t(i)}' g_{s(i)}
  vector[N] eta;
  for (i in 1:N) {
    eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], G[ss[i]]);
  }

  // ---- (D) data / Gaussian observation term, N terms ---------------------
  // y_i ~ N(eta_i, sigma_eps^2); Stan takes an SD, so sigma_eps directly.
  target += normal_lpdf(y | eta, sigma_eps);

  // ---- (G) phylogenetic latent-score term, K multivariate terms ----------
  // g_{.k} ~ N_S(0, A), independent across axes k; A fixed, unit diagonal.
  // multi_normal_cholesky_lpdf contributes
  //     -S/2 log(2 pi) - sum_s log L_A[s,s] - 0.5 || L_A^{-1} g_{.k} ||^2
  // and sum_s log L_A[s,s] = 0.5 log|A|, i.e. exactly the k-th summand of (G).
  for (k in 1:K) {
    target += multi_normal_cholesky_lpdf(col(G, k) | zeros_S, L_A);
  }

  // No priors.  No Jacobian adjustments.  No third density term.
}

generated quantities {
  // Reporting only; never used in the density (spec section 4.3).
  // Loadings-only: Sigma_phy = Lambda Lambda', singular of rank K < T.
  matrix[n_t, n_t] Sigma_phy = Lambda * Lambda';
}
