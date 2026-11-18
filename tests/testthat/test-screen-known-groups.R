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

## Issue #1154 -- the one-hot test was WHOLE-GROUP only: a declared group
## containing a genuine one-hot subset plus an unrelated member reported
## PASS / known_group_checked, the identical "declaring a slightly-too-large
## group weakens the verdict" shape as the nesting defect fixed above.
## Fixed by a bounded exhaustive subset search (see SUBSET_MAX below).

## {A, B, C} is a genuine 3-way one-hot block; D is unrelated (varies
## independently of the A/B/C block by construction, and never sums with
## it to a constant).
.one_hot_subset_plus_unrelated_data <- function(n = 24) {
  i <- 0:(n - 1)
  b <- i %% 3
  A <- as.integer(b == 0)
  B <- as.integer(b == 1)
  C <- as.integer(b == 2)
  D <- as.integer(((i %/% 3) %% 2) == 1)
  data.frame(unit = factor(seq_len(n)), A = A, B = B, C = C, D = D)
}

test_that("known_groups: one-hot subset {A,B,C} plus unrelated D is certified (was silently PASS pre-fix)", {
  df <- .one_hot_subset_plus_unrelated_data()
  fmla <- traits(A, B, C, D) ~ 1 + latent(1 | unit, d = 1)

  ## Sanity: the WHOLE group does not sum to 1 (D breaks it), so the
  ## pre-fix whole-group-only test correctly reports FALSE here -- the
  ## defect is that it then falls through to PASS instead of finding the
  ## {A,B,C} subset.
  expect_false(all(abs(df$A + df$B + df$C + df$D - 1) < 1e-8))
  expect_true(all(abs(df$A + df$B + df$C - 1) < 1e-8))

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("A", "B", "C", "D"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]

  ## Must FAIL with a certified {A,B,C} = 1 subset, not PASS as
  ## known_group_checked.
  expect_true(any(kg$status == "FAIL"))
  expect_false(any(kg$type == "known_group_checked"))
  subset_rows <- kg[kg$type == "known_one_hot_subset", ]
  expect_equal(nrow(subset_rows), 1L)
  expect_true(grepl("A + B + C = 1", subset_rows$certificate, fixed = TRUE))
  expect_false(grepl("D", subset_rows$certificate, fixed = TRUE))
})

test_that("known_groups: two disjoint one-hot subsets inside one declared group are both certified and both minimal", {
  n <- 24
  i <- 0:(n - 1)
  ab <- i %% 2
  A <- as.integer(ab == 0)
  B <- as.integer(ab == 1)
  cde <- (i %/% 2) %% 3
  Cc <- as.integer(cde == 0)
  Dd <- as.integer(cde == 1)
  Ee <- as.integer(cde == 2)
  spare <- as.integer(((i %/% 6) %% 2) == 1)
  df <- data.frame(
    unit = factor(seq_len(n)),
    A = A, B = B, C = Cc, D = Dd, E = Ee, F = spare
  )
  fmla <- traits(A, B, C, D, E, F) ~ 1 + latent(1 | unit, d = 1)

  ## Sanity: whole group never sums to 1 (A+B=1, C+D+E=1, so the whole
  ## group sums to 2 + F), and neither the pair nor the triple alone
  ## equals the whole declared group.
  expect_false(all(abs(df$A + df$B + df$C + df$D + df$E + df$F - 1) < 1e-8))

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("A", "B", "C", "D", "E", "F"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]
  subset_rows <- kg[kg$type == "known_one_hot_subset", ]

  expect_equal(nrow(subset_rows), 2L)
  certs <- sort(subset_rows$certificate)
  expect_true(any(grepl("A + B = 1", certs, fixed = TRUE)))
  expect_true(any(grepl("C + D + E = 1", certs, fixed = TRUE)))
  ## Neither certificate names F or bleeds into the other block.
  expect_false(any(grepl("F", certs, fixed = TRUE)))
})

test_that("known_groups: minimality -- a one-hot subset's superset is not also reported", {
  df <- .one_hot_subset_plus_unrelated_data()
  fmla <- traits(A, B, C, D) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("A", "B", "C", "D"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]
  subset_rows <- kg[kg$type == "known_one_hot_subset", ]

  ## Exactly one certificate (the minimal {A,B,C}); the superset
  ## {A,B,C,D} -- which does NOT sum to 1 here, but the point of this test
  ## is that even when a superset happens to also test true it must not
  ## be reported once a smaller subset already covers it.
  expect_equal(nrow(subset_rows), 1L)
  expect_true(grepl("A + B + C = 1", subset_rows$certificate, fixed = TRUE))
  ## No certificate lists all four traits.
  expect_false(any(vapply(
    strsplit(subset_rows$traits, ", "),
    function(tr) setequal(tr, c("A", "B", "C", "D")),
    logical(1L)
  )))
})

test_that("known_groups: whole-group one-hot still reports known_one_hot exactly as before (regression guard)", {
  df <- .three_one_hot_blocks_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g1 = c("A", "B", "C"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]
  expect_equal(nrow(kg), 1L)
  expect_equal(kg$type, "known_one_hot")
  expect_equal(kg$status, "FAIL")
  expect_equal(kg$certificate, "A + B + C = 1")
  expect_equal(
    kg$message,
    sprintf(
      "declared group '%s' (%s) sums to exactly 1 on every complete row (%d rows): this is one categorical variable, not %d independent binary traits",
      "g1", "A, B, C", nrow(df), 3L
    )
  )
})

test_that("known_groups: a declared group larger than SUBSET_MAX gets an explicit not-attempted message, not a silent PASS", {
  ## 13 mutually independent, non-constant, non-nested binary traits (no
  ## whole-group one-hot, no pairwise containment) -- constructed once with
  ## a fixed seed and verified analytically below.
  set.seed(42)
  n <- 60
  k <- 13
  Y <- matrix(0L, n, k)
  for (j in seq_len(k)) {
    Y[, j] <- rbinom(n, 1, 0.3 + 0.03 * j)
  }
  colnames(Y) <- paste0("t", seq_len(k))
  ## Sanity: not whole-group one-hot, no pairwise nesting, none constant.
  expect_false(all(abs(rowSums(Y) - 1) < 1e-8))
  expect_true(all(apply(Y, 2, function(x) length(unique(x))) > 1))
  for (a in seq_len(k)) {
    for (b in seq_len(k)) {
      if (a != b) expect_false(all(Y[, a] >= Y[, b]))
    }
  }

  df <- data.frame(unit = factor(seq_len(n)))
  for (cn in colnames(Y)) df[[cn]] <- Y[, cn]
  fmla <- as.formula(paste0(
    "traits(", paste(colnames(Y), collapse = ", "), ") ~ 1 + latent(1 | unit, d = 1)"
  ))

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = colnames(Y))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]

  expect_false(any(kg$type == "known_group_checked"))
  expect_true(any(kg$type == "known_group_subset_not_attempted"))
  not_attempted <- kg[kg$type == "known_group_subset_not_attempted", ]
  expect_true(grepl("not attempted", not_attempted$message, fixed = TRUE))
  expect_true(grepl("13", not_attempted$message, fixed = TRUE))
})

test_that("known_groups: a subset that is one-hot only because its members are constant is not certified (degenerate guard)", {
  n <- 20
  df <- data.frame(
    unit = factor(seq_len(n)),
    const1 = 1,
    const0 = 0,
    other = rep(c(0, 1), length.out = n)
  )
  fmla <- traits(const1, const0, other) ~ 1 + latent(1 | unit, d = 1)

  ## const1 + const0 == 1 on every row, but only because both are
  ## constant -- not a genuine relationship.
  expect_true(all(abs(df$const1 + df$const0 - 1) < 1e-8))

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(g = c("const1", "const0", "other"))
  ))
  deps <- screen_table(scr, "response_dependencies")
  kg <- deps[deps$scope == "known_group", ]
  expect_false(any(kg$type == "known_one_hot_subset"))
  expect_false(any(kg$type == "known_one_hot"))
})

## Extends .three_one_hot_blocks_data() with an unrelated tenth trait X, so
## a subset one-hot certificate inside a padded declared group can be
## tested against a matrix the AUTOMATIC search cannot resolve alone: with
## three simultaneous one-hot blocks present, .screen_response_affine_certificates()
## documented-ly resolves NONE of them (see the "three disjoint one-hot
## blocks" test above) -- so `unresolved` reaching 0 here can only happen
## via the known_groups certification path, not as a side effect of the
## automatic per-matrix search.
.three_one_hot_blocks_plus_spare_data <- function(n = 30) {
  df <- .three_one_hot_blocks_data(n)
  i <- 0:(n - 1)
  df$X <- as.integer(((i %/% 5) %% 2) == 1)
  df
}

test_that("known_groups: unresolved count integration -- a one-hot subset inside a larger declared group resolves it to 0", {
  ## The three blocks A/B/C, D/E/F, G/H/I are the only affine dependencies
  ## (deficiency 3); X is unrelated. g1 is declared TOO LARGE (padded with
  ## X, so it is not itself whole-group one-hot); the {A,B,C} subset must
  ## still be found and credited so unresolved reaches 0 -- pre-fix it does
  ## not, because .screen_known_group_rows() never emits a vector for a
  ## subset of a declared group that fails the whole-group one-hot test.
  df <- .three_one_hot_blocks_plus_spare_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I, X) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(
      g1 = c("A", "B", "C", "X"),
      g2 = c("D", "E", "F"),
      g3 = c("G", "H", "I")
    )
  ))
  deps <- screen_table(scr, "response_dependencies")
  unresolved <- deps[deps$type == "unresolved", ]
  expect_equal(nrow(unresolved), 0L)
  kg <- deps[deps$scope == "known_group", ]
  expect_equal(sum(kg$type == "known_one_hot_subset"), 1L)
  expect_equal(sum(kg$type == "known_one_hot"), 2L)
})

test_that("known_groups: a subset certificate and a whole-group certificate of the SAME dependency do not double-credit rank", {
  ## g1 declares the whole {A,B,C} block (known_one_hot); g1_padded
  ## declares the identical relation padded with the unrelated X
  ## (known_one_hot_subset). Both describe the SAME null vector -- the
  ## rank-of-span computation must not credit it twice, and unresolved
  ## must not go negative.
  df <- .three_one_hot_blocks_plus_spare_data()
  fmla <- traits(A, B, C, D, E, F, G, H, I, X) ~ 1 + latent(1 | unit, d = 1)

  scr <- suppressWarnings(screen_gllvmTMB(
    fmla,
    data = df, unit = "unit", family = binomial(),
    known_groups = list(
      g1 = c("A", "B", "C"),
      g1_padded = c("A", "B", "C", "X"),
      g2 = c("D", "E", "F"),
      g3 = c("G", "H", "I")
    )
  ))
  deps <- screen_table(scr, "response_dependencies")
  unresolved <- deps[deps$type == "unresolved", ]
  expect_equal(nrow(unresolved), 0L)
  kg <- deps[deps$scope == "known_group", ]
  expect_equal(sum(kg$type == "known_one_hot"), 3L)
  expect_equal(sum(kg$type == "known_one_hot_subset"), 1L)
})

test_that("known_groups: the nesting-vs-undeclared-dependency trap test still passes unchanged (rank credit regression guard)", {
  ## Re-run of the existing trap test above to confirm the subset-search
  ## change does not disturb it: a declared nesting group must still
  ## contribute nothing to the certified null-vector span.
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
