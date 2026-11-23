## #1765: classed aborts when animal_* cluster adoption is ambiguous.

.fix1765_abort_layout <- function() {
  set.seed(17651)
  ids <- paste0("i", 1:6)
  df <- expand.grid(
    individual = factor(ids),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  df$unit <- df$individual
  ped <- data.frame(
    id = ids,
    sire = c(NA, NA, ids[1], ids[1], ids[2], ids[2]),
    dam = c(NA, NA, ids[3], ids[3], ids[4], ids[4]),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  list(df = df, ped = ped, A = A)
}

.fix1765_abort_control <- function() {
  gllvmTMB::gllvmTMBcontrol(
    n_init = 1L, se = FALSE, laplace_auto_refit = FALSE
  )
}

test_that("missing animal grouping column stops with gllvmTMB_animal_grouping (#1765)", {
  fx <- .fix1765_abort_layout()
  df <- fx$df
  df$individual <- NULL
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_scalar(individual, pedigree = fx$ped),
      data = df, trait = "trait", unit = "unit",
      control = .fix1765_abort_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_animal_grouping")
  msg <- conditionMessage(err)
  expect_match(msg, "groups by .individual., which is not a column")
  expect_no_match(msg, "placeholder")
  expect_no_match(msg, "phylo_vcv")
})

test_that("two animal_* groupings without cluster stop with gllvmTMB_animal_grouping (#1765)", {
  ids <- paste0("i", 1:4)
  df <- expand.grid(
    ind1 = factor(ids),
    ind2 = factor(ids),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  df$unit <- df$ind1
  A <- diag(length(ids))
  dimnames(A) <- list(ids, ids)
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        animal_indep(0 + trait | ind1, A = A) +
        animal_indep(0 + trait | ind2, A = A),
      data = df, unit = "unit", trait = "trait",
      control = .fix1765_abort_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_animal_grouping")
  msg <- conditionMessage(err)
  expect_match(msg, "more than one grouping column")
  expect_match(msg, "ind1")
  expect_match(msg, "ind2")
  expect_match(msg, "cluster")
})