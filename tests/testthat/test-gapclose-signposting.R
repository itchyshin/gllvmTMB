## Task A1 (a)-(c): every changed refusal names a route that fits.
##
## (a) `.assert_no_augmented_lhs` (R/brms-sugar.R) and phylo_indep's own
##     augmented-LHS check redirect conditioned on BOTH the RHS of `|` and
##     the LHS shape (single- vs multi-covariate slope), corrected after
##     an adversarial review (2026-09-02, finding B2) showed the first cut
##     named `phylo_slope()`/`animal_slope()` for ANY non-trait grouping,
##     including ordinary columns (`site`) that have no relatedness
##     structure -- a route that REFUSES. Current contract: trait RHS ->
##     response-column slope grammar (`slope()`/`phylo_slope()`/
##     `animal_slope()`); single-slope non-trait, non-spatial RHS ->
##     `latent()`/`unique()`'s own augmented random-regression engine
##     (verified fitting); more than one slope covariate, or a spatial
##     keyword's non-trait RHS -> no supported single-term route, stated
##     plainly, naming no phylo/animal route for spatial.
## (b) #1196: a random-effect grouping column value-identical to `trait`
##     collides with the fixed per-trait intercepts; abort names the fix.
## (c) #1163: the spatial_*() `| token` grouping is decorative (the field
##     is always driven by `mesh =`/`coords =`); warn once, and the fit is
##     unaffected (logLik identical to the canonical `| coords` spelling).

## ---- Shared fixture: 30 sites, 4 traits, 6 species + a random ultrametric
## tree per grouping axis (species and trait). --------------------------

.gapclose_signposting_fixture <- function(seed = 4001L) {
  testthat::skip_if_not_installed("ape")
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30L, n_species = 6L, n_traits = 4L,
    mean_species_per_site = 6L, seed = seed
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_along(levels(df$species)))
  df$x <- stats::rnorm(nrow(df))
  tree_species <- ape::rcoal(6L, tip.label = levels(df$species))
  tree_trait <- ape::rcoal(4L, tip.label = levels(df$trait))
  list(data = df, tree_species = tree_species, tree_trait = tree_trait)
}

## ---- (a) .assert_no_augmented_lhs: trait-RHS branch -------------------

test_that("indep(1 + x | trait) redirects to the response-column slope grammar", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + indep(1 + x | trait))
  )
})

test_that("phylo_slope(x | trait, tree = tree) -- the named route -- fits", {
  fx <- .gapclose_signposting_fixture()
  tree_trait <- fx$tree_trait
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | trait, tree = tree_trait),
    data = fx$data, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- (a) .assert_no_augmented_lhs: group-axis branch (non-spatial) ----
##
## #1196 B2 correction: an ordinary grouping column (site, not a species/
## pedigree axis) has no relatedness structure, so `phylo_slope()`/
## `animal_slope()` would refuse (no tree covers `site`'s levels). The
## route that actually fits a single-slope augmented LHS is `latent()`/
## `unique()`'s own random-regression engine.

test_that("indep(1 + x | site) redirects to latent()/unique(), not phylo_slope()", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + indep(1 + x | site))
  )
})

test_that("latent(1 + x | site, d = K) and unique(1 + x | site) -- the named routes -- fit", {
  fx <- .gapclose_signposting_fixture()
  fit_latent <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(1 + x | site, d = 1),
    data = fx$data, unit = "site"
  )))
  expect_equal(fit_latent$opt$convergence, 0L)
  fit_unique <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + unique(1 + x | site),
    data = fx$data, unit = "site"
  )))
  expect_equal(fit_unique$opt$convergence, 0L)
})

## The trait-relevant `phylo_slope(x | species, tree = tree)` route remains
## verified fitting on its own merits (a genuine phylogenetic grouping),
## just no longer claimed as the fix for an ORDINARY grouping like `site`.
test_that("phylo_slope(x | species, tree = tree) fits (still true; not named for `site`)", {
  fx <- .gapclose_signposting_fixture()
  tree_species <- fx$tree_species
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_slope(x | species, tree = tree_species),
    data = fx$data, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- (a) .assert_no_augmented_lhs: spatial keywords never name phylo/animal,
## and more-than-one-slope-covariate has no supported route at all -------

test_that("spatial_dep(1 + x1 + x2 | coords) says so plainly, names no phylo/animal route", {
  msg <- tryCatch(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + spatial_dep(1 + x1 + x2 | coords)
    ),
    error = function(e) conditionMessage(e)
  )
  expect_false(grepl("phylo_slope|animal_slope", msg))
  expect_match(msg, "no supported route|fit separate models")
})

## ---- (a) phylo_indep's own augmented-LHS check: trait-RHS branch ------

test_that("phylo_indep(0 + trait + trait:x | trait) redirects to the response-column slope grammar", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_indep(0 + trait + trait:x | trait)
    )
  )
})

## ---- (a) phylo_indep's own augmented-LHS check: group-axis branch -----

test_that("phylo_indep(0 + trait + trait:x | species) redirects to the group-axis slope grammar", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_indep(0 + trait + trait:x | species)
    )
  )
})

## ---- (b) #1196: identical grouping/trait column guard ------------------

test_that("a grouping column value-identical to trait aborts naming the fixed/random collision", {
  fx <- .gapclose_signposting_fixture()
  df <- fx$data
  df$trait_copy <- df$trait
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | trait_copy, d = 1),
      data = df, unit = "site"
    )
  )
})

test_that("a distinct grouping column still fits (no false-positive collision)", {
  fx <- .gapclose_signposting_fixture()
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = fx$data, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- (c) #1163: spatial grouping-token warning --------------------------

.gapclose_spatial_fixture <- function(seed = 5001L) {
  testthat::skip_if_not_installed("fmesher")
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40L, n_species = 1L, n_traits = 3L, mean_species_per_site = 1,
    n_predictors = 1, alpha = rep(0, 3), beta = matrix(0, 3, 1),
    sigma2_eps = 0.3, spatial_range = 0.4, sigma2_spa = rep(0.4, 3),
    seed = seed
  )
  df <- sim$data
  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.15)
  list(data = df, mesh = mesh)
}

test_that("spatial_indep(0 + trait | banana) warns that the grouping token is ignored", {
  testthat::skip_on_cran()
  ## tests/testthat/setup.R sets gllvmTMB.quiet_grammar_notes = TRUE package-
  ## wide; this notice reuses that same one-shot mechanism (like the
  ## unique-family deprecation tests), so both the option and the tracker
  ## key must be reset locally to observe it.
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  fx <- .gapclose_spatial_fixture()
  rlang::env_unbind(
    getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen,
    nms = "spatial-grouping-token-spatial_indep"
  )
  expect_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | banana),
      data = fx$data, unit = "site", mesh = fx$mesh
    )),
    regexp = "grouping token is ignored"
  )
})

test_that("spatial_indep(0 + trait | banana) fits identically to the canonical | coords spelling", {
  testthat::skip_on_cran()
  fx <- .gapclose_spatial_fixture()
  fit_banana <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | banana),
    data = fx$data, unit = "site", mesh = fx$mesh
  )))
  fit_coords <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | coords),
    data = fx$data, unit = "site", mesh = fx$mesh
  )))
  expect_equal(
    as.numeric(stats::logLik(fit_banana)),
    as.numeric(stats::logLik(fit_coords))
  )
})

## ---- R2 (adversarial review 2026-09-02): fit-multi.R's "only one X"
## ceiling-family bullets. Four of five originally said "combine the
## covariates into one term" naming a formula the parser refuses; only
## `phylo_latent(1 + x1 + x2 | species, d = K, tree = tree)` actually
## parses AND fits. The other four now say plainly there is no supported
## multi-covariate route. ---------------------------------------------

test_that("the ordinary-latent 'only one X at unit tier' bullet says no route exists, not a route that refuses", {
  fx <- .gapclose_signposting_fixture()
  df <- fx$data
  df$x2 <- stats::rnorm(nrow(df))
  msg <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        latent(1 + x | site, d = 1) + latent(1 + x2 | site, d = 1),
      data = df, unit = "site"
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(msg, "no supported multi-covariate route")
  expect_false(grepl("Combine the covariates into one term", msg))
})

test_that("phylo_latent(1 + x1 + x2 | species, d = K, tree = tree) -- the one route that DOES fit -- fits", {
  fx <- .gapclose_signposting_fixture()
  df <- fx$data
  df$x1 <- df$x
  df$x2 <- stats::rnorm(nrow(df))
  tree_species <- fx$tree_species
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(1 + x1 + x2 | species, d = 1, tree = tree_species),
    data = df, unit = "site"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

## ---- R3/R4 (adversarial review 2026-09-02): the runaway-loading advice in
## R/diagnose.R shipped a literal unbound `tau` symbol
## (`gllvmTMBcontrol(loading_ridge = tau)` -> "object 'tau' not found") and
## offered `integration = "va"` with no stated precondition, though the VA
## fence refuses the default latent() model, n < 100, and d > 2. Both
## messages now name a runnable literal (`loading_ridge = 0.25`, the pre-run
## arm that cleared the flag) and state VA's precondition in one clause. ---

test_that("the diagnose.R runaway-loading messages name a runnable ridge literal, not `tau`", {
  root <- .gapclose_repo_root()
  testthat::skip_if(is.null(root), "repo files not available (installed copy)")
  txt <- paste(
    readLines(file.path(root, "R", "diagnose.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_false(grepl("loading_ridge = tau\\)", txt, fixed = FALSE))
  expect_true(grepl("loading_ridge = 0.25", txt, fixed = TRUE))
  ## The exact call named in the message must itself be valid, runnable R.
  expect_no_error(gllvmTMB::gllvmTMBcontrol(loading_ridge = 0.25))
})

test_that("the diagnose.R runaway-loading messages state VA's precondition, not an unconditional offer", {
  root <- .gapclose_repo_root()
  testthat::skip_if(is.null(root), "repo files not available (installed copy)")
  txt <- paste(
    readLines(file.path(root, "R", "diagnose.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl(
    "integration = 'va'\\) for latent\\(\\.\\.\\., unique = FALSE\\) fits with at least 100 units and d <= 2",
    txt
  ))
})

## ---- Regression (found while fixing R7): the #1196 collision guard also
## false-positived on `animal_scalar()`/`phylo_scalar()`'s `common = TRUE`
## collapse, which desugars to `propto(0 + species | trait, Ainv)` -- a
## SYNTHETIC literal `trait` group symbol, not a user-chosen column, the
## same defect class as the earlier `phylo_rr` false positive but under a
## different covstruct kind the first fix did not cover. -----------------

test_that("animal_scalar()/propto()'s synthetic trait-literal group does not false-positive the collision guard", {
  ped <- data.frame(
    id   = paste0("i", 1:12),
    sire = c(rep(NA, 4), rep(c("i1", "i2"), length.out = 8)),
    dam  = c(rep(NA, 4), rep(c("i3", "i4"), length.out = 8))
  )
  set.seed(1)
  A <- gllvmTMB::pedigree_to_A(ped)
  yvec <- as.numeric(MASS::mvrnorm(
    1, mu = rep(0, 2 * 12),
    Sigma = kronecker(diag(2), A) * 0.5 + diag(2 * 12) * 0.5
  ))
  df <- data.frame(
    species = factor(rep(ped$id, each = 2), levels = ped$id),
    trait   = factor(rep(c("t1", "t2"), times = 12), levels = c("t1", "t2")),
    value   = yvec
  )
  fit <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = ped),
    data = df, unit = "species", family = gaussian()
  )))
  expect_equal(fit$opt$convergence, 0L)
})
