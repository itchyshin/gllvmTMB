## False-positive sweep for the runaway-relative-loading gate (R/diagnose.R).
##
## Question: `binomial_prevalence_loading` currently requires `extreme_prevalence`
## before a dominant loading can flag, so a Heywood case at moderate prevalence
## reports PASS. If a runaway loading is allowed to flag on its own, what
## criterion separates degenerate fits from healthy ones -- and does one number
## transport across families, loading structures, n, T (traits) and q?
##
## Two candidate statistics are recorded per fit, because they fail differently:
##
##   rl_max       max over traits of `relative_loading` = a trait's largest
##                loading divided by max(median, mad) of the per-trait largest
##                loadings. Dimensionless, so the response scale cancels -- but
##                its DENOMINATOR COLLAPSES when most traits genuinely load near
##                zero, which inflates the ratio on a perfectly healthy fit.
##                That is the transport risk, and the `sparse*` DGPs below exist
##                to measure it.
##   max_loading  the largest |loading| on the linear-predictor scale. For a
##                logit link this has a real absolute meaning (|eta| > 10 is
##                already a fitted probability indistinguishable from 0 or 1),
##                but it does not transport to gaussian, where a large loading
##                can be legitimate.
##
## HEALTHY IS DEFINED BY RECOVERY, NOT BY CONVERGENCE. 59 of 70 recorded
## degenerate fits reported convergence = 0 with pdHess = TRUE
## (docs/dev-log/2026-07-29-vgh-implementation-plan.md:126-131), so screening on
## the optimizer would seed the "healthy" set with the exact pathology being
## calibrated against.
##
## Usage: Rscript dev/heywood/fp-sweep.R <grid> <n_seeds> <out.csv> [cores]

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})

args <- commandArgs(trailingOnly = TRUE)
grid_name <- if (length(args) >= 1) args[[1]] else "pilot"
n_seeds <- if (length(args) >= 2) as.integer(args[[2]]) else 5L
out_csv <- if (length(args) >= 3) args[[3]] else "dev/heywood/fp-sweep-pilot.csv"
n_cores <- if (length(args) >= 4) as.integer(args[[4]]) else 8L

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(x, y) if (is.null(x)) y else x

## ---------------------------------------------------------------- grid ----
##
## dgp controls how the TRUE loadings are spread across traits:
##   homog     every trait sd 0.7            -- denominator well determined
##   sparse50  half the traits sd 0.05        -- median sits at the boundary
##   sparse75  three quarters of traits 0.05  -- median sits inside the weak
##                                              group; adversarial for a ratio

grids <- list(
  pilot = expand.grid(
    dgp = c("homog", "sparse50", "sparse75"),
    family = c("binomial", "poisson", "gaussian"),
    n = c(60L, 150L),
    p = c(5L, 12L),
    q = c(2L, 3L),
    stringsAsFactors = FALSE
  ),
  full = expand.grid(
    dgp = c("homog", "sparse50", "sparse75"),
    family = c("binomial", "poisson", "gaussian"),
    n = c(60L, 150L, 400L),
    p = c(5L, 12L, 25L),
    q = c(2L, 3L, 5L),
    stringsAsFactors = FALSE
  )
)
grid <- grids[[grid_name]]
grid <- grid[grid$q < grid$p, , drop = FALSE] # rank must be below trait count

## Seeds are spent where they decide the threshold. Only binomial fits produce
## the row at all (`.gllvmTMB_binomial_prevalence_loading_row()` returns NULL
## with no binomial rows), so binomial needs a tight healthy null; gaussian and
## poisson are carried at lower replication as transport evidence for the
## statistic itself.
seed_mult <- c(binomial = 3L, gaussian = 1L, poisson = 1L)
cells <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  ns <- n_seeds * seed_mult[[grid$family[[i]]]]
  cbind(grid[rep(i, ns), , drop = FALSE], seed = seq_len(ns))
}))
rownames(cells) <- NULL

## ------------------------------------------------------------- one fit ----

loading_sd <- function(dgp, p) {
  weak_frac <- switch(dgp, homog = 0, sparse50 = 0.5, sparse75 = 0.75)
  n_weak <- round(p * weak_frac)
  if (n_weak == 0L) {
    return(rep(0.7, p))
  }
  c(rep(0.05, n_weak), rep(1.0, p - n_weak))
}

simulate_one <- function(dgp, family, n, p, q, seed) {
  set.seed(seed * 100003L + n * 101L + p * 17L + q * 13L)
  sds <- loading_sd(dgp, p)
  Lam <- matrix(stats::rnorm(p * q, 0, rep(sds, times = q)), p, q)
  B <- switch(
    family,
    binomial = stats::rnorm(p, 0, 0.3),
    poisson = stats::rnorm(p, 1.5, 0.3),
    gaussian = stats::rnorm(p, 0, 0.3)
  )
  Z <- matrix(stats::rnorm(n * q), n, q)
  eta <- Z %*% t(Lam) + matrix(B, n, p, byrow = TRUE)
  Y <- switch(
    family,
    binomial = matrix(
      stats::rbinom(n * p, 1, stats::plogis(as.numeric(eta))),
      n,
      p
    ),
    poisson = matrix(stats::rpois(n * p, exp(as.numeric(eta))), n, p),
    gaussian = matrix(as.numeric(eta) + stats::rnorm(n * p), n, p)
  )
  colnames(Y) <- paste0("sp", seq_len(p))
  list(
    Lam = Lam,
    dat = data.frame(
      y = as.numeric(t(Y)),
      trait = factor(rep(seq_len(p), times = n)),
      site = factor(rep(seq_len(n), each = p))
    )
  )
}

na_row <- function(cell, seconds, error) {
  data.frame(
    dgp = cell$dgp, family = cell$family, n = cell$n, p = cell$p,
    q = cell$q, seed = cell$seed,
    convergence = NA_integer_, pdHess = NA, rel_frob = NA_real_,
    max_loading = NA_real_, rl_max = NA_real_, rl_argmax_loading = NA_real_,
    rl_argmax_extreme_prev = NA, rl_argmax_prev = NA_real_,
    rl_argmax_saturation = NA_real_, rl_median = NA_real_, denom = NA_real_,
    row_present = NA, row_status_now = NA_character_,
    seconds = seconds, error = error, stringsAsFactors = FALSE
  )
}

run_cell <- function(i) {
  cell <- cells[i, ]
  t0 <- proc.time()[["elapsed"]]
  res <- try(
    {
      sim <- simulate_one(cell$dgp, cell$family, cell$n, cell$p, cell$q, cell$seed)
      fam <- switch(
        cell$family,
        binomial = stats::binomial(),
        poisson = stats::poisson(),
        gaussian = stats::gaussian()
      )
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cell$q, unique = FALSE),
        data = sim$dat,
        family = fam,
        unit = "site"
      ))

      G_hat <- tcrossprod(fit$report$Lambda_B)
      G_true <- tcrossprod(sim$Lam)
      rel_frob <- norm(G_hat - G_true, "F") / norm(G_true, "F")

      ## exactly the statistic the shipped check consumes
      lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
      ok <- is.finite(lt$relative_loading)
      j <- if (any(ok)) which.max(replace(lt$relative_loading, !ok, -Inf)) else NA_integer_

      ## marginal prevalence and fitted-probability saturation of the
      ## worst-ratio trait -- the two corroborating signals the row already
      ## carries, recorded so `runaway & saturated` can be scored offline
      ## against `runaway` alone.
      prev_j <- NA_real_
      sat_j <- NA_real_
      if (!is.na(j) && identical(cell$family, "binomial")) {
        yv <- as.numeric(fit$tmb_data$y)
        tid <- as.integer(fit$tmb_data$trait_id) + 1L
        prev_j <- mean(yv[tid == j], na.rm = TRUE)
        pv <- stats::plogis(as.numeric(fit$report$eta)[tid == j])
        pv <- pv[is.finite(pv)]
        if (length(pv)) sat_j <- mean(pv >= 0.99 | pv <= 0.01)
      }

      chk <- suppressWarnings(gllvmTMB::check_gllvmTMB(fit))
      brow <- chk[chk$component == "binomial_prevalence_loading", , drop = FALSE]

      data.frame(
        dgp = cell$dgp, family = cell$family, n = cell$n, p = cell$p,
        q = cell$q, seed = cell$seed,
        convergence = fit$opt$convergence %||% NA_integer_,
        pdHess = isTRUE(fit$sd_report$pdHess),
        rel_frob = rel_frob,
        max_loading = max(lt$max_loading, na.rm = TRUE),
        rl_max = if (!is.na(j)) lt$relative_loading[j] else NA_real_,
        rl_argmax_loading = if (!is.na(j)) lt$max_loading[j] else NA_real_,
        rl_argmax_extreme_prev = is.finite(prev_j) &&
          (prev_j >= 0.9 || prev_j <= 0.1),
        rl_argmax_prev = prev_j,
        rl_argmax_saturation = sat_j,
        rl_median = stats::median(lt$relative_loading[ok]),
        denom = if (!is.na(j)) lt$max_loading[j] / lt$relative_loading[j] else NA_real_,
        row_present = nrow(brow) == 1L,
        row_status_now = if (nrow(brow) == 1L) brow$status else NA_character_,
        seconds = proc.time()[["elapsed"]] - t0,
        error = NA_character_, stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(res, "try-error")) {
    return(na_row(
      cell,
      proc.time()[["elapsed"]] - t0,
      substr(conditionMessage(attr(res, "condition")), 1, 200)
    ))
  }
  res
}

message(sprintf(
  "grid=%s cells=%d seeds=%d fits=%d cores=%d",
  grid_name, nrow(grid), n_seeds, nrow(cells), n_cores
))

out <- parallel::mclapply(seq_len(nrow(cells)), run_cell, mc.cores = n_cores)
out <- do.call(rbind, out[vapply(out, is.data.frame, logical(1))])
dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(out, out_csv, row.names = FALSE)
message(sprintf(
  "wrote %s (%d rows, %.1f min total fit time)",
  out_csv, nrow(out), sum(out$seconds, na.rm = TRUE) / 60
))
