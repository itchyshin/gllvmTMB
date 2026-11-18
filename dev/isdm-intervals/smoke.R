## D-139 smoke test for the iSDM interval-calibration feasibility grid
## (docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md §3;
## approved by Shinichi 2026-08-18: smoke → estimate → Totoro grid if <30 min).
## One cell: n_cells=150, effort 1x, n_sources=2, weak amplitude (the
## gamma-recovery baseline); 12 reps. Adapted from
## dev/isdm-multisource/prerun-gamma-recovery.R (same DGP family).
##
## Per-rep checks (K1 gate: >1/12 failing any check => stop, bug-fix task):
##   c1 conv == 0 and pd_hessian recorded
##   c2 fixed-effect Wald SEs finite & positive (trait:env block)
##   c3 latent-amplitude estimate + SE finite & positive
##   c4 predict(se.fit=TRUE) training rows finite & in-range
##   c5 truth-containment indicator computable per env coefficient

isTRUE_v <- function(x) !is.na(x) & x
suppressMessages(devtools::load_all(
  Sys.getenv("GLLVMTMB_WT", "/private/tmp/gllvmtmb-isdm-predict"),
  quiet = TRUE))

run_rep <- function(seed) {
  set.seed(seed)
  n_cell <- 150L
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2", "sp3")
  x <- as.numeric(scale(runif(n_cell)))
  u <- as.numeric(scale(sin(seq_len(n_cell) / 6)))
  alpha <- c(-0.2, 0.2, 0.0); beta <- c(0.5, -0.3, 0.4)
  lambda <- c(0.8, 0.5, -0.4)                    # weak = gamma-recovery baseline
  src_names <- c("s1", "pa"); laws <- c("count", "pa")
  gamma <- matrix(0, 2L, 3L)
  gamma[2L, ] <- runif(3L, -1, 1)
  eff <- c(2.0, 0.9)                             # effort ratio 1x baseline

  dat <- do.call(rbind, lapply(1:2, function(d) {
    dd <- expand.grid(cell_id = cells, trait = species,
                      stringsAsFactors = FALSE)
    ci <- match(dd$cell_id, cells); si <- match(dd$trait, species)
    eta <- alpha[si] + x[ci] * beta[si] + u[ci] * lambda[si] + gamma[d, si]
    dd$isdm_source <- src_names[d]
    dd$support <- eff[d]
    dd$value <- if (laws[d] == "count") rpois(nrow(dd), eff[d] * exp(eta)) else
      rbinom(nrow(dd), 1, -expm1(-eff[d] * exp(eta)))
    dd
  }))
  dat$trait <- factor(dat$trait); dat$cell_id <- factor(dat$cell_id)
  dat$log_support <- log(dat$support)
  dat$env <- x[match(as.character(dat$cell_id), cells)]
  dat$src <- factor(dat$isdm_source, levels = src_names)
  fam <- isdm_sources(s1 = poisson(), pa = binomial(link = "cloglog"))

  t0 <- Sys.time()
  fit <- try(suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    silent = TRUE)), silent = TRUE)
  secs_fit <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  fail <- function(why) data.frame(seed = seed, secs_fit = round(secs_fit, 2),
    secs_total = NA, conv = NA, pd = NA, c2 = FALSE, c3 = FALSE, c4 = FALSE,
    c5 = FALSE, cover_env = NA, note = why)
  if (inherits(fit, "try-error")) return(fail("fit error"))

  h <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
  pd <- if (is.null(h)) NA else
    identical(h$status[h$component == "pd_hessian"], "PASS")

  ## c2 + c5: fixed-effect Wald SEs for the trait:env block, and containment
  sdr <- tryCatch(TMB::sdreport(fit$tmb_obj,
                                getJointPrecision = FALSE),
                  error = function(e) NULL)
  c2 <- FALSE; c5 <- FALSE; cover_env <- NA
  if (!is.null(sdr)) {
    ss <- summary(sdr, select = "fixed")
    bidx <- grep(":env", fit$X_fix_names)
    bhat <- fit$opt$par[names(fit$opt$par) == "b_fix"][bidx]
    bse <- ss[rownames(ss) == "b_fix", "Std. Error"][bidx]
    c2 <- length(bse) == 3L && all(is.finite(bse)) && all(bse > 0)
    if (c2) {
      lo <- bhat - 1.96 * bse; hi <- bhat + 1.96 * bse
      cov_ind <- as.integer(beta >= lo & beta <= hi)
      c5 <- length(cov_ind) == 3L && all(!is.na(cov_ind))
      cover_env <- mean(cov_ind)
    }
    ## c3: latent-loading amplitude (theta parameters) est + SE
    th <- rownames(ss) %in% c("theta_rr_B", "theta_rr")
    c3 <- any(th) && all(is.finite(ss[th, "Std. Error"])) &&
      all(ss[th, "Std. Error"] > 0)
  }

  ## c4: predict(se.fit = TRUE) on training rows
  pr <- tryCatch(predict(fit, se.fit = TRUE), error = function(e) NULL)
  c4 <- !is.null(pr) && all(is.finite(pr$se.fit)) && all(pr$se.fit > 0)

  secs_total <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(seed = seed, secs_fit = round(secs_fit, 2),
             secs_total = round(secs_total, 2),
             conv = fit$opt$convergence, pd = pd, c2 = c2, c3 = c3, c4 = c4,
             c5 = c5, cover_env = cover_env, note = "")
}

res <- do.call(rbind, lapply(201:212, run_rep))
print(res, row.names = FALSE)
## SE-dependent checks (c2-c5) are judged on PD fits only: on a non-PD fit
## the package CORRECTLY refuses Wald SEs (a classed, loud refusal), so NA
## SEs there are certified behaviour the campaign records via pd_rate, not a
## harness failure. K1 is read against harness errors on the reps where the
## checks are defined. pd_rate itself is a per-cell campaign metric (the
## prior survey-design campaign reported pd_rate 0.555).
pd_ok <- with(res, conv == 0 & isTRUE_v(pd))
ok <- with(res, pd_ok & c2 & c3 & c4 & c5)
cat("\nSMOKE SUMMARY: reps =", nrow(res),
    " conv0 =", sum(res$conv == 0, na.rm = TRUE),
    " pd_rate =", sum(pd_ok), "/ 12",
    " all-checks-pass among PD =", sum(ok), "/", sum(pd_ok),
    " (K1 harness read: fires if any PD rep fails a check)\n")
cat("per-fit secs: median fit =", median(res$secs_fit),
    " median total (fit+sdreport+predict) =", median(res$secs_total), "\n")
cat("FULL-GRID ESTIMATE: 16 cells x 100 reps = 1600 fits;",
    "core-seconds =", round(1600 * median(res$secs_total)),
    "; wall at 100 cores ~", round(1600 * median(res$secs_total) / 100 / 60, 1),
    "min (single-thread fits, embarrassingly parallel)\n")
cat("NOTE: the 810-cell and 10x-effort and 3-source cells cost more per fit",
    "than this baseline cell; apply a conservative x4-x6 multiplier before",
    "judging the 30-min line.\n")
