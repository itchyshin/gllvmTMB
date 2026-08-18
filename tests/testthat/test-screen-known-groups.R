## Regression tests for a known_groups= defect reported by @Ayumi-495
## against PR #1123 (screen_gllvmTMB()):
##
## Defect 1 -- a declared group of 3+ traits whose containment relations
## form a PARTIAL order (one broad trait containing two mutually
## incomparable narrower ones) was checked only as a single total chain
## (declared order, or its reverse) and silently PASSED
## known_group_checked instead of FAILing known_nesting.
##
## A second, related defect (the "unresolved" affine-dependency count
## ignoring declared known_groups certificates) and a third defect found
## while fixing it (a typo'd trait name silently accepted whenever the
## check itself is infeasible for the data) are covered further down in
## this file, added in a follow-up commit.

test_that("known_groups: declared pairwise, each FAILs known_nesting", {
  ## Her real case, one relation at a time: realm_water >= realm_freshwater
  ## and realm_water >= realm_marine, both exact containments. This passed
  ## before the fix and must keep passing after it.
  n <- 24
  df <- data.frame(unit = factor(seq_len(n)))
  df$realm_water <- rep(c(1, 1, 1, 0), length.out = n)
  df$realm_freshwater <- rep(c(1, 0, 0, 0), length.out = n)
  df$realm_marine <- rep(c(0, 1, 0, 0), length.out = n)
  fmla <- traits(realm_water, realm_freshwater, realm_marine) ~
    1 + latent(1 | unit, d = 1)

  s1 <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("realm_water", "realm_freshwater"))
  ))
  kg1 <- screen_table(s1, "response_dependencies")
  kg1 <- kg1[kg1$scope == "known_group", ]
  expect_equal(kg1$type, "known_nesting")
  expect_equal(kg1$status, "FAIL")

  s2 <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("realm_water", "realm_marine"))
  ))
  kg2 <- screen_table(s2, "response_dependencies")
  kg2 <- kg2[kg2$scope == "known_group", ]
  expect_equal(kg2$type, "known_nesting")
  expect_equal(kg2$status, "FAIL")
})

test_that("known_groups: declared as a trio, a partial order still FAILs known_nesting naming both relations", {
  ## Ayumi-495's actual report: freshwater and marine are each contained in
  ## water but are mutually incomparable, so the trio is a partial order,
  ## not a chain. Pre-fix this returned PASS / known_group_checked.
  n <- 24
  df <- data.frame(unit = factor(seq_len(n)))
  df$realm_water <- rep(c(1, 1, 1, 0), length.out = n)
  df$realm_freshwater <- rep(c(1, 0, 0, 0), length.out = n)
  df$realm_marine <- rep(c(0, 1, 0, 0), length.out = n)
  fmla <- traits(realm_water, realm_freshwater, realm_marine) ~
    1 + latent(1 | unit, d = 1)

  ## No hidden affine dependency in this construction: some rows have
  ## water == 1 with both children 0, so water != freshwater + marine
  ## exactly, keeping this a pure containment (inequality) case.
  M <- cbind(1, df$realm_water, df$realm_freshwater, df$realm_marine)
  tol <- sqrt(.Machine$double.eps) * max(dim(M))
  expect_equal(ncol(M) - qr(M, tol = tol)$rank, 0L)

  s3 <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(realm = c("realm_water", "realm_freshwater", "realm_marine"))
  ))
  kg3 <- screen_table(s3, "response_dependencies")
  kg3 <- kg3[kg3$scope == "known_group", ]
  expect_equal(kg3$type, "known_nesting")
  expect_equal(kg3$status, "FAIL")
  expect_true(grepl("realm_water >= realm_freshwater", kg3$certificate, fixed = TRUE))
  expect_true(grepl("realm_water >= realm_marine", kg3$certificate, fixed = TRUE))
})

test_that("known_groups: a genuine chain of 3 still reports the chain wording (regression guard)", {
  n <- 16
  df <- data.frame(unit = factor(seq_len(n)))
  df$a <- rep(c(1, 1, 1, 0), length.out = n)
  df$b <- rep(c(1, 1, 0, 0), length.out = n)
  df$c <- rep(c(1, 0, 0, 0), length.out = n)
  fmla <- traits(a, b, c) ~ 1 + latent(1 | unit, d = 1)

  scr <- screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(chain = c("a", "b", "c"))
  )
  kg <- screen_table(scr, "response_dependencies")
  kg <- kg[kg$scope == "known_group", ]
  expect_equal(kg$type, "known_nesting")
  expect_equal(kg$status, "FAIL")
  expect_equal(kg$certificate, "a >= b >= c")
  expect_true(grepl("chain", kg$message, fixed = TRUE))
})

test_that("known_groups: a trio with no containment and no one-hot still PASSes known_group_checked", {
  ## Guards against the pairwise-containment fix turning every declared
  ## group into a nesting FAIL.
  df <- data.frame(unit = factor(seq_len(8)))
  df$x <- c(1, 0, 1, 0, 1, 0, 1, 0)
  df$y <- c(0, 1, 1, 0, 0, 1, 1, 0)
  df$z <- c(1, 0, 0, 1, 0, 1, 1, 0)
  fmla <- traits(x, y, z) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("x", "y", "z"))
  ))
  kg <- screen_table(scr, "response_dependencies")
  kg <- kg[kg$scope == "known_group", ]
  expect_equal(kg$type, "known_group_checked")
  expect_equal(kg$status, "PASS")
})

test_that("known_groups: an all-constant group of 3 still reports the degenerate message, not a vacuous FAIL", {
  df <- data.frame(
    unit = factor(seq_len(20)),
    c0 = 0, c1 = 0, c2 = 0,
    other = rep(c(0, 1), length.out = 20)
  )
  fmla <- traits(c0, c1, c2, other) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("c0", "c1", "c2"))
  ))
  kg <- screen_table(scr, "response_dependencies")
  kg <- kg[kg$scope == "known_group", ]
  expect_equal(kg$type, "known_group_degenerate")
  expect_equal(kg$status, "PASS")
})
