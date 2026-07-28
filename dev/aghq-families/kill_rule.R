## dev/aghq-families/kill_rule.R -- the PRE-REGISTERED pass/dead rule.
##
## Verbatim from the brief (do not re-derive or soften):
##
##   "a family/regime cell PASSES iff the AGHQ-vs-Laplace paired estimate of
##    |attenuation(Sigma_hat, Sigma_true) - 1|, averaged over at least 8
##    seeds, has its 95% CI entirely below 0.03 -- under- and over-shoot
##    scored IDENTICALLY by absolute value, never 'higher attenuation is
##    better' -- and any cell whose point estimate exceeds 0.05 is DEAD and
##    is reported as a NAMED EXCLUSION, never silently dropped from the
##    average."
##
## READING, made explicit because "AGHQ-vs-Laplace paired estimate of
## |attenuation - 1|" is not itself a single number without a comparison
## operator:
##
##   For seed i, engine e in {laplace, aghq}: e_i^{(e)} = |attenuation_ratio
##   (Sigma_hat_i^{(e)}, Sigma_true_i) - 1|  (attenuation_ratio is the
##   trace-ratio scale summary defined in run_family.R; taking the absolute
##   deviation from 1 is what makes under- and over-shoot score identically
##   -- an implementation that instead compared signed attenuation_ratio, or
##   compared raw attenuation_aghq to raw attenuation_laplace without the
##   "-1", would silently reward AGHQ overshooting past 1 as if it were an
##   improvement, which the brief explicitly rules out).
##
##   The PAIRED difference is d_i = e_i^{(aghq)} - e_i^{(laplace)}: how much
##   WORSE (positive) or better (negative) AGHQ's attenuation error is than
##   Laplace's, on the SAME simulated dataset (paired by seed, so sampling
##   noise in the DGP itself cancels). mean(d) over seeds is a
##   non-inferiority style estimate: PASS means AGHQ is not meaningfully
##   worse than Laplace (mean difference confidently below 0.03), not that
##   AGHQ must beat Laplace.
##
##   DEAD is a SEPARATE, harsher threshold on the point estimate alone
##   (mean(d) > 0.05, regardless of CI width) -- a cell that clearly makes
##   things worse on average is named and excluded rather than folded into
##   a summary that would look fine only because of a wide CI.
##
## Verification discipline: this exact function was exercised against
## synthetic paired-attenuation vectors at DEAD / PASS / AMBIGUOUS /
## INSUFFICIENT_SEEDS inputs, and separately broken (removing the abs() so
## sign was scored instead of magnitude) to confirm the check goes wrong in
## the expected direction before being restored. See the calling agent's
## final report for the pasted output; this file only carries the
## implementation.

## kill_rule(): given PAIRED per-seed attenuation_ratio vectors (same length,
## same seed order) for the Laplace and AGHQ engines of ONE family/regime
## cell, return the verdict.
##
##   n < 8            -> "INSUFFICIENT_SEEDS" (the rule requires >= 8 seeds;
##                        it does not silently evaluate on fewer)
##   mean(d) > 0.05    -> "DEAD" (named exclusion; point estimate alone)
##   CI upper < 0.03   -> "PASS"
##   otherwise         -> "AMBIGUOUS" (neither confidently passing nor
##                        named-dead; must not be reported as either)
kill_rule <- function(attenuation_laplace, attenuation_aghq,
                      conf_level = 0.95, min_seeds = 8L) {
  stopifnot(length(attenuation_laplace) == length(attenuation_aghq))
  ## Drop seed-pairs where either engine failed to produce a finite
  ## attenuation_ratio (NA from a fit error) -- a failed fit is not evidence
  ## either way, and must not silently become a zero in the mean.
  keep <- is.finite(attenuation_laplace) & is.finite(attenuation_aghq)
  n_used <- sum(keep)
  n_total <- length(attenuation_laplace)

  if (n_used < min_seeds) {
    return(list(n_total = n_total, n_used = n_used, mean_diff = NA_real_,
                ci_low = NA_real_, ci_high = NA_real_,
                verdict = "INSUFFICIENT_SEEDS"))
  }

  e_laplace <- abs(attenuation_laplace[keep] - 1)
  e_aghq    <- abs(attenuation_aghq[keep] - 1)
  d <- e_aghq - e_laplace   # positive = AGHQ worse than Laplace at this seed

  m  <- mean(d)
  s  <- stats::sd(d)
  se <- s / sqrt(n_used)
  if (se == 0) {
    ci <- c(m, m)
  } else {
    tcrit <- stats::qt(1 - (1 - conf_level) / 2, df = n_used - 1)
    ci <- c(m - tcrit * se, m + tcrit * se)
  }

  verdict <- if (m > 0.05) {
    "DEAD"
  } else if (ci[2] < 0.03) {
    "PASS"
  } else {
    "AMBIGUOUS"
  }

  list(n_total = n_total, n_used = n_used, mean_diff = m,
       ci_low = ci[1], ci_high = ci[2], verdict = verdict)
}

## Apply kill_rule() to one run_family()-shaped data.frame, grouped by
## family (and, if present, any other regime column named `regime`). Returns
## one row per family/regime with the verdict -- DEAD cells are named here,
## never dropped silently.
kill_rule_report <- function(results, group_cols = "family") {
  stopifnot(is.data.frame(results), all(group_cols %in% names(results)))
  keys <- do.call(paste, c(results[group_cols], sep = "\r"))
  out <- lapply(split(seq_len(nrow(results)), keys), function(idx) {
    sub <- results[idx, , drop = FALSE]
    kr <- kill_rule(sub$attenuation_laplace, sub$attenuation_aghq)
    cbind(sub[1, group_cols, drop = FALSE],
          data.frame(n_total = kr$n_total, n_used = kr$n_used,
                     mean_diff = kr$mean_diff, ci_low = kr$ci_low,
                     ci_high = kr$ci_high, verdict = kr$verdict,
                     stringsAsFactors = FALSE))
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}
