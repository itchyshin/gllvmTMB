# Structured trait-intercept source strength. This channel is deliberately
# separate from response-column coefficient rho and its singleton parameter.

.structured_rho_validate <- function(value) {
  if (is.null(value)) return(invisible(NULL))
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
      value < 0 || value > 1) {
    cli::cli_abort("{.arg rho} must be a single finite number in [0, 1], or {.code NULL} to estimate source strength.",
      class = "gllvmTMB_structured_rho_invalid")
  }
  invisible(value)
}

.parse_structured_rho_formula <- function(formula, trait_col = "trait", strip = TRUE) {
  sources <- c("phylo", "animal", "kernel", "spatial")
  modes <- c("indep", "dep", "latent", "scalar", "unique")
  helpers <- as.vector(outer(sources, modes, paste, sep = "_"))
  # Legacy structured blocks also count when any new attenuation is requested.
  blocks <- c(helpers, "phylo_rr", "phylo", "phylo_slope", "animal_slope",
              "spatial", "spatial_rr", "propto", "equalto",
              "phylo_coef", "animal_coef", "kernel_coef", "spatial_coef")
  env <- environment(formula)
  found <- list()
  active <- list()
  match_marker <- function(definition, e) {
    tryCatch(match.call(definition, e, expand.dots = FALSE), error = function(err) {
      cli::cli_abort("Could not match structured source arguments; supply {.arg rho} once, preferably by name.",
        class = "gllvmTMB_structured_rho_invalid", parent = err)
    })
  }
  walk <- function(e) {
    if (!is.call(e)) return(e)
    fn <- if (is.symbol(e[[1L]])) as.character(e[[1L]]) else ""
    if (fn %in% blocks) found[[length(found) + 1L]] <<- fn
    if (fn %in% setdiff(blocks, c(helpers, "phylo_coef", "animal_coef", "kernel_coef", "spatial_coef")) &&
        "rho" %in% names(as.list(e))) {
      value <- eval(e$rho, env)
      .structured_rho_validate(value)
      if (is.null(value) || value != 1) {
        cli::cli_abort("New {.arg rho} requires a canonical {.code phylo_*}, {.code animal_*} or {.code kernel_*} indep/dep/latent helper; it is not supported on {.fn {fn}}.",
          class = "gllvmTMB_structured_rho_alias")
      }
      e <- as.call(as.list(e)[names(as.list(e)) != "rho"])
    }
    if (fn %in% helpers) {
      args <- as.list(e)[-1L]
      nms <- names(args)
      if (is.null(nms)) nms <- rep("", length(args))
      rho_idx <- which(nms == "rho")
      if (length(rho_idx) > 1L) {
        cli::cli_abort("Supply {.arg rho} only once per structured term.",
          class = "gllvmTMB_structured_rho_invalid")
      }
      # Trailing positional rho is admitted on canonical helpers. Using the
      # actual public formals keeps their argument order authoritative.
      if (!length(rho_idx) && exists(fn, mode = "function", inherits = TRUE)) {
        definition <- get(fn, mode = "function", inherits = TRUE)
        if ("rho" %in% names(formals(definition))) {
          matched <- match_marker(definition, e)
          if ("rho" %in% names(as.list(matched))) {
            # Match each argument with a unique token to find the original
            # position without evaluating source objects or changing syntax.
            tagged <- e
            for (j in seq_along(args)) tagged[j + 1L] <- list(as.name(paste0(".arg", j)))
            tagged <- match_marker(definition, tagged)
            rho_idx <- as.integer(sub(".arg", "", as.character(tagged$rho), fixed = TRUE))
          }
        }
      }
      if (length(rho_idx)) {
        value <- tryCatch(eval(args[[rho_idx]], env), error = function(err) {
          cli::cli_abort("Could not evaluate {.arg rho} in the formula environment.",
            class = "gllvmTMB_structured_rho_invalid", parent = err)
        })
        .structured_rho_validate(value)
        enabled <- is.null(value) || value != 1
        source <- sub("_.*", "", fn)
        mode <- sub("^[^_]+_", "", fn)
        if (enabled && mode %in% c("scalar", "unique")) {
          replacement <- paste0(source, "_indep")
          extra <- if (mode == "scalar") ", common = TRUE" else ""
          cli::cli_abort(c(
            "New source attenuation requires a canonical helper.",
            "i" = "Replace {.code {fn}(...)} with {.code {replacement}(...{extra}, rho = ...)}."
          ), class = "gllvmTMB_structured_rho_alias")
        }
        if (enabled) {
          options <- args
          if (mode %in% c("indep", "dep", "latent")) {
            definition <- get(fn, mode = "function", inherits = TRUE)
            options <- as.list(match_marker(definition, e))[-1L]
          }
          first <- options[[1L]]
          is_bar <- is.call(first) && as.character(first[[1L]]) %in% c("|", "||")
          group <- if (is_bar) first[[3L]] else first
          lhs_ok <- !is_bar || .structured_rho_intercept_lhs(first[[2L]], trait_col)
          if (!is.symbol(group) || !lhs_ok) {
            cli::cli_abort("New {.arg rho} supports structured trait intercepts only; augmented slopes are not admitted.",
              class = "gllvmTMB_structured_rho_slope")
          }
          eval_option <- function(name, default) {
            idx <- which(names(options) == name)
            if (length(idx)) eval(options[[idx]], env) else default
          }
          active[[length(active) + 1L]] <<- list(
            term = paste0("structured_", length(found)), helper = fn,
            source = source, mode = mode, grouping = as.character(group),
            status = if (is.null(value)) "estimated" else "fixed",
            value = value, folded_psi = isTRUE(eval_option("unique", FALSE)),
            common = isTRUE(eval_option("common", FALSE)),
            d = eval_option("d", 1L), original_call = e,
            source_arguments = options[names(options) %in% c("tree", "vcv", "A", "Ainv", "K", "pedigree")]
          )
        }
        # Remove explicit endpoint rho as well: downstream legacy parsing must
        # see exactly the old call, with no inert extras concealing differences.
        if (strip || !enabled) {
          retained <- if (enabled) options[names(options) != "rho"] else args[-rho_idx]
          e <- as.call(c(list(e[[1L]]), retained))
        } else {
          # Existing shared()/wide walkers assign with [[<- and can delete a
          # literal NULL. A constant base expression survives those passes and
          # evaluates to NULL when captured again in the long-format entry.
          e[rho_idx + 1L] <- list(if (is.null(value)) quote(base::as.null(0)) else value)
        }
      }
      return(e)
    }
    for (j in seq_along(e)[-1L]) e[j] <- list(walk(e[[j]]))
    e
  }
  out <- formula
  out[[length(out)]] <- walk(out[[length(out)]])
  if (length(active) && length(found) != 1L) {
    cli::cli_abort(c(
      "New source attenuation admits one structured covariance block per fit.",
      "i" = "A latent term with {.code unique = TRUE} counts as one block; separate structured terms cannot be combined with new {.arg rho}."
    ), class = "gllvmTMB_structured_rho_blocks")
  }
  list(formula = out, spec = if (length(active)) active[[1L]] else NULL)
}

.structured_rho_dispatch_fence <- function(spec, engine = "tmb",
                                         integration = "laplace", estimator = "ml",
                                         aghq = FALSE) {
  if (is.null(spec)) return(invisible(NULL))
  if (engine != "tmb" || integration != "laplace" || estimator != "ml" || !isFALSE(aghq)) {
    cli::cli_abort("New structured {.arg rho} requires native TMB Laplace maximum likelihood; Julia, VA and MSPL are not supported.",
      class = "gllvmTMB_structured_rho_dispatch")
  }
  invisible(NULL)
}

.structured_rho_intercept_lhs <- function(lhs, trait_col) {
  lhs <- .strip_lhs_parens(lhs)
  .is_one_lhs(lhs) ||
    (is.symbol(lhs) && identical(as.character(lhs), trait_col)) ||
    (is.call(lhs) && length(lhs) == 3L &&
      identical(lhs[[1L]], as.name("+")) && identical(lhs[[2L]], 0) &&
      is.symbol(lhs[[3L]]) && identical(as.character(lhs[[3L]]), trait_col))
}

.structured_rho_covariance <- function(K, rho) {
  .structured_rho_validate(rho)
  if (is.null(rho)) stop("A numerical rho is required to form a covariance.")
  if (rho == 1) return(K)
  out <- rho * K
  diag(out) <- diag(K)
  out
}

.structured_rho_marginal_diagonal <- function(precision, labels) {
  index <- match(labels, rownames(precision))
  if (anyNA(index)) stop("Modeled source labels are absent from the resolved precision.")
  factor <- Matrix::Cholesky(Matrix::forceSymmetric(precision), LDL = FALSE)
  diagonal <- numeric(length(index))
  contrast <- 0
  # Selected inverse columns with one sparse factorization. Never materialize
  # the augmented covariance (or condition on dropped ancestral nodes).
  for (j in seq_along(index)) {
    rhs <- numeric(nrow(precision))
    rhs[index[j]] <- 1
    column <- as.numeric(Matrix::solve(factor, rhs, system = "A"))[index]
    diagonal[j] <- column[j]
    if (length(index) > 1L) contrast <- max(contrast, abs(column[-j]))
  }
  names(diagonal) <- labels
  list(diagonal = diagonal, contrast = contrast)
}

.structured_rho_assert_estimation <- function(spec, family_id, group_id,
                                             observation_id, trait_id, n_traits,
                                             is_observed, competing = FALSE,
                                             REML = FALSE,
                                             n_groups = length(unique(group_id))) {
  if (is.null(spec) || spec$status != "estimated") return(invisible(NULL))
  abort <- function(message) cli::cli_abort(message,
    class = "gllvmTMB_structured_rho_identification")
  if (any(family_id != 0L) || isTRUE(REML)) {
    abort("Estimated structured {.arg rho} currently requires Gaussian maximum likelihood with retained observation residual variance.")
  }
  if (any(competing)) {
    abort(c("Estimated structured {.arg rho} does not admit competing ordinary covariance or other unproved observation models.",
      "i" = "An ordinary covariance on the same units can absorb changes in rho exactly. Remove the competing term or fix rho; optimizer convergence cannot establish identification."))
  }
  if (spec$mode == "latent" && (n_traits < 4L || !identical(as.numeric(spec$d), 1))) {
    abort("Estimated latent source strength requires rank one and at least four traits; triangular loading constraints alone do not identify the decomposition.")
  }
  if (n_traits < 2L) {
    abort("Estimated structured {.arg rho} requires at least two traits; the initial estimator supports replicated multivariate Gaussian observations.")
  }
  if (anyNA(group_id) || anyNA(observation_id) || anyNA(trait_id) ||
      anyNA(is_observed) || any(is_observed != 1L)) {
    abort("Estimated structured {.arg rho} requires complete observed multivariate replicate vectors.")
  }
  if (length(unique(group_id)) != n_groups) {
    abort("Estimated structured {.arg rho} requires observations for every modeled source group. Remove unused grouping-factor levels explicitly; contrast involving unobserved levels cannot identify rho.")
  }
  counts <- table(interaction(group_id, observation_id, drop=TRUE), trait_id)
  if (ncol(counts) != n_traits || any(counts != 1L)) {
    abort("Estimated structured {.arg rho} requires complete replicate vectors, each with exactly one observation per trait.")
  }
  vectors <- unique(data.frame(group=group_id, observation=observation_id))
  if (any(table(vectors$group) < 2L)) {
    abort("Estimated structured {.arg rho} requires at least two complete observation vectors per source group; retain Gaussian observation residual variance.")
  }
  invisible(NULL)
}

.structured_rho_assert_source <- function(diagonal, contrast) {
  # Scale-aware declared contrast tolerance, independent of fit outcomes.
  if (any(!is.finite(diagonal) | diagonal <= 0) || !is.finite(contrast) ||
      contrast <= 1e-10 * max(diagonal)) {
    cli::cli_abort("Estimated structured {.arg rho} requires positive source diagonals and nonzero between-group source contrast; a diagonal source cannot identify rho.",
      class = "gllvmTMB_structured_rho_identification")
  }
  invisible(NULL)
}

.structured_rho_spectral <- function(K) {
  d <- sqrt(diag(K))
  eig <- eigen(K / outer(d,d), symmetric=TRUE)
  if (any(!is.finite(eig$values) | eig$values <= 0)) {
    cli::cli_abort("The resolved source for estimated {.arg rho} must be positive definite.",
      class = "gllvmTMB_structured_rho_source")
  }
  list(vectors=eig$vectors, values=eig$values)
}

# Scores at modeled source levels, before observation replication. Dense fitted
# fields already have K_r covariance. Sparse fields retain their ancestors;
# only the independent companion lives directly on the modeled source levels.
.structured_rho_scores <- function(fit, count, field = "g_phy", iid = "g_phy_iid",
                                   redraw = FALSE, parameters = NULL) {
  td <- fit$tmb_data
  strength <- fit$source_strength
  if (is.null(strength)) {
    # Legacy endpoint: no metadata is added to the fitted object. Treat the
    # retained precision as augmented so its label map is always respected.
    strength <- list(value=1,status="fixed",representation="sparse",
      labels=levels(fit$data[[fit$species_col]]))
    fit$source_strength <- strength
  }
  rho <- strength$value
  weights <- .structured_rho_weights(fit)
  n <- td$n_species
  sparse <- identical(strength$representation, "sparse")
  aug <- if (sparse && !is.null(strength$labels) && !is.null(rownames(td$Ainv_phy_rr))) {
    match(strength$labels,rownames(td$Ainv_phy_rr))
  } else td$species_aug_id[match(seq_len(n)-1L,td$species_id)] + 1L
  if (redraw) {
    if (!sparse && isTRUE(td$structured_rho_estimated == 1L)) {
      variances <- weights[2L]^2 + weights[1L]^2*td$structured_rho_eigenvalues
      z <- matrix(stats::rnorm(n*count), n, count)
      return(sqrt(td$structured_rho_diagonal) *
        (td$structured_rho_eigenvectors %*% (sqrt(variances)*z)))
    }
    if (!sparse || weights[1L] > 0) {
      Q <- if (isTRUE(fit$use$propto)) td$Cphy_inv else td$Ainv_phy_rr
      z <- matrix(stats::rnorm(nrow(Q)*count), nrow(Q), count)
      if (inherits(Q,"sparseMatrix")) {
        fac <- Matrix::Cholesky(Q, perm=FALSE, LDL=FALSE)
        scores <- as.matrix(Matrix::solve(fac,z,system="Lt"))
      } else scores <- backsolve(chol(as.matrix(Q)),z)
      if (!sparse) return(scores)
      scores <- weights[1L]*scores[aug,,drop=FALSE]
    } else scores <- matrix(0,n,count)
    if (weights[2L] > 0) scores <- scores + weights[2L]*sqrt(td$structured_rho_diagonal)*
      matrix(stats::rnorm(n*count),n,count)
    return(scores)
  }
  if (is.null(parameters)) {
    parameters <- fit$tmb_obj$env$parList(par=fit$tmb_obj$env$last.par.best)
  }
  if (!sparse) return(parameters[[field]])
  scores <- if (weights[1L] == 0) matrix(0,n,count) else
    weights[1L]*parameters[[field]][aug,,drop=FALSE]
  if (weights[2L] > 0) scores <- scores + weights[2L]*sqrt(td$structured_rho_diagonal)*parameters[[iid]]
  scores
}

# Only rr + folded Psi: the propto branch already adds physical p_phy
# separately in both simulation and prediction. Never add it twice here.
.structured_rho_contribution <- function(fit, redraw = FALSE) {
  td <- fit$tmb_data
  ans <- matrix(0,td$n_species,td$n_traits)
  if (isTRUE(fit$use$phylo_rr)) {
    scores <- .structured_rho_scores(fit,td$d_phy,redraw=redraw)
    ans <- ans + scores %*% t(fit$report$Lambda_phy)
  }
  if (isTRUE(fit$use$phylo_diag)) {
    scores <- .structured_rho_scores(fit,td$n_traits,"g_phy_diag","g_phy_diag_iid",redraw)
    ans <- ans + sweep(scores,2L,fit$report$sd_phy_diag,"*")
  }
  ans
}

.structured_rho_source_allocation_assert <- function(fit, caller) {
  level <- if(is.list(fit) && identical(fit$source_strength$source,"spatial")) "spatial" else "phy"
  next_call <- sprintf('extract_Sigma(fit, level = "%s", link_residual = "none")',level)
  if (is.list(fit) && !is.null(fit$source_strength)) cli::cli_abort(c(
    "{.fn {caller}} does not account for structured source attenuation.",
    "i" = "Use {.code {next_call}} for trait covariance and its {.field source_strength} metadata.",
    "i" = "Source strength rho is not a variance-share or phylogenetic-signal summary."
  ), class = "gllvmTMB_structured_rho_source_allocation_unsupported")
  invisible(NULL)
}

.structured_rho_refit_assert <- function(fit, caller) {
  if (is.list(fit) && !is.null(fit$source_strength)) cli::cli_abort(c(
    "{.fn {caller}} cannot yet refit a rho-enabled structured model without changing its source specification.",
    "i" = "Use point covariance and source strength from {.fn extract_Sigma}; rho intervals and automatic comparison refits are not supported."
  ), class = "gllvmTMB_structured_rho_refit_unsupported")
  invisible(NULL)
}

.structured_rho_metadata <- function(fit) {
  x <- fit$source_strength
  if (is.null(x)) return(NULL)
  x[intersect(c("term","source","grouping","mode","folded_psi","common",
    "labels","resolved_scale","source_diagonal","representation","value","status",
    "boundary","nll_score_rho","nll_score_logit","kappa","diagnostics"),names(x))]
}


.structured_rho_weights <- function(fit) {
  rho <- fit$source_strength$value
  if (identical(fit$source_strength$status,"estimated")) {
    eta <- unname(fit$opt$par[names(fit$opt$par)=="eta_structured_rho"])
    if (length(eta)!=1L || !is.finite(eta)) cli::cli_abort(
      "Estimated source strength has no finite fitted logit parameter.",
      class="gllvmTMB_structured_rho_parameter_missing")
    softplus <- function(x) pmax(x,0)+log1p(exp(-abs(x)))
    return(exp(-.5*c(softplus(-eta),softplus(eta))))
  }
  c(sqrt(rho),sqrt(1-rho))
}

# Descriptive weak-signal checks, not identification certificates or intervals.
# Thresholds are fixed before the optimizer pre-run and retained study.
.structured_rho_diagnostics <- function(fit) {
  strength <- fit$source_strength
  if (is.null(strength) || strength$status != "estimated") return(NULL)
  L <- fit$report$Lambda_phy
  psi <- if (isTRUE(fit$use$phylo_diag)) fit$report$sd_phy_diag^2 else rep(0,fit$n_traits)
  shared <- if (isTRUE(fit$use$propto)) rep(as.numeric(fit$report$lam_phy),fit$n_traits) else if(!is.null(L)) rowSums(L^2) else rep(0,fit$n_traits)
  spatial <- identical(strength$source,"spatial")
  if(spatial) {
    L <- if(fit$tmb_data$spde_lv_k>0) fit$report$Lambda_spde else matrix(0,fit$n_traits,1)
    pars <- fit$tmb_obj$env$parList(par=fit$tmb_obj$env$last.par.best)
    psi <- if(fit$tmb_data$spde_lv_k==0 || fit$tmb_data$spde_lv_unique==1) exp(-2*pars$log_tau_spde) else rep(0,fit$n_traits)
    shared <- rowSums(L^2)
  }
  total <- shared+psi
  variance <- outer(strength$source_diagonal,total)
  residual <- rep(fit$report$sigma_eps[1L]^2,fit$n_traits)
  shares <- variance/(variance+matrix(residual,nrow(variance),length(residual),byrow=TRUE))
  weak_total <- !all(is.finite(shares)) || max(shares) < 1e-4
  messages <- character()
  if (isTRUE(strength$boundary)) messages <- c(messages,"rho is near an endpoint (within 0.0001); this is a descriptive flag.")
  if (weak_total) messages <- c(messages,"Total structured variance is negligible relative to Gaussian observation noise; source strength may be weakly determined.")
  ans <- list(weak_total_source=weak_total,variance_share_threshold=1e-4)
  if(spatial) {
    geometry <- .structured_rho_spatial_diagnostic(fit)
    ans$range_strength_geometry <- geometry
    if(isFALSE(geometry$available)) messages <- c(messages,paste("Spatial geometry diagnostic unavailable:",geometry$reason))
    if(isTRUE(geometry$relative_singular_value<=1e-8)) messages <- c(messages,
      "Spatial range and rho are weakly separated at the fitted point; the local geometry diagnostic is not a global identification test.")
  }
  if (strength$mode=="latent") {
    standard <- abs(as.numeric(L[,1L]))/sqrt(total)
    standard[!is.finite(standard)] <- 0
    n_informative <- sum(standard > .05)
    weak_split <- isTRUE(strength$folded_psi) && n_informative < 3L
    shared_variance <- outer(strength$source_diagonal,shared)
    shared_shares <- shared_variance/(variance+matrix(residual,nrow(variance),length(residual),byrow=TRUE))
    weak_shared <- !all(is.finite(shared_shares)) || max(shared_shares)<1e-4
    ans <- c(ans,list(weak_shared_component=weak_shared,
      weak_loading_psi_separation=weak_split,informative_loadings=n_informative,
      standardized_loadings=standard,loading_threshold=.05))
    if (weak_shared) messages <- c(messages,"Shared latent covariance is negligible; positive Psi can still identify total source covariance.")
    if (weak_split) messages <- c(messages,"Fewer than three standardized loadings exceed 0.05: weak evidence for separating shared covariance from Psi. This threshold is a heuristic, not a proof of nonidentification.")
  }
  ans$messages <- messages
  ans
}

.structured_rho_print <- function(strength) {
  if (is.null(strength)) return(invisible(NULL))
  cat(sprintf("  Source strength: rho = %.4g (%s; %s, group %s)\n",
    strength$value,strength$status,strength$source,strength$grouping))
  for (message in strength$diagnostics$messages) cat("  Source diagnostic:",message,"\n")
  invisible(NULL)
}


.structured_rho_interval_assert <- function(fit,name,which,lincomb) {
  if (!identical(fit$source_strength$status,"estimated")) return(invisible(NULL))
  level <- if (identical(fit$source_strength$source,"spatial")) "spatial" else "phy"
  next_call <- sprintf('extract_Sigma(fit, level = "%s")$source_strength',level)
  index <- base::which(names(fit$opt$par)=="eta_structured_rho")
  involves_rho <- if (is.null(lincomb)) {
    .resolve_param_index(fit,name,which) %in% index
  } else is.numeric(lincomb) && length(lincomb)==length(fit$opt$par) &&
    any(!is.finite(lincomb[index]) | lincomb[index]!=0)
  if (involves_rho) cli::cli_abort(c(
    "Intervals for structured source strength rho are not supported, including its raw logit or linear combinations containing it.",
    "i" = "Use the point value and descriptive diagnostics in {.code {next_call}}."
  ),class="gllvmTMB_structured_rho_interval_unsupported")
  invisible(NULL)
}
