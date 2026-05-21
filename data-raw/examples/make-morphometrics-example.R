## data-raw/examples/make-morphometrics-example.R
## =================================================
## Regenerate inst/extdata/examples/morphometrics-example.rds.
##
## The RDS stores a portable teaching fixture: long data, wide data,
## truth, estimands, formulas, fit arguments, story, and alignment. It
## deliberately does not store fitted TMB objects.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-morphometrics-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path(
  "inst", "extdata", "examples", "morphometrics-example.rds"
)

seed <- 20260520L
set.seed(seed)

n_individuals <- 150L
trait_names <- c("length", "mass", "wing", "tarsus", "bill")
n_traits <- length(trait_names)
d <- 2L

Lambda <- matrix(c(
  0.9,  0.1,
  1.0,  0.2,
  0.8, -0.4,
  0.7, -0.5,
  0.6,  0.6
), nrow = n_traits, ncol = d, byrow = TRUE,
dimnames = list(trait_names, c("size", "shape")))

psi <- c(
  length = 0.15,
  mass = 0.10,
  wing = 0.20,
  tarsus = 0.12,
  bill = 0.18
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
shared_var <- diag(Lambda %*% t(Lambda))
communality <- shared_var / diag(Sigma)

estimands <- data.frame(
  trait = trait_names,
  shared_variance = unname(shared_var),
  unique_variance = unname(psi),
  total_variance = unname(diag(Sigma)),
  communality = unname(communality)
)

formula_long <- value ~ 0 + trait +
  latent(0 + trait | individual, d = 2) +
  unique(0 + trait | individual)

formula_wide <- traits(length, mass, wing, tarsus, bill) ~ 1 +
  latent(1 | individual, d = 2) +
  unique(1 | individual)

alignment <- data.frame(
  symbol = c("Sigma", "Lambda", "Psi / psi", "cor(Sigma)", "communality"),
  keyword = c(
    "latent() + unique()",
    "latent(..., d = 2)",
    "unique()",
    "extract_correlations()",
    "extract_communality()"
  ),
  dgp = c(
    "Lambda %*% t(Lambda) + Psi",
    "two morphology axes: size and shape",
    "trait-specific unique variance",
    "cov2cor(Sigma)",
    "diag(Lambda Lambda^T) / diag(Sigma)"
  ),
  extractor = c(
    "extract_Sigma(fit, level = \"unit\")",
    "extract_ordination(fit, level = \"unit\")",
    "extract_Sigma(fit, level = \"unit\", part = \"unique\")",
    "extract_correlations(fit, tier = \"unit\")",
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
    correlation = R,
    communality = communality,
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
    title = "Individual morphometrics",
    question = paste(
      "Do five body measurements share two latent axes, size and shape,",
      "while retaining trait-specific variation?"
    ),
    unit = "individual bird",
    traits = c(
      length = "body length",
      mass = "body mass",
      wing = "wing chord",
      tarsus = "tarsus length",
      bill = "bill depth"
    ),
    axes = c(
      size = "larger individuals tend to be larger on all measurements",
      shape = "long-and-skinny versus short-and-stocky contrast"
    )
  ),
  alignment = alignment,
  generator = "data-raw/examples/make-morphometrics-example.R"
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
