# Freeze independent spatial recovery fixtures. This script deliberately
# constructs K_rho directly and never calls a production attenuation helper.
args <- commandArgs(TRUE)
dest <- args[[1L]]
root <- normalizePath(if (length(args) >= 2L) args[[2L]] else ".")
if (dir.exists(dest)) stop("Refusing to replace frozen spatial fixtures")
dir.create(dest, recursive = TRUE)
dir.create(file.path(dest, "data"))
.libPaths(c(file.path(root, "library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
bundle <- jsonlite::read_json(file.path(root, "bundle-manifest.json"), simplifyVector = TRUE)
installation <- jsonlite::read_json(file.path(root, "install-receipt.json"), simplifyVector = TRUE)
stopifnot(identical(installation$exit_status, 0L),
          identical(installation$bundle_hash, bundle$bundle_hash),
          startsWith(normalizePath(system.file(package = "gllvmTMB")),
                     normalizePath(file.path(root, "library"))))
source("dev/structured-rho/spatial-recovery/study-metrics.R")

n <- 120L
p <- 6L
labels <- sprintf("g%03d", seq_len(n))
regular <- expand.grid(x = seq(0, 2, length.out = 12),
                       ycoord = seq(0, 2, length.out = 10))
set.seed(320102L)
irregular <- data.frame(x = runif(n, 0, 2), ycoord = runif(n, 0, 2))
regime_defs <- list(
  regular_short = list(locations = regular, cutoff = 0.10, kappa = 2,
                       location_seed = NA_integer_),
  irregular_long = list(locations = irregular, cutoff = 0.08, kappa = 0.7,
                        location_seed = 320102L)
)

sd <- c(.6, .7, .8, .65, .75, .55)
Ldep <- diag(sd)
Ldep[lower.tri(Ldep)] <- rep(c(.12, -.08, .1), length.out = 15)
loading <- c(.7, .65, -.6, .8, -.55, .75)
psi <- c(.18, .25, .22, .2, .3, .16)
base_forms <- list(
  indep = list(L = diag(sd), Psi = rep(0, p)),
  dep = list(L = Ldep, Psi = rep(0, p)),
  latent = list(L = matrix(loading, p, 1), Psi = rep(0, p)),
  latent_psi = list(L = matrix(loading, p, 1), Psi = psi)
)
mu <- c(.1, -.2, .25, .05, -.15, .2)
sigma_eps <- .6
regimes <- list()
geometry <- list()

for (regime in names(regime_defs)) {
  def <- regime_defs[[regime]]
  locations <- def$locations
  locations$group <- labels
  template <- expand.grid(trait = paste0("t", seq_len(p)), rep = 1:3,
                          group = labels)
  template$group <- factor(template$group, levels = labels)
  template$obs <- interaction(template$group, template$rep, drop = TRUE)
  template$x <- locations$x[match(template$group, labels)]
  template$ycoord <- locations$ycoord[match(template$group, labels)]
  mesh <- make_mesh(template, c("x", "ycoord"), cutoff = def$cutoff)
  first_group_row <- match(labels, as.character(template$group))
  A <- as.matrix(mesh$A_st[first_group_row, , drop = FALSE])
  stopifnot(nrow(mesh$A_st) == nrow(template), nrow(A) == n,
            isTRUE(all.equal(as.matrix(mesh$A_st),
                             A[as.integer(template$group), , drop = FALSE],
                             tolerance = 1e-12)))
  cov <- spatial_rho_source_covariance(A, mesh$spde$c0, mesh$spde$g1,
                                       mesh$spde$g2, def$kappa, 1)
  K <- cov$K
  eig <- eigen(K, symmetric = TRUE, only.values = TRUE)$values
  psd_tolerance <- 100 * .Machine$double.eps * max(1, max(abs(eig)))
  stopifnot(all(is.finite(K)), min(eig) >= -psd_tolerance,
            all(diag(K) > 0))
  attenuated_min_eigen <- setNames(numeric(2), c("rho_0.3", "rho_0.7"))
  for (rho in c(.3, .7)) {
    Krho <- rho * K
    diag(Krho) <- diag(K)
    eig_rho <- eigen(Krho, symmetric = TRUE, only.values = TRUE)$values
    stopifnot(min(eig_rho) > 0,
              !inherits(try(chol(Krho), silent = TRUE), "try-error"))
    attenuated_min_eigen[[paste0("rho_", rho)]] <- min(eig_rho)
  }
  # This is an admission check, not the simulator or covariance oracle. Record
  # the exact production guard's diagnostics before any retained fit exists.
  admission <- gllvmTMB:::.structured_rho_spatial_admit(
    Matrix::Matrix(A, sparse = TRUE), mesh$spde$c0, mesh$spde$g1, mesh$spde$g2
  )
  stopifnot(length(admission) == 3L,
            any(vapply(admission, function(x)
              x$relative_singular_value > x$tolerance, logical(1))))
  scale <- mean(diag(K))
  forms <- lapply(base_forms, function(x) {
    list(L = x$L / sqrt(scale), Psi = x$Psi / scale)
  })
  regimes[[regime]] <- list(
    name = regime, locations = locations, mesh = mesh, A = A, K = K,
    M0 = mesh$spde$c0, M1 = mesh$spde$g1, M2 = mesh$spde$g2,
    kappa = def$kappa, cutoff = def$cutoff,
    location_seed = def$location_seed, forms = forms,
    base_forms = base_forms, source_scale = scale, labels = labels,
    admission_diagnostics = admission
  )
  geometry[[regime]] <- data.frame(
    regime = regime, n = n, cutoff = def$cutoff, kappa = def$kappa,
    practical_range = sqrt(8) / def$kappa,
    diagonal_min = min(diag(K)), diagonal_max = max(diag(K)),
    eigen_min = min(eig), eigen_max = max(eig),
    psd_tolerance = psd_tolerance,
    numerical_rank = sum(eig > max(eig) * 1e-10),
    attenuated_min_eigen_rho_0.3 = attenuated_min_eigen[["rho_0.3"]],
    attenuated_min_eigen_rho_0.7 = attenuated_min_eigen[["rho_0.7"]],
    participation_ratio = sum(eig)^2 / sum(eig^2),
    median_offdiagonal = median(K[lower.tri(K)]), source_scale = scale,
    admission_min_relative_singular = min(vapply(admission, function(x)
      x$relative_singular_value, numeric(1))),
    admission_max_relative_singular = max(vapply(admission, function(x)
      x$relative_singular_value, numeric(1)))
  )
}
saveRDS(list(regimes = regimes, mu = mu, sigma_eps = sigma_eps,
             base_forms = base_forms), file.path(dest, "sources.rds"), version = 3)
write.csv(do.call(rbind, geometry), file.path(dest, "source-geometry.csv"), row.names = FALSE)

jobs <- list()
datasets <- list()
dataset_id <- 0L
attempt_id <- 0L
for (regime in names(regimes)) {
  fixture <- regimes[[regime]]
  template <- expand.grid(trait = paste0("t", seq_len(p)), rep = 1:3,
                          group = labels)
  template$group <- factor(template$group, levels = labels)
  template$obs <- interaction(template$group, template$rep, drop = TRUE)
  template$x <- fixture$locations$x[match(template$group, labels)]
  template$ycoord <- fixture$locations$ycoord[match(template$group, labels)]
  gi <- as.integer(template$group)
  ti <- as.integer(template$trait)
  for (mode in names(fixture$forms)) for (rho in c(.3, .7)) {
    Kr <- rho * fixture$K
    diag(Kr) <- diag(fixture$K)
    LK <- t(chol(Kr))
    form <- fixture$forms[[mode]]
    for (replication in seq_len(50L)) {
      dataset_id <- dataset_id + 1L
      seed <- 3202000L + dataset_id
      set.seed(seed)
      U <- LK %*% matrix(rnorm(n * ncol(form$L)), n, ncol(form$L)) %*% t(form$L)
      if (any(form$Psi > 0)) {
        U <- U + sweep(LK %*% matrix(rnorm(n * p), n, p),
                       2, sqrt(form$Psi), "*")
      }
      data <- template
      data$y <- mu[ti] + U[cbind(gi, ti)] + rnorm(nrow(data), sd = sigma_eps)
      file <- sprintf("data/dataset-%04d.rds", dataset_id)
      saveRDS(data, file.path(dest, file), version = 3)
      datasets[[dataset_id]] <- data.frame(
        dataset_id = dataset_id, file = file, regime = regime, mode = mode,
        rho = rho, replication = replication, seed = seed
      )
      for (method in c("fixed", "estimated")) {
        attempt_id <- attempt_id + 1L
        jobs[[attempt_id]] <- data.frame(
          attempt_id = sprintf("spatial-retained-%04d", attempt_id),
          dataset_id = dataset_id, dataset = file, regime = regime, mode = mode,
          rho = rho, replication = replication, seed = seed,
          fit_seed = 730000L + dataset_id, method = method,
          pilot = replication == 1L
        )
      }
    }
  }
}
jobs <- do.call(rbind, jobs)
datasets <- do.call(rbind, datasets)
stopifnot(nrow(jobs) == 1600L, sum(jobs$pilot) == 32L,
          nrow(datasets) == 800L, !anyDuplicated(jobs$attempt_id))
write.csv(jobs, file.path(dest, "jobs.csv"), row.names = FALSE)
write.csv(datasets, file.path(dest, "datasets.csv"), row.names = FALSE)

hash_file <- function(path) unname(tools::md5sum(path))
paths <- sort(list.files(dest, recursive = TRUE, full.names = TRUE))
paths <- paths[file.info(paths)$isdir %in% FALSE]
relative <- substring(normalizePath(paths), nchar(normalizePath(dest)) + 2L)
files <- setNames(vapply(paths, hash_file, character(1)), relative)
manifest <- list(
  design = "2 regimes x 4 forms x 2 strengths x 50 datasets x 2 fits",
  retained_attempts = 1600L, pilot_attempts = 32L,
  engineering_ceiling = 32L, workers = 12L, blas_threads = 1L,
  candidate_head = bundle$head, candidate_bundle_hash = bundle$bundle_hash,
  numerical_success = paste("one optimizer; convergence 0; pdHess; finite",
                             "objective/parameters/covariance/gradient; max gradient <= .01"),
  files = lapply(seq_along(files), function(i)
    list(path = names(files)[[i]], md5 = unname(files[[i]])))
)
jsonlite::write_json(manifest, file.path(dest, "manifest.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA)
cat("SPATIAL_RECOVERY_FIXTURES_FROZEN_800_DATASETS_1600_ATTEMPTS_32_PILOT\n")
