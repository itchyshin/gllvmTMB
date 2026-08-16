## Fenced planned tapes: beta and Tweedie may exist in C++ but the
## public door still rejects estimator = "mspl". nbinom1/nbinom2 now
## share the Poisson planned door (not admitted).
##
## Beta Jeffreys (Ferrari–Cribari-Neto mean-model weight) is NOT coercive
## at mu -> 0/1. Tweedie W = mu^{2-p} / phi REWARDS phi -> 0. These are
## hostilities, not repairs. Do not sell either atom as a fix.
##
## Atom = GLM-outer 1/2 log det(X' W X) candidate, NOT I_LA(beta).

.mspl_fence_dat <- function(y) {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = y
  )
}

.mspl_fence_form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

.mspl_cpp_source <- function() {
  cpp_candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  installed <- system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")
  if (nzchar(installed)) {
    cpp_candidates <- c(installed, cpp_candidates)
  }
  cpp_path <- cpp_candidates[file.exists(cpp_candidates)][1L]
  testthat::skip_if(
    is.na(cpp_path),
    "gllvmTMB.cpp source file is not available in this test context."
  )
  paste(readLines(cpp_path, warn = FALSE), collapse = "\n")
}

## After stripping negations ("not I_LA(beta)", "NOT Laplace-marginal I(beta)"),
## leftover mentions mean a comment called the GLM-outer atom I_LA(beta).
.mspl_calls_atom_ila_beta <- function(cpp) {
  stripped <- gsub(
    "(?i)not\\s+(?:the\\s+)?(?:laplace-marginal\\s+)?I(?:_LA)?\\s*\\(\\s*(?:beta|β)\\s*\\)",
    "",
    cpp,
    perl = TRUE
  )
  grepl(
    "(?i)I_LA\\s*\\(\\s*(?:beta|β)\\s*\\)",
    stripped,
    perl = TRUE
  )
}

test_that("public mspl still rejects beta and Tweedie", {
  cases <- list(
    beta = list(family = Beta(), y = rep(c(0.2, 0.5, 0.8), length.out = 24L)),
    tweedie = list(family = tweedie(), y = rep(c(0.5, 1, 2), length.out = 24L))
  )
  for (family_name in names(cases)) {
    case <- cases[[family_name]]
    dat <- .mspl_fence_dat(case$y)
    expect_error(
      gllvmTMB(
        .mspl_fence_form,
        data = dat,
        family = case$family,
        estimator = "mspl"
      ),
      class = "gllvmTMB_mspl_unsupported",
      info = family_name
    )
  }
})

test_that("public mspl rejects Beta() and tweedie() at the door", {
  dat_beta <- .mspl_fence_dat(rep(c(0.2, 0.5, 0.8), length.out = 24L))
  expect_error(
    gllvmTMB(
      .mspl_fence_form,
      data = dat_beta,
      family = Beta(),
      estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
  dat_tweedie <- .mspl_fence_dat(rep(c(0.5, 1, 2), length.out = 24L))
  expect_error(
    gllvmTMB(
      .mspl_fence_form,
      data = dat_tweedie,
      family = tweedie(),
      estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
})

test_that("nbinom planned is not admitted; no planned/admitted beta or Tweedie", {
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  nb <- reg[reg$family %in% c("nbinom1", "nbinom2"), , drop = FALSE]
  expect_true(nrow(nb) >= 4L)
  expect_true(all(nb$status == "planned"))
  expect_false(any(nb$status == "admitted"))
  beta_names <- c("beta", "Beta")
  tweedie_names <- c("tweedie", "Tweedie")
  expect_false(any(reg$family %in% beta_names &
                     reg$status %in% c("planned", "admitted")))
  expect_false(any(reg$family %in% tweedie_names &
                     reg$status %in% c("planned", "admitted")))
  expect_null(gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    "beta", "logit", "ordinary", 1L
  ))
  expect_null(gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    "tweedie", "log", "ordinary", 1L
  ))
  expect_true(any(reg$family == "poisson" & reg$status == "admitted"))
  expect_false(any(reg$family %in% c("nbinom1", "nbinom2",
                                     beta_names, tweedie_names) &
                     reg$status == "admitted"))
})

test_that("C++ GLM-outer hook names beta/Tweedie hostilities and not I_LA(beta)", {
  cpp <- .mspl_cpp_source()
  expect_match(cpp, "GLM-outer", info = "must name GLM-outer, not I_LA")
  expect_match(cpp, "family_id == 7", info = "Beta tape")
  expect_match(cpp, "family_id == 6", info = "Tweedie tape")
  ## Beta Jeffreys is NOT coercive at mu -> 0/1. Not a repair.
  expect_match(cpp, "not coercive", info = "Beta hostility")
  ## Tweedie W = mu^{2-p} / phi REWARDS phi -> 0. Not a repair.
  expect_match(cpp, "rewards", info = "Tweedie hostility")
  expect_match(cpp, "family_id == 2", info = "Poisson tape")
  expect_match(cpp, "family_id == 5", info = "NB2 tape")
  expect_match(cpp, "family_id == 15", info = "NB1 tape")
  expect_false(
    .mspl_calls_atom_ila_beta(cpp),
    info = "comments must not call the GLM-outer atom I_LA(beta)"
  )
})
