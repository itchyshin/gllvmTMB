## Kernel random slopes (Design 79 RE-surface arc).
## Strand 0 turned the silent kernel-slope mis-parse into a fail-loud. B1 then
## WIRED kernel_indep/kernel_dep random slopes: they route to the same augmented
## phylo_slope engine as animal_indep/dep, carrying `vcv = K` (dense-kernel =
## phylo with a supplied K), so kernel_*(1 + x | g) is byte-equivalent to
## phylo_*(1 + x | g, vcv = K). `||` comes free via the A0/A1/A2 markers.
## kernel_latent slopes are not yet wired -> still fail loud.

test_that("kernel_indep/kernel_dep route a random-slope bar to phylo_slope (B1)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  K <- diag(3)
  for (kw in c("kernel_indep", "kernel_dep")) {
    f <- stats::as.formula(sprintf("y ~ %s(1 + x | g, K = K)", kw))
    txt <- paste(deparse(gllvmTMB:::rewrite_canonical_aliases(f)), collapse = " ")
    expect_match(txt, "phylo_slope", fixed = TRUE, info = kw)
    expect_match(txt, ".phylo_dep_augmented = TRUE", fixed = TRUE, info = kw)
  }
  ## kernel_indep carries the block-diagonal marker; kernel_dep does not.
  expect_match(paste(deparse(gllvmTMB:::rewrite_canonical_aliases(
    y ~ kernel_indep(1 + x | g, K = K))), collapse = " "),
    ".indep_blockdiag = TRUE", fixed = TRUE)
})

test_that("kernel_latent still rejects a random-slope bar (deferred)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  K <- diag(3)
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(y ~ kernel_latent(1 + x | g, K = K)),
    regexp = "does not support this random-slope bar"
  )
})

test_that("intercept-only kernel keywords still route (no regression)", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  K <- diag(3)
  txt <- paste(deparse(
    gllvmTMB:::rewrite_canonical_aliases(y ~ kernel_indep(unit, K = K))
  ), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".kernel_mode = \"indep\"", fixed = TRUE)
})

## --- B1 recovery: kernel slope == phylo-with-K (heavy) -----------------------
test_that("kernel_indep/dep random slopes equal phylo_*(vcv = K) (B1, incl. ||)", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
  set.seed(13); n_sp <- 70L; n_rep <- 8L; T <- 3L
  tree <- ape::rcoal(n_sp); A <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(A)); sp <- rownames(A)
  rows <- list()
  bi <- LA %*% matrix(stats::rnorm(n_sp * T), n_sp, T) * 0.7
  bs <- LA %*% matrix(stats::rnorm(n_sp * T), n_sp, T) * 0.6
  for (i in seq_len(n_sp)) for (r in seq_len(n_rep)) {
    x <- stats::rnorm(1)
    for (t in seq_len(T)) rows[[length(rows) + 1L]] <- data.frame(
      species = sp[i], trait = paste0("t", t), x = x,
      value = bi[i, t] + x * bs[i, t] + stats::rnorm(1, 0, 0.3), stringsAsFactors = FALSE)
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp); df$trait <- factor(df$trait, levels = paste0("t", 1:3))
  kf <- function(mode, cp) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(sprintf("value ~ 0 + trait + kernel_%s(1 + x %s species, K = A, name = 'k')", mode, cp)),
    data = df, unit = "species", cluster = "species", family = stats::gaussian())))
  pf <- function(mode, cp) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    stats::as.formula(sprintf("value ~ 0 + trait + phylo_%s(1 + x %s species, vcv = A)", mode, cp)),
    data = df, unit = "species", cluster = "species", family = stats::gaussian())))
  for (spec in list(c("indep", "|"), c("indep", "||"), c("dep", "|"), c("dep", "||"))) {
    k <- kf(spec[1], spec[2]); p <- pf(spec[1], spec[2])
    expect_equal(k$opt$convergence, 0L, info = paste(spec, collapse = " "))
    expect_equal(as.numeric(stats::logLik(k)), as.numeric(stats::logLik(p)),
                 tolerance = 1e-6, info = paste(spec, collapse = " "))
  }
})
