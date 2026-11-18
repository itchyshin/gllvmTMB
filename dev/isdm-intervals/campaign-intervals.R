## iSDM interval-calibration FEASIBILITY grid (approved 2026-08-18; proposal
## docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md).
## Grid: n_cells {150, 810} x eff_ratio {1, 10} x n_sources {2, 3} x
## amplitude {weak = 1x, strong = 2x} x 100 seeds = 1,600 fits.
## Smoke receipt (dev/isdm-intervals/smoke-output.txt): 12/12 conv, pd 10/12,
## all PD reps pass all checks, median 3.2 s/fit -> comfortably under the
## D-139 30-minute line on 100 cores.
## Estimands measured per-cell, per-group (NEVER pooled):
##   E1 env-slope Wald coverage, per species
##   E2 latent-loading amplitude est + SE (coverage only if ADREPORTed SE
##      exists for Lambda; availability recorded, not assumed)
##   E4 predict(se.fit) coverage of TRUE eta on training rows, per arm
##   E3 (intensity ratios) NOT measured: no row-pair covariance is exposed,
##      so no interval is computable today -- that absence is itself a
##      campaign finding, recorded here rather than silently dropped.
suppressMessages(library(gllvmTMB))
suppressMessages(library(parallel))
suppressMessages(library(TMB))

## ---------------------------------------------------------------------------
## Version guard. A campaign pre-registered against one package version and
## silently RUN against another produces numbers that are quietly off-version
## and look completely normal: no error, no warning, plausible magnitudes.
##
## This is not hypothetical. On 2026-08-18 the E1 campaign was one step from
## running against gllvmTMB 0.6.0 from a shared library while the deployment's
## own DESCRIPTION said 0.7.0 -- the source tree and the LOADED package were
## different things, and only the loaded one affects the answer.
##
## So: measure the loaded version, never infer it from the deployment tree,
## and fail CLOSED when the caller states an expectation.
## ---------------------------------------------------------------------------
.gllvm_version <- as.character(utils::packageVersion("gllvmTMB"))
.gllvm_libpath <- dirname(find.package("gllvmTMB"))
cat("gllvmTMB:", .gllvm_version, "from", .gllvm_libpath, "\n")
.expect <- Sys.getenv("CAMPAIGN_EXPECT_VERSION", "")
if (nzchar(.expect) && !identical(.expect, .gllvm_version)) {
  stop(sprintf(
    paste0("campaign version guard: expected gllvmTMB %s but LOADED %s from %s.\n",
           "  The deployment's DESCRIPTION is not evidence of what gets loaded.\n",
           "  Install into a campaign-private library and set R_LIBS to it."),
    .expect, .gllvm_version, .gllvm_libpath
  ), call. = FALSE)
}

run_cell <- function(n_cells_f, eff_ratio, n_sources, amp, seed) {
  set.seed(seed)
  n_cell <- n_cells_f
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2", "sp3")
  x <- as.numeric(scale(runif(n_cell)))
  u <- as.numeric(scale(sin(seq_len(n_cell) / 6)))
  alpha <- c(-0.2, 0.2, 0.0); beta <- c(0.5, -0.3, 0.4)
  lambda <- amp * c(0.8, 0.5, -0.4)
  src_names <- paste0("s", seq_len(n_sources))
  laws <- c(rep("count", n_sources - 1L), "pa")
  gamma <- matrix(0, n_sources, 3L)
  gamma[-1L, ] <- matrix(runif((n_sources - 1L) * 3L, -1, 1),
                         n_sources - 1L, 3L)
  eff <- c(2.0, rep(2.0 / eff_ratio, n_sources - 1L))

  eta_true_row <- NULL
  dat <- do.call(rbind, lapply(seq_len(n_sources), function(d) {
    dd <- expand.grid(cell_id = cells, trait = species,
                      stringsAsFactors = FALSE)
    ci <- match(dd$cell_id, cells); si <- match(dd$trait, species)
    eta <- alpha[si] + x[ci] * beta[si] + u[ci] * lambda[si] + gamma[d, si]
    dd$eta_true <- eta + log(eff[d])   # linear predictor INCLUDING offset
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
  args <- stats::setNames(
    lapply(laws, function(l) if (l == "count") poisson() else
      binomial(link = "cloglog")), src_names)
  fam <- do.call(isdm_sources, args)

  base <- data.frame(n_cells = n_cell, eff_ratio = eff_ratio,
                     n_sources = n_sources, amp = amp, seed = seed)
  t0 <- Sys.time()
  fit <- try(suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    silent = TRUE)), silent = TRUE)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  na9 <- rep(NA_real_, 3L)
  out_fail <- cbind(base, data.frame(secs = round(secs, 2), conv = NA, pd = NA,
    se_ok = FALSE, cov_env_sp1 = NA, cov_env_sp2 = NA, cov_env_sp3 = NA,
    lam_se_ok = NA, lam_report_se = NA,
    cov_eta_po = NA, cov_eta_pa = NA, sefit_ok = NA))
  if (inherits(fit, "try-error")) return(out_fail)

  h <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
  pd <- if (is.null(h)) NA else
    identical(h$status[h$component == "pd_hessian"], "PASS")

  sdr <- tryCatch(TMB::sdreport(fit$tmb_obj, getJointPrecision = FALSE),
                  error = function(e) NULL)
  se_ok <- FALSE; cov_env <- na9; lam_se_ok <- NA; lam_report_se <- NA
  if (!is.null(sdr)) {
    ss <- tryCatch(summary(sdr, select = "fixed"), error = function(e) NULL)
    if (!is.null(ss)) {
      bidx <- grep(":env", fit$X_fix_names)
      bhat <- fit$opt$par[names(fit$opt$par) == "b_fix"][bidx]
      bse <- ss[rownames(ss) == "b_fix", "Std. Error"][bidx]
      se_ok <- length(bse) == 3L && all(is.finite(bse)) && all(bse > 0)
      if (se_ok) {
        cov_env <- as.numeric(beta >= bhat - 1.96 * bse &
                              beta <= bhat + 1.96 * bse)
      }
      th <- rownames(ss) %in% c("theta_rr_B", "theta_rr")
      lam_se_ok <- any(th) && all(is.finite(ss[th, "Std. Error"]))
    }
    ## E2 coverage only if Lambda is ADREPORTed with an SE
    sr <- tryCatch(summary(sdr, select = "report"), error = function(e) NULL)
    lam_report_se <- !is.null(sr) &&
      any(grepl("Lambda", rownames(sr))) &&
      any(is.finite(sr[grepl("Lambda", rownames(sr)), "Std. Error"]))
  }

  ## E4: se.fit coverage of TRUE eta on training rows, per arm
  pr <- tryCatch(predict(fit, se.fit = TRUE), error = function(e) NULL)
  cov_eta_po <- NA_real_; cov_eta_pa <- NA_real_; sefit_ok <- FALSE
  if (!is.null(pr) && all(is.finite(pr$se.fit))) {
    sefit_ok <- TRUE
    hit <- as.numeric(dat$eta_true >= pr$est - 1.96 * pr$se.fit &
                      dat$eta_true <= pr$est + 1.96 * pr$se.fit)
    i_pa <- dat$isdm_source == src_names[n_sources]
    cov_eta_po <- mean(hit[!i_pa]); cov_eta_pa <- mean(hit[i_pa])
  }

  cbind(base, data.frame(secs = round(secs, 2),
    conv = fit$opt$convergence, pd = pd, se_ok = se_ok,
    cov_env_sp1 = cov_env[1], cov_env_sp2 = cov_env[2],
    cov_env_sp3 = cov_env[3], lam_se_ok = lam_se_ok,
    lam_report_se = lam_report_se,
    cov_eta_po = round(cov_eta_po, 4), cov_eta_pa = round(cov_eta_pa, 4),
    sefit_ok = sefit_ok))
}

## Seed block is parameterised (E1 pre-registration, 2026-08-18). Defaults
## reproduce the approved feasibility run BIT-FOR-BIT: seed_base 1001,
## n_rep 100 -> seeds 1001:1100, the same 1,600-fit grid. CAMPAIGN_SEED_BASE
## lets a smoke run take a NON-OVERLAPPING block so it cannot accidentally
## re-score fits already in the results file, and CAMPAIGN_NREP can now
## exceed 100 (previously capped by the hard-coded seed vector).
seed_base <- as.integer(Sys.getenv("CAMPAIGN_SEED_BASE", "1001"))
n_rep <- as.integer(Sys.getenv("CAMPAIGN_NREP", "100"))
grid <- expand.grid(n_cells_f = c(150L, 810L), eff_ratio = c(1, 10),
                    n_sources = c(2L, 3L), amp = c(1, 2),
                    seed = seed_base + seq_len(n_rep) - 1L)
## Optional cell subset. Two forms:
##   CAMPAIGN_CELLS  = "n_cells:n_sources" pairs (implies eff_ratio 1, amp 1)
##                     -- the smoke-run shorthand.
##   CAMPAIGN_CELLS4 = "n_cells:eff_ratio:n_sources:amp" full tuples
##                     -- used by the E1 escalation, which must address
##                     exactly the cells the escalation rule names and no
##                     others. Escalating a cell that did not trigger would
##                     quietly change the pre-registered design.
cell_filter <- Sys.getenv("CAMPAIGN_CELLS", "")
if (nzchar(cell_filter)) {
  want <- strsplit(strsplit(cell_filter, ",")[[1]], ":")
  keep <- Reduce(`|`, lapply(want, function(w) {
    grid$n_cells_f == as.integer(w[1]) & grid$n_sources == as.integer(w[2]) &
      grid$eff_ratio == 1 & grid$amp == 1
  }))
  grid <- grid[keep, , drop = FALSE]
}
cell_filter4 <- Sys.getenv("CAMPAIGN_CELLS4", "")
if (nzchar(cell_filter4)) {
  want <- strsplit(strsplit(cell_filter4, ",")[[1]], ":")
  keep <- Reduce(`|`, lapply(want, function(w) {
    grid$n_cells_f == as.integer(w[1]) & grid$eff_ratio == as.numeric(w[2]) &
      grid$n_sources == as.integer(w[3]) & grid$amp == as.numeric(w[4])
  }))
  grid <- grid[keep, , drop = FALSE]
}
cat("fits:", nrow(grid), " seeds:", min(grid$seed), "-", max(grid$seed), "\n")
res <- do.call(rbind, mclapply(seq_len(nrow(grid)), function(i) {
  run_cell(grid$n_cells_f[i], grid$eff_ratio[i], grid$n_sources[i],
           grid$amp[i], grid$seed[i])
}, mc.cores = as.integer(Sys.getenv("CAMPAIGN_CORES", "100"))))
out <- Sys.getenv("CAMPAIGN_OUT", "campaign-intervals-results.csv")
## Carry the MEASURED version with the data, so a results file can never be
## separated from the package that produced it.
res$gllvmtmb_version <- .gllvm_version
write.csv(res, out, row.names = FALSE)
cat("wrote", out, "rows", nrow(res), "\n")
cat("errors:", sum(is.na(res$conv)), " conv0:", sum(res$conv == 0, na.rm = TRUE),
    "/", nrow(res), " pd:", sum(res$pd, na.rm = TRUE), "\n")
agg <- aggregate(cbind(pd, cov_env_sp1, cov_env_sp2, cov_env_sp3,
                       cov_eta_po, cov_eta_pa) ~
                 n_cells + eff_ratio + n_sources + amp,
                 data = res, FUN = function(z) round(mean(z, na.rm = TRUE), 3),
                 na.action = na.pass)
print(agg, row.names = FALSE)
