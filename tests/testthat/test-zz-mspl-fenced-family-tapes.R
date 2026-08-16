## Fenced planned tapes: Tweedie/Beta may exist in C++ and now have
## planned registry rows, but the public door still rejects
## estimator = "mspl". nbinom1/nbinom2 share the Poisson planned door
## (not admitted). Tweedie hang keeps Tweedie off the allow-list.
## Beta family id 7 stays off the public door (atom is now K_bb).
##
## Beta Jeffreys (Ferrari–Cribari-Neto mean-model weight) is NOT coercive
## at mu -> 0/1. True Tweedie W = mu^{2-p} / phi REWARDS phi -> 0
## (one-sided). Live tape uses working logistic W_* plus Huber on
## log_phi / logit(p-1). That is an existence device, not a repair
## and not an admit. Public door stays closed.
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

test_that("public mspl still rejects Gamma and lognormal", {
  cases <- list(
    Gamma = list(family = stats::Gamma(link = "log"), y = rep(c(0.5, 1, 2), length.out = 24L)),
    lognormal = list(family = lognormal(), y = rep(c(0.5, 1, 2), length.out = 24L))
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

test_that("public mspl still rejects Beta() and tweedie() at the door", {
  old_probe <- Sys.getenv("GLLVMTMB_MSPL_TWEEDIE_PROBE", unset = NA_character_)
  Sys.unsetenv("GLLVMTMB_MSPL_TWEEDIE_PROBE")
  on.exit({
    if (is.na(old_probe)) {
      Sys.unsetenv("GLLVMTMB_MSPL_TWEEDIE_PROBE")
    } else {
      Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = old_probe)
    }
  }, add = TRUE)
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

test_that("nbinom/Tweedie/Beta planned is not admitted; public door stays closed", {
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  planned_ok <- c(
    "nbinom1", "nbinom2", "tweedie", "Beta", "gamma", "lognormal",
    "student", "ordinal_probit", "betabinomial",
    "truncated_poisson", "truncated_nbinom2", "multinomial"
  )
  nb_tb <- reg[reg$family %in% planned_ok, , drop = FALSE]
  expect_true(nrow(nb_tb) >= 8L)
  expect_true(all(nb_tb$status == "planned"))
  expect_false(any(nb_tb$status == "admitted"))
  expect_true(any(reg$family == "poisson" & reg$status == "admitted"))
  expect_false(any(reg$family %in% planned_ok & reg$status == "admitted"))
})

test_that("C++ GLM-outer hook names beta/Tweedie hostilities and not I_LA(beta)", {
  cpp <- .mspl_cpp_source()
  expect_match(cpp, "GLM-outer", info = "must name GLM-outer, not I_LA")
  expect_match(cpp, "family_id == 7", info = "Beta tape")
  expect_match(cpp, "family_id == 6", info = "Tweedie tape")
  ## Beta Jeffreys is NOT coercive at mu -> 0/1. Not a repair.
  expect_match(cpp, "not coercive", info = "Beta hostility")
  ## True Tweedie W rewards phi -> 0. Live tape is working W_*.
  expect_match(cpp, "rewards", info = "Tweedie true-W hostility")
  expect_match(cpp, "working logistic", info = "Tweedie working W_*")
  expect_match(cpp, "pseudohuber(log_phi_tweedie", info = "Tweedie Huber on log phi",
               fixed = TRUE)
  expect_match(cpp, "family_id == 2", info = "Poisson tape")
  expect_match(cpp, "family_id == 5", info = "NB2 tape")
  expect_match(cpp, "family_id == 15", info = "NB1 tape")
  expect_false(
    .mspl_calls_atom_ila_beta(cpp),
    info = "comments must not call the GLM-outer atom I_LA(beta)"
  )
})

test_that("MSPL BFGS rescue skips Tweedie family 6", {
  ## Residual #999 hang after working W_*: rescue restarts BFGS from
  ## par_init with maxit=5000 into dtweedie series cost. Spatial
  ## Bernoulli keeps the rescue; Tweedie must not.
  fit_path <- testthat::test_path("..", "..", "R", "fit-multi.R")
  testthat::skip_if(!file.exists(fit_path), "fit-multi.R not in this test context")
  txt <- paste(readLines(fit_path, warn = FALSE), collapse = "\n")
  expect_match(txt, "Tweedie is excluded")
  expect_match(txt, "!identical\\(as.integer\\(family_id\\), 6L\\)")
})
