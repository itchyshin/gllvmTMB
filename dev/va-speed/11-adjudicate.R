fs <- Sys.glob("/tmp/seed-*.rds")
a <- do.call(rbind, lapply(fs, readRDS))
w <- reshape(a[, c("seed","arm","rf")], idvar="seed", timevar="arm", direction="wide")
names(w) <- sub("^rf[.]", "", names(w))
n <- nrow(w)

cat("=== 1. THE GATE (MATURE-VA Item 1: AC rel_frob <= 0.298) ===\n")
cat(sprintf("  AC median = %.4f  ->  %s\n", median(w$ac),
            if (median(w$ac) <= 0.298) "PASS" else "FAIL"))
cat(sprintf("  AC per-seed: %s\n", paste(sprintf("%.4f", sort(w$ac)), collapse=", ")))
cat(sprintf("  AC cells above 0.298: %d of %d\n", sum(w$ac > 0.298), n))

cat("\n=== 2. AC vs gllvm -- IMPLEMENTATION AGREEMENT ===\n")
cat(sprintf("  max relative difference %.3e over %d seeds\n",
            max(abs(w$ac-w$gllvm)/w$gllvm), n))
cat(sprintf("  paired sign test, AC vs gllvm: AC better in %d/%d, exact p = %.3f\n",
            sum(w$ac < w$gllvm), n,
            binom.test(sum(w$ac < w$gllvm), n)$p.value))

cat("\n=== 3. AC vs OUR GH tier -- the edge we were told to protect ===\n")
d <- w$ac - w$gh
cat(sprintf("  medians: GH %.4f   AC %.4f   (lower is better)\n", median(w$gh), median(w$ac)))
cat(sprintf("  AC better in %d of %d seeds\n", sum(w$ac < w$gh), n))
bt <- binom.test(sum(w$ac < w$gh), n)
cat(sprintf("  exact paired sign test: p = %.4f  -> %s\n", bt$p.value,
    if (bt$p.value > 0.05) "NO significant difference either way at n=6" else "significant"))
cat(sprintf("  per-seed (AC - GH): %s\n", paste(sprintf("%+.4f", d), collapse=", ")))
cat(sprintf("  median difference %+.4f\n", median(d)))

cat("\n=== 4. DEGENERACY (the defect that invalidated the last campaign) ===\n")
for (arm in c("gh","ac","gllvm")) {
  v <- w[[arm]]
  cat(sprintf("  %-6s collapses(|rf-1|<1e-6): %d   runaways(rf>10): %d   max %.4f\n",
              arm, sum(abs(v-1)<1e-6), sum(v>10), max(v)))
}
cat("\n=== 5. VARIABILITY ===\n")
for (arm in c("gh","ac","gllvm"))
  cat(sprintf("  %-6s sd %.4f   range [%.4f, %.4f]\n", arm,
              sd(w[[arm]]), min(w[[arm]]), max(w[[arm]])))
