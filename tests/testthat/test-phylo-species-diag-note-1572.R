## #1572: the once-per-session note for a species-level phylogenetic term plus
## indep(0 + trait | species) at unit != species. It must not name a keyword the
## user did not write, recommend indep() to a user who already used it, or print
## internal engine slot names.

test_that("phylo + indep(species) at unit != species note is plain and keyword-neutral (#1572)", {
  skip_if_not_installed("ape")
  set.seed(1572)
  n_sp <- 20L; n_ind <- 3L; n_tr <- 3L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  df <- expand.grid(trait = factor(paste0("t", seq_len(n_tr))),
                    individual = seq_len(n_ind),
                    species = tree$tip.label)
  df$species <- factor(df$species, levels = tree$tip.label)
  df$ind_id <- interaction(df$species, df$individual)
  df$value <- rnorm(nrow(df))

  ## The note is shown once per session; reset it so this test sees it.
  rlang::env_unbind(getFromNamespace("message_freq_env", "rlang"),
                    "gllvmTMB-phylo-q-decomposition-inform")

  msgs <- character()
  withCallingHandlers(
    suppressWarnings(try(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        phylo_latent(species, d = 1, unique = TRUE, vcv = Cphy) +
        indep(0 + trait | species),
      data = df, trait = "trait", unit = "ind_id", cluster = "species",
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L)
    ), silent = TRUE)),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  note <- grep("non-phylogenetic variance", msgs, value = TRUE)
  expect_length(note, 1L)
  expect_false(grepl("phylo_indep", note, fixed = TRUE))
  expect_false(grepl("q_sp", note, fixed = TRUE))
  expect_false(grepl("p_it", note, fixed = TRUE))
  expect_false(grepl("Use `indep", note, fixed = TRUE))
  expect_match(note, "indep(0 + trait | species)", fixed = TRUE)
})
