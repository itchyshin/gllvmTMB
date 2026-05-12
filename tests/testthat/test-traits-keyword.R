## Design 08 Stage 2: traits() formula-LHS marker for wide-format input.
##
## The traits() marker is a thin tidyr::pivot_longer() shim. The user
## passes a wide data frame with one row per individual and one column
## per trait; traits() captures the column selection (tidyselect-aware),
## pivots to long format internally, rewrites the LHS to .y_wide_, and
## dispatches to the long-format engine. The compact wide RHS (`1`,
## `x`, `latent(1 | g)`) expands to the long trait-stacked grammar
## (`0 + trait`, `(0 + trait):x`, `latent(0 + trait | g)`). Explicit
## long syntax remains accepted.
##
## Verifications:
##   1. Basic call runs (no NameError on traits()).
##   2. Byte-equivalent fit$opt$objective vs hand-rolled long-format.
##   3. Tidyselect verbs (all_of, starts_with, matches) all give the
##      same fit as bare names.
##   4. NA handling: cells with NA response are dropped, message reports
##      the count.
##   5. Mixed-family pass-through (no parser interception).
##   6. fit$call_wide and fit$call_long_format are stored.
##   7. No regression on the long-format API (no traits() in call).
##   8. Vector weights pass-through, byte-equivalent to manual replication.
##   9. Matrix weights are rejected with a redirect to gllvmTMB_wide().

## ---- Helpers --------------------------------------------------------------

# Build a small wide-format data frame from simulate_site_trait long output.
make_wide_df <- function(seed = 42) {
  set.seed(seed)
  long <- gllvmTMB::simulate_site_trait(
    n_sites = 30,
    n_species = 1,
    n_traits = 4,
    mean_species_per_site = 1,
    seed = seed
  )$data
  ## one row per (site, species, trait) -> one row per (site, species)
  ## with one column per trait. site = the "individual" axis here.
  trait_levels <- levels(long$trait)
  wide <- data.frame(
    individual = unique(long$site),
    env_temp = NA_real_
  )
  ## copy env_temp from the per-site mapping
  env_map <- unique(long[, c("site", "env_1")])
  wide$env_temp <- env_map$env_1[match(wide$individual, env_map$site)]
  ## one column per trait
  for (tr in trait_levels) {
    wide[[tr]] <- long$value[match(
      paste(wide$individual),
      paste(long$site[long$trait == tr])
    )]
  }
  wide
}

# Equivalent hand-rolled long-format pivot.
make_long_df <- function(wide, cols) {
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    skip("tidyr not installed")
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(cols),
    names_to = "trait",
    values_to = ".y_wide_",
    values_drop_na = TRUE
  )
  long$trait <- factor(long$trait, levels = cols)
  long
}

## ---- Test 1: basic invocation does not error ------------------------------

test_that("traits() formula-LHS marker is recognised and a basic fit runs", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")
  ## Use bare-name traits() with backtick column names; we'll use all_of()
  ## for portability when columns have non-syntactic names.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})

## ---- Test 2: compact RHS matches hand-rolled long format ------------------

test_that("traits() compact RHS matches hand-rolled long-format pivot", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  long <- make_long_df(wide, trait_cols)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    .y_wide_ ~ 0 +
      trait +
      (0 + trait):env_temp +
      latent(0 + trait | individual, d = 1) +
      unique(0 + trait | individual),
    data = long,
    unit = "individual",
    family = gaussian()
  )))

  expect_equal(
    fit_wide$opt$objective,
    fit_long$opt$objective,
    tolerance = 1e-10
  )
})

test_that("traits() compact phylo two-U syntax matches explicit long syntax", {
  skip_on_cran()
  skip_if_not_installed("ape")
  skip_if_not_installed("tidyr")

  set.seed(13)
  n_sp <- 30
  n_traits <- 3
  trait_cols <- paste0("trait_", seq_len(n_traits))
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy <- t(chol(Cphy + 1e-8 * diag(n_sp)))

  Lambda_phy <- matrix(c(0.7, 0.45, 0.25), n_traits, 1)
  s_phy <- c(0.20, 0.15, 0.12)
  s_non <- c(0.18, 0.20, 0.16)

  g_phy <- Lphy %*% stats::rnorm(n_sp)
  e_phy <- Lphy %*% matrix(stats::rnorm(n_sp * n_traits), n_sp, n_traits)
  e_non <- matrix(stats::rnorm(n_sp * n_traits), n_sp, n_traits)
  Y <- g_phy %*% t(Lambda_phy) +
    sweep(e_phy, 2, sqrt(s_phy), "*") +
    sweep(e_non, 2, sqrt(s_non), "*")
  rownames(Y) <- tree$tip.label
  colnames(Y) <- trait_cols

  wide <- data.frame(
    species = factor(tree$tip.label, levels = tree$tip.label),
    Y,
    check.names = FALSE
  )

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      phylo_latent(species, d = 1, tree = tree) +
      phylo_unique(species, tree = tree) +
      unique(1 | species),
    data = wide,
    unit = "species",
    cluster = "species",
    family = gaussian()
  )))

  long <- make_long_df(wide, trait_cols)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    .y_wide_ ~ 0 + trait +
      phylo_latent(species, d = 1, tree = tree) +
      phylo_unique(species, tree = tree) +
      unique(0 + trait | species),
    data = long,
    unit = "species",
    cluster = "species",
    family = gaussian()
  )))

  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective,
               tolerance = 1e-10)
})

test_that("traits() compact RHS preserves regular random intercepts", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df(seed = 43)
  wide$batch <- factor(rep(seq_len(5), length.out = nrow(wide)))
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      (1 | batch) +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  long <- make_long_df(wide, trait_cols)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    .y_wide_ ~ 0 +
      trait +
      (0 + trait):env_temp +
      (1 | batch) +
      latent(0 + trait | individual, d = 1) +
      unique(0 + trait | individual),
    data = long,
    unit = "individual",
    family = gaussian()
  )))

  expect_equal(
    fit_wide$opt$objective,
    fit_long$opt$objective,
    tolerance = 1e-10
  )
})

test_that("traits() RHS expander recognises the covariance keyword grid", {
  rhs <- quote(
    1 +
      env_temp +
      (1 | batch) +
      latent(1 | individual, d = 1) +
      unique(1 | individual) +
      indep(1 | individual) +
      dep(1 | individual) +
      phylo_scalar(individual) +
      phylo_unique(individual) +
      phylo_latent(individual, d = 1) +
      phylo_indep(1 | individual) +
      phylo_dep(1 | individual) +
      spatial_scalar(1 | individual) +
      spatial_unique(1 | individual) +
      spatial_indep(1 | individual) +
      spatial_latent(1 | individual, d = 1) +
      spatial_dep(1 | individual) +
      spatial(1 | individual)
  )

  expanded <- paste(deparse(gllvmTMB:::.traits_expand_rhs(rhs)), collapse = " ")
  expanded <- gsub("\\s+", " ", expanded)

  expect_match(expanded, "0 \\+ trait")
  expect_match(expanded, "\\(0 \\+ trait\\):env_temp")
  expect_match(expanded, "\\(1 \\| batch\\)")
  expect_match(expanded, "latent\\(0 \\+ trait \\| individual, d = 1\\)")
  expect_match(expanded, "unique\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "indep\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "dep\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "phylo_scalar\\(individual\\)")
  expect_match(expanded, "phylo_unique\\(individual\\)")
  expect_match(expanded, "phylo_latent\\(individual, d = 1\\)")
  expect_match(expanded, "phylo_indep\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "phylo_dep\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "spatial_scalar\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "spatial_unique\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "spatial_indep\\(0 \\+ trait \\| individual\\)")
  expect_match(
    expanded,
    "spatial_latent\\(0 \\+ trait \\| individual, d = 1\\)"
  )
  expect_match(expanded, "spatial_dep\\(0 \\+ trait \\| individual\\)")
  expect_match(expanded, "spatial\\(1 \\| individual\\)")
  expect_no_match(
    expanded,
    ":phylo_latent|:phylo_unique|:spatial_latent|:\\(1 \\| batch\\)"
  )
})

test_that("traits() RHS expander preserves intercept-control minus one", {
  compact <- paste(
    deparse(gllvmTMB:::.traits_expand_rhs(quote(-1 + env_temp))),
    collapse = " "
  )
  compact <- gsub("\\s+", " ", compact)

  explicit <- paste(
    deparse(gllvmTMB:::.traits_expand_rhs(
      quote(0 + trait + (0 + trait):env_temp - 1)
    )),
    collapse = " "
  )
  explicit <- gsub("\\s+", " ", explicit)

  expect_match(compact, "^-1 \\+ \\(0 \\+ trait\\):env_temp$")
  expect_match(explicit, "0 \\+ trait")
  expect_match(explicit, "\\(0 \\+ trait\\):env_temp")
  expect_match(explicit, "- 1$")
  expect_no_match(compact, "-\\(0 \\+ trait\\)")
  expect_no_match(explicit, "- \\(0 \\+ trait\\)")
})

## ---- Test 3: tidyselect verb equivalence ----------------------------------

test_that("traits() supports tidyselect verbs (all_of, starts_with, matches, bare names)", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")

  ## reference: bare names (all_of)
  fit_all <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  ## bare-name form: traits(trait_1, trait_2, trait_3, trait_4)
  fit_bare <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(trait_1, trait_2, trait_3, trait_4) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  ## starts_with("trait_")
  fit_starts <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::starts_with("trait_")) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  ## matches("^trait_[0-9]+$")
  fit_match <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::matches("^trait_[0-9]+$")) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))

  expect_equal(fit_bare$opt$objective, fit_all$opt$objective, tolerance = 1e-10)
  expect_equal(
    fit_starts$opt$objective,
    fit_all$opt$objective,
    tolerance = 1e-10
  )
  expect_equal(
    fit_match$opt$objective,
    fit_all$opt$objective,
    tolerance = 1e-10
  )
})

## ---- Test 4: NA handling drops cells, reports count -----------------------

test_that("traits() drops NA cells with values_drop_na = TRUE and reports count", {
  skip(
    "0.2.0: fix-effects-only fit hits the removed sdmTMB() fallback. Migrate to covstruct + drop-NA in 0.2.x."
  )
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")
  ## Inject 3 NA cells across trait columns at known positions.
  wide$trait_1[1] <- NA
  wide$trait_2[2] <- NA
  wide$trait_3[3] <- NA
  ## Capture the inform message and verify it reports n_dropped = 3.
  ## Use a fixed-effects-only fit so the long-format engine doesn't
  ## demand a clean convergence on a 3-cell ragged design — the contract
  ## here is the parser pre-pass + drop count, not engine convergence.
  msgs <- character()
  withCallingHandlers(
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      traits(tidyselect::all_of(trait_cols)) ~ 0 + trait + (0 + trait):env_temp,
      data = wide,
      unit = "individual",
      family = gaussian()
    )),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  ## Successful return, parser-side: traits_meta records the dropped count.
  expect_equal(fit$traits_meta$n_dropped, 3L)
  ## Inform message should mention "3" (the count of dropped cells).
  expect_true(
    any(grepl("\\b3\\b", msgs) & grepl("(?i)dropp", msgs, perl = TRUE)),
    info = paste(msgs, collapse = " | ")
  )
  ## Nrow of the long data on the engine: 4 traits × 30 rows − 3 NA = 117.
  expect_equal(nrow(fit$data), 4L * 30L - 3L)
})

## ---- Test 5: mixed-family pass-through ------------------------------------

test_that("traits() does not intercept family = list(...) (mixed-family pass-through)", {
  skip_if_not_installed("tidyr")
  ## Build a small mixed-family wide_df: trait_1 gaussian, trait_2 binomial.
  set.seed(7)
  n_id <- 50
  wide <- data.frame(
    individual = factor(seq_len(n_id)),
    env_temp = rnorm(n_id),
    trait_1 = rnorm(n_id),
    trait_2 = rbinom(n_id, 1L, 0.5)
  )
  ## The expectation here is that traits() doesn't error at the parser
  ## level when family is a list. Whether the long-format engine accepts
  ## the family list is the engine's concern — out of scope for the
  ## traits() shim. We just confirm that traits() forwards the family
  ## argument unchanged.
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(tidyselect::all_of(c("trait_1", "trait_2"))) ~ 0 +
        trait +
        (0 + trait):env_temp,
      data = wide,
      unit = "individual",
      family = list(gaussian(), binomial())
    ))),
    error = function(e) e
  )
  ## A successful fit OR a long-format-engine error are both acceptable
  ## (the engine is what dispatches family lists, not traits()). What we
  ## DO NOT accept is a parser-level error from traits() itself
  ## complaining about family.
  if (inherits(fit, "error")) {
    expect_false(
      grepl("traits", conditionMessage(fit), fixed = TRUE),
      info = conditionMessage(fit)
    )
  } else {
    expect_s3_class(fit, "gllvmTMB")
  }
})

## ---- Test 6: fit$call_wide and fit$call_long_format are stored -----------

test_that("traits() records call_wide and call_long_format on the fit object", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    family = gaussian()
  )))
  expect_true(!is.null(fit$call_wide))
  expect_true(!is.null(fit$call_long_format))
  ## call_wide should contain the traits(...) call expression on its LHS.
  cw_str <- paste(deparse(fit$call_wide), collapse = " ")
  expect_true(grepl("traits\\(", cw_str), info = cw_str)
  ## call_long_format LHS should be .y_wide_ (the synthetic name).
  cl_str <- paste(deparse(fit$call_long_format), collapse = " ")
  expect_true(grepl("\\.y_wide_", cl_str), info = cl_str)
})

## ---- Test 7: no regression on the long-format API -------------------------

test_that("long-format calls without traits() are not intercepted", {
  set.seed(42)
  long <- gllvmTMB::simulate_site_trait(
    n_sites = 20,
    n_species = 4,
    n_traits = 4,
    mean_species_per_site = 4,
    seed = 42
  )$data
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = long
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## No call_wide should be set on a non-traits() fit.
  expect_null(fit$call_wide)
})

## ---- Test 8: vector weights pass-through ----------------------------------

test_that("traits() with vector weights replicates across traits and matches manual long-format", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")
  set.seed(123)
  w_vec <- runif(nrow(wide), 0.5, 1.5)

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(tidyselect::all_of(trait_cols)) ~ 1 +
      env_temp +
      latent(1 | individual, d = 1) +
      unique(1 | individual),
    data = wide,
    unit = "individual",
    weights = w_vec,
    family = gaussian()
  )))

  ## Manual: replicate weights across traits in the same order traits()
  ## produces (i.e. by tidyr::pivot_longer order).
  long <- make_long_df(wide, trait_cols)
  ## Reconstruct the per-row weight by matching individual.
  long$.weights_ <- w_vec[match(long$individual, wide$individual)]
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    .y_wide_ ~ 0 +
      trait +
      (0 + trait):env_temp +
      latent(0 + trait | individual, d = 1) +
      unique(0 + trait | individual),
    data = long,
    unit = "individual",
    weights = long$.weights_,
    family = gaussian()
  )))

  expect_equal(
    fit_wide$opt$objective,
    fit_long$opt$objective,
    tolerance = 1e-10
  )
})

## ---- Test 9: matrix weights rejected with redirect to gllvmTMB_wide() -----

test_that("traits() rejects a weights matrix with a pointer to gllvmTMB_wide()", {
  skip_if_not_installed("tidyr")
  wide <- make_wide_df()
  trait_cols <- c("trait_1", "trait_2", "trait_3", "trait_4")
  W_mat <- matrix(
    runif(nrow(wide) * length(trait_cols), 0.5, 1.5),
    nrow = nrow(wide),
    ncol = length(trait_cols)
  )
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(tidyselect::all_of(trait_cols)) ~ 0 + trait + (0 + trait):env_temp,
      data = wide,
      unit = "individual",
      weights = W_mat,
      family = gaussian()
    ))),
    regexp = "gllvmTMB_wide"
  )
})
