test_that("structured rho capture preserves endpoint calls and literal NULL", {
  f <- y ~ 0 + trait + phylo_latent(group, d = 1, unique = TRUE)
  endpoint <- .parse_structured_rho_formula(f)
  expect_identical(endpoint$formula, f)
  expect_null(endpoint$spec)
  one <- y ~ 0 + trait + phylo_latent(group, d = 1, unique = TRUE, rho = 1)
  expect_identical(.parse_structured_rho_formula(one)$formula, f)
  estimated <- .parse_structured_rho_formula(
    y ~ trait + phylo_latent(group, unique = TRUE, rho = NULL))
  expect_identical(estimated$spec$status, "estimated")
  expect_null(estimated$spec$value)
  expect_identical(estimated$spec$grouping, "group")
  expect_true(estimated$spec$folded_psi)
  expect_identical(estimated$spec$source, "phylo")
  expect_identical(estimated$spec$term, "structured_1")
  expect_false("rho" %in% names(as.list(estimated$formula[[3L]][[3L]])))
})

test_that("structured rho evaluates in the formula environment without coefficient capture", {
  strength <- 0.37
  f <- y ~ kernel_dep(group, K = K, rho = strength)
  out <- .parse_structured_rho_formula(f)
  expect_identical(out$spec$value, strength)
  expect_identical(out$spec$mode, "dep")
  positional <- .parse_structured_rho_formula(y ~ kernel_latent(group, K, 1, "kernel", TRUE, .3))
  expect_identical(positional$spec$value, .3)
  expect_true(positional$spec$folded_psi)
  expect_identical(positional$formula[[3L]]$unique, TRUE)
  expect_error(.parse_structured_rho_formula(y ~ phylo(group, rho = .4)),
    class = "gllvmTMB_structured_rho_alias")
  expect_error(.parse_structured_rho_formula(y ~ phylo_latent(group, rho = .4) +
    kernel_coef(x | trait, K = K)), class = "gllvmTMB_structured_rho_blocks")
  expect_error(.parse_structured_rho_formula(y ~ phylo_dep(log(trait) | group, rho = .4)),
    class = "gllvmTMB_structured_rho_slope")
  for (helper in c("phylo_coef", "animal_coef", "kernel_coef", "spatial_coef")) {
    f <- as.formula(paste0("y ~ ", helper, "(x | trait, rho = NULL)"))
    expect_identical(.parse_structured_rho_formula(f)$formula, f)
    expect_null(.parse_structured_rho_formula(f)$spec)
  }
})

test_that("sparse source diagonal marginalizes retained ancestors", {
  K <- matrix(c(3,1,.6, 1,2,.4, .6,.4,1), 3,
              dimnames = list(c("ancestor","a","b"), c("ancestor","a","b")))
  Q <- Matrix::Matrix(solve(K), sparse = TRUE)
  resolved <- .structured_rho_marginal_diagonal(Q, c("b", "a"))
  expect_equal(resolved$diagonal, diag(K)[c("b","a")], tolerance = 1e-12)
  expect_equal(resolved$contrast, .4, tolerance = 1e-12)
  # Negative controls catch reciprocal-diagonal and conditioned-tip mistakes.
  expect_gt(max(abs(resolved$diagonal - 1/Matrix::diag(Q)[c("b","a")])), .1)
  expect_gt(max(abs(resolved$diagonal - diag(solve(as.matrix(Q[c("b","a"),c("b","a")]))))), .1)
})

test_that("new attenuation rejects ambiguous blocks, aliases and unsupported dispatch", {
  for (value in list(-.1, 1.1, NA_real_, NaN, Inf, .5+0i, c(.2, .3), TRUE, "0.5")) {
    f <- y ~ phylo_dep(0 + trait | group, rho = value)
    expect_error(.parse_structured_rho_formula(f), class = "gllvmTMB_structured_rho_invalid")
  }
  expect_error(.parse_structured_rho_formula(
    y ~ kernel_latent(group, K = K, rho = .4) + kernel_latent(group, K = J)),
    class = "gllvmTMB_structured_rho_blocks")
  expect_null(.parse_structured_rho_formula(
    y ~ kernel_latent(group, K = K, rho = 1) + kernel_latent(group, K = J))$spec)
  expect_error(.parse_structured_rho_formula(y ~ animal_unique(group, rho = .4)),
    "animal_indep", class = "gllvmTMB_structured_rho_alias")
  expect_error(.parse_structured_rho_formula(y ~ phylo_scalar(group, rho = NULL)),
    "common = TRUE", class = "gllvmTMB_structured_rho_alias")
  expect_equal(.parse_structured_rho_formula(y ~ spatial_latent(0 + trait | coords, rho = .4))$spec$value,.4)
  expect_null(.parse_structured_rho_formula(y ~ spatial_dep(0 + trait | coords, rho = 1))$spec)
  expect_error(.parse_structured_rho_formula(y ~ animal_dep(1 + x | group, rho = .5)),
    class = "gllvmTMB_structured_rho_slope")
  spec <- .parse_structured_rho_formula(y ~ phylo_indep(0 + trait | group, rho = .5))$spec
  for (route in list(list(engine = "julia"), list(integration = "va"), list(estimator = "mspl"))) {
    expect_error(do.call(.structured_rho_dispatch_fence, c(list(spec = spec), route)),
      class = "gllvmTMB_structured_rho_dispatch")
  }
  expect_silent(.structured_rho_dispatch_fence(NULL, engine = "julia"))
})

test_that("covariance attenuation preserves source scale and modeled labels", {
  K <- matrix(c(2, .6, .4, .6, 3, .8, .4, .8, 4), 3,
              dimnames = list(c("c", "a", "b"), c("c", "a", "b")))
  D <- diag(diag(K)); dimnames(D) <- dimnames(K)
  for (r in c(0, .3, 1)) {
    mixed <- .structured_rho_covariance(K, r)
    expect_equal(mixed, r * K + (1-r) * D, tolerance = 1e-12)
    expect_identical(diag(mixed), diag(K))
    expect_identical(dimnames(mixed), dimnames(K))
    expect_equal(.structured_rho_covariance(K[c(3,1,2), c(3,1,2)], r),
                 mixed[c(3,1,2), c(3,1,2)], tolerance = 1e-12)
  }
  expect_identical(.structured_rho_covariance(K, 1), K)
})

test_that("independent oracle exposes confounding and whole-Psi requirement", {
  K <- matrix(c(1,.5,.5,1), 2)
  S <- tcrossprod(c(.8,.6)) + diag(c(.2,.3))
  T <- diag(2)
  r <- .3; rp <- .7
  original <- kronecker(.structured_rho_covariance(K,r), S) + kronecker(diag(2),T)
  alternative <- kronecker(.structured_rho_covariance(K,rp), r/rp*S) +
    kronecker(diag(2), T+(1-r/rp)*S)
  expect_equal(original, alternative, tolerance = 1e-12)
  wrong <- kronecker(.structured_rho_covariance(K,r), tcrossprod(c(.8,.6))) +
    kronecker(K, diag(c(.2,.3))) + kronecker(diag(2),T)
  expect_gt(max(abs(original-wrong)), .01)
  # Incidence repeats source effects; independent observation noise is separate.
  Z <- kronecker(diag(2), matrix(1,3,1))
  C <- Z %*% .structured_rho_covariance(K,r) %*% t(Z)
  expect_equal(C[1,2], 1)
  expect_equal(C[1,4], r*.5)
})
