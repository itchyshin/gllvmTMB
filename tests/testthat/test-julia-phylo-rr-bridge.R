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

test_that("private S3b adapter reaches the closed Julia consumer when opted in", {
  skip_if_not(
    identical(Sys.getenv("GLLVM_S3B_LIVE_ADAPTER_TESTS"), "1"),
    "set GLLVM_S3B_LIVE_ADAPTER_TESTS=1 with an isolated Julia project to run"
  )
  project <- Sys.getenv("GLLVM_DESTINATION_B_PROJECT", "")
  julia_home <- Sys.getenv("GLLVM_S3B_JULIA_HOME", "")
  skip_if_not(nzchar(project), "GLLVM_DESTINATION_B_PROJECT is required")
  skip_if_not(nzchar(julia_home), "GLLVM_S3B_JULIA_HOME is required")

  Sys.setenv(JULIA_PROJECT = project)
  JuliaCall::julia_setup(
    JULIA_HOME = julia_home,
    install = FALSE,
    useRCall = FALSE,
    verbose = FALSE
  )
  JuliaCall::julia_command(sprintf(
    "import Pkg; Pkg.activate(\"%s\"); using GLLVM",
    gsub("\\\\", "\\\\\\\\", project, fixed = TRUE)
  ))
  old_ready <- .gllvm_jl_env$ready
  .gllvm_jl_env$ready <- TRUE
  on.exit({
    .gllvm_jl_env$ready <- old_ready
  }, add = TRUE)

  result <- gllvmTMB:::.gllvm_julia_phylo_rr_adapter(
    .s3b_phylo_rr_fixture(),
    ci_method = "none"
  )
  expect_identical(result$model, "precision_multivariate_candidate")
  expect_identical(result$admission_status, "closed")
  expect_identical(result$bridge_scope, "experimental_private_phylo_rr")
  expect_equal(result$n_traits, 2L)
  expect_equal(result$n_observations, 2L)
})

test_that("private S3b adapter pairs with one genuine frozen native tree fit", {
  skip_if_not(
    identical(Sys.getenv("GLLVM_S3B_LIVE_ADAPTER_TESTS"), "1"),
    "set GLLVM_S3B_LIVE_ADAPTER_TESTS=1 with an isolated Julia project to run"
  )
  project <- Sys.getenv("GLLVM_DESTINATION_B_PROJECT", "")
  julia_home <- Sys.getenv("GLLVM_S3B_JULIA_HOME", "")
  skip_if_not(nzchar(project), "GLLVM_DESTINATION_B_PROJECT is required")
  skip_if_not(nzchar(julia_home), "GLLVM_S3B_JULIA_HOME is required")
  skip_if_not_installed("ape")

  tree <- ape::read.tree(text = "((sp1:1,sp2:1):1,(sp3:1,sp4:1):1);")
  dat <- expand.grid(
    site = factor(paste0("site", 1:3)),
    species = factor(paste0("sp", 1:4), levels = paste0("sp", 1:4)),
    trait = factor(c("t1", "t2"), levels = c("t1", "t2"))
  )
  dat$site_species <- interaction(dat$site, dat$species, drop = TRUE)
  set.seed(701L)
  mu <- c(t1 = -0.25, t2 = 0.35)
  species_effect <- c(sp1 = -0.55, sp2 = -0.20, sp3 = 0.15, sp4 = 0.50)
  loading <- c(t1 = 0.80, t2 = -0.55)
  dat$value <- unname(
    mu[as.character(dat$trait)] +
      loading[as.character(dat$trait)] * species_effect[as.character(dat$species)] +
      stats::rnorm(nrow(dat), sd = 0.12)
  )
  native <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, unique = FALSE),
    data = dat, trait = "trait", unit = "site_species", cluster = "species",
    family = gaussian(), phylo_tree = tree,
    control = gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_true(isTRUE(native$use$phylo_rr))
  expect_false(isTRUE(native$use$phylo_diag))

  Sys.setenv(JULIA_PROJECT = project)
  JuliaCall::julia_setup(
    JULIA_HOME = julia_home,
    install = FALSE,
    useRCall = FALSE,
    verbose = FALSE
  )
  JuliaCall::julia_command(sprintf(
    "import Pkg; Pkg.activate(\"%s\"); using GLLVM",
    gsub("\\\\", "\\\\\\\\", project, fixed = TRUE)
  ))
  old_ready <- .gllvm_jl_env$ready
  .gllvm_jl_env$ready <- TRUE
  on.exit(.gllvm_jl_env$ready <- old_ready, add = TRUE)
  julia <- gllvmTMB:::.gllvm_julia_phylo_rr_adapter(native, ci_method = "none")
  payload <- gllvmTMB:::.gllvm_julia_phylo_rr_payload(native)

  expect_identical(julia$admission_status, "closed")
  expect_equal(abs(as.numeric(logLik(native)) - julia$loglik), 0, tolerance = 1e-6)
  expect_equal(max(abs(unname(coef(native)) - julia$coefficients)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$Sigma_phy - julia$phylo_covariance)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$sigma_eps^2 - julia$residual_variance)), 0, tolerance = 1e-6)
  expect_identical(payload$species_id, julia$species_id)
  expect_equal(julia$scale, 2)
  expect_equal(payload$phylo$log_det, julia$log_det, tolerance = 0)
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
