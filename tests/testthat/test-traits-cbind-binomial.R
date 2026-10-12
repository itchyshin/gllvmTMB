## Issue #1494: wide traits(cbind(successes, failures), ...) multi-trial binomial.

.cbind_fixture <- function(n = 60L, seed = 11L) {
  set.seed(seed)
  z <- rnorm(n)
  mk <- function(a, l) {
    tr <- sample(5:15, n, replace = TRUE)
    s <- rbinom(n, tr, plogis(a + l * z))
    list(s = s, f = tr - s)
  }
  a <- mk(-0.3, 1); b <- mk(0, 0.8); c3 <- mk(0.3, 0.5)
  data.frame(
    id = factor(seq_len(n)),
    s1 = a$s, f1 = a$f, s2 = b$s, f2 = b$f, s3 = c3$s, f3 = c3$f
  )
}

test_that("wide traits(cbind()) matches the long-format cbind fit", {
  skip_on_cran()
  d <- .cbind_fixture()
  ctl <- gllvmTMBcontrol(se = FALSE, n_init = 1L)
  wide <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(cbind(s1, f1), cbind(s2, f2), cbind(s3, f3)) ~ 1 +
      latent(1 | id, d = 1, unique = FALSE),
    data = d, unit = "id", family = binomial(), control = ctl
  )))
  long <- do.call(rbind, lapply(1:3, function(j) data.frame(
    id = d$id, trait = factor(paste0("s", j), levels = paste0("s", 1:3)),
    succ = d[[paste0("s", j)]], fail = d[[paste0("f", j)]]
  )))
  long <- long[order(long$id, long$trait), ]
  lfit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | id, d = 1, unique = FALSE),
    data = long, unit = "id", trait = "trait", family = binomial(), control = ctl
  )))
  expect_equal(as.numeric(logLik(wide)), as.numeric(logLik(lfit)),
               tolerance = 1e-4)
})

test_that("cbind pairs: NA / zero-trial cells are dropped, expressions work", {
  d <- .cbind_fixture(30L)
  d$s1[2] <- NA
  d$s2[3] <- 0; d$f2[3] <- 0
  rw <- gllvmTMB:::rewrite_traits_lhs(
    traits(cbind(s1, f1), cbind(s2, f2), cbind(s3, f3 + 0)) ~ 1 +
      latent(1 | id, d = 1),
    data = d
  )
  expect_equal(rw$n_dropped, 2L)
  expect_equal(nrow(rw$data_long), 30L * 3L - 2L)
  expect_equal(rw$trait_cols, c("s1", "s2", "s3"))
  expect_identical(deparse(rw$formula_long[[2L]]),
                   "cbind(.succ_wide_, .fail_wide_)")
})

test_that("cbind in traits(): mixed and malformed forms are refused", {
  d <- .cbind_fixture(20L)
  expect_error(
    gllvmTMB:::rewrite_traits_lhs(
      traits(cbind(s1, f1), s2) ~ 1 + latent(1 | id, d = 1), data = d),
    class = "gllvmTMB_traits_cbind_mixed"
  )
  expect_error(
    gllvmTMB:::rewrite_traits_lhs(
      traits(cbind(s1), cbind(s2, f2)) ~ 1 + latent(1 | id, d = 1), data = d),
    class = "gllvmTMB_traits_cbind_arity"
  )
  expect_error(
    gllvmTMB:::rewrite_traits_lhs(
      traits(cbind(s1, f1), cbind(s1, f2)) ~ 1 + latent(1 | id, d = 1),
      data = d),
    class = "gllvmTMB_traits_cbind_names"
  )
})
