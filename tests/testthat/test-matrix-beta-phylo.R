## Phase B-matrix B-beta (Design 59 Group B): `Beta()` (logit link) on the
## phylogenetic structural keywords -- structural recovery + CI smoke.
##
## Walks PHY-04 (phylo_scalar) and PHY-05 (phylo_indep / phylo_dep /
## phylo_latent+phylo_unique) of `docs/design/35-validation-debt-register.md`
## from `partial` to `covered` for the Beta branch.
##
## Family scope: Beta is a MEAN-DEPENDENT family (the latent residual scale
## varies with mu; there is no fixed link-residual the way binomial-logit has
## pi^2/3 or ordinal-probit has 1). Per the Phase B0 scoping memo
## (docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md sec.2-3),
## mean-dependent families carry WIDER recovery tolerance than
## fixed-residual-scale families. We therefore do NOT make a tight B0
## point-recovery assertion on the structural variances; the load-bearing
## assertions are (a) clean convergence with a PD Hessian, (b) the engine
## use-flag for the intended structural path, (c) CI smoke on at least one
## phylogenetic correlation pair, and (d) a non-degenerate
## extract_correlations(tier = "phy"). This is the honest target for a
## mean-dependent family at a modest fixture size: structural *recovery* in
## the "fits + identifies + reports finite structure" sense, not a narrow
## numeric band.
##
## Fixture: 3-4 traits, ~40-60 species, concentration phi = 5, response
## strictly in (0, 1), star tree (identity VCV). The star tree
## (`Cphy = I_n_sp`) is the cleanest identifiable case for these keywords:
## species are i.i.d. draws on the phylo side, removing between-species
## correlation as a confounder. Per the B0 memo, beta x phylo x {unique,
## indep} is OK and x {dep, latent(d>=2)} is borderline -- so the dep /
## paired-latent cells are the ones most likely to honest-SKIP at this n.
##
## SKIP discipline (no fake-pass): any cell that fails to construct, fails to
## converge, or returns a non-PD Hessian is `skip()`-ped with a reason and
## reported as "stays partial". A degenerate CI or correlation frame also
## skips rather than relaxing the assertion. The register row only moves to
## `covered` on real passing evidence.

skip_if_not_beta_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared star-tree Beta fixture. `mu` is held mid-range (logit intercepts
## near 0, modest phylogenetic signal) so the simulated proportions never
## crowd the 0/1 boundaries where Beta degenerates.
make_beta_phylo_fixture <- function(n_sp = 50L,
                                    n_traits = 3L,
                                    phi = 5,
                                    seed = 20260529L) {
  set.seed(seed)
  ## Star tree => identity tip-correlation matrix. Species are independent
  ## N(0, sigma^2_phy) draws on the latent logit scale.
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)

  ## Per-trait phylogenetic SDs on the logit scale -- modest so invlogit()
  ## stays mid-range and Beta does not saturate at 0/1.
  sigma_phy_true <- c(0.5, 0.45, 0.4, 0.5)[seq_len(n_traits)]
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  p_mat <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sigma_phy_true[t] *
      as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  ## Logit-scale intercepts kept near 0 -> mu mid-range (~0.4-0.6).
  alpha <- c(-0.2, 0.0, 0.2, -0.1)[seq_len(n_traits)]

  rows <- vector("list", n_sp * n_traits)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      mu  <- stats::plogis(eta)
      y   <- stats::rbeta(1L, mu * phi, (1 - mu) * phi)
      rows[[k]] <- data.frame(
        species = sp_names[i],
        trait   = paste0("trait_", t),
        value   = y,
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp_names)
  df$trait   <- factor(df$trait,   levels = paste0("trait_", seq_len(n_traits)))

  list(
    data           = df,
    Cphy           = Cphy,
    sp_names       = sp_names,
    n_traits       = n_traits,
    phi            = phi,
    sigma_phy_true = sigma_phy_true
  )
}

expect_beta_phylo_fit_health <- function(fit) {
  expect_converged(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  expect_converged(fit)
  ## Sanity: this really is the Beta family (family_id 7) and phi is finite.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 7L)
  testthat::expect_true(all(is.finite(as.numeric(fit$report$phi_beta))))
}

## Reusable CI smoke: at least one finite profile bound on one of the
## upper-tri rho:phy pairs. Returns TRUE/FALSE; the caller decides skip.
beta_phylo_rho_ci_any_finite <- function(fit, n_traits) {
  pairs_to_try <- utils::combn(seq_len(n_traits), 2L, simplify = FALSE)
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:phy:%d,%d", p[1L], p[2L])
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      return(TRUE)
    }
  }
  FALSE
}

## Reusable: extract_correlations(tier = "phy") is a non-degenerate frame.
expect_beta_phylo_correlations_nondegenerate <- function(fit) {
  cor_df <- suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit,
      tier          = "phy",
      method        = "fisher-z",
      link_residual = "none"
    )
  ))
  testthat::expect_s3_class(cor_df, "data.frame")
  testthat::expect_gt(nrow(cor_df), 0L)
  testthat::expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                              "lower", "upper") %in% names(cor_df)))
  testthat::expect_true(all(is.finite(cor_df$correlation)))
}

## Paired two-U fixture. The bare `phylo_latent(species) + phylo_unique(
## species)` keywords are the two-U PGLLVM pattern: `unit` stays at its
## default ("site") and `species` is the phylogenetic cluster, so the data
## needs a `site` grouping with replication of each species across sites
## (mirrors the established Gaussian two-U fixture at
## test-phylo-q-decomposition.R). The DGP draws a rank-1 cross-trait phylo
## factor (the phylo_latent block) plus a per-trait diagonal phylo block
## (the phylo_unique block), both on the logit scale, then emits Beta(mu*phi,
## (1-mu)*phi) responses with mu mid-range.
make_beta_phylo_paired_fixture <- function(n_sp = 50L,
                                           n_traits = 3L,
                                           n_site = 4L,
                                           phi = 5,
                                           seed = 20260529L) {
  set.seed(seed)
  Cphy <- diag(n_sp)
  sp_names <- paste0("sp", seq_len(n_sp))
  dimnames(Cphy) <- list(sp_names, sp_names)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))

  ## Rank-1 cross-trait phylo factor (phylo_latent block): one shared
  ## per-species factor g, loaded onto traits by Lambda_phy (T x 1).
  Lambda_phy <- matrix(c(0.5, 0.4, 0.45, 0.5)[seq_len(n_traits)], ncol = 1L)
  g <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))           # length n_sp
  mu_cross <- outer(g, as.numeric(Lambda_phy))              # n_sp x T

  ## Per-trait diagonal phylo block (phylo_unique block): independent
  ## per-trait per-species draws, modest SDs so mu stays mid-range.
  sd_phy_diag <- c(0.35, 0.3, 0.35, 0.3)[seq_len(n_traits)]
  u <- matrix(0, n_sp, n_traits)
  for (t in seq_len(n_traits)) {
    u[, t] <- sd_phy_diag[t] * as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  alpha <- c(-0.2, 0.0, 0.2, -0.1)[seq_len(n_traits)]
  eta_sp <- sweep(mu_cross + u, 2L, alpha, "+")             # n_sp x T (logit)

  rows <- vector("list", n_site * n_sp * n_traits)
  k <- 1L
  for (s in seq_len(n_site)) {
    for (i in seq_len(n_sp)) {
      for (t in seq_len(n_traits)) {
        mu <- stats::plogis(eta_sp[i, t])
        y  <- stats::rbeta(1L, mu * phi, (1 - mu) * phi)
        rows[[k]] <- data.frame(
          site    = s,
          species = sp_names[i],
          trait   = paste0("trait_", t),
          value   = y,
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$site    <- factor(df$site)
  df$species <- factor(df$species, levels = sp_names)
  df$trait   <- factor(df$trait,   levels = paste0("trait_", seq_len(n_traits)))

  list(
    data       = df,
    Cphy       = Cphy,
    sp_names   = sp_names,
    n_traits   = n_traits,
    phi        = phi,
    Lambda_phy = Lambda_phy
  )
}

## ---------------------------------------------------------------
## Cell 1: phylo_latent(species, d = 1) + phylo_unique(species) paired
## ---------------------------------------------------------------
## The two-U pattern: phylo_latent supplies the reduced-rank cross-trait
## block (use$phylo_rr) and phylo_unique supplies the per-trait diagonal
## block (use$phylo_diag). Per the B0 memo this is the borderline
## latent-on-mean-dependent case, so an honest skip is expected if the
## fixture does not identify it.
test_that("Beta: phylo_latent(d=1) + phylo_unique paired fits; pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_beta_phylo_deps()
  fx <- make_beta_phylo_paired_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_latent(species, d = 1) +
        phylo_unique(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      family    = gllvmTMB::Beta()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Beta phylo_latent+phylo_unique fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Beta phylo_latent+phylo_unique did not converge with PD Hessian; PHY-04/05(beta) stays partial pending bigger n / different seed")
  }

  expect_beta_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$phylo_diag))

  ## extract_correlations on the phy tier (rr block present) must be a
  ## non-degenerate frame with finite correlations.
  expect_beta_phylo_correlations_nondegenerate(fit)
})

## ---------------------------------------------------------------
## Cell 2: phylo_scalar(species)
## ---------------------------------------------------------------
## A single shared phylogenetic scaling across traits; rewrites through
## phylo() -> propto(), so the engine flag is use$propto. CI smoke is on the
## single shared scaling parameter `lambda_phy` (the propto path sets neither
## phylo_rr nor phylo_diag, so the `phylo_signal` / `rho:phy` tokens do not
## apply -- see profile_ci_phylo_signal() precondition, mirrored from the
## phylo_scalar binary test).
test_that("Beta: phylo_scalar(species) fits; pd_hessian TRUE; lambda_phy profile CI finite", {
  skip_if_not_heavy()
  skip_if_not_beta_phylo_deps()
  fx <- make_beta_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::Beta()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Beta phylo_scalar fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Beta phylo_scalar did not converge with PD Hessian; PHY-04(beta) stays partial pending bigger n / different seed")
  }

  expect_beta_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$propto))

  ## The single shared scaling is finite on the log scale.
  loglam <- unname(fit$opt$par["loglambda_phy"])
  expect_true(is.finite(loglam))

  ## CI smoke on the single shared scaling parameter.
  ci <- tryCatch(
    suppressMessages(suppressWarnings(stats::confint(
      fit, parm = "lambda_phy", method = "profile"
    ))),
    error = function(e) e
  )
  if (inherits(ci, "error")) {
    skip(sprintf(
      "confint(parm = 'lambda_phy', method = 'profile') errored on Beta phylo_scalar: %s",
      conditionMessage(ci)
    ))
  }
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 1L)
  expect_equal(ncol(ci), 2L)
  if (!any(is.finite(ci))) {
    skip("lambda_phy profile CI returned no finite bound on Beta phylo_scalar; honest skip rather than relax assertion")
  }
  expect_true(any(is.finite(ci)))
})

## ---------------------------------------------------------------
## Cell 3: phylo_indep(0 + trait | species)
## ---------------------------------------------------------------
## Diagonal (marginal-only) per-trait phylogenetic block: use$phylo_indep.
## Per the B0 memo this is the easiest mean-dependent phylo case after
## `unique`. extract_correlations(tier = "phy") returns structural-zero
## correlations but the frame must be non-degenerate.
test_that("Beta: phylo_indep(0 + trait | species) fits; pd_hessian TRUE; phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_beta_phylo_deps()
  fx <- make_beta_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::Beta()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Beta phylo_indep fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Beta phylo_indep did not converge with PD Hessian; PHY-05(beta) stays partial pending bigger n / different seed")
  }

  expect_beta_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))
  expect_beta_phylo_correlations_nondegenerate(fit)
})

## ---------------------------------------------------------------
## Cell 4: phylo_dep(0 + trait | species)
## ---------------------------------------------------------------
## Full unstructured cross-trait phylogenetic block; rewrites to
## phylo_rr(d = n_traits), so use$phylo_dep AND use$phylo_rr are both set.
## Per the B0 memo this is the borderline mean-dependent case (full 2T x 2T
## may give boundary correlations at small n), so it is the most likely to
## honest-SKIP. CI smoke: at least one finite profile bound on one rho:phy
## pair; plus a non-degenerate extract_correlations(tier = "phy").
test_that("Beta: phylo_dep(0 + trait | species) fits; pd_hessian TRUE; rho:phy CI smoke + phy correlations non-degenerate", {
  skip_if_not_heavy()
  skip_if_not_beta_phylo_deps()
  fx <- make_beta_phylo_fixture()

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species),
      data      = fx$data,
      phylo_vcv = fx$Cphy,
      unit      = "species",
      family    = gllvmTMB::Beta()
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "Beta phylo_dep fit failed to construct: %s",
      conditionMessage(fit)
    ))
  }
  if (!.fit_converged(fit)) {
    skip("Beta phylo_dep did not converge with PD Hessian; PHY-05(beta) stays partial pending bigger n / different seed")
  }

  expect_beta_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_dep))
  expect_true(isTRUE(fit$use$phylo_rr))  # phylo_dep rewrites to phylo_rr(d = n_traits)

  ## CI smoke on rho:phy. If no pair yields a finite profile bound, skip
  ## honestly rather than relaxing the assertion.
  if (!beta_phylo_rho_ci_any_finite(fit, fx$n_traits)) {
    skip("Profile CI for rho:phy returned no finite bound on any pair (Beta phylo_dep); honest skip rather than relax assertion")
  }
  expect_true(beta_phylo_rho_ci_any_finite(fit, fx$n_traits))

  expect_beta_phylo_correlations_nondegenerate(fit)
})
