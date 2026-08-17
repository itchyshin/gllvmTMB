## dev/categorical-replication/verify-admission-pa4.R
##
## PA4 Task 1 — LIVE grammatical-admission verification for the paper's
## eq 38-46 combined phylo + non-phylo species-effect model (Design 123
## "Paper alignment", the two "grammatically admitted, combination
## UNTESTED" rows) on REPLICATED data (unit = "obs", cluster = "species"):
##
##   O1  ordinal_probit : phylo_indep(0 + trait | species, tree) +
##                        indep(0 + trait | species)        [row 522 shape]
##   O2  ordinal_probit : phylo_latent(species, d = 2, tree) +
##                        indep(0 + trait | species)        [latent variant]
##   M1  multinomial    : phylo_latent(species, d = K-1, tree) +
##                        indep(0 + trait | species)        [row 521 shape]
##
## Each construction is fit on ONE small dataset; we record exactly what
## RUNS vs ERRORS (fence aborts included, verbatim). This is a grammar
## probe, not a recovery claim — estimates from these tiny fits are not
## evidence of anything beyond "the fence admits the combination and the
## fit returns".
##
## Usage:  GLLVMTMB_DIR=../.. Rscript verify-admission-pa4.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
source(file.path(.here, "dgp-ordinal-replicated.R"))
source(file.path(.here, "dgp-multinomial-replicated-species.R"))

PKG_DIR <- Sys.getenv("GLLVMTMB_DIR", file.path(.here, "..", ".."))
suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))

.probe <- function(label, expr) {
  t0 <- Sys.time()
  out <- tryCatch({
    fit <- suppressWarnings(suppressMessages(force(expr)))
    list(status = "RUNS",
         class = paste(class(fit), collapse = "/"),
         convergence = fit$opt$convergence,
         pdHess = isTRUE(fit$sd_report$pdHess),
         error = NA_character_)
  }, error = function(e) {
    list(status = "ERROR", class = NA_character_,
         convergence = NA_integer_, pdHess = NA,
         error = conditionMessage(e))
  })
  out$elapsed_sec <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  cat(sprintf("\n== %s ==\n  status: %s | elapsed %.1f s | conv=%s pdHess=%s\n",
              label, out$status, out$elapsed_sec,
              out$convergence, out$pdHess))
  if (!is.na(out$error)) cat("  ERROR: ", out$error, "\n")
  out
}

## Small probe data — big enough to construct, small enough to be quick.
d_ord <- dgp_ordinal_replicated(n_sp = 40L, n_rep = 3L, seed = 11L)
d_mn  <- dgp_multinomial_replicated_species(n_sp = 60L, n_rep = 4L, seed = 11L)

tree_ord <- d_ord$tree
tree_mn  <- d_mn$tree

res <- list()

res$O1 <- .probe("O1 ordinal_probit: phylo_indep + indep(cluster)",
  gllvmTMB(value ~ 0 + trait +
             phylo_indep(0 + trait | species, tree = tree_ord) +
             indep(0 + trait | species),
           data = d_ord$data, family = ordinal_probit(),
           trait = "trait", unit = "obs", cluster = "species"))

res$O2 <- .probe("O2 ordinal_probit: phylo_latent(d=2) + indep(cluster)",
  gllvmTMB(value ~ 0 + trait +
             phylo_latent(species, d = 2, tree = tree_ord) +
             indep(0 + trait | species),
           data = d_ord$data, family = ordinal_probit(),
           trait = "trait", unit = "obs", cluster = "species"))

res$M1 <- .probe("M1 multinomial: phylo_latent(d=K-1) + indep(cluster)",
  gllvmTMB(value ~ 0 + trait +
             phylo_latent(species, d = 2, tree = tree_mn) +
             indep(0 + trait | species),
           data = d_mn$data, family = multinomial(),
           trait = "trait", unit = "obs", cluster = "species"))

cat("\n---- summary ----\n")
for (nm in names(res)) {
  cat(sprintf("%s: %s%s\n", nm, res[[nm]]$status,
              if (!is.na(res[[nm]]$error)) paste0(" — ", res[[nm]]$error) else ""))
}
