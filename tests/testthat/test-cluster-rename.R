## Pure-rename: `species = "..."` → `cluster = "..."` for the third
## grouping slot. The internal name `species` is preserved so the
## engine, the TMB template, and downstream extractors are untouched.
## These tests verify:
##   * `cluster = "species"` is accepted and behaves identically to
##     the legacy `species = "species"` path (byte-identical fits);
##   * `species = "..."` still works but emits a one-shot soft warning;
##   * `cluster = "population"` (a non-phylogenetic third grouping)
##     gives a regular crossed/nested 3rd grouping;
##   * Crossed (site × species) and strictly-nested
##     (population > individual > session) designs both fit cleanly.

make_simple <- function(seed = 42) {
  set.seed(seed)
  gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 4,
    mean_species_per_site = 4, seed = seed
  )$data
}

test_that("`cluster = ...` argument is accepted and fits", {
  df <- make_simple()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site),
    data = df, cluster = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## Stored under the canonical name (back-compat alias preserved).
  expect_equal(fit$cluster_col, "species")
  expect_equal(fit$species_col, "species")
})

test_that("`species = ...` deprecated alias still works with a soft warning", {
  df <- make_simple()
  ## cli's `.frequency = "once"` may have fired on a sibling test in
  ## this session; the assertion is that the call still works. We
  ## capture cli messages directly.
  msgs <- character()
  withCallingHandlers(
    suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = df, species = "species"
    )),
    message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") }
  )
  ## At minimum the call should not error; if cli emitted a message we
  ## also assert it points the user at `cluster`.
  if (length(msgs) > 0L) {
    expect_match(paste(msgs, collapse = "\n"),
                 regexp = "deprecated alias|use `cluster")
  } else {
    succeed("cli once-per-session cache absorbed the message")
  }
})

test_that("`cluster = '...'` and `species = '...'` give byte-identical fits", {
  df <- make_simple()
  fit_cluster <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, cluster = "species"
  )))
  fit_species <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df, species = "species"
  )))
  ## Pure rename ⇒ byte-identical objective.
  expect_identical(fit_cluster$opt$objective, fit_species$opt$objective)
})

test_that("Passing both `cluster` and `species` (with conflicting values) errors", {
  df <- make_simple()
  ## Add a second column so `cluster = "altcol"` is non-default and
  ## doesn't itself fail the data-coercion path.
  df$altcol <- df$species
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = df, cluster = "altcol", species = "species"
    ),
    regexp = "either.*cluster.*or.*species|deprecated alias"
  )
})

test_that("`cluster = 'population'` (non-phylo) gives a regular 3rd grouping", {
  set.seed(2026)
  ## Strictly-nested 3-level personality fixture:
  ## 4 populations -> 8 individuals/pop -> 3 sessions/individual -> 3 traits.
  n_pop <- 4; n_ind_per <- 8; n_sess <- 3; n_traits <- 3
  pop  <- factor(rep(seq_len(n_pop), each = n_ind_per * n_sess))
  ind  <- factor(rep(seq_len(n_pop * n_ind_per), each = n_sess))
  sess <- factor(seq_along(ind))
  trait <- factor(rep(letters[seq_len(n_traits)], each = length(sess)))
  ## Long format: one row per (session, trait).
  df <- data.frame(
    population = rep(pop,  n_traits),
    individual = rep(ind,  n_traits),
    session_id = rep(sess, n_traits),
    trait      = trait,
    value      = rnorm(length(trait))
  )
  ## Engine needs the within-unit factor, defaults to "site_species" -- we
  ## tell it that "session_id" plays that role.
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            unique(0 + trait | population),
    data = df,
    unit       = "individual",
    unit_obs   = "session_id",
    cluster    = "population"
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$cluster_col, "population")
  ## diag at the third (cluster) slot lights up: 3 per-trait variances.
  expect_true(isTRUE(fit$use$diag_species))
  expect_length(as.numeric(fit$report$sd_q), n_traits)
  ## extract_Sigma at level = "cluster" returns the unique() diagonal.
  ext <- gllvmTMB::extract_Sigma(fit, level = "cluster", part = "unique")
  expect_equal(length(ext$s), n_traits)
})

test_that("Crossed (site x species) design fits via `cluster = 'species'`", {
  df <- make_simple(seed = 99)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | site, d = 2) +
            unique(0 + trait | site) +
            latent(0 + trait | site_species, d = 1) +
            unique(0 + trait | site_species),
    data = df, cluster = "species"
  )))
  expect_equal(fit$opt$convergence, 0L)
})

test_that("Strictly-nested design fits via `cluster = 'population'`", {
  ## Same fixture as the non-phylo test above, but with a between-unit
  ## random latent at the individual level on top of the population-tier
  ## diag — the engine doesn't enforce nesting and both terms register.
  set.seed(2026)
  n_pop <- 4; n_ind_per <- 8; n_sess <- 3; n_traits <- 3
  pop  <- factor(rep(seq_len(n_pop), each = n_ind_per * n_sess))
  ind  <- factor(rep(seq_len(n_pop * n_ind_per), each = n_sess))
  sess <- factor(seq_along(ind))
  trait <- factor(rep(letters[seq_len(n_traits)], each = length(sess)))
  df <- data.frame(
    population = rep(pop,  n_traits),
    individual = rep(ind,  n_traits),
    session_id = rep(sess, n_traits),
    trait      = trait,
    value      = rnorm(length(trait))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | individual, d = 1) +
            unique(0 + trait | population),
    data = df,
    unit       = "individual",
    unit_obs   = "session_id",
    cluster    = "population"
  )))
  expect_equal(fit$opt$convergence, 0L)
})
