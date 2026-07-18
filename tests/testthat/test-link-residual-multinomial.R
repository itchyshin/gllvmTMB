## Tier-2b item 1 (Design 84 follow-up): the multinomial link residual is a
## (K-1) x (K-1) MATRIX (pi^2/6)(I + J) -- pi^2/3 on the diagonal (each
## baseline contrast is a logit, as binomial-logit) and pi^2/6 off-diagonal
## (the shared baseline category couples the contrasts; McFadden 1974). It is
## added to the multinomial trait's pseudo-trait block of Sigma by
## `link_residual = "auto"` (the default). It reduces to binomial's pi^2/3 at
## K = 2 and is tier-agnostic (phylo / spatial / kernel / ordinary latent).

.get_sigma <- function(x) {
  if (is.matrix(x)) return(x)
  if (!is.null(x$Sigma)) return(x$Sigma)
  x[[1L]]
}

test_that(".multinomial_link_residual_offdiag() places pi^2/6 on within-block off-diagonals only", {
  off <- pi^2 / 6

  ## Single K = 3 multinomial (two baseline-contrast pseudo-traits).
  tn <- c("morph:2", "morph:3")
  M <- gllvmTMB:::.multinomial_link_residual_offdiag(tn, c(2L, 2L))
  expect_equal(dim(M), c(2L, 2L))
  expect_equal(unname(diag(M)), c(0, 0))                 # diagonal handled elsewhere
  expect_equal(unname(M[1L, 2L]), off)
  expect_true(isSymmetric(M))

  ## Mixed distribution: a multinomial trait (K = 3) alongside a normal trait.
  ## The gaussian trait carries no coupling, and the multinomial block does not
  ## leak into it -- proves the "other structural deps + normal RE" contract.
  tn2 <- c("morph:2", "morph:3", "bodymass")
  M2 <- gllvmTMB:::.multinomial_link_residual_offdiag(tn2, c(2L, 2L, 0L))
  expect_equal(M2[1L, 2L], off)
  expect_equal(unname(M2[3L, ]), c(0, 0, 0))             # gaussian row all zero
  expect_equal(unname(M2[, 3L]), c(0, 0, 0))             # gaussian col all zero

  ## Two independent multinomial traits: each couples within its own block,
  ## never across blocks.
  tn3 <- c("diet:2", "diet:3", "diet:4", "hab:2", "hab:3")
  M3 <- gllvmTMB:::.multinomial_link_residual_offdiag(tn3, c(3L, 3L, 3L, 2L, 2L))
  expect_equal(M3[1L, 2L], off); expect_equal(M3[1L, 3L], off)  # diet block
  expect_equal(M3[4L, 5L], off)                                  # hab block
  expect_equal(M3[1L, 4L], 0)                                    # no cross-block leak
  expect_equal(M3[3L, 5L], 0)

  ## No multinomial trait -> all zeros (auto is a no-op for the block).
  M0 <- gllvmTMB:::.multinomial_link_residual_offdiag(c("a", "b"), c(0L, 0L))
  expect_true(all(M0 == 0))
})

test_that("extract_Sigma(link_residual='auto') adds (pi^2/6)(I+J) to a multinomial V; 'none' does not", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(11L)
  n <- 60L; K <- 3L
  tree <- ape::rcoal(n); tree$tip.label <- paste0("sp", seq_len(n))
  df <- data.frame(species = factor(tree$tip.label, levels = tree$tip.label),
                   trait = factor("morph"),
                   value = factor(sample.int(K, n, replace = TRUE)))
  fit <- gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree),
                  data = df, family = multinomial(), trait = "trait",
                  unit = "species")

  V_none <- .get_sigma(extract_Sigma(fit, level = "phy", link_residual = "none"))
  ## 'auto' is the default; it must NOT warn about an unavailable residual now.
  V_auto <- .get_sigma(
    expect_no_warning(extract_Sigma(fit, level = "phy", link_residual = "auto"))
  )

  expect_equal(dim(V_auto), c(K - 1L, K - 1L))
  IJ <- (pi^2 / 6) * (diag(K - 1L) + matrix(1, K - 1L, K - 1L))
  expect_equal(unname(V_auto - V_none), unname(IJ), tolerance = 1e-8)
  expect_true(isSymmetric(unname(round(V_auto, 8))))
  ## Diagonal gained exactly pi^2/3; off-diagonal exactly pi^2/6.
  expect_equal(unname(diag(V_auto) - diag(V_none)), rep(pi^2 / 3, K - 1L), tolerance = 1e-8)

  ## The link residual applies ONLY to part = "total"; the reduced-rank
  ## "shared" and the "unique" diagonal are covariance sub-parts that must be
  ## untouched by link_residual = "auto".
  sh_auto <- .get_sigma(extract_Sigma(fit, level = "phy", part = "shared", link_residual = "auto"))
  sh_none <- .get_sigma(extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none"))
  expect_equal(unname(sh_auto), unname(sh_none), tolerance = 1e-10)
})

test_that("extract_Omega() agrees with extract_Sigma() on the multinomial block (blast-radius)", {
  skip_on_cran()
  skip_if_not_installed("ape")
  ## The fid-16 scalar change (NA -> pi^2/3) plus the off-diagonal must be
  ## applied CONSISTENTLY: for a phylo-only multinomial the summed Omega equals
  ## the phy-tier total Sigma. Guards against Omega silently disagreeing with
  ## Sigma (the pre-fix inconsistency: Omega had the diagonal but not the
  ## pi^2/6 off-diagonal).
  set.seed(11L)
  n <- 60L; K <- 3L
  tree <- ape::rcoal(n); tree$tip.label <- paste0("sp", seq_len(n))
  df <- data.frame(species = factor(tree$tip.label, levels = tree$tip.label),
                   trait = factor("morph"),
                   value = factor(sample.int(K, n, replace = TRUE)))
  fit <- gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree),
                  data = df, family = multinomial(), trait = "trait",
                  unit = "species")

  get_om <- function(x) if (!is.null(x$Omega)) x$Omega else x
  Om_auto <- get_om(extract_Omega(fit, link_residual = "auto"))
  Om_none <- get_om(extract_Omega(fit, link_residual = "none"))
  IJ <- (pi^2 / 6) * (diag(K - 1L) + matrix(1, K - 1L, K - 1L))
  ## The residual Omega gains is the SAME full matrix Sigma gains -- diagonal
  ## pi^2/3 AND off-diagonal pi^2/6 -- so the two never silently disagree.
  expect_equal(unname(Om_auto - Om_none), unname(IJ), tolerance = 1e-8)
  ## The off-diagonal coupling is really present (not just the diagonal).
  expect_gt(abs((Om_auto - Om_none)[1L, 2L]), pi^2 / 6 - 1e-6)
})
