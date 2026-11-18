## dev/multinomial-structured/rerun-s2-indep-corrected.R
##
## Provenance script for results/s2-indep-corrected-summary.csv (D-43 panel
## finding: the corrected rerun was executed inline by the orchestrator and
## its generating code was not committed — this file reconstructs it exactly).
##
## WHY THIS RERUN EXISTS: campaign-s2-phylo-dep-indep.R fed BOTH cells the
## default correlated DGP (rho_true = 0.6), but pass-criteria-s2.md
## pre-registers the phylo_indep cell against DIAGONAL truth
## (rho_true = 0, sd_true = c(0.8, 0.5)). This script re-runs the indep cell
## under its pre-registered design, including the planted-zero criterion
## (a full-V phylo_latent refit on the same data must not invent
## correlation).
##
## Usage (from the package root):
##   OPENBLAS_NUM_THREADS=1 Rscript dev/multinomial-structured/rerun-s2-indep-corrected.R

source("dev/multinomial-structured/dgp-multinomial-structured.R")
suppressMessages(devtools::load_all(".", quiet = TRUE))

fit_cell <- function(seed) {
  dgp <- dgp_multinomial_structured(n_sp = 800L, seed = seed, K = 3L,
                                    rho_true = 0, sd_true = c(0.8, 0.5))
  df <- dgp$data; tree <- dgp$tree
  fi <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree),
    data = df, family = multinomial(), trait = "trait", unit = "species")))
  Vi <- extract_Sigma(fi, level = "phy", part = "shared", link_residual = "none")
  Vi <- if (is.matrix(Vi)) Vi else Vi$Sigma
  fl <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree),
    data = df, family = multinomial(), trait = "trait", unit = "species")))
  Vl <- extract_Sigma(fl, level = "phy", part = "shared", link_residual = "none")
  Vl <- if (is.matrix(Vl)) Vl else Vl$Sigma
  rho_l <- if (all(is.finite(Vl)) && Vl[1, 1] > 1e-10 && Vl[2, 2] > 1e-10)
    Vl[1, 2] / sqrt(Vl[1, 1] * Vl[2, 2]) else NA_real_
  data.frame(seed = seed, conv = fi$opt$convergence,
             pd = isTRUE(fi$sd_report$pdHess),
             v1_ratio = Vi[1, 1] / 0.64,   # true V11 = 0.8^2
             v2_ratio = Vi[2, 2] / 0.25,   # true V22 = 0.5^2
             rho_latent_refit = rho_l)
}

res <- do.call(rbind, parallel::mclapply(
  201:220, fit_cell,
  mc.cores = as.integer(Sys.getenv("CAMPAIGN_CORES", "10"))))
write.csv(res,
          "dev/multinomial-structured/results/s2-indep-corrected-summary.csv",
          row.names = FALSE)

ok <- res$conv == 0 & res$pd
cat(sprintf(paste0(
  "phylo_indep CORRECTED (diagonal truth): n=%d conv+PD=%d | ",
  "median v1 ratio=%.2f v2 ratio=%.2f (band 0.33-3.0) | ",
  "in-band: v1 %d v2 %d | latent-refit median rho magnitude=%.3f ",
  "(planted-zero criterion < 0.35)\n"),
  nrow(res), sum(ok),
  median(res$v1_ratio[ok]), median(res$v2_ratio[ok]),
  sum(res$v1_ratio[ok] >= 1/3 & res$v1_ratio[ok] <= 3),
  sum(res$v2_ratio[ok] >= 1/3 & res$v2_ratio[ok] <= 3),
  median(abs(res$rho_latent_refit[ok]), na.rm = TRUE)))
