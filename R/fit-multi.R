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
                               family, weights,
                               phylo_vcv = NULL, phylo_tree = NULL,
                               known_V = NULL,
                               mesh = NULL,
                               lambda_constraint = NULL,
                               control, silent,
                               unit_obs = "site_species") {
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
  ##              model; K-category ordinal y with K >= 3 categories).
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
      cli::cli_abort(c(
        "Unsupported family: {.val {f$family}}.",
        "i" = "Currently supported: {.code gaussian()}, {.code binomial()}, {.code poisson()}, {.code lognormal()}, {.code Gamma()}, {.code nbinom2()}, {.code tweedie()}, {.code Beta()}, {.code betabinomial()}, {.code student()}, {.code truncated_poisson()}, {.code truncated_nbinom2()}, {.code delta_lognormal()}, {.code delta_gamma()}, {.code ordinal_probit()}."
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
    family    <- family[[1]]   # keep one for downstream linkinv
  } else {
    fl_pair <- family_to_id(family)
    family_id <- fl_pair[1]
    link_id   <- fl_pair[2]
    n_obs <- nrow(data)
    family_id_vec <- rep(family_id, n_obs)
    link_id_vec   <- rep(link_id,   n_obs)
    for (i in seq_along(family_per_row)) family_per_row[[i]] <- family
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
  use_propto <- any(kinds == "propto")
  use_equalto <- any(kinds == "equalto")
  use_spde   <- any(kinds == "spde")
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
  phy_is_unique  <- vapply(phy_idx, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.phylo_unique),
                           logical(1L))
  phy_is_indep   <- vapply(phy_idx, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.indep),
                           logical(1L))
  phy_is_dep     <- vapply(phy_idx, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.dep),
                           logical(1L))
  phylo_rr_idx   <- phy_idx[!phy_is_unique]   # phylo_latent + phylo_dep terms
  phylo_diag_idx <- phy_idx[ phy_is_unique]   # phylo_unique terms (incl. phylo_indep)
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
  ## spatial_scalar(): rewrites to spde(form, .spatial_scalar = TRUE).
  ## We tie log_tau_spde across traits via the TMB map mechanism so the
  ## per-trait variances collapse to one shared scalar. No C++ change.
  is_spatial_scalar <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$.spatial_scalar)
  })
  ## spatial_latent(): rewrites to spde(form, .spatial_latent = TRUE, d = K).
  ## K_S shared SPDE fields drive all T traits via a T x K_S loading matrix
  ## Lambda_spde (the spatial analogue of phylo_latent's Lambda_phy). The
  ## TMB template provides a `spde_lv_k` switch that toggles between the
  ## per-trait omega_spde path (used by spatial_unique / spatial_scalar)
  ## and the low-rank Lambda_spde x omega_spde_lv path used here.
  is_spatial_latent <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$.spatial_latent)
  })
  ## spatial_indep(): rewrites to spde(form, .spatial_indep = TRUE).
  ## Same engine path as spatial_unique-alone (per-trait omega_spde with
  ## independent log_tau per trait). The .spatial_indep marker only changes
  ## the printed label and triggers the spatial_indep+spatial_latent guard.
  is_spatial_indep <- isTRUE({
    idx <- which(kinds == "spde")
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$.spatial_indep)
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
                             isTRUE(parsed$covstructs[[i]]$extra$.spatial_latent),
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
              isTRUE(parsed$covstructs[[i]]$extra$.spatial_indep),
              logical(1L)) &
      !vapply(spde_idx_for_dep, function(i)
              isTRUE(parsed$covstructs[[i]]$extra$.spatial_scalar),
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
                                 isTRUE(parsed$covstructs[[i]]$extra$.spatial_indep),
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
                               isTRUE(parsed$covstructs[[i]]$extra$.spatial_indep),
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
      as.integer(cs$extra$d %||% 1L)
    }
  } else 1L
  ## Phylogenetic random slope (Q6): phylo_slope(x | species). Reuses
  ## the Ainv_phy_rr from phylo_rr; only one tree / VCV needed even when
  ## both terms appear. Initial release: ONE continuous covariate, ONE
  ## shared slope variance, slopes shared across traits.
  use_phylo_slope  <- any(kinds == "phylo_slope")
  phylo_slope_xcol <- if (use_phylo_slope) {
    cs <- parsed$covstructs[[which(kinds == "phylo_slope")[1]]]
    deparse(cs$lhs)
  } else NA_character_

  d_B <- if (use_rr_B) {
    cs <- parsed$covstructs[[which(kinds == "rr" & groupings == site)[1]]]
    as.integer(cs$extra$d %||% 1L)
  } else 1L
  d_W <- if (use_rr_W) {
    cs <- parsed$covstructs[[which(kinds == "rr" & groupings == ss_name)[1]]]
    as.integer(cs$extra$d %||% 1L)
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
  ## Diagnostic: error if a rr()/diag() targets an unexpected grouping
  ## that doesn't map to one of the engine's known tiers.
  bad_groups <- which(kinds %in% c("rr","diag")
                      & !(groupings %in% c(site, ss_name, species)))
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

  if (any(is.na(y)) || any(is.na(X_fix)))
    cli::cli_abort("NA in response or design matrix; remove NA rows before fitting.")
  ## Sanity check: y must be in [0, n_trials] for binomial rows.
  bin_rows <- family_id_vec == 1L
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
  beta_rows <- family_id_vec == 7L
  if (any(beta_rows)) {
    if (any(y[beta_rows] <= 0) || any(y[beta_rows] >= 1))
      cli::cli_abort(c(
        "Beta rows: {.code y} must satisfy 0 < y < 1.",
        "i" = "Exact 0s or 1s require a zero-/one-inflated Beta variant."
      ))
  }
  ## Beta-binomial rows: y must be in [0, n_trials], same as binomial.
  bb_rows <- family_id_vec == 8L
  if (any(bb_rows)) {
    if (any(y[bb_rows] < 0) || any(y[bb_rows] > n_trials[bb_rows]))
      cli::cli_abort(c(
        "Beta-binomial rows: `y` (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers."
      ))
  }
  ## Sanity check: y >= 1 for zero-truncated count families.
  trunc_rows <- which(family_id_vec %in% c(10L, 11L))
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
  delta_rows <- family_id_vec %in% c(12L, 13L)
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
    if (any(y[ordinal_rows] != round(y[ordinal_rows])))
      cli::cli_abort(c(
        "ordinal_probit: response must be integer-valued (categories 1..K).",
        "i" = "Coerce {.var y} via {.code as.integer(factor(y))} or pass an ordered factor."
      ))
    if (any(y[ordinal_rows] < 1))
      cli::cli_abort(c(
        "ordinal_probit: response must be in {.val 1..K} (1-indexed).",
        "i" = "Smallest observed category was {min(y[ordinal_rows])}; categories must start at 1."
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
  log_link_only <- all(family_id_vec %in% c(2L, 3L, 4L, 5L, 6L, 10L, 11L, 12L, 13L))
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
      if (!is.null(vcv_inkey) && is.matrix(vcv_inkey)) {
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

  ## ---- Phylogenetic VCV preparation (propto + phylo_latent) -----------------
  n_species <- nlevels(data[[species]])
  species_id <- as.integer(data[[species]]) - 1L
  Cphy_inv      <- matrix(0, n_species, n_species)
  log_det_Cphy  <- 0
  Ainv_phy_rr      <- Matrix::Matrix(0, n_species, n_species, sparse = TRUE)
  log_det_A_phy_rr <- 0
  n_aug_phy        <- n_species
  species_aug_id   <- species_id        # default: tip-only path uses species_id directly
  ## Build the sparse A^-1 machinery whenever either phylo_latent OR
  ## phylo_slope is requested. The two terms share Ainv_phy_rr,
  ## n_aug_phy, log_det_A_phy_rr, and species_aug_id.
  use_any_phy_term <- use_phylo_rr || use_phylo_diag || use_phylo_slope
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
  if (use_propto) {
    if (is.null(phylo_vcv))
      cli::cli_abort("propto() found in formula but {.arg phylo_vcv} is NULL.")
    if (is.null(rownames(phylo_vcv)))
      cli::cli_abort("phylo_vcv must have rownames matching levels of {.var {species}}.")
    levs <- levels(data[[species]])
    if (!all(levs %in% rownames(phylo_vcv)))
      cli::cli_abort("phylo_vcv rownames do not cover all species levels.")
    Cphy <- phylo_vcv[levs, levs, drop = FALSE]
    Cphy <- Cphy + diag(1e-8, nrow = nrow(Cphy)) ## numerical jitter
    Cphy_inv     <- solve(Cphy)
    log_det_Cphy <- as.numeric(determinant(Cphy, logarithm = TRUE)$modulus)
  }

  ## ---- SPDE preparation -------------------------------------------------
  n_mesh <- 1L
  A_proj <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M0 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M1 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M2 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  if (use_spde) {
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

  tmb_data <- list(
    y                = as.numeric(y),
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
    ## Two-U PGLLVM: per-trait phylogenetic random intercepts (psi_phy diag)
    use_phylo_diag   = as.integer(use_phylo_diag),
    ## Q6: phylo_slope data
    use_phylo_slope  = as.integer(use_phylo_slope),
    x_phy_slope      = if (use_phylo_slope) {
                          if (!phylo_slope_xcol %in% names(data))
                            cli::cli_abort(c(
                              "{.arg phylo_slope({phylo_slope_xcol} | {species})} references column {.val {phylo_slope_xcol}}, which is not in {.arg data}.",
                              "i" = "Add the covariate column to the data frame."))
                          as.numeric(data[[phylo_slope_xcol]])
                        } else rep(0.0, n_obs),
    use_re_int       = as.integer(use_re_int),
    n_re_int_terms   = as.integer(n_re_int_terms),
    re_int_offsets   = re_int_offsets_dat,
    re_int_n_groups  = re_int_n_groups_dat,
    re_int_group_id  = re_int_id_mat_dat,
    weights_i        = as.numeric(weights_i)
  )

  init_rr_theta <- function(p, rank) {
    ## Lambda_B/W ~ I_rank diagonal start (so initial Sigma is the identity
    ## scaled by 0). Concretely: lam_diag = 0.5 (sd 1.65), lam_lower = 0.
    c(rep(0.5, rank), rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank))
  }

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
    theta_rr_phy = if (use_phylo_rr) {
                     init_rr_theta_pkg <- function(p, rank)
                       c(rep(0.5, rank), rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank))
                     init_rr_theta_pkg(n_traits, d_phy)
                   } else 0.0,
    g_phy        = matrix(0, nrow = n_aug_phy, ncol = if (use_phylo_rr) d_phy else 1L),
    ## Two-U PGLLVM: per-trait phylogenetic random intercept (psi_phy diag).
    ## When use_phylo_diag = 0 these are mapped off below.
    log_sd_phy_diag = if (use_phylo_diag) rep(0.0, n_traits) else 0.0,
    g_phy_diag      = matrix(0, nrow = n_aug_phy,
                             ncol = if (use_phylo_diag) n_traits else 1L),
    ## Q6: phylo_slope params
    b_phy_slope     = rep(0.0, n_aug_phy),  # one slope per augmented A row
    log_sigma_slope = 0.0,
    u_re_int       = rep(0.0, u_re_int_len),
    log_sigma_re_int = if (use_re_int) rep(0.0, n_re_int_terms) else 0.0,
    ## NB2 / Tweedie per-trait dispersion. log(phi) starts at 0 (phi = 1);
    ## logit(p) starts at 0 (p = 1.5, mid of the compound-Poisson regime).
    log_phi_nbinom2  = rep(0.0, n_traits),
    log_phi_tweedie  = rep(0.0, n_traits),
    logit_p_tweedie  = rep(0.0, n_traits),
    ## Beta / beta-binomial per-trait precision. log(phi) starts at 1.0 so
    ## phi = e ~ 2.72, a moderate-concentration default that avoids the
    ## degenerate phi -> 0 boundary while not being so peaked that the
    ## inner Newton stalls (Smithson & Verkuilen 2006; Hilbe 2014).
    log_phi_beta      = rep(1.0, n_traits),
    log_phi_betabinom = rep(1.0, n_traits),
    ## Student-t per-trait scale (sigma) and log(df-1) (so df > 1).
    ## log(0) = 0 -> sigma = 1; log(df-1) = log(2) -> df = 3 (a common
    ## heavy-tailed default; Lange et al. 1989).
    log_sigma_student = rep(0.0, n_traits),
    log_df_student    = rep(log(2.0), n_traits),
    ## truncated_nbinom2 per-trait dispersion. Same parameterisation as
    ## NB2 (Var = mu + mu^2/phi), but conditioned on y >= 1.
    log_phi_truncnb2  = rep(0.0, n_traits),
    ## Delta (hurdle) families: per-trait dispersion of the *positive*
    ## component only. log(sigma) starts at 0 (sigma_lognormal = 1);
    ## log(phi) starts at 0 (gamma CV = 1, ~Exponential).
    log_sigma_lognormal_delta = rep(0.0, n_traits),
    log_phi_gamma_delta       = rep(0.0, n_traits),
    ## ordinal_probit cutpoint log-increments. Length = sum(K_t - 2) over
    ## ordinal traits (or 1 stub when no trait is ordinal). Initialised
    ## from MASS::polr(method = "probit") per ordinal trait when sample
    ## size permits, else equal-spaced 0.5 (log-increment = log(0.5)).
    ordinal_log_increments = if (any_ordinal_probit && length(ordinal_init_log_incs) > 0L)
                               ordinal_init_log_incs else 0.0
  )

  ## ---- Map: zero-out unused parameters ---------------------------------
  tmb_map <- list()
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
  if (!use_equalto) {
    tmb_map$e_eq <- factor(rep(NA_integer_, length(tmb_params$e_eq)))
  }
  if (!use_spde) {
    tmb_map$log_tau_spde   <- factor(rep(NA_integer_, length(tmb_params$log_tau_spde)))
    tmb_map$log_kappa_spde <- factor(NA_integer_)
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
  if (!use_phylo_slope) {
    tmb_map$b_phy_slope     <- factor(rep(NA_integer_, length(tmb_params$b_phy_slope)))
    tmb_map$log_sigma_slope <- factor(NA_integer_)
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
  any_tweedie <- any(family_id_vec == 6L)
  any_beta    <- any(family_id_vec == 7L)
  any_betabinom <- any(family_id_vec == 8L)
  any_delta_lognormal <- any(family_id_vec == 12L)
  any_delta_gamma     <- any(family_id_vec == 13L)
  if (!any_nbinom2)
    tmb_map$log_phi_nbinom2 <- factor(rep(NA_integer_, n_traits))
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
  if (use_equalto) random <- c(random, "e_eq")
  if (use_spde && !is_spatial_latent) random <- c(random, "omega_spde")
  if (is_spatial_latent)              random <- c(random, "omega_spde_lv")
  if (use_phylo_rr) random <- c(random, "g_phy")
  if (use_phylo_diag) random <- c(random, "g_phy_diag")
  if (use_phylo_slope) random <- c(random, "b_phy_slope")
  if (use_re_int)   random <- c(random, "u_re_int")

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
      method <- control$optArgs$method %||% "BFGS"
      opt_args <- control$optArgs
      opt_args$method <- method
      do.call(stats::optim,
              c(list(par = par_init, fn = obj$fn, gr = obj$gr,
                     control = list(maxit = 2000)), opt_args)) -> raw
      list(par = raw$par, objective = raw$value,
           convergence = raw$convergence, message = raw$message)
    } else {
      stats::nlminb(par_init, obj$fn, obj$gr,
                    control = list(eval.max = 2000, iter.max = 1500))
    }
  }

  ## Multi-start: run n_init fits with jittered starting parameter
  ## vectors (per Maeve McGillycuddy's recommendation), keep the best.
  best_opt <- NULL
  best_obj <- Inf
  for (i in seq_len(max(1L, control$n_init))) {
    par0 <- if (i == 1L) obj$par
            else obj$par + stats::rnorm(length(obj$par),
                                        sd = control$init_jitter)
    opt_i <- tryCatch(run_one(par0), error = function(e) NULL)
    if (is.null(opt_i)) next
    if (isTRUE(control$verbose))
      cat(sprintf("  restart %d: -logLik = %.3f, conv = %s\n",
                  i, opt_i$objective,
                  ifelse(is.null(opt_i$convergence), "?", opt_i$convergence)))
    if (opt_i$objective < best_obj) {
      best_obj <- opt_i$objective
      best_opt <- opt_i
    }
  }
  if (is.null(best_opt))
    cli::cli_abort("All {control$n_init} restarts failed.")
  opt <- best_opt
  rep <- obj$report()
  sd_rep <- TMB::sdreport(obj, getJointPrecision = FALSE)

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
      data         = data,
      trait_col    = trait,
      unit_col     = site,
      unit_obs_col = unit_obs,
      species_col  = species,
      ## `cluster_col` is the canonical name (matches the public
      ## `cluster = ...` argument); `species_col` is preserved as a
      ## back-compat alias and is identical in value.
      cluster_col  = species,
      n_traits     = n_traits,
      n_sites      = n_sites,
      n_species    = n_species,
      n_site_species = n_site_species,
      d_B          = d_B,
      d_W          = d_W,
      use          = list(rr_B = use_rr_B, diag_B = use_diag_B,
                          rr_W = use_rr_W, diag_W = use_diag_W,
                          propto = use_propto, diag_species = use_diag_species,
                          equalto = use_equalto, spde = use_spde,
                          phylo_rr = use_phylo_rr,
                          ## Two-U PGLLVM: phylo_diag is the new dedicated
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
                          re_int = use_re_int),
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
      package_version = utils::packageVersion("gllvmTMB"),
      stage        = 2L
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
  fit
}

`%||%` <- function(a, b) if (is.null(a)) b else a
