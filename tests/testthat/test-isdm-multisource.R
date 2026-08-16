## The multi-source integrated contract (Design 120, Model 2): the declared
## route, its refusals, and byte-compatibility of the legacy two-source shape.

.ms_fixture <- function(sources = c(gbif = "count", literature = "count",
                                    survey = "pa"),
                        n_cell = 30L, seed = 7L) {
  set.seed(seed)
  cells <- paste0("c", seq_len(n_cell))
  species <- c("sp1", "sp2")
  x <- as.numeric(scale(runif(n_cell)))
  alpha <- c(-0.1, 0.2); beta <- c(0.4, -0.3)
  out <- do.call(rbind, lapply(names(sources), function(src) {
    d <- expand.grid(cell_id = cells, trait = species,
                     stringsAsFactors = FALSE)
    ci <- match(d$cell_id, cells); si <- match(d$trait, species)
    eta <- alpha[si] + x[ci] * beta[si]
    d$isdm_source <- src
    d$support <- if (sources[[src]] == "count") 1.5 else 0.9
    d$value <- if (sources[[src]] == "count") {
      rpois(nrow(d), d$support * exp(eta))
    } else {
      rbinom(nrow(d), 1, -expm1(-d$support * exp(eta)))
    }
    d
  }))
  out$trait <- factor(out$trait)
  out$cell_id <- factor(out$cell_id)
  out$log_support <- log(out$support)
  out$env <- x[match(as.character(out$cell_id), cells)]
  out
}

test_that("isdm_sources() validates its declaration", {
  fam <- isdm_sources(gbif = poisson(), literature = poisson(),
                      survey = binomial(link = "cloglog"))
  expect_identical(attr(fam, "family_var"), "isdm_source")
  expect_identical(names(fam), c("gbif", "literature", "survey"))

  expect_error(isdm_sources(gbif = poisson()), "at least two")
  expect_error(isdm_sources(poisson(), binomial("cloglog")), "at least two")
  expect_error(isdm_sources(a = poisson(), a = binomial("cloglog")),
               "declared twice")
  ## logit and probit do not share a log-intensity scale; dispersion families
  ## reintroduce the per-trait nuisance ambiguity. All refused at declaration.
  expect_error(isdm_sources(a = poisson(), b = binomial("logit")),
               "not admitted")
  expect_error(isdm_sources(a = poisson(), b = binomial("probit")),
               "not admitted")
  expect_error(isdm_sources(a = poisson(), b = gaussian()), "not admitted")
})

test_that("a declared three-source mixed-law model fits through gllvmTMB()", {
  skip_if_not_installed("TMB")
  dat <- .ms_fixture()
  fam <- isdm_sources(gbif = poisson(), literature = poisson(),
                      survey = binomial(link = "cloglog"))
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    silent = TRUE
  ))
  expect_s3_class(fit, "gllvmTMB")
  expect_identical(fit$opt$convergence, 0L)
})

test_that("the declared contract's refusals hold", {
  skip_if_not_installed("TMB")
  fam <- isdm_sources(gbif = poisson(), literature = poisson(),
                      survey = binomial(link = "cloglog"))
  base_call <- function(d, ...) {
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + trait:env + offset(log_support) +
        latent(0 + trait | cell_id, d = 1),
      data = d, trait = "trait", unit = "cell_id", family = fam,
      silent = TRUE, ...
    ))
  }

  ## an isdm_source value outside the declaration is refused BEFORE admission
  ## is even considered: the mixed-family machinery counts a fourth selector
  ## level against a three-entry family list and aborts there. Refused either
  ## way; the assertion matches where the refusal actually lands.
  d_bad <- .ms_fixture(); d_bad$isdm_source[1] <- "mystery"
  expect_error(base_call(d_bad),
               "must match the number of distinct levels")

  ## a trait missing one declared source is not the declared model
  d_inc <- .ms_fixture()
  d_inc <- d_inc[!(d_inc$trait == "sp1" & d_inc$isdm_source == "survey"), ]
  expect_error(base_call(d_inc),
               class = "gllvmTMB_family_within_trait_unsupported")

  ## the Model 1 refusals generalise: weights and multi-trial rows stay out
  d_ok <- .ms_fixture()
  expect_error(base_call(d_ok, weights = rep(1, nrow(d_ok))),
               class = "gllvmTMB_isdm_weights_unsupported")
})

test_that("an all-count declaration needs no admission and keeps weights", {
  skip_if_not_installed("TMB")
  ## With every declared law Poisson nothing varies within a trait, so no
  ## relaxation is requested and ordinary behaviour -- including `weights` as
  ## likelihood multipliers -- is preserved. The admitted contract must refuse
  ## weights; an all-count fit must NOT, because there is no binomial arm to
  ## make the meaning ambiguous.
  dat <- .ms_fixture(sources = c(gbif = "count", literature = "count"))
  fam <- isdm_sources(gbif = poisson(), literature = poisson())
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = fam,
    weights = rep(1, nrow(dat)), silent = TRUE
  ))
  expect_s3_class(fit, "gllvmTMB")
})

test_that("the legacy two-source shape is the n = 2 case of the same core", {
  d <- data.frame(source = c("gbif", "survey"),
                  isdm_family = c("gbif", "survey_pa"),
                  stringsAsFactors = FALSE)
  tl <- factor(c("sp1", "sp1"))
  lfam <- list(gbif = stats::poisson(),
               survey_pa = stats::binomial(link = "cloglog"))
  attr(lfam, "family_var") <- "isdm_family"

  ## both the retained old name and the generalised predicate admit it
  expect_true(.gllvmTMB_integrated_two_source_contract(
    lfam, d, c(2L, 1L), c(0L, 2L), trait_labels = tl))
  expect_true(.gllvmTMB_integrated_sources_contract(
    lfam, d, c(2L, 1L), c(0L, 2L), trait_labels = tl))

  ## and the declared route admits the same shape under honest declaration
  dd <- data.frame(isdm_source = c("gbif", "survey"),
                   stringsAsFactors = FALSE)
  dfam <- isdm_sources(gbif = stats::poisson(),
                       survey = stats::binomial(link = "cloglog"))
  expect_true(.gllvmTMB_integrated_sources_contract(
    dfam, dd, c(2L, 1L), c(0L, 2L), trait_labels = tl))
})

test_that("legacy two-source fits are byte-compatible through the rewrite", {
  skip_if_not_installed("TMB")
  ## The generalisation must not move a single number for existing users: the
  ## same legacy fit gives the same objective and parameters.
  dat <- .ms_fixture(sources = c(gbif = "count", survey = "pa"))
  dat$source <- ifelse(dat$isdm_source == "gbif", "gbif", "survey")
  dat$isdm_family <- factor(
    ifelse(dat$source == "gbif", "gbif", "survey_pa"),
    levels = c("gbif", "survey_pa"))
  lfam <- list(gbif = poisson(), survey_pa = binomial(link = "cloglog"))
  attr(lfam, "family_var") <- "isdm_family"
  legacy <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat, trait = "trait", unit = "cell_id", family = lfam,
    silent = TRUE))

  dfam <- isdm_sources(gbif = poisson(), survey = binomial(link = "cloglog"))
  dat2 <- dat
  declared <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + trait:env + offset(log_support) +
      latent(0 + trait | cell_id, d = 1),
    data = dat2, trait = "trait", unit = "cell_id", family = dfam,
    silent = TRUE))

  ## same data, same model, two admission routes: identical fits
  expect_equal(declared$opt$objective, legacy$opt$objective, tolerance = 1e-8)
  expect_equal(unname(declared$opt$par), unname(legacy$opt$par),
               tolerance = 1e-6)
})
