## Curie-nb2: fenced NB2 LA-MSPL tape (Wave 1).
##
## Public estimator="mspl" must still error for nbinom2(). The registry
## cell stays excluded — never planned, never admitted. Poisson being
## planned (or even publicly callable) does not transfer to NB2.
##
## The C++ source-pin is allowed RED until the GLM-outer atom exists.
## Do not treat a Poisson tape as evidence that NB2 is callable.

.mspl_nb2_tiny <- function() {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(0:3, length.out = n_site * n_trait)
  )
}

.mspl_nb2_form <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

.mspl_nb2_cpp_text <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  installed <- system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(candidates, installed)
  }
  cpp_path <- candidates[file.exists(candidates)][1L]
  testthat::skip_if(
    is.na(cpp_path),
    "gllvmTMB.cpp source file is not available in this test context."
  )
  paste(readLines(cpp_path, warn = FALSE), collapse = "\n")
}

.mspl_nb2_registry_cell <- function() {
  row <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "nbinom2",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  if (!is.null(row)) {
    return(row)
  }
  ## Excluded rows may carry a suffix on cell_id
  ## (nbinom2:log:ordinary:q1:nbinom2). Lookup is exact; the cell is
  ## still the ordinary q=1 NB2 fence.
  tbl <- gllvmTMB:::.gllvmTMB_mspl_registry()
  want <- gllvmTMB:::.gllvmTMB_mspl_registry_cell_id(
    "nbinom2", "log", "ordinary", 1L
  )
  hits <- tbl[
    tbl$family == "nbinom2" &
      tbl$link == "log" &
      tbl$structure == "ordinary" &
      tbl$q == 1L,
    ,
    drop = FALSE
  ]
  if (!nrow(hits)) {
    hits <- tbl[startsWith(tbl$cell_id, want), , drop = FALSE]
  }
  if (!nrow(hits)) {
    return(NULL)
  }
  hits[1L, , drop = FALSE]
}

test_that("public nbinom2 estimator=mspl still errors at the fence", {
  dat <- .mspl_nb2_tiny()
  expect_error(
    gllvmTMB(
      .mspl_nb2_form,
      data = dat,
      family = nbinom2(),
      estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
})

test_that("nbinom2 ordinary q=1 registry cell stays excluded", {
  row <- .mspl_nb2_registry_cell()
  expect_false(is.null(row))
  expect_identical(row$status, "excluded")

  tbl <- gllvmTMB:::.gllvmTMB_mspl_registry()
  nb2 <- tbl[tbl$family == "nbinom2", , drop = FALSE]
  expect_gt(nrow(nb2), 0L)
  expect_true(all(nb2$status == "excluded"))
  expect_false(any(nb2$status == "planned"))
  expect_false(any(nb2$status == "admitted"))
})

test_that("C++ source pins NB2 family_id 5 and W=mu*phi/(phi+mu)", {
  cpp <- .mspl_nb2_cpp_text()
  expect_match(
    cpp,
    "family_id == 5",
    info = "NB2 GLM-outer tape must dispatch on family_id == 5"
  )
  expect_true(
    grepl("mu\\s*\\*\\s*phi\\s*/\\s*\\(\\s*phi\\s*\\+\\s*mu\\s*\\)", cpp) ||
      grepl("W\\s*=\\s*mu\\s*\\*\\s*phi\\s*/\\s*\\(\\s*phi\\s*\\+\\s*mu\\s*\\)", cpp) ||
      grepl("W\\s*=\\s*mu\\s*\\*\\s*phi\\s*/\\s*\\(phi\\s*\\+\\s*mu\\)", cpp),
    info = "NB2 atom must name W = mu * phi / (phi + mu) (or W=mu*phi/(phi+mu))"
  )
})

test_that("Poisson planned does not make nbinom2 admitted or publicly callable", {
  pois <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "poisson",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  if (!is.null(pois)) {
    expect_true(pois$status %in% c("planned", "admitted"))
    expect_false(identical(pois$status, "excluded"))
  }

  tbl <- gllvmTMB:::.gllvmTMB_mspl_registry()
  expect_false(any(tbl$family == "nbinom2" & tbl$status == "admitted"))
  expect_false(any(tbl$family == "nbinom2" & tbl$status == "planned"))

  nb2 <- .mspl_nb2_registry_cell()
  expect_false(is.null(nb2))
  expect_identical(nb2$status, "excluded")
  expect_false(identical(nb2$status, "admitted"))

  dat <- .mspl_nb2_tiny()
  expect_error(
    gllvmTMB(
      .mspl_nb2_form,
      data = dat,
      family = nbinom2(),
      estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
})
