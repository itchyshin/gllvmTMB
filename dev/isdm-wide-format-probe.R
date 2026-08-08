## Jason probe: does the integrated (mixed-family, source-duplicated-row) model
## work in WIDE format (traits() LHS), not just long format?
##
## Lane: claude/experiment-integrated-sdm. Worktree-only, no package edits.

devtools::load_all("/Users/z3437171/local-scratch/worktrees/gllvmtmb-isdm", quiet = TRUE)

set.seed(1)

## ---- Build a toy wide frame: 5 cells, TWO ROWS PER CELL (source = po/pa),
## 3 species columns. This is the "naive expectation is too quick" shape from
## the task: duplicate (unit) rows distinguished only by a non-trait `source`
## column, expander expected to stack each trait column with the unit value
## repeating.
n_cell <- 5
base <- data.frame(
  cell_id = rep(seq_len(n_cell), each = 2),
  source  = rep(c("po", "pa"), times = n_cell),
  env     = rep(rnorm(n_cell), each = 2)
)
## Species columns: PO rows get Poisson-ish counts, PA rows get 0/1.
sp1 <- ifelse(base$source == "po", rpois(nrow(base), 3), rbinom(nrow(base), 1, 0.5))
sp2 <- ifelse(base$source == "po", rpois(nrow(base), 2), rbinom(nrow(base), 1, 0.4))
sp3 <- ifelse(base$source == "po", rpois(nrow(base), 4), rbinom(nrow(base), 1, 0.6))
wide <- cbind(base, sp1 = sp1, sp2 = sp2, sp3 = sp3)
## per-trait offset columns for the offset(e1,e2,e3) wide syntax
wide$e1 <- ifelse(wide$source == "po", log(1.2), 0)
wide$e2 <- ifelse(wide$source == "po", log(0.8), 0)
wide$e3 <- ifelse(wide$source == "po", log(1.5), 0)

cat("==== wide input ====\n")
print(wide)

## ==== Q1: does rewrite_traits_lhs() carry the non-trait `source` column
## through to the long frame? ====
cat("\n==== Q1: rewrite_traits_lhs() directly ====\n")
f <- traits(sp1, sp2, sp3) ~ 1 + latent(1 | cell_id, d = 1)
rw <- tryCatch(
  gllvmTMB:::rewrite_traits_lhs(formula = f, data = wide, eval_env = environment()),
  error = function(e) { cat("ERROR in rewrite_traits_lhs:\n"); print(e); NULL }
)
if (!is.null(rw)) {
  cat("data_long columns:", paste(names(rw$data_long), collapse = ", "), "\n")
  cat("'source' present in data_long:", "source" %in% names(rw$data_long), "\n")
  print(head(rw$data_long, 12))
  cat("formula_long:\n")
  print(rw$formula_long)
}

## ==== Q2: does attr(family_list, "family_var") <- "source" survive, and
## produce a per-row family_id_vec on an actual fit? ====
cat("\n==== Q2: fit with mixed family keyed on 'source' ====\n")
fam_list <- list(po = poisson(), pa = binomial(link = "cloglog"))
attr(fam_list, "family_var") <- "source"

fit_q2 <- tryCatch(
  gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + latent(1 | cell_id, d = 1),
    data = wide,
    unit = "cell_id",
    family = fam_list,
    silent = TRUE
  ),
  error = function(e) { cat("ERROR fitting Q2:\n"); print(e); NULL }
)
if (!is.null(fit_q2)) {
  cat("fit class:", paste(class(fit_q2), collapse = ", "), "\n")
  fid <- fit_q2$tmb_data$family_id_vec
  cat("length(family_id_vec):", length(fid), " nrow(data):", nrow(fit_q2$data %||% wide), "\n")
  cat("family_id_vec table:\n")
  print(table(fid))
  ## cross-tab against source in the fitted long data if retrievable
  if (!is.null(fit_q2$data) && "source" %in% names(fit_q2$data)) {
    cat("crosstab family_id_vec x source:\n")
    print(table(fit_q2$data$source, fid))
  }
}

## ==== Q3: does the wide offset(e1,e2,e3) survive row duplication? ====
cat("\n==== Q3: offset(e1,e2,e3) with duplicated rows ====\n")
fit_q3 <- tryCatch(
  gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + offset(e1, e2, e3) + latent(1 | cell_id, d = 1),
    data = wide,
    unit = "cell_id",
    family = fam_list,
    silent = TRUE
  ),
  error = function(e) { cat("ERROR fitting Q3:\n"); print(e); print(conditionMessage(e)); NULL }
)
if (!is.null(fit_q3)) {
  cat("fit_q3 class:", paste(class(fit_q3), collapse = ", "), "\n")
  cat("length(tmb_data$offset) if present:\n")
  print(str(fit_q3$tmb_data$offset))
}

## ==== Q4: does getLV() return one score per CELL, not per cell x source? ====
cat("\n==== Q4: getLV() dimension check ====\n")
if (!is.null(fit_q2)) {
  lv <- tryCatch(getLV(fit_q2), error = function(e) { cat("ERROR in getLV:\n"); print(e); NULL })
  if (!is.null(lv)) {
    cat("dim(getLV(fit_q2)):", paste(dim(lv), collapse = " x "), "\n")
    cat("n_cell (expected rows if per-CELL):", n_cell, "\n")
    cat("nrow(wide) (expected rows if per-cell-x-source, i.e. NOT deduplicated):", nrow(wide), "\n")
  }
}

cat("\n==== DONE ====\n")
