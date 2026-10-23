## PA2 -- phylogenetic heritability H^2 for the categorical families
## (Design 123 "Paper alignment": Mizuno et al. 2025 J. Evol. Biol.
## 38:1699-1715, eq 4/18/19).
##
## extract_phylo_signal(link_residual = "auto") adds the fixed liability
## residual sigma^2_d to the denominator:
##   ordinal_probit (fid 14): H^2_t   = V_a,t  / (V_a,t  + 1)        per trait
##   multinomial    (fid 16): H^2_(k) = V_a(k) / (V_a(k) + pi^2/3)   per CONTRAST
## Contrast H^2 is baseline-referenced (the softmax link residual is the full
## (pi^2/6)(I + J) matrix; the shared baseline couples contrasts), so the
## output keeps one row per contrast and is never collapsed to a scalar.
##
## Hand-computed cells use the house mocked-fit pattern (test-extract-omega.R);
## live cells reuse the star-tree ordinal fixture recipe
## (test-matrix-ordinal-phylo.R) and dgp_multinomial_structured(), heavy-gated
## with skip-honest discipline. The MCMCglmm cell is the paper's own route
## (family = "ordinal", R fixed at 1) as the cross-package comparator.

## ---------------------------------------------------------------
## Mocked-fit helpers (hand-computed values, no TMB fit)
## ---------------------------------------------------------------

.mock_phylo_fit <- function(trait_names, fids) {
  structure(
    list(
      use = list(phylo_rr = TRUE),
      n_traits = length(trait_names),
      data = data.frame(
        trait = factor(trait_names, levels = trait_names)
      ),
      trait_col = "trait",
      unit_col = "site",       # unit != cluster => only the phy tier is read
      cluster_col = "species",
      tmb_data = list(family_id_vec = fids)
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

## Mock extract_Sigma to serve a known phy-tier Sigma, and
## link_residual_per_trait to serve a known sigma^2_d vector.
.with_mocked_phy <- function(Va, sigma2_d, code) {
  Tn <- length(Va)
  trait_names <- names(Va)
  Sigma <- diag(Va, nrow = Tn)
  dimnames(Sigma) <- list(trait_names, trait_names)
  testthat::local_mocked_bindings(
    extract_Sigma = function(fit, level, part, link_residual = "none", ...) {
      stopifnot(identical(level, "phy"))
      list(Sigma = Sigma, note = "mock phy")
    },
    link_residual_per_trait = function(fit) {
      stats::setNames(sigma2_d, trait_names)
    },
    .package = "gllvmTMB",
    .env = parent.frame()
  )
  force(code)
}

test_that("ordinal_probit hand-computed H2 = Va / (Va + 1) with link_residual = 'auto' (fid 14)", {
  Va <- c(trait_1 = 0.6, trait_2 = 0.4)
  fit <- .mock_phylo_fit(names(Va), fids = 14L)
  .with_mocked_phy(Va, sigma2_d = c(1, 1), {
    ps <- suppressMessages(
      extract_phylo_signal(fit, link_residual = "auto")
    )
    expect_equal(ps$H2, unname(Va / (Va + 1)), tolerance = 1e-12)
    expect_equal(ps$link_residual, unname(1 / (Va + 1)), tolerance = 1e-12)
    expect_equal(ps$V_eta, unname(Va + 1), tolerance = 1e-12)
    ## Four proportions sum to one.
    expect_equal(ps$H2 + ps$C2_non + ps$Psi + ps$link_residual,
                 rep(1, 2), tolerance = 1e-12)
    expect_named(ps, c("trait", "H2", "C2_non", "Psi", "link_residual", "V_eta"))
  })
})

test_that("multinomial hand-computed per-contrast H2 = Va(k) / (Va(k) + pi^2/3); never collapsed (fid 16)", {
  ## Two baseline-category contrasts of one K = 3 multinomial trait.
  Va <- c("morph:2" = 0.09, "morph:3" = 0.02)
  fit <- .mock_phylo_fit(names(Va), fids = 16L)
  .with_mocked_phy(Va, sigma2_d = rep(pi^2 / 3, 2), {
    ps <- suppressMessages(
      extract_phylo_signal(fit, link_residual = "auto")
    )
    ## One row PER CONTRAST -- baseline-referenced, never a scalar.
    expect_equal(nrow(ps), 2L)
    expect_equal(as.character(ps$trait), c("morph:2", "morph:3"))
    expect_equal(ps$H2, unname(Va / (Va + pi^2 / 3)), tolerance = 1e-12)
    expect_equal(ps$V_eta, unname(Va + pi^2 / 3), tolerance = 1e-12)
    expect_equal(ps$H2 + ps$C2_non + ps$Psi + ps$link_residual,
                 rep(1, 2), tolerance = 1e-12)
  })
})

test_that("default link_residual = 'none' is unchanged (H2 = 1 phylo-only) and advises for fid 14/16", {
  Va <- c(trait_1 = 0.6, trait_2 = 0.4)
  fit <- .mock_phylo_fit(names(Va), fids = 14L)
  .with_mocked_phy(Va, sigma2_d = c(1, 1), {
    ## Advisory names the liability route.
    msgs <- character(0)
    withCallingHandlers(
      ps <- extract_phylo_signal(fit),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_true(any(grepl("liability", msgs)))
    ## Back-compat shape and values.
    expect_named(ps, c("trait", "H2", "C2_non", "Psi", "V_eta"))
    expect_equal(ps$H2, rep(1, 2))
    expect_equal(ps$V_eta, unname(Va), tolerance = 1e-12)
  })
})

test_that("no liability advisory for a gaussian fit (fid 0)", {
  Va <- c(trait_1 = 0.6, trait_2 = 0.4)
  fit <- .mock_phylo_fit(names(Va), fids = 0L)
  .with_mocked_phy(Va, sigma2_d = c(0, 0), {
    msgs <- character(0)
    withCallingHandlers(
      extract_phylo_signal(fit),
      message = function(m) {
        msgs <<- c(msgs, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
    expect_false(any(grepl("liability", msgs)))
  })
})

## ---------------------------------------------------------------
## Typed refusals
## ---------------------------------------------------------------

test_that("typed refusal: no admitted phylo tier", {
  fit <- .mock_phylo_fit(c("a", "b"), fids = 14L)
  fit$use <- list()
  expect_error(
    extract_phylo_signal(fit, link_residual = "auto"),
    class = "gllvmTMB_phylo_signal_no_phylo_tier"
  )
})

test_that("typed refusal: ci = TRUE with link_residual = 'auto'", {
  fit <- .mock_phylo_fit(c("a", "b"), fids = 14L)
  expect_error(
    extract_phylo_signal(fit, ci = TRUE, link_residual = "auto"),
    class = "gllvmTMB_phylo_signal_ci_link_residual_unsupported"
  )
})

## ---------------------------------------------------------------
## Live fits (heavy-gated, skip-honest)
## ---------------------------------------------------------------

skip_if_not_categorical_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Star-tree ordinal fixture -- same recipe as test-matrix-ordinal-phylo.R
## (Cphy = I so species are i.i.d. on the phylo side; n_rep replicates per
## (species, trait) cell concentrate the per-cell likelihood).
.make_ordinal_phylo_fixture_pa2 <- function(n_sp = 50L, n_traits = 4L,
                                            n_rep = 4L, seed = 20260529L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  sigma2_phy_true <- c(0.6, 0.5, 0.4, 0.5)[seq_len(n_traits)]
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sqrt(sigma2_phy_true[t]) * stats::rnorm(n_sp)
  }
  alpha  <- c(0.2, -0.1, 0.0, 0.1)[seq_len(n_traits)]
  taus   <- c(0, 0.7, 1.4)
  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) for (t in seq_len(n_traits)) for (r in seq_len(n_rep)) {
    x     <- stats::rnorm(1L)
    ystar <- alpha[t] + 0.8 * x + p_mat[i, t] + stats::rnorm(1L)
    rows[[k]] <- data.frame(
      species = sp_names[i], trait = paste0("trait_", t),
      x = x, value = 1L + sum(ystar > taus),
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp_names)
  df$trait   <- factor(df$trait, levels = paste0("trait_", seq_len(n_traits)))
  list(data = df, Cphy = Cphy, sigma2_phy_true = sigma2_phy_true)
}

test_that("live ordinal_probit phylo fit: liability H2 = Va/(Va + 1), loose recovery of truth", {
  skip_if_not_heavy()
  skip_if_not_categorical_phylo_deps()
  fx <- .make_ordinal_phylo_fixture_pa2()
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + phylo_latent(species, d = 1) + phylo_unique(species),
      data = fx$data, phylo_vcv = fx$Cphy, unit = "species",
      family = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("ordinal phylo fit failed to construct: %s",
                 conditionMessage(fit)))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("ordinal phylo fit did not converge with PD Hessian; PA2 liability H2 cell stays partial pending bigger n / different seed")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 14L)

  ## Default (species-level latent denominator): phylo-only => H2 = 1.
  ps0 <- suppressMessages(gllvmTMB::extract_phylo_signal(fit))
  expect_equal(ps0$H2, rep(1, fit$n_traits))

  ## Liability-scale H2 (the paper's eq 18): Va / (Va + 1), per trait.
  ps <- suppressMessages(
    gllvmTMB::extract_phylo_signal(fit, link_residual = "auto")
  )
  Va <- diag(suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "total", link_residual = "none"
  ))$Sigma)
  expect_equal(ps$H2, unname(Va / (Va + 1)), tolerance = 1e-8)
  expect_true(all(ps$H2 > 0 & ps$H2 < 1))
  ## Loose recovery: truth on the liability scale is
  ## sigma2_phy_true / (sigma2_phy_true + 1) in (0.286, 0.375). This seed's
  ## fits sit within ~0.08 of truth; the 0.2 band absorbs seed noise without
  ## admitting a broken denominator (a wrong sigma_d would shift H2 by >> 0.2).
  h2_true <- fx$sigma2_phy_true / (fx$sigma2_phy_true + 1)
  expect_true(all(abs(ps$H2 - h2_true) <= 0.2))
})

test_that("live multinomial phylo fit: per-contrast liability H2 = Va(k)/(Va(k) + pi^2/3) (wiring, no recovery claim)", {
  skip_if_not_heavy()
  skip_if_not_categorical_phylo_deps()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("MASS")
  dgp_path <- testthat::test_path("..", "..", "dev", "multinomial-structured",
                                  "dgp-multinomial-structured.R")
  testthat::skip_if(!file.exists(dgp_path),
                    "dev/ DGP script not present in this checkout")
  source(dgp_path, local = TRUE)

  ## ONE categorical draw per species: FAM-20C established this regime does
  ## NOT identify V (rail rate 8/20), so this cell asserts the H2 WIRING
  ## (denominator + shape) only -- no recovery claim is admissible here.
  sim <- dgp_multinomial_structured(n_sp = 150L, seed = 42L)
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 2),
      data = sim$data, phylo_vcv = sim$A_corr, trait = "trait",
      unit = "species", family = multinomial()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("multinomial phylo fit failed to construct: %s",
                 conditionMessage(fit)))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("multinomial phylo fit did not converge with PD Hessian; PA2 wiring cell stays partial pending different seed")
  }
  expect_equal(fit$tmb_data$family_id_vec[1], 16L)

  ps <- suppressMessages(
    gllvmTMB::extract_phylo_signal(fit, link_residual = "auto")
  )
  ## K = 3 => exactly K - 1 = 2 contrast rows, named "<base>:<cat>";
  ## baseline-referenced, never collapsed to one scalar.
  expect_equal(nrow(ps), 2L)
  expect_true(all(grepl(":", as.character(ps$trait))))
  Va <- diag(suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "total", link_residual = "none"
  ))$Sigma)
  expect_equal(ps$H2, unname(Va / (Va + pi^2 / 3)), tolerance = 1e-8)
  expect_true(all(ps$H2 >= 0 & ps$H2 < 1))
  expect_equal(ps$link_residual, unname((pi^2 / 3) / (Va + pi^2 / 3)),
               tolerance = 1e-8)
})

## ---------------------------------------------------------------
## MCMCglmm comparator (the paper's own route; heavy-gated)
## ---------------------------------------------------------------

test_that("ordinal liability H2 agrees with MCMCglmm family = 'ordinal', R fixed at 1 (band 0.15)", {
  skip_if_not_heavy()
  skip_if_not_categorical_phylo_deps()
  testthat::skip_if_not_installed("MCMCglmm")
  testthat::skip_if_not_installed("ape")

  ## Real coalescent tree, two traits, diagonal phylo tier (marginal model of
  ## each trait = the univariate ordinal PGLMM MCMCglmm fits). K = 3.
  set.seed(20260817L)
  n_sp <- 100L; n_rep <- 4L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sigma2_phy_true <- c(1.0, 0.5)      # liability H2_true = 0.5, 1/3
  L <- t(chol(Cphy + 1e-8 * diag(n_sp)))
  a_mat <- cbind(as.numeric(L %*% stats::rnorm(n_sp)) * sqrt(sigma2_phy_true[1]),
                 as.numeric(L %*% stats::rnorm(n_sp)) * sqrt(sigma2_phy_true[2]))
  taus <- c(0, 0.9)
  df <- expand.grid(rep = seq_len(n_rep), trait = c("t1", "t2"),
                    species = tree$tip.label, stringsAsFactors = FALSE)
  df$species <- factor(df$species, levels = tree$tip.label)
  df$trait <- factor(df$trait)
  df$x <- stats::rnorm(nrow(df))
  ystar <- 0.5 * df$x +
    a_mat[cbind(as.integer(df$species), as.integer(df$trait))] +
    stats::rnorm(nrow(df))
  df$value <- 1L + vapply(ystar, function(z) sum(z > taus), integer(1))

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + phylo_indep(0 + trait | species),
      data = df, phylo_vcv = Cphy, unit = "species",
      family = ordinal_probit()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf("comparator gllvmTMB fit failed to construct: %s",
                 conditionMessage(fit)))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("comparator gllvmTMB fit did not converge with PD Hessian")
  }
  ps <- suppressMessages(
    gllvmTMB::extract_phylo_signal(fit, link_residual = "auto")
  )
  h2_gllvm <- ps$H2[1]

  ## MCMCglmm on trait 1's rows (univariate ordinal PGLMM, the tutorial
  ## route). Short chain: nitt = 33000, burnin = 3000, thin = 30 -> 1000
  ## posterior draws; documented MC error justifies the loose 0.15 band.
  ## MCMCglmm's "ordinal" family adds an implicit probit link variance of 1
  ## on top of the (fixed) units residual, so its liability H2 is
  ## Va / (Va + Vunits + 1); heritability is scale-invariant, so this is
  ## directly comparable with gllvmTMB's Va / (Va + 1).
  df1 <- df[df$trait == "t1", setdiff(names(df), "trait"), drop = FALSE]
  df1$value_f <- factor(df1$value, ordered = TRUE)
  Ainv <- MCMCglmm::inverseA(tree, nodes = "TIPS")$Ainv
  prior <- list(
    R = list(V = 1, fix = 1),
    G = list(G1 = list(V = 1, nu = 1, alpha.mu = 0, alpha.V = 1000))
  )
  m <- tryCatch(
    MCMCglmm::MCMCglmm(
      value_f ~ x, random = ~ species, ginverse = list(species = Ainv),
      data = df1, family = "ordinal", prior = prior,
      nitt = 33000, burnin = 3000, thin = 30, verbose = FALSE
    ),
    error = function(e) e
  )
  if (inherits(m, "error")) {
    skip(sprintf("MCMCglmm comparator fit failed: %s", conditionMessage(m)))
  }
  h2_mcmc <- mean(m$VCV[, "species"] /
                    (m$VCV[, "species"] + m$VCV[, "units"] + 1))
  ## Measured locally (seed 20260817): gllvmTMB 0.357, MCMCglmm 0.436,
  ## abs diff 0.079 against truth 0.5.
  expect_lt(abs(h2_gllvm - h2_mcmc), 0.15)
})
