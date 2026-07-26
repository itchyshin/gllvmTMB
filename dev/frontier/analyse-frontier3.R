#!/usr/bin/env Rscript
d <- read.csv("/private/tmp/gllvmtmb-va-wiring-20260726/dev/frontier/frontier.csv", stringsAsFactors = FALSE)

## Runtime is only meaningful for calls that actually ran an optimisation.
## "error" / "skipped_family_unsupported" fire near-instantly (0.00-0.01s)
## and would silently deflate the mean if pooled in -- exclude them from
## runtime aggregates, but keep and report their counts separately.
d$wall_clock_ok <- d$wall_clock_s
d$wall_clock_ok[d$status %in% c("error", "skipped_family_unsupported")] <- NA
d$objective_hib[d$status %in% c("error", "skipped_family_unsupported")] <- NA

cell_stat <- function(df, valcol, fun = function(x) mean(x, na.rm = TRUE)) {
  agg <- aggregate(df[[valcol]], by = list(family = df$family, p = df$p, n_units = df$n_units, arm = df$arm), FUN = fun)
  names(agg)[5] <- valcol
  agg
}
n_ok_tab <- aggregate(!is.na(wall_clock_ok) ~ family + p + n_units + arm, d, sum)
names(n_ok_tab)[5] <- "n_ok"

rt <- cell_stat(d, "wall_clock_ok")
obj <- cell_stat(d, "objective_hib")

cat("==== Successful-fit runtime (mean seconds over reps that actually ran) ====\n")
rt_wide <- reshape(rt[, c("family","p","n_units","arm","wall_clock_ok")],
                   idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(rt_wide) <- gsub("wall_clock_ok\\.", "", names(rt_wide))
print(rt_wide[order(rt_wide$family, rt_wide$p, rt_wide$n_units), ], row.names = FALSE, digits = 4)

cat("\n==== n_ok (of 3 seeds) actually completing an optimisation attempt ====\n")
nok_wide <- reshape(n_ok_tab, idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(nok_wide) <- gsub("n_ok\\.", "", names(nok_wide))
print(nok_wide[order(nok_wide$family, nok_wide$p, nok_wide$n_units), ], row.names = FALSE)

cat("\n==== Laplace / GH-VA runtime ratio (successful fits only) ====\n")
rt_wide$laplace_over_ghva <- rt_wide$gllvmTMB_Laplace / rt_wide[["gllvmTMB_GH-VA"]]
print(rt_wide[order(rt_wide$family, rt_wide$p, rt_wide$n_units), c("family","p","n_units","gllvmTMB_Laplace","gllvmTMB_GH-VA","laplace_over_ghva")],
     row.names = FALSE, digits = 4)

cat("\n==== GH-VA / gllvm_JJ runtime ratio (bernoulli, successful fits only) ====\n")
rtb <- subset(rt_wide, family == "bernoulli")
rtb$ghva_over_jj <- rtb[["gllvmTMB_GH-VA"]] / rtb$gllvm_JJ
print(rtb[order(rtb$p, rtb$n_units), c("p","n_units","gllvmTMB_GH-VA","gllvm_JJ","ghva_over_jj")], row.names = FALSE, digits = 4)

cat("\n==== Objective (nats, higher=better), successful fits only ====\n")
obj_wide <- reshape(obj[, c("family","p","n_units","arm","objective_hib")],
                    idvar = c("family","p","n_units"), timevar = "arm", direction = "wide")
names(obj_wide) <- gsub("objective_hib\\.", "", names(obj_wide))
print(obj_wide[order(obj_wide$family, obj_wide$p, obj_wide$n_units), ], row.names = FALSE, digits = 6)

cat("\n==== Accuracy gap GH-VA - gllvm_JJ, absolute AND per-cell (bernoulli) ====\n")
objb <- subset(obj_wide, family == "bernoulli")
objb$gap_nats <- objb[["gllvmTMB_GH-VA"]] - objb$gllvm_JJ
objb$n_cells <- objb$p * objb$n_units
objb$gap_per_cell <- objb$gap_nats / objb$n_cells
print(objb[order(objb$p, objb$n_units), c("p","n_units","n_cells","gllvmTMB_GH-VA","gllvm_JJ","gap_nats","gap_per_cell")],
     row.names = FALSE, digits = 5)

cat("\n==== Runtime scaling ratio p=40/p=8, within each n (successful fits) ====\n")
for (fam in c("poisson","bernoulli")) {
  for (nu in c(40,100)) {
    sub <- subset(rt_wide, family==fam & n_units==nu)
    if (nrow(sub)==3) {
      r8  <- sub[sub$p==8, , drop=FALSE]
      r40 <- sub[sub$p==40, , drop=FALSE]
      cat(sprintf("family=%s n=%d: ", fam, nu))
      for (arm in c("gllvmTMB_GH-VA","gllvmTMB_Laplace","gllvm_JJ","gllvm_VA","gllvm_EVA")) {
        if (arm %in% names(sub)) {
          v8 <- r8[[arm]]; v40 <- r40[[arm]]
          if (length(v8)==1 && length(v40)==1 && !is.na(v8) && !is.na(v40) && v8>0)
            cat(sprintf("%s: x%.2f  ", arm, v40/v8))
        }
      }
      cat("\n")
    }
  }
}
