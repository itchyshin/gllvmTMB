## #1861 / #1862: multi-group and missing-column aborts for default cluster
## resolution on animal_* and phylo_* keywords.

.grouping_abort_fixture <- function() {
  set.seed(1861L)
  n <- 8L
  p <- 2L
  ids <- paste0("i", seq_len(n))
  taxa <- paste0("t", seq_len(n))
  ped <- data.frame(
    id = ids,
    sire = c(rep(NA, 2L), rep(ids[1], n - 2L)),
    dam = c(rep(NA, 2L), rep(ids[2], n - 2L)),
    stringsAsFactors = FALSE
  )
  K <- matrix(0.6, n, n)
  diag(K) <- 1
  rownames(K) <- colnames(K) <- taxa
  df <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    individual = factor(rep(ids, each = p), levels = ids),
    herd = factor(rep(paste0("h", ((seq_len(n) - 1L) %% 3L) + 1L), each = p)),
    taxon = factor(rep(taxa, each = p), levels = taxa),
    lineage = factor(rep(paste0("l", seq_len(n)), each = p)),
    trait = factor(rep(paste0("v", seq_len(p)), times = n)),
    value = stats::rnorm(n * p)
  )
  list(df = df, ped = ped, K = K)
}

test_that("two animal_* bare groupings without cluster abort gllvmTMB_animal_grouping (#1861)", {
  fx <- .grouping_abort_fixture()
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        animal_scalar(individual, pedigree = fx$ped) +
        animal_scalar(herd, pedigree = fx$ped),
      data = fx$df, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_animal_grouping")
  expect_match(conditionMessage(err), "more than one grouping column")
})

test_that("missing animal_* grouping column aborts gllvmTMB_animal_grouping (#1861)", {
  fx <- .grouping_abort_fixture()
  df <- fx$df
  df$individual <- NULL
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_scalar(individual, pedigree = fx$ped),
      data = df, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_animal_grouping")
  expect_match(conditionMessage(err), "not a column in")
  expect_match(conditionMessage(err), "individual")
})

test_that("two phylo_* bare groupings without cluster abort gllvmTMB_phylo_grouping (#1862)", {
  fx <- .grouping_abort_fixture()
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_indep(0 + trait | taxon, vcv = fx$K) +
        phylo_indep(0 + trait | lineage, vcv = fx$K),
      data = fx$df, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_phylo_grouping")
  expect_match(conditionMessage(err), "more than one grouping column")
})

test_that("missing phylo_* grouping column aborts gllvmTMB_phylo_grouping (#1862)", {
  fx <- .grouping_abort_fixture()
  df <- fx$df
  df$taxon <- NULL
  err <- tryCatch(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | taxon, vcv = fx$K),
      data = df, trait = "trait", unit = "unit",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE),
      silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_phylo_grouping")
  expect_match(conditionMessage(err), "not a column in")
  expect_match(conditionMessage(err), "taxon")
})