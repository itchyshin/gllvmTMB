## #856 — does the PER-TRAIT guard actually fire on a MIXED design?
##
## This is the specific new hazard the promotion creates. Q7's original test was
## dataset-wide, so a design where trait 1 has replicates and trait 2 does not
## would NOT trip it; with a per-trait vector, trait 2's sigma_eps_t is then
## exactly confounded with its own psi_t while trait 1 is fine.
##
## Expected after the fix: trait 2 (no replicates) is suppressed, trait 1 is
## genuinely estimated and recovers its true SD. The message should name t2.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
set.seed(4242)

n_unit <- 150L
sd_e   <- c(t1 = 0.5, t2 = 1.5)   # true residual SDs
sd_u   <- c(t1 = 1.0, t2 = 1.0)
reps   <- c(t1 = 4L,   t2 = 1L)   # <-- MIXED: t1 replicated, t2 not

u <- cbind(rnorm(n_unit, 0, sd_u[1]), rnorm(n_unit, 0, sd_u[2]))
df <- do.call(rbind, lapply(seq_len(n_unit), function(i) {
  do.call(rbind, lapply(1:2, function(tt) {
    data.frame(unit = i, trait = paste0("t", tt),
               value = u[i, tt] + rnorm(reps[tt], 0, sd_e[tt]))
  }))
}))
df$unit  <- factor(df$unit); df$trait <- factor(df$trait)

cat("rows:", nrow(df), "\n")
cat("rows per trait:", paste(table(df$trait), collapse = ", "), "\n")
cat("unique (trait,unit) cells per trait:",
    paste(tapply(paste(df$unit, df$trait), df$trait,
                 function(z) length(unique(z))), collapse = ", "), "\n")
cat("-> t1 has 4 rows/cell (identified); t2 has 1 row/cell (confounded)\n\n")

cat("---- fitting (messages shown, to see the per-trait suppression notice) ----\n")
fit <- suppressWarnings(gllvmTMB(
  value ~ 0 + trait + indep(0 + trait | unit),
  data = df, unit = "unit", trait = "trait"
))

cat("\n---- results ----\n")
cat("convergence:", fit$opt$convergence, "\n")
m <- fit$tmb_obj$env$map$log_sigma_eps
cat("map$log_sigma_eps:", if (is.null(m)) "ABSENT (nothing suppressed)" else
      paste(as.character(m), collapse = ", "), "\n")
cat("  -> NA marks a SUPPRESSED trait; a level marks an ESTIMATED one\n")
cat("report$sigma_eps:", paste(signif(fit$report$sigma_eps, 5), collapse = ", "),
    " (length", length(fit$report$sigma_eps), ")\n")
cat("TRUE:              ", paste(sd_e, collapse = ", "), "\n\n")

ok_len <- length(fit$report$sigma_eps) == 2L
ok_t1  <- abs(fit$report$sigma_eps[1] - sd_e[1]) / sd_e[1] < 0.30
ok_sup <- !is.null(m) && is.na(m[2]) && !is.na(m[1])
cat("PASS length-2 vector:            ", ok_len, "\n")
cat("PASS t1 recovered within 30%:    ", ok_t1, "\n")
cat("PASS only t2 suppressed in map:  ", ok_sup, "\n")
