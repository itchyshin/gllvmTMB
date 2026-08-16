## Model 2 gamma-recovery campaign (Design 120 section 6, nonspatial arm).
## Grid: n_sources {2,3,4} x mix {allpo, pa} x effort-ratio {1, 10} x 100 seeds
## = 1,200 fits. Runs on Totoro with mclapply; OPENBLAS single-thread per fit.
## Pre-run receipt: 12/12 conv, 12/12 pd_hessian PASS, median 3.6 s/fit, so the
## whole grid is ~80 core-minutes -- under the D-139 30-minute line.
suppressMessages(library(gllvmTMB))
suppressMessages(library(parallel))

run_cell <- function(n_sources, mix, eff_ratio, seed) {
  set.seed(seed)
  n_cell <- 150L
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2", "sp3")
  x <- as.numeric(scale(runif(n_cell)))
  u <- as.numeric(scale(sin(seq_len(n_cell) / 6)))
  alpha <- c(-0.2, 0.2, 0.0); beta <- c(0.5, -0.3, 0.4)
  lambda <- c(0.8, 0.5, -0.4)
  laws <- if (mix == "pa") c(rep("count", n_sources - 1L), "pa") else
    rep("count", n_sources)
  src_names <- paste0("s", seq_len(n_sources))
  gamma <- matrix(0, n_sources, 3L)
  if (n_sources > 1L)
    gamma[-1L, ] <- matrix(runif((n_sources - 1L) * 3L, -1, 1),
                           n_sources - 1L, 3L)
  eff <- c(2.0, rep(2.0 / eff_ratio, n_sources - 1L))

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

  ## the all-count arm uses plain poisson() DELIBERATELY: an all-count
  ## declaration needs no admission and isdm_sources() would add nothing --
  ## but that means the allpo half of the grid exercises the ordinary route,
  ## not the declared one, and the register row must count only the "pa"
  ## half (600 fits) as isdm_sources() evidence.
  fit <- try(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:env + trait:src + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id",
    family = if (mix == "pa") {
      do.call(isdm_sources, stats::setNames(
        lapply(laws, function(l) if (l == "count") poisson() else
          binomial(link = "cloglog")), src_names))
    } else poisson(),
    silent = TRUE))), silent = TRUE)
  if (inherits(fit, "try-error")) {
    return(data.frame(n_sources = n_sources, mix = mix,
                      eff_ratio = eff_ratio, seed = seed,
                      conv = NA_integer_, pd = NA, gamma_rmse = NA_real_,
                      gamma_bias = NA_real_))
  }
  h <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
  pd <- if (is.null(h)) NA else
    identical(h$status[h$component == "pd_hessian"], "PASS")
  idx <- grep(":src", fit$X_fix_names)
  est <- unname(fit$opt$par[idx])
  truth <- as.vector(t(gamma[-1L, , drop = FALSE]))
  ok <- length(est) == length(truth)
  ## SPLIT the recovery metric by arm type. Pooling all (n_sources - 1) * 3
  ## gammas into one RMSE dilutes the fixed number of hard PA gammas with a
  ## growing pool of easy PO gammas as arms are added, manufacturing an
  ## apparent improvement that is an averaging artifact (review finding B2).
  ## In the "pa" mix the LAST source is the PA arm, so its 3 gammas are the
  ## final 3 entries of `truth`/`est` (trait-fastest within source).
  err <- if (ok) est - truth else NULL
  pa_idx <- if (ok && mix == "pa") {
    seq.int(length(err) - 2L, length(err))
  } else integer(0)
  po_idx <- if (ok) setdiff(seq_along(err), pa_idx) else integer(0)
  rmse <- function(z) if (length(z)) sqrt(mean(z^2)) else NA_real_
  data.frame(n_sources = n_sources, mix = mix, eff_ratio = eff_ratio,
             seed = seed, conv = fit$opt$convergence, pd = pd,
             gamma_rmse = rmse(err),
             gamma_rmse_po = rmse(err[po_idx]),
             gamma_rmse_pa = rmse(err[pa_idx]),
             gamma_bias = if (ok) mean(err) else NA_real_)
}

grid <- expand.grid(n_sources = c(2L, 3L, 4L), mix = c("allpo", "pa"),
                    eff_ratio = c(1, 10), seed = 1001:1100,
                    stringsAsFactors = FALSE)
cat("cells:", nrow(grid), "\n")
res <- do.call(rbind, mclapply(seq_len(nrow(grid)), function(i) {
  run_cell(grid$n_sources[i], grid$mix[i], grid$eff_ratio[i], grid$seed[i])
}, mc.cores = as.integer(Sys.getenv("CAMPAIGN_CORES", "100"))))
out <- Sys.getenv("CAMPAIGN_OUT", "campaign-gamma-recovery-results.csv")
write.csv(res, out, row.names = FALSE)
cat("wrote", out, "rows", nrow(res), "\n")
cat("\n== errors:", sum(is.na(res$conv)),
    " conv0:", sum(res$conv == 0, na.rm = TRUE), "/", nrow(res),
    " pd_pass:", sum(res$pd, na.rm = TRUE), "\n")
agg <- aggregate(cbind(gamma_rmse, gamma_rmse_po, gamma_rmse_pa, gamma_bias, pd)
                 ~ n_sources + mix + eff_ratio,
                 data = res, FUN = function(z) round(mean(z, na.rm = TRUE), 3),
                 na.action = na.pass)
print(agg, row.names = FALSE)
