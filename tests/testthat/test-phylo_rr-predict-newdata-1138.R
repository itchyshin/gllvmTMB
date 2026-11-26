## #1138: `predict(newdata = )` re-adds the phylogenetic reduced-rank tier
## (`phylo_rr`). The acceptance criterion is the issue's own: on the training
## rows the rebuilt linear predictor equals `report$eta` with max|diff| == 0.
## A non-zero contribution, or a close one, does not distinguish a correct
## reshape from a transposed one.
##
## Conventions pinned here (src/gllvmTMB.cpp):
##   PARAMETER_MATRIX(g_phy)  -- n_aug_phy x d_phy
##   eta(o) += sum_k Lambda_phy(t(o), k) * g_phy(species_aug_id(o), k)
## The sum over k is taken in the template's order. A BLAS matrix product is
## free to fuse or reorder it, which moves the last bit when d_phy > 1.

## A ladder tree built by hand (no ape needed): tip i hangs off internal node
## i, the last two tips share the deepest node, every tip is at height 1.
.phylo_rr_1138_tree <- function(n_tips) {
  n_node <- n_tips - 1L
  depth <- (seq_len(n_node) - 1) / n_node
  parent <- integer(0)
  child <- integer(0)
  len <- numeric(0)
  for (i in seq_len(n_node)) {
    parent <- c(parent, n_tips + i)
    child <- c(child, i)
    len <- c(len, 1 - depth[i])
    if (i < n_node) {
      parent <- c(parent, n_tips + i)
      child <- c(child, n_tips + i + 1L)
      len <- c(len, depth[i + 1L] - depth[i])
    } else {
      parent <- c(parent, n_tips + i)
      child <- c(child, n_tips)
      len <- c(len, 1 - depth[i])
    }
  }
  structure(
    list(
      edge = cbind(parent, child, deparse.level = 0),
      edge.length = len,
      tip.label = paste0("sp", seq_len(n_tips)),
      Nnode = n_node
    ),
    class = "phylo"
  )
}

## The correlation matrix the same ladder tree implies.
.phylo_rr_1138_vcv <- function(n_tips) {
  n_node <- n_tips - 1L
  depth <- (seq_len(n_node) - 1) / n_node
  C <- outer(seq_len(n_tips), seq_len(n_tips), function(i, j) {
    depth[pmin(i, j, n_node)]
  })
  diag(C) <- 1
  dimnames(C) <- list(paste0("sp", seq_len(n_tips)), paste0("sp", seq_len(n_tips)))
  C
}

## Seven observed species out of nine tips, four traits, three sites per
## species. The species levels are NOT in tip order and two tips are never
## observed, so `species_aug_id` is not the identity; seven species against
## four traits means a transposed block cannot even be indexed the same way.
.phylo_rr_1138_fixture <- function() {
  n_tips <- 9L
  observed <- c("sp6", "sp2", "sp9", "sp4", "sp1", "sp7", "sp3")
  traits <- paste0("t", 1:4)
  dat <- expand.grid(
    trait = traits, rep = 1:3, species = observed,
    stringsAsFactors = FALSE
  )
  dat$species <- factor(dat$species, levels = observed)
  dat$trait <- factor(dat$trait, levels = traits)
  dat$site <- factor(paste(dat$species, dat$rep, sep = "_"))
  sp <- as.integer(dat$species)
  tr <- as.integer(dat$trait)
  i <- seq_len(nrow(dat))
  ## Deterministic values with two species-level axes of different size per
  ## trait, plus row-level noise. No random numbers are drawn.
  dat$value <- sin(1.7 * sp) * c(1.2, -0.7, 0.4, 0.9)[tr] +
    cos(2.9 * sp) * c(0.3, 0.8, -1.1, 0.5)[tr] +
    0.35 * sin(12.9898 * i) + 0.2 * cos(4.1 * i)
  list(
    data = dat,
    tree = .phylo_rr_1138_tree(n_tips),
    vcv = .phylo_rr_1138_vcv(n_tips)
  )
}

.phylo_rr_1138_fit <- function(formula, data) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    formula,
    data = data, trait = "trait", unit = "site", cluster = "species",
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, n_init = 1L),
    silent = TRUE
  )))
}

test_that("#1138: phylo_rr is re-added on newdata, exactly, at every rank", {
  fx <- .phylo_rr_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  vcv <- fx$vcv

  formulas <- list(
    "tree d = 1" = value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree),
    "tree d = 2" = value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree),
    "tree d = 3" = value ~ 0 + trait + phylo_latent(species, d = 3, tree = tree),
    "tree dep" = value ~ 0 + trait + phylo_dep(0 + trait | species, tree = tree),
    "tree indep" = value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree),
    "vcv d = 2" = value ~ 0 + trait + phylo_latent(species, d = 2, vcv = vcv)
  )

  for (label in names(formulas)) {
    fit <- .phylo_rr_1138_fit(formulas[[label]], dat)
    expect_identical(as.integer(fit$tmb_data$use_phylo_rr), 1L, info = label)
    expect_identical(as.integer(fit$tmb_data$use_phylo_diag), 0L, info = label)

    eta <- as.numeric(fit$report$eta)
    fixed_only <- predict(fit, newdata = dat, re_form = ~0)$est
    ## The tier has to be doing something, or the identity below is empty.
    expect_gt(max(abs(eta - fixed_only)), 1e-3, label = label)

    on_newdata <- suppressMessages(predict(fit, newdata = dat))$est
    expect_equal(max(abs(on_newdata - eta)), 0, tolerance = 1e-10, info = label)

    ## It is named as re-added, and nothing is reported as omitted.
    expect_message(predict(fit, newdata = dat), "phylo_rr", fixed = TRUE)
    expect_no_warning(suppressMessages(predict(fit, newdata = dat)))
  }
})

test_that("#1138: phylo_rr follows the row's species and trait, not its position", {
  fx <- .phylo_rr_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  fit <- .phylo_rr_1138_fit(
    value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree), dat
  )
  eta <- as.numeric(fit$report$eta)

  ## A subset in a scrambled row order must still pick up the right cell.
  rows <- c(71L, 3L, 44L, 18L, 80L, 9L, 57L, 26L, 62L, 35L, 1L, 84L, 50L)
  on_subset <- suppressMessages(predict(fit, newdata = dat[rows, ]))$est
  expect_equal(max(abs(on_subset - eta[rows])), 0, tolerance = 1e-10)

  ## A species the fit never saw gets the fixed-effects-only value in its own
  ## row, and leaves every other row exactly as it was.
  nd <- dat[rows, ]
  nd$species <- as.character(nd$species)
  nd$species[2L] <- "sp_unseen"
  with_unseen <- suppressMessages(predict(fit, newdata = nd))$est
  fixed_only <- predict(fit, newdata = nd, re_form = ~0)$est
  expect_identical(with_unseen[2L], fixed_only[2L])
  expect_equal(max(abs(with_unseen[-2L] - eta[rows][-2L])), 0, tolerance = 1e-10)
})
