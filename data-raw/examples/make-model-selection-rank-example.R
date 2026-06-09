## data-raw/examples/make-model-selection-rank-example.R
## ======================================================
## Regenerate inst/extdata/examples/model-selection-rank-example.rds.
##
## The RDS stores a portable teaching fixture for latent-rank model
## comparison: long data, wide data, known Gaussian truth, formulas, fit
## arguments, story, and an alignment table. It deliberately does not
## store fitted TMB objects.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-model-selection-rank-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path(
  "inst",
  "extdata",
  "examples",
  "model-selection-rank-example.rds"
)

seed <- 20260609L
set.seed(seed)

n_individuals <- 120L
trait_names <- c("length", "mass", "wing", "tarsus", "bill")
n_traits <- length(trait_names)
d_true <- 2L

Lambda <- matrix(c(
  0.9,  0.1,
  1.0,  0.2,
  0.8, -0.4,
  0.7, -0.5,
  0.6,  0.6
), nrow = n_traits, ncol = d_true, byrow = TRUE,
dimnames = list(trait_names, c("size", "shape")))

psi <- c(
  length = 0.15,
  mass = 0.10,
  wing = 0.20,
  tarsus = 0.12,
  bill = 0.18
)

scores <- matrix(stats::rnorm(n_individuals * d_true),
                 nrow = n_individuals, ncol = d_true)
unique_error <- sapply(
  seq_len(n_traits),
  function(t) stats::rnorm(n_individuals, sd = sqrt(psi[t]))
)

Y <- scores %*% t(Lambda) + unique_error
rownames(Y) <- as.character(seq_len(n_individuals))
colnames(Y) <- trait_names

data_wide <- data.frame(
  individual = factor(seq_len(n_individuals)),
  Y,
  check.names = FALSE
)

data_long <- data.frame(
  individual = factor(rep(seq_len(n_individuals), each = n_traits)),
  trait = factor(rep(trait_names, n_individuals), levels = trait_names),
  value = as.vector(t(Y))
)

Psi <- diag(psi, n_traits, n_traits)
dimnames(Psi) <- list(trait_names, trait_names)
Sigma <- Lambda %*% t(Lambda) + Psi
R <- stats::cov2cor(Sigma)
shared_var <- diag(Lambda %*% t(Lambda))
communality <- shared_var / diag(Sigma)

formula_long <- value ~ 0 + trait +
  latent(0 + trait | individual, d = 2) +
  unique(0 + trait | individual)

formula_wide <- traits(length, mass, wing, tarsus, bill) ~ 1 +
  latent(1 | individual, d = 2) +
  unique(1 | individual)

rank_candidates <- data.frame(
  d = 0:3,
  formula_label = c(
    "unique(0 + trait | individual)",
    "latent(..., d = 1) + unique(...)",
    "latent(..., d = 2) + unique(...)",
    "latent(..., d = 3) + unique(...)"
  )
)

estimands <- data.frame(
  trait = trait_names,
  shared_variance = unname(shared_var),
  unique_variance = unname(psi),
  total_variance = unname(diag(Sigma)),
  communality = unname(communality)
)

alignment <- data.frame(
  symbol = c("Sigma", "Lambda", "Psi / psi", "d", "AIC / BIC"),
  keyword = c(
    "latent() + unique()",
    "latent(..., d = 2)",
    "unique()",
    "d argument in latent()",
    "AIC(fit), BIC(fit)"
  ),
  dgp = c(
    "Lambda %*% t(Lambda) + Psi",
    "two planted morphology axes: size and shape",
    "trait-specific unique variance",
    "true rank d_true = 2",
    "computed from logLik(), df, and likelihood-contributing nobs"
  ),
  extractor = c(
    "extract_Sigma(fit, level = \"unit\")",
    "extract_ordination(fit, level = \"unit\")",
    "extract_Sigma(fit, level = \"unit\", part = \"unique\")",
    "candidate model formulas",
    "stats::AIC(), stats::BIC(), stats::logLik()"
  ),
  truth_column = c(
    "truth$Sigma",
    "truth$Lambda",
    "truth$psi",
    "truth$d_true",
    "rank_table in the article"
  )
)

example <- list(
  data_long = data_long,
  data_wide = data_wide,
  truth = list(
    seed = seed,
    n_individuals = n_individuals,
    trait_names = trait_names,
    d_true = d_true,
    Lambda = Lambda,
    psi = psi,
    Psi = Psi,
    Sigma = Sigma,
    correlation = R,
    communality = communality,
    scores = scores
  ),
  estimands = estimands,
  formula_long = formula_long,
  formula_wide = formula_wide,
  rank_candidates = rank_candidates,
  fit_args = list(
    trait = "trait",
    unit = "individual",
    family = stats::gaussian()
  ),
  story = list(
    title = "Latent-rank model selection",
    question = paste(
      "Do five continuous traits need one latent axis, two axes,",
      "or a richer rank before the covariance summary is interpretable?"
    ),
    unit = "individual",
    traits = c(
      length = "body length",
      mass = "body mass",
      wing = "wing chord",
      tarsus = "tarsus length",
      bill = "bill depth"
    ),
    rank_decision = paste(
      "Compare a diagonal baseline and latent + unique candidates",
      "with d = 1, 2, and 3, then read AIC/BIC beside fit health."
    )
  ),
  alignment = alignment,
  generator = "data-raw/examples/make-model-selection-rank-example.R"
)

attr(example, "created_at") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
attr(example, "gllvmTMB_version") <-
  as.character(utils::packageVersion("gllvmTMB"))

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(example, OUT_PATH)

cat(sprintf("[data-raw] saved -> %s (%d bytes)\n",
            OUT_PATH, file.size(OUT_PATH)))
