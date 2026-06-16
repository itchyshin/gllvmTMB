## Tests for the exported trait_families() accessor and the per-trait
## family column added to print.gllvmTMB_multi().
##
## trait_families() reads ONLY fields already stored on the fit
## (family_selector + the per-row family/trait ids), so the accessor
## logic is tested against a lightweight mock object -- no fitting.
## The print augmentation is checked on a real mixed-family fit gated
## behind skip_if_not_heavy().

## Build a minimal gllvmTMB_multi-shaped list carrying just the fields
## trait_families() / .per_trait_family() read. `fids` is the per-trait
## runtime family id (family_to_id() ids), expanded to one row per trait
## here (one observation per trait keeps the mapping unambiguous).
make_multi_mock <- function(trait_levels, fids, family_selector = NULL,
                            family = NULL) {
  Tn <- length(trait_levels)
  stopifnot(length(fids) == Tn)
  dat <- data.frame(
    trait = factor(trait_levels, levels = trait_levels),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      n_traits = Tn,
      trait_col = "trait",
      data = dat,
      family = family,
      family_selector = family_selector,
      tmb_data = list(
        family_id_vec = as.integer(fids),
        trait_id = seq_len(Tn) - 1L # 0-based, matches .per_trait_link()
      )
    ),
    class = "gllvmTMB_multi"
  )
}

# ---- mixed-family accessor (no fit) ---------------------------------

test_that("trait_families() returns the per-trait named family vector (mixed)", {
  ## 8 traits across 5 families (2 gaussian, 2 binomial, 2 poisson,
  ## 1 Gamma, 1 nbinom2): mirrors the 5-family fixture, where n_traits
  ## (8) exceeds the number of family-selector levels (5).
  trait_levels <- paste0("trait_", 1:8)
  fids <- c(0L, 0L, 1L, 1L, 2L, 2L, 4L, 5L) # gaussian/binomial/poisson/Gamma/nbinom2
  fit <- make_multi_mock(
    trait_levels = trait_levels,
    fids = fids,
    ## A present family_selector marks the fit as mixed-family; the
    ## per-trait names are resolved from the per-row family ids.
    family_selector = list(family_var = "family")
  )

  fam <- trait_families(fit)
  expect_type(fam, "character")
  expect_length(fam, 8L)
  expect_named(fam, trait_levels)
  expect_equal(
    unname(fam),
    c("gaussian", "gaussian", "binomial", "binomial",
      "poisson", "poisson", "Gamma", "nbinom2")
  )
})

test_that("trait_families() maps every supported family id to its canonical name", {
  ## One trait per family-id, covering the full family_to_id() range.
  ids <- 0:15
  trait_levels <- paste0("t", ids)
  fit <- make_multi_mock(
    trait_levels = trait_levels,
    fids = ids,
    family_selector = list(family_var = "family")
  )
  expect_equal(
    unname(trait_families(fit)),
    c("gaussian", "binomial", "poisson", "lognormal", "Gamma",
      "nbinom2", "tweedie", "Beta", "betabinomial", "student",
      "truncated_poisson", "truncated_nbinom2", "delta_lognormal",
      "delta_gamma", "ordinal_probit", "nbinom1")
  )
})

# ---- single-family fallback (no fit) --------------------------------

test_that("trait_families() falls back to the single retained family (uniform)", {
  ## No family_selector -> single-family fit; every trait shares
  ## object$family$family.
  trait_levels <- c("trait_1", "trait_2", "trait_3")
  fit <- make_multi_mock(
    trait_levels = trait_levels,
    fids = c(2L, 2L, 2L),
    family_selector = NULL,
    family = poisson()
  )
  fam <- trait_families(fit)
  expect_named(fam, trait_levels)
  expect_equal(unname(fam), rep("poisson", 3L))
})

test_that("trait_families() is dispatched via the exported S3 generic", {
  expect_true(is.function(trait_families))
  expect_true("trait_families" %in% getNamespaceExports("gllvmTMB"))
  ## A non-multi object falls through to the default (no method) and errors.
  expect_error(trait_families(structure(list(), class = "not_a_fit")))
})

# ---- print() shows the per-trait family (real fit, heavy) -----------

test_that("print.gllvmTMB_multi shows per-trait family for a mixed-family fit", {
  skip_if_not_heavy()
  skip_on_cran()
  fit <- gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)
  out <- paste(capture.output(print(fit)), collapse = "\n")

  ## The mixed-family annotation now reports family + link per trait.
  expect_match(out, "Per-trait family and link")
  ## Each of the 3 fixture families appears in the printed table.
  expect_match(out, "gaussian")
  expect_match(out, "binomial")
  expect_match(out, "poisson")

  ## And the accessor agrees with the fixture's known per-trait families.
  fam <- trait_families(fit)
  expect_equal(
    unname(fam),
    c("gaussian", "binomial", "poisson")
  )
})
