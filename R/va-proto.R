# R/va-proto.R -- EXPERIMENTAL, STANDALONE variational-approximation (VA)
# proof-of-mechanism harness for Phase 1 of Design 72
# (docs/design/72-variational-approximation-feasibility.md).
#
# NONE of this is wired into the public gllvmTMB() API. It is an internal
# scaffold whose only consumer is the Phase-1 benchmark
# (tests/va-benchmark/run-va-benchmark.R) and its CI workflow. The VA TMB
# template lives at inst/tmb/gllvmTMB_va.cpp and is compiled into its OWN DLL
# with TMB::compile(); the proven Laplace engine (src/gllvmTMB.cpp) is never
# touched, recompiled, or linked against here.
#
# Model: random intercept + random slope per group with an UNSTRUCTURED 2x2
# prior covariance Sigma -- the "dep"-style full-unstructured covariance whose
# inner Laplace Hessian goes non-PD for non-Gaussian families at small n
# (PHY-18 / SPA-10). The VA path replaces the Laplace inner mode-find with a
# single smooth mean-field-diagonal Gaussian ELBO.

# Compile and load the standalone VA DLL. Returns the DLL base name to pass
# to TMB::MakeADFun(DLL=). Compiles only if the shared object is missing or
# older than the source. Kept deliberately filesystem-local so a CI runner
# can compile once and reuse.
.va_compile <- function(src = NULL, verbose = TRUE) {
  if (is.null(src)) {
    # Prefer the installed location; fall back to the source tree (devtools).
    src <- system.file("tmb", "gllvmTMB_va.cpp", package = "gllvmTMB")
    if (!nzchar(src) || !file.exists(src)) {
      src <- file.path("inst", "tmb", "gllvmTMB_va.cpp")
    }
  }
  if (!file.exists(src)) {
    stop("VA template not found at: ", src)
  }
  dll_base <- tools::file_path_sans_ext(basename(src))
  dir <- dirname(src)
  so <- file.path(dir, paste0(dll_base, .Platform$dynlib.ext))
  needs_compile <- !file.exists(so) ||
    file.info(src)$mtime > file.info(so)$mtime
  if (needs_compile) {
    if (verbose) message("Compiling VA template: ", src)
    # framework = "TMBad" matches the package Makevars (-DTMBAD_FRAMEWORK);
    # TMB::compile adds the define itself for this framework.
    TMB::compile(src, framework = "TMBad")
  }
  # Unload then load to pick up a fresh build.
  try(dyn.unload(so), silent = TRUE)
  dyn.load(so)
  dll_base
}

# Build a VA MakeADFun object for the random-intercept + random-slope model.
#   data : data.frame with columns y, x, group (group: integer/factor)
#   family : "gaussian" or "poisson"
.va_make_adfun <- function(data, family = c("gaussian", "poisson"),
                           dll_base = "gllvmTMB_va") {
  family <- match.arg(family)
  fam_id <- if (family == "gaussian") 0L else 1L

  grp <- as.integer(as.factor(data$group))
  n_group <- length(unique(grp))
  d <- 2L  # intercept + slope

  X <- cbind(1, data$x)                 # n x 2 fixed-effect design
  Z <- cbind(1, data$x)                 # n x 2 latent design within a group

  tmb_data <- list(
    y = as.numeric(data$y),
    X = X,
    group = grp - 1L,                   # 0-based for C++
    Z = Z,
    n_group = n_group,
    d = d,
    family = fam_id
  )

  parameters <- list(
    beta = rep(0, ncol(X)),
    log_phi = 0,
    m = matrix(0, n_group, d),
    log_s = matrix(log(0.5), n_group, d),   # modest non-zero start
    L_diag = rep(log(0.5), d),              # Sigma diag start ~ 0.25
    L_offdiag = rep(0, d * (d - 1L) / 2L)
  )

  # Poisson has no dispersion; map log_phi out via factor(NA).
  map <- list()
  if (family == "poisson") {
    map$log_phi <- factor(NA)
  }

  TMB::MakeADFun(
    data = tmb_data,
    parameters = parameters,
    map = map,
    DLL = dll_base,
    silent = TRUE
    # NB: NO random= argument -- the variational params m/log_s are ORDINARY
    # parameters. This is the whole point: no inner Laplace mode-find, no
    # inner Hessian to go non-PD.
  )
}

# Fit the VA model. Returns a list with beta-hat, the prior variance
# components (sd_intercept, sd_slope, corr), convergence info, and the final
# negative ELBO.
fit_va <- function(data, family = c("gaussian", "poisson"),
                   dll_base = "gllvmTMB_va", verbose = FALSE) {
  family <- match.arg(family)
  obj <- .va_make_adfun(data, family = family, dll_base = dll_base)

  opt <- tryCatch(
    stats::nlminb(obj$par, obj$fn, obj$gr,
                  control = list(eval.max = 2000, iter.max = 2000)),
    error = function(e) list(convergence = 99L, message = conditionMessage(e),
                             objective = NA_real_, par = obj$par)
  )

  rep <- tryCatch(obj$report(opt$par), error = function(e) NULL)

  beta_hat <- as.numeric(opt$par[names(opt$par) == "beta"])
  sd_prior <- if (!is.null(rep)) as.numeric(rep$sd_prior) else c(NA, NA)
  corr01 <- if (!is.null(rep) && !is.null(rep$corr01)) as.numeric(rep$corr01) else NA_real_

  # nlminb convergence == 0 is success. Also guard against NA objective.
  converged <- isTRUE(opt$convergence == 0L) && is.finite(opt$objective)

  list(
    method = "VA",
    family = family,
    converged = converged,
    convergence_code = opt$convergence,
    message = if (!is.null(opt$message)) opt$message else NA_character_,
    neg_elbo = opt$objective,
    beta = beta_hat,
    sd_intercept = sd_prior[1],
    sd_slope = sd_prior[2],
    corr = corr01,
    obj = if (verbose) obj else NULL,
    opt = if (verbose) opt else NULL
  )
}

# ---------------------------------------------------------------------------
# Minimal Laplace comparator (inst/tmb/gllvmTMB_la_min.cpp). SAME model, SAME
# data; the latent u goes in random= so TMB applies the Laplace approximation
# (inner mode-find + inner Hessian). This is the path we expect to go non-PD
# on the small-n Poisson random-slope fixture.
# ---------------------------------------------------------------------------

.la_make_adfun <- function(data, family = c("gaussian", "poisson"),
                           dll_base = "gllvmTMB_la_min") {
  family <- match.arg(family)
  fam_id <- if (family == "gaussian") 0L else 1L

  grp <- as.integer(as.factor(data$group))
  n_group <- length(unique(grp))
  d <- 2L

  X <- cbind(1, data$x)
  Z <- cbind(1, data$x)

  tmb_data <- list(
    y = as.numeric(data$y), X = X, group = grp - 1L, Z = Z,
    n_group = n_group, d = d, family = fam_id
  )
  parameters <- list(
    beta = rep(0, ncol(X)),
    log_phi = 0,
    L_diag = rep(log(0.5), d),
    L_offdiag = rep(0, d * (d - 1L) / 2L),
    u = matrix(0, n_group, d)
  )
  map <- list()
  if (family == "poisson") map$log_phi <- factor(NA)

  TMB::MakeADFun(
    data = tmb_data, parameters = parameters, map = map,
    random = "u", DLL = dll_base, silent = TRUE
  )
}

# Fit the Laplace comparator. Returns beta-hat, prior variance components,
# convergence info, AND a PD-Hessian flag (the decisive LA failure signal:
# the outer sdreport / inner Hessian is non-positive-definite).
fit_la <- function(data, family = c("gaussian", "poisson"),
                   dll_base = "gllvmTMB_la_min", verbose = FALSE) {
  family <- match.arg(family)

  # Stage 1: build + optimise. These must succeed for ANY estimate to exist.
  # sdreport is DELIBERATELY excluded here: on a non-PD inner Hessian sdreport
  # raises / returns SE=NA, but the optimiser still returns a valid MODE. We
  # want the LA POINT estimates of (sd0, sd1, rho) at that mode regardless.
  res <- tryCatch({
    obj <- .la_make_adfun(data, family = family, dll_base = dll_base)
    opt <- stats::nlminb(obj$par, obj$fn, obj$gr,
                         control = list(eval.max = 2000, iter.max = 2000))
    list(obj = obj, opt = opt, err = NA_character_)
  }, error = function(e) {
    list(obj = NULL, opt = NULL, err = conditionMessage(e))
  })

  if (!is.na(res$err)) {
    return(list(
      method = "LA", family = family, converged = FALSE, pd_hess = FALSE,
      convergence_code = 99L, message = res$err, nll = NA_real_,
      beta = c(NA, NA), sd_intercept = NA_real_, sd_slope = NA_real_,
      corr = NA_real_
    ))
  }

  obj <- res$obj
  opt <- res$opt
  converged <- isTRUE(opt$convergence == 0L) && is.finite(opt$objective)

  # Stage 2: extract the LA POINT ESTIMATES the SAME way VA does -- from
  # obj$report() at the optimised mode. For a Laplace object the random u live
  # in obj$env$last.par.best; report() needs the FULL parameter vector, not the
  # fixed-only opt$par. We re-evaluate the joint NLL at the optimum first so
  # last.par.best is the converged mode, then report() off it.
  invisible(tryCatch(obj$fn(opt$par), error = function(e) NULL))
  full_par <- tryCatch(obj$env$last.par.best, error = function(e) NULL)
  rep <- NULL
  if (!is.null(full_par)) {
    rep <- tryCatch(obj$report(full_par), error = function(e) NULL)
  }
  if (is.null(rep)) {
    # Last resort: report() with the fixed-effect par vector.
    rep <- tryCatch(obj$report(opt$par), error = function(e) NULL)
  }
  beta_hat <- as.numeric(opt$par[names(opt$par) == "beta"])
  sd_prior <- if (!is.null(rep) && !is.null(rep$sd_prior)) {
    as.numeric(rep$sd_prior)
  } else {
    c(NA_real_, NA_real_)
  }
  corr01 <- if (!is.null(rep) && !is.null(rep$corr01)) {
    as.numeric(rep$corr01)
  } else {
    NA_real_
  }

  # Stage 3: sdreport, guarded. Its ONLY job here is the pdHess flag (the
  # decisive LA failure signal). A non-PD Hessian must NOT wipe the point
  # estimates extracted above. SEs may be NA; we do not use them.
  sdr <- tryCatch(TMB::sdreport(obj), error = function(e) NULL)
  pd_hess <- isTRUE(!is.null(sdr) && isTRUE(sdr$pdHess))

  list(
    method = "LA", family = family,
    converged = converged, pd_hess = pd_hess,
    convergence_code = opt$convergence,
    message = if (!is.null(opt$message)) opt$message else NA_character_,
    nll = opt$objective,
    beta = beta_hat,
    sd_intercept = sd_prior[1], sd_slope = sd_prior[2], corr = corr01,
    obj = if (verbose) obj else NULL,
    opt = if (verbose) opt else NULL,
    sdr = if (verbose) sdr else NULL
  )
}

# Simulate the random-intercept + random-slope fixture with KNOWN truth.
#   n_group : number of groups (small -> drives the LA non-PD skip)
#   n_per   : observations per group
#   sd0,sd1 : true prior SDs (intercept, slope); rho their correlation
#   beta0,beta1 : true fixed effects
# Returns list(data = data.frame(y, x, group), truth = list(...)).
simulate_va_fixture <- function(n_group = 8L, n_per = 4L,
                                sd0 = 0.8, sd1 = 0.8, rho = 0.3,
                                beta0 = 0.5, beta1 = 0.4,
                                family = c("gaussian", "poisson"),
                                gaussian_sd = 0.5, seed = 1L) {
  family <- match.arg(family)
  set.seed(seed)
  Sigma <- matrix(c(sd0^2, rho * sd0 * sd1,
                    rho * sd0 * sd1, sd1^2), 2, 2)
  Lc <- chol(Sigma)  # upper
  G <- n_group
  u <- matrix(rnorm(G * 2), G, 2) %*% Lc  # G x 2, rows ~ N(0, Sigma)

  group <- rep(seq_len(G), each = n_per)
  n <- length(group)
  x <- rnorm(n)
  eta <- beta0 + beta1 * x + u[group, 1] + u[group, 2] * x
  if (family == "gaussian") {
    y <- rnorm(n, eta, gaussian_sd)
  } else {
    y <- rpois(n, exp(eta))
  }
  list(
    data = data.frame(y = y, x = x, group = group),
    truth = list(beta0 = beta0, beta1 = beta1,
                 sd_intercept = sd0, sd_slope = sd1, corr = rho,
                 family = family)
  )
}
