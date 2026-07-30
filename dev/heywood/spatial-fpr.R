## Spatial-tier false-positive rate -- the last open coverage cell.
##
## Two earlier attempts failed to produce a HEALTHY spatial fit and the gap was
## recorded as open. The cause was the DGP, not the package: single-trial
## Bernoulli at n = 80 with two competing latent structures is close to the
## hardest case available. Multi-trial binomial supplies ~10x the information
## per cell and converges cleanly.
##
## Healthy is defined by RECOVERY of the unit tier against known truth.
suppressPackageStartupMessages({ library(gllvmTMB); library(parallel) })
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
RUNAWAY <- 25; ABSOLUTE <- 6
grid <- expand.grid(ns = c(200L, 300L), p = c(6L, 8L), nt = c(10L, 20L),
                    seed = 1:8, stringsAsFactors = FALSE)
run <- function(i) {
  cl <- grid[i, ]; q <- 1L
  out <- try({
    set.seed(cl$seed * 8837L + cl$ns + cl$p + cl$nt)
    co <- data.frame(lon = runif(cl$ns), lat = runif(cl$ns))
    D <- as.matrix(dist(co)); ch <- t(chol(exp(-D / 0.35) + diag(1e-6, cl$ns)))
    Lam <- matrix(rnorm(cl$p * q, 0, 0.6), cl$p, q); B <- rnorm(cl$p, 0, 0.3)
    Z <- matrix(rnorm(cl$ns * q), cl$ns, q); spl <- rnorm(cl$p, 0, 0.6)
    fld <- as.numeric(ch %*% rnorm(cl$ns))
    eta <- Z %*% t(Lam) + matrix(B, cl$ns, cl$p, byrow = TRUE) + outer(fld, spl)
    S <- matrix(rbinom(cl$ns * cl$p, cl$nt, plogis(as.numeric(t(eta)))), cl$ns, cl$p, byrow = TRUE)
    dat <- data.frame(succ = as.numeric(t(S)), fail = cl$nt - as.numeric(t(S)),
      trait = factor(rep(seq_len(cl$p), times = cl$ns)),
      site = factor(rep(seq_len(cl$ns), each = cl$p)),
      lon = rep(co$lon, each = cl$p), lat = rep(co$lat, each = cl$p))
    mesh <- make_mesh(dat, c("lon", "lat"), type = "cutoff", cutoff = 0.10)
    f <- suppressMessages(suppressWarnings(gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE) +
        spatial_latent(0 + trait | coords, d = 1),
      data = dat, mesh = mesh, family = binomial(), unit = "site", silent = TRUE)))
    lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(f)
    ck <- suppressWarnings(check_gllvmTMB(f))
    data.frame(ns = cl$ns, p = cl$p, nt = cl$nt, seed = cl$seed,
      rel_frob = norm(tcrossprod(f$report$Lambda_B) - tcrossprod(Lam), "F") /
        norm(tcrossprod(Lam), "F"),
      rl_max = max(lt$relative_loading, na.rm = TRUE),
      ml_pooled = max(lt$max_loading, na.rm = TRUE),
      ml_unit = suppressWarnings(max(lt$max_loading_unit, na.rm = TRUE)),
      row_status = ck$status[ck$component == "binomial_prevalence_loading"],
      stringsAsFactors = FALSE)
  }, silent = TRUE)
  if (inherits(out, "try-error")) NULL else out
}
message(sprintf("fits = %d", nrow(grid)))
d <- do.call(rbind, Filter(is.data.frame, mclapply(seq_len(nrow(grid)), run, mc.cores = 10)))
write.csv(d, "dev/heywood/spatial-fpr.csv", row.names = FALSE)
d$healthy <- d$rel_frob <= 0.5
h <- d[d$healthy, ]
cat(sprintf("\nusable %d of %d;  HEALTHY %d\n", nrow(d), nrow(grid), nrow(h)))
cat(sprintf("\nFALSE POSITIVES on healthy spatial fits: %d / %d\n",
            sum(h$rl_max >= RUNAWAY | h$ml_unit >= ABSOLUTE), nrow(h)))
cat(sprintf("worst healthy rl_max %.2f (thr 25);  ml_unit %.3f (thr 6)\n",
            max(h$rl_max), max(h$ml_unit)))
cat(sprintf("\nfor contrast, POOLED max_loading on the same healthy fits: %.0f .. %.0f\n",
            min(h$ml_pooled), max(h$ml_pooled)))
cat(sprintf("  -> would the OLD pooled rule have fired? %d of %d\n",
            sum(h$ml_pooled >= ABSOLUTE), nrow(h)))
cat("\nshipped row statuses on healthy fits:\n"); print(table(h$row_status))
