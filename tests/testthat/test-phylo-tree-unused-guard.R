## Two user-facing safety bugs in the phylogenetic validation path
## (2026-07-25). Neither changes any likelihood; both are typed
## diagnostics / a propagation fix on top of existing engine paths.
## See dev/s1-phylo-validation-fixes-RESULTS.md and
## dev/s0-rederive-two-tree-RESULTS.md for the underlying derivation.
##
## Bug 1(a) -- a tree/vcv supplied to gllvmTMB() (globally, or via an
## in-keyword `tree =`/`vcv =`) but consumed by NO term at all (no
## phylo_*() term in the formula) is now a typed ERROR: unambiguous user
## error, the formula and the tree argument disagree.
##
## Bug 1(b) -- a tree IS consumed by a diagonal/marginal phylo term
## (`phylo_indep()`, `phylo_unique()`, `phylo_scalar()`,
## `phylo_indep(common = TRUE)`), but the data layout makes the tree's
## cross-species structure structurally unreachable (every `trait`-role
## level is observed for at most one `species` level -- the JSDM
## trait-IS-species naming clash). This is now a typed WARNING: the fit
## is real and well-identified for the marginal variance, just silently
## uninformative about the tree. `phylo_dep()`/`phylo_latent()` (which
## DO propagate the tree in the identical layout) must NOT trigger it.
##
## Bug 2 -- `phylo_scalar()` / `phylo_indep(common = TRUE)` desugar to
## `propto()` internally; an in-keyword `tree = my_tree` on those two
## keywords used to be silently dropped by the propto engine path (which
## only looked at the dense/sparse `phylo_vcv`, never the harvested
## `phylo_tree`), throwing a false "propto() found in formula but
## phylo_vcv is NULL" even when a perfectly valid tree was supplied.
## Fixed by building the same sparse tree precision the phylo_rr/
## phylo_latent path already uses and marginalising it to the observed
## tips.

skip_if_no_ape <- function() {
  testthat::skip_if_not_installed("ape")
}

make_star_tree <- function(labels) {
  ## A minimal valid ultrametric tree over `labels`; used where the
  ## specific topology does not matter (Bug 1a/1b structural checks).
  skip_if_no_ape()
  set.seed(2026L)
  tr <- ape::rcoal(length(labels))
  tr$tip.label <- labels
  tr
}

## ---------------------------------------------------------------------
## Bug 1(a): tree/vcv supplied, formula has no phylo_*() term at all.
## ---------------------------------------------------------------------

test_that("global phylo_tree with no phylo_*() term in the formula errors", {
  skip_if_no_ape()
  sp_labels <- paste0("sp", 1:5)
  tree <- make_star_tree(sp_labels)
  set.seed(1L)
  d <- expand.grid(
    site = factor(paste0("site", 1:10)),
    trait = factor(paste0("t", 1:5))
  )
  d$value <- stats::rnorm(nrow(d))

  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + dep(0 + trait | site),
      data = d, unit = "site", family = gaussian(),
      phylo_tree = tree, control = gllvmTMBcontrol(se = FALSE)
    )),
    "no phylogenetic term"
  )
})

test_that("global phylo_vcv with no phylo_*() term in the formula errors", {
  skip_if_no_ape()
  sp_labels <- paste0("sp", 1:5)
  tree <- make_star_tree(sp_labels)
  Cphy <- ape::vcv(tree, corr = TRUE)
  set.seed(1L)
  d <- expand.grid(
    site = factor(paste0("site", 1:10)),
    trait = factor(paste0("t", 1:5))
  )
  d$value <- stats::rnorm(nrow(d))

  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = d, unit = "site", family = gaussian(),
      phylo_vcv = Cphy, control = gllvmTMBcontrol(se = FALSE)
    )),
    "no phylogenetic term"
  )
})

test_that("a real phylo_*() term does not trigger the no-consumer error", {
  ## Regression guard on the guard itself: a legitimate phylo_latent()
  ## fit with a global phylo_tree must NOT hit the new abort.
  skip_if_no_ape()
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  set.seed(2L)
  d <- expand.grid(
    species = factor(sp_labels),
    trait = factor(paste0("t", 1:4))
  )
  d$value <- stats::rnorm(nrow(d))

  expect_no_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = d, unit = "species", cluster = "species", family = gaussian(),
      phylo_tree = tree, control = gllvmTMBcontrol(se = FALSE)
    )))
  )
})

## ---------------------------------------------------------------------
## Bug 1(b): diagonal/marginal phylo terms in a structurally-unreachable
## (trait-IS-species) layout warn; phylo_dep()/phylo_latent() and the
## legitimate unit = species layout must NOT warn.
## ---------------------------------------------------------------------

make_jsdm_trait_is_species_data <- function(sp_labels, tree, n_site = 12L, seed = 11L) {
  ## unit = site, cluster = species, and the `trait` column literally
  ## holds species identity -- the pathological layout from
  ## dev/s0-rederive-two-tree-RESULTS.md E1: each trait level is
  ## observed for exactly one species level, so the diagonal phylo modes
  ## can never compare two species within the same factor column.
  set.seed(seed)
  d <- expand.grid(
    site = factor(paste0("site", seq_len(n_site))),
    species = factor(sp_labels)
  )
  d$trait <- d$species
  A_true <- ape::vcv(tree, corr = TRUE)[sp_labels, sp_labels]
  z_true <- as.numeric(
    mvtnorm::rmvnorm(1, sigma = 4 * A_true, checkSymmetry = FALSE)
  )
  names(z_true) <- sp_labels
  d$value <- z_true[as.character(d$species)] + stats::rnorm(nrow(d), 0, 0.2)
  d
}

test_that("phylo_indep() warns when the tree is structurally unreachable", {
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  expect_warning(
    fit <- gllvmTMB(
      value ~ 1 + phylo_indep(0 + trait | species, tree = tree),
      data = d, unit = "site", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    "cannot enter the likelihood"
  )
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo_unique() (compatibility alias) also warns", {
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  ## Capture ALL warnings (including phylo_unique()'s own soft-deprecation
  ## notice) and check the unreachable-tree warning is among them, rather
  ## than using expect_warning() (which only checks the first).
  msgs <- character(0)
  fit <- withCallingHandlers(
    gllvmTMB(
      value ~ 1 + phylo_unique(species, tree = tree),
      data = d, unit = "site", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("cannot enter the likelihood", msgs, fixed = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo_scalar() / phylo_indep(common = TRUE) also warn (propto path)", {
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  msgs <- character(0)
  fit <- withCallingHandlers(
    gllvmTMB(
      value ~ 1 + phylo_indep(0 + trait | species, tree = tree, common = TRUE),
      data = d, unit = "site", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("cannot enter the likelihood", msgs, fixed = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo_dep() does NOT warn in the identical trait-IS-species layout", {
  ## Positive control: phylo_dep() shares factor columns across species
  ## by construction, so the tree DOES enter the likelihood here (see
  ## E1c in dev/s0-rederive-two-tree-RESULTS.md) -- the guard must not
  ## fire for it.
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  msgs <- character(0)
  fit <- withCallingHandlers(
    gllvmTMB(
      value ~ 1 + phylo_dep(0 + trait | species, tree = tree),
      data = d, unit = "site", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("cannot enter the likelihood", msgs, fixed = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo_latent(unique = TRUE) (folded loadings + diag) does NOT warn", {
  ## The folded form auto-emits a companion diagonal phylo_rr term
  ## (`.auto_unique`), but ALSO keeps the loadings term -- is_phylo_unique
  ## is FALSE whenever a loadings phylo_rr term is also present, so this
  ## must not trigger the diagonal-only guard.
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  msgs <- character(0)
  withCallingHandlers(
    gllvmTMB(
      value ~ 1 + phylo_latent(species, d = 1, tree = tree, unique = TRUE),
      data = d, unit = "site", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    },
    error = function(e) NULL
  )
  expect_false(any(grepl("cannot enter the likelihood", msgs, fixed = TRUE)))
})

test_that("phylo_indep() does NOT warn in the legitimate unit = species layout", {
  ## The documented layout (unit = species, cluster = species, `trait`
  ## a genuinely separate axis): every trait level is shared by ALL
  ## species, so the tree is reachable and the guard must stay silent.
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  set.seed(33L)
  n_trait <- 4L
  A_true <- ape::vcv(tree, corr = TRUE)[sp_labels, sp_labels]
  z_sp <- as.numeric(mvtnorm::rmvnorm(1, sigma = A_true))
  names(z_sp) <- sp_labels
  lambda_t <- c(1.0, -0.8, 0.6, 0.9)[seq_len(n_trait)]
  grid <- expand.grid(
    species = sp_labels, trait = paste0("t", seq_len(n_trait)),
    stringsAsFactors = FALSE
  )
  grid$eta <- lambda_t[match(grid$trait, paste0("t", seq_len(n_trait)))] *
    z_sp[grid$species]
  grid$value <- grid$eta + stats::rnorm(nrow(grid), 0, 0.3)
  grid$species <- factor(grid$species, levels = sp_labels)
  grid$trait <- factor(grid$trait, levels = paste0("t", seq_len(n_trait)))

  msgs <- character(0)
  fit <- withCallingHandlers(
    gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree),
      data = grid, unit = "species", cluster = "species", family = gaussian(),
      control = gllvmTMBcontrol(se = FALSE)
    ),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("cannot enter the likelihood", msgs, fixed = TRUE)))
  expect_equal(fit$opt$convergence, 0L)
})

## ---------------------------------------------------------------------
## Bug 2: phylo_scalar() / phylo_indep(common = TRUE) with an in-keyword
## tree = must no longer throw the false "phylo_vcv is NULL" error, and
## must give the SAME fit as the equivalent dense vcv = route.
## ---------------------------------------------------------------------

test_that("phylo_scalar(species, tree = ) fits instead of erroring", {
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  fit <- suppressWarnings(gllvmTMB(
    value ~ 1 + phylo_scalar(species, tree = tree),
    data = d, unit = "site", cluster = "species", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_true(fit$use$propto)
  expect_equal(fit$opt$convergence, 0L)
})

test_that("phylo_indep(common = TRUE, tree = ) fits instead of erroring", {
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)

  fit <- suppressWarnings(gllvmTMB(
    value ~ 1 + phylo_indep(0 + trait | species, tree = tree, common = TRUE),
    data = d, unit = "site", cluster = "species", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_true(fit$use$propto)
  expect_equal(fit$opt$convergence, 0L)
})

test_that("propto in-keyword tree = route agrees with the dense vcv = route", {
  ## The bug fix builds Cphy_inv from the tree via the same sparse
  ## precision + marginalisation machinery the phylo_rr path uses; this
  ## must numerically agree with supplying the equivalent dense phylo
  ## correlation matrix directly, not merely avoid the error.
  skip_if_no_ape()
  testthat::skip_if_not_installed("mvtnorm")
  sp_labels <- paste0("sp", 1:6)
  tree <- make_star_tree(sp_labels)
  d <- make_jsdm_trait_is_species_data(sp_labels, tree)
  Cphy <- ape::vcv(tree, corr = TRUE)[sp_labels, sp_labels]

  fit_tree <- suppressWarnings(gllvmTMB(
    value ~ 1 + phylo_scalar(species, tree = tree),
    data = d, unit = "site", cluster = "species", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  fit_vcv <- suppressWarnings(gllvmTMB(
    value ~ 1 + phylo_scalar(species, vcv = Cphy),
    data = d, unit = "site", cluster = "species", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_equal(fit_tree$opt$objective, fit_vcv$opt$objective, tolerance = 1e-8)
  expect_equal(as.numeric(logLik(fit_tree)), as.numeric(logLik(fit_vcv)), tolerance = 1e-8)
})
