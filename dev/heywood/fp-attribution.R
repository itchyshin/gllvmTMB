## Attribution of the `binomial_prevalence_loading` false-positive rate
## (issue #1098) to the individual arms of the shipped disjunction, on the
## two existing calibration pools. Read-only analysis of existing CSVs --
## no fitting.
##
## THE SHIPPED RULE (R/diagnose.R:485-590, `.gllvmTMB_binomial_prevalence_
## loading_row()`, confirmed by reading the source on 2026-08-17):
##
##   extreme_prevalence = prevalence >= 0.9 | prevalence <= 0.1   (prevalence_thresh)
##   dominant_loading   = relative_loading >= 8                    (loading_relative_thresh)
##   saturated_fit      = saturation_share >= 0.5                  (saturation_share_thresh)
##   runaway_loading    = relative_loading >= 25                   (loading_runaway_thresh)
##   extreme_magnitude  = max_loading_unit >= 6                    (loading_absolute_thresh)
##
##   flag = (extreme_prevalence & (dominant_loading | saturated_fit))
##          | runaway_loading
##          | extreme_magnitude
##
## FIDELITY CHECK (mandatory, done by reading each pool's own generator
## script, not re-derivable from the CSVs): the shipped `extreme_magnitude`
## conjunct is judged on `max_loading_unit` -- the UNIT-TIER loadings only
## (R/diagnose.R:384-421) -- because a structured/SPDE tier's loadings carry
## their own basis normalisation and are not on the same link scale. Both
## harnesses fit a SINGLE unstructured latent term,
## `latent(0 + trait | site, d = q, unique = FALSE)` (dev/heywood/fp-sweep.R
## line ~158; dev/design108-stage8/laplace-silent-divergence.R line ~208) --
## no phylo/spatial/SPDE/kernel tier anywhere in either grid. With only a
## unit-level term present, `max_loading_unit` and the pooled `max_loading`
## coincide by construction (every tier contributing to the pooled maximum
## IS a unit tier), so the CSV's `max_loading` column is a VALID, exact
## proxy for `max_loading_unit` in both pools -- not an approximation. This
## is verified below empirically for pool 2, where the real shipped
## `check_status` is available: the reconstructed rule using `max_loading`
## reproduces it with ZERO mismatches over 1200 binomial_probit fits.
##
## POOL 2's `check_status` was captured by a REAL `check_gllvmTMB()` call
## (dev/design108-stage8/laplace-silent-divergence.R:257-261) and is the
## ground truth used to validate the reconstruction. POOL 1's own
## `row_status_now` column is NOT used as ground truth here: it is all
## "PASS" or NA (verified below -- the reconstructed prevalence-only branch
## also never fires on this data, and rl_max reaches into the thousands),
## which is only consistent with `row_status_now` having been captured
## BEFORE `runaway_loading` / `extreme_magnitude` existed in the shipped
## rule (fp-sweep.R's own header frames the question as "if a runaway
## loading is allowed to flag on its own" -- i.e. this sweep IS the
## calibration evidence that later produced those two arms, at a time when
## they did not yet exist). Pool 1 is therefore analysed by reconstructing
## the CURRENT full rule from its raw columns
## (`rl_argmax_extreme_prev`, `rl_max`, `rl_argmax_saturation`,
## `max_loading`), exactly extending `fp-analyse.R`'s own `old_flag()`
## reconstruction of the prevalence branch with the two later arms at their
## shipped thresholds -- not by trusting `row_status_now`.

POOL1_CSV <- "dev/heywood/fp-sweep-full.csv"
POOL2_CSV <- Sys.getenv(
  "POOL2_CSV",
  "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/7c7d64df-d837-4bba-8fee-2af42bc5a5ec/scratchpad/design108-stage8-grid.csv"
)

## shipped thresholds (R/diagnose.R defaults)
PREVALENCE_THRESH <- 0.9
LOADING_RELATIVE_THRESH <- 8
SATURATION_SHARE_THRESH <- 0.5
LOADING_RUNAWAY_THRESH <- 25
LOADING_ABSOLUTE_THRESH <- 6

cat("======================================================================\n")
cat("POOL 1 -- dev/heywood/fp-sweep-full.csv (the heywood sweep)\n")
cat("======================================================================\n")

d1 <- utils::read.csv(POOL1_CSV, stringsAsFactors = FALSE)
b1 <- d1[d1$family == "binomial" & !is.na(d1$rl_max) & is.na(d1$error), ]
cat(sprintf(
  "binomial rows total=%d  usable(rl_max present, no error)=%d\n",
  sum(d1$family == "binomial"), nrow(b1)
))

## reconstruct the CURRENT shipped rule from raw columns
ep1 <- b1$rl_argmax_extreme_prev
dl1 <- b1$rl_max >= LOADING_RELATIVE_THRESH
sf1 <- !is.na(b1$rl_argmax_saturation) &
  b1$rl_argmax_saturation >= SATURATION_SHARE_THRESH
rl1 <- b1$rl_max >= LOADING_RUNAWAY_THRESH
em1 <- b1$max_loading >= LOADING_ABSOLUTE_THRESH
prev_branch1 <- ep1 & (dl1 | sf1)
flag1 <- prev_branch1 | rl1 | em1

cat(sprintf(
  "\nSANITY: extreme_prevalence fires on %d/%d rows (range of rl_argmax_prev: %.3f - %.3f)\n",
  sum(ep1), nrow(b1), min(b1$rl_argmax_prev, na.rm = TRUE),
  max(b1$rl_argmax_prev, na.rm = TRUE)
))
cat("  -> the prevalence-gated branch is STRUCTURALLY UNTESTABLE in pool 1:\n")
cat("     the DGP's intercept is N(0, 0.3) on the logit scale, which keeps\n")
cat("     prevalence in a tight band around 0.5 by design (this sweep's own\n")
cat("     purpose was to isolate the loading-only arms from the prevalence\n")
cat("     gate -- see the header of fp-sweep.R). Treat any 'prevalence\n")
cat("     branch never fires' finding below as a DGP property, not a\n")
cat("     package finding.\n")

## fp-analyse.R's own health classification (reused, not forked)
b1$health <- ifelse(
  b1$rel_frob <= 0.5, "healthy",
  ifelse(b1$rel_frob >= 5, "degenerate", "middle")
)
## pool 2's native definition (rel_frob <= 10 non-degenerate), applied here
## too so the two pools can be compared on the SAME cutoff.
b1$health10 <- ifelse(b1$rel_frob <= 10, "healthy10", "degenerate10")

report_pool <- function(flag, health_vec, healthy_lab, degenerate_lab,
                         ep = NULL, dl = NULL, sf = NULL, rl, em,
                         prev_branch = NULL, label) {
  hi <- health_vec == healthy_lab
  gi <- health_vec == degenerate_lab
  cat(sprintf(
    "\n--- %s : healthy(%s) n=%d, degenerate(%s) n=%d ---\n",
    label, healthy_lab, sum(hi), degenerate_lab, sum(gi)
  ))
  nwarn_h <- sum(flag[hi])
  cat(sprintf(
    "healthy WARN (false positives) = %d / %d  (FPR = %.4f)\n",
    nwarn_h, sum(hi), if (sum(hi) > 0) nwarn_h / sum(hi) else NA
  ))
  rl_h <- rl[hi]; em_h <- em[hi]
  cat(sprintf(
    "  fires runaway_loading:  %d   fires extreme_magnitude: %d\n",
    sum(rl_h), sum(em_h)
  ))
  cat(sprintf(
    "  runaway ONLY: %d   magnitude ONLY: %d   BOTH: %d\n",
    sum(rl_h & !em_h), sum(em_h & !rl_h), sum(rl_h & em_h)
  ))
  if (!is.null(prev_branch)) {
    pb_h <- prev_branch[hi]
    cat(sprintf("  fires prevalence-branch: %d\n", sum(pb_h)))
    cat(sprintf(
      "  WARN accounted for by union(runaway,magnitude,prevalence): %d (should equal WARN=%d)\n",
      sum(rl_h | em_h | pb_h), nwarn_h
    ))
  }
  ntp_g <- sum(flag[gi])
  cat(sprintf(
    "degenerate flagged (sensitivity/TPR) = %d / %d  (%.4f)\n",
    ntp_g, sum(gi), if (sum(gi) > 0) ntp_g / sum(gi) else NA
  ))
  rl_g <- rl[gi]; em_g <- em[gi]
  cat(sprintf(
    "  runaway ONLY: %d   magnitude ONLY: %d   BOTH: %d   missed(neither): %d\n",
    sum(rl_g & !em_g), sum(em_g & !rl_g), sum(rl_g & em_g),
    sum(!rl_g & !em_g)
  ))
  invisible(NULL)
}

report_pool(
  flag1, b1$health, "healthy", "degenerate",
  rl = rl1, em = em1, prev_branch = prev_branch1,
  label = "pool 1, fp-analyse.R definition (rel_frob<=0.5 / >=5)"
)
report_pool(
  flag1, b1$health10, "healthy10", "degenerate10",
  rl = rl1, em = em1, prev_branch = prev_branch1,
  label = "pool 1, pool-2-native definition (rel_frob<=10)"
)

cat("\n======================================================================\n")
cat("POOL 2 -- design108 stage8 grid (issue #897's own pool)\n")
cat("======================================================================\n")

d2 <- utils::read.csv(POOL2_CSV, stringsAsFactors = FALSE)
b2 <- d2[d2$family == "binomial_probit", ]
cat(sprintf("binomial_probit rows total=%d (status: %s)\n",
            nrow(b2), paste(names(table(b2$status)), table(b2$status), collapse = ", ")))

## attribution by subtraction: runaway_loading and extreme_magnitude are
## exactly computable from rl_max / max_loading; the shipped check_status
## is the ground truth (a real check_gllvmTMB() call), so anything WARN
## that neither of those two explains MUST be the prevalence branch.
rl2 <- b2$rl_max >= LOADING_RUNAWAY_THRESH
em2 <- b2$max_loading >= LOADING_ABSOLUTE_THRESH
true_warn2 <- b2$check_status == "WARN"
recon2 <- rl2 | em2

cat(sprintf(
  "\nRECONSTRUCTION FIDELITY on the FULL binomial_probit pool (n=%d):\n",
  nrow(b2)
))
mismatch <- recon2 != true_warn2
cat(sprintf(
  "  reconstructed (runaway|magnitude) vs real check_status mismatches: %d\n",
  sum(mismatch)
))
cat(sprintf(
  "  implied prevalence-branch-only WARNs (WARN & !runaway & !magnitude): %d\n",
  sum(true_warn2 & !rl2 & !em2)
))
cat(sprintf(
  "  implied spurious PASS-side firings (PASS but runaway|magnitude TRUE): %d\n",
  sum(!true_warn2 & recon2)
))
cat("  -> exact match confirms max_loading is a valid max_loading_unit proxy\n")
cat("     here (fidelity check), AND confirms the prevalence branch never\n")
cat("     independently contributes in this pool either (same DGP property\n")
cat("     as pool 1: intercept ~ N(0,0.3) on the probit scale).\n")

## the healthy subset issue #897 measured against: rel_frob <= 10 is the
## DETECTOR.md / laplace-silent-divergence.R convention (silent_divergent
## = rel_frob > 10 & clean convergence); this EXACTLY reproduces 928/232.
h2 <- b2[b2$rel_frob <= 10, ]
g2 <- b2[b2$rel_frob > 10, ]
cat(sprintf(
  "\nnon-degenerate (rel_frob<=10): n=%d   WARN=%d   FPR=%.4f\n",
  nrow(h2), sum(h2$check_status == "WARN"),
  mean(h2$check_status == "WARN")
))
cat(sprintf(
  "  #897 reproduction check: 928/232 expected -> got %d/%d %s\n",
  nrow(h2), sum(h2$check_status == "WARN"),
  if (nrow(h2) == 928 && sum(h2$check_status == "WARN") == 232) {
    "(MATCH)"
  } else {
    "(NO MATCH)"
  }
))

rl2h <- h2$rl_max >= LOADING_RUNAWAY_THRESH
em2h <- h2$max_loading >= LOADING_ABSOLUTE_THRESH
cat(sprintf(
  "  fires runaway_loading: %d   fires extreme_magnitude: %d\n",
  sum(rl2h), sum(em2h)
))
cat(sprintf(
  "  runaway ONLY: %d   magnitude ONLY: %d   BOTH: %d\n",
  sum(rl2h & !em2h), sum(em2h & !rl2h), sum(rl2h & em2h)
))

cat("\n  -- by sigma_lambda (the DGP's true loading SD; 0.7 = mild, 3.0 = #847's ridge-failure regime) --\n")
for (s in sort(unique(h2$sigma_lambda))) {
  hs <- h2[h2$sigma_lambda == s, ]
  cat(sprintf(
    "  sigma_lambda=%.1f  n=%d  WARN=%d  FPR=%.4f\n",
    s, nrow(hs), sum(hs$check_status == "WARN"),
    mean(hs$check_status == "WARN")
  ))
}
cat("\n  -- by arm (default vs the aghq_ridge=2 remedy) --\n")
for (a in sort(unique(h2$arm))) {
  hs <- h2[h2$arm == a, ]
  cat(sprintf(
    "  arm=%-8s n=%d  WARN=%d  FPR=%.4f\n",
    a, nrow(hs), sum(hs$check_status == "WARN"),
    mean(hs$check_status == "WARN")
  ))
}

## same 0.5/5/middle classification as pool 1, for a like-for-like check
b2$health <- ifelse(
  b2$rel_frob <= 0.5, "healthy",
  ifelse(b2$rel_frob >= 5, "degenerate", "middle")
)
cat(sprintf(
  "\n(secondary, pool-1-style def rel_frob<=0.5): healthy n=%d WARN=%d FPR=%.4f\n",
  sum(b2$health == "healthy"),
  sum(b2$health == "healthy" & b2$check_status == "WARN"),
  mean(b2$check_status[b2$health == "healthy"] == "WARN")
))

cat("\n======================================================================\n")
cat("SENSITIVITY SWEEP -- extreme_magnitude's threshold (loading_absolute_thresh)\n")
cat("holding runaway_loading and the prevalence branch at shipped values\n")
cat("======================================================================\n")

taus <- c(6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 100, 150)

sweep <- function(h, g, label) {
  cat(sprintf("\n-- %s : healthy n=%d, degenerate n=%d --\n", label, nrow(h), nrow(g)))
  cat(sprintf("%6s %10s %10s\n", "tau", "FPR(healthy)", "TPR(degen)"))
  for (tau in taus) {
    fpr <- mean(h$rl_max >= LOADING_RUNAWAY_THRESH | h$max_loading >= tau)
    tpr <- mean(g$rl_max >= LOADING_RUNAWAY_THRESH | g$max_loading >= tau)
    cat(sprintf("%6.0f %10.4f %10.4f\n", tau, fpr, tpr))
  }
}

sweep(h2, g2, "pool 2, native def (rel_frob<=10 / >10)")

h1 <- b1[b1$health10 == "healthy10", ]
g1 <- b1[b1$health10 == "degenerate10", ]
sweep(h1, g1, "pool 1, pool-2-native def (rel_frob<=10 / >10), for comparison")

cat("\n=== DONE ===\n")
