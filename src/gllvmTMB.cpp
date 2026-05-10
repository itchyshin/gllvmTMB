// gllvmTMB_multi.cpp -- TMB template for the multivariate (stacked-trait,
// long-format) model. Companion to src/gllvmTMB.cpp (single-response sdmTMB
// engine). Implements the Nakagawa et al. (in prep) functional-biogeography
// GLLVM with a glmmTMB-style covariance dispatch (rr / diag / propto /
// equalto) and an sdmTMB-style spde() spatial term.
//
// Stage 2 (this version) supports:
//   * trait-specific fixed effects via X_fix
//   * rr(0+trait | site, d = d_B) (between-site reduced-rank: u_st = Lambda_B * z_B)
//   * diag(0+trait | site) (between-site trait-specific specific variance: s_st_B)
//   * rr(0+trait | site_species, d = d_W) (within-site reduced-rank: e_sit = Lambda_W * z_W)
//   * diag(0+trait | site_species) (within-site specific variance: s_sit_W)
//   * Gaussian observation likelihood
// Each of the four covstruct terms can be toggled on/off independently via
// the use_* flags.
//
// The reduced-rank block is a direct port from glmmTMB src/glmmTMB.cpp
// (case rr_covstruct, lines ~698-762; Brooks et al. 2017, GPL-3). Lambda
// is lower-triangular: theta = [lam_diag (rank entries), lam_lower (rest)],
// filled column-by-column with strict upper triangle zeroed for
// identifiability.
//
// Stages 3-5 will add propto/equalto and the spde() term inside this same
// template; the layout of DATA / PARAMETER macros is designed to be
// extensible.

#define TMB_LIB_INIT R_init_gllvmTMB
#include <TMB.hpp>

template <class Type>
Type objective_function<Type>::operator()()
{
  using namespace density;

  // -------- DATA --------------------------------------------------------
  DATA_VECTOR(y);                  // long-format response (n_obs)
  DATA_VECTOR(n_trials);           // length n_obs; size argument for binomial.
                                   // For non-binomial rows the entry is unused
                                   // (set to 1.0 by R). For Bernoulli rows it
                                   // is 1.0; for binomial(k-of-n) rows it is
                                   // the trial count and y is the success count.
  DATA_MATRIX(X_fix);              // fixed-effects design matrix (n_obs x p)
  DATA_IVECTOR(trait_id);          // 0-indexed trait per row
  DATA_IVECTOR(site_id);           // 0-indexed site per row
  DATA_IVECTOR(site_species_id);   // 0-indexed site_species per row
  DATA_INTEGER(n_traits);
  DATA_INTEGER(n_sites);
  DATA_INTEGER(n_site_species);
  DATA_INTEGER(d_B);               // rank of between-site rr term (>= 1 if used)
  DATA_INTEGER(d_W);               // rank of within-site rr term  (>= 1 if used)
  DATA_INTEGER(use_rr_B);          // 1/0
  DATA_INTEGER(use_diag_B);        // 1/0
  DATA_INTEGER(use_rr_W);          // 1/0
  DATA_INTEGER(use_diag_W);        // 1/0

  // Stage-3 phylogenetic random effect (propto): one length-n_species draw
  // per trait, prior MVN(0, exp(loglambda_phy) * C_phy). The species factor
  // is mapped onto observations via species_id.
  DATA_INTEGER(use_propto);
  DATA_IVECTOR(species_id);        // 0-indexed species per row (only used if use_propto)
  DATA_INTEGER(n_species);
  DATA_MATRIX(Cphy_inv);           // n_species x n_species, precomputed
  DATA_SCALAR(log_det_Cphy);       // scalar, precomputed

  // Stage-3 species non-phylogenetic random effect (q_it): diag of trait-
  // specific variances on species level. Re-uses diag_covstruct semantics
  // but on the species grouping rather than site / site_species.
  DATA_INTEGER(use_diag_species);

  // Stage-3 known-V (equalto): a single length-n_obs draw with prior
  // MVN(0, V), V fixed. Used by Stage 6's two-stage meta-regression.
  DATA_INTEGER(use_equalto);
  DATA_MATRIX(V_inv);              // n_obs x n_obs (kept as dense for now)
  DATA_SCALAR(log_det_V);

  // Stage-4 spde: one independent SPDE field per trait. Uses fmesher-built
  // SPDE finite-element matrices M0, M1, M2 and a sparse projection matrix
  // A_proj (n_obs x n_mesh). The Q matrix is reconstructed inside the
  // template as Q_base = kappa^4 * M0 + 2 * kappa^2 * M1 + M2.
  //
  // spde_lv_k toggles the rank of the spatial component:
  //   * spde_lv_k == 0: per-trait independent fields path
  //     (`spatial_unique` / `spatial_scalar`). One omega_spde column per
  //     trait, prior SCALE(GMRF(Q), 1/tau)(omega_t).
  //   * spde_lv_k >= 1: low-rank `spatial_latent` path. K_S shared spatial
  //     fields omega_spde_lv (n_mesh x K_S) with prior GMRF(Q_base) (tau
  //     absorbed into Lambda_spde for identifiability, mirroring
  //     phylo_latent), and a T x K_S loading matrix Lambda_spde drives all
  //     traits via eta(o) += sum_k Lambda_spde(t, k) * (A_proj * omega_spde_lv.col(k))(o).
  DATA_INTEGER(use_spde);
  DATA_INTEGER(spde_lv_k);         // 0 = per-trait path; >=1 = K-rank loadings path
  DATA_INTEGER(n_mesh);
  DATA_SPARSE_MATRIX(A_proj);      // n_obs x n_mesh
  DATA_SPARSE_MATRIX(spde_M0);     // n_mesh x n_mesh
  DATA_SPARSE_MATRIX(spde_M1);
  DATA_SPARSE_MATRIX(spde_M2);

  // Stage-33 + 37: response family. family_id_vec is length n_obs;
  // each entry picks the family for that observation:
  //   0 = Gaussian (identity link)
  //   1 = Bernoulli / binomial
  //   2 = Poisson (log link)
  //   3 = Lognormal (log link)
  //   4 = Gamma (log link)
  //   5 = NB2 negative binomial type-2 (log link)
  //   6 = Tweedie compound Poisson-Gamma (log link)
  //   7 = Beta (logit link; mu-phi parameterisation, y in (0, 1))
  //   8 = Beta-binomial (logit link; n_trials trials, mu-phi parameterisation)
  //   9 = Student-t (identity link; per-trait sigma + df)
  //  10 = truncated Poisson (log link; y >= 1 strictly)
  //  11 = truncated NB2 (log link; y >= 1 strictly; per-trait phi)
  //  12 = delta_lognormal (hurdle: Bernoulli{y>0} x Lognormal{y|y>0})
  //  13 = delta_gamma     (hurdle: Bernoulli{y>0} x Gamma{y|y>0})
  //  14 = ordinal_probit  (Wright/Falconer/Hadfield threshold model;
  //                        K-category ordinal data with K >= 3, K-2 free
  //                        cutpoints per trait beyond the fixed tau_1 = 0)
  // For single-family fits the vector is filled with the same value.
  // sigma_eps is mapped off when no row has family_id_vec(o) in {0, 3, 4}.
  // Delta families share ONE linear predictor for both components: p =
  // invlogit(eta) for presence and mu_pos = exp(eta) for the positive
  // continuous part. A future release may decouple the two predictors.
  DATA_IVECTOR(family_id_vec);

  // link_id_vec is length n_obs (matched to family_id_vec). Currently
  // only the binomial family (fid 1) is link-flexible; for other
  // families the entry is ignored. Encoding:
  //   0 = logit   (binomial; canonical; implicit latent-residual var = pi^2/3)
  //   1 = probit  (binomial; implicit latent-residual var = 1)
  //   2 = cloglog (binomial; implicit latent-residual var = pi^2/6)
  // For Gaussian/Poisson/lognormal/Gamma, link_id_vec entries are 0
  // and unused.
  DATA_IVECTOR(link_id_vec);

  // ordinal_probit (fid 14): per-trait cutpoint metadata.
  // n_ordinal_cuts_per_trait(t)  = K_t - 2, the number of FREE cutpoints
  //                               for trait t (0 for non-ordinal traits).
  //                               tau_1 = 0 is fixed for identifiability,
  //                               so a K_t-category trait estimates K_t - 2
  //                               cutpoints {tau_2, ..., tau_{K_t-1}}.
  // ordinal_offset_per_trait(t)  = cumulative count of free cutpoints across
  //                               traits 1..t-1 (start index into the flat
  //                               ordinal_log_increments parameter vector).
  // The vector length is n_traits in both cases; entries for non-ordinal
  // traits are 0 and unused. Reference: Hadfield (2015) MEE 6:706-714, eqn 9.
  DATA_IVECTOR(n_ordinal_cuts_per_trait);
  DATA_IVECTOR(ordinal_offset_per_trait);

  // Stage-35 / Stage-40: phylogenetic reduced-rank covstruct (PGLLVM).
  // For each factor k = 0..d_phy-1, g_phy.col(k) ~ N(0, A) where A is
  // the phylogenetic correlation matrix, passed as its (sparse) inverse
  // for efficient quadratic-form evaluation.
  //
  // Stage-40 (true sparse-$A^{-1}$ trick): A^-1 is built over tips +
  // internal nodes via MCMCglmm::inverseA(tree), giving a genuinely
  // sparse matrix of dimension n_aug_phy = 2*n_tips - 1 (or close to it
  // depending on tree topology). Each observation's contribution reads
  // g_phy at the augmented row corresponding to its tip species, via
  // species_aug_id.
  //
  // Backward-compatible fallback: when no tree is provided, R passes
  // a dense Cphy^-1 and species_aug_id == species_id; the dimensions
  // collapse to n_species and behaviour is identical to the previous
  // implementation.
  DATA_INTEGER(use_phylo_rr);
  DATA_INTEGER(d_phy);
  DATA_INTEGER(n_aug_phy);           // n_aug_phy >= n_species (== n_species in legacy path)
  DATA_SPARSE_MATRIX(Ainv_phy_rr);   // n_aug_phy x n_aug_phy (sparse)
  DATA_SCALAR(log_det_A_phy_rr);     // precomputed
  DATA_IVECTOR(species_aug_id);      // n_obs, 0-indexed row in g_phy (== species_id in legacy path)

  // Two-U PGLLVM: phylo_diag (per-trait phylogenetic random intercept).
  // When phylo_latent(species, d=K) and phylo_unique(species) co-fit, the
  // phy-tier covariance becomes Sigma_phy = Lambda_phy Lambda_phy^T +
  // diag(U_phy). The Lambda_phy Lambda_phy^T part is fit by the phylo_rr
  // block above; the diag(U_phy) part is fit here, with one phylogenetic
  // random intercept per trait. Each column g_phy_diag.col(t) ~ N(0, A)
  // (the same A used by phylo_rr), scaled by exp(log_sd_phy_diag(t)).
  // Reuses Ainv_phy_rr, n_aug_phy, log_det_A_phy_rr, species_aug_id from
  // the phylo_rr machinery (no new tree / VCV needed). When
  // use_phylo_diag == 0, log_sd_phy_diag and g_phy_diag are mapped off.
  // Reference: Hadfield & Nakagawa (2010) JEB 23:494-508; Halliwell et al.
  // (2025); Meyer & Kirkpatrick (2008) Genetics 178:2223-2240.
  DATA_INTEGER(use_phylo_diag);

  // Phylogenetic random slope (Q6):
  //   eta(o) += b_phy_slope(species_aug_id(o)) * x_phy_slope(o)
  //   b_phy_slope ~ N(0, sigma_slope^2 * A_phy)
  // Slopes are shared across traits (one per species, applied uniformly to
  // every trait). Reuses Ainv_phy_rr / n_aug_phy / species_aug_id from the
  // phylo_rr machinery. When use_phylo_slope == 0, b_phy_slope is mapped
  // off and x_phy_slope is unused.
  DATA_INTEGER(use_phylo_slope);
  DATA_VECTOR(x_phy_slope);          // length n_obs; covariate values

  // Generic random intercepts `(1 | group)` (lme4/glmmTMB bar syntax).
  // Each term t adds u_re_int[offset(t) + group_id(o, t)] to eta(o), where
  // u_re_int[range_t] ~ N(0, sigma_re_int(t)^2) i.i.d. across levels.
  // Random slopes are not yet implemented.
  DATA_INTEGER(use_re_int);
  DATA_INTEGER(n_re_int_terms);
  DATA_IVECTOR(re_int_offsets);      // length n_re_int_terms (start of each term in u_re_int)
  DATA_IVECTOR(re_int_n_groups);     // length n_re_int_terms (n levels per term)
  DATA_IMATRIX(re_int_group_id);     // n_obs x n_re_int_terms (0-indexed group level per row, term)

  // lme4 / glmmTMB-style per-row likelihood weights (length n_obs). The
  // observation-level NLL contribution for row o is multiplied by
  // weights_i(o). For binomial rows the user-supplied `weights = ` is
  // already absorbed into n_trials (the alternative-API trial-count
  // semantics), so weights_i(o) is set to 1 on those rows by the R side
  // to avoid double-application. Unit weights (default) reproduce the
  // unweighted behaviour exactly. Mirrors src/gllvmTMB.cpp:162.
  DATA_VECTOR(weights_i);

  // -------- PARAMETERS --------------------------------------------------
  PARAMETER_VECTOR(b_fix);                       // fixed-effects coefficients (p)
  PARAMETER(log_sigma_eps);                      // residual log-SD

  // Between-site rr: Lambda_B (n_traits x d_B) packed as theta_rr_B
  // length = d_B + (n_traits - d_B) * d_B = n_traits*d_B - d_B*(d_B-1)/2
  PARAMETER_VECTOR(theta_rr_B);
  PARAMETER_MATRIX(z_B);                         // d_B x n_sites spherical N(0, I)

  // Between-site diag: log-SDs per trait
  PARAMETER_VECTOR(theta_diag_B);                // length n_traits
  PARAMETER_MATRIX(s_B);                         // n_traits x n_sites

  // Within-site rr: Lambda_W (n_traits x d_W)
  PARAMETER_VECTOR(theta_rr_W);
  PARAMETER_MATRIX(z_W);                         // d_W x n_site_species

  // Within-site diag
  PARAMETER_VECTOR(theta_diag_W);                // length n_traits
  PARAMETER_MATRIX(s_W);                         // n_traits x n_site_species

  // Stage-3 propto: phylogenetic random effects p_it. Single global scaling
  // loglambda_phy. p_phy is n_species x n_traits, prior MVN(0, exp(loglambda_phy) * Cphy)
  // applied independently across trait columns.
  PARAMETER(loglambda_phy);                      // single global scaling
  PARAMETER_MATRIX(p_phy);                       // n_species x n_traits

  // Stage-3 non-phylogenetic species term q_it: diag(0 + trait | species)
  PARAMETER_VECTOR(theta_diag_species);          // length n_traits
  PARAMETER_MATRIX(q_sp);                        // n_traits x n_species

  // Stage-3 equalto: known-V random effect e_eq, length n_obs, prior MVN(0, V)
  PARAMETER_VECTOR(e_eq);                        // length n_obs (or 1 if unused)

  // Stage-4 spde: one SPDE field per trait
  PARAMETER_VECTOR(log_tau_spde);                // length n_traits (or 1 if unused)
  PARAMETER(log_kappa_spde);                     // shared
  PARAMETER_MATRIX(omega_spde);                  // n_mesh x n_traits

  // spatial_latent: low-rank SPDE loadings + K_S shared spatial fields.
  // Same packed lower-triangular layout as theta_rr_B / theta_rr_W /
  // theta_rr_phy; identifiability via the standard rr() convention. Tau is
  // absorbed into Lambda_spde so omega_spde_lv has prior N(0, Q_base^{-1}).
  PARAMETER_VECTOR(theta_rr_spde_lv);            // packed Lambda_spde (n_traits x spde_lv_k)
  PARAMETER_MATRIX(omega_spde_lv);               // n_mesh x spde_lv_k

  // Stage-35 PGLLVM: phylogenetic reduced-rank loadings + species factors.
  PARAMETER_VECTOR(theta_rr_phy);                // packed lower-triangular Lambda_phy
  PARAMETER_MATRIX(g_phy);                       // n_species x d_phy
  // Two-U PGLLVM: per-trait phylogenetic random intercepts and their log-SDs.
  // log_sd_phy_diag is length n_traits (or 1 if unused); g_phy_diag is
  // n_aug_phy x n_traits (or n_aug_phy x 1 if unused). Each trait column is
  // ~ N(0, A) with the same Ainv_phy_rr / log_det_A_phy_rr as phylo_rr.
  PARAMETER_VECTOR(log_sd_phy_diag);             // length n_traits (or 1 if unused)
  PARAMETER_MATRIX(g_phy_diag);                  // n_aug_phy x n_traits (or x 1 if unused)
  // phylo_slope params (Q6)
  PARAMETER_VECTOR(b_phy_slope);                 // length n_aug_phy; per-species slopes
  PARAMETER(log_sigma_slope);                    // scalar; log slope sd

  // Generic random intercepts: flat vector across all (1|g) terms.
  PARAMETER_VECTOR(u_re_int);                    // length sum(re_int_n_groups) (or 1 if unused)
  PARAMETER_VECTOR(log_sigma_re_int);            // length n_re_int_terms (or 1 if unused)

  // NB2 / Tweedie dispersion parameters (per trait). Mapped off when the
  // corresponding family is not in family_id_vec; otherwise one log-phi
  // (NB2) and one log-phi + logit-p (Tweedie) per trait is estimated.
  // NB2 variance: var = mu + mu^2 / phi (so phi -> infinity recovers Poisson).
  // Tweedie:      var = phi * mu^p with 1 < p < 2 (compound Poisson-Gamma).
  PARAMETER_VECTOR(log_phi_nbinom2);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_tweedie);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(logit_p_tweedie);             // length n_traits (or 1 if unused); p = 1 + plogis(.)

  // Beta / beta-binomial precision parameters (per trait). Mapped off when
  // the corresponding family is not in family_id_vec. Both families use the
  // mean-precision (mu, phi) parameterisation: a = mu * phi, b = (1-mu)*phi
  // so Var(y_beta) = mu*(1-mu)/(1+phi). Larger phi -> tighter concentration.
  // Reference for the Beta regression parameterisation: Smithson & Verkuilen
  // (2006) Psychol. Methods 11:54-71. Beta-binomial follows Hilbe (2014)
  // Modeling Count Data and Bolker (2008) Ecological Models and Data in R.
  PARAMETER_VECTOR(log_phi_beta);                // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_betabinom);           // length n_traits (or 1 if unused)

  // Student-t (family_id 9): per-trait scale (log_sigma_student) and
  // per-trait log(df - 1) (log_df_student) so df = 1 + exp(log_df_student) > 1.
  // Mapped off when no row has fid 9. Reference: Lange, Little & Taylor
  // (1989) JASA 84:881-896; Pinheiro, Liu & Wu (2001) Comp. Stat. Data Anal.
  // 38:367-386. Identity link; mu = eta(o).
  PARAMETER_VECTOR(log_sigma_student);           // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_df_student);              // length n_traits (or 1 if unused); df = 1 + exp(log_df_student)

  // truncated_nbinom2 (family_id 11): zero-truncated NB2. Per-trait log-phi.
  // Likelihood: dnbinom2(y, mu, phi) / (1 - dnbinom2(0, mu, phi)) for y >= 1.
  // Mapped off when no row has fid 11.
  PARAMETER_VECTOR(log_phi_truncnb2);            // length n_traits (or 1 if unused)

  // Delta (hurdle) families: per-trait dispersion of the *positive*
  // component only. The Bernoulli presence component has no extra
  // dispersion. Mapped off when fid 12/13 is absent.
  PARAMETER_VECTOR(log_sigma_lognormal_delta);   // length n_traits (or 1 if unused), fid 12
  PARAMETER_VECTOR(log_phi_gamma_delta);         // length n_traits (or 1 if unused), fid 13

  // ordinal_probit (fid 14): flat vector of LOG-spacings between
  // consecutive cutpoints, packed across ordinal traits in trait order.
  // For each ordinal trait t with K_t categories, n_ordinal_cuts_per_trait(t)
  // = K_t - 2 elements live at positions [ordinal_offset_per_trait(t),
  // ordinal_offset_per_trait(t) + K_t - 2). Cutpoints are then reconstructed
  // as tau_t = (0, exp(delta_{t,1}), exp(delta_{t,1}) + exp(delta_{t,2}), ...)
  // which guarantees tau_t,1 = 0 < tau_t,2 < tau_t,3 < ... by construction
  // (Christensen 2019 ordinal R package; brms cumulative()). Mapped off
  // (length 1 stub) when no row has fid 14.
  PARAMETER_VECTOR(ordinal_log_increments);

  Type nll = 0;

  // -------- Fixed-effects part of the linear predictor ------------------
  vector<Type> eta_fix = X_fix * b_fix;
  vector<Type> eta(y.size());
  for (int o = 0; o < y.size(); o++) eta(o) = eta_fix(o);

  // -------- Construct Lambda_B (n_traits x d_B), lower-triangular -------
  // Ported from glmmTMB src/glmmTMB.cpp case rr_covstruct (Brooks et al.,
  // GPL-3). theta layout: head(d_B) = lam_diag, tail = lam_lower (column-
  // major fill of the strict lower triangle).
  matrix<Type> Lambda_B(n_traits, std::max(d_B, 1));
  Lambda_B.setZero();
  if (use_rr_B == 1) {
    int p = n_traits;
    int rank = d_B;
    int nt = theta_rr_B.size();
    int expected_nt = p * rank - rank * (rank - 1) / 2;
    if (nt != expected_nt)
      error("gllvmTMB_multi: theta_rr_B has wrong length");
    vector<Type> lam_diag = theta_rr_B.head(rank);
    vector<Type> lam_lower = theta_rr_B.tail(nt - rank);
    for (int j = 0; j < rank; j++) {
      for (int i = 0; i < p; i++) {
        if (j > i)
          Lambda_B(i, j) = 0;
        else if (i == j)
          Lambda_B(i, j) = lam_diag(j);
        else
          Lambda_B(i, j) = lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
      }
    }
    // Spherical prior on z_B
    for (int s = 0; s < n_sites; s++) {
      vector<Type> col_s = z_B.col(s);
      nll -= dnorm(col_s, Type(0), Type(1), true).sum();
    }
    REPORT(Lambda_B);
    matrix<Type> Sigma_B = Lambda_B * Lambda_B.transpose();
    REPORT(Sigma_B);
  }

  // -------- diag_B contribution ----------------------------------------
  if (use_diag_B == 1) {
    if (theta_diag_B.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_B has wrong length");
    vector<Type> sd_B = exp(theta_diag_B);
    REPORT(sd_B);
    for (int s = 0; s < n_sites; s++) {
      for (int t = 0; t < n_traits; t++) {
        nll -= dnorm(s_B(t, s), Type(0), sd_B(t), true);
      }
    }
  }

  // -------- Construct Lambda_W (n_traits x d_W), lower-triangular -------
  matrix<Type> Lambda_W(n_traits, std::max(d_W, 1));
  Lambda_W.setZero();
  if (use_rr_W == 1) {
    int p = n_traits;
    int rank = d_W;
    int nt = theta_rr_W.size();
    int expected_nt = p * rank - rank * (rank - 1) / 2;
    if (nt != expected_nt)
      error("gllvmTMB_multi: theta_rr_W has wrong length");
    vector<Type> lam_diag = theta_rr_W.head(rank);
    vector<Type> lam_lower = theta_rr_W.tail(nt - rank);
    for (int j = 0; j < rank; j++) {
      for (int i = 0; i < p; i++) {
        if (j > i)
          Lambda_W(i, j) = 0;
        else if (i == j)
          Lambda_W(i, j) = lam_diag(j);
        else
          Lambda_W(i, j) = lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
      }
    }
    for (int ss = 0; ss < n_site_species; ss++) {
      vector<Type> col_ss = z_W.col(ss);
      nll -= dnorm(col_ss, Type(0), Type(1), true).sum();
    }
    REPORT(Lambda_W);
    matrix<Type> Sigma_W = Lambda_W * Lambda_W.transpose();
    REPORT(Sigma_W);
  }

  // -------- diag_W contribution ----------------------------------------
  if (use_diag_W == 1) {
    if (theta_diag_W.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_W has wrong length");
    vector<Type> sd_W = exp(theta_diag_W);
    REPORT(sd_W);
    for (int ss = 0; ss < n_site_species; ss++) {
      for (int t = 0; t < n_traits; t++) {
        nll -= dnorm(s_W(t, ss), Type(0), sd_W(t), true);
      }
    }
  }

  // -------- propto phylogenetic random effect (per trait) ---------------
  // For each trait t, p_phy.col(t) ~ MVN(0, exp(loglambda_phy) * Cphy)
  // -log p = 0.5 * (n_species*log(2π) + n_species*loglambda_phy + log_det_Cphy
  //                + exp(-loglambda_phy) * p_t' Cphy_inv p_t)
  if (use_propto == 1) {
    Type lam_phy = exp(loglambda_phy);
    Type inv_lam = exp(-loglambda_phy);
    for (int t = 0; t < n_traits; t++) {
      vector<Type> p_t = p_phy.col(t);
      Type quad = (p_t.matrix().transpose() * Cphy_inv * p_t.matrix())(0, 0);
      nll += 0.5 * (Type(n_species) * log(2.0 * M_PI)
                    + Type(n_species) * loglambda_phy
                    + log_det_Cphy
                    + inv_lam * quad);
    }
    REPORT(lam_phy);
  }

  // -------- diag(0 + trait | species) -- non-phylo q_it ----------------
  if (use_diag_species == 1) {
    if (theta_diag_species.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_species has wrong length");
    vector<Type> sd_q = exp(theta_diag_species);
    REPORT(sd_q);
    for (int i = 0; i < n_species; i++) {
      for (int t = 0; t < n_traits; t++)
        nll -= dnorm(q_sp(t, i), Type(0), sd_q(t), true);
    }
  }

  // -------- Stage-35 phylo_rr (PGLLVM) ----------------------------------
  // For each phylogenetic factor k, g_phy.col(k) ~ N(0, A_phy). Apply
  // the lower-triangular rr() identifiability convention to Lambda_phy
  // (re-using the same packed layout as theta_rr_B / theta_rr_W).
  matrix<Type> Lambda_phy(n_traits, std::max(d_phy, 1));
  Lambda_phy.setZero();
  if (use_phylo_rr == 1) {
    int p = n_traits;
    int rank = d_phy;
    int nt = theta_rr_phy.size();
    int expected_nt = p * rank - rank * (rank - 1) / 2;
    if (nt != expected_nt)
      error("gllvmTMB_multi: theta_rr_phy has wrong length");
    vector<Type> lam_diag = theta_rr_phy.head(rank);
    vector<Type> lam_lower = theta_rr_phy.tail(nt - rank);
    for (int j = 0; j < rank; j++) {
      for (int i = 0; i < p; i++) {
        if (j > i)
          Lambda_phy(i, j) = 0;
        else if (i == j)
          Lambda_phy(i, j) = lam_diag(j);
        else
          Lambda_phy(i, j) = lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
      }
    }
    // Prior: each column of g_phy is N(0, A), evaluated through the sparse Ainv.
    // -log p(g_k) = 0.5 * (n_aug_phy * log(2pi) + log_det_A + g_k' Ainv g_k)
    // In the Stage-40 sparse-$A^{-1}$ path n_aug_phy = 2*n_tips - 1 (tips +
    // internal nodes); in the legacy dense path n_aug_phy == n_species.
    for (int k = 0; k < d_phy; k++) {
      vector<Type> g_k = g_phy.col(k);
      Type quad = (g_k.matrix().transpose() * Ainv_phy_rr * g_k.matrix())(0, 0);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + log_det_A_phy_rr + quad);
    }
    REPORT(Lambda_phy);
    matrix<Type> Sigma_phy = Lambda_phy * Lambda_phy.transpose();
    REPORT(Sigma_phy);
  }

  // -------- Two-U PGLLVM phylo_diag (per-trait phylo random intercept) ---
  // Each trait column g_phy_diag.col(t) ~ N(0, A) with the same A^-1 as
  // phylo_rr, scaled by exp(log_sd_phy_diag(t)). The contribution to eta
  // is eta(o) += exp(log_sd_phy_diag(t)) * g_phy_diag(species_aug_id(o), t),
  // which is equivalent to drawing a per-trait phylogenetic intercept
  // u_t ~ N(0, sd^2 * A). The trait-by-trait diagonal U_phy =
  // diag(exp(2 * log_sd_phy_diag)) is the "unique" phylogenetic component
  // (Hadfield & Nakagawa 2010; Meyer & Kirkpatrick 2008).
  vector<Type> sd_phy_diag(n_traits);
  matrix<Type> Sigma_phy_diag(n_traits, n_traits);
  if (use_phylo_diag == 1) {
    if (log_sd_phy_diag.size() != n_traits)
      error("gllvmTMB_multi: log_sd_phy_diag has wrong length");
    for (int t = 0; t < n_traits; t++) sd_phy_diag(t) = exp(log_sd_phy_diag(t));
    REPORT(sd_phy_diag);
    ADREPORT(sd_phy_diag);
    Sigma_phy_diag.setZero();
    for (int t = 0; t < n_traits; t++)
      Sigma_phy_diag(t, t) = sd_phy_diag(t) * sd_phy_diag(t);
    REPORT(Sigma_phy_diag);
    // Prior: each column ~ N(0, A).
    // -log p(g_t) = 0.5 * (n_aug_phy * log(2pi) + log_det_A + g_t' Ainv g_t)
    for (int t = 0; t < n_traits; t++) {
      vector<Type> g_t = g_phy_diag.col(t);
      Type quad = (g_t.matrix().transpose() * Ainv_phy_rr * g_t.matrix())(0, 0);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + log_det_A_phy_rr + quad);
    }
  }

  // -------- Q6: phylo_slope prior --------------------------------------
  // b_phy_slope ~ N(0, sigma_slope^2 * A_phy), evaluated through the
  // sparse Ainv. The same Ainv_phy_rr is shared with phylo_rr above.
  // -log p(b) = 0.5 * (n_aug_phy * log(2pi) + 2 n_aug_phy log_sigma_slope
  //                    + log_det_A_phy_rr
  //                    + b' Ainv b / sigma_slope^2)
  if (use_phylo_slope == 1) {
    Type sigma_slope = exp(log_sigma_slope);
    Type sigma_slope2 = sigma_slope * sigma_slope;
    vector<Type> b = b_phy_slope;
    Type quad = (b.matrix().transpose() * Ainv_phy_rr * b.matrix())(0, 0);
    nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                  + Type(2) * Type(n_aug_phy) * log_sigma_slope
                  + log_det_A_phy_rr
                  + quad / sigma_slope2);
    REPORT(sigma_slope);
  }

  // -------- spde: per-trait SPDE GMRF prior on omega columns -----------
  // Marriage step: glmmTMB-style covstruct dispatch + sdmTMB-style sparse Q.
  // Two paths share the same Q_base = kappa^4 M0 + 2 kappa^2 M1 + M2:
  //
  //   * per-trait path (spde_lv_k == 0): one omega_spde column per trait,
  //     each scaled by its own tau_t -- prior N(0, (tau_t^2 Q_base)^-1).
  //     Used by spatial_unique() and spatial_scalar() (the latter ties the
  //     log_tau_spde entries via the R-side TMB map).
  //   * spatial_latent path (spde_lv_k >= 1): K_S shared spatial fields in
  //     omega_spde_lv with prior GMRF(Q_base) (tau == 1, scale absorbed
  //     into Lambda_spde for identifiability), and a packed
  //     lower-triangular Lambda_spde (n_traits x K_S) loading matrix.
  matrix<Type> Lambda_spde(n_traits, std::max(spde_lv_k, 1));
  Lambda_spde.setZero();
  if (use_spde == 1) {
    Type kappa  = exp(log_kappa_spde);
    Type kappa2 = kappa * kappa;
    Type kappa4 = kappa2 * kappa2;
    Eigen::SparseMatrix<Type> Q_base =
      kappa4 * spde_M0 + Type(2.0) * kappa2 * spde_M1 + spde_M2;
    if (spde_lv_k == 0) {
      // Per-trait path
      for (int t = 0; t < n_traits; t++) {
        Type tau = exp(log_tau_spde(t));
        vector<Type> omega_t = omega_spde.col(t);
        nll += SCALE(GMRF(Q_base), Type(1.0) / tau)(omega_t);
      }
      REPORT(log_tau_spde);
    } else {
      // spatial_latent: build Lambda_spde from packed lower-triangular
      // theta_rr_spde_lv (same layout as theta_rr_B/W/phy).
      int p = n_traits;
      int rank = spde_lv_k;
      int nt = theta_rr_spde_lv.size();
      int expected_nt = p * rank - rank * (rank - 1) / 2;
      if (nt != expected_nt)
        error("gllvmTMB_multi: theta_rr_spde_lv has wrong length");
      vector<Type> lam_diag = theta_rr_spde_lv.head(rank);
      vector<Type> lam_lower = theta_rr_spde_lv.tail(nt - rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < p; i++) {
          if (j > i)
            Lambda_spde(i, j) = 0;
          else if (i == j)
            Lambda_spde(i, j) = lam_diag(j);
          else
            Lambda_spde(i, j) = lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
        }
      }
      // Prior on each column of omega_spde_lv: GMRF(Q_base) (no tau scale --
      // absorbed into Lambda_spde).
      for (int k = 0; k < spde_lv_k; k++) {
        vector<Type> omega_k = omega_spde_lv.col(k);
        nll += GMRF(Q_base)(omega_k);
      }
      REPORT(Lambda_spde);
      matrix<Type> Sigma_spde = Lambda_spde * Lambda_spde.transpose();
      REPORT(Sigma_spde);
    }
    REPORT(kappa);
  }

  // -------- generic (1 | group) random intercepts -----------------------
  // For each term t, the slice u_re_int[offset(t) .. offset(t)+n_groups(t))
  // is i.i.d. N(0, sigma_re_int(t)^2). Sum independent normal log-densities.
  if (use_re_int == 1) {
    for (int t = 0; t < n_re_int_terms; t++) {
      Type sigma_t = exp(log_sigma_re_int(t));
      int off = re_int_offsets(t);
      int ng  = re_int_n_groups(t);
      for (int g = 0; g < ng; g++) {
        nll -= dnorm(u_re_int(off + g), Type(0), sigma_t, true);
      }
    }
    REPORT(log_sigma_re_int);
  }

  // -------- equalto: e_eq ~ MVN(0, V), V fixed --------------------------
  if (use_equalto == 1) {
    Type quad = (e_eq.matrix().transpose() * V_inv * e_eq.matrix())(0, 0);
    nll += 0.5 * (Type(e_eq.size()) * log(2.0 * M_PI)
                  + log_det_V
                  + quad);
  }

  // -------- Pre-compute spatial-projected fields for spde --------------
  // For the per-trait path (spde_lv_k == 0): A_omega(o, t) =
  //   (A_proj * omega_spde)(o, t). One sparse matvec per trait.
  // For the spatial_latent path (spde_lv_k >= 1): A_omega_lv(o, k) =
  //   (A_proj * omega_spde_lv)(o, k). One sparse matvec per latent field;
  //   the per-trait contribution is built inside the eta loop via
  //   sum_k Lambda_spde(t, k) * A_omega_lv(o, k).
  matrix<Type> A_omega(y.size(), std::max(n_traits, 1));
  matrix<Type> A_omega_lv(y.size(), std::max(spde_lv_k, 1));
  A_omega.setZero();
  A_omega_lv.setZero();
  if (use_spde == 1) {
    if (spde_lv_k == 0) {
      for (int t = 0; t < n_traits; t++) {
        vector<Type> omega_t = omega_spde.col(t);
        vector<Type> Ao_t = A_proj * omega_t;
        for (int o = 0; o < y.size(); o++) A_omega(o, t) = Ao_t(o);
      }
    } else {
      for (int k = 0; k < spde_lv_k; k++) {
        vector<Type> omega_k = omega_spde_lv.col(k);
        vector<Type> Ao_k = A_proj * omega_k;
        for (int o = 0; o < y.size(); o++) A_omega_lv(o, k) = Ao_k(o);
      }
    }
  }

  // -------- Add RE contributions to eta ---------------------------------
  for (int o = 0; o < y.size(); o++) {
    int t  = trait_id(o);
    int s  = site_id(o);
    int ss = site_species_id(o);
    if (use_rr_B == 1) {
      Type u_B_st = 0;
      for (int k = 0; k < d_B; k++) u_B_st += Lambda_B(t, k) * z_B(k, s);
      eta(o) += u_B_st;
    }
    if (use_diag_B == 1)
      eta(o) += s_B(t, s);
    if (use_rr_W == 1) {
      Type u_W_sst = 0;
      for (int k = 0; k < d_W; k++) u_W_sst += Lambda_W(t, k) * z_W(k, ss);
      eta(o) += u_W_sst;
    }
    if (use_diag_W == 1)
      eta(o) += s_W(t, ss);
    if (use_propto == 1)
      eta(o) += p_phy(species_id(o), t);
    if (use_diag_species == 1)
      eta(o) += q_sp(t, species_id(o));
    if (use_equalto == 1)
      eta(o) += e_eq(o);
    if (use_spde == 1) {
      if (spde_lv_k == 0) {
        eta(o) += A_omega(o, t);
      } else {
        Type contrib_spde = 0;
        for (int k = 0; k < spde_lv_k; k++)
          contrib_spde += Lambda_spde(t, k) * A_omega_lv(o, k);
        eta(o) += contrib_spde;
      }
    }
    if (use_phylo_rr == 1) {
      Type contrib = 0;
      for (int k = 0; k < d_phy; k++)
        contrib += Lambda_phy(t, k) * g_phy(species_aug_id(o), k);
      eta(o) += contrib;
    }
    if (use_phylo_diag == 1) {
      // Per-trait phylogenetic random intercept.
      eta(o) += exp(log_sd_phy_diag(t)) * g_phy_diag(species_aug_id(o), t);
    }
    if (use_phylo_slope == 1) {
      // Per-species slope on x, shared across traits.
      eta(o) += b_phy_slope(species_aug_id(o)) * x_phy_slope(o);
    }
    if (use_re_int == 1) {
      for (int term = 0; term < n_re_int_terms; term++) {
        int gid = re_int_group_id(o, term);
        eta(o) += u_re_int(re_int_offsets(term) + gid);
      }
    }
  }

  // -------- Observation likelihood --------------------------------------
  Type sigma_eps = exp(log_sigma_eps);
  REPORT(sigma_eps);
  for (int o = 0; o < y.size(); o++) {
    int fid = family_id_vec(o);
    // Capture the running NLL so we can scale this row's contribution by
    // its weight after the family-dispatch block. Mirrors the
    // `tmp_ll *= weights_i(i)` pattern in src/gllvmTMB.cpp around line 1136.
    Type nll_before_row = nll;
    if (fid == 0) {
      // Gaussian, identity link
      nll -= dnorm(y(o), eta(o), sigma_eps, true);
    } else if (fid == 1) {
      // Bernoulli / binomial(k-of-n). Link depends on link_id_vec(o):
      //   0 = logit:    p = 1 / (1 + exp(-eta))
      //   1 = probit:   p = pnorm(eta)
      //   2 = cloglog:  p = 1 - exp(-exp(eta))
      // `n_trials(o)` is the size: 1.0 for Bernoulli (default and previous
      // behaviour), otherwise the user-supplied trial count from
      // `cbind(successes, failures)` on the LHS of the formula. `y(o)` is
      // the success count; the parser ensures 0 <= y(o) <= n_trials(o).
      int lid = link_id_vec(o);
      Type p;
      if (lid == 0) {
        p = Type(1.0) / (Type(1.0) + exp(-eta(o)));
      } else if (lid == 1) {
        p = pnorm(eta(o));
      } else if (lid == 2) {
        p = Type(1.0) - exp(-exp(eta(o)));
      } else {
        error("gllvmTMB_multi: unknown link_id for binomial family");
      }
      // Numerical safety: clip away from 0/1 to prevent log(0).
      Type tiny = Type(1e-12);
      p = (p < tiny)            ? tiny           : p;
      p = (p > Type(1.0) - tiny) ? Type(1.0) - tiny : p;
      nll -= dbinom(y(o), n_trials(o), p, true);
    } else if (fid == 2) {
      // Poisson, log link
      nll -= dpois(y(o), exp(eta(o)), true);
    } else if (fid == 3) {
      // Lognormal, log link
      // y > 0 strictly. log(y) ~ Normal(eta, sigma_eps); add Jacobian -log(y).
      nll -= dnorm(log(y(o)), eta(o), sigma_eps, true) - log(y(o));
    } else if (fid == 4) {
      // Gamma, log link, mu + CV parametrization
      // mu = exp(eta); sigma_eps interpreted as the coefficient of variation.
      // shape = 1 / sigma_eps^2 ; scale = mu / shape so E(y) = mu, CV(y) = sigma_eps.
      Type mu_g    = exp(eta(o));
      Type shape_g = Type(1.0) / (sigma_eps * sigma_eps);
      Type scale_g = mu_g / shape_g;
      nll -= dgamma(y(o), shape_g, scale_g, true);
    } else if (fid == 5) {
      // NB2 (negative binomial, type 2), log link.
      // Var(y) = mu + mu^2 / phi, with one log_phi per trait.
      // Use dnbinom_robust (numerically stable; takes log_mu and log(var-mu)).
      // log(var - mu) = log(mu^2 / phi) = 2*log(mu) - log(phi).
      int t = trait_id(o);
      Type log_mu = eta(o);                       // log link
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_nbinom2(t);
      nll -= dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
    } else if (fid == 6) {
      // Tweedie compound Poisson-Gamma, log link.
      // y >= 0 (point mass at zero plus continuous positive part).
      // Per-trait dispersion phi = exp(log_phi_tweedie(t));
      // power p in (1, 2), parameterised as p = 1 + plogis(logit_p_tweedie(t)).
      int t = trait_id(o);
      Type mu_t  = exp(eta(o));
      Type phi_t = exp(log_phi_tweedie(t));
      Type p_t   = Type(1.0) + invlogit(logit_p_tweedie(t));
      nll -= dtweedie(y(o), mu_t, phi_t, p_t, true);
    } else if (fid == 7) {
      // Beta family, logit link, mean-precision parameterisation.
      // y in (0, 1); mu = invlogit(eta); a = mu*phi, b = (1-mu)*phi.
      // log f(y) = lgamma(phi) - lgamma(a) - lgamma(b)
      //           + (a - 1) log(y) + (b - 1) log(1 - y)
      // (Smithson & Verkuilen 2006 Psychol. Methods 11:54-71.)
      int t = trait_id(o);
      Type mu_b  = invlogit(eta(o));
      Type phi_b = exp(log_phi_beta(t));
      Type a_b   = mu_b * phi_b;
      Type b_b   = (Type(1.0) - mu_b) * phi_b;
      Type tiny_y = Type(1e-12);
      Type y_safe = y(o);
      y_safe = (y_safe < tiny_y)            ? tiny_y           : y_safe;
      y_safe = (y_safe > Type(1.0) - tiny_y) ? Type(1.0) - tiny_y : y_safe;
      Type ld = lgamma(phi_b) - lgamma(a_b) - lgamma(b_b)
              + (a_b - Type(1.0)) * log(y_safe)
              + (b_b - Type(1.0)) * log(Type(1.0) - y_safe);
      nll -= ld;
    } else if (fid == 8) {
      // Beta-binomial family (Hilbe 2014; Bolker 2008).
      int t = trait_id(o);
      Type mu_bb  = invlogit(eta(o));
      Type phi_bb = exp(log_phi_betabinom(t));
      Type a_bb   = mu_bb * phi_bb;
      Type b_bb   = (Type(1.0) - mu_bb) * phi_bb;
      Type N      = n_trials(o);
      Type yo     = y(o);
      Type ld = lgamma(N + Type(1.0))
              + lgamma(yo + a_bb)
              + lgamma(N - yo + b_bb)
              + lgamma(a_bb + b_bb)
              - lgamma(yo + Type(1.0))
              - lgamma(N - yo + Type(1.0))
              - lgamma(a_bb)
              - lgamma(b_bb)
              - lgamma(N + a_bb + b_bb);
      nll -= ld;
    } else if (fid == 9) {
      // Student-t, identity link.
      int t = trait_id(o);
      Type mu_t    = eta(o);
      Type sigma_t = exp(log_sigma_student(t));
      Type df_t    = Type(1.0) + exp(log_df_student(t));
      Type z_t     = (y(o) - mu_t) / sigma_t;
      nll -= dt(z_t, df_t, true) - log(sigma_t);
    } else if (fid == 10) {
      // Zero-truncated Poisson, log link.
      Type lambda_t = exp(eta(o));
      nll -= dpois(y(o), lambda_t, true)
             - logspace_sub(Type(0.0), -lambda_t);
    } else if (fid == 11) {
      // Zero-truncated NB2, log link.
      int t = trait_id(o);
      Type log_mu = eta(o);
      Type mu_t   = exp(log_mu);
      Type phi_t  = exp(log_phi_truncnb2(t));
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_truncnb2(t);
      Type log_p0 = phi_t * (log_phi_truncnb2(t) - log(mu_t + phi_t));
      nll -= dnbinom_robust(y(o), log_mu, log_v_minus_mu, true)
             - logspace_sub(Type(0.0), log_p0);
    } else if (fid == 12) {
      // delta_lognormal (hurdle): one shared eta drives both components.
      //   Presence: I{y>0} ~ Bernoulli(invlogit(eta))   via dbinom_robust
      //   Positive: log y | y>0 ~ Normal(eta, sigma_t)
      // The Bernoulli logit-p IS eta(o) under the shared-predictor scheme,
      // so we hand eta directly to dbinom_robust for numerical stability.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      nll -= dbinom_robust(x_pres, Type(1.0), eta(o), true);
      if (y(o) > Type(0)) {
        Type sigma_t = exp(log_sigma_lognormal_delta(t));
        // log y ~ Normal(eta, sigma_t); add Jacobian -log y so the density
        // is for Y rather than log Y.
        nll -= dnorm(log(y(o)), eta(o), sigma_t, true) - log(y(o));
      }
    } else if (fid == 13) {
      // delta_gamma (hurdle): same shared-eta logic.
      //   Positive: y | y>0 ~ Gamma(shape = 1/phi^2, scale = mu * phi^2)
      //     so E(y) = mu = exp(eta), CV(y) = phi.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      nll -= dbinom_robust(x_pres, Type(1.0), eta(o), true);
      if (y(o) > Type(0)) {
        Type phi_t   = exp(log_phi_gamma_delta(t));
        Type mu_g    = exp(eta(o));
        Type shape_g = Type(1.0) / (phi_t * phi_t);
        Type scale_g = mu_g / shape_g;
        nll -= dgamma(y(o), shape_g, scale_g, true);
      }
    } else if (fid == 14) {
      // ordinal_probit (Wright/Falconer/Hadfield threshold model).
      //   y* = eta + e,  e ~ N(0, 1)   (link-residual variance = 1)
      //   y = k iff tau_{k-1} < y* <= tau_k
      //   tau_0 = -Inf, tau_1 = 0, tau_K = +Inf
      //   Free params: tau_2, ..., tau_{K-1}  (K - 2 cutpoints)
      // P(y = k | eta) = pnorm(tau_k - eta) - pnorm(tau_{k-1} - eta)
      // Reference: Hadfield (2015) MEE 6:706-714, eqn 9. K = 2 reduces to
      // binomial(probit) (eqn 10). y is 1-indexed (1, 2, ..., K).
      int t       = trait_id(o);
      int K_minus_2 = n_ordinal_cuts_per_trait(t);   // = K_t - 2
      int offset  = ordinal_offset_per_trait(t);
      int K       = K_minus_2 + 2;                   // number of categories
      // Reconstruct cutpoints tau_1 = 0, tau_2, ..., tau_{K-1} from log-
      // increments. cuts has length K-1 (excluding tau_0 = -Inf, tau_K = +Inf).
      vector<Type> cuts(K - 1);
      cuts(0) = Type(0.0);   // tau_1 fixed at 0 for identifiability
      for (int j = 1; j < K - 1; j++) {
        cuts(j) = cuts(j - 1) + exp(ordinal_log_increments(offset + j - 1));
      }
      int yk = CppAD::Integer(y(o));   // observed category, 1..K
      // Compute P(y = yk) = Phi(upper - eta) - Phi(lower - eta).
      Type upper_p, lower_p;
      if (yk >= K) {
        upper_p = Type(1.0);
      } else {
        upper_p = pnorm(cuts(yk - 1) - eta(o));
      }
      if (yk <= 1) {
        lower_p = Type(0.0);
      } else {
        lower_p = pnorm(cuts(yk - 2) - eta(o));
      }
      Type p_k = upper_p - lower_p;
      Type tiny_p = Type(1e-12);
      p_k = (p_k < tiny_p) ? tiny_p : p_k;
      nll -= log(p_k);
    } else {
      error("gllvmTMB_multi: unknown family_id");
    }
    // Apply the per-row weight: scale this row's NLL contribution by
    // weights_i(o). Unit weight is a no-op; weight 0 zeroes the row's
    // contribution (cross-validation hold-out semantics).
    Type row_nll = nll - nll_before_row;
    nll = nll_before_row + row_nll * weights_i(o);
  }

  ADREPORT(b_fix);
  REPORT(eta);

  // Per-trait dispersion / power for NB2 and Tweedie. These are reported
  // unconditionally; the R side only reads them when the corresponding
  // family is in use (and TMB's `map` zeroes their gradient otherwise).
  vector<Type> phi_nbinom2 = exp(log_phi_nbinom2);
  vector<Type> phi_tweedie = exp(log_phi_tweedie);
  vector<Type> p_tweedie(logit_p_tweedie.size());
  for (int i = 0; i < logit_p_tweedie.size(); i++) {
    p_tweedie(i) = Type(1.0) + invlogit(logit_p_tweedie(i));
  }
  vector<Type> phi_beta = exp(log_phi_beta);
  vector<Type> phi_betabinom = exp(log_phi_betabinom);
  REPORT(phi_nbinom2);
  REPORT(phi_tweedie);
  REPORT(p_tweedie);
  REPORT(phi_beta);
  REPORT(phi_betabinom);

  // Student-t per-trait sigma and df (df = 1 + exp(log_df_student)).
  vector<Type> sigma_student = exp(log_sigma_student);
  vector<Type> df_student(log_df_student.size());
  for (int i = 0; i < log_df_student.size(); i++) {
    df_student(i) = Type(1.0) + exp(log_df_student(i));
  }
  REPORT(sigma_student);
  REPORT(df_student);

  // truncated NB2 per-trait phi.
  vector<Type> phi_truncnb2 = exp(log_phi_truncnb2);
  REPORT(phi_truncnb2);

  // Delta-family per-trait dispersion (positive component only).
  vector<Type> sigma_lognormal_delta = exp(log_sigma_lognormal_delta);
  vector<Type> phi_gamma_delta       = exp(log_phi_gamma_delta);
  REPORT(sigma_lognormal_delta);
  REPORT(phi_gamma_delta);

  // ordinal_probit cutpoints, reconstructed from log-increments and packed
  // back into a flat vector in the same layout as ordinal_log_increments.
  // The R side splits these by trait via ordinal_offset_per_trait. Each
  // trait's segment holds {tau_2, ..., tau_{K-1}} (length K_t - 2).
  vector<Type> ordinal_cutpoints(ordinal_log_increments.size());
  ordinal_cutpoints.setZero();   // initialise so TMB doesn't see undefined memory
  for (int t = 0; t < n_traits; t++) {
    int K_minus_2 = n_ordinal_cuts_per_trait(t);
    if (K_minus_2 == 0) continue;
    int offset = ordinal_offset_per_trait(t);
    Type running = Type(0.0);   // tau_1 = 0
    for (int j = 0; j < K_minus_2; j++) {
      running += exp(ordinal_log_increments(offset + j));
      ordinal_cutpoints(offset + j) = running;
    }
  }
  REPORT(ordinal_cutpoints);
  ADREPORT(ordinal_cutpoints);

  return nll;
}
