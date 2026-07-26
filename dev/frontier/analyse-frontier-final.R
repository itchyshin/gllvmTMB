#!/usr/bin/env Rscript
d <- read.csv("/private/tmp/gllvmtmb-va-wiring-20260726/dev/frontier/frontier.csv", stringsAsFactors = FALSE)

## Exclude near-instant failures from runtime aggregates (they measure error
## latency, not fit cost); keep them in status/failure reporting.
d$wall_clock_ok <- d$wall_clock_s
d$wall_clock_ok[d$status %in% c("error", "skipped_family_unsupported")] <- NA
d$objective_hib[d$status %in% c("error", "skipped_family_unsupported")] <- NA

## One-time TMB compilation artifact: the very first GH-VA call in the run
## (poisson, p=8, n=40, seed 20272839) silently paid for lazy compilation of
## the va_r3 TMB template (~17s), which happens once per R session. Flag it
## out of the runtime aggregate (kept, unedited, in frontier.csv itself).
compile_artifact <- d$arm == "gllvmTMB_GH-VA" & d$seed == 20272839
d$wall_clock_ok[compile_artifact] <- NA

cell_mean <- function(df, valcol) {
  agg <- aggregate(df[[valcol]], by = list(family = df$family, p = df$p, n_units = df$n_units, arm = df$arm),
                   FUN = function(x) mean(x, na.rm = TRUE))
  names(agg)[5] <- valcol
  agg
}
rt <- cell_mean(d, "wall_clock_ok")
obj <- cell_mean(d, "objective_hib")

rt_wide <- reshape(rt[, c("family","p","n_units","arm","wall_clock_ok")],
                   idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(rt_wide) <- gsub("wall_clock_ok\\.", "", names(rt_wide))
obj_wide <- reshape(obj[, c("family","p","n_units","arm","objective_hib")],
                    idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(obj_wide) <- gsub("objective_hib\\.", "", names(obj_wide))

master <- merge(rt_wide, obj_wide, by = c("family","p","n_units"), suffixes = c("_s", "_obj"))
master <- master[order(master$family, master$p, master$n_units), ]

cat("==== MASTER TABLE ====\n")
print(master, row.names = FALSE, digits = 6)

cat("\n==== Bernoulli: gap, per-cell gap, cost-per-nat ====\n")
mb <- subset(master, family == "bernoulli")
mb$gap_nats <- mb$`gllvmTMB_GH-VA_obj` - mb$gllvm_JJ_obj
mb$n_cells <- mb$p * mb$n_units
mb$gap_per_cell <- mb$gap_nats / mb$n_cells
mb$ghva_over_jj_time <- mb$`gllvmTMB_GH-VA_s` / mb$gllvm_JJ_s
mb$nats_per_second <- mb$gap_nats / mb$`gllvmTMB_GH-VA_s`
print(mb[, c("p","n_units","n_cells","gap_nats","gap_per_cell","gllvmTMB_GH-VA_s","gllvm_JJ_s","ghva_over_jj_time","nats_per_second")],
     row.names = FALSE, digits = 5)

cat("\n==== Poisson: Laplace/GH-VA runtime ratio + scaling p8->p40 (n=100) ====\n")
mp <- subset(master, family == "poisson")
mp$laplace_over_ghva <- mp$gllvmTMB_Laplace_s / mp$`gllvmTMB_GH-VA_s`
print(mp[, c("p","n_units","gllvmTMB_Laplace_s","gllvmTMB_GH-VA_s","laplace_over_ghva")], row.names=FALSE, digits=4)

cat("\n==== EVA vs GH-VA (bernoulli; NOT a certified bound -- context only) ====\n")
mb$eva_minus_ghva <- mb$gllvm_EVA_obj - mb$`gllvmTMB_GH-VA_obj`
mb$eva_time_ratio <- mb$`gllvmTMB_GH-VA_s` / mb$gllvm_EVA_s
print(mb[, c("p","n_units","gllvm_EVA_obj","gllvmTMB_GH-VA_obj","eva_minus_ghva","gllvm_EVA_s","gllvmTMB_GH-VA_s","eva_time_ratio")],
     row.names=FALSE, digits=6)

write.csv(master, "/private/tmp/gllvmtmb-va-wiring-20260726/dev/frontier/frontier-summary.csv", row.names = FALSE)
cat("\nWrote frontier-summary.csv\n")
