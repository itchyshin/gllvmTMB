#!/usr/bin/env Rscript
d <- read.csv("/private/tmp/gllvmtmb-va-wiring-20260726/dev/frontier/frontier.csv", stringsAsFactors = FALSE)

cat("==== Mean wall-clock (s) by arm x p (pooled over n, seeds) ====\n")
rt <- aggregate(wall_clock_s ~ arm + p, d, function(x) mean(x, na.rm = TRUE))
print(reshape(rt, idvar = "p", timevar = "arm", direction = "wide"))

cat("\n==== Mean wall-clock (s) by arm x family x p (pooled over n, seeds) ====\n")
rt2 <- aggregate(wall_clock_s ~ arm + family + p, d, function(x) mean(x, na.rm = TRUE))
print(rt2[order(rt2$family, rt2$arm, rt2$p), ], row.names = FALSE)

cat("\n==== Laplace / GH-VA runtime ratio by p (pooled over family, n, seeds) ====\n")
wide <- reshape(aggregate(wall_clock_s ~ arm + p, d, mean), idvar = "p", timevar = "arm", direction = "wide")
names(wide) <- gsub("wall_clock_s\\.", "", names(wide))
wide$laplace_over_ghva <- wide$gllvmTMB_Laplace / wide[["gllvmTMB_GH-VA"]]
print(wide[, c("p", "gllvmTMB_Laplace", "gllvmTMB_GH-VA", "laplace_over_ghva")])

cat("\n==== GH-VA / gllvm_JJ runtime ratio by p, bernoulli only ====\n")
db <- subset(d, family == "bernoulli")
wideb <- reshape(aggregate(wall_clock_s ~ arm + p, db, mean), idvar = "p", timevar = "arm", direction = "wide")
names(wideb) <- gsub("wall_clock_s\\.", "", names(wideb))
wideb$ghva_over_jj <- wideb[["gllvmTMB_GH-VA"]] / wideb$gllvm_JJ
print(wideb[, c("p", "gllvmTMB_GH-VA", "gllvm_JJ", "ghva_over_jj")])

cat("\n==== Accuracy: GH-VA - gllvm_JJ objective gap (nats), bernoulli, by p x n ====\n")
acc <- reshape(
  aggregate(objective_hib ~ arm + p + n_units, db, mean),
  idvar = c("p", "n_units"), timevar = "arm", direction = "wide"
)
names(acc) <- gsub("objective_hib\\.", "", names(acc))
acc$gap_nats <- acc[["gllvmTMB_GH-VA"]] - acc$gllvm_JJ
print(acc[order(acc$p, acc$n_units), c("p", "n_units", "gllvmTMB_GH-VA", "gllvm_JJ", "gap_nats")])

cat("\n==== Accuracy: GH-VA - gllvm_JJ gap, bernoulli, by p only (pooled n, seeds) ====\n")
acc2 <- reshape(aggregate(objective_hib ~ arm + p, db, mean), idvar = "p", timevar = "arm", direction = "wide")
names(acc2) <- gsub("objective_hib\\.", "", names(acc2))
acc2$gap_nats <- acc2[["gllvmTMB_GH-VA"]] - acc2$gllvm_JJ
print(acc2[order(acc2$p), c("p", "gllvmTMB_GH-VA", "gllvm_JJ", "gap_nats")])

cat("\n==== Per-row bernoulli GH-VA vs JJ gap, sign check (should always be >=0) ====\n")
byrow <- reshape(db[, c("family","p","n_units","seed","arm","objective_hib")],
                 idvar = c("p","n_units","seed"), timevar = "arm", direction = "wide")
names(byrow) <- gsub("objective_hib\\.", "", names(byrow))
byrow$gap <- byrow[["gllvmTMB_GH-VA"]] - byrow$gllvm_JJ
print(byrow[order(byrow$p, byrow$n_units), c("p","n_units","seed","gllvmTMB_GH-VA","gllvm_JJ","gap")], row.names = FALSE)
cat("min gap:", min(byrow$gap, na.rm=TRUE), " max gap:", max(byrow$gap, na.rm=TRUE),
   " n negative:", sum(byrow$gap < 0, na.rm = TRUE), " n rows:", sum(!is.na(byrow$gap)), "\n")

cat("\n==== GH-VA status counts by family x p ====\n")
print(table(d$family[d$arm=="gllvmTMB_GH-VA"], d$p[d$arm=="gllvmTMB_GH-VA"], d$status[d$arm=="gllvmTMB_GH-VA"]))

cat("\n==== Laplace vs GH-VA: which is more accurate against gllvm_JJ (bernoulli)? ====\n")
byrow2 <- reshape(db[, c("family","p","n_units","seed","arm","objective_hib")],
                  idvar = c("p","n_units","seed"), timevar = "arm", direction = "wide")
names(byrow2) <- gsub("objective_hib\\.", "", names(byrow2))
byrow2$laplace_gap <- byrow2$gllvmTMB_Laplace - byrow2$gllvm_JJ
print(summary(byrow2$laplace_gap))

cat("\n==== Poisson: GH-VA vs gllvm_VA objective (should match near-exactly) ====\n")
dp <- subset(d, family == "poisson")
byrowp <- reshape(dp[, c("p","n_units","seed","arm","objective_hib")],
                  idvar = c("p","n_units","seed"), timevar = "arm", direction = "wide")
names(byrowp) <- gsub("objective_hib\\.", "", names(byrowp))
byrowp$diff <- byrowp[["gllvmTMB_GH-VA"]] - byrowp$gllvm_VA
print(summary(abs(byrowp$diff)))

cat("\n==== Convergence failures detail ====\n")
print(d[d$status %in% c("error","not_converged","failed_variance_domain"), c("family","p","n_units","seed","arm","status","note")], row.names=FALSE)
