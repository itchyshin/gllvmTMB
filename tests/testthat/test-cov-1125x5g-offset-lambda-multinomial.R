## Coverage (cursor-cloud-1125x5g): offset prep, lambda_constraint names, multinomial classify.

test_that("gll_prepare_offset() returns zeros when offset is absent", {
  df <- data.frame(y = 1:3)
  fam <- rep(2L, 3L)
  out <- gllvmTMB:::gll_prepare_offset(
    NULL, df, environment(), fam, rep(0L, 3L), list(), NULL
  )
  expect_equal(out, c(0, 0, 0))
})

test_that("gll_prepare_offset() evaluates numeric vectors and recycles scalars", {
  df <- data.frame(effort = c(1, 2, 3))
  expr <- quote(log(effort))
  fam <- rep(2L, 3L)
  off <- gllvmTMB:::gll_prepare_offset(
    expr, df, environment(), fam, rep(0L, 3L),
    list(structure(list(family = "poisson"), class = "family")),
    factor(c("a", "b", "c"))
  )
  expect_equal(off, log(1:3))
  scalar <- gllvmTMB:::gll_prepare_offset(
    quote(2), df, environment(), fam, rep(0L, 3L),
    list(structure(list(family = "poisson"), class = "family")),
    NULL
  )
  expect_equal(scalar, rep(2, 3L))
})

test_that("gll_prepare_offset() refuses non-numeric and wrong-length offsets", {
  df <- data.frame(x = 1:2)
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(letters[1]), df, environment(), c(2L, 2L), rep(0L, 2L),
      list(structure(list(family = "poisson"), class = "family")), NULL
    ),
    "numeric"
  )
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(c(1, 2, 3)), df, environment(), c(2L, 2L), rep(0L, 2L),
      list(structure(list(family = "poisson"), class = "family")), NULL
    ),
    "length"
  )
})

test_that("gll_prepare_offset() blocks nonzero offset on gaussian rows", {
  df <- data.frame(y = 0:1)
  fam_ids <- c(0L, 0L)
  fams <- list(
    structure(list(family = "gaussian"), class = "family"),
    structure(list(family = "gaussian"), class = "family")
  )
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      quote(c(0.5, 0)), df, environment(), fam_ids, rep(0L, 2L), fams,
      factor(c("ga", "gb"))
    ),
    "offsets are supported"
  )
})

test_that(".gllvmTMB_offset_vec() defaults missing stored offsets to zero", {
  fit <- list(tmb_data = list(X_fix = matrix(0, 4, 1)))
  expect_equal(gllvmTMB:::.gllvmTMB_offset_vec(fit), rep(0, 4L))
  fit2 <- list(tmb_data = list(X_fix = matrix(0, 2, 1), offset_vec = c(1, 2)))
  expect_equal(gllvmTMB:::.gllvmTMB_offset_vec(fit2), c(1, 2))
})

test_that(".gllvmTMB_offset_newdata() errors on missing columns", {
  fit <- list(
    offset_expr = quote(log(effort)),
    formula = y ~ 1,
    tmb_data = list()
  )
  nd <- data.frame(y = 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit, nd),
    "missing"
  )
  fit$offset_expr <- NULL
  expect_equal(gllvmTMB:::.gllvmTMB_offset_newdata(fit, nd), 0)
})

test_that(".normalise_lambda_constraint_names() maps canonical tier names", {
  lc <- gllvmTMB:::.normalise_lambda_constraint_names(
    list(unit = diag(2), unit_obs = diag(2))
  )
  expect_equal(names(lc), c("B", "W"))
  opt <- "gllvmTMB.warned_lambda_constraint_B"
  withr::local_options(setNames(list(NULL), opt))
  legacy <- suppressWarnings(
    gllvmTMB:::.normalise_lambda_constraint_names(list(B = diag(2)))
  )
  expect_equal(names(legacy), "B")
  expect_error(
    gllvmTMB:::.normalise_lambda_constraint_names("not_a_list"),
    "list"
  )
  expect_error(
    gllvmTMB:::.normalise_lambda_constraint_names(list(diag(2))),
    "named"
  )
  expect_error(
    gllvmTMB:::.normalise_lambda_constraint_names(list(banana = 1)),
    "Unknown element"
  )
})

test_that(".mn_covstruct_tier() maps grouping columns to tiers", {
  cs <- list(group = quote(site))
  expect_equal(
    gllvmTMB:::.mn_covstruct_tier(cs, site = "site", ss_name = "ss",
                                   species = "sp", cluster2_col = NULL),
    "unit"
  )
  cs2 <- list(group = quote(ss))
  expect_equal(
    gllvmTMB:::.mn_covstruct_tier(cs2, "site", "ss", "sp", NULL),
    "unit_obs"
  )
  cs3 <- list(group = quote(other))
  expect_equal(
    gllvmTMB:::.mn_covstruct_tier(cs3, "site", "ss", "sp", NULL),
    "other"
  )
})

test_that(".mn_classify_covstruct() admits unit-tier latent and refuses meta_V", {
  latent <- list(kind = "rr", group = quote(site), extra = list(.dep = FALSE))
  cls <- gllvmTMB:::.mn_classify_covstruct(
    latent, site = "site", ss_name = "ss", species = "sp", cluster2_col = NULL
  )
  expect_true(cls$admitted)
  expect_equal(cls$mode, "latent")

  eq <- list(kind = "equalto", group = quote(site), extra = list())
  bad <- gllvmTMB:::.mn_classify_covstruct(
    eq, "site", "ss", "sp", NULL
  )
  expect_false(bad$admitted)
  expect_match(bad$label, "meta_V")

  re <- list(kind = "re_int", group = quote(ss), extra = list())
  re_bad <- gllvmTMB:::.mn_classify_covstruct(re, "site", "ss", "sp", NULL)
  expect_false(re_bad$admitted)
})