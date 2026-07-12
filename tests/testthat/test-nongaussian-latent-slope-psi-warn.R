# T1.2: the default diagonal-Psi companion of an augmented ordinary
# latent(1 + x | unit) reaction-norm slope is Gaussian-only (D-28). For a
# non-Gaussian family it is dropped (loadings-only). Before the fix this was
# silent; now it warns unless the user opts out with unique = FALSE.

make_pois_rr_data <- function(seed = 3L, n_ind = 24L, n_rep = 4L) {
  set.seed(seed)
  traits <- c("t1", "t2")
  grid <- expand.grid(
    individual = factor(seq_len(n_ind)),
    rep = seq_len(n_rep),
    trait = factor(traits)
  )
  grid$x <- as.numeric(scale(grid$rep))
  b0 <- rnorm(n_ind, 1.2, 0.4)[as.integer(grid$individual)]
  b1 <- rnorm(n_ind, 0.3, 0.2)[as.integer(grid$individual)]
  grid$value <- rpois(nrow(grid), exp(b0 + b1 * grid$x))
  grid
}

psi_re <- "Gaussian-only|Psi\\b.*companion"

test_that("non-Gaussian augmented latent() slope warns that Psi is dropped", {
  d <- make_pois_rr_data()
  expect_warning(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait + (0 + trait):x | individual, d = 1),
      data = d, trait = "trait", unit = "individual",
      family = poisson(), silent = TRUE
    )),
    regexp = psi_re
  )
})

test_that("unique = FALSE silences the non-Gaussian Psi-drop warning", {
  d <- make_pois_rr_data()
  ws <- character()
  withCallingHandlers(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait +
        latent(0 + trait + (0 + trait):x | individual, d = 1, unique = FALSE),
      data = d, trait = "trait", unit = "individual",
      family = poisson(), silent = TRUE
    )),
    warning = function(w) {
      ws <<- c(ws, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl(psi_re, ws)))
})
