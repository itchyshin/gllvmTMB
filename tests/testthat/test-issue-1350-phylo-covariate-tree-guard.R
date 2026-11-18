## Issue #1350: the "one tree per fit" guard for a phylo() covariate model
## compared tip labels only, in storage order. A different tree with the same
## tips passed silently (the user's `tree =` was discarded); the same tree with
## its tips stored in another order was rejected as "differs".

.tree_1350 <- function(n = 12L, seed = 1L) {
  set.seed(seed)
  tr <- ape::rcoal(n)
  tr$tip.label <- paste0("sp", seq_len(n))
  tr
}

## Same tree, tips stored in another order.
.reorder_tree_1350 <- function(tr) {
  n <- length(tr$tip.label)
  perm <- rev(seq_len(n))                 # new tip i is old tip perm[i]
  tips <- tr$edge[, 2L] <= n
  tr$edge[tips, 2L] <- match(tr$edge[tips, 2L], perm)
  tr$tip.label <- tr$tip.label[perm]
  tr
}

## Same tips in the same order, different branch lengths.
.rescale_tree_1350 <- function(tr, seed = 2L) {
  set.seed(seed)
  tr$edge.length <- tr$edge.length * stats::runif(length(tr$edge.length), 0.5, 2)
  tr
}

## Species-level covariate x with two species missing, two traits, a
## species-level response covariate z (self-contained: no shared fixtures).
.data_1350 <- function(tree, reps = 2L, seed = 11L) {
  set.seed(seed)
  n <- length(tree$tip.label)
  x_sp <- as.numeric(t(chol(ape::vcv(tree, corr = TRUE) + 1e-9 * diag(n))) %*%
                       stats::rnorm(n)) + stats::rnorm(n, sd = 0.4)
  z_sp <- stats::rnorm(n)
  rows <- list()
  k <- 0L
  for (i in seq_len(n)) {
    for (r in seq_len(reps)) {
      k <- k + 1L
      rows[[k]] <- data.frame(
        site = k, species = tree$tip.label[i], trait = c("t1", "t2"),
        value = c(0.6, -0.3) + 1.2 * x_sp[i] + c(-0.25, 0.45) * z_sp[i] +
          stats::rnorm(2, sd = 0.4),
        x = x_sp[i], z = z_sp[i], stringsAsFactors = FALSE
      )
    }
  }
  dat <- do.call(rbind, rows)
  dat$x[dat$species %in% tree$tip.label[c(2L, 7L)]] <- NA_real_
  dat$site <- factor(dat$site)
  dat$species <- factor(dat$species, levels = tree$tip.label)
  dat$trait <- factor(dat$trait, levels = c("t1", "t2"))
  dat
}

.fit_1350 <- function(dat, tree, cov_tree) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + mi(x),
    data = dat, family = gaussian(),
    phylo_tree = tree,
    impute = list(x = x ~ phylo(1 | species, tree = cov_tree)),
    missing = miss_control(predictor = "model"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

test_that(".gllvmTMB_same_phylo_tree() compares trees, not tip-label order", {
  skip_if_not_installed("ape")
  same <- gllvmTMB:::.gllvmTMB_same_phylo_tree
  t1 <- .tree_1350()
  t3 <- .reorder_tree_1350(t1)
  t2 <- .rescale_tree_1350(t1)
  ## Premises: the reordered copy is stored in another tip order, and the
  ## rescaled copy has the same tip vector as the original.
  expect_false(identical(t1$tip.label, t3$tip.label))
  expect_identical(t1$tip.label, t2$tip.label)

  expect_true(same(t1, t1))
  expect_true(same(t1, t3))
  expect_false(same(t1, t2))
  t4 <- t1
  t4$tip.label[1] <- "other"
  expect_false(same(t1, t4))
  expect_false(same(t1, .tree_1350(seed = 99L)))
})

test_that("phylo() covariate tree: a different tree on the same tips is refused", {
  skip_if_not_installed("ape")
  tree <- .tree_1350()
  dat <- .data_1350(tree)
  t2 <- .rescale_tree_1350(tree)
  expect_identical(tree$tip.label, t2$tip.label)
  expect_error(
    .fit_1350(dat, tree, t2),
    "differs from the response phylogenetic tree"
  )
})

test_that("phylo() covariate tree: the same tree with reordered tips is accepted", {
  skip_if_not_installed("ape")
  tree <- .tree_1350()
  dat <- .data_1350(tree)
  t3 <- .reorder_tree_1350(tree)
  expect_false(identical(tree$tip.label, t3$tip.label))
  fit <- .fit_1350(dat, tree, t3)
  expect_s3_class(fit, "gllvmTMB_multi")
})
