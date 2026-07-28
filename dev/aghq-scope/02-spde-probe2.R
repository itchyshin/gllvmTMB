suppressPackageStartupMessages(library(gllvmTMB))
set.seed(5)
rep2 <- function(tag, fit) {
  if (inherits(fit, "try-error")) { cat(sprintf("\n== %s ==\n  FAILED: %s\n", tag, as.character(fit))); return(invisible()) }
  o <- fit$tmb_obj; pl <- o$env$parList(); b <- fit$random
  cat(sprintf("\n== %s ==\n", tag))
  cat("  blocks: ", paste(sprintf("%s=%d", b, vapply(b, function(x) length(pl[[x]]), 1L)), collapse=", "), "\n")
  cat("  length(env$random) = ", length(o$env$random), " | n_obs = ", length(fit$tmb_data$y), "\n")
}
n_s <- 60L; n_tr <- 3L
loc <- cbind(runif(n_s), runif(n_s))
long <- data.frame(
  site  = factor(rep(seq_len(n_s), times = n_tr)),
  X     = rep(loc[,1], times = n_tr),
  Y     = rep(loc[,2], times = n_tr),
  trait = factor(rep(paste0("t", seq_len(n_tr)), each = n_s)),
  value = rnorm(n_s * n_tr))
msh <- make_mesh(long, xy_cols = c("X","Y"), cutoff = 0.12)
cat("  mesh n_nodes =", msh$mesh$n, "\n")
ctl <- gllvmTMBcontrol(se = FALSE)
f_sp <- try(suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + spatial_indep(0 + trait | site),
  data = long, trait = "trait", unit = "site", family = gaussian(),
  mesh = msh, control = ctl))), silent = TRUE)
rep2("spatial_indep (SPDE), 60 sites, 3 traits", f_sp)
f_sl <- try(suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + spatial_latent(0 + trait | site, d = 2),
  data = long, trait = "trait", unit = "site", family = gaussian(),
  mesh = msh, control = ctl))), silent = TRUE)
rep2("spatial_latent(d=2) (SPDE)", f_sl)
