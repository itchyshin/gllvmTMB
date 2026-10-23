## ---------------------------------------------------------------------------
## The shared simulation behind BOTH iSDM articles
##   vignettes/articles/isdm-canada-warbler.Rmd
##   vignettes/articles/isdm-spatial-precision.Rmd
##
## One simulation, so the two articles cannot drift apart.
##
## WHY THIS WAS REBUILT
## -------------------
## The previous design could not recover its own environmental slopes:
## cor(beta_hat, beta_true) = 0.67, mean|err| = 1.81 against true slopes of
## SD 0.45. The diagnostic that mattered was cor(|err|, log PO count) = +0.60 --
## error GREW with data, so the fault was systematic misspecification, not
## noise. Three separate causes were found and all three are fixed here:
##
##   (a) cor(env, access) = 0.649. The environmental covariate and the
##       accessibility covariate driving presence-only reporting bias were both
##       smooth functions of longitude, so the shared bias coefficient and the
##       per-species env slopes were confounded.  FIX: `access` is residualised
##       on `env` by construction (section 2).
##
##   (b) cor(env, latent field). The latent field was ALSO a smooth function of
##       the same two coordinates, and the model fits it with per-species
##       loadings. beta_j * env and lambda_j * u are then two rank-1 spatial
##       terms competing species by species -- classical spatial confounding.
##       This one survives removing `access` entirely, so it was the larger of
##       the two.  FIX: the field is residualised on BOTH env and access.
##
##   (c) Silent optimiser failure at large counts. Past a count magnitude the
##       fit returns convergence == 0 after ONE iteration at an objective of
##       ~1e25, with every spatial parameter still at its starting value and
##       the env slopes at |beta| ~ 20. `fit$opt$convergence` does not catch
##       this.  FIX: the intensity is set well below that boundary (section 3)
##       and `isdm_fit()` rejects any fit with <= 1 iteration (section 4).
##
## Everything is deterministic given the seeds. The landscape is FIXED: both
## articles show one landscape, so replicates vary the observation process
## only. See SIM-REBUILD-REPORT.md for the measured gate results.
## ---------------------------------------------------------------------------

## Run against the branch build when this file sits in the gllvmTMB source
## tree -- an installed release may predate the fixes these articles rely on.
if (file.exists("DESCRIPTION") &&
    identical(unname(read.dcf("DESCRIPTION")[1, "Package"]), "gllvmTMB") &&
    requireNamespace("devtools", quietly = TRUE)) {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
} else {
  suppressMessages(library(gllvmTMB))
}

## Presence-only arm is large, the structured survey arm small: integration is
## then a real trade-off rather than an average of two equals.
N_PO       <- 300L
N_SURVEY   <-  60L

## Domain: Alberta boreal, wholly inside UTM zone 11 (lon -120 .. -114), so
## add_utm_columns() never straddles a zone and the isotropic SPDE sees real
## distance rather than a 1.72x latitude artefact.
LON_RANGE  <- c(-118.5, -115.0)
LAT_RANGE  <- c(  54.0,   58.0)

## Presence-only intensity offset. Deliberately conservative: at KAPPA >= 1.5
## the optimiser hits the silent failure described in (c) above.
KAPPA_PO   <- 0.5
B_ACCESS   <- 1.2      # reporting-bias slope, presence-only arm only
MESH_CUTOFF <- 40      # km

SPECIES <- c(
  CAWA = "Canada Warbler",        OVEN = "Ovenbird",
  TEWA = "Tennessee Warbler",     BLPW = "Blackpoll Warbler",
  BBWA = "Bay-breasted Warbler",  BTNW = "Black-throated Green Warbler",
  CMWA = "Cape May Warbler",      MAWA = "Magnolia Warbler",
  SWTH = "Swainson's Thrush",     WTSP = "White-throated Sparrow",
  YRWA = "Yellow-rumped Warbler", RBNU = "Red-breasted Nuthatch"
)

## ---------------------------------------------------------------------------
## 1-2. Landscape and covariates
##
## Three deterministic surfaces, then orthogonalised. `env` is driven by
## latitude and terrain, `access` by longitude (distance to a road corridor),
## and the latent field `u` by a shorter-wavelength pattern. Orthogonalisation
## coefficients are fitted ON THE ANALYSIS CELLS and stored, so the identical
## affine map can be replayed on any prediction grid -- which is also what
## keeps an article's map from re-`scale()`ing its covariates against a
## different sample than the one the model was trained on.
## ---------------------------------------------------------------------------

.env_raw <- function(lon, lat) {
  1.00 * (lat - 56) / 1.2 +
  0.70 * sin(2.2 * (lat - 54)) +
  0.45 * cos(1.9 * (lon + 117))
}
.access_raw <- function(lon, lat) {
  exp(-((lon + 117.2) / 0.55)^2) + 0.25 * exp(-((lon + 115.6) / 0.35)^2)
}
.field_raw <- function(lon, lat) {
  sin(1.6 * (lon + 116.75)) * cos(1.15 * (lat - 56)) +
    0.5 * sin(0.8 * (lat - 56) + 1.1 * (lon + 116.75))
}

#' Build the fixed landscape.
#'
#' @return A list with `cells` (one row per sampling unit), `covariates()` (a
#'   closure mapping lon/lat to the orthogonalised covariates, for prediction
#'   grids), and `utm_warnings` (captured, for gate 5).
isdm_landscape <- function(n_po = N_PO, n_survey = N_SURVEY, seed = 4242L) {
  set.seed(seed)
  n <- n_po + n_survey
  lon <- runif(n, LON_RANGE[1], LON_RANGE[2])
  lat <- runif(n, LAT_RANGE[1], LAT_RANGE[2])

  ## Gate 5: project, capturing any zone-straddle warning rather than letting
  ## it scroll past.
  warns <- character(0)
  utm <- withCallingHandlers(
    add_utm_columns(data.frame(lon = lon, lat = lat), c("lon", "lat"),
                    utm_names = c("X", "Y"), units = "km"),
    warning = function(cond) {
      warns <<- c(warns, conditionMessage(cond)); invokeRestart("muffleWarning")
    },
    message = function(cond) invokeRestart("muffleMessage")
  )

  ## Orthogonalise: access on env, then the field on both.
  e_raw <- .env_raw(lon, lat)
  e_m <- mean(e_raw); e_s <- stats::sd(e_raw)
  env <- (e_raw - e_m) / e_s

  a_fit <- stats::lm(.access_raw(lon, lat) ~ env)
  a_res <- stats::resid(a_fit)
  a_m <- mean(a_res); a_s <- stats::sd(a_res)
  access <- (a_res - a_m) / a_s

  u_fit <- stats::lm(.field_raw(lon, lat) ~ env + access)
  u_res <- stats::resid(u_fit)
  u_m <- mean(u_res); u_s <- stats::sd(u_res)
  field <- (u_res - u_m) / u_s

  ## Replay the same affine map anywhere (e.g. a prediction grid).
  covariates <- function(lon, lat) {
    env <- (.env_raw(lon, lat) - e_m) / e_s
    ac <- stats::coef(a_fit)
    access <- ((.access_raw(lon, lat) - (ac[[1]] + ac[[2]] * env)) - a_m) / a_s
    uc <- stats::coef(u_fit)
    field <- ((.field_raw(lon, lat) -
                 (uc[[1]] + uc[[2]] * env + uc[[3]] * access)) - u_m) / u_s
    data.frame(env = env, access = access, field = field)
  }

  ## Gate 6: the two arms occupy DISJOINT locations and share no unit. This is
  ## the shape real integrated data has -- eBird rows and survey rows are never
  ## the same visit to the same place.
  arm <- rep(c("ebird", "abmi"), c(n_po, n_survey))
  cell_id <- c(sprintf("po%03d", seq_len(n_po)),
               sprintf("sv%03d", seq_len(n_survey)))

  ## Gate 4: effort varies WITHIN each arm -- eBird checklist duration and
  ## survey station effort -- and both are centred, so the offset is not a
  ## relabelling of the arm indicator.
  set.seed(seed + 1L)
  log_effort <- numeric(n)
  log_effort[arm == "ebird"] <- rnorm(n_po, 0, 0.65)
  log_effort[arm == "abmi"]  <- rnorm(n_survey, 0, 0.35)

  list(
    cells = data.frame(cell_id = cell_id, lon = lon, lat = lat,
                       X = utm$X, Y = utm$Y, env = env, access = access,
                       field = field, arm = arm, log_effort = log_effort,
                       stringsAsFactors = FALSE),
    covariates = covariates,
    utm_warnings = warns,
    utm_zones = unique(floor((lon + 180) / 6) + 1L)
  )
}

#' The species truths. Fixed once: they are a property of the fictional system,
#' not something to redraw per replicate.
isdm_species <- function(seed = 707L) {
  set.seed(seed)
  s <- length(SPECIES)
  list(code = names(SPECIES), name = unname(SPECIES),
       alpha = runif(s, -1.6, -0.6),      # abundance
       beta = rnorm(s, 0.35, 0.45),       # env slope -- THE ESTIMAND
       lambda = rnorm(s, 0.60, 0.30))     # loading on the shared field
}

## ---------------------------------------------------------------------------
## 3. The observation process
##
## Both arms observe ONE shared intensity. They differ in observation law
## (Poisson counts vs cloglog detection/non-detection), in effort, and in that
## the presence-only arm carries accessibility-driven reporting bias -- the
## reason anyone integrates a structured arm in the first place.
##
## `fuzz_km` displaces the survey arm's RECORDED coordinates without moving the
## organisms, so the covariate is read from the wrong place. That is the
## errors-in-variables mechanism the precision article measures; it is 0 here
## by default.
## ---------------------------------------------------------------------------
isdm_simulate <- function(land, spec, seed = 2026L, kappa = KAPPA_PO,
                          b_access = B_ACCESS, fuzz_km = 0) {
  cl <- land$cells
  set.seed(seed)

  ## Recorded position: exact for the presence-only arm, displaced for the
  ## survey arm. Kilometres are converted to degrees at this latitude.
  rec_lon <- cl$lon; rec_lat <- cl$lat
  if (fuzz_km > 0) {
    sv <- cl$arm == "abmi"
    km_per_deg_lat <- 111.0
    km_per_deg_lon <- 111.0 * cos(mean(cl$lat) * pi / 180)
    rec_lon[sv] <- cl$lon[sv] + rnorm(sum(sv), 0, fuzz_km / km_per_deg_lon)
    rec_lat[sv] <- cl$lat[sv] + rnorm(sum(sv), 0, fuzz_km / km_per_deg_lat)
  }
  env_recorded <- land$covariates(rec_lon, rec_lat)$env

  rows <- lapply(seq_along(spec$code), function(j) {
    ## The TRUE environment drives the response; the RECORDED one is handed to
    ## the model. With fuzz_km = 0 they are identical.
    eta <- spec$alpha[j] + spec$beta[j] * cl$env +
      spec$lambda[j] * cl$field + cl$log_effort +
      ifelse(cl$arm == "ebird", kappa + b_access * cl$access, 0)
    value <- ifelse(cl$arm == "ebird",
                    rpois(nrow(cl), exp(eta)),
                    rbinom(nrow(cl), 1, -expm1(-exp(eta))))
    data.frame(cell_id = cl$cell_id, trait = spec$code[j],
               X = cl$X, Y = cl$Y, lon = cl$lon, lat = cl$lat,
               env = env_recorded, access = cl$access,
               isdm_source = cl$arm, log_effort = cl$log_effort,
               value = value, stringsAsFactors = FALSE)
  })
  dat <- do.call(rbind, rows)
  dat$trait <- factor(dat$trait, levels = spec$code)
  dat$cell_id <- factor(dat$cell_id, levels = cl$cell_id)
  dat$isdm_source <- factor(dat$isdm_source, levels = c("ebird", "abmi"))
  ## The bias covariate acts on the presence-only arm only, which is how the
  ## thinning term is specified in the iSDM literature and what a competent
  ## analyst would write.
  dat$po_access <- dat$access * (dat$isdm_source == "ebird")
  dat
}

## ---------------------------------------------------------------------------
## 4. The model
##
## `spatial_latent(0 + trait | coords, d = 1)` is ONE shared field with
## per-species loadings, which is exactly the DGP. (The shipped article used
## `spatial_scalar()`, which fits INDEPENDENT per-trait fields and does not
## match; measured dLogLik ~ 15 on 1 df in favour of spatial_latent.)
## ---------------------------------------------------------------------------
isdm_formula <- function() {
  value ~ 0 + trait + trait:env + isdm_source + offset(log_effort) +
    po_access + spatial_latent(0 + trait | coords, d = 1)
}

isdm_fit <- function(dat, cutoff = MESH_CUTOFF) {
  mesh <- make_mesh(dat, c("X", "Y"), cutoff = cutoff)
  fam <- isdm_sources(ebird = poisson(), abmi = binomial(link = "cloglog"))
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB(
      isdm_formula(), data = dat, trait = "trait", unit = "cell_id",
      family = fam, mesh = mesh, silent = TRUE))),
    error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  ## `convergence == 0` is NOT sufficient: the documented silent failure
  ## reports success after a single iteration at an objective of ~1e25 with
  ## every spatial parameter still at its start. Reject that explicitly.
  if (!identical(as.integer(fit$opt$convergence), 0L) ||
      fit$opt$iterations <= 1L || !is.finite(fit$opt$objective)) {
    return(NULL)
  }
  fit
}

#' Pull the per-species environmental slopes out, matched to species by name
#' rather than by position.
isdm_env_slopes <- function(fit, spec) {
  b <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  nm <- fit$X_fix_names
  k <- grep("^trait.*:env$", nm)
  est <- b[k]
  names(est) <- sub("^trait(.*):env$", "\\1", nm[k])
  est[spec$code]
}

## ---------------------------------------------------------------------------
## 5. THE RECOVERY GATE
##
## Six assertions, inline, so the failure that shipped in the articles cannot
## silently return. Each returns its measured number alongside PASS/FAIL.
## ---------------------------------------------------------------------------
isdm_recovery_gate <- function(n_rep = 30L, verbose = TRUE) {
  land <- isdm_landscape()
  spec <- isdm_species()
  dat1 <- isdm_simulate(land, spec, seed = 5001L)
  cl <- land$cells
  g <- list()

  ## -- Gate 1: env orthogonal to BOTH access and the latent field ------------
  g$g1_env_access <- cor(cl$env, cl$access)
  g$g1_env_field  <- cor(cl$env, cl$field)

  ## -- Gate 4: the offset is identifiable ------------------------------------
  g$g4_effort_source <- cor(dat1$log_effort, as.numeric(dat1$isdm_source))
  g$g4_effort_levels <- tapply(cl$log_effort, cl$arm, function(z) length(unique(z)))

  ## -- Gate 5: projected coordinates, one UTM zone ---------------------------
  g$g5_n_zones <- length(land$utm_zones)
  g$g5_n_warnings <- length(land$utm_warnings)

  ## -- Gate 6: the arms share no unit ----------------------------------------
  g$g6_shared_units <- length(intersect(
    unique(as.character(dat1$cell_id[dat1$isdm_source == "ebird"])),
    unique(as.character(dat1$cell_id[dat1$isdm_source == "abmi"]))))

  ## -- Replicates for gates 2 and 3 ------------------------------------------
  out <- list(); n_fail <- 0L
  for (r in seq_len(n_rep)) {
    dat <- isdm_simulate(land, spec, seed = 5000L + r)
    fit <- isdm_fit(dat)
    if (is.null(fit)) { n_fail <- n_fail + 1L; next }
    est <- isdm_env_slopes(fit, spec)
    po <- as.numeric(tapply(dat$value[dat$isdm_source == "ebird"],
                            droplevels(dat$trait[dat$isdm_source == "ebird"]),
                            sum)[spec$code])
    out[[length(out) + 1L]] <- data.frame(
      rep = r, sp = spec$code, est = as.numeric(est), true = spec$beta, po = po)
    if (verbose) cat(sprintf("  rep %2d/%d  cor=%.3f  mean|err|=%.3f\n",
                             r, n_rep, cor(est, spec$beta),
                             mean(abs(est - spec$beta))))
  }
  res <- do.call(rbind, out)
  res$err <- res$est - res$true
  g$n_fits <- length(out); g$n_failed <- n_fail

  ## Gate 2a: rank + level recovery of the 12 slopes, per replicate.
  per_rep_cor <- tapply(seq_len(nrow(res)), res$rep,
                        function(i) cor(res$est[i], res$true[i]))
  g$g2a_mean_cor <- mean(per_rep_cor); g$g2a_min_cor <- min(per_rep_cor)

  ## Gate 2b: is the typical error the size Monte-Carlo noise alone predicts?
  ## sd_MC is the across-replicate spread of each species' estimate; under
  ## unbiasedness E|err| = sqrt(2/pi) * sd_MC, so the ratio is ~1. Systematic
  ## error inflates the numerator while leaving the denominator alone, which is
  ## precisely what a misspecification check needs.
  sd_mc <- tapply(res$est, res$sp, stats::sd)
  g$g2b_mean_abs_err <- mean(abs(res$err))
  g$g2b_mean_sd_mc <- mean(sd_mc)
  g$g2b_ratio <- g$g2b_mean_abs_err / (sqrt(2 / pi) * g$g2b_mean_sd_mc)
  g$g2b_mean_err <- mean(res$err)

  ## Gate 3: does error GROW with data? That was the signature of the failure.
  ## One correlation per replicate across the 12 species, then a one-sided
  ## t-test of the mean. Fail if significantly POSITIVE.
  per_rep_g3 <- tapply(seq_len(nrow(res)), res$rep,
                       function(i) cor(abs(res$err[i]), log(res$po[i])))
  tt <- stats::t.test(as.numeric(per_rep_g3), alternative = "greater")
  g$g3_mean_cor <- mean(per_rep_g3); g$g3_p_greater <- tt$p.value
  g$results <- res
  g
}

isdm_gate_table <- function(g) {
  row <- function(id, what, val, pass) sprintf(
    "%-4s %-52s %18s  %s", id, what, val, if (pass) "PASS" else "FAIL")
  p1 <- abs(g$g1_env_access) < 0.05 && abs(g$g1_env_field) < 0.05
  p2a <- g$g2a_mean_cor > 0.95
  p2b <- g$g2b_ratio < 3
  p3 <- g$g3_p_greater > 0.05
  p4 <- abs(g$g4_effort_source) < 0.9 && all(g$g4_effort_levels > 1)
  p5 <- g$g5_n_zones == 1L && g$g5_n_warnings == 0L
  p6 <- g$g6_shared_units == 0L
  cat(paste(c(
    row("G1a", "|cor(env, access)|  < 0.05",
        sprintf("%+.4f", g$g1_env_access), abs(g$g1_env_access) < 0.05),
    row("G1b", "|cor(env, latent field)|  < 0.05",
        sprintf("%+.4f", g$g1_env_field), abs(g$g1_env_field) < 0.05),
    row("G2a", "mean cor(beta_hat, beta_true)  > 0.95",
        sprintf("%.4f", g$g2a_mean_cor), p2a),
    row("G2b", "mean|err| / (sqrt(2/pi) * mean sd_MC)  < 3",
        sprintf("%.2f", g$g2b_ratio), p2b),
    row("G3",  "cor(|err|, log PO) not sig. positive (p > 0.05)",
        sprintf("r=%+.3f p=%.3f", g$g3_mean_cor, g$g3_p_greater), p3),
    row("G4",  "|cor(log_effort, source)|  < 0.9, effort varies",
        sprintf("%+.4f", g$g4_effort_source), p4),
    row("G5",  "one UTM zone, no straddle warning",
        sprintf("%d zone / %d warn", g$g5_n_zones, g$g5_n_warnings), p5),
    row("G6",  "arms share zero cell_id",
        sprintf("%d shared", g$g6_shared_units), p6)
  ), collapse = "\n"), "\n")
  all(c(p1, p2a, p2b, p3, p4, p5, p6))
}

## ---- Assertions: the gate cannot silently regress -------------------------
isdm_assert_gate <- function(g) {
  stopifnot(
    "G1a: env and access are not orthogonal" = abs(g$g1_env_access) < 0.05,
    "G1b: env and the latent field are not orthogonal" = abs(g$g1_env_field) < 0.05,
    "G2a: slope recovery correlation below 0.95" = g$g2a_mean_cor > 0.95,
    "G2b: mean|err| exceeds 3x Monte-Carlo SE" = g$g2b_ratio < 3,
    "G3: error grows significantly with PO count" = g$g3_p_greater > 0.05,
    "G4: offset confounded with the source indicator" =
      abs(g$g4_effort_source) < 0.9 && all(g$g4_effort_levels > 1),
    "G5: coordinates straddle a UTM zone" =
      g$g5_n_zones == 1L && g$g5_n_warnings == 0L,
    "G6: the two arms share a cell_id" = g$g6_shared_units == 0L
  )
  invisible(TRUE)
}

## ---------------------------------------------------------------------------
if (sys.nframe() == 0L) {
  n_rep <- as.integer(Sys.getenv("ISDM_NREP", "30"))
  cat("Running the shared iSDM simulation and its recovery gate,",
      n_rep, "replicates.\n\n")
  g <- isdm_recovery_gate(n_rep = n_rep)
  cat("\n", strrep("-", 80), "\nRECOVERY GATE\n", strrep("-", 80), "\n", sep = "")
  ok <- isdm_gate_table(g)
  cat(strrep("-", 80), "\n", sep = "")
  cat(sprintf("fits: %d ok / %d failed | mean err %+.4f | mean|err| %.4f | mean sd_MC %.4f\n",
              g$n_fits, g$n_failed, g$g2b_mean_err, g$g2b_mean_abs_err,
              g$g2b_mean_sd_mc))
  cat(sprintf("true slope SD %.3f | min per-replicate cor %.4f\n",
              stats::sd(isdm_species()$beta), g$g2a_min_cor))
  cat("VERDICT:", if (ok) "GATE PASSED" else "GATE FAILED", "\n")
  saveRDS(g, "dev/isdm-precision/precision-sim-gate.rds")
  isdm_assert_gate(g)
}
