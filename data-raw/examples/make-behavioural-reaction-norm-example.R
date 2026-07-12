## data-raw/examples/make-behavioural-reaction-norm-example.R
## ============================================================
## Regenerate inst/extdata/examples/behavioural-reaction-norm-example.rds.
##
## The RDS stores a portable teaching fixture for an individual-level
## Gaussian reaction-norm GLLVM: long data, wide data, known augmented
## covariance truth, long/wide formulas, fit arguments, story, and an
## alignment table. It deliberately does not store fitted TMB objects.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-behavioural-reaction-norm-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

OUT_PATH <- file.path(
  "inst",
  "extdata",
  "examples",
  "behavioural-reaction-norm-example.rds"
)

seed <- 20260608L
set.seed(seed)

n_individuals <- 60L
n_sessions_per_individual <- 5L
trait_names <- c("boldness", "exploration", "activity")
n_traits <- length(trait_names)
d_B <- 1L
d_W <- 1L

individuals <- paste0("ind_", seq_len(n_individuals))

sessions <- expand.grid(
  individual = factor(individuals, levels = individuals),
  session = seq_len(n_sessions_per_individual),
  KEEP.OUT.ATTRS = FALSE
)
sessions$session_id <- factor(
  paste(sessions$individual, sessions$session, sep = "_")
)

planned_temperature_C <- seq(
  12,
  28,
  length.out = n_sessions_per_individual
)
sessions$temperature_C <-
  planned_temperature_C[sessions$session] +
  stats::rnorm(nrow(sessions), sd = 0.6)
temperature_center_C <- mean(sessions$temperature_C)
temperature_scale_C <- stats::sd(sessions$temperature_C)
sessions$temperature <-
  (sessions$temperature_C - temperature_center_C) / temperature_scale_C

data_long <- sessions[rep(seq_len(nrow(sessions)), each = n_traits), ]
data_long$trait <- factor(
  rep(trait_names, times = nrow(sessions)),
  levels = trait_names
)

alpha <- c(
  boldness = 0.20,
  exploration = -0.05,
  activity = 0.10
)
beta <- c(
  boldness = 0.18,
  exploration = 0.05,
  activity = -0.12
)

augmented_names <- as.vector(rbind(
  paste0("intercept.", trait_names),
  paste0("slope.temperature.", trait_names)
))

Lambda_unit_slope <- matrix(
  c(
    0.55,
    0.18,
    0.48,
    0.16,
    0.42,
    -0.14
  ),
  ncol = d_B,
  dimnames = list(augmented_names, "reactivity_axis")
)

sd_unit_slope <- c(
  0.22,
  0.10,
  0.20,
  0.09,
  0.18,
  0.08
)
names(sd_unit_slope) <- augmented_names
psi_unit_slope <- sd_unit_slope^2

z_B <- stats::rnorm(n_individuals)
q_B <- matrix(
  stats::rnorm(
    length(sd_unit_slope) * n_individuals,
    sd = rep(sd_unit_slope, n_individuals)
  ),
  nrow = length(sd_unit_slope),
  ncol = n_individuals,
  dimnames = list(augmented_names, individuals)
)

Lambda_unit_obs <- matrix(
  c(0.25, 0.18, 0.12),
  ncol = d_W,
  dimnames = list(trait_names, "occasion_arousal")
)
z_W <- stats::rnorm(nrow(sessions))
names(z_W) <- as.character(sessions$session_id)

sigma_eps <- 0.12
eta <- numeric(nrow(data_long))

for (o in seq_len(nrow(data_long))) {
  trait <- as.character(data_long$trait[o])
  trait_index <- match(trait, trait_names)
  individual_index <- as.integer(data_long$individual[o])
  session_id <- as.character(data_long$session_id[o])
  base <- 2L * (trait_index - 1L)

  unit_coefficients <-
    Lambda_unit_slope[, 1L] * z_B[individual_index] +
    q_B[, individual_index]

  eta[o] <-
    alpha[trait] +
    beta[trait] * data_long$temperature[o] +
    unit_coefficients[base + 1L] +
    unit_coefficients[base + 2L] * data_long$temperature[o] +
    Lambda_unit_obs[trait_index, 1L] * z_W[session_id]
}

data_long$value <- eta + stats::rnorm(nrow(data_long), sd = sigma_eps)

data_wide <- stats::reshape(
  data_long[
    c(
      "individual",
      "session",
      "session_id",
      "temperature_C",
      "temperature",
      "trait",
      "value"
    )
  ],
  idvar = c(
    "individual",
    "session",
    "session_id",
    "temperature_C",
    "temperature"
  ),
  timevar = "trait",
  direction = "wide"
)
names(data_wide) <- sub("^value\\.", "", names(data_wide))
rownames(data_wide) <- NULL

Sigma_unit_slope_shared <- Lambda_unit_slope %*% t(Lambda_unit_slope)
Sigma_unit_slope_unique <- diag(psi_unit_slope, nrow = length(psi_unit_slope))
dimnames(Sigma_unit_slope_unique) <-
  list(augmented_names, augmented_names)
Sigma_unit_slope <- Sigma_unit_slope_shared + Sigma_unit_slope_unique
R_unit_slope <- stats::cov2cor(Sigma_unit_slope)

intercept_names <- paste0("intercept.", trait_names)
slope_names <- paste0("slope.temperature.", trait_names)
Sigma_intercept <- Sigma_unit_slope[intercept_names, intercept_names]
Sigma_slope <- Sigma_unit_slope[slope_names, slope_names]
Sigma_intercept_slope <- Sigma_unit_slope[intercept_names, slope_names]

Sigma_unit_obs <- Lambda_unit_obs %*% t(Lambda_unit_obs)

estimands <- data.frame(
  coefficient = augmented_names,
  trait = rep(trait_names, each = 2L),
  component = rep(c("intercept", "slope"), times = n_traits),
  shared_variance = unname(diag(Sigma_unit_slope_shared)),
  unique_variance = unname(psi_unit_slope),
  total_variance = unname(diag(Sigma_unit_slope)),
  communality = unname(
    diag(Sigma_unit_slope_shared) / diag(Sigma_unit_slope)
  )
)

formula_long <- value ~ 0 +
  trait +
  (0 + trait):temperature +
  latent(
    0 + trait + (0 + trait):temperature | individual,
    d = 1
  ) +
  latent(0 + trait | session_id, d = 1)

formula_wide <- traits(boldness, exploration, activity) ~
  1 +
  temperature +
  latent(1 + temperature | individual, d = 1) +
  latent(1 | session_id, d = 1)

alignment <- data.frame(
  symbol = c(
    "eta",
    "Lambda_B,aug",
    "psi_B,aug",
    "Sigma_B,aug",
    "Sigma_W",
    "R_t(x)"
  ),
  keyword = c(
    "0 + trait + (0 + trait):temperature",
    "latent(1 + temperature | individual, d = 1)",
    "default Psi from latent(1 + temperature | individual, d = 1)",
    "latent() default Psi",
    "latent(1 | session_id, d = 1)",
    "extract_Sigma(level = \"unit_slope\")"
  ),
  dgp = c(
    "trait intercepts and population-average temperature slopes",
    "one shared axis for individual intercepts and slopes",
    "trait-specific augmented individual deviations",
    "Lambda_B,aug %*% t(Lambda_B,aug) + diag(psi_B,aug)",
    "one shared occasion-level arousal axis",
    "Var(u_it + b_it x) / total variance at temperature x"
  ),
  extractor = c(
    "tidy(fit, effects = \"fixed\")",
    "extract_Sigma(fit, level = \"unit_slope\", part = \"shared\")",
    "extract_Sigma(fit, level = \"unit_slope\", part = \"unique\")",
    "extract_Sigma(fit, level = \"unit_slope\", part = \"total\")",
    "extract_Sigma(fit, level = \"unit_obs\", part = \"shared\")",
    "article helper using unit_slope and unit_obs covariance"
  ),
  truth_column = c(
    "truth$alpha, truth$beta",
    "truth$Sigma_unit_slope_shared",
    "truth$psi_unit_slope",
    "truth$Sigma_unit_slope",
    "truth$Sigma_unit_obs",
    "truth$Sigma_unit_slope, truth$Sigma_unit_obs, truth$sigma_eps"
  )
)

example <- list(
  data_long = data_long,
  data_wide = data_wide,
  truth = list(
    seed = seed,
    n_individuals = n_individuals,
    n_sessions_per_individual = n_sessions_per_individual,
    planned_temperature_C = planned_temperature_C,
    temperature_center_C = temperature_center_C,
    temperature_scale_C = temperature_scale_C,
    trait_names = trait_names,
    augmented_names = augmented_names,
    d_B = d_B,
    d_W = d_W,
    alpha = alpha,
    beta = beta,
    Lambda_unit_slope = Lambda_unit_slope,
    psi_unit_slope = psi_unit_slope,
    sd_unit_slope = sd_unit_slope,
    Sigma = Sigma_unit_slope,
    Sigma_unit_slope = Sigma_unit_slope,
    Sigma_unit_slope_shared = Sigma_unit_slope_shared,
    Sigma_unit_slope_unique = Sigma_unit_slope_unique,
    R_unit_slope = R_unit_slope,
    Sigma_intercept = Sigma_intercept,
    Sigma_slope = Sigma_slope,
    Sigma_intercept_slope = Sigma_intercept_slope,
    Lambda_unit_obs = Lambda_unit_obs,
    Sigma_unit_obs = Sigma_unit_obs,
    sigma_eps = sigma_eps,
    z_B = z_B,
    z_W = z_W
  ),
  estimands = estimands,
  formula_long = formula_long,
  formula_wide = formula_wide,
  fit_args = list(
    trait = "trait",
    unit = "individual",
    unit_obs = "session_id",
    family = stats::gaussian()
  ),
  story = list(
    title = "Behavioural reaction norms",
    question = paste(
      "Do individuals differ in average behaviour and in temperature",
      "responsiveness, and do those reaction-norm coefficients covary",
      "across behaviours?"
    ),
    unit = "individual",
    unit_obs = "session",
    context = "temperature",
    traits = c(
      boldness = "latency-adjusted boldness score",
      exploration = "arena exploration score",
      activity = "movement activity score"
    ),
    axes = c(
      reactivity_axis = paste(
        "individuals with high average boldness and exploration also",
        "show stronger positive temperature responsiveness"
      ),
      occasion_arousal = paste(
        "sessions with higher unobserved arousal shift all behaviours",
        "in the same direction"
      )
    )
  ),
  alignment = alignment,
  generator = "data-raw/examples/make-behavioural-reaction-norm-example.R"
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
