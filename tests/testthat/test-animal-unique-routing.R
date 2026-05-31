## Issue #354 part (b) -- animal_unique(1 + x | id) routing.
##
## animal_unique(1 + x | id, pedigree = ped) is a CORRELATED intercept + slope
## additive-genetic reaction norm: vec(B) ~ N(0, Sigma_b (x) A), Sigma_b a 2x2
## (intercept, slope) covariance with a FREE cross-correlation. It now routes
## through the phylo_unique augmented engine -- byte-identical to
## phylo_unique(1 + x | id, vcv = pedigree_to_Ainv_sparse(ped)) -- instead of
## the old fail-loud abort that misdirected users to animal_slope.
##
## The bare animal_unique(id) and the intercept-only animal_unique(0 + trait |
## id) forms are unchanged (intercept-only path); a genuinely unsupported bar
## LHS still fails loud.

skip_if_no_pedigree_helpers <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not(exists("pedigree_to_A", envir = asNamespace("gllvmTMB")))
}

make_au_routing_fixture <- function(seed = 5641L, n_id = 60L,
                                    n_traits = 3L, n_rep = 6L) {
  set.seed(seed)
  ped <- data.frame(
    id   = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 8L), rep(paste0("i", rep(1:4, length.out = n_id - 8L)), 1L)),
    dam  = c(rep(NA, 8L), rep(paste0("i", rep(5:8, length.out = n_id - 8L)), 1L)),
    stringsAsFactors = FALSE
  )
  A_dense   <- gllvmTMB::pedigree_to_A(ped)
  id_labels <- rownames(A_dense)

  Sigma_b_true <- matrix(c(0.4, 0.5 * sqrt(0.4 * 0.3),
                           0.5 * sqrt(0.4 * 0.3), 0.3), 2L, 2L)
  ab <- (t(chol(A_dense)) %*% matrix(stats::rnorm(n_id * 2L), n_id, 2L)) %*%
    chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- id_labels

  id_rep <- expand.grid(
    species = factor(id_labels, levels = id_labels),
    rep     = seq_len(n_rep)
  )
  id_rep$x <- stats::rnorm(nrow(id_rep))
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(id_rep,
              data.frame(trait = factor(trait_levels, levels = trait_levels)),
              all = TRUE)
  df <- df[order(df$species, df$rep, df$trait), ]
  df$value <- c(2, 1, 0.5)[as.integer(df$trait)] +
    ab[as.character(df$species), "alpha"] +
    ab[as.character(df$species), "beta"] * df$x +
    stats::rnorm(nrow(df), sd = 0.3)

  list(ped = ped, A = A_dense, df = df)
}

## Build the 2x2 Sigma_b from the augmented closed-form report (sd_b / cor_b),
## the canonical recovery for the correlated phylo_unique slope path.
.Sigma_b_from_report <- function(fit) {
  sd_b <- as.numeric(fit$report$sd_b)
  rho  <- as.numeric(fit$report$cor_b)
  matrix(
    c(sd_b[1L]^2, rho * sd_b[1L] * sd_b[2L],
      rho * sd_b[1L] * sd_b[2L], sd_b[2L]^2),
    nrow = 2L, ncol = 2L,
    dimnames = list(c("intercept", "slope"), c("intercept", "slope"))
  )
}

## ======================================================================
## 1. animal_unique(1 + x | id) fits, and is byte-identical to the
##    equivalent phylo_unique() sparse-Ainv pedigree call.
## ======================================================================
test_that("animal_unique(1 + x | id) routes to the phylo_unique augmented engine (byte-identical)", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()

  fx  <- make_au_routing_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)

  fit_au <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(1 + x | species, pedigree = fx$ped),
    data = fx$df, unit = "species", control = ctl
  )))
  ## Same engine as phylo_unique(1 + x | id, vcv = pedigree_to_Ainv_sparse(ped)):
  ## animal_*(pedigree = ) resolves to the sparse-Ainv vcv, so this is the
  ## same numeric path and must be byte-identical. Build the Ainv outside the
  ## formula (matching the established pattern in
  ## test-animal-unique-slope-gaussian.R).
  Ainv_ped <- gllvmTMB::pedigree_to_Ainv_sparse(fx$ped)
  fit_pu <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = Ainv_ped),
    data = fx$df, unit = "species", control = ctl
  )))

  expect_equal(fit_au$opt$convergence, 0L)
  ## The correlated augmented engine is active (NOT the intercept-only path,
  ## NOT the dep path): a free intercept-slope correlation.
  expect_identical(fit_au$tmb_data$use_phylo_slope_correlated, 1L)
  expect_false(isTRUE(fit_au$use$phylo_dep_slope))
  expect_identical(fit_au$tmb_data$n_lhs_cols, 2L)

  ## Byte-identity with the explicit phylo_unique sparse-Ainv call.
  expect_equal(as.numeric(logLik(fit_au)), as.numeric(logLik(fit_pu)),
               tolerance = 1e-6)
  expect_equal(.Sigma_b_from_report(fit_au), .Sigma_b_from_report(fit_pu),
               tolerance = 1e-6)
})

## ======================================================================
## 2. Sigma_b matches the dense phylo_unique(vcv = pedigree_to_A(ped)) call
##    to tolerance (the task-specified dense target; sparse-Ainv vs dense-A
##    take different numeric paths but agree to ~1e-6).
## ======================================================================
test_that("animal_unique(1 + x | id) Sigma_b matches phylo_unique(vcv = pedigree_to_A(ped)) to tolerance", {
  skip_if_not_heavy()
  skip_if_no_pedigree_helpers()

  fx  <- make_au_routing_fixture()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)

  fit_au <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(1 + x | species, pedigree = fx$ped),
    data = fx$df, unit = "species", control = ctl
  )))
  A_dense <- gllvmTMB::pedigree_to_A(fx$ped)
  fit_pu_dense <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = A_dense),
    data = fx$df, unit = "species", control = ctl
  )))

  expect_equal(as.numeric(logLik(fit_au)),
               as.numeric(logLik(fit_pu_dense)), tolerance = 1e-5)
  Sb_au <- .Sigma_b_from_report(fit_au)
  Sb_pu <- .Sigma_b_from_report(fit_pu_dense)
  expect_equal(dim(Sb_au), c(2L, 2L))
  expect_identical(rownames(Sb_au), c("intercept", "slope"))
  expect_equal(Sb_au, Sb_pu, tolerance = 1e-4)
})

## ======================================================================
## 3. Negative: bare animal_unique(id) is unchanged (intercept-only path).
## ======================================================================
test_that("animal_unique(id) bare form is unchanged (intercept-only, not the slope engine)", {
  skip_if_no_pedigree_helpers()

  fx  <- make_au_routing_fixture(n_id = 12L, n_rep = 2L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$df, unit = "species",
    control = list(optimize = FALSE)
  )))
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 0L)
  expect_identical(fit$tmb_data$use_phylo_slope, 0L)
})

## ======================================================================
## 4. Negative: animal_unique(0 + trait | id) is unchanged (intercept-only
##    bar form), NOT the slope engine.
## ======================================================================
test_that("animal_unique(0 + trait | id) intercept-only bar is unchanged (not the slope engine)", {
  skip_if_no_pedigree_helpers()

  fx  <- make_au_routing_fixture(n_id = 12L, n_rep = 2L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(0 + trait | species, pedigree = fx$ped),
    data = fx$df, unit = "species",
    control = list(optimize = FALSE)
  )))
  expect_identical(fit$tmb_data$use_phylo_slope_correlated, 0L)
  expect_identical(fit$tmb_data$use_phylo_slope, 0L)
})

## ======================================================================
## 5. Genuinely unsupported bar LHS still fails loud (kept guard).
## ======================================================================
test_that("animal_unique() with an unsupported bar LHS fails loud", {
  skip_if_no_pedigree_helpers()

  fx <- make_au_routing_fixture(n_id = 10L, n_rep = 2L)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_unique(0 + x | species, pedigree = fx$ped),
      data = fx$df, unit = "species",
      control = list(optimize = FALSE)
    ))),
    regexp = "animal_unique.*not supported|augmented LHS"
  )
})
