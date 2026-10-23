## Aggregate the 300 per-(family,size,seed) RDS files into a per-seed CSV
## and a per-cell (family x size) pass-rate summary CSV against the
## predeclared bars. Run on Totoro. Mirrors dev/gapclose/arcD/recovery's
## aggregate.R pattern, adapted to ordinal_logit / censored_poisson's own
## metrics (each family keeps its own bars; unused columns are NA).

args <- commandArgs(trailingOnly = TRUE)
out_dir <- args[[1]]     ## e.g. ~/gllvmtmb-arcF-recovery/out
csv_dir <- args[[2]]     ## e.g. ~/gllvmtmb-arcF-recovery/summary

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
files <- list.files(out_dir, pattern = "\\.rds$", full.names = TRUE)
cat("files:", length(files), "\n")

rows <- list()
for (f in files) {
  r <- readRDS(f)
  rows[[length(rows) + 1L]] <- data.frame(
    family = r$family, size = r$size, seed = r$seed,
    runtime = r$runtime,
    convergence = if (is.null(r$convergence)) NA_integer_ else r$convergence,
    max_gradient = if (is.null(r$max_gradient)) NA_real_ else r$max_gradient,
    pd_hessian = if (is.null(r$pd_hessian)) NA else r$pd_hessian,
    error = if (is.null(r$error)) NA_character_ else r$error,
    frac_censored = if (!is.null(r$frac_censored)) r$frac_censored else NA_real_,
    median_rel_loading = if (!is.null(r$median_rel_loading)) r$median_rel_loading else NA_real_,
    max_rel_loading = if (!is.null(r$max_rel_loading)) r$max_rel_loading else NA_real_,
    max_abs_cutpoint = if (!is.null(r$max_abs_cutpoint)) r$max_abs_cutpoint else NA_real_,
    max_int_err = if (!is.null(r$max_int_err)) r$max_int_err else NA_real_,
    rel_frob = if (!is.null(r$rel_frob)) r$rel_frob else NA_real_,
    stringsAsFactors = FALSE
  )
}
df <- do.call(rbind, rows)
write.csv(df, file.path(csv_dir, "per_seed_summary.csv"), row.names = FALSE)
cat("wrote per_seed_summary.csv:", nrow(df), "rows\n")

## Predeclared bars (verbatim from the shipped tests)
bar_ordlogit <- list(median_rel_loading = 0.25, max_rel_loading = 0.40, max_abs_cutpoint = 0.30)
bar_cpois    <- list(max_int_err = 0.15, rel_frob = 0.25)

cells <- unique(df[, c("family", "size")])
cell_summary <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  fam <- cells$family[i]; sz <- cells$size[i]
  sub <- df[df$family == fam & df$size == sz, ]
  n_seeds <- nrow(sub)
  n_conv0 <- sum(sub$convergence == 0, na.rm = TRUE)
  n_pd <- sum(sub$pd_hessian == TRUE, na.rm = TRUE)

  if (fam == "ordinal_logit") {
    ok_a <- sub$median_rel_loading < bar_ordlogit$median_rel_loading
    ok_b <- sub$max_rel_loading < bar_ordlogit$max_rel_loading
    ok_c <- sub$max_abs_cutpoint < bar_ordlogit$max_abs_cutpoint
    ok_a[is.na(ok_a)] <- FALSE; ok_b[is.na(ok_b)] <- FALSE; ok_c[is.na(ok_c)] <- FALSE
    conv_ok <- !is.na(sub$convergence) & sub$convergence == 0
    joint <- conv_ok & ok_a & ok_b & ok_c
    data.frame(
      family = fam, size = sz, n_seeds = n_seeds,
      frac_converged = n_conv0 / n_seeds,
      frac_pd_hessian = n_pd / n_seeds,
      frac_bar_median_rel_loading = mean(ok_a),
      frac_bar_max_rel_loading = mean(ok_b),
      frac_bar_max_abs_cutpoint = mean(ok_c),
      frac_all_bars_joint = mean(joint),
      median_median_rel_loading = stats::median(sub$median_rel_loading, na.rm = TRUE),
      p90_median_rel_loading = stats::quantile(sub$median_rel_loading, 0.90, na.rm = TRUE),
      median_max_rel_loading = stats::median(sub$max_rel_loading, na.rm = TRUE),
      p90_max_rel_loading = stats::quantile(sub$max_rel_loading, 0.90, na.rm = TRUE),
      median_max_abs_cutpoint = stats::median(sub$max_abs_cutpoint, na.rm = TRUE),
      p90_max_abs_cutpoint = stats::quantile(sub$max_abs_cutpoint, 0.90, na.rm = TRUE),
      median_runtime_s = stats::median(sub$runtime, na.rm = TRUE)
    )
  } else if (fam == "censored_poisson") {
    ok_a <- sub$max_int_err < bar_cpois$max_int_err
    ok_b <- sub$rel_frob < bar_cpois$rel_frob
    ok_a[is.na(ok_a)] <- FALSE; ok_b[is.na(ok_b)] <- FALSE
    conv_ok <- !is.na(sub$convergence) & sub$convergence == 0
    joint <- conv_ok & ok_a & ok_b
    data.frame(
      family = fam, size = sz, n_seeds = n_seeds,
      frac_converged = n_conv0 / n_seeds,
      frac_pd_hessian = n_pd / n_seeds,
      frac_bar_median_rel_loading = NA_real_,
      frac_bar_max_rel_loading = NA_real_,
      frac_bar_max_abs_cutpoint = NA_real_,
      frac_all_bars_joint = mean(joint),
      median_median_rel_loading = NA_real_,
      p90_median_rel_loading = NA_real_,
      median_max_rel_loading = NA_real_,
      p90_max_rel_loading = NA_real_,
      median_max_abs_cutpoint = NA_real_,
      p90_max_abs_cutpoint = NA_real_,
      median_runtime_s = stats::median(sub$runtime, na.rm = TRUE)
    )
  } else {
    stop("unknown family: ", fam)
  }
}))

## Add censored_poisson-specific bar columns separately (kept out of the
## generic table above to avoid NA-riddled shared columns across families).
cp_extra <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  fam <- cells$family[i]; sz <- cells$size[i]
  if (fam != "censored_poisson") return(NULL)
  sub <- df[df$family == fam & df$size == sz, ]
  ok_a <- sub$max_int_err < bar_cpois$max_int_err
  ok_b <- sub$rel_frob < bar_cpois$rel_frob
  ok_a[is.na(ok_a)] <- FALSE; ok_b[is.na(ok_b)] <- FALSE
  data.frame(
    family = fam, size = sz,
    frac_bar_max_int_err = mean(ok_a),
    frac_bar_rel_frob = mean(ok_b),
    median_max_int_err = stats::median(sub$max_int_err, na.rm = TRUE),
    p90_max_int_err = stats::quantile(sub$max_int_err, 0.90, na.rm = TRUE),
    median_rel_frob = stats::median(sub$rel_frob, na.rm = TRUE),
    p90_rel_frob = stats::quantile(sub$rel_frob, 0.90, na.rm = TRUE),
    median_frac_censored = stats::median(sub$frac_censored, na.rm = TRUE)
  )
}))

write.csv(cell_summary, file.path(csv_dir, "per_cell_summary.csv"), row.names = FALSE)
if (!is.null(cp_extra)) {
  write.csv(cp_extra, file.path(csv_dir, "per_cell_censored_poisson_extra.csv"), row.names = FALSE)
}
cat("wrote per_cell_summary.csv:\n")
print(cell_summary)
if (!is.null(cp_extra)) {
  cat("wrote per_cell_censored_poisson_extra.csv:\n")
  print(cp_extra)
}
