#!/usr/bin/env Rscript

## Reproducible performance receipt for the two-tier mixed-family GLLVM path.
##
## This is an engineering benchmark, not a recovery study and not a substitute
## for Ayumi's BIRDBASE analysis. It intentionally retains the structural
## features that make that workflow costly: mixed families, an ordinary latent
## tier, and a phylogenetic latent tier. Results are written outside the repo by
## default so performance evidence never enters package source by accident.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default) {
  hit <- sub(paste0("^", name, "="), "", args[grepl(paste0("^", name, "="), args)])
  if (length(hit)) hit[[1L]] else default
}
out_dir <- arg_value("--out-dir", NULL)
if (is.null(out_dir)) {
  out_dir <- file.path(tempdir(), "gllvmtmb-performance-audit")
}
n_species <- as.integer(arg_value("--n-species", 20L))
n_traits <- as.integer(arg_value("--n-traits", 3L))
rank <- as.integer(arg_value("--rank", 1L))
if (n_species < 3L || n_traits < 3L || rank < 1L || rank > n_traits) {
  stop("Require n_species >= 3, n_traits >= 3, and 1 <= rank <= n_traits.", call. = FALSE)
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("ape", quietly = TRUE)) {
  stop("This benchmark requires the suggested package 'ape'.", call. = FALSE)
}

devtools::load_all(quiet = TRUE)

make_fixture <- function(seed = 20260724L, n_species, n_traits) {
  set.seed(seed)
  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- simulate_site_trait(
    ## Ayumi's all-species formula puts both latent tiers on `species`.
    ## One synthetic site therefore yields one row per (species, trait),
    ## matching that grouping rather than a crossed site-by-species design.
    n_sites = 1L,
    n_species = n_species,
    n_traits = n_traits,
    mean_species_per_site = n_species,
    sigma2_eps = 0.4,
    Lambda_B = matrix(0.6, nrow = n_traits, ncol = 1L),
    psi_B = rep(0.2, n_traits),
    Cphy = Cphy,
    sigma2_phy = rep(0.4, n_traits),
    seed = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  families <- c("gaussian", "binomial", "poisson")
  trait_families <- rep(families, length.out = n_traits)
  family_lookup <- setNames(trait_families, levels(df$trait))
  df$family <- factor(family_lookup[as.character(df$trait)],
                      levels = families)
  for (fam in families) {
    idx <- which(df$family == fam)
    value <- df$value[idx]
    df$value[idx] <- switch(fam,
      gaussian = value,
      binomial = as.integer((value - mean(value)) > 0),
      poisson = pmax(0L, as.integer(round(value - mean(value) + 2)))
    )
  }
  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"
  list(data = df, family = family_list, tree = tree)
}

fixture <- make_fixture(n_species = n_species, n_traits = n_traits)
formula <- value ~ 0 + trait +
  latent(0 + trait | species, d = rank, unique = TRUE) +
  phylo_latent(species, d = rank, tree = fixture$tree, unique = TRUE)

fit_one <- function(label, control) {
  started <- proc.time()[["elapsed"]]
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    formula,
    data = fixture$data,
    family = fixture$family,
    trait = "trait",
    unit = "species",
    cluster = "species",
    control = control,
    silent = TRUE
  )))
  elapsed <- proc.time()[["elapsed"]] - started
  list(label = label, fit = fit, elapsed_s = elapsed)
}

baseline <- fit_one(
  "one_start_bfgs",
  gllvmTMBcontrol(
    n_init = 1L,
    optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L)),
    se = FALSE
  )
)
five_start <- fit_one(
  "five_start_bfgs",
  gllvmTMBcontrol(
    n_init = 5L,
    init_jitter = 0.1,
    optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L)),
    se = FALSE
  )
)

profile_file <- file.path(out_dir, "warm_start_bfgs.Rprof")
Rprof(profile_file, interval = 0.01)
warm_start <- fit_one(
  "warm_start_bfgs",
  gllvmTMBcontrol(
    n_init = 1L,
    optimizer = "optim",
    optArgs = list(method = "BFGS", control = list(maxit = 1000L)),
    start_from = baseline$fit,
    se = FALSE
  )
)
Rprof(NULL)

## TMB-level attribution is more informative than Rprof's aggregated .Call
## sample: it splits the objective, gradient, sparse Hessian, and Cholesky
## operations at the fitted parameter vector. This is a local diagnostic, not
## an optimisation target in isolation.
tmb_benchmark <- TMB::benchmark(warm_start$fit$tmb_obj, n = 10L)
tmb_benchmark$operation <- rownames(tmb_benchmark)
rownames(tmb_benchmark) <- NULL

receipt <- do.call(rbind, lapply(
  list(baseline, five_start, warm_start),
  function(x) {
    history <- x$fit$restart_history
    data.frame(
      benchmark = x$label,
      total_elapsed_s = x$elapsed_s,
      restart = history$restart,
      restart_elapsed_s = history$elapsed_s,
      iterations = history$iterations,
      evaluations = history$evaluations,
      objective = history$objective,
      convergence = history$convergence,
      selected = history$selected,
      n_rows = nrow(fixture$data),
      n_species = nlevels(fixture$data$species),
      n_traits = nlevels(fixture$data$trait),
      rank = rank,
      stringsAsFactors = FALSE
    )
  }
))
write.csv(receipt, file.path(out_dir, "benchmark-receipt.csv"), row.names = FALSE)
write.csv(tmb_benchmark, file.path(out_dir, "tmb-operation-benchmark.csv"), row.names = FALSE)
saveRDS(summaryRprof(profile_file), file.path(out_dir, "warm-start-bfgs-rprof.rds"))
writeLines(capture.output(sessionInfo()), file.path(out_dir, "session-info.txt"))
message("Wrote benchmark receipt to: ", normalizePath(out_dir))
