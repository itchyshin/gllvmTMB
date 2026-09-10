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

  expect_identical(native$opt$convergence, 0L)
  expect_true(isTRUE(julia$converged))
  expect_identical(julia$admission_status, "closed")
  expect_equal(abs(as.numeric(logLik(native)) - julia$loglik), 0, tolerance = 1e-6)
  expect_equal(max(abs(unname(coef(native)) - julia$coefficients)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$Sigma_phy - julia$phylo_covariance)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$sigma_eps^2 - julia$residual_variance)), 0, tolerance = 1e-6)
  expect_identical(payload$species_id, julia$species_id)
  expect_equal(julia$scale, 2)
  expect_equal(payload$phylo$log_det, julia$log_det, tolerance = 0)
  s4 <- gllvmTMB:::gllvm_julia_phylo_rr(native, ci_level = 0.9)
  s4_summary <- gllvmTMB:::summary.gllvmTMB_julia_phylo_rr(s4)
  s4_ci <- gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(s4, level = 0.9)
  expect_s3_class(s4, "gllvmTMB_julia_phylo_rr")
  expect_false(inherits(s4, "gllvmTMB_julia"))
  expect_true(is.finite(as.numeric(gllvmTMB:::logLik.gllvmTMB_julia_phylo_rr(s4))))
  expect_equal(
    gllvmTMB:::coef.gllvmTMB_julia_phylo_rr(s4),
    stats::setNames(s4$coefficients, s4$coefficient_names)
  )
  expect_true(is.matrix(s4$phylo_covariance))
  expect_true(all(is.finite(s4$residual_variance)))
  expect_true(isTRUE(s4_summary$diagnostics$hessian_positive_definite))
  expect_gt(nrow(s4_ci), 0L)
  expect_true(all(is.finite(s4_ci)))
  expect_true(all(s4_ci[, 1L] < s4_ci[, 2L]))
  assign(".s3b_tree_pair_receipt", list(
    kind = "tree", n_traits = 2L, n_species = 4L, n_observations = 12L,
    scale = julia$scale, log_det_precision = julia$log_det,
    seed = 701L, data_sha256 = digest::digest(dat, algo = "sha256", serialize = TRUE),
    model_spec = "gaussian; 0 + trait + phylo_latent(species, d = 1, unique = FALSE)",
    native_convergence = native$opt$convergence, julia_converged = isTRUE(julia$converged),
    deltas = list(
      log_likelihood = abs(as.numeric(logLik(native)) - julia$loglik),
      fixed_effects = max(abs(unname(coef(native)) - julia$coefficients)),
      phylogenetic_covariance = max(abs(native$report$Sigma_phy - julia$phylo_covariance)),
      residual_variance = max(abs(native$report$sigma_eps^2 - julia$residual_variance))
    )
  ), envir = globalenv())
})

test_that("private S3b adapter pairs with a native sparse-pedigree fit", {
  skip_if_not(
    identical(Sys.getenv("GLLVM_S3B_LIVE_ADAPTER_TESTS"), "1"),
    "set GLLVM_S3B_LIVE_ADAPTER_TESTS=1 with an isolated Julia project to run"
  )
  project <- Sys.getenv("GLLVM_DESTINATION_B_PROJECT", "")
  julia_home <- Sys.getenv("GLLVM_S3B_JULIA_HOME", "")
  skip_if_not(nzchar(project), "GLLVM_DESTINATION_B_PROJECT is required")
  skip_if_not(nzchar(julia_home), "GLLVM_S3B_JULIA_HOME is required")

  ## The founders are not observed responses.  They must nevertheless remain
  ## in the transported precision system so the descendant effects are
  ## marginalised, rather than conditioned on a truncated covariance.
  pedigree <- data.frame(
    id = c("founder_s", "founder_d", "desc_1", "desc_2"),
    sire = c(NA, NA, "founder_s", "founder_s"),
    dam = c(NA, NA, "founder_d", "founder_d")
  )
  dat <- expand.grid(
    site = factor(paste0("site", 1:3)),
    species = factor(c("desc_1", "desc_2"), levels = c("desc_1", "desc_2")),
    trait = factor(c("t1", "t2"), levels = c("t1", "t2"))
  )
  dat$site_species <- interaction(dat$site, dat$species, drop = TRUE)
  set.seed(702L)
  effects <- c(desc_1 = -0.35, desc_2 = 0.40)
  loading <- c(t1 = 0.72, t2 = -0.48)
  mean <- c(t1 = -0.20, t2 = 0.30)
  dat$value <- unname(
    mean[as.character(dat$trait)] +
      loading[as.character(dat$trait)] * effects[as.character(dat$species)] +
      stats::rnorm(nrow(dat), sd = 0.10)
  )
  native <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = pedigree, unique = FALSE),
    data = dat, trait = "trait", unit = "site_species", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_true(isTRUE(native$use$phylo_rr))

  Sys.setenv(JULIA_PROJECT = project)
  JuliaCall::julia_setup(
    JULIA_HOME = julia_home, install = FALSE, useRCall = FALSE, verbose = FALSE
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

  expect_identical(native$opt$convergence, 0L)
  expect_true(isTRUE(julia$converged))
  expect_identical(julia$admission_status, "closed")
  expect_equal(payload$phylo$n_aug, 4L)
  expect_equal(payload$phylo$n_leaves, 2L)
  expect_equal(payload$phylo$node_labels, pedigree$id)
  ## The bridge contract is zero-based for Julia indexing.
  expect_equal(payload$phylo$species_aug_id, c(2L, 3L))
  expect_equal(abs(as.numeric(logLik(native)) - julia$loglik), 0, tolerance = 1e-6)
  expect_equal(max(abs(unname(coef(native)) - julia$coefficients)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$Sigma_phy - julia$phylo_covariance)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$sigma_eps^2 - julia$residual_variance)), 0, tolerance = 1e-6)
  expect_equal(payload$phylo$log_det, julia$log_det, tolerance = 0)
  assign(".s3b_pedigree_pair_receipt", list(
    kind = "sparse_pedigree", n_traits = 2L, n_observations = 6L,
    augmented_nodes = payload$phylo$n_aug, observed_nodes_zero_based = payload$phylo$species_aug_id,
    log_det_precision = julia$log_det,
    seed = 702L, data_sha256 = digest::digest(dat, algo = "sha256", serialize = TRUE),
    model_spec = "gaussian; 0 + trait + animal_latent(species, d = 1, pedigree = pedigree, unique = FALSE)",
    native_convergence = native$opt$convergence, julia_converged = isTRUE(julia$converged),
    deltas = list(
      log_likelihood = abs(as.numeric(logLik(native)) - julia$loglik),
      fixed_effects = max(abs(unname(coef(native)) - julia$coefficients)),
      phylogenetic_covariance = max(abs(native$report$Sigma_phy - julia$phylo_covariance)),
      residual_variance = max(abs(native$report$sigma_eps^2 - julia$residual_variance))
    )
  ), envir = globalenv())
})

test_that("private S3b adapter transports a native R-ridged-once dense vcv", {
  skip_if_not(
    identical(Sys.getenv("GLLVM_S3B_LIVE_ADAPTER_TESTS"), "1"),
    "set GLLVM_S3B_LIVE_ADAPTER_TESTS=1 with an isolated Julia project to run"
  )
  project <- Sys.getenv("GLLVM_DESTINATION_B_PROJECT", "")
  julia_home <- Sys.getenv("GLLVM_S3B_JULIA_HOME", "")
  skip_if_not(nzchar(project), "GLLVM_DESTINATION_B_PROJECT is required")
  skip_if_not(nzchar(julia_home), "GLLVM_S3B_JULIA_HOME is required")

  species <- c("a", "b", "c")
  original_vcv <- diag(c(1, 1e-9, 0.5))
  dimnames(original_vcv) <- list(species, species)
  dat <- expand.grid(
    trait = factor(c("t1", "t2"), levels = c("t1", "t2")),
    species = factor(species, levels = species)
  )
  dat$unit <- factor(dat$species, levels = species)
  dat$value <- c(0.2, -0.1, 0.5, 0.3, -0.2, 0.4)
  native <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, vcv = original_vcv, unique = FALSE),
    data = dat, trait = "trait", unit = "unit", family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_true(isTRUE(native$use$phylo_rr))

  Sys.setenv(JULIA_PROJECT = project)
  JuliaCall::julia_setup(
    JULIA_HOME = julia_home, install = FALSE, useRCall = FALSE, verbose = FALSE
  )
  JuliaCall::julia_command(sprintf(
    "import Pkg; Pkg.activate(\"%s\"); using GLLVM",
    gsub("\\\\", "\\\\\\\\", project, fixed = TRUE)
  ))
  old_ready <- .gllvm_jl_env$ready
  .gllvm_jl_env$ready <- TRUE
  on.exit(.gllvm_jl_env$ready <- old_ready, add = TRUE)
  payload <- NULL
  expect_warning(
    payload <- gllvmTMB:::.gllvm_julia_phylo_rr_payload(native),
    "GJL-WARN-PHYLO-VCV-CONDITION"
  )
  ## The adapter validates the original dense covariance again; its warning is
  ## already asserted above, so keep this paired-result step noise-free.
  julia <- suppressWarnings(
    gllvmTMB:::.gllvm_julia_phylo_rr_adapter(native, ci_method = "none")
  )
  ridged_vcv <- original_vcv + diag(1e-8, length(species))
  Q_transport <- matrix(0, payload$phylo$n_aug, payload$phylo$n_aug)
  Q_transport[cbind(payload$phylo$i, payload$phylo$j)] <- payload$phylo$x

  expect_identical(native$opt$convergence, 0L)
  expect_true(isTRUE(julia$converged))
  expect_identical(julia$admission_status, "closed")
  expect_equal(payload$phylo$n_aug, length(species))
  expect_equal(payload$phylo$node_labels, species)
  expect_equal(Q_transport, unname(solve(ridged_vcv)), tolerance = 1e-10)
  expect_equal(abs(as.numeric(logLik(native)) - julia$loglik), 0, tolerance = 1e-6)
  expect_equal(max(abs(unname(coef(native)) - julia$coefficients)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$Sigma_phy - julia$phylo_covariance)), 0, tolerance = 1e-6)
  expect_equal(max(abs(native$report$sigma_eps^2 - julia$residual_variance)), 0, tolerance = 1e-6)
  expect_equal(payload$phylo$log_det, julia$log_det, tolerance = 0)
  assign(".s3b_dense_pair_receipt", list(
    kind = "dense_vcv", n_traits = 2L, n_observations = 3L,
    condition_number_original = kappa(original_vcv), diagonal_jitter = 1e-8,
    augmented_nodes = payload$phylo$n_aug, log_det_precision = julia$log_det,
    seed = "deterministic_fixed_response", data_sha256 = digest::digest(dat, algo = "sha256", serialize = TRUE),
    model_spec = "gaussian; 0 + trait + phylo_latent(species, d = 1, vcv = original_vcv, unique = FALSE)",
    native_convergence = native$opt$convergence, julia_converged = isTRUE(julia$converged),
    deltas = list(
      log_likelihood = abs(as.numeric(logLik(native)) - julia$loglik),
      fixed_effects = max(abs(unname(coef(native)) - julia$coefficients)),
      phylogenetic_covariance = max(abs(native$report$Sigma_phy - julia$phylo_covariance)),
      residual_variance = max(abs(native$report$sigma_eps^2 - julia$residual_variance))
    )
  ), envir = globalenv())
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

.s4_tree_wrapper_fixture <- function() {
  skip_if_not_installed("ape")
  tree <- ape::read.tree(text = "(sp1:2,sp2:2);")
  native <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
  fit <- .s3b_phylo_rr_fixture()
  fit$phylo_tree <- tree
  fit$phylo_vcv <- NULL
  fit$REML <- FALSE
  fit$tmb_data$REML <- FALSE
  fit$opt <- list(convergence = 0L, par = c(-0.2, 0.3, -0.7, -1.2))
  fit$tmb_data$Ainv_phy_rr <- native$precision
  fit$tmb_data$n_aug_phy <- nrow(native$precision)
  fit$tmb_data$log_det_A_phy_rr <- -native$log_det_precision
  fit$tmb_data$species_aug_id <- c(0L, 0L, 1L, 1L)
  fit$X_fix <- cbind(
    traitt1 = c(1, 0, 1, 0),
    traitt2 = c(0, 1, 0, 1)
  )
  fit$X_fix_names <- colnames(fit$X_fix)
  fit$Xcoef_fixed <- NULL
  fit
}

.s4_tree_wrapper_julia_result <- function(...) {
  list(
    family = "gaussian",
    model = "precision_multivariate_candidate",
    admission_status = "closed",
    d = 1L,
    n_traits = 2L,
    n_observations = 2L,
    coefficients = c(-0.2, 0.3),
    coefficient_names = c("traitt1", "traitt2"),
    phylo_covariance = matrix(c(0.4, -0.1, -0.1, 0.3), 2L),
    residual_variance = c(0.08, 0.08),
    loglik = -4.5,
    parameters = c(-0.2, 0.3, -0.7, -1.2),
    converged = TRUE,
    gradient_max = 1e-8,
    hessian_positive_definite = TRUE,
    hessian_condition_number = 12,
    ci_method = "wald",
    ci_level = 0.9,
    ci_status = "available",
    ci_target_names = c("beta[1]", "beta[2]", "phylo_cov[1,1]", "signal"),
    ci_estimate = c(-0.2, 0.3, 0.4, 0.5),
    ci_lower = c(-0.4, 0.1, 0.1, NA_real_),
    ci_upper = c(0.0, 0.5, 0.7, NA_real_),
    ci_note = "",
    ci_target_methods = rep("transformed_wald", 4L),
    ci_statuses = c("available", "available", "available", "not_identified")
  )
}

.s4_public_phylo_dep_fixture <- function() {
  fit <- .s4_tree_wrapper_fixture()
  ## Exact narrow public S4 structure: two trait intercepts and the full
  ## dependent phylogenetic trait covariance (`d_phy = n_traits = 2`).
  fit$d_phy <- 2L
  fit$tmb_data$d_phy <- 2L
  fit$use$phylo_dep <- TRUE
  fit$use$phylo_latent <- FALSE
  fit$opt$par <- c(-0.2, 0.3, 0.4, -0.1, 0.5, -1.2)
  fit$covstructs <- list(list(
    kind = "phylo_rr",
    lhs = quote(0 + species),
    group = quote(trait),
    extra = list(d = 2L, .dep = TRUE, tree = fit$phylo_tree)
  ))
  fit
}

.s4_public_phylo_dep_julia_result <- function(...) {
  result <- .s4_tree_wrapper_julia_result(...)
  result$d <- 2L
  result$parameters <- c(-0.2, 0.3, 0.4, -0.1, 0.5, -1.2)
  ## Mirror the generic Julia PMV order: shared residual target 1 is emitted
  ## before the second covariance diagonal. The public R formula surface must
  ## order by names, never assume this internal layout.
  result$ci_target_names <- c(
    "beta[1]", "beta[2]", "phylo_cov[1,1]", "phylo_cov[2,1]",
    "residual_var_shared[1]", "phylo_cov[2,2]", "residual_var_shared[2]"
  )
  result$ci_estimate <- c(-0.2, 0.3, 0.4, -0.1, 0.08, 0.3, 0.08)
  result$ci_lower <- c(-0.4, 0.1, 0.1, -0.3, 0.04, 0.1, 0.04)
  result$ci_upper <- c(0.0, 0.5, 0.7, 0.1, 0.12, 0.6, 0.12)
  result$ci_se_transformed <- rep(0.1, 7L)
  result$ci_transforms <- c("identity", "identity", "log", "identity", "log", "log", "log")
  result$ci_target_methods <- rep("transformed_wald", 7L)
  result$ci_statuses <- rep("available", 7L)
  result
}

test_that("S4 public formula wrapper transports only phylo_dep full covariance", {
  fit <- .s4_public_phylo_dep_fixture()
  captured <- NULL
  result <- gllvmTMB:::gllvm_julia_phylo_rr(
    fit,
    ci_level = 0.9,
    .julia_call = function(...) {
      captured <<- list(...)
      .s4_public_phylo_dep_julia_result(...)
    }
  )

  expect_equal(captured$d, 2L)
  expect_equal(captured$options$mode, "barelowrank")
  expect_equal(captured$options$residual_mode, "shared")
  ci <- gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9)
  expect_equal(rownames(ci), c(
    "beta[1]", "beta[2]", "phylo_cov[1,1]", "phylo_cov[2,1]",
    "phylo_cov[2,2]", "residual_var_shared[1]", "residual_var_shared[2]"
  ))
  expect_identical(result$ci_param_names, rownames(ci))
  expect_identical(names(result$ci_estimate), rownames(ci))
  expect_true(all(ci[, 1L] < ci[, 2L]))
})

test_that("S4 public formula wrapper rejects a different structured term", {
  fit <- .s4_public_phylo_dep_fixture()
  fit$covstructs[[1L]]$extra$.dep <- FALSE
  expect_error(
    gllvmTMB:::gllvm_julia_phylo_rr(fit, .julia_call = .s4_public_phylo_dep_julia_result),
    "GJL-GATE-PHYLO-MV-FORMULA"
  )
})

test_that("generic engine remains closed for the public phylo_dep formula", {
  skip_if_not_installed("ape")
  tree <- ape::read.tree(text = "(sp1:2,sp2:2,sp3:2);")
  data <- data.frame(
    individual = seq_len(3L), species = c("sp1", "sp2", "sp3"),
    trait_1 = c(0.2, 1.4, 0.8), trait_2 = c(0.1, 0.7, 0.4)
  )
  expect_error(
    gllvmTMB(
      traits(trait_1, trait_2) ~ 1 + phylo_dep(1 | species, tree = tree),
      data = data, unit = "individual", family = gaussian(), engine = "julia"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
})

test_that("S4 public phylo_dep formula retains paired transformed-Wald endpoints", {
  skip_if_not(identical(Sys.getenv("GLLVM_S4_LIVE_FORMULA_TESTS"), "1"))
  skip_if_not_installed("JuliaCall")
  skip_if_not_installed("ape")

  julia_project <- Sys.getenv("GLLVM_DESTINATION_B_PROJECT")
  julia_home <- Sys.getenv("GLLVM_S4_JULIA_HOME")
  if (!nzchar(julia_project) || !nzchar(julia_home)) {
    skip("set GLLVM_DESTINATION_B_PROJECT and GLLVM_S4_JULIA_HOME for the opt-in S4 paired workflow")
  }

  tree <- ape::read.tree(text = "(sp1:2,sp2:2,sp3:2);")
  data <- data.frame(
    individual = seq_len(9L),
    species = rep(c("sp1", "sp2", "sp3"), each = 3L),
    trait_1 = c(0.2, 0.4, 0.1, 1.4, 1.3, 1.5, 0.8, 0.9, 1.0),
    trait_2 = c(0.1, 0.3, 0.2, 0.7, 0.8, 0.6, 0.4, 0.5, 0.6)
  )
  native <- gllvmTMB(
    traits(trait_1, trait_2) ~ 1 + phylo_dep(1 | species, tree = tree),
    data = data,
    unit = "individual",
    family = gaussian(),
    control = gllvmTMBcontrol(se = TRUE)
  )
  julia <- gllvm_julia_phylo_rr(
    native,
    ci_level = 0.9,
    jl_path = julia_project,
    julia_home = julia_home
  )

  fixed <- native$opt$par
  full <- native$tmb_obj$env$last.par.best
  native_targets <- function(parameters) {
    full_parameters <- full
    full_parameters[seq_along(parameters)] <- parameters
    report <- native$tmb_obj$report(full_parameters)
    c(
      "beta[1]" = unname(parameters[1L]),
      "beta[2]" = unname(parameters[2L]),
      "phylo_cov[1,1]" = report$Sigma_phy[1L, 1L],
      "phylo_cov[2,1]" = report$Sigma_phy[2L, 1L],
      "phylo_cov[2,2]" = report$Sigma_phy[2L, 2L],
      "residual_var_shared[1]" = report$sigma_eps^2,
      "residual_var_shared[2]" = report$sigma_eps^2
    )
  }
  native_estimate <- native_targets(fixed)
  step <- 1e-5
  jacobian <- sapply(seq_along(fixed), function(index) {
    plus <- minus <- fixed
    plus[index] <- plus[index] + step
    minus[index] <- minus[index] - step
    (native_targets(plus) - native_targets(minus)) / (2 * step)
  })
  covariance <- native$sd_report$cov.fixed
  native_se <- sqrt(pmax(0, diag(jacobian %*% covariance %*% t(jacobian))))
  critical <- stats::qnorm(0.95)
  native_lower <- native_estimate - critical * native_se
  native_upper <- native_estimate + critical * native_se
  log_targets <- names(native_estimate) %in% c(
    "phylo_cov[1,1]", "phylo_cov[2,2]",
    "residual_var_shared[1]", "residual_var_shared[2]"
  )
  log_jacobian <- jacobian[log_targets, , drop = FALSE] / native_estimate[log_targets]
  log_se <- sqrt(pmax(0, diag(log_jacobian %*% covariance %*% t(log_jacobian))))
  native_lower[log_targets] <- exp(log(native_estimate[log_targets]) - critical * log_se)
  native_upper[log_targets] <- exp(log(native_estimate[log_targets]) + critical * log_se)
  julia_ci <- confint(julia, level = 0.9)
  embedded_julia_active_project <- normalizePath(as.character(JuliaCall::julia_eval("string(Base.active_project())")), mustWork = TRUE)
  embedded_julia_package_root <- normalizePath(as.character(JuliaCall::julia_eval("string(Base.pkgdir(GLLVM))")), mustWork = TRUE)
  expect_identical(embedded_julia_package_root, normalizePath(julia_project, mustWork = TRUE))

  expect_identical(rownames(julia_ci), names(native_estimate))
  ## Independent native and Julia optimizers are compared on an absolute scale;
  ## 5e-6 exceeds the observed 9e-7 component difference without masking a
  ## meaningful covariance mismatch in this small controlled fixture.
  expect_equal(as.numeric(julia$phylo_covariance), as.numeric(native$report$Sigma_phy), tolerance = 5e-6)
  expect_equal(as.numeric(julia_ci[, 1L]), unname(native_lower), tolerance = 1e-4)
  expect_equal(as.numeric(julia_ci[, 2L]), unname(native_upper), tolerance = 1e-4)
  assign(".s4_public_phylo_dep_receipt", list(
    target_names = rownames(julia_ci), native_lower = unname(native_lower),
    native_upper = unname(native_upper), julia_lower = as.numeric(julia_ci[, 1L]),
    julia_upper = as.numeric(julia_ci[, 2L]),
    embedded_julia_active_project = embedded_julia_active_project,
    embedded_julia_package_root = embedded_julia_package_root,
    fixture_sha256 = digest::digest(list(
      data = data, tree = tree,
      formula = "traits(trait_1, trait_2) ~ 1 + phylo_dep(1 | species, tree = tree)",
      family = "gaussian", ci_level = 0.9,
      test_source = readLines("tests/testthat/test-julia-phylo-rr-bridge.R", warn = FALSE)
    ), algo = "sha256", serialize = TRUE)
  ), envir = globalenv())
})

test_that("S4 Tree wrapper is an explicit post-fit Wald surface", {
  fit <- .s4_tree_wrapper_fixture()
  captured <- NULL

  result <- gllvmTMB:::gllvm_julia_phylo_rr(
    fit,
    ci_level = 0.9,
    .julia_call = function(...) {
      captured <<- list(...)
      .s4_tree_wrapper_julia_result(...)
    }
  )

  expect_s3_class(result, "gllvmTMB_julia_phylo_rr")
  expect_false(inherits(result, "gllvmTMB_julia"))
  expect_equal(captured$options$ci_method, "wald")
  expect_equal(captured$options$ci_level, 0.9)
  expect_equal(
    gllvmTMB:::coef.gllvmTMB_julia_phylo_rr(result),
    c(traitt1 = -0.2, traitt2 = 0.3)
  )
  ci <- gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9)
  expect_equal(rownames(ci), c("beta[1]", "beta[2]", "phylo_cov[1,1]"))
  expect_true(all(ci[, 1L] < ci[, 2L]))
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, parm = "signal", level = 0.9),
    "unavailable"
  )
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, method = "wald", level = 0.9),
    "recomputation"
  )
  result_logLik <- gllvmTMB:::logLik.gllvmTMB_julia_phylo_rr(result)
  expect_equal(as.numeric(result_logLik), -4.5)
  expect_equal(attr(result_logLik, "df"), length(result$parameters))
  expect_equal(attr(result_logLik, "nobs"), result$n_traits * result$n_observations)
  expect_true(is.list(gllvmTMB:::summary.gllvmTMB_julia_phylo_rr(result)))
})

test_that("S4 Tree wrapper refuses an unconverged native fit before Julia", {
  fit <- .s4_tree_wrapper_fixture()
  fit$opt$convergence <- 1L
  expect_error(
    gllvmTMB:::gllvm_julia_phylo_rr(fit, .julia_call = .s4_tree_wrapper_julia_result),
    "GJL-GATE-PHYLO-MV-NATIVE-HEALTH"
  )
  fit <- .s4_tree_wrapper_fixture()
  fit$opt$convergence <- 0.5
  expect_error(
    gllvmTMB:::gllvm_julia_phylo_rr(fit, .julia_call = .s4_tree_wrapper_julia_result),
    "GJL-GATE-PHYLO-MV-NATIVE-HEALTH"
  )
  fit <- .s4_tree_wrapper_fixture()
  fit$opt <- 0
  expect_error(
    gllvmTMB:::gllvm_julia_phylo_rr(fit, .julia_call = .s4_tree_wrapper_julia_result),
    "GJL-GATE-PHYLO-MV-NATIVE-HEALTH"
  )
})

test_that("S4 Tree wrapper refuses counterfeit non-Wald stored endpoints", {
  fit <- .s4_tree_wrapper_fixture()
  result <- gllvmTMB:::gllvm_julia_phylo_rr(
    fit,
    ci_level = 0.9,
    .julia_call = .s4_tree_wrapper_julia_result
  )
  result$ci_target_methods[1L] <- "profile"
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
    "GJL-GATE-PHYLO-MV-CI-RESULT"
  )
  result <- gllvmTMB:::gllvm_julia_phylo_rr(
    fit,
    ci_level = 0.9,
    .julia_call = .s4_tree_wrapper_julia_result
  )
  result$ci_method <- "profile"
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
    "GJL-GATE-PHYLO-MV-CI-RESULT"
  )
  result <- gllvmTMB:::gllvm_julia_phylo_rr(
    fit,
    ci_level = 0.9,
    .julia_call = .s4_tree_wrapper_julia_result
  )
  result$ci_statuses[1L] <- NA_character_
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
    "GJL-GATE-PHYLO-MV-CI-RESULT"
  )
})

test_that("S4 Tree wrapper refuses reversed stored endpoints", {
  result <- .s4_tree_wrapper_julia_result()
  result$ci_lower[1L] <- 0
  result$ci_upper[1L] <- -0.4
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
    "GJL-GATE-PHYLO-MV-CI-RESULT"
  )
})

test_that("S4 Tree wrapper refuses collapsed stored endpoints", {
  result <- .s4_tree_wrapper_julia_result()
  result$ci_lower[1L] <- result$ci_estimate[1L]
  result$ci_upper[1L] <- result$ci_estimate[1L]
  expect_error(
    gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
    "GJL-GATE-PHYLO-MV-CI-RESULT"
  )
})

test_that("S4 Tree wrapper refuses stored endpoints excluding their estimate", {
  for (estimate in c(-0.5, 0.1)) {
    result <- .s4_tree_wrapper_julia_result()
    result$ci_estimate[1L] <- estimate
    expect_error(
      gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
      "GJL-GATE-PHYLO-MV-CI-RESULT"
    )
  }
})

test_that("S4 Tree wrapper accepts an estimate equal to its lower endpoint", {
  result <- .s4_tree_wrapper_julia_result()
  result$ci_estimate[1L] <- result$ci_lower[1L]
  ci <- gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9)
  expect_equal(unname(ci["beta[1]", ]), c(-0.4, 0.0))
})

test_that("S4 Tree wrapper accepts an estimate equal to its upper endpoint", {
  result <- .s4_tree_wrapper_julia_result()
  result$ci_estimate[1L] <- result$ci_upper[1L]
  ci <- gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9)
  expect_equal(unname(ci["beta[1]", ]), c(-0.4, 0.0))
})

test_that("S4 Tree wrapper refuses available non-finite stored endpoints", {
  for (endpoint in c("ci_lower", "ci_upper")) {
    for (value in c(NA_real_, Inf, -Inf)) {
      result <- .s4_tree_wrapper_julia_result()
      result[[endpoint]][1L] <- value
      expect_error(
        gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
        "GJL-GATE-PHYLO-MV-CI-RESULT"
      )
    }
  }
})

test_that("S4 Tree wrapper refuses available non-finite stored estimates", {
  for (value in c(NA_real_, Inf, -Inf)) {
    result <- .s4_tree_wrapper_julia_result()
    result$ci_estimate[1L] <- value
    expect_error(
      gllvmTMB:::confint.gllvmTMB_julia_phylo_rr(result, level = 0.9),
      "GJL-GATE-PHYLO-MV-CI-RESULT"
    )
  }
})

test_that("S4 Tree wrapper rejects a non-intercept fixed design before Julia", {
  fit <- .s4_tree_wrapper_fixture()
  fit$X_fix[, 1L] <- 2
  expect_error(
    gllvmTMB:::gllvm_julia_phylo_rr(fit, .julia_call = .s4_tree_wrapper_julia_result),
    "GJL-GATE-PHYLO-MV-X-FIX"
  )
})
