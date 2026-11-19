# Synthetic single-kernel bootstrap forwarding probe; no interval claim.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop('Usage: Rscript probe.R OUTPUT_DIR')
out <- normalizePath(args[[1]], mustWork = TRUE)
stopifnot(!file.exists(file.path(out, 'result.rds')))
source_files <- sort(c(list.files('R', '[.]R$', full.names = TRUE),
                       list.files('src', full.names = TRUE, recursive = TRUE)))
source_files <- source_files[file.info(source_files)$isdir %in% FALSE]
source_files <- source_files[!grepl('[.](o|so|dylib|dll)$', source_files)]
hashes <- function() tools::md5sum(source_files)
before <- hashes()
pkgload::load_all('.', quiet = TRUE, recompile = FALSE)
native <- getLoadedDLLs()[['gllvmTMB']][['path']]
native_hash <- unname(tools::md5sum(native))
cat('HEAD', system2('git', c('rev-parse', 'HEAD'), stdout = TRUE), '\n')
cat('NATIVE', normalizePath(native), native_hash, '\n')
cat('PACKAGE', as.character(utils::packageVersion('gllvmTMB')), 'R', as.character(getRversion()), '\n')
set.seed(202611151L)
n <- 10L; sp <- sprintf('s%02d', seq_len(n))
K <- .6^abs(outer(seq_len(n), seq_len(n), '-'))
dimnames(K) <- list(sp, sp)
draw <- function() as.numeric(t(chol(K + diag(1e-8, n))) %*% rnorm(n))
loading <- c(.9, .7, -.8); psi <- c(.35, .45, .3); sigma <- 1e-4
shared <- draw()
y <- sapply(seq_along(loading), function(j) .2*j + loading[j]*shared +
              sqrt(psi[j])*draw() + rnorm(n, sd = sigma))
dat <- data.frame(species = factor(sp, levels = sp), row_id = factor(sp),
                  a = y[,1], b = y[,2], c = y[,3])
f <- traits(a,b,c) ~ 1 + kernel_latent(species, K = K, d = 1, name = 'phy', unique = TRUE)
warnings <- character()
capture_warning <- function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart('muffleWarning') }
result <- list(source_md5_before = before, native_path = native, native_md5 = native_hash,
               target_sd = sigma, seed = 202611151L, warnings = warnings)
tryCatch(withCallingHandlers({
  started <- proc.time()[['elapsed']]
  fit <- gllvmTMB(f, data = dat, family = gaussian(), unit = 'row_id',
                  cluster = 'species', known_sigma_eps = sigma,
                  control = gllvmTMBcontrol(se = FALSE, n_init = 1), silent = TRUE)
  result$initial_elapsed <- proc.time()[['elapsed']] - started
  result$initial_convergence <- fit$opt$convergence
  result$initial_fixed_sd <- fit$known_sigma_eps
  e <- new.env(parent = emptyenv()); e$entry <- list(); e$returned <- list()
  assign('.two_kernel_boot_probe', e, envir = .GlobalEnv)
  trace('gllvmTMB', where = asNamespace('gllvmTMB'), print = FALSE,
        tracer = quote({
          ee <- get('.two_kernel_boot_probe', envir = .GlobalEnv)
          ee$entry[[length(ee$entry)+1L]] <- list(
            missing = missing(known_sigma_eps), value = known_sigma_eps)
        }),
        exit = quote({
          ee <- get('.two_kernel_boot_probe', envir = .GlobalEnv)
          rv <- returnValue()
          if (inherits(rv, 'gllvmTMB_multi')) {
            ee$returned[[length(ee$returned)+1L]] <- list(
              value = rv$known_sigma_eps, map = rv$tmb_map$log_sigma_eps,
              parameter = rv$tmb_params$log_sigma_eps,
              convergence = rv$opt$convergence)
          }
        }))
  started <- proc.time()[['elapsed']]
  boot <- bootstrap_Sigma(fit, n_boot = 1, level = 'phy', what = 'Sigma',
                          conf = .5, seed = 202611152L, n_cores = 1,
                          progress = FALSE, keep_draws = TRUE)
  result$bootstrap_elapsed <- proc.time()[['elapsed']] - started
  result$boot_n_failed <- boot$n_failed
  result$entry <- e$entry; result$returned <- e$returned
  untrace('gllvmTMB', where = asNamespace('gllvmTMB'))
  rm('.two_kernel_boot_probe', envir = .GlobalEnv)
  stopifnot(length(result$entry) >= 1L,
            all(vapply(result$entry, function(z) !z$missing && identical(z$value, sigma), logical(1))),
            length(result$returned) >= 1L,
            all(vapply(result$returned, function(z) identical(z$value, sigma) &&
                  all(is.na(z$map)) && all(abs(z$parameter - log(sigma)) < 1e-12), logical(1))))
  result$forward_and_map <- TRUE
}, warning = capture_warning), error = function(err) {
  result$error <<- conditionMessage(err)
})
result$warnings <- warnings
result$source_md5_after <- hashes()
result$source_unchanged <- identical(result$source_md5_before, result$source_md5_after)
result$native_md5_after <- unname(tools::md5sum(native))
result$native_unchanged <- identical(native_hash, result$native_md5_after)
saveRDS(result, file.path(out, 'result.rds'))
print(result[c('initial_elapsed','initial_convergence','initial_fixed_sd','bootstrap_elapsed',
               'boot_n_failed','entry','returned','forward_and_map','error',
               'source_unchanged','native_unchanged','warnings')])
if (!isTRUE(result$forward_and_map) || !isTRUE(result$source_unchanged) ||
    !isTRUE(result$native_unchanged)) quit(status = 1L)
cat('BOOTSTRAP_FORWARD_MAP_PASS\n')
