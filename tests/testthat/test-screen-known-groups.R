## Regression tests for two known_groups= defects reported by @Ayumi-495
## against PR #1123 (screen_gllvmTMB()), and a third found while fixing the
## second:
##
## Defect 1 -- a declared group of 3+ traits whose containment relations
## form a PARTIAL order (one broad trait containing two mutually
## incomparable narrower ones) was checked only as a single total chain
## (declared order, or its reverse) and silently PASSED
## known_group_checked instead of FAILing known_nesting.
##
## Defect 2 -- the automatic affine-rank screen's "N further exact affine
## dependencies ... unresolved" count never subtracted the one-hot
## certificates a user supplied via known_groups, even when every
## remaining dependency was correctly declared and certified. The fix
## takes the RANK of the pooled certified null-vector span rather than
## subtracting row counts, so declaring the same dependency under two
## names cannot under-report a genuinely unresolved dependency, and a
## declared nesting relation (an inequality, not an exact affine relation)
## never reduces the count.
##
## Correction C -- a typo'd trait name in known_groups was silently
## accepted whenever the affine/known-group check itself was infeasible
## for the data (info$ok == FALSE), because the name validation ran after
## that early return.

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

## --- Data shared by the unresolved-count tests: three disjoint one-hot
## blocks (A,B,C / D,E,F / G,H,I), each a genuinely independent 3-way
## categorical variable. cbind(1, A..I) has deficiency exactly 3, and (per
## the automatic search's own documented limitation) the automatic
## certificate finder resolves NONE of them when all three are present
## simultaneously -- so with no known_groups declared, "unresolved" is 3,
## matching Ayumi-495's report.
.three_one_hot_blocks_data <- function(n = 30) {
  i <- 0:(n - 1)
  b1 <- i %% 3
  b2 <- (i %/% 3) %% 3
  b3 <- (i %/% 9) %% 3
  mkonehot <- function(idx, k) {
    m <- matrix(0, nrow = length(idx), ncol = k)
    for (j in seq_along(idx)) m[j, idx[j] + 1] <- 1
    m
  }
  A <- mkonehot(b1, 3)
  colnames(A) <- c("A", "B", "C")
  D <- mkonehot(b2, 3)
  colnames(D) <- c("D", "E", "F")
  G <- mkonehot(b3, 3)
  colnames(G) <- c("G", "H", "I")
  Y <- cbind(A, D, G)
  df <- data.frame(unit = factor(seq_len(n)))
  for (cn in colnames(Y)) df[[cn]] <- Y[, cn]
  df
}

test_that("known_groups: three disjoint one-hot blocks -- unresolved is 3 undeclared, 0 when all three are certified", {
  df <- .three_one_hot_blocks_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I) ~ 1 + latent(1 | unit, d = 1)

  scr_none <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial()
  ))
  deps_none <- screen_table(scr_none, "response_dependencies")
  unresolved_none <- deps_none[deps_none$type == "unresolved", ]
  expect_equal(nrow(unresolved_none), 1L)
  expect_true(grepl("^3 further", unresolved_none$message))

  scr_all <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(
      g1 = c("A", "B", "C"),
      g2 = c("D", "E", "F"),
      g3 = c("G", "H", "I")
    )
  ))
  deps_all <- screen_table(scr_all, "response_dependencies")
  expect_equal(nrow(deps_all[deps_all$type == "unresolved", ]), 0L)
  kg_all <- deps_all[deps_all$scope == "known_group", ]
  expect_equal(nrow(kg_all), 3L)
  expect_true(all(kg_all$type == "known_one_hot"))
})

test_that("known_groups: 2 declared one-hot blocks + 1 undeclared -- unresolved is exactly 1", {
  df <- .three_one_hot_blocks_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g1 = c("A", "B", "C"), g2 = c("D", "E", "F"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  unresolved <- deps[deps$type == "unresolved", ]
  expect_equal(nrow(unresolved), 1L)
  expect_true(grepl("^1 further", unresolved$message))
})

test_that("known_groups: the same one-hot block declared twice under two names does not go negative or hide dependencies", {
  ## The rank-of-certified-span fix must not double-subtract a relation
  ## declared (or covered) twice: a count-based
  ## `unresolved <- deficiency - length(certs) - length(known_group_rows)`
  ## would.
  df <- .three_one_hot_blocks_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(
      g1 = c("A", "B", "C"),
      g1_dup = c("A", "B", "C"),
      g2 = c("D", "E", "F"),
      g3 = c("G", "H", "I")
    )
  ))
  deps <- screen_table(scr, "response_dependencies")
  expect_equal(nrow(deps[deps$type == "unresolved", ]), 0L)
  kg <- deps[deps$scope == "known_group", ]
  expect_equal(nrow(kg), 4L)
  expect_true(all(kg$type == "known_one_hot"))
})

test_that("known_groups: a declared nesting group must NOT be credited against a genuine undeclared affine dependency", {
  ## The dangerous case: a nesting/containment relation is an INEQUALITY,
  ## not an exact affine (equality) relation, so it must contribute 0 to
  ## the certified null-vector span. A naive fix that subtracts one unit
  ## of deficiency per declared known_groups row (regardless of type)
  ## would wrongly zero out the genuinely unresolved G/H/I block below.
  n <- 36
  i <- 0:(n - 1)

  wf <- i %% 4
  water <- ifelse(wf %in% c(0, 1, 2), 1, 0)
  freshwater <- ifelse(wf == 0, 1, 0)
  marine <- ifelse(wf == 1, 1, 0)

  b1 <- i %% 3
  b2 <- (i %/% 3) %% 3
  b3 <- (i %/% 9) %% 3
  mkonehot <- function(idx, k) {
    m <- matrix(0, nrow = length(idx), ncol = k)
    for (j in seq_along(idx)) m[j, idx[j] + 1] <- 1
    m
  }
  A <- mkonehot(b1, 3)
  colnames(A) <- c("A", "B", "C")
  D <- mkonehot(b2, 3)
  colnames(D) <- c("D", "E", "F")
  G <- mkonehot(b3, 3)
  colnames(G) <- c("G", "H", "I")

  Y <- cbind(water = water, freshwater = freshwater, marine = marine, A, D, G)
  df <- data.frame(unit = factor(seq_len(n)))
  for (cn in colnames(Y)) df[[cn]] <- Y[, cn]

  fmla <- traits(water, freshwater, marine, A, B, C, D, E, F, G, H, I) ~
    1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(
      realm = c("water", "freshwater", "marine"),
      g1 = c("A", "B", "C"),
      g2 = c("D", "E", "F")
    )
  ))
  deps <- screen_table(scr, "response_dependencies")

  realm_row <- deps[deps$scope == "known_group" & deps$group == "realm", ]
  expect_equal(realm_row$type, "known_nesting")
  expect_equal(realm_row$status, "FAIL")

  unresolved <- deps[deps$type == "unresolved", ]
  expect_equal(nrow(unresolved), 1L)
  expect_true(grepl("^1 further", unresolved$message))
})

test_that("known_groups: a typo'd trait name aborts even when the check itself is infeasible for the data", {
  ## Correction C -- validation of names must run BEFORE the info$ok gate.
  ## Duplicate unit-trait rows make the affine/known-group check infeasible
  ## (info$ok == FALSE) while leaving the trait column, and its levels,
  ## intact.
  n <- 20
  df <- data.frame(
    unit = factor(rep(seq_len(10), each = 2)),
    x = rep(c(0, 1), length.out = n),
    y = rep(c(1, 0), length.out = n)
  )
  fmla <- traits(x, y) ~ 1 + latent(1 | unit, d = 1)

  ## A group naming only real traits is accepted (and reported
  ## NOT_CHECKED, since the affine check itself is infeasible here).
  scr_ok <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("x", "y"))
  ))
  deps_ok <- screen_table(scr_ok, "response_dependencies")
  kg_ok <- deps_ok[deps_ok$scope == "known_group", ]
  expect_equal(kg_ok$type, "not_checked")
  expect_equal(kg_ok$status, "NOT_CHECKED")

  ## A typo'd trait name must still abort.
  expect_error(
    suppressWarnings(screen_gllvmTMB(
      fmla,
      data = df, unit = "unit", family = binomial(),
      known_groups = list(g = c("x", "z_typo"))
    )),
    class = "rlang_error"
  )
})
