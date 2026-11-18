#!/usr/bin/env Rscript

## Post-run provenance finalizer.  It reads a completed G2n root and adds the
## immutable state omitted by an earlier receipt; it never calls a fitter,
## profile, optimizer, or simulator.
args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
root_arg <- value("root")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
if (is.null(root_arg)) stop("require --root=PATH", call. = FALSE)
root <- normalizePath(if (grepl("^/", root_arg)) root_arg else file.path(getwd(), root_arg),
                      mustWork = TRUE)
fit_file <- file.path(root, "g2i-delegate", "fit.rds")
if (!file.exists(fit_file)) stop("completed retained fit.rds is required", call. = FALSE)
hash_file <- function(path) unname(tools::md5sum(path))[[1L]]
hash_object <- function(x) {
  tmp <- tempfile("g2n-provenance-")
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  hash_file(tmp)
}
source_file <- file.path(pkg, "dev", "isdm-package-recovery", "g2h-360cell-fixture.R")
source(source_file, local = TRUE)
receipt <- readRDS(file.path(root, "g2n-root-receipt.rds"))
fixture <- g2h_make_fixture(seed = receipt$seed)
g2h_validate_fixture(fixture)
oracle <- g2h_information_oracle(fixture)
survey <- fixture$rows$source == "survey"
source_gate <- list(
  valid = isTRUE(abs(oracle$x_b_correlation) <= .10) &&
    identical(oracle$fixed_design_rank, 3L) && all(oracle$gamma_information >= 130) &&
    all(is.finite(fixture$B[!survey, 1L])) && all(is.na(fixture$B[survey, 1L])) &&
    all(table(fixture$rows$cell_id[survey], fixture$rows$trait[survey]) == 3L),
  gbif_bias_finite = all(is.finite(fixture$B[!survey, 1L])),
  survey_bias_na = all(is.na(fixture$B[survey, 1L])),
  x_bias_correlation = oracle$x_b_correlation,
  fixed_design_rank = oracle$fixed_design_rank,
  gamma_information = oracle$gamma_information,
  repeated_pa_events_per_cell_species = as.integer(unique(table(
    fixture$rows$cell_id[survey], fixture$rows$trait[survey]
  )))
)
fit <- readRDS(fit_file)
cov_fixed <- fit$sd_report$cov.fixed
if (!is.matrix(cov_fixed) || !all(is.finite(cov_fixed))) {
  stop("finite fixed-effect covariance is required", call. = FALSE)
}
eigenvalues <- eigen((cov_fixed + t(cov_fixed)) / 2, symmetric = TRUE,
                     only.values = TRUE)$values
ordered_par <- fit$opt$par
map_signature <- hash_object(fit$tmb_map)
data_signature <- hash_object(fit$tmb_data)
random_signature <- hash_object(fit$random)
control_signature <- hash_object(fit$control)
bounds <- list(lower = rep(-Inf, length(ordered_par)), upper = rep(Inf, length(ordered_par)))
provenance <- list(
  kind = "G2N_LOCAL_PRERUN_POSTRUN_PROVENANCE_ADDENDUM",
  source_gate = source_gate,
  parameter_map = list(signature = map_signature, map = fit$tmb_map),
  ordered_opt_par = ordered_par,
  gradient = fit$tmb_obj$gr(ordered_par),
  cov_fixed = cov_fixed,
  covariance_diagnostics = list(
    dimnames_present = !is.null(rownames(cov_fixed)) && !is.null(colnames(cov_fixed)),
    symmetric = isTRUE(all.equal(cov_fixed, t(cov_fixed), tolerance = 1e-10)),
    condition_number = kappa(cov_fixed),
    min_eigenvalue = min(eigenvalues), max_eigenvalue = max(eigenvalues)
  ),
  signatures = list(
    data = data_signature, random = random_signature,
    bounds = hash_object(bounds), scale = hash_object(list(parameter_scale = "native_TMB")),
    control = control_signature
  ),
  fit_engine = list(
    dll = fit$tmb_obj$env$DLL, tmb_version = as.character(utils::packageVersion("TMB")),
    r_version = R.version.string, platform = R.version$platform
  )
)
saveRDS(provenance, file.path(root, "g2n-postrun-provenance-addendum.rds"))

prior_closure <- file.path(root, "g2n-final-provenance-closure.rds")
if (file.exists(prior_closure)) {
  stopifnot(file.rename(prior_closure,
    file.path(root, "g2n-prior-final-provenance-closure-v2.rds")))
}
script <- normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), mustWork = TRUE)
saveRDS(list(
  kind = "G2N_POSTRUN_PROVENANCE_FINALIZER_V3",
  finalizer_md5 = hash_file(script),
  manifest_excludes = c("g2n-file-manifest.csv", "g2n-final-provenance-closure.rds")
), file.path(root, "g2n-provenance-finalizer-v3-receipt.rds"))
files <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE),
                 file.path(root, c("g2n-file-manifest.csv",
                                   "g2n-final-provenance-closure.rds")))
utils::write.csv(data.frame(
  path = sub(paste0("^", root, "/"), "", files),
  md5 = vapply(files, hash_file, character(1L)), stringsAsFactors = FALSE
), file.path(root, "g2n-file-manifest.csv"), row.names = FALSE)
files <- setdiff(list.files(root, full.names = TRUE, recursive = TRUE),
                 file.path(root, "g2n-final-provenance-closure.rds"))
closure <- list(
  kind = "G2N_LOCAL_PRERUN_FINAL_PROVENANCE_CLOSURE_V3",
  convention = "Manifest excludes itself and final closure; final closure binds all files except itself.",
  files = stats::setNames(unname(tools::md5sum(files)),
    sub(paste0("^", root, "/"), "", files))
)
saveRDS(closure, file.path(root, "g2n-final-provenance-closure.rds"))
stopifnot(identical(unname(tools::md5sum(file.path(root, names(closure$files)))),
                    unname(closure$files)))
cat("G2N post-run provenance finalization PASS (no fit)\n")
