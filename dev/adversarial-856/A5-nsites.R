suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
cat("ITEM 4: is the collapse SAMPLE-SIZE curable? Fix seed=2 (a collapsing seed),\n")
cat("keep ONE row per (site,trait), grow n_sites.\n\n")
for (ns in c(30L, 60L, 120L, 240L, 480L)) {
  set.seed(2L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = ns, n_species = 1, n_traits = 4, mean_species_per_site = 1,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2), psi_B = rep(0.2, 4), seed = 2L)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE))), error = function(e) e)
  if (inherits(fit, "error")) { cat("n_sites", ns, "ERROR\n"); next }
  se <- as.numeric(fit$report$sigma_eps)
  cat("n_sites ", ns, " (rows ", nrow(sim$data), "): conv=", fit$opt$convergence,
      " pdHess=", isTRUE(fit$sd_report$pdHess),
      " sigma_eps=", paste(signif(se, 4), collapse = ", "),
      "  collapsed=", any(se < 0.05), "\n", sep = "")
}
cat("\nNow grow REPLICATION instead (n_sites=30 fixed, species/site 1->4):\n")
for (rp in c(1L, 2L, 3L, 4L)) {
  set.seed(2L)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = rp, n_traits = 4, mean_species_per_site = rp,
    Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2), psi_B = rep(0.2, 4), seed = 2L)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim$data, silent = TRUE))), error = function(e) e)
  if (inherits(fit, "error")) { cat("reps", rp, "ERROR\n"); next }
  se <- as.numeric(fit$report$sigma_eps)
  cat("species/site ", rp, " (rows ", nrow(sim$data), "): sigma_eps=",
      paste(signif(se, 4), collapse = ", "), "  collapsed=", any(se < 0.05), "\n", sep = "")
}
