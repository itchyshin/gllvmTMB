## #1138: `predict(newdata = )` re-adds the slope-only phylogenetic / pedigree
## random regression (`phylo_slope(x | group)`, `animal_slope(x | group)`).
## The acceptance criterion is the issue's own: on the training rows the
## rebuilt linear predictor equals `report$eta` with max|diff| == 0.
##
## Conventions pinned here (src/gllvmTMB.cpp):
##   PARAMETER_VECTOR(b_phy_slope)   -- length n_aug_phy_slope
##   eta(o) += b_phy_slope(phylo_slope_aug_id(o)) * x_phy_slope(o)
## in the `else` arm of use_phylo_slope_correlated. One slope per group
## level, shared by every trait, no random intercept.
##
## Only that block is rebuilt. The intercept-plus-slope and response-column
## routes (`phylo_indep(1 + x | species)`, `phylo_slope(x | trait)`, ...) raise
## the same `use_phylo_slope` flag but live in a different parameter block;
## the last test checks they are never passed off as re-added.

## A ladder tree built by hand (no ape needed): tip i hangs off internal node
## i, the last two tips share the deepest node, every tip is at height 1.
.phylo_slope_1138_tree <- function(n_tips) {
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
.phylo_slope_1138_vcv <- function(n_tips) {
  n_node <- n_tips - 1L
  depth <- (seq_len(n_node) - 1) / n_node
  C <- outer(seq_len(n_tips), seq_len(n_tips), function(i, j) {
    depth[pmin(i, j, n_node)]
  })
  diag(C) <- 1
  dimnames(C) <- list(paste0("sp", seq_len(n_tips)), paste0("sp", seq_len(n_tips)))
  C
}

## Seven observed species out of nine tips, three traits, four sites per
## species. The species levels are NOT in tip order and two tips are never
## observed, so with `tree =` the slope node of a row is neither its species
## code nor its tip number (the tree route carries 16 nodes for 7 levels).
## Each species has its own slope on `x`, and `x` varies within species.
.phylo_slope_1138_fixture <- function() {
  n_tips <- 9L
  observed <- c("sp6", "sp2", "sp9", "sp4", "sp1", "sp7", "sp3")
  traits <- paste0("t", 1:3)
  dat <- expand.grid(
    trait = traits, rep = 1:4, species = observed,
    stringsAsFactors = FALSE
  )
  dat$species <- factor(dat$species, levels = observed)
  dat$trait <- factor(dat$trait, levels = traits)
  dat$site <- factor(paste(dat$species, dat$rep, sep = "_"))
  sp <- as.integer(dat$species)
  tr <- as.integer(dat$trait)
  i <- seq_len(nrow(dat))
  ## Deterministic values; no random numbers are drawn.
  dat$x <- sin(0.9 * i) + 0.5 * cos(2.3 * i)
  dat$value <- c(0.4, -0.2, 0.7)[tr] + sin(1.7 * sp) * dat$x +
    0.3 * sin(12.9898 * i) + 0.2 * cos(4.1 * i)
  ## The same grouping under another name, as a character column, for a term
  ## whose right-hand side is not the `cluster` column.
  dat$lineage <- as.character(dat$species)
  list(
    data = dat,
    tree = .phylo_slope_1138_tree(n_tips),
    vcv = .phylo_slope_1138_vcv(n_tips)
  )
}

.phylo_slope_1138_fit <- function(formula, data) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    formula,
    data = data, trait = "trait", unit = "site", cluster = "species",
    family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE, n_init = 1L),
    silent = TRUE
  )))
}

## Was a tier reported as omitted? Returns the dropped-tier warning, or NULL.
.phylo_slope_1138_dropped <- function(fit, newdata) {
  caught <- NULL
  withCallingHandlers(
    suppressMessages(predict(fit, newdata = newdata)),
    gllvmTMB_predict_newdata_re_dropped = function(w) {
      caught <<- w
      invokeRestart("muffleWarning")
    }
  )
  caught
}

test_that("#1138: the slope-only phylo_slope block is re-added on newdata, exactly", {
  fx <- .phylo_slope_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  vcv <- fx$vcv

  formulas <- list(
    "phylo_slope, tree" = value ~ 0 + trait + phylo_slope(x | species, tree = tree),
    "phylo_slope, vcv" = value ~ 0 + trait + phylo_slope(x | species, vcv = vcv),
    "animal_slope, A" = value ~ 0 + trait + animal_slope(x | species, A = vcv),
    "phylo_slope, tree, grouped on lineage" =
      value ~ 0 + trait + phylo_slope(x | lineage, tree = tree),
    "phylo_slope + (1 | species)" =
      value ~ 0 + trait + phylo_slope(x | species, tree = tree) + (1 | species)
  )

  for (label in names(formulas)) {
    fit <- .phylo_slope_1138_fit(formulas[[label]], dat)
    expect_identical(as.integer(fit$tmb_data$use_phylo_slope), 1L, info = label)
    expect_identical(
      as.integer(fit$tmb_data$use_phylo_slope_correlated), 0L,
      info = label
    )

    eta <- as.numeric(fit$report$eta)
    ## The slope block has to be doing something, or the identity below says
    ## nothing about it: the fitted slopes are far from zero.
    par <- fit$tmb_obj$env$last.par.best
    slopes <- par[names(par) == "b_phy_slope"]
    expect_length(slopes, fit$tmb_data$n_aug_phy_slope)
    expect_gt(max(abs(slopes)), 1e-3, label = label)

    on_newdata <- suppressMessages(predict(fit, newdata = dat))$est
    expect_equal(max(abs(on_newdata - eta)), 0, tolerance = 1e-10, info = label)

    ## The tier is named as re-added, and nothing is reported as omitted.
    expect_message(predict(fit, newdata = dat), "phylo_slope", fixed = TRUE)
    expect_no_warning(suppressMessages(predict(fit, newdata = dat)))
  }
})

test_that("#1138: phylo_slope follows the row's group and covariate, not its position", {
  fx <- .phylo_slope_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  fit <- .phylo_slope_1138_fit(
    value ~ 0 + trait + phylo_slope(x | species, tree = tree),
    dat
  )
  eta <- as.numeric(fit$report$eta)

  ## A subset in a scrambled row order must still pick up the right slope.
  rows <- c(71L, 3L, 44L, 18L, 80L, 9L, 57L, 26L, 62L, 35L, 1L, 84L, 50L)
  on_subset <- suppressMessages(predict(fit, newdata = dat[rows, ]))$est
  expect_equal(max(abs(on_subset - eta[rows])), 0, tolerance = 1e-10)

  ## At x = 0 the slope contributes nothing: fixed effects only, exactly.
  at_zero <- dat[rows, ]
  at_zero$x <- 0
  expect_equal(
    suppressMessages(predict(fit, newdata = at_zero))$est,
    predict(fit, newdata = at_zero, re_form = ~0)$est,
    tolerance = 1e-10
  )

  ## A level the fit never saw gets the fixed-effects-only value in its own
  ## row, and leaves every other row exactly as it was. `sp5` is a tip of the
  ## tree with no training rows; it is treated like any other unseen level.
  for (new_level in c("sp_unseen", "sp5")) {
    nd <- dat[rows, ]
    nd$species <- as.character(nd$species)
    nd$species[2L] <- new_level
    with_unseen <- suppressMessages(predict(fit, newdata = nd))$est
    fixed_only <- predict(fit, newdata = nd, re_form = ~0)$est
    expect_equal(with_unseen[2L], fixed_only[2L], tolerance = 1e-10, info = new_level)
    expect_equal(
      max(abs(with_unseen[-2L] - eta[rows][-2L])), 0,
      tolerance = 1e-10,
      info = new_level
    )
  }
})

test_that("#1138: phylo_slope is named as omitted when newdata cannot carry it", {
  fx <- .phylo_slope_1138_fixture()
  dat <- fx$data
  tree <- fx$tree
  fit <- .phylo_slope_1138_fit(
    value ~ 0 + trait + phylo_slope(x | species, tree = tree),
    dat
  )

  ## Without the covariate the slope cannot be rebuilt. The prediction is
  ## then the fixed-effects one, and the warning says which tier is missing.
  no_x <- dat[, setdiff(names(dat), "x")]
  dropped <- .phylo_slope_1138_dropped(fit, no_x)
  expect_s3_class(dropped, "gllvmTMB_predict_newdata_re_dropped")
  expect_match(conditionMessage(dropped), "phylo_slope", fixed = TRUE)
  expect_equal(
    suppressWarnings(suppressMessages(predict(fit, newdata = no_x)))$est,
    predict(fit, newdata = no_x, re_form = ~0)$est,
    tolerance = 1e-10
  )
})

test_that("#1138: other phylogenetic slope routes are never passed off as re-added", {
  fx <- .phylo_slope_1138_fixture()
  dat <- fx$data
  tree <- fx$tree

  ## An intercept-plus-slope term raises `use_phylo_slope` as well, but its
  ## effects are in another parameter block that the slope-only rebuild does
  ## not read. Whatever predict() does with it, it must not be silent: either
  ## the omission is reported, or the training-row identity holds exactly.
  fit <- .phylo_slope_1138_fit(
    value ~ 0 + trait + phylo_indep(1 + x | species, tree = tree),
    dat
  )
  expect_identical(as.integer(fit$tmb_data$use_phylo_slope), 1L)
  expect_identical(as.integer(fit$tmb_data$use_phylo_slope_correlated), 1L)

  dropped <- .phylo_slope_1138_dropped(fit, dat)
  on_newdata <- suppressWarnings(suppressMessages(predict(fit, newdata = dat)))$est
  exact <- identical(max(abs(on_newdata - as.numeric(fit$report$eta))), 0)
  expect_true(!is.null(dropped) || exact)
})
