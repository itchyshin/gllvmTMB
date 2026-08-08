## dev/isdm-probe.R
##
## Probe for issue #945: is a mixed-family-within-species fit (one species,
## some rows Poisson "presence-only", other rows Bernoulli/cloglog
## "presence-absence") runnable today?
##
## Uses the INSTALLED gllvmTMB (do not devtools::load_all()).
## Self-contained, seeded, re-runnable. Run with:
##   Rscript dev/isdm-probe.R
##
## Lane rule: this worktree only. Do not touch R/, src/, tests/.

suppressPackageStartupMessages(library(gllvmTMB))
cat("gllvmTMB version loaded:", as.character(packageVersion("gllvmTMB")), "\n")
cat("R version:", R.version.string, "\n\n")

hr <- function(x) cat("\n", strrep("=", 10), x, strrep("=", 10), "\n", sep = "")

## ---------------------------------------------------------------------
## T1 -- one species, mixed family WITHIN the species via `source`
## ---------------------------------------------------------------------
hr("T1: one species, family varies by `source` (po/pa) within it")

set.seed(101)
n_cell <- 60
cell   <- factor(seq_len(n_cell))
env    <- rnorm(n_cell)

b0_po <- 0.5; b1_po <- 0.4
b0_pa <- -0.3; b1_pa <- 0.6

y_po <- rpois(n_cell, exp(b0_po + b1_po * env))
p_pa <- 1 - exp(-exp(b0_pa + b1_pa * env))   # cloglog inverse link
y_pa <- rbinom(n_cell, 1, p_pa)

df1 <- rbind(
  data.frame(cell = cell, trait = factor("sp1"), source = factor("po"), env = env, value = y_po),
  data.frame(cell = cell, trait = factor("sp1"), source = factor("pa"), env = env, value = y_pa)
)
df1 <- df1[order(df1$cell), ]

family_list1 <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(family_list1, "family_var") <- "source"

fit1 <- tryCatch(
  gllvmTMB(
    value ~ 1 + env + source,
    data   = df1,
    trait  = "trait",
    unit   = "cell",
    family = family_list1,
    silent = TRUE
  ),
  error = function(e) e
)

if (inherits(fit1, "error")) {
  cat("T1 ERRORED:\n")
  print(fit1)
} else {
  cat("T1 fit succeeded.\n")
  cat("length(family_id_vec):", length(fit1$tmb_data$family_id_vec), "\n")
  cat("length(link_id_vec):  ", length(fit1$tmb_data$link_id_vec), "\n")
  cat("nrow(data):            ", nrow(df1), "\n\n")
  cat("family_id_vec x source (1=binomial, 2=poisson):\n")
  print(table(fit1$tmb_data$family_id_vec, df1$source))
  cat("\nlink_id_vec x source:\n")
  print(table(fit1$tmb_data$link_id_vec, df1$source))
  cat("\nfit$opt$convergence:", fit1$opt$convergence, "\n")
  cat("fit$opt$message:     ", fit1$opt$message, "\n")
  cat("sd_report$pdHess:    ", fit1$sd_report$pdHess, "\n")
}

## ---------------------------------------------------------------------
## T2 -- 3 species, latent(0 + trait | cell, d = 1), each (cell, species)
## contributing a po row and a pa row
## ---------------------------------------------------------------------
hr("T2: 3 species + latent(0 + trait | cell, d = 1)")

set.seed(202)
n_sp <- 3
Lambda <- matrix(c(0.8, 0.5, -0.4), nrow = n_sp, ncol = 1)
u <- rnorm(n_cell)

b0_po <- c(0.3, 0.1, -0.2); b1_po <- c(0.4, 0.3, 0.2)
b0_pa <- c(-0.2, -0.4, 0.1); b1_pa <- c(0.5, 0.4, 0.3)

rows <- list()
for (s in seq_len(n_sp)) {
  eta_lv <- u * Lambda[s, 1]
  y_po_s <- rpois(n_cell, exp(b0_po[s] + b1_po[s] * env + eta_lv))
  p_pa_s <- 1 - exp(-exp(b0_pa[s] + b1_pa[s] * env + eta_lv))
  y_pa_s <- rbinom(n_cell, 1, p_pa_s)
  rows[[length(rows) + 1L]] <- data.frame(cell = seq_len(n_cell), trait = paste0("sp", s),
                                           source = "po", env = env, value = y_po_s)
  rows[[length(rows) + 1L]] <- data.frame(cell = seq_len(n_cell), trait = paste0("sp", s),
                                           source = "pa", env = env, value = y_pa_s)
}
df2 <- do.call(rbind, rows)
df2$cell   <- factor(df2$cell)
df2$trait  <- factor(df2$trait)
df2$source <- factor(df2$source)

family_list2 <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(family_list2, "family_var") <- "source"

## cluster = "trait" is the natural user choice here: the 3 species ARE the
## trait levels, and we want `unit_obs` (site_species) built per (cell, sp),
## not collapsed further via a missing default "species" column (see T4).
fit2 <- tryCatch(
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:env + latent(0 + trait | cell, d = 1),
    data    = df2,
    trait   = "trait",
    unit    = "cell",
    cluster = "trait",
    family  = family_list2,
    silent  = TRUE
  )),
  error = function(e) e
)

if (inherits(fit2, "error")) {
  cat("T2 ERRORED:\n")
  print(fit2)
} else {
  cat("T2 fit succeeded.\n")
  cat("fit$opt$convergence:", fit2$opt$convergence, "\n")
  cat("fit$opt$message:     ", fit2$opt$message, "\n")
  cat("sd_report$pdHess:    ", fit2$sd_report$pdHess, "\n\n")
  cat("family_id_vec x source:\n")
  print(table(fit2$tmb_data$family_id_vec, df2$source))
  lv <- getLV(fit2)
  cat("\ngetLV(fit2) dim:", paste(dim(lv), collapse = " x "),
      " (n_cell =", n_cell, ", n_sp =", n_sp, ")\n")
}

## ---------------------------------------------------------------------
## T3 -- starting-value footgun
## ---------------------------------------------------------------------
hr("T3: starting-value footgun (raw-y lm.fit on mixed count/binary response)")

if (!inherits(fit2, "error")) {
  cat("start_provenance for the default-start T2 fit:\n")
  print(fit2$start_provenance)

  cat("\nIllustration: manual lm.fit(X_fix, raw y) as the default init path\n")
  cat("does when the family mix is not all-log-link and not multi-trial binomial\n")
  cat("(see R/fit-multi.R ~2794-2850; our mix triggers the final `else` branch):\n")
  X_fix <- fit2$X_fix
  fit_lm_illustration <- lm.fit(X_fix, df2$value)
  print(fit_lm_illustration$coefficients)

  cat("\nComparison fit using control = gllvmTMBcontrol(start_method = list(method = \"indep\")),\n")
  cat("which copies fixed effects from a per-family independent-diagonal fit instead:\n")
  fit2_indep <- tryCatch(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + trait:env + latent(0 + trait | cell, d = 1),
      data    = df2, trait = "trait", unit = "cell", cluster = "trait",
      family  = family_list2, silent = TRUE,
      control = gllvmTMBcontrol(start_method = list(method = "indep"))
    )),
    error = function(e) e
  )
  if (inherits(fit2_indep, "error")) {
    cat("start_method='indep' fit ERRORED:\n"); print(fit2_indep)
  } else {
    cat("default-start : convergence =", fit2$opt$convergence,
        " iterations =", fit2$opt$iterations,
        " logLik =", -fit2$opt$objective, "\n")
    cat("indep-start   : convergence =", fit2_indep$opt$convergence,
        " iterations =", fit2_indep$opt$iterations,
        " logLik =", -fit2_indep$opt$objective, "\n")
  }

  cat("\nXcoef_fixed is NOT a general starting-value hook: per ?gllvmTMB and\n")
  cat("R/fit-multi.R .normalise_Xcoef_fixed(), values must currently be 0\n")
  cat("(structural-zero pinning only), not arbitrary start values.\n")
}

## ---------------------------------------------------------------------
## T4 -- unit_obs collapse
## ---------------------------------------------------------------------
hr("T4: unit_obs (within-unit grouping) collapse")

if (!inherits(fit2, "error")) {
  cat("With cluster = \"trait\" (T2's fit):\n")
  cat("  unit_obs_col:", fit2$unit_obs_col, "\n")
  cat("  n_site_species:", fit2$n_site_species, " (n_cell * n_sp =", n_cell * n_sp, ")\n")
  tab2 <- table(fit2$data[[fit2$unit_obs_col]], df2$source)
  cat("  distinct sources sharing one site_species level (table of counts):\n")
  print(table(rowSums(tab2 > 0)))
  cat("  example rows for cell=1, trait=sp1:\n")
  print(fit2$data[df2$cell == "1" & df2$trait == "sp1", c("cell", "trait", "source", fit2$unit_obs_col)])
}

cat("\nWith the DEFAULT cluster (\"species\", not present in this data -- a\n")
cat("common real-world case since the mixed-family `source` example has no\n")
cat("separate 'species' column distinct from `trait`):\n")
fit2_defclust <- tryCatch(
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + trait:env + latent(0 + trait | cell, d = 1),
    data   = df2, trait = "trait", unit = "cell",
    family = family_list2, silent = TRUE
  )),
  error = function(e) e
)
if (inherits(fit2_defclust, "error")) {
  cat("default-cluster fit ERRORED:\n"); print(fit2_defclust)
} else {
  cat("  unit_obs_col:", fit2_defclust$unit_obs_col, "\n")
  cat("  n_site_species:", fit2_defclust$n_site_species, " (n_cell =", n_cell, ")\n")
  cat("  levels (head):\n")
  print(head(levels(fit2_defclust$data[[fit2_defclust$unit_obs_col]]), 6))
  cat("  -> with the default cluster, species AND source both collapse into\n")
  cat("     one unit_obs level per cell, because `cluster` defaults to a\n")
  cat("     'species' column that does not exist here and is synthesised as\n")
  cat("     a constant placeholder (R/gllvmTMB.R ~470-475).\n")
}

## ---------------------------------------------------------------------
## T5 -- extract_Sigma scoring call
## ---------------------------------------------------------------------
hr("T5: extract_Sigma(fit2, level='unit', part='total', link_residual=...)")

if (!inherits(fit2, "error")) {
  cat("--- link_residual = 'none' ---\n")
  res_none <- tryCatch(
    withCallingHandlers(
      extract_Sigma(fit2, level = "unit", part = "total", link_residual = "none"),
      warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
    ),
    error = function(e) e
  )
  if (inherits(res_none, "error")) {
    cat("ERROR:\n"); print(res_none)
  } else if (is.null(res_none)) {
    cat("RESULT IS NULL\n")
  } else {
    cat("Sigma:\n"); print(res_none$Sigma)
    cat("R:\n"); print(res_none$R)
  }

  cat("\n--- link_residual = 'auto' ---\n")
  res_auto <- tryCatch(
    withCallingHandlers(
      extract_Sigma(fit2, level = "unit", part = "total", link_residual = "auto"),
      warning = function(w) { cat("WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
    ),
    error = function(e) e
  )
  if (inherits(res_auto, "error")) {
    cat("ERROR:\n"); print(res_auto)
  } else if (is.null(res_auto)) {
    cat("RESULT IS NULL\n")
  } else {
    cat("Sigma:\n"); print(res_auto$Sigma)
    cat("R:\n"); print(res_auto$R)
    cat("\nidentical(none$Sigma, auto$Sigma):", identical(res_none$Sigma, res_auto$Sigma), "\n")
    cat("any(is.na(auto$Sigma)):", any(is.na(res_auto$Sigma)), "\n")
  }
}

hr("DONE")
