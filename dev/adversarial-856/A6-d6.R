suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
set.seed(106)
sim6 <- simulate_site_trait(n_sites = 40, n_species = 1, n_traits = 4,
                            mean_species_per_site = 1,
                            Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2),
                            psi_B = rep(0.2, 4), seed = 106)
fit6 <- tryCatch(suppressMessages(suppressWarnings(
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2), data = sim6$data)
)), error = function(e) e)
if (inherits(fit6,"error")) cat("ERROR:", conditionMessage(fit6), "\n") else {
cat("D6 conv=", fit6$opt$convergence, " pdHess=", isTRUE(fit6$sd_report$pdHess),
    "\n  sigma_eps=", paste(signif(as.numeric(fit6$report$sigma_eps),5), collapse=", "),
    "\n  map=", { m<-fit6$tmb_obj$env$map$log_sigma_eps; if(is.null(m)) "ABSENT" else paste(as.character(m),collapse=",")},
    "\n  sd_B=", paste(signif(as.numeric(fit6$report$sd_B %||% NA),4), collapse=", "), "\n", sep="")
}
