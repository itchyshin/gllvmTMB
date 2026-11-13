## #1580: user-facing notes that named the wrong keyword or repeated
## themselves. Two items are pinned here:
##   - extract_Sigma() on a kernel_latent() tier advised a phylo_latent()
##     refit and talked about a "phylo-equivalent engine path";
##   - summary() on a latent(..., unique = FALSE) fit printed the
##     "Sigma_unit is latent-only" note three times per call.

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
