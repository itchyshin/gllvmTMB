## Smoke-test the synthetic plant--bumblebee point-estimate article example.
## Run from the repository root:
##   Rscript --vanilla dev/plant-bumblebee-coevolution-smoke.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

fixture_path <- file.path(
  "inst", "extdata", "examples", "plant-bumblebee-coevolution-example.rds"
)
stopifnot(file.exists(fixture_path))
example <- readRDS(fixture_path)

K_cross <- make_cross_kernel(
  example$A_plant,
  example$A_bumblebee,
  example$W,
  rho = example$truth$rho
)
stopifnot(isTRUE(all.equal(K_cross, example$K_cross, tolerance = 1e-12)))
stopifnot(min(eigen(K_cross, symmetric = TRUE, only.values = TRUE)$values) > -1e-6)

fit <- gllvmTMB(
  traits(flower_tube_depth, nectar_volume, tongue_length, body_size) ~ 1 +
    kernel_latent(species, K = K_cross, d = 2, name = "cross"),
  data = example$data_wide,
  unit = "observation",
  cluster = "species",
  family = gaussian(),
  control = gllvmTMBcontrol(se = FALSE)
)

stopifnot(identical(fit$opt$convergence, 0L))
Gamma_hat <- extract_Gamma(
  fit,
  level = "cross",
  row_traits = example$truth$plant_traits,
  col_traits = example$truth$bumblebee_traits
)
stopifnot(is.matrix(Gamma_hat), all(is.finite(Gamma_hat)))

refit_cross <- function(K, rho) {
  gllvmTMB(
    traits(flower_tube_depth, nectar_volume, tongue_length, body_size) ~ 1 +
      kernel_latent(species, K = K, d = 2, name = "cross"),
    data = example$data_wide,
    unit = "observation",
    cluster = "species",
    family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )
}

rho_profile <- profile_cross_rho(
  example$A_plant,
  example$A_bumblebee,
  example$W,
  rho = c(0, 0.25, example$truth$rho, 0.8),
  refit = refit_cross
)
stopifnot(
  nrow(rho_profile) == 4L,
  all(rho_profile$status == "ok"),
  all(is.finite(rho_profile$logLik)),
  all(is.finite(rho_profile$relative_logLik))
)

cat("plant_bumblebee_point_estimate=PASS\n")
cat("plant_bumblebee_fixed_rho_sensitivity=PASS\n")
cat(sprintf("logLik=%.6f\n", as.numeric(logLik(fit))))
print(Gamma_hat)
