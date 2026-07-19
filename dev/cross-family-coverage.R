## =====================================================================
## dev/cross-family-coverage.R  --  Slice 5 of the "calibrated cross-family
## intervals" arc (multinomial Lane A).
##
## A self-contained, multi-seed coverage-CERTIFICATION harness that measures
## the coverage of the intervals attached to extract_cross_correlations()
## (Slices 1-4) against an ANALYTICALLY-KNOWN truth.
##
## Two estimands, measured across every WIRED (estimand, method) cell of
## extract_cross_correlations() (5 cells total; multiple_r x profile is
## deliberately NOT wired -- the block functional has no profile parameter):
##   * multiple_r  -- aggregate cross-family multiple correlation (Sigma-block
##     functional). Methods: "bootstrap", "wald".
##   * contrast_r  -- pairwise partner-vs-contrast correlation. Methods:
##     "profile" (Option-b AUTO scale), "wald", "bootstrap".
## Per replicate, the fit is refit ONCE and reused across all three
## extract_cross_correlations() calls (wald / bootstrap / profile) -- the
## refit is the cost, not the interval computation.
##
## HONESTY BANNER (D-43): EVERY number produced by this harness is
##   "MEASURED, NOT certified -- awaiting D-43 panel".
## Nothing here promotes any validation-register row (CI-11 stays pending).
## Results are written to LOCAL .rds only (D-50: never GitHub artifacts).
##
## This file is design-of-record: ~/.claude/plans/do-we-need-to-functional-zebra.md
##   ("Coverage-study design" + the binding "v3 -- Full-panel resolution").
##
## Run modes (env-var + CLI guarded main; see the bottom of the file and
## .xfc_launch_note()):
##   XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=pilot \
##       --shard=$SLURM_ARRAY_TASK_ID --n-shards=100 --n-sim=200 --seed-base=20260718
##
## Smoke (fast, in-process; assumes gllvmTMB already load_all'd):
##   source("dev/cross-family-coverage.R"); print(xfc_smoke())
## =====================================================================

XFC_BANNER <- "MEASURED, NOT certified -- awaiting D-43 panel"

## ---------------------------------------------------------------------
## 0. Package + small utilities
## ---------------------------------------------------------------------

.xfc_ensure_pkg <- function() {
  if ("gllvmTMB" %in% loadedNamespaces()) return(invisible(TRUE))
  ok <- suppressWarnings(suppressMessages(
    requireNamespace("gllvmTMB", quietly = TRUE)))
  if (ok) {
    suppressWarnings(suppressMessages(library(gllvmTMB)))
  } else if (requireNamespace("devtools", quietly = TRUE)) {
    suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))
  } else {
    stop("gllvmTMB is not available (install it, or run under devtools::load_all).")
  }
  invisible(TRUE)
}

## The Path-2 unconditional-redraw gate, robust to load_all vs installed.
.xfc_can_redraw <- function(fit) {
  f <- tryCatch(
    getFromNamespace(".check_simulate_unconditional", "gllvmTMB"),
    error = function(e) NULL
  )
  if (is.null(f)) return(list(can_redraw = NA, unhandled = "gate-unavailable"))
  f(fit)
}

## Numerically-stable multinomial-block link residual (pi^2/6)(I + J):
##   pi^2/3 on the diagonal, pi^2/6 off-diagonal, within the (K-1) block.
.PI2_3 <- pi^2 / 3   # ~3.2899  binomial-logit + per-contrast diagonal
.PI2_6 <- pi^2 / 6   # ~1.6449  multinomial off-diagonal coupling

## ---------------------------------------------------------------------
## 1. Analytic truth: Sigma_total_true = Lambda Lambda^T + diag(psi) + R_link
##    with the mapped-off multinomial-contrast psi PINNED to 0.
## ---------------------------------------------------------------------

## Deterministic link residual R_link in CANONICAL order (partner, cat:2, cat:3).
##   * partner diagonal: gaussian -> 0 ; binomial-logit -> pi^2/3.
##   * multinomial block: (pi^2/6)(I + J)  == diag pi^2/3, off-diag pi^2/6.
##   * gaussian partner keeps a SEPARATE obs-dispersion (sigma_eps) that is NOT
##     part of Sigma (its link residual is 0), so it never enters R_link.
.xfc_R_link <- function(partner_family) {
  link_p <- switch(partner_family, gaussian = 0, binomial = .PI2_3,
                   stop("partner_family must be 'gaussian' or 'binomial'."))
  R <- matrix(0, 3L, 3L)
  diag(R) <- c(link_p, .PI2_3, .PI2_3)   # partner, cat:2, cat:3
  R[2L, 3L] <- R[3L, 2L] <- .PI2_6       # softmax off-diagonal within the block
  R
}

## The estimator's OWN doubly-clamped aggregate functional applied to a Sigma.
## p = partner index (1), blk = contrast indices (2:3).
.xfc_multiple_r <- function(Sigma, p = 1L, blk = 2:3) {
  Scc <- Sigma[blk, blk, drop = FALSE]
  Scc_inv <- tryCatch(solve(Scc), error = function(e) MASS::ginv(Scc))
  Spc <- Sigma[p, blk, drop = FALSE]
  mr <- sqrt(max(0, as.numeric(Spc %*% Scc_inv %*% t(Spc)) / Sigma[p, p]))
  min(mr, 1)
}

## The estimator's pairwise contrast_r vector (auto scale). Named by contrast.
.xfc_contrast_r <- function(Sigma, p = 1L, blk = 2:3, blk_names = NULL) {
  cr <- Sigma[p, blk] / sqrt(Sigma[p, p] * diag(Sigma[blk, blk, drop = FALSE]))
  if (!is.null(blk_names)) names(cr) <- blk_names
  cr
}

## Base loadings (3 x 2), canonical order (partner, cat:2, cat:3). The partner
## direction (1, 0.5) lies in the span of the two contrast rows, so a large
## coupling scale drives multiple_r -> 1 (used by the near-collinear diagnostic).
.XFC_LAMBDA0 <- rbind(
  partner = c(1.0, 0.5),
  `cat:2` = c(1.0, 0.0),
  `cat:3` = c(0.3, 0.9)
)

## Build the analytic truth for one cell. Tune the single coupling scalar s
## (Lambda = s * Lambda0) by uniroot so the estimator's functional evaluated at
## Sigma_total_true hits target_mr exactly. psi is FIXED (never scaled) and its
## contrast entries are PINNED to 0 (the .expand_mapped_diag auto-suppression
## convention); the binomial partner's psi is also 0 (single-trial binary Psi is
## auto-suppressed too), gaussian partner keeps psi_partner (identified via reps).
.xfc_build_truth <- function(target_mr, partner_family,
                             partner_trait = if (partner_family == "gaussian") "g" else "b",
                             partner_famlab = if (partner_family == "gaussian") "g" else "b",
                             psi_partner = if (partner_family == "gaussian") 0.5 else 0,
                             Lambda0 = .XFC_LAMBDA0,
                             s_bracket = c(1e-3, 60)) {
  stopifnot(target_mr > 0, target_mr < 1)
  psi <- c(psi_partner, 0, 0)                     # partner, cat:2, cat:3 (pinned)
  R_link <- .xfc_R_link(partner_family)
  sigma_total <- function(s) {
    L <- s * Lambda0
    L %*% t(L) + diag(psi) + R_link
  }
  mr_of_s <- function(s) .xfc_multiple_r(sigma_total(s)) - target_mr
  f_lo <- mr_of_s(s_bracket[1]); f_hi <- mr_of_s(s_bracket[2])
  if (f_lo * f_hi > 0) {
    ## widen the upper bracket if the ceiling has not yet passed the target.
    s_bracket[2] <- 200
    f_hi <- mr_of_s(s_bracket[2])
    if (f_lo * f_hi > 0) {
      stop(sprintf(
        "Cannot bracket target multiple_r = %.3f for %s partner (achievable range [%.3f, %.3f]).",
        target_mr, partner_family,
        .xfc_multiple_r(sigma_total(s_bracket[1])),
        .xfc_multiple_r(sigma_total(s_bracket[2]))))
    }
  }
  s <- stats::uniroot(mr_of_s, interval = s_bracket, tol = 1e-8)$root
  Sig_latent <- (s * Lambda0) %*% t(s * Lambda0) + diag(psi)   # link_residual = "none"
  Sig_total  <- Sig_latent + R_link                            # link_residual = "auto"
  ## dimnames must use the ACTUAL trait names the estimator emits (partner
  ## trait name, then the two contrast pseudo-traits) so truth permutes to the
  ## fit's row order by name.
  nm <- c(partner_trait, "cat:2", "cat:3")
  dimnames(Sig_latent) <- dimnames(Sig_total) <- list(nm, nm)
  blk_names <- c("cat:2", "cat:3")
  list(
    partner_family = partner_family,
    partner_trait  = partner_trait,
    partner_famlab = partner_famlab,
    nominal        = "cat",
    trait_names    = nm,
    blk_names      = blk_names,
    s              = s,
    psi            = psi,
    Sigma_latent   = Sig_latent,             # canonical order
    Sigma_total    = Sig_total,              # canonical order
    multiple_r_true = .xfc_multiple_r(Sig_total),
    contrast_r_true = .xfc_contrast_r(Sig_total, blk_names = blk_names)
  )
}

## ---------------------------------------------------------------------
## 2. DGP: simulate one long-format cross-family dataset from a truth object.
## ---------------------------------------------------------------------

.xfc_simulate_data <- function(truth, N, reps, seed, sigma_eps = 0.6, mu = 0) {
  if (!requireNamespace("MASS", quietly = TRUE)) stop("MASS is required for the DGP.")
  set.seed(seed)
  Sig <- truth$Sigma_latent                     # canonical (partner, cat:2, cat:3)
  b <- MASS::mvrnorm(N, mu = rep(0, 3L), Sigma = Sig)   # N x 3 latent per unit
  if (N == 1L) b <- matrix(b, nrow = 1L)
  unit_v <- rep(seq_len(N), each = reps)
  n_obs <- length(unit_v)

  ## multinomial: softmax(c(0, b2, b3)) per row, numerically stable.
  E <- cbind(0, b[unit_v, 2L], b[unit_v, 3L])
  E <- E - apply(E, 1L, max)
  P <- exp(E); P <- P / rowSums(P)
  yc <- vapply(seq_len(n_obs), function(r) sample.int(3L, 1L, prob = P[r, ]), integer(1L))

  ## partner
  bp <- b[unit_v, 1L]
  yp <- if (truth$partner_family == "gaussian") {
    mu + bp + stats::rnorm(n_obs, sd = sigma_eps)
  } else {
    stats::rbinom(n_obs, 1L, stats::plogis(mu + bp))
  }

  dat <- rbind(
    data.frame(unit = unit_v, trait = "cat", family = "m",
               value = as.numeric(yc), stringsAsFactors = FALSE),
    data.frame(unit = unit_v, trait = truth$partner_trait, family = truth$partner_famlab,
               value = as.numeric(yp), stringsAsFactors = FALSE)
  )
  dat$unit   <- factor(dat$unit, levels = seq_len(N))
  dat$trait  <- factor(dat$trait)
  dat$family <- factor(dat$family)
  dat
}

.xfc_family_list <- function(partner_family) {
  fam <- if (partner_family == "gaussian") {
    list(g = gaussian(), m = multinomial())
  } else {
    list(b = binomial(), m = multinomial())
  }
  attr(fam, "family_var") <- "family"
  fam
}

.xfc_fit <- function(data, partner_family, d = 2L, silent = TRUE) {
  fam <- .xfc_family_list(partner_family)
  suppressWarnings(suppressMessages(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = d),
      data = data, family = fam, trait = "trait", unit = "unit", silent = silent
    )
  ))
}

.xfc_converged <- function(fit) {
  !is.null(fit) && inherits(fit, "gllvmTMB_multi") &&
    !is.null(fit$opt) && isTRUE(fit$opt$convergence == 0L)
}

## ---------------------------------------------------------------------
## 3. Hard truth-construction assertion (aborts the campaign if it fails).
##    Fit ONE truth-DGP fixture and confirm the estimator's link_residual="none"
##    total Sigma matches the analytic latent Sigma (Lambda Lambda^T + diag(psi),
##    contrast block INCLUDED) -- i.e. truth == what the estimator targets.
##    This is a finite-sample recovery check: the tolerance is STRUCTURAL (it
##    catches trait-ordering / psi-convention / R_link mistakes, which are many
##    times MC noise) while tolerating ordinary sampling noise.
## ---------------------------------------------------------------------

.xfc_assert_truth <- function(truth, N = 400L, reps = 5L, seed = 12345L,
                              tol_abs = 0.6, tol_rel = 0.25, max_tries = 3L,
                              verbose = TRUE) {
  .xfc_ensure_pkg()
  fit <- NULL
  for (k in seq_len(max_tries)) {
    dat <- .xfc_simulate_data(truth, N = N, reps = reps, seed = seed + 1000L * (k - 1L))
    fit <- tryCatch(.xfc_fit(dat, truth$partner_family), error = function(e) NULL)
    if (.xfc_converged(fit)) break
    fit <- NULL
  }
  if (is.null(fit)) {
    stop("TRUTH ASSERTION ABORT: the truth-DGP fixture did not converge in ",
         max_tries, " tries.")
  }
  S <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                      link_residual = "none"))
  Sig_hat <- if (is.list(S) && !is.null(S$Sigma)) S$Sigma else S
  ord <- rownames(Sig_hat)                       # the estimator's trait order
  Sig_true <- truth$Sigma_latent[ord, ord, drop = FALSE]  # permute truth to match
  D <- abs(Sig_hat - Sig_true)
  allow <- tol_abs + tol_rel * abs(Sig_true)
  ok <- all(D <= allow)
  max_abs <- max(D)
  ## AUTO-scale (total = latent + R_link) is the quantity the wald/bootstrap
  ## intervals TARGET; assert it too (not only the latent scale) so a mismatch in
  ## the estimator's link-residual augmentation is caught, not just a latent error.
  S_auto <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                           link_residual = "auto"))
  Sig_hat_auto <- if (is.list(S_auto) && !is.null(S_auto$Sigma)) S_auto$Sigma else S_auto
  Sig_true_auto <- truth$Sigma_total[ord, ord, drop = FALSE]
  D_auto <- abs(Sig_hat_auto - Sig_true_auto)
  ok_auto <- all(D_auto <= (tol_abs + tol_rel * abs(Sig_true_auto)))
  ok <- ok && ok_auto
  max_abs <- max(max_abs, max(D_auto))
  if (verbose) {
    cat(sprintf("[truth-assertion] partner=%s  target mr_true=%.3f  order=(%s)\n",
                truth$partner_family, truth$multiple_r_true, paste(ord, collapse = ", ")))
    cat(sprintf("[truth-assertion] max|Sigma_hat - Sigma_true| = %.4f  (allow up to %.4f)  => %s\n",
                max_abs, max(allow), if (ok) "PASS" else "FAIL"))
  }
  if (!ok) {
    stop(sprintf(
      "TRUTH ASSERTION ABORT: extract_Sigma(none) != analytic latent Sigma (max|diff|=%.3f).\nSigma_hat:\n%s\nSigma_true:\n%s",
      max_abs,
      paste(utils::capture.output(print(round(Sig_hat, 3))), collapse = "\n"),
      paste(utils::capture.output(print(round(Sig_true, 3))), collapse = "\n")))
  }
  invisible(list(ok = ok, max_abs = max_abs, order = ord,
                 Sigma_hat = Sig_hat, Sigma_true = Sig_true, note = XFC_BANNER))
}

## ---------------------------------------------------------------------
## 4. One replicate: fit once, then measure BOTH estimands' interval coverage.
##    Coverage metric (v3 BLOCKER 2): coverage = covered / CONVERGED reps.
##    A ci_failed / NA-bound interval counts as a MISS (never dropped). Only
##    pre-CI, outcome-independent base-optimizer non-convergence is excluded.
## ---------------------------------------------------------------------

.xfc_one_rep <- function(truth, N, reps, seed, n_boot,
                         estimands = c("multiple_r", "contrast_r"),
                         methods_multiple_r = c("bootstrap", "wald"),
                         methods_contrast_r = c("profile", "wald", "bootstrap"),
                         conf = 0.95) {
  dat <- .xfc_simulate_data(truth, N = N, reps = reps, seed = seed)
  fit <- tryCatch(.xfc_fit(dat, truth$partner_family), error = function(e) NULL)
  converged <- .xfc_converged(fit)
  pdHess <- converged && isTRUE(fit$sd_report$pdHess)
  res <- list(seed = seed, converged = converged, pdHess = pdHess,
              multiple_r = NULL, contrast_r = NULL)
  if (!converged) return(res)   # excluded from the denominator (tracked)

  ## Path-2 gate: never bootstrap a fit whose RE cannot be unconditionally redrawn.
  can_redraw <- isTRUE(.xfc_can_redraw(fit)$can_redraw)
  ## Only compute methods for the estimands actually requested (an estimand-
  ## scoped run must not pay for the other estimand's refit/profile cost).
  needed_methods <- unique(c(
    if ("multiple_r" %in% estimands) methods_multiple_r,
    if ("contrast_r" %in% estimands) methods_contrast_r))

  ## ---- ONE extract_cross_correlations() call per requested METHOD, fit
  ## reused across estimands: "wald" and "bootstrap" each serve BOTH
  ## multiple_r and contrast_r in a single call; "profile" serves contrast_r
  ## only (multiple_r x profile is not wired -- fenced upstream). ----------
  cc_by_method <- list()
  if ("wald" %in% needed_methods) {
    cc_by_method$wald <- tryCatch(
      suppressMessages(extract_cross_correlations(
        fit, level = "unit", contrasts = TRUE, link_residual = "auto",
        method = "wald", conf = conf)),
      error = function(e) NULL)
  }
  if ("bootstrap" %in% needed_methods) {
    cc_by_method$bootstrap <- if (!can_redraw) NULL else tryCatch(
      suppressMessages(extract_cross_correlations(
        fit, level = "unit", contrasts = TRUE, link_residual = "auto",
        method = "bootstrap", conf = conf, nsim = as.integer(n_boot), seed = seed)),
      error = function(e) NULL)
  }
  if ("profile" %in% needed_methods) {
    cc_by_method$profile <- tryCatch(
      suppressMessages(extract_cross_correlations(
        fit, level = "unit", contrasts = TRUE, link_residual = "auto",
        method = "profile", conf = conf)),
      error = function(e) NULL)
  }

  ## ---- multiple_r: one row per method -------------------------------------
  if ("multiple_r" %in% estimands) {
    rows <- vector("list", length(methods_multiple_r))
    for (mi in seq_along(methods_multiple_r)) {
      meth <- methods_multiple_r[mi]
      cc <- cc_by_method[[meth]]
      lo <- hi <- NA_real_
      if (!is.null(cc) && nrow(cc) >= 1L) {
        lo <- as.numeric(cc$multiple_r_lower[1L])
        hi <- as.numeric(cc$multiple_r_upper[1L])
      }
      ci_failed <- !is.finite(lo) || !is.finite(hi)
      covered <- !ci_failed && (truth$multiple_r_true >= lo) && (truth$multiple_r_true <= hi)
      miss_side <- if (ci_failed) "ci_failed"
                   else if (covered) NA_character_
                   else if (truth$multiple_r_true < lo) "lower" else "upper"
      rows[[mi]] <- data.frame(
        seed = seed, method = meth, truth = truth$multiple_r_true, lower = lo, upper = hi,
        ci_failed = ci_failed, covered = covered, miss_side = miss_side,
        stringsAsFactors = FALSE)
    }
    res$multiple_r <- do.call(rbind, rows)
  }

  ## ---- contrast_r: one row per (method, contrast) -------------------------
  if ("contrast_r" %in% estimands) {
    blk <- truth$blk_names
    cr_true <- truth$contrast_r_true
    rows <- list()
    for (meth in methods_contrast_r) {
      cc <- cc_by_method[[meth]]
      for (k in seq_along(blk)) {
        lo <- hi <- NA_real_
        if (!is.null(cc) && nrow(cc) >= 1L) {
          lo <- as.numeric(cc$contrast_r_lower[[1L]][blk[k]])
          hi <- as.numeric(cc$contrast_r_upper[[1L]][blk[k]])
        }
        ci_failed <- !is.finite(lo) || !is.finite(hi)
        tr <- as.numeric(cr_true[blk[k]])
        covered <- !ci_failed && (tr >= lo) && (tr <= hi)
        miss_side <- if (ci_failed) "ci_failed"
                     else if (covered) NA_character_
                     else if (tr < lo) "lower" else "upper"
        rows[[length(rows) + 1L]] <- data.frame(
          seed = seed, method = meth, contrast = blk[k], truth = tr, lower = lo, upper = hi,
          ci_failed = ci_failed, covered = covered, miss_side = miss_side,
          stringsAsFactors = FALSE)
      }
    }
    res$contrast_r <- do.call(rbind, rows)
  }
  res
}

## ---------------------------------------------------------------------
## 5. MCSE + gate reducers.
## ---------------------------------------------------------------------

## Power to pass the (phat - 2*MCSE >= gate) rule if the TRUE coverage were
## `nominal`, at N_reps converged reps (normal approximation). Reported so a
## PASS is read against its power, and a FAIL is not mistaken for miscalibration.
.xfc_gate_power <- function(N_reps, gate = 0.94, nominal = 0.95) {
  if (is.na(N_reps) || N_reps < 1) return(NA_real_)
  se0 <- sqrt(nominal * (1 - nominal) / N_reps)
  thr <- gate + 2 * se0            # phat threshold implied by the lower-band rule
  stats::pnorm((nominal - thr) / se0)
}

## Summarise one coverage series (a vector of covered/ci_failed over converged
## reps, PLUS the non-converged count) into the gate verdict.
.xfc_summarise_series <- function(covered, ci_failed, n_nonconverged,
                                  gate = 0.94, nominal = 0.95) {
  n_conv <- length(covered)                       # converged reps (denominator)
  n_cov <- sum(covered)                           # ci_failed already FALSE here
  n_cifail <- sum(ci_failed)
  p_hat <- if (n_conv > 0) n_cov / n_conv else NA_real_
  mcse <- if (n_conv > 0) sqrt(p_hat * (1 - p_hat) / n_conv) else NA_real_
  lower_band <- p_hat - 2 * mcse
  n_total <- n_conv + n_nonconverged
  ## worst-case sensitivity: non-converged treated as not-covered.
  p_wc <- if (n_total > 0) n_cov / n_total else NA_real_
  mcse_wc <- if (n_total > 0) sqrt(p_wc * (1 - p_wc) / n_total) else NA_real_
  data.frame(
    n_converged = n_conv,
    n_nonconverged = n_nonconverged,
    conv_rate = if (n_total > 0) n_conv / n_total else NA_real_,
    n_covered = n_cov,
    n_ci_failed = n_cifail,
    ci_failed_rate = if (n_conv > 0) n_cifail / n_conv else NA_real_,
    coverage = p_hat,
    mcse = mcse,
    lower_2mcse = lower_band,
    gate = gate,
    gate_pass = isTRUE(lower_band >= gate),
    coverage_worstcase = p_wc,
    lower_2mcse_worstcase = p_wc - 2 * mcse_wc,
    gate_pass_worstcase = isTRUE((p_wc - 2 * mcse_wc) >= gate),
    power_vs_nominal = .xfc_gate_power(n_conv, gate, nominal),
    note = XFC_BANNER,
    stringsAsFactors = FALSE
  )
}

## ---------------------------------------------------------------------
## 6. Run one grid cell -> per-cell coverage summaries for both estimands.
## ---------------------------------------------------------------------

## Deterministic per-rep seed: cell-stable base + rep index, shard-safe.
.xfc_rep_seed <- function(seed_base, cell_id, rep) {
  as.integer((seed_base %% 100000L) + 1000003L * (cell_id %% 997L) + rep)
}

xfc_run_cell <- function(truth, N, reps, n_sim, n_boot, seed_base, cell_id = 1L,
                         rep_range = c(1L, n_sim),
                         estimands = c("multiple_r", "contrast_r"),
                         methods_multiple_r = c("bootstrap", "wald"),
                         methods_contrast_r = c("profile", "wald", "bootstrap"),
                         conf = 0.95, gate = 0.94, verbose = TRUE) {
  .xfc_ensure_pkg()
  rr <- seq.int(rep_range[1L], rep_range[2L])
  mr_rows <- list(); cr_rows <- list()
  n_nonconv <- 0L
  for (i in rr) {
    seed <- .xfc_rep_seed(seed_base, cell_id, i)
    rep_res <- tryCatch(
      .xfc_one_rep(truth, N = N, reps = reps, seed = seed, n_boot = n_boot,
                   estimands = estimands, methods_multiple_r = methods_multiple_r,
                   methods_contrast_r = methods_contrast_r, conf = conf),
      error = function(e) list(converged = FALSE))
    if (!isTRUE(rep_res$converged)) { n_nonconv <- n_nonconv + 1L; next }
    if (!is.null(rep_res$multiple_r)) mr_rows[[length(mr_rows) + 1L]] <- rep_res$multiple_r
    if (!is.null(rep_res$contrast_r)) cr_rows[[length(cr_rows) + 1L]] <- rep_res$contrast_r
  }

  out <- list(
    meta = data.frame(
      cell_id = cell_id, partner = truth$partner_family, N = N, reps = reps,
      n_sim = n_sim, n_boot = n_boot, rep_start = rep_range[1L], rep_end = rep_range[2L],
      target_multiple_r = truth$multiple_r_true,
      ## Fit-level non-convergence carried in META (not only in the per-estimand
      ## summaries) so the worst-case denominator is honest even when a shard has
      ## ZERO converged reps (its summaries are NULL, but this count survives).
      n_nonconverged = n_nonconv, note = XFC_BANNER,
      stringsAsFactors = FALSE),
    raw_multiple_r = if (length(mr_rows)) do.call(rbind, mr_rows) else NULL,
    raw_contrast_r = if (length(cr_rows)) do.call(rbind, cr_rows) else NULL,
    summary_multiple_r = NULL, summary_contrast_r = NULL)

  ## Per-(estimand, method) summaries -- multiple_r splits on `method`;
  ## contrast_r splits on `method` x `contrast` (drop = TRUE: only combos that
  ## actually occurred, since a method may be entirely NULL on a bad rep).
  if ("multiple_r" %in% estimands && length(mr_rows)) {
    m <- do.call(rbind, mr_rows)
    per <- lapply(split(m, m$method, drop = TRUE), function(mk) {
      s <- .xfc_summarise_series(mk$covered, mk$ci_failed, n_nonconv, gate = gate)
      cbind(data.frame(cell_id = cell_id, partner = truth$partner_family, N = N,
                       estimand = "multiple_r", method = mk$method[1L],
                       contrast = NA_character_,
                       truth = truth$multiple_r_true, stringsAsFactors = FALSE), s)
    })
    out$summary_multiple_r <- do.call(rbind, per)
  }
  if ("contrast_r" %in% estimands && length(cr_rows)) {
    m <- do.call(rbind, cr_rows)
    per <- lapply(split(m, list(m$method, m$contrast), drop = TRUE), function(mk) {
      s <- .xfc_summarise_series(mk$covered, mk$ci_failed, n_nonconv, gate = gate)
      cbind(data.frame(cell_id = cell_id, partner = truth$partner_family, N = N,
                       estimand = "contrast_r", method = mk$method[1L],
                       contrast = mk$contrast[1L],
                       truth = mk$truth[1L], stringsAsFactors = FALSE), s)
    })
    out$summary_contrast_r <- do.call(rbind, per)
  }
  if (verbose) {
    cat(sprintf("[cell %d] partner=%s N=%d mr_true=%.3f  reps=[%d,%d] nonconv=%d\n",
                cell_id, truth$partner_family, N, truth$multiple_r_true,
                rep_range[1L], rep_range[2L], n_nonconv))
    if (!is.null(out$summary_multiple_r)) {
      for (ri in seq_len(nrow(out$summary_multiple_r))) {
        s <- out$summary_multiple_r[ri, ]
        cat(sprintf("         multiple_r[%s]: coverage=%.3f (2MCSE lower %.3f) conv=%.2f gate>=%.2f -> %s  [%s]\n",
                    s$method, s$coverage, s$lower_2mcse, s$conv_rate, s$gate,
                    ifelse(s$gate_pass, "PASS", "no"), XFC_BANNER))
      }
    }
    if (!is.null(out$summary_contrast_r)) {
      for (ri in seq_len(nrow(out$summary_contrast_r))) {
        s <- out$summary_contrast_r[ri, ]
        cat(sprintf("         contrast_r[%s,%s]: coverage=%.3f (2MCSE lower %.3f) conv=%.2f gate>=%.2f -> %s  [%s]\n",
                    s$method, s$contrast, s$coverage, s$lower_2mcse, s$conv_rate, s$gate,
                    ifelse(s$gate_pass, "PASS", "no"), XFC_BANNER))
      }
    }
  }
  out
}

## ---------------------------------------------------------------------
## 7. Pre-campaign inner-convergence gate: measure the K=3 cross-family refit
##    convergence rate + the inner-bootstrap min-effective-B survival on 1-2
##    pilot cells; print an ABORT / PROCEED recommendation if convergence < 0.8.
## ---------------------------------------------------------------------

xfc_inner_convergence_gate <- function(cells = NULL, n_pilot = 8L, n_boot = 25L,
                                       reps = 5L, seed_base = 20260718L,
                                       min_conv = 0.8, verbose = TRUE) {
  .xfc_ensure_pkg()
  if (is.null(cells)) {
    cells <- list(
      list(partner_family = "gaussian", target_mr = 0.5, N = 150L),
      list(partner_family = "binomial", target_mr = 0.5, N = 150L)
    )
  }
  rows <- list()
  for (ci in seq_along(cells)) {
    cc <- cells[[ci]]
    truth <- .xfc_build_truth(cc$target_mr, cc$partner_family)
    n_conv <- 0L; surv <- numeric(0)
    for (i in seq_len(n_pilot)) {
      seed <- .xfc_rep_seed(seed_base, 900L + ci, i)
      dat <- .xfc_simulate_data(truth, N = cc$N, reps = reps, seed = seed)
      fit <- tryCatch(.xfc_fit(dat, cc$partner_family), error = function(e) NULL)
      if (!.xfc_converged(fit)) next
      n_conv <- n_conv + 1L
      ## inner-bootstrap survival: min per-partner finite-draw fraction.
      boot <- tryCatch(
        suppressMessages(gllvmTMB::bootstrap_Sigma(
          fit, n_boot = as.integer(n_boot), level = "unit", what = "cross_corr",
          conf = 0.95, link_residual = "auto", seed = seed, progress = FALSE)),
        error = function(e) NULL)
      ne <- if (!is.null(boot)) boot$n_effective[["multiple_r_B"]] else NULL
      if (!is.null(ne) && length(ne)) surv <- c(surv, min(ne) / n_boot)
    }
    conv_rate <- n_conv / n_pilot
    min_surv <- if (length(surv)) min(surv) else NA_real_
    med_surv <- if (length(surv)) stats::median(surv) else NA_real_
    rows[[ci]] <- data.frame(
      partner = cc$partner_family, target_mr = cc$target_mr, N = cc$N,
      n_pilot = n_pilot, outer_conv_rate = conv_rate,
      inner_min_survival = min_surv, inner_median_survival = med_surv,
      note = XFC_BANNER, stringsAsFactors = FALSE)
  }
  tab <- do.call(rbind, rows)
  worst <- min(tab$outer_conv_rate, na.rm = TRUE)
  recommend <- if (worst >= min_conv) "PROCEED" else "ABORT / lower-B / relax-tol"
  if (verbose) {
    cat("\n==== INNER-CONVERGENCE GATE ====  [", XFC_BANNER, "]\n", sep = "")
    print(tab, row.names = FALSE)
    cat(sprintf("worst outer convergence = %.2f  (threshold %.2f)  =>  RECOMMENDATION: %s\n\n",
                worst, min_conv, recommend))
  }
  invisible(list(table = tab, worst_conv = worst, recommend = recommend,
                 proceed = worst >= min_conv))
}

## ---------------------------------------------------------------------
## 8. The grid: CERTIFIED interior cells + NON-CERTIFIED boundary diagnostics.
## ---------------------------------------------------------------------

## Certified interior cells: N in {50,150,500} x mr in {0.2,0.5,0.8}
##   x partner in {gaussian, binomial}. All interior (mr <= 0.8, never ->1).
xfc_grid_certified <- function() {
  g <- expand.grid(
    N = c(50L, 150L, 500L),
    target_mr = c(0.2, 0.5, 0.8),
    partner = c("gaussian", "binomial"),
    stringsAsFactors = FALSE)
  g$kind <- "certified"
  g$cell_id <- seq_len(nrow(g))
  g
}

## Non-certified DIAGNOSTIC boundary cells (NOT part of any certificate):
##   * near-collinear  -> multiple_r -> 1 (atanh/clamp regime).
##   * near-zero       -> trips the sqrt(max(0,.)) point mass.
xfc_grid_diagnostic <- function() {
  g <- rbind(
    data.frame(N = 150L, target_mr = 0.97, partner = "gaussian", stringsAsFactors = FALSE),
    data.frame(N = 150L, target_mr = 0.05, partner = "gaussian", stringsAsFactors = FALSE)
  )
  g$kind <- "diagnostic"
  g$cell_id <- 100L + seq_len(nrow(g))
  g
}

## ---------------------------------------------------------------------
## 9. Grid driver: run a set of cells for one shard, write LOCAL .rds.
## ---------------------------------------------------------------------

xfc_run_grid <- function(grid, N_sim, n_boot, seed_base, shard = 1L, n_shards = 1L,
                         estimands = c("multiple_r", "contrast_r"),
                         reps = 5L, conf = 0.95, gate = 0.94,
                         out_dir = "cross-family-coverage-results",
                         assert_truth = TRUE, verbose = TRUE) {
  .xfc_ensure_pkg()
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  cells <- lapply(seq_len(nrow(grid)), function(r) {
    row <- grid[r, ]
    truth <- .xfc_build_truth(row$target_mr, row$partner)
    list(row = row, truth = truth)
  })

  ## Truth-construction assertion (ONE fixture per distinct partner family).
  if (assert_truth) {
    for (pf in unique(grid$partner)) {
      tr <- .xfc_build_truth(0.5, pf)              # a representative interior truth
      .xfc_assert_truth(tr, verbose = verbose)     # aborts on failure
    }
  }

  results <- list()
  for (cc in cells) {
    row <- cc$row
    rr <- unname(as.integer(.xfc_shard_range(N_sim, shard, n_shards)))
    results[[length(results) + 1L]] <- xfc_run_cell(
      cc$truth, N = row$N, reps = reps, n_sim = N_sim, n_boot = n_boot,
      seed_base = seed_base, cell_id = row$cell_id, rep_range = rr,
      estimands = estimands, conf = conf, gate = gate, verbose = verbose)
  }

  fn <- file.path(out_dir, sprintf(
    "xfc-coverage_shard%03d-of-%03d_nsim%d_nboot%d_seed%d.rds",
    shard, n_shards, N_sim, n_boot, seed_base))
  saveRDS(list(grid = grid, results = results, shard = shard, n_shards = n_shards,
               N_sim = N_sim, n_boot = n_boot, seed_base = seed_base,
               note = XFC_BANNER, when = Sys.time()), fn)
  if (verbose) cat(sprintf("[grid] wrote %s  [%s]\n", fn, XFC_BANNER))
  invisible(list(file = fn, results = results))
}

## Shard a 1:N_sim rep range into contiguous blocks (one block per shard).
.xfc_shard_range <- function(n_sim, shard = 1L, n_shards = 1L) {
  n_sim <- as.integer(n_sim); shard <- as.integer(shard); n_shards <- as.integer(n_shards)
  if (n_shards < 1L || shard < 1L || shard > n_shards) stop("bad shard/n_shards")
  if (n_shards > n_sim) n_shards <- n_sim
  c(start = floor((shard - 1L) * n_sim / n_shards) + 1L,
    end   = floor(shard * n_sim / n_shards))
}

## ---------------------------------------------------------------------
## 10. Smoke: 1 gaussian cell, tiny N + tiny n_sim, end-to-end via load_all.
##     Confirms (a) the truth assertion passes and (b) all 5 wired
##     (estimand, method) cells -- multiple_r x {bootstrap, wald},
##     contrast_r x {profile, wald, bootstrap} -- produce a summary row.
##     Runs in a couple of minutes; NOT a campaign.
## ---------------------------------------------------------------------

xfc_smoke <- function() {
  .xfc_ensure_pkg()
  cat("==== xfc_smoke ====  [", XFC_BANNER, "]\n", sep = "")
  truth <- .xfc_build_truth(target_mr = 0.5, partner_family = "gaussian")
  cat(sprintf("built truth: mr_true=%.4f  s=%.3f  contrast_r_true=(%s)\n",
              truth$multiple_r_true, truth$s,
              paste(sprintf("%.3f", truth$contrast_r_true), collapse = ", ")))

  ## (a) hard truth-construction assertion (aborts on failure).
  ta <- .xfc_assert_truth(truth, N = 150L, reps = 4L, seed = 202607L,
                          tol_abs = 0.8, tol_rel = 0.3)

  ## (b) a tiny coverage cell: 3 reps, tiny N, tiny inner bootstrap; all 5
  ## wired cells (default methods_multiple_r / methods_contrast_r).
  cell <- xfc_run_cell(
    truth, N = 40L, reps = 4L, n_sim = 3L, n_boot = 8L,
    seed_base = 20260718L, cell_id = 1L,
    estimands = c("multiple_r", "contrast_r"), verbose = TRUE)

  cat("\n---- smoke coverage summary (multiple_r) ----\n")
  print(cell$summary_multiple_r, row.names = FALSE)
  cat("\n---- smoke coverage summary (contrast_r) ----\n")
  print(cell$summary_contrast_r, row.names = FALSE)
  cat("\n---- raw multiple_r rows ----\n")
  print(cell$raw_multiple_r, row.names = FALSE)

  ## 5-cell coverage check: multiple_r x {bootstrap, wald} (2 rows) +
  ## contrast_r x {profile, wald, bootstrap} x 2 contrasts (6 rows).
  mr_methods <- sort(unique(cell$summary_multiple_r$method))
  cr_methods <- sort(unique(cell$summary_contrast_r$method))
  cat(sprintf("\n[xfc_smoke] multiple_r methods present: %s\n",
              paste(mr_methods, collapse = ", ")))
  cat(sprintf("[xfc_smoke] contrast_r methods present: %s\n",
              paste(cr_methods, collapse = ", ")))
  five_cell_ok <- setequal(mr_methods, c("bootstrap", "wald")) &&
    setequal(cr_methods, c("bootstrap", "profile", "wald"))
  cat(sprintf("[xfc_smoke] all 5 wired cells present: %s\n",
              if (five_cell_ok) "YES" else "NO"))

  invisible(list(truth_assertion = ta, cell = cell, five_cell_ok = five_cell_ok,
                 note = XFC_BANNER))
}

## ---------------------------------------------------------------------
## 11. CLI main (env-var guarded so `source()` under load_all never fires it).
## ---------------------------------------------------------------------

.xfc_parse_args <- function(args) {
  kv <- list()
  for (a in args) {
    m <- regmatches(a, regexec("^--([A-Za-z0-9_-]+)=(.*)$", a))[[1]]
    if (length(m) == 3L) kv[[m[2]]] <- m[3]
  }
  kv
}

.xfc_launch_note <- function() {
  cat("
HOW TO LAUNCH ON TOTORO (results LOCAL only; D-50 -- never GitHub artifacts):
  # 0. deploy the worktree (branch is unpushed): rsync to ~/gtmb_work, install/load_all there.
  # 1. inner-convergence gate FIRST (cheap), decide PROCEED/ABORT:
  XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=gate --seed-base=20260718
  # 2. pilot (plumbing/smoke scale), one shard per array task:
  XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=pilot \\
      --n-sim=200 --n-boot=199 --shard=$SLURM_ARRAY_TASK_ID --n-shards=100 --seed-base=20260718
  # 3. confirm (~12k CONVERGED reps; inflate n-sim for attrition), sharded:
  XFC_MAIN=1 Rscript dev/cross-family-coverage.R --mode=confirm \\
      --n-sim=13000 --n-boot=499 --shard=$SLURM_ARRAY_TASK_ID --n-shards=200 --seed-base=20260718
Each shard writes ONE .rds (rep block [start,end] per cell) into --out-dir; aggregate offline.
Keep cores <= 100 on Totoro. Every number carries: ", XFC_BANNER, "\n", sep = "")
}

xfc_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  .xfc_ensure_pkg()
  kv <- .xfc_parse_args(args)
  mode      <- kv[["mode"]]      %||% "pilot"
  shard     <- as.integer(kv[["shard"]]     %||% "1")
  n_shards  <- as.integer(kv[["n-shards"]]  %||% "1")
  n_sim     <- as.integer(kv[["n-sim"]]     %||% "200")
  n_boot    <- as.integer(kv[["n-boot"]]    %||% "199")
  seed_base <- as.integer(kv[["seed-base"]] %||% "20260718")
  reps      <- as.integer(kv[["reps"]]      %||% "5")
  out_dir   <- kv[["out-dir"]]   %||% "cross-family-coverage-results"
  grid_kind <- kv[["grid"]]      %||% "certified"
  est       <- strsplit(kv[["estimands"]] %||% "multiple_r,contrast_r", ",")[[1]]

  cat(sprintf("[xfc_main] mode=%s grid=%s shard=%d/%d n_sim=%d n_boot=%d seed_base=%d  [%s]\n",
              mode, grid_kind, shard, n_shards, n_sim, n_boot, seed_base, XFC_BANNER))

  if (identical(mode, "gate")) {
    return(invisible(xfc_inner_convergence_gate(seed_base = seed_base)))
  }
  if (identical(mode, "smoke")) {
    return(invisible(xfc_smoke()))
  }
  grid <- switch(grid_kind,
                 certified = xfc_grid_certified(),
                 ## lean: the light interior cells (N <= 150) for a fast in-session
                 ## plumbing-scale signal; the heavy N=500 cells run in the full campaign.
                 lean = { g <- xfc_grid_certified(); g[g$N <= 150L, , drop = FALSE] },
                 diagnostic = xfc_grid_diagnostic(),
                 both = rbind(xfc_grid_certified(), xfc_grid_diagnostic()),
                 stop("--grid must be certified|lean|diagnostic|both"))
  xfc_run_grid(grid, N_sim = n_sim, n_boot = n_boot, seed_base = seed_base,
               shard = shard, n_shards = n_shards, estimands = est, reps = reps,
               out_dir = out_dir, assert_truth = TRUE, verbose = TRUE)
}

## small null-coalesce
`%||%` <- function(a, b) if (is.null(a)) b else a

if (identical(Sys.getenv("XFC_MAIN"), "1")) {
  xfc_main()
}
