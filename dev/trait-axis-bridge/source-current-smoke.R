suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

bridge <- readRDS("inst/extdata/examples/trait-axis-bridge.rds")

pcm <- bridge$pcm
pcm_data <- pcm$data
tree <- pcm$tree
fit_pcm <- gllvmTMB(
  value_z ~ 0 + trait + column_domain:elevation +
    slope(elevation | trait) +
    phylo_latent(
      0 + trait | species,
      tree = tree,
      d = 2,
      unique = TRUE
    ),
  data = pcm_data,
  trait = "trait",
  unit = "record_id",
  cluster = "species",
  family = gaussian(),
  silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE)
)
stopifnot(
  identical(fit_pcm$opt$convergence, 0L),
  isTRUE(fit_pcm$use$phylo_column_slope),
  identical(fit_pcm$use$phylo_column_slope_source, "ordinary"),
  isTRUE(fit_pcm$use$phylo_rr),
  all(is.finite(fit_pcm$tmb_obj$gr(fit_pcm$opt$par)))
)
cat("PCM_OK objective=", fit_pcm$opt$objective, "\n", sep = "")

column <- bridge$column
fit_column <- gllvmTMB(
  value ~ 0 + trait + guild:elevation + guild:forest_cover +
    phylo_slope(
      elevation + forest_cover | trait,
      tree = column$tree
    ),
  data = column$data,
  trait = "trait",
  unit = "site_id",
  family = gaussian(),
  silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE)
)
Sigma_slope <- extract_Sigma(fit_column, level = "column_slope")$Sigma
stopifnot(
  identical(fit_column$opt$convergence, 0L),
  identical(dim(Sigma_slope), c(2L, 2L)),
  identical(rownames(Sigma_slope), c("elevation", "forest_cover")),
  all(is.finite(fit_column$tmb_obj$gr(fit_column$opt$par)))
)
cat("COLUMN_OK objective=", fit_column$opt$objective, "\n", sep = "")

isdm <- bridge$isdm
fit_isdm <- gllvmTMB(
  isdm$formula,
  data = isdm$data,
  trait = "trait",
  unit = "unit_id",
  family = isdm$family,
  silent = TRUE,
  control = gllvmTMBcontrol(se = FALSE)
)
stopifnot(
  identical(fit_isdm$opt$convergence, 0L),
  all(is.finite(fit_isdm$tmb_obj$gr(fit_isdm$opt$par)))
)
cat("ISDM_OK objective=", fit_isdm$opt$objective, "\n", sep = "")

cat("TRAIT_BRIDGE_SOURCE_CURRENT_SMOKE_OK\n")
