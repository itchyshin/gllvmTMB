## =============================================================================
## 27 -- ONE REPLICATE, for a DRAC SLURM job array
## =============================================================================
## One array task = one (cell, seed) = 5 arms on the same simulated data.
## Writes a single-row-per-arm CSV so a killed array leaves every completed task
## intact; the collector (`27-drac-collect.R`) merges them.
##
## Env contract (set by the submit script):
##   CELL_FAMILY, CELL_N, CELL_LAM   -- the cell
##   SLURM_ARRAY_TASK_ID             -- 1..NSIM, indexes the seed
##   OUTDIR                          -- where to write results
##
## THE DGP AND ARMS MUST MATCH `24-estimator-campaign.R` EXACTLY. They are copied
## rather than sourced (that file does devtools::load_all and drives its own grid),
## so divergence is a real risk -- guarded by an executable checksum below, not by
## a promise.
## =============================================================================
suppressWarnings(suppressMessages(library(gllvmTMB)))

FAM  <- Sys.getenv("CELL_FAMILY", "binomial")
N    <- as.integer(Sys.getenv("CELL_N", "100"))
LAM  <- as.numeric(Sys.getenv("CELL_LAM", "1"))
TASK <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID", "1"))
OUTDIR <- Sys.getenv("OUTDIR", ".")
MASTER_SEED <- 20260731L
P <- 6L; Q <- 2L

## Seeds derived ONCE from the master, exactly as the local runner does, so a DRAC
## replicate and a local replicate with the same index are the SAME dataset.
set.seed(MASTER_SEED)
seed_pool <- sample.int(.Machine$integer.max, 100000L)
cell_id <- paste(FAM, N, LAM, sep = "-")
offset <- switch(cell_id,
  "binomial-100-1" = 0L, "binomial-100-3" = 1000L,
  "binomial-400-1" = 2000L, "binomial-400-3" = 3000L,
  "binomial-1600-1" = 4000L, "binomial-1600-3" = 5000L,
  "gaussian-100-1" = 6000L, "gaussian-1600-1" = 7000L,
  "poisson-100-1"  = 8000L, "poisson-1600-1"  = 9000L,
  stop("unknown cell: ", cell_id))
SEED <- seed_pool[offset + TASK]

mk <- function(n, p, q, lam_sd, seed, family) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- switch(family,
    binomial = matrix(rbinom(n * p, 1, plogis(eta)), n, p),
    poisson  = matrix(rpois(n * p, exp(pmin(eta, 8))), n, p),
    gaussian = matrix(rnorm(n * p, eta, 1), n, p),
    stop("unsupported family: ", family))
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt, b = b)
}

## ---- DGP CHECKSUM: proves this file's mk() still matches the local runner's ----
## Value computed from 24-estimator-campaign.R's mk() at these exact arguments. If
## either DGP is edited, this fails LOUDLY here rather than producing a campaign
## silently measuring a different model.
.chk <- mk(25L, 3L, 1L, 1, 424242L, "binomial")
.got <- sum(as.matrix(.chk$df[, paste0("sp", 1:3)])) + round(sum(.chk$Lt), 6)
.want <- as.numeric(Sys.getenv("DGP_CHECKSUM", "NA"))
if (is.finite(.want) && abs(.got - .want) > 1e-9) {
  stop(sprintf("DGP CHECKSUM MISMATCH: got %.6f, expected %.6f -- this runner's mk() has diverged from 24-estimator-campaign.R", .got, .want))
}
cat(sprintf("dgp checksum %.6f (expected %s)\n", .got, Sys.getenv("DGP_CHECKSUM", "unset")))

fam_obj <- function(f) switch(f, binomial = binomial(), poisson = poisson(), gaussian = gaussian())
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

ARM_CTL <- list(
  laplace       = function() gllvmTMBcontrol(),
  laplace_ridge = function() gllvmTMBcontrol(aghq_ridge = 2),
  aghq_single   = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf, aghq_multistart = FALSE),
  aghq          = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf),
  aghq_ridge    = function() gllvmTMBcontrol(aghq = 9)
)

d  <- mk(N, P, Q, LAM, SEED, FAM)
St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St))
off <- upper.tri(Rt); nrmT <- norm(d$Lt, "F"); fam <- fam_obj(FAM)

fits <- list(); rows <- list()
for (arm in names(ARM_CTL)) {
  t0 <- Sys.time()
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = fam, control = ARM_CTL[[arm]]())),
                error = function(e) structure(list(msg = conditionMessage(e)), class = "failed"))
  el <- as.numeric(Sys.time() - t0, units = "secs")
  if (inherits(f, "failed")) {
    rows[[arm]] <- data.frame(arm = arm, ok = FALSE, fail_msg = substr(f$msg, 1, 150),
                              converged = FALSE, elapsed_s = el, stringsAsFactors = FALSE)
    next
  }
  fits[[arm]] <- f
  L  <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  Sh <- L %*% t(L); Rh <- corr_of(Sh)
  rows[[arm]] <- data.frame(
    arm = arm, ok = TRUE, fail_msg = NA_character_,
    obj = tryCatch(as.numeric(f$opt$objective), error = function(e) NA_real_),
    conv = tryCatch(as.integer(f$opt$convergence), error = function(e) NA_integer_),
    ## `aghq$converged` is the field; opt$convergence is the per-pass iteration cap.
    converged = if (isTRUE(f$aghq$used)) isTRUE(f$aghq$converged) else isTRUE(f$opt$convergence == 0),
    stop_reason = tryCatch(as.character(f$aghq$stop_reason %||% NA_character_), error = function(e) NA_character_),
    n_starts = tryCatch(as.integer(f$aghq$n_starts %||% NA_integer_), error = function(e) NA_integer_),
    aghq_used = isTRUE(f$aghq$used),
    rho_mae  = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),
    rho_bias = mean(Rh[off] - Rt[off], na.rm = TRUE),
    rho_rmse = sqrt(mean((Rh[off] - Rt[off])^2, na.rm = TRUE)),
    sigma_rat = median(sqrt(diag(Sh)) / sg_t),
    frob_rat  = norm(L, "F") / nrmT,
    lambda_hat = paste(signif(as.numeric(L), 8), collapse = "|"),
    elapsed_s = el, stringsAsFactors = FALSE)
}

pshift <- NA_real_
if (!is.null(fits$laplace) && !is.null(fits$aghq) &&
    identical(names(fits$laplace$opt$par), names(fits$aghq$opt$par))) {
  pshift <- max(abs(fits$laplace$opt$par - fits$aghq$opt$par))
}
out <- do.call(rbind, lapply(rows, function(r) {
  for (nm in c("obj","conv","stop_reason","n_starts","aghq_used","rho_mae","rho_bias",
               "rho_rmse","sigma_rat","frob_rat","lambda_hat")) if (is.null(r[[nm]])) r[[nm]] <- NA
  r
}))
out <- cbind(family = FAM, n = N, p = P, q = Q, lam_sd = LAM, task = TASK, seed = SEED,
             out, par_shift = pshift,
             lambda_true = paste(signif(as.numeric(d$Lt), 8), collapse = "|"), row.names = NULL)
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)
write.csv(out, file.path(OUTDIR, sprintf("%s_task%05d.csv", cell_id, TASK)), row.names = FALSE)
cat(sprintf("done: %s task %d seed %d, %d arms, %.1f s total\n",
            cell_id, TASK, SEED, nrow(out), sum(out$elapsed_s)))
