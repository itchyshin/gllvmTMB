## =====================================================================
## xfc-stress-test.R -- empirical robustness probe for
## extract_cross_correlations() and its wald / bootstrap / profile
## interval routes, on TINY cross-family multinomial fits.
##
## MEASURED, NOT certified. This script does not certify coverage or
## correctness. It DELIBERATELY drives extract_cross_correlations() into
## the singular / ill-conditioned / boundary / few-unit regimes named in
## the ci11 robustness audit and records, per (regime, method), one of:
##     ok | crash | clean_error | NA_interval | non_bracketing |
##     absurd_width | absurd_point
## so a human can SEE which failure modes fire on real fits before any
## certification claim is made. It is a diagnostic, not evidence.
##
## Run (from the package root, .so already built):
##   pkgload::load_all(".", quiet = TRUE, compile = FALSE)  # (done inside)
##   source("dev/xfc-stress-test.R")
##   print(xfc_stress_test())
## or non-interactively:
##   XFC_STRESS_MAIN=1 Rscript dev/xfc-stress-test.R
##
## Sourcing alone does NOT run anything (guarded at the bottom).
## Targets ~1-3 minutes on tiny (N = 12 unit) fits.
## =====================================================================

XFC_STRESS_BANNER <- "MEASURED, NOT certified -- robustness probe, not evidence"

## ---------------------------------------------------------------------
## 0. Setup: load the package + reuse the coverage harness helpers.
##    We temporarily clear XFC_MAIN so sourcing the harness does not
##    auto-launch a campaign (its bottom guard keys off XFC_MAIN == "1").
## ---------------------------------------------------------------------

.xfcs_setup <- function(pkg = ".") {
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required (install.packages('pkgload')).")
  }
  pkgload::load_all(pkg, quiet = TRUE, compile = FALSE)
  harness <- file.path(pkg, "dev", "cross-family-coverage.R")
  if (!file.exists(harness)) {
    stop("cannot find the coverage harness at ", harness,
         " (run from the package root).")
  }
  old_main <- Sys.getenv("XFC_MAIN", unset = NA)
  Sys.unsetenv("XFC_MAIN")
  on.exit(if (!is.na(old_main)) Sys.setenv(XFC_MAIN = old_main), add = TRUE)
  ## Reuse .xfc_build_truth / .xfc_simulate_data / .xfc_fit / .xfc_can_redraw
  ## for the K = 3 boundary regimes; the large-K and poisson regimes use the
  ## generalized simulator below.
  sys.source(normalizePath(harness), envir = globalenv())
  invisible(TRUE)
}

`%|%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

## ---------------------------------------------------------------------
## 1. Generalized K-category DGP (mirrors the harness K = 3 DGP, but for
##    arbitrary K and a poisson partner). A rank-r latent with r < K-1
##    makes the estimator's (K-1) x (K-1) contrast block Scc numerically
##    rank-deficient -> solve() throws -> MASS::ginv() fallback fires
##    (findings 1/2/5); large coupling s drives multiple_r -> the min(.,1)
##    clamp; link_residual = "none" removes the diagonal floor that would
##    otherwise regularize the contrast block (finding 3).
## ---------------------------------------------------------------------

.xfcs_lambda0_K <- function(K, r = 1L) {
  base <- c(1.0, 0.9, 0.7, 0.5, 0.3, 0.2, 0.15, 0.1)
  L <- matrix(base[seq_len(K)], ncol = 1L)          # partner in the contrast span
  if (r > 1L) L <- cbind(L, matrix(stats::rnorm(K * (r - 1L), sd = 0.25), K, r - 1L))
  L
}

.xfcs_simulate_K <- function(K, N, reps, seed, partner_family = "gaussian",
                             s = 3, r = 1L, psi_partner = 0.5, sigma_eps = 0.6) {
  if (!requireNamespace("MASS", quietly = TRUE)) stop("MASS is required for the DGP.")
  set.seed(seed)
  L   <- s * .xfcs_lambda0_K(K, r = r)
  psi <- c(psi_partner, rep(0, K - 1L))              # contrast psi pinned to 0
  Sig <- L %*% t(L) + diag(psi)                      # K x K latent (partner, cat:2..cat:K)
  b   <- MASS::mvrnorm(N, mu = rep(0, K), Sigma = Sig)
  if (N == 1L) b <- matrix(b, nrow = 1L)
  unit_v <- rep(seq_len(N), each = reps)
  n_obs  <- length(unit_v)
  ## multinomial: softmax(c(0, b2..bK)) per row, numerically stable.
  E <- cbind(0, b[unit_v, 2:K, drop = FALSE])
  E <- E - apply(E, 1L, max)
  P <- exp(E); P <- P / rowSums(P)
  yc <- vapply(seq_len(n_obs), function(rr) sample.int(K, 1L, prob = P[rr, ]), integer(1L))
  bp <- b[unit_v, 1L]
  plab <- switch(partner_family, gaussian = "g", binomial = "b", poisson = "p",
                 stop("partner_family must be gaussian/binomial/poisson"))
  yp <- switch(partner_family,
    gaussian = bp + stats::rnorm(n_obs, sd = sigma_eps),
    binomial = stats::rbinom(n_obs, 1L, stats::plogis(bp)),
    poisson  = stats::rpois(n_obs, exp(0.5 + 0.5 * bp)))
  dat <- rbind(
    data.frame(unit = unit_v, trait = "cat", family = "m",
               value = as.numeric(yc), stringsAsFactors = FALSE),
    data.frame(unit = unit_v, trait = plab, family = plab,
               value = as.numeric(yp), stringsAsFactors = FALSE))
  dat$unit   <- factor(dat$unit, levels = seq_len(N))
  dat$trait  <- factor(dat$trait)
  dat$family <- factor(dat$family)
  dat
}

.xfcs_fit_K <- function(dat, partner_family, d = 1L) {
  fam <- switch(partner_family,
    gaussian = list(g = gaussian(), m = multinomial()),
    binomial = list(b = binomial(), m = multinomial()),
    poisson  = list(p = poisson(),  m = multinomial()))
  attr(fam, "family_var") <- "family"
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = d),
    data = dat, family = fam, trait = "trait", unit = "unit", silent = TRUE)))
}

.xfcs_converged <- function(fit) {
  !is.null(fit) && inherits(fit, "gllvmTMB_multi") &&
    !is.null(fit$opt) && isTRUE(fit$opt$convergence == 0L)
}

## ---------------------------------------------------------------------
## 2. Call wrapper + outcome classifier.
## ---------------------------------------------------------------------

## Evaluate a thunk, capturing errors AND warnings without aborting.
.xfcs_call <- function(thunk) {
  warns <- character(0)
  val <- withCallingHandlers(
    tryCatch(thunk(),
             error = function(e)
               structure(list(msg = conditionMessage(e)), class = "xfcs_err")),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  list(val = val, warns = warns)
}

.PAT_BRACKET <- "bracket|uniroot|opposite sign|end points|f\\(\\) values|not.*finite.*root"
.PAT_CLEAN   <- paste0("certified only|parameter- or mean-dependent|needs .*contrast|",
                       "unconditional|cannot be.*redraw|not.*profileable|singular .*Scc|",
                       "no non-nominal partner")

## Classify one (regime, method) call into a single outcome token.
.xfcs_classify <- function(res) {
  v <- res$val; warns <- res$warns
  if (inherits(v, "xfcs_err")) {
    msg <- v$msg
    if (grepl(.PAT_BRACKET, msg, ignore.case = TRUE)) {
      return(list(outcome = "non_bracketing", detail = .xfcs_trunc(msg)))
    }
    if (grepl(.PAT_CLEAN, msg, ignore.case = TRUE)) {
      return(list(outcome = "clean_error", detail = .xfcs_trunc(msg)))
    }
    return(list(outcome = "crash", detail = .xfcs_trunc(msg)))
  }
  if (!is.data.frame(v)) {
    return(list(outcome = "crash", detail = "non-data.frame return"))
  }
  ## gather point estimates + interval bounds
  mr_pt <- suppressWarnings(as.numeric(v$multiple_r %|% NA_real_))
  cr_pt <- suppressWarnings(as.numeric(unlist(v$contrast_r %|% list())))
  mr_lo <- suppressWarnings(as.numeric(v$multiple_r_lower %|% NA_real_))
  mr_hi <- suppressWarnings(as.numeric(v$multiple_r_upper %|% NA_real_))
  cr_lo <- suppressWarnings(as.numeric(unlist(v$contrast_r_lower %|% list())))
  cr_hi <- suppressWarnings(as.numeric(unlist(v$contrast_r_upper %|% list())))
  pts   <- c(mr_pt, cr_pt)
  ## --- absurd POINT: |r| > 1 or NaN in a headline estimate (finding 3) ---
  if (any(is.nan(pts)) || any(abs(pts) > 1 + 1e-6, na.rm = TRUE)) {
    bad <- pts[is.nan(pts) | (abs(pts) > 1 + 1e-6 & !is.na(pts))]
    return(list(outcome = "absurd_point",
                detail = paste0("point out of [-1,1]/NaN: ",
                                paste(signif(bad[seq_len(min(3, length(bad)))], 4),
                                      collapse = ", "))))
  }
  ## multiple_r pinned to exactly 1 by the min(.,1) clamp with an NA CI:
  ## "estimate certain, interval unavailable" masking numerical garbage (finding 2)
  pinned <- any(is.finite(mr_pt) & abs(mr_pt - 1) < 1e-9)
  ## interval columns present? (point-only method has none)
  has_iv <- any(c("multiple_r_lower", "contrast_r_lower") %in% names(v))
  if (has_iv) {
    all_bounds <- c(mr_lo, mr_hi, cr_lo, cr_hi)
    n_bound_slots <- length(all_bounds)
    n_na <- sum(is.na(all_bounds))
    if (n_bound_slots > 0L && n_na == n_bound_slots) {
      return(list(outcome = "NA_interval",
                  detail = paste0("all ", n_bound_slots, " CI bound(s) NA",
                                  if (pinned) "; multiple_r pinned at 1" else "")))
    }
    ## widest interval as a fraction of its feasible range (mr in [0,1] -> 1;
    ## cr in [-1,1] -> 2). >= 0.95 == essentially uninformative.
    fr_mr <- max((mr_hi - mr_lo) / 1, na.rm = TRUE)
    fr_cr <- suppressWarnings(max((cr_hi - cr_lo) / 2, na.rm = TRUE))
    frac  <- suppressWarnings(max(c(fr_mr, fr_cr), na.rm = TRUE))
    if (is.finite(frac) && frac >= 0.95) {
      return(list(outcome = "absurd_width",
                  detail = paste0("widest CI = ", round(100 * frac), "% of feasible range")))
    }
    if (pinned) {
      return(list(outcome = "absurd_point",
                  detail = "multiple_r clamped to exactly 1 (min(.,1) guard)"))
    }
  }
  det <- "finite point + interval"
  if (length(warns) > 0L) det <- paste0(det, "; warn: ", .xfcs_trunc(warns[1L], 40))
  list(outcome = "ok", detail = det)
}

.xfcs_trunc <- function(s, n = 70L) {
  s <- gsub("\\s+", " ", paste(s, collapse = " "))
  if (nchar(s) > n) paste0(substr(s, 1L, n), "...") else s
}

## ---------------------------------------------------------------------
## 3. Regime definitions. Each returns a fitted model (or NULL) plus the
##    link_residual scale to probe. Tiny by construction: N = 12 units.
## ---------------------------------------------------------------------

.xfcs_regimes <- function() {
  list(
    ## -- K = 3 harness truths (exact target multiple_r via uniroot) ------
    list(id = "k3_interior_gauss", K = 3, N = 12, reps = 6, partner = "gaussian",
         link = "auto", note = "sanity: interior target_mr = 0.50",
         build = function(seed) {
           tr <- .xfc_build_truth(0.50, "gaussian")
           .xfc_fit(.xfc_simulate_data(tr, N = 12, reps = 6, seed = seed), "gaussian")
         }),
    list(id = "k3_boundary_hi_gauss", K = 3, N = 12, reps = 6, partner = "gaussian",
         link = "auto", note = "boundary target_mr = 0.98 (wald |r|->1; profile bracket)",
         build = function(seed) {
           tr <- .xfc_build_truth(0.98, "gaussian")
           .xfc_fit(.xfc_simulate_data(tr, N = 12, reps = 6, seed = seed), "gaussian")
         }),
    list(id = "k3_boundary_lo_gauss", K = 3, N = 12, reps = 6, partner = "gaussian",
         link = "auto", note = "boundary target_mr = 0.03 (near-zero r)",
         build = function(seed) {
           tr <- .xfc_build_truth(0.03, "gaussian")
           .xfc_fit(.xfc_simulate_data(tr, N = 12, reps = 6, seed = seed), "gaussian")
         }),
    list(id = "k3_binom_partner", K = 3, N = 12, reps = 8, partner = "binomial",
         link = "auto", note = "non-gaussian CERTIFIED partner (binomial), target 0.90",
         build = function(seed) {
           tr <- .xfc_build_truth(0.90, "binomial")
           .xfc_fit(.xfc_simulate_data(tr, N = 12, reps = 8, seed = seed), "binomial")
         }),
    ## -- large K = 5, rank-1 latent: singular contrast block Scc ---------
    list(id = "k5_lowrank_gauss_auto", K = 5, N = 12, reps = 8, partner = "gaussian",
         link = "auto", note = "K=5 rank-1 latent -> singular Scc, ginv fallback (find 1/2/5)",
         build = function(seed) {
           .xfcs_fit_K(.xfcs_simulate_K(5, N = 12, reps = 8, seed = seed,
                                        partner_family = "gaussian", s = 4, r = 1L),
                       "gaussian", d = 1L)
         }),
    ## -- same regime on the "none" (latent) scale: no diagonal floor -----
    list(id = "k5_lowrank_gauss_none", K = 5, N = 12, reps = 8, partner = "gaussian",
         link = "none", note = "K=5 rank-1, link='none' -> unfloored contrast_r (find 3)",
         build = function(seed) {
           .xfcs_fit_K(.xfcs_simulate_K(5, N = 12, reps = 8, seed = seed,
                                        partner_family = "gaussian", s = 4, r = 1L),
                       "gaussian", d = 1L)
         }),
    ## -- poisson partner: profile AUTO fence must fire (cert integrity) --
    list(id = "k3_poisson_partner_auto", K = 3, N = 12, reps = 8, partner = "poisson",
         link = "auto", note = "poisson partner: profile AUTO fence -> clean_error expected",
         build = function(seed) {
           .xfcs_fit_K(.xfcs_simulate_K(3, N = 12, reps = 8, seed = seed,
                                        partner_family = "poisson", s = 3, r = 1L),
                       "poisson", d = 1L)
         })
  )
}

## ---------------------------------------------------------------------
## 4. Driver.
## ---------------------------------------------------------------------

xfc_stress_test <- function(pkg = ".", seed = 20260718L, n_boot = 15L,
                            methods = c("wald", "bootstrap", "profile"),
                            verbose = TRUE) {
  .xfcs_setup(pkg)
  regimes <- .xfcs_regimes()
  rows <- list()
  for (rg in regimes) {
    if (verbose) cat(sprintf("[regime] %-24s %s\n", rg$id, rg$note))
    fit <- .xfcs_call(function() rg$build(seed))$val
    conv <- !inherits(fit, "xfcs_err") && .xfcs_converged(fit)
    ## point-estimate diagnostics (pinned multiple_r / absurd contrast_r)
    diag_pt <- ""
    if (conv) {
      pt <- .xfcs_call(function()
        suppressMessages(extract_cross_correlations(
          fit, level = "unit", contrasts = TRUE, link_residual = rg$link,
          method = "point")))
      cl <- .xfcs_classify(pt)
      diag_pt <- paste0("point:", cl$outcome)
    }
    for (m in methods) {
      if (!conv) {
        rows[[length(rows) + 1L]] <- data.frame(
          regime = rg$id, K = rg$K, N = rg$N, partner = rg$partner,
          link = rg$link, method = m, outcome = "crash",
          detail = "fit did not converge", stringsAsFactors = FALSE)
        next
      }
      res <- .xfcs_call(function()
        suppressMessages(extract_cross_correlations(
          fit, level = "unit", contrasts = TRUE, link_residual = rg$link,
          method = m, conf = 0.95, nsim = as.integer(n_boot), seed = seed)))
      cl <- .xfcs_classify(res)
      rows[[length(rows) + 1L]] <- data.frame(
        regime = rg$id, K = rg$K, N = rg$N, partner = rg$partner,
        link = rg$link, method = m, outcome = cl$outcome,
        detail = paste0(cl$detail, if (nzchar(diag_pt)) paste0(" [", diag_pt, "]") else ""),
        stringsAsFactors = FALSE)
    }
  }
  tab <- do.call(rbind, rows)
  attr(tab, "banner") <- XFC_STRESS_BANNER
  if (verbose) {
    cat("\n================ XFC STRESS TEST ================\n")
    cat(XFC_STRESS_BANNER, "\n\n")
    print(tab[c("regime", "method", "link", "outcome", "detail")], row.names = FALSE)
    cat("\noutcome legend: ok | crash | clean_error | NA_interval | ",
        "non_bracketing | absurd_width | absurd_point\n", sep = "")
  }
  invisible(tab)
}

## ---------------------------------------------------------------------
## 5. Run guard: `source()` defines only; set XFC_STRESS_MAIN=1 to run.
## ---------------------------------------------------------------------
if (identical(Sys.getenv("XFC_STRESS_MAIN"), "1")) {
  print(xfc_stress_test())
}
