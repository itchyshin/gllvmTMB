## ---------------------------------------------------------------------------
## Spatial-precision mismatch in an integrated SDM.
##
## Motivating fact (measured, dev-log 2026-08-17 flagship-candidate check):
## ABMI publishes survey locations fuzzed to ~5.5 km, while GBIF/eBird
## presence-only records carry precise coordinates. An integrated model fuses
## the two as if both located their observations equally well.
##
## The claim under test: coordinate fuzzing on ONE arm is covariate
## measurement error in disguise. The environmental covariate is read at the
## RECORDED location, so a fuzzed arm reads the wrong covariate value, and a
## classical errors-in-variables attenuation follows -- on the very slope the
## SDM exists to estimate. If so, integrating a fuzzed arm with a precise one
## should drag the joint estimate AWAY from the truth the precise arm alone
## recovers: more data, worse answer.
##
## This script measures that rather than asserting it.
## ---------------------------------------------------------------------------

suppressMessages(library(gllvmTMB))

## A smooth environmental surface on the unit square. `ell` is its correlation
## length: fuzzing matters relative to THIS, not in absolute km.
env_surface <- function(n_side, ell = 0.25, seed = 1) {
  set.seed(seed)
  gx <- seq(0, 1, length.out = n_side)
  g <- expand.grid(lon = gx, lat = gx)
  d <- as.matrix(dist(g))
  S <- exp(-d / ell)
  z <- as.numeric(t(chol(S + diag(1e-6, nrow(S)))) %*% rnorm(nrow(g)))
  g$env <- as.numeric(scale(z))
  g
}

## Read the covariate at an arbitrary location (nearest grid node).
read_env <- function(grid, lon, lat) {
  idx <- max.col(-(outer(lon, grid$lon, "-")^2 + outer(lat, grid$lat, "-")^2))
  grid$env[idx]
}

#' One replicate.
#'
#' Both arms see the SAME truth: eta = alpha_arm + beta * env(TRUE location).
#' They differ only in how well the recorded coordinate matches the true one.
#' `fuzz` is the sd of the positional error applied to the survey arm, in
#' units of the environmental correlation length.
sim_once <- function(fuzz, n_site = 220L, beta = 0.9, ell = 0.25,
                     n_side = 26L, seed = 1) {
  set.seed(seed)
  grid <- env_surface(n_side, ell = ell, seed = seed)

  ## True sampling locations, shared design for both arms.
  lon <- runif(n_site); lat <- runif(n_site)
  env_true <- read_env(grid, lon, lat)

  ## Presence-only arm: precise coordinates.
  ## Survey arm: the SAME sites, but the recorded coordinate is displaced.
  lon_f <- pmin(pmax(lon + rnorm(n_site, 0, fuzz * ell), 0), 1)
  lat_f <- pmin(pmax(lat + rnorm(n_site, 0, fuzz * ell), 0), 1)
  env_recorded_survey <- read_env(grid, lon_f, lat_f)

  ## Responses are generated from the TRUE environment for both arms --
  ## the organism responds to where it actually is, not to where we wrote down.
  ## Two species so the trait factor is non-degenerate (a one-level factor
  ## cannot take contrasts), and so this is a joint model, as an SDM would be.
  sp_names <- c("sp1", "sp2")
  alpha <- c(-0.3, 0.1)
  mk <- function(env_recorded, src) {
    do.call(rbind, lapply(seq_along(sp_names), function(j) {
      eta <- alpha[j] + beta * env_true          # TRUE env drives the counts
      data.frame(
        cell_id = factor(paste0(src, "_", seq_len(n_site))),
        trait   = sp_names[j],
        value   = rpois(n_site, exp(eta)),
        env     = env_recorded,                  # RECORDED env enters the model
        src     = src,
        stringsAsFactors = FALSE
      )
    }))
  }
  ## The analyst's data: the precise arm carries env at its true location;
  ## the fuzzed arm carries env read at its RECORDED location.
  d_po  <- mk(env_true,            "po")
  d_srv <- mk(env_recorded_survey, "survey")

  fit_one <- function(dat) {
    dat$trait <- factor(dat$trait, levels = sp_names)
    dat$cell_id <- factor(dat$cell_id)
    ## Only include the source term when both arms are present; a one-level
    ## factor has no contrasts.
    rhs <- if (length(unique(dat$src)) > 1L) {
      dat$src <- factor(dat$src)
      value ~ 0 + trait + trait:env + src
    } else {
      value ~ 0 + trait + trait:env
    }
    f <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(
      rhs, data = dat, trait = "trait", unit = "cell_id",
      family = poisson(), silent = TRUE))), error = function(e) NULL)
    if (is.null(f) || !identical(as.integer(f$opt$convergence), 0L)) {
      return(NA_real_)
    }
    b <- f$opt$par[names(f$opt$par) == "b_fix"]
    ## Average the two species' env slopes: both share the same true beta.
    mean(unname(b[grep(":env$", f$X_fix_names)]))
  }

  ## Three analyses of the same world.
  c(precise_only = fit_one(d_po),
    fuzzed_only  = fit_one(d_srv),
    integrated   = fit_one(rbind(d_po, d_srv)))
}

run_grid <- function(fuzzes = c(0, 0.25, 0.5, 1.0), n_rep = 20L, beta = 0.9) {
  out <- list()
  for (f in fuzzes) {
    for (r in seq_len(n_rep)) {
      v <- sim_once(fuzz = f, beta = beta, seed = 1000L + r)
      out[[length(out) + 1L]] <- data.frame(fuzz = f, rep = r,
                                            arm = names(v), beta_hat = as.numeric(v),
                                            stringsAsFactors = FALSE)
    }
    cat("fuzz", f, "done\n")
  }
  do.call(rbind, out)
}

if (sys.nframe() == 0L) {
  BETA <- 0.9
  res <- run_grid(n_rep = as.integer(Sys.getenv("PREC_NREP", "20")), beta = BETA)
  agg <- aggregate(beta_hat ~ fuzz + arm, res,
                   function(z) round(c(mean = mean(z), sd = sd(z)), 4))
  agg <- do.call(data.frame, agg)
  agg$bias <- round(agg$beta_hat.mean - BETA, 4)
  agg$pct_attenuation <- round(100 * (1 - agg$beta_hat.mean / BETA), 1)
  print(agg[order(agg$arm, agg$fuzz), ], row.names = FALSE)
  saveRDS(res, "dev/isdm-precision/precision-sim-results.rds")
  cat("\ntrue beta =", BETA, "\n")
}
