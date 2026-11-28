## refs #1937 — refuse phylo_latent when only one species is observed.

test_that("phylo_latent() refuses a single observed species", {
  skip_on_cran()
  labs <- paste0("sp", 1:8)
  C <- diag(8) + 0.2
  dimnames(C) <- list(labs, labs)
  df <- expand.grid(
    species = factor("sp1", levels = labs),
    trait = factor(c("t1", "t2")),
    site = factor(1:3),
    stringsAsFactors = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, vcv = C),
      data = df,
      unit = "site",
      family = gaussian()
    )),
    class = "gllvmTMB_phylo_insufficient_species"
  )
})