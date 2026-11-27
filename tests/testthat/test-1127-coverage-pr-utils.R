## Cursor coverage 27 Nov: focused branches in R/[p-r]* helpers
## (reportable-table, rng-utils, pedigree-precision, phylo-tree-precision,
## profile-targets, ridge-path). Kept fast (no multi-seed fits).

test_that(".reportable_table leaves non-data.frames unchanged", {
  x <- matrix(1:4, 2, 2)
  expect_identical(gllvmTMB:::.reportable_table(x), x)
  expect_false(inherits(x, "gllvmTMB_reportable_table"))
})

test_that(".gllvmTMB_jitter_offsets returns an empty list for n < 1", {
  expect_identical(gllvmTMB:::.gllvmTMB_jitter_offsets(0L, len = 3L, sd = 0.1), list())
})

test_that(".gllvmTMB_jitter_offsets is reproducible and restores the RNG stream", {
  set.seed(1)
  before <- runif(2)
  set.seed(1)
  jit <- gllvmTMB:::.gllvmTMB_jitter_offsets(2L, len = 4L, sd = 0.25, seed = 99L)
  expect_identical(before, runif(2))
  expect_length(jit, 2L)
  expect_length(jit[[1L]], 4L)
  set.seed(99)
  ref <- list(
    stats::rnorm(4, sd = 0.25),
    stats::rnorm(4, sd = 0.25)
  )
  expect_equal(jit, ref, tolerance = 1e-12)
})

test_that(".gllvmTMB_local_seed removes a newly created .Random.seed on exit", {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  f <- function() {
    gllvmTMB:::.gllvmTMB_local_seed(4L)
    stats::runif(1)
  }
  f()
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("pedigree standardisation normalises blank and zero parent codes", {
  ped <- data.frame(
    id = c("A", "B", "C"),
    dam = c(NA, "", "0"),
    sire = c("A", NA, "B"),
    stringsAsFactors = FALSE
  )
  out <- gllvmTMB:::.gllvm_standardize_pedigree(ped)
  expect_true(all(is.na(out$dam[c(1L, 2L)])))
  expect_true(is.na(out$dam[[3L]]))
})

test_that("pedigree helpers refuse invalid pedigree tables", {
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(list(id = "A")),
    "data frame",
    fixed = TRUE
  )
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(data.frame(id = c("A", "B"), dam = c(NA, NA))),
    "dam",
    fixed = TRUE
  )
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(
      data.frame(id = c("A", ""), dam = c(NA, NA), sire = c(NA, NA), stringsAsFactors = FALSE)
    ),
    "non-missing",
    fixed = TRUE
  )
  cyc <- data.frame(
    id = c("A", "B", "C"),
    dam = c("B", "C", "A"),
    sire = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  expect_error(
    gllvmTMB:::.gllvm_pedigree_topological_order(cyc),
    "parent-offspring cycles",
    fixed = TRUE
  )
})

test_that("Quaas assembly covers sire-only, dam-only, and founder diagonals", {
  sire_only <- data.frame(
    id = c("A", "B"), dam = c(NA, NA), sire = c(NA, "A"), stringsAsFactors = FALSE
  )
  dam_only <- data.frame(
    id = c("A", "B"), dam = c(NA, "A"), sire = c(NA, NA), stringsAsFactors = FALSE
  )
  founders <- data.frame(
    id = c("A", "B"), dam = c(NA, NA), sire = c(NA, NA), stringsAsFactors = FALSE
  )
  for (ped in list(sire_only, dam_only, founders)) {
    native <- gllvmTMB:::.gllvm_pedigree_precision(ped)
    expect_s4_class(native, "dgCMatrix")
    expect_equal(
      gllvmTMB:::.gllvm_pedigree_precision_dense_F(ped),
      native,
      tolerance = 1e-10
    )
  }
})

test_that(".ridge_path_verdict enforces convergence length and degenerate tau grids", {
  expect_error(
    gllvmTMB:::.ridge_path_verdict(
      tau = c(1, 2), max_loading = c(1, 2), convergence = c(0)
    ),
    "convergence",
    fixed = TRUE
  )
  dup <- gllvmTMB:::.ridge_path_verdict(tau = c(2, 2), max_loading = c(1, 1.2))
  expect_identical(dup$verdict, "insufficient")
  inf_only <- gllvmTMB:::.ridge_path_verdict(
    tau = c(Inf), max_loading = c(10), convergence = c(1L)
  )
  expect_identical(inf_only$verdict, "insufficient")
})

test_that("print.gllvmTMB_ridge_path reports insufficient evidence per trait", {
  x <- data.frame(
    tau = c(2, 4),
    trait = rep("sp1", 2),
    max_loading = c(1, NA_real_),
    convergence = c(0L, 0L),
    stringsAsFactors = FALSE
  )
  class(x) <- c("gllvmTMB_ridge_path", "data.frame")
  out <- paste(capture.output(print(x)), collapse = "\n")
  expect_match(out, "insufficient finite-tau evidence", fixed = TRUE)
})

test_that(".gllvm_validate_phylo_tree catches malformed phylo inputs", {
  skip_if_not_installed("ape")
  expect_error(
    gllvmTMB:::.gllvm_validate_phylo_tree("not-a-tree"),
    "phylo",
    fixed = TRUE
  )
  bad <- structure(list(), class = "phylo")
  expect_error(
    gllvmTMB:::.gllvm_validate_phylo_tree(bad),
    "tip labels",
    fixed = TRUE
  )
  tree <- ape::rtree(4)
  tree$tip.label[[2L]] <- tree$tip.label[[1L]]
  expect_error(gllvmTMB:::.gllvm_validate_phylo_tree(tree), "unique", fixed = TRUE)
})

test_that(".gllvm_validate_phylo_species maps species to tip labels", {
  skip_if_not_installed("ape")
  tree <- ape::rcoal(4)
  tree$tip.label <- paste0("t", seq_len(4))
  expect_error(
    gllvmTMB:::.gllvm_validate_phylo_species(character(0), tree$tip.label),
    "at least one",
    fixed = TRUE
  )
  expect_error(
    gllvmTMB:::.gllvm_validate_phylo_species(c("t1", "missing"), tree$tip.label),
    "Missing tip label",
    fixed = TRUE
  )
  lv <- gllvmTMB:::.gllvm_validate_phylo_species(c("t1", "t2", "t2"), tree$tip.label)
  expect_identical(lv, c("t1", "t2"))
})

test_that("profile target helpers transform links and validate inventories", {
  expect_equal(gllvmTMB:::.profile_target_transform(0, "exp"), 1)
  expect_equal(gllvmTMB:::.profile_target_transform(0, "logit"), 0.5, tolerance = 1e-12)
  expect_equal(gllvmTMB:::.profile_target_transform(log(2), "ordinal_threshold"), 2, tolerance = 1e-12)
  expect_true(is.na(gllvmTMB:::.profile_target_transform(0, "not_a_transform")))

  expect_identical(gllvmTMB:::.profile_target_label("sd_B", 1L, 1L), "sd_B")
  expect_identical(gllvmTMB:::.profile_target_label("sd_B", 3L, 5L), "sd_B[3]")

  expect_error(
    gllvmTMB:::.validate_profile_targets(data.frame(parm = "x")),
    class = "gllvmTMB_profile_targets_invalid"
  )
})