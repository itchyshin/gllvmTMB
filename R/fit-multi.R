## Stage 2 of gllvmTMB: fit a multivariate stacked-trait model with rr() +
## diag() covariance structures using src/gllvmTMB.cpp.

#' Fit a long-format multivariate stacked-trait model (Stage 2 internal)
#'
#' Called by [gllvmTMB()] when the formula contains `latent()` or `unique()`
#' covstruct terms. Constructs the TMB data + parameter lists, calls
#' `TMB::MakeADFun()` against the runtime-compiled `gllvmTMB_multi` DLL,
#' and optimises with `nlminb()`.
#'
#' @inheritParams gllvmTMB
#' @param parsed The output of [parse_multi_formula()].
#' @keywords internal
#' @noRd
gllvmTMB_multi_fit <- function(parsed, data, trait, site, species,
                               cluster2 = NULL,
                               family, weights,
                               phylo_vcv = NULL, phylo_tree = NULL,
                               known_V = NULL,
                               mesh = NULL,
                               lambda_constraint = NULL,
                               control, silent,
                               unit_obs = "site_species",
                               impute = NULL,
                               missing = miss_control(),
                               is_y_observed = NULL,
                               missing_meta = NULL) {
  ## Family arg can be:
  ##   * a single family object (as before): same family for all rows.
  ##   * a list of family objects + a `family_var` column in `data` whose
  ##     factor / integer levels pick the family per row (galamm-style).
  ##
  ## family_to_id() returns BOTH a family-id and a link-id integer:
  ##   family_id: 0 = gaussian, 1 = binomial, 2 = poisson,
  ##              3 = lognormal, 4 = Gamma,
  ##              5 = nbinom2, 6 = tweedie,
  ##              7 = Beta, 8 = betabinomial,
  ##              9 = student, 10 = truncated_poisson, 11 = truncated_nbinom2,
  ##             12 = delta_lognormal, 13 = delta_gamma (hurdle:
  ##              Bernoulli{y>0} x Lognormal/Gamma{y|y>0}; one shared eta),
  ##             14 = ordinal_probit (Wright/Falconer/Hadfield threshold
  ##              model; K-category ordinal y with K >= 3 categories),
  ##             15 = nbinom1 (negative binomial type-1; linear mean-variance
  ##              Var = mu*(1+phi); per-trait phi via log_phi_nbinom1).
  ##   link_id:   0 = logit / identity / log (the canonical link for that family)
  ##              1 = probit (binomial only)
  ##              2 = cloglog (binomial only)
  ## For non-binomial families, link_id is fixed at 0 (canonical) for now.
  family_to_id <- function(f) {
    ## Allow "delta_lognormal" / "delta_gamma" as character shortcuts to
    ## the constructors in R/families.R. Other character entries are
    ## passed through to do.call() below if they name a family function.
    if (is.character(f) && length(f) == 1L) {
      f <- switch(
        f,
        delta_lognormal = delta_lognormal(),
        delta_gamma     = delta_gamma(),
        f
      )
    }
    if (!inherits(f, "family")) f <- f()
    ## Delta (hurdle) families: $delta = TRUE and $family is a length-2
    ## character vector ("binomial", "lognormal" / "Gamma"). Detect via the
    ## $delta flag rather than by name so future delta_<x> additions can
    ## extend the switch without surprising existing code.
    if (isTRUE(f$delta)) {
      if (!isTRUE(f$type == "standard"))
        cli::cli_abort(c(
          "{.fn delta_lognormal}/{.fn delta_gamma}: only the standard (logit/log) parameterisation is currently supported in the multivariate engine.",
          "i" = "Use {.code delta_lognormal()} or {.code delta_gamma()} (default {.code type = \"standard\"}).",
          "*" = "{.code type = \"poisson-link\"} is on the roadmap."
        ))
      if (!identical(f$link[1], "logit"))
        cli::cli_abort("delta_lognormal/delta_gamma: only logit (presence) is currently supported.")
      if (!identical(f$link[2], "log"))
        cli::cli_abort("delta_lognormal/delta_gamma: only log (positive component) is currently supported.")
      if (identical(f$family, c("binomial", "lognormal")))
        return(c(12L, 0L))
      if (identical(f$family, c("binomial", "Gamma")))
        return(c(13L, 0L))
      cli::cli_abort(c(
        "Unsupported delta family: {.val {paste(f$family, collapse = '/')}}.",
        "i" = "Currently supported delta families: {.code delta_lognormal()}, {.code delta_gamma()}."
      ))
    }
    fid <- switch(
      f$family,
      gaussian          = 0L,
      binomial          = 1L,
      poisson           = 2L,
      lognormal         = 3L,
      Gamma             = 4L,
      nbinom2           = 5L,
      tweedie           = 6L,
      Beta              = 7L,
      beta              = 7L,   # glmmTMB::beta_family() returns family = "beta"
      betabinomial      = 8L,
      student           = 9L,
      truncated_poisson = 10L,
      truncated_nbinom2 = 11L,
      delta_lognormal   = 12L,
      delta_gamma       = 13L,
      ordinal_probit    = 14L,
      nbinom1           = 15L,
      cli::cli_abort(c(
        "Unsupported family: {.val {f$family}}.",
        "i" = "Currently supported: {.code gaussian()}, {.code binomial()}, {.code poisson()}, {.code lognormal()}, {.code Gamma()}, {.code nbinom2()}, {.code nbinom1()}, {.code tweedie()}, {.code Beta()}, {.code betabinomial()}, {.code student()}, {.code truncated_poisson()}, {.code truncated_nbinom2()}, {.code delta_lognormal()}, {.code delta_gamma()}, {.code ordinal_probit()}."
      ))
    )
    lid <- 0L
    if (fid == 1L) {
      lid <- switch(
        f$link,
        logit   = 0L,
        probit  = 1L,
        cloglog = 2L,
        cli::cli_abort(c(
          "binomial: link {.val {f$link}} not supported.",
          "i" = "Use {.code binomial()} (logit; default), {.code binomial(link = \"probit\")}, or {.code binomial(link = \"cloglog\")}."
        ))
      )
    }
    if (fid == 2L && !identical(f$link, "log"))
      cli::cli_abort("poisson: only the log link is currently supported.")
    if (fid == 3L && !identical(f$link, "log"))
      cli::cli_abort("lognormal: only the log link is currently supported.")
    if (fid == 4L && !identical(f$link, "log"))
      cli::cli_abort("Gamma: only the log link is currently supported. Use {.code Gamma(link = \"log\")}.")
    if (fid == 5L && !identical(f$link, "log"))
      cli::cli_abort("nbinom2: only the log link is currently supported.")
    if (fid == 6L && !identical(f$link, "log"))
      cli::cli_abort("tweedie: only the log link is currently supported.")
    if (fid == 7L && !identical(f$link, "logit"))
      cli::cli_abort("Beta: only the logit link is currently supported.")
    if (fid == 8L && !identical(f$link, "logit"))
      cli::cli_abort("betabinomial: only the logit link is currently supported.")
    if (fid == 9L && !identical(f$link, "identity"))
      cli::cli_abort("student: only the identity link is currently supported.")
    if (fid == 10L && !identical(f$link, "log"))
      cli::cli_abort("truncated_poisson: only the log link is currently supported.")
    if (fid == 11L && !identical(f$link, "log"))
      cli::cli_abort("truncated_nbinom2: only the log link is currently supported.")
    if (fid == 14L && !identical(f$link, "probit"))
      cli::cli_abort("ordinal_probit: only the probit link is supported.")
    if (fid == 15L && !identical(f$link, "log"))
      cli::cli_abort("nbinom1: only the log link is currently supported.")
    c(fid, lid)
  }
  ## Per-row family list (length = nrow(data)). Used downstream to read
  ## family-specific extras like Student-t `$df` (fixed vs estimated).
  family_per_row <- vector("list", nrow(data))
  ## Allow string convenience: family = "delta_lognormal" / "delta_gamma"
  ## is rewritten to the constructor result so downstream code (which
  ## consults family$linkinv etc.) sees the full object. Other string
  ## entries are left alone — family_to_id() will error sensibly later.
  if (is.character(family) && length(family) == 1L) {
    family <- switch(
      family,
      delta_lognormal = delta_lognormal(),
      delta_gamma     = delta_gamma(),
      family
    )
  }
  if (is.list(family) && !inherits(family, "family")) {
    fam_var <- attr(family, "family_var") %||% "family"
    if (!fam_var %in% names(data))
      cli::cli_abort(c(
        "Mixed-family fit needs a {.var {fam_var}} column in {.arg data}.",
        "i" = "Set {.code attr(family, 'family_var') <- 'colname'} or include a {.var family} column."
      ))
    fl_pairs <- vapply(family, family_to_id, integer(2))
    fids     <- fl_pairs[1, ]
    lids     <- fl_pairs[2, ]
    fam_levels <- if (is.factor(data[[fam_var]])) levels(data[[fam_var]])
                  else sort(unique(as.character(data[[fam_var]])))
    if (length(fam_levels) != length(family))
      cli::cli_abort("length(family) must match the number of distinct levels in {.var {fam_var}}.")
    fam_idx       <- match(as.character(data[[fam_var]]), fam_levels)
    family_id_vec <- fids[fam_idx]
    link_id_vec   <- lids[fam_idx]
    for (i in seq_along(family_per_row)) family_per_row[[i]] <- family[[fam_idx[i]]]
    family_id <- 0L
    family_input <- family    # M1.8: preserve original list (with family_var attr)
    family    <- family[[1]]   # keep one for downstream linkinv
  } else {
    fl_pair <- family_to_id(family)
    family_id <- fl_pair[1]
    link_id   <- fl_pair[2]
    n_obs <- nrow(data)
    family_id_vec <- rep(family_id, n_obs)
    link_id_vec   <- rep(link_id,   n_obs)
    for (i in seq_along(family_per_row)) family_per_row[[i]] <- family
    family_input <- family    # M1.8: single-family path; family_input == family
  }

  ## ---- Identify which RE terms are present and on which grouping --------
  groupings <- vapply(parsed$covstructs, function(cs) deparse(cs$group), character(1))
  kinds     <- vapply(parsed$covstructs, function(cs) cs$kind, character(1))

  ## ---- `dep` quartet: resolve `.deferred_n_traits` placeholder to T --------
  ## The parser-side rewrite for `dep` / `phylo_dep` / `spatial_dep` writes a
  ## symbolic `d = .deferred_n_traits` because it doesn't have access to
  ## `data`. Resolve it now using the trait factor in `data`. We mirror the
  ## phylo_unique d = n_traits resolution below (which used to be the only
  ## consumer of trait-count-aware rank values).
  .n_traits_for_dep <- nlevels(if (is.factor(data[[trait]])) data[[trait]]
                               else factor(data[[trait]]))
  for (i in seq_along(parsed$covstructs)) {
    cs <- parsed$covstructs[[i]]
    if (isTRUE(cs$extra$.dep)) {
      ## extra$d carries either an integer (already resolved upstream) or the
      ## symbol `.deferred_n_traits` (parser-deferred). Replace symbol with T.
      d_val <- cs$extra$d
      if (is.symbol(d_val) && identical(as.character(d_val), ".deferred_n_traits")) {
        parsed$covstructs[[i]]$extra$d <- as.integer(.n_traits_for_dep)
      }
    }
  }

  ## We need at most: rr|site, diag|site, rr|site_species, diag|site_species,
  ## diag|species, propto|trait, equalto|<obs-grouping>.
  use_rr_B   <- any(kinds == "rr"   & groupings == site)
  use_diag_B <- any(kinds == "diag" & groupings == site)
  ## `common = TRUE` parsimony mode: when the user passes
  ## `unique(0 + trait | g, common = TRUE)`, fit a single shared
  ## sigma_S across all traits at that tier instead of T separate ones.
  ## Implemented by tying all elements of the corresponding theta vector
  ## via `tmb_map` (same factor level), so TMB treats them as one
  ## parameter. No C++ change required.
  diag_B_common <- isTRUE({
    idx <- which(kinds == "diag" & groupings == site)
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$common)
  })
  ## Within-unit grouping name. Defaults to "site_species" (legacy);
  ## users can override via `unit_obs = ...` to gllvmTMB() so the
  ## formula can use any column name (e.g. `obs`, `individual_obs`).
  ss_name    <- unit_obs
  use_rr_W   <- any(kinds == "rr"   & groupings == ss_name)
  use_diag_W <- any(kinds == "diag" & groupings == ss_name)
  diag_W_common <- isTRUE({
    idx <- which(kinds == "diag" & groupings == ss_name)
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$common)
  })
  use_diag_species <- any(kinds == "diag" & groupings == species)
  ## ---- cluster2: a SECOND independent diagonal grouping slot ------------
  ## A renamed copy of the `cluster` (diag_species / q_sp) tier on a
  ## distinct grouping column, so a user can fit two crossed/nested plain
  ## diagonal per-trait variance components at once (e.g.
  ## `cluster = "site"` + `cluster2 = "year"`). Family-agnostic: the
  ## contribution is added to eta before family dispatch (no per-family
  ## C++ branching), exactly like diag_species. See issue #342.
  cluster2_col <- if (is.null(cluster2)) NULL else as.character(cluster2)[1]
  use_diag_cluster2 <- !is.null(cluster2_col) &&
    any(kinds == "diag" & groupings == cluster2_col)
  use_propto <- any(kinds == "propto")
  use_equalto <- any(kinds == "equalto")
  use_spde   <- any(kinds == "spde")
  ## ---- BASE augmented SPDE random-slope detection (Design 60 §3.4) -------
  ## spatial_unique(1 + x | coords) / spatial_indep(1 + x | coords) route to
  ## an `spde` covstruct carrying the `.spatial_unique_augmented` marker (and,
  ## for the indep diagonal special case, `.spatial_indep_augmented`). When
  ## present we drive the now-integrated base SPDE slope engine
  ## (use_spde_slope): a SECOND SPDE field on the covariate with a 2x2
  ## cross-field covariance. The augmented field REPLACES the intercept-only
  ## per-trait field, so use_spde is turned off on this path (the augmented
  ## block reuses the same mesh / Q_base / log_kappa_spde).
  ## The base unique / indep augmented SPDE slope carries the
  ## `.spatial_unique_augmented` marker; the spatial_dep augmented slope
  ## (Design 64 §2) carries `.spatial_dep_augmented` on the same `spde`
  ## covstruct. BOTH drive the use_spde_slope engine (the dep path is the
  ## C = 2T unstructured-Sigma_field generalisation that reuses the same
  ## omega_spde_aug field array + A_proj eta projection); they are detected
  ## together and the dep marker only widens n_lhs_cols_spde and frees
  ## theta_spde_dep_chol below.
  spde_aug_idx <- which(vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "spde") &&
      (isTRUE(cs$extra[[".spatial_unique_augmented"]]) ||
         isTRUE(cs$extra[[".spatial_dep_augmented"]]))
  }, logical(1L)))
  use_spde_slope <- length(spde_aug_idx) > 0L
  if (length(spde_aug_idx) > 1L) {
    cli::cli_abort("Only one augmented spatial random-regression term is supported per formula.")
  }
  spde_slope_cs <- if (use_spde_slope) parsed$covstructs[[spde_aug_idx[1L]]] else NULL
  use_spde_slope_indep <- isTRUE(spde_slope_cs$extra[[".spatial_indep_augmented"]])
  ## spatial_dep(1 + x | coords): the full unstructured C x C field covariance
  ## Sigma_field (C = 2T) over the interleaved (intercept, slope) spatial
  ## fields (Design 64 §2). It nests under use_spde_slope (shares omega_spde_aug
  ## + A_proj eta), so we just record the flag; the dep-specific overrides below
  ## expand n_lhs_cols_spde to 2T, build the interleaved Z, free
  ## theta_spde_dep_chol, and map off log_sd_spde_b / atanh_cor_spde_b.
  use_spde_dep_slope <- isTRUE(spde_slope_cs$extra[[".spatial_dep_augmented"]])
  spde_slope_lhs_form <- if (use_spde_slope) {
    spde_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  spde_slope_xcol <- if (use_spde_slope) {
    sc <- spde_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort("Internal: augmented spatial random regression is missing {.code slope_col}.")
    }
    sc
  } else NA_character_
  if (use_spde_slope) {
    ## The augmented SPDE field supersedes the intercept-only per-trait field.
    use_spde <- FALSE
    ## Split family guard (was a single gaussian-only abort): the base
    ## spatial_unique / spatial_indep (2x2 cross-field) augmented slope and the
    ## spatial_dep (full unstructured 2T x 2T field covariance) augmented slope
    ## nest under the same use_spde_slope engine but have different
    ## identifiability, so each carries its own family-id allowlist (the #388 /
    ## #392 allowlist discipline: a family joins a mode only after its recovery
    ## cell passes empirically). Allowlists hold the RUNTIME family id
    ## (family_to_id(): gaussian = 0, binomial = 1, poisson = 2, Gamma = 4,
    ## nbinom2 = 5, Beta = 7, ordinal_probit = 14), NOT the enum.R column.
    if (use_spde_dep_slope) {
      ## spatial_dep(1 + x | coords): the full unstructured 2T x 2T field
      ## covariance is gaussian-only -- the non-Gaussian cells are non-PD at
      ## the matrix fixtures' n_sites (identifiability of the unstructured
      ## cross-field block, the spatial analogue of phylo_dep / PHY-18). They
      ## stay reserved; the spatial_dep x slope matrix rows honest-skip.
      if (any(!family_id_vec %in% c(0L))) {
        cli::cli_abort(c(
          "{.fn spatial_dep} random slopes are validated for {.code gaussian()} only in this release.",
          "i" = "The augmented {.code spatial_dep(1 + x | coords)} (full unstructured 2T x 2T field covariance) non-Gaussian cells are reserved (Design 64; non-Gaussian non-PD = identifiability).",
          ">" = "Use a Gaussian family for the augmented unstructured SPDE random-regression fit."
        ))
      }
    } else if (any(family_id_vec != 0L)) {
      ## Base spatial_unique / spatial_indep (1 + x | coords): the 2x2
      ## cross-field augmented slope stays gaussian-only in THIS release; its
      ## non-Gaussian activation is a separate slice. Fail loud so the base
      ## spatial matrix-slope non-Gaussian skeletons keep honest-skipping.
      cli::cli_abort(c(
        "{.fn spatial_unique} random slopes are validated for {.code gaussian()} only in this release.",
        "i" = "The augmented {.code spatial_unique(1 + x | coords)} non-Gaussian cells are deferred (Design 60 sections 3.4-3.5, Design 64).",
        ">" = "Use a Gaussian family for the augmented SPDE random-regression fit."
      ))
    }
  }
  ## ---- spatial_latent(1 + x | coords, d) augmented slope (Design 64 §3) ---
  ## Block-diagonal reduced-rank random regression on the SPDE field. Carries
  ## the `.spatial_latent_augmented` marker on an `spde` covstruct (distinct
  ## from the intercept-only `.spatial_latent` marker). Drives its OWN engine
  ## block (use_spde_latent_slope), separate from use_spde_slope.
  spde_lat_aug_idx <- which(vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "spde") && isTRUE(cs$extra[[".spatial_latent_augmented"]])
  }, logical(1L)))
  use_spde_latent_slope <- length(spde_lat_aug_idx) > 0L
  if (length(spde_lat_aug_idx) > 1L) {
    cli::cli_abort("Only one augmented {.fn spatial_latent} (random-slope) term is supported per formula.")
  }
  spde_latent_slope_cs <- if (use_spde_latent_slope) {
    parsed$covstructs[[spde_lat_aug_idx[1L]]]
  } else NULL
  if (use_spde_latent_slope) {
    use_spde <- FALSE
    ## spatial_latent(1 + x | coords, d): the block-diagonal reduced-rank
    ## augmented slope (each LHS column gets its own Lambda_k Lambda_k^T; no
    ## intercept-slope correlation block). Family-id allowlist per the
    ## #388 / #392 discipline -- a family joins ONLY after its recovery cell in
    ## test-matrix-slope-spatial-latent.R passes empirically. Like the phylo
    ## analogue (phylo_latent activated across all families), the reduced-rank
    ## latent path is the best-identified augmented spatial slope. Allowlist
    ## holds the RUNTIME family id (family_to_id(): gaussian = 0, binomial = 1,
    ## poisson = 2, Gamma = 4, nbinom2 = 5, Beta = 7, ordinal_probit = 14).
    if (any(!family_id_vec %in% c(0L, 1L, 2L, 4L, 5L, 7L, 14L))) {
      cli::cli_abort(c(
        "Augmented {.fn spatial_latent} random slopes are validated for {.code gaussian()}, {.code binomial()} (probit / logit), {.code poisson()}, {.code nbinom2()}, {.code Gamma()}, {.code Beta()}, and {.code ordinal_probit()} in this release.",
        "i" = "Other families for {.code spatial_latent(1 + x | coords, d = K)} are reserved (Design 64 section 6).",
        ">" = "Use a validated family for the augmented SPDE reduced-rank random-regression fit."
      ))
    }
  }
  ## Reduced-rank latent slope sizing + fail-loud d <= n_traits guard
  ## (mirrors the phylo_latent guard at the d_phy_slope site below).
  d_spde_slope <- if (use_spde_latent_slope) {
    d_req <- as.integer(spde_latent_slope_cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "spatial_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  spde_latent_slope_lhs_form <- if (use_spde_latent_slope) {
    spde_latent_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  n_lhs_cols_spde_lat <- if (use_spde_latent_slope) 2L else 1L
  spde_latent_slope_xcol <- if (use_spde_latent_slope) {
    sc <- spde_latent_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort("Internal: augmented spatial_latent random regression is missing {.code slope_col}.")
    }
    sc
  } else NA_character_
  ## ---- "indep" keyword over-parameterisation guards --------------------
  ## The clean quartet is documented in `R/brms-sugar.R`:
  ##   * `latent + unique` is the decomposition mode (paired).
  ##   * `indep` standalone is the marginal-only mode (always alone).
  ##   * `dep` standalone is the full unstructured mode (always alone).
  ## `indep` and `latent` (or `indep` and `unique`) together on the SAME
  ## correlation side are over-parameterised --- the model cannot decide
  ## whether trait variance lives in the shared component or the
  ## marginal component. We hard-abort with a targeted message.
  ##
  ## After rewrite_canonical_aliases() the `.indep` marker rides on the
  ## engine-level covstruct's `extra` list:
  ##   indep(form)           -> diag(form, .indep = TRUE)
  ##   phylo_indep(0+t|sp)   -> phylo_rr(species, .phylo_unique = TRUE,
  ##                                     .indep = TRUE)
  ##   spatial_indep(form)   -> spde(form, .spatial_indep = TRUE)
  diag_is_indep <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "diag") && isTRUE(cs$extra$.indep)
  }, logical(1L))
  is_indep_B <- any(diag_is_indep & groupings == site)
  is_indep_W <- any(diag_is_indep & groupings == ss_name)
  is_indep_cluster <- any(diag_is_indep & groupings == species)
  ## ---- "dep" keyword over-parameterisation guards (run BEFORE indep) -----
  ## `dep(0+trait|g)` rewrites to `rr(form, d = n_traits, .dep = TRUE)`.
  ## Same engine path as `latent(d = n_traits)` standalone (full-rank packed
  ## triangular Lambda IS the Cholesky factor of unstructured Sigma). The
  ## `.dep` marker labels the printed term and triggers these guards:
  ##   * dep + latent on same grouping: over-parameterised
  ##   * dep + unique on same grouping: redundant (dep already includes diag)
  ##   * dep + indep on same grouping: redundant
  ## We run these BEFORE the indep guards so a `dep + indep` user gets the
  ## targeted "redundant" message rather than the more generic
  ## "indep + latent over-parameterised" one (since dep rewrites to an rr
  ## term at the engine level).
  rr_is_dep <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "rr") && isTRUE(cs$extra$.dep)
  }, logical(1L))
  is_dep_B <- any(rr_is_dep & groupings == site)
  is_dep_W <- any(rr_is_dep & groupings == ss_name)
  is_dep_cluster <- any(rr_is_dep & groupings == species)
  for (gname in unique(groupings[rr_is_dep])) {
    ## dep + latent on same grouping: another `rr` term without `.dep` exists.
    has_rr_latent <- any(kinds == "rr" & groupings == gname & !rr_is_dep)
    if (has_rr_latent) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn latent} on the same grouping are over-parameterised.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code latent(0 + trait | {gname}, d = K)} appear in the formula.",
        ">" = "Use {.fn dep} alone for the full unstructured fit, or use {.code latent + unique} (paired) for the decomposition. They cannot coexist."
      ))
    }
    ## dep + unique (any `diag` without `.indep`) on same grouping: redundant.
    has_plain_diag_dep <- any(kinds == "diag" & groupings == gname &
                              !vapply(seq_along(parsed$covstructs), function(i)
                                isTRUE(parsed$covstructs[[i]]$extra$.indep),
                                logical(1L)))
    if (has_plain_diag_dep) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn unique} on the same grouping are redundant.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code unique(0 + trait | {gname})} appear in the formula.",
        ">" = "{.fn dep} standalone already includes the per-trait diagonal -- pick one."
      ))
    }
    ## dep + indep (`diag` with `.indep = TRUE`) on same grouping: redundant.
    has_indep_dep <- any(diag_is_indep & groupings == gname)
    if (has_indep_dep) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn indep} on the same grouping are redundant.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code indep(0 + trait | {gname})} appear in the formula.",
        ">" = "{.fn dep} standalone already includes the per-trait diagonal -- pick one."
      ))
    }
  }
  ## indep + latent on the same grouping (over-parameterised). Skip if the
  ## rr term carries the .dep marker (the dep guards above handle that case
  ## with a more targeted message).
  for (gname in unique(groupings[diag_is_indep])) {
    has_rr   <- any(kinds == "rr" & groupings == gname & !rr_is_dep)
    if (has_rr) {
      cli::cli_abort(c(
        "{.fn indep} and {.fn latent} on the same grouping are over-parameterised.",
        "i" = "Both {.code indep(0 + trait | {gname})} and {.code latent(0 + trait | {gname}, d = K)} appear in the formula.",
        ">" = "Use {.fn indep} alone for the marginal-only fit, or use {.code latent + unique} (paired) for the decomposition. They cannot coexist."
      ))
    }
    ## indep + unique on the same grouping (redundant; both produce
    ## diag(sigma^2_t), but writing both is a confusion and has two
    ## conflicting `extra` lists for the same engine slot).
    has_plain_diag <- any(diag_is_indep == FALSE & kinds == "diag" & groupings == gname)
    if (has_plain_diag) {
      cli::cli_abort(c(
        "{.fn indep} and {.fn unique} on the same grouping are redundant.",
        "i" = "Both {.code indep(0 + trait | {gname})} and {.code unique(0 + trait | {gname})} appear in the formula.",
        ">" = "{.fn indep} standalone and {.fn unique} standalone are mathematically identical -- pick one."
      ))
    }
  }
  ## ---- Phylogenetic keyword resolution ---------------------------------
  ## After rewrite_canonical_aliases(), both phylo_latent(species, d=K) and
  ## phylo_unique(species) appear in `parsed$covstructs` as kind="phylo_rr".
  ## We separate them by inspecting the .phylo_unique marker:
  ##   * phylo_latent (no marker)         -> populates phylo_rr (Lambda_phy)
  ##   * phylo_unique (.phylo_unique=TRUE) -> populates phylo_diag (psi_phy diag)
  ##                                          ALWAYS, never phylo_rr.
  ## When ONLY phylo_unique is present, the engine still works (use_phylo_rr
  ## is FALSE; only the diag block fires). When BOTH are present, they
  ## co-fit as separate components: Sigma_phy = Lambda_phy Lambda_phy^T +
  ## Psi_phy. This is the manuscript-aligned paired PGLLVM decomposition
  ## (Hadfield & Nakagawa 2010; Meyer & Kirkpatrick 2008; Halliwell et al.
  ## 2025).
  phy_idx        <- which(kinds == "phylo_rr")
  ## Design 56 Sec. 9.5a: augmented phylo_latent(1 + x | sp, d = K) routes to a
  ## phylo_rr covstruct carrying the `.latent_slope` marker. It drives the
  ## dedicated block-diagonal reduced-rank latent-slope C++ block
  ## (use_phylo_latent_slope), NOT the intercept-only phylo_rr block, so it is
  ## excluded from both phylo_rr_idx and phylo_diag_idx below.
  phy_is_latent_slope <- vapply(phy_idx, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.latent_slope),
                           logical(1L))
  phy_idx_main   <- phy_idx[!phy_is_latent_slope]
  phylo_latent_slope_idx <- phy_idx[phy_is_latent_slope]
  phy_is_unique  <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.phylo_unique),
                           logical(1L))
  phy_is_indep   <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.indep),
                           logical(1L))
  phy_is_dep     <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.dep),
                           logical(1L))
  phy_kernel_name <- vapply(phy_idx_main, function(i) {
    val <- parsed$covstructs[[i]]$extra$.kernel_name
    if (is.null(val)) NA_character_ else as.character(val)
  }, character(1L))
  has_kernel_term <- any(!is.na(phy_kernel_name))
  kernel_name <- NULL
  if (has_kernel_term) {
    if (any(is.na(phy_kernel_name))) {
      cli::cli_abort(c(
        "{.fn kernel_*} terms cannot be mixed with {.fn phylo_*} terms in C1.",
        "i" = "The dense kernel path reuses the phylo-equivalent engine slot; use either all {.fn kernel_*} terms or all {.fn phylo_*} terms for that tier."
      ))
    }
    if (any(!nzchar(phy_kernel_name))) {
      cli::cli_abort(
        "{.arg name} in {.fn kernel_*} terms must be a non-empty string."
      )
    }
    unique_kernel_names <- unique(phy_kernel_name)
    if (length(unique_kernel_names) != 1L) {
      cli::cli_abort(c(
        "{.fn kernel_*} terms in the same formula must use one {.arg name}.",
        "i" = "Got names: {.val {unique_kernel_names}}."
      ))
    }
    kernel_name <- unique_kernel_names
  }
  phylo_rr_idx   <- phy_idx_main[!phy_is_unique]   # phylo_latent + phylo_dep terms
  phylo_diag_idx <- phy_idx_main[ phy_is_unique]   # phylo_unique terms (incl. phylo_indep)
  if (length(phylo_latent_slope_idx) > 1L)
    cli::cli_abort("Only one augmented {.fn phylo_latent} (random-slope) term is supported per formula.")
  ## ---- phylo_dep over-parameterisation guards --------------------------
  ## `phylo_dep(0+trait|species)` rewrites to `phylo_rr(species, d = n_traits,
  ## .dep = TRUE)`. Same engine path as `phylo_latent(species, d = n_traits)`
  ## standalone (full-rank packed-triangular Lambda_phy IS the Cholesky factor
  ## of unstructured Sigma_phy). The `.dep` marker triggers these guards:
  ##   * phylo_dep + phylo_latent: over-parameterised
  ##   * phylo_dep + phylo_unique: redundant (phylo_dep already includes diag)
  ##   * phylo_dep + phylo_indep:  redundant
  is_phylo_dep <- any(phy_is_dep)
  if (is_phylo_dep) {
    if (any(!phy_is_dep & !phy_is_unique)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_latent} are over-parameterised together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_latent(species, d = K)} appear in the formula.",
        ">" = "Use {.fn phylo_dep} alone for the full unstructured cross-trait phylogenetic fit, or use {.code phylo_latent + phylo_unique} (paired) for the paired phylogenetic decomposition. They cannot coexist."
      ))
    }
    if (any(phy_is_unique & !phy_is_indep)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_unique} are redundant together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_unique(species)} appear in the formula.",
        ">" = "{.fn phylo_dep} standalone already includes the per-trait phylogenetic diagonal -- pick one."
      ))
    }
    if (any(phy_is_indep)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_indep} are redundant together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_indep(0 + trait | species)} appear in the formula.",
        ">" = "{.fn phylo_dep} standalone already includes the per-trait phylogenetic diagonal -- pick one."
      ))
    }
  }
  if (length(phylo_rr_idx) > 1L)
    cli::cli_abort("Only one {.fn phylo_latent} term is supported per formula.")
  if (length(phylo_diag_idx) > 1L)
    cli::cli_abort("Only one {.fn phylo_unique} term is supported per formula.")
  ## ---- phylo_indep over-parameterisation guards ------------------------
  ## phylo_indep is the marginal-only canonical for phylogenetic fits;
  ## same engine as phylo_unique-alone, the .indep marker only changes
  ## the printed label and triggers these guards.
  is_phylo_indep <- any(phy_is_indep)
  if (is_phylo_indep) {
    ## phylo_indep + phylo_latent: over-parameterised (cannot decide
    ## whether trait-level phylogenetic variance lives in the shared
    ## low-rank component or the marginal per-trait component).
    if (length(phylo_rr_idx) > 0L) {
      cli::cli_abort(c(
        "{.fn phylo_indep} and {.fn phylo_latent} are over-parameterised together.",
        "i" = "Both {.code phylo_indep(0 + trait | species)} and {.code phylo_latent(species, d = K)} appear in the formula.",
        ">" = "Use {.fn phylo_indep} alone for the marginal-only phylogenetic fit, or use {.code phylo_latent + phylo_unique} (paired) for the paired phylogenetic decomposition. They cannot coexist."
      ))
    }
    ## phylo_indep + phylo_unique: redundant (both produce diag(sigma^2_phy,t)).
    ## After rewrite, phylo_indep terms ALSO carry .phylo_unique = TRUE, so
    ## "redundant" here means the user wrote phylo_unique() AND phylo_indep()
    ## both — i.e. mixed marker pattern.
    if (sum(phy_is_unique) > 0L && sum(phy_is_indep) > 0L &&
        sum(phy_is_unique) > sum(phy_is_indep)) {
      cli::cli_abort(c(
        "{.fn phylo_indep} and {.fn phylo_unique} are redundant together.",
        "i" = "Both appear in the formula.",
        ">" = "{.fn phylo_indep} standalone and {.fn phylo_unique} standalone are mathematically identical -- pick one."
      ))
    }
  }
  use_phylo_rr   <- length(phylo_rr_idx)   > 0L
  use_phylo_diag <- length(phylo_diag_idx) > 0L
  ## Backward-compat: if ONLY phylo_unique is present, keep the legacy
  ## "phylo_rr with diagonal Lambda" parameterisation so existing fits and
  ## tests stay byte-identical. The new phylo_diag slot only fires when
  ## phylo_unique co-occurs with phylo_latent.
  is_phylo_unique <- use_phylo_diag && !use_phylo_rr
  if (is_phylo_unique) {
    ## Reroute the lone phylo_unique term to the legacy phylo_rr slot
    ## (rank = T, diagonal lambda_constraint added below).
    use_phylo_rr   <- TRUE
    use_phylo_diag <- FALSE
    phylo_rr_idx   <- phylo_diag_idx
    phylo_diag_idx <- integer(0)
  }
  ## IMPORTANT: read engine markers with `[[` (EXACT match), never `$`. The
  ## augmented SPDE-slope markers `.spatial_latent_augmented` /
  ## `.spatial_indep_augmented` have `.spatial_latent` / `.spatial_indep` as a
  ## PREFIX, so the `$` form (cs[["extra"]] accessed via `$.spatial_latent`)
  ## would PARTIAL-MATCH the augmented marker and spuriously flip the
  ## intercept-only flag on (the bug that activated a stray omega_spde_lv block
  ## on the spatial_latent slope path).
  ## spatial_scalar(): rewrites to spde(form, .spatial_scalar = TRUE).
  ## We tie log_tau_spde across traits via the TMB map mechanism so the
  ## per-trait variances collapse to one shared scalar. No C++ change.
  is_spatial_scalar <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra[[".spatial_scalar"]])
  })
  ## spatial_latent(): rewrites to spde(form, .spatial_latent = TRUE, d = K).
  ## K_S shared SPDE fields drive all T traits via a T x K_S loading matrix
  ## Lambda_spde (the spatial analogue of phylo_latent's Lambda_phy). The
  ## TMB template provides a `spde_lv_k` switch that toggles between the
  ## per-trait omega_spde path (used by spatial_unique / spatial_scalar)
  ## and the low-rank Lambda_spde x omega_spde_lv path used here.
  is_spatial_latent <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra[[".spatial_latent"]])
  })
  ## spatial_indep(): rewrites to spde(form, .spatial_indep = TRUE).
  ## Same engine path as spatial_unique-alone (per-trait omega_spde with
  ## independent log_tau per trait). The .spatial_indep marker only changes
  ## the printed label and triggers the spatial_indep+spatial_latent guard.
  is_spatial_indep <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra[[".spatial_indep"]])
  })
  ## spatial_dep(): rewrites to spde(form, .spatial_latent = TRUE,
  ## d = n_traits, .dep = TRUE). Same engine path as
  ## spatial_latent(d = n_traits) standalone (full-rank packed-triangular
  ## Lambda_spde IS the Cholesky factor of unstructured Sigma_spatial). The
  ## .dep marker labels the printed term and triggers these guards:
  ##   * spatial_dep + spatial_latent: over-parameterised (different rank)
  ##   * spatial_dep + spatial_unique: redundant (dep already includes diag)
  ##   * spatial_dep + spatial_indep:  redundant
  spde_idx_for_dep <- which(kinds == "spde")
  spde_is_dep_flag <- vapply(spde_idx_for_dep, function(i)
                             isTRUE(parsed$covstructs[[i]]$extra$.dep),
                             logical(1L))
  is_spatial_dep <- any(spde_is_dep_flag)
  if (is_spatial_dep) {
    ## spatial_dep + spatial_latent: over-parameterised. Detect by counting
    ## spde terms with .spatial_latent but WITHOUT .dep markers (i.e. user
    ## wrote both spatial_dep and spatial_latent on the same coords).
    spde_is_latent <- vapply(spde_idx_for_dep, function(i)
                             isTRUE(parsed$covstructs[[i]]$extra[[".spatial_latent"]]),
                             logical(1L))
    if (any(spde_is_latent & !spde_is_dep_flag)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and {.fn spatial_latent} are over-parameterised together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_latent(0 + trait | coords, d = K)} appear in the formula.",
        ">" = "Use {.fn spatial_dep} alone for the full unstructured cross-trait spatial fit, or use {.fn spatial_latent} (with optional {.fn spatial_unique}) for the rank-reduced decomposition. They cannot coexist."
      ))
    }
    ## spatial_dep + spatial_unique: redundant. spatial_unique = spde with
    ## no markers; detect any spde term with no dep/indep/latent/scalar flag.
    spde_is_plain <- !spde_is_dep_flag & !spde_is_latent &
      !vapply(spde_idx_for_dep, function(i)
              isTRUE(parsed$covstructs[[i]]$extra[[".spatial_indep"]]),
              logical(1L)) &
      !vapply(spde_idx_for_dep, function(i)
              isTRUE(parsed$covstructs[[i]]$extra[[".spatial_scalar"]]),
              logical(1L))
    if (any(spde_is_plain)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and {.fn spatial_unique} are redundant together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_unique(0 + trait | coords)} appear in the formula.",
        ">" = "{.fn spatial_dep} standalone already includes the per-trait spatial diagonal -- pick one."
      ))
    }
    ## spatial_dep + spatial_indep: redundant.
    spde_is_indep_flag <- vapply(spde_idx_for_dep, function(i)
                                 isTRUE(parsed$covstructs[[i]]$extra[[".spatial_indep"]]),
                                 logical(1L))
    if (any(spde_is_indep_flag)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and {.fn spatial_indep} are redundant together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_indep(0 + trait | coords)} appear in the formula.",
        ">" = "{.fn spatial_dep} standalone already includes the per-trait spatial diagonal -- pick one."
      ))
    }
  }
  if (is_spatial_indep && is_spatial_latent && !is_spatial_dep) {
    cli::cli_abort(c(
      "{.fn spatial_indep} and {.fn spatial_latent} are over-parameterised together.",
      "i" = "Both {.code spatial_indep(0 + trait | coords)} and {.code spatial_latent(0 + trait | coords, d = K)} appear in the formula.",
      ">" = "Use {.fn spatial_indep} alone for the marginal-only spatial fit, or use {.fn spatial_latent} (with optional {.fn spatial_unique} for unshared per-trait residual) for the decomposition. They cannot coexist."
    ))
  }
  if (is_spatial_indep && !is_spatial_dep) {
    ## spatial_indep + spatial_unique: redundant (both produce per-trait
    ## independent fields with the SPDE precision). Detect by counting
    ## spde terms with vs. without the .spatial_indep marker.
    spde_idx <- which(kinds == "spde")
    spde_indep_flags <- vapply(spde_idx, function(i)
                               isTRUE(parsed$covstructs[[i]]$extra[[".spatial_indep"]]),
                               logical(1L))
    if (any(!spde_indep_flags) && any(spde_indep_flags)) {
      cli::cli_abort(c(
        "{.fn spatial_indep} and {.fn spatial_unique} are redundant together.",
        "i" = "Both appear in the formula.",
        ">" = "{.fn spatial_indep} standalone and {.fn spatial_unique} standalone are mathematically identical -- pick one."
      ))
    }
  }
  d_spde_lv <- if (is_spatial_latent) {
    cs <- parsed$covstructs[[which(kinds == "spde")[1L]]]
    as.integer(cs$extra$d %||% 1L)
  } else 0L
  d_phy <- if (use_phylo_rr) {
    cs <- parsed$covstructs[[phylo_rr_idx[1L]]]
    if (is_phylo_unique) {
      ## phylo_unique alone (legacy path): D independent variances on phylo
      ## C, implemented as phylo_rr with d = n_traits and a diagonal Lambda
      ## constraint. The diagonal entries become per-trait phylo SDs.
      n_traits_tmp <- nlevels(if (is.factor(data[[trait]])) data[[trait]]
                              else factor(data[[trait]]))
      as.integer(n_traits_tmp)
    } else {
      d_req <- as.integer(cs$extra$d %||% 1L)
      n_traits <- .n_traits_for_dep
      if (d_req > n_traits) {
        cli::cli_abort(
          "phylo_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
        )
      }
      d_req
    }
  } else 1L
  ## Phylogenetic random slope (Q6): phylo_slope(x | species). Reuses
  ## the Ainv_phy_rr from phylo_rr; only one tree / VCV needed even when
  ## both terms appear. Initial release: ONE continuous covariate, ONE
  ## shared slope variance, slopes shared across traits.
  phylo_slope_idx <- which(kinds == "phylo_slope")
  use_phylo_slope <- length(phylo_slope_idx) > 0L
  if (length(phylo_slope_idx) > 1L) {
    cli::cli_abort("Only one phylogenetic random-regression term is supported per formula.")
  }
  phylo_slope_cs <- if (use_phylo_slope) {
    parsed$covstructs[[phylo_slope_idx[1L]]]
  } else NULL
  use_phylo_slope_correlated <- isTRUE(
    phylo_slope_cs$extra$.phylo_unique_augmented
  )
  ## phylo_dep(1 + x | species): the full unstructured 2T x 2T covariance
  ## Sigma_b across the trait-stacked (intercept, slope) random-effect
  ## columns (Design 56 §9.5c). The C++ dep branch is nested under
  ## use_phylo_slope_correlated == 1 (it shares the b_phy_aug random block
  ## and Z_phy_aug design array), so we force the correlated flag on. The
  ## dep-specific overrides below expand n_lhs_cols to 2T, build the
  ## interleaved Z, free theta_dep_chol, and map off log_sd_b / atanh_cor_b
  ## (the unstructured Sigma_b replaces the closed-form 2x2 parameters).
  use_phylo_dep_slope <- isTRUE(phylo_slope_cs$extra$.phylo_dep_augmented)
  use_phylo_slope_correlated <- use_phylo_slope_correlated ||
    use_phylo_dep_slope
  ## phylo_indep(1 + x | species): same augmented b_phy_aug engine as
  ## phylo_unique() but the intercept-slope correlation is fixed at 0. The
  ## `.indep` marker (set by the phylo_indep parser handler) triggers pinning
  ## atanh_cor_b to 0 via the TMB map below. No new C++ likelihood block.
  use_phylo_slope_indep <- use_phylo_slope_correlated &&
    isTRUE(phylo_slope_cs$extra$.indep)
  ## Track B scope (issue #341): the augmented phylo_indep(1 + x | sp) path
  ## is validated for the Gaussian anchor cell, the binomial family
  ## (probit + logit, #381) AND -- this slice -- poisson, nbinom2, Gamma,
  ## Beta, and ordinal_probit. The augmented-slope engine is family-agnostic
  ## -- eta += b_phy_aug . Z_phy_aug is accumulated BEFORE the C++ family
  ## dispatch (src/gllvmTMB.cpp), and phylo_indep only differs from the
  ## family-general phylo_unique() path by pinning atanh_cor_b to 0 via the
  ## TMB map below -- so each family needs ZERO new C++; activation is just
  ## this family-id allowlist relax once a per-family diagonal-Sigma_b
  ## recovery cell passes (test-phylo-indep-slope-nongaussian.R; the binomial
  ## anchor is test-binomial-slope-recovery.R). The allowlist holds the
  ## runtime family ids (family_to_id(), NOT the .valid_family enum):
  ## 0 gaussian, 1 binomial, 2 poisson, 4 Gamma, 5 nbinom2, 7 Beta,
  ## 14 ordinal_probit. Families NOT on this list (e.g. tweedie, student,
  ## the delta / truncated / mixture families) stay reserved fail-loud until
  ## their own recovery cells land. Family is unknown at parse time, so the
  ## reservation is enforced here where family_id_vec exists. The message
  ## keeps the parser's "LHS richer than" phrasing so the contract substring
  ## is unchanged.
  if (use_phylo_slope_indep && any(!family_id_vec %in% c(0L, 1L, 2L, 4L, 5L, 7L, 14L))) {
    cli::cli_abort(c(
      "{.fn phylo_indep} LHS richer than {.code 0 + trait} is not yet supported for this family.",
      "i" = "Augmented {.code phylo_indep(1 + x | species)} is validated for {.code gaussian()}, {.code binomial()} (probit / logit), {.code poisson()}, {.code nbinom2()}, {.code Gamma()}, {.code Beta()}, and {.code ordinal_probit()} in this release.",
      ">" = "Use {.code phylo_unique(1 + x | species)} (family-general) for any other non-Gaussian augmented phylogenetic random regression, or {.code phylo_indep(0 + trait | species)} for the per-trait phylogenetic variance fit."
    ))
  }
  ## phylo_dep(1 + x | species) augmented-slope scope (Design 56 §9.5c):
  ## the full unstructured 2T x 2T Sigma_b path is validated for the Gaussian
  ## anchor cell only in this release. The engine is family-agnostic (eta +=
  ## b_phy_aug . Z_phy_aug is accumulated before the C++ family dispatch), so
  ## construction succeeds for the wired families -- BUT, unlike the diagonal
  ## phylo_indep / block-diagonal phylo_latent paths, the FULL unstructured
  ## C x C (C = 2*n_traits) covariance is not yet identifiable for the
  ## non-Gaussian families at the validation fixtures: every non-Gaussian dep
  ## recovery cell honest-skips at the converge/PD-Hessian guard
  ## (test-matrix-slope-phylo-dep.R; verified empirically across n_sp up to
  ## 100). Per the #388 discipline a family joins this allowlist ONLY after its
  ## recovery cell passes, so non-Gaussian dep stays reserved fail-loud. The
  ## allowlist holds the runtime family id (family_to_id(), NOT the
  ## .valid_family enum): 0 gaussian. Family is unknown at parse time, so the
  ## reservation is enforced here where family_id_vec exists. Fail loud rather
  ## than silently truncate (Design 56 §7).
  if (use_phylo_dep_slope && any(!family_id_vec %in% c(0L))) {
    cli::cli_abort(c(
      "{.fn phylo_dep} LHS richer than {.code 0 + trait} is not yet supported for this family.",
      "i" = "Augmented {.code phylo_dep(1 + x | species)} (full unstructured 2T x 2T covariance) is validated for {.code gaussian()} only in this release.",
      ">" = "Use {.code phylo_dep(0 + trait | species)} for the intercept-only unstructured phylogenetic fit (family-general), or wait for the non-Gaussian dep-slope cells."
    ))
  }
  phylo_slope_lhs_form <- if (use_phylo_slope_correlated) {
    phylo_slope_cs$extra$lhs_form %||% "unsupported"
  } else "legacy_slope"
  phylo_slope_xcol <- if (use_phylo_slope) {
    if (use_phylo_slope_correlated) {
      slope_col <- phylo_slope_cs$extra$slope_col
      if (is.null(slope_col) || !nzchar(slope_col)) {
        cli::cli_abort("Internal: augmented phylogenetic random regression is missing {.code slope_col}.")
      }
      slope_col
    } else {
      deparse(phylo_slope_cs$lhs)
    }
  } else NA_character_

  ## RE-03 multi-slope: the ordered slope-covariate VECTOR for the phylo_dep
  ## augmented path (`phylo_dep(1 + x1 + ... + xs | sp)`, s >= 1). Threaded
  ## from the parser as `extra$slope_cols`; falls back to the scalar
  ## `extra$slope_col` (always length 1) for the single-slope unique/indep
  ## correlated paths and any older call shape. `n_phy_slope` == s drives the
  ## (1+s)T column count and the (1+s)-wide Z fill below. For the legacy
  ## one-column `phylo_slope(x | sp)` and the non-augmented paths it is the
  ## single `phylo_slope_xcol` (s == 1), preserving the existing behaviour.
  phylo_slope_xcols <- if (use_phylo_dep_slope) {
    sc <- phylo_slope_cs$extra$slope_cols %||% phylo_slope_cs$extra$slope_col
    if (is.null(sc) || length(sc) < 1L || !all(nzchar(sc))) {
      cli::cli_abort("Internal: augmented phylo_dep random regression is missing {.code slope_cols}.")
    }
    as.character(sc)
  } else if (!is.na(phylo_slope_xcol)) {
    phylo_slope_xcol
  } else character(0L)
  n_phy_slope <- length(phylo_slope_xcols)

  ## Design 56 Sec. 5.3 / 9.5a: augmented phylo_latent(1 + x | sp, d = K).
  ## Block-diagonal reduced-rank random regression -- each LHS column gets its
  ## own factor-analytic Lambda_k Lambda_k^T (rank d_phy_slope), no intercept-
  ## slope correlation. Drives the dedicated use_phylo_latent_slope C++ block.
  use_phylo_latent_slope <- length(phylo_latent_slope_idx) > 0L
  phylo_latent_slope_cs <- if (use_phylo_latent_slope) {
    parsed$covstructs[[phylo_latent_slope_idx[1L]]]
  } else NULL
  ## Gaussian anchor PLUS the wired non-Gaussian families in this slice. The
  ## block-diagonal reduced-rank latent slope is family-agnostic exactly like
  ## the phylo_indep sweep (#388): the eta contribution is accumulated before
  ## the C++ family dispatch, so each family needs ZERO new C++ and activation
  ## is just this family-id allowlist relax once its per-family recovery cell
  ## passes (test-matrix-slope-phylo-latent.R). The allowlist holds the runtime
  ## family ids (family_to_id(), NOT the .valid_family enum): 0 gaussian,
  ## 1 binomial, 2 poisson, 4 Gamma, 5 nbinom2, 7 Beta, 14 ordinal_probit.
  ## Families NOT on this list stay reserved fail-loud until their own recovery
  ## cells land. Family is unknown at parse time, so the reservation is
  ## enforced here where family_id_vec exists.
  if (use_phylo_latent_slope && any(!family_id_vec %in% c(0L, 1L, 2L, 4L, 5L, 7L, 14L))) {
    cli::cli_abort(c(
      "{.fn phylo_latent} random slopes are not yet supported for this family.",
      "i" = "Augmented {.code phylo_latent(1 + x | species, d = K)} random slopes are validated for {.code gaussian()}, {.code binomial()} (probit / logit), {.code poisson()}, {.code nbinom2()}, {.code Gamma()}, {.code Beta()}, and {.code ordinal_probit()} in this release.",
      ">" = "Use {.code phylo_unique(1 + x | species)} (family-general) for any other non-Gaussian augmented phylogenetic random regression."
    ))
  }
  d_phy_slope <- if (use_phylo_latent_slope) {
    d_req <- as.integer(phylo_latent_slope_cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "phylo_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  phylo_latent_slope_lhs_form <- if (use_phylo_latent_slope) {
    phylo_latent_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  n_lhs_cols_lat <- if (use_phylo_latent_slope) 2L else 1L
  phylo_latent_slope_xcol <- if (use_phylo_latent_slope) {
    sc <- phylo_latent_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort("Internal: augmented phylo_latent random regression is missing {.code slope_col}.")
    }
    sc
  } else NA_character_

  d_B <- if (use_rr_B) {
    cs <- parsed$covstructs[[which(kinds == "rr" & groupings == site)[1]]]
    d_req <- as.integer(cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  d_W <- if (use_rr_W) {
    cs <- parsed$covstructs[[which(kinds == "rr" & groupings == ss_name)[1]]]
    d_req <- as.integer(cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L

  unrecognised <- !(kinds %in% c("rr", "diag", "propto", "equalto", "spde",
                                  "phylo_rr", "phylo_slope", "re_int"))
  if (any(unrecognised)) {
    cli::cli_abort(c(
      "Unsupported covstruct(s) {.val {kinds[unrecognised]}}.",
      "i" = "Supported: {.fn latent}, {.fn unique}, {.fn propto}, {.fn equalto}, {.fn spatial}, {.fn phylo_latent}, {.fn phylo_slope}."
    ))
  }
  ## PGLLVM foot-gun detector (run BEFORE the generic `bad_groups`
  ## check so the user gets the targeted message rather than the
  ## generic "unsupported grouping" one). Two sub-cases:
  ##
  ##   (a) `latent(0 + trait | species, d = K)` (i.e. `rr | species`) at
  ##       `unit != species`: the engine has NO slot for an rr term at the
  ##       cluster grouping. Without `unit = species` this term is silently
  ##       ignored. Hard-abort with a redirect to `unit = species`.
  ##
  ##   (b) `unique(0 + trait | species)` (i.e. `diag | species`) at
  ##       `unit != species`: the engine HAS a slot (`use_diag_species` /
  ##       `q_sp`) for per-trait non-phylo species variance. This is the
  ##       q_it term in the Nakagawa et al. functional-biogeography
  ##       framework (paired with `phylo_unique(species)` for p_it). Empirically
  ##       identifiable when n_species >= 100 in a crossed (site x species)
  ##       design (see `dev/dev-log/after-task/17-phylo-q-guard-investigation.md`):
  ##       sigma2_Q recovers within ~10% relative error; sigma2_P recovers
  ##       within ~50%, with high per-trait variance. Allow the fit but
  ##       inform the user once per session about the regime where it's
  ##       reliable.
  if (use_phylo_rr) {
    species_rr <- any(kinds == "rr"   & groupings == species)
    species_diag <- any(kinds == "diag" & groupings == species)
    if (species_rr && !identical(site, species)) {
      cli::cli_abort(c(
        "Detected {.code phylo_latent({species}) + latent({species}, d = K)} (or equivalent {.fn rr}-{.code | species} term) but {.code unit = {.val {site}}}.",
        "i" = "The engine has no {.val {species}}-level reduced-rank slot when {.code unit != {.val {species}}}; the term would be silently ignored.",
        ">" = "For the three-piece decomposition Omega = Lambda_phy Lambda_phy^T + Lambda_non Lambda_non^T + Psi, pass {.code unit = {.val {species}}} so the {.val {species}}-level {.fn latent} term registers as the between-unit (B) tier."
      ))
    }
    if (species_diag && !identical(site, species)) {
      cli::cli_inform(c(
        "i" = "{.code phylo_unique({species}) + unique(0 + trait | {species})} at {.code unit = {.val {site}}} fits the {.val {species}}-level non-phylogenetic variance via the {.code diag | {species}} ({.code q_sp}) engine slot.",
        "*" = "This is the {.code p_it + q_it} decomposition of the Nakagawa et al. functional-biogeography model. Joint identifiability is empirically reasonable at {.code n_species >= 100} with strong phylogenetic signal: {.code sigma2_Q} recovers within ~10% relative error; {.code sigma2_P} within ~50% (per-trait estimates can be noisy). Compare the fit without the {.code unique({species})} term to the fit with it to confirm both terms contribute on your data."
      ), .frequency = "once",
         .frequency_id = "gllvmTMB-phylo-q-decomposition-inform")
    }
  }
  ## cluster2 foot-gun guard: the engine has no reduced-rank (rr / latent)
  ## slot at the cluster2 tier -- it is diagonal-only (a renamed copy of
  ## the diag_species block). Mirror the cluster-tier `rr | species`
  ## redirect: a `latent(... | cluster2)` / `dep(... | cluster2)` term
  ## aborts pointing the user at `unit = <col>` rather than silently
  ## collapsing (the Sokal silent-collapse lesson). See issue #342.
  if (!is.null(cluster2_col)) {
    rr_cluster2 <- which(kinds == "rr" & groupings == cluster2_col)
    if (length(rr_cluster2) > 0) {
      cli::cli_abort(c(
        "The {.code cluster2} tier is diagonal-only: {.fn latent}/{.fn rr}/{.fn dep} on {.val {cluster2_col}} is not supported.",
        "i" = "Use {.code unique(0 + trait | {cluster2_col})} for the per-trait diagonal variance at the cluster2 slot.",
        ">" = "For a reduced-rank latent structure on {.val {cluster2_col}}, pass {.code unit = {.val {cluster2_col}}} (or {.code unit_obs = {.val {cluster2_col}}}) to {.fn gllvmTMB} instead."
      ))
    }
  }
  ## Diagnostic: error if a rr()/diag() targets an unexpected grouping
  ## that doesn't map to one of the engine's known tiers. cluster2_col
  ## (when set) is an accepted diag grouping.
  allowed_groups <- c(site, ss_name, species, cluster2_col)
  bad_groups <- which(kinds %in% c("rr","diag")
                      & !(groupings %in% allowed_groups))
  if (length(bad_groups) > 0) {
    cli::cli_abort(c(
      "Unsupported grouping {.val {groupings[bad_groups]}} for {.fn rr}/{.fn diag}.",
      "i" = "Supported groupings: {.val {site}}, {.val {ss_name}}, {.val {species}} (slots: unit, unit_obs, cluster).",
      ">" = "If you meant the within-unit grouping, pass {.code unit_obs = {.val {groupings[bad_groups][1]}}} to {.fn gllvmTMB} (the engine maps it to the internal {.val site_species} factor)."
    ))
  }

  ## ---- Generic random intercepts (1 | group) ----------------------------
  re_int_idx <- which(kinds == "re_int")
  use_re_int <- length(re_int_idx) > 0L
  ## Each term gets its own group factor + variance component. We pack all
  ## random intercepts into a single flat vector u_re_int with per-term
  ## offsets so the cpp side can index them with `offset_t + group_id`.
  re_int_groups   <- character(0)        # group column names, length n_re_int_terms
  re_int_offsets  <- integer(0)          # cumulative offsets into u_re_int
  re_int_n_groups <- integer(0)          # n levels of each term's group factor
  re_int_id_mat   <- matrix(0L, nrow = nrow(data), ncol = max(length(re_int_idx), 1L))
  if (use_re_int) {
    for (k in seq_along(re_int_idx)) {
      cs <- parsed$covstructs[[re_int_idx[k]]]
      gname <- as.character(cs$group)
      if (!gname %in% names(data))
        cli::cli_abort(c(
          "{.code (1 | {gname})} found in formula but {.var {gname}} is not a column in {.arg data}.",
          "i" = "Add a {.var {gname}} column to {.arg data} or rename the grouping factor."
        ))
      if (!is.factor(data[[gname]])) data[[gname]] <- factor(data[[gname]])
      re_int_groups[k]   <- gname
      re_int_n_groups[k] <- nlevels(data[[gname]])
      re_int_id_mat[, k] <- as.integer(data[[gname]]) - 1L
    }
    re_int_offsets <- c(0L, cumsum(re_int_n_groups[-length(re_int_n_groups)]))
  }

  ## ---- Build factors and indices ----------------------------------------
  if (!is.factor(data[[trait]])) data[[trait]] <- factor(data[[trait]])
  if (!is.factor(data[[site]]))  data[[site]] <- factor(data[[site]])
  if (!is.factor(data[[species]])) data[[species]] <- factor(data[[species]])
  if (!ss_name %in% names(data))
    data[[ss_name]] <- factor(paste(data[[site]], data[[species]], sep = "_"))
  if (!is.factor(data[[ss_name]])) data[[ss_name]] <- factor(data[[ss_name]])

  n_traits        <- nlevels(data[[trait]])
  n_sites         <- nlevels(data[[site]])
  n_site_species  <- nlevels(data[[ss_name]])

  ## ---- Phase 2a: validate mi() BEFORE the design matrix -----------------
  ## gll_prepare_mi_setup is data-free; running it here fires the loud mi()
  ## guards (exactly one, bare predictor, additive, impute LHS/name, no nested
  ## mi, fixed-effect-only covariate model) before model.matrix tries to
  ## evaluate any stripped-but-invalid mi() expression (e.g. mi(log(x))).
  mi_setup <- gll_prepare_mi_setup(parsed$mi_rhs, impute, missing)

  ## Guard (GAP-6 / issue #399): the bare mi() variable reused in a transformed
  ## or interacted term (e.g. y ~ mi(x) + I(x^2), or mi(x) + x:z). mi() imputes
  ## ONLY the bare broadcast column; a transform / interaction of the same raw
  ## variable still carries NA, which would otherwise trip the generic "NA in
  ## the fixed-effect design matrix" abort below and MISATTRIBUTE the cause.
  ## Detect the reuse up front and name it precisely. The mi() variable is the
  ## bare term itself; any OTHER fixed term whose variables include it is a
  ## reuse (the parser already rejects mi(x) inside transforms / interactions,
  ## so the offending term here is an un-wrapped raw reuse).
  if (isTRUE(mi_setup$enabled)) {
    mi_var <- mi_setup$variable
    fixed_term_labels <- attr(
      stats::terms(parsed$fixed), "term.labels"
    )
    reuse_terms <- Filter(
      function(lbl) {
        !identical(lbl, mi_var) && (mi_var %in% all.vars(stats::reformulate(lbl)))
      },
      fixed_term_labels
    )
    if (length(reuse_terms) > 0L) {
      cli::cli_abort(c(
        "The {.fn mi} variable {.val {mi_var}} cannot also appear in a transformed or interacted term.",
        "x" = "Found {.code {reuse_terms}} alongside {.code mi({mi_var})}.",
        "i" = "{.fn mi} imputes only the bare broadcast column; a transform or interaction of {.val {mi_var}} would still carry the raw {.code NA}s. Use a single bare {.code mi({mi_var})}."
      ))
    }
  }

  ## Phase 5a (design 68): a BINARY mi() predictor must enter the fixed design
  ## as a SINGLE numeric 0/1 column literally named `var` (so the delta-swap
  ## targets one column). A 2-level factor / logical / character predictor
  ## would otherwise expand to a contrast column named `varTRUE` / `var1`, and
  ## the single-broadcast-column contract (the mu_col match below) would fail.
  ## Code it to numeric 0/1 here -- BEFORE model.matrix -- capturing the
  ## original level labels for the registry; the bare-formula model.matrix and
  ## the impute model.frame then both see the numeric column. Mirrors drmTMB,
  ## which codes the binary predictor to numeric before building the design.
  mi_binary_levels <- character(0)
  if (isTRUE(mi_setup$enabled) && identical(mi_setup$family, "bernoulli")) {
    mi_var <- mi_setup$variable
    if (!mi_var %in% names(data)) {
      cli::cli_abort(c(
        "Internal error: the binary {.fn mi} predictor {.val {mi_var}} is not a data column.",
        "i" = "Expected {.val {mi_var}} in the model data."
      ))
    }
    coded <- gll_binary_mi_response(data[[mi_var]], mi_var)
    data[[mi_var]] <- coded$value
    mi_binary_levels <- coded$levels
  }

  ## ---- Build fixed-effects design matrix --------------------------------
  ## We use the full data env so that 0 + trait + (0+trait):env etc. parses.
  mf <- stats::model.frame(parsed$fixed, data = data, na.action = stats::na.pass)
  X_fix <- stats::model.matrix(parsed$fixed, mf)
  ## Strip an unwanted (Intercept) column if the user wrote `~1 + …`.
  has_int <- "(Intercept)" %in% colnames(X_fix)

  y_raw <- stats::model.response(mf)
  ## Multi-trial binomial via Wilkinson `cbind(succ, fail) ~ ...`:
  ## `model.response()` returns a 2-column matrix. Split into a length-n
  ## success vector `y` and a length-n trial-count vector `n_trials`. For
  ## any other LHS, default to `n_trials = 1` (Bernoulli for binomial
  ## rows; unused inside TMB for non-binomial families).
  if (is.matrix(y_raw) && ncol(y_raw) == 2L) {
    succ <- as.numeric(y_raw[, 1L])
    fail <- as.numeric(y_raw[, 2L])
    if (any(succ < 0) || any(fail < 0))
      cli::cli_abort("cbind(successes, failures): both columns must be non-negative.")
    y         <- succ
    n_trials  <- succ + fail
    if (any(n_trials <= 0))
      cli::cli_abort("cbind(successes, failures): rows with zero trials are not allowed.")
  } else {
    y <- as.numeric(y_raw)
    ## Optional API (B): when binomial rows are present, `weights = n_trials`
    ## is interpreted as the per-row trial count (alternative glmmTMB API).
    ## For non-binomial rows we instead route `weights` to the lme4-style
    ## per-observation likelihood multiplier (`weights_i` below). The
    ## decision per-row is made just before tmb_data is built.
    has_binom <- any(family_id_vec == 1L)
    if (has_binom && !is.null(weights) && is.numeric(weights) &&
        length(weights) == nrow(data)) {
      n_trials <- as.numeric(weights)
      if (any(!is.finite(n_trials)) || any(n_trials <= 0))
        cli::cli_abort("`weights` (used as binomial size) must be positive and finite.")
    } else {
      n_trials <- rep(1, length(y))
    }
  }
  n_obs <- length(y)

  ## ---- Phase 1 response mask (design 59 sec.4b / sec.9) ------------------
  ## `is_y_observed` is the long-format observed-response indicator (1/0),
  ## length n_obs, aligned with `y`. When NULL (the response="drop" default,
  ## or any internal caller) every row is observed -> all-ones, an exact
  ## no-op. For response="include", masked rows carry an NA `y`; replace it
  ## with a safe sentinel (0) so the value never reaches a family density --
  ## the C++ `if (is_y_observed(o))` gate guarantees the sentinel does not
  ## enter the likelihood (sentinel-invariance, sec.9).
  if (is.null(is_y_observed)) {
    is_y_observed <- rep(1L, n_obs)
  } else {
    is_y_observed <- as.integer(is_y_observed)
    if (length(is_y_observed) != n_obs)
      cli::cli_abort(c(
        "Internal error: {.code is_y_observed} length mismatch.",
        "i" = "Got length {length(is_y_observed)}; expected {n_obs}."
      ))
  }
  masked_response <- is_y_observed == 0L
  if (any(masked_response)) {
    y[masked_response] <- 0   # sentinel; gated out by is_y_observed in TMB
  }

  ## ---- lme4 / glmmTMB-style observation weights -------------------------
  ## For each row, dispatch on family:
  ##   * binomial (fid 1): weights_i = 1 (the user-supplied `weights` is
  ##     already absorbed into `n_trials` above as the trial count, so
  ##     applying it again would double-count it).
  ##   * non-binomial: weights_i = weights[i] when `weights` is supplied
  ##     (lme4 / glmmTMB convention: per-row log-likelihood multiplier).
  ## Default `weights = NULL` produces a length-n_obs vector of 1.0 — the
  ## new code path is an exact no-op for unweighted fits. Mirrors the
  ## sdmTMB single-engine pattern at src/gllvmTMB.cpp:162 / 1136.
  if (!is.null(weights)) {
    if (!is.numeric(weights) || length(weights) != n_obs)
      cli::cli_abort(c(
        "`weights` must be a numeric vector of length nrow(data).",
        "i" = "Got length {length(weights)}; expected {n_obs}."
      ))
    if (any(!is.finite(weights)))
      cli::cli_abort("`weights` must be finite.")
    if (any(weights < 0))
      cli::cli_abort("`weights` must be non-negative.")
    weights_i <- as.numeric(weights)
    weights_i[family_id_vec == 1L] <- 1.0
  } else {
    weights_i <- rep(1.0, n_obs)
  }
  trait_id        <- as.integer(data[[trait]]) - 1L
  site_id         <- as.integer(data[[site]]) - 1L
  site_species_id <- as.integer(data[[ss_name]]) - 1L

  ## ---- Phase 2a/2b/2c missing-PREDICTOR layer (design 67) ---------------
  ## Detect + validate mi(x), build the latent-level Gaussian covariate model,
  ## and locate the broadcast mi() column in X_fix. The latent-bearing level is
  ## the wide-row unit (Phase 2a/2b, one x per `site`) OR -- when the covariate
  ## model carries a `mi_group(g)` marker (Phase 2c, design 67 sec.2.1 / 69
  ## sec.4.1) -- a coarser group `g`, so the latent x_mis has one entry per
  ## missing LEVEL and `mi_unit_id` (= the resolved long-row -> level map)
  ## broadcasts x_full(level) to every long row. When no mi() term is present
  ## this is an exact no-op (empty model, has_mi = 0). `mi_setup` was validated
  ## earlier (before the design matrix); reuse it.
  if (isTRUE(mi_setup$enabled)) {
    mi_colname <- mi_setup$variable
    mi_col <- match(mi_colname, colnames(X_fix))
    if (is.na(mi_col)) {
      cli::cli_abort(c(
        "Internal error: the {.fn mi} predictor {.val {mi_colname}} is not a column of the fixed-effects design matrix.",
        "i" = "Expected a single broadcast column named {.val {mi_colname}}."
      ))
    }
    ## Phase 5a: dispatch the predictor-model builder by family. The Gaussian
    ## continuous path (mi_family == 0) is integrated by a Laplace latent x_mis;
    ## the binary discrete path (mi_family == 1, design 68) has NO latent and is
    ## summed out exactly in the engine.
    mi_model <- if (identical(mi_setup$family, "bernoulli")) {
      m <- gll_build_binary_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
      ## Restore the ORIGINAL level labels captured before the data was coded to
      ## numeric 0/1 (the build re-read the now-numeric column as c("0","1")).
      if (length(mi_binary_levels) == 2L) m$levels <- mi_binary_levels
      m
    } else {
      gll_build_gaussian_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
    }
    ## PORT-INVARIANT (single-source): the mi() design column X_fix[, mi_col]
    ## MUST be the SAME level-broadcast imputed vector (mi_x_unit) that is fed
    ## to the latent covariate density in the engine. We overwrite the whole
    ## column from mi_x_unit broadcast by the SAME long-row -> level map
    ## (`mi_model$unit_id`, = site_id at unit level, = the mi_group() level map
    ## at Phase 2c), so the delta-correction
    ##   eta(o) += b_fix(mi_col) * (x_full(level) - X_fix(o, mi_col))
    ## cancels EXACTLY at observed rows (x_full == X_fix == observed x) and only
    ## swaps the placeholder for x_mis at missing rows. Using `mi_model$unit_id`
    ## (NOT site_id) keeps the design column and the C++ `mi_unit_id` sourced
    ## from ONE map at any level -- a Phase-2c group whose broadcast differed
    ## from the density's would bias eta and "finite + converged" would not
    ## catch it (coordinator audit point 1).
    X_fix[, mi_col] <- mi_model$x_unit[mi_model$unit_id + 1L]
  } else {
    mi_model <- gll_empty_mi_model()
  }
  use_mi_predictor <- isTRUE(mi_model$enabled)

  ## Guard (BUG-4 / issue #399): an mi() variable used ALSO as a structured
  ## random-slope covariate is rejected. mi() imputes only the broadcast FIXED
  ## column (X_fix[, mi_col]); the structured-slope covariate columns
  ## (phylo_slope / spatial / phylo_latent / spatial_latent) live in the Z
  ## design and read RAW data[[var]] -- which still carries NA -- so they escape
  ## the X_fix NA guard and leak NA -> NaN eta -> opaque non-convergence. Fail
  ## loud BEFORE MakeADFun rather than ship a NaN objective.
  if (use_mi_predictor) {
    mi_var <- mi_setup$variable
    structured_slope_cols <- c(
      if (use_spde_slope) spde_slope_xcol,
      if (use_spde_latent_slope) spde_latent_slope_xcol,
      if (use_phylo_slope) phylo_slope_xcol,
      if (use_phylo_latent_slope) phylo_latent_slope_xcol
    )
    if (mi_var %in% structured_slope_cols) {
      cli::cli_abort(c(
        "The {.fn mi} variable {.val {mi_var}} is also used as a structured random-slope covariate.",
        "x" = "{.fn mi} imputes only the broadcast fixed column; a structured slope (e.g. {.code phylo_slope({mi_var} | ...)}, {.code spatial(1 + {mi_var} | ...)}, {.code phylo_latent(1 + {mi_var} | ...)}) reads the raw {.val {mi_var}} with its {.code NA}s.",
        "i" = "Use {.fn mi} on {.val {mi_var}} OR a structured slope on it, not both."
      ))
    }
  }

  ## ---- Phase 3 phylogenetic covariate model (design 69) -----------------
  ## When the impute RHS carried phylo(1 | species, tree =), the covariate field
  ## g_x ~ N(0, A) reuses the EXISTING sparse Ainv_phy_rr (no new precision).
  ## Two requirements (design 69 sec.2.2 / 5.4):
  ##   (a) the phylo grouping column must be the `species` (cluster) grouping --
  ##       Ainv_phy_rr is keyed to levels(data[[species]]); a different column
  ##       cannot reuse it.
  ##   (b) one tree per fit (Q3): inject the covariate tree as `phylo_tree` so
  ##       the existing Stage-40 builder constructs Ainv_phy_rr from it. When a
  ##       response phylo term also supplies a tree, they must AGREE (topology);
  ##       a differing covariate tree is a Phase-4 multi-tree concern -> error.
  use_mi_phylo <- use_mi_predictor && isTRUE(mi_model$phylo$enabled)
  if (use_mi_phylo) {
    if (!identical(mi_model$phylo$group, species)) {
      cli::cli_abort(c(
        "The {.fn phylo} covariate grouping must be the species (cluster) grouping {.val {species}}.",
        "x" = "Found {.code phylo(1 | {mi_model$phylo$group})}, but the fit's species grouping is {.val {species}}.",
        "i" = "The covariate phylogenetic field reuses the species tree; group it by {.val {species}}."
      ))
    }
    cov_tree <- mi_model$phylo$tree
    if (is.null(cov_tree) && is.null(phylo_tree)) {
      cli::cli_abort(c(
        "The {.fn phylo} covariate model needs a tree.",
        "i" = "Pass it on the token: {.code phylo(1 | {species}, tree = tree)}, or supply {.arg phylo_tree} to {.fn gllvmTMB}."
      ))
    }
    if (!is.null(cov_tree)) {
      if (!inherits(cov_tree, "phylo"))
        cli::cli_abort("The {.fn phylo} covariate {.code tree =} must be an {.cls ape::phylo} tree.")
      if (is.null(phylo_tree)) {
        phylo_tree <- cov_tree
      } else if (!identical(phylo_tree$tip.label, cov_tree$tip.label)) {
        cli::cli_abort(c(
          "The {.fn phylo} covariate tree differs from the response phylogenetic tree.",
          "i" = "One tree per fit in this version; the covariate and response phylo terms must share a tree (multi-tree is a later phase)."
        ))
      }
    }
  }

  if (any(is.na(y[!masked_response]))) {
    cli::cli_abort(c(
      "NA in an observed response reached the fitting engine.",
      "i" = "Public {.fn gllvmTMB} drops (response = \"drop\") or masks (response = \"include\") missing response rows before fitting; please report this internal preprocessing failure."
    ))
  }
  if (any(is.na(X_fix))) {
    cli::cli_abort(c(
      "NA in the fixed-effect design matrix.",
      "i" = "Missing response rows are allowed and dropped before fitting; missing predictors still need to be removed or imputed before fitting (or declared with {.code mi()} under {.code missing = miss_control(predictor = \"model\")})."
    ))
  }
  ## The family-specific response-range checks below validate the *observed*
  ## response only. Masked rows (response = "include") carry the sentinel y = 0
  ## which is gated out of the likelihood; it must not trip a range check.
  ## When nothing is masked this is identical to checking every row.
  bin_rows <- (family_id_vec == 1L) & !masked_response
  if (any(bin_rows)) {
    if (any(y[bin_rows] < 0) || any(y[bin_rows] > n_trials[bin_rows]))
      cli::cli_abort(c(
        "Binomial rows: `y` (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers."
      ))
  }
  ## Beta rows: y must be in the open unit interval (0, 1). The likelihood
  ## clips y away from the boundaries internally for numerical safety, but
  ## a y of exactly 0 or 1 is a hint that the user wants a zero/one-inflated
  ## Beta or a different family (Smithson & Verkuilen 2006).
  beta_rows <- (family_id_vec == 7L) & !masked_response
  if (any(beta_rows)) {
    if (any(y[beta_rows] <= 0) || any(y[beta_rows] >= 1))
      cli::cli_abort(c(
        "Beta rows: {.code y} must satisfy 0 < y < 1.",
        "i" = "Exact 0s or 1s require a zero-/one-inflated Beta variant."
      ))
  }
  ## Beta-binomial rows: y must be in [0, n_trials], same as binomial.
  bb_rows <- (family_id_vec == 8L) & !masked_response
  if (any(bb_rows)) {
    if (any(y[bb_rows] < 0) || any(y[bb_rows] > n_trials[bb_rows]))
      cli::cli_abort(c(
        "Beta-binomial rows: `y` (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers."
      ))
  }
  ## Sanity check: y >= 1 for zero-truncated count families.
  trunc_rows <- which((family_id_vec %in% c(10L, 11L)) & !masked_response)
  if (length(trunc_rows) > 0L) {
    bad <- trunc_rows[y[trunc_rows] < 1 | y[trunc_rows] != round(y[trunc_rows])]
    if (length(bad) > 0L) {
      shown    <- utils::head(bad, 10)
      ellipsis <- if (length(bad) > 10) ", ..." else ""
      cli::cli_abort(c(
        "Zero-truncated count families ({.code truncated_poisson()}, {.code truncated_nbinom2()}) require positive integer responses (y >= 1).",
        "i" = paste0("Offending row indices: ", paste(shown, collapse = ", "), ellipsis, "."),
        ">" = "Drop zero rows from {.arg data} before fitting, or use {.code poisson()} / {.code nbinom2()} instead."
      ))
    }
  }
  ## Delta (hurdle) families: y must be non-negative (zeros = absence,
  ## positives = presence + abundance). The log y term inside the TMB
  ## switch is gated on y > 0, so negative y would silently propagate.
  delta_rows <- (family_id_vec %in% c(12L, 13L)) & !masked_response
  if (any(delta_rows)) {
    if (any(y[delta_rows] < 0))
      cli::cli_abort(c(
        "Delta families: response must be non-negative (zero or positive).",
        "i" = "{.fn delta_lognormal}/{.fn delta_gamma} are hurdle models with an exact zero point mass + continuous positive part."
      ))
  }

  ## ---- ordinal_probit (fid 14): cutpoint metadata ---------------------
  ## For each ordinal trait t, count K_t = number of distinct categories
  ## observed (1..K_t after coercing to integer). The engine estimates
  ## K_t - 2 free cutpoints per trait (tau_1 = 0 fixed). Build the flat
  ## n_ordinal_cuts_per_trait + ordinal_offset_per_trait vectors so the
  ## engine can index into ordinal_log_increments per trait. Reference:
  ## Hadfield (2015) MEE 6:706-714, eqn 9.
  any_ordinal_probit <- any(family_id_vec == 14L)
  n_ordinal_cuts_per_trait  <- integer(n_traits)
  ordinal_offset_per_trait  <- integer(n_traits)
  ordinal_K_per_trait       <- integer(n_traits)
  ordinal_init_log_incs     <- numeric(0)
  if (any_ordinal_probit) {
    ordinal_rows <- family_id_vec == 14L
    ## Validate the observed ordinal responses only; masked rows carry the
    ## sentinel y = 0 (gated out of the likelihood) and must not trip these.
    ordinal_obs_rows <- ordinal_rows & !masked_response
    if (any(y[ordinal_obs_rows] != round(y[ordinal_obs_rows])))
      cli::cli_abort(c(
        "ordinal_probit: response must be integer-valued (categories 1..K).",
        "i" = "Coerce {.var y} via {.code as.integer(factor(y))} or pass an ordered factor."
      ))
    if (any(y[ordinal_obs_rows] < 1))
      cli::cli_abort(c(
        "ordinal_probit: response must be in {.val 1..K} (1-indexed).",
        "i" = "Smallest observed category was {min(y[ordinal_obs_rows])}; categories must start at 1."
      ))
    cum_offset <- 0L
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L) & family_id_vec == 14L)
      if (length(rows_t) == 0L) {
        ordinal_offset_per_trait[t] <- cum_offset
        next
      }
      ## Mixing ordinal_probit with another family on the SAME trait makes
      ## no sense (cutpoints are per-trait). The mixed-family API allows
      ## one family per row, but ordinal_probit must own its trait entirely.
      rows_t_all <- which(trait_id == (t - 1L))
      if (any(family_id_vec[rows_t_all] != 14L))
        cli::cli_abort(c(
          "ordinal_probit on trait {t}: other rows of this trait use a different family.",
          "i" = "ordinal_probit must own all rows of a trait (cutpoints are estimated per trait)."
        ))
      Kt <- max(as.integer(y[rows_t]))
      if (Kt < 2L)
        cli::cli_abort(c(
          "ordinal_probit: trait {t} has only {Kt} observed categor{?y/ies}.",
          "i" = "Need at least K = 2 categories to define a likelihood."
        ))
      if (Kt == 2L) {
        ## Hadfield (2015) eqn 10: K = 2 ordinal_probit reduces EXACTLY to
        ## binomial(link = "probit") with no free cutpoints (tau_1 = 0 is
        ## the only threshold). We allow this for backward-compatibility
        ## checks and to verify the mathematical reduction empirically,
        ## but recommend the binomial form for clarity.
        cli::cli_inform(c(
          "i" = "{.fn ordinal_probit} with K = 2 reduces exactly to {.code binomial(link = \"probit\")} (Hadfield 2015 eqn 10).",
          "*" = "Both forms give identical likelihoods; consider using {.code binomial(link = \"probit\")} for clarity."
        ))
      }
      if (any(y[rows_t] > Kt))
        cli::cli_abort(c(
          "ordinal_probit: trait {t} response exceeds inferred K = {Kt}.",
          "i" = "All observed categories must lie in 1..K; check for missing intermediate levels."
        ))
      ordinal_K_per_trait[t]      <- Kt
      n_ordinal_cuts_per_trait[t] <- Kt - 2L
      ordinal_offset_per_trait[t] <- cum_offset
      cum_offset <- cum_offset + (Kt - 2L)
      ## Initialise log-spacings via MASS::polr (uses zeta, the cutpoints).
      ## Convert zeta to log-increments respecting our convention: shift so
      ## zeta_1 -> 0, then log-difference. With Kt = 3 there's exactly one
      ## free cutpoint and the increment is log(zeta_2 - zeta_1).
      init_log_incs_t <- if (requireNamespace("MASS", quietly = TRUE) &&
                              length(rows_t) >= max(20L, 4L * Kt)) {
        polr_dat <- data.frame(
          y_factor = factor(y[rows_t], levels = seq_len(Kt), ordered = TRUE)
        )
        polr_fit <- tryCatch(
          MASS::polr(y_factor ~ 1, data = polr_dat, method = "probit"),
          error = function(e) NULL
        )
        if (!is.null(polr_fit)) {
          zeta_t  <- as.numeric(polr_fit$zeta)
          ## Shift so zeta[1] = 0: tau_2 = zeta[2] - zeta[1], etc.
          tau_t   <- zeta_t[-1L] - zeta_t[1L]
          incs_t  <- diff(c(0, tau_t))
          ## Guard non-positive increments (rare but possible in corner cases).
          incs_t  <- pmax(incs_t, 1e-3)
          log(incs_t)
        } else NULL
      } else NULL
      if (is.null(init_log_incs_t)) {
        ## Fallback: equal spacing of 0.5 between consecutive cutpoints.
        init_log_incs_t <- rep(log(0.5), Kt - 2L)
      }
      ordinal_init_log_incs <- c(ordinal_init_log_incs, init_log_incs_t)
    }
  }

  ## ---- Theta lengths ----------------------------------------------------
  rr_theta_len <- function(p, rank) p * rank - rank * (rank - 1L) / 2L
  theta_rr_B_len <- if (use_rr_B) rr_theta_len(n_traits, d_B) else 1L
  theta_rr_W_len <- if (use_rr_W) rr_theta_len(n_traits, d_W) else 1L

  ## ---- Initial values via PCA of residuals ------------------------------
  ## Quick OLS initial estimate of b_fix. For multi-trial binomial rows
  ## (n_trials > 1) we OLS on the empirical logit so the initial b_fix is
  ## on the link scale; otherwise lm.fit on raw success counts can yield
  ## intercepts of ~mean(succ) which are way off the logit scale and the
  ## inner Newton diverges. Bernoulli rows (n_trials == 1) and non-binomial
  ## rows keep the previous behaviour exactly.
  has_multi_trial <- any(family_id_vec == 1L) && any(n_trials > 1)
  ## Beta-binomial rows behave like multi-trial binomial for initialisation:
  ## empirical-logit on y/n is the right scale for the logit-link b_fix.
  has_betabinom_trial <- any(family_id_vec == 8L) && any(n_trials > 1)
  ## Log-link families (nbinom2, tweedie, also poisson / lognormal / Gamma):
  ## OLS on log(y + small) is a much better init for b_fix than raw y, which
  ## can blow up the inner Newton when mu = exp(eta) starts at exp(mean(y)).
  ## Restrict to the cases where we know it helps (count/biomass families)
  ## to avoid changing existing behaviour for Gaussian / binomial fits.
  ## Includes delta families (12/13) which use a log link on the positive
  ## component (and zeros are well-handled by log(0 + 0.5)) and the
  ## truncated count families (10/11) which use a log link.
  log_link_only <- all(family_id_vec %in% c(2L, 3L, 4L, 5L, 6L, 10L, 11L, 12L, 13L, 15L))
  ## Beta family init: empirical-logit on y in (0, 1) gives a much better
  ## starting b_fix than raw y on the (0,1) scale (the latter can leave the
  ## inner Newton stuck when mu = invlogit(eta) is far from y).
  beta_only <- all(family_id_vec == 7L)
  ## ordinal_probit init: project y onto the latent probit scale via
  ## qnorm((y - 0.5) / K) per trait. This puts categories on the same scale
  ## as eta + N(0,1) and avoids fit_lm starting b_fix at the integer-mean
  ## scale (e.g. 2.5 for K=4), which is far from the probit-link interior.
  ordinal_only <- all(family_id_vec == 14L)
  if (has_multi_trial || has_betabinom_trial) {
    p_emp  <- pmin(pmax(y / n_trials, 0.5 / pmax(n_trials, 1)),
                   1 - 0.5 / pmax(n_trials, 1))
    z_init <- log(p_emp / (1 - p_emp))
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (log_link_only && all(y >= 0)) {
    z_init <- log(y + 0.5)
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (beta_only && all(y > 0 & y < 1)) {
    z_init <- log(y / (1 - y))
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (ordinal_only) {
    z_init <- numeric(length(y))
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) next
      Kt <- ordinal_K_per_trait[t]
      ## Empirical-quantile init: q = (rank - 0.5) / N then qnorm(q).
      ## With small samples this can produce -Inf at extremes; clip.
      ranks_t <- rank(y[rows_t], ties.method = "average")
      q_t <- pmin(pmax((ranks_t - 0.5) / length(rows_t), 0.01), 0.99)
      z_init[rows_t] <- stats::qnorm(q_t)
    }
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else {
    fit_lm <- stats::lm.fit(X_fix, y)
  }
  b_fix_init <- fit_lm$coefficients
  resid_init <- fit_lm$residuals
  ## Guard against numerical zero residuals (degenerate single-row case).
  log_sigma_eps_init <- log(max(stats::sd(resid_init), 1e-3))

  ## ---- Phase L: harvest per-term `tree = ...` / `vcv = ...` overrides -------
  ## Phase L (May 2026): users can now write
  ##   `phylo_latent(species, d = K, tree = my_tree)` or
  ##   `phylo_unique(species, vcv = Cphy)`
  ## as an alternative to passing `phylo_tree =` / `phylo_vcv =` globally
  ## to `gllvmTMB()`. Per-term wins; if both global and per-term are set
  ## they must agree (per-term takes precedence with a soft inform).
  ## Multiple phylo terms must agree on the tree / vcv.
  for (i in seq_along(parsed$covstructs)) {
    cs <- parsed$covstructs[[i]]
    if (cs$kind %in% c("phylo_rr", "propto", "phylo_slope")) {
      tree_inkey <- cs$extra$tree
      vcv_inkey  <- cs$extra$vcv
      if (!is.null(tree_inkey) && inherits(tree_inkey, "phylo")) {
        if (is.null(phylo_tree)) {
          phylo_tree <- tree_inkey
        } else if (!identical(phylo_tree$tip.label, tree_inkey$tip.label)) {
          cli::cli_warn(c(
            "{.code tree =} inside a phylo keyword disagrees with the global {.arg phylo_tree}.",
            "i" = "Using the global {.arg phylo_tree}; remove one to silence this warning."
          ))
        }
      }
      if (!is.null(vcv_inkey) &&
          (is.matrix(vcv_inkey) || inherits(vcv_inkey, "sparseMatrix"))) {
        ## Design 47 follow-on (2026-05-18): the sparseMatrix branch
        ## carries pre-computed A^{-1} from `pedigree_to_Ainv_sparse()`
        ## (via the animal_*(pedigree=ped) sugar) or from a user-supplied
        ## sparse Ainv. The fit-multi.R phylo VCV preparation block
        ## detects sparse input and uses it directly as Ainv_phy_rr.
        if (is.null(phylo_vcv)) {
          phylo_vcv <- vcv_inkey
        } else if (!identical(dim(phylo_vcv), dim(vcv_inkey))) {
          cli::cli_warn(c(
            "{.code vcv =} inside a phylo keyword disagrees with the global {.arg phylo_vcv}.",
            "i" = "Using the global {.arg phylo_vcv}; remove one to silence this warning."
          ))
        }
      }
    }
    if (cs$kind == "spde") {
      mesh_inkey <- cs$extra$mesh
      if (!is.null(mesh_inkey) && is.null(mesh)) mesh <- mesh_inkey
    }
  }

  ## ---- cluster2 grouping id (0-indexed for C++) ------------------------
  ## Mirrors species_id. When the cluster2 slot is inactive (no diag term
  ## on the cluster2 column, or cluster2 = NULL) we still pass a length-1
  ## grouping so the (mapped-off) r_c2 parameter has a valid shape.
  if (use_diag_cluster2) {
    if (!is.factor(data[[cluster2_col]])) {
      data[[cluster2_col]] <- factor(data[[cluster2_col]])
    }
    n_cluster2  <- nlevels(data[[cluster2_col]])
    cluster2_id <- as.integer(data[[cluster2_col]]) - 1L
  } else {
    n_cluster2  <- 1L
    cluster2_id <- integer(nrow(data))
  }

  ## ---- Phylogenetic VCV preparation (propto + phylo_latent) -----------------
  n_species <- nlevels(data[[species]])
  species_id <- as.integer(data[[species]]) - 1L
  Cphy_inv      <- matrix(0, n_species, n_species)
  log_det_Cphy  <- 0
  Ainv_phy_rr      <- Matrix::Matrix(0, n_species, n_species, sparse = TRUE)
  log_det_A_phy_rr <- 0
  n_aug_phy        <- n_species
  species_aug_id   <- species_id        # default: tip-only path uses species_id directly
  ## Build the sparse A^-1 machinery whenever any phylogenetic term
  ## (phylo_latent, phylo_unique, phylo_slope, or the augmented latent-slope)
  ## is requested. They share Ainv_phy_rr, n_aug_phy, log_det_A_phy_rr, and
  ## species_aug_id.
  ## Phase 3: the phylogenetic covariate model also needs Ainv_phy_rr (built
  ## from the same species tree). Including use_mi_phylo here makes the existing
  ## Stage-40 builder construct the sparse precision even when the RESPONSE side
  ## has no phylo term (design 69 sec.2.2).
  use_any_phy_term <- use_phylo_rr || use_phylo_diag || use_phylo_slope ||
    use_phylo_latent_slope || use_mi_phylo
  if (use_any_phy_term) {
    if (!is.null(phylo_tree)) {
      ## --- Stage 40: TRUE Hadfield sparse-A^-1 trick ----------------------
      ## A^-1 is built over tips + internal nodes via MCMCglmm::inverseA.
      ## At n_tips = 1000 this gives ~6k non-zeros instead of ~676k (113x
      ## sparser); the speedup is realised in TMB's sparse matvecs.
      if (!requireNamespace("MCMCglmm", quietly = TRUE))
        cli::cli_abort(c(
          "{.pkg MCMCglmm} is required for the {.code phylo_tree} path.",
          "i" = "Install it via {.code install.packages('MCMCglmm')}, ",
          "i" = "or pass {.arg phylo_vcv} instead (legacy dense path)."
        ))
      if (!inherits(phylo_tree, "phylo"))
        cli::cli_abort("{.arg phylo_tree} must be an {.cls ape::phylo} tree.")
      levs <- levels(data[[species]])
      if (!all(levs %in% phylo_tree$tip.label))
        cli::cli_abort("phylo_tree tip labels do not cover all species levels.")
      inv <- MCMCglmm::inverseA(phylo_tree)
      Ainv_phy_rr      <- inv$Ainv          # already sparse (dgCMatrix)
      log_det_A_phy_rr <- -sum(log(inv$dii)) # log det A = -sum(log(dii))
      n_aug_phy        <- nrow(Ainv_phy_rr)
      ## Build the species_aug_id map: each observation row's species
      ## (1..n_species in the data factor) -> position in the augmented
      ## A^-1. Tips live at the END of inv$node.names.
      tip_to_aug <- match(levs, rownames(Ainv_phy_rr))
      if (anyNA(tip_to_aug))
        cli::cli_abort("Internal: tip names not all found in inverseA(tree)$Ainv rownames.")
      species_aug_id <- tip_to_aug[species_id + 1L] - 1L  # 0-indexed for C++
    } else if (inherits(phylo_vcv, "sparseMatrix")) {
      ## --- Sparse Ainv direct engine path (Design 47 follow-on,
      ## 2026-05-18) -------------------------------------------------
      ## When `phylo_vcv` is a sparse Matrix (e.g. dgCMatrix), treat
      ## it as the pre-computed A^{-1} and use it directly, mirroring
      ## the `phylo_tree` route at the top of this block. Triggered
      ## by `animal_*(id, pedigree = ped)` (via
      ## `pedigree_to_Ainv_sparse()` in the brms-sugar resolver) and
      ## by `animal_*(id, Ainv = sparse_Ainv)` (via
      ## `.gllvmTMB_maybe_keep_sparse_ainv()`).
      if (is.null(rownames(phylo_vcv)))
        cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} must have rownames matching levels of {.var {species}}.")
      levs <- levels(data[[species]])
      if (!all(levs %in% rownames(phylo_vcv)))
        cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames do not cover all species levels.")
      Ainv_phy_rr      <- phylo_vcv[levs, levs, drop = FALSE]
      ## log_det_A = -log|det(Ainv)|; sparse Cholesky via Matrix.
      log_det_A_phy_rr <- -as.numeric(Matrix::determinant(Ainv_phy_rr,
                                                          logarithm = TRUE)$modulus)
      n_aug_phy        <- nrow(Ainv_phy_rr)
      species_aug_id   <- species_id    # tip-only sparse path: identity
    } else {
      ## --- Legacy dense path: invert tip-only Cphy and store sparse-format
      if (is.null(phylo_vcv))
        cli::cli_abort("phylo_latent() / phylo_slope() found in formula but {.arg phylo_vcv} (or {.arg phylo_tree}) is NULL.")
      if (is.null(rownames(phylo_vcv)))
        cli::cli_abort("phylo_vcv must have rownames matching levels of {.var {species}}.")
      levs <- levels(data[[species]])
      if (!all(levs %in% rownames(phylo_vcv)))
        cli::cli_abort("phylo_vcv rownames do not cover all species levels.")
      Aphy <- phylo_vcv[levs, levs, drop = FALSE]
      Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))
      Ainv_phy_rr      <- Matrix::Matrix(solve(Aphy), sparse = TRUE)
      log_det_A_phy_rr <- as.numeric(determinant(Aphy, logarithm = TRUE)$modulus)
      n_aug_phy        <- n_species
      species_aug_id   <- species_id    # tip-only path: identity
    }
  }

  ## Phase 3: build the species-latent -> augmented-A-node map for the covariate
  ## field g_x (design 69 sec.3.3). The covariate model is per-species (the
  ## latent level), so eta_x(u) reads g_x at the augmented node of latent species
  ## u. `species_aug_id` (length n_obs, 0-indexed) maps each long row's species
  ## to its node; `mi_model$unit_id` (0-indexed) maps each long row to its latent
  ## species. Deriving the per-latent-species node from a representative long row
  ## works for ALL Ainv paths (sparse tree, sparse Ainv, dense). The covariate
  ## tree was injected as `phylo_tree` above, so the latent species order
  ## (= levels(data[[species]])) aligns with species_aug_id by construction.
  if (use_mi_phylo) {
    n_units_mi <- as.integer(mi_model$n_units)
    node_map <- rep(NA_integer_, n_units_mi)
    uid <- mi_model$unit_id            # 0-indexed long-row -> latent species
    for (o in seq_len(n_obs)) {
      u1 <- uid[o] + 1L
      if (is.na(node_map[u1])) node_map[u1] <- species_aug_id[o]
    }
    if (anyNA(node_map))
      cli::cli_abort(c(
        "Internal error: the {.fn phylo} covariate species -> node map is incomplete.",
        "i" = "A latent species had no long row to read its augmented-tree node from."
      ))
    mi_model$phylo_node_id <- as.integer(node_map)   # 0-indexed
    mi_model$phylo_n_aug   <- as.integer(n_aug_phy)
  }
  if (use_propto) {
    if (is.null(phylo_vcv))
      cli::cli_abort("propto() found in formula but {.arg phylo_vcv} is NULL.")
    if (is.null(rownames(phylo_vcv)))
      cli::cli_abort("phylo_vcv must have rownames matching levels of {.var {species}}.")
    levs <- levels(data[[species]])
    if (!all(levs %in% rownames(phylo_vcv)))
      cli::cli_abort("phylo_vcv rownames do not cover all species levels.")
    if (inherits(phylo_vcv, "sparseMatrix")) {
      ## Design 47 follow-on (2026-05-18): sparse `phylo_vcv` IS the
      ## precomputed A^{-1} (from `pedigree_to_Ainv_sparse()` via the
      ## animal_scalar sugar, or a user-supplied sparse Ainv). The
      ## propto C++ branch uses `Cphy_inv` directly; populate it from
      ## the sparse Ainv and recover `log_det_Cphy = log|det(A)| =
      ## -log|det(Ainv)|`. We densify here because the propto engine
      ## path is dense; the speed gain from `pedigree_to_Ainv_sparse`
      ## relative to `solve(pedigree_to_A(ped))` is in *construction*
      ## (sparse Henderson rules) rather than runtime matvecs.
      Ainv_sub <- phylo_vcv[levs, levs, drop = FALSE]
      Cphy_inv <- as.matrix(Ainv_sub)
      log_det_Cphy <- -as.numeric(Matrix::determinant(Ainv_sub,
                                                      logarithm = TRUE)$modulus)
    } else {
      Cphy <- phylo_vcv[levs, levs, drop = FALSE]
      Cphy <- Cphy + diag(1e-8, nrow = nrow(Cphy)) ## numerical jitter
      Cphy_inv     <- solve(Cphy)
      log_det_Cphy <- as.numeric(determinant(Cphy, logarithm = TRUE)$modulus)
    }
  }

  ## ---- SPDE preparation -------------------------------------------------
  n_mesh <- 1L
  A_proj <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M0 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M1 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M2 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  ## The base SPDE slope engine (use_spde_slope) reuses the same mesh / Q_base
  ## machinery (A_proj, spde_M0/M1/M2, n_mesh), so build it on that path too.
  if (use_spde || use_spde_slope || use_spde_latent_slope) {
    if (is.null(mesh))
      cli::cli_abort("{.fn spatial_unique}/{.fn spatial_scalar}/{.fn spatial_latent} found in formula but {.arg mesh} is NULL.")
    if (!inherits(mesh, "sdmTMBmesh"))
      cli::cli_abort("Pass {.arg mesh} as a result of {.fn make_mesh}.")
    if (!isTRUE(nrow(mesh$A_st) == n_obs))
      cli::cli_abort(c(
        "make_mesh() projection has {nrow(mesh$A_st)} rows but the long-format data has {n_obs}.",
        "i" = "Build the mesh on the same long-format data passed to gllvmTMB()."
      ))
    n_mesh   <- ncol(mesh$A_st)
    A_proj   <- Matrix::sparseMatrix(i = 1:1, j = 1:1, x = 0, dims = c(n_obs, n_mesh))
    A_proj   <- mesh$A_st
    spde_M0  <- mesh$spde$c0
    spde_M1  <- mesh$spde$g1
    spde_M2  <- mesh$spde$g2
  }

  ## ---- BASE augmented SPDE slope (Design 60 §3.4) -----------------------
  ## Second SPDE field on a covariate with a 2x2 cross-field covariance,
  ## prior vec(Omega) ~ N(0, Sigma_field (x) Q^-1) on the same mesh / Q_base.
  ## Activated by spatial_unique(1 + x | coords) / spatial_indep(1 + x | coords)
  ## via the `.spatial_unique_augmented` marker (use_spde_slope, set above).
  ## n_lhs_cols_spde = 2: column 0 = intercept ones, column 1 = the covariate.
  ## Both wide (`1 + x`) and long (`0 + trait + (0 + trait):x`) surfaces build
  ## the SAME 2-column Z_spde_aug, preserving the Design 55 §3 wide<->long
  ## byte-identity contract. The C++ dimension asserts (src/gllvmTMB.cpp)
  ## are the fail-loud backstop -- they are NOT bypassed here.
  ##
  ## spatial_dep(1 + x | coords) (Design 64 §2) lifts the {1,2} cap: it stacks
  ## the per-trait (intercept, slope) fields into a single C = 2T-wide block
  ## carrying the full unstructured Sigma_field. The column ordering is
  ## INTERLEAVED -- (alpha_t0, beta_t0, alpha_t1, beta_t1, ...) -- matching the
  ## validated phylo_dep core; Z routes each row's intercept and slope into its
  ## own trait's pair of columns.
  n_lhs_cols_spde <- if (use_spde_dep_slope) {
    2L * n_traits
  } else if (use_spde_slope) 2L else 1L
  Z_spde_aug      <- array(0.0, dim = c(n_obs, n_lhs_cols_spde))
  if (use_spde_slope) {
    if (
      !spde_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented spatial random-regression LHS.",
        "i" = "Got LHS form {.val {spde_slope_lhs_form}}.",
        ">" = "Use {.code spatial_unique(1 + x | coords)} or {.code spatial_unique(0 + trait + (0 + trait):x | coords)}."
      ))
    }
    if (!spde_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code spatial_unique(1 + {spde_slope_xcol} | coords)} references column {.val {spde_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    if (use_spde_dep_slope) {
      x_dep <- as.numeric(data[[spde_slope_xcol]])
      for (o in seq_len(n_obs)) {
        t0 <- trait_id[o]                       # 0-based trait index
        Z_spde_aug[o, 2L * t0 + 1L] <- 1.0      # intercept field col for trait t0
        Z_spde_aug[o, 2L * t0 + 2L] <- x_dep[o] # slope field col
      }
    } else {
      Z_spde_aug[, 1L] <- 1.0
      Z_spde_aug[, 2L] <- as.numeric(data[[spde_slope_xcol]])
    }
  }

  ## ---- spatial_latent(1 + x | coords, d) augmented slope (Design 64 §3) ---
  ## Reduced-rank design matrix Z_spde_lat (n_obs x n_lhs_cols_spde_lat).
  ## Column 0 = intercept (1's), column 1 = the slope covariate. Independent of
  ## Z_spde_aug (the dep / unique path).
  Z_spde_lat <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_spde_lat)
  if (use_spde_latent_slope) {
    if (
      !spde_latent_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented spatial_latent random-regression LHS.",
        "i" = "Got LHS form {.val {spde_latent_slope_lhs_form}}.",
        ">" = "Use {.code spatial_latent(1 + x | coords, d = K)} or {.code spatial_latent(0 + trait + (0 + trait):x | coords, d = K)}."
      ))
    }
    if (!spde_latent_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code spatial_latent(1 + {spde_latent_slope_xcol} | coords, d = K)} references column {.val {spde_latent_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    Z_spde_lat[, 1L] <- 1.0
    Z_spde_lat[, 2L] <- as.numeric(data[[spde_latent_slope_xcol]])
  }

  ## ---- equalto (known V) preparation ------------------------------------
  V_inv     <- matrix(0, nrow = 1, ncol = 1)
  log_det_V <- 0
  if (use_equalto) {
    if (is.null(known_V))
      cli::cli_abort("equalto() found in formula but {.arg known_V} is NULL.")
    V <- as.matrix(known_V)
    if (!isTRUE(all.equal(nrow(V), n_obs)) || !isTRUE(all.equal(ncol(V), n_obs)))
      cli::cli_abort("known_V must be n_obs x n_obs (got {nrow(V)} x {ncol(V)}).")
    V <- V + diag(1e-8, nrow = nrow(V))
    V_inv     <- solve(V)
    log_det_V <- as.numeric(determinant(V, logarithm = TRUE)$modulus)
  }

  ## ---- TMB inputs -------------------------------------------------------
  ## Pack re_int term metadata into flat vectors. When use_re_int == 0 the
  ## cpp side never reads these, but we still need to pass valid (1-element)
  ## stubs so TMB doesn't choke on zero-length integer vectors.
  n_re_int_terms <- length(re_int_idx)
  re_int_offsets_dat <- if (use_re_int) as.integer(re_int_offsets) else 0L
  re_int_n_groups_dat <- if (use_re_int) as.integer(re_int_n_groups) else 1L
  re_int_id_mat_dat <- if (use_re_int) re_int_id_mat
                        else matrix(0L, nrow = nrow(data), ncol = 1L)
  u_re_int_len <- if (use_re_int) sum(re_int_n_groups) else 1L
  x_phy_slope_dat <- if (use_phylo_slope) {
    if (!phylo_slope_xcol %in% names(data))
      cli::cli_abort(c(
        "{.arg phylo_slope({phylo_slope_xcol} | {species})} references column {.val {phylo_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."))
    as.numeric(data[[phylo_slope_xcol]])
  } else rep(0.0, n_obs)
  ## RE-03 multi-slope: the n_obs x s matrix of the s phylo_dep slope
  ## covariates (column j = the j-th covariate in source order). Only the dep
  ## path builds/uses it; for s == 1 its single column equals x_phy_slope_dat.
  ## The legacy `x_phy_slope` TMB data arg (read only on the single-slope
  ## C++ branch) keeps carrying the FIRST covariate for back-compat.
  x_phy_slope_mat <- if (use_phylo_dep_slope) {
    missing_cols <- setdiff(phylo_slope_xcols, names(data))
    if (length(missing_cols) > 0L) {
      cli::cli_abort(c(
        "{.fn phylo_dep} slope covariate{?s} {.val {missing_cols}} not found in {.arg data}.",
        "i" = "Add the covariate column{?s} to the data frame."))
    }
    matrix(
      as.numeric(unlist(lapply(phylo_slope_xcols, function(col) as.numeric(data[[col]])))),
      nrow = n_obs, ncol = n_phy_slope
    )
  } else matrix(0.0, nrow = n_obs, ncol = max(n_phy_slope, 1L))
  ## Phase 56.3: parser activation for the augmented-LHS phylogenetic
  ## random-regression path. Legacy phylo_slope(x | species) keeps the
  ## one-column b_phy_slope path; phylo_unique(1 + x | species) and its
  ## long-form equivalent route through b_phy_aug with columns
  ## (intercept, slope).
  ##
  ## phylo_dep(1 + x1 + ... + xs | species) (Design 56 Sec. 9.5c + RE-03) lifts the
  ## block-local {1,2} n_lhs_cols invariant: it stacks the per-trait (intercept,
  ## slope_1, ..., slope_s) columns into a single C = (1+s)T-wide block carrying
  ## the full unstructured Sigma_b. The column ordering is INTERLEAVED per
  ## trait -- (alpha_t0, beta1_t0, ..., betas_t0, alpha_t1, beta1_t1, ...) --
  ## generalising the validated s == 1 dep core; Z routes each row's intercept
  ## and s slopes into its own trait's run of (1+s) columns. The C++ dep path is
  ## dimension-general in `C = n_lhs_cols`, so s >= 2 needs ZERO new C++.
  n_lhs_cols <- if (use_phylo_dep_slope) {
    (1L + n_phy_slope) * n_traits
  } else if (use_phylo_slope_correlated) {
    2L
  } else 1L
  n_phy_aug_blocks <- 1L
  Z_phy_aug <- array(0.0, dim = c(n_obs, n_lhs_cols, n_phy_aug_blocks))
  if (use_phylo_dep_slope) {
    if (
      !phylo_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylogenetic random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_slope_lhs_form}}.",
        ">" = "Use {.code phylo_dep(1 + x | species)} or {.code phylo_dep(0 + trait + (0 + trait):x | species)}."
      ))
    }
    ## Per trait t0 the (1+s) columns are [(1+s)*t0 + 1] = intercept and
    ## [(1+s)*t0 + 1 + j] = slope covariate j (j = 1..s).
    stride <- 1L + n_phy_slope
    for (o in seq_len(n_obs)) {
      t0 <- trait_id[o]                          # 0-based trait index
      base <- stride * t0
      Z_phy_aug[o, base + 1L, 1L] <- 1.0         # intercept col for trait t0
      for (j in seq_len(n_phy_slope)) {
        Z_phy_aug[o, base + 1L + j, 1L] <- x_phy_slope_mat[o, j]  # slope col j
      }
    }
  } else if (use_phylo_slope_correlated) {
    if (
      !phylo_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylogenetic random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_slope_lhs_form}}.",
        ">" = "Use {.code phylo_unique(1 + x | species)} or {.code phylo_unique(0 + trait + (0 + trait):x | species)}."
      ))
    }
    Z_phy_aug[, 1L, 1L] <- 1.0
    Z_phy_aug[, 2L, 1L] <- x_phy_slope_dat
  } else if (use_phylo_slope) {
    Z_phy_aug[, 1L, 1L] <- x_phy_slope_dat
  }

  ## Design 56 Sec. 9.5a: augmented phylo_latent design matrix Z_phy_lat
  ## (n_obs x n_lhs_cols_lat). Column 0 = intercept (1's), column 1 = the
  ## slope covariate. Independent of Z_phy_aug (the dep/unique path).
  Z_phy_lat <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_lat)
  if (use_phylo_latent_slope) {
    if (
      !phylo_latent_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylo_latent random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_latent_slope_lhs_form}}.",
        ">" = "Use {.code phylo_latent(1 + x | species, d = K)} or {.code phylo_latent(0 + trait + (0 + trait):x | species, d = K)}."
      ))
    }
    if (!phylo_latent_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code phylo_latent(1 + {phylo_latent_slope_xcol} | {species})} references column {.val {phylo_latent_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    Z_phy_lat[, 1L] <- 1.0
    Z_phy_lat[, 2L] <- as.numeric(data[[phylo_latent_slope_xcol]])
  }

  tmb_data <- list(
    y                = as.numeric(y),
    is_y_observed    = as.integer(is_y_observed),
    n_trials         = as.numeric(n_trials),
    X_fix            = X_fix,
    trait_id         = trait_id,
    site_id          = site_id,
    site_species_id  = site_species_id,
    n_traits         = as.integer(n_traits),
    n_sites          = as.integer(n_sites),
    n_site_species   = as.integer(n_site_species),
    d_B              = as.integer(d_B),
    d_W              = as.integer(d_W),
    use_rr_B         = as.integer(use_rr_B),
    use_diag_B       = as.integer(use_diag_B),
    use_rr_W         = as.integer(use_rr_W),
    use_diag_W       = as.integer(use_diag_W),
    use_propto       = as.integer(use_propto),
    species_id       = species_id,
    n_species        = as.integer(n_species),
    Cphy_inv         = Cphy_inv,
    log_det_Cphy     = log_det_Cphy,
    use_diag_species = as.integer(use_diag_species),
    cluster2_id       = cluster2_id,
    n_cluster2        = as.integer(n_cluster2),
    use_diag_cluster2 = as.integer(use_diag_cluster2),
    use_equalto      = as.integer(use_equalto),
    V_inv            = V_inv,
    log_det_V        = log_det_V,
    use_spde         = as.integer(use_spde),
    spde_lv_k        = as.integer(d_spde_lv),
    n_mesh           = as.integer(n_mesh),
    A_proj           = A_proj,
    spde_M0          = spde_M0,
    spde_M1          = spde_M1,
    spde_M2          = spde_M2,
    ## BASE augmented SPDE slope. Parser-activated for spatial_unique / spatial_indep
    ## x Gaussian via the .spatial_unique_augmented / .spatial_indep_augmented markers;
    ## use_spde_slope is driven live by those markers. When 0, the stubs keep
    ## MakeADFun()'s data/parameter contract consistent (no slope field added).
    use_spde_slope   = as.integer(use_spde_slope),
    n_lhs_cols_spde  = as.integer(n_lhs_cols_spde),
    Z_spde_aug       = Z_spde_aug,
    ## spatial_dep slope (Design 64 §2). Activated by the spatial_dep(1 + x |
    ## coords) route. When 1, n_lhs_cols_spde = 2T and Sigma_field is the full
    ## unstructured C x C built from theta_spde_dep_chol in the TMB template;
    ## else 0 keeps the base unique / indep SPDE-slope paths byte-identical.
    use_spde_dep_slope = as.integer(use_spde_dep_slope),
    ## spatial_latent slope (Design 64 §3). Block-diagonal reduced-rank random
    ## regression on the SPDE field; its own dedicated engine block.
    use_spde_latent_slope = as.integer(use_spde_latent_slope),
    d_spde_slope     = as.integer(d_spde_slope),
    n_lhs_cols_spde_lat = as.integer(n_lhs_cols_spde_lat),
    Z_spde_lat       = Z_spde_lat,
    family_id_vec    = as.integer(family_id_vec),
    link_id_vec      = as.integer(link_id_vec),
    n_ordinal_cuts_per_trait = as.integer(n_ordinal_cuts_per_trait),
    ordinal_offset_per_trait = as.integer(ordinal_offset_per_trait),
    use_phylo_rr     = as.integer(use_phylo_rr),
    d_phy            = as.integer(d_phy),
    n_aug_phy        = as.integer(n_aug_phy),
    Ainv_phy_rr      = Ainv_phy_rr,
    log_det_A_phy_rr = log_det_A_phy_rr,
    species_aug_id   = as.integer(species_aug_id),
    ## Paired phylogenetic PGLLVM: per-trait phylogenetic random intercepts
    ## (psi_phy diag)
    use_phylo_diag   = as.integer(use_phylo_diag),
    ## Q6: phylo_slope data
    use_phylo_slope  = as.integer(use_phylo_slope),
    x_phy_slope      = x_phy_slope_dat,
    use_phylo_slope_correlated = as.integer(use_phylo_slope_correlated),
    n_lhs_cols       = as.integer(n_lhs_cols),
    Z_phy_aug        = Z_phy_aug,
    ## Design 56 Sec. 9.5a: augmented phylo_latent (block-diagonal RR slope)
    use_phylo_latent_slope = as.integer(use_phylo_latent_slope),
    d_phy_slope      = as.integer(d_phy_slope),
    n_lhs_cols_lat   = as.integer(n_lhs_cols_lat),
    Z_phy_lat        = Z_phy_lat,
    ## phylo_dep slope (Stage 3, Design 56 sec.9.5c). Activated by the
    ## phylo_dep(1 + x | sp) parser route. When 1, n_lhs_cols = 2 * n_traits
    ## and Sigma_b is the full unstructured C x C built from theta_dep_chol
    ## in the TMB template; else 0 keeps the legacy / unique / indep paths
    ## byte-identical.
    use_phylo_dep_slope = as.integer(use_phylo_dep_slope),
    use_re_int       = as.integer(use_re_int),
    n_re_int_terms   = as.integer(n_re_int_terms),
    re_int_offsets   = re_int_offsets_dat,
    re_int_n_groups  = re_int_n_groups_dat,
    re_int_group_id  = re_int_id_mat_dat,
    weights_i        = as.numeric(weights_i)
  )

  ## Phase 2a missing-predictor DATA slots (has_mi = 0 no-op when disabled).
  tmb_data <- c(tmb_data, gll_tmb_mi_data(mi_model, n_obs))

  init_rr_theta <- function(p, rank) {
    ## Lambda_B/W ~ I_rank diagonal start (so initial Sigma is the identity
    ## scaled by 0). Concretely: lam_diag = 0.5 (sd 1.65), lam_lower = 0.
    c(rep(0.5, rank), rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank))
  }

  ## Design 48 §2-B (M3.4 boundary regimes): clamp initial value of any
  ## log_phi_* parameter to [log(0.01), log(100)]. Default zero inits are
  ## already inside this range (this is a no-op for the default path);
  ## warm-started values and multi-start jittered values that drift to
  ## near-Poisson (phi → 0) or near-flat-likelihood (phi → ∞) get
  ## reined in. The OPTIMIZER stays unconstrained — only the starting
  ## value is clamped. Mirrors the gllvm pattern (`gllvm.TMB:599-602`).
  .clamp_log_phi <- function(x) pmax(pmin(x, log(100.0)), log(0.01))

  tmb_params <- list(
    b_fix        = unname(b_fix_init),
    log_sigma_eps = log_sigma_eps_init,
    theta_rr_B   = if (use_rr_B) init_rr_theta(n_traits, d_B) else rep(0.0, theta_rr_B_len),
    z_B          = matrix(0, nrow = max(d_B, 1L), ncol = n_sites),
    theta_diag_B = rep(0.0, n_traits),
    s_B          = matrix(0, nrow = n_traits, ncol = n_sites),
    theta_rr_W   = if (use_rr_W) init_rr_theta(n_traits, d_W) else rep(0.0, theta_rr_W_len),
    z_W          = matrix(0, nrow = max(d_W, 1L), ncol = n_site_species),
    theta_diag_W = rep(0.0, n_traits),
    s_W          = matrix(0, nrow = n_traits, ncol = n_site_species),
    loglambda_phy = 0.0,
    p_phy        = matrix(0, nrow = n_species, ncol = n_traits),
    theta_diag_species = rep(0.0, n_traits),
    q_sp         = matrix(0, nrow = n_traits, ncol = n_species),
    theta_diag_cluster2 = rep(0.0, n_traits),
    r_c2         = matrix(0, nrow = n_traits, ncol = n_cluster2),
    e_eq         = if (use_equalto) rep(0.0, n_obs) else 0.0,
    log_tau_spde = if (use_spde) rep(0.0, n_traits) else 0.0,
    log_kappa_spde = 0.0,
    omega_spde   = matrix(0, nrow = n_mesh, ncol = if (use_spde) n_traits else 1L),
    ## spatial_latent: packed lower-triangular Lambda_spde (n_traits x K_S)
    ## and K_S shared spatial fields. Allocated with dim 1 when not in use
    ## so TMB can still read a valid (mapped-off) matrix.
    theta_rr_spde_lv = if (is_spatial_latent) {
                          init_rr_theta_spde_lv <- function(p, rank)
                            c(rep(0.5, rank),
                              rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank))
                          init_rr_theta_spde_lv(n_traits, d_spde_lv)
                        } else 0.0,
    omega_spde_lv = matrix(0, nrow = n_mesh,
                           ncol = if (is_spatial_latent) d_spde_lv else 1L),
    ## BASE augmented SPDE slope params (dormant; mapped off when inactive).
    ## omega_spde_aug widens to n_mesh x 2T on the spatial_dep path.
    omega_spde_aug   = array(0.0, dim = c(n_mesh, n_lhs_cols_spde)),
    log_sd_spde_b    = rep(0.0, n_lhs_cols_spde),
    atanh_cor_spde_b = numeric(n_lhs_cols_spde * (n_lhs_cols_spde - 1L) / 2L),
    ## spatial_dep slope unstructured-covariance Cholesky packing; length
    ## C(C+1)/2 (C = n_lhs_cols_spde = 2T) only on the dep path, else empty. The
    ## first C entries are the log-diagonal of L (C++ exp-transforms them); the
    ## remaining C(C-1)/2 strictly-lower entries follow column-major. Diagonal
    ## initialised at log(0.5) (a sane positive start); off-diagonals 0. Mirrors
    ## theta_dep_chol (phylo_dep).
    theta_spde_dep_chol = if (use_spde_dep_slope) {
                            n_chol <- n_lhs_cols_spde * (n_lhs_cols_spde + 1L) / 2L
                            td <- numeric(n_chol)
                            td[seq_len(n_lhs_cols_spde)] <- log(0.5)
                            td
                          } else numeric(0L),
    ## spatial_latent slope (Design 64 §3): per-column packed lower-triangular
    ## Lambda_k blocks + shared spatial field scores on the mesh. Mapped off
    ## when not in use. Mirrors theta_rr_phy_slope / g_phy_slope.
    theta_rr_spde_slope = if (use_spde_latent_slope) {
                            rep(init_rr_theta(n_traits, d_spde_slope), n_lhs_cols_spde_lat)
                          } else {
                            rep(0.0, n_lhs_cols_spde_lat *
                                  (n_traits * d_spde_slope - d_spde_slope * (d_spde_slope - 1L) / 2L))
                          },
    g_spde_slope     = array(0.0, dim = c(n_mesh, d_spde_slope, n_lhs_cols_spde_lat)),
    theta_rr_phy = if (use_phylo_rr) {
                     init_rr_theta_pkg <- function(p, rank)
                       c(rep(0.5, rank), rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank))
                     init_rr_theta_pkg(n_traits, d_phy)
                   } else 0.0,
    g_phy        = matrix(0, nrow = n_aug_phy, ncol = if (use_phylo_rr) d_phy else 1L),
    ## Paired phylogenetic PGLLVM: per-trait phylogenetic random intercept
    ## (psi_phy diag).
    ## When use_phylo_diag = 0 these are mapped off below.
    log_sd_phy_diag = if (use_phylo_diag) rep(0.0, n_traits) else 0.0,
    g_phy_diag      = matrix(0, nrow = n_aug_phy,
                             ncol = if (use_phylo_diag) n_traits else 1L),
    ## Q6: phylo_slope params
    b_phy_slope     = rep(0.0, n_aug_phy),  # one slope per augmented A row
    log_sigma_slope = 0.0,
    b_phy_aug       = array(0.0, dim = c(n_aug_phy, n_lhs_cols, n_phy_aug_blocks)),
    log_sd_b        = rep(0.0, n_lhs_cols),
    atanh_cor_b     = numeric(n_lhs_cols * (n_lhs_cols - 1L) / 2L),
    ## Design 56 Sec. 9.5a: augmented phylo_latent (block-diagonal RR slope).
    ## theta_rr_phy_slope packs n_lhs_cols_lat lower-triangular Lambda_k blocks
    ## (each with the rr() identity-diagonal start); g_phy_slope holds the
    ## per-column N(0, A) factor scores. Mapped off when not in use.
    theta_rr_phy_slope = if (use_phylo_latent_slope) {
      rep(init_rr_theta(n_traits, d_phy_slope), n_lhs_cols_lat)
    } else {
      rep(0.0, n_lhs_cols_lat *
            (n_traits * d_phy_slope - d_phy_slope * (d_phy_slope - 1L) / 2L))
    },
    g_phy_slope     = array(0.0, dim = c(n_aug_phy, d_phy_slope, n_lhs_cols_lat)),
    ## phylo_dep slope unstructured-covariance Cholesky packing; length
    ## C(C+1)/2 (C = n_lhs_cols = (1+s)T) only on the dep path, else empty. The
    ## first C entries are the log-diagonal of the lower-triangular L (the
    ## C++ exp-transforms them); the remaining C(C-1)/2 strictly-lower
    ## entries follow column-major. Diagonal initialised at log(0.5) so the
    ## starting L has diag 0.5 (a sane positive start); off-diagonals 0.
    theta_dep_chol  = if (use_phylo_dep_slope) {
                        n_chol <- n_lhs_cols * (n_lhs_cols + 1L) / 2L
                        td <- numeric(n_chol)
                        td[seq_len(n_lhs_cols)] <- log(0.5)
                        td
                      } else numeric(0L),
    u_re_int       = rep(0.0, u_re_int_len),
    log_sigma_re_int = if (use_re_int) rep(0.0, n_re_int_terms) else 0.0,
    ## NB2 / NB1 / Tweedie per-trait dispersion. log(phi) starts at 0 (phi = 1);
    ## logit(p) starts at 0 (p = 1.5, mid of the compound-Poisson regime).
    ## Design 48 phi-clamp ([0.01, 100]) applied below.
    log_phi_nbinom2  = .clamp_log_phi(rep(0.0, n_traits)),
    log_phi_nbinom1  = .clamp_log_phi(rep(0.0, n_traits)),
    log_phi_tweedie  = .clamp_log_phi(rep(0.0, n_traits)),
    logit_p_tweedie  = rep(0.0, n_traits),
    ## Beta / beta-binomial per-trait precision. log(phi) starts at 1.0 so
    ## phi = e ~ 2.72, a moderate-concentration default that avoids the
    ## degenerate phi -> 0 boundary while not being so peaked that the
    ## inner Newton stalls (Smithson & Verkuilen 2006; Hilbe 2014).
    log_phi_beta      = .clamp_log_phi(rep(1.0, n_traits)),
    log_phi_betabinom = .clamp_log_phi(rep(1.0, n_traits)),
    ## Student-t per-trait scale (sigma) and log(df-1) (so df > 1).
    ## log(0) = 0 -> sigma = 1; log(df-1) = log(2) -> df = 3 (a common
    ## heavy-tailed default; Lange et al. 1989).
    log_sigma_student = rep(0.0, n_traits),
    log_df_student    = rep(log(2.0), n_traits),
    ## truncated_nbinom2 per-trait dispersion. Same parameterisation as
    ## NB2 (Var = mu + mu^2/phi), but conditioned on y >= 1.
    log_phi_truncnb2  = .clamp_log_phi(rep(0.0, n_traits)),
    ## Delta (hurdle) families: per-trait dispersion of the *positive*
    ## component only. log(sigma) starts at 0 (sigma_lognormal = 1);
    ## log(phi) starts at 0 (gamma CV = 1, ~Exponential).
    log_sigma_lognormal_delta = rep(0.0, n_traits),
    log_phi_gamma_delta       = .clamp_log_phi(rep(0.0, n_traits)),
    ## ordinal_probit cutpoint log-increments. Length = sum(K_t - 2) over
    ## ordinal traits (or 1 stub when no trait is ordinal). Initialised
    ## from MASS::polr(method = "probit") per ordinal trait when sample
    ## size permits, else equal-spaced 0.5 (log-increment = log(0.5)).
    ordinal_log_increments = if (any_ordinal_probit && length(ordinal_init_log_incs) > 0L)
                               ordinal_init_log_incs else 0.0
  )

  ## Phase 2a/2b missing-predictor PARAMETERS. beta_mi / log_sigma_mi are the
  ## Gaussian covariate-model coefficients + log residual SD; x_mis is the
  ## latent vector of missing UNIT-level x values (joins `random`). Phase 2b
  ## adds u_mi_group (N(0,1) unit-level group effects, joins `random`) and
  ## log_sd_mi_group. Stub lengths (1 / empty) when no mi() term / no group is
  ## present -- mapped off below.
  use_mi_group <- use_mi_predictor && isTRUE(mi_model$random$enabled)
  ## Phase 5a: the DISCRETE (binary) route has NO latent x and NO residual
  ## sigma -- the missing x is summed out exactly in the engine (design 68
  ## sec.1.1). x_mis stays length 0 (out of `random`) and log_sigma_mi is
  ## mapped off; only beta_mi (the Bernoulli-logit coefficients) is estimated.
  use_mi_discrete <- use_mi_predictor && identical(mi_model$family, "bernoulli")
  if (use_mi_predictor) {
    tmb_params$beta_mi      <- unname(mi_model$beta_start)
    tmb_params$log_sigma_mi <- mi_model$log_sigma_start
    tmb_params$x_mis        <- unname(mi_model$x_mis_start)
  } else {
    tmb_params$beta_mi      <- 0.0
    tmb_params$log_sigma_mi <- 0.0
    tmb_params$x_mis        <- numeric(0)
  }
  if (use_mi_group) {
    tmb_params$u_mi_group      <- unname(mi_model$u_group_start)
    tmb_params$log_sd_mi_group <- mi_model$log_sd_group_start
  } else {
    tmb_params$u_mi_group      <- 0.0
    tmb_params$log_sd_mi_group <- 0.0
  }
  ## Phase 3 (design 69): the phylogenetic covariate field g_x ~ N(0, A)
  ## (STANDARDIZED form, Q1) over the augmented A nodes, plus its log-SD log_sd_x.
  ## g_x joins `random`; eta_x(s) += sd_x * g_x(node(s)) in the engine. Stub
  ## length 1 / mapped off when no phylo() covariate term is present.
  if (use_mi_phylo) {
    tmb_params$g_x      <- rep(0.0, mi_model$phylo_n_aug)
    tmb_params$log_sd_x <- mi_model$log_sd_x_start
  } else {
    tmb_params$g_x      <- 0.0
    tmb_params$log_sd_x <- 0.0
  }

  ## McGillycuddy / glmmTMB-style residual starts for factor-analytic
  ## random effects. The fixed-effects pseudo-fit above gives
  ## `resid_init`; here we reshape those residuals to group x trait matrices
  ## and use a reduced-rank SVD start for Lambda + latent scores. This is
  ## opt-in because random starts and the existing phi warmup remain useful
  ## in difficult M3.3/M3.4 regimes.
  start_method <- .gllvmTMB_normalize_start_method(
    control$start_method %||% list(method = NULL, jitter.sd = 0)
  )
  start_from_fit <- control$start_from %||% NULL
  start_provenance <- list(
    init_strategy = control$init_strategy,
    start_method = start_method$method %||% "default",
    start_method_jitter_sd = start_method$jitter.sd,
    start_from = !is.null(start_from_fit),
    start_from_source = if (!is.null(start_from_fit)) "user" else NULL,
    start_from_copied = character(0),
    auto_indep_fit = FALSE
  )
  if (identical(start_method$method, "indep")) {
    drop_rr <- kinds == "rr" & groupings %in% c(site, ss_name)
    keep_covstruct <- !drop_rr
    has_indep_terms <- any(kinds == "diag" & groupings %in% c(site, ss_name))
    if (any(drop_rr) && has_indep_terms) {
      parsed_indep <- parsed
      parsed_indep$covstructs <- parsed$covstructs[keep_covstruct]
      control_indep <- control
      control_indep$start_method <- list(method = NULL, jitter.sd = 0)
      control_indep$start_from <- NULL
      control_indep$n_init <- 1L
      control_indep$verbose <- FALSE
      auto_start <- tryCatch(
        gllvmTMB_multi_fit(
          parsed = parsed_indep,
          data = data,
          trait = trait,
          site = site,
          species = species,
          family = family_input,
          weights = weights,
          phylo_vcv = phylo_vcv,
          phylo_tree = phylo_tree,
          known_V = known_V,
          mesh = mesh,
          lambda_constraint = lambda_constraint,
          control = control_indep,
          silent = silent,
          unit_obs = unit_obs
        ),
        error = function(e) e
      )
      if (inherits(auto_start, "error")) {
        cli::cli_warn(c(
          "{.arg start_method = list(method = \"indep\")} failed while fitting the simpler independent model; continuing with the default starts.",
          "i" = conditionMessage(auto_start)
        ))
      } else if (is.null(start_from_fit)) {
        start_from_fit <- auto_start
        start_provenance$start_from <- TRUE
        start_provenance$start_from_source <- "auto_indep"
        start_provenance$auto_indep_fit <- TRUE
        if (isTRUE(control$verbose)) {
          cat("  start_method='indep': fitted unique-only warm-start model\n")
        }
      }
    } else if (isTRUE(control$verbose)) {
      cat("  start_method='indep': skipped (no paired unique() terms to fit)\n")
    }
  }
  if (identical(start_method$method, "res")) {
    if (use_rr_B) {
      start_B <- .gllvmTMB_residual_factor_start(
        resid = resid_init,
        trait_id = trait_id,
        group_id = site_id,
        n_traits = n_traits,
        n_groups = n_sites,
        rank = d_B,
        jitter.sd = start_method$jitter.sd,
        default_theta = tmb_params$theta_rr_B
      )
      if (isTRUE(start_B$usable)) {
        tmb_params$theta_rr_B <- start_B$theta_rr
        tmb_params$z_B <- start_B$z
        if (use_diag_B) {
          tmb_params$theta_diag_B <- start_B$theta_diag
          tmb_params$s_B <- start_B$s
        }
      }
      if (isTRUE(control$verbose)) {
        cat(sprintf("  start_method='res' B-tier: %s\n", start_B$reason))
      }
    }
    if (use_rr_W) {
      start_W <- .gllvmTMB_residual_factor_start(
        resid = resid_init,
        trait_id = trait_id,
        group_id = site_species_id,
        n_traits = n_traits,
        n_groups = n_site_species,
        rank = d_W,
        jitter.sd = start_method$jitter.sd,
        default_theta = tmb_params$theta_rr_W
      )
      if (isTRUE(start_W$usable)) {
        tmb_params$theta_rr_W <- start_W$theta_rr
        tmb_params$z_W <- start_W$z
        if (use_diag_W) {
          tmb_params$theta_diag_W <- start_W$theta_diag
          tmb_params$s_W <- start_W$s
        }
      }
      if (isTRUE(control$verbose)) {
        cat(sprintf("  start_method='res' W-tier: %s\n", start_W$reason))
      }
    }
  }
  if (!is.null(start_from_fit)) {
    warm <- .gllvmTMB_apply_start_from(
      tmb_params = tmb_params,
      start_from = start_from_fit,
      verbose = isTRUE(control$verbose)
    )
    tmb_params <- warm$params
    start_provenance$start_from <- TRUE
    start_provenance$start_from_copied <- warm$copied
  }

  ## ---- Map: zero-out unused parameters ---------------------------------
  tmb_map <- list()
  ## Missing-predictor params are stubs when no mi() term is present: map both
  ## scalars off so TMB does not estimate them (x_mis is length 0 and simply
  ## stays out of the `random` set).
  if (!use_mi_predictor) {
    tmb_map$beta_mi      <- factor(rep(NA_integer_, length(tmb_params$beta_mi)))
    tmb_map$log_sigma_mi <- factor(rep(NA_integer_, length(tmb_params$log_sigma_mi)))
  } else if (use_mi_discrete) {
    ## Phase 5a: the binary route estimates beta_mi but has no residual sigma.
    ## Map log_sigma_mi off (the discrete SUM never reads it); x_mis is length 0
    ## and simply stays out of the `random` set.
    tmb_map$log_sigma_mi <- factor(rep(NA_integer_, length(tmb_params$log_sigma_mi)))
  }
  ## Phase 2b grouped covariate RE: map the group params off (and keep
  ## u_mi_group out of `random`) when no (1|group) term is present.
  if (!use_mi_group) {
    tmb_map$u_mi_group      <- factor(rep(NA_integer_, length(tmb_params$u_mi_group)))
    tmb_map$log_sd_mi_group <- factor(rep(NA_integer_, length(tmb_params$log_sd_mi_group)))
  }
  ## Phase 3 phylo covariate field: map g_x / log_sd_x off (and keep g_x out of
  ## `random`) when no phylo() covariate term is present (the no-op pattern).
  if (!use_mi_phylo) {
    tmb_map$g_x      <- factor(rep(NA_integer_, length(tmb_params$g_x)))
    tmb_map$log_sd_x <- factor(rep(NA_integer_, length(tmb_params$log_sd_x)))
  }
  if (!use_rr_B) {
    tmb_map$theta_rr_B <- factor(rep(NA_integer_, length(tmb_params$theta_rr_B)))
    tmb_map$z_B        <- factor(rep(NA_integer_, length(tmb_params$z_B)))
  }
  if (!use_diag_B) {
    tmb_map$theta_diag_B <- factor(rep(NA_integer_, n_traits))
    tmb_map$s_B          <- factor(rep(NA_integer_, length(tmb_params$s_B)))
  } else if (diag_B_common) {
    ## All trait variances at B tier tied to the first parameter —
    ## one shared sigma_S across traits. The parameter vector still
    ## has length n_traits (so the C++ template works unchanged), but
    ## TMB's `map` mechanism collapses it to a single estimable value.
    tmb_map$theta_diag_B <- factor(rep(1L, n_traits))
  }
  if (!use_rr_W) {
    tmb_map$theta_rr_W <- factor(rep(NA_integer_, length(tmb_params$theta_rr_W)))
    tmb_map$z_W        <- factor(rep(NA_integer_, length(tmb_params$z_W)))
  }
  if (!use_diag_W) {
    tmb_map$theta_diag_W <- factor(rep(NA_integer_, n_traits))
    tmb_map$s_W          <- factor(rep(NA_integer_, length(tmb_params$s_W)))
  } else if (diag_W_common) {
    ## Same parsimony mode for the W tier.
    tmb_map$theta_diag_W <- factor(rep(1L, n_traits))
  }
  ## Confirmatory lambda_constraint (galamm-style). Only fixes entries
  ## that respect the engine's lower-triangular structure: diagonal and
  ## strict-lower-triangle of an n_traits x rank Lambda. Upper-triangle
  ## constraints are silently ignored (those entries are already 0).
  if (use_rr_B && !is.null(lambda_constraint$B)) {
    cm <- lambda_packed_map(lambda_constraint$B, n_traits, d_B,
                            tmb_params$theta_rr_B)
    tmb_map$theta_rr_B    <- cm$map
    tmb_params$theta_rr_B <- cm$init
  }
  if (use_rr_W && !is.null(lambda_constraint$W)) {
    cm <- lambda_packed_map(lambda_constraint$W, n_traits, d_W,
                            tmb_params$theta_rr_W)
    tmb_map$theta_rr_W    <- cm$map
    tmb_params$theta_rr_W <- cm$init
  }
  ## phylo_unique(): force a diagonal Lambda_phy by pinning the strict-
  ## lower-triangle entries to 0. The diagonal entries remain free and
  ## become the per-trait phylogenetic SDs. This builds an n_traits x
  ## n_traits Lambda where column k contributes only to trait k -- giving
  ## D independent phylogenetic random intercepts on the same C, exactly
  ## the unique-rank cell of the phylogenetic column of the keyword grid.
  ## Implemented entirely via lambda_packed_map(); no TMB change needed.
  if (use_phylo_rr && is_phylo_unique) {
    if (!is.null(lambda_constraint$phy))
      cli::cli_abort("phylo_unique() supplies its own diagonal lambda_constraint and is incompatible with a user-supplied {.code lambda_constraint$phy}. Use {.fn phylo_latent} for the general case.")
    diag_constraint <- matrix(NA_real_, nrow = n_traits, ncol = d_phy)
    ## Pin the strict lower triangle to 0 (diagonal stays NA = free).
    for (j in seq_len(d_phy)) {
      for (i in seq_len(n_traits)) {
        if (i > j) diag_constraint[i, j] <- 0
      }
    }
    cm <- lambda_packed_map(diag_constraint, n_traits, d_phy,
                            tmb_params$theta_rr_phy)
    tmb_map$theta_rr_phy    <- cm$map
    tmb_params$theta_rr_phy <- cm$init
    ## Track the user-facing intent so downstream printing / extractors can
    ## label the term as "phylo_unique" rather than "phylo_latent".
    lambda_constraint$phy <- diag_constraint
  } else if (use_phylo_rr && !is.null(lambda_constraint$phy)) {
    cm <- lambda_packed_map(lambda_constraint$phy, n_traits, d_phy,
                            tmb_params$theta_rr_phy)
    tmb_map$theta_rr_phy    <- cm$map
    tmb_params$theta_rr_phy <- cm$init
  }
  ## spatial_scalar(): tie all per-trait log_tau_spde entries to a single
  ## level so they collapse to one shared variance parameter. Same TMB
  ## map trick as `unique(..., common = TRUE)`. The per-trait spatial
  ## fields remain independent (one omega_spde column per trait), but
  ## share a single marginal variance.
  if (use_spde && is_spatial_scalar) {
    tmb_map$log_tau_spde <- factor(rep(1L, n_traits))
  }
  ## spatial_latent(): the engine reads Lambda_spde * omega_spde_lv instead
  ## of per-trait omega_spde. Map off the unused per-trait params so the
  ## optimiser doesn't move them. The shared kappa stays free; tau is
  ## absorbed into Lambda_spde for identifiability (mirrors phylo_latent).
  if (use_spde && is_spatial_latent) {
    tmb_map$log_tau_spde <- factor(rep(NA_integer_, length(tmb_params$log_tau_spde)))
    tmb_map$omega_spde   <- factor(rep(NA_integer_, length(tmb_params$omega_spde)))
    ## Optional confirmatory constraint on Lambda_spde, same packed
    ## lower-triangular convention as B / W / phy.
    if (!is.null(lambda_constraint$spde)) {
      cm <- lambda_packed_map(lambda_constraint$spde, n_traits, d_spde_lv,
                              tmb_params$theta_rr_spde_lv)
      tmb_map$theta_rr_spde_lv    <- cm$map
      tmb_params$theta_rr_spde_lv <- cm$init
    }
  }
  if (!use_propto) {
    tmb_map$loglambda_phy <- factor(NA_integer_)
    tmb_map$p_phy         <- factor(rep(NA_integer_, length(tmb_params$p_phy)))
  }
  if (!use_diag_species) {
    tmb_map$theta_diag_species <- factor(rep(NA_integer_, n_traits))
    tmb_map$q_sp               <- factor(rep(NA_integer_, length(tmb_params$q_sp)))
  }
  if (!use_diag_cluster2) {
    tmb_map$theta_diag_cluster2 <- factor(rep(NA_integer_, n_traits))
    tmb_map$r_c2                <- factor(rep(NA_integer_, length(tmb_params$r_c2)))
  }
  if (!use_equalto) {
    tmb_map$e_eq <- factor(rep(NA_integer_, length(tmb_params$e_eq)))
  }
  if (!use_spde) {
    tmb_map$log_tau_spde   <- factor(rep(NA_integer_, length(tmb_params$log_tau_spde)))
    ## The base / dep SPDE slope engine (use_spde_slope) and the spatial_latent
    ## slope engine (use_spde_latent_slope) both build Q_base from
    ## log_kappa_spde, so keep kappa FREE on those paths even though the
    ## intercept-only per-trait fields (log_tau_spde, omega_spde) are off.
    if (!use_spde_slope && !use_spde_latent_slope) {
      tmb_map$log_kappa_spde <- factor(NA_integer_)
    }
    tmb_map$omega_spde     <- factor(rep(NA_integer_, length(tmb_params$omega_spde)))
  }
  if (!is_spatial_latent) {
    tmb_map$theta_rr_spde_lv <- factor(rep(NA_integer_, length(tmb_params$theta_rr_spde_lv)))
    tmb_map$omega_spde_lv    <- factor(rep(NA_integer_, length(tmb_params$omega_spde_lv)))
  }
  if (!use_phylo_rr) {
    tmb_map$theta_rr_phy <- factor(rep(NA_integer_, length(tmb_params$theta_rr_phy)))
    tmb_map$g_phy        <- factor(rep(NA_integer_, length(tmb_params$g_phy)))
  }
  if (!use_phylo_diag) {
    tmb_map$log_sd_phy_diag <- factor(rep(NA_integer_, length(tmb_params$log_sd_phy_diag)))
    tmb_map$g_phy_diag      <- factor(rep(NA_integer_, length(tmb_params$g_phy_diag)))
  }
  if (!use_phylo_slope || use_phylo_slope_correlated) {
    tmb_map$b_phy_slope     <- factor(rep(NA_integer_, length(tmb_params$b_phy_slope)))
    tmb_map$log_sigma_slope <- factor(NA_integer_)
  }
  if (!use_phylo_slope_correlated) {
    tmb_map$b_phy_aug <- factor(rep(NA_integer_, length(tmb_params$b_phy_aug)))
    tmb_map$log_sd_b  <- factor(rep(NA_integer_, length(tmb_params$log_sd_b)))
    if (length(tmb_params$atanh_cor_b) > 0L) {
      tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
    }
  } else if (use_phylo_dep_slope) {
    ## phylo_dep: the full unstructured (1+s)T x (1+s)T Sigma_b is parameterised
    ## by the FREE theta_dep_chol; the closed-form log_sd_b / atanh_cor_b do NOT
    ## enter the dep prior, so they are mapped off (the dep covariance replaces
    ## them). b_phy_aug stays free (it is a random effect joined to `random`
    ## below).
    tmb_map$log_sd_b <- factor(rep(NA_integer_, length(tmb_params$log_sd_b)))
    if (length(tmb_params$atanh_cor_b) > 0L) {
      tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
    }
  } else if (use_phylo_slope_indep && length(tmb_params$atanh_cor_b) > 0L) {
    ## phylo_indep: hold the intercept-slope correlation at its init (0) so the
    ## C++ prior reduces to block-diagonal Sigma_b (rho = tanh(0) = 0).
    tmb_params$atanh_cor_b[] <- 0
    tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
  }
  ## BASE augmented SPDE slope: map all params off while dormant.
  if (!use_spde_slope) {
    tmb_map$omega_spde_aug   <- factor(rep(NA_integer_, length(tmb_params$omega_spde_aug)))
    tmb_map$log_sd_spde_b    <- factor(rep(NA_integer_, length(tmb_params$log_sd_spde_b)))
    if (length(tmb_params$atanh_cor_spde_b) > 0L) {
      tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
    }
  } else if (use_spde_dep_slope) {
    ## spatial_dep: the full unstructured C x C Sigma_field is parameterised by
    ## the FREE theta_spde_dep_chol; the closed-form log_sd_spde_b /
    ## atanh_cor_spde_b do NOT enter the dep prior, so they are mapped off (the
    ## unstructured covariance replaces them). omega_spde_aug stays free (it is
    ## a random effect joined to `random` below). Mirrors the phylo_dep map.
    tmb_map$log_sd_spde_b <- factor(rep(NA_integer_, length(tmb_params$log_sd_spde_b)))
    if (length(tmb_params$atanh_cor_spde_b) > 0L) {
      tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
    }
  } else if (use_spde_slope_indep && length(tmb_params$atanh_cor_spde_b) > 0L) {
    ## spatial_indep: hold the intercept-slope cross-field correlation at its
    ## init (0) so the C++ prior reduces to a DIAGONAL Sigma_field
    ## (rho = tanh(0) = 0). Same engine as spatial_unique; only the rho map
    ## differs (Design 60 §3.5). Mirrors the phylo_indep atanh_cor_b NA-pin.
    tmb_params$atanh_cor_spde_b[] <- 0
    tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
  }
  if (!use_phylo_latent_slope) {
    tmb_map$theta_rr_phy_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_rr_phy_slope)))
    tmb_map$g_phy_slope <-
      factor(rep(NA_integer_, length(tmb_params$g_phy_slope)))
  }
  ## spatial_latent slope: map off the per-column loadings + shared field
  ## scores when not in use (mirrors the phylo_latent slope map).
  if (!use_spde_latent_slope) {
    tmb_map$theta_rr_spde_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_rr_spde_slope)))
    tmb_map$g_spde_slope <-
      factor(rep(NA_integer_, length(tmb_params$g_spde_slope)))
  }
  ## theta_dep_chol is FREE only on the dep path; mapped off (length 0
  ## no-op) everywhere else so the legacy / unique / indep fits stay
  ## byte-identical and TMB never tries to optimise a stray parameter.
  if (!use_phylo_dep_slope) {
    tmb_map$theta_dep_chol <-
      factor(rep(NA_integer_, length(tmb_params$theta_dep_chol)))
  }
  ## theta_spde_dep_chol is FREE only on the spatial_dep path; mapped off
  ## (length-0 no-op) everywhere else.
  if (!use_spde_dep_slope) {
    tmb_map$theta_spde_dep_chol <-
      factor(rep(NA_integer_, length(tmb_params$theta_spde_dep_chol)))
  }
  if (!use_re_int) {
    tmb_map$u_re_int         <- factor(rep(NA_integer_, length(tmb_params$u_re_int)))
    tmb_map$log_sigma_re_int <- factor(rep(NA_integer_, length(tmb_params$log_sigma_re_int)))
  }
  ## NB2 / Tweedie per-trait dispersion: only estimated when the corresponding
  ## family appears in family_id_vec. For mixed-family fits (e.g., one trait
  ## NB2, another Gaussian) we still allocate n_traits parameters but rely on
  ## the data not invoking the unused ones; mapping off only happens when the
  ## family is entirely absent.
  any_nbinom2 <- any(family_id_vec == 5L)
  any_nbinom1 <- any(family_id_vec == 15L)
  any_tweedie <- any(family_id_vec == 6L)
  any_beta    <- any(family_id_vec == 7L)
  any_betabinom <- any(family_id_vec == 8L)
  any_delta_lognormal <- any(family_id_vec == 12L)
  any_delta_gamma     <- any(family_id_vec == 13L)
  if (!any_nbinom2)
    tmb_map$log_phi_nbinom2 <- factor(rep(NA_integer_, n_traits))
  if (!any_nbinom1)
    tmb_map$log_phi_nbinom1 <- factor(rep(NA_integer_, n_traits))
  if (!any_tweedie) {
    tmb_map$log_phi_tweedie <- factor(rep(NA_integer_, n_traits))
    tmb_map$logit_p_tweedie <- factor(rep(NA_integer_, n_traits))
  }
  if (!any_beta)
    tmb_map$log_phi_beta <- factor(rep(NA_integer_, n_traits))
  if (!any_betabinom)
    tmb_map$log_phi_betabinom <- factor(rep(NA_integer_, n_traits))
  ## Student-t (fid 9) and truncated NB2 (fid 11): map per-trait dispersion
  ## parameters off when the corresponding family is entirely absent.
  any_student   <- any(family_id_vec == 9L)
  any_truncnb2  <- any(family_id_vec == 11L)
  if (!any_student) {
    tmb_map$log_sigma_student <- factor(rep(NA_integer_, n_traits))
    tmb_map$log_df_student    <- factor(rep(NA_integer_, n_traits))
  } else {
    ## If the user supplied numeric `df` on the student() family object
    ## (e.g. student(df = 3)), pin log_df_student per trait that uses it.
    ## Per-trait pinning: walk family_per_row and find which trait_id rows
    ## use a student family; if for a given trait the unique student `$df`
    ## values are all numeric (and equal), pin log_df_student[t] at
    ## log(df - 1). If df is NULL for any row, leave that trait estimable.
    df_pin <- rep(NA_real_, n_traits)
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L) & family_id_vec == 9L)
      if (length(rows_t) == 0L) next
      df_vals <- vapply(family_per_row[rows_t], function(f) {
        v <- f$df
        if (is.null(v)) NA_real_ else as.numeric(v)
      }, numeric(1))
      if (all(!is.na(df_vals)) && length(unique(df_vals)) == 1L) {
        if (df_vals[1] <= 1)
          cli::cli_abort("student(): {.code df} must be > 1 (got {df_vals[1]}).")
        df_pin[t] <- df_vals[1]
      }
    }
    if (any(!is.na(df_pin))) {
      tmb_params$log_df_student[!is.na(df_pin)] <- log(df_pin[!is.na(df_pin)] - 1)
      df_map <- seq_len(n_traits)
      df_map[!is.na(df_pin)] <- NA
      tmb_map$log_df_student <- factor(df_map)
    }
  }
  if (!any_truncnb2)
    tmb_map$log_phi_truncnb2 <- factor(rep(NA_integer_, n_traits))
  if (!any_delta_lognormal)
    tmb_map$log_sigma_lognormal_delta <- factor(rep(NA_integer_, n_traits))
  if (!any_delta_gamma)
    tmb_map$log_phi_gamma_delta <- factor(rep(NA_integer_, n_traits))
  ## ordinal_probit: cutpoint log-increments. When no trait uses fid 14
  ## (or every ordinal trait is K = 2 with no free cutpoints) the
  ## parameter is a length-1 stub and must be mapped off.
  if (!any_ordinal_probit ||
      sum(n_ordinal_cuts_per_trait) == 0L)
    tmb_map$ordinal_log_increments <- factor(NA_integer_)
  ## sigma_eps is the noise-scale parameter for the *continuous* families
  ## (gaussian fid 0, lognormal fid 3, gamma fid 4 with sigma_eps = CV).
  ## Map it off and fix at log(1) only when NONE of those families is in use.
  any_continuous <- any(family_id_vec %in% c(0L, 3L, 4L))
  ## Detect whether unique() is at per-row resolution (OLRE regime). We
  ## compute these flags up here so the per-family-aware OLRE selection
  ## block below can also use them.
  cell_W <- paste(trait_id, site_species_id, sep = "_")
  per_row_diag_W <- use_diag_W && length(unique(cell_W)) == n_obs
  cell_B <- paste(trait_id, site_id, sep = "_")
  per_row_diag_B <- use_diag_B && length(unique(cell_B)) == n_obs
  if (!any_continuous) {
    tmb_map$log_sigma_eps <- factor(NA_integer_)
    tmb_params$log_sigma_eps <- 0
  } else {
    ## Q7: auto-suppress sigma_eps when a `diag()` term is at the per-row
    ## level — i.e., the diag random effects index the same atoms as the
    ## observation residual. Keeping both estimable creates a non-identifiable
    ## sum sd_W[t]^2 + sigma_eps^2; the user's intent when they wrote
    ## `+ unique(0 + trait | <row-level group>)` is for unique(S) to BE the
    ## row-level residual. We honour that by fixing sigma_eps to a tiny
    ## fraction of the response sd so the Gaussian density stays well-defined
    ## while diag(Psi) absorbs the row-level variation.
    if (per_row_diag_W || per_row_diag_B) {
      level_lab <- if (per_row_diag_W) ss_name else site
      data_sd  <- stats::sd(y)
      small_eps <- max(1e-3 * data_sd, 1e-6)
      tmb_params$log_sigma_eps <- log(small_eps)
      tmb_map$log_sigma_eps    <- factor(NA_integer_)
      cli::cli_inform(c(
        "i" = paste0(
          "Auto-suppressing {.code sigma_eps}: ",
          "{.code unique(0 + trait | ", level_lab, ")} is at the per-row level, so it already absorbs the observation residual."
        ),
        "*" = "Fixed at {.val {signif(small_eps, 3)}} (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by {.code unique()}."
      ))
    }
  }

  ## ---- Per-family-aware OLRE selection (W-tier) ------------------------
  ## When `unique(0 + trait | <unit_obs>)` is at the per-row level, the
  ## resulting per-trait random effects on the linear predictor are an
  ## observation-level random effect (OLRE). For some response families
  ## OLRE is unidentifiable or biologically suspect; we handle these per
  ## trait so that mixed-family fits do the right thing for each trait.
  ##
  ## Family-id table for OLRE handling (W-tier, per-row regime):
  ##   * fid 1 (binomial), all rows single-trial (n_trials == 1): SKIP
  ##     OLRE for that trait. Single-trial Bernoulli OLRE has no
  ##     within-cell information to identify the variance (Nakagawa &
  ##     Schielzeth 2010). The MLE is sd_W[t] -> 0; mapping the
  ##     parameter off makes the unidentifiability explicit and removes
  ##     a spurious free parameter.
  ##   * fid 12, 13 (delta_lognormal / delta_gamma): WARN. The OLRE
  ##     enters the shared linear predictor of the hurdle, which mixes
  ##     presence and abundance noise; the resulting variance estimate
  ##     is hard to interpret biologically. The fit is still allowed.
  ##   * all other single families (0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
  ##     and mixed-within-trait combinations: fit OLRE normally.
  ##
  ## Multi-trial binomial (cbind(succ, fail) or weights = n_trials with
  ## n_trials > 1) is identifiable in principle, so we leave the trait
  ## estimable in that case. Mixed Bernoulli + non-Bernoulli within a
  ## single trait (which we expect to be rare) is also left estimable
  ## because the non-Bernoulli rows contribute identifying information.
  if (use_diag_W && per_row_diag_W) {
    family_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(NA_integer_)
      fids_t <- unique(family_id_vec[rows_t])
      if (length(fids_t) == 1L) as.integer(fids_t) else NA_integer_
    }, integer(1))
    bernoulli_only_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      isTRUE(all(family_id_vec[rows_t] == 1L) &&
             all(n_trials[rows_t] == 1))
    }, logical(1))
    ## ordinal_probit (fid 14): OLRE is unidentifiable for the same scale-
    ## absorbing reason as single-trial Bernoulli. The threshold model fixes
    ## sigma2_d = 1 by convention to identify the cutpoint scale; adding
    ## sd_W on top introduces an extra scale factor that the cutpoints
    ## absorb (tau_k -> tau_k / sqrt(sd_W^2 + 1)), so sd_W is not separately
    ## identifiable. Same auto-skip as bernoulli_only_per_trait.
    ordinal_only_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      isTRUE(all(family_id_vec[rows_t] == 14L))
    }, logical(1))
    skip_olre_t <- bernoulli_only_per_trait | ordinal_only_per_trait
    warn_olre_t <- !is.na(family_per_trait) &
                   family_per_trait %in% c(12L, 13L)
    trait_levels_lab <- levels(data[[trait]])
    if (any(skip_olre_t)) {
      ## Pin theta_diag_W[t] at log(1e-6) so the reported sd_W[t] is
      ## essentially zero; map both the per-trait variance AND the
      ## corresponding s_W column to NA so neither is estimated.
      pin_log_sd <- log(1e-6)
      tmb_params$theta_diag_W[skip_olre_t] <- pin_log_sd
      ## Build a length-n_traits factor map: NA for skipped traits, 1L
      ## for the rest (so they remain free; unless diag_W_common is set,
      ## in which case we collapse the free entries to a shared level).
      td_map <- rep(NA_integer_, n_traits)
      free_idx <- which(!skip_olre_t)
      if (length(free_idx) > 0L) {
        if (diag_W_common) {
          td_map[free_idx] <- 1L
        } else {
          td_map[free_idx] <- seq_along(free_idx)
        }
      }
      tmb_map$theta_diag_W <- factor(td_map)
      ## Map off the s_W rows (one per trait) for skipped traits. The
      ## init values stay at 0 so dnorm(0, 0, 1e-6, true) contributes
      ## only a constant to the log-density.
      sW_map <- matrix(seq_len(length(tmb_params$s_W)),
                       nrow = nrow(tmb_params$s_W),
                       ncol = ncol(tmb_params$s_W))
      sW_map[skip_olre_t, ] <- NA_integer_
      ## Re-number the remaining free entries as 1..K to keep TMB happy.
      keep <- !is.na(sW_map)
      sW_map[keep] <- seq_len(sum(keep))
      tmb_map$s_W <- factor(as.integer(sW_map))
      skipped_labs <- trait_levels_lab[skip_olre_t]
      ## Two reason kinds: single-trial Bernoulli (PR #45) or ordinal_probit
      ## (Phase G). The cli messages keep separate templates so that the
      ## existing PR #45 test fixtures continue to grep "Skipping OLRE for
      ## single-trial Bernoulli". Each template is gated by whether any
      ## traits in that category appear in skip_olre_t.
      bernoulli_skipped_labs <- trait_levels_lab[bernoulli_only_per_trait]
      ordinal_skipped_labs   <- trait_levels_lab[ordinal_only_per_trait]
      if (length(bernoulli_skipped_labs) > 0L) {
        cli::cli_inform(c(
          "i" = "Skipping OLRE for single-trial Bernoulli trait{?s}: sd_W is unidentifiable when each (trait, {ss_name}) cell has one 0/1 observation.",
          "i" = "Trait{?s} affected: {.val {bernoulli_skipped_labs}}.",
          "*" = "Mapped {.code theta_diag_W[t]} and the corresponding {.code s_W} column off; pass multi-trial data ({.code cbind(successes, failures)} or {.code weights = n_trials}) to recover identifiability."
        ))
      }
      if (length(ordinal_skipped_labs) > 0L) {
        n_ord <- length(ordinal_skipped_labs)
        cli::cli_inform(c(
          "i" = "Skipping OLRE for {n_ord} ordinal_probit trait{?s}: sd_W is structurally unidentifiable in the threshold model.",
          "i" = "Trait{?s} affected: {.val {ordinal_skipped_labs}}.",
          "*" = "The threshold model fixes sigma2_d = 1 by convention; adding sd_W introduces an extra scale factor that the cutpoints absorb. {.code theta_diag_W[t]} and the corresponding {.code s_W} column are mapped off."
        ))
      }
    }
    if (any(warn_olre_t)) {
      warn_labs <- trait_levels_lab[warn_olre_t]
      cli::cli_warn(c(
        "OLRE on hurdle / delta families is applied to the shared linear predictor and may not be biologically interpretable.",
        "i" = "Trait{?s} affected: {.val {warn_labs}}.",
        "*" = "Consider using a non-hurdle family for these traits, or treat the OLRE result as exploratory."
      ))
    }
  }

  ## The TMB engine is compiled at install time as src/gllvmTMB.cpp; the
  ## DLL is registered via NAMESPACE useDynLib() and loaded automatically.
  ## (Earlier versions compiled the engine at runtime under
  ## src/gllvmTMB.cpp because the legacy package shipped two
  ## templates; gllvmTMB 0.2.0 ships only the multivariate engine.)

  ## ---- random vector --------------------------------------------------
  random <- character(0)
  if (use_rr_B)   random <- c(random, "z_B")
  if (use_diag_B) random <- c(random, "s_B")
  if (use_rr_W)   random <- c(random, "z_W")
  if (use_diag_W) random <- c(random, "s_W")
  if (use_propto) random <- c(random, "p_phy")
  if (use_diag_species) random <- c(random, "q_sp")
  if (use_diag_cluster2) random <- c(random, "r_c2")
  if (use_equalto) random <- c(random, "e_eq")
  if (use_spde && !is_spatial_latent) random <- c(random, "omega_spde")
  if (is_spatial_latent)              random <- c(random, "omega_spde_lv")
  if (use_spde_slope)                 random <- c(random, "omega_spde_aug")
  if (use_spde_latent_slope)          random <- c(random, "g_spde_slope")
  if (use_phylo_rr) random <- c(random, "g_phy")
  if (use_phylo_diag) random <- c(random, "g_phy_diag")
  if (use_phylo_slope_correlated) {
    random <- c(random, "b_phy_aug")
  } else if (use_phylo_slope) {
    random <- c(random, "b_phy_slope")
  }
  if (use_phylo_latent_slope) random <- c(random, "g_phy_slope")
  if (use_re_int)   random <- c(random, "u_re_int")
  ## Phase 2a: the latent missing UNIT-level x values are integrated by Laplace.
  ## Phase 5a: the DISCRETE (binary) route has NO latent x (it is summed out
  ## exactly), so x_mis stays out of `random` -- only the continuous Gaussian
  ## route adds it.
  if (use_mi_predictor && !use_mi_discrete) random <- c(random, "x_mis")
  ## Phase 2b: the unit-level grouped covariate intercepts u_mi_group ~ N(0,1)
  ## also join the Laplace-integrated `random` set.
  if (use_mi_group) random <- c(random, "u_mi_group")
  ## Phase 3: the phylogenetic covariate field g_x ~ N(0, A) is a SEPARATE
  ## Laplace-integrated latent block (its OWN field, NOT shared with any
  ## response phylo field -- design 69 sec.5). Independent-only in Phase 3.
  if (use_mi_phylo) random <- c(random, "g_x")

  ## Design 48 §2 Mitigation A (single-trait warmup). Opt-in via
  ## `control$init_strategy = "single_trait_warmup"`. Fits an
  ## intercept-only univariate GLM per trait (with that trait's
  ## family) and seeds the matching `log_phi_*` entries before
  ## MakeADFun. No-op for traits whose family doesn't carry a phi
  ## parameter (e.g. Gaussian, Poisson, binomial).
  if (identical(control$init_strategy, "single_trait_warmup")) {
    trait_vec_int <- as.integer(data[[trait]])
    warm <- .gllvmTMB_single_trait_warmup(
      trait_vec     = trait_vec_int,
      y             = as.numeric(y),
      family_per_row = family_per_row,
      n_traits      = n_traits,
      verbose       = isTRUE(control$verbose)
    )
    for (nm in names(warm)) tmb_params[[nm]] <- warm[[nm]]
  }

  obj <- TMB::MakeADFun(
    data       = tmb_data,
    parameters = tmb_params,
    map        = tmb_map,
    random     = random,
    DLL        = "gllvmTMB",
    silent     = silent
  )

  ## Optimiser dispatch: nlminb (default) or optim with user-supplied
  ## method (per Maeve McGillycuddy's email — optim/BFGS is often more
  ## robust than nlminb for two-level rr fits).
  run_one <- function(par_init) {
    if (identical(control$optimizer, "optim")) {
      opt_args <- control$optArgs
      method <- opt_args$method %||% "BFGS"
      opt_args$method <- method
      opt_args$control <- utils::modifyList(
        list(maxit = 2000),
        opt_args$control %||% list()
      )
      do.call(stats::optim,
              c(list(par = par_init, fn = obj$fn, gr = obj$gr), opt_args)) -> raw
      list(par = raw$par, objective = raw$value,
           convergence = raw$convergence, message = raw$message %||% "",
           iterations = unname(raw$counts[["function"]] %||% NA_integer_),
           evaluations = unname(raw$counts[["gradient"]] %||% NA_integer_))
    } else {
      nlminb_args <- control$optArgs
      keep <- names(nlminb_args) %in% c("control", "lower", "upper", "scale")
      if (length(nlminb_args) > 0L && any(!keep) && isTRUE(control$verbose)) {
        cat(sprintf(
          "  nlminb optArgs ignored: %s\n",
          paste(names(nlminb_args)[!keep], collapse = ", ")
        ))
      }
      nlminb_args <- nlminb_args[keep]
      nlminb_args$control <- utils::modifyList(
        list(eval.max = 2000, iter.max = 1500),
        nlminb_args$control %||% list()
      )
      do.call(stats::nlminb,
              c(list(start = par_init, objective = obj$fn,
                     gradient = obj$gr), nlminb_args))
    }
  }

  ## Multi-start: run n_init fits with jittered starting parameter
  ## vectors (per Maeve McGillycuddy's recommendation), keep the best.
  best_opt <- NULL
  best_obj <- Inf
  n_restarts <- max(1L, control$n_init)
  restart_history <- vector("list", n_restarts)
  for (i in seq_len(n_restarts)) {
    par0 <- if (i == 1L) {
      obj$par
    } else {
      .gllvmTMB_reclamp_start_par(
        obj$par + stats::rnorm(length(obj$par), sd = control$init_jitter)
      )
    }
    elapsed_start <- proc.time()[["elapsed"]]
    opt_i <- tryCatch(run_one(par0), error = function(e) e)
    elapsed_s <- proc.time()[["elapsed"]] - elapsed_start
    if (inherits(opt_i, "error")) {
      restart_history[[i]] <- .gllvmTMB_restart_history_row(
        restart = i,
        start_label = if (i == 1L) "initial" else "jitter",
        start_method = start_provenance$start_method,
        optimizer = control$optimizer,
        jitter_sd = if (i == 1L) 0 else control$init_jitter,
        objective = NA_real_,
        convergence = NA_integer_,
        message = conditionMessage(opt_i),
        elapsed_s = elapsed_s,
        iterations = NA_integer_,
        evaluations = NA_integer_,
        success = FALSE
      )
      next
    }
    if (isTRUE(control$verbose))
      cat(sprintf("  restart %d: -logLik = %.3f, conv = %s\n",
                  i, opt_i$objective,
                  ifelse(is.null(opt_i$convergence), "?", opt_i$convergence)))
    restart_history[[i]] <- .gllvmTMB_restart_history_row(
      restart = i,
      start_label = if (i == 1L) "initial" else "jitter",
      start_method = start_provenance$start_method,
      optimizer = control$optimizer,
      jitter_sd = if (i == 1L) 0 else control$init_jitter,
      objective = opt_i$objective,
      convergence = opt_i$convergence %||% NA_integer_,
      message = opt_i$message %||% "",
      elapsed_s = elapsed_s,
      iterations = opt_i$iterations %||% NA_integer_,
      evaluations = opt_i$evaluations %||% NA_integer_,
      success = is.finite(opt_i$objective)
    )
    if (opt_i$objective < best_obj) {
      best_obj <- opt_i$objective
      best_opt <- opt_i
    }
  }
  restart_history <- do.call(rbind, restart_history)
  if (is.null(best_opt))
    cli::cli_abort("All {control$n_init} restarts failed.")
  opt <- best_opt
  restart_history$selected <- FALSE
  selectable <- which(restart_history$success &
                        is.finite(restart_history$objective))
  selected_idx <- selectable[which.min(restart_history$objective[selectable])]
  restart_history$selected[selected_idx] <- TRUE
  start_provenance$selected_restart <- restart_history$restart[
    which(restart_history$selected)[1L]
  ]

  ## ---- Force TMB internal state to the selected optimum --------------
  ## After the multi-start loop, TMB's internal `obj$env$last.par` is
  ## whatever the FINAL restart evaluated last -- not necessarily
  ## `best_opt$par`. `obj$env$last.par.best` is TMB's globally-best-seen
  ## evaluation, which is usually `best_opt$par` but can disagree in
  ## pathological cases (a restart's optimizer transiently visited
  ## better params and walked away).
  ##
  ## Without this block, `obj$report()` (default arg is `last.par`)
  ## returned report values for the LAST restart's last step rather
  ## than for `opt$par`. Every downstream extractor reading
  ## `fit$report` -- extract_Sigma, extract_correlations,
  ## extract_communality, extract_phylo_signal, ordination,
  ## communality, repeatability, plot.gllvmTMB_multi, ... -- then
  ## reported quantities inconsistent with `fit$opt$par` and
  ## `fit$opt$objective`. The bug only manifested when restart-1
  ## won AND restart-N (N > 1) ran last.
  ##
  ## Fix: (1) re-evaluate `obj$fn(opt$par)` so the inner optim runs
  ## at the selected fixed-effect optimum AND `obj$env$last.par`
  ## gets re-populated with the FULL parameter vector (fixed-effect
  ## block = `opt$par`, random-effect block = the conditional mode
  ## of RE given `opt$par`); (2) force `last.par.best <- last.par`
  ## so downstream consumers reading `last.par.best`
  ## (R/plot.R, R/extractors.R, R/extract-repeatability.R,
  ## R/methods-gllvmTMB.R) also see `opt$par`-aligned values;
  ## (3) call `obj$report()` with no args (so it reads the just-
  ## forced `last.par`) and `TMB::sdreport(obj, par.fixed = opt$par,
  ## ...)` with explicit `par.fixed = opt$par` so the report and
  ## sdreport are self-consistent regardless of TMB's internal-state
  ## quirks. NOTE: `obj$report(opt$par)` would be incorrect --
  ## `obj$report()` expects the FULL parameter vector (fixed + RE),
  ## not just the fixed-effects-only `opt$par`. The correct idiom
  ## is `obj$fn(opt$par); obj$report()`.
  ##
  ## See docs/dev-log/audits/2026-05-15-external-audit-response.md
  ## for the bug history.
  invisible(obj$fn(opt$par))
  obj$env$last.par.best <- obj$env$last.par

  rep <- obj$report()
  sdreport_error <- NULL
  sd_rep <- if (isFALSE(control$se)) {
    sdreport_error <- "standard-error calculation skipped by gllvmTMBcontrol(se = FALSE)"
    NULL
  } else {
    tryCatch(
      TMB::sdreport(obj, par.fixed = opt$par,
                    getJointPrecision = FALSE),
      error = function(e) {
        sdreport_error <<- conditionMessage(e)
        NULL
      }
    )
  }

  ## Track whether the user fitted a latent() / phylo_latent() with rank > 1 and
  ## without a `lambda_constraint`. The implied Sigma is identifiable, but
  ## raw Lambda is only identified up to rotation. Surfaced once via
  ## `getLoadings()` / `print()` so users know they should rotate or pin
  ## before comparing loadings across fits or against another package.
  ## phylo_unique() injects its own diagonal lambda_constraint (so the
  ## `is.null(lambda_constraint$phy)` test is FALSE here), and is
  ## structurally rotation-free.
  needs_rotation_advice <- list(
    B    = isTRUE(use_rr_B)         && is.null(lambda_constraint$B)    && isTRUE(d_B   > 1L),
    W    = isTRUE(use_rr_W)         && is.null(lambda_constraint$W)    && isTRUE(d_W   > 1L),
    phy  = isTRUE(use_phylo_rr)     && is.null(lambda_constraint$phy)  && isTRUE(d_phy > 1L),
    spde = isTRUE(is_spatial_latent) && is.null(lambda_constraint$spde) && isTRUE(d_spde_lv > 1L)
  )

  fit <- structure(
    list(
      tmb_obj      = obj,
      tmb_data     = tmb_data,
      tmb_params   = tmb_params,
      tmb_map      = tmb_map,
      opt          = opt,
      sd_report    = sd_rep,
      report       = rep,
      formula      = parsed$fixed,
      covstructs   = parsed$covstructs,
      family       = family,
      ## M1.8 (2026-05-17): preserve the original `family` argument
      ## (potentially a list with `family_var` attribute for mixed-family
      ## fits) so downstream callers — notably `bootstrap_Sigma()`'s
      ## refit_one — can pass the correct family list back to `gllvmTMB()`.
      ## For single-family fits, `family_input == family`.
      family_input = family_input,
      data         = data,
      ## Phase 1 missing-data layer (design 59 sec.4b). `missing_data` is the
      ## shared-contract fit slot; `data_original` is the pre-drop / pre-mask
      ## data so original-row accounting is recoverable. `random` records the
      ## TMB random-effect block names (needed to rebuild MakeADFun, e.g. the
      ## sentinel-invariance check).
      missing_data = .gllvmTMB_build_missing_data(missing_meta, is_y_observed, mi_model),
      data_original = if (!is.null(missing_meta)) missing_meta$data_original else data,
      random       = random,
      trait_col    = trait,
      unit_col     = site,
      unit_obs_col = unit_obs,
      species_col  = species,
      ## `cluster_col` is the canonical name (matches the public
      ## `cluster = ...` argument); `species_col` is preserved as a
      ## back-compat alias and is identical in value.
      cluster_col  = species,
      ## Second independent diagonal grouping (cluster2 slot). NULL when
      ## the slot is unused (assigning NULL drops the list element, so
      ## `fit$cluster2_col` returns NULL).
      cluster2_col = cluster2_col,
      n_traits     = n_traits,
      n_sites      = n_sites,
      n_species    = n_species,
      n_site_species = n_site_species,
      d_B          = d_B,
      d_W          = d_W,
      use          = list(rr_B = use_rr_B, diag_B = use_diag_B,
                          rr_W = use_rr_W, diag_W = use_diag_W,
                          propto = use_propto, diag_species = use_diag_species,
                          diag_cluster2 = use_diag_cluster2,
                          equalto = use_equalto, spde = use_spde,
                          phylo_rr = use_phylo_rr,
                          ## Design 56 Sec. 9.5a: augmented phylo_latent
                          ## (block-diagonal reduced-rank random slope). Its
                          ## own dedicated engine block, distinct from the
                          ## intercept-only phylo_rr.
                          phylo_latent_slope = use_phylo_latent_slope,
                          ## Paired phylogenetic PGLLVM: phylo_diag is the new dedicated
                          ## engine slot for per-trait phylogenetic random
                          ## intercepts. Co-fits with phylo_rr to give the
                          ## decomposition Sigma_phy = Lambda_phy
                          ## Lambda_phy^T + Psi_phy.
                          phylo_diag = use_phylo_diag,
                          ## Sub-flags identifying the canonical-keyword
                          ## flavour: phylo_unique (when ALONE) reuses the
                          ## phylo_rr slot with d = T and a diagonal Lambda
                          ## constraint (legacy path; kept for backward
                          ## compatibility); spatial_scalar reuses the spde
                          ## slot with a tied log_tau across traits. Used
                          ## by print() and the pkgdown reference.
                          phylo_unique   = isTRUE(is_phylo_unique),
                          spatial_scalar = isTRUE(is_spatial_scalar),
                          spatial_latent = isTRUE(is_spatial_latent),
                          ## "indep" mode (one of the quartet): marginal-
                          ## only canonical keywords. Engine path
                          ## identical to the matching unique() /
                          ## phylo_unique() / spatial_unique() standalone;
                          ## these flags only steer print()/extract_*/
                          ## tidy() label dispatch so user-facing output
                          ## reads "indep" / "phylo_indep" /
                          ## "spatial_indep" when the user wrote the
                          ## indep form.
                          indep_B        = isTRUE(is_indep_B),
                          indep_W        = isTRUE(is_indep_W),
                          indep_cluster  = isTRUE(is_indep_cluster),
                          phylo_indep    = isTRUE(is_phylo_indep),
                          spatial_indep  = isTRUE(is_spatial_indep),
                          ## "dep" quartet: full-unstructured canonical
                          ## keywords. Engine path identical to the
                          ## matching latent(d = n_traits) / phylo_latent(
                          ## d = n_traits) / spatial_latent(d = n_traits)
                          ## standalone (the packed-triangular Lambda at
                          ## full rank IS the Cholesky factor of
                          ## unstructured Sigma). These flags only steer
                          ## print()/extract_*/tidy() label dispatch so
                          ## user-facing output reads "dep" / "phylo_dep"
                          ## / "spatial_dep" when the user wrote the dep
                          ## form.
                          dep_B          = isTRUE(is_dep_B),
                          dep_W          = isTRUE(is_dep_W),
                          dep_cluster    = isTRUE(is_dep_cluster),
                          phylo_dep      = isTRUE(is_phylo_dep),
                          spatial_dep    = isTRUE(is_spatial_dep),
                          ## DISTINCT from `phylo_dep` (= the intercept-only
                          ## phylo_dep(0 + trait | sp) RR path). This flag
                          ## marks the augmented phylo_dep(1 + x | sp)
                          ## slope path (full unstructured 2T x 2T Sigma_b
                          ## via theta_dep_chol). extract_Sigma() keys on
                          ## it to surface the reported Sigma_b_dep.
                          phylo_dep_slope = isTRUE(use_phylo_dep_slope),
                          ## RE-03 multi-slope: the ordered slope-covariate
                          ## names (length s) so extract_Sigma() can label the
                          ## (1+s)T interleaved Sigma_b_dep rows as
                          ## intercept.<t>, slope.<x1>.<t>, ... NULL off the dep
                          ## path.
                          phylo_dep_slope_cols =
                            if (use_phylo_dep_slope) phylo_slope_xcols else NULL,
                          kernel = isTRUE(has_kernel_term),
                          ## Augmented SPDE random slopes (Design 64). DISTINCT
                          ## from the intercept-only spatial_dep / spatial_latent
                          ## flags above. spde_slope marks the base
                          ## spatial_unique / spatial_indep (1 + x | coords)
                          ## augmented path (2x2 cross-field Sigma_field via
                          ## sd_spde_b / cor_spde_b; extract_Sigma keys on it).
                          ## spde_dep_slope marks the
                          ## spatial_dep(1 + x | coords) full unstructured 2T x 2T
                          ## field-covariance path (extract_Sigma keys on it to
                          ## surface the reported Sigma_field); spde_latent_slope
                          ## marks the spatial_latent(1 + x | coords, d) block-
                          ## diagonal reduced-rank path.
                          spde_slope     = isTRUE(use_spde_slope),
                          spde_dep_slope = isTRUE(use_spde_dep_slope),
                          spde_latent_slope = isTRUE(use_spde_latent_slope),
                          re_int = use_re_int),
      kernel_levels = if (has_kernel_term) {
                        list(name = kernel_name, internal_level = "phy")
                      } else NULL,
      re_int       = if (use_re_int) list(
                       groups   = re_int_groups,
                       n_groups = re_int_n_groups,
                       offsets  = re_int_offsets
                     ) else NULL,
      d_phy        = d_phy,
      d_spde_lv    = d_spde_lv,
      mesh         = mesh,
      ## Phylogenetic inputs are stored on the fit so post-fit refits
      ## (e.g. fitting the same data with a different covstruct intent)
      ## do not require the user to pass the tree/VCV again.
      phylo_vcv    = phylo_vcv,
      phylo_tree   = phylo_tree,
      X_fix        = X_fix,
      X_fix_names  = colnames(X_fix),
      lambda_constraint     = lambda_constraint,
      needs_rotation_advice = needs_rotation_advice,
      restart_history = restart_history,
      start_provenance = start_provenance,
      sdreport_error = sdreport_error,
      package_version = utils::packageVersion("gllvmTMB"),
      stage        = 2L
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
  ## Phase 2a: fill the missing-predictor conditional mode (x_mis EBLUP) from
  ## the fitted parameter list into the registry (+ the full unit-level x).
  if (use_mi_predictor) {
    par_list <- obj$env$parList(opt$par)
    ## Phase 5a: the binary route reads the per-unit conditional probability
    ## from the engine REPORT(mi_probability); pass the report to gll_finalize_mi.
    mi_report <- tryCatch(obj$report(opt$par), error = function(e) NULL)
    fit$missing_data <- gll_finalize_mi(
      fit$missing_data, par_list, mi_model, sdr = sd_rep, report = mi_report
    )
  }
  fit$fit_health <- .gllvmTMB_build_fit_health(fit)
  fit
}

## Build the shared-contract `fit$missing_data` slot (design 59 sec.4b).
##
## Fields:
##   original_row -- pre-drop / pre-mask row index for each *model* (engine)
##                   row. response="include" keeps all rows so this is 1:N;
##                   response="drop" maps surviving model rows back to their
##                   original positions.
##   model_row    -- 1..(n model rows), the index into the fitted data / y.
##   observed_y   -- is_y_observed over the model rows (1 = contributes to the
##                   likelihood). All-ones under response="drop".
##   counts       -- n_total (original rows), n_observed, n_missing_response,
##                   n_model_rows, n_dropped.
##   slice        -- the implementation slice tag.
##   contract_version -- the shared-contract version this slot conforms to.
##
## `missing_meta` is NULL for internal callers that bypass the public
## gllvmTMB() entry (e.g. direct gllvmTMB_multi_fit() in older tests); in that
## case the slot is built from is_y_observed alone (treated as response="drop"
## complete-case when all-ones).
.gllvmTMB_build_missing_data <- function(missing_meta, is_y_observed,
                                         mi_model = NULL) {
  is_y_observed <- as.integer(is_y_observed)
  n_model <- length(is_y_observed)
  model_row <- seq_len(n_model)

  if (is.null(missing_meta)) {
    n_total <- n_model
    original_row <- model_row
    response <- "drop"
    predictor <- "fail"
    engine <- "laplace"
    n_missing_response <- sum(is_y_observed == 0L)
  } else {
    response <- missing_meta$response
    predictor <- missing_meta$predictor
    engine <- missing_meta$engine
    original_row <- missing_meta$original_row
    if (is.null(original_row)) original_row <- model_row
    n_missing_response <- missing_meta$n_missing_response %||% 0L
    n_total <- if (!is.null(missing_meta$data_original)) {
      nrow(missing_meta$data_original)
    } else {
      n_model
    }
  }

  n_observed <- sum(is_y_observed == 1L)
  ## Under response="drop" the dropped rows are absent from the model; the
  ## n_missing_response count comes from missing_meta (pre-drop). Under
  ## response="include" the missing rows are present-but-masked, so
  ## n_missing_response == sum(is_y_observed == 0L). n_dropped distinguishes
  ## the two.
  n_dropped <- max(0L, n_total - n_model)
  n_likelihood <- sum(is_y_observed == 1L)

  ## Missing-PREDICTOR registry (design 67 / shared contract sec.4b). Empty
  ## list when no mi() term is present; populated (conditional_mode filled
  ## post-fit by gll_finalize_mi) for a fitted Gaussian mi() predictor.
  predictors <- if (!is.null(mi_model) && isTRUE(mi_model$enabled)) {
    gll_mi_metadata(mi_model)
  } else {
    list()
  }

  list(
    original_row = as.integer(original_row),
    model_row = as.integer(model_row),
    observed_y = is_y_observed,
    response = response,
    predictor = predictor,
    ## drmTMB-aligned policy aliases (shared MD contract): response_policy /
    ## predictor_policy mirror response / predictor.
    response_policy = response,
    predictor_policy = predictor,
    engine = engine,
    predictors = predictors,
    ## counts carries BOTH the gllvmTMB-native field names and the
    ## drmTMB-aligned names (design 59 sec.4b shared contract). drmTMB ships
    ## retained_rows / observed_response / missing_response / likelihood_rows;
    ## we mirror those so summary()$missing and cross-package tooling line up,
    ## while keeping the descriptive n_* names already in use.
    counts = list(
      n_total = as.integer(n_total),
      n_model_rows = as.integer(n_model),
      n_observed = as.integer(n_observed),
      n_missing_response = as.integer(n_missing_response),
      n_dropped = as.integer(n_dropped),
      ## drmTMB-aligned field names (shared MD contract):
      retained_rows = as.integer(n_model),
      observed_response = as.integer(n_observed),
      missing_response = as.integer(n_missing_response),
      likelihood_rows = as.integer(n_likelihood)
    ),
    slice = "Phase1-s2",
    contract_version = "59-v1"
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.gllvmTMB_reclamp_start_par <- function(par) {
  nm <- names(par)
  if (is.null(nm)) return(par)
  phi <- grepl("(^|\\.)log_phi", nm) | grepl("^log_phi", nm)
  if (any(phi)) {
    par[phi] <- pmax(pmin(par[phi], log(100.0)), log(0.01))
  }
  par
}

.gllvmTMB_restart_history_row <- function(restart, start_label, start_method,
                                          optimizer, jitter_sd, objective,
                                          convergence, message, elapsed_s,
                                          iterations, evaluations, success) {
  scalar_num <- function(x, missing = NA_real_) {
    if (is.null(x) || length(x) == 0L) return(missing)
    x <- as.numeric(x)
    if (length(x) > 1L) return(sum(x, na.rm = TRUE))
    x
  }
  scalar_int <- function(x) as.integer(round(scalar_num(x, NA_real_)))
  scalar_chr <- function(x) {
    if (is.null(x) || length(x) == 0L) return("")
    paste(as.character(x), collapse = "; ")
  }
  data.frame(
    restart = scalar_int(restart),
    start_label = scalar_chr(start_label),
    start_method = scalar_chr(start_method),
    optimizer = scalar_chr(optimizer),
    jitter_sd = scalar_num(jitter_sd),
    objective = scalar_num(objective),
    convergence = scalar_int(convergence),
    message = scalar_chr(message),
    elapsed_s = scalar_num(elapsed_s),
    iterations = scalar_int(iterations),
    evaluations = scalar_int(evaluations),
    success = isTRUE(success),
    selected = FALSE,
    stringsAsFactors = FALSE
  )
}
