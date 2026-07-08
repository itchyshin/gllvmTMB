## Tier-claiming for per-trait diagonal (`diag`) covstructs.
##
## The engine has two additive per-trait diagonal slots that live at DIFFERENT
## groupings: the unit tier (`use_diag_B` / `s_B`, scaled by `sd_B`) and the
## cluster tier (`use_diag_species` / `q_sp`, scaled by `sd_q`) -- the latter is
## the `q_it` term of the Nakagawa et al. functional-biogeography framework, and
## is meaningful in a crossed `site x species` design (see R/fit-multi.R:1637).
##
## Both enter `eta` additively at index `(trait, group)`:
##   src/gllvmTMB.cpp:1821  eta(o) += s_B(t, site_id(o));
##   src/gllvmTMB.cpp:1839  eta(o) += q_sp(t, species_id(o));
##
## When `unit == cluster` those indices coincide, so a SINGLE `diag` covstruct
## on that grouping used to satisfy both tier predicates and materialise both
## slots. The two draws then collapse to one N(0, sd_B^2 + sd_q^2) per
## (trait, group): only the SUM is identified. The split is arbitrary -- walking
## it from 50/50 to 95/5 at fixed sum moves the objective by ~1e-9 -- yet
## `extract_Sigma()`, `extract_communality()`, `extract_repeatability()`,
## `extract_phylo_signal()` and `VP()` all read one block alone. It also leaves
## the Hessian with `n_traits` exactly-flat directions, so `pdHess` is FALSE and
## every Wald SE silently becomes NA.
##
## Each `diag` covstruct must therefore be claimed by exactly ONE tier.
## `B_lv = Lambda_B alpha^T` is invariant along the ridge, so this is a variance
## /uncertainty defect, not a point-estimate one.

.diag_alias_fx <- function(S = 30L, T_ = 4L, seed = 20260708L) {
  set.seed(seed)
  tree <- ape::rcoal(S)
  tree$tip.label <- paste0("sp", seq_len(S))
  A <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A))
  LambdaB   <- matrix(c(1.0, 0.8, -0.6, 0.5)[seq_len(T_)], T_, 1)
  LambdaPhy <- matrix(c(0.7, -0.5, 0.4, 0.6)[seq_len(T_)], T_, 1)
  alpha <- 0.9
  beta  <- stats::rnorm(T_, 0, 0.5)
  x     <- stats::rnorm(S)
  zB    <- matrix(x, S, 1) * alpha + matrix(stats::rnorm(S), S, 1)
  gphy  <- LA %*% matrix(stats::rnorm(S), S, 1)
  eta   <- matrix(beta, S, T_, byrow = TRUE) + zB %*% t(LambdaB) + gphy %*% t(LambdaPhy)
  y     <- eta + matrix(stats::rnorm(S * T_, 0, 0.5), S, T_)
  list(
    tree = tree,
    truth_B_lv = as.vector(LambdaB %*% t(alpha)),
    data = data.frame(
      species = factor(rep(tree$tip.label, times = T_), levels = tree$tip.label),
      trait   = factor(rep(paste0("t", seq_len(T_)), each = S)),
      value   = as.vector(y),
      x       = rep(x, times = T_)
    )
  )
}

.diag_alias_fit <- function(fx) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | species, d = 1, lv = ~x) +
      phylo_latent(0 + trait | species, d = 1, tree = fx$tree),
    data = fx$data, unit = "species", trait = "trait", family = gaussian(),
    REML = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(
      se = TRUE, optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )))
}

test_that("a diag covstruct at unit == cluster claims exactly one tier", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fit <- .diag_alias_fit(.diag_alias_fx())

  expect_equal(fit$opt$convergence, 0L)
  ## The single auto-emitted Psi belongs to the unit tier.
  expect_true(isTRUE(fit$use$diag_B))
  ## It must NOT also materialise the cluster slot.
  expect_false(isTRUE(fit$use$diag_species))
  expect_false("theta_diag_species" %in% names(fit$opt$par))
  ## sd_q must not be reported, so downstream consumers cannot read exp(0) = 1.
  expect_null(fit$report[["sd_q"]])
})

test_that("no unidentified ridge remains: the Hessian is positive definite", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fit <- .diag_alias_fit(.diag_alias_fx())

  par <- fit$opt$par
  H <- optimHess(par, fit$tmb_obj$fn, fit$tmb_obj$gr)
  ev <- eigen((H + t(H)) / 2, symmetric = TRUE, only.values = TRUE)$values
  ## Before the tier-claiming fix there were exactly n_traits flat directions.
  expect_equal(sum(ev < 1e-3), 0L)
  expect_true(isTRUE(fit$sd_report$pdHess))
})

test_that("Wald SEs for B_lv are available once the alias is gone", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fit <- .diag_alias_fit(.diag_alias_fx())

  w <- gllvmTMB::extract_lv_effects(fit)
  expect_true(all(is.finite(w$std.error)))
  expect_true(all(is.finite(w$lower)), label = "Wald lower endpoints finite")
})

test_that("extract_Sigma reports the whole Psi at one tier, and none at the other", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  fit <- .diag_alias_fit(.diag_alias_fx())

  ## The whole per-trait Psi lives at the unit tier and equals exp(2 * theta_diag_B):
  ## there is no second block left to hold an arbitrary half of it.
  psi <- as.numeric(gllvmTMB::extract_Sigma(fit, level = "unit", part = "unique")$s)
  par <- fit$opt$par
  expect_equal(psi, as.numeric(exp(2 * par[names(par) == "theta_diag_B"])))
  expect_true(all(is.finite(psi) & psi > 0))

  ## And the cluster tier must say so plainly rather than hand back sd_q^2.
  expect_error(
    gllvmTMB::extract_Sigma(fit, level = "cluster"),
    regexp = "nothing to extract"
  )
})

test_that("crossed site x species design keeps BOTH diagonal tiers (q_it)", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  ## Regression guard: when the groupings genuinely differ, the cluster tier
  ## (`q_sp`, the Nakagawa et al. q_it term) must survive alongside `s_B`.
  set.seed(11)
  n_site <- 25L; n_sp <- 8L; T_ <- 3L
  g <- expand.grid(
    site    = factor(paste0("s", seq_len(n_site))),
    species = factor(paste0("sp", seq_len(n_sp))),
    trait   = factor(paste0("t", seq_len(T_)))
  )
  g$value <- stats::rnorm(nrow(g))
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site) + indep(0 + trait | species),
    data = g, unit = "site", cluster = "species", trait = "trait",
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$diag_species))
})
