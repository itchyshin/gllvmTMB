## ---------------------------------------------------------------------------
## generate-cawa12.R -- the 12-species integrated SDM simulator
##
## A TWO-ARM integrated SDM over a boreal songbird community:
##
##   * an OPPORTUNISTIC arm ("ebird"): Poisson counts, 300 cells, effort
##     varying within the arm (checklist duration), carrying an extra
##     intensity offset `kappa` that makes it the high-count arm;
##   * a STRUCTURED arm ("abmi"): binomial/cloglog detection-non-detection,
##     60 stations, its own within-arm effort variation.
##
## The two arms sit at DISJOINT locations -- no cell_id is shared -- which is
## the shape real integrated data has. Coordinates are projected to UTM
## (km) and the domain sits wholly inside zone 11, so the isotropic SPDE
## sees real distance.
##
## The truth is a RANK-2 shared spatial field with per-species loadings:
##
##   eta_ij = alpha_j + beta_j env_i + lam1_j f1_i + lam2_j f2_i
##            + log_effort_i + kappa 1{arm_i = opportunistic}
##
## BOTH field axes are residualised against `env` at the sampled locations,
## and f2 against f1. Without that residualisation beta_j env and lam_j f
## are two competing rank-1 spatial terms (spatial confounding) and the
## measured consequence is severe: env slopes driven to about +21 against a
## true mean near +1.3 (see the note in precision-sim.R, causes (a)-(b)).
##
## Entry point: sim_cawa12(seed) -> long-format data frame, with the truth
## attached as attr(, "truth") and the landscape as attr(, "cells").
##
## The LANDSCAPE is fixed (locations, env, both field axes, effort, species
## truths); `seed` varies the OBSERVATION process only, so replicates are
## replicate observations of one system and any article map is stable.
## ---------------------------------------------------------------------------

if (file.exists("DESCRIPTION") &&
    identical(unname(read.dcf("DESCRIPTION")[1, "Package"]), "gllvmTMB") &&
    requireNamespace("devtools", quietly = TRUE)) {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
} else if (dir.exists("/private/tmp/gllvmtmb-1132") &&
           requireNamespace("devtools", quietly = TRUE)) {
  suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-1132", quiet = TRUE))
} else {
  suppressMessages(library(gllvmTMB))
}

N_PO        <- 300L      # opportunistic cells
N_SURVEY    <-  60L      # structured stations
LON_RANGE   <- c(-118.5, -115.0)
LAT_RANGE   <- c(  54.0,   58.0)
MESH_CUTOFF <- 40        # km  -- see cawa12-probe.rds for the node count
## Opportunistic intensity offset. MEASURED envelope (cawa12-probe.rds,
## 3 seeds per rung, 12 seeds at each replicate rung):
##
##   kappa   mean count   fit                    cor(beta_hat, beta_true)
##   0.5      1.07        healthy 12/12          0.927 (sd 0.061)
##   1.0      1.77        healthy 12/12          0.936 (sd 0.026)   <- CHOSEN
##   1.5      2.92        healthy 12/12          0.888 (sd 0.031)
##   2.3      6.46        healthy 12/12          0.800 (sd 0.045)
##   2.4      7.17        FAILS 3/3 (13-14 iterations, objective ~2e14)
##   3.0     12.96        FAILS 3/3 -- issue #1167: convergence == 0 after
##                        ONE iteration at objective ~6e24
##   4.5+                 hard error, "All 1 restarts failed."
##
## So the numerical ceiling is kappa 2.3 and the STATISTICAL one is lower:
## recovery is already decaying two rungs before the optimiser breaks.
KAPPA_PO    <- 1.0       # chosen operating point

SPECIES <- c(
  CAWA = "Canada Warbler",        OVEN = "Ovenbird",
  TEWA = "Tennessee Warbler",     BLPW = "Blackpoll Warbler",
  BBWA = "Bay-breasted Warbler",  BTNW = "Black-throated Green Warbler",
  CMWA = "Cape May Warbler",      MAWA = "Magnolia Warbler",
  SWTH = "Swainson's Thrush",     WTSP = "White-throated Sparrow",
  YRWA = "Yellow-rumped Warbler", RBNU = "Red-breasted Nuthatch"
)

## -- deterministic surfaces -------------------------------------------------
.env_raw <- function(lon, lat) {
  1.00 * (lat - 56) / 1.2 +
    0.70 * sin(2.2 * (lat - 54)) +
    0.45 * cos(1.9 * (lon + 117))
}
## Two field axes at different wavelengths and orientations.
.f1_raw <- function(lon, lat) {
  sin(1.6 * (lon + 116.75)) * cos(1.15 * (lat - 56)) +
    0.50 * sin(0.8 * (lat - 56) + 1.1 * (lon + 116.75))
}
.f2_raw <- function(lon, lat) {
  cos(2.3 * (lon + 116.75) - 0.6 * (lat - 56)) -
    0.40 * sin(1.7 * (lat - 55.4))
}

#' The fixed landscape: locations, covariate, both true field axes, effort.
cawa12_landscape <- function(n_po = N_PO, n_survey = N_SURVEY, seed = 4242L) {
  set.seed(seed)
  n <- n_po + n_survey
  lon <- runif(n, LON_RANGE[1], LON_RANGE[2])
  lat <- runif(n, LAT_RANGE[1], LAT_RANGE[2])

  warns <- character(0)
  utm <- withCallingHandlers(
    add_utm_columns(data.frame(lon = lon, lat = lat), c("lon", "lat"),
                    utm_names = c("X", "Y"), units = "km"),
    warning = function(cond) {
      warns <<- c(warns, conditionMessage(cond)); invokeRestart("muffleWarning")
    },
    message = function(cond) invokeRestart("muffleMessage")
  )

  ## env, standardised.
  e_raw <- .env_raw(lon, lat)
  env <- as.numeric(scale(e_raw))

  ## RESIDUALISATION, at the sampled locations:
  ##   f1 on env; f2 on env and f1. The rank-2 latent subspace is then
  ##   orthogonal to the covariate the model also estimates a slope for.
  f1_fit <- stats::lm(.f1_raw(lon, lat) ~ env)
  f1 <- as.numeric(scale(stats::resid(f1_fit)))
  f2_fit <- stats::lm(.f2_raw(lon, lat) ~ env + f1)
  f2 <- as.numeric(scale(stats::resid(f2_fit)))

  ## Arms: disjoint locations, no shared unit.
  arm <- rep(c("ebird", "abmi"), c(n_po, n_survey))
  cell_id <- c(sprintf("po%03d", seq_len(n_po)),
               sprintf("sv%03d", seq_len(n_survey)))

  ## Effort varies WITHIN each arm, and is centred, so the offset is not a
  ## relabelling of the arm indicator.
  set.seed(seed + 1L)
  log_effort <- numeric(n)
  log_effort[arm == "ebird"] <- rnorm(n_po, 0, 0.65)
  log_effort[arm == "abmi"]  <- rnorm(n_survey, 0, 0.35)

  list(
    cells = data.frame(
      cell_id = cell_id, lon = lon, lat = lat, X = utm$X, Y = utm$Y,
      env = env, f1 = f1, f2 = f2, arm = arm, log_effort = log_effort,
      stringsAsFactors = FALSE),
    utm_warnings = warns,
    utm_zones = unique(floor((lon + 180) / 6) + 1L)
  )
}

#' Species truths: fixed once, a property of the fictional community.
cawa12_species <- function(seed = 707L) {
  set.seed(seed)
  s <- length(SPECIES)
  list(
    code   = names(SPECIES),
    name   = unname(SPECIES),
    alpha  = runif(s, -1.6, -0.6),     # abundance
    beta   = rnorm(s, 0.35, 0.45),     # env slope -- THE ESTIMAND
    lam1   = rnorm(s, 0.60, 0.30),     # loading on field axis 1
    lam2   = rnorm(s, 0.00, 0.35)      # loading on field axis 2
  )
}

#' Simulate one replicate observation of the fixed landscape.
#'
#' @param seed Observation-process seed.
#' @param kappa Opportunistic-arm intensity offset (the swept quantity).
#' @return Long-format data frame, one row per cell x species.
sim_cawa12 <- function(seed = 1L, kappa = KAPPA_PO,
                       land = cawa12_landscape(), spec = cawa12_species()) {
  ## FORCE the defaults BEFORE set.seed(seed). R default arguments are lazy, so
  ## `spec = cawa12_species()` would otherwise be evaluated inside the lapply
  ## below -- AFTER set.seed(seed) -- and cawa12_species() itself calls
  ## set.seed(707L). That reseeds the stream and makes `seed` INERT: measured,
  ## sim_cawa12(1), (2) and (3) returned byte-identical data (sum 6625 every
  ## time), so any "N replicate seeds" result computed with default args was N
  ## copies of ONE dataset. `land` has the same shape and was harmless only by
  ## accident of evaluation order. Forcing both makes every caller safe,
  ## including one that never passes them.
  force(land)
  force(spec)
  cl <- land$cells
  set.seed(seed)
  rows <- lapply(seq_along(spec$code), function(j) {
    eta <- spec$alpha[j] + spec$beta[j] * cl$env +
      spec$lam1[j] * cl$f1 + spec$lam2[j] * cl$f2 +
      cl$log_effort + ifelse(cl$arm == "ebird", kappa, 0)
    value <- ifelse(cl$arm == "ebird",
                    rpois(nrow(cl), exp(eta)),
                    rbinom(nrow(cl), 1, -expm1(-exp(eta))))
    data.frame(cell_id = cl$cell_id, trait = spec$code[j],
               X = cl$X, Y = cl$Y, lon = cl$lon, lat = cl$lat,
               env = cl$env, isdm_source = cl$arm,
               log_effort = cl$log_effort, value = value,
               stringsAsFactors = FALSE)
  })
  dat <- do.call(rbind, rows)
  dat$trait <- factor(dat$trait, levels = spec$code)
  dat$cell_id <- factor(dat$cell_id, levels = cl$cell_id)
  dat$isdm_source <- factor(dat$isdm_source, levels = c("ebird", "abmi"))
  attr(dat, "truth") <- spec
  attr(dat, "cells") <- cl
  attr(dat, "kappa") <- kappa
  dat
}

## -- the model --------------------------------------------------------------
## d = 2 matches the rank-2 DGP: one shared field pair with per-species
## loadings.
cawa12_formula <- function() {
  value ~ 0 + trait + trait:env + isdm_source + offset(log_effort) +
    spatial_latent(0 + trait | coords, d = 2)
}

cawa12_mesh <- function(dat, cutoff = MESH_CUTOFF) {
  make_mesh(dat, c("X", "Y"), cutoff = cutoff)
}

#' Fit, REJECTING the issue #1167 silent failure.
#'
#' Past a count magnitude the SPDE fit returns convergence == 0 after ONE
#' iteration at an objective of ~1e21, every spatial parameter still at its
#' start. `convergence == 0` does not catch it; the iteration count does.
#'
#' @return list(fit, ok, reason, iterations, objective, secs)
cawa12_fit <- function(dat, cutoff = MESH_CUTOFF) {
  mesh <- cawa12_mesh(dat, cutoff)
  fam <- isdm_sources(ebird = poisson(), abmi = binomial(link = "cloglog"))
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      cawa12_formula(), data = dat, trait = "trait", unit = "cell_id",
      family = fam, mesh = mesh, silent = TRUE))),
    error = function(e) structure(list(msg = conditionMessage(e)),
                                  class = "cawa12_error"))
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "cawa12_error")) {
    return(list(fit = NULL, ok = FALSE, reason = paste("error:", fit$msg),
                iterations = NA_integer_, objective = NA_real_, secs = secs))
  }
  it <- tryCatch(as.integer(fit$opt$iterations), error = function(e) NA_integer_)
  ob <- tryCatch(as.numeric(fit$opt$objective), error = function(e) NA_real_)
  cv <- tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_)
  reason <- NA_character_
  ok <- TRUE
  if (!identical(cv, 0L)) { ok <- FALSE; reason <- "convergence != 0" }
  else if (is.na(it) || it <= 1L) { ok <- FALSE; reason <- "iterations <= 1 (#1167 silent failure)" }
  else if (!is.finite(ob)) { ok <- FALSE; reason <- "non-finite objective" }
  list(fit = if (ok) fit else NULL, ok = ok, reason = reason,
       iterations = it, objective = ob, convergence = cv, secs = secs)
}

#' Per-species env slopes, matched to species by NAME.
cawa12_env_slopes <- function(fit, spec = cawa12_species()) {
  b <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  nm <- fit$X_fix_names
  k <- grep("^trait.*:env$", nm)
  est <- b[k]
  names(est) <- sub("^trait(.*):env$", "\\1", nm[k])
  est[spec$code]
}
