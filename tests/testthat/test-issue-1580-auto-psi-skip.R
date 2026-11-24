## #1580: auto-Psi skip notes must not blanket-label multinomial-only fits
## or expose internal parameter names.

psi_skip_text <- function(...) {
  paste(unname(gllvmTMB:::.auto_psi_skip_message(...)), collapse = "\n")
}

test_that("multinomial-only Psi skip uses a multinomial headline (#1580)", {
  msg <- gllvmTMB:::.auto_psi_skip_message(multinomial_labs = c("cat:2", "cat:3"))
  expect_match(msg[[1L]], "2 multinomial contrast traits", fixed = TRUE)
  text <- psi_skip_text(multinomial_labs = c("cat:2", "cat:3"))
  expect_false(grepl("single-trial binomial", text, fixed = TRUE))
  expect_false(grepl("binary / categorical-contrast", text, fixed = TRUE))
  expect_false(grepl("theta_diag_B", text, fixed = TRUE))
  expect_false(grepl("s_B", text, fixed = TRUE))
  expect_match(msg[[length(msg)]], "not estimated", fixed = TRUE)
})

test_that("binomial-only Psi skip does not use the multinomial blanket (#1580)", {
  msg <- gllvmTMB:::.auto_psi_skip_message(binomial_labs = "bin")
  expect_match(msg[[1L]], "1 single-trial binomial trait", fixed = TRUE)
  text <- psi_skip_text(binomial_labs = "bin")
  expect_false(grepl("binary / categorical-contrast", text, fixed = TRUE))
  expect_false(grepl("theta_diag_B", text, fixed = TRUE))
  expect_false(grepl("s_B", text, fixed = TRUE))
})

test_that("ordinal-only auto-Psi skip message has no internal parameter names (#1580)", {
  msg <- gllvmTMB:::.auto_psi_skip_message(ordinal_labs = c("ord1", "ord2"))
  expect_match(msg[[1L]], "2 single-observation ordinal traits", fixed = TRUE)
  text <- psi_skip_text(ordinal_labs = c("ord1", "ord2"))
  expect_false(grepl("theta_diag_B", text, fixed = TRUE))
  expect_false(grepl("s_B", text, fixed = TRUE))
})

test_that("explicit ordinal indep() warning text has no internal parameter names (#1580)", {
  skip_on_cran()
  set.seed(1580L)
  cuts <- list(vigour = c(0, 0.8), damage = c(0, 0.6))
  mu <- c(vigour = 0.3, damage = 0.2)
  dd <- expand.grid(
    site = seq_len(24L),
    rep = 1L,
    trait = names(cuts)
  )
  u <- matrix(stats::rnorm(24L * 2L, sd = 0.8), 24L, 2L)
  lia <- mu[as.character(dd$trait)] +
    u[cbind(dd$site, as.integer(dd$trait))] +
    stats::rnorm(nrow(dd))
  dd$value <- NA_integer_
  for (tr in names(cuts)) {
    rows <- dd$trait == tr
    dd$value[rows] <- findInterval(lia[rows], cuts[[tr]]) + 1L
  }
  dd$site <- factor(dd$site)
  dd$trait <- factor(dd$trait, levels = names(cuts))
  warns <- character()
  suppressMessages(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(
        value ~ 0 + trait + indep(0 + trait | site),
        data = dd,
        trait = "trait",
        unit = "site",
        family = gllvmTMB::ordinal_probit(),
        control = gllvmTMB::gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
      ),
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  )
  text <- paste(warns, collapse = "\n")
  expect_match(text, "not estimated", fixed = TRUE)
  expect_false(grepl("theta_diag_B", text, fixed = TRUE))
  expect_false(grepl("s_B", text, fixed = TRUE))
})