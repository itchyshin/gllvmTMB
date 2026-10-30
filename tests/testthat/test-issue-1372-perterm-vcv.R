## #1372: a per-term vcv = that disagrees with phylo_vcv = used to be
## dropped with no message whenever the two matrices had the same
## dimensions. The harvest now refuses a numeric mismatch.

test_that("#1372 same-dimension VCV inputs compare by value, not only dim()", {
  same <- gllvmTMB:::.gllvmTMB_same_phylo_vcv
  a <- diag(3)
  b <- a
  b[1, 2] <- b[2, 1] <- 0.4
  expect_true(same(a, a))
  expect_true(same(a, `dimnames<-`(a, list(letters[1:3], letters[1:3]))))
  expect_false(same(a, b))
  expect_false(same(a, diag(4)))
})

test_that("#1372 conflicting in-keyword vcv and phylo_vcv abort", {
  set.seed(2)
  ns <- 8L
  nt <- 2L
  sp <- paste0("sp", seq_len(ns))
  ar1 <- function(r) {
    m <- r^abs(outer(seq_len(ns), seq_len(ns), "-"))
    dimnames(m) <- list(sp, sp)
    m
  }
  K1 <- ar1(0.3)
  K2 <- ar1(0.9)
  d <- expand.grid(
    species = factor(sp, levels = sp),
    trait = factor(paste0("t", seq_len(nt))),
    KEEP.OUT.ATTRS = FALSE
  )
  d$site <- factor(d$species)
  d$value <- rnorm(nrow(d))
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species, vcv = K1),
      data = d,
      unit = "site",
      trait = "trait",
      cluster = "species",
      family = gaussian(),
      phylo_vcv = K2,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    class = "gllvmTMB_phylo_vcv_conflict"
  )
})

test_that("#1372 matching in-keyword vcv and phylo_vcv still fit", {
  set.seed(2)
  ns <- 8L
  nt <- 2L
  sp <- paste0("sp", seq_len(ns))
  K <- diag(ns)
  dimnames(K) <- list(sp, sp)
  d <- expand.grid(
    species = factor(sp, levels = sp),
    trait = factor(paste0("t", seq_len(nt))),
    KEEP.OUT.ATTRS = FALSE
  )
  d$site <- factor(d$species)
  d$value <- rnorm(nrow(d))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species, vcv = K),
    data = d,
    unit = "site",
    trait = "trait",
    cluster = "species",
    family = gaussian(),
    phylo_vcv = K,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(all.equal(unname(as.matrix(fit$phylo_vcv)), unname(K))))
})
