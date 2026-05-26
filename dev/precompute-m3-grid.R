## dev/precompute-m3-grid.R
## ========================
## M3.2 driver: runs the DGP grid pipeline from `dev/m3-grid.R` and
## persists the long-format coverage data + per-cell summary to
## `dev/precomputed/`.
##
## Usage (from repo root):
##   Rscript dev/precompute-m3-grid.R              # smoke (10 reps/cell, Gaussian only)
##   Rscript dev/precompute-m3-grid.R --all-fams   # smoke across all 5 families
##   Rscript dev/precompute-m3-grid.R --full       # full grid (200 reps; ~hours)
##   Rscript dev/precompute-m3-grid.R --full --family=nbinom2 --d=2 \
##     --n-reps=200 --init-strategy=single_trait_warmup
##   Rscript dev/precompute-m3-grid.R --full --family=binomial --d=2 \
##     --n-reps=200 --shard=1 --n-shards=4 \
##     --out-prefix=m3-coverage-binomial-d2-shard1
##   Rscript dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 \
##     --n-reps=50 --init-strategy=single_trait_warmup \
##     --start-method=res --start-jitter=0.2 --n-init=5 \
##     --targets=psi,Sigma_unit_diag --n-boot=30 --n-cores-boot=4
##   Rscript dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 \
##     --n-units=120 --phi=0.4 --lambda-scale=0.5 --psi-scale=1.5 \
##     --targets=Sigma_unit_diag --n-reps=10 --n-boot=10
##   Rscript dev/precompute-m3-grid.R --full --family=nbinom2 --d=1 \
##     --n-reps=2 --init-strategy=single_trait_warmup \
##     --targets=Sigma_unit_diag --n-boot=10 --seed-base=20260524 \
##     --out-prefix=m3-local-smoke   # 2026-05-24 sim-lane local smoke
##   Rscript dev/precompute-m3-grid.R --nb2-stress-map --n-reps=10 \
##     --out-prefix=m3-nb2-stress-point
##   Rscript dev/precompute-m3-grid.R --nb2-start-probe --n-reps=5 \
##     --out-prefix=m3-nb2-start-probe
##   Rscript dev/precompute-m3-grid.R --nb2-start-probe --n-reps=1 \
##     --probe-config=current_res_bfgs_n3_j005 \
##     --out-prefix=m3-nb2-start-probe-smoke
##
## Output:
##   dev/precomputed/m3-coverage-grid.rds (long-format)
##   dev/precomputed/m3-coverage-summary.rds (per-cell aggregate)
##   dev/precomputed/*-diagnostic-report.md and
##   dev/precomputed/*-source-map-dashboard.png for diagnostic modes
##
## Scope (M3.2/M3.3 — Curie + Grace lead; Fisher review):
##   * Pipeline machinery + a working smoke artefact.
##   * Profile CIs on per-trait psi for the production grid.
##   * Optional bootstrap CIs on total Sigma_unit[tt] for the
##     target-explicit M3.3 pilot.
##   * Full 5-family x 3-d grid execution is dispatched by the
##     M3 production-grid GitHub Actions workflow.

suppressPackageStartupMessages({
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
})

source("dev/m3-grid.R")

## ---- Argument parsing -------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
mode <- if ("--nb2-start-probe" %in% args) {
  "nb2-start-probe"
} else if ("--nb2-stress-map" %in% args) {
  "nb2-stress-map"
} else if ("--full" %in% args) {
  "full"
} else if ("--all-fams" %in% args) {
  "all-fams"
} else {
  "smoke"
}

arg_value <- function(name, default = NULL) {
  prefix <- paste0(name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) {
    return(default)
  }
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

split_arg <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(NULL)
  }
  strsplit(x, ",", fixed = TRUE)[[1L]]
}

config <- switch(
  mode,
  smoke = list(
    cells = data.frame(
      family = "gaussian",
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 10L,
    label = "smoke-gaussian"
  ),
  `all-fams` = list(
    ## All 5 families × 3 dims = 15 cells.
    ## Mixed-family integration uses the M1 fixture pattern: per-row
    ## `family_id` column + `attr(family_list, 'family_var')` lookup.
    cells = expand.grid(
      family = M3_FAMILIES,
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 10L,
    label = "smoke-all-fams"
  ),
  full = list(
    cells = expand.grid(
      family = M3_FAMILIES,
      d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    ),
    n_reps = 200L,
    label = "full-grid"
  ),
  `nb2-stress-map` = list(
    cells = m3_nb2_stress_surfaces(
      include_controls = "--include-controls" %in% args
    ),
    n_reps = 10L,
    label = "nb2-stress-map"
  ),
  `nb2-start-probe` = list(
    cells = m3_nb2_stress_surfaces(include_controls = FALSE),
    start_configs = m3_nb2_start_probe_configs(
      include_optimizer_probe = !("--no-optimizer-probe" %in% args)
    ),
    n_reps = 5L,
    label = "nb2-start-probe"
  )
)

family_filter <- split_arg(arg_value("--family"))
d_filter <- split_arg(arg_value("--d"))
if (!is.null(family_filter)) {
  unknown <- setdiff(family_filter, M3_SUPPORTED_FAMILIES)
  if (length(unknown)) {
    stop("Unknown --family value(s): ", paste(unknown, collapse = ", "))
  }
  config$cells <- config$cells[
    config$cells$family %in% family_filter,
    ,
    drop = FALSE
  ]
}
if (!is.null(d_filter)) {
  d_filter <- as.integer(d_filter)
  if (anyNA(d_filter) || any(!d_filter %in% c(1L, 2L, 3L))) {
    stop("--d must contain one or more of 1, 2, 3")
  }
  config$cells <- config$cells[config$cells$d %in% d_filter, , drop = FALSE]
}
if (!nrow(config$cells)) {
  stop("No M3 cells selected")
}
if (identical(mode, "nb2-start-probe")) {
  probe_filter <- split_arg(arg_value("--probe-config"))
  if (!is.null(probe_filter) && !"all" %in% probe_filter) {
    unknown <- setdiff(probe_filter, config$start_configs$probe_id)
    if (length(unknown)) {
      stop("Unknown --probe-config value(s): ", paste(unknown, collapse = ", "))
    }
    config$start_configs <- config$start_configs[
      config$start_configs$probe_id %in% probe_filter,
      ,
      drop = FALSE
    ]
  }
}

n_reps_override <- arg_value("--n-reps")
if (!is.null(n_reps_override)) {
  config$n_reps <- as.integer(n_reps_override)
  if (is.na(config$n_reps) || config$n_reps < 1L) {
    stop("--n-reps must be a positive integer")
  }
}

n_units <- as.integer(arg_value("--n-units", as.character(M3_DEFAULT_N_UNITS)))
if (is.na(n_units) || n_units < 1L) {
  stop("--n-units must be a positive integer")
}
n_traits <- as.integer(arg_value(
  "--n-traits",
  as.character(M3_DEFAULT_N_TRAITS)
))
if (is.na(n_traits) || n_traits < 2L) {
  stop("--n-traits must be an integer >= 2")
}
lambda_scale <- as.numeric(arg_value(
  "--lambda-scale",
  as.character(M3_DEFAULT_LAMBDA_SCALE)
))
if (is.na(lambda_scale) || lambda_scale <= 0) {
  stop("--lambda-scale must be a positive number")
}
psi_scale <- as.numeric(arg_value(
  "--psi-scale",
  as.character(M3_DEFAULT_PSI_SCALE)
))
if (is.na(psi_scale) || psi_scale <= 0) {
  stop("--psi-scale must be a positive number")
}
phi_arg <- arg_value("--phi")
phi <- if (is.null(phi_arg)) NULL else as.numeric(phi_arg)
if (!is.null(phi) && (is.na(phi) || phi <= 0)) {
  stop("--phi must be a positive number")
}
phi_shape <- as.numeric(arg_value(
  "--phi-shape",
  as.character(M3_DEFAULT_PHI_SHAPE)
))
if (is.na(phi_shape) || phi_shape <= 0) {
  stop("--phi-shape must be a positive number")
}
phi_rate <- as.numeric(arg_value(
  "--phi-rate",
  as.character(M3_DEFAULT_PHI_RATE)
))
if (is.na(phi_rate) || phi_rate <= 0) {
  stop("--phi-rate must be a positive number")
}

init_strategy <- match.arg(
  arg_value(
    "--init-strategy",
    if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
      "single_trait_warmup"
    } else {
      "default"
    }
  ),
  c("default", "single_trait_warmup")
)
start_method_name <- arg_value(
  "--start-method",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "res" else "default"
)
if (!start_method_name %in% c("default", "res", "indep")) {
  stop("--start-method must be one of default, res, indep")
}
start_jitter <- as.numeric(arg_value(
  "--start-jitter",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "0.2" else "0"
))
if (is.na(start_jitter) || start_jitter < 0) {
  stop("--start-jitter must be a non-negative number")
}
start_method <- if (identical(start_method_name, "default")) {
  list(method = NULL, jitter.sd = 0)
} else {
  list(method = start_method_name, jitter.sd = start_jitter)
}
optimizer <- match.arg(
  arg_value(
    "--optimizer",
    if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "optim" else "nlminb"
  ),
  c("nlminb", "optim")
)
optim_method <- arg_value("--optim-method", "BFGS")
optArgs <- if (identical(optimizer, "optim")) {
  list(method = optim_method)
} else {
  list()
}
n_init <- as.integer(arg_value(
  "--n-init",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "3" else "1"
))
if (is.na(n_init) || n_init < 1L) {
  stop("--n-init must be a positive integer")
}
init_jitter <- as.numeric(arg_value(
  "--init-jitter",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "0.05" else "0.3"
))
if (is.na(init_jitter) || init_jitter < 0) {
  stop("--init-jitter must be a non-negative number")
}
se <- tolower(arg_value(
  "--se",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "false" else "true"
))
if (!se %in% c("true", "false")) {
  stop("--se must be true or false")
}
se <- identical(se, "true")
target_default <- if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
  "Sigma_unit_diag"
} else {
  "psi"
}
targets <- m3_normalise_targets(split_arg(arg_value(
  "--targets",
  target_default
)))
n_boot <- as.integer(arg_value(
  "--n-boot",
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) "0" else "30"
))
if (is.na(n_boot) || n_boot < 0L) {
  stop("--n-boot must be a non-negative integer")
}
n_cores_boot <- as.integer(arg_value("--n-cores-boot", "1"))
if (is.na(n_cores_boot) || n_cores_boot < 1L) {
  stop("--n-cores-boot must be a positive integer")
}
ci_level <- as.numeric(arg_value(
  "--ci-level",
  as.character(M3_DEFAULT_NOMINAL)
))
if (is.na(ci_level) || ci_level <= 0 || ci_level >= 1) {
  stop("--ci-level must be a number in (0, 1)")
}
shard <- as.integer(arg_value("--shard", "1"))
n_shards <- as.integer(arg_value("--n-shards", "1"))
if (is.na(shard) || is.na(n_shards)) {
  stop("--shard and --n-shards must be integers")
}
rep_range <- m3_shard_rep_range(
  n_reps = config$n_reps,
  shard = shard,
  n_shards = n_shards
)
if (n_shards > 1L && mode %in% c("nb2-stress-map", "nb2-start-probe")) {
  stop(
    "Sharding is currently supported only for smoke, all-fams, and full modes"
  )
}

OUT_DIR <- arg_value("--out-dir", file.path("dev", "precomputed"))
out_prefix <- arg_value("--out-prefix", "m3-coverage")
GRID_RDS <- file.path(OUT_DIR, paste0(out_prefix, "-grid.rds"))
SUMM_RDS <- file.path(OUT_DIR, paste0(out_prefix, "-summary.rds"))

if (!dir.exists(OUT_DIR)) {
  dir.create(OUT_DIR, recursive = TRUE)
}

## ---- Run --------------------------------------------------------------

if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
  config$cells$target <- paste(targets, collapse = ",")
  config$cells$n_boot <- n_boot
  config$cells$n_cores_boot <- n_cores_boot
  config$cells$ci_method <- if (n_boot == 0L) "none" else "bootstrap"
}

n_start_configs <- if (identical(mode, "nb2-start-probe")) {
  nrow(config$start_configs)
} else {
  1L
}
## Seed-base resolution. CLI override via `--seed-base=<int>` wins;
## otherwise mode-specific defaults preserve the 2026-05-17 / 2026-05-20
## historical seeds. Workflow_dispatch plumbs the input here so a pilot
## dispatch can stay clear of the failed 2026-05-19 production seed
## (per Curie 2026-05-24 consult).
seed_base_arg <- arg_value("--seed-base")
run_seed_base <- if (!is.null(seed_base_arg) && nzchar(seed_base_arg)) {
  parsed_seed <- suppressWarnings(as.integer(seed_base_arg))
  if (is.na(parsed_seed)) {
    stop("--seed-base must be an integer (got: ", seed_base_arg, ")")
  }
  parsed_seed
} else if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
  20260520L
} else {
  20260517L
}

cat(sprintf(
  "[m3] mode = %s (%d cells x %d reps x %d start configs; shard = %d/%d, reps %d-%d; n_units = %s; n_traits = %s; lambda_scale = %s; psi_scale = %s; phi = %s; init_strategy = %s; start_method = %s; optimizer = %s; n_init = %d; targets = %s; n_boot = %d; n_cores_boot = %d)\n",
  mode,
  nrow(config$cells),
  config$n_reps,
  n_start_configs,
  shard,
  n_shards,
  rep_range[["start"]],
  rep_range[["end"]],
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
    "surface-specific"
  } else {
    as.character(n_units)
  },
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
    "surface-specific"
  } else {
    as.character(n_traits)
  },
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
    "surface-specific"
  } else {
    sprintf("%.3g", lambda_scale)
  },
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
    "surface-specific"
  } else {
    sprintf("%.3g", psi_scale)
  },
  if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
    "surface-specific"
  } else if (is.null(phi)) {
    "sampled"
  } else {
    format(phi, scientific = FALSE)
  },
  init_strategy,
  start_method_name,
  optimizer,
  n_init,
  paste(targets, collapse = ","),
  n_boot,
  n_cores_boot
))

t_start <- Sys.time()
if (identical(mode, "nb2-stress-map")) {
  grid_df <- m3_run_surface_register(
    surfaces = config$cells,
    n_reps = config$n_reps,
    seed_base = run_seed_base,
    init_strategy = init_strategy,
    start_method = start_method,
    optimizer = optimizer,
    optArgs = optArgs,
    n_init = n_init,
    init_jitter = init_jitter,
    se = se,
    ci_level = ci_level,
    verbose = TRUE
  )
} else if (identical(mode, "nb2-start-probe")) {
  grid_df <- m3_run_start_probe(
    surfaces = config$cells,
    configs = config$start_configs,
    n_reps = config$n_reps,
    seed_base = run_seed_base,
    targets = targets,
    n_boot = n_boot,
    n_cores_boot = n_cores_boot,
    se = se,
    ci_level = ci_level,
    verbose = TRUE
  )
} else {
  grid_df <- m3_run_grid(
    cells = config$cells,
    n_reps = config$n_reps,
    rep_index_start = rep_range[["start"]],
    rep_index_end = rep_range[["end"]],
    seed_base = run_seed_base,
    n_units = n_units,
    n_traits = n_traits,
    lambda_scale = lambda_scale,
    psi_scale = psi_scale,
    phi = phi,
    phi_shape = phi_shape,
    phi_rate = phi_rate,
    init_strategy = init_strategy,
    start_method = start_method,
    optimizer = optimizer,
    optArgs = optArgs,
    n_init = n_init,
    init_jitter = init_jitter,
    se = se,
    targets = targets,
    n_boot = n_boot,
    n_cores_boot = n_cores_boot,
    ci_level = ci_level,
    parallel = FALSE # workflow matrix parallelises cells
  )
}
t_elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

summary_df <- m3_summarise(grid_df)
report <- if (mode %in% c("nb2-stress-map", "nb2-start-probe")) {
  m3_diagnostic_report_data(grid_df)
} else {
  NULL
}
dashboard_path <- NULL
if (
  !is.null(report) &&
    requireNamespace("ggplot2", quietly = TRUE) &&
    isTRUE(capabilities("png"))
) {
  dashboard_path <- file.path(
    OUT_DIR,
    paste0(out_prefix, "-source-map-dashboard.png")
  )
  m3_write_source_map_dashboard(grid_df, dashboard_path)
} else if (!is.null(report)) {
  reason <- if (!requireNamespace("ggplot2", quietly = TRUE)) {
    "ggplot2 is unavailable"
  } else {
    "PNG device is unavailable"
  }
  warning(
    paste0(reason, "; skipping M3 source-map dashboard render"),
    call. = FALSE
  )
}

cat(sprintf(
  "[m3] total time: %.1fs (%d cells, %d reps each)\n",
  t_elapsed,
  nrow(config$cells),
  config$n_reps
))
cat("[m3] per-cell summary:\n")
print(summary_df, row.names = FALSE)

## ---- Persist artefacts -----------------------------------------------

artefact <- list(
  meta = list(
    label = config$label,
    mode = mode,
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    gllvmTMB_ver = as.character(utils::packageVersion("gllvmTMB")),
    R_version = R.version.string,
    elapsed_s = t_elapsed,
    seed_base = run_seed_base,
    n_reps = config$n_reps,
    shard = shard,
    n_shards = n_shards,
    rep_index_start = rep_range[["start"]],
    rep_index_end = rep_range[["end"]],
    n_reps_this_shard = rep_range[["end"]] - rep_range[["start"]] + 1L,
    n_cells = nrow(config$cells),
    n_start_configs = n_start_configs,
    start_configs = if (identical(mode, "nb2-start-probe")) {
      config$start_configs
    } else {
      NULL
    },
    n_units = n_units,
    n_traits = n_traits,
    lambda_scale = lambda_scale,
    psi_scale = psi_scale,
    phi = phi,
    phi_shape = phi_shape,
    phi_rate = phi_rate,
    init_strategy = init_strategy,
    start_method = start_method_name,
    start_jitter = start_jitter,
    optimizer = optimizer,
    optArgs = optArgs,
    n_init = n_init,
    init_jitter = init_jitter,
    se = se,
    targets = targets,
    n_boot = n_boot,
    n_cores_boot = n_cores_boot,
    ci_level = ci_level
  ),
  grid = grid_df,
  summary = summary_df,
  diagnostic_report = report,
  diagnostic_dashboard = if (!is.null(dashboard_path)) {
    list(path = dashboard_path)
  } else {
    NULL
  }
)

saveRDS(artefact, GRID_RDS)
saveRDS(summary_df, SUMM_RDS)
if (!is.null(report)) {
  REPORT_MD <- file.path(OUT_DIR, paste0(out_prefix, "-diagnostic-report.md"))
  m3_write_diagnostic_report(report, REPORT_MD)
  cat(sprintf("[m3] saved -> %s (diagnostic report)\n", REPORT_MD))
  if (!is.null(dashboard_path)) {
    cat(sprintf("[m3] saved -> %s (source-map dashboard)\n", dashboard_path))
  }
}

cat(sprintf("[m3] saved -> %s (long-format)\n", GRID_RDS))
cat(sprintf("[m3] saved -> %s (per-cell summary)\n", SUMM_RDS))
