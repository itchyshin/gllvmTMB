## TEMPORARY debug probe -- deleted after diagnosis. Runs the exact seed-103 cell
## inside testthat's execution context and prints what the standalone script prints.
test_that("ZZZ DEBUG: seed-103 cell inside testthat", {
  skip_if_not_heavy(); skip_on_cran()
  src <- readLines(testthat::test_path("test-phylo-q-decomposition.R"))
  eval(parse(text = paste(src[31:78], collapse = "\n")))
  s <- simulate_phylo_q_dgp(n_species = 100, n_sites = 60, n_traits = 5, seed = 103)
  tree <- s$tree
  cat(sprintf("\n[dbg] data checksum %.6f | nrow %d\n", sum(s$data$value), nrow(s$data)))
  cat(sprintf("[dbg] LC_COLLATE = %s\n", Sys.getlocale("LC_COLLATE")))
  cat(sprintf("[dbg] species levels head: %s\n", paste(head(levels(s$data$species), 4), collapse = ",")))
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) +
            unique(0 + trait | site_species) +
            unique(0 + trait | species) +
            phylo_unique(species, tree = tree),
    data    = s$data,
    cluster = "species"
  )))
  g <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
  cat(sprintf("[dbg] convergence %s | msg '%s'\n", fit$opt$convergence, fit$opt$message))
  cat(sprintf("[dbg] objective  %.6f | |grad| %.3e | iters %s | npar %d\n",
              fit$opt$objective, g, fit$opt$iterations, length(fit$opt$par)))
  cat(sprintf("[dbg] standalone was: conv 0 | obj 36622.108862 | grad 4.694e-02 | iters 206\n"))
  expect_true(TRUE)
})
