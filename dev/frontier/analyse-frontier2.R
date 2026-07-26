#!/usr/bin/env Rscript
d <- read.csv("/private/tmp/gllvmtmb-va-wiring-20260726/dev/frontier/frontier.csv", stringsAsFactors = FALSE)
d$objective_hib[d$status %in% c("error","skipped_family_unsupported")] <- NA

cell_mean <- function(df, valcol) {
  agg <- aggregate(df[[valcol]], by = list(family = df$family, p = df$p, n_units = df$n_units, arm = df$arm),
                   FUN = function(x) mean(x, na.rm = TRUE))
  names(agg)[5] <- valcol
  n_ok <- aggregate(df[[valcol]], by = list(family = df$family, p = df$p, n_units = df$n_units, arm = df$arm),
                    FUN = function(x) sum(!is.na(x)))
  names(n_ok)[5] <- "n_ok"
  merge(agg, n_ok)
}

rt <- cell_mean(d, "wall_clock_s")
obj <- cell_mean(d, "objective_hib")

cat("==== Runtime (mean seconds, n_ok/3 seeds succeeded) by family x p x n x arm ====\n")
rt_wide <- reshape(rt[, c("family","p","n_units","arm","wall_clock_s")],
                   idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(rt_wide) <- gsub("wall_clock_s\\.", "", names(rt_wide))
print(rt_wide[order(rt_wide$family, rt_wide$p, rt_wide$n_units), ], row.names = FALSE, digits = 3)

cat("\n==== n successful reps (of 3) by family x p x n x arm ====\n")
nok_wide <- reshape(rt[, c("family","p","n_units","arm","n_ok")],
                    idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(nok_wide) <- gsub("n_ok\\.", "", names(nok_wide))
print(nok_wide[order(nok_wide$family, nok_wide$p, nok_wide$n_units), ], row.names = FALSE)

cat("\n==== Laplace / GH-VA runtime ratio, by family x p x n ====\n")
rt_wide$laplace_over_ghva <- rt_wide$gllvmTMB_Laplace / rt_wide[["gllvmTMB_GH-VA"]]
print(rt_wide[order(rt_wide$family, rt_wide$p, rt_wide$n_units), c("family","p","n_units","gllvmTMB_Laplace","gllvmTMB_GH-VA","laplace_over_ghva")],
     row.names = FALSE, digits = 3)

cat("\n==== GH-VA / gllvm_JJ runtime ratio (bernoulli only), by p x n ====\n")
rtb <- subset(rt_wide, family == "bernoulli")
rtb$ghva_over_jj <- rtb[["gllvmTMB_GH-VA"]] / rtb$gllvm_JJ
print(rtb[order(rtb$p, rtb$n_units), c("p","n_units","gllvmTMB_GH-VA","gllvm_JJ","ghva_over_jj")], row.names = FALSE, digits = 4)

cat("\n==== Objective (nats, higher = better) by family x p x n x arm ====\n")
obj_wide <- reshape(obj[, c("family","p","n_units","arm","objective_hib")],
                    idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(obj_wide) <- gsub("objective_hib\\.", "", names(obj_wide))
print(obj_wide[order(obj_wide$family, obj_wide$p, obj_wide$n_units), ], row.names = FALSE, digits = 6)

cat("\n==== Accuracy gap: GH-VA - gllvm_JJ, absolute nats AND per-cell (bernoulli only) ====\n")
objb <- subset(obj_wide, family == "bernoulli")
objb$gap_nats <- objb[["gllvmTMB_GH-VA"]] - objb$gllvm_JJ
objb$n_cells <- objb$p * objb$n_units
objb$gap_per_cell <- objb$gap_nats / objb$n_cells
print(objb[order(objb$p, objb$n_units), c("p","n_units","n_cells","gllvmTMB_GH-VA","gllvm_JJ","gap_nats","gap_per_cell")],
     row.names = FALSE, digits = 5)

cat("\n==== Poisson sign/consistency check: GH-VA vs gllvm_VA (should match ~exactly) ====\n")
objp <- subset(obj_wide, family == "poisson")
objp$diff <- objp[["gllvmTMB_GH-VA"]] - objp$gllvm_VA
print(objp[order(objp$p, objp$n_units), c("p","n_units","gllvmTMB_GH-VA","gllvm_VA","diff")], row.names = FALSE, digits = 6)

cat("\n==== gllvm_EVA vs GH-VA (bernoulli; EVA is ALSO a tighter-than-JJ bound in gllvm) ====\n")
print(objb[order(objb$p, objb$n_units), c("p","n_units","gllvmTMB_GH-VA","gllvm_EVA")], row.names = FALSE, digits = 6)
