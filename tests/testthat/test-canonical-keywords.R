## Canonical formula-keyword syntax: latent / unique / phylo_latent /
## phylo_scalar / spatial / meta_V are silent canonical names;
## the older rr / diag / phylo_rr / phylo / spde / meta still work as
## deprecated aliases that emit a one-shot soft warning per session.

make_simple <- function(seed = 42) {
  set.seed(seed)
  gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 4,
    mean_species_per_site = 4, seed = seed
  )$data
}

test_that("explicit latent plus unique compatibility pair matches old rr plus diag aliases", {
  df <- make_simple()
  fit_new <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = df
  )))
  fit_old <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            rr(0 + trait | site, d = 2) +
            diag(0 + trait | site),
    data = df
  )))
  expect_equal(fit_new$opt$convergence, 0L)
  expect_equal(fit_old$opt$convergence, 0L)
  expect_equal(-fit_new$opt$objective, -fit_old$opt$objective, tolerance = 1e-8)
})

test_that("Old keywords still work + emit one-shot deprecation message", {
  df <- make_simple()
  ## Reset the deprecation tracker for this test by clearing the env
  rlang::env_unbind(getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen,
                    nms = c("rr", "diag"))
  expect_message(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + rr(0 + trait | site, d = 2) + diag(0 + trait | site),
      data = df
    )),
    regexp = "deprecated alias"
  )
})

test_that("phylo_latent and phylo_scalar are recognized canonical aliases", {
  set.seed(7)
  n_sp <- 20
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 7
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label

  ## phylo_latent canonical
  fit_pl <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data = df, phylo_vcv = Cphy
  )))
  expect_equal(fit_pl$opt$convergence, 0L)

  ## phylo_scalar canonical
  fit_ps <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species),
    data = df, phylo_vcv = Cphy
  )))
  expect_equal(fit_ps$opt$convergence, 0L)
})

test_that("`unit` argument is the canonical name; `site` is deprecated alias", {
  df <- make_simple()
  rlang::env_unbind(getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen,
                    nms = "rr")
  ## Also reset rlang's once-per-session frequency cache for the
  ## `site = ...` deprecation. cli::cli_inform(.frequency = "once",
  ## .frequency_id = "gllvmTMB-site-deprecation") delegates to
  ## rlang::inform(), which tracks once-per-session state in
  ## `rlang:::message_freq_env`. If anything earlier in the session
  ## fires that frequency_id (across test files, examples, package
  ## load, etc.), the message is suppressed and the expect_message()
  ## below sees no message and fails. Clearing the entry here makes
  ## the test robust to test-execution-order quirks.
  freq_env <- getFromNamespace("message_freq_env", "rlang")
  rlang::env_unbind(freq_env, "gllvmTMB-site-deprecation")
  ## New canonical: unit
  fit_unit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, unit = "site"
  )))
  expect_equal(fit_unit$opt$convergence, 0L)
  ## Deprecated: site = ... still works but emits a soft warning
  expect_message(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = df, site = "site"
    )),
    regexp = "deprecated alias|use `unit"
  )
})

test_that("`unit_obs = ...` re-routes the within-unit grouping factor", {
  set.seed(2026)
  ## Build a simple two-level dataset where the within-unit column is
  ## called `obs` (not the default `site_species`).
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = 2026
  )$data
  df$obs <- df$site_species   # rename
  df$site_species <- NULL     # remove default
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site,         d = 2) +
            latent(0 + trait | obs, d = 1) +
            unique(0 + trait | obs),
    data = df, unit_obs = "obs"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$rr_W))
})

test_that("`unique(..., common = TRUE)` ties trait variances to one shared parameter", {
  set.seed(2026)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 5, n_traits = 4,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.6, 0.4, -0.3, 0.2,
                        0.0, 0.5,  0.3, -0.2), 4, 2),
    psi_B = c(0.3, 0.3, 0.3, 0.3),  # truly shared
    seed = 2026
  )
  ## With `common = TRUE`, all traits should share one sd_B value.
  fit_common <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2, unique = FALSE) +
            unique(0 + trait | site, common = TRUE),
    data = sim$data, unit = "site"
  )))
  expect_equal(fit_common$opt$convergence, 0L)
  sds <- as.numeric(fit_common$report$sd_B)
  expect_length(sds, 4)
  expect_true(all(abs(sds - sds[1L]) < 1e-10))   # all equal

  ## Free version has T-1 more parameters.
  fit_free <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2, unique = FALSE) +
            unique(0 + trait | site),
    data = sim$data, unit = "site"
  )))
  expect_equal(length(fit_free$opt$par) - length(fit_common$opt$par), 3L)
})

test_that("`unique(..., common = TRUE)` works at the W tier too", {
  set.seed(7)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 8, n_traits = 4,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(1, 0.5, -0.4, 0.3, 0, 0.8, 0.4, -0.2), 4, 2),
    psi_B  = c(0.2, 0.15, 0.1, 0.25),
    Lambda_W = matrix(c(0.4, 0.2, -0.1, 0.3), 4, 1),
    psi_W  = c(0.1, 0.1, 0.1, 0.1),  # shared at W
    seed = 7
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2, unique = FALSE) +
            unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1, unique = FALSE) +
            unique(0 + trait | site_species, common = TRUE),
    data = sim$data
  )))
  expect_equal(fit$opt$convergence, 0L)
  sds_W <- as.numeric(fit$report$sd_W)
  expect_true(all(abs(sds_W - sds_W[1L]) < 1e-10))
})

test_that("latent(common = TRUE) is the paired common-Psi replacement", {
  df <- make_simple(seed = 20260618)

  fit_latent_common <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2, common = TRUE),
    data = df, unit = "site"
  ))
  fit_legacy_common <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2, unique = FALSE) +
            unique(0 + trait | site, common = TRUE),
    data = df, unit = "site"
  )))

  expect_equal(fit_latent_common$opt$convergence, 0L)
  expect_equal(fit_legacy_common$opt$convergence, 0L)
  expect_equal(
    fit_latent_common$opt$objective,
    fit_legacy_common$opt$objective,
    tolerance = 1e-10
  )
  expect_true(isTRUE(fit_latent_common$use$diag_B))
  expect_false(isTRUE(fit_latent_common$use$indep_B))
  sds <- as.numeric(fit_latent_common$report$sd_B)
  expect_lt(max(abs(sds - sds[1L])), 1e-10)
})

test_that("latent(common = TRUE) rejects removed or augmented Psi targets", {
  df <- make_simple(seed = 20260619)
  df$temperature <- rnorm(nrow(df))

  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
              latent(0 + trait | site, d = 2, unique = FALSE, common = TRUE),
      data = df, unit = "site"
    ),
    regexp = "requires.*unique = TRUE"
  )

  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(1 + temperature | site, d = 1, common = TRUE),
      data = df, unit = "site"
    ),
    regexp = "not implemented.*augmented ordinary"
  )
})

test_that("source-specific latent lv predictors fail loudly", {
  source_specific_lv <- list(
    value ~ 0 + trait + phylo_scalar(species, lv = ~env),
    value ~ 0 + trait + phylo_unique(species, lv = ~env),
    value ~ 0 + trait + phylo_indep(0 + trait | species, lv = ~env),
    value ~ 0 + trait + phylo_latent(species, d = 1, lv = ~env),
    value ~ 0 + trait + phylo_dep(0 + trait | species, lv = ~env),
    value ~ 0 + trait + phylo(0 + trait | species, mode = "latent", lv = ~env),
    value ~ 0 + trait + spatial_scalar(0 + trait | site, lv = ~env),
    value ~ 0 + trait + spatial_unique(0 + trait | site, lv = ~env),
    value ~ 0 + trait + spatial_indep(0 + trait | site, lv = ~env),
    value ~ 0 + trait + spatial_latent(0 + trait | site, d = 1, lv = ~env),
    value ~ 0 + trait + spatial_dep(0 + trait | site, lv = ~env),
    value ~ 0 + trait + spatial(0 + trait | site, mode = "latent", lv = ~env),
    value ~ 0 + trait + animal_scalar(species, pedigree = ped, lv = ~env),
    value ~ 0 + trait + animal_unique(species, pedigree = ped, lv = ~env),
    value ~ 0 + trait + animal_indep(0 + trait | species, pedigree = ped, lv = ~env),
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = ped, lv = ~env),
    value ~ 0 + trait + animal_dep(0 + trait | species, pedigree = ped, lv = ~env),
    value ~ 0 + trait + kernel_latent(site, K = K, d = 1, lv = ~env),
    value ~ 0 + trait + kernel_unique(site, K = K, lv = ~env),
    value ~ 0 + trait + kernel_indep(site, K = K, lv = ~env),
    value ~ 0 + trait + kernel_dep(site, K = K, lv = ~env)
  )

  for (f in source_specific_lv) {
    expect_error(
      suppressMessages(suppressWarnings(gllvmTMB:::desugar_brms_sugar(f))),
      regexp = "reserved for ordinary.*latent|silently dropping"
    )
  }
})

test_that("spatial_latent(unique = TRUE) carries the unique-diagonal parser marker", {
  f_unique <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1, unique = TRUE)
  )
  txt_unique <- paste(deparse(f_unique), collapse = " ")
  expect_match(txt_unique, ".spatial_latent = TRUE", fixed = TRUE)
  expect_match(txt_unique, ".spatial_unique_diag = TRUE", fixed = TRUE)

  f_low_rank <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1)
  )
  txt_low_rank <- paste(deparse(f_low_rank), collapse = " ")
  expect_match(txt_low_rank, ".spatial_latent = TRUE", fixed = TRUE)
  expect_match(txt_low_rank, ".spatial_unique_diag = FALSE", fixed = TRUE)
})

test_that("latent-mode source helpers (spatial/animal/kernel) accept named control arguments (d, unique)", {
  ## Source keywords attach a structure to the LATENT kind -- spatial <->
  ## coords/mesh, animal <-> pedigree, kernel <-> K matrix -- and take the
  ## low-rank / Psi control arguments `d` / `unique` by name, per the
  ## documented grammar (CLAUDE.md / the articles).
  f_spatial <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 2, unique = TRUE)
  )
  txt_spatial <- paste(deparse(f_spatial), collapse = " ")
  expect_match(txt_spatial, "spde", fixed = TRUE)
  expect_match(txt_spatial, "d = 2", fixed = TRUE)
  expect_match(txt_spatial, ".spatial_unique_diag = TRUE", fixed = TRUE)

  f_animal <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + animal_latent(species, d = 2, pedigree = ped)
  )
  txt_animal <- paste(deparse(f_animal), collapse = " ")
  expect_match(txt_animal, "phylo_rr", fixed = TRUE)
  expect_match(txt_animal, "d = 2", fixed = TRUE)

  f_kernel <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + kernel_latent(site, K = K, d = 2, name = "known")
  )
  txt_kernel <- paste(deparse(f_kernel), collapse = " ")
  expect_match(txt_kernel, "phylo_rr", fixed = TRUE)
  expect_match(txt_kernel, "d = 2", fixed = TRUE)
  expect_match(txt_kernel, ".kernel_mode = \"latent\"", fixed = TRUE)
})

test_that("indep is a diagonal kind, distinct from latent (no low-rank part)", {
  ## `indep` is one of the three main correlation kinds (latent / dep / indep),
  ## NOT a latent helper: it desugars to a pure diagonal (`diag(.indep=TRUE)`),
  ## carries no `d`/`unique` low-rank controls, and only takes `common` (shared
  ## vs per-trait variance). It cannot carry a latent / low-rank block.
  f_indep <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + indep(0 + trait | site, common = TRUE)
  )
  txt_indep <- paste(deparse(f_indep), collapse = " ")
  expect_match(txt_indep, "diag", fixed = TRUE)
  expect_match(txt_indep, ".indep = TRUE", fixed = TRUE)
  expect_match(txt_indep, "common = TRUE", fixed = TRUE)
  ## No low-rank factor: the desugar must not introduce an `rr`/`spde` block.
  expect_false(grepl("rr(", txt_indep, fixed = TRUE))
  expect_false(grepl("spde", txt_indep, fixed = TRUE))
})

test_that("control args (d, unique, common) are first-class positional, equivalent to named", {
  ## Positional control arguments desugar BYTE-IDENTICALLY to the named
  ## spelling for every source-latent helper and for indep -- positional is a
  ## first-class alternate spelling, not a tolerated accident. (Structure args
  ## coords/tree/pedigree/K remain first-class positional/named as before.)
  ds <- function(f) paste(deparse(gllvmTMB:::desugar_brms_sugar(f)), collapse = " ")
  expect_identical(
    ds(value ~ 0 + trait + spatial_latent(0 + trait | coords, 2, TRUE)),
    ds(value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 2, unique = TRUE))
  )
  expect_identical(
    ds(value ~ 0 + trait + animal_latent(species, 2, pedigree = ped)),
    ds(value ~ 0 + trait + animal_latent(species, d = 2, pedigree = ped))
  )
  expect_identical(
    ds(value ~ 0 + trait + kernel_latent(site, K = K, 2, name = "known")),
    ds(value ~ 0 + trait + kernel_latent(site, K = K, d = 2, name = "known"))
  )
  expect_identical(
    ds(value ~ 0 + trait + phylo_latent(species, 2, tree = tree)),
    ds(value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree))
  )
  expect_identical(
    ds(value ~ 0 + trait + indep(0 + trait | site, TRUE)),
    ds(value ~ 0 + trait + indep(0 + trait | site, common = TRUE))
  )
})

test_that("PGLLVM foot-gun: phylo_latent + latent/unique without `unit = species` errors", {
  set.seed(7)
  n_sp <- 20
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 7
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label

  expect_error(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 2) +
              latent(0 + trait | species, d = 1) +
              unique(0 + trait | species),
      data = df, phylo_tree = tree
    )),
    regexp = "PGLLVM-style|unit ="
  )
})

## ============================================================
## Phase B: indep / phylo_indep / spatial_indep ("clean trio")
## ============================================================

test_that("indep(0+trait|g) standalone fits identically to unique(0+trait|g) standalone", {
  df <- make_simple()
  fit_indep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = df
  )))
  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | site),
    data = df
  )))
  expect_equal(fit_indep$opt$convergence, 0L)
  expect_equal(fit_unique$opt$convergence, 0L)
  ## Byte-identical objective (same engine path; only the .indep marker differs).
  expect_equal(fit_indep$opt$objective, fit_unique$opt$objective, tolerance = 1e-10)
  ## Use-flag dispatch: indep_B should be TRUE only on the indep fit.
  expect_true(isTRUE(fit_indep$use$indep_B))
  expect_false(isTRUE(fit_unique$use$indep_B))
})

test_that("indep(common = TRUE) is the standalone scalar diagonal replacement", {
  df <- make_simple()
  fit_indep <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site, common = TRUE),
    data = df
  ))
  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(0 + trait | site, common = TRUE),
    data = df
  )))

  expect_equal(fit_indep$opt$convergence, 0L)
  expect_equal(fit_unique$opt$convergence, 0L)
  expect_equal(fit_indep$opt$objective, fit_unique$opt$objective, tolerance = 1e-10)
  expect_true(isTRUE(fit_indep$use$indep_B))
  sds <- as.numeric(fit_indep$report$sd_B)
  expect_lt(max(abs(sds - sds[1L])), 1e-10)
})

test_that("phylo_indep(0+trait|species) standalone fits identically to phylo_unique(species) standalone", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(11)
  n_sp <- 12
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 11
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  fit_indep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species),
    data = df, phylo_tree = tree, unit = "species"
  )))
  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species),
    data = df, phylo_tree = tree, unit = "species"
  )))
  expect_equal(fit_indep$opt$convergence, 0L)
  expect_equal(fit_unique$opt$convergence, 0L)
  expect_equal(fit_indep$opt$objective, fit_unique$opt$objective, tolerance = 1e-10)
  expect_true(isTRUE(fit_indep$use$phylo_indep))
  expect_false(isTRUE(fit_unique$use$phylo_indep))
})

test_that("indep + latent on same grouping is a hard error", {
  df <- make_simple()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | site) +
              latent(0 + trait | site, d = 2),
      data = df
    ))),
    regexp = "over-parameterised|cannot coexist|indep.*latent"
  )
})

test_that("phylo_indep + phylo_latent is a hard error", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(13)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 13
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species) +
              phylo_latent(species, d = 1),
      data = df, phylo_tree = tree, unit = "species"
    ))),
    regexp = "over-parameterised|cannot coexist|phylo_indep.*phylo_latent"
  )
})

test_that("indep + unique on same grouping is a redundancy error", {
  df <- make_simple()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | site) +
              unique(0 + trait | site),
      data = df
    ))),
    regexp = "redundant|mathematically identical|indep.*unique"
  )
})

test_that("print(fit) labels phylo_indep distinctly from phylo_unique", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(15)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 15
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species),
    data = df, phylo_tree = tree, unit = "species"
  )))
  printed <- capture.output(print(fit))
  ## Diagonal phylogenetic terms print as the canonical keyword-free
  ## "phylo_indep" (the deprecated "phylo_unique" spelling is no longer shown).
  expect_true(any(grepl("phylo_indep", printed)))
  expect_false(any(grepl("phylo_unique", printed)))
})

## ============================================================
## Phase E: dep / phylo_dep / spatial_dep ("full unstructured" quartet)
## ============================================================

test_that("dep(0+trait|g) standalone fits identically to latent(0+trait|g, d=n_traits) standalone", {
  df <- make_simple()
  ## make_simple() builds 4 traits; use the literal so parse_covstruct_call's
  ## eval() finds it without depending on the test's local frame.
  fit_dep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + dep(0 + trait | site),
    data = df
  )))
  fit_latent <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 4),
    data = df
  )))
  expect_equal(fit_dep$opt$convergence, 0L)
  expect_equal(fit_latent$opt$convergence, 0L)
  ## Byte-identical objective (same engine path; only the .dep marker differs).
  expect_equal(fit_dep$opt$objective, fit_latent$opt$objective, tolerance = 1e-10)
  ## Use-flag dispatch: dep_B should be TRUE only on the dep fit.
  expect_true(isTRUE(fit_dep$use$dep_B))
  expect_false(isTRUE(fit_latent$use$dep_B))
})

test_that("phylo_dep(0+trait|species) standalone fits identically to phylo_latent(species, d=n_traits) standalone", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(21)
  n_sp <- 12
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 21
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  ## n_traits = 3 from the simulate_site_trait call above; use the literal
  ## so parse_covstruct_call's eval() finds it without scope ambiguity.
  fit_dep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species),
    data = df, phylo_tree = tree, unit = "species"
  )))
  fit_latent <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 3, unique = FALSE),
    data = df, phylo_tree = tree, unit = "species"
  )))
  expect_equal(fit_dep$opt$convergence, 0L)
  expect_equal(fit_latent$opt$convergence, 0L)
  expect_equal(fit_dep$opt$objective, fit_latent$opt$objective, tolerance = 1e-10)
  expect_true(isTRUE(fit_dep$use$phylo_dep))
  expect_false(isTRUE(fit_latent$use$phylo_dep))
})

test_that("dep + latent on same grouping is a hard error", {
  df <- make_simple()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | site) +
              latent(0 + trait | site, d = 2),
      data = df
    ))),
    regexp = "over-parameterised|cannot coexist|dep.*latent"
  )
})

test_that("dep + unique on same grouping is a redundancy error", {
  df <- make_simple()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | site) +
              unique(0 + trait | site),
      data = df
    ))),
    regexp = "redundant|already includes|dep.*unique"
  )
})

test_that("dep + indep on same grouping is a redundancy error", {
  df <- make_simple()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | site) +
              indep(0 + trait | site),
      data = df
    ))),
    regexp = "redundant|already includes|dep.*indep"
  )
})

test_that("phylo_dep + phylo_latent is a hard error", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(23)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 23
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species) +
              phylo_latent(species, d = 1),
      data = df, phylo_tree = tree, unit = "species"
    ))),
    regexp = "over-parameterised|cannot coexist|phylo_dep.*phylo_latent"
  )
})

test_that("phylo_dep + phylo_unique is a redundancy error", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(25)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 25
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species) +
              phylo_unique(species),
      data = df, phylo_tree = tree, unit = "species"
    ))),
    regexp = "redundant|already includes|phylo_dep.*phylo_unique"
  )
})

test_that("phylo_dep + phylo_indep is a redundancy error", {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MCMCglmm")
  set.seed(27)
  n_sp <- 10
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = 27
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species) +
              phylo_indep(0 + trait | species),
      data = df, phylo_tree = tree, unit = "species"
    ))),
    regexp = "redundant|already includes|phylo_dep.*phylo_indep"
  )
})

test_that("spatial_dep + spatial_latent is a hard error", {
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("INLA")
  set.seed(31)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = 31
  )
  df <- sim$data
  df$x <- runif(nrow(df))
  df$y <- runif(nrow(df))
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("x", "y"), cutoff = 0.1),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(mesh), "mesh build failed")
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | coords) +
              spatial_latent(0 + trait | coords, d = 1),
      data = df, mesh = mesh
    ))),
    regexp = "over-parameterised|cannot coexist|spatial_dep.*spatial_latent"
  )
})

test_that("spatial_dep + spatial_unique is a redundancy error", {
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("INLA")
  set.seed(33)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = 33
  )
  df <- sim$data
  df$x <- runif(nrow(df))
  df$y <- runif(nrow(df))
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("x", "y"), cutoff = 0.1),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(mesh), "mesh build failed")
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | coords) +
              spatial_unique(0 + trait | coords),
      data = df, mesh = mesh
    ))),
    regexp = "redundant|already includes|spatial_dep.*spatial_unique"
  )
})

test_that("spatial_dep + spatial_indep is a redundancy error", {
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("INLA")
  set.seed(35)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = 35
  )
  df <- sim$data
  df$x <- runif(nrow(df))
  df$y <- runif(nrow(df))
  mesh <- tryCatch(
    gllvmTMB::make_mesh(df, c("x", "y"), cutoff = 0.1),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(mesh), "mesh build failed")
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | coords) +
              spatial_indep(0 + trait | coords),
      data = df, mesh = mesh
    ))),
    regexp = "redundant|already includes|spatial_dep.*spatial_indep"
  )
})

test_that("print(fit) labels dep distinctly from latent", {
  df <- make_simple()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + dep(0 + trait | site),
    data = df
  )))
  printed <- capture.output(print(fit))
  ## Stage 4 of design 02 (2026-05-08) renamed user-facing labels from
  ## *_B / *_W to *_unit / *_unit_obs. Print should now show "dep_unit"
  ## (not "dep_B" or just "latent_unit").
  expect_true(any(grepl("dep_unit", printed)))
})

## ============================================================
## scalar(): the no-prefix one-shared-variance mode (Design 79)
## ============================================================

test_that("scalar() desugars byte-identically to indep(common = TRUE)", {
  expect_identical(
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + scalar(0 + trait | site)),
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + indep(0 + trait | site, common = TRUE)
    )
  )
  ## Concretely: a diagonal (.indep) tier with the shared-variance tie and no
  ## low-rank / rr block.
  txt <- paste(deparse(
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + scalar(0 + trait | site))
  ), collapse = " ")
  expect_match(txt, "diag", fixed = TRUE)
  expect_match(txt, ".indep = TRUE", fixed = TRUE)
  expect_match(txt, "common = TRUE", fixed = TRUE)
  expect_false(grepl("rr(", txt, fixed = TRUE))
})

test_that("scalar() fits one shared variance across traits (= indep(common = TRUE))", {
  df <- make_simple()
  fit_scalar <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + scalar(0 + trait | site),
    data = df
  ))
  fit_indep_common <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site, common = TRUE),
    data = df
  )))
  expect_equal(fit_scalar$opt$convergence, 0L)
  ## One shared variance: every trait's sd_B is identical.
  sds <- as.numeric(fit_scalar$report$sd_B)
  expect_gt(length(sds), 1L)
  expect_lt(max(abs(sds - sds[1L])), 1e-10)
  ## Byte-identical fit to the indep(common = TRUE) longhand.
  expect_equal(fit_scalar$opt$objective, fit_indep_common$opt$objective,
               tolerance = 1e-10)
  expect_true(isTRUE(fit_scalar$use$indep_B))
})

test_that("scalar() slope form fails loud (augmented LHS deferred, Design 79)", {
  expect_error(
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + scalar(1 + x | site)),
    regexp = "augmented LHS is not yet supported"
  )
})
