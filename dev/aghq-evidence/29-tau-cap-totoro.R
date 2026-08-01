## =============================================================================
## 29 -- #847 paired scale-aware tau campaign (Totoro, resumable)
## =============================================================================
## The pilot is ALWAYS unpenalised multi-start AGHQ on the default Bernoulli
## grammar. Plain Laplace and penalised pilots are deliberately absent.
##
## PHASE=smoke      NSIM=1   CORES=6
## PHASE=selection  NSIM=100 CORES<=100   candidates 5,6,8 + uncapped
## PHASE=confirm    NSIM=200 CORES<=100 LOCKED_CAP=<selected cap>
##
## Each replicate writes its own CSV before returning. Re-running skips complete
## files, so interruption retains all finished fits. Bulk results stay on Totoro;
## only aggregate evidence and receipts return to the repository.

suppressWarnings(suppressMessages(library(gllvmTMB)))
suppressWarnings(suppressMessages(library(parallel)))

PHASE <- Sys.getenv("PHASE", "smoke")
NSIM <- as.integer(Sys.getenv(
  "NSIM", switch(PHASE, smoke = "1", selection = "100", confirm = "200")
))
CORES <- min(100L, as.integer(Sys.getenv("CORES", "6")))
OUTDIR <- Sys.getenv("OUTDIR", file.path(tempdir(), "gllvmtmb-tau-29"))
LOCKED_CAP <- suppressWarnings(as.numeric(Sys.getenv("LOCKED_CAP", "NA")))
N_VALUES <- as.integer(strsplit(Sys.getenv(
  "N_VALUES", if (PHASE == "smoke") "100" else "100,400,1600"
), ",", fixed = TRUE)[[1L]])
LAM_VALUES <- as.numeric(strsplit(Sys.getenv(
  "LAM_VALUES", if (PHASE == "smoke") "1" else "1,3"
), ",", fixed = TRUE)[[1L]])
MASTER_SEED <- 20260801L
P <- 6L
Q <- 2L

if (!PHASE %in% c("smoke", "selection", "confirm")) {
  stop("PHASE must be smoke, selection, or confirm")
}
if (PHASE == "confirm" && (!is.finite(LOCKED_CAP) || LOCKED_CAP <= 0)) {
  stop("confirmation requires a positive finite LOCKED_CAP")
}
if (!is.finite(NSIM) || NSIM < 1L || !is.finite(CORES) || CORES < 1L) {
  stop("NSIM and CORES must be positive integers")
}
if (!length(N_VALUES) || !all(N_VALUES %in% c(100L, 400L, 1600L)) ||
    !length(LAM_VALUES) || !all(LAM_VALUES %in% c(1, 3))) {
  stop("N_VALUES and LAM_VALUES must select from the locked campaign grid")
}

expected_arms <- if (PHASE == "confirm") {
  c(
    "fixed2_shipped", "pilot_unpenalised", "fixed2_pilot",
    paste0("auto_cap", format(LOCKED_CAP, trim = TRUE))
  )
} else {
  c(
    "fixed2_shipped", "pilot_unpenalised", "fixed2_pilot",
    "auto_uncapped", "auto_cap5", "auto_cap6", "auto_cap8"
  )
}

## The installed binary, not the source checkout, executes the campaign. Require
## an explicit marker created only after installing this exact commit into its
## private library; a matching working-tree SHA alone would not prove that the
## loaded shared object came from the same source.
expected_sha <- Sys.getenv("PACKAGE_SHA", "")
pkg_path <- normalizePath(system.file(package = "gllvmTMB"), mustWork = TRUE)
sha_marker <- file.path(pkg_path, "CAMPAIGN_GIT_SHA")
installed_sha <- if (file.exists(sha_marker)) trimws(readLines(sha_marker, n = 1L)) else ""
source_sha <- paste(system("git rev-parse HEAD", intern = TRUE), collapse = "")
if (!nzchar(expected_sha) || !identical(installed_sha, expected_sha) ||
    !identical(source_sha, expected_sha)) {
  stop(sprintf(
    paste0("PACKAGE PROVENANCE MISMATCH: expected=%s installed-marker=%s ",
           "source=%s path=%s"),
    expected_sha, installed_sha, source_sha, pkg_path
  ))
}
pkg_description <- readLines(file.path(pkg_path, "DESCRIPTION"), warn = FALSE)
pkg_built <- grep("^Built:", pkg_description, value = TRUE)
pkg_built <- if (length(pkg_built)) sub("^Built:\\s*", "", pkg_built[[1L]]) else NA_character_

phase_dir <- file.path(OUTDIR, PHASE)
dir.create(phase_dir, recursive = TRUE, showWarnings = FALSE)

required_task_columns <- c(
  "phase", "n", "lam_sd", "task", "seed", "arm", "ok", "converged",
  "aghq_used", "tau_raw", "tau_used", "tau_cap", "tau_clipped",
  "rho_mae", "frob_rat", "loading_log_error", "package_sha"
)
valid_task_file <- function(path) {
  if (!file.exists(path)) return(FALSE)
  x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  !is.null(x) && nrow(x) == length(expected_arms) &&
    all(required_task_columns %in% names(x)) && !anyDuplicated(x$arm) &&
    setequal(x$arm, expected_arms) && all(x$phase == PHASE) &&
    all(x$package_sha == expected_sha)
}

mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt <- matrix(stats::rnorm(p * q, 0, lam_sd), p, q)
  u <- matrix(stats::rnorm(n * q), n, q)
  b <- stats::rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  ## DEFAULT grammar on purpose. Arc 0 proves this is loadings-only only when
  ## every automatic Bernoulli Psi is structurally pinned.
  fml <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d)",
    paste(colnames(Y), collapse = ", "), q
  ))
  list(df = df, fml = fml, Lt = Lt, b = b)
}

## Executable DGP guard. This value comes from the original estimator campaign's
## own mk() at the same arguments; formula grammar is deliberately not part of
## the checksum because Arc 0 proves the default and unique=FALSE objectives are
## identical when all automatic Bernoulli Psi coordinates are pinned.
.chk <- mk(25L, 3L, 1L, 1, 424242L)
.got <- sum(as.matrix(.chk$df[, paste0("sp", 1:3)])) + round(sum(.chk$Lt), 6)
.want <- 43.170363
if (abs(.got - .want) > 1e-9) {
  stop(sprintf(
    "DGP CHECKSUM MISMATCH: got %.6f, expected %.6f; campaign stopped",
    .got, .want
  ))
}

corr_of <- function(S) {
  d <- sqrt(diag(S))
  d[d <= 0] <- NA_real_
  S / outer(d, d)
}

fit_one <- function(d, tau, start_from = NULL) {
  ctl <- gllvmTMBcontrol(
    aghq = 9L,
    aghq_ridge = tau,
    aghq_multistart = TRUE,
    start_from = start_from,
    se = FALSE,
    warn_runaway = FALSE
  )
  suppressMessages(suppressWarnings(gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(), control = ctl
  )))
}

metric_row <- function(fit, arm, tau_raw, tau_used, tau_cap, elapsed,
                       Lt, pilot = NULL) {
  L <- fit$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  St <- Lt %*% t(Lt)
  Sh <- L %*% t(L)
  Rt <- corr_of(St)
  Rh <- corr_of(Sh)
  off <- upper.tri(Rt)
  data.frame(
    arm = arm,
    ok = TRUE,
    fail_msg = NA_character_,
    obj = tryCatch(as.numeric(fit$opt$objective), error = function(e) NA_real_),
    converged = if (isTRUE(fit$aghq$used)) isTRUE(fit$aghq$converged) else
      isTRUE(fit$opt$convergence == 0),
    aghq_used = isTRUE(fit$aghq$used),
    n_starts = tryCatch(as.integer(fit$aghq$n_starts), error = function(e) NA_integer_),
    stop_reason = tryCatch(as.character(fit$aghq$stop_reason),
                           error = function(e) NA_character_),
    tau_raw = tau_raw,
    tau_used = tau_used,
    tau_cap = tau_cap,
    tau_clipped = is.finite(tau_cap) && tau_raw > tau_cap,
    tau_source = switch(
      arm,
      pilot_unpenalised = "unpenalised_multistart_aghq",
      fixed2_shipped = "fixed2_shipped_start",
      fixed2_pilot = "fixed2_pilot_start",
      "pilot_unpenalised_multistart_aghq"
    ),
    pilot_ok = !is.null(pilot),
    pilot_converged = if (is.null(pilot)) NA else isTRUE(pilot$aghq$converged),
    pilot_k = if (is.null(pilot)) NA_integer_ else as.integer(pilot$aghq$k),
    pilot_n_starts = if (is.null(pilot)) NA_integer_ else as.integer(pilot$aghq$n_starts),
    rho_mae = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),
    rho_bias = mean(Rh[off] - Rt[off], na.rm = TRUE),
    frob_rat = norm(L, "F") / norm(Lt, "F"),
    loading_log_error = abs(log(norm(L, "F") / norm(Lt, "F"))),
    lambda_hat = paste(signif(as.numeric(L), 8), collapse = "|"),
    elapsed_s = elapsed,
    stringsAsFactors = FALSE
  )
}

failure_row <- function(arm, message, tau_raw = NA_real_, tau_used = NA_real_,
                        tau_cap = NA_real_, elapsed = NA_real_, pilot = NULL) {
  data.frame(
    arm = arm, ok = FALSE, fail_msg = substr(message, 1L, 180L),
    obj = NA_real_, converged = FALSE, aghq_used = FALSE,
    n_starts = NA_integer_, stop_reason = NA_character_,
    tau_raw = tau_raw, tau_used = tau_used, tau_cap = tau_cap,
    tau_clipped = is.finite(tau_cap) && is.finite(tau_raw) && tau_raw > tau_cap,
    tau_source = if (arm == "fixed2_shipped")
      "fixed2_shipped_start" else "pilot_unpenalised_multistart_aghq",
    pilot_ok = !is.null(pilot),
    pilot_converged = if (is.null(pilot)) NA else isTRUE(pilot$aghq$converged),
    pilot_k = if (is.null(pilot)) NA_integer_ else as.integer(pilot$aghq$k),
    pilot_n_starts = if (is.null(pilot)) NA_integer_ else as.integer(pilot$aghq$n_starts),
    rho_mae = NA_real_, rho_bias = NA_real_, frob_rat = NA_real_,
    loading_log_error = NA_real_, lambda_hat = NA_character_,
    elapsed_s = elapsed, stringsAsFactors = FALSE
  )
}

run_job <- function(job) {
  cell <- sprintf("n%d-lam%d", job$n, job$lam_sd)
  target <- file.path(
    phase_dir,
    sprintf("%s_task%04d_seed%d.csv", cell, job$task, job$seed)
  )
  if (valid_task_file(target)) return(target)
  if (file.exists(target)) {
    stop("existing task file is incomplete or invalid: ", target)
  }

  d <- mk(job$n, P, Q, job$lam_sd, job$seed)
  rows <- list()

  ## Operational comparator: this is the currently shipped AGHQ tau=2 route,
  ## independent of whether the extra calibration pilot succeeds.
  t0 <- proc.time()[["elapsed"]]
  shipped <- tryCatch(fit_one(d, 2, start_from = NULL), error = function(e) e)
  shipped_elapsed <- proc.time()[["elapsed"]] - t0
  rows[[length(rows) + 1L]] <- if (inherits(shipped, "error")) {
    failure_row("fixed2_shipped", conditionMessage(shipped),
                tau_used = 2, tau_cap = 2, elapsed = shipped_elapsed)
  } else {
    metric_row(shipped, "fixed2_shipped", NA_real_, 2, 2,
               shipped_elapsed, d$Lt)
  }

  t0 <- proc.time()[["elapsed"]]
  pilot <- tryCatch(fit_one(d, Inf), error = function(e) e)
  pilot_elapsed <- proc.time()[["elapsed"]] - t0
  pilot_problem <- if (inherits(pilot, "error")) {
    conditionMessage(pilot)
  } else if (!isTRUE(pilot$aghq$used)) {
    "pilot did not use AGHQ"
  } else if (!isTRUE(pilot$aghq$converged)) {
    "pilot AGHQ did not converge"
  } else if (length(pilot$aghq$n_starts) != 1L ||
             !is.finite(pilot$aghq$n_starts) || pilot$aghq$n_starts < 2L) {
    "pilot did not complete multi-start AGHQ"
  } else if (!identical(as.numeric(pilot$aghq$ridge_tau), Inf)) {
    "pilot AGHQ was not unpenalised"
  } else {
    NULL
  }

  tau_raw <- NA_real_
  if (is.null(pilot_problem)) {
    Lp <- pilot$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
    tau_raw <- max(1, norm(Lp, "F") / sqrt(P * Q))
    if (!is.finite(tau_raw)) {
      pilot_problem <- "pilot loading scale is non-finite"
    } else {
      rows[[length(rows) + 1L]] <- metric_row(
        pilot, "pilot_unpenalised", tau_raw, Inf, Inf,
        pilot_elapsed, d$Lt, pilot
      )
    }
  }
  if (!is.null(pilot_problem)) {
    rows[[length(rows) + 1L]] <- failure_row(
      "pilot_unpenalised", pilot_problem, elapsed = pilot_elapsed,
      pilot = if (inherits(pilot, "error")) NULL else pilot
    )
  }

  if (!is.null(pilot_problem)) {
    specs <- data.frame(
      arm = "fixed2_pilot", cap = 2, stringsAsFactors = FALSE
    )
    if (PHASE != "confirm") {
      specs <- rbind(specs, data.frame(
        arm = c("auto_uncapped", "auto_cap5", "auto_cap6", "auto_cap8"),
        cap = c(Inf, 5, 6, 8), stringsAsFactors = FALSE
      ))
    } else {
      specs <- rbind(specs, data.frame(
        arm = paste0("auto_cap", format(LOCKED_CAP, trim = TRUE)),
        cap = LOCKED_CAP, stringsAsFactors = FALSE
      ))
    }
    for (i in seq_len(nrow(specs))) {
      rows[[length(rows) + 1L]] <- failure_row(
        specs$arm[i], paste0("invalid pilot; final fit not attempted: ", pilot_problem),
        tau_cap = specs$cap[i]
      )
    }
  } else {
    specs <- data.frame(
      arm = "fixed2_pilot", cap = 2, use_pilot = TRUE,
      stringsAsFactors = FALSE
    )
    if (PHASE != "confirm") {
      specs <- rbind(specs, data.frame(
        arm = c("auto_uncapped", "auto_cap5", "auto_cap6", "auto_cap8"),
        cap = c(Inf, 5, 6, 8), use_pilot = TRUE,
        stringsAsFactors = FALSE
      ))
    } else {
      specs <- rbind(specs, data.frame(
        arm = paste0("auto_cap", format(LOCKED_CAP, trim = TRUE)),
        cap = LOCKED_CAP, use_pilot = TRUE,
        stringsAsFactors = FALSE
      ))
    }

    for (i in seq_len(nrow(specs))) {
      tau_used <- if (specs$arm[i] == "fixed2_pilot") {
        2
      } else if (is.finite(specs$cap[i])) {
        min(specs$cap[i], tau_raw)
      } else {
        tau_raw
      }
      start <- if (isTRUE(specs$use_pilot[i])) pilot else NULL
      t0 <- proc.time()[["elapsed"]]
      fit <- tryCatch(fit_one(d, tau_used, start_from = start), error = function(e) e)
      elapsed <- proc.time()[["elapsed"]] - t0
      rows[[length(rows) + 1L]] <- if (inherits(fit, "error")) {
        failure_row(
          specs$arm[i], conditionMessage(fit), tau_raw, tau_used,
          specs$cap[i], elapsed, pilot
        )
      } else {
        metric_row(
          fit, specs$arm[i], tau_raw, tau_used, specs$cap[i],
          elapsed, d$Lt, pilot
        )
      }
    }
  }

  out <- do.call(rbind, rows)
  out <- cbind(
    phase = PHASE, n = job$n, p = P, q = Q, lam_sd = job$lam_sd,
    task = job$task, seed = job$seed, out,
    lambda_true = paste(signif(as.numeric(d$Lt), 8), collapse = "|"),
    package_sha = expected_sha, package_path = pkg_path,
    package_version = as.character(utils::packageVersion("gllvmTMB")),
    package_built = pkg_built,
    row.names = NULL
  )
  if (!setequal(out$arm, expected_arms) || anyDuplicated(out$arm)) {
    stop("internal arm-set mismatch before task write")
  }
  tmp <- paste0(target, ".tmp-", Sys.getpid())
  utils::write.csv(out, tmp, row.names = FALSE)
  if (!file.rename(tmp, target)) stop("atomic task-file rename failed: ", target)
  if (!valid_task_file(target)) stop("task file failed post-write validation: ", target)
  target
}

cells <- expand.grid(
  n = N_VALUES, lam_sd = LAM_VALUES,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
## Confirmation uses a disjoint half of one pre-generated seed pool.
set.seed(MASTER_SEED)
seed_pool <- sample.int(.Machine$integer.max, 50000L)
phase_offset <- if (PHASE == "confirm") 20000L else 0L
jobs <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  idx <- phase_offset + (i - 1L) * 2000L + seq_len(NSIM)
  cbind(
    cells[rep(i, NSIM), , drop = FALSE],
    task = seq_len(NSIM), seed = seed_pool[idx], row.names = NULL
  )
}))

cat(sprintf(
  "phase=%s | dgp=%.6f | package=%s | %d cells x %d seeds | %d jobs | %d cores | git=%s\n",
  PHASE, .got, as.character(utils::packageVersion("gllvmTMB")),
  nrow(cells), NSIM, nrow(jobs), CORES,
  paste(system("git rev-parse --short HEAD", intern = TRUE), collapse = "")
))
t0 <- Sys.time()
paths <- parallel::mclapply(
  seq_len(nrow(jobs)),
  function(i) tryCatch(run_job(jobs[i, ]), error = function(e) {
    warning(sprintf("job %d failed outside fit capture: %s", i, conditionMessage(e)))
    NA_character_
  }),
  mc.cores = CORES, mc.preschedule = FALSE
)
paths <- unlist(paths, use.names = FALSE)
if (length(paths) != nrow(jobs) || anyNA(paths) || anyDuplicated(paths) ||
    !all(vapply(paths, function(p) !is.na(p) && valid_task_file(p), logical(1)))) {
  stop(sprintf(
    "campaign incomplete: %d/%d valid unique task files; aggregation refused",
    sum(!is.na(paths) & vapply(paths, function(p) !is.na(p) && valid_task_file(p), logical(1))),
    nrow(jobs)
  ))
}
combined <- do.call(rbind, lapply(paths, utils::read.csv, stringsAsFactors = FALSE))
if (nrow(combined) != nrow(jobs) * length(expected_arms) ||
    anyDuplicated(combined[c("phase", "n", "lam_sd", "task", "seed", "arm")])) {
  stop("combined campaign rows are incomplete or duplicated; output refused")
}
combined_path <- file.path(OUTDIR, sprintf("29-tau-cap-%s.csv", PHASE))
combined_tmp <- paste0(combined_path, ".tmp-", Sys.getpid())
utils::write.csv(combined, combined_tmp, row.names = FALSE)
if (!file.rename(combined_tmp, combined_path)) stop("combined-file rename failed")
saveRDS(utils::sessionInfo(), file.path(OUTDIR, sprintf("29-%s-sessionInfo.rds", PHASE)))
utils::write.csv(data.frame(
  phase = PHASE, package_sha = expected_sha, package_path = pkg_path,
  package_version = as.character(utils::packageVersion("gllvmTMB")),
  package_built = pkg_built, dgp_checksum = .got,
  jobs = nrow(jobs), arms = length(expected_arms), stringsAsFactors = FALSE
), file.path(OUTDIR, sprintf("29-%s-provenance.csv", PHASE)), row.names = FALSE)
cat(sprintf(
  "completed %d/%d jobs, %d fit rows, %.1f minutes -> %s\n",
  length(paths), nrow(jobs), nrow(combined),
  as.numeric(Sys.time() - t0, units = "mins"), combined_path
))
