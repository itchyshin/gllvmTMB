## data-raw/examples/make-joint-sdm-example.R
## =================================================
## Regenerate inst/extdata/examples/joint-sdm-example.rds.
##
## The RDS stores a portable teaching fixture: complete binary
## site-by-species data in long and wide form, known latent-liability
## truth, formulas, fit arguments, story, and an alignment table. It
## deliberately does not store fitted TMB objects.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-joint-sdm-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path(
  "inst",
  "extdata",
  "examples",
  "joint-sdm-example.rds"
)

seed <- 20260529L
set.seed(seed)

n_sites <- 120L
trait_names <- paste0("sp_", seq_len(8L))
n_traits <- length(trait_names)
d <- 2L

env_1 <- as.numeric(scale(
  seq(-1.5, 1.5, length.out = n_sites) +
    stats::rnorm(n_sites, sd = 0.2)
))

scores <- matrix(stats::rnorm(n_sites * d), n_sites, d)
colnames(scores) <- c("moisture_axis", "elevation_axis")

Lambda <- matrix(
  c(
    -0.85,
    -0.70,
    -0.75,
    -0.80,
    -0.75,
    0.75,
    -0.65,
    0.85,
    0.75,
    -0.75,
    0.85,
    -0.65,
    0.70,
    0.80,
    0.80,
    0.70
  ),
  nrow = n_traits,
  ncol = d,
  byrow = TRUE,
  dimnames = list(trait_names, c("moisture_axis", "elevation_axis"))
)

alpha <- c(
  sp_1 = -0.45,
  sp_2 = -0.25,
  sp_3 = -0.15,
  sp_4 = 0.05,
  sp_5 = -0.05,
  sp_6 = 0.15,
  sp_7 = 0.25,
  sp_8 = 0.45
)

beta <- c(
  sp_1 = 0.65,
  sp_2 = 0.45,
  sp_3 = -0.45,
  sp_4 = -0.65,
  sp_5 = 0.55,
  sp_6 = 0.35,
  sp_7 = -0.35,
  sp_8 = -0.55
)

eta <- outer(rep(1, n_sites), alpha) +
  outer(env_1, beta) +
  scores %*% t(Lambda)
prob <- stats::plogis(eta)

Y <- matrix(
  stats::rbinom(
    n_sites * n_traits,
    size = 1L,
    prob = as.vector(prob)
  ),
  nrow = n_sites,
  ncol = n_traits,
  dimnames = list(NULL, trait_names)
)

data_wide <- data.frame(
  site = factor(seq_len(n_sites)),
  env_1 = env_1,
  Y,
  check.names = FALSE
)

data_long <- data.frame(
  site = factor(rep(seq_len(n_sites), each = n_traits)),
  env_1 = rep(env_1, each = n_traits),
  trait = factor(rep(trait_names, times = n_sites), levels = trait_names),
  value = as.vector(t(Y))
)

Sigma_shared <- Lambda %*% t(Lambda)
Sigma_latent <- Sigma_shared + diag(pi^2 / 3, n_traits, n_traits)
correlation <- stats::cov2cor(Sigma_latent)

estimands <- data.frame(
  trait = trait_names,
  intercept = unname(alpha),
  env_slope = unname(beta),
  shared_variance = unname(diag(Sigma_shared)),
  link_residual_variance = rep(pi^2 / 3, n_traits),
  latent_liability_variance = unname(diag(Sigma_latent)),
  communality = unname(diag(Sigma_shared) / diag(Sigma_latent))
)

formula_long <- value ~ 0 +
  trait +
  (0 + trait):env_1 +
  latent(0 + trait | site, d = 2)

formula_wide <- traits(sp_1, sp_2, sp_3, sp_4, sp_5, sp_6, sp_7, sp_8) ~
  1 + env_1 + latent(1 | site, d = 2)

alignment <- data.frame(
  symbol = c(
    "eta",
    "Lambda",
    "Sigma_shared",
    "Sigma_latent",
    "cor(Sigma_latent)"
  ),
  keyword = c(
    "0 + trait + (0 + trait):env_1",
    "latent(..., d = 2)",
    "latent()",
    "latent() + binomial-logit link residual",
    "extract_correlations(link_residual = \"auto\")"
  ),
  dgp = c(
    "species intercepts and env_1 slopes on the logit scale",
    "two residual co-occurrence axes",
    "Lambda %*% t(Lambda)",
    "Lambda %*% t(Lambda) + diag(pi^2 / 3)",
    "cov2cor(Sigma_latent)"
  ),
  extractor = c(
    "tidy(fit, effects = \"fixed\")",
    "extract_ordination(fit, level = \"unit\")",
    "extract_Sigma(fit, level = \"unit\", part = \"shared\")",
    "extract_Sigma(fit, level = \"unit\", part = \"total\")",
    "extract_correlations(fit, tier = \"unit\", link_residual = \"auto\")"
  ),
  truth_column = c(
    "truth$alpha, truth$beta",
    "truth$Lambda",
    "truth$Sigma_shared",
    "truth$Sigma_latent",
    "truth$correlation"
  )
)

example <- list(
  data_long = data_long,
  data_wide = data_wide,
  truth = list(
    seed = seed,
    n_sites = n_sites,
    trait_names = trait_names,
    d = d,
    alpha = alpha,
    beta = beta,
    Lambda = Lambda,
    scores = scores,
    Sigma_shared = Sigma_shared,
    Sigma_latent = Sigma_latent,
    correlation = correlation,
    link_residual_variance = pi^2 / 3
  ),
  estimands = estimands,
  formula_long = formula_long,
  formula_wide = formula_wide,
  fit_args = list(
    trait = "trait",
    unit = "site",
    family = stats::binomial()
  ),
  story = list(
    title = "Binary joint species distribution model",
    question = paste(
      "Which species retain residual co-occurrence after an environmental",
      "gradient is accounted for?"
    ),
    unit = "site",
    traits = c(
      sp_1 = "dry lowland species 1",
      sp_2 = "dry lowland species 2",
      sp_3 = "dry highland species 1",
      sp_4 = "dry highland species 2",
      sp_5 = "wet lowland species 1",
      sp_6 = "wet lowland species 2",
      sp_7 = "wet highland species 1",
      sp_8 = "wet highland species 2"
    ),
    axes = c(
      moisture_axis = "dry-to-wet residual species turnover",
      elevation_axis = "lowland-to-highland residual species turnover"
    )
  ),
  alignment = alignment,
  generator = "data-raw/examples/make-joint-sdm-example.R"
)

attr(example, "created_at") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
attr(example, "gllvmTMB_version") <-
  as.character(utils::packageVersion("gllvmTMB"))

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(example, OUT_PATH)

cat(sprintf(
  "[data-raw] saved -> %s (%d bytes)\n",
  OUT_PATH,
  file.size(OUT_PATH)
))
