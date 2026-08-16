## Multinomial (family_id 16) structured-term admission fence (Slice 0,
## Design 108/122). Confirms every deferred keyword combined with a
## multinomial() trait fails loud rather than silently reaching an
## untested categorical path, and that the current admitted set (a shared
## unit-tier latent() ordination, phylo_latent(), and the default auto-Psi)
## still fits. See R/multinomial-fence.R for the leak this closes.
##
## Every cell below carries the SAME class,
## "gllvmTMB_multinomial_structured_not_admitted", whether pass 1 (the early
## covstruct-keyed classifier) or pass 2 (the late use_* re-scan,
## belt-and-braces) catches it -- phylo_scalar() / animal_scalar() and mi()
## are pass-2-only cells (propto and mi() predictor terms are not
## covstructs), but the class is shared, so their assertions are just as
## tight as the pass-1 cells.

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

## ---- Blocked: augmented (intercept + slope) latent() / phylo_latent() ----
## (Slice 0 repair, adversarial Opus review 2026-08-16, findings 1-2: pass 1
## fell through to ADMITTED for both -- neither carries `.dep`/`.phylo_unique`/
## `.kernel_name`/`.animal_source`, so the plain unit-tier / plain-latent
## checks matched. The `latent()` case was still caught by the untyped
## pass-2 use_rr_B_slope scan (see the pre-existing
## test-cross-family-multinomial.R regression test); the `phylo_latent()`
## case was caught by NEITHER pass -- an unrelated per-family
## augmented-slope-support gate happened to abort first.)

test_that("augmented (1 + x) latent() is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(41L, n = 60L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(1 + x | unit, d = 1), data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    class = .mn_not_admitted
  )
})

test_that("augmented (1 + x) phylo_latent() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(42L, n = 20L)
  df <- fx$data
  df$x <- stats::rnorm(nrow(df))
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_latent(1 + x | species, d = 1),
             data = df, family = multinomial(), trait = "trait",
             unit = "species", phylo_tree = fx$tree),
    class = .mn_not_admitted
  )
})

## ---- Blocked: phylo_latent(unique = TRUE) (a free phylogenetic Psi) ------
## (Slice 0 repair, finding 3: pass 1 + the admission table wrongly said
## ADMITTED, contradicting R/extract-sigma.R's documented policy. Pass 2
## already caught it via use_phylo_diag, so this was a pass-1/table
## contradiction, not a live leak -- fixed anyway, since pass 1 not being
## load-bearing here defeats its purpose.)

test_that("phylo_latent(unique = TRUE) is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(43L, n = 20L)
  expect_error(
    gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 1, unique = TRUE),
             data = fx$data, family = multinomial(), trait = "trait",
             unit = "species", phylo_tree = fx$tree),
    class = .mn_not_admitted
  )
})

## ---- Blocked: meta_V() / equalto() (Slice 0 repair, finding 8) -----------
## Previously blanket-exempted in both passes alongside use_propto; no
## established route for a known-sampling-covariance term on a
## categorical-contrast pseudo-trait, so fail-closed by default.

test_that("meta_V() is not admitted for multinomial", {
  skip_on_cran()
  set.seed(44L)
  n_unit <- 20L; K <- 3L
  df <- data.frame(
    unit = factor(seq_len(n_unit)), trait = factor("morph"),
    value = factor(sample.int(K, n_unit, replace = TRUE))
  )
  ## known_V is sized to the internal n_obs AFTER multinomial's (K-1)
  ## pseudo-trait expansion (n_unit * (K - 1)), not nrow(df). This only
  ## matters if the fence is ever removed and the fit runs far enough to
  ## reach the known_V dimension check -- get it right so a future
  ## regression is reported as "not blocked", not masked as "bad V size".
  V <- diag(stats::runif(n_unit * (K - 1L), 0.02, 0.08))
  expect_error(
    gllvmTMB(value ~ 0 + trait + meta_V(V = V), data = df,
             family = multinomial(), trait = "trait", unit = "unit",
             known_V = V),
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
    class = .mn_not_admitted
  )
})

test_that("animal_scalar() is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(15L)
  A <- ape::vcv(fx$tree, corr = TRUE)
  expect_error(
    gllvmTMB(value ~ 0 + trait + animal_scalar(species, A = A), data = fx$data,
             family = multinomial(), trait = "trait", unit = "species"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: animal_latent(unique = TRUE) / kernel_latent(unique = TRUE) -
## Slice 1 (2026-08-16) admits the PLAIN loadings-only cell for both keywords
## (see test-matrix-multinomial-phylo.R for the admission-fit tests and the
## phylo_latent() equivalence check); the auto-emitted Psi companion of
## `unique = TRUE` stays blocked for the same reason phylo_latent(unique =
## TRUE) does (a free phylogenetic Psi is not admitted for multinomial).

test_that("animal_latent(unique = TRUE) is not admitted for multinomial", {
  skip_on_cran(); skip_if_not_installed("ape")
  fx <- .mn_fence_phylo_data(16L)
  A <- ape::vcv(fx$tree, corr = TRUE)
  expect_error(
    gllvmTMB(value ~ 0 + trait +
               animal_latent(species, A = A, d = 1, unique = TRUE),
             data = fx$data, family = multinomial(), trait = "trait",
             unit = "species"),
    class = .mn_not_admitted
  )
})

test_that("kernel_latent(unique = TRUE) (single name) is not admitted for multinomial", {
  skip_on_cran()
  df <- .mn_fence_data(17L, n = 20L)
  K <- diag(20L)
  rownames(K) <- colnames(K) <- levels(df$unit)
  expect_error(
    gllvmTMB(value ~ 0 + trait +
               kernel_latent(unit, K = K, d = 1, name = "k1", unique = TRUE),
             data = df, family = multinomial(), trait = "trait", unit = "unit",
             cluster = "unit"),
    class = .mn_not_admitted
  )
})

## ---- Blocked: multi-kernel -------------------------------------------

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
    class = .mn_not_admitted
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

test_that("a mixed gaussian+multinomial dep(0+trait|unit) fit (a pass-1 path) also states the per-fit limitation", {
  skip_on_cran(); skip_if_not_installed("MASS")
  ## Slice 0 repair, finding 5: pass 2's message already carried a "per-fit,
  ## not per-trait" note; pass 1's did not. dep(0 + trait | unit) is a
  ## pass-1-only path (a plain "rr" covstruct, never reaches the use_*
  ## re-scan because pass 1 aborts first), so this pins that pass 1's
  ## message states the same limitation.
  set.seed(45L)
  N <- 40L
  dat <- rbind(
    data.frame(unit = seq_len(N), trait = "g", family = "g",
               value = stats::rnorm(N)),
    data.frame(unit = seq_len(N), trait = "cat", family = "m",
               value = sample(1:3, N, replace = TRUE))
  )
  dat$unit <- factor(dat$unit); dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  err <- tryCatch(
    gllvmTMB(value ~ 0 + trait + dep(0 + trait | unit), data = dat,
             family = fam, trait = "trait", unit = "unit"),
    error = function(e) e
  )
  expect_true(inherits(err, .mn_not_admitted))
  expect_match(conditionMessage(err), "per-fit|not per-trait")
})

## ---- Table-consistency: .mn_admission_table matches the classifier -------
## (Slice 0 repair, finding 6b -- would have caught finding 3: an admission-
## table row whose `status` disagreed with what the classifier actually
## returns for a representative covstruct of that row.)

test_that(".mn_admission_table is consistent with .mn_classify_covstruct() for every row", {
  skip_on_cran()
  tbl <- gllvmTMB:::.mn_admission_table
  site <- "unit"; ss_name <- "site_species"; species <- "species"
  cluster2_col <- NULL
  ## One representative covstruct per table row, in row order.
  reprs <- list(
    list(kind = "rr",       group = as.name("unit"),    extra = list()),
    list(kind = "diag",     group = as.name("unit"),    extra = list(.auto_unique = TRUE)),
    list(kind = "phylo_rr", group = as.name("species"), extra = list()),
    list(kind = "phylo_rr", group = as.name("species"),
         extra = list(.phylo_unique = TRUE, .auto_unique = TRUE)),
    list(kind = "rr",       group = as.name("unit"),    extra = list(.latent_augmented = TRUE)),
    list(kind = "phylo_rr", group = as.name("species"), extra = list(.latent_slope = TRUE)),
    list(kind = "equalto",  group = as.name("grp_V"),   extra = list()),
    ## Slice 1 (Design 122, 2026-08-16): animal_latent()/kernel_latent()
    ## (single name) admitted rows, and their unique = TRUE auto-Psi
    ## companions, blocked.
    list(kind = "phylo_rr", group = as.name("species"),
         extra = list(.animal_source = TRUE)),
    list(kind = "phylo_rr", group = as.name("species"),
         extra = list(.kernel_name = "phy", .kernel_mode = "latent")),
    list(kind = "phylo_rr", group = as.name("species"),
         extra = list(.phylo_unique = TRUE, .auto_unique = TRUE, .animal_source = TRUE)),
    list(kind = "phylo_rr", group = as.name("species"),
         extra = list(.phylo_unique = TRUE, .auto_unique = TRUE,
                      .kernel_name = "phy", .kernel_mode = "unique"))
  )
  expect_equal(nrow(tbl), length(reprs))
  for (i in seq_len(nrow(tbl))) {
    cls <- gllvmTMB:::.mn_classify_covstruct(
      reprs[[i]], site = site, ss_name = ss_name, species = species,
      cluster2_col = cluster2_col
    )
    expect_identical(
      cls$admitted, identical(tbl$status[i], "admitted"),
      info = sprintf("row %d (%s/%s/%s): table says %s, classifier says admitted=%s",
                      i, tbl$source[i], tbl$mode[i], tbl$tier[i], tbl$status[i], cls$admitted)
    )
  }
})

## ---- VA route pin: integration = "va" rejects multinomial -----------------
## (Slice 0 repair, finding 6c.) Pass 1 runs before the VA route branches off
## and only classifies covstructs -- it does not look at `control$integration`
## -- and pass 2 is UNREACHABLE on the VA route (an early `return()` in
## gllvmTMB_multi_fit() sends `integration = "va"` straight to
## .gllvmTMB_va_route(), well before pass 2). The VA route's own
## family/link fence (R/va-routing.R, `.va_route_family_link()`) is what
## actually protects this route; this test pins that it still does.

test_that("integration = \"va\" rejects a multinomial trait (VA route pin)", {
  skip_on_cran()
  df <- .mn_fence_data(46L, n = 60L)
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = df, family = multinomial(),
             trait = "trait", unit = "unit",
             control = gllvmTMBcontrol(integration = "va")),
    regexp = "multinomial|coupled-softmax|does not admit this model"
  )
})
