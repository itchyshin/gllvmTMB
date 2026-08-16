## Multinomial (family_id 16) structured-term admission fence (Slice 0,
## Design 108/122). Confirms every deferred keyword combined with a
## multinomial() trait fails loud rather than silently reaching an
## untested categorical path, and that the current admitted set (a shared
## unit-tier latent() ordination, phylo_latent(), and the default auto-Psi)
## still fits. See R/multinomial-fence.R for the leak this closes.
##
## Most cells below are caught by the EARLY covstruct-keyed classifier
## (class "gllvmTMB_multinomial_structured_not_admitted"); phylo_scalar() /
## animal_scalar() and mi() are caught only by the LATE use_* re-scan
## (belt-and-braces; no special class), so those use a regexp instead.

.mn_fence_data <- function(seed = 1L, n = 60L, K = 3L) {
  set.seed(seed)
  data.frame(
    unit = factor(seq_len(n)), trait = factor("morph"),
    value = factor(sample.int(K, n, replace = TRUE)),
    x = stats::rnorm(n)
  )
}

.mn_fence_phylo_data <- function(seed = 11L, n = 20L, K = 3L) {
  set.seed(seed)
  tree <- ape::rcoal(n); tree$tip.label <- paste0("sp", seq_len(n))
  df <- data.frame(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait = factor("morph"),
    value = factor(sample.int(K, n, replace = TRUE))
  )
  list(data = df, tree = tree)
}

.mn_not_admitted <- "gllvmTMB_multinomial_structured_not_admitted"

## ---- Blocked: unit-tier dep() -------------------------------------------

test_that("dep() at the unit tier is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(1L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + dep(0 + trait | unit), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: explicit unique()/indep() at the unit tier -----------------

test_that("explicit unique() at the unit tier is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(2L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + unique(0 + trait | unit), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

test_that("explicit indep() at the unit tier is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(3L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: generic (1 | group) random intercept -----------------------

test_that("(1 | group) is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(4L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + (1 | unit), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: unit_obs ("within") tier ------------------------------------

test_that("latent() at the unit_obs tier is not admitted for multinomial", {
  skip_on_cran()
  set.seed(5L)
  n_unit <- 20L
  df <- data.frame(
    unit = factor(rep(seq_len(n_unit), each = 2L)),
    site_species = factor(seq_len(n_unit * 2L)),
    trait = factor("morph"),
    value = factor(sample.int(3L, n_unit * 2L, replace = TRUE))
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | site_species, d = 1),
             data = df, family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: cluster tier (indep(0 + trait | g) via `cluster =`) --------

test_that("indep() at the cluster tier is not admitted for multinomial", {
  skip_on_cran()
  set.seed(6L)
  n <- 40L
  df <- data.frame(
    unit = factor(seq_len(n)), species = factor(rep(seq_len(10L), length.out = n)),
    trait = factor("morph"), value = factor(sample.int(3L, n, replace = TRUE))
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + indep(0 + trait | species), data = df,
             family = multinomial(), trait = "trait", unit = "unit",
             cluster = "species"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: cluster2 tier -----------------------------------------------

test_that("indep() at the cluster2 tier is not admitted for multinomial", {
  skip_on_cran()
  set.seed(7L)
  n <- 40L
  df <- data.frame(
    unit = factor(seq_len(n)), year = factor(rep(seq_len(5L), length.out = n)),
    trait = factor("morph"), value = factor(sample.int(3L, n, replace = TRUE))
  )
  expect_error(
    gllvmTMB(value ~ 0 + trait + indep(0 + trait | year), data = df,
             family = multinomial(), trait = "trait", unit = "unit",
             cluster2 = "year"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: phylo_dep() / phylo_indep() / phylo_unique() ---------------

test_that("phylo_dep() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(11L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_dep(0 + trait | species), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species",
             phylo_tree = fx$tree),
    class = .mn_not_admitted
  )
})

test_that("phylo_indep() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(12L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait | species), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species",
             phylo_tree = fx$tree),
    class = .mn_not_admitted
  )
})

test_that("phylo_unique() (standalone) is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(13L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_unique(species), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species",
             phylo_tree = fx$tree),
    class = .mn_not_admitted
  )
})

## ---- Blocked: phylo_scalar() / animal_scalar() (propto exemption removed) --

test_that("phylo_scalar() is not admitted for multinomial (propto exemption removed)", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(14L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_scalar(species), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species",
             phylo_tree = fx$tree),
    regexp = "not admitted|unsupported latent|deferred"
  )
})

test_that("animal_scalar() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(15L)
  A <- ape::vcv(fx$tree, corr = TRUE)
  expect_error(
    gllvmTMB(value ~ 0 + trait + animal_scalar(species, A = A), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species"),
    regexp = "not admitted|unsupported latent|deferred"
  )
})

## ---- Blocked: animal_latent() (pure sugar for phylo_latent(); the ONE ----
## ---- animal_* keyword with no marker distinguishing it from an admitted --
## ---- phylo_* cell -- see the .animal_source marker in R/brms-sugar.R) ----

test_that("animal_latent() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(16L)
  A <- ape::vcv(fx$tree, corr = TRUE)
  expect_error(
    gllvmTMB(value ~ 0 + trait + animal_latent(species, A = A, d = 1),
             data = fx$data, family = multinomial(), trait = "trait",
             unit = "species"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: kernel_latent() (single name) and multi-kernel -------------

test_that("kernel_latent() (single name) is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(17L, n = 20L)
  K <- diag(20L)
  rownames(K) <- colnames(K) <- levels(df$unit)
  expect_error(
    gllvmTMB(value ~ 0 + trait + kernel_latent(unit, K = K, d = 1, name = "k1"),
             data = df, family = multinomial(), trait = "trait", unit = "unit",
             cluster = "unit"),
    class = .mn_not_admitted
  )
})

test_that("multi-kernel is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(18L, n = 20L)
  K1 <- diag(20L); rownames(K1) <- colnames(K1) <- levels(df$unit)
  K2 <- diag(20L); rownames(K2) <- colnames(K2) <- levels(df$unit)
  expect_error(
    gllvmTMB(value ~ 0 + trait +
               kernel_latent(unit, K = K1, d = 1, name = "k1") +
               kernel_latent(unit, K = K2, d = 1, name = "k2"),
             data = df, family = multinomial(), trait = "trait", unit = "unit",
             cluster = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: spatial_* -----------------------------------------------

.mn_spatial_skip <- function() {
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("INLA")
}

.mn_spatial_fixture <- function(seed = 21L, n = 40L, K = 3L) {
  set.seed(seed)
  df <- data.frame(
    trait = factor("morph"), value = factor(sample.int(K, n, replace = TRUE)),
    x = stats::runif(n), y = stats::runif(n)
  )
  mesh <- tryCatch(gllvmTMB::make_mesh(df, c("x", "y"), cutoff = 0.3),
                    error = function(e) NULL)
  list(data = df, mesh = mesh)
}

test_that("spatial_indep() is not admitted for multinomial", {
  skip_on_cran(); .mn_spatial_skip()
  fx <- .mn_spatial_fixture(21L)
  skip_if(is.null(fx$mesh), "mesh build failed")
  expect_error(
    gllvmTMB(value ~ 0 + trait + spatial_indep(0 + trait | coords), data = fx$data,
             family = multinomial(), trait = "trait", mesh = fx$mesh),
    class = .mn_not_admitted
  )
})

test_that("spatial_dep() is not admitted for multinomial", {
  skip_on_cran(); .mn_spatial_skip()
  fx <- .mn_spatial_fixture(22L)
  skip_if(is.null(fx$mesh), "mesh build failed")
  expect_error(
    gllvmTMB(value ~ 0 + trait + spatial_dep(0 + trait | coords), data = fx$data,
             family = multinomial(), trait = "trait", mesh = fx$mesh),
    class = .mn_not_admitted
  )
})

test_that("spatial_latent() is not admitted for multinomial", {
  skip_on_cran(); .mn_spatial_skip()
  fx <- .mn_spatial_fixture(23L)
  skip_if(is.null(fx$mesh), "mesh build failed")
  expect_error(
    gllvmTMB(value ~ 0 + trait + spatial_latent(0 + trait | coords, d = 1),
             data = fx$data, family = multinomial(), trait = "trait", mesh = fx$mesh),
    class = .mn_not_admitted
  )
})

test_that("spatial_scalar() is not admitted for multinomial", {
  skip_on_cran(); .mn_spatial_skip()
  fx <- .mn_spatial_fixture(24L)
  skip_if(is.null(fx$mesh), "mesh build failed")
  expect_error(
    gllvmTMB(value ~ 0 + trait + spatial_scalar(0 + trait | coords), data = fx$data,
             family = multinomial(), trait = "trait", mesh = fx$mesh),
    class = .mn_not_admitted
  )
})

## ---- Blocked: mi() (THE load-bearing timing-gap regression test) ---------
## use_mi_predictor / use_mi_group / use_mi_discrete / use_mi_ordered are
## defined AFTER the old fence location; a mi() term was invisible to the
## late re-scan until it was moved past every use_mi_* definition.

test_that("mi() is not admitted for multinomial (timing-gap regression)", {
  skip_on_cran()
  set.seed(25L)
  n <- 60L
  df <- data.frame(
    unit = factor(seq_len(n)), trait = factor("morph"),
    value = factor(sample.int(3L, n, replace = TRUE)),
    x = stats::rnorm(n)
  )
  df$x[sample.int(n, 5L)] <- NA
  expect_error(
    gllvmTMB(value ~ 0 + trait + mi(x), data = df,
             family = multinomial(), trait = "trait", unit = "unit",
             impute = list(x = impute_model(x ~ 1, family = gaussian())),
             missing = miss_control(predictor = "model")),
    regexp = "not admitted|unsupported latent|deferred"
  )
})

## ---- Not blocked by this fence: AGHQ request (orthogonal to covstructs) --
## AGHQ is an integration-method choice, not a structured/latent term; it
## acts on z_B (the shared latent() score, an ADMITTED tier) downstream of
## this fence and is not itself a `use_*` covstruct flag. A request should
## not trip the admission fence -- whatever AGHQ itself decides to do
## (adapt, or decline back to Laplace because the fit is not AGHQ-eligible)
## is out of this fence's scope.

test_that("an AGHQ request on multinomial is not rejected by the admission fence", {
  skip_on_cran()
  df <- .mn_fence_data(26L, n = 60L)
  fit <- tryCatch(
    gllvmTMB(value ~ 0 + trait, data = df, family = multinomial(),
             trait = "trait", unit = "unit",
             control = gllvmTMBcontrol(aghq = 2)),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    expect_false(inherits(fit, .mn_not_admitted))
  } else {
    expect_s3_class(fit, "gllvmTMB_multi")
  }
})

## ---- Positive controls: the admitted set still fits -----------------------

test_that("phylo_latent() still fits for multinomial (positive control)", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(31L, n = 30L)
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2), data = fx$data,
    family = multinomial(), trait = "trait", unit = "species",
    phylo_tree = fx$tree
  ))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(all(fit$tmb_data$family_id_vec == 16L))
})

test_that("shared latent() cross-family fit still constructs (positive control)", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## K = 3 categories (mirrors .build_xfam_raw() in
  ## test-cross-family-multinomial.R): Lam is 3-column (gaussian trait +
  ## two category-contrast columns), so the multinomial trait genuinely has
  ## 3 unordered categories.
  set.seed(32L)
  N <- 80L
  Lam <- matrix(c(1.3, 0.4, 1.0, 0.6, -0.6, 0.9), 3, byrow = TRUE)
  d <- ncol(Lam)
  Z <- matrix(stats::rnorm(N * d), N, d)
  u <- Z %*% t(Lam)
  yg <- u[, 1L] + stats::rnorm(N, sd = 0.25)
  p <- cbind(1, exp(u[, 2L]), exp(u[, 3L])); p <- p / rowSums(p)
  yc <- vapply(seq_len(N), function(i) sample.int(3L, 1L, prob = p[i, ]), integer(1))
  dat <- rbind(
    data.frame(unit = seq_len(N), trait = "g", family = "g", value = yg),
    data.frame(unit = seq_len(N), trait = "cat", family = "m", value = yc)
  )
  dat$unit <- factor(dat$unit); dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2),
    data = dat, family = fam, trait = "trait", unit = "unit"
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
})

test_that("the default auto-Psi works for multinomial (positive control)", {
  skip_on_cran()
  df <- .mn_fence_data(33L, n = 60L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1), data = df,
    family = multinomial(), trait = "trait", unit = "unit"
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
})

## ---- Mixed-family propto message quality ---------------------------------
## The fence is per-fit, not per-trait: a propto() (phylo_scalar()) term
## targeting only a NON-multinomial trait in a mixed-family fit still aborts,
## and the message should say so rather than blaming the multinomial trait.

test_that("a mixed-family propto() term targeting only the non-multinomial trait still aborts, with a helpful message", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(34L, n = 20L)
  ## A single mixed-family frame with a gaussian trait "g" carrying the
  ## phylo_scalar() term and a multinomial trait sharing no structured term
  ## of its own.
  set.seed(35L)
  n_sp <- 20L
  tree <- fx$tree
  dat <- data.frame(
    species = factor(rep(tree$tip.label, 2L), levels = tree$tip.label),
    trait = factor(rep(c("g", "cat"), each = n_sp)),
    family = factor(rep(c("g", "m"), each = n_sp)),
    value = c(stats::rnorm(n_sp), sample(1:3, n_sp, replace = TRUE))
  )
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  err <- tryCatch(
    gllvmTMB(value ~ 0 + trait + phylo_scalar(species), data = dat,
             family = fam, trait = "trait", unit = "species", phylo_tree = tree),
    error = function(e) e
  )
  expect_true(inherits(err, "error"))
  expect_match(conditionMessage(err), "per-fit|not per-trait|propto")
})
