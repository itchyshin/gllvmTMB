## ---------------------------------------------------------------------------
## Replicate-level results behind Block 10 (READER-BLOCKS.md): the claim
## survives a BIASED presence-only arm. Reuses the exact simulation and
## estimator in evidence-biased-po.R -- this script only adds saveRDS() so the
## article can plot the full replicate scatter instead of the printed
## aggregates.
##
## Run from the package root:
##   Rscript dev/isdm-precision/generate-biased-po-results.R
## ---------------------------------------------------------------------------
suppressMessages(devtools::load_all(".", quiet = TRUE))

env_surface <- function(ns = 26, ell = 0.25, seed = 1) {
  set.seed(seed)
  gx <- seq(0, 1, length.out = ns); g <- expand.grid(lon = gx, lat = gx)
  S <- exp(-as.matrix(dist(g)) / ell)
  z <- as.numeric(t(chol(S + diag(1e-6, nrow(S)))) %*% rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g
}
rd <- function(gr, lo, la, col) {
  gr[[col]][max.col(-(outer(lo, gr$lon, "-")^2 + outer(la, gr$lat, "-")^2))]
}

sim <- function(fuzz, n_po, n_sv, beta = 0.9, gamma = 1.2, ell = 0.25, seed = 1) {
  set.seed(seed); gr <- env_surface(26, ell, seed)
  ## ACCESS: an INDEPENDENT smooth surface (env _|_ access by construction)
  gr2 <- env_surface(26, ell, seed + 500L); gr$access <- gr2$env
  sp <- c("sp1", "sp2"); alpha <- c(-0.3, 0.1)
  arm <- function(n, src, fz, biased) {
    lo <- runif(n); la <- runif(n)
    et <- rd(gr, lo, la, "env"); ac <- rd(gr, lo, la, "access")
    er <- if (fz > 0) {
      lf <- pmin(pmax(lo + rnorm(n, 0, fz * ell), 0), 1)
      af <- pmin(pmax(la + rnorm(n, 0, fz * ell), 0), 1)
      rd(gr, lf, af, "env")
    } else et
    do.call(rbind, lapply(seq_along(sp), function(j) {
      eta <- alpha[j] + beta * et + if (biased) gamma * ac else 0
      data.frame(cell_id = factor(paste0(src, "_", seq_len(n))), trait = sp[j],
                 value = rpois(n, exp(eta)), env = er, access = ac, src = src)
    }))
  }
  d_po <- arm(n_po, "po", 0, TRUE)          # precise BUT sampling-biased
  d_sv <- arm(n_sv, "survey", fuzz, FALSE)  # unbiased BUT fuzzed
  fit1 <- function(dat) {
    dat$trait <- factor(dat$trait, levels = sp); dat$cell_id <- factor(dat$cell_id)
    rhs <- if (length(unique(dat$src)) > 1) {
      dat$src <- factor(dat$src); value ~ 0 + trait + trait:env + access + src
    } else value ~ 0 + trait + trait:env + access
    f <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(rhs, data = dat,
      trait = "trait", unit = "cell_id", family = poisson(), silent = TRUE))),
      error = function(e) NULL)
    if (is.null(f) || f$opt$convergence != 0) return(NA_real_)
    b <- f$opt$par[names(f$opt$par) == "b_fix"]
    mean(unname(b[grep(":env$", f$X_fix_names)]))
  }
  c(precise = fit1(d_po), fuzzed = fit1(d_sv), integrated = fit1(rbind(d_po, d_sv)))
}

out <- list()
for (f in c(0, 0.5, 1.0)) {
  for (r in 1:15) {
    est <- sim(f, 400, 100, seed = 3000 + r)
    out[[length(out) + 1]] <- data.frame(
      n_po = 400, n_survey = 100, fuzz = f, rep = r,
      arm = names(est), beta_hat = unname(est), row.names = NULL)
  }
}
res <- do.call(rbind, out)
saveRDS(res, "dev/isdm-precision/biased-po-results.rds")
cat("saved", nrow(res), "rows to dev/isdm-precision/biased-po-results.rds\n")
