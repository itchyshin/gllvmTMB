## dev/arc0/30-ray.R -- Arc 0, slice T3: the divergence ray and boundary
## diagnostics.
##
## Tests H3 (no finite MLE; the reported optimum is a halt on a plateau
## running to infinity) against its alternative, a finite optimum. Anchored at
## fit$opt$par (NOT fit$tmb_obj$par -- see dev/arc0/lib.R footer for why that
## trap silently probes the wrong point, verified to differ by ~39.5 nll units
## on the smoke cell used below).
##
## Usage:
##   Rscript dev/arc0/30-ray.R [input_csv] [output_csv]
## or via env vars:
##   ARC0_INPUT_CSV=/tmp/grid-ref.csv ARC0_OUTPUT_CSV=dev/arc0/ray.csv \
##     Rscript dev/arc0/30-ray.R
## Defaults: input "/tmp/grid-ref.csv", output "dev/arc0/ray.csv" (relative to
## the repo root, i.e. /private/tmp/gllvmtmb-arc0-identifiability).
##
## The caller (not this script) is expected to parallelise across cells with
## parallel::mclapply; arc0_ray_cell() below is the unit of work, and the
## bottom main block runs it serially over all selected cells for direct
## Rscript invocation.

suppressMessages({
  source(file.path("dev", "arc0", "lib.R"))
})

## Wide, log-spaced grid of multipliers spanning well below and well above 1.
RAY_S_GRID <- 10 ^ seq(-1, 3, length.out = 21)  ## 0.1 .. 1000, 21 points

## ---------------------------------------------------------------------------
## Core per-cell worker. Takes one row of the filtered campaign CSV (as a
## list/data.frame row) and returns a data.frame of ray-diagnostic rows (one
## per ray x cell -- ray A and ray B), or a one-row error record on failure.
## Never throws: all fit/probe work is wrapped in tryCatch.
arc0_ray_cell <- function(row) {
  cell_id <- sprintf("%s_n%d_p%d_q%d_seed%d", row$family, row$n, row$p, row$q,
                      row$seed)
  stratum <- sprintf("n%d_q%d", row$n, row$q)
  grp <- if (isTRUE(row$rel_frob > 10)) "degenerate" else "healthy"

  base_fields <- list(
    cell_id = cell_id, design = "T3_ray", stratum = stratum, grp = grp,
    n = row$n, p = row$p, q = row$q, seed = row$seed
  )

  err_row <- function(ray_name, msg) {
    as.data.frame(c(base_fields, list(
      ray = ray_name,
      nll_at_opt = NA_real_, fn_matches_opt = FALSE,
      s_argmin = NA_real_, nll_min_on_ray = NA_real_, delta_nll_min = NA_real_,
      nll_at_s_max = NA_real_, delta_nll_at_s_max = NA_real_,
      monotone_decreasing = NA, plateau_width_1unit = NA_real_,
      n_valid_s = NA_integer_, s_max_valid = NA_real_,
      frob_lambda = NA_real_, max_abs_b_fix = NA_real_,
      max_fitted_prob = NA_real_, min_fitted_prob = NA_real_,
      n_species_extreme = NA_integer_,
      conv = NA_integer_, pdHess = NA,
      verdict = "ERROR", error = msg
    )), stringsAsFactors = FALSE)
  }

  fit <- tryCatch({
    dat <- arc0_data(row$n, row$p, row$q, row$seed)
    arc0_fit(dat)
  }, error = function(e) e)

  if (inherits(fit, "error") || is.null(fit)) {
    msg <- if (inherits(fit, "error")) conditionMessage(fit) else "fit returned NULL"
    return(rbind(err_row("A", msg), err_row("B", msg)))
  }

  out <- tryCatch({
    pr <- fit$opt$par
    is_lam <- names(pr) == "theta_rr_B"
    is_b   <- names(pr) == "b_fix"
    nll_at_opt <- fit$opt$objective

    ## Mandatory anchor check: fn(opt$par) must reproduce opt$objective.
    ## fit$tmb_obj$fn() returns a value carrying a "logarithm" attribute (TMB's
    ## ADFun convention) that unname() alone does not strip, which makes
    ## all.equal() spuriously report a names/attribute mismatch even when the
    ## numeric values are identical -- strip via as.numeric(), not just unname().
    fn_at_opt <- as.numeric(fit$tmb_obj$fn(pr))
    fn_matches_opt <- isTRUE(all.equal(as.numeric(fn_at_opt), as.numeric(nll_at_opt),
                                        tolerance = 1e-4))

    conv <- fit$opt$convergence
    pdHess <- isTRUE(fit$sd_report$pdHess)

    L <- fit$report$Lambda_B[seq_len(row$p), seq_len(row$q), drop = FALSE]
    frob_lambda <- norm(L, "F")
    max_abs_b_fix <- max(abs(pr[is_b]))

    ## fit$report$eta comes back as a FLAT vector of length n*p, not a matrix
    ## (verified live: dim() is NULL, length 320 at n=40,p=8). Reshaping
    ## matrix(eta, nrow = p, ncol = n) puts species on rows and its row means
    ## reproduce b_fix (checked against the smoke fit); the flattening is
    ## species-major within each site, consistent with the stacked-trait long
    ## format. This eta is the linear predictor AT THE FITTED LATENT MODE
    ## (the Laplace-approximation conditional value of u, not a marginal-
    ## over-u quantity) -- so these fitted probabilities are conditional-on-
    ## latent-field probabilities, and extreme values here reflect
    ## conditional, not marginal, separation (consistent with the pre-fit
    ## scan finding zero marginal all-0/all-1 species).
    mat_eta <- matrix(fit$report$eta, nrow = row$p, ncol = row$n)
    prob_hat <- plogis(mat_eta)
    max_fitted_prob <- max(prob_hat)
    min_fitted_prob <- min(prob_hat)
    sp_extreme <- rowSums(prob_hat > (1 - 1e-6) | prob_hat < 1e-6) > 0
    n_species_extreme <- sum(sp_extreme)

    make_ray <- function(ray_name, scale_b) {
      nlls <- vapply(RAY_S_GRID, function(s) {
        pr_s <- pr
        pr_s[is_lam] <- pr[is_lam] * s
        if (scale_b) pr_s[is_b] <- pr[is_b] * s
        val <- tryCatch(as.numeric(fit$tmb_obj$fn(pr_s)), error = function(e) NA_real_)
        if (!is.finite(val)) NA_real_ else val
      }, numeric(1))

      ## NOTE: fit$tmb_obj$fn() returns NaN, not an error, once the scaled
      ## parameter vector overflows the C++ likelihood evaluation (observed on
      ## both smoke cells above s ~ 1.6-4: exp() overflow at huge linear
      ## predictors). n_valid_s / s_max_valid record how much of the nominal
      ## 0.1-1000 grid was actually probeable -- a ray that is mostly NaN is a
      ## different failure mode from one that stays finite and turns up, and
      ## the two must not be conflated silently.
      valid <- is.finite(nlls)
      n_valid_s <- sum(valid)
      s_max_valid <- if (any(valid)) max(RAY_S_GRID[valid]) else NA_real_
      if (!any(valid)) {
        return(list(
          s_argmin = NA_real_, nll_min_on_ray = NA_real_, delta_nll_min = NA_real_,
          nll_at_s_max = NA_real_, delta_nll_at_s_max = NA_real_,
          monotone_decreasing = NA, plateau_width_1unit = NA_real_,
          n_valid_s = n_valid_s, s_max_valid = s_max_valid,
          verdict = "ERROR"
        ))
      }

      s_v <- RAY_S_GRID[valid]
      nll_v <- nlls[valid]
      i_min <- which.min(nll_v)
      s_argmin <- s_v[i_min]
      nll_min_on_ray <- nll_v[i_min]
      delta_nll_min <- nll_at_opt - nll_min_on_ray  ## >0 => improvement available

      i_smax <- which.max(s_v)
      nll_at_s_max <- nll_v[i_smax]
      delta_nll_at_s_max <- nll_at_opt - nll_at_s_max  ## >0 => still improving at s_max

      ## monotone_decreasing: nll falls (weakly) across the whole ordered grid
      ord <- order(s_v)
      nll_ord <- nll_v[ord]
      monotone_decreasing <- all(diff(nll_ord) <= 1e-6)

      ## plateau_width_1unit: multiplicative range of s within 1 nll unit of
      ## the minimum on the ray.
      within1 <- s_v[nll_v <= nll_min_on_ray + 1]
      plateau_width_1unit <- if (length(within1) >= 2) {
        max(within1) / min(within1)
      } else {
        1
      }

      ## Verdict: turns up (delta_nll_at_s_max clearly negative, i.e. nll
      ## higher at s_max than at the minimum found) with a narrow plateau =>
      ## finite optimum, H3 refuted for this ray. Otherwise: still falling or
      ## plateau spans decades => consistent with H3 (no finite MLE).
      turns_up <- (nll_at_s_max - nll_min_on_ray) > 1  ## nll rose by >1 unit past the min
      narrow_plateau <- is.finite(plateau_width_1unit) && plateau_width_1unit < 10
      verdict <- if (turns_up && narrow_plateau) {
        "finite_optimum_H3_refuted"
      } else {
        "H3_no_finite_MLE"
      }

      list(
        s_argmin = s_argmin, nll_min_on_ray = nll_min_on_ray,
        delta_nll_min = delta_nll_min, nll_at_s_max = nll_at_s_max,
        delta_nll_at_s_max = delta_nll_at_s_max,
        monotone_decreasing = monotone_decreasing,
        plateau_width_1unit = plateau_width_1unit,
        n_valid_s = n_valid_s, s_max_valid = s_max_valid,
        verdict = verdict
      )
    }

    rA <- make_ray("A", scale_b = FALSE)
    rB <- make_ray("B", scale_b = TRUE)

    mk_row <- function(ray_name, r) {
      as.data.frame(c(base_fields, list(
        ray = ray_name,
        nll_at_opt = nll_at_opt, fn_matches_opt = fn_matches_opt,
        s_argmin = r$s_argmin, nll_min_on_ray = r$nll_min_on_ray,
        delta_nll_min = r$delta_nll_min,
        nll_at_s_max = r$nll_at_s_max, delta_nll_at_s_max = r$delta_nll_at_s_max,
        monotone_decreasing = r$monotone_decreasing,
        plateau_width_1unit = r$plateau_width_1unit,
        n_valid_s = r$n_valid_s, s_max_valid = r$s_max_valid,
        frob_lambda = frob_lambda, max_abs_b_fix = max_abs_b_fix,
        max_fitted_prob = max_fitted_prob, min_fitted_prob = min_fitted_prob,
        n_species_extreme = n_species_extreme,
        conv = conv, pdHess = pdHess,
        verdict = r$verdict, error = NA_character_
      )), stringsAsFactors = FALSE)
    }

    rbind(mk_row("A", rA), mk_row("B", rB))
  }, error = function(e) e)

  if (inherits(out, "error")) {
    return(rbind(err_row("A", conditionMessage(out)),
                 err_row("B", conditionMessage(out))))
  }
  out
}

## ---------------------------------------------------------------------------
## Main block: standalone Rscript entry point. Reads the campaign CSV, filters
## to the 281-cell bernoulli/gtmb_laplace universe, and appends one CSV row
## per (cell, ray) as each cell completes -- so a kill mid-run leaves usable
## output. Does NOT parallelise itself; the caller may mclapply over
## arc0_ray_cell() directly for parallel use.
arc0_ray_is_direct_run <- function() {
  ca <- commandArgs(trailingOnly = FALSE)
  any(grepl("--file=.*30-ray\\.R$", ca))
}

if (arc0_ray_is_direct_run()) {
  args <- commandArgs(trailingOnly = TRUE)
  input_csv <- if (length(args) >= 1) args[[1]] else Sys.getenv("ARC0_INPUT_CSV", "/tmp/grid-ref.csv")
  output_csv <- if (length(args) >= 2) args[[2]] else Sys.getenv("ARC0_OUTPUT_CSV", "dev/arc0/ray.csv")

  arc0_load()

  d <- read.csv(input_csv, stringsAsFactors = FALSE)
  sel <- d$arm == "gtmb_laplace" & d$family == "bernoulli" & is.finite(d$rel_frob)
  cells <- d[sel, , drop = FALSE]
  message(sprintf("30-ray.R: %d cells selected from %s", nrow(cells), input_csv))

  if (file.exists(output_csv)) file.remove(output_csv)
  wrote_header <- FALSE

  for (i in seq_len(nrow(cells))) {
    row <- cells[i, ]
    res <- tryCatch(arc0_ray_cell(row), error = function(e) {
      data.frame(cell_id = sprintf("%s_n%d_p%d_q%d_seed%d", row$family, row$n,
                                    row$p, row$q, row$seed),
                 error = conditionMessage(e), stringsAsFactors = FALSE)
    })
    utils::write.table(res, output_csv, sep = ",", row.names = FALSE,
                        col.names = !wrote_header, append = wrote_header,
                        qmethod = "double")
    wrote_header <- TRUE
    message(sprintf("[%d/%d] %s: %s", i, nrow(cells),
                     if (!is.null(row$n)) sprintf("n%d_q%d_seed%d", row$n, row$q, row$seed) else "?",
                     if ("verdict" %in% names(res)) paste(unique(res$verdict), collapse = "/") else "ERROR"))
  }

  message(sprintf("30-ray.R: done, wrote %s", output_csv))
}
