## READ-ONLY: random-vector length under phylo / spatial / crossed-RE / OLRE.
suppressPackageStartupMessages({library(gllvmTMB); library(ape)})
set.seed(3)
n_sp <- 30L; n_tr <- 4L
tree <- ape::rcoal(n_sp, tip.label = paste0("sp", seq_len(n_sp)))
sp <- factor(tree$tip.label, levels = tree$tip.label)
site <- factor(rep(seq_len(10L), length.out = n_sp))
Y <- matrix(rnorm(n_sp * n_tr), n_sp, n_tr); colnames(Y) <- paste0("t", 1:n_tr)
wide <- data.frame(species = sp, site = site, Y, check.names = FALSE)
ctl <- gllvmTMBcontrol(se = FALSE)

rep2 <- function(tag, fit) {
  if (inherits(fit, "try-error")) { cat(sprintf("\n== %s ==\n  FAILED: %s\n", tag, as.character(fit))); return(invisible()) }
  o <- fit$tmb_obj; pl <- o$env$parList(); b <- fit$random
  cat(sprintf("\n== %s ==\n", tag))
  cat("  blocks: ", paste(sprintf("%s=%d", b, vapply(b, function(x) length(pl[[x]]), 1L)), collapse=", "), "\n")
  cat("  length(env$random) = ", length(o$env$random), " | n_obs = ", length(fit$tmb_data$y), "\n")
}

f_ph <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4) ~ 1 + phylo_latent(1 | species, d = 2),
  data = wide, unit = "species", cluster = "species", phylo_tree = tree,
  family = gaussian(), control = ctl))), silent = TRUE)
rep2("phylo_latent(d=2), 30 species", f_ph)

f_ph2 <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4) ~ 1 + phylo_latent(1 | species, d = 2, unique = TRUE),
  data = wide, unit = "species", cluster = "species", phylo_tree = tree,
  family = gaussian(), control = ctl))), silent = TRUE)
rep2("phylo_latent(d=2, unique=TRUE)", f_ph2)

f_ind <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4) ~ 1 + phylo_indep(1 | species),
  data = wide, unit = "species", cluster = "species", phylo_tree = tree,
  family = gaussian(), control = ctl))), silent = TRUE)
rep2("phylo_indep (diagonal Psi, structured A)", f_ind)

## crossed ordinary RE on top of latent(): does the block graph stay per-site?
wide2 <- wide; wide2$region <- factor(rep(1:3, length.out = n_sp))
f_cr <- try(suppressMessages(suppressWarnings(gllvmTMB(
  traits(t1,t2,t3,t4) ~ 1 + latent(1 | site, d = 1) + (1 | region),
  data = wide2, unit = "site", family = gaussian(), control = ctl))), silent = TRUE)
rep2("latent(d=1|site) + crossed (1|region)", f_cr)
