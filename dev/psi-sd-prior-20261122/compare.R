#!/usr/bin/env Rscript
# Fixed-point verification only. Native mode builds a public-route objective;
# no convergence, recovery, or uncertainty claim follows from these checks.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L, args[1L] %in% c("pure", "native"))
mode <- args[1L]
smoke <- length(args) >= 4L && identical(args[4L], "smoke")
oracle_dir <- normalizePath(args[2L], mustWork = TRUE)
out_dir <- if (length(args) >= 3L) args[3L] else tempfile("psi-sd-receipt-")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Python reads JSON only; this exporter avoids loading R packages in pure mode.
py <- paste(
  "import json,sys,math",
  "def r(x):",
  " if x is None: return 'NULL'",
  " if isinstance(x,bool): return 'TRUE' if x else 'FALSE'",
  " if isinstance(x,str): return json.dumps(x)",
  " if isinstance(x,(int,float)): return repr(x) if math.isfinite(x) else ('Inf' if x>0 else '-Inf')",
  " if isinstance(x,dict): return 'setNames(list('+','.join(r(v) for v in x.values())+'),c('+','.join(r(k) for k in x)+'))'",
  " return 'list('+','.join(r(v) for v in x)+')'",
  "print(r({k:json.load(open(sys.argv[1]+'/'+k+'.json')) for k in ['fixture','expected']}))",
  sep = "\n"
)
data_file <- tempfile(fileext = ".R")
stopifnot(system2("python3", c("-c", shQuote(py), shQuote(oracle_dir)),
                     stdout = data_file) == 0L)
oracle <- dget(data_file)
unlink(data_file)
f <- oracle$fixture
if (smoke) f$points <- f$points[1L]
expected <- setNames(oracle$expected, vapply(oracle$expected, `[[`, "", "name"))
vec <- function(x) unlist(x, use.names = FALSE)
mat <- function(x) do.call(rbind, lapply(x, vec))
traits <- vec(f$traits)
sites <- vec(f$sites)
kernel_names <- names(f$kernels)
kernels <- lapply(f$kernels, mat)
response <- vec(f$response)
prior <- do.call(rbind, lapply(f$priors, function(x) {
  data.frame(kernel = x$kernel, trait = x$trait, shape = x$shape, rate = x$rate)
}))
theta_names <- vec(f$parameter_names)
tol <- f$adapter_tolerances
checks <- list()
check <- function(label, actual, target, atol, rtol = 0, required = TRUE) {
  actual <- as.numeric(actual); target <- as.numeric(target)
  ok <- length(actual) == length(target) &&
    all(is.finite(actual) & is.finite(target)) &&
    all(abs(actual - target) <= atol + rtol * abs(target))
  err <- if (length(actual) == length(target)) max(abs(actual - target)) else Inf
  checks[[length(checks) + 1L]] <<- data.frame(
    label = label, passed = ok, required = required, max_abs_error = err
  )
  invisible(ok)
}
fd_gradient <- function(fn, p) {
  vapply(seq_along(p), function(i) {
    h <- 1e-5 * max(1, abs(p[i])); hi <- lo <- p
    hi[i] <- hi[i] + h; lo[i] <- lo[i] - h
    (fn(hi) - fn(lo)) / (2 * h)
  }, numeric(1))
}
fd_hessian <- function(fn, p) {
  n <- length(p); H <- matrix(0, n, n); center <- fn(p)
  steps <- 2e-4 * pmax(1, abs(p))
  for (i in seq_len(n)) for (j in seq_len(i)) {
    if (i == j) {
      hi <- lo <- p; hi[i] <- hi[i] + steps[i]; lo[i] <- lo[i] - steps[i]
      H[i, i] <- (fn(hi) - 2 * center + fn(lo)) / steps[i]^2
    } else {
      pp <- pm <- mp <- mm <- p
      pp[i] <- pm[i] <- p[i] + steps[i]
      mp[i] <- mm[i] <- p[i] - steps[i]
      pp[j] <- mp[j] <- p[j] + steps[j]
      pm[j] <- mm[j] <- p[j] - steps[j]
      H[i, j] <- H[j, i] <-
        (fn(pp) - fn(pm) - fn(mp) + fn(mm)) / (4 * steps[i] * steps[j])
    }
  }
  H
}

# Native R loadings have raw diagonal coordinates. The frozen oracle has log
# diagonal coordinates, so BOTH the Jacobian and second derivative are needed.
native_theta <- function(theta, order = kernel_names) {
  p <- theta; p[c(4L, 7L)] <- exp(p[c(4L, 7L)])
  source <- unlist(lapply(order, function(k) {
    i <- match(k, kernel_names); 3L + (i - 1L) * 3L + seq_len(3L)
  }))
  unique <- unlist(lapply(order, function(k) {
    i <- match(k, kernel_names); 9L + (i - 1L) * 3L + seq_len(3L)
  }))
  p <- p[c(1:3, source, unique)]
  names(p) <- c(rep("b_fix", 3L), rep("theta_rr_kernel", 6L),
                rep("log_sd_kernel_diag", 6L))
  p
}
to_oracle_derivatives <- function(g, H, theta, order) {
  ix <- c(1:3, unlist(lapply(kernel_names, function(k) {
    3L + (match(k, order) - 1L) * 3L + seq_len(3L)
  })), unlist(lapply(kernel_names, function(k) {
    9L + (match(k, order) - 1L) * 3L + seq_len(3L)
  })))
  g <- g[ix]; H <- H[ix, ix]
  J <- rep(1, length(theta)); J[c(4L, 7L)] <- exp(theta[c(4L, 7L)])
  H <- H * outer(J, J)
  diag(H)[c(4L, 7L)] <- diag(H)[c(4L, 7L)] +
    g[c(4L, 7L)] * J[c(4L, 7L)]
  list(gradient = g * J, hessian = H)
}
dense_nll <- function(p, order = kernel_names, sigma = f$known_residual_sd) {
  V <- diag(sigma^2, length(response))
  for (j in seq_along(order)) {
    loading <- p[3L + (j - 1L) * 3L + seq_len(3L)]
    sd <- exp(p[9L + (j - 1L) * 3L + seq_len(3L)])
    V <- V + kronecker(kernels[[order[j]]], tcrossprod(loading) + diag(sd^2))
  }
  R <- chol(V); residual <- response - rep(p[1:3], length(sites))
  z <- forwardsolve(t(R), residual)
  length(response) * log(2 * pi) / 2 + sum(log(diag(R))) + sum(z^2) / 2
}

if (mode == "pure") {
  source("R/kernel-psi-sd-priors.R")
  resolve <- .gllvmTMB_resolve_kernel_psi_sd_prior
  attach_prior <- .gllvmTMB_attach_kernel_psi_sd_prior
} else {
  # Run only after resource clearance. load_all may compile the native package.
  devtools::load_all(quiet = TRUE)
  resolve <- getFromNamespace(".gllvmTMB_resolve_kernel_psi_sd_prior", "gllvmTMB")
  attach_prior <- getFromNamespace(".gllvmTMB_attach_kernel_psi_sd_prior", "gllvmTMB")
}

build_objective <- function(order, adjusted = FALSE, with_prior = FALSE) {
  p <- native_theta(vec(f$points[[1L]]$theta), order)
  if (mode == "pure") return(list(
    par = p, fn = function(p) dense_nll(p, order),
    gr = function(p) fd_gradient(function(x) dense_nll(x, order), p),
    he = function(p) fd_hessian(function(x) dense_nll(x, order), p)
  ))
  K <- lapply(kernels, function(x) {
    if (adjusted) diag(x) <- diag(x) - 1e-8
    dimnames(x) <- list(sites, sites); x
  })
  dat <- data.frame(value = response,
                    trait = factor(rep(traits, length(sites)), levels = traits),
                    species = factor(rep(sites, each = length(traits)), levels = sites))
  dat$row_id <- dat$species
  K_first <- K[[order[1L]]]; K_second <- K[[order[2L]]]
  form <- value ~ 0 + trait +
    kernel_latent(species, K = K_first, d = 1, name = "first", unique = TRUE) +
    kernel_latent(species, K = K_second, d = 1, name = "second", unique = TRUE)
  # Keep true component names in the formula; terms are otherwise identical.
  txt <- paste(deparse(form), collapse = " ")
  txt <- sub('name = "first"', paste0('name = "', order[1L], '"'), txt, fixed = TRUE)
  txt <- sub('name = "second"', paste0('name = "', order[2L], '"'), txt, fixed = TRUE)
  form <- stats::as.formula(txt, env = environment())
  fit <- suppressWarnings(gllvmTMB(
    form, data = dat, unit = "row_id", cluster = "species", family = gaussian(),
    known_sigma_eps = f$known_residual_sd,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, init_jitter = 0,
      optimizer = "optim", optArgs = list(method = "BFGS", control = list(maxit = 0L)),
      svd_start = FALSE, laplace_auto_refit = FALSE,
      kernel_psi_sd_prior = if (with_prior) prior else NULL), silent = TRUE
  ))
  obj <- fit$tmb_obj
  stopifnot(identical(names(obj$par), names(p)))
  attr(obj, "public_prior_receipt") <- list(
    specification = fit$kernel_psi_sd_prior$specification,
    estimator = fit$estimator, components = fit$objective_components,
    reported_logLik = as.numeric(logLik(fit)),
    parameter = fit$opt$par
  )
  # Record the supplied and effective matrices; check every entry independently.
  Ainv <- obj$env$data$Ainv_kernel
  for (j in seq_along(order)) {
    k <- order[j]; effective <- solve(Ainv[j, , ])
    utils::write.csv(K[[k]], file.path(out_dir, paste0(if (adjusted) "adjusted" else "literal", "-input-", k, ".csv")))
    utils::write.csv(effective, file.path(out_dir, paste0(if (adjusted) "adjusted" else "literal", "-effective-", k, ".csv")))
    check(paste(if (adjusted) "adjusted" else "literal", "effective kernel", k),
          effective, kernels[[k]], 1e-12, required = adjusted)
  }
  obj
}

routes <- if (mode == "pure") "pure" else if (smoke) "adjusted" else c("literal", "adjusted")
orders <- if (smoke) list(kernel_names) else list(kernel_names, rev(kernel_names))
for (route in routes) for (order in orders) {
  obj <- build_objective(order, adjusted = route == "adjusted")
  registry <- resolve(prior, order, rep(1L, 2L), traits, TRUE)
  penalized <- attach_prior(obj, registry)
  stopifnot(is.null(obj$kernel_psi_sd_prior)) # Never attach to a penalized tape.
  stopifnot(identical(attach_prior(obj, NULL), obj))
  for (point in f$points) {
    theta <- vec(point$theta); p <- native_theta(theta, order)
    e <- expected[[point$name]]
    label <- paste(route, paste(order, collapse = ":"), point$name)
    # Literal kernel drift is a measured difference, not identical-input parity.
    required <- route != "literal"
    check(paste(label, "nll"), obj$fn(p), e$nll, 1e-8, 1e-8, required)
    check(paste(label, "prior"), penalized$kernel_psi_sd_prior$penalty(p),
          e$negative_log_prior, 1e-8, 1e-8)
    check(paste(label, "criterion"), penalized$fn(p), e$criterion, 1e-8, 1e-8, required)
    g0 <- as.numeric(obj$gr(p))
    H0 <- if (mode == "pure") obj$he(p) else
      stats::optimHess(p, fn = obj$fn, gr = obj$gr)
    d0 <- to_oracle_derivatives(g0, H0, theta, order)
    check(paste(label, "unpenalized gradient"), d0$gradient,
          vec(e$unpenalized_gradient), 2e-6, 2e-5, required)
    check(paste(label, "unpenalized full Hessian"), d0$hessian,
          mat(e$unpenalized_hessian), 2e-5, 2e-5, required)
    g <- as.numeric(penalized$gr(p))
    H <- if (mode == "pure") penalized$he(p) else
      stats::optimHess(p, fn = penalized$fn, gr = penalized$gr)
    d <- to_oracle_derivatives(g, H, theta, order)
    isolated <- attach_prior(list(par = p, fn = function(p) 0,
      gr = function(p) numeric(length(p)), he = function(p) matrix(0, length(p), length(p))), registry)
    dp <- to_oracle_derivatives(isolated$gr(p), isolated$he(p), theta, order)
    check(paste(label, "isolated prior gradient"), dp$gradient,
          vec(e$prior_gradient), 1e-12)
    check(paste(label, "isolated prior full Hessian"), dp$hessian,
          mat(e$prior_hessian), 1e-12)
    check(paste(label, "gradient"), d$gradient, vec(e$gradient), 2e-6, 2e-5, required)
    check(paste(label, "full Hessian"), d$hessian, mat(e$hessian), 2e-5, 2e-5, required)
    # Independently difference the native criterion, then transform, including
    # the nonzero second derivative of exp(log_loading_diag).
    dfd <- to_oracle_derivatives(fd_gradient(penalized$fn, p),
                                fd_hessian(penalized$fn, p), theta, order)
    check(paste(label, "central gradient"), dfd$gradient, vec(e$gradient), 2e-6, 2e-5, required)
    check(paste(label, "central full Hessian"), dfd$hessian, mat(e$hessian), 2e-5, 2e-5, required)
  }
}

if (mode == "pure") {
  for (point in f$boundary_points) {
    theta <- vec(point$theta_reference); p <- native_theta(theta)
    zero <- vec(point$zero_unique_indices) + 1L # JSON indices are zero-based.
    fn <- function(p) { p[zero] <- -Inf; dense_nll(p) }
    check(paste(point$name, "unpenalized exact-zero nll"), fn(p), point$nll, 1e-8, 1e-8)
    d <- to_oracle_derivatives(fd_gradient(fn, p), fd_hessian(fn, p), theta, kernel_names)
    check(paste(point$name, "unpenalized exact-zero gradient"), d$gradient,
          vec(point$gradient), 2e-6, 2e-5)
    check(paste(point$name, "unpenalized exact-zero full Hessian"), d$hessian,
          mat(point$hessian), 2e-5, 2e-5)
    pp <- p; pp[zero] <- -Inf
    registry <- resolve(prior, kernel_names, c(1L, 1L), traits, TRUE)
    isolated <- attach_prior(list(par = p, fn = function(p) 0,
      gr = function(p) numeric(length(p)), he = function(p) matrix(0, length(p), length(p))), registry)
    check(paste(point$name, "selected Gamma zero is infinite"),
          as.numeric(is.infinite(isolated$fn(pp))),
          as.numeric(point$selected_prior_penalty_is_infinite), 0)
  }
  for (point in f$fixed_sigma_sensitivity) {
    theta <- vec(point$theta); p <- native_theta(theta)
    fn <- function(p) dense_nll(p, sigma = point$known_residual_sd)
    label <- paste("fixed observation SD", point$known_residual_sd)
    check(paste(label, "nll"), fn(p), point$nll, 1e-8, 1e-8)
    d <- to_oracle_derivatives(fd_gradient(fn, p), fd_hessian(fn, p), theta, kernel_names)
    check(paste(label, "unpenalized gradient"), d$gradient,
          vec(point$unpenalized_gradient), 2e-6, 2e-5)
    check(paste(label, "unpenalized full Hessian"), d$hessian,
          mat(point$unpenalized_hessian), 2e-5, 2e-5)
  }
}

if (mode == "native") for (order in orders) {
  public <- build_objective(order, adjusted = TRUE, with_prior = TRUE)
  stopifnot(!is.null(public$kernel_psi_sd_prior)) # Already attached through control.
  raw <- build_objective(order, adjusted = TRUE)
  receipt <- attr(public, "public_prior_receipt")
  stopifnot(identical(receipt$specification$kernel, prior$kernel),
            identical(receipt$specification$trait, prior$trait),
            identical(receipt$estimator, "MAP"))
  for (point in f$points) {
    p <- native_theta(vec(point$theta), order); e <- expected[[point$name]]
    check(paste("public", paste(order, collapse = ":"), point$name, "prior increment"),
          public$fn(p) - raw$fn(p), e$negative_log_prior, 1e-8, 1e-8)
    check(paste("public", paste(order, collapse = ":"), point$name, "criterion"),
          public$fn(p), e$criterion, 1e-8, 1e-8)
    d <- to_oracle_derivatives(as.numeric(public$gr(p)),
      stats::optimHess(p, fn = public$fn, gr = public$gr), vec(point$theta), order)
    check(paste("public", paste(order, collapse = ":"), point$name, "gradient"),
          d$gradient, vec(e$gradient), 2e-6, 2e-5)
    check(paste("public", paste(order, collapse = ":"), point$name, "full Hessian"),
          d$hessian, mat(e$hessian), 2e-5, 2e-5)
  }
  check(paste("public logLik decomposition", paste(order, collapse = ":")),
        receipt$reported_logLik, -receipt$components$likelihood_nll, 1e-8, 1e-8)
}

# Natural-scale normalization and units are separate from model calculations.
for (i in seq_len(nrow(prior))) {
  row <- prior[i, ]
  single <- resolve(row, kernel_names, c(1L, 1L), traits, TRUE)
  p <- native_theta(vec(f$points[[1L]]$theta))
  zero <- list(par = p, fn = function(p) 0, gr = function(p) rep(0, length(p)),
               he = function(p) matrix(0, length(p), length(p)))
  prior_obj <- attach_prior(zero, single)
  idx <- prior_obj$kernel_psi_sd_prior$indices
  integral <- integrate(function(s) vapply(s, function(x) {
    pp <- p; pp[idx] <- log(x)
    exp(-prior_obj$fn(pp))
  }, numeric(1)), 0, Inf, rel.tol = 1e-11)$value
  check(paste("normalization", i), integral, 1, 1e-9)
  scaled <- row; scaled$rate <- scaled$rate / 7
  scaled_obj <- attach_prior(zero, resolve(scaled, kernel_names, c(1L, 1L), traits, TRUE))
  ps <- p; ps[idx] <- ps[idx] + log(7)
  check(paste("SD scale", i), scaled_obj$fn(ps) - prior_obj$fn(p), log(7), 1e-12)
}

if (mode == "pure") {
  p <- native_theta(vec(f$points[[1L]]$theta))
  zero <- list(par = p, fn = function(p) 0, gr = function(p) numeric(length(p)),
               he = function(p) matrix(0, length(p), length(p)))
  registry <- resolve(prior, kernel_names, c(1L, 1L), traits, TRUE)
  isolated <- attach_prior(zero, registry)
  correct <- isolated$kernel_psi_sd_prior$penalty
  idx <- isolated$kernel_psi_sd_prior$indices
  wrong <- prior; wrong$trait <- c("t2", "t3")
  wrong_obj <- attach_prior(zero, resolve(wrong, kernel_names, c(1L, 1L), traits, TRUE))
  gamma_nll <- function(s) sum(prior$rate * s - (prior$shape - 1) * log(s) -
                                prior$shape * log(prior$rate) + lgamma(prior$shape))
  mutations <- list(
    extra_Jacobian = function(p) correct(p) - sum(p[idx]),
    wrong_target = wrong_obj$kernel_psi_sd_prior$penalty,
    doubled = function(p) 2 * correct(p),
    per_site = function(p) length(sites) * correct(p),
    per_cell = function(p) length(response) * correct(p),
    omitted = function(p) 0,
    variance_for_SD = function(p) gamma_nll(exp(2 * p[idx])),
    loading_for_Psi = function(p) gamma_nll(abs(p[c(4L, 8L)])),
    observation_SD_for_Psi = function(p) gamma_nll(rep(f$known_residual_sd, 2L))
  )
  for (name in names(mutations)) {
    mutation <- mutations[[name]]
    check(paste("mutation distinguished value", name),
          as.numeric(abs(mutation(p) - correct(p)) > 1e-5), 1, 0)
    gradient_gap <- max(abs(fd_gradient(mutation, p) - isolated$gr(p)))
    hessian_gap <- max(abs(fd_hessian(mutation, p) - isolated$he(p)))
    check(paste("mutation distinguished derivatives", name),
          as.numeric(max(gradient_gap, hessian_gap) > 1e-5), 1, 0)
  }
  # Preserve the established half-normal path and a NULL prior exactly.
  legacy <- data.frame(kernel = "oak", trait = "t1", scale = 0.5)
  legacy_registry <- resolve(legacy, kernel_names, c(1L, 1L), traits, TRUE)
  legacy_obj <- attach_prior(zero, legacy_registry)
  for (eta in c(-30, -12, log(0.7))) {
    p[10L] <- eta; sd <- exp(eta)
    check(paste("half-normal density unchanged", eta), legacy_obj$fn(p),
          -stats::dnorm(sd, 0, 0.5, log = TRUE) - log(2), 0)
    check(paste("half-normal gradient unchanged", eta), legacy_obj$gr(p)[10L], sd^2 / 0.5^2, 0)
    check(paste("half-normal Hessian unchanged", eta), legacy_obj$he(p)[10L, 10L], 2 * sd^2 / 0.5^2, 0)
  }
  invalid <- list(transform(prior, scale = 1), transform(prior, shape = 1),
    transform(prior, rate = 0), transform(prior, rate = NA_real_),
    transform(prior, shape = Inf), transform(prior, rate = "1"),
    prior[setdiff(names(prior), "rate")], rbind(prior, prior), prior[FALSE, ])
  for (i in seq_along(invalid)) {
    err <- tryCatch(resolve(invalid[[i]], kernel_names, c(1L, 1L), traits, TRUE), error = identity)
    check(paste("invalid Gamma schema rejected", i),
          as.numeric(inherits(err, "gllvmTMB_kernel_psi_prior_invalid")), 1, 0)
  }
  with_random <- zero; with_random$env <- list(random = 1:4)
  random_obj <- attach_prior(with_random, registry)
  stopifnot(is.null(random_obj$kernel_psi_sd_prior$likelihood_he))
}
result <- do.call(rbind, checks)
utils::write.csv(result, file.path(out_dir, paste0(mode, "-checks.csv")), row.names = FALSE)
source_files <- c("R/kernel-psi-sd-priors.R", "tests/testthat/test-psi-sd-priors.R",
                  "dev/psi-sd-prior-20261122/compare.R")
system2("shasum", c("-a", "256", source_files),
        stdout = file.path(out_dir, "SOURCE-SHA256SUMS"))
file.copy(file.path(oracle_dir, "SHA256SUMS"),
          file.path(out_dir, "ORACLE-SHA256SUMS"), overwrite = TRUE)
writeLines(system("git diff -- R/kernel-psi-sd-priors.R tests/testthat/test-psi-sd-priors.R",
                   intern = TRUE), file.path(out_dir, "source.diff"))
saveRDS(list(source = system("git rev-parse HEAD", intern = TRUE), mode = mode, smoke = smoke,
             observed_at_UTC = format(Sys.time(), tz = "UTC"), checks = result,
             session = sessionInfo()), file.path(out_dir, paste0(mode, "-receipt.rds")))
print(result[!result$passed, ], row.names = FALSE)
cat(sum(result$passed), "/", nrow(result), "checks passed; required failures:",
    sum(!result$passed & result$required), "\n")
if (any(!result$passed & result$required)) quit(status = 1L)
