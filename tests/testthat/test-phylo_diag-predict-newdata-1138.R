## #1138: `predict(newdata = )` re-adds the per-trait phylogenetic tier
## (`phylo_diag`, the folded Psi of `phylo_latent(..., unique = TRUE)`). The
## acceptance criterion is the issue's own: on the training rows the rebuilt
## linear predictor equals `report$eta` with max|diff| == 0.
##
## Conventions pinned here (src/gllvmTMB.cpp):
##   PARAMETER_MATRIX(g_phy_diag)  -- n_aug_phy x n_traits
##   eta(o) += exp(log_sd_phy_diag(t(o))) * g_phy_diag(species_aug_id(o), t(o))
## added as its OWN step after the shared `phylo_rr` block. `phylo_diag` is
## only ever active beside `phylo_rr`, and adding the two as one pre-summed
## term rounds differently from adding them one after the other.
##
## Every fit here uses d = 1 for the shared block, so this file isolates the
## per-trait tier; the sum over shared factors at d > 1 is pinned in
## test-phylo_rr-predict-newdata-1138.R.

## A ladder tree built by hand (no ape needed): tip i hangs off internal node
## i, the last two tips share the deepest node, every tip is at height 1.
.phylo_diag_1138_tree <- function(n_tips) {
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
.phylo_diag_1138_vcv <- function(n_tips) {
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
## The species effects have two axes with different trait loadings, so a
## rank-one shared block leaves per-trait phylogenetic variance for Psi.
.phylo_diag_1138_fixture <- function() {
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
  ## Deterministic values; no random numbers are drawn.
  dat$value <- sin(1.7 * sp) * c(1.2, -0.7, 0.4, 0.9)[tr] +
    cos(2.9 * sp) * c(0.3, 0.8, -1.1, 0.5)[tr] +
    0.35 * sin(12.9898 * i) + 0.2 * cos(4.1 * i)
  list(
    data = dat,
    tree = .phylo_diag_1138_tree(n_tips),
    vcv = .phylo_diag_1138_vcv(n_tips)
  )
}

.phylo_diag_1138_fit <- function(formula, data) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    formula,
    data = data, trait = "trait", unit = "site", cluster = "species",
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, n_init = 1L),
    silent = TRUE
  )))
}

test_that("#1138: phylo_diag is re-added on newdata, exactly", {
  fx <- .phylo_diag_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  vcv <- fx$vcv

  formulas <- list(
    "tree" = value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = tree, unique = TRUE),
    "vcv" = value ~ 0 + trait +
      phylo_latent(species, d = 1, vcv = vcv, unique = TRUE),
    "tree, rho = 0.35" = value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = tree, unique = TRUE, rho = 0.35)
  )

  for (label in names(formulas)) {
    fit <- .phylo_diag_1138_fit(formulas[[label]], dat)
    expect_identical(as.integer(fit$tmb_data$use_phylo_diag), 1L, info = label)
    expect_identical(as.integer(fit$tmb_data$use_phylo_rr), 1L, info = label)

    eta <- as.numeric(fit$report$eta)
    ## The per-trait tier has to be doing something, or the identity below
    ## says nothing about it: the block on its own is far from zero.
    per_trait <- gllvmTMB:::.structured_rho_contribution(fit, tiers = "phylo_diag")
    expect_identical(dim(per_trait), c(7L, 4L), info = label)
    expect_gt(max(abs(per_trait)), 1e-3, label = label)

    on_newdata <- suppressMessages(predict(fit, newdata = dat))$est
    expect_identical(max(abs(on_newdata - eta)), 0, info = label)

    ## Both phylogenetic tiers are named as re-added, and nothing is reported
    ## as omitted.
    expect_message(predict(fit, newdata = dat), "phylo_diag", fixed = TRUE)
    expect_no_warning(suppressMessages(predict(fit, newdata = dat)))
  }
})

test_that("#1138: phylo_diag follows the row's species and trait, not its position", {
  fx <- .phylo_diag_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  fit <- .phylo_diag_1138_fit(
    value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree, unique = TRUE),
    dat
  )
  eta <- as.numeric(fit$report$eta)

  ## A subset in a scrambled row order must still pick up the right cell.
  rows <- c(71L, 3L, 44L, 18L, 80L, 9L, 57L, 26L, 62L, 35L, 1L, 84L, 50L)
  on_subset <- suppressMessages(predict(fit, newdata = dat[rows, ]))$est
  expect_identical(max(abs(on_subset - eta[rows])), 0)

  ## A species the fit never saw gets the fixed-effects-only value in its own
  ## row, and leaves every other row exactly as it was.
  nd <- dat[rows, ]
  nd$species <- as.character(nd$species)
  nd$species[2L] <- "sp_unseen"
  with_unseen <- suppressMessages(predict(fit, newdata = nd))$est
  fixed_only <- predict(fit, newdata = nd, re_form = ~0)$est
  expect_identical(with_unseen[2L], fixed_only[2L])
  expect_identical(max(abs(with_unseen[-2L] - eta[rows][-2L])), 0)
})

test_that("#1138: the two phylogenetic blocks still sum to the combined contribution", {
  fx <- .phylo_diag_1138_fixture()
  tree <- fx$tree
  fit <- .phylo_diag_1138_fit(
    value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree, unique = TRUE),
    fx$data
  )
  ## simulate() and the other callers take both blocks at once; selecting a
  ## tier must not change what the default returns.
  both <- gllvmTMB:::.structured_rho_contribution(fit)
  shared <- gllvmTMB:::.structured_rho_contribution(fit, tiers = "phylo_rr")
  per_trait <- gllvmTMB:::.structured_rho_contribution(fit, tiers = "phylo_diag")
  expect_identical(both, shared + per_trait)
})
