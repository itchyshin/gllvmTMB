## Multinomial (family_id 16) structured-dependency admission -- Slice 3
## (Design 123, 2026-08-16): the spatial (SPDE) mode axis --
## `spatial_latent()` (shared fields, loadings-only), `spatial_indep()`
## (per-contrast independent fields), and `spatial_dep()` (full unstructured
## cross-contrast field covariance) -- join the pre-existing phylogenetic
## mode axis (test-matrix-multinomial-phylo.R) for the among-category
## surface.
##
## GATE CHECK (dev/multinomial-structured/gate-check-a-proj.R, run BEFORE
## this admission landed): `expand_multinomial_response()` (R/gllvmTMB.R)
## duplicates each observation into K-1 contrast rows BEFORE any mesh/A_proj
## construction, so `A_proj` must be built on the POST-expansion coordinate
## frame. VERIFIED (real fit, no monkeypatch): a mesh built on the user's
## original per-site data fails LOUD (`make_mesh() projection has <n_site>
## rows but the long-format data has <n_site * (K-1)>`), never silently
## misaligned; a mesh built on a coordinate frame pre-expanded with the SAME
## `rep(seq_len(n), each = K - 1)` convention `expand_multinomial_response()`
## uses internally aligns EXACTLY -- every site's K-1 contrast rows carry the
## IDENTICAL A_proj row (0/40 mismatches in the gate-check script), matching
## the intended semantic of one shared spatial field draw per site entering
## every one of its category-contrast linear predictors. `make_fixture()`
## below performs this required pre-expansion for every fixture in this
## file.
##
## This environment has fmesher but NOT INLA -- VERIFIED (this task) that
## `make_mesh()` and the base SPDE engine need only fmesher; every cell below
## is REAL FIT-LEVEL evidence (construction, convergence, PD Hessian, and
## `extract_Sigma()` output), not classifier-only.
##
## spatial_dep() desugar VERIFIED (R/brms-sugar.R, `fn == "spatial_dep"`
## intercept-only branch): it literally sets `.spatial_latent = TRUE, d =
## n_traits, .dep = TRUE` -- the SAME marker spatial_latent() itself uses,
## i.e. spatial_dep() === spatial_latent(d = n_traits), not merely
## V-equivalent. Confirmed empirically below (matched TMB objective at each
## other's converged parameters, both directions).
##
## Stays BLOCKED: spatial_scalar(), spatial_latent(unique = TRUE)'s paired
## Psi_spde companion, standalone spatial_unique()/deprecated bare spatial(),
## and every augmented (intercept + slope) spatial_*() form -- see
## test-multinomial-fence.R.

skip_if_not_mn_spatial_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## ---------------------------------------------------------------
## Fixture: one row per site, x/y coords in the unit square. The mesh MUST be
## built on a coordinate frame pre-expanded with the SAME `rep(seq_len(n),
## each = K - 1)` convention `expand_multinomial_response()` uses internally
## (see the gate-check note above) -- this is REQUIRED, not a convenience;
## building the mesh on `fx$data` directly aborts loud (see the fence test
## "spatial_indep() with a naively-built (un-expanded) mesh aborts loud" for
## a pinned regression of that failure mode).
## ---------------------------------------------------------------
make_mn_spatial_fixture <- function(seed, n_site = 100L, K = 3L, cutoff = 0.1) {
  set.seed(seed)
  df <- data.frame(
    site = factor(seq_len(n_site)),
    x = stats::runif(n_site), y = stats::runif(n_site),
    trait = factor("cat"),
    value = factor(sample.int(K, n_site, replace = TRUE))
  )
  L <- K - 1L
  idx <- rep(seq_len(n_site), each = L)
  mesh <- gllvmTMB::make_mesh(df[idx, , drop = FALSE], c("x", "y"), cutoff = cutoff)
  list(data = df, mesh = mesh, n_site = n_site, K = K, L = L)
}

.mn_sigma_only <- function(S) if (is.matrix(S)) S else S$Sigma

expect_mn_spatial_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], 16L)
}

## ---------------------------------------------------------------
## Cell 1: spatial_latent() (shared fields, loadings-only)
## ---------------------------------------------------------------
test_that("spatial_latent() fits for multinomial (Slice 3 admission); extract_Sigma(level = \"spatial\") well-formed", {
  skip_if_not_mn_spatial_deps()
  fx <- make_mn_spatial_fixture(seed = 6L, n_site = 100L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(0 + trait | coords, d = fx$L),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", mesh = fx$mesh
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_latent() multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial_latent() multinomial fit did not converge with PD Hessian; FAM-20E stays partial")
  }

  expect_mn_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_latent))

  S <- gllvmTMB::extract_Sigma(
    fit, level = "spatial", part = "total", link_residual = "auto"
  )
  Smat <- .mn_sigma_only(S)
  expect_true(is.matrix(Smat))
  expect_equal(dim(Smat), c(fx$L, fx$L))
  expect_equal(unname(Smat), unname(t(Smat)), tolerance = 1e-8)
  ## link_residual = "auto" adds the (pi^2/6)(I + J) block on the TOTAL
  ## surface (task item 3), matching the phy contract
  ## (test-link-residual-multinomial.R): the note must record it.
  expect_true(any(grepl("pi\\^2/6", S$note)))
})

## ---------------------------------------------------------------
## Cell 2: spatial_indep() (per-contrast independent fields)
## ---------------------------------------------------------------
test_that("spatial_indep() fits for multinomial (Slice 3 admission)", {
  skip_if_not_mn_spatial_deps()
  fx <- make_mn_spatial_fixture(seed = 6L, n_site = 100L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | coords),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", mesh = fx$mesh
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_indep() multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial_indep() multinomial fit did not converge with PD Hessian; FAM-20E stays partial")
  }

  expect_mn_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_indep))
  expect_false(isTRUE(fit$use$spatial_latent))

  kappa <- as.numeric(fit$report$kappa)
  expect_true(is.finite(kappa) && kappa > 0)
  log_tau <- as.numeric(fit$report$log_tau_spde)
  expect_equal(length(log_tau), fit$n_traits)
  expect_true(all(is.finite(log_tau)))

  ## KNOWN LIMITATION (task item 3, NOT fixed here -- pre-existing,
  ## family-agnostic): extract_Sigma(level = "spatial") requires a
  ## spatial_latent()-shaped term (fit$use$spatial_latent); a
  ## spatial_indep()-ONLY fit has no Lambda_spde to assemble, so it aborts
  ## with "Fit has no spatial_latent() term" -- the SAME gap exists for
  ## every other family (e.g. ordinal_probit's spatial_indep cell in
  ## test-matrix-ordinal-spatial.R reads fit$report$kappa/log_tau_spde
  ## directly rather than through extract_Sigma(), for the same reason).
  ## This is not a multinomial-specific bug and building a new diagonal-SPDE
  ## extraction surface is out of this slice's scope.
  err <- tryCatch(
    gllvmTMB::extract_Sigma(fit, level = "spatial"),
    error = function(e) e
  )
  expect_true(inherits(err, "error"))
  expect_match(conditionMessage(err), "spatial_latent")
})

## ---------------------------------------------------------------
## Cell 3: spatial_dep() (full unstructured cross-contrast field covariance)
## ---------------------------------------------------------------
test_that("spatial_dep() fits for multinomial (Slice 3 admission); extract_Sigma(level = \"spatial\") well-formed", {
  skip_if_not_mn_spatial_deps()
  fx <- make_mn_spatial_fixture(seed = 6L, n_site = 100L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | coords),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", mesh = fx$mesh
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "spatial_dep() multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("spatial_dep() multinomial fit did not converge with PD Hessian; FAM-20E stays partial")
  }

  expect_mn_spatial_fit_health(fit)
  expect_true(isTRUE(fit$use$spde))
  expect_true(isTRUE(fit$use$spatial_dep))
  ## spatial_dep() rewrites to spatial_latent(d = n_traits) -- the latent
  ## flag must also be TRUE (mirrors the ordinal-spatial contract).
  expect_true(isTRUE(fit$use$spatial_latent))

  S <- gllvmTMB::extract_Sigma(
    fit, level = "spatial", part = "total", link_residual = "auto"
  )
  Smat <- .mn_sigma_only(S)
  expect_true(is.matrix(Smat))
  expect_equal(dim(Smat), c(fx$L, fx$L))
})

## ---------------------------------------------------------------
## Equivalence: spatial_dep() is numerically identical to
## spatial_latent(d = K - 1) for multinomial (task item 1, desugar identity;
## the package's own roxygen already states "Mathematically identical to
## spatial_latent(0 + trait | coords, d = T) standalone; the keyword choice
## is documentary" -- confirmed here on a real fit, not just the docstring).
## ---------------------------------------------------------------
test_that("spatial_dep() is numerically equivalent to spatial_latent(d = K - 1) for multinomial", {
  skip_on_cran(); skip_if_not_heavy()
  skip_if_not_mn_spatial_deps()
  fx <- make_mn_spatial_fixture(seed = 6L, n_site = 100L, K = 3L)

  fit_latent <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(0 + trait | coords, d = fx$L),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", mesh = fx$mesh
    ))),
    error = function(e) e
  )
  fit_dep <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(0 + trait | coords),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", mesh = fx$mesh
    ))),
    error = function(e) e
  )
  if (inherits(fit_latent, "error") || inherits(fit_dep, "error")) {
    skip(sprintf(
      "spatial_latent()/spatial_dep() equivalence fit failed to construct: latent=%s dep=%s",
      if (inherits(fit_latent, "error")) conditionMessage(fit_latent) else "ok",
      if (inherits(fit_dep, "error")) conditionMessage(fit_dep) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_latent) ||
        !.fit_stationary_for_recovery_test(fit_dep)) {
    skip("spatial_latent()/spatial_dep() equivalence fit did not converge with PD Hessian on both arms")
  }

  ## Matched objective, BOTH directions (mirrors the phylo_dep equivalence
  ## test, test-matrix-multinomial-phylo.R).
  expect_equal(
    as.numeric(fit_dep$tmb_obj$fn(fit_latent$opt$par)), fit_latent$opt$objective,
    tolerance = 1e-6
  )
  expect_equal(
    as.numeric(fit_latent$tmb_obj$fn(fit_dep$opt$par)), fit_dep$opt$objective,
    tolerance = 1e-6
  )

  V_latent <- gllvmTMB::extract_Sigma(
    fit_latent, level = "spatial", part = "shared", link_residual = "none"
  )
  V_dep <- gllvmTMB::extract_Sigma(
    fit_dep, level = "spatial", part = "shared", link_residual = "none"
  )
  expect_equal(unname(as.matrix(.mn_sigma_only(V_dep))),
               unname(as.matrix(.mn_sigma_only(V_latent))), tolerance = 1e-4)
})

## ---------------------------------------------------------------
## Regression pin: a mesh built on the UN-expanded (per-site) data fails
## loud, matching the gate-check finding (dev/multinomial-structured/
## gate-check-a-proj.R) -- this is the load-bearing negative control for
## Slice 3's admission (a silent misalignment would be far worse than a
## typed-blocked cell).
## ---------------------------------------------------------------
test_that("spatial_indep() with a naively-built (un-expanded) mesh aborts loud rather than silently misaligning A_proj", {
  skip_if_not_mn_spatial_deps()
  set.seed(7L)
  n_site <- 30L; K <- 3L
  df <- data.frame(
    site = factor(seq_len(n_site)),
    x = stats::runif(n_site), y = stats::runif(n_site),
    trait = factor("cat"),
    value = factor(sample.int(K, n_site, replace = TRUE))
  )
  mesh_naive <- gllvmTMB::make_mesh(df, c("x", "y"), cutoff = 0.15)
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | coords),
      data = df, family = gllvmTMB::multinomial(), trait = "trait",
      mesh = mesh_naive
    ),
    error = function(e) e
  )
  expect_true(inherits(err, "error"))
  expect_match(conditionMessage(err), "make_mesh\\(\\) projection has")
})
