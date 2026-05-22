## data-raw/examples/make-morphometrics-bootstrap-correlation.R
## ================================================================
## Regenerate inst/extdata/examples/morphometrics-bootstrap-r.rds.
##
## The RDS stores a small cached bootstrap_Sigma() object for the
## morphometrics article. It is a teaching fixture for interval-aware
## correlation plots, not a simulation-calibration study.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-morphometrics-bootstrap-correlation.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

EXAMPLE_PATH <- file.path(
  "inst",
  "extdata",
  "examples",
  "morphometrics-example.rds"
)
OUT_PATH <- file.path(
  "inst",
  "extdata",
  "examples",
  "morphometrics-bootstrap-r.rds"
)

seed <- 20260521L
n_boot <- 100L

morph <- readRDS(EXAMPLE_PATH)
ctl <- gllvmTMBcontrol(se = FALSE)

fit <- suppressMessages(gllvmTMB(
  morph$formula_long,
  data = morph$data_long,
  trait = morph$fit_args$trait,
  unit = morph$fit_args$unit,
  family = morph$fit_args$family,
  control = ctl
))

boot <- suppressMessages(bootstrap_Sigma(
  fit,
  n_boot = n_boot,
  level = "unit",
  what = "R",
  seed = seed,
  progress = FALSE,
  keep_draws = FALSE
))

if (boot$n_failed > 0L) {
  warning(
    "Bootstrap fixture generation had failed refits: ",
    boot$n_failed,
    call. = FALSE
  )
}

attr(boot, "fixture") <- list(
  generator = "data-raw/examples/make-morphometrics-bootstrap-correlation.R",
  source_example = EXAMPLE_PATH,
  purpose = paste(
    "Cached teaching fixture for interval-aware morphometrics correlation",
    "plots; not a simulation-calibration study."
  )
)

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(boot, OUT_PATH)

cat(sprintf(
  "[data-raw] saved -> %s (%d bytes; n_boot = %d, seed = %d)\n",
  OUT_PATH,
  file.size(OUT_PATH),
  n_boot,
  seed
))
