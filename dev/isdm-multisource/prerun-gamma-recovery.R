## Model 2 recovery pre-run (D-139): a 12-fit toy proving the harness writes
## non-empty, in-range output BEFORE any campaign is proposed. One seed per
## cell of a tiny grid: n_sources in {2,3,4} x 4 seeds, nonspatial, mixed laws
## (one PA arm, the rest PO), n_cell = 150, 3 species.
##
## Full-campaign proposal (NEEDS MAINTAINER APPROVAL before launch, per D-139):
##   grid = n_sources {2,3,4} x law-mix {all-PO, (n-1)PO+PA} x effort-ratio
##          {1x, 10x} x 100 seeds = 1,200 fits.
##   Per-fit cost measured here; Totoro, <= 150 cores, OPENBLAS single-thread.
suppressMessages(devtools::load_all(
  Sys.getenv("GLLVMTMB_WT", "/private/tmp/gllvmtmb-model2"), quiet = TRUE))

run_cell <- function(n_sources, seed) {
  set.seed(seed)
  n_cell <- 150L
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2", "sp3")
  x <- as.numeric(scale(runif(n_cell)))
  u <- as.numeric(scale(sin(seq_len(n_cell) / 6)))
  alpha <- c(-0.2, 0.2, 0.0); beta <- c(0.5, -0.3, 0.4)
  lambda <- c(0.8, 0.5, -0.4)
  src_names <- c("s1", paste0("po", seq_len(n_sources - 2L)), "pa")[seq_len(n_sources)]
  laws <- c(rep("count", n_sources - 1L), "pa")
  ## true per-source recording effects, reference-coded on source 1
  gamma <- matrix(0, n_sources, 3L)
  if (n_sources > 1L) {
    gamma[-1L, ] <- matrix(runif((n_sources - 1L) * 3L, -1, 1),
                           n_sources - 1L, 3L)
  }
  eff <- c(2.0, rep(0.8, n_sources - 2L), 0.9)

  dat <- do.call(rbind, lapply(seq_len(n_sources), function(d) {
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

  args <- stats::setNames(
    lapply(laws, function(l) if (l == "count") poisson() else
      binomial(link = "cloglog")),
    src_names)
  fam <- do.call(isdm_sources, args)

  t0 <- Sys.time()
  fit <- try(suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    silent = TRUE)), silent = TRUE)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(fit, "try-error")) {
    return(data.frame(n_sources = n_sources, seed = seed, secs = secs,
                      conv = NA, pd = NA, gamma_rmse = NA))
  }
  h <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
  pd <- if (is.null(h)) NA else
    identical(h$status[h$component == "pd_hessian"], "PASS")
  idx <- grep(":src", fit$X_fix_names)
  est <- unname(fit$opt$par[idx])
  truth <- as.vector(t(gamma[-1L, , drop = FALSE]))
  gr <- if (length(est) == length(truth)) sqrt(mean((est - truth)^2)) else NA
  data.frame(n_sources = n_sources, seed = seed, secs = round(secs, 1),
             conv = fit$opt$convergence, pd = pd,
             gamma_rmse = round(gr, 3))
}

grid <- expand.grid(n_sources = c(2L, 3L, 4L), seed = 101:104)
res <- do.call(rbind, Map(run_cell, grid$n_sources, grid$seed))
print(res, row.names = FALSE)
cat("\nSUMMARY: fits =", nrow(res),
    " errors =", sum(is.na(res$conv)),
    " conv0 =", sum(res$conv == 0, na.rm = TRUE),
    " pd_pass =", sum(res$pd, na.rm = TRUE),
    " median secs =", median(res$secs), "\n")
cat("median gamma RMSE by n_sources:\n")
print(round(tapply(res$gamma_rmse, res$n_sources, median, na.rm = TRUE), 3))
