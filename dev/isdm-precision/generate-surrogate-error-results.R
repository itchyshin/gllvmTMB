## ---------------------------------------------------------------------------
## Replicate-level results behind the sign-reversal table in
## vignettes/articles/isdm-spatial-precision.Rmd.
##
## Extends evidence-bias-surrogate-error.R in two ways:
##   1. adds the MISSING CELL -- rho = 0 with surrogate error -- which is the
##      cell that identifies the mechanism. Without it the design cannot tell
##      "surrogate error flips the sign" from "confounding AND surrogate error
##      together flip the sign", and those are different instructions to a
##      reader. (Fisher review F2.)
##   2. saves every replicate, so the article can count and test rather than
##      quote a mean.
##
## Run from the package root:
##   Rscript dev/isdm-precision/generate-surrogate-error-results.R
## ---------------------------------------------------------------------------
suppressMessages(devtools::load_all(".", quiet = TRUE))

env_surface <- function(ns = 26, ell = 0.25, seed = 1) {
  set.seed(seed)
  gx <- seq(0, 1, length.out = ns); g <- expand.grid(lon = gx, lat = gx)
  S <- exp(-as.matrix(dist(g)) / ell)
  z <- as.numeric(t(chol(S + diag(1e-6, nrow(S)))) %*% rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g
}
rd <- function(gr, lo, la, col)
  gr[[col]][max.col(-(outer(lo, gr$lon, "-")^2 + outer(la, gr$lat, "-")^2))]

sim <- function(fuzz, rho, meas_err, model_access, seed,
                beta = 0.9, gamma = 1.2, ell = 0.25) {
  set.seed(seed); gr <- env_surface(26, ell, seed)
  g2 <- env_surface(26, ell, seed + 500L)
  gr$access <- as.numeric(scale(rho * gr$env + sqrt(max(1 - rho^2, 0)) * g2$env))
  sp <- c("sp1", "sp2"); alpha <- c(-0.3, 0.1)
  arm <- function(n, src, fz, biased) {
    lo <- runif(n); la <- runif(n)
    et <- rd(gr, lo, la, "env"); ac <- rd(gr, lo, la, "access")
    er <- if (fz > 0) {
      lf <- pmin(pmax(lo + rnorm(n, 0, fz * ell), 0), 1)
      af <- pmin(pmax(la + rnorm(n, 0, fz * ell), 0), 1)
      rd(gr, lf, af, "env")
    } else et
    ac_obs <- ac + rnorm(n, 0, meas_err)
    do.call(rbind, lapply(seq_along(sp), function(j) {
      eta <- alpha[j] + beta * et + if (biased) gamma * ac else 0
      data.frame(cell_id = factor(paste0(src, "_", seq_len(n))), trait = sp[j],
                 value = rpois(n, exp(eta)), env = er, access = ac_obs, src = src)
    }))
  }
  d_po <- arm(400, "po", 0, TRUE); d_sv <- arm(100, "survey", fuzz, FALSE)
  f1 <- function(dat) {
    dat$trait <- factor(dat$trait, levels = sp)
    dat$cell_id <- factor(dat$cell_id)
    acc <- if (model_access) "+access" else ""
    src <- if (length(unique(dat$src)) > 1) { dat$src <- factor(dat$src); "+src" } else ""
    fml <- stats::as.formula(paste0("value~0+trait+trait:env", acc, src))
    f <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(fml, data = dat,
      trait = "trait", unit = "cell_id", family = poisson(), silent = TRUE))),
      error = function(e) NULL)
    if (is.null(f) || f$opt$convergence != 0) return(NA_real_)
    b <- f$opt$par[names(f$opt$par) == "b_fix"]
    mean(unname(b[grep(":env$", f$X_fix_names)]))
  }
  c(precise = f1(d_po), integrated = f1(rbind(d_po, d_sv)))
}

cond <- list(
  list(lab = "measured exactly",              rho = 0,   err = 0,   mod = TRUE),
  list(lab = "surrogate error only",          rho = 0,   err = 0.5, mod = TRUE),
  list(lab = "confounding only",              rho = 0.7, err = 0,   mod = TRUE),
  list(lab = "confounding + surrogate error", rho = 0.7, err = 0.5, mod = TRUE),
  list(lab = "confounded, not modelled",      rho = 0.7, err = 0,   mod = FALSE))

out <- list()
for (i in seq_along(cond)) {
  cc <- cond[[i]]
  for (r in 1:12) {
    est <- sim(1.0, cc$rho, cc$err, cc$mod, seed = 7000 + r)
    out[[length(out) + 1]] <- data.frame(
      order = i, cond = cc$lab, rho = cc$rho, err_sd = cc$err,
      modelled = cc$mod, rep = r,
      precise = unname(est["precise"]), integrated = unname(est["integrated"]),
      row.names = NULL)
  }
  cat(sprintf("%-30s done\n", cc$lab))
}
res <- do.call(rbind, out)
saveRDS(res, "dev/isdm-precision/surrogate-error-results.rds")
cat("saved", nrow(res), "rows to dev/isdm-precision/surrogate-error-results.rds\n")
