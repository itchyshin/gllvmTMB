suppressPackageStartupMessages(library(gllvmTMB))
set.seed(5)
rep2 <- function(tag, fit) {
  if (inherits(fit, "try-error")) { cat(sprintf("\n== %s ==\n  FAILED: %s\n", tag, as.character(fit))); return(invisible()) }
  o <- fit$tmb_obj; pl <- o$env$parList(); b <- fit$random
  cat(sprintf("\n== %s ==\n", tag))
  cat("  blocks: ", paste(sprintf("%s=%d", b, vapply(b, function(x) length(pl[[x]]), 1L)), collapse=", "), "\n")
  cat("  length(env$random) = ", length(o$env$random), " | n_obs = ", length(fit$tmb_data$y),
      " | is_y_observed 0s = ", sum(fit$tmb_data$is_y_observed == 0L), "\n")
}
## ---- missing = include (MASK route) ----
n_sites <- 40L; n_tr <- 5L
site <- factor(seq_len(n_sites))
Y <- matrix(rnorm(n_sites*n_tr), n_sites, n_tr); colnames(Y) <- paste0("t",1:n_tr)
w <- data.frame(site = site, Y, check.names = FALSE)
wm <- w; M <- as.matrix(wm[,-1]); M[sample(length(M), 12)] <- NA; wm[,-1] <- M
ctl <- gllvmTMBcontrol(se = FALSE)
f_inc <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4,t5) ~ 1 + latent(1 | site, d = 2),
  data = wm, unit = "site", family = gaussian(), control = ctl,
  missing = miss_control(response = "include")))), silent = TRUE)
rep2("latent(d=2) + missing=include (mask)", f_inc)

## ---- SPDE spatial ----
n_s <- 60L
loc <- cbind(runif(n_s), runif(n_s))
Ys <- matrix(rnorm(n_s*3), n_s, 3); colnames(Ys) <- paste0("t",1:3)
ws <- data.frame(site = factor(seq_len(n_s)), X = loc[,1], Y = loc[,2], Ys, check.names = FALSE)
msh <- try(make_mesh(ws, xy_cols = c("X","Y"), cutoff = 0.12), silent = TRUE)
if (inherits(msh, "try-error")) cat("\nmesh failed:", as.character(msh), "\n") else {
  cat("\n  mesh n_nodes = ", msh$mesh$n, "\n")
  f_sp <- try(suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1,t2,t3) ~ 1 + spatial_indep(1 | site),
    data = ws, unit = "site", family = gaussian(), mesh = msh, control = ctl))), silent = TRUE)
  rep2("spatial_indep (SPDE), 60 sites", f_sp)
  f_sl <- try(suppressMessages(suppressWarnings(gllvmTMB(
    traits(t1,t2,t3) ~ 1 + spatial_latent(1 | site, d = 2),
    data = ws, unit = "site", family = gaussian(), mesh = msh, control = ctl))), silent = TRUE)
  rep2("spatial_latent(d=2) (SPDE), 60 sites", f_sl)
}
