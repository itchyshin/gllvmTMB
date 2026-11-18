library(gllvmTMB, lib.loc = '/tmp/gllvm-baseline-abf3-GJqzkU-lib')
## Unreplicated two-kernel coevolution with a fixed Gaussian observation SD.
## This is a small construction/objective oracle, not a recovery simulation.

.two_lineage_known_error_fixture <- function(identical_kernels = FALSE,
                                            cross_block_only = FALSE) {
  n_side <- 8L
  species <- c(paste0("H", seq_len(n_side)), paste0("P", seq_len(n_side)))
  A <- 0.6 ^ abs(outer(seq_len(n_side), seq_len(n_side), `-`))
  I <- diag(n_side)
  K_phy <- rbind(cbind(A, 0.55 * A), cbind(0.55 * A, A))
  K_tip <- rbind(cbind(I, 0.55 * I), cbind(0.55 * I, I))
  if (identical_kernels) K_tip <- K_phy
  if (cross_block_only) {
    K_phy <- rbind(cbind(A, 0.2 * A), cbind(0.2 * A, A))
    K_tip <- rbind(cbind(A, 0.1 * I), cbind(0.1 * I, A))
  }
  dimnames(K_phy) <- dimnames(K_tip) <- list(species, species)

  dat <- data.frame(
    species = factor(species, levels = species),
    row_id = factor(species, levels = species),
    H1 = c(sin(seq_len(n_side)), rep(NA_real_, n_side)),
    H2 = c(cos(seq_len(n_side)), rep(NA_real_, n_side)),
    P1 = c(rep(NA_real_, n_side), sin(seq_len(n_side) + 0.3)),
    P2 = c(rep(NA_real_, n_side), cos(seq_len(n_side) + 0.3))
  )
  list(data = dat, K_phy = K_phy, K_tip = K_tip, species = species)
}

.capture_two_lineage_known_error_tmb <- function(args) {
  capture_name <- ".gllvmTMB_known_error_capture"
  old <- get0(capture_name, envir = .GlobalEnv, inherits = FALSE)
  assign(capture_name, NULL, envir = .GlobalEnv)
  traced <- FALSE
  on.exit({
    if (traced) untrace("MakeADFun", where = asNamespace("TMB"))
    if (is.null(old)) {
      if (exists(capture_name, envir = .GlobalEnv, inherits = FALSE))
        rm(list = capture_name, envir = .GlobalEnv)
    } else {
      assign(capture_name, old, envir = .GlobalEnv)
    }
  }, add = TRUE)
  tracer <- substitute({
    assign(NAME, list(data = data, parameters = parameters, map = map,
                      random = random, DLL = DLL), envir = .GlobalEnv)
    stop("TWO_LINEAGE_KNOWN_ERROR_CAPTURE", call. = FALSE)
  }, list(NAME = capture_name))
  trace("MakeADFun", where = asNamespace("TMB"), tracer = tracer,
        print = FALSE)
  traced <- TRUE
  warning_text <- character()
  err <- tryCatch({
    withCallingHandlers(do.call(gllvmTMB, args), warning = function(w) {
      warning_text <<- c(warning_text, conditionMessage(w))
      invokeRestart('muffleWarning')
    })
    NULL
  }, error = conditionMessage)
  list(error = err,
       warnings = warning_text,
       captured = get(capture_name, envir = .GlobalEnv, inherits = FALSE))
}

.two_lineage_known_error_args <- function(fixture, known_sigma_eps = NULL) {
  K_phy <- fixture$K_phy
  K_tip <- fixture$K_tip
  formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = TRUE)",
    env = environment()
  )
  args <- list(
    formula = formula,
    data = fixture$data,
    family = gaussian(),
    unit = "row_id",
    cluster = "species",
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )
  if (!is.null(known_sigma_eps)) args$known_sigma_eps <- known_sigma_eps
  args
}

fixture <- .two_lineage_known_error_fixture()
args <- .two_lineage_known_error_args(fixture)
cat('PACKAGE_PATH=', find.package('gllvmTMB'), '\n', sep='')
cat('REQUESTED_UNIQUE=TRUE,TRUE\n')
out <- .capture_two_lineage_known_error_tmb(args)
cat('CAPTURE_ERROR=', out$error, '\n', sep='')
cat('WARNINGS=', paste(out$warnings, collapse=' | '), '\n', sep='')
if (is.null(out$captured)) stop('No MakeADFun capture: ', out$error)
cat('KERNEL_HAS_DIAG=', paste(out$captured$data$kernel_has_diag, collapse=','), '\n', sep='')
cat('MASK_OBSERVED=', sum(out$captured$data$is_y_observed == 1L), '\n', sep='')
cat('MASK_MISSING=', sum(out$captured$data$is_y_observed == 0L), '\n', sep='')
stopifnot(identical(as.integer(out$captured$data$kernel_has_diag), c(0L, 0L)))
cat('BASELINE_SILENT_OMISSION_REPRODUCED\n')
