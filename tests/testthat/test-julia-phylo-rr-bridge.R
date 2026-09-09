# Closed S3b transport from an already fitted native phylo_rr model.
#
# This file deliberately does not widen `engine = "julia"`.  It exercises the
# private, fail-closed adapter payload only; live JuliaCall execution is a
# separate opt-in test once a GLLVM.jl project is configured.

.s3b_phylo_rr_fixture <- function() {
  labels <- c("ancestor", "sp1", "sp2")
  ## One unobserved ancestor remains in the precision system.  It must survive
  ## transport rather than be conditioned away by subsetting to observed tips.
  Q <- Matrix::forceSymmetric(Matrix::Matrix(
    c(3, -1, -1,
      -1, 1, 0,
      -1, 0, 1),
    nrow = 3L,
    sparse = TRUE
  ))
  dimnames(Q) <- list(labels, labels)
  dat <- data.frame(
    trait = factor(c("t1", "t2", "t1", "t2"), levels = c("t1", "t2")),
    species = factor(c("sp1", "sp1", "sp2", "sp2"), levels = c("sp1", "sp2")),
    site_species = factor(c("a_sp1", "a_sp1", "b_sp2", "b_sp2")),
    value = c(1, 2, 3, 4)
  )
  structure(
    list(
      family = stats::gaussian(),
      data = dat,
      trait_col = "trait",
      species_col = "species",
      unit_obs_col = "site_species",
      n_traits = 2L,
      n_site_species = 2L,
      d_phy = 1L,
      use = list(
        phylo_rr = TRUE,
        phylo_diag = FALSE,
        rr_B = FALSE,
        diag_B = FALSE,
        rr_W = FALSE,
        diag_W = FALSE,
        diag_species = FALSE,
        diag_cluster2 = FALSE,
        propto = FALSE,
        lv_B = FALSE,
        spde = FALSE,
        re_int = FALSE
      ),
      tmb_data = list(
        y = c(1, 2, 3, 4),
        trait_id = c(0L, 1L, 0L, 1L),
        species_id = c(0L, 0L, 1L, 1L),
        site_species_id = c(0L, 0L, 1L, 1L),
        Ainv_phy_rr = Q,
        log_det_A_phy_rr = 0,
        n_aug_phy = 3L,
        species_aug_id = c(1L, 1L, 2L, 2L),
        d_phy = 1L,
        use_phylo_rr = 1L
      )
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

test_that("private S3b payload preserves the native augmented precision", {
  payload <- gllvmTMB:::.gllvm_julia_phylo_rr_payload(.s3b_phylo_rr_fixture())

  expect_equal(payload$y, matrix(c(1, 2, 3, 4), nrow = 2L))
  expect_equal(payload$species_id, c(1L, 2L))
  expect_equal(payload$phylo$n_aug, 3L)
  expect_equal(payload$phylo$n_leaves, 2L)
  expect_equal(payload$phylo$node_labels, c("ancestor", "sp1", "sp2"))
  expect_equal(payload$phylo$species_aug_id, c(1L, 2L))
  expect_equal(payload$phylo$scale, 1)
  ## Native R stores log det(A); the Julia precision consumer needs log det(Q).
  expect_equal(payload$phylo$log_det, 0)
})

test_that("private S3b payload refuses an incomplete tip-to-augmented map", {
  fit <- .s3b_phylo_rr_fixture()
  fit$data$species <- factor(fit$data$species, levels = c("sp1", "sp2", "unused"))

  expect_error(
    gllvmTMB:::.gllvm_julia_phylo_rr_payload(fit),
    "GJL-GATE-PHYLO-MV-TIPMAP"
  )
})

test_that("private S3b payload warns from the original ill-conditioned dense vcv", {
  fit <- .s3b_phylo_rr_fixture()
  C <- matrix(c(1, 1 - 1e-9,
                1 - 1e-9, 1), nrow = 2L)
  dimnames(C) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  ## This is the frozen-R dense contract: ridge C once in R, then transport
  ## that canonical precision.  The adapter must not independently invert C.
  C_ridged <- C + diag(1e-8, 2L)
  Q <- Matrix::forceSymmetric(Matrix::Matrix(solve(C_ridged), sparse = TRUE))
  dimnames(Q) <- dimnames(C)
  fit$phylo_vcv <- C
  fit$tmb_data$Ainv_phy_rr <- Q
  fit$tmb_data$n_aug_phy <- 2L
  fit$tmb_data$species_aug_id <- c(0L, 0L, 1L, 1L)
  fit$tmb_data$log_det_A_phy_rr <- as.numeric(
    determinant(C_ridged, logarithm = TRUE)$modulus
  )

  payload <- NULL
  expect_warning(
    payload <- gllvmTMB:::.gllvm_julia_phylo_rr_payload(fit),
    "GJL-WARN-PHYLO-VCV-CONDITION"
  )
  Q_transport <- matrix(0, nrow = 2L, ncol = 2L)
  Q_transport[cbind(payload$phylo$i, payload$phylo$j)] <- payload$phylo$x
  expect_equal(Q_transport, unname(as.matrix(Q)), tolerance = 0)
  expect_equal(payload$phylo$log_det, -fit$tmb_data$log_det_A_phy_rr)
})

test_that("private S3b payload retains the non-unit native tree scale", {
  skip_if_not_installed("ape")
  tree <- ape::read.tree(text = "(sp1:2,sp2:2);")
  native <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
  fit <- .s3b_phylo_rr_fixture()
  fit$phylo_tree <- tree
  fit$tmb_data$Ainv_phy_rr <- native$precision
  fit$tmb_data$n_aug_phy <- nrow(native$precision)
  fit$tmb_data$log_det_A_phy_rr <- -native$log_det_precision
  fit$tmb_data$species_aug_id <- c(0L, 0L, 1L, 1L)

  payload <- gllvmTMB:::.gllvm_julia_phylo_rr_payload(fit)
  expect_equal(payload$phylo$scale, 2)
  expect_equal(payload$phylo$log_det, native$log_det_precision)
})

test_that("private S3b payload rejects determinant and tree-scale corruption", {
  fit <- .s3b_phylo_rr_fixture()
  fit$tmb_data$log_det_A_phy_rr <- 0.1
  expect_error(
    gllvmTMB:::.gllvm_julia_phylo_rr_payload(fit),
    "GJL-GATE-PHYLO-MV-LOGDET"
  )

  skip_if_not_installed("ape")
  tree <- ape::read.tree(text = "(sp1:2,sp2:2);")
  native <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
  fit <- .s3b_phylo_rr_fixture()
  fit$phylo_tree <- tree
  fit$tmb_data$Ainv_phy_rr <- native$precision * 2
  fit$tmb_data$n_aug_phy <- nrow(native$precision)
  fit$tmb_data$log_det_A_phy_rr <- -native$log_det_precision
  fit$tmb_data$species_aug_id <- c(0L, 0L, 1L, 1L)
  expect_error(
    gllvmTMB:::.gllvm_julia_phylo_rr_payload(fit),
    "GJL-GATE-PHYLO-MV-TREE"
  )
})

test_that("private S3b adapter sends only the closed multivariate contract", {
  captured <- NULL
  result <- gllvmTMB:::.gllvm_julia_phylo_rr_adapter(
    .s3b_phylo_rr_fixture(),
    ci_method = "wald",
    ci_level = 0.9,
    .julia_call = function(...) {
      captured <<- list(...)
      list(
        family = "gaussian",
        n_traits = 2L,
        trait_names = c("t1", "t2"),
        unit_names = c("a_sp1", "b_sp2"),
        loadings = matrix(c(0.2, 0.1), nrow = 2L),
        loglik = -4
      )
    }
  )

  expect_equal(captured[[1L]], "GLLVM.bridge_fit")
  expect_equal(captured$y, matrix(c(1, 2, 3, 4), nrow = 2L))
  expect_equal(captured$family, "gaussian")
  expect_equal(captured$d, 1L)
  expect_equal(captured$options$phylo_model, "multivariate")
  expect_equal(captured$options$species_id, c(1L, 2L))
  expect_equal(captured$options$mode, "barelowrank")
  expect_equal(captured$options$residual_mode, "shared")
  expect_equal(captured$options$ci_method, "wald")
  expect_equal(captured$options$ci_level, 0.9)
  expect_equal(result$bridge_scope, "experimental_private_phylo_rr")
  expect_false(inherits(result, "gllvmTMB_julia"))
})

test_that("engine = 'julia' remains closed for phylo_rr", {
  df <- .s3b_phylo_rr_fixture()$data
  A <- diag(2L)
  dimnames(A) <- list(c("sp1", "sp2"), c("sp1", "sp2"))

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1L, vcv = A),
      data = df,
      trait = "trait",
      unit = "site_species",
      cluster = "species",
      family = gaussian(),
      engine = "julia"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
})
