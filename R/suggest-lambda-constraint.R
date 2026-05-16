## Helper that produces a default `lambda_constraint` matrix to fix the
## rotational ambiguity of the reduced-rank loadings Lambda. The implied
## covariance Lambda Lambda^T is identifiable; Lambda alone is not. Users
## then pass the returned matrix to `gllvmTMB(..., lambda_constraint = ...)`.

#' Suggest a `lambda_constraint` matrix for a reduced-rank GLLVM
#'
#' Produces a sensible default constraint matrix `M` that resolves the
#' rotational ambiguity of the reduced-rank loadings Lambda in models of
#' the form
#' `value ~ 0 + trait + latent(0 + trait | site, d = K) + ...`. The matrix is
#' returned in the format expected by [gllvmTMB()]'s `lambda_constraint`
#' argument: `NA` in free entries, numeric in pinned entries.
#'
#' @param fit_or_formula Either a fitted `gllvmTMB_multi` object or a
#'   formula. If a formula, `data` must also be supplied.
#' @param data A data frame. Required when `fit_or_formula` is a formula;
#'   ignored when it is a fit.
#' @param level Which loading matrix to constrain: `"B"` (between-site,
#'   default) or `"W"` (within-site).
#' @param convention One of:
#'   \describe{
#'     \item{`"lower_triangular"` (default)}{Pin every upper-triangular
#'       entry to 0, i.e. `M[i, j] = 0` for `j > i`. Removes the
#'       rotational ambiguity completely. Pins `K(K-1)/2` entries.}
#'     \item{`"pin_top_one"`}{Single-anchor convention: `M[1, 1] = 1`,
#'       rest `NA`. Sets the scale of factor 1; does NOT remove rotational
#'       ambiguity.}
#'     \item{`"none"`}{All-`NA` matrix -- no pins. Useful if you plan to
#'       apply post-hoc rotation (e.g. varimax) instead.}
#'   }
#' @param trait,unit Name of the trait and unit (site) columns. Forwarded when
#'   `fit_or_formula` is a formula and the data does not already use
#'   defaults.
#' @param site Deprecated alias for `unit`. Emits a one-shot warning and maps
#'   to `unit`.
#'
#' @return A list with components:
#'   \describe{
#'     \item{`constraint`}{A `T x K` matrix with `NA` in free entries and
#'       0 (or 1, for `"pin_top_one"`) in pinned entries. Has trait names
#'       as rownames and `"f1", ..., "fK"` as colnames.}
#'     \item{`convention`}{The chosen convention.}
#'     \item{`d`}{The number of factors `K`.}
#'     \item{`n_pins`}{Number of pinned entries.}
#'     \item{`note`}{A short explanation of what was pinned and why.}
#'     \item{`usage_hint`}{An example call as a string showing how to use
#'       the returned matrix with [gllvmTMB()].}
#'   }
#'
#' @examples
#' \dontrun{
#' sug <- suggest_lambda_constraint(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data = my_data
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data              = my_data,
#'   trait             = "trait",
#'   unit              = "site",
#'   lambda_constraint = list(B = sug$constraint)
#' )
#' }
#' @export
suggest_lambda_constraint <- function(fit_or_formula,
                                      data = NULL,
                                      level = c("unit", "unit_obs", "B", "W"),
                                      convention = c("lower_triangular",
                                                     "pin_top_one",
                                                     "none"),
                                      trait = "trait",
                                      unit = "site",
                                      site = NULL) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  ## Backward-compat: `site` is a deprecated alias for `unit`.
  if (!is.null(site)) {
    .Deprecated(msg = paste0(
      "The `site` argument of `suggest_lambda_constraint()` is deprecated. ",
      "Use `unit` instead."
    ))
    unit <- site
  }
  ## level was already normalised at function entry (line above)
  convention <- match.arg(convention)

  ## ---- Resolve T (n_traits), K (rank), trait_names ---------------------
  if (inherits(fit_or_formula, "gllvmTMB_multi")) {
    fit <- fit_or_formula
    if (level == "B") {
      if (!isTRUE(fit$use$rr_B))
        cli::cli_abort("Fit has no {.code latent(... | unit, ...)} term -- nothing to constrain at level {.val B}.")
      K <- as.integer(fit$d_B)
    } else {
      if (!isTRUE(fit$use$rr_W))
        cli::cli_abort("Fit has no {.code latent()} term at the within-unit (W) tier -- nothing to constrain at level {.val W}.")
      K <- as.integer(fit$d_W)
    }
    n_traits    <- as.integer(fit$n_traits)
    trait_names <- levels(fit$data[[fit$trait_col]])
  } else if (inherits(fit_or_formula, "formula")) {
    if (is.null(data))
      cli::cli_abort("{.arg data} is required when {.arg fit_or_formula} is a formula.")
    ## Run the canonical-keyword + brms-sugar rewriter so that formulas
    ## using `latent()` / `unique()` / `phylo_latent()` etc. are
    ## recognised by parse_multi_formula() (which only knows the
    ## engine-internal names `rr`, `diag`, `phylo_rr`).
    fit_or_formula <- desugar_brms_sugar(fit_or_formula, trait_col = trait)
    parsed   <- parse_multi_formula(fit_or_formula)
    kinds    <- vapply(parsed$covstructs, function(cs) cs$kind, character(1))
    groups   <- vapply(parsed$covstructs, function(cs) deparse(cs$group), character(1))
    target_group <- if (level == "B") unit else "site_species"
    idx <- which(kinds == "rr" & groups == target_group)
    if (length(idx) == 0L)
      cli::cli_abort("Formula has no {.code latent(... | {target_group}, ...)} term -- nothing to constrain at level {.val {level}}.")
    cs <- parsed$covstructs[[idx[1]]]
    K  <- as.integer(cs$extra$d %||% 1L)
    if (!trait %in% names(data))
      cli::cli_abort("Column {.val {trait}} not found in {.arg data}.")
    tcol <- data[[trait]]
    trait_names <- if (is.factor(tcol)) levels(tcol) else sort(unique(as.character(tcol)))
    n_traits <- length(trait_names)
  } else {
    cli::cli_abort("{.arg fit_or_formula} must be a {.cls gllvmTMB_multi} fit or a formula.")
  }

  ## ---- Validate K vs T --------------------------------------------------
  if (K > n_traits)
    cli::cli_abort(c(
      "Number of factors K = {K} exceeds number of traits T = {n_traits}.",
      "i" = "A T x K loadings matrix requires K <= T."
    ))

  ## ---- Build constraint matrix ----------------------------------------
  M <- matrix(NA_real_, nrow = n_traits, ncol = K)
  rownames(M) <- trait_names
  colnames(M) <- paste0("f", seq_len(K))

  n_pins <- 0L
  note   <- ""
  if (convention == "lower_triangular") {
    if (K == 1L) {
      note <- paste0(
        "K = 1: no rotational ambiguity exists for a single factor, so ",
        "no entries are pinned. Returned matrix is all NA."
      )
    } else {
      for (i in seq_len(n_traits)) {
        for (j in seq_len(K)) {
          if (j > i) M[i, j] <- 0
        }
      }
      n_pins <- as.integer(K * (K - 1L) / 2L)
      note <- paste0(
        "Pinned the K(K-1)/2 = ", n_pins,
        " upper-triangular entries of Lambda to 0 (lower-triangular ",
        "convention). Removes the rotational ambiguity completely."
      )
    }
  } else if (convention == "pin_top_one") {
    M[1L, 1L] <- 1
    n_pins <- 1L
    note <- paste0(
      "Pinned M[1, 1] = 1 (single-anchor convention). Sets the scale of ",
      "factor 1 but does NOT remove the rotational ambiguity; consider ",
      "post-hoc rotation (e.g. varimax) for interpretation."
    )
  } else {
    note <- paste0(
      "No pins. Returned matrix is all NA. Use this if you intend to ",
      "rotate the fitted Lambda post-hoc (e.g. varimax)."
    )
  }

  arg <- if (level == "B") "B" else "W"
  usage_hint <- sprintf("lambda_constraint = list(%s = result$constraint)", arg)

  list(
    constraint = M,
    convention = convention,
    d          = K,
    n_pins     = n_pins,
    note       = note,
    usage_hint = usage_hint
  )
}
