# Eight pre-retained toy fits: four forms by fixed/estimated rho.
args <- commandArgs(TRUE)
dest <- args[[1L]]
root <- normalizePath(if (length(args) >= 2L) args[[2L]] else ".")
if (dir.exists(dest)) stop("Refusing to replace engineering fixtures")
dir.create(dest, recursive = TRUE)
dir.create(file.path(dest, "data"))
.libPaths(c(file.path(root, "library"), .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
if (file.exists(file.path(root, "bundle-manifest.json"))) {
  bundle <- jsonlite::read_json(file.path(root, "bundle-manifest.json"), simplifyVector = TRUE)
  installation <- jsonlite::read_json(file.path(root, "install-receipt.json"), simplifyVector = TRUE)
  stopifnot(identical(installation$exit_status, 0L),
            identical(installation$bundle_hash, bundle$bundle_hash),
            startsWith(normalizePath(system.file(package = "gllvmTMB")),
                       normalizePath(file.path(root, "library"))))
}
source("dev/structured-rho/spatial-recovery/study-metrics.R")
n <- 40L
p <- 4L
labels <- sprintf("e%02d", seq_len(n))
locations <- expand.grid(x = seq(0, 2, length.out = 8),
                         ycoord = seq(0, 2, length.out = 5))
locations$group <- labels
template <- expand.grid(trait = paste0("t", seq_len(p)), rep = 1:2, group = labels)
template$group <- factor(template$group, levels = labels)
template$obs <- interaction(template$group, template$rep, drop = TRUE)
template$x <- locations$x[match(template$group, labels)]
template$ycoord <- locations$ycoord[match(template$group, labels)]
# The production fit needs one projection row per long-format observation.
# The independent DGP needs one projection row per modeled source level.
mesh <- make_mesh(template, c("x", "ycoord"), cutoff = .12)
first_group_row <- match(labels, as.character(template$group))
A <- as.matrix(mesh$A_st[first_group_row, , drop = FALSE])
stopifnot(nrow(mesh$A_st) == nrow(template), nrow(A) == n,
          isTRUE(all.equal(as.matrix(mesh$A_st),
                           A[as.integer(template$group), , drop = FALSE],
                           tolerance = 1e-12)))
kappa <- 2
source <- spatial_rho_source_covariance(A, mesh$spde$c0, mesh$spde$g1,
                                        mesh$spde$g2, kappa, .6)
K <- source$K
scale <- mean(diag(K))
loading <- c(.9, .7, -.8, .6)
psi <- c(.3, .2, .25, .35)
base_forms <- list(
  indep = list(L = diag(abs(loading)), Psi = rep(0, p)),
  dep = list(L = diag(abs(loading)) + matrix(c(0,0,0,0,.12,0,0,0,-.08,.1,0,0,.06,-.05,.09,0),p,p), Psi = rep(0,p)),
  latent = list(L = matrix(loading, p, 1), Psi = rep(0, p)),
  latent_psi = list(L = matrix(loading, p, 1), Psi = psi)
)
forms <- lapply(base_forms, function(x)
  list(L = x$L / sqrt(scale), Psi = x$Psi / scale))
fixture <- list(
  name = "engineering", locations = locations, mesh = mesh, A = A, K = K,
  M0 = mesh$spde$c0, M1 = mesh$spde$g1, M2 = mesh$spde$g2,
  kappa = kappa, cutoff = .12, location_seed = NA_integer_, forms = forms,
  base_forms = base_forms, source_scale = scale, labels = labels
)
saveRDS(list(regimes = list(engineering = fixture), mu = c(.1,-.2,.25,.05),
             sigma_eps = .6, base_forms = base_forms),
        file.path(dest, "sources.rds"), version = 3)
gi <- as.integer(template$group)
ti <- as.integer(template$trait)
jobs <- list()
datasets <- list()
i <- 0L
for (mode in names(forms)) {
  set.seed(320120L + match(mode, names(forms)))
  Kr <- .6 * K
  diag(Kr) <- diag(K)
  LK <- t(chol(Kr))
  form <- forms[[mode]]
  U <- LK %*% matrix(rnorm(n * ncol(form$L)), n, ncol(form$L)) %*% t(form$L)
  if (any(form$Psi > 0))
    U <- U + sweep(LK %*% matrix(rnorm(n * p), n, p), 2, sqrt(form$Psi), "*")
  data <- template
  data$y <- c(.1,-.2,.25,.05)[ti] + U[cbind(gi, ti)] + rnorm(nrow(data), sd = .6)
  file <- paste0("data/", mode, ".rds")
  saveRDS(data, file.path(dest, file), version = 3)
  datasets[[mode]] <- data.frame(dataset_id = match(mode, names(forms)), file = file,
                                 regime = "engineering", mode = mode, rho = .6,
                                 replication = 1L, seed = 320120L + match(mode,names(forms)))
  for (method in c("fixed", "estimated")) {
    i <- i + 1L
    jobs[[i]] <- data.frame(
      attempt_id = sprintf("spatial-engineering-%02d", i),
      dataset_id = match(mode, names(forms)), dataset = file,
      regime = "engineering", mode = mode, rho = .6, replication = 1L,
      seed = 320120L + match(mode, names(forms)), fit_seed = 730108L + i,
      method = method, pilot = FALSE
    )
  }
}
jobs <- do.call(rbind, jobs)
jobs$attempt_id <- sprintf("spatial-engineering-%02d", 8L + seq_len(nrow(jobs)))
stopifnot(nrow(jobs) == 8L)
write.csv(jobs, file.path(dest, "jobs.csv"), row.names = FALSE)
write.csv(do.call(rbind, datasets), file.path(dest, "datasets.csv"), row.names = FALSE)
files <- sort(list.files(dest, recursive = TRUE, full.names = TRUE))
files <- files[file.info(files)$isdir %in% FALSE]
relative <- substring(normalizePath(files), nchar(normalizePath(dest)) + 2L)
md5 <- setNames(unname(tools::md5sum(files)), relative)
file_records <- lapply(seq_along(md5), function(i)
  list(path = names(md5)[[i]], md5 = unname(md5[[i]])))
jsonlite::write_json(list(engineering_attempts = 8L, files = file_records),
                     file.path(dest, "manifest.json"), auto_unbox = TRUE,
                     pretty = TRUE)
cat("SPATIAL_ENGINEERING_FIXTURES_FROZEN_8_ATTEMPTS\n")
