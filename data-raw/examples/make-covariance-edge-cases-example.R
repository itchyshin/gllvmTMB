## data-raw/examples/make-covariance-edge-cases-example.R
## =======================================================
## Regenerate inst/extdata/examples/covariance-edge-cases-example.rds.
##
## The RDS stores a portable teaching fixture for covariance/correlation
## edge cases: a Gaussian behavioural-syndrome dataset where latent-only
## correlations are inflated unless the diagonal Psi component is included.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-covariance-edge-cases-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path(
  "inst", "extdata", "examples", "covariance-edge-cases-example.rds"
)

seed <- 20260521L
set.seed(seed)

n_individuals <- 180L
trait_names <- c(
  "boldness", "exploration", "activity", "aggression", "sociability"
)
n_traits <- length(trait_names)
d <- 2L

Lambda <- matrix(c(
  0.9,  0.1,
  1.0,  0.2,
  0.8, -0.4,
  0.7, -0.5,
  0.6,  0.6
), nrow = n_traits, ncol = d, byrow = TRUE,
dimnames = list(trait_names, c("reactivity", "social_axis")))

psi <- c(
  boldness = 0.30,
  exploration = 0.20,
  activity = 0.40,
  aggression = 0.25,
  sociability = 0.35
)

scores <- matrix(rnorm(n_individuals * d), n_individuals, d)
unique_error <- sapply(
  seq_len(n_traits),
  function(t) rnorm(n_individuals, sd = sqrt(psi[t]))
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
shared <- Lambda %*% t(Lambda)

estimands <- data.frame(
  trait = trait_names,
  shared_variance = unname(diag(shared)),
  unique_variance = unname(psi),
  total_variance = unname(diag(Sigma)),
  communality = unname(diag(shared) / diag(Sigma))
)

formula_long <- value ~ 0 + trait +
  latent(0 + trait | individual, d = 2)

formula_wide <- traits(
  boldness, exploration, activity, aggression, sociability
) ~ 1 +
  latent(1 | individual, d = 2)

formula_latent_only_long <- value ~ 0 + trait +
  latent(0 + trait | individual, d = 2, unique = FALSE)

formula_latent_only_wide <- traits(
  boldness, exploration, activity, aggression, sociability
) ~ 1 +
  latent(1 | individual, d = 2, unique = FALSE)

alignment <- data.frame(
  symbol = c("Sigma", "Lambda", "Psi / psi", "R", "communality"),
  keyword = c(
    "latent() default Psi",
    "latent(..., d = 2)",
    "default latent() Psi",
    "extract_Sigma(..., part = \"total\")$R",
    "extract_communality()"
  ),
  dgp = c(
    "Lambda %*% t(Lambda) + Psi",
    "two behavioural axes: reactivity and social tendency",
    "trait-specific unique variance",
    "cov2cor(Sigma)",
    "diag(Lambda Lambda^T) / diag(Sigma)"
  ),
  extractor = c(
    "extract_Sigma(fit, level = \"unit\")",
    "extract_ordination(fit, level = \"unit\")",
    "extract_Sigma(fit, level = \"unit\", part = \"unique\")",
    "extract_Sigma(fit, level = \"unit\")$R",
    "extract_communality(fit, level = \"unit\")"
  ),
  truth_column = c(
    "truth$Sigma",
    "truth$Lambda",
    "truth$psi",
    "truth$correlation",
    "estimands$communality"
  )
)

edge_cases <- list(
  latent_only = list(
    formula_long = formula_latent_only_long,
    formula_wide = formula_latent_only_wide,
    failure_mode = paste(
      "With unique = FALSE, the diagonal of Sigma contains only",
      "Lambda Lambda^T, so correlations are inflated when the",
      "true data-generating process has trait-specific variance."
    )
  ),
  recommended = list(
    formula_long = formula_long,
    formula_wide = formula_wide,
    rule = "Use default latent() when trait-specific variance is part of the estimand."
  )
)

example <- list(
  data_long = data_long,
  data_wide = data_wide,
  truth = list(
    seed = seed,
    n_individuals = n_individuals,
    trait_names = trait_names,
    d = d,
    Lambda = Lambda,
    psi = psi,
    Psi = Psi,
    Sigma = Sigma,
    shared = shared,
    correlation = R,
    communality = estimands$communality,
    scores = scores
  ),
  estimands = estimands,
  formula_long = formula_long,
  formula_wide = formula_wide,
  fit_args = list(
    trait = "trait",
    unit = "individual",
    family = stats::gaussian()
  ),
  story = list(
    title = "Behavioural covariance edge cases",
    question = paste(
      "Do five behaviours share latent syndrome axes while keeping",
      "behaviour-specific variance in the correlation denominator?"
    ),
    unit = "individual animal",
    traits = c(
      boldness = "risk-taking response",
      exploration = "movement through a novel arena",
      activity = "baseline movement rate",
      aggression = "response to a social challenge",
      sociability = "time spent near conspecifics"
    ),
    axes = c(
      reactivity = "high overall behavioural response intensity",
      social_axis = "social approach versus solitary activity"
    )
  ),
  alignment = alignment,
  edge_cases = edge_cases,
  generator = "data-raw/examples/make-covariance-edge-cases-example.R"
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
