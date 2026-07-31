## ADVERSARIAL #856 -- ITEM 2 (the guard) + ITEM 3 (mixed family within one
## trait) + ITEM 4 (the Root-Cause-C verdict).
##
## Hunting for the DANGEROUS outcome: a fit that CONVERGES with a POSITIVE
## DEFINITE Hessian and reports WRONG numbers. A loud failure is fine; a
## silent one is not.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

## ---- shared reporter -----------------------------------------------------
report_fit <- function(label, fit, truth = NULL, note = "") {
  cat("\n---- ", label, " ----\n", sep = "")
  if (inherits(fit, "error")) {
    cat("  ERROR (loud failure): ", conditionMessage(fit), "\n", sep = "")
    return(invisible(NULL))
  }
  conv <- tryCatch(fit$opt$convergence, error = function(e) NA)
  se <- as.numeric(fit$report$sigma_eps)
  m <- fit$tmb_obj$env$map$log_sigma_eps
  ## Hessian PD check on the FREE parameters
  pd <- tryCatch({
    h <- fit$tmb_obj$he(fit$tmb_obj$env$last.par.best[fit$tmb_obj$env$lfixed()])
    ev <- eigen(h, symmetric = TRUE, only.values = TRUE)$values
    list(pd = all(ev > 0), min_ev = min(ev))
  }, error = function(e) list(pd = NA, min_ev = NA))
  sdr_ok <- tryCatch({
    s <- fit$sd_report
    !is.null(s) && isTRUE(s$pdHess)
  }, error = function(e) NA)
  cat("  convergence      : ", conv, "\n", sep = "")
  cat("  sdreport pdHess  : ", sdr_ok, "\n", sep = "")
  cat("  he() PD          : ", pd$pd, "   min eigenvalue: ",
      signif(pd$min_ev, 4), "\n", sep = "")
  cat("  map$log_sigma_eps: ",
      if (is.null(m)) "ABSENT (all free)" else paste(as.character(m), collapse = ", "),
      "\n", sep = "")
  cat("  sigma_eps        : ", paste(signif(se, 5), collapse = ", "), "\n", sep = "")
  if (!is.null(truth)) cat("  TRUE             : ", paste(truth, collapse = ", "), "\n", sep = "")
  if (nzchar(note)) cat("  NOTE: ", note, "\n", sep = "")
  invisible(list(conv = conv, se = se, map = m, pd = pd$pd, sdr = sdr_ok))
}

mk <- function(reps_per_trait, sd_e, sd_u = 1, n_unit = 120L, seed = 1L) {
  set.seed(seed)
  nt <- length(reps_per_trait)
  u <- matrix(rnorm(n_unit * nt, 0, sd_u), n_unit, nt)
  df <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
    do.call(rbind, lapply(seq_len(nt), function(t) {
      data.frame(unit = i, trait = paste0("t", t),
                 value = u[i, t] + rnorm(reps_per_trait[t], 0, sd_e[t]))
    }))
  }))
  df$unit <- factor(df$unit); df$trait <- factor(df$trait)
  df
}

f <- function(form, data, ...) {
  tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB(form, data = data, unit = "unit", trait = "trait", ...)
  )), error = function(e) e)
}

cat("##################### ITEM 2: ADVERSARIAL GUARD DESIGNS ################\n")

## D1: 3 traits, replication 1 / 2 / 5
d1 <- mk(c(1L, 2L, 5L), sd_e = c(0.5, 1.0, 2.0), seed = 101)
cat("\nD1 rows/trait:", paste(table(d1$trait), collapse = ", "), "\n")
report_fit("D1  3 traits, reps 1/2/5, indep(0+trait|unit)",
           f(value ~ 0 + trait + indep(0 + trait | unit), d1),
           truth = c(0.5, 1.0, 2.0),
           note = "t1 (1 rep) must be suppressed; t2 (2 reps, BOUNDARY) and t3 free")

## D2: EVERY trait exactly 2 rows per cell -- the identifiability boundary
d2 <- mk(c(2L, 2L, 2L), sd_e = c(0.3, 1.0, 3.0), seed = 102)
report_fit("D2  all traits exactly 2 rows/cell (identifiability boundary)",
           f(value ~ 0 + trait + indep(0 + trait | unit), d2),
           truth = c(0.3, 1.0, 3.0),
           note = "guard must NOT fire; 1 df per cell -- is the estimate sane?")

## D3: UNBALANCED within a trait -- extreme. t2 has ONE unit with 2 rows,
##     all other units 1 row. The guard's `unique(cell)==length(rows)` test
##     is FALSE, so it does NOT suppress. Is sigma_eps[2] identified?
set.seed(103)
n_unit <- 120L
u <- matrix(rnorm(n_unit * 2, 0, 1), n_unit, 2)
d3 <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  rbind(
    data.frame(unit = i, trait = "t1", value = u[i, 1] + rnorm(4, 0, 0.5)),
    data.frame(unit = i, trait = "t2",
               value = u[i, 2] + rnorm(if (i == 1L) 2L else 1L, 0, 2.0))
  )
}))
d3$unit <- factor(d3$unit); d3$trait <- factor(d3$trait)
cat("\nD3 t2 cells with >1 row:",
    sum(table(d3$unit[d3$trait == "t2"]) > 1L), "of", n_unit, "\n")
report_fit("D3  t2 unbalanced: exactly ONE unit has 2 rows, 119 have 1",
           f(value ~ 0 + trait + indep(0 + trait | unit), d3),
           truth = c(0.5, 2.0),
           note = "guard does NOT fire (not strictly one-row-per-cell). 1 df total for sigma_eps[2].")

## D3b: milder -- 10% of units replicated
set.seed(1031)
d3b <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  rbind(
    data.frame(unit = i, trait = "t1", value = u[i, 1] + rnorm(4, 0, 0.5)),
    data.frame(unit = i, trait = "t2",
               value = u[i, 2] + rnorm(if (i <= 12L) 3L else 1L, 0, 2.0))
  )
}))
d3b$unit <- factor(d3b$unit); d3b$trait <- factor(d3b$trait)
report_fit("D3b t2 unbalanced: 12/120 units have 3 rows, rest 1",
           f(value ~ 0 + trait + indep(0 + trait | unit), d3b),
           truth = c(0.5, 2.0))

## D4: diagonal term on a DIFFERENT grouping than the replication.
##     indep on unit_obs (the W tier) while replication is at the unit tier.
set.seed(104)
d4 <- mk(c(3L, 3L), sd_e = c(0.4, 1.6), seed = 104)
d4$obs <- factor(seq_len(nrow(d4)))          # per-row grouping
report_fit("D4  indep(0+trait|obs) where obs is PER-ROW (W tier)",
           tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
             value ~ 0 + trait + indep(0 + trait | obs),
             data = d4, unit = "unit", trait = "trait", unit_obs = "obs"
           ))), error = function(e) e),
           truth = c(0.4, 1.6),
           note = "cell_W is per-row for BOTH traits -> both should suppress")

## D5: mixed -- t1 replicated at unit, t2 per-row, diag at the W tier
set.seed(105)
d5 <- mk(c(4L, 1L), sd_e = c(0.5, 1.5), seed = 105)
d5$obs <- factor(paste0(d5$unit, "_", ave(seq_len(nrow(d5)),
                                          paste(d5$unit, d5$trait), FUN = seq_along)))
report_fit("D5  indep(0+trait|obs), obs shared across traits within unit-rep",
           tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
             value ~ 0 + trait + indep(0 + trait | obs),
             data = d5, unit = "unit", trait = "trait", unit_obs = "obs"
           ))), error = function(e) e),
           truth = c(0.5, 1.5))

cat("\n##################### ITEM 2e / ITEM 4: latent() Psi ###################\n")

## D6: DEFAULT latent() (folded diagonal Psi) at ONE ROW PER CELL.
##     Psi_t is diagonal per trait at the unit tier -> exactly confounded
##     with sigma_eps[t]. Does the Q7 guard fire? (use_diag_B is computed
##     from kinds=="diag"; a folded latent() Psi may not register.)
set.seed(106)
sim6 <- simulate_site_trait(n_sites = 40, n_species = 1, n_traits = 4,
                            mean_species_per_site = 1,
                            Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2),
                            psi_B = rep(0.2, 4), seed = 106)
d6 <- sim6$data
cat("\nD6 rows:", nrow(d6), " unique (site,trait) cells:",
    length(unique(paste(d6$site, d6$trait))), " -> one row per cell:",
    nrow(d6) == length(unique(paste(d6$site, d6$trait))), "\n")
fit6 <- tryCatch(suppressMessages(suppressWarnings(
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2), data = d6)
)), error = function(e) e)
report_fit("D6  DEFAULT latent(d=2) w/ folded Psi, ONE row per (site,trait)",
           fit6,
           note = "psi_B truth 0.2 (sd 0.447); sigma2_eps truth from simulator")
if (!inherits(fit6, "error")) {
  cat("  psi_B (diag Psi) : ", paste(signif(as.numeric(fit6$report$psi_B %||% NA), 4), collapse = ", "), "\n", sep = "")
  cat("  sd_B             : ", paste(signif(as.numeric(fit6$report$sd_B %||% NA), 4), collapse = ", "), "\n", sep = "")
}

## D7: ROOT CAUSE C reproduction -- loadings-only latent(unique=FALSE),
##     ONE row per (site, trait), 4 traits, d=2.
fit7 <- tryCatch(suppressMessages(suppressWarnings(
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
           data = d6)
)), error = function(e) e)
report_fit("D7  latent(d=2, unique=FALSE) loadings-only, ONE row per cell",
           fit7,
           note = "ROOT CAUSE C: do d=2 of the 4 traits collapse to the sigma_eps boundary?")

## D7b: same but WITH replication (the fixture's fix)
set.seed(107)
sim7b <- simulate_site_trait(n_sites = 30, n_species = 10, n_traits = 4,
                             mean_species_per_site = 10,
                             Lambda_B = matrix(rnorm(8, sd = 0.4), 4, 2),
                             psi_B = rep(0.2, 4), seed = 107)
fit7b <- tryCatch(suppressMessages(suppressWarnings(
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
           data = sim7b$data)
)), error = function(e) e)
report_fit("D7b latent(d=2, unique=FALSE) WITH 10 species/site replication",
           fit7b, note = "the fixture's fix -- does the collapse go away?")

## D7c: is it d-dependent? d = 1, one row per cell, 4 traits.
fit7c <- tryCatch(suppressMessages(suppressWarnings(
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
           data = d6)
)), error = function(e) e)
report_fit("D7c latent(d=1, unique=FALSE), ONE row per cell, 4 traits",
           fit7c, note = "if exactly 1 trait collapses, the mechanism is d-dependent")

cat("\n##################### ITEM 2f: MIXED FAMILY (per trait) ################\n")

## D8: gaussian trait + poisson trait
set.seed(108)
d8 <- mk(c(3L, 3L), sd_e = c(0.5, 1.0), seed = 108)
d8$family <- factor(ifelse(d8$trait == "t1", "g", "p"), levels = c("g", "p"))
d8$value[d8$family == "p"] <- rpois(sum(d8$family == "p"), lambda = 3)
fl <- list(gaussian(), poisson()); attr(fl, "family_var") <- "family"
fit8 <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = d8, unit = "unit", trait = "trait", family = fl
))), error = function(e) e)
report_fit("D8  trait1 gaussian + trait2 poisson (poisson has NO sigma_eps)",
           fit8, truth = c(0.5, "n/a"),
           note = "sigma_eps[2] has NO informative rows -- flat direction (item 7)")

cat("\n##################### ITEM 3: MIXED FAMILY WITHIN ONE TRAIT ############\n")

## D9: ONE trait carrying BOTH gaussian (identity-scale) and lognormal
##     (log-scale) rows. Per-trait sigma_eps does NOT separate these.
set.seed(109)
n_unit <- 150L
uu <- rnorm(n_unit, 0, 1)
d9 <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  rbind(
    ## trait A: HALF gaussian rows (identity, sd 3.0), HALF lognormal rows
    ## (log scale, sd 0.2). The two scales are ~15x apart.
    data.frame(unit = i, trait = "A", fam = "g",
               value = 10 + uu[i] + rnorm(2, 0, 3.0)),
    data.frame(unit = i, trait = "A", fam = "ln",
               value = exp(1 + rnorm(2, 0, 0.2))),
    data.frame(unit = i, trait = "B", fam = "g",
               value = 5 + uu[i] + rnorm(3, 0, 1.0))
  )
}))
d9$unit <- factor(d9$unit); d9$trait <- factor(d9$trait)
d9$fam <- factor(d9$fam, levels = c("g", "ln"))
fl9 <- list(g = gaussian(), ln = lognormal()); attr(fl9, "family_var") <- "fam"
cat("\nD9 rows per (trait, fam):\n"); print(table(d9$trait, d9$fam))
fit9 <- tryCatch(suppressMessages(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = d9, unit = "unit", trait = "trait", family = fl9
)), error = function(e) e)
cat("\n-- was any WARNING emitted for the within-trait family mix? --\n")
w9 <- tryCatch({
  withCallingHandlers(
    { suppressMessages(gllvmTMB(value ~ 0 + trait + indep(0 + trait | unit),
                                 data = d9, unit = "unit", trait = "trait",
                                 family = fl9)); character(0) },
    warning = function(w) { cat("   WARNING: ", conditionMessage(w), "\n", sep = ""); invokeRestart("muffleWarning") }
  )
}, error = function(e) paste("ERROR:", conditionMessage(e)))
report_fit("D9  trait A = gaussian(sd 3.0 identity) + lognormal(sd 0.2 log)",
           fit9,
           truth = c("A: 3.0 identity AND 0.2 log -- no single value is right", "B: 1.0"),
           note = "does sigma_eps[A] silently pool an identity-scale and a log-scale SD?")

## D9b: the documented PRECEDENT -- link_residual_per_trait() on the same fit
if (!inherits(fit9, "error")) {
  cat("\n-- precedent: link_residual_per_trait() on the SAME fit --\n")
  lr <- tryCatch(
    withCallingHandlers(gllvmTMB:::link_residual_per_trait(fit9),
                        warning = function(w) {
                          cat("   WARNING: ", conditionMessage(w), "\n", sep = "")
                          invokeRestart("muffleWarning")
                        }),
    error = function(e) e)
  if (!inherits(lr, "error")) cat("   value: ", paste(lr, collapse = ", "), "\n", sep = "")
  cat("\n-- does check_gllvmTMB() flag it? --\n")
  ck <- tryCatch(capture.output(print(check_gllvmTMB(fit9))), error = function(e) conditionMessage(e))
  cat(paste(utils::head(ck, 40), collapse = "\n"), "\n")
}
