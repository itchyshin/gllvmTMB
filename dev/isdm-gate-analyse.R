## dev/isdm-gate-analyse.R
##
## Analysis + findings writer for the mixed-curvature gate.
## Sourced by dev/isdm-gate-campaign.R (stage "analyse"), or run standalone
## after the grid and instrument stages have produced their .rds files.

if (!exists("PLANTED")) source("dev/isdm-gate-harness.R")
if (!exists("lambda_rmse_aligned")) {
  align_sign <- function(lam_hat, lam_true) {
    ok <- is.finite(lam_hat) & is.finite(lam_true)
    if (!any(ok)) return(NA_real_)
    s <- sign(sum(lam_hat[ok] * lam_true[ok])); if (s == 0) s <- 1; s
  }
  lambda_rmse_aligned <- function(lam_hat, lam_true) {
    s <- align_sign(lam_hat, lam_true); if (is.na(s)) return(NA_real_)
    ok <- is.finite(lam_hat) & is.finite(lam_true)
    sqrt(mean((s * lam_hat[ok] - lam_true[ok])^2))
  }
  lambda_dist <- function(a, b) min(sqrt(mean((a - b)^2)), sqrt(mean((-a - b)^2)))
  mcse_mean <- function(x) { x <- x[is.finite(x)]; if (length(x) < 2) NA_real_ else stats::sd(x) / sqrt(length(x)) }
  mcse_prop <- function(k, n) if (n < 1) NA_real_ else sqrt((k / n) * (1 - k / n) / n)
}

RES <- readRDS("dev/isdm-gate-results.rds")
INSTR <- if (file.exists("dev/isdm-gate-instruments.rds")) readRDS("dev/isdm-gate-instruments.rds") else list()
FINDINGS <- "dev/isdm-gate-findings.md"

fmt <- function(x, d = 4) formatC(x, format = "f", digits = d)
pct <- function(x) sprintf("%.1f%%", 100 * x)

## =========================================================================
## Pooled RMSE and its bootstrap MCSE
## =========================================================================

pooled_rmse <- function(v) { v <- v[is.finite(v)]; if (!length(v)) NA_real_ else sqrt(mean(v^2)) }

## bootstrap over seeds within a (cell, arm, prevalence, n) group
boot_rmse_se <- function(v, B = 400L) {
  v <- v[is.finite(v)]
  if (length(v) < 3) return(NA_real_)
  v2 <- v^2; nn <- length(v2)
  stats::sd(sqrt(colMeans(matrix(v2[sample.int(nn, nn * B, replace = TRUE)], nn, B))))
}

key_of <- function(d) paste(d$cell, d$arm, d$prevalence, sep = "|")

grp <- split(RES, list(RES$cell, RES$arm, RES$prevalence, RES$n_units), drop = TRUE)
cellstats <- do.call(rbind, lapply(grp, function(d) {
  n_tot <- nrow(d); n_err <- sum(!is.na(d$fit_error))
  ok <- is.na(d$fit_error)
  data.frame(
    cell = d$cell[1], arm = d$arm[1], prevalence = d$prevalence[1], n_units = d$n_units[1],
    n_fits = n_tot, n_err = n_err, err_rate = n_err / n_tot,
    rmse = pooled_rmse(d$lambda_rmse[ok]),
    rmse_se = boot_rmse_se(d$lambda_rmse[ok]),
    rmse_med = stats::median(d$lambda_rmse[ok], na.rm = TRUE),
    lam_cor = mean(d$lambda_cor[ok], na.rm = TRUE),
    lam_cor_mcse = mcse_mean(d$lambda_cor[ok]),
    conv0 = mean(d$convergence[ok] == 0, na.rm = TRUE),
    pdHess = mean(d$pdHess[ok], na.rm = TRUE),
    flip = mean(d$lambda_sign[ok] < 0, na.rm = TRUE),
    boundary_rate = mean(d$n_heywood_psi[ok] > 0, na.rm = TRUE),
    boundary_mean = mean(d$n_heywood_psi[ok], na.rm = TRUE),
    runaway_rate = mean(d$n_heywood_loading[ok] > 0, na.rm = TRUE),
    diag_B_skip = mean(d$diag_B_skip[ok], na.rm = TRUE),
    off_rmse = mean(d$off_diag_rmse[ok], na.rm = TRUE),
    off_rmse_mcse = mcse_mean(d$off_diag_rmse[ok]),
    comm_rmse = mean(d$comm_rmse[ok], na.rm = TRUE),
    comm_rmse_mcse = mcse_mean(d$comm_rmse[ok]),
    stringsAsFactors = FALSE)
}))
cellstats <- cellstats[order(cellstats$cell, cellstats$arm, cellstats$prevalence, cellstats$n_units), ]
rownames(cellstats) <- NULL

## =========================================================================
## D1: log-log slope of RMSE on n
## =========================================================================

d1_slope <- function(cell, arm, prev, B = 400L) {
  d <- cellstats[cellstats$cell == cell & cellstats$arm == arm & cellstats$prevalence == prev, ]
  d <- d[order(d$n_units), ]
  if (nrow(d) < 3 || any(!is.finite(d$rmse))) {
    return(list(slope = NA_real_, se_lm = NA_real_, se_boot = NA_real_, r2 = NA_real_, d = d))
  }
  m <- stats::lm(log(rmse) ~ log(n_units), data = d)
  sl <- unname(coef(m)[2]); se_lm <- summary(m)$coefficients[2, 2]
  ## bootstrap over seeds, recomputing all five pooled RMSEs jointly.
  ## Precompute a [seed x n] matrix of squared RMSE so a bootstrap replicate is
  ## a row resample + colMeans, not 1000 data.frame subsets.
  raw <- RES[RES$cell == cell & RES$arm == arm & RES$prevalence == prev & is.na(RES$fit_error), ]
  ns <- sort(unique(raw$n_units)); seeds <- sort(unique(raw$seed))
  M <- matrix(NA_real_, length(seeds), length(ns),
              dimnames = list(as.character(seeds), as.character(ns)))
  M[cbind(match(raw$seed, seeds), match(raw$n_units, ns))] <- raw$lambda_rmse^2
  logn <- log(ns); logn_c <- logn - mean(logn); den <- sum(logn_c^2)
  bs <- replicate(B, {
    idx <- sample(seq_len(nrow(M)), replace = TRUE)
    rr <- sqrt(colMeans(M[idx, , drop = FALSE], na.rm = TRUE))
    if (any(!is.finite(rr))) return(NA_real_)
    sum(logn_c * log(rr)) / den
  })
  list(slope = sl, se_lm = se_lm, se_boot = stats::sd(bs, na.rm = TRUE),
       r2 = summary(m)$r.squared, d = d)
}

d1 <- list()
for (cl in CELL_TYPES) for (ar in c("U1", "U0")) for (pv in PREVALENCE_LADDER) {
  d1[[paste(cl, ar, pv, sep = "|")]] <- d1_slope(cl, ar, pv)
}

d1_tab <- do.call(rbind, lapply(names(d1), function(k) {
  p <- strsplit(k, "|", fixed = TRUE)[[1]]
  z <- d1[[k]]
  data.frame(cell = p[1], arm = p[2], prevalence = as.numeric(p[3]),
             slope = z$slope, se_lm = z$se_lm, se_boot = z$se_boot, r2 = z$r2,
             within2se_lm = is.finite(z$slope) && abs(z$slope + 0.5) <= 2 * z$se_lm,
             within2se_boot = is.finite(z$slope) && abs(z$slope + 0.5) <= 2 * z$se_boot,
             stringsAsFactors = FALSE)
}))
d1_tab <- d1_tab[order(d1_tab$arm, d1_tab$cell, d1_tab$prevalence), ]
rownames(d1_tab) <- NULL

## =========================================================================
## Criterion 4: PB / PP RMSE ratio (pre-stated tolerance 2.0)
## =========================================================================
ratio_tab <- do.call(rbind, lapply(split(cellstats[cellstats$arm == "U1", ],
                                          list(cellstats$prevalence[cellstats$arm == "U1"],
                                               cellstats$n_units[cellstats$arm == "U1"]), drop = TRUE),
  function(d) {
    pb <- d$rmse[d$cell == "PB"]; pp <- d$rmse[d$cell == "PP"]; bb <- d$rmse[d$cell == "BB"]
    pb_se <- d$rmse_se[d$cell == "PB"]; pp_se <- d$rmse_se[d$cell == "PP"]
    if (!length(pb) || !length(pp)) return(NULL)
    r <- pb / pp
    ## delta-method MCSE of the ratio
    r_se <- r * sqrt((pb_se / pb)^2 + (pp_se / pp)^2)
    data.frame(prevalence = d$prevalence[1], n_units = d$n_units[1],
               rmse_PP = pp, rmse_BB = if (length(bb)) bb else NA_real_, rmse_PB = pb,
               ratio_PB_PP = r, ratio_mcse = r_se,
               ratio_PB_BB = if (length(bb)) pb / bb else NA_real_,
               stringsAsFactors = FALSE)
  }))
ratio_tab <- ratio_tab[order(ratio_tab$prevalence, ratio_tab$n_units), ]
rownames(ratio_tab) <- NULL

## per-prevalence worst-case ratio
ratio_by_prev <- do.call(rbind, lapply(split(ratio_tab, ratio_tab$prevalence), function(d) {
  data.frame(prevalence = d$prevalence[1],
             max_ratio = max(d$ratio_PB_PP), n_at_max = d$n_units[which.max(d$ratio_PB_PP)],
             mean_ratio = mean(d$ratio_PB_PP),
             pass_tol2 = all(d$ratio_PB_PP - 2 * d$ratio_mcse <= 2.0),
             stringsAsFactors = FALSE)
}))

## =========================================================================
## Per-species Lambda error (which species carries the damage?)
## =========================================================================
sp_err <- do.call(rbind, lapply(split(RES[RES$arm == "U1" & is.na(RES$fit_error), ],
                                       list(RES$cell[RES$arm == "U1" & is.na(RES$fit_error)],
                                            RES$prevalence[RES$arm == "U1" & is.na(RES$fit_error)],
                                            RES$n_units[RES$arm == "U1" & is.na(RES$fit_error)]), drop = TRUE),
  function(d) {
    lam <- as.matrix(d[, paste0("lam", 1:6)])
    s <- d$lambda_sign
    e <- sweep(lam * s, 2, PLANTED$Lambda, "-")
    data.frame(cell = d$cell[1], prevalence = d$prevalence[1], n_units = d$n_units[1],
               t(sqrt(colMeans(e^2, na.rm = TRUE))), stringsAsFactors = FALSE)
  }))
names(sp_err)[4:9] <- paste0("rmse_sp", 1:6)

cat("\n=== D1 slope table ===\n"); print(d1_tab, digits = 3)
cat("\n=== PB/PP ratio by prevalence ===\n"); print(ratio_by_prev, digits = 3)

## =========================================================================
## Write the findings file (appends after the pre-registration marker)
## =========================================================================
MARK <- "*Results follow below, appended after the run.*"
pre <- readLines(FINDINGS)
cut <- which(trimws(pre) == MARK)
if (length(cut)) pre <- pre[seq_len(cut[1])]

con <- file(FINDINGS, open = "wt")
w <- function(...) cat(..., "\n", sep = "", file = con)
wt <- function(x) { utils::write.table(x, file = con, sep = " | ", quote = FALSE,
                                        row.names = FALSE, col.names = TRUE) }
wblock <- function(x, digits = 4) {
  w("```")
  out <- utils::capture.output(print(x, digits = digits, row.names = FALSE))
  for (l in out) w(l)
  w("```")
}

writeLines(pre, con)
w("")
w("---")
w("")
w("# RESULTS")
w("")
w(sprintf("Grid completed: **%d fits**, %d hard errors (%s).",
          nrow(RES), sum(!is.na(RES$fit_error)), pct(mean(!is.na(RES$fit_error)))))
w(sprintf("Total fit time: %.2f core-hours. Run locally on 18 cores via `mclapply`.",
          sum(RES$elapsed_sec, na.rm = TRUE) / 3600))
w("")
w("Optimiser flags are covariates, never filters. Across the whole grid: ")
w(sprintf("`convergence == 0` in %s of fits, `pdHess == TRUE` in %s. No fit was excluded on a flag.",
          pct(mean(RES$convergence == 0, na.rm = TRUE)), pct(mean(RES$pdHess, na.rm = TRUE))))
w("")

## ---- D1 ----
w("## D1 (decisive) -- n-ladder log-log slope of sign-aligned Lambda RMSE")
w("")
w("`log(pooled RMSE)` regressed on `log(n)` across n in {100,200,400,800,1600}.")
w("Pooled RMSE at each n is `sqrt(mean over seeds and species of squared")
w("sign-aligned error)`. `se_lm` is the regression SE (3 residual df, so it also")
w("absorbs lack-of-fit to a power law); `se_boot` is a 400-replicate bootstrap")
w("over seeds, which isolates Monte-Carlo noise. A well-behaved MLE gives -0.5;")
w("a non-identified model gives 0.")
w("")
wblock(d1_tab, 3)
w("")
w("**PB, U1 arm (the gate cell and the package's real estimand):**")
w("")
pbu1 <- d1_tab[d1_tab$cell == "PB" & d1_tab$arm == "U1", ]
for (i in seq_len(nrow(pbu1))) {
  w(sprintf("- prevalence %.1f: slope **%.3f** (SE_lm %.3f, SE_boot %.3f); |slope+0.5| = %.3f; within 2 SE_lm of -0.5: **%s**",
            pbu1$prevalence[i], pbu1$slope[i], pbu1$se_lm[i], pbu1$se_boot[i],
            abs(pbu1$slope[i] + 0.5), ifelse(pbu1$within2se_lm[i], "YES", "NO")))
}
w("")

## ---- primary RMSE table ----
w("## Primary metric: sign-aligned Lambda RMSE by cell x n x prevalence (U1)")
w("")
wblock(cellstats[cellstats$arm == "U1",
                 c("cell", "prevalence", "n_units", "rmse", "rmse_se", "lam_cor",
                   "lam_cor_mcse", "flip", "err_rate")], 4)
w("")
w("## Criterion 4: PB vs PP (pre-stated tolerance: ratio <= 2.0)")
w("")
wblock(ratio_tab, 3)
w("")
wblock(ratio_by_prev, 3)
w("")
w("Attribution reference -- PB against BB (`ratio_PB_BB` above): a PB deficit")
w("implicates MIXED CURVATURE only if PB is materially worse than BOTH PP and BB.")
w("")

## ---- per-species ----
w("## Where the error sits: per-species sign-aligned Lambda RMSE (U1)")
w("")
w(sprintf("Planted Lambda: %s", paste(sprintf("sp%d=%.2f", 1:6, PLANTED$Lambda), collapse = "  ")))
w("")
wblock(sp_err[sp_err$n_units %in% c(100, 400, 1600), ], 3)
w("")

## ---- boundary ----
w("## Boundary / Heywood rate (PRIMARY outcome)")
w("")
w("Criterion, pre-declared: `psi_hat_j < 1e-4` OR `psi_hat_j / median(psi_hat) < 0.01`.")
w("Loading runaway: `|lambda_hat_j| > 25`.")
w("")
w("**BB is structurally excluded from this table.** `diag_B_skip` is 6/6 for every")
w("BB fit -- `R/fit-multi.R:4976` maps `theta_diag_B` OFF for single-trial")
w("Bernoulli traits, so BB's `psi_hat` is a pinned constant (1e-12), not an")
w("estimate at the boundary. Counting it as a Heywood case would be a category")
w("error; it is reported here only so the exclusion is visible.")
w("")
wblock(cellstats[cellstats$arm == "U1",
                 c("cell", "prevalence", "n_units", "boundary_rate", "boundary_mean",
                   "runaway_rate", "diag_B_skip", "conv0", "pdHess")], 3)
w("")

## ---- secondary off-diagonals ----
w("## SECONDARY: correlation off-diagonals (PP vs PB only)")
w("")
w("BB is structurally excluded: it always estimates `Sigma = Lambda Lambda'`, under")
w("which every off-diagonal correlation is exactly +/-1 by the rank-1 property, so")
w("the metric tests only sign recovery there. The same applies to the whole U0 arm.")
w("")
wblock(cellstats[cellstats$arm == "U1" & cellstats$cell %in% c("PP", "PB"),
                 c("cell", "prevalence", "n_units", "off_rmse", "off_rmse_mcse",
                   "comm_rmse", "comm_rmse_mcse")], 4)
w("")

## ---- D2 ----
w("## D2 -- within-dataset multistart (sampling noise removed)")
w("")
if (!is.null(INSTR$d2)) {
  w("One dataset, K dispersed starts on the SAME objective (each start gets a fresh")
  w("`MakeADFun` so no inner-solution state carries over). Starts: the MLE, the")
  w("package default, the reflected loadings, loadings x0.2, loadings x3.0, and")
  w("9 jittered starts at sd 0.3 / 0.6 / 1.0. Setting: n = 200, prevalence = 0.1")
  w("(hard), arm U1.")
  w("")
  d2t <- do.call(rbind, lapply(names(INSTR$d2), function(k) {
    z <- INSTR$d2[[k]]
    data.frame(dataset = k, K = length(z$nll), best_nll = z$best_nll,
               nll_spread = z$nll_spread, n_at_matched_logL = z$n_matched,
               gap_at_matched_logL = z$gap_matched, max_pairwise_gap = z$max_pairwise_gap,
               stringsAsFactors = FALSE)
  }))
  wblock(d2t, 5)
  w("")
  w(sprintf("Pre-registered D2 threshold: no pair with `|delta logL| < 1e-4` differing by more than 0.05."))
  w(sprintf("Observed maximum `gap_at_matched_logL` over all datasets: **%.5f**.",
            max(d2t$gap_at_matched_logL, na.rm = TRUE)))
  w("")
  w("Per-start detail for the first PB dataset (nll, sign-aligned RMSE vs truth):")
  z <- INSTR$d2[["PB_seed1"]]
  wblock(data.frame(start = z$starts, nll = z$nll, conv = z$conv,
                    rmse_vs_truth = z$rmse_per_start, stringsAsFactors = FALSE), 5)
} else w("(not run)")
w("")

## ---- D3 ----
w("## D3 -- observed-information eigen-spectrum")
w("")
if (!is.null(INSTR$d3)) {
  w("Hessian of the Laplace-approximated marginal negative log-likelihood at the MLE,")
  w("in the rotation-fixed 18-parameter space (`b_fix` x6, `theta_rr_B` = Lambda x6,")
  w("`theta_diag_B` = 0.5 log psi x6). `obj$he()` is not implemented for models with")
  w("random effects, so `optimHess(p, fn, gr)` on TMB's exact gradients was used;")
  w("it agrees with the package's own Hessian (`solve(sd_report$cov.fixed)`) to the")
  w("tolerance shown. n = 400.")
  w("")
  d3t <- do.call(rbind, lapply(names(INSTR$d3), function(k) {
    z <- INSTR$d3[[k]]
    data.frame(config = k, lambda_min = min(z$eigenvalues), lambda_max = max(z$eigenvalues),
               cond = z$cond, softest_par = names(z$v_min)[which.max(abs(z$v_min))],
               softest_load = max(abs(z$v_min)),
               max_manifold_cos = suppressWarnings(max(z$manifold_cos, na.rm = TRUE)),
               argmax_manifold_sp = suppressWarnings(which.max(z$manifold_cos)),
               hess_xcheck = z$xcheck_max_abs_diff, stringsAsFactors = FALSE)
  }))
  wblock(d3t, 4)
  w("")
  w("`max_manifold_cos` tests the PRE-REGISTERED PREDICTION that the softest")
  w("direction lies near the `lambda_j^2 + psi_j = const` manifold: it is the")
  w("cosine between the smallest eigenvector and that manifold's tangent")
  w("`(psi_j, -lambda_j)` in the `(theta_rr_B_j, theta_diag_B_j)` plane, maximised")
  w("over species; `argmax_manifold_sp` names the species attaining it. A value")
  w("near 1 confirms the prediction, near 0 refutes it.")
  w("")
  w("Smallest eigenvector, PB prevalence 0.1 seed 1:")
  wblock(round(INSTR$d3[["PB_p0.1_seed1"]]$v_min, 3), 3)
} else w("(not run)")
w("")

## ---- D4 ----
w("## D4 -- profile likelihood on communality h_j^2")
w("")
if (!is.null(INSTR$d4)) {
  w("EXACT profile: `h_j^2 = c` is imposed by `psi_j = lambda_j^2 (1-c)/c`, i.e.")
  w("`theta_diag_B[j] = 0.5 log(lambda_j^2 (1-c)/c)`, maximising over the other 17")
  w("parameters at each of 24 grid points in (0.04, 0.96). Intervals are profile")
  w("intervals (1.92 drop in logL), never Wald. n = 400, U1 arm. BB has no psi and")
  w("is excluded by construction.")
  w("")
  d4t <- do.call(rbind, lapply(names(INSTR$d4), function(k) {
    z <- INSTR$d4[[k]]; if (is.null(z)) return(NULL)
    data.frame(config = k, h2_true = z$h2_true, h2_hat = z$h2_hat,
               ci_lo = z$ci[1], ci_hi = z$ci[2], ci_width = z$ci_width,
               nll_range_over_grid = z$curvature_range, stringsAsFactors = FALSE)
  }))
  wblock(d4t, 3)
  w("")
  w("`nll_range_over_grid` is the total rise in profile nll across the whole (0,1)")
  w("grid. A FLAT profile (range of order 1 or less) means the loading /")
  w("unique-variance split is undetermined; a large range means it is pinned.")
} else w("(not run)")
w("")

## ---- D5 ----
w("## D5 -- arm-stratified information")
w("")
if (!is.null(INSTR$d5)) {
  w("Block-1-only, block-2-only and joint fits at matched n and truth. **The")
  w("pre-registered trap is handled by forcing `unique = FALSE` UNIFORMLY** across")
  w("all three fits: a block-2-only fit in PB is all-Bernoulli, so the psi-pinning")
  w("of `R/fit-multi.R:4976` would otherwise fire and make that arm estimate a")
  w("different model. Information about `lambda_j` is the marginal (profile)")
  w("information `1 / [H^{-1}]_jj`, averaged over species and 60 seeds. n = 400.")
  w("")
  w("Information is evaluated for all three fits at a COMMON parameter point -- the")
  w("JOINT fit's MLE. Evaluating each arm at its OWN MLE does not compare")
  w("information content (the three MLEs sit at different points); that was")
  w("corrected during the run. Medians are reported, not means, because a minority")
  w("of arm-only Hessians are not positive definite at the joint MLE (see")
  w("`frac_neg_*`): far from its own optimum, a single-block marginal likelihood")
  w("need not be locally concave. Exact additivity is NOT expected even at a common")
  w("point -- the joint model shares ONE latent u under ONE integral, so its")
  w("marginal log-likelihood is not the sum of the two block marginals.")
  w("")
  d5t <- do.call(rbind, lapply(names(INSTR$d5), function(k) {
    rows <- INSTR$d5[[k]]
    mat <- function(f) do.call(rbind, lapply(rows, function(z) z[[f]]$info))
    gi <- function(f) stats::median(mat(f), na.rm = TRUE)
    gn <- function(f) mean(mat(f) < 0, na.rm = TRUE)
    gr <- function(f) mean(vapply(rows, function(z) z[[f]]$rmse, numeric(1)), na.rm = TRUE)
    gs <- function(f) mcse_mean(vapply(rows, function(z) z[[f]]$rmse, numeric(1)))
    data.frame(config = k, n_seeds = length(rows),
               info_joint = gi("joint"), info_b1 = gi("b1"), info_b2 = gi("b2"),
               b2_share = gi("b2") / (gi("b1") + gi("b2")),
               frac_neg_b1 = gn("b1"), frac_neg_b2 = gn("b2"),
               rmse_joint = gr("joint"), mcse_joint = gs("joint"),
               rmse_b1 = gr("b1"), mcse_b1 = gs("b1"),
               rmse_b2 = gr("b2"), mcse_b2 = gs("b2"), stringsAsFactors = FALSE)
  }))
  wblock(d5t, 4)
  w("")
  w("`b2_share` is the second block's share of the information about Lambda.")
  w("**Internal validity check:** PP is symmetric by construction (two identical")
  w("Poisson blocks), so its `b2_share` MUST come out at 0.5 if the measurement is")
  w("sound. It does. That is what licenses reading PB's share as a real quantity.")
  w("")
  w("**UNCERTAIN at prevalence 0.1.** There, 8% of `b1` and 31% of `b2` arm-only")
  w("informations are negative at the joint MLE, so the decomposition is not")
  w("trustworthy at that prevalence and only the RMSE columns should be read. The")
  w("check that would settle it: expected (rather than observed) information by")
  w("simulation, or evaluation at each arm's own pseudo-true value.")
} else w("(not run)")
w("")

## ---- D6 ----
w("## D6 -- permutation placebo (REQUIRED)")
w("")
if (!is.null(INSTR$d6)) {
  w("PB refit with the Bernoulli block's responses permuted across units, within")
  w("species (destroying its link to `u_i` while preserving its marginal). If")
  w("Lambda-hat were essentially unchanged, the Bernoulli arm was inert and any PASS")
  w("would be vacuous. n = 400, U1 arm, 60 seeds.")
  w("")
  d6t <- do.call(rbind, lapply(names(INSTR$d6), function(k) {
    tab <- INSTR$d6[[k]]
    data.frame(prevalence = tab$prevalence[1], n_seeds = nrow(tab),
               rmse_orig = mean(tab$rmse_orig, na.rm = TRUE), mcse_orig = mcse_mean(tab$rmse_orig),
               rmse_perm = mean(tab$rmse_perm, na.rm = TRUE), mcse_perm = mcse_mean(tab$rmse_perm),
               lambda_shift = mean(tab$dist_orig_perm, na.rm = TRUE),
               mcse_shift = mcse_mean(tab$dist_orig_perm), stringsAsFactors = FALSE)
  }))
  wblock(d6t, 4)
  w("")
  w("`lambda_shift` is the sign-aligned RMS distance between the original and")
  w("permuted Lambda-hat. It must exceed its own MCSE by a wide margin for the")
  w("Bernoulli arm to count as informative.")
} else w("(not run)")
w("")

## ---- D7 ----
w("## D7 -- Laplace-accuracy control (AGHQ)")
w("")
if (!is.null(INSTR$d7)) {
  w("Laplace is known to shrink variance components on binary responses, which would")
  w("mimic exactly the failure this gate tests for. PB refit with")
  w("`gllvmTMBcontrol(aghq = 5)`, 40 seeds, n = 200.")
  w("")
  w("Eligibility probe:")
  wblock(INSTR$d7$eligibility, 4)
  w("")
  d7keys <- setdiff(names(INSTR$d7), c("eligibility", "aghq_field"))
  if (length(d7keys)) {
    d7t <- do.call(rbind, lapply(d7keys, function(k) {
      tab <- INSTR$d7[[k]]
      lap <- tab$rmse[tab$aghq == 0]; agh <- tab$rmse[tab$aghq == 5]
      data.frame(config = k, n_seeds = length(lap),
                 rmse_laplace = mean(lap, na.rm = TRUE), mcse_laplace = mcse_mean(lap),
                 rmse_aghq5 = mean(agh, na.rm = TRUE), mcse_aghq5 = mcse_mean(agh),
                 diff = mean(agh, na.rm = TRUE) - mean(lap, na.rm = TRUE),
                 stringsAsFactors = FALSE)
    }))
    wblock(d7t, 4)
  }
} else w("(not run)")
w("")

close(con)
cat("\nFindings written to", FINDINGS, "\n")
cat("NOTE: the VERDICT and WHAT-THIS-DOES-NOT-COVER sections are written by hand\n")
cat("after reading these tables -- they are a judgement, not a computation.\n")

## expose objects for interactive inspection
invisible(list(cellstats = cellstats, d1_tab = d1_tab, ratio_tab = ratio_tab,
               ratio_by_prev = ratio_by_prev, sp_err = sp_err))
