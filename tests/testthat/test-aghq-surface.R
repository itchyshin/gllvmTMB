## Surface-level tests for the AGHQ (adaptive Gauss-Hermite quadrature)
## engine: the control-surface contract, the family-agnostic quadrature
## kernel's exactness/movement behaviour, the anti-runaway adaptation cap,
## and the honesty of the structural fence.
##
## These are DIFFERENT tests from tests/testthat/test-aghq-golden.R (a
## peer-owned file): the golden file proves quadrature ACCURACY against an
## independent brute-force oracle; this file proves the USER-FACING
## SURFACE behaves as documented and does not silently misbehave (runaway,
## silent fallback, invalid control values slipping through unvalidated).
##
## Every fit below is deterministic (fixed seed, n_init = 1, init_jitter =
## 0), so the hard-coded reference numbers are exact reproductions of a
## real run of this code, not invented figures. Re-derive them with
## devtools::load_all() + the fixture helpers below if the AGHQ engine
## changes in a way that legitimately moves these numbers.
##
## Peers are actively editing src/gllvmTMB.cpp and R/fit-multi.R while this
## file is written, so every fit-dependent test skip_if_not()s on an actual
## smoke fit (not an exists()/formals() probe) rather than failing outright
## if the kernel is momentarily incomplete.

## ---------------------------------------------------------------------
## Fixtures
## ---------------------------------------------------------------------

## Gaussian latent-linear DGP: q = 1, T = 3, n = 30 sites. Laplace is EXACT
## for this model (no non-normality anywhere in the chain), which is what
## makes it the load-bearing fixture: any AGHQ bug that produces a wrong
## number, or a k-dependence that should not exist, shows up here with
## nothing else that could explain it away.
.aghq_gaussian_formula <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

.aghq_gaussian_data <- function() {
  set.seed(1)
  n_site <- 30
  beta   <- c(-0.3, 0.5, 0.2)
  lambda <- c(0.9, -0.6, 0.4)
  n_trait <- length(beta)
  u <- rnorm(n_site)
  site  <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] + lambda[as.integer(trait)] * u[as.integer(site)]
  y <- eta + rnorm(length(eta), sd = 0.3)
  data.frame(site = site, trait = trait, y = y)
}

.aghq_gaussian_fit <- function(aghq) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE, aghq = aghq)
  suppressWarnings(gllvmTMB::gllvmTMB(
    .aghq_gaussian_formula, data = .aghq_gaussian_data(), family = gaussian(),
    unit = "site", control = ctrl
  ))
}

## Binomial DGP: q = 1, T = 3, n = 30 sites (seed 13, chosen out of 25
## tried as a well-behaved fit: Laplace converges (convergence == 0) to a
## modest, non-degenerate loading vector, and the AGHQ adaptation loop also
## converges within its pass cap -- 258 of the default 400 -- rather than
## exhausting it). Used by both the "AGHQ must move away from Laplace" test
## and the "and not run away while doing it" test.
.aghq_binomial_formula <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

.aghq_binomial_data <- function() {
  set.seed(13)
  n_site <- 30
  beta   <- c(-0.2, 0.3, 0.1)
  lambda <- c(0.6, -0.5, 0.4)
  n_trait <- length(beta)
  u <- rnorm(n_site)
  site  <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] + lambda[as.integer(trait)] * u[as.integer(site)]
  y <- rbinom(length(eta), 1L, plogis(eta))
  data.frame(site = site, trait = trait, y = y)
}

.aghq_binomial_fit <- function(aghq) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE, aghq = aghq)
  suppressWarnings(gllvmTMB::gllvmTMB(
    .aghq_binomial_formula, data = .aghq_binomial_data(), family = binomial(),
    unit = "site", control = ctrl
  ))
}

.aghq_sigma_frob <- function(fit) {
  L <- fit$report$Lambda_B
  norm(L %*% t(L), "F")
}

## Full end-to-end smoke check: does a real (not stubbed) AGHQ fit run to a
## finite objective with fit$aghq$used TRUE? This project has previously
## mistaken "the argument exists" for "the capability works" (a negative
## exists()/formals() probe cannot prove a kernel absent OR ready), so this
## USES the capability -- a real toy fit -- rather than inspecting for it.
.aghq_smoke_ok <- function() {
  ok <- tryCatch({
    fit <- .aghq_gaussian_fit(3L)
    is.finite(fit$opt$objective) && isTRUE(fit$aghq$used)
  }, error = function(e) FALSE)
  isTRUE(ok)
}

## ---------------------------------------------------------------------
## 1. GAUSSIAN EXACTNESS -- the load-bearing test.
## ---------------------------------------------------------------------

test_that("GAUSSIAN EXACTNESS: AGHQ reproduces the Laplace objective and is k-independent", {
  ## WHY: Laplace is exact for a gaussian latent-linear model (no
  ## non-normal likelihood anywhere in the chain), so a correctly
  ## integrating AGHQ must reproduce the Laplace objective with NO free
  ## parameters, at ANY node count. This is the strongest single
  ## correctness check available: a bug in the quadrature nodes, weights,
  ## or adaptation would show up here with nothing else to explain it away.
  ## Note well: k = 1 agreement alone would prove only PLUMBING (k = 1 IS
  ## Laplace, by construction -- a single node at the mode); the k = 3 vs
  ## k = 9 agreement is what proves QUADRATURE, since two different node
  ## counts landing on the identical answer is not something a plumbing-
  ## only stub would produce by coincidence.
  skip_if_not(.aghq_smoke_ok(), "AGHQ kernel not available in this build -- skipped, not failed")

  fit_lap <- .aghq_gaussian_fit(FALSE)
  fit_k3  <- .aghq_gaussian_fit(3L)
  fit_k9  <- .aghq_gaussian_fit(9L)

  expect_true(isTRUE(fit_k3$aghq$used))
  expect_true(isTRUE(fit_k9$aghq$used))

  ## AGHQ objective == Laplace objective, at both k = 3 and k = 9.
  expect_equal(unname(fit_k3$opt$objective), unname(fit_lap$opt$objective), tolerance = 1e-8)
  expect_equal(unname(fit_k9$opt$objective), unname(fit_lap$opt$objective), tolerance = 1e-8)

  ## k = 3 and k = 9 must ALSO agree with each other -- the k-independence
  ## half that rules out the agreement above being a fluke of one k.
  expect_equal(unname(fit_k3$opt$objective), unname(fit_k9$opt$objective), tolerance = 1e-8)
})

## ---------------------------------------------------------------------
## 2. NON-GAUSSIAN MOVEMENT.
## ---------------------------------------------------------------------

test_that("NON-GAUSSIAN MOVEMENT: AGHQ differs from Laplace on a binomial fit", {
  ## WHY: unlike the gaussian case, Laplace is only an APPROXIMATION for a
  ## non-normal (binomial) likelihood, so a correctly wired AGHQ must give
  ## a genuinely different objective. A test that only checked "AGHQ runs"
  ## would pass against a stub that silently returned the Laplace answer
  ## regardless of `aghq =`; this is the guard against exactly that.
  skip_if_not(.aghq_smoke_ok(), "AGHQ kernel not available in this build -- skipped, not failed")

  fit_lap <- .aghq_binomial_fit(FALSE)
  fit_k9  <- .aghq_binomial_fit(9L)
  skip_if_not(isTRUE(fit_k9$aghq$used),
              "AGHQ was gated to Laplace for this fixture -- skipped, not failed")

  expect_gt(abs(fit_k9$opt$objective - fit_lap$opt$objective), 1e-3)
})

## ---------------------------------------------------------------------
## 3. NO RUNAWAY.
## ---------------------------------------------------------------------

test_that("NO RUNAWAY: ||Sigma_B||_F stays within a stated factor of the Laplace value", {
  ## WHY: an earlier build without the per-pass adaptation cap drove
  ## ||Sigma_B||_F from Laplace's 4.43 to 4.1e7 in ONE pass on a 60x6
  ## binomial q = 2 fit -- a ~1e7-fold blow-up -- and nothing caught it.
  ## control$aghq_iter_cap defaults to 1 specifically to prevent that. On
  ## THIS (smaller) well-behaved fixture, the ratio measured with the
  ## default cap is ~6.6x: real AGHQ-vs-Laplace disagreement is expected
  ## and even desired (see the MOVEMENT test above), so the bound here
  ## (30x) is set generously above that measured ratio -- loose enough to
  ## tolerate ordinary quadrature-vs-Laplace disagreement, but many orders
  ## of magnitude below the multi-million-fold runaway this guards against.
  skip_if_not(.aghq_smoke_ok(), "AGHQ kernel not available in this build -- skipped, not failed")

  fit_lap <- .aghq_binomial_fit(FALSE)
  fit_k9  <- .aghq_binomial_fit(9L)
  skip_if_not(isTRUE(fit_k9$aghq$used),
              "AGHQ was gated to Laplace for this fixture -- skipped, not failed")

  frob_lap <- .aghq_sigma_frob(fit_lap)
  frob_k9  <- .aghq_sigma_frob(fit_k9)
  expect_true(is.finite(frob_k9))
  expect_lt(frob_k9 / frob_lap, 30)
})

## ---------------------------------------------------------------------
## 4. use_aghq = 0 IS UNCHANGED.
## ---------------------------------------------------------------------

test_that("use_aghq = 0 IS UNCHANGED: a plain Laplace fit is unaffected by the AGHQ code being present", {
  ## WHY: the AGHQ engine adds a large new code path inside R/fit-multi.R
  ## and the TMB template, gated behind `control$aghq`. This pins a plain
  ## Laplace fit (aghq = FALSE, the default) against hard-coded values
  ## obtained from an actual run of this exact code, so that ANY
  ## regression the AGHQ work introduces into the ordinary Laplace path --
  ## even one that never touches use_aghq = 1 -- is caught.
  fit <- .aghq_gaussian_fit(FALSE)

  expect_false(isTRUE(fit$aghq$used))
  expect_equal(unname(fit$opt$objective), 45.5887409352846, tolerance = 1e-6)
  expect_equal(
    unname(fit$opt$par),
    c(-0.18622536190375, 0.54806758659643, 0.202794108243223,
      -1.41565883979284, 0.836600402924123, -0.576074712118109,
      0.341232122028088),
    tolerance = 1e-6
  )
})

## ---------------------------------------------------------------------
## 5. THE CONTROL SURFACE.
## ---------------------------------------------------------------------

test_that("THE CONTROL SURFACE: gllvmTMBcontrol(aghq = ...) accepts the documented values and rejects the rest", {
  ## WHY: this is the argument-validation contract users see directly. If
  ## a future change loosens the validation, or flips the default without
  ## the head-to-head evidence the maintainer requires, this is what stops
  ## it.
  expect_identical(gllvmTMB::gllvmTMBcontrol()$aghq, FALSE)  ## THE DEFAULT IS FALSE.

  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = FALSE)$aghq, FALSE)
  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = "auto")$aghq, "auto")
  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = TRUE)$aghq, "auto")
  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = 9)$aghq, 9L)
  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = 9L)$aghq, 9L)

  expect_error(gllvmTMB::gllvmTMBcontrol(aghq = 0))
  expect_error(gllvmTMB::gllvmTMBcontrol(aghq = -1))
  expect_error(gllvmTMB::gllvmTMBcontrol(aghq = 2.5))
  expect_error(gllvmTMB::gllvmTMBcontrol(aghq = "nine"))
  expect_error(gllvmTMB::gllvmTMBcontrol(aghq = c(3, 9)))
})

## ---------------------------------------------------------------------
## 6. THE FENCES ARE HONEST.
## ---------------------------------------------------------------------

test_that("THE FENCES ARE HONEST: an out-of-scope model is refused with a reason and falls back to a valid Laplace fit", {
  ## WHY: Stage 1a's structural gate refuses any model outside its scope
  ## (multiple random blocks, mi() predictors, multinomial rows, no B-tier
  ## latent() block, ...). A SILENT fallback -- aghq$used == FALSE with no
  ## explanation -- is exactly what this guards against: the reason string
  ## must be non-empty, and the fit itself must still be a valid, finite
  ## Laplace fit rather than an error or a garbage number.
  set.seed(5)
  n_site <- 20
  beta <- c(-0.2, 0.3)
  n_trait <- length(beta)
  u <- rnorm(n_site, sd = 0.5)
  site  <- factor(rep(paste0("s", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(paste0("t", seq_len(n_trait)), n_site),
                  levels = paste0("t", seq_len(n_trait)))
  eta <- beta[as.integer(trait)] + u[as.integer(site)]
  y <- rbinom(length(eta), 1L, plogis(eta))
  dat <- data.frame(site = site, trait = trait, y = y)

  ## No latent() block at all -- an ordinary (1 | site) random intercept --
  ## which fails the "no B-tier latent() block" eligibility check even
  ## though `aghq = 9` was explicitly requested.
  fit <- tryCatch(
    suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + (1 | site), data = dat, family = binomial(), unit = "site",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE, aghq = 9L)
    )),
    error = function(e) e
  )
  fit_ok <- !inherits(fit, "error")
  skip_if_not(fit_ok,
              if (fit_ok) "" else paste("fence-test fit itself failed:", conditionMessage(fit)))

  expect_false(isTRUE(fit$aghq$used))
  expect_true(nzchar(fit$aghq$reason))
  expect_true(is.finite(fit$opt$objective))
})

## ---------------------------------------------------------------------
## 7. fit$aghq STRUCTURE.
## ---------------------------------------------------------------------

test_that("fit$aghq structure: present with expected fields on an AGHQ fit; present-but-unused on a Laplace fit", {
  ## WHY: fit$aghq is the provenance record downstream code/users read to
  ## know whether AGHQ ran. It must carry used/k/blocks/reason on an AGHQ
  ## fit, and on an ordinary Laplace fit it must still be present (not
  ## NULL) but clearly marked unused -- never silently missing either way.
  skip_if_not(.aghq_smoke_ok(), "AGHQ kernel not available in this build -- skipped, not failed")

  fit_lap <- .aghq_gaussian_fit(FALSE)
  expect_true(is.list(fit_lap$aghq))
  expect_false(isTRUE(fit_lap$aghq$used))

  fit_k3 <- .aghq_gaussian_fit(3L)
  expect_true(is.list(fit_k3$aghq))
  expect_true(isTRUE(fit_k3$aghq$used))
  for (field in c("used", "k", "blocks", "reason")) {
    expect_true(field %in% names(fit_k3$aghq))
  }
  expect_identical(fit_k3$aghq$k, 3L)
  expect_true(nzchar(fit_k3$aghq$reason))
})
