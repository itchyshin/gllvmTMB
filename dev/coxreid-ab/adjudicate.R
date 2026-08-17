#!/usr/bin/env Rscript
## Design 121 A+B campaign -- adjudication script.
##
## Reads dev/coxreid-ab/coxreid-ab-full.csv (1,600 rows: 2 families x
## T in {4,8} x n in {100,200} x arm in {A,B} x seed 1:100; ridge = Inf
## both arms) and applies the pre-registered analysis rules in
## docs/design/121-coxreid-validation-slice.md Section 3 EXACTLY as written:
##   - K1 no-effect gate (n=100, both families, |bias reduction| < 2pp)
##   - MCSE governance clause (paired-seed MCSE of the A-B bias difference)
##   - non-convergence rule (moot here: 100% convergence both arms)
##   - runaway-partition rule (degenerate rows, seed-pairing across arms)
## Outputs are printed to stdout for embedding in dev/coxreid-ab/RESULTS.md
## and are not silently summarised away -- every number below is either a
## direct read of the data or a documented aggregate of it.
##
## No package changes. No promotion. This script produces evidence only.

suppressWarnings(suppressMessages({
  stopifnot(requireNamespace("stats", quietly = TRUE))
}))

d <- read.csv("dev/coxreid-ab/coxreid-ab-full.csv", stringsAsFactors = FALSE)
stopifnot(nrow(d) == 1600)
stopifnot(all(d$converged))              # non-convergence rule is moot -- assert it
stopifnot(all(is.na(d$error) | d$error == ""))

cat("=== Design 121 A+B adjudication ===\n")
cat(sprintf("Rows: %d | 100%% convergence: %s | non-finite bias_pct: %d\n\n",
            nrow(d), all(d$converged), sum(!is.finite(d$bias_pct))))

## ---------------------------------------------------------------------
## 1. Degenerate-row partition (runaway rule)
## ---------------------------------------------------------------------
## Design 121 Sec 3 names norm_ratio and max|Lambda| as the runaway signature.
## Use norm_ratio > 10 as the primary flag (explicitly suggested in the task
## brief and consistent with the pre-run's own +669%/+672% runaway reading,
## norm_ratio ~ 7.7 there); report max_abs_lambda alongside, not as a second
## independent gate, since Design 121 treats both as facets of one pathology.
d$runaway <- d$norm_ratio > 10

cat("--- Degenerate (runaway) row counts, norm_ratio > 10 ---\n")
runaway_by_arm <- tapply(d$runaway, d$arm, sum)
print(runaway_by_arm)
cat("\nRunaway rows by family x T x n x arm:\n")
runaway_cells <- aggregate(runaway ~ family + T + n + arm, data = d, FUN = sum)
print(runaway_cells[order(-runaway_cells$runaway), ], row.names = FALSE)

cat("\nmax_abs_lambda summary by arm (all rows):\n")
print(tapply(d$max_abs_lambda, d$arm, summary))
cat("\nmax_abs_lambda summary by arm, runaway rows only:\n")
if (any(d$runaway)) print(tapply(d$max_abs_lambda[d$runaway], d$arm[d$runaway], summary))

## Seed-pairing check: does a runaway in arm A at a given
## family/T/n/seed cell also runaway in arm B (same seed), i.e. is the
## pathology seed-specific and shared across arms (as the pre-run found for
## binomial T8n100 seed 2), or arm-specific?
wide_run <- reshape(d[, c("family", "T", "n", "arm", "seed", "runaway", "norm_ratio")],
                     idvar = c("family", "T", "n", "seed"), timevar = "arm",
                     direction = "wide")
wide_run$paired <- wide_run$runaway.A & wide_run$runaway.B
wide_run$A_only <- wide_run$runaway.A & !wide_run$runaway.B
wide_run$B_only <- !wide_run$runaway.A & wide_run$runaway.B

cat(sprintf(
  "\nSeed-pairing of runaway rows: A&B both runaway = %d, A-only = %d, B-only = %d (of %d seed-cells)\n",
  sum(wide_run$paired), sum(wide_run$A_only), sum(wide_run$B_only), nrow(wide_run)))

## Explicit check for the pre-run's reproducible degenerate cell: binomial
## T=8 n=100.
bt8n100 <- subset(wide_run, family == "binomial" & T == 8 & n == 100)
cat(sprintf(
  "\nbinomial T=8 n=100: %d/%d seeds runaway in A, %d/%d in B, %d/%d in BOTH (paired)\n",
  sum(bt8n100$runaway.A), nrow(bt8n100), sum(bt8n100$runaway.B), nrow(bt8n100),
  sum(bt8n100$paired), nrow(bt8n100)))
cat("Seeds runaway in binomial T=8 n=100 (arm A):\n")
print(bt8n100$seed[bt8n100$runaway.A])

## ---------------------------------------------------------------------
## 2. max_abs_gradient sanity check
## ---------------------------------------------------------------------
cat("\n--- max_abs_gradient sanity (rows above 1e-3) ---\n")
grad_bad <- d[d$max_abs_gradient > 1e-3, ]
cat(sprintf("Rows with max_abs_gradient > 1e-3: %d / %d\n", nrow(grad_bad), nrow(d)))
cat("Overall max_abs_gradient:", max(d$max_abs_gradient), "\n")
if (nrow(grad_bad) > 0) {
  print(aggregate(max_abs_gradient ~ family + T + n + arm, data = grad_bad, FUN = length))
}

## ---------------------------------------------------------------------
## 3. Per-cell bias summary (family x T x n), arm A vs B, paired by seed
## ---------------------------------------------------------------------
cells <- unique(d[, c("family", "T", "n")])
cells <- cells[order(cells$family, cells$T, cells$n), ]

cell_summary <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  fam <- cells$family[i]; Tt <- cells$T[i]; nn <- cells$n[i]
  sub <- d[d$family == fam & d$T == Tt & d$n == nn, ]
  a <- sub[sub$arm == "A", ]; b <- sub[sub$arm == "B", ]
  a <- a[order(a$seed), ]; b <- b[order(b$seed), ]
  stopifnot(identical(a$seed, b$seed))

  diff <- b$bias_pct - a$bias_pct           # paired B - A, per seed
  sd_diff <- sd(diff)
  mcse_diff <- sd_diff / sqrt(length(diff))

  # runaway-excluded (either arm runaway in that seed pair -> drop the pair)
  keep <- !(a$runaway | b$runaway)

  data.frame(
    family = fam, T = Tt, n = nn, n_seeds = nrow(a),
    median_bias_A = median(a$bias_pct), median_bias_B = median(b$bias_pct),
    mean_bias_A = mean(a$bias_pct), mean_bias_B = mean(b$bias_pct),
    mean_bias_A_noRunaway = mean(a$bias_pct[keep]), mean_bias_B_noRunaway = mean(b$bias_pct[keep]),
    n_dropped_runaway_pairs = sum(!keep),
    median_diff_BminusA = median(diff), mean_diff_BminusA = mean(diff),
    sd_diff = sd_diff, mcse_diff = mcse_diff,
    ## K1 quantity: |median bias| reduction of B vs A (closer to 0 is
    ## "reduction"; positive = B closer to zero than A)
    abs_median_reduction = abs(median(a$bias_pct)) - abs(median(b$bias_pct)),
    abs_mean_reduction = abs(mean(a$bias_pct)) - abs(mean(b$bias_pct)),
    abs_mean_reduction_noRunaway = abs(mean(a$bias_pct[keep])) - abs(mean(b$bias_pct[keep])),
    stringsAsFactors = FALSE
  )
}))

cat("\n--- Per-cell bias summary (family x T x n) ---\n")
print(cell_summary, row.names = FALSE, digits = 4)

## ---------------------------------------------------------------------
## 4. Family-level n=100 summaries -- THE K1 GATE CELLS
## ---------------------------------------------------------------------
## K1: "point-bias reduction of arm B vs arm A ... at n=100 in BOTH
## families". Pools T=4 and T=8 within n=100 for each family (200 seed-obs
## per arm per family) -- the natural reading of "at n=100" with T left
## unconditioned by K1's own wording.
n100 <- d[d$n == 100, ]

fam_gate <- do.call(rbind, lapply(sort(unique(n100$family)), function(fam) {
  sub <- n100[n100$family == fam, ]
  a <- sub[sub$arm == "A", ]; b <- sub[sub$arm == "B", ]
  a <- a[order(a$T, a$seed), ]; b <- b[order(b$T, b$seed), ]
  stopifnot(identical(a$T, b$T), identical(a$seed, b$seed))

  diff <- b$bias_pct - a$bias_pct
  sd_diff <- sd(diff)
  mcse_diff <- sd_diff / sqrt(length(diff))

  keep <- !(a$runaway | b$runaway)

  data.frame(
    family = fam, n_pairs = length(diff),
    median_bias_A = median(a$bias_pct), median_bias_B = median(b$bias_pct),
    mean_bias_A = mean(a$bias_pct), mean_bias_B = mean(b$bias_pct),
    mean_bias_A_noRunaway = mean(a$bias_pct[keep]), mean_bias_B_noRunaway = mean(b$bias_pct[keep]),
    n_dropped_runaway_pairs = sum(!keep),
    sd_diff_BminusA = sd_diff, mcse_diff_BminusA = mcse_diff,
    abs_median_reduction_pp = abs(median(a$bias_pct)) - abs(median(b$bias_pct)),
    abs_mean_reduction_pp = abs(mean(a$bias_pct)) - abs(mean(b$bias_pct)),
    abs_mean_reduction_noRunaway_pp = abs(mean(a$bias_pct[keep])) - abs(mean(b$bias_pct[keep])),
    stringsAsFactors = FALSE
  )
}))

cat("\n--- Family-level n=100 summary (K1 gate) ---\n")
print(fam_gate, row.names = FALSE, digits = 4)

## MCSE governance clause: threshold (2pp) must exceed ~2x its achieved MCSE.
## Reported literally as SD(diff)/sqrt(n) on the raw paired bias_pct
## difference (as the clause specifies), PLUS a bootstrap SE of the paired
## MEDIAN difference -- the raw SD/sqrt(n) formula is a mean-precision
## statistic and is dominated by the runaway tail (Sec 3's own "converged,
## unflagged, degenerate fit" risk), while K1 is adjudicated on medians
## (primary, per this script's brief) precisely because medians are robust
## to that tail. Both are reported; neither is allowed to silently replace
## the other.
set.seed(121)
boot_median_diff_se <- function(diff, B = 2000) {
  n <- length(diff)
  meds <- replicate(B, median(sample(diff, n, replace = TRUE)))
  sd(meds)
}

cat("\n--- K1 MCSE governance check ---\n")
for (i in seq_len(nrow(fam_gate))) {
  fam <- fam_gate$family[i]
  sub <- n100[n100$family == fam, ]
  a <- sub[sub$arm == "A", ]; b <- sub[sub$arm == "B", ]
  a <- a[order(a$T, a$seed), ]; b <- b[order(b$T, b$seed), ]
  diff <- b$bias_pct - a$bias_pct

  mcse_raw <- fam_gate$mcse_diff_BminusA[i]
  mcse_boot_median <- boot_median_diff_se(diff)

  cat(sprintf(
    "%s: raw paired MCSE(B-A) [mean/SD-based, spec-literal] = %.3fpp (2x = %.3fpp, %s 2pp threshold)\n",
    fam, mcse_raw, 2 * mcse_raw, if (2 > 2 * mcse_raw) "CLEARS" else "does NOT clear"))
  cat(sprintf(
    "%s: bootstrap MCSE of paired MEDIAN(B-A) [robust, matches K1's primary metric] = %.3fpp (2x = %.3fpp, %s 2pp threshold)\n",
    fam, mcse_boot_median, 2 * mcse_boot_median,
    if (2 > 2 * mcse_boot_median) "CLEARS" else "does NOT clear"))
}

## ---------------------------------------------------------------------
## 5. K1 verdict
## ---------------------------------------------------------------------
cat("\n--- K1 verdict (primary: medians, secondary: means reported) ---\n")
## K1's own wording is a SIGNED test on the reduction quantity itself
## (abs(A) - abs(B): positive = B closer to zero than A = bias reduced;
## negative = B moved further from zero than A = bias increased), compared
## directly against the 2pp threshold -- NOT a test on the absolute value of
## the reduction. A negative reduction trivially satisfies "< 2pp".
k1_fires <- all(fam_gate$abs_median_reduction_pp < 2)
for (i in seq_len(nrow(fam_gate))) {
  fam <- fam_gate$family[i]
  cat(sprintf(
    "%s: median|A|=%.2f median|B|=%.2f -> bias reduction (B vs A) = %.3fpp (median, PRIMARY) | %.3fpp (mean) | %.3fpp (mean, runaway-excluded)\n",
    fam, abs(fam_gate$median_bias_A[i]), abs(fam_gate$median_bias_B[i]),
    fam_gate$abs_median_reduction_pp[i], fam_gate$abs_mean_reduction_pp[i],
    fam_gate$abs_mean_reduction_noRunaway_pp[i]
  ))
}
cat(sprintf("\nK1 (median-based, primary): %s\n",
            if (k1_fires) "FIRES -- bias reduction < 2pp in BOTH families -> Cox-Reid hypothesis DEAD for this parameterisation"
            else "does not fire on medians alone (check both families individually above)"))

## ---------------------------------------------------------------------
## 6. Wall-time totals
## ---------------------------------------------------------------------
cat("\n--- Wall time ---\n")
cat(sprintf("Total campaign wall time (sum wall_time_s): %.1f s = %.2f min = %.3f h\n",
            sum(d$wall_time_s), sum(d$wall_time_s) / 60, sum(d$wall_time_s) / 3600))
cat("By arm:\n")
print(tapply(d$wall_time_s, d$arm, sum))
cat("\nPer-fit wall time summary (all rows):\n")
print(summary(d$wall_time_s))

cat("\n=== end adjudication ===\n")
