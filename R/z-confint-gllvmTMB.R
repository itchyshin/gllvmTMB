## confint() method for fits returned by gllvmTMB().
##
## This file sorts after methods-gllvmTMB.R (z > m) so that this
## definition of confint.gllvmTMB_multi takes precedence at load time.
##
## Three-method API (Phase K):
##   method = "profile"   (NEW DEFAULT) -- profile-likelihood CI via
##                                          TMB::tmbprofile() + uniroot
##                                          (R/profile-ci.R)
##   method = "wald"                    -- Wald CI from sd_report
##   method = "bootstrap"               -- parametric bootstrap via
##                                          bootstrap_Sigma()
##
## Two parameter-class dispatch paths:
##   parm = "Sigma_unit" | "Sigma_unit_obs" | "sigma_phy"
##        (legacy aliases: "Sigma_B", "Sigma_W")
##                                                      -> bootstrap or profile
##   parm = character/integer/missing            -> Wald / profile on
##                                                   fixed effects + var
##                                                   components

## Internal helper: accepted sigma-type parm tokens.
.sigma_parm_tokens <- function() {
  c("Sigma_unit", "Sigma_unit_obs", "Sigma_B", "Sigma_W", "sigma_phy")
}

## Internal helper: return display and extraction metadata for a sigma-type
## parm token. `display` preserves the caller's token so legacy callers keep
## legacy row labels while new callers get canonical `Sigma_unit[...]` labels.
.sigma_parm_info <- function(parm) {
  switch(
    parm,
    Sigma_unit = list(
      display = "Sigma_unit",
      level = "unit",
      internal = "B",
      key = "Sigma_B",
      phy = FALSE
    ),
    Sigma_unit_obs = list(
      display = "Sigma_unit_obs",
      level = "unit_obs",
      internal = "W",
      key = "Sigma_W",
      phy = FALSE
    ),
    Sigma_B = list(
      display = "Sigma_B",
      level = "unit",
      internal = "B",
      key = "Sigma_B",
      phy = FALSE
    ),
    Sigma_W = list(
      display = "Sigma_W",
      level = "unit_obs",
      internal = "W",
      key = "Sigma_W",
      phy = FALSE
    ),
    sigma_phy = list(
      display = "sigma_phy",
      level = "phy",
      internal = "phy",
      key = "Sigma_phy",
      phy = TRUE
    ),
    NULL
  )
}

## Internal helper: recognise sigma-type parm tokens.
.is_sigma_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    parm %in% .sigma_parm_tokens()
}

## Internal helper (Stage 2 of profile-CI unified framework, 2026-05-27):
## recognise Lambda-entry parm tokens. Accepts:
##   * "Lambda"           -> all free Lambda entries
##   * "Lambda:i,j"       -> single entry
##   * "Lambda:i,j;k,l"   -> multiple entries (semicolon-separated)
##
## Always matches against `Lambda_<unit>` (the unit-level loading matrix).
## A future stage will extend to `unit_obs` via a "Lambda_unit_obs:..." or
## a separate `level` argument; out of scope here.
.is_lambda_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    (identical(parm, "Lambda") || grepl("^Lambda:", parm))
}

## Internal helper (Stage 2): parse a "Lambda:i,j;k,l" string into an
## integer (i, k) matrix suitable for `loading_profile(entries = ...)`.
## Returns `NULL` for the bare token "Lambda" (meaning "all free entries").
## Errors clearly on malformed tokens or out-of-range indices.
.parse_lambda_parm <- function(parm, n_traits, K) {
  if (identical(parm, "Lambda")) {
    return(NULL)
  }
  spec <- sub("^Lambda:", "", parm)
  pairs <- strsplit(spec, ";", fixed = TRUE)[[1L]]
  pairs <- trimws(pairs)
  pairs <- pairs[nzchar(pairs)]
  if (length(pairs) == 0L) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code Lambda} parm token.",
      i = "Expected {.code \"Lambda:i,j\"} or {.code \"Lambda:i,j;k,l\"}."
    ))
  }
  parts_list <- lapply(pairs, function(p) {
    parts <- strsplit(p, ",", fixed = TRUE)[[1L]]
    if (length(parts) != 2L) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code Lambda} parm token.",
        i = "Expected {.code \"Lambda:i,j\"} or {.code \"Lambda:i,j;k,l\"}; each pair must have two integers separated by a comma."
      ))
    }
    i <- suppressWarnings(as.integer(trimws(parts[1L])))
    k <- suppressWarnings(as.integer(trimws(parts[2L])))
    if (anyNA(c(i, k))) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code Lambda} parm token.",
        i = "Indices must be integers; got {.val {parts[1L]}}, {.val {parts[2L]}}."
      ))
    }
    c(i, k)
  })
  m <- do.call(rbind, parts_list)
  storage.mode(m) <- "integer"
  out_of_range <- m[, 1L] < 1L | m[, 1L] > n_traits |
    m[, 2L] < 1L | m[, 2L] > K
  if (any(out_of_range)) {
    bad <- which(out_of_range)
    cli::cli_abort(c(
      "{cli::qty(length(bad))} Lambda entr{?y/ies} {.val {paste0(m[bad, 1L], ',', m[bad, 2L])}} out of range.",
      i = "Valid indices: {.code i} in 1:{n_traits}, {.code k} in 1:{K}."
    ))
  }
  m
}

## Internal helper (Stage 2): build the data.frame return value for
## `confint(fit, parm = \"Lambda:...\")`. Wald paths route through
## `loading_ci()` (which already enforces the pdHess gate -> NA + flag);
## the profile path calls `loading_profile()` directly with the requested
## entries (cheaper than going through `loading_ci(method = 'profile')`,
## which always profiles every free entry) and inverts via
## `.invert_profile_loadings()`.
##
## Return shape: data.frame with columns
##   `parameter` (e.g. "Lambda[trait_1,LV1]"), `estimate`, `lower`,
##   `upper`, `method`, `pd_hessian`, `ci_status`. Pinned entries are
##   included when `parm = "Lambda"` (lower == upper == estimate,
##   ci_status == "pinned") so the row order is stable across methods.
.confint_lambda <- function(object, parm, level, method, nsim = 500L, seed = NULL, ...) {
  method <- match.arg(method, c("wald", "wald_asym", "profile", "bootstrap"))

  Lambda_mat <- object$report[["Lambda_B"]]
  if (is.null(Lambda_mat)) {
    cli::cli_abort(c(
      "Fit has no {.code Lambda_B} to summarise.",
      i = "Add a {.fn latent} term at {.code level = \"unit\"} and refit."
    ))
  }
  Lambda_mat <- as.matrix(Lambda_mat)
  n_traits <- nrow(Lambda_mat)
  K <- ncol(Lambda_mat)

  entries <- .parse_lambda_parm(parm, n_traits = n_traits, K = K)

  if (method %in% c("wald", "wald_asym")) {
    ## `loading_ci()` already implements the pdHess gate (NA + status
    ## columns) and the pinned-entry collapse; we just filter rows
    ## down to the requested entries and rename to a `parameter`
    ## column for matrix consistency with the Sigma path.
    ci <- loading_ci(
      fit = object,
      level = "unit",
      method = method,
      conf_level = level
    )
    trait_lab <- as.character(ci$trait)
    axis_lab <- as.character(ci$axis)
    parameter <- sprintf("Lambda[%s,%s]", trait_lab, axis_lab)
    ## Promote pinned-entry status: `loading_ci()` reports `ci_status =
    ## "ok"` for pinned entries (their bounds collapse to the point).
    ## To match the profile-path convention -- and to give callers a
    ## single way to identify pinned entries from the confint output --
    ## upgrade those rows to `"pinned"`. Keep "ok" for free entries on
    ## a PD fit and the non-PD flag untouched.
    ci$ci_status <- ifelse(
      ci$pinned & ci$ci_status == "ok",
      "pinned",
      ci$ci_status
    )
    ## Row layout in `loading_ci()`: column-major over Lambda[i, k]
    ## (trait repeated `times = d`, axis repeated `each = n_traits`).
    if (!is.null(entries)) {
      row_ids <- entries[, 1L] + (entries[, 2L] - 1L) * n_traits
      ci <- ci[row_ids, , drop = FALSE]
      parameter <- parameter[row_ids]
    }
    return(data.frame(
      parameter = parameter,
      estimate = ci$estimate,
      lower = ci$lower,
      upper = ci$upper,
      method = ci$method,
      pd_hessian = ci$pd_hessian,
      ci_status = ci$ci_status,
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## ---- Phase B-INF Lane 1 A4 (2026-05-28): bootstrap path -------------------
  if (method == "bootstrap") {
    ci <- .loading_ci_bootstrap(
      fit = object,
      level = "unit",
      entries = entries,
      conf_level = level,
      nsim = nsim,
      seed = seed
    )
    trait_lab <- as.character(ci$trait)
    axis_lab <- as.character(ci$axis)
    parameter <- sprintf("Lambda[%s,%s]", trait_lab, axis_lab)
    return(data.frame(
      parameter = parameter,
      estimate = ci$estimate,
      lower = ci$lower,
      upper = ci$upper,
      method = ci$method,
      pd_hessian = ci$pd_hessian,
      ci_status = ci$ci_status,
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## method == "profile": build curve(s) directly for the requested
  ## entries, then invert. `loading_profile()` skips pinned entries by
  ## construction; for `parm = "Lambda"` we include them as collapsed
  ## point rows so the output row count matches the Wald paths.
  prof <- loading_profile(
    fit = object,
    level = "unit",
    entries = entries,
    n_grid = 11L,
    grid_extent = 6,
    conf_level = level
  )
  bounds <- .invert_profile_loadings(prof)
  ## Map profile bounds back to a per-entry data.frame matching the
  ## Wald-path layout (so callers can rely on a consistent shape).
  trait_names <- rownames(Lambda_mat)
  if (is.null(trait_names)) {
    trait_names <- rownames(object$lambda_constraint[["B"]])
  }
  if (is.null(trait_names) && !is.null(object$trait_col) &&
      !is.null(object$data) && !is.null(object$data[[object$trait_col]])) {
    trait_names <- levels(object$data[[object$trait_col]])
  }
  if (is.null(trait_names)) {
    trait_names <- paste0("trait_", seq_len(n_traits))
  }
  axis_names <- colnames(Lambda_mat)
  if (is.null(axis_names)) {
    axis_names <- paste0("LV", seq_len(K))
  }
  pd_ok <- isTRUE(object$sd_report$pdHess)

  if (is.null(entries)) {
    ## Build the full grid of (i, k) entries; pinned ones (not present
    ## in `bounds`) collapse to point.
    M_user <- object$lambda_constraint[["B"]]
    is_pinned <- if (is.null(M_user)) {
      matrix(FALSE, n_traits, K)
    } else {
      !is.na(M_user)
    }
    ## Engine pins the strict-upper-triangle of the first d rows
    ## (mirror of `loading_profile()` so the displayed pinned set matches).
    for (i in seq_len(min(n_traits, K))) {
      for (j in seq_len(K)) {
        if (j > i) is_pinned[i, j] <- TRUE
      }
    }
    all_entries <- expand.grid(
      i = seq_len(n_traits),
      k = seq_len(K),
      KEEP.OUT.ATTRS = FALSE
    )
    parameter <- sprintf(
      "Lambda[%s,%s]",
      trait_names[all_entries$i],
      axis_names[all_entries$k]
    )
    estimate <- as.numeric(Lambda_mat)
    lower <- estimate
    upper <- estimate
    ci_status <- ifelse(is_pinned, "pinned", "interval_unavailable")
    ## Overwrite with profile bounds where available
    key_all <- paste(all_entries$i, all_entries$k, sep = ":")
    key_b <- paste(bounds$i, bounds$k, sep = ":")
    hit <- match(key_b, key_all)
    lower[hit] <- bounds$lower
    upper[hit] <- bounds$upper
    ci_status[hit] <- bounds$ci_status
    return(data.frame(
      parameter = parameter,
      estimate = estimate,
      lower = lower,
      upper = upper,
      method = "profile",
      pd_hessian = pd_ok,
      ci_status = ci_status,
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## Specific entries requested: bounds row order matches `entries`
  ## (loading_profile preserves the order of `entries`).
  parameter <- sprintf(
    "Lambda[%s,%s]",
    trait_names[entries[, 1L]],
    axis_names[entries[, 2L]]
  )
  ## Align rows: bounds may have a different order if loading_profile
  ## reorders, but at present it preserves the row order of `entries`.
  ## Defensive remap by (i, k) key.
  key_req <- paste(entries[, 1L], entries[, 2L], sep = ":")
  key_b <- paste(bounds$i, bounds$k, sep = ":")
  idx <- match(key_req, key_b)
  data.frame(
    parameter = parameter,
    estimate = bounds$estimate[idx],
    lower = bounds$lower[idx],
    upper = bounds$upper[idx],
    method = "profile",
    pd_hessian = pd_ok,
    ci_status = bounds$ci_status[idx],
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

## ---- Stage 3a: derived-quantity parm tokens (2026-05-27) -----------------
## Routes `parm = "icc[:...]"`, `"phylo_signal[:...]"`,
## `"communality:tier[:trait]"`, and `"rho:tier:i,j[;k,l]"` through the
## existing derived-quantity helpers (extract_repeatability /
## profile_ci_repeatability, profile_ci_phylo_signal,
## profile_ci_communality, extract_correlations / profile_ci_correlation).
## Mirrors the Stage 2 Lambda template: strict regex anchors on the
## recognizers, parser helpers that return the args to forward, dispatcher
## helpers that build a numeric matrix with `<lo>%` / `<hi>%` colnames.

## Internal helper: parse a per-trait token of the form
##   "<prefix>"                      -> NULL (all traits)
##   "<prefix>:<name1>;<name2>"      -> integer trait indices (by name)
##   "<prefix>:[1,3]"                -> integer trait indices (by 1-based index)
## Returns a sorted integer vector or `NULL` (all traits). Errors with a
## clear message on out-of-range or unknown names.
.parse_pertrait_parm <- function(parm, prefix, trait_names) {
  if (identical(parm, prefix)) {
    return(NULL)
  }
  spec <- sub(paste0("^", prefix, ":"), "", parm)
  spec <- trimws(spec)
  if (!nzchar(spec)) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code {prefix}} parm token.",
      i = "Expected {.code \"{prefix}\"}, {.code \"{prefix}:<trait_name>\"}, {.code \"{prefix}:[k]\"}, or {.code \"{prefix}:[i,j]\"}."
    ))
  }
  ## Bracketed index form: "[1]" or "[1,3]"
  if (grepl("^\\[.*\\]$", spec)) {
    body <- sub("^\\[(.*)\\]$", "\\1", spec)
    parts <- strsplit(body, ",", fixed = TRUE)[[1L]]
    parts <- trimws(parts)
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0L) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code {prefix}} parm token.",
        i = "Bracketed index list is empty."
      ))
    }
    ix <- suppressWarnings(as.integer(parts))
    if (anyNA(ix)) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code {prefix}} parm token.",
        i = "Bracketed indices must be integers; got {.val {parts}}."
      ))
    }
    out_of_range <- ix < 1L | ix > length(trait_names)
    if (any(out_of_range)) {
      bad <- ix[out_of_range]
      cli::cli_abort(c(
        "{cli::qty(length(bad))} trait ind{?ex/ices} {.val {bad}} out of range.",
        i = "Valid indices: 1:{length(trait_names)}."
      ))
    }
    return(sort(unique(ix)))
  }
  ## Name list: "<n1>" or "<n1>;<n2>"
  parts <- strsplit(spec, ";", fixed = TRUE)[[1L]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code {prefix}} parm token.",
      i = "Empty trait list."
    ))
  }
  ix <- match(parts, trait_names)
  if (anyNA(ix)) {
    bad <- parts[is.na(ix)]
    cli::cli_abort(c(
      "{cli::qty(length(bad))} trait name{?s} {.val {bad}} not found.",
      i = "Available trait names: {.val {trait_names}}."
    ))
  }
  sort(unique(ix))
}

## Internal helper: recognise `icc` parm tokens.
.is_icc_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    (identical(parm, "icc") || grepl("^icc:", parm))
}

## Internal helper: recognise `phylo_signal` parm tokens.
.is_phylo_signal_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    (identical(parm, "phylo_signal") || grepl("^phylo_signal:", parm))
}

## Internal helper: recognise `communality:tier[:trait]` parm tokens.
## Strict: must start with "communality:" followed by at least a tier
## token; bare "communality" without a tier is rejected (tier is
## mandatory because there is no sensible default).
.is_communality_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    grepl("^communality:", parm)
}

## Internal helper: parse a communality token "communality:<tier>" or
## "communality:<tier>:<trait>". Returns list(tier = <tier>, trait_idx
## = <int-vec-or-NULL>).
.parse_communality_parm <- function(parm, trait_names) {
  spec <- sub("^communality:", "", parm)
  ## Split on the FIRST ":" only — the trait portion may itself
  ## contain commas (bracketed indices) but not colons.
  ix_colon <- regexpr(":", spec, fixed = TRUE)
  if (ix_colon == -1L) {
    tier <- spec
    trait_part <- NULL
  } else {
    tier <- substr(spec, 1L, ix_colon - 1L)
    trait_part <- substr(spec, ix_colon + 1L, nchar(spec))
  }
  tier <- trimws(tier)
  if (!nzchar(tier)) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code communality} parm token.",
      i = "Expected {.code \"communality:<tier>\"} or {.code \"communality:<tier>:<trait>\"}; tier is mandatory."
    ))
  }
  if (!tier %in% c("unit", "unit_obs", "phy", "B", "W")) {
    cli::cli_abort(c(
      "Invalid tier {.val {tier}} in {.val {parm}}.",
      i = "Communality tiers: {.val unit}, {.val unit_obs}, or {.val phy} (legacy aliases {.val B} / {.val W} also accepted)."
    ))
  }
  trait_idx <- NULL
  if (!is.null(trait_part) && nzchar(trimws(trait_part))) {
    ## Build a synthetic per-trait token and reuse `.parse_pertrait_parm`
    ## so the index / name grammar is identical to icc / phylo_signal.
    fake_parm <- paste0("communality:", trait_part)
    trait_idx <- .parse_pertrait_parm(fake_parm, "communality", trait_names)
  }
  list(tier = tier, trait_idx = trait_idx)
}

## Internal helper: recognise `rho:tier:i,j[;k,l]` parm tokens.
.is_rho_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    grepl("^rho:", parm)
}

## Internal helper: parse "rho:<tier>:i,j[;k,l]" into list(tier, pairs)
## where pairs is an integer matrix with columns (i, j) and i < j.
.parse_rho_parm <- function(parm, trait_names) {
  spec <- sub("^rho:", "", parm)
  ix_colon <- regexpr(":", spec, fixed = TRUE)
  if (ix_colon == -1L) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code rho} parm token.",
      i = "Expected {.code \"rho:<tier>:i,j\"} or {.code \"rho:<tier>:i,j;k,l\"}; tier and pair are mandatory."
    ))
  }
  tier <- trimws(substr(spec, 1L, ix_colon - 1L))
  pair_spec <- substr(spec, ix_colon + 1L, nchar(spec))
  if (!nzchar(tier)) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code rho} parm token.",
      i = "Tier is mandatory."
    ))
  }
  if (!tier %in% c("unit", "unit_obs", "phy", "spatial", "B", "W", "spde")) {
    cli::cli_abort(c(
      "Invalid tier {.val {tier}} in {.val {parm}}.",
      i = "Correlation tiers: {.val unit}, {.val unit_obs}, {.val phy}, or {.val spatial} (legacy aliases {.val B} / {.val W} / {.val spde} also accepted)."
    ))
  }
  pairs <- strsplit(pair_spec, ";", fixed = TRUE)[[1L]]
  pairs <- trimws(pairs)
  pairs <- pairs[nzchar(pairs)]
  if (length(pairs) == 0L) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code rho} parm token.",
      i = "Expected at least one pair {.code i,j}."
    ))
  }
  T <- length(trait_names)
  parts_list <- lapply(pairs, function(p) {
    bits <- strsplit(p, ",", fixed = TRUE)[[1L]]
    bits <- trimws(bits)
    if (length(bits) != 2L) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code rho} parm token.",
        i = "Each pair must have two integers separated by a comma; got {.val {p}}."
      ))
    }
    i <- suppressWarnings(as.integer(bits[1L]))
    j <- suppressWarnings(as.integer(bits[2L]))
    if (anyNA(c(i, j))) {
      cli::cli_abort(c(
        "Could not parse {.val {parm}} as a {.code rho} parm token.",
        i = "Pair indices must be integers; got {.val {bits[1L]}}, {.val {bits[2L]}}."
      ))
    }
    if (i < 1L || j < 1L || i > T || j > T) {
      cli::cli_abort(c(
        "Pair {.val {paste0(i, ',', j)}} out of range.",
        i = "Valid indices: 1:{T}."
      ))
    }
    if (i == j) {
      cli::cli_abort(c(
        "Pair {.val {paste0(i, ',', j)}} must have distinct traits.",
        i = "Cross-trait correlations require {.code i != j}."
      ))
    }
    if (i > j) {
      ## Canonicalise to i < j; the underlying profile_ci_correlation
      ## requires i < j.
      c(j, i)
    } else {
      c(i, j)
    }
  })
  m <- do.call(rbind, parts_list)
  storage.mode(m) <- "integer"
  list(tier = tier, pairs = m)
}

## Internal helper: turn a confint-style level into the two column
## names `<lo>%` and `<hi>%` (matches the matrix shape used elsewhere).
.confint_colnames <- function(level) {
  c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
}

## Internal helper: dispatch `confint(fit, parm = "icc[:...]")`.
## Routes to extract_repeatability() for wald / bootstrap and to
## profile_ci_repeatability() for profile (the latter is the cheaper
## per-trait path that bypasses extract_repeatability()'s honest-fallback
## Wald demotion). Returns a numeric matrix with rownames `icc:<trait>`.
.confint_icc <- function(object, parm, level, method, nsim, seed, ...) {
  trait_names <- levels(object$data[[object$trait_col]])
  trait_idx <- .parse_pertrait_parm(parm, "icc", trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_along(trait_names)
  }

  if (method == "profile") {
    tbl <- profile_ci_repeatability(
      fit = object,
      trait_idx = trait_idx,
      level = level
    )
  } else if (method %in% c("wald", "bootstrap")) {
    tbl <- suppressMessages(extract_repeatability(
      fit = object,
      level = level,
      method = method,
      nsim = nsim,
      seed = seed
    ))
    ## extract_repeatability() always returns all traits; filter.
    tbl <- tbl[trait_idx, , drop = FALSE]
  } else {
    cli::cli_abort(c(
      "Method {.val {method}} not supported for {.code icc}.",
      i = "Available: {.val profile}, {.val wald}, {.val bootstrap}."
    ))
  }
  out <- cbind(as.numeric(tbl$lower), as.numeric(tbl$upper))
  rownames(out) <- paste0("icc:", as.character(tbl$trait))
  colnames(out) <- .confint_colnames(level)
  out
}

## Internal helper: dispatch `confint(fit, parm = "phylo_signal[:...]")`.
## Routes to profile_ci_phylo_signal() for method = "profile" and to the
## companion phylogenetic-signal Wald/bootstrap helpers for method =
## "wald" / "bootstrap".
.confint_phylo_signal <- function(object, parm, level, method, nsim = 500L, seed = NULL, ...) {
  trait_names <- levels(object$data[[object$trait_col]])
  trait_idx <- .parse_pertrait_parm(parm, "phylo_signal", trait_names)
  if (is.null(trait_idx)) {
    trait_idx <- seq_along(trait_names)
  }
  ## Phase B-INF Lane 1 A3 (2026-05-28): wald + bootstrap routes added.
  tbl <- switch(
    method,
    profile = profile_ci_phylo_signal(
      fit = object, trait_idx = trait_idx, level = level
    ),
    wald = .phylo_signal_wald_ci(
      fit = object, trait_idx = trait_idx, level = level
    ),
    bootstrap = .phylo_signal_bootstrap_ci(
      fit = object, trait_idx = trait_idx,
      level = level, nsim = nsim, seed = seed
    ),
    cli::cli_abort(c(
      "Method {.val {method}} not implemented for {.code phylo_signal}.",
      i = "Available: {.val profile}, {.val wald}, {.val bootstrap}."
    ))
  )
  out <- cbind(as.numeric(tbl$lower), as.numeric(tbl$upper))
  rownames(out) <- paste0("phylo_signal:", as.character(tbl$trait))
  colnames(out) <- .confint_colnames(level)
  out
}

## Internal helper: dispatch `confint(fit, parm = "communality:tier[:trait]")`.
## Routes to profile_ci_communality() for profile, and scalar Wald/bootstrap
## helpers for wald/bootstrap.
.confint_communality <- function(object, parm, level, method, nsim = 500L, seed = NULL, ...) {
  trait_names <- levels(object$data[[object$trait_col]])
  parsed <- .parse_communality_parm(parm, trait_names)
  tier <- parsed$tier
  trait_idx <- parsed$trait_idx
  if (is.null(trait_idx)) {
    trait_idx <- seq_along(trait_names)
  }
  ## Phase B-INF Lane 1 A1 (2026-05-28): wald + bootstrap routes added.
  ## A1's `.communality_wald_ci()` / `.communality_bootstrap_ci()` are
  ## scalar-trait functions (one trait per call); we loop here so the
  ## dispatcher exposes the same vector trait_idx semantics as the
  ## profile path.
  tbl <- switch(
    method,
    profile = suppressWarnings(profile_ci_communality(
      fit = object, tier = tier, trait_idx = trait_idx, level = level
    )),
    wald = do.call(rbind, lapply(trait_idx, function(t) {
      v <- .communality_wald_ci(
        fit = object, tier = tier, trait_idx = t, level = level
      )
      ## A1 returns a named numeric vector; wrap in a 1-row data frame
      ## matching the profile path's column layout so downstream
      ## indexing (`tbl$lower`, `tbl$upper`, `tbl$trait`) just works.
      data.frame(
        trait = trait_names[t],
        c2 = unname(v["estimate"]),
        lower = unname(v["lower"]),
        upper = unname(v["upper"]),
        method = "wald",
        stringsAsFactors = FALSE
      )
    })),
    bootstrap = do.call(rbind, lapply(trait_idx, function(t) {
      v <- .communality_bootstrap_ci(
        fit = object, tier = tier, trait_idx = t,
        level = level, nsim = nsim, seed = seed
      )
      data.frame(
        trait = trait_names[t],
        c2 = unname(v["estimate"]),
        lower = unname(v["lower"]),
        upper = unname(v["upper"]),
        method = "bootstrap",
        stringsAsFactors = FALSE
      )
    })),
    cli::cli_abort(c(
      "Method {.val {method}} not implemented for {.code communality}.",
      i = "Available: {.val profile}, {.val wald}, {.val bootstrap}."
    ))
  )
  ## Preserve the user-supplied tier in the row labels (the underlying
  ## table reports the internal slot, e.g. "B"; we report what the user
  ## typed, e.g. "unit").
  out <- cbind(as.numeric(tbl$lower), as.numeric(tbl$upper))
  rownames(out) <- paste0(
    "communality:",
    tier,
    ":",
    as.character(tbl$trait)
  )
  colnames(out) <- .confint_colnames(level)
  out
}

## Internal helper: dispatch `confint(fit, parm = "rho:tier:i,j[;k,l]")`.
## Routes to extract_correlations() for fisher-z / wald / bootstrap, and
## profile_ci_correlation() for profile (the latter is cheaper than
## going through extract_correlations(method = "profile") when only
## specific pairs are requested).
.confint_rho <- function(object, parm, level, method, nsim, seed, ...) {
  trait_names <- levels(object$data[[object$trait_col]])
  parsed <- .parse_rho_parm(parm, trait_names)
  tier <- parsed$tier
  pairs <- parsed$pairs

  n_pairs <- nrow(pairs)
  lo <- numeric(n_pairs)
  hi <- numeric(n_pairs)
  rn <- character(n_pairs)

  if (method == "profile") {
    for (m in seq_len(n_pairs)) {
      i <- pairs[m, 1L]
      j <- pairs[m, 2L]
      ci <- profile_ci_correlation(
        fit = object,
        tier = tier,
        i = i,
        j = j,
        level = level
      )
      lo[m] <- unname(ci["lower"])
      hi[m] <- unname(ci["upper"])
      rn[m] <- sprintf("rho:%s:%d,%d", tier, i, j)
    }
  } else if (method %in% c("fisher-z", "wald", "bootstrap")) {
    ## extract_correlations() returns all pairs at the tier; loop per
    ## requested pair and match the row.
    for (m in seq_len(n_pairs)) {
      i <- pairs[m, 1L]
      j <- pairs[m, 2L]
      df <- suppressMessages(extract_correlations(
        fit = object,
        tier = tier,
        pair = c(i, j),
        level = level,
        method = method,
        nsim = nsim,
        seed = seed
      ))
      if (nrow(df) != 1L) {
        cli::cli_abort(c(
          "Unexpected return from {.fn extract_correlations} for pair {.val {paste0(i, ',', j)}}.",
          i = "Expected one row, got {nrow(df)}."
        ))
      }
      lo[m] <- as.numeric(df$lower[1L])
      hi[m] <- as.numeric(df$upper[1L])
      rn[m] <- sprintf("rho:%s:%d,%d", tier, i, j)
    }
  } else {
    cli::cli_abort(c(
      "Method {.val {method}} not supported for {.code rho}.",
      i = "Available: {.val profile}, {.val fisher-z}, {.val wald}, {.val bootstrap}."
    ))
  }
  out <- cbind(lo, hi)
  rownames(out) <- rn
  colnames(out) <- .confint_colnames(level)
  out
}

## ---- Stage 3b (2026-05-27): proportion parm tokens -----------------------
## Routes `parm = "proportion[:component[:trait]]"` and variants through
## `profile_ci_proportions()`. Grammar:
##   * "proportion"                                -> all components, all traits
##   * "proportion:<component>"                    -> one component, all traits
##   * "proportion:<component>:<trait>"            -> one (component, trait)
##   * "proportion:<component>:<t1>;<t2>"          -> one component, multiple traits
##   * "proportion:<component>:[1,3]"              -> one component, bracketed indices
##   * "proportion:<c1>;<c2>"                      -> multiple components, all traits

## Known component vocabulary (matches extract_proportions() outputs).
.proportion_components <- function() {
  c(
    "shared_unit",
    "unique_unit",
    "shared_unit_obs",
    "unique_unit_obs",
    "shared_phy",
    "unique_phy",
    "link_residual"
  )
}

## Recognise `proportion` parm tokens.
.is_proportion_parm <- function(parm) {
  !missing(parm) &&
    is.character(parm) &&
    length(parm) == 1L &&
    (identical(parm, "proportion") || grepl("^proportion:", parm))
}

## Parse a `proportion:<comp[s]>[:<trait[s]>]` token.
## Returns list(components = <chr-or-NULL>, trait_idx = <int-vec-or-NULL>).
## - `components = NULL` means "all components present in the fit".
## - `trait_idx  = NULL` means "all traits".
.parse_proportion_parm <- function(parm, trait_names) {
  if (identical(parm, "proportion")) {
    return(list(components = NULL, trait_idx = NULL))
  }
  spec <- sub("^proportion:", "", parm)
  ## Split on the FIRST ":" only -- the trait portion may contain
  ## commas (bracketed indices) and semicolons (multi-trait lists)
  ## but never a colon.
  ix_colon <- regexpr(":", spec, fixed = TRUE)
  if (ix_colon == -1L) {
    comp_part <- spec
    trait_part <- NULL
  } else {
    comp_part <- substr(spec, 1L, ix_colon - 1L)
    trait_part <- substr(spec, ix_colon + 1L, nchar(spec))
  }
  comp_part <- trimws(comp_part)
  if (!nzchar(comp_part)) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code proportion} parm token.",
      i = "Expected {.code \"proportion\"}, {.code \"proportion:<component>\"}, or {.code \"proportion:<component>:<trait>\"}."
    ))
  }
  comps <- strsplit(comp_part, ";", fixed = TRUE)[[1L]]
  comps <- trimws(comps)
  comps <- comps[nzchar(comps)]
  if (length(comps) == 0L) {
    cli::cli_abort(c(
      "Could not parse {.val {parm}} as a {.code proportion} parm token.",
      i = "Empty component list."
    ))
  }
  known <- .proportion_components()
  bad <- setdiff(comps, known)
  if (length(bad) > 0L) {
    cli::cli_abort(c(
      "{cli::qty(length(bad))} unknown proportion component{?s}: {.val {bad}}.",
      i = "Available components: {.val {known}}."
    ))
  }

  trait_idx <- NULL
  if (!is.null(trait_part) && nzchar(trimws(trait_part))) {
    ## Reuse `.parse_pertrait_parm` for the trait portion: build a
    ## synthetic token "proportion:<trait_part>" so the index / name
    ## grammar is identical to icc / phylo_signal / communality.
    fake_parm <- paste0("proportion:", trait_part)
    trait_idx <- .parse_pertrait_parm(fake_parm, "proportion", trait_names)
  }
  list(components = comps, trait_idx = trait_idx)
}

## Dispatch `confint(fit, parm = "proportion[:...]")`.
## Routes to profile_ci_proportions() for method = "profile" and to the
## scalar proportion Wald/bootstrap helpers for method = "wald" / "bootstrap".
.confint_proportion <- function(object, parm, level, method, nsim = 500L, seed = NULL, ...) {
  trait_names <- levels(object$data[[object$trait_col]])
  parsed <- .parse_proportion_parm(parm, trait_names)
  ## Phase B-INF Lane 1 A2 (2026-05-28): wald + bootstrap routes added.
  tbl <- switch(
    method,
    profile = profile_ci_proportions(
      fit = object,
      components = parsed$components,
      trait_idx = parsed$trait_idx,
      level = level
    ),
    wald = .proportions_wald_ci(
      fit = object,
      components = parsed$components,
      trait_idx = parsed$trait_idx,
      level = level
    ),
    bootstrap = .proportions_bootstrap_ci(
      fit = object,
      components = parsed$components,
      trait_idx = parsed$trait_idx,
      level = level, nsim = nsim, seed = seed
    ),
    cli::cli_abort(c(
      "Method {.val {method}} not implemented for {.code proportion}.",
      i = "Available: {.val profile}, {.val wald}, {.val bootstrap}.",
      ">" = "For point estimates of the proportion decomposition see {.fn extract_proportions}."
    ))
  )
  out <- cbind(as.numeric(tbl$lower), as.numeric(tbl$upper))
  rownames(out) <- paste0(
    "proportion:",
    as.character(tbl$component),
    ":",
    as.character(tbl$trait)
  )
  colnames(out) <- .confint_colnames(level)
  out
}

## Internal helper (P1a 2026-05-15): recognise parm tokens that match
## the `profile_targets()` inventory (e.g. "sigma_eps", "sd_B[1]",
## "phi_nbinom2[2]", "Lambda_B_packed[3]"). These are variance,
## dispersion, scaling, loading-packed, or threshold-class targets;
## the fixed-effect path below already handles b_fix elements via
## tidy(). Returns TRUE when parm is character, length >= 1, and
## every entry matches a profile-target label in
## profile_targets(object).
.is_profile_target_parm <- function(object, parm) {
  if (missing(parm) || !is.character(parm) || length(parm) == 0L) {
    return(FALSE)
  }
  if (any(parm %in% .sigma_parm_tokens())) {
    return(FALSE)
  }
  tgt <- tryCatch(
    profile_targets(object, ready_only = FALSE),
    error = function(e) NULL
  )
  if (is.null(tgt)) {
    return(FALSE)
  }
  all(parm %in% tgt$parm)
}

## Internal helper (P1a 2026-05-15): build a matrix CI for direct
## profile targets via tmbprofile_wrapper(). Mirrors the Sigma-path
## matrix shape (lower / upper, with the requested parm rownames).
.confint_profile_targets <- function(object, parm, level, ...) {
  targets <- profile_targets(object, ready_only = FALSE)
  chosen <- targets[targets$parm %in% as.character(parm), , drop = FALSE]
  ## Filter out derived rows with a typed message pointing at the
  ## right extractor.
  derived_rows <- chosen[chosen$target_type == "derived", , drop = FALSE]
  if (nrow(derived_rows) > 0L) {
    derived_pointers <- derived_rows$parm
    cli::cli_warn(c(
      "Profile CIs for {length(derived_pointers)} derived target{?s} ({.val {derived_pointers}}) are not produced by {.fn confint}.",
      "i" = "Use the matching {.fn extract_*} extractor with {.code method = \"profile\"} instead. See {.fn profile_targets} for the full mapping."
    ))
    chosen <- chosen[chosen$target_type == "direct", , drop = FALSE]
  }
  not_ready <- chosen[!chosen$profile_ready, , drop = FALSE]
  if (nrow(not_ready) > 0L) {
    cli::cli_abort(c(
      "Cannot profile {nrow(not_ready)} target{?s}: {.val {not_ready$parm}}.",
      "i" = "Reason{?s}: {.val {unique(not_ready$profile_note)}}.",
      ">" = "If the fit object has been serialised, refit before calling {.fn confint}."
    ))
  }
  lower <- numeric(nrow(chosen))
  upper <- numeric(nrow(chosen))
  for (i in seq_len(nrow(chosen))) {
    row <- chosen[i, ]
    tf <- row$transformation
    transform_fun <- switch(
      tf,
      "linear_predictor" = identity,
      "exp" = exp,
      "logit" = stats::plogis,
      "logit_p_tweedie" = function(x) 1 + stats::plogis(x),
      "lambda_packed" = identity,
      "ordinal_threshold" = exp,
      identity
    )
    which_idx <- if (is.na(row$index)) 1L else row$index
    args <- list(
      fit = object,
      name = row$tmb_parameter,
      which = which_idx,
      level = level,
      transform = transform_fun
    )
    extra <- list(...)
    args <- utils::modifyList(args, extra[!names(extra) %in% names(args)])
    res <- do.call(tmbprofile_wrapper, args)
    lower[i] <- unname(res["lower"])
    upper[i] <- unname(res["upper"])
  }
  out <- cbind(lower, upper)
  rownames(out) <- chosen$parm
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  out
}

## Internal helper (P1a 2026-05-15 follow-up; for coverage_study()
## support and audit-API consistency): build a matrix Wald CI for
## direct profile targets using `fit$sd_report$cov.fixed` directly,
## then transforming back to the natural scale via the registered
## transformation. Mirrors `.confint_profile_targets()` but for
## method = "wald".
.confint_wald_targets <- function(object, parm, level, ...) {
  targets <- profile_targets(object, ready_only = FALSE)
  chosen <- targets[targets$parm %in% as.character(parm), , drop = FALSE]
  derived_rows <- chosen[chosen$target_type == "derived", , drop = FALSE]
  if (nrow(derived_rows) > 0L) {
    derived_pointers <- derived_rows$parm
    cli::cli_warn(c(
      "Wald CIs for {length(derived_pointers)} derived target{?s} ({.val {derived_pointers}}) are not produced by {.fn confint}.",
      "i" = "Use the matching {.fn extract_*} extractor with {.code method = \"wald\"} instead."
    ))
    chosen <- chosen[chosen$target_type == "direct", , drop = FALSE]
  }
  if (nrow(chosen) == 0L) {
    out <- matrix(numeric(0L), nrow = 0L, ncol = 2L)
    colnames(out) <- c(
      sprintf("%.1f %%", 100 * (1 - level) / 2),
      sprintf("%.1f %%", 100 * (1 + level) / 2)
    )
    return(out)
  }
  z <- stats::qnorm(1 - (1 - level) / 2)
  lower <- numeric(nrow(chosen))
  upper <- numeric(nrow(chosen))
  for (i in seq_len(nrow(chosen))) {
    row <- chosen[i, ]
    transform_fun <- switch(
      row$transformation,
      "linear_predictor" = identity,
      "exp" = exp,
      "logit" = stats::plogis,
      "logit_p_tweedie" = function(x) 1 + stats::plogis(x),
      "lambda_packed" = identity,
      "ordinal_threshold" = exp,
      identity
    )
    idx <- .resolve_param_index(
      object,
      name = row$tmb_parameter,
      which = if (is.na(row$index)) 1L else row$index
    )
    se <- tryCatch(
      sqrt(diag(object$sd_report$cov.fixed))[idx],
      error = function(e) NA_real_
    )
    if (is.na(se) || !is.finite(se)) {
      lower[i] <- NA_real_
      upper[i] <- NA_real_
    } else {
      link_est <- as.numeric(object$opt$par[idx])
      lower[i] <- transform_fun(link_est - z * se)
      upper[i] <- transform_fun(link_est + z * se)
    }
  }
  out <- cbind(lower, upper)
  rownames(out) <- chosen$parm
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  out
}

#' Confidence intervals for a fitted gllvmTMB model
#'
#' Returns 95% (or other-level) confidence intervals for fixed effects,
#' variance components, and trait covariance matrices, with three method
#' choices:
#'
#' \itemize{
#'   \item \code{method = "profile"} (\strong{new default in Phase K}):
#'     profile-likelihood CIs via \code{TMB::tmbprofile()} +
#'     \code{stats::uniroot()}. Accurate, respects skewness, fast for
#'     individual parameters.
#'   \item \code{method = "wald"}: Gaussian-approximation CIs from
#'     \code{sd_report}. Fastest; poor near boundaries.
#'   \item \code{method = "bootstrap"}: parametric bootstrap via
#'     \code{bootstrap_Sigma()}. Slowest; most flexible (full sampling
#'     distribution).
#' }
#'
#' Scope boundary: IN, fixed-effect and direct-parameter intervals use the
#' requested \code{method} where supported (CI-01, CI-02), and Sigma-matrix
#' intervals accept canonical \code{parm = "Sigma_unit"} /
#' \code{"Sigma_unit_obs"} names plus legacy \code{"Sigma_B"} /
#' \code{"Sigma_W"} aliases (CI-02, CI-03; underlying extraction EXT-01).
#' PARTIAL, profile intervals for full decomposed Sigma entries fall back to
#' bootstrap because those entries are nonlinear functions of rotation-equivalent
#' loadings and diagonal \eqn{\Psi}; non-Gaussian bootstrap calibration remains
#' experimental under EXT-13 / CI-10. PLANNED, richer derived-profile intervals
#' and broader calibration evidence remain M3 work.
#'
#' Two parm-class dispatch paths:
#'
#' \itemize{
#'   \item \strong{Sigma matrices} -- when \code{parm} is one of
#'     \code{"Sigma_unit"}, \code{"Sigma_unit_obs"}, or \code{"sigma_phy"}
#'     (legacy aliases \code{"Sigma_B"} and \code{"Sigma_W"} still work),
#'     returns a tidy \code{data.frame} with columns \code{parameter},
#'     \code{estimate}, \code{lower}, \code{upper}, \code{method}. Profile is
#'     computed element-wise via [TMB::tmbprofile()] for the diagonal entries;
#'     off-diagonals fall back to bootstrap (full Sigma sampling) since they mix
#'     two parameters in a non-linear way.
#'   \item \strong{Fixed effects / variance components} -- when \code{parm}
#'     is missing, an integer index, or a character vector of fixed-effect
#'     term names, returns a numeric matrix with rows = parameters and
#'     columns = lower / upper bounds (same shape as
#'     [stats::confint()]). Method choice applies.
#' }
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param parm One of:
#'   \itemize{
#'     \item \code{"Sigma_unit"} -- between-unit trait covariance matrix.
#'     \item \code{"Sigma_unit_obs"} -- within-unit trait covariance matrix.
#'     \item \code{"sigma_phy"} -- per-trait phylogenetic standard deviations.
#'     \item Legacy aliases \code{"Sigma_B"} and \code{"Sigma_W"}, retained
#'       for existing scripts.
#'     \item \code{"Lambda"} (all free entries of \code{Lambda_unit}),
#'       \code{"Lambda:i,j"} (single entry), or \code{"Lambda:i,j;k,l"}
#'       (multiple entries, semicolon-separated). Routes to
#'       [loading_ci()] / [loading_profile()] (Stage 2 of the unified
#'       profile-CI framework). For these tokens the method choices are
#'       \code{c("wald", "wald_asym", "profile")} with default
#'       \code{"wald"}.
#'     \item \code{"icc"} (all traits), \code{"icc:<trait_name>"} (one
#'       trait by name), \code{"icc:<t1>;<t2>"} (multiple by name), or
#'       \code{"icc:[1,3]"} (1-based trait indices). Routes to
#'       [profile_ci_repeatability()] (for \code{method = "profile"}) or
#'       [extract_repeatability()] (\code{"wald"} / \code{"bootstrap"}).
#'       Stage 3a of the unified profile-CI framework.
#'     \item \code{"phylo_signal"} / \code{"phylo_signal:<trait>"} etc.
#'       -- same grammar as \code{"icc"}. Routes to
#'       [profile_ci_phylo_signal()] for \code{"profile"} and the companion
#'       Wald/bootstrap helpers for \code{"wald"} / \code{"bootstrap"}.
#'       For multi-component fits, \code{"profile"} falls back to numerical
#'       Wald bounds with an explicit method label until the full
#'       fix-and-refit profile is implemented.
#'     \item \code{"communality:<tier>"} (one tier, all traits) or
#'       \code{"communality:<tier>:<trait>"} (one tier, one trait).
#'       Tier is one of \code{"unit"} / \code{"unit_obs"} / \code{"phy"}
#'       (legacy \code{"B"} / \code{"W"}). Routes to
#'       [profile_ci_communality()] for \code{"profile"} and the companion
#'       Wald/bootstrap helpers for \code{"wald"} / \code{"bootstrap"}.
#'     \item \code{"rho:<tier>:i,j"} (one pair) or
#'       \code{"rho:<tier>:i,j;k,l"} (multiple pairs). Tier is one of
#'       \code{"unit"} / \code{"unit_obs"} / \code{"phy"} /
#'       \code{"spatial"} (legacy \code{"B"} / \code{"W"} / \code{"spde"}).
#'       Routes to [profile_ci_correlation()] (profile) or
#'       [extract_correlations()] (\code{"fisher-z"} / \code{"wald"} /
#'       \code{"bootstrap"}).
#'     \item \code{"proportion"} (all components, all traits),
#'       \code{"proportion:<component>"} (one component, all traits),
#'       \code{"proportion:<component>:<trait>"} (one (component, trait)),
#'       \code{"proportion:<component>:<t1>;<t2>"} (one component,
#'       multiple traits), or \code{"proportion:<c1>;<c2>"} (multiple
#'       components). Components are by name (\code{"shared_unit"},
#'       \code{"unique_unit"}, \code{"shared_unit_obs"},
#'       \code{"unique_unit_obs"}, \code{"shared_phy"},
#'       \code{"unique_phy"}, \code{"link_residual"}). Routes to
#'       [profile_ci_proportions()] for \code{"profile"} and the companion
#'       proportion Wald/bootstrap helpers for \code{"wald"} /
#'       \code{"bootstrap"}.
#'     \item An integer index vector or character vector of fixed-effect
#'       term names (same as the standard \code{confint()} interface).
#'     \item Missing (default) -- all fixed-effect parameters.
#'   }
#' @param level Confidence level in \code{(0, 1)}. Default \code{0.95}.
#' @param method One of \code{"profile"} (default), \code{"wald"},
#'   \code{"bootstrap"}. For \code{parm = "Lambda..."} the accepted
#'   methods are \code{c("wald", "wald_asym", "profile")} with default
#'   \code{"wald"} (matching the base R \code{confint()} convention).
#' @param nsim Number of bootstrap replicates passed to [bootstrap_Sigma()]
#'   when \code{method = "bootstrap"}. Default \code{500}. Use a small
#'   value (e.g. \code{50}) during development or testing.
#' @param seed Optional integer RNG seed forwarded to [bootstrap_Sigma()]
#'   (only meaningful when \code{method = "bootstrap"}).
#' @param ... Additional arguments currently unused.
#'
#' @return
#' \itemize{
#'   \item \strong{Sigma path} -- a \code{data.frame} with columns
#'     \code{parameter} (character, e.g. \code{"Sigma_unit[t1,t1]"}),
#'     \code{estimate} (point estimate), \code{lower}, \code{upper}, and
#'     \code{method} (the method used for that row). The parameter prefix
#'     follows the requested \code{parm}, so legacy calls still return
#'     legacy \code{"Sigma_B[...]"} or \code{"Sigma_W[...]"} labels.
#'   \item \strong{Lambda path} -- a \code{data.frame} with columns
#'     \code{parameter} (e.g. \code{"Lambda[trait_1,LV1]"}),
#'     \code{estimate}, \code{lower}, \code{upper}, \code{method},
#'     \code{pd_hessian}, and \code{ci_status} (the last two from the
#'     Stage 1 convention: when \code{pdHess = FALSE} on a Wald path,
#'     \code{lower}/\code{upper} are \code{NA} and \code{ci_status}
#'     flags the reason).
#'   \item \strong{Derived-quantity path} (\code{"icc"} /
#'     \code{"phylo_signal"} / \code{"communality"} / \code{"rho"}) --
#'     a numeric matrix with two columns named after the requested
#'     \code{level} (e.g. \code{"2.5 \%"} / \code{"97.5 \%"}) and
#'     rownames identifying the entry, e.g. \code{"icc:trait_1"},
#'     \code{"communality:unit:trait_1"}, \code{"rho:unit:1,2"}.
#'   \item \strong{Fixed-effects / variance-component path} -- a numeric
#'     matrix with rownames = parameter names and two columns named
#'     \code{"2.5 \%"} / \code{"97.5 \%"} (or the analogous quantiles for
#'     the requested \code{level}).
#' }
#'
#' @seealso [bootstrap_Sigma()], [extract_Sigma()], [extract_correlations()],
#'   [extract_repeatability()], [extract_communality()], [tmbprofile_wrapper()],
#'   [loading_ci()], [loading_profile()], [gllvmTMB()].
#'
#' @section References:
#' Pawitan, Y. (2001). \emph{In All Likelihood: Statistical Modelling
#' and Inference Using Likelihood}, Oxford University Press, ch. 9.
#'
#' Venzon, D. J. & Moolgavkar, S. H. (1988). A method for computing
#' profile-likelihood-based confidence intervals. \emph{Applied
#' Statistics} \strong{37}, 87-94. \doi{10.2307/2347496}
#'
#' McCune, K. B., \emph{et al.} (2024) \code{coxme_icc_ci()} -- the
#' Nakagawa-authored \code{coxme}-based profile-CI helper that
#' inspired this work, in
#' \url{https://github.com/kelseybmccune/Time-to-Event_Repeatability/blob/main/R/rptRsurv.R}.
#'
#' @examples
#' \dontrun{
#' ## Fit a tiny example
#' set.seed(1)
#' s <- simulate_site_trait(
#'   n_sites = 30, n_species = 4, n_traits = 3,
#'   mean_species_per_site = 4,
#'   Lambda_B = matrix(c(0.9, 0.4, -0.3), 3, 1),
#'   psi_B = c(0.20, 0.15, 0.10),
#'   beta = matrix(0, 3, 2), seed = 1
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'   data  = s$data,
#'   trait = "trait",
#'   unit  = "site"
#' )
#'
#' ## Profile-likelihood CIs for the between-site covariance matrix (default)
#' ci_unit <- confint(fit, parm = "Sigma_unit")
#' ci_unit
#'
#' ## Bootstrap CIs (slow, more accurate for non-monotone cases)
#' ci_unit_boot <- confint(fit, parm = "Sigma_unit", method = "bootstrap",
#'                         nsim = 200, seed = 42)
#'
#' ## Wald CIs for fixed effects
#' confint(fit)
#' }
#'
#' @export
#' @method confint gllvmTMB_multi
confint.gllvmTMB_multi <- function(
  object,
  parm,
  level = 0.95,
  method = c("profile", "wald", "bootstrap"),
  nsim = 500L,
  seed = NULL,
  ...
) {
  ## ---- Lambda entry path (Stage 2, 2026-05-27) -----------------------------
  ## `parm = "Lambda"` (all free entries) or `"Lambda:i,j"` /
  ## `"Lambda:i,j;k,l"` (specific entries) route to Stage 1 machinery in
  ## `loading_ci()` / `loading_profile()`. Lambda uses its own method set
  ## `c("wald", "wald_asym", "profile")` with default `"wald"`, so we
  ## intercept BEFORE the outer `match.arg(method)` (which would reject
  ## `"wald_asym"`).
  if (.is_lambda_parm(parm)) {
    method_lambda <- if ("method" %in% names(match.call())) {
      method
    } else {
      "wald"
    }
    return(.confint_lambda(
      object,
      parm = parm,
      level = level,
      method = method_lambda,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }

  ## ---- Stage 3a: derived-quantity tokens (2026-05-27) ----------------------
  ## `parm = "icc[:...]"`, `"phylo_signal[:...]"`,
  ## `"communality:tier[:trait]"`, and `"rho:tier:i,j[;k,l]"` route to
  ## profile_ci_repeatability / extract_repeatability,
  ## profile_ci_phylo_signal, profile_ci_communality, and
  ## profile_ci_correlation / extract_correlations respectively.
  ## Default method for these tokens is `"profile"` (the base default),
  ## so we keep the outer `method` argument as-is and let each helper
  ## error if a non-supported method is requested. We intercept the
  ## icc / rho branches BEFORE the outer `match.arg(method)` so that
  ## `extract_correlations()`'s `"fisher-z"` method (which is not in
  ## the base set) is forwardable. The `match.arg()` below validates
  ## the base set for all later branches.
  if (.is_icc_parm(parm)) {
    method_icc <- if ("method" %in% names(match.call())) method else "profile"
    return(.confint_icc(
      object,
      parm = parm,
      level = level,
      method = method_icc,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }
  if (.is_phylo_signal_parm(parm)) {
    method_ps <- if ("method" %in% names(match.call())) method else "profile"
    return(.confint_phylo_signal(
      object,
      parm = parm,
      level = level,
      method = method_ps,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }
  if (.is_communality_parm(parm)) {
    method_co <- if ("method" %in% names(match.call())) method else "profile"
    return(.confint_communality(
      object,
      parm = parm,
      level = level,
      method = method_co,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }
  if (.is_rho_parm(parm)) {
    method_rho <- if ("method" %in% names(match.call())) method else "profile"
    return(.confint_rho(
      object,
      parm = parm,
      level = level,
      method = method_rho,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }
  if (.is_proportion_parm(parm)) {
    method_prop <- if ("method" %in% names(match.call())) method else "profile"
    return(.confint_proportion(
      object,
      parm = parm,
      level = level,
      method = method_prop,
      nsim = nsim,
      seed = seed,
      ...
    ))
  }

  method <- match.arg(method)

  ## ---- Sigma matrix path ---------------------------------------------------
  if (.is_sigma_parm(parm)) {
    return(.confint_sigma(
      object,
      parm = parm,
      level = level,
      method = method,
      nsim = nsim,
      seed = seed
    ))
  }

  ## ---- profile_targets() inventory path (P1a, 2026-05-15) ------------------
  ## When `parm` matches a `profile_targets()` user-facing label
  ## (e.g. "sigma_eps", "sd_B[1]", "phi_nbinom2[2]"), route through
  ## the right helper instead of the fixed-effects path. b_fix
  ## elements continue through the fixed-effects path so existing
  ## callers don't break.
  if (.is_profile_target_parm(object, parm)) {
    tgt_filt <- profile_targets(object, ready_only = FALSE)
    is_b_fix <- as.character(parm) %in%
      tgt_filt$parm[
        tgt_filt$tmb_parameter == "b_fix" &
          !is.na(tgt_filt$tmb_parameter)
      ]
    if (!all(is_b_fix)) {
      if (method == "profile") {
        return(.confint_profile_targets(
          object,
          parm = parm,
          level = level,
          ...
        ))
      }
      if (method == "wald") {
        return(.confint_wald_targets(object, parm = parm, level = level, ...))
      }
      ## bootstrap on direct variance/dispersion components is not
      ## (yet) wired through here; fall through to the existing
      ## fixed-effects path's bootstrap-fallback handler which will
      ## issue a "not implemented; falling back to Wald" note.
    }
  }

  ## ---- Fixed-effects / variance-component path -----------------------------
  if (method == "wald") {
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  } else if (method == "profile") {
    td <- .confint_fixef_profile(object, level = level)
  } else {
    ## bootstrap on fixed effects: not currently supported (existing bootstrap
    ## machinery only covers Sigma matrices). Fall back to Wald with a note.
    cli::cli_inform(
      "Bootstrap on fixed effects is not implemented; falling back to {.code method = \"wald\"}."
    )
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  }

  if (!missing(parm)) {
    if (is.numeric(parm)) {
      td <- td[parm, , drop = FALSE]
    } else {
      td <- td[match(parm, td$term), , drop = FALSE]
    }
  }
  out <- as.matrix(td[, c("conf.low", "conf.high")])
  rownames(out) <- td$term
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  out
}

## ---- Sigma path: dispatch on method ---------------------------------------

#' @keywords internal
#' @noRd
.confint_sigma <- function(object, parm, level, method, nsim, seed) {
  if (method == "bootstrap") {
    return(.confint_sigma_bootstrap(object, parm, level, nsim, seed))
  }
  if (method == "wald") {
    return(.confint_sigma_wald(object, parm, level))
  }
  ## profile
  .confint_sigma_profile(object, parm, level, nsim = nsim, seed = seed)
}

#' @keywords internal
#' @noRd
.confint_sigma_bootstrap <- function(object, parm, level, nsim, seed) {
  info <- .sigma_parm_info(parm)
  lvl <- info$internal

  boot <- bootstrap_Sigma(
    fit = object,
    n_boot = as.integer(nsim),
    level = info$level,
    what = "Sigma",
    conf = level,
    seed = seed,
    progress = FALSE
  )

  key_pt <- info$key
  pe <- boot$point_est[[key_pt]]
  lo <- boot$ci_lower[[key_pt]]
  hi <- boot$ci_upper[[key_pt]]

  if (is.null(pe)) {
    cli::cli_abort(c(
      "No {.val {parm}} found in the bootstrap output.",
      "i" = "Check that this covariance tier is present in the fit."
    ))
  }

  if (isTRUE(info$phy)) {
    tr_nms <- rownames(pe)
    if (is.null(tr_nms)) {
      tr_nms <- paste0("trait_", seq_len(nrow(pe)))
    }
    return(data.frame(
      parameter = paste0("sigma_phy[", tr_nms, "]"),
      estimate = sqrt(diag(pe)),
      lower = sqrt(diag(lo)),
      upper = sqrt(diag(hi)),
      method = "bootstrap",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  n <- nrow(pe)
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) {
    tr_nms <- paste0("trait_", seq_len(n))
  }
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)
  data.frame(
    parameter = paste0(
      info$display,
      "[",
      tr_nms[idx[, 1L]],
      ",",
      tr_nms[idx[, 2L]],
      "]"
    ),
    estimate = pe[idx],
    lower = lo[idx],
    upper = hi[idx],
    method = "bootstrap",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' @keywords internal
#' @noRd
.confint_sigma_wald <- function(object, parm, level) {
  ## Wald on Sigma: use sd_report covariance of theta_diag_<tier> +
  ## theta_rr_<tier> entries combined; for now fall back to the
  ## point-estimate diagonal and SE on diagonal-only entries.
  info <- .sigma_parm_info(parm)
  lvl <- info$internal
  tier_label <- if (lvl == "phy") "phy" else lvl
  Sigma_pt <- suppressMessages(extract_Sigma(
    object,
    level = info$level,
    part = "total",
    link_residual = "none"
  ))
  if (is.null(Sigma_pt)) {
    cli::cli_abort("No tier {.val {lvl}} in fit.")
  }
  pe <- Sigma_pt$Sigma
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) {
    tr_nms <- paste0("trait_", seq_len(nrow(pe)))
  }

  if (isTRUE(info$phy)) {
    ## Per-trait SDs: profile is direct on log_sd_phy_diag
    ix <- which(names(object$opt$par) == "log_sd_phy_diag")
    if (length(ix) == 0L) {
      cli::cli_abort(
        "Sigma_phy Wald CIs require {.code log_sd_phy_diag} in opt$par."
      )
    }
    se <- sqrt(diag(object$sd_report$cov.fixed))[ix]
    z <- stats::qnorm(1 - (1 - level) / 2)
    log_sd <- as.numeric(object$opt$par[ix])
    return(data.frame(
      parameter = paste0("sigma_phy[", tr_nms, "]"),
      estimate = exp(log_sd),
      lower = exp(log_sd - z * se),
      upper = exp(log_sd + z * se),
      method = "wald",
      stringsAsFactors = FALSE,
      row.names = NULL
    ))
  }

  ## Generic Sigma matrix Wald path: only diagonal entries get SE'd
  ## (off-diagonals are non-linear functions of multiple parameters
  ## and need delta-method which we defer to bootstrap or profile).
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)
  out <- data.frame(
    parameter = paste0(
      info$display,
      "[",
      tr_nms[idx[, 1L]],
      ",",
      tr_nms[idx[, 2L]],
      "]"
    ),
    estimate = pe[idx],
    lower = NA_real_,
    upper = NA_real_,
    method = "wald",
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  ## Fill diagonal entries only
  diag_rows <- which(idx[, 1L] == idx[, 2L])
  ## On the log-SD scale of diag_<tier>, get the SE; transform back to var
  ix_diag <- which(names(object$opt$par) == paste0("theta_diag_", tier_label))
  if (length(ix_diag) >= length(diag_rows) && !is.null(object$sd_report)) {
    se_vec <- tryCatch(
      sqrt(diag(object$sd_report$cov.fixed))[ix_diag],
      error = function(e) NULL
    )
    if (!is.null(se_vec) && length(se_vec) == nrow(pe)) {
      log_sd <- as.numeric(object$opt$par[ix_diag])
      z <- stats::qnorm(1 - (1 - level) / 2)
      var_lo <- exp(2 * (log_sd - z * se_vec))
      var_hi <- exp(2 * (log_sd + z * se_vec))
      out$lower[diag_rows] <- var_lo
      out$upper[diag_rows] <- var_hi
    }
  }
  out
}

#' @keywords internal
#' @noRd
.confint_sigma_profile <- function(object, parm, level, nsim, seed) {
  ## Profile path on Sigma matrices.
  ##
  ## For sigma_phy (per-trait SDs from log_sd_phy_diag), TMB::tmbprofile()
  ## is direct -- one parameter per trait.
  ##
  ## For Sigma_unit / Sigma_unit_obs with only diag_<tier> (no latent), profile on
  ## theta_diag_<tier> gives per-trait variance; off-diagonals are zero
  ## by construction. This is the cleanest profile case.
  ##
  ## For Sigma_unit / Sigma_unit_obs with latent + diag, the total Sigma_t,t and
  ## off-diagonals are non-linear functions of multiple parameters
  ## (Lambda * Lambda^T + S_t), with rotation indeterminacy in Lambda.
  ## Profile via fix-and-refit is theoretically possible but unstable in
  ## practice (the rotation-equivalent class of Lambda is dense). We
  ## emit a clear advisory and fall back to bootstrap.
  info <- .sigma_parm_info(parm)
  lvl <- info$internal
  Sigma_pt <- suppressMessages(extract_Sigma(
    object,
    level = info$level,
    part = "total",
    link_residual = "none"
  ))
  if (is.null(Sigma_pt)) {
    cli::cli_abort("No tier {.val {lvl}} in fit.")
  }
  pe <- Sigma_pt$Sigma
  tr_nms <- rownames(pe)
  if (is.null(tr_nms)) {
    tr_nms <- paste0("trait_", seq_len(nrow(pe)))
  }

  if (isTRUE(info$phy)) {
    ## Per-trait SDs: profile is direct on log_sd_phy_diag
    df_log <- .tmbprofile_block(
      object,
      "log_sd_phy_diag",
      level = level,
      transform = exp,
      labels = paste0("sigma_phy[", tr_nms, "]")
    )
    if (is.null(df_log)) {
      cli::cli_inform(
        "No {.code log_sd_phy_diag} in opt$par; falling back to Wald for sigma_phy."
      )
      return(.confint_sigma_wald(object, parm, level))
    }
    return(df_log)
  }

  ## For Sigma_unit / Sigma_unit_obs: profile diagonal on theta_diag_<tier> when
  ## that gives the full diagonal (no rr at this tier).
  rr_used <- if (lvl == "B") {
    isTRUE(object$use$rr_B)
  } else {
    isTRUE(object$use$rr_W)
  }
  diag_used <- if (lvl == "B") {
    isTRUE(object$use$diag_B)
  } else {
    isTRUE(object$use$diag_W)
  }
  idx <- which(upper.tri(pe, diag = TRUE), arr.ind = TRUE)

  if (!rr_used && diag_used) {
    ## Pure diag tier: per-trait variance is identifiable and direct profile
    diag_block <- .tmbprofile_block(
      object,
      paste0("theta_diag_", lvl),
      level = level,
      transform = function(x) exp(2 * x)
    )
    out <- data.frame(
      parameter = paste0(
        info$display,
        "[",
        tr_nms[idx[, 1L]],
        ",",
        tr_nms[idx[, 2L]],
        "]"
      ),
      estimate = pe[idx],
      lower = NA_real_,
      upper = NA_real_,
      method = "profile",
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    diag_rows <- which(idx[, 1L] == idx[, 2L])
    if (
      !is.null(diag_block) && length(diag_block$estimate) == length(diag_rows)
    ) {
      out$lower[diag_rows] <- diag_block$lower
      out$upper[diag_rows] <- diag_block$upper
    }
    ## Off-diagonals are zero by construction in pure-diag tier
    off_rows <- which(idx[, 1L] != idx[, 2L])
    out$lower[off_rows] <- 0
    out$upper[off_rows] <- 0
    return(out)
  }

  ## rr present (with or without diag): full Sigma is rotation-equivalent
  ## under Lambda. Fall back to bootstrap with a clear advisory.
  cli::cli_inform(c(
    "Profile CIs on {parm} entries when {.code latent()} is present require fix-and-refit on a non-linear function of multiple rotation-equivalent parameters and are unstable.",
    "i" = "Falling back to {.code method = \"bootstrap\"}; pass {.code nsim} to control replicate count."
  ))
  ## Reuse the bootstrap path with the caller's controls.
  return(.confint_sigma_bootstrap(
    object,
    parm,
    level,
    nsim = nsim,
    seed = seed
  ))
}

## ---- Profile / Wald on fixed effects -------------------------------------

#' @keywords internal
#' @noRd
.confint_fixef_profile <- function(object, level) {
  if (isTRUE(object$REML)) {
    cli::cli_abort(c(
      "Profile confidence intervals for fixed effects are not available for REML fits.",
      "i" = "Use {.code method = \"wald\"} for REML fixed effects, or refit with {.code REML = FALSE} for ML profiling."
    ))
  }
  ## Loop over b_fix entries via tmbprofile, label as the fixed-effect
  ## term names from $X_fix_names.
  ix <- which(names(object$opt$par) == "b_fix")
  if (length(ix) == 0L) {
    ## No fixed effects -- return empty
    td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
    td$conf.low <- NA_real_
    td$conf.high <- NA_real_
    return(td)
  }
  term_names <- object$X_fix_names %||% paste0("b_fix[", seq_along(ix), "]")
  out <- vector("list", length(ix))
  for (k in seq_along(ix)) {
    out[[k]] <- tmbprofile_wrapper(
      object,
      name = "b_fix",
      which = k,
      level = level
    )
  }
  ## Wald estimates and SEs from existing tidy
  td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  ## Override conf.low / conf.high with profile bounds
  ## (only for rows that match b_fix entries)
  ## Match terms
  est <- vapply(out, `[`, numeric(1), "estimate")
  lo <- vapply(out, `[`, numeric(1), "lower")
  hi <- vapply(out, `[`, numeric(1), "upper")
  if (nrow(td) == length(ix)) {
    td$conf.low <- lo
    td$conf.high <- hi
  }
  td
}
