## ---------------------------------------------------------------------------
## Analysis of dev/vgh/gaussian-collapse.csv.
##
## Reads the CSV at FULL precision.  Do NOT analyse the driver's console log
## instead: it prints d_ll_pooled with "%+9.5f", which rounds a genuine ~1e-9
## residual to "-0.00000" and would license a false claim of an EXACTLY zero
## gap.  (Caught during this arc -- an artifact of the reporting format, not of
## the data.)
##
## Two questions, kept separate:
##   Q_A  Does d_ll COLLAPSE when the parameterisations are matched?  (the gate)
##   Q_B  Is the UNPOOLED d_ll what 19 extra dispersion parameters buy?
##        Distributional now, not five single draws: 12 paired seeds per n, so
##        the whole 2*d_ll distribution can be tested against chisq_19, and the
##        mean against df/2 -- the two checks the adversarial review said were
##        missing.
##
## Usage:  Rscript dev/vgh/gaussian-collapse-analyse.R
## ---------------------------------------------------------------------------
REPO <- "/private/tmp/gllvmtmb-vgh-pluralism"
CSV  <- file.path(REPO, "dev", "vgh", "gaussian-collapse.csv")
if (!file.exists(CSV)) stop("not found: ", CSV, " -- run dev/vgh/gaussian-collapse.R first")
r <- read.csv(CSV)

cat("cells:", nrow(r), " n grid:", paste(sort(unique(r$n)), collapse = "/"),
    " T:", unique(r$T), " d:", unique(r$d), "\n\n")

## --- integrity gates: nothing below is interpretable if these fail ----------
cat("=================== INTEGRITY ===================\n")
yard <- max(abs(r$ll_laplace - r$ll_laplace_pkg), na.rm = TRUE)
cat(sprintf("Yardstick: max |exact_ll(laplace) - logLik(laplace)| = %.3e\n", yard))
cat("  All arms are scored by ONE local exact_ll(), so a differing additive\n")
cat("  constant between it and stats::logLik() cannot corrupt any comparison.\n")
cat(sprintf("  PASS: %s\n", yard < 1e-6))
cat(sprintf("Parameter counts matched (laplace == vgh_pooled) in %d of %d cells\n",
            sum(r$np_laplace == r$np_vgh_pooled), nrow(r)))
cat(sprintf("Pooled phi genuinely flat in %d of %d cells\n",
            sum(r$pooled_phi_is_flat), nrow(r)))
cat(sprintf("VGH hit the sweep cap in %d cells; Laplace non-convergences: %d\n",
            sum(r$vgh_p_at_cap | r$vgh_u_at_cap), sum(r$la_conv != 0)))

## --- Q_A: the collapse gate ------------------------------------------------
cat("\n=================== Q_A: THE COLLAPSE GATE ===================\n")
cat("Same objective + same parameter count => the two engines must reach the\n")
cat("same optimum, so d_ll should fall to optimiser tolerance.\n\n")
qa <- do.call(rbind, lapply(split(r, r$n), function(d) data.frame(
  n = d$n[1], cells = nrow(d),
  median_unpooled = round(median(d$d_ll_unpooled), 3),
  median_pooled   = signif(median(abs(d$d_ll_pooled)), 3),
  max_pooled      = signif(max(abs(d$d_ll_pooled)), 3),
  collapse_factor = signif(median(abs(d$d_ll_unpooled)) / max(abs(d$d_ll_pooled)), 3),
  sigma_relfrob   = signif(median(d$sigma_relfrob), 3),
  stringsAsFactors = FALSE)))
print(qa, row.names = FALSE)
cat(sprintf("\nOVERALL max |d_ll_pooled| across all cells = %.3e\n", max(abs(r$d_ll_pooled))))
cat(sprintf("OVERALL median |d_ll_unpooled|             = %.3f\n", median(abs(r$d_ll_unpooled))))
cat("\nSign of the residual pooled gap is DIAGNOSTIC, not noise:\n")
cat(sprintf("  positive (=> Laplace fell short) in %d of %d cells\n",
            sum(r$d_ll_pooled > 0), nrow(r)))
cat(sprintf("  negative (=> VGH fell short)     in %d of %d cells\n",
            sum(r$d_ll_pooled < 0), nrow(r)))

cat("\n--- Do the two MATCHED arms agree on the estimates, not just the objective? ---\n")
cat(sprintf("Sigma_B relative Frobenius difference: median %.3e, max %.3e\n",
            median(r$sigma_relfrob), max(r$sigma_relfrob)))
cat(sprintf("Recovery vs known truth -- Laplace %.4f vs pooled VGH %.4f (median rel_frob)\n",
            median(r$relfrob_laplace), median(r$relfrob_vgh_p)))
cat(sprintf("  max |difference in recovery between the two arms| = %.3e\n",
            max(abs(r$relfrob_laplace - r$relfrob_vgh_p))))
cat(sprintf("Residual SD -- Laplace %.4f vs pooled VGH %.4f (median); max abs diff %.3e\n",
            median(r$sd_laplace), median(r$sd_vgh_pooled),
            max(abs(r$sd_laplace - r$sd_vgh_pooled))))
cat("  This is the cross-implementation check of the TMB gaussian path: an\n")
cat("  independent pure-R reimplementation reproducing it is a software test.\n")

## --- Q_B: is the unpooled gap what 19 parameters buy? ----------------------
DF <- unique(r$np_vgh_unpool - r$np_laplace)
cat("\n=================== Q_B: IS THE GAP JUST DEGREES OF FREEDOM? ===================\n")
cat("Nested models: Laplace is VGH under phi_1 = ... = phi_T. DGP is\n")
cat("homoscedastic, both log-liks exact => 2*d_ll ~ chisq(df) under a TRUE null.\n")
cat("  df (unpooled - laplace free params) =", paste(DF, collapse = "/"), "\n\n")
for (nn in sort(unique(r$n))) {
  d <- r[r$n == nn, ]
  df <- d$np_vgh_unpool[1] - d$np_laplace[1]
  lr <- 2 * d$d_ll_unpooled
  p  <- pchisq(lr, df, lower.tail = FALSE)
  ks <- suppressWarnings(ks.test(lr, "pchisq", df))
  tt <- t.test(d$d_ll_unpooled, mu = df / 2)
  cat(sprintf("n = %d  (%d seeds)\n", nn, nrow(d)))
  cat(sprintf("  observed d_ll : mean %.3f  sd %.3f   [null predicts mean %.1f, sd %.3f]\n",
              mean(d$d_ll_unpooled), sd(d$d_ll_unpooled), df / 2, sqrt(2 * df) / 2))
  cat(sprintf("  per-cell LR   : %d of %d cells reach p < 0.05\n", sum(p < 0.05), length(p)))
  cat(sprintf("  DISTRIBUTION  : KS vs chisq_%d  D = %.4f, p = %.4f\n", df, ks$statistic, ks$p.value))
  cat(sprintf("  MEAN          : t-test vs %.1f      p = %.4f  (95%% CI %.2f to %.2f)\n\n",
              df / 2, tt$p.value, tt$conf.int[1], tt$conf.int[2]))
}
cat("Reading: a HIGH p on both the KS and the t-test means the observed gap is\n")
cat("indistinguishable from what df extra parameters buy on data where the\n")
cat("constraint is TRUE. That refutes the gap being an accuracy advantage. It is\n")
cat("NOT proof of exact equivalence -- absence of evidence against the null.\n")

## --- timing, for the record (not a clean benchmark under contention) --------
cat("\n=================== TIMING (indicative only) ===================\n")
tm <- do.call(rbind, lapply(split(r, r$n), function(d) data.frame(
  n = d$n[1], laplace_s = round(median(d$la_sec), 2),
  vgh_pooled_s = round(median(d$vgh_p_sec), 2),
  vgh_unpooled_s = round(median(d$vgh_u_sec), 2),
  note = "Laplace runs n_init=5 restarts; VGH single-start. NOT comparable.",
  stringsAsFactors = FALSE)))
print(tm, row.names = FALSE)
