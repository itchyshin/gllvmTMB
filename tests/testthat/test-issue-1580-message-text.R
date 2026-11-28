## #1580: user-facing notes that named the wrong keyword or repeated
## themselves. Two items are pinned here:
##   - extract_Sigma() on a kernel_latent() tier advised a phylo_latent()
##     refit and talked about a "phylo-equivalent engine path";
##   - summary() on a latent(..., unique = FALSE) fit printed the
##     "Sigma_unit is latent-only" note three times per call;
##   - the auto-Psi skip note for multinomial traits named internal TMB
##     parameters (`theta_diag_B[t]`, `s_B`) and listed trait kinds that the
##     fit did not contain.

collect_messages <- function(expr) {
  msgs <- character()
  value <- withCallingHandlers(
    expr,
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(value = value, messages = msgs)
}

kernel_1580_data <- function() {
  set.seed(1580)
  x <- seq(0, 1, length.out = 20)
  K <- exp(-abs(outer(x, x, "-")) / 0.1)
  dimnames(K) <- list(paste0("s", 1:20), paste0("s", 1:20))
  L <- t(chol(K))
  lambda <- c(0.8, 0.6, -0.5, 0.4)
  site_eff <- outer(drop(L %*% stats::rnorm(20)), lambda)
  dat <- expand.grid(
    trait = factor(paste0("y", 1:4)), visit = 1:3,
    site = factor(rownames(K), levels = rownames(K))
  )
  dat$obs <- factor(paste(dat$site, dat$visit, sep = "_"))
  dat$value <- site_eff[cbind(as.integer(dat$site), as.integer(dat$trait))] +
    stats::rnorm(nrow(dat), sd = 0.4)
  list(data = dat, K = K)
}

test_that(".summary_unique_messages() re-signals each distinct message once (#1580)", {
  got <- collect_messages(gllvmTMB:::.summary_unique_messages({
    message("a")
    message("b")
    message("a")
    message("a")
  }))
  expect_identical(got$messages, c("a\n", "b\n"))
})

test_that("extract_Sigma() on a kernel_latent() tier names kernel_latent() (#1580)", {
  skip_on_cran()
  d <- kernel_1580_data()
  K <- d$K
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(site, K = K, d = 1, name = "gradient"),
    data = d$data, trait = "trait", unit = "obs", cluster = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  S <- suppressMessages(extract_Sigma(fit, level = "gradient"))
  note <- paste(S$note, collapse = " ")
  expect_match(note, "kernel_latent(..., unique = TRUE)", fixed = TRUE)
  expect_match(note, "Kernel tier 'gradient' is currently latent-only",
               fixed = TRUE)
  expect_no_match(note, "phylo_latent", fixed = TRUE)
  expect_no_match(note, "phylo-equivalent", fixed = TRUE)
})

test_that("summary() prints the latent-only note once per call (#1580)", {
  skip_on_cran()
  d <- kernel_1580_data()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = d$data, trait = "trait", unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  got <- collect_messages(summary(fit))
  latent_only <- grepl("is latent-only", got$messages, fixed = TRUE)
  expect_identical(sum(latent_only), 1L)
  ## The advice no longer reads as if `unique = FALSE` were the default.
  note <- gsub("\\s+", " ", got$messages[latent_only])
  expect_match(note, "refit with `unique = TRUE`, the default for `latent()`",
               fixed = TRUE)
  ## The summary payload is still filled in.
  expect_false(is.null(got$value$Sigma_B))
})

test_that("auto-Psi skip note names only the kind of trait it skipped (#1580)", {
  header <- function(...) {
    msg <- gllvmTMB:::.auto_psi_skip_message(...)
    unname(msg)[[1L]]
  }
  multinomial_only <- header(multinomial_labs = c("cat:2", "cat:3"))
  expect_match(multinomial_only, "for 2 categorical-contrast traits",
               fixed = TRUE)
  expect_no_match(multinomial_only, "binary", fixed = TRUE)
  expect_no_match(multinomial_only, "ordinal", fixed = TRUE)

  expect_match(header(binomial_labs = "b"), "for 1 binary trait", fixed = TRUE)
  expect_no_match(header(binomial_labs = "b"), "categorical-contrast",
                  fixed = TRUE)
  ordinal_only <- header(ordinal_labs = c("o1", "o2"))
  expect_match(ordinal_only, "for 2 single-observation ordinal traits",
               fixed = TRUE)
  expect_no_match(ordinal_only, "binary", fixed = TRUE)

  ## A fit that skips more than one kind keeps the umbrella wording.
  expect_match(header(binomial_labs = "b", ordinal_labs = "o"),
               "for 2 binary / categorical-contrast / single-observation ordinal traits",
               fixed = TRUE)
})

test_that("auto-Psi skip note does not expose internal TMB parameter names (#1580)", {
  for (msg in list(
    gllvmTMB:::.auto_psi_skip_message(multinomial_labs = c("cat:2", "cat:3")),
    gllvmTMB:::.auto_psi_skip_message(binomial_labs = "b"),
    gllvmTMB:::.auto_psi_skip_message(ordinal_labs = "o"),
    gllvmTMB:::.auto_psi_skip_message(binomial_labs = "b",
                                      multinomial_labs = "cat:2",
                                      ordinal_labs = "o")
  )) {
    text <- paste(unname(msg), collapse = " ")
    expect_no_match(text, "theta_diag_B", fixed = TRUE)
    expect_no_match(text, "s_B", fixed = TRUE)
    expect_match(text, "no between-unit", fixed = TRUE)
  }
})

test_that("a Gaussian + multinomial fit prints the plain-language Psi skip note (#1580)", {
  skip_on_cran()
  set.seed(1580)
  N <- 60L
  Lam <- matrix(c(1.3, 0.4, 1.0, 0.6, -0.6, 0.9), 3, byrow = TRUE)
  u <- matrix(stats::rnorm(N * 2L), N, 2L) %*% t(Lam)
  yc <- vapply(seq_len(N), function(i) {
    p <- c(1, exp(u[i, 2]), exp(u[i, 3]))
    sample.int(3L, 1L, prob = p / sum(p))
  }, integer(1))
  dat <- rbind(
    data.frame(unit = seq_len(N), trait = "cat", family = "m", value = yc),
    data.frame(unit = seq_len(N), trait = "g", family = "g",
               value = u[, 1] + stats::rnorm(N, sd = 0.25))
  )
  dat$unit <- factor(dat$unit)
  dat$trait <- factor(dat$trait)
  dat$family <- factor(dat$family)
  fam <- list(g = gaussian(), m = multinomial())
  attr(fam, "family_var") <- "family"
  withr::local_options(rlib_message_verbosity = "verbose")
  freq_env <- getFromNamespace("message_freq_env", "rlang")
  ids <- "gllvmTMB-psi-skip-multinomial"
  rlang::env_unbind(freq_env, ids)
  withr::defer(rlang::env_unbind(freq_env, ids))

  got <- collect_messages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, family = fam, trait = "trait", unit = "unit", silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  skip_note <- gsub("\\s+", " ", paste(
    got$messages[grepl("Skipping the default between-unit", got$messages)],
    collapse = " "
  ))
  expect_match(skip_note, "for 2 categorical-contrast traits", fixed = TRUE)
  expect_match(skip_note, "cat:2, cat:3", fixed = TRUE)
  expect_no_match(skip_note, "theta_diag_B", fixed = TRUE)
  expect_no_match(skip_note, "s_B", fixed = TRUE)
  expect_no_match(skip_note, "binary", fixed = TRUE)
})
