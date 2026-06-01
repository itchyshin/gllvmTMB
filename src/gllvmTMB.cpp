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

// Stable log helpers for the cumulative-logit ordered missing-PREDICTOR prior
// (Phase 5b, design 68 sec.1.2). Ported verbatim from drmTMB src/drm_numeric.h
// (drm_log_inv_logit / drm_log1m_inv_logit / drm_log1mexp / drm_log_inv_logit_
// diff) so the finite-state SUM math is byte-identical across packages (the
// cross-package contract, design 68 sec.7.5). gllvmTMB already has logspace_add
// but lacks the named log_inv_logit helpers.
template <class Type>
Type gll_log_inv_logit(Type eta)
{
  // log F(eta) = log( 1 / (1 + exp(-eta)) ) = -log(1 + exp(-eta)).
  return -logspace_add(Type(0.0), -eta);
}

template <class Type>
Type gll_log1m_inv_logit(Type eta)
{
  // log(1 - F(eta)) = -log(1 + exp(eta)).
  return -logspace_add(Type(0.0), eta);
}

template <class Type>
Type gll_log1mexp(Type log_p)
{
  // log(1 - exp(log_p)) for log_p <= 0, with a small-argument series guard
  // (drm_log1mexp). u = -log_p >= 0; for tiny u use the Taylor series.
  Type u = -log_p;
  Type series_arg = u - u * u / Type(2.0) + u * u * u / Type(6.0);
  Type series = log(series_arg);
  Type direct = log(Type(1.0) - exp(log_p));
  return CppAD::CondExpLt(u, Type(1e-6), series, direct);
}

template <class Type>
Type gll_log_inv_logit_diff(Type upper, Type lower)
{
  // log( F(upper) - F(lower) ) for upper > lower, stable form (drm_log_inv_
  // logit_diff): the log of the cumulative-logit cell probability of a middle
  // ordered category.
  return upper + gll_log1mexp(lower - upper) -
    logspace_add(Type(0.0), upper) -
    logspace_add(Type(0.0), lower);
}

template <class Type>
Type objective_function<Type>::operator()()
{
  using namespace density;

  // -------- DATA --------------------------------------------------------
  DATA_VECTOR(y);                  // long-format response (n_obs)
  DATA_IVECTOR(is_y_observed);     // 1 = response observed, 0 = missing (n_obs).
                                   // Phase 1 response mask: rows with 0 add
                                   // nothing to the likelihood and their y entry
                                   // is a safe sentinel (filled on the R side).
                                   // All-ones under miss_control(response="drop")
                                   // -> an exact no-op.
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

  // cluster2: a SECOND independent diagonal grouping (a renamed copy of
  // the diag_species block). Lets a user fit two crossed/nested plain
  // diagonal per-trait variance components at once. Family-agnostic: the
  // contribution is added to eta before family dispatch.
  DATA_IVECTOR(cluster2_id);       // 0-indexed cluster2 grouping per row
  DATA_INTEGER(n_cluster2);
  DATA_INTEGER(use_diag_cluster2);

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
  (void)n_mesh;                    // retained in the data contract for mesh sanity checks in R
  DATA_SPARSE_MATRIX(A_proj);      // n_obs x n_mesh
  DATA_SPARSE_MATRIX(spde_M0);     // n_mesh x n_mesh
  DATA_SPARSE_MATRIX(spde_M1);
  DATA_SPARSE_MATRIX(spde_M2);

  // BASE augmented SPDE slope (spatial_unique 1 + x | coords).
  // Dormant unless use_spde_slope == 1. A SECOND SPDE field on the
  // covariate x is added on the SAME mesh / SAME Q_base (same kappa)
  // as the intercept field; the two node-level fields
  // (omega_alpha, omega_beta) share a 2x2 cross-field covariance
  // Sigma_field, giving the matrix-normal prior
  //   vec(Omega) ~ N(0, Sigma_field (x) Q^{-1}),   Omega = [omega_a | omega_b].
  // eta(o) += (A_proj omega_a)(o) + x(o) * (A_proj omega_b)(o)
  //         = sum_j (A_proj omega_j)(o) * Z_spde_aug(o, j).
  // Sigma_field absorbs the field marginal variances (no separate tau),
  // mirroring how spde_lv absorbs scale into Lambda_spde.
  DATA_INTEGER(use_spde_slope);    // 0 = dormant (default); 1 = base augmented SPDE slope
  DATA_INTEGER(n_lhs_cols_spde);   // block-local LHS columns: 1 (slope-only) or 2 (intercept + slope);
                                   // C = 2*n_traits on the spatial_dep slope path
  DATA_ARRAY(Z_spde_aug);          // n_obs x n_lhs_cols_spde (col 0 = 1's; col 1 = x covariate);
                                   // INTERLEAVED (alpha_t0, beta_t0, alpha_t1, ...) on the dep path

  // spatial_dep slope flag (Design 64 sec.2). When 1, the augmented SPDE prior
  // uses the full unstructured C x C Sigma_field = L L^T (C = 2*n_traits) built
  // from theta_spde_dep_chol, replacing the closed-form 1x1 / 2x2 Sigma_field of
  // the base. This is the spatial analogue of use_phylo_dep_slope with A_phy
  // swapped for the SPDE field covariance Q_base^{-1}. Default 0 keeps the
  // base unique/indep SPDE-slope paths byte-identical.
  DATA_INTEGER(use_spde_dep_slope);

  // spatial_latent slope (Design 64 sec.3): spatial_latent(1 + x | coords, d).
  // Block-diagonal reduced-rank random regression on the SPDE field. For each
  // LHS column k in {0 = intercept, 1 = slope} an INDEPENDENT rank-d_spde_slope
  // factor structure Sigma_k = Lambda_k Lambda_k^T (n_traits x n_traits), with
  // d_spde_slope shared spatial fields g_spde_slope[ , f, k] ~ N(0, Q_base^{-1})
  // i.i.d. across f and k. No intercept-slope correlation (block-diagonal). This
  // is the spatial analogue of use_phylo_latent_slope with the species-indexed
  // score g_phy_slope replaced by the A_proj-projected mesh field. When
  // use_spde_latent_slope == 0 the parameters below are mapped off on the R side.
  DATA_INTEGER(use_spde_latent_slope);
  DATA_INTEGER(d_spde_slope);      // rank K of each per-column FA decomposition
  DATA_INTEGER(n_lhs_cols_spde_lat);  // LHS columns for the latent-slope block (1 or 2)
  DATA_MATRIX(Z_spde_lat);         // n_obs x n_lhs_cols_spde_lat (col 0 = 1's; col 1 = x)

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
  //  15 = NB1 negative binomial type-1 (log link; Var = mu*(1+phi), linear
  //                        in the mean; per-trait phi via log_phi_nbinom1)
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
  // Augmented-LHS random-regression path (live). The default R-side flag is
  // 0, so the legacy b_phy_slope path above remains active and byte-identical
  // for non-augmented fits; the parser/R design-matrix routes set it to 1.
  DATA_INTEGER(use_phylo_slope_correlated);
  DATA_INTEGER(n_lhs_cols);           // block-local LHS columns: 1 or 2 (unique/indep);
                                      // C = 2*n_traits for the phylo_dep slope path
  DATA_ARRAY(Z_phy_aug);              // n_obs x n_lhs_cols x n_phy_aug_blocks
  // phylo_dep slope flag (Stage 3, Design 56 sec.9.5c). When 1, the
  // augmented prior below uses the full unstructured C x C Sigma_b built
  // from theta_dep_chol instead of the closed-form 1x1 / 2x2 covariance.
  // Default 0 keeps the unique/indep/legacy paths byte-identical.
  DATA_INTEGER(use_phylo_dep_slope);

  // phylo_latent random slope (Design 56 Sec. 5.3 latent row; Sec. 9.5a):
  //   phylo_latent(1 + x | sp, d = K) -- reduced-rank, BLOCK-DIAGONAL across
  //   the LHS columns. Each LHS column k in {0 = intercept, 1 = slope} gets
  //   its OWN factor-analytic decomposition Sigma_k = Lambda_k Lambda_k^T
  //   (n_traits x n_traits, rank d_phy_slope), with K latent factor-score
  //   columns g_phy_slope[ , f, k] ~ N(0, A_phy) i.i.d. across f and k. There
  //   is NO intercept-slope correlation (block-diagonal == cross-column
  //   covariance blocks are zero), which is the Sec. 5.3 latent semantics, in
  //   contrast to the full 2x2 / unstructured b_phy_aug (dep/unique) path.
  //
  //   eta(o) += sum_{k} Z_phy_lat(o, k)
  //               * sum_{f} Lambda_phy_slope(t(o), f, k) * g_phy_slope(sp(o), f, k)
  //
  //   This is the existing phylo_rr eta term replicated per LHS column, with
  //   an independent loading matrix per column and the column design value
  //   Z_phy_lat (column 0 = 1's; column 1 = x covariate). Reuses
  //   Ainv_phy_rr / n_aug_phy / log_det_A_phy_rr / species_aug_id from the
  //   phylo_rr machinery (same tree / VCV). When use_phylo_latent_slope == 0
  //   the parameters below are mapped off on the R side and this block is
  //   inert. References: Hadfield & Nakagawa (2010) JEB 23:494-508 (the A
  //   prior); the random-regression / reaction-norm decomposition (Design 56
  //   Sec. 5.1) restricted to the block-diagonal (uncorrelated) case.
  DATA_INTEGER(use_phylo_latent_slope);
  DATA_INTEGER(d_phy_slope);          // rank K of each per-column FA decomposition
  DATA_INTEGER(n_lhs_cols_lat);       // LHS columns for the latent-slope block (1 or 2)
  DATA_MATRIX(Z_phy_lat);             // n_obs x n_lhs_cols_lat (col 0 = 1's; col 1 = x)

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

  // -------- Missing-PREDICTOR layer (Phase 2a/2b/2c, design 67) ----------
  // One continuous Gaussian missing predictor declared with mi(x). The missing
  // x lives at a LATENT level -- the wide-row unit (Phase 2a/2b) or, when the
  // covariate model carries a mi_group(g) marker, a coarser/cross-cutting group
  // g (Phase 2c, design 67 sec.2.1 / 69 sec.4.1). x is broadcast across that
  // level's long rows, so the latent x_mis has ONE entry per missing LEVEL
  // value (not per long row), and the Gaussian covariate density is evaluated
  // at the LATENT level. The long-row -> level map `mi_unit_id` broadcasts
  // x_full(u) to every long row. The block is level-agnostic: n_units below is
  // the number of latent-level values (units or groups). has_mi == 0 -> every
  // block below is gated off (exact no-op).
  DATA_INTEGER(has_mi);            // 1 = a Gaussian mi() predictor is present
  DATA_INTEGER(mi_family);         // 0 = Gaussian (only family in Phase 2a)
  DATA_INTEGER(mi_col);            // 0-indexed column of X_fix for the mi() x
  DATA_VECTOR(mi_x_unit);          // length n_units (latent levels); observed x,
                                   // sentinel where missing (x_mis overrides)
  DATA_IVECTOR(mi_observed_unit);  // length n_units; 1 = x observed for a level
  DATA_IVECTOR(mi_missing_index);  // 0-indexed positions of missing levels
  DATA_IVECTOR(mi_unit_id);        // length n_obs; long-row -> level (0-indexed)
  DATA_MATRIX(X_mi);               // level covariate design (n_units x p_x)
  // Phase 2b: ONE grouped random intercept on the covariate model, at the
  // LATENT level. has_mi_group == 0 -> the group block is an exact no-op.
  DATA_INTEGER(has_mi_group);      // 1 = the covariate model has (1 | group)
  DATA_IVECTOR(mi_group_index);    // length n_units; level -> RE group (0-idx)
  // Phase 3 (design 69): a PHYLOGENETIC structured intercept on the covariate
  // model. The covariate latent level is SPECIES, so the field g_x ~ N(0, A)
  // is evaluated through the SAME sparse precision Ainv_phy_rr / log_det_A_phy_rr
  // / n_aug_phy the response phylo block uses (no new precision). mi_species_
  // node_id maps each latent species (the covariate-model rows, length n_units)
  // to its augmented-A node row in g_x. has_mi_phylo == 0 -> the g_x block is an
  // exact no-op and Ainv_phy_rr is referenced but unused by this block.
  DATA_INTEGER(has_mi_phylo);          // 1 = the covariate model has phylo(1|species)
  DATA_IVECTOR(mi_species_node_id);    // length n_units; species -> aug node (0-idx)
  // Phase 5b (design 68 sec.1.2 / sec.4): ORDERED discrete predictor via the
  // cumulative-logit K-state SUM (mi_family == 2). mi_n_state = K (number of
  // ordered categories). X_fix_state is the long-and-stacked state-design
  // matrix (the gllvmTMB analogue of drmTMB X_mi_state_mu) FILTERED to the long
  // rows of missing units: for a missing-unit long row o it holds K stacked
  // rows -- the FULL fixed-effect design of row o with the mi() ordered
  // predictor forced to category k (k = 0..K-1), state as the FAST index. The
  // base row of o's K-block is mi_state_row(o); state k is row mi_state_row(o)
  // + k. mi_state_row(o) = -1 for observed-unit rows (no state block). When
  // mi_family != 2 these are 1x1 / length-1 stubs and the whole block is an
  // exact no-op.
  DATA_INTEGER(mi_n_state);            // K = number of ordered categories
  DATA_MATRIX(X_fix_state);            // (sum_{missing u} |rows(u)| * K) x p
  DATA_IVECTOR(mi_state_row);          // length n_obs; 0-idx K-block base or -1

  // -------- PARAMETERS --------------------------------------------------
  PARAMETER_VECTOR(b_fix);                       // fixed-effects coefficients (p)
  PARAMETER(log_sigma_eps);                      // residual log-SD

  // Missing-predictor (Phase 2a): Gaussian covariate-model coefficients,
  // log residual SD, and the latent missing UNIT-level x values (random).
  PARAMETER_VECTOR(beta_mi);                     // covariate-model coefs (p_x)
  PARAMETER_VECTOR(log_sigma_mi);                // length 1; log sigma_x
  PARAMETER_VECTOR(x_mis);                       // latent missing UNIT x values
  // Phase 2b grouped covariate random intercept: standardized unit-level group
  // effects u_mi_group ~ N(0, 1) (joins `random`) scaled by sd_mi_group.
  PARAMETER_VECTOR(u_mi_group);                  // length n_group; N(0,1)
  PARAMETER_VECTOR(log_sd_mi_group);             // length 1; log group SD
  // Phase 3 phylogenetic covariate field (design 69): STANDARDIZED unit-variance
  // field g_x ~ N(0, A) over the augmented A nodes (joins `random`), scaled by
  // sd_x when it enters the covariate mean. log_sd_x is its log phylogenetic SD.
  // Parallels g_phy_diag / log_sd_phy_diag (the response per-trait phylo
  // intercept). Mapped off (length 1) when no phylo() covariate term is present.
  PARAMETER_VECTOR(g_x);                         // length n_aug_phy (or 1 if unused)
  PARAMETER_VECTOR(log_sd_x);                    // length 1; log phylo SD of x
  // Phase 5b (design 68 sec.1.2): the ORDERED predictor cutpoints, K-1 FREE,
  // parametrised as theta_ord = (free base c_1, log-increments...). The cutpoint
  // reconstruction is c_1 = theta_ord(0); c_j = c_{j-1} + exp(theta_ord(j)) for
  // j = 1..K-2. This MIRRORS drmTMB (K-1 free) and is DISTINCT from gllvmTMB's
  // fid-14 ordinal_probit RESPONSE convention (tau_1 = 0, K-2 free): the
  // cumulative-logit PREDICTOR has no separate response intercept, so the first
  // cutpoint stays free. Length 0 (mapped off) when mi_family != 2.
  PARAMETER_VECTOR(theta_ord);                   // length K-1 (ordered) or 0

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

  // cluster2 diagonal term: diag(0 + trait | cluster2) -- renamed copy of
  // the diag_species block on a second independent grouping.
  PARAMETER_VECTOR(theta_diag_cluster2);         // length n_traits
  PARAMETER_MATRIX(r_c2);                        // n_traits x n_cluster2

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

  // BASE augmented SPDE slope: the (intercept, slope) spatial field and its
  // 2x2 cross-field covariance Sigma_field. Dormant unless use_spde_slope==1.
  // Same scalable-name scheme as the phylo augmented block (log_sd_b /
  // atanh_cor_b): Sigma_field is built from log_sd_spde_b + atanh_cor_spde_b.
  PARAMETER_ARRAY(omega_spde_aug);               // n_mesh x n_lhs_cols_spde (col 0 = alpha; col 1 = beta;
                                                 // C = 2T interleaved fields on the dep path)
  PARAMETER_VECTOR(log_sd_spde_b);               // length n_lhs_cols_spde (mapped off on the dep path)
  PARAMETER_VECTOR(atanh_cor_spde_b);            // length n_lhs_cols_spde*(n_lhs_cols_spde-1)/2 (off on dep)
  // spatial_dep slope (Design 64 sec.2): full unstructured C x C field
  // covariance Sigma_field = L L^T over the C = 2T interleaved (intercept,
  // slope) spatial fields. theta_spde_dep_chol packs the free lower-triangular
  // Cholesky factor L as the C log-diagonal entries (C++ exp-transforms them)
  // followed by the strictly-lower entries column-major; length C(C+1)/2. Empty
  // (and mapped off) for the base unique / indep SPDE-slope paths (C in {1,2}),
  // so those fits are byte-identical. Same packing as theta_dep_chol.
  PARAMETER_VECTOR(theta_spde_dep_chol);         // length C(C+1)/2 when use_spde_dep_slope; else 0
  // spatial_latent slope (Design 64 sec.3): per-column reduced-rank loadings +
  // shared spatial fields. theta_rr_spde_slope packs n_lhs_cols_spde_lat
  // lower-triangular Lambda_k blocks back-to-back (each length
  // n_traits*d_spde_slope - d_spde_slope*(d_spde_slope-1)/2, same rr() layout as
  // theta_rr_phy_slope). g_spde_slope holds the shared spatial field scores on
  // the mesh. Mapped off on the R side when use_spde_latent_slope == 0.
  PARAMETER_VECTOR(theta_rr_spde_slope);         // n_lhs_cols_spde_lat packed Lambda_k blocks
  PARAMETER_ARRAY(g_spde_slope);                 // n_mesh x d_spde_slope x n_lhs_cols_spde_lat

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
  PARAMETER_ARRAY(b_phy_aug);                     // n_aug_phy x n_lhs_cols x n_phy_aug_blocks
  PARAMETER_VECTOR(log_sd_b);                     // length n_lhs_cols
  PARAMETER_VECTOR(atanh_cor_b);                  // n_lhs_cols * (n_lhs_cols - 1) / 2
  // phylo_latent slope (Design 56 Sec. 5.3 / 9.5a). theta_rr_phy_slope packs
  // n_lhs_cols_lat lower-triangular Lambda_k blocks back-to-back, each of
  // length n_traits*d_phy_slope - d_phy_slope*(d_phy_slope-1)/2 (same packed
  // layout as theta_rr_phy). g_phy_slope holds the per-column latent factor
  // scores. Mapped off on the R side when use_phylo_latent_slope == 0.
  PARAMETER_VECTOR(theta_rr_phy_slope);           // n_lhs_cols_lat packed Lambda_k blocks
  PARAMETER_ARRAY(g_phy_slope);                   // n_aug_phy x d_phy_slope x n_lhs_cols_lat
  // phylo_dep slope (Stage 3, Design 56 sec.9.5c): full unstructured
  // C x C covariance Sigma_b = L L^T over the C = 2T trait-stacked
  // (intercept, slope) random-effect columns. theta_dep_chol packs the
  // free lower-triangular Cholesky factor L column-major below the
  // diagonal plus the C log-diagonal entries; length C(C+1)/2. Empty
  // (and mapped off) for the legacy / unique / indep paths (C in {1,2}),
  // so those fits are byte-identical. See Sigma_b construction below.
  PARAMETER_VECTOR(theta_dep_chol);               // length C(C+1)/2 when use_phylo_dep_slope; else 0

  // Generic random intercepts: flat vector across all (1|g) terms.
  PARAMETER_VECTOR(u_re_int);                    // length sum(re_int_n_groups) (or 1 if unused)
  PARAMETER_VECTOR(log_sigma_re_int);            // length n_re_int_terms (or 1 if unused)

  // NB2 / NB1 / Tweedie dispersion parameters (per trait). Mapped off when the
  // corresponding family is not in family_id_vec; otherwise one log-phi
  // (NB2 / NB1) and one log-phi + logit-p (Tweedie) per trait is estimated.
  // NB2 variance: var = mu + mu^2 / phi (so phi -> infinity recovers Poisson).
  // NB1 variance: var = mu * (1 + phi) = mu + phi * mu (linear in the mean;
  //               phi -> 0 recovers Poisson). Reference: Hilbe (2011) Negative
  //               Binomial Regression, 2nd ed.
  // Tweedie:      var = phi * mu^p with 1 < p < 2 (compound Poisson-Gamma).
  PARAMETER_VECTOR(log_phi_nbinom2);             // length n_traits (or 1 if unused)
  PARAMETER_VECTOR(log_phi_nbinom1);             // length n_traits (or 1 if unused)
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

  // -------- Missing-PREDICTOR block (Phase 2a, mi_family == 0) ----------
  // Direct analogue of drmTMB src/drmTMB.cpp mi_family == 0, with the design
  // 67 sec.2.0-2.1 unit broadcast: reconstruct x_full per UNIT (observed x, or
  // the latent x_mis for missing units); add the unit-level Gaussian covariate
  // density; delta-correct each long row's eta by swapping the broadcast mi()
  // column's contribution for the reconstructed value. For a singleton-unit
  // model `mi_unit_id` is the identity and this collapses to the per-row
  // drmTMB form -- the cross-package contract.
  if (has_mi == 1 && mi_family == 0) {
    int n_units = mi_x_unit.size();
    // Per-unit covariate mean eta_x = X_mi * beta_mi.
    vector<Type> mi_eta_x = X_mi * beta_mi;
    Type sigma_mi = exp(log_sigma_mi(0));
    // Phase 2b: add the UNIT-level grouped random intercept to eta_x. Direct
    // analogue of drmTMB src/drmTMB.cpp has_mi_group (mi_eta(i) += sd *
    // u(group(i))), evaluated at the unit level here. u_mi_group ~ N(0, 1).
    Type sd_mi_group = Type(0.0);
    if (has_mi_group == 1) {
      sd_mi_group = exp(log_sd_mi_group(0));
      for (int u = 0; u < n_units; ++u) {
        mi_eta_x(u) += sd_mi_group * u_mi_group(mi_group_index(u));
      }
      for (int g = 0; g < u_mi_group.size(); ++g) {
        nll -= dnorm(u_mi_group(g), Type(0.0), Type(1.0), true);
      }
    }
    // Phase 3 (design 69): the PHYLOGENETIC structured intercept on the
    // covariate mean. STANDARDIZED-field convention (Q1), mirroring the
    // response phylo_diag block (:771-776): the field g_x ~ N(0, A) is drawn
    // with a UNIT-variance GMRF penalty through the SAME sparse Ainv_phy_rr
    // (no new precision), then scaled by sd_x = exp(log_sd_x) as it enters the
    // per-species covariate mean:
    //   eta_x(u) += sd_x * g_x(mi_species_node_id(u))
    //   -log p(g_x) = 0.5 * (n_aug_phy*log(2pi) + log_det_A_phy_rr + g_x' Ainv g_x)
    // This is equivalent to a per-species phylogenetic intercept u_x ~ N(0,
    // sd_x^2 A). It is the covariate's OWN field (its OWN sd_x), SEPARATE from
    // any response phylo field -- they may reuse Ainv_phy_rr but are distinct
    // latents (Level-1 independent; the joint field is deferred to Phase 4).
    // The residual sigma_mi (sigma_x) stays -- the Pagel partition (Q2): as
    // sd_x -> 0 the field flattens and the covariate model degrades to the
    // independent Phase-2c model with no separate code path.
    Type sd_x = Type(0.0);
    if (has_mi_phylo == 1) {
      sd_x = exp(log_sd_x(0));
      for (int u = 0; u < n_units; ++u) {
        mi_eta_x(u) += sd_x * g_x(mi_species_node_id(u));
      }
      Type quad_x = (g_x.matrix().transpose() * Ainv_phy_rr * g_x.matrix())(0, 0);
      nll += 0.5 * (Type(n_aug_phy) * log(2.0 * M_PI)
                    + log_det_A_phy_rr + quad_x);
    }
    // Reconstruct x_full(u): observed value, else the latent x_mis entry.
    vector<Type> mi_x_full(n_units);
    for (int u = 0; u < n_units; ++u) mi_x_full(u) = mi_x_unit(u);
    for (int j = 0; j < mi_missing_index.size(); ++j) {
      mi_x_full(mi_missing_index(j)) = x_mis(j);
    }
    // Covariate density, summed over UNITS (NOT long rows).
    for (int u = 0; u < n_units; ++u) {
      nll -= dnorm(mi_x_full(u), mi_eta_x(u), sigma_mi, true);
    }
    // Delta-correct each long row: replace the broadcast mi() column's
    // contribution X_fix(o, mi_col) * b_fix(mi_col) with the reconstructed
    // x_full(mi_unit_id(o)) * b_fix(mi_col).
    for (int o = 0; o < y.size(); ++o) {
      eta(o) += b_fix(mi_col) * (mi_x_full(mi_unit_id(o)) - X_fix(o, mi_col));
    }
    REPORT(mi_x_full);
    REPORT(beta_mi);
    REPORT(log_sigma_mi);
    REPORT(sigma_mi);
    REPORT(x_mis);
    if (has_mi_group == 1) {
      REPORT(u_mi_group);
      REPORT(log_sd_mi_group);
      REPORT(sd_mi_group);
      ADREPORT(log_sd_mi_group);
      ADREPORT(sd_mi_group);
    }
    // Phase 3: EBLUP field + the phylogenetic SD of the covariate.
    if (has_mi_phylo == 1) {
      REPORT(g_x);
      REPORT(log_sd_x);
      REPORT(sd_x);
      ADREPORT(log_sd_x);
      ADREPORT(sd_x);
    }
    ADREPORT(beta_mi);
    ADREPORT(log_sigma_mi);
    ADREPORT(sigma_mi);
  }

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
  // -log p = 0.5 * (n_species*log(2*pi) + n_species*loglambda_phy + log_det_Cphy
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

  // -------- diag(0 + trait | cluster2) -- 2nd-grouping per-trait var ----
  // Renamed copy of the diag_species block on the cluster2 grouping.
  if (use_diag_cluster2 == 1) {
    if (theta_diag_cluster2.size() != n_traits)
      error("gllvmTMB_multi: theta_diag_cluster2 has wrong length");
    vector<Type> sd_c2 = exp(theta_diag_cluster2);
    REPORT(sd_c2);
    for (int i = 0; i < n_cluster2; i++) {
      for (int t = 0; t < n_traits; t++)
        nll -= dnorm(r_c2(t, i), Type(0), sd_c2(t), true);
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
  // Legacy path: b_phy_slope ~ N(0, sigma_slope^2 * A_phy), evaluated
  // through the sparse Ainv. The augmented path below is live (parser
  // activation has landed); keeping this branch active preserves current
  // phylo_slope() fits and parameter names byte-for-byte.
  // -log p(b) = 0.5 * (n_aug_phy * log(2pi) + 2 n_aug_phy log_sigma_slope
  //                    + log_det_A_phy_rr
  //                    + b' Ainv b / sigma_slope^2)
  if (use_phylo_slope == 1 && use_phylo_slope_correlated == 0) {
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
  // Augmented path (live): vec(B) ~ N(0, Sigma_b \otimes A_phy), where
  // Sigma_b is block-local across LHS columns (1 = legacy slope-only;
  // 2 = intercept + slope). Driven by the phylo_unique / phylo_indep /
  // phylo_dep parser routes.
  if (use_phylo_slope_correlated == 1) {
    // Closed-form covariance paths (unique / indep / legacy) require
    // n_lhs_cols in {1, 2}. The phylo_dep slope path (use_phylo_dep_slope
    // == 1) lifts this cap: there C = 2*n_traits and Sigma_b is the full
    // unstructured C x C built from theta_dep_chol.
    if (use_phylo_dep_slope == 0 && (n_lhs_cols < 1 || n_lhs_cols > 2))
      error("gllvmTMB_multi: n_lhs_cols must be 1 or 2 in the closed-form augmented path");
    if (use_phylo_dep_slope == 1 && n_lhs_cols < 1)
      error("gllvmTMB_multi: n_lhs_cols must be >= 1 in the phylo_dep slope path");
    if (b_phy_aug.dim.size() != 3 || Z_phy_aug.dim.size() != 3)
      error("gllvmTMB_multi: b_phy_aug and Z_phy_aug must be 3D arrays");
    if (b_phy_aug.dim[0] != n_aug_phy)
      error("gllvmTMB_multi: b_phy_aug first dimension must equal n_aug_phy");
    if (b_phy_aug.dim[1] != n_lhs_cols || Z_phy_aug.dim[1] != n_lhs_cols)
      error("gllvmTMB_multi: n_lhs_cols does not match augmented phylo arrays");
    if (Z_phy_aug.dim[0] != y.size())
      error("gllvmTMB_multi: Z_phy_aug first dimension must equal n_obs");
    if (Z_phy_aug.dim[2] != b_phy_aug.dim[2])
      error("gllvmTMB_multi: Z_phy_aug and b_phy_aug block counts differ");

    if (use_phylo_dep_slope == 1) {
      // ---- phylo_dep slope: full unstructured C x C Sigma_b = L L^T -----
      // theta_dep_chol packs L (C x C lower-triangular) as: the C diagonal
      // entries are exp(theta_dep_chol[j]) (strictly positive, identified);
      // the strictly-lower entries follow in column-major order. Hence
      // Sigma_b = L L^T is symmetric positive-definite by construction --
      // the natural unrestricted parameterisation of an unstructured
      // covariance (Pinheiro & Bates 1996). Length C(C+1)/2.
      int C = n_lhs_cols;
      int n_chol = C * (C + 1) / 2;
      if (theta_dep_chol.size() != n_chol)
        error("gllvmTMB_multi: theta_dep_chol has wrong length for phylo_dep slope");
      matrix<Type> Lb(C, C);
      Lb.setZero();
      {
        int idx = 0;
        // Diagonal first (exp-transformed for positivity / identifiability).
        for (int j = 0; j < C; j++) {
          Lb(j, j) = exp(theta_dep_chol(idx));
          idx++;
        }
        // Strictly-lower entries, column-major (j = col, i = row > j).
        for (int j = 0; j < C; j++) {
          for (int i = j + 1; i < C; i++) {
            Lb(i, j) = theta_dep_chol(idx);
            idx++;
          }
        }
      }
      matrix<Type> Sigma_b_dep = Lb * Lb.transpose();
      matrix<Type> Sigma_b_inv = atomic::matinv(Sigma_b_dep);
      // log det Sigma_b = 2 * sum_j log L_jj.
      Type logdet_Sigma_b = Type(0);
      for (int j = 0; j < C; j++) logdet_Sigma_b += Type(2) * log(Lb(j, j));
      // Report the recovered SDs and correlation matrix for extractors/tests.
      vector<Type> sd_b(C);
      for (int j = 0; j < C; j++) sd_b(j) = sqrt(Sigma_b_dep(j, j));
      REPORT(sd_b);
      matrix<Type> cor_b_mat(C, C);
      for (int a = 0; a < C; a++)
        for (int bcol = 0; bcol < C; bcol++)
          cor_b_mat(a, bcol) = Sigma_b_dep(a, bcol) / (sd_b(a) * sd_b(bcol));
      REPORT(cor_b_mat);
      REPORT(Sigma_b_dep);
      // -log p(vec(B)) = 0.5 [ n*C*log(2pi) + n*logdet(Sigma_b)
      //                        + C*logdet(A) + tr(Sigma_b^{-1} B' A^{-1} B) ].
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        // Q(j,l) = b_j' A^{-1} b_l, C x C.
        matrix<Type> Bmat(n_aug_phy, C);
        for (int j = 0; j < C; j++)
          for (int i = 0; i < n_aug_phy; i++) Bmat(i, j) = b_phy_aug(i, j, k);
        matrix<Type> AinvB = Ainv_phy_rr * Bmat;        // n_aug_phy x C
        matrix<Type> Q = Bmat.transpose() * AinvB;      // C x C
        // tr(Sigma_b^{-1} Q) = sum_{j,l} Sigma_b_inv(j,l) * Q(l,j).
        Type quad = Type(0);
        for (int j = 0; j < C; j++)
          for (int l = 0; l < C; l++)
            quad += Sigma_b_inv(j, l) * Q(l, j);
        nll += Type(0.5) * (Type(n_aug_phy * C) * log(2.0 * M_PI)
                            + Type(n_aug_phy) * logdet_Sigma_b
                            + Type(C) * log_det_A_phy_rr
                            + quad);
      }
    } else {
    if (log_sd_b.size() != n_lhs_cols)
      error("gllvmTMB_multi: log_sd_b has wrong length");
    int n_cor_b = n_lhs_cols * (n_lhs_cols - 1) / 2;
    if (atanh_cor_b.size() != n_cor_b)
      error("gllvmTMB_multi: atanh_cor_b has wrong length");

    vector<Type> sd_b(n_lhs_cols);
    for (int j = 0; j < n_lhs_cols; j++) sd_b(j) = exp(log_sd_b(j));
    REPORT(sd_b);
    if (n_lhs_cols == 1) {
      Type sd0 = sd_b(0);
      Type inv00 = Type(1) / (sd0 * sd0);
      Type logdet_Sigma_b = Type(2) * log_sd_b(0);
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        vector<Type> b0(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) b0(i) = b_phy_aug(i, 0, k);
        Type quad00 = (b0.matrix().transpose() * Ainv_phy_rr * b0.matrix())(0, 0);
        nll += Type(0.5) * (Type(n_aug_phy) * log(2.0 * M_PI)
                            + Type(n_aug_phy) * logdet_Sigma_b
                            + log_det_A_phy_rr
                            + inv00 * quad00);
      }
    } else {
      Type rho = tanh(atanh_cor_b(0));
      Type one_minus_rho2 = Type(1) - rho * rho;
      Type inv00 = Type(1) / (sd_b(0) * sd_b(0) * one_minus_rho2);
      Type inv11 = Type(1) / (sd_b(1) * sd_b(1) * one_minus_rho2);
      Type inv01 = -rho / (sd_b(0) * sd_b(1) * one_minus_rho2);
      Type logdet_Sigma_b = Type(2) * log_sd_b(0) +
                             Type(2) * log_sd_b(1) +
                             log(one_minus_rho2);
      vector<Type> cor_b(1);
      cor_b(0) = rho;
      REPORT(cor_b);
      for (int k = 0; k < b_phy_aug.dim[2]; k++) {
        vector<Type> b0(n_aug_phy);
        vector<Type> b1(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) {
          b0(i) = b_phy_aug(i, 0, k);
          b1(i) = b_phy_aug(i, 1, k);
        }
        Type quad00 = (b0.matrix().transpose() * Ainv_phy_rr * b0.matrix())(0, 0);
        Type quad01 = (b0.matrix().transpose() * Ainv_phy_rr * b1.matrix())(0, 0);
        Type quad11 = (b1.matrix().transpose() * Ainv_phy_rr * b1.matrix())(0, 0);
        Type quad = inv00 * quad00 + Type(2) * inv01 * quad01 + inv11 * quad11;
        nll += Type(0.5) * (Type(n_aug_phy * n_lhs_cols) * log(2.0 * M_PI)
                            + Type(n_aug_phy) * logdet_Sigma_b
                            + Type(n_lhs_cols) * log_det_A_phy_rr
                            + quad);
      }
    }
    }  // end closed-form (use_phylo_dep_slope == 0) branch
  }

  // -------- phylo_latent slope (Design 56 Sec. 5.3 / 9.5a) -------------
  // Block-diagonal reduced-rank random regression on the phylogeny. For each
  // LHS column k, build an independent loading matrix Lambda_k (n_traits x
  // d_phy_slope, lower-triangular rr() convention) and place an independent
  // N(0, A) prior on each of the d_phy_slope factor-score columns
  // g_phy_slope[ , f, k]. The negative log prior is the standard MVN constant
  // 0.5*(n_aug*log2pi + log|A|) plus 0.5*g' Ainv g, summed over the
  // n_lhs_cols_lat * d_phy_slope independent latent columns -- the existing
  // phylo_rr prior loop replicated across an extra LHS-column axis. There is
  // no cross-column (intercept-slope) term: the cross-column covariance
  // blocks are exactly zero (the Sec. 5.3 "block-diagonal across LHS columns"
  // semantics). Lambda_phy_slope is REPORTed per column for extraction.
  array<Type> Lambda_phy_slope(n_traits, std::max(d_phy_slope, 1),
                               std::max(n_lhs_cols_lat, 1));
  Lambda_phy_slope.setZero();
  if (use_phylo_latent_slope == 1) {
    if (n_lhs_cols_lat < 1 || n_lhs_cols_lat > 2)
      error("gllvmTMB_multi: n_lhs_cols_lat must be 1 or 2");
    if (g_phy_slope.dim.size() != 3)
      error("gllvmTMB_multi: g_phy_slope must be a 3D array");
    if (g_phy_slope.dim[0] != n_aug_phy)
      error("gllvmTMB_multi: g_phy_slope first dimension must equal n_aug_phy");
    if (g_phy_slope.dim[1] != d_phy_slope)
      error("gllvmTMB_multi: g_phy_slope second dimension must equal d_phy_slope");
    if (g_phy_slope.dim[2] != n_lhs_cols_lat)
      error("gllvmTMB_multi: g_phy_slope third dimension must equal n_lhs_cols_lat");
    if (Z_phy_lat.rows() != y.size() || Z_phy_lat.cols() != n_lhs_cols_lat)
      error("gllvmTMB_multi: Z_phy_lat must be n_obs x n_lhs_cols_lat");
    int p = n_traits;
    int rank = d_phy_slope;
    int len_per_col = p * rank - rank * (rank - 1) / 2;
    if (theta_rr_phy_slope.size() != n_lhs_cols_lat * len_per_col)
      error("gllvmTMB_multi: theta_rr_phy_slope has wrong length");
    // Build each per-column Lambda_k from its packed lower-triangular slice.
    for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
      vector<Type> theta_k =
        theta_rr_phy_slope.segment(kcol * len_per_col, len_per_col);
      vector<Type> lam_diag = theta_k.head(rank);
      vector<Type> lam_lower = theta_k.tail(len_per_col - rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < p; i++) {
          if (j > i)
            Lambda_phy_slope(i, j, kcol) = 0;
          else if (i == j)
            Lambda_phy_slope(i, j, kcol) = lam_diag(j);
          else
            Lambda_phy_slope(i, j, kcol) =
              lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
        }
      }
    }
    // Independent N(0, A) prior on every factor-score column.
    for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
      for (int f = 0; f < d_phy_slope; f++) {
        vector<Type> g_kf(n_aug_phy);
        for (int i = 0; i < n_aug_phy; i++) g_kf(i) = g_phy_slope(i, f, kcol);
        Type quad = (g_kf.matrix().transpose() * Ainv_phy_rr * g_kf.matrix())(0, 0);
        nll += Type(0.5) * (Type(n_aug_phy) * log(2.0 * M_PI)
                            + log_det_A_phy_rr + quad);
      }
    }
    REPORT(Lambda_phy_slope);
    // Per-column Sigma_k = Lambda_k Lambda_k^T for extraction / recovery.
    matrix<Type> L0(n_traits, std::max(d_phy_slope, 1));
    matrix<Type> L1(n_traits, std::max(d_phy_slope, 1));
    for (int j = 0; j < std::max(d_phy_slope, 1); j++)
      for (int i = 0; i < n_traits; i++) {
        L0(i, j) = Lambda_phy_slope(i, j, 0);
        L1(i, j) = (n_lhs_cols_lat > 1) ? Lambda_phy_slope(i, j, 1) : Type(0);
      }
    matrix<Type> Sigma_phy_slope_intercept = L0 * L0.transpose();
    matrix<Type> Sigma_phy_slope_slope = L1 * L1.transpose();
    REPORT(Sigma_phy_slope_intercept);
    REPORT(Sigma_phy_slope_slope);
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

  // -------- BASE augmented SPDE slope: vec(Omega) ~ N(0, Sigma_field (x) Q^-1)
  // Omega = [omega_alpha | omega_beta] is n_mesh x n_lhs_cols_spde, drawn on
  // the SAME mesh / Q_base (same kappa) as the intercept field. Sigma_field is
  // the 2x2 cross-field covariance, shared across traits (BASE unique case).
  //
  // The negative-log-density is computed by REUSING density::GMRF(Q_base):
  //   GMRF(Q)(x) = 0.5*( n log(2pi) - logdet(Q) + x' Q x )   [TMB convention]
  // For the 2-column matrix-normal prior with precision Sigma_field^-1 (x) Q,
  //   nll = GMRF(Q)(om0) + GMRF(Q)(om1)               // gives 2n log2pi - 2 logdetQ + q00 + q11
  //       + 0.5 * n_mesh * logdet(Sigma_field)
  //       + 0.5 * [ (Sinv00 - 1) q00 + (Sinv11 - 1) q11 + 2 Sinv01 q01 ]
  // where qij = om_i' Q om_j (sparse Q via GMRF::Quadform / Q*x). This uses
  // ONLY the sparse SPDE machinery already exercised by the per-trait path
  // above; no new atomic / sparse-solve op is introduced. Validated against a
  // dense Sigma_field (x) Q^-1 MVN density to < 1e-9 (see tests).
  if (use_spde_slope == 1) {
    // Closed-form Sigma_field paths (base unique / indep) require
    // n_lhs_cols_spde in {1, 2}. The spatial_dep slope path
    // (use_spde_dep_slope == 1) lifts this cap: there C = 2*n_traits and
    // Sigma_field is the full unstructured C x C built from theta_spde_dep_chol.
    if (use_spde_dep_slope == 0 && (n_lhs_cols_spde < 1 || n_lhs_cols_spde > 2))
      error("gllvmTMB_multi: n_lhs_cols_spde must be 1 or 2 in the base SPDE slope");
    if (use_spde_dep_slope == 1 && n_lhs_cols_spde < 1)
      error("gllvmTMB_multi: n_lhs_cols_spde must be >= 1 in the spatial_dep slope path");
    if (omega_spde_aug.dim.size() != 2)
      error("gllvmTMB_multi: omega_spde_aug must be a 2D array");
    if (omega_spde_aug.dim[1] != n_lhs_cols_spde || Z_spde_aug.dim[1] != n_lhs_cols_spde)
      error("gllvmTMB_multi: n_lhs_cols_spde does not match augmented SPDE arrays");
    if (Z_spde_aug.dim[0] != y.size())
      error("gllvmTMB_multi: Z_spde_aug first dimension must equal n_obs");

    Type kappa_s  = exp(log_kappa_spde);
    Type kappa_s2 = kappa_s * kappa_s;
    Type kappa_s4 = kappa_s2 * kappa_s2;
    Eigen::SparseMatrix<Type> Q_slope =
      kappa_s4 * spde_M0 + Type(2.0) * kappa_s2 * spde_M1 + spde_M2;
    density::GMRF_t<Type> gmrf_slope(Q_slope);

    if (use_spde_dep_slope == 1) {
      // ---- spatial_dep slope: full unstructured C x C Sigma_field = L L^T ----
      // Design 64 sec.2.2/2.3, eq (**). Build L (C x C lower-triangular) from
      // theta_spde_dep_chol: C log-diagonal entries (exp-transformed, >0 and
      // identified) then the strictly-lower entries column-major. Then the
      // matrix-normal nll vec(Omega) ~ N(0, Sigma_field (x) Q_base^{-1}) is
      //   nll = sum_j GMRF(Q_base)(omega_j)               // n*C log2pi - C logdetQ + tr(Q)
      //       + 0.5 * n_node * logdet(Sigma_field)
      //       + 0.5 * ( tr(Sinv*Q) - tr(Q) ),    Q(j,l) = omega_j' Q_base omega_l.
      // This is the phylo_dep formula (src/gllvmTMB.cpp dep block) with
      // A_phy^{-1} -> Q_base and n_aug_phy -> n_node. No new atomic / sparse op.
      int C = n_lhs_cols_spde;
      int n_chol = C * (C + 1) / 2;
      if (theta_spde_dep_chol.size() != n_chol)
        error("gllvmTMB_multi: theta_spde_dep_chol has wrong length for spatial_dep slope");
      int n_node = omega_spde_aug.dim[0];
      matrix<Type> Lf(C, C);
      Lf.setZero();
      {
        int idx = 0;
        for (int j = 0; j < C; j++) { Lf(j, j) = exp(theta_spde_dep_chol(idx)); idx++; }
        for (int j = 0; j < C; j++)
          for (int i = j + 1; i < C; i++) { Lf(i, j) = theta_spde_dep_chol(idx); idx++; }
      }
      matrix<Type> Sigma_field = Lf * Lf.transpose();
      matrix<Type> Sigma_field_inv = atomic::matinv(Sigma_field);
      Type logdet_Sigma_field = Type(0);
      for (int j = 0; j < C; j++) logdet_Sigma_field += Type(2) * log(Lf(j, j));
      // Report recovered per-field SDs (covariance scale) + correlation matrix.
      vector<Type> sd_spde_b(C);
      for (int j = 0; j < C; j++) sd_spde_b(j) = sqrt(Sigma_field(j, j));
      REPORT(sd_spde_b);
      matrix<Type> cor_spde_field(C, C);
      for (int a = 0; a < C; a++)
        for (int bcol = 0; bcol < C; bcol++)
          cor_spde_field(a, bcol) = Sigma_field(a, bcol) / (sd_spde_b(a) * sd_spde_b(bcol));
      REPORT(cor_spde_field);
      REPORT(Sigma_field);
      // Pull the C field columns; Q(j,l) = omega_j' Q_base omega_l via sparse
      // mat-vec, and accumulate sum_j GMRF(Q_base)(omega_j).
      matrix<Type> Qmat(C, C);
      for (int j = 0; j < C; j++) {
        vector<Type> omj(n_node);
        for (int i = 0; i < n_node; i++) omj(i) = omega_spde_aug(i, j);
        nll += gmrf_slope(omj);                          // single-field GMRF
        for (int l = 0; l <= j; l++) {
          vector<Type> oml(n_node);
          for (int i = 0; i < n_node; i++) oml(i) = omega_spde_aug(i, l);
          Type qjl = (omj * (Q_slope * oml.matrix()).array()).sum();
          Qmat(j, l) = qjl;
          Qmat(l, j) = qjl;
        }
      }
      Type trQ = Type(0);
      for (int j = 0; j < C; j++) trQ += Qmat(j, j);
      Type tr_SinvQ = Type(0);
      for (int j = 0; j < C; j++)
        for (int l = 0; l < C; l++)
          tr_SinvQ += Sigma_field_inv(j, l) * Qmat(l, j);
      nll += Type(0.5) * Type(n_node) * logdet_Sigma_field
           + Type(0.5) * (tr_SinvQ - trQ);
      REPORT(kappa_s);
    } else {
    if (log_sd_spde_b.size() != n_lhs_cols_spde)
      error("gllvmTMB_multi: log_sd_spde_b has wrong length");
    int n_cor_spde = n_lhs_cols_spde * (n_lhs_cols_spde - 1) / 2;
    if (atanh_cor_spde_b.size() != n_cor_spde)
      error("gllvmTMB_multi: atanh_cor_spde_b has wrong length");

    vector<Type> sd_spde_b(n_lhs_cols_spde);
    for (int j = 0; j < n_lhs_cols_spde; j++) sd_spde_b(j) = exp(log_sd_spde_b(j));
    REPORT(sd_spde_b);

    if (n_lhs_cols_spde == 1) {
      // Slope-only: omega_beta ~ N(0, sd^2 Q^-1) == SCALE(GMRF(Q), sd).
      vector<Type> om0(omega_spde_aug.dim[0]);
      for (int i = 0; i < omega_spde_aug.dim[0]; i++) om0(i) = omega_spde_aug(i, 0);
      nll += SCALE(gmrf_slope, sd_spde_b(0))(om0);
    } else {
      Type rho = tanh(atanh_cor_spde_b(0));
      Type one_minus_rho2 = Type(1) - rho * rho;
      Type Sinv00 =  Type(1) / (sd_spde_b(0) * sd_spde_b(0) * one_minus_rho2);
      Type Sinv11 =  Type(1) / (sd_spde_b(1) * sd_spde_b(1) * one_minus_rho2);
      Type Sinv01 = -rho / (sd_spde_b(0) * sd_spde_b(1) * one_minus_rho2);
      Type logdet_Sigma_field = Type(2) * log_sd_spde_b(0)
                              + Type(2) * log_sd_spde_b(1)
                              + log(one_minus_rho2);
      vector<Type> cor_spde_b(1);
      cor_spde_b(0) = rho;
      REPORT(cor_spde_b);

      int n_node = omega_spde_aug.dim[0];
      vector<Type> om0(n_node), om1(n_node);
      for (int i = 0; i < n_node; i++) {
        om0(i) = omega_spde_aug(i, 0);
        om1(i) = omega_spde_aug(i, 1);
      }
      Type q00 = gmrf_slope.Quadform(om0);                 // om0' Q om0
      Type q11 = gmrf_slope.Quadform(om1);                 // om1' Q om1
      Type q01 = (om0 * (Q_slope * om1.matrix()).array()).sum();  // om0' Q om1

      // Two single-field GMRF calls supply 2n log2pi - 2 logdetQ + q00 + q11.
      nll += gmrf_slope(om0);
      nll += gmrf_slope(om1);
      // Sigma_field log-determinant + the off-diagonal / rescaled quadratic.
      nll += Type(0.5) * Type(n_node) * logdet_Sigma_field
           + Type(0.5) * ((Sinv00 - Type(1)) * q00
                          + (Sinv11 - Type(1)) * q11
                          + Type(2) * Sinv01 * q01);
    }
    REPORT(kappa_s);
    }  // end closed-form (use_spde_dep_slope == 0) branch
  }

  // -------- spatial_latent slope (Design 64 sec.3) ----------------------
  // Block-diagonal reduced-rank random regression on the SPDE field. For each
  // LHS column k, build an independent loading matrix Lambda_k (n_traits x
  // d_spde_slope, lower-triangular rr() convention) and place an independent
  // N(0, Q_base^{-1}) prior on each of the d_spde_slope shared field columns
  // g_spde_slope[ , f, k] (a single GMRF(Q_base) call each; scale absorbed into
  // Lambda_k). The negative log prior is sum over the n_lhs_cols_spde_lat *
  // d_spde_slope independent fields of GMRF(Q_base)(.) -- the existing
  // spatial_latent (intercept-only) prior loop replicated across an extra
  // LHS-column axis. No cross-column (intercept-slope) term. This is the
  // phylo_latent slope block with the species-indexed score replaced by the
  // shared mesh field, and Ainv_phy_rr replaced by GMRF(Q_base).
  array<Type> Lambda_spde_slope(n_traits, std::max(d_spde_slope, 1),
                                std::max(n_lhs_cols_spde_lat, 1));
  Lambda_spde_slope.setZero();
  if (use_spde_latent_slope == 1) {
    if (n_lhs_cols_spde_lat < 1 || n_lhs_cols_spde_lat > 2)
      error("gllvmTMB_multi: n_lhs_cols_spde_lat must be 1 or 2");
    if (g_spde_slope.dim.size() != 3)
      error("gllvmTMB_multi: g_spde_slope must be a 3D array");
    if (g_spde_slope.dim[1] != d_spde_slope)
      error("gllvmTMB_multi: g_spde_slope second dimension must equal d_spde_slope");
    if (g_spde_slope.dim[2] != n_lhs_cols_spde_lat)
      error("gllvmTMB_multi: g_spde_slope third dimension must equal n_lhs_cols_spde_lat");
    if (Z_spde_lat.rows() != y.size() || Z_spde_lat.cols() != n_lhs_cols_spde_lat)
      error("gllvmTMB_multi: Z_spde_lat must be n_obs x n_lhs_cols_spde_lat");
    int n_node = g_spde_slope.dim[0];
    Type kappa_l  = exp(log_kappa_spde);
    Type kappa_l2 = kappa_l * kappa_l;
    Type kappa_l4 = kappa_l2 * kappa_l2;
    Eigen::SparseMatrix<Type> Q_lat =
      kappa_l4 * spde_M0 + Type(2.0) * kappa_l2 * spde_M1 + spde_M2;
    density::GMRF_t<Type> gmrf_lat(Q_lat);
    int p = n_traits;
    int rank = d_spde_slope;
    int len_per_col = p * rank - rank * (rank - 1) / 2;
    if (theta_rr_spde_slope.size() != n_lhs_cols_spde_lat * len_per_col)
      error("gllvmTMB_multi: theta_rr_spde_slope has wrong length");
    // Build each per-column Lambda_k from its packed lower-triangular slice
    // (identical packing to theta_rr_phy_slope / theta_rr_spde_lv).
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      vector<Type> theta_k =
        theta_rr_spde_slope.segment(kcol * len_per_col, len_per_col);
      vector<Type> lam_diag = theta_k.head(rank);
      vector<Type> lam_lower = theta_k.tail(len_per_col - rank);
      for (int j = 0; j < rank; j++) {
        for (int i = 0; i < p; i++) {
          if (j > i)
            Lambda_spde_slope(i, j, kcol) = 0;
          else if (i == j)
            Lambda_spde_slope(i, j, kcol) = lam_diag(j);
          else
            Lambda_spde_slope(i, j, kcol) =
              lam_lower(j * p - (j + 1) * j / 2 + i - 1 - j);
        }
      }
    }
    // Independent N(0, Q_base^{-1}) prior on every shared field column.
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      for (int f = 0; f < d_spde_slope; f++) {
        vector<Type> g_kf(n_node);
        for (int i = 0; i < n_node; i++) g_kf(i) = g_spde_slope(i, f, kcol);
        nll += gmrf_lat(g_kf);
      }
    }
    REPORT(Lambda_spde_slope);
    // Per-column Sigma_k = Lambda_k Lambda_k^T for extraction / recovery.
    matrix<Type> Ls0(n_traits, std::max(d_spde_slope, 1));
    matrix<Type> Ls1(n_traits, std::max(d_spde_slope, 1));
    for (int j = 0; j < std::max(d_spde_slope, 1); j++)
      for (int i = 0; i < n_traits; i++) {
        Ls0(i, j) = Lambda_spde_slope(i, j, 0);
        Ls1(i, j) = (n_lhs_cols_spde_lat > 1) ? Lambda_spde_slope(i, j, 1) : Type(0);
      }
    matrix<Type> Sigma_spde_slope_intercept = Ls0 * Ls0.transpose();
    matrix<Type> Sigma_spde_slope_slope = Ls1 * Ls1.transpose();
    REPORT(Sigma_spde_slope_intercept);
    REPORT(Sigma_spde_slope_slope);
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

  // Augmented SPDE slope: project each field column (alpha, beta) once.
  //   A_omega_aug(o, j) = (A_proj * omega_spde_aug.col(j))(o).
  // eta gets sum_j A_omega_aug(o, j) * Z_spde_aug(o, j) in the loop below.
  matrix<Type> A_omega_aug(y.size(), std::max(n_lhs_cols_spde, 1));
  A_omega_aug.setZero();
  if (use_spde_slope == 1) {
    for (int j = 0; j < n_lhs_cols_spde; j++) {
      vector<Type> omega_j(omega_spde_aug.dim[0]);
      for (int i = 0; i < omega_spde_aug.dim[0]; i++) omega_j(i) = omega_spde_aug(i, j);
      vector<Type> Ao_j = A_proj * omega_j;
      for (int o = 0; o < y.size(); o++) A_omega_aug(o, j) = Ao_j(o);
    }
  }

  // spatial_latent slope: project each shared field column g_spde_slope[ ,f,k]
  // once. A_g_spde_slope(o, f, k) = (A_proj * g_spde_slope.col(f, k))(o). eta
  // gets sum_k Z_spde_lat(o,k) * sum_f Lambda_k(t(o),f) * A_g_spde_slope(o,f,k).
  array<Type> A_g_spde_slope(y.size(), std::max(d_spde_slope, 1),
                             std::max(n_lhs_cols_spde_lat, 1));
  A_g_spde_slope.setZero();
  if (use_spde_latent_slope == 1) {
    for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
      for (int f = 0; f < d_spde_slope; f++) {
        vector<Type> g_kf(g_spde_slope.dim[0]);
        for (int i = 0; i < g_spde_slope.dim[0]; i++) g_kf(i) = g_spde_slope(i, f, kcol);
        vector<Type> Ag = A_proj * g_kf;
        for (int o = 0; o < y.size(); o++) A_g_spde_slope(o, f, kcol) = Ag(o);
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
    if (use_diag_cluster2 == 1)
      eta(o) += r_c2(t, cluster2_id(o));
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
    if (use_spde_slope == 1) {
      // eta(o) += (A_proj omega_alpha)(o) + x(o) * (A_proj omega_beta)(o).
      // On the spatial_dep path the loop runs over all C = 2T interleaved
      // fields, Z_spde_aug selecting this row's trait pair.
      Type contrib_spde_aug = 0;
      for (int j = 0; j < n_lhs_cols_spde; j++)
        contrib_spde_aug += A_omega_aug(o, j) * Z_spde_aug(o, j);
      eta(o) += contrib_spde_aug;
    }
    if (use_spde_latent_slope == 1) {
      // Block-diagonal reduced-rank random regression on the SPDE field: per
      // LHS column k, the reduced-rank field structure (independent Lambda_k
      // and shared field scores), weighted by the column design Z_spde_lat(o,k).
      Type contrib_spde_lat = 0;
      for (int kcol = 0; kcol < n_lhs_cols_spde_lat; kcol++) {
        Type u_kt = 0;
        for (int f = 0; f < d_spde_slope; f++)
          u_kt += Lambda_spde_slope(t, f, kcol) * A_g_spde_slope(o, f, kcol);
        contrib_spde_lat += Z_spde_lat(o, kcol) * u_kt;
      }
      eta(o) += contrib_spde_lat;
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
    if (use_phylo_slope_correlated == 1) {
      Type contrib_aug = 0;
      for (int k = 0; k < b_phy_aug.dim[2]; k++)
        for (int j = 0; j < n_lhs_cols; j++)
          contrib_aug += b_phy_aug(species_aug_id(o), j, k) * Z_phy_aug(o, j, k);
      eta(o) += contrib_aug;
    } else if (use_phylo_slope == 1) {
      // Per-species slope on x, shared across traits.
      eta(o) += b_phy_slope(species_aug_id(o)) * x_phy_slope(o);
    }
    if (use_phylo_latent_slope == 1) {
      // Block-diagonal reduced-rank random regression: per LHS column k,
      // the reduced-rank phylo factor structure (independent Lambda_k and
      // scores), weighted by the column design value Z_phy_lat(o, k).
      Type contrib_lat = 0;
      for (int kcol = 0; kcol < n_lhs_cols_lat; kcol++) {
        Type u_kt = 0;
        for (int f = 0; f < d_phy_slope; f++)
          u_kt += Lambda_phy_slope(t, f, kcol)
                  * g_phy_slope(species_aug_id(o), f, kcol);
        contrib_lat += Z_phy_lat(o, kcol) * u_kt;
      }
      eta(o) += contrib_lat;
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
  // Per-row response log-density log p(y(o) | eta_o), factored out of the
  // family-dispatch loop so the SAME kernels can be evaluated at a STATE-
  // SUBSTITUTED eta for the discrete missing-predictor SUM (design 68
  // sec.1.0 / sec.3.3: "the SUM introduces NO new RESPONSE family"). The
  // ordinary loop calls obs_loglik(o, eta(o)); the binary mi() block (below)
  // calls obs_loglik(o, eta_state) for each hypothetical predictor state and
  // accumulates the per-unit product. The body is the verbatim fid dispatch
  // with each `nll -= <density>` rewritten as `ll += <density>; return ll`.
  auto obs_loglik = [&](int o, Type eta_o) -> Type {
    int fid = family_id_vec(o);
    Type ll = Type(0.0);
    if (fid == 0) {
      // Gaussian, identity link
      ll += dnorm(y(o), eta_o, sigma_eps, true);
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
        p = Type(1.0) / (Type(1.0) + exp(-eta_o));
      } else if (lid == 1) {
        p = pnorm(eta_o);
      } else if (lid == 2) {
        p = Type(1.0) - exp(-exp(eta_o));
      } else {
        error("gllvmTMB_multi: unknown link_id for binomial family");
      }
      // Numerical safety: clip away from 0/1 to prevent log(0).
      Type tiny = Type(1e-12);
      p = (p < tiny)            ? tiny           : p;
      p = (p > Type(1.0) - tiny) ? Type(1.0) - tiny : p;
      ll += dbinom(y(o), n_trials(o), p, true);
    } else if (fid == 2) {
      // Poisson, log link
      ll += dpois(y(o), exp(eta_o), true);
    } else if (fid == 3) {
      // Lognormal, log link
      // y > 0 strictly. log(y) ~ Normal(eta, sigma_eps); add Jacobian -log(y).
      ll += dnorm(log(y(o)), eta_o, sigma_eps, true) - log(y(o));
    } else if (fid == 4) {
      // Gamma, log link, mu + CV parametrization
      // mu = exp(eta); sigma_eps interpreted as the coefficient of variation.
      // shape = 1 / sigma_eps^2 ; scale = mu / shape so E(y) = mu, CV(y) = sigma_eps.
      Type mu_g    = exp(eta_o);
      Type shape_g = Type(1.0) / (sigma_eps * sigma_eps);
      Type scale_g = mu_g / shape_g;
      ll += dgamma(y(o), shape_g, scale_g, true);
    } else if (fid == 5) {
      // NB2 (negative binomial, type 2), log link.
      // Var(y) = mu + mu^2 / phi, with one log_phi per trait.
      // Use dnbinom_robust (numerically stable; takes log_mu and log(var-mu)).
      // log(var - mu) = log(mu^2 / phi) = 2*log(mu) - log(phi).
      int t = trait_id(o);
      Type log_mu = eta_o;                         // log link
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_nbinom2(t);
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
    } else if (fid == 6) {
      // Tweedie compound Poisson-Gamma, log link.
      // y >= 0 (point mass at zero plus continuous positive part).
      // Per-trait dispersion phi = exp(log_phi_tweedie(t));
      // power p in (1, 2), parameterised as p = 1 + plogis(logit_p_tweedie(t)).
      int t = trait_id(o);
      Type mu_t  = exp(eta_o);
      Type phi_t = exp(log_phi_tweedie(t));
      Type p_t   = Type(1.0) + invlogit(logit_p_tweedie(t));
      ll += dtweedie(y(o), mu_t, phi_t, p_t, true);
    } else if (fid == 7) {
      // Beta family, logit link, mean-precision parameterisation.
      // y in (0, 1); mu = invlogit(eta); a = mu*phi, b = (1-mu)*phi.
      // log f(y) = lgamma(phi) - lgamma(a) - lgamma(b)
      //           + (a - 1) log(y) + (b - 1) log(1 - y)
      // (Smithson & Verkuilen 2006 Psychol. Methods 11:54-71.)
      int t = trait_id(o);
      Type mu_b  = invlogit(eta_o);
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
      ll += ld;
    } else if (fid == 8) {
      // Beta-binomial family (Hilbe 2014; Bolker 2008).
      int t = trait_id(o);
      Type mu_bb  = invlogit(eta_o);
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
      ll += ld;
    } else if (fid == 9) {
      // Student-t, identity link.
      int t = trait_id(o);
      Type mu_t    = eta_o;
      Type sigma_t = exp(log_sigma_student(t));
      Type df_t    = Type(1.0) + exp(log_df_student(t));
      Type z_t     = (y(o) - mu_t) / sigma_t;
      ll += dt(z_t, df_t, true) - log(sigma_t);
    } else if (fid == 10) {
      // Zero-truncated Poisson, log link.
      Type lambda_t = exp(eta_o);
      ll += dpois(y(o), lambda_t, true)
             - logspace_sub(Type(0.0), -lambda_t);
    } else if (fid == 11) {
      // Zero-truncated NB2, log link.
      int t = trait_id(o);
      Type log_mu = eta_o;
      Type mu_t   = exp(log_mu);
      Type phi_t  = exp(log_phi_truncnb2(t));
      Type log_v_minus_mu = Type(2.0) * log_mu - log_phi_truncnb2(t);
      Type log_p0 = phi_t * (log_phi_truncnb2(t) - log(mu_t + phi_t));
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true)
             - logspace_sub(Type(0.0), log_p0);
    } else if (fid == 12) {
      // delta_lognormal (hurdle): one shared eta drives both components.
      //   Presence: I{y>0} ~ Bernoulli(invlogit(eta))   via dbinom_robust
      //   Positive: log y | y>0 ~ Normal(eta, sigma_t)
      // The Bernoulli logit-p IS eta(o) under the shared-predictor scheme,
      // so we hand eta directly to dbinom_robust for numerical stability.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      ll += dbinom_robust(x_pres, Type(1.0), eta_o, true);
      if (y(o) > Type(0)) {
        Type sigma_t = exp(log_sigma_lognormal_delta(t));
        // log y ~ Normal(eta, sigma_t); add Jacobian -log y so the density
        // is for Y rather than log Y.
        ll += dnorm(log(y(o)), eta_o, sigma_t, true) - log(y(o));
      }
    } else if (fid == 13) {
      // delta_gamma (hurdle): same shared-eta logic.
      //   Positive: y | y>0 ~ Gamma(shape = 1/phi^2, scale = mu * phi^2)
      //     so E(y) = mu = exp(eta), CV(y) = phi.
      int t = trait_id(o);
      Type x_pres = (y(o) > Type(0)) ? Type(1.0) : Type(0.0);
      ll += dbinom_robust(x_pres, Type(1.0), eta_o, true);
      if (y(o) > Type(0)) {
        Type phi_t   = exp(log_phi_gamma_delta(t));
        Type mu_g    = exp(eta_o);
        Type shape_g = Type(1.0) / (phi_t * phi_t);
        Type scale_g = mu_g / shape_g;
        ll += dgamma(y(o), shape_g, scale_g, true);
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
        upper_p = pnorm(cuts(yk - 1) - eta_o);
      }
      if (yk <= 1) {
        lower_p = Type(0.0);
      } else {
        lower_p = pnorm(cuts(yk - 2) - eta_o);
      }
      Type p_k = upper_p - lower_p;
      Type tiny_p = Type(1e-12);
      p_k = (p_k < tiny_p) ? tiny_p : p_k;
      ll += log(p_k);
    } else if (fid == 15) {
      // NB1 (negative binomial, type 1), log link.
      // Var(y) = mu * (1 + phi) = mu + phi * mu, with one log_phi per trait
      // (linear mean-variance; phi -> 0 recovers Poisson). Hilbe (2011).
      // Use dnbinom_robust (numerically stable; takes log_mu and log(var-mu)).
      // Contrast NB2 (fid 5), where var - mu = mu^2 / phi so the second
      // argument is 2*log(mu) - log(phi); here var - mu = phi * mu so it is
      // log(phi) + log(mu) = log_mu + log_phi_nbinom1(t).
      int t = trait_id(o);
      Type log_mu = eta_o;                         // log link
      Type log_v_minus_mu = log_mu + log_phi_nbinom1(t);
      ll += dnbinom_robust(y(o), log_mu, log_v_minus_mu, true);
    } else {
      error("gllvmTMB_multi: unknown family_id");
    }
    return ll;
  };

  // -------- Discrete missing-PREDICTOR SUM: binary + ordered -------------
  // Design 68 sec.1.1 / sec.1.2 / sec.3 (drmTMB MD6a/MD6b analogue with the
  // multivariate per-UNIT product). A discrete missing predictor is
  // marginalised EXACTLY by a finite-state SUM evaluated here, with NO latent
  // x. For a missing-x unit u the observed-data contribution is
  //   nll -= logspace_add_over_k( log p(x=k|z_u) + log_y_k(u) )
  // where log_y_k(u) = sum_t obs_loglik(o, eta_state(o, k)) is the PRODUCT
  // over u's trait rows (sec.3.2: the SUM is OUTSIDE the trait product, so the
  // prior is counted ONCE per unit and a SINGLE state k feeds all traits -- a
  // per-row SUM would double-count the prior). The per-unit, per-state
  // accumulator mi_acc(u, k) is M x K (K = 2 for binary, K = mi_n_state for
  // ordered -- the generalisation of Phase 5a's M x 2); it is filled by the
  // gated rows in the loop below, initialised here to the per-unit log-priors.
  //   * binary  (mi_family == 1): K = 2; Bernoulli-logit prior; the state-eta
  //     uses the single-column DELTA-SWAP (sec.3.4), value k in {0, 1}.
  //   * ordered (mi_family == 2): K states; cumulative-logit prior with K-1
  //     free cutpoints reconstructed from theta_ord (sec.1.2); the state-eta
  //     uses the FULL-SWAP via X_fix_state (an ordered factor expands to K-1
  //     contrast columns, so a single-column delta is insufficient).
  // has_mi != 1, or mi_family not in {1, 2} -> the whole block is an exact
  // no-op (mi_acc / mi_logp* / mi_cutpoints unused).
  bool mi_is_discrete = (has_mi == 1 && (mi_family == 1 || mi_family == 2));
  int mi_K = (has_mi == 1 && mi_family == 2) ? mi_n_state : 2;
  int mi_n_units = mi_is_discrete ? mi_x_unit.size() : 0;
  matrix<Type> mi_acc(std::max(mi_n_units, 1), std::max(mi_K, 1));
  mi_acc.setZero();
  // Binary prior caches (used only for mi_family == 1; the observed-unit term
  // and the posterior probability read them in the collapse pass).
  vector<Type> mi_logp1(std::max(mi_n_units, 1));
  vector<Type> mi_logp0(std::max(mi_n_units, 1));
  mi_logp1.setZero();
  mi_logp0.setZero();
  // Ordered per-unit per-state log-prior cache (used only for mi_family == 2).
  matrix<Type> mi_log_prior(std::max(mi_n_units, 1), std::max(mi_K, 1));
  mi_log_prior.setZero();
  // Ordered cutpoints c_1 < ... < c_{K-1} reconstructed from the K-1 FREE raw
  // vector theta_ord (sec.1.2): c_1 = theta_ord(0) free base, c_j = c_{j-1} +
  // exp(theta_ord(j)). MIRRORS drmTMB (K-1 free); NOT the fid-14 tau_1 = 0
  // RESPONSE convention. Length 0 unless mi_family == 2.
  vector<Type> mi_cutpoints(theta_ord.size());
  if (has_mi == 1 && mi_family == 1) {
    // Per-unit Bernoulli-logit predictor prior (verbatim drmTMB MD6a:
    // log_p1 = -logspace_add(0, -eta_x), log_p0 = -logspace_add(0, eta_x)).
    vector<Type> mi_eta_x = X_mi * beta_mi;
    for (int u = 0; u < mi_n_units; ++u) {
      mi_logp1(u) = -logspace_add(Type(0.0), -mi_eta_x(u));
      mi_logp0(u) = -logspace_add(Type(0.0),  mi_eta_x(u));
      // Initialise the per-state accumulator with the state log-prior; the
      // response product (sec.3.3 step 2) is added per trait row below.
      mi_acc(u, 0) = mi_logp0(u);
      mi_acc(u, 1) = mi_logp1(u);
    }
  } else if (has_mi == 1 && mi_family == 2) {
    // Reconstruct the K-1 free cutpoints (sec.1.2). The increment loop body is
    // byte-identical to drmTMB MD6b src/drmTMB.cpp:872-875 and to gllvmTMB's
    // fid-14 reconstruction (sec.5) -- but entry 0 stays a FREE base here.
    if (theta_ord.size() > 0) {
      mi_cutpoints(0) = theta_ord(0);
      for (int j = 1; j < theta_ord.size(); ++j) {
        mi_cutpoints(j) = mi_cutpoints(j - 1) + exp(theta_ord(j));
      }
    }
    // Per-unit cumulative-logit state log-prior (drmTMB MD6b sec.1.2 form):
    //   state 0    : log F(c_1 - eta_x)
    //   state K-1  : log(1 - F(c_{K-1} - eta_x))
    //   state k    : log[ F(c_k - eta_x) - F(c_{k-1} - eta_x) ]
    vector<Type> mi_eta_x = X_mi * beta_mi;
    for (int u = 0; u < mi_n_units; ++u) {
      for (int k = 0; k < mi_K; ++k) {
        Type log_prob;
        if (k == 0) {
          log_prob = gll_log_inv_logit(mi_cutpoints(0) - mi_eta_x(u));
        } else if (k == mi_K - 1) {
          log_prob = gll_log1m_inv_logit(mi_cutpoints(mi_K - 2) - mi_eta_x(u));
        } else {
          Type upper = mi_cutpoints(k) - mi_eta_x(u);
          Type lower = mi_cutpoints(k - 1) - mi_eta_x(u);
          log_prob = gll_log_inv_logit_diff(upper, lower);
        }
        mi_log_prior(u, k) = log_prob;
        // Initialise the accumulator with the state log-prior (sec.3.3 step 3);
        // the response product is added per trait row below.
        mi_acc(u, k) = log_prob;
      }
    }
  }

  for (int o = 0; o < y.size(); o++) {
    // Capture the running NLL so we can scale this row's contribution by
    // its weight after the family-dispatch block. Mirrors the
    // `tmp_ll *= weights_i(i)` pattern in src/gllvmTMB.cpp around line 1136.
    Type nll_before_row = nll;
    // The discrete-row GATE (design 68 sec.2 / drmTMB src/drmTMB.cpp:1163-1170).
    // For a row whose unit has a MISSING discrete predictor (mi_family in
    // {1, 2}, mi_observed_unit(unit) == 0), the per-state response density is
    // folded into the per-unit SUM (mi_acc below), so the ordinary family term
    // must NOT also fire -- otherwise y is double-counted. The gate consults the
    // per-UNIT observed flag via the long-row -> unit map mi_unit_id (the
    // multivariate adaptation: drmTMB's mi_observed is per response row). The
    // condition is identical for binary and ordered; only the accumulation
    // branch differs (delta-swap vs full-swap).
    bool mi_missing_row = (mi_is_discrete &&
                           mi_observed_unit(mi_unit_id(o)) == 0);
    // Phase 1 response mask: a row with is_y_observed(o) == 0 contributes
    // nothing to the likelihood. Its y(o) is a safe sentinel, so we must NOT
    // evaluate any family density on it (that is the sentinel-invariance
    // guarantee, design 59 sec.9). When all rows are observed (response="drop")
    // this guard is always true -> an exact no-op.
    if (is_y_observed(o) && !mi_missing_row) {
      // Ordinary path: observed-y row whose predictor value is NOT a missing
      // discrete x (observed-x units take this path with the true x in eta(o)).
      nll -= obs_loglik(o, eta(o));
    } else if (is_y_observed(o) && mi_missing_row) {
      // Discrete-SUM path (sec.3.3 steps 1-2): accumulate the per-state
      // response log-density into the unit's K-state accumulator. Weights enter
      // HERE per trait row (the outer weight scaling at the foot of the loop is
      // bypassed for gated rows since row_nll == 0).
      int u = mi_unit_id(o);
      if (mi_family == 1) {
        // Binary: the single-column DELTA-SWAP removes the mi() column's
        // placeholder contribution and inserts the hypothetical state value k
        // in {0, 1}.
        Type eta_base = eta(o) - b_fix(mi_col) * X_fix(o, mi_col);
        mi_acc(u, 0) += weights_i(o) *
          obs_loglik(o, eta_base + b_fix(mi_col) * Type(0.0));
        mi_acc(u, 1) += weights_i(o) *
          obs_loglik(o, eta_base + b_fix(mi_col) * Type(1.0));
      } else {
        // Ordered: the FULL-SWAP (sec.3.4) swaps the ENTIRE fixed-effect linear
        // predictor for its state-k version, leaving every random-effect
        // contribution untouched (those do not depend on x):
        //   eta_state(o,k) = eta(o) - X_fix(o,.).b_fix + X_fix_state(base+k,.).b_fix
        // X_fix_state is filtered to missing-unit rows; mi_state_row(o) is o's
        // 0-indexed K-block base (state fast). Compute the base fixed-effect
        // contribution X_fix(o,.).b_fix once, then add each state's.
        Type eta_minus_fix = eta(o);
        for (int col = 0; col < X_fix.cols(); ++col) {
          eta_minus_fix -= X_fix(o, col) * b_fix(col);
        }
        int base = mi_state_row(o);
        for (int k = 0; k < mi_K; ++k) {
          Type state_fix = Type(0.0);
          for (int col = 0; col < X_fix_state.cols(); ++col) {
            state_fix += X_fix_state(base + k, col) * b_fix(col);
          }
          mi_acc(u, k) += weights_i(o) *
            obs_loglik(o, eta_minus_fix + state_fix);
        }
      }
    }
    // Apply the per-row weight: scale this row's NLL contribution by
    // weights_i(o). Unit weight is a no-op; weight 0 zeroes the row's
    // contribution (cross-validation hold-out semantics). For a masked or
    // gated row the family block above added nothing, so row_nll == 0 and this
    // is a no-op too.
    Type row_nll = nll - nll_before_row;
    nll = nll_before_row + row_nll * weights_i(o);
  }

  // -------- Discrete missing-PREDICTOR SUM: collapse + report ------------
  // Second pass over the M missing units (design 68 sec.3.3 steps 4 + 6):
  // log-sum-exp the 2-state accumulator into nll ONCE per unit, and report the
  // per-unit posterior P(x = 1 | y_u) = exp(acc(u,1) - logspace_add(...)) (the
  // conditional probability, sec.4.4 -- NOT a latent mode). For OBSERVED-x
  // units the ordinary path already fired above; we add only the single
  // matching state's log-prior here (drmTMB MD6a `mi_x * log_p1 + (1-mi_x) *
  // log_p0`, src/drmTMB.cpp:847). mi_probability holds P(x=1|y) at missing
  // units and the observed x value at observed units (drmTMB mi_x_full shape).
  if (has_mi == 1 && mi_family == 1) {
    vector<Type> mi_probability(mi_n_units);
    for (int u = 0; u < mi_n_units; ++u) {
      if (mi_observed_unit(u) == 1) {
        // Observed-x unit: add the matching state's log-prior. mi_x_unit(u) is
        // the observed binary value (0 or 1).
        nll -= mi_x_unit(u) * mi_logp1(u)
             + (Type(1.0) - mi_x_unit(u)) * mi_logp0(u);
        mi_probability(u) = mi_x_unit(u);
      } else {
        // Missing-x unit: collapse the 2-state mixture-of-products ONCE.
        Type log_norm = logspace_add(mi_acc(u, 0), mi_acc(u, 1));
        nll -= log_norm;
        mi_probability(u) = exp(mi_acc(u, 1) - log_norm);
      }
    }
    REPORT(mi_probability);
    REPORT(beta_mi);
    ADREPORT(beta_mi);
  } else if (has_mi == 1 && mi_family == 2) {
    // Ordered (drmTMB MD6b): collapse the K-state mixture-of-products ONCE per
    // missing unit (sec.3.3 step 4) and report (step 6) the per-unit posterior
    // state weights w(u,k) (M x K) and the conditional EXPECTED CATEGORY SCORE
    // sum_k (k+1) w(u,k) (sec.4.4). For OBSERVED-x units the ordinary response
    // path already fired above; add only the single matching state's log-prior
    // (drmTMB MD6b src/drmTMB.cpp:899-913). mi_expected_score holds the expected
    // score at missing units and the observed integer category at observed
    // units; mi_state_probability holds w(u,.) (a one-hot at observed units).
    matrix<Type> mi_state_probability(mi_n_units, mi_K);
    mi_state_probability.setZero();
    vector<Type> mi_expected_score(mi_n_units);
    for (int u = 0; u < mi_n_units; ++u) {
      if (mi_observed_unit(u) == 1) {
        // Observed-x unit: mi_x_unit(u) is the observed integer category 1..K.
        int state = CppAD::Integer(mi_x_unit(u)) - 1;  // 0-indexed
        nll -= mi_log_prior(u, state);
        mi_state_probability(u, state) = Type(1.0);
        mi_expected_score(u) = mi_x_unit(u);
      } else {
        // Missing-x unit: log-sum-exp the K-state accumulator ONCE.
        Type log_norm = mi_acc(u, 0);
        for (int k = 1; k < mi_K; ++k) {
          log_norm = logspace_add(log_norm, mi_acc(u, k));
        }
        nll -= log_norm;
        Type score = Type(0.0);
        for (int k = 0; k < mi_K; ++k) {
          Type posterior = exp(mi_acc(u, k) - log_norm);
          mi_state_probability(u, k) = posterior;
          score += Type(k + 1) * posterior;
        }
        mi_expected_score(u) = score;
      }
    }
    REPORT(mi_expected_score);
    REPORT(mi_state_probability);
    REPORT(mi_cutpoints);
    REPORT(beta_mi);
    ADREPORT(beta_mi);
    ADREPORT(mi_cutpoints);
  }

  ADREPORT(b_fix);
  REPORT(eta);

  // Per-trait dispersion / power for NB2 and Tweedie. These are reported
  // unconditionally; the R side only reads them when the corresponding
  // family is in use (and TMB's `map` zeroes their gradient otherwise).
  vector<Type> phi_nbinom2 = exp(log_phi_nbinom2);
  vector<Type> phi_nbinom1 = exp(log_phi_nbinom1);
  vector<Type> phi_tweedie = exp(log_phi_tweedie);
  vector<Type> p_tweedie(logit_p_tweedie.size());
  for (int i = 0; i < logit_p_tweedie.size(); i++) {
    p_tweedie(i) = Type(1.0) + invlogit(logit_p_tweedie(i));
  }
  vector<Type> phi_beta = exp(log_phi_beta);
  vector<Type> phi_betabinom = exp(log_phi_betabinom);
  REPORT(phi_nbinom2);
  REPORT(phi_nbinom1);
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
