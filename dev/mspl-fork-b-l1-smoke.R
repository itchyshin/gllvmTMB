#!/usr/bin/env Rscript
## Dual-arm L1 local probe — Design 125 fork B vs fork A ablation.
##
## Rescued from the orphan clone
## `~/local-scratch/lanes/gllvmTMB-g0-unlock-20260818` (tip a6bb6916,
## not an ancestor of #1130).  Companion to, not a replacement for,
## `dev/mspl-forkB-l1-ademp.R` / `dev/mspl-forkB-l1-smoke.R` (the
## tape= ADEMP harness and the 50-rep T=8 receipt on #1128).
##
## This runner walks BOTH arms through `objective=`:
##   unpenalized = fork B (SIGNED construction; needs #1130 on the
##                 loaded package)
##   penalised   = fork A (pre-registered ablation)
##
## Hard OUT: no Totoro, no public se / vcov / confint, no undraft of
## #1077, no NEWS covered, no MSPL-04 flip.  calibrated = FALSE and
## coverage_claim = "none" stay on the probe.  n_rep < 50 is not an
## L1 gate (ADEMP L1 band is 50–100).
##
## Usage:
##   Rscript --vanilla dev/mspl-fork-b-l1-smoke.R
##   L1_N_REP=1 Rscript --vanilla dev/mspl-fork-b-l1-smoke.R
##   Rscript --vanilla -e 'source("dev/mspl-fork-b-l1-smoke.R", local = TRUE)'
##     (helpers only; the loop does not run when sourced)

N_REP     <- as.integer(Sys.getenv("L1_N_REP", "100"))
N_SITE    <- as.integer(Sys.getenv("L1_N_SITE", "80"))
N_TRAIT   <- as.integer(Sys.getenv("L1_N_TRAIT", "4"))
SEED_BASE <- as.integer(Sys.getenv("L1_SEED_BASE", "20260818"))
OUT_DIR   <- Sys.getenv("L1_OUT_DIR", "dev/mspl-fork-b-l1-results")

## Anchor cell truths: well-identified interior, prevalence near 0.5 on every
## trait, target intercept non-zero so coverage is not trivially satisfied by
## any interval that straddles the origin.
BETA0  <- c(-0.25, 0.25, -0.10, 0.10)[seq_len(N_TRAIT)]
LAMBDA <- rep(0.8, N_TRAIT)
TARGET <- 1L  # E1 on trait 1; b_fix coordinate 1

mspl_fork_b_l1_objective_ready <- function() {
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) return(FALSE)
  ns <- asNamespace("gllvmTMB")
  if (!exists(".gllvmTMB_mspl_profile_feasibility",
              where = ns, inherits = FALSE)) {
    return(FALSE)
  }
  fn <- get(".gllvmTMB_mspl_profile_feasibility", envir = ns)
  "objective" %in% names(formals(fn))
}

simulate_cell <- function(seed) {
  set.seed(seed)
  dat <- expand.grid(
    site  = factor(seq_len(N_SITE)),
    trait = factor(paste0("sp", seq_len(N_TRAIT)))
  )
  z <- stats::rnorm(N_SITE)
  eta <- BETA0[as.integer(dat$trait)] +
    LAMBDA[as.integer(dat$trait)] * z[as.integer(dat$site)]
  dat$y <- stats::rbinom(nrow(dat), 1L, stats::plogis(eta))
  dat
}

## R-SAT (pre-fit): a response column with no variation is separated; the
## pre-registration refuses the coordinate and forbids any fallback arm.
r_sat <- function(dat) {
  any(vapply(
    split(dat$y, dat$trait),
    function(col) length(unique(col)) < 2L,
    logical(1L)
  ))
}

fit_cell <- function(dat) {
  tryCatch(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = stats::binomial(link = "logit"),
      estimator = "mspl",
      control = gllvmTMBcontrol(
        n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
      )
    ),
    error = identity
  )
}

run_arm <- function(fit, arm) {
  probe <- tryCatch(
    gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
      fit, which = TARGET, step = 0.5, max_steps = 8L, level = 0.95,
      refinement_steps = 20L, objective = arm
    ),
    error = identity
  )
  if (inherits(probe, "error")) {
    return(list(
      status = "R-NAVL", reason = paste0("probe_error: ", conditionMessage(probe)),
      lower = NA_real_, upper = NA_real_, estimate = NA_real_
    ))
  }
  two_sided <- identical(probe$lower_status, "crossed") &&
    identical(probe$upper_status, "crossed") &&
    is.finite(probe$lower_endpoint) && is.finite(probe$upper_endpoint)
  if (!identical(probe$centre_status, "matched")) {
    return(list(status = "R-NAVL", reason = paste0("centre_", probe$centre_status),
                lower = NA_real_, upper = NA_real_, estimate = probe$mle))
  }
  if (!two_sided) {
    return(list(
      status = "R-NAVL",
      reason = paste0("lower_", probe$lower_status, "|upper_", probe$upper_status),
      lower = NA_real_, upper = NA_real_, estimate = probe$mle
    ))
  }
  list(status = "returned", reason = "", lower = probe$lower_endpoint,
       upper = probe$upper_endpoint, estimate = probe$mle)
}

## Wilson score interval -- the pre-registration's named uncertainty band.
wilson <- function(x, n, conf = 0.95) {
  if (n == 0L) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- x / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(max(0, centre - half), min(1, centre + half))
}

summarise_arm <- function(d) {
  n_total   <- nrow(d)
  n_sat     <- sum(d$status == "R-SAT")
  n_ret     <- sum(d$status == "returned")
  n_refused <- n_total - n_ret
  n_cov     <- sum(d$covered %in% TRUE)

  cov_ret <- if (n_ret > 0L) n_cov / n_ret else NA_real_
  r_hat   <- n_refused / n_total
  ## Effective coverage prices a refusal as non-coverage (pre-reg SIGNED
  ## default, fail-closed).  Its Wilson band is therefore the band on
  ## n_cov successes out of n_total, not out of n_ret.
  cov_eff <- n_cov / n_total
  w_ret <- wilson(n_cov, n_ret)
  w_eff <- wilson(n_cov, n_total)

  ## Availability (P2): two-sided bracket among non-R-SAT replicates.
  n_elig <- n_total - n_sat
  avail  <- if (n_elig > 0L) n_ret / n_elig else NA_real_
  w_avail <- wilson(n_ret, n_elig)

  widths <- d$upper[d$status == "returned"] - d$lower[d$status == "returned"]

  data.frame(
    arm = d$arm[1L], n_total = n_total, n_returned = n_ret,
    n_refused = n_refused, n_sat = n_sat, n_covered = n_cov,
    cov_ret = cov_ret, cov_ret_lo = w_ret[1L], cov_ret_hi = w_ret[2L],
    refusal = r_hat,
    cov_eff = cov_eff, cov_eff_lo = w_eff[1L], cov_eff_hi = w_eff[2L],
    availability = avail, avail_lo = w_avail[1L], avail_hi = w_avail[2L],
    median_width = if (length(widths)) stats::median(widths) else NA_real_,
    stringsAsFactors = FALSE
  )
}

l1_gate <- function(s) {
  c(
    cov_eff_band = !isTRUE(s$cov_eff_hi < 0.80),
    availability = isTRUE(s$availability >= 0.90),
    refusal      = isTRUE(s$refusal <= 0.15)
  )
}

## n_rep below the ADEMP L1 band cannot produce a gate verdict.
l1_band_ready <- function(n_rep) {
  n_rep <- as.integer(n_rep)
  !is.na(n_rep) && n_rep >= 50L && n_rep <= 100L
}

run_dual_arm_probe <- function() {
  if (!mspl_fork_b_l1_objective_ready()) {
    stop(
      "blocked-on-L0: loaded .gllvmTMB_mspl_profile_feasibility() has no ",
      "objective= argument.  This dual-arm runner needs PR #1130 ",
      "(or --pkg load_all of that worktree).  It will not walk fork A ",
      "as a silent substitute.  The tape= ADEMP harness is ",
      "dev/mspl-forkB-l1-ademp.R.",
      call. = FALSE
    )
  }

  dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

  rows <- list()
  t0 <- Sys.time()
  for (i in seq_len(N_REP)) {
    seed <- SEED_BASE + i
    dat <- simulate_cell(seed)

    if (r_sat(dat)) {
      for (arm in c("unpenalized", "penalised")) {
        rows[[length(rows) + 1L]] <- data.frame(
          rep = i, seed = seed, arm = arm, status = "R-SAT",
          reason = "response_column_no_variation", estimate = NA_real_,
          lower = NA_real_, upper = NA_real_, covered = NA,
          stringsAsFactors = FALSE
        )
      }
      next
    }

    fit <- fit_cell(dat)
    if (inherits(fit, "error")) {
      for (arm in c("unpenalized", "penalised")) {
        rows[[length(rows) + 1L]] <- data.frame(
          rep = i, seed = seed, arm = arm, status = "R-FIT",
          reason = conditionMessage(fit), estimate = NA_real_,
          lower = NA_real_, upper = NA_real_, covered = NA,
          stringsAsFactors = FALSE
        )
      }
      next
    }

    for (arm in c("unpenalized", "penalised")) {
      res <- run_arm(fit, arm)
      covered <- if (identical(res$status, "returned")) {
        BETA0[TARGET] >= res$lower && BETA0[TARGET] <= res$upper
      } else {
        NA
      }
      rows[[length(rows) + 1L]] <- data.frame(
        rep = i, seed = seed, arm = arm, status = res$status,
        reason = res$reason, estimate = res$estimate,
        lower = res$lower, upper = res$upper, covered = covered,
        stringsAsFactors = FALSE
      )
    }

    if (i %% 10L == 0L) {
      cat(sprintf("  ... rep %d/%d  (%.1f min elapsed)\n", i, N_REP,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
      utils::flush.console()
    }
  }

  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(OUT_DIR, "l1-anchor-raw.csv"), row.names = FALSE)

  summary_tbl <- do.call(rbind, lapply(split(res, res$arm), summarise_arm))
  utils::write.csv(summary_tbl, file.path(OUT_DIR, "l1-anchor-summary.csv"),
                   row.names = FALSE)

  cat("\n================ L1 ANCHOR CELL ================\n")
  cat(sprintf("DGP: n_site=%d  T=%d  q=1  logit  latent(unique=FALSE)\n",
              N_SITE, N_TRAIT))
  cat(sprintf("Truth beta_0 = [%s];  Lambda = %.2f;  target E1 = beta_0[%d] = %.2f\n",
              paste(BETA0, collapse = ", "), LAMBDA[1L], TARGET, BETA0[TARGET]))
  cat(sprintf("n_rep = %d;  seeds %d..%d\n", N_REP, SEED_BASE + 1L,
              SEED_BASE + N_REP))
  if (!l1_band_ready(N_REP)) {
    cat(sprintf(
      "L1 BAND: n_rep=%d is outside 50-100.  Numbers below are a probe, not a gate.\n\n",
      N_REP
    ))
  } else {
    cat("\n")
  }

  for (a in rownames(summary_tbl)) {
    s <- summary_tbl[a, ]
    g <- l1_gate(s)
    cat(sprintf("--- arm: %s  (fork %s)\n", s$arm,
                if (s$arm == "unpenalized") "B -- SIGNED construction"
                else "A -- ablation"))
    cat(sprintf("  returned / refused / R-SAT : %d / %d / %d  of %d\n",
                s$n_returned, s$n_refused, s$n_sat, s$n_total))
    cat(sprintf("  conditional coverage       : %.3f  Wilson [%.3f, %.3f]\n",
                s$cov_ret, s$cov_ret_lo, s$cov_ret_hi))
    cat(sprintf("  refusal rate               : %.3f\n", s$refusal))
    cat(sprintf("  EFFECTIVE coverage (priced): %.3f  Wilson [%.3f, %.3f]\n",
                s$cov_eff, s$cov_eff_lo, s$cov_eff_hi))
    cat(sprintf("  availability (P2)          : %.3f  Wilson [%.3f, %.3f]\n",
                s$availability, s$avail_lo, s$avail_hi))
    cat(sprintf("  median interval width      : %.4f\n", s$median_width))
    if (l1_band_ready(N_REP)) {
      cat(sprintf("  GATE cov_eff band >= 0.80  : %s\n", ifelse(g[["cov_eff_band"]], "PASS", "FAIL")))
      cat(sprintf("  GATE availability >= 0.90  : %s\n", ifelse(g[["availability"]], "PASS", "FAIL")))
      cat(sprintf("  GATE refusal <= 0.15       : %s\n", ifelse(g[["refusal"]], "PASS", "FAIL")))
      cat(sprintf("  L1 VERDICT                 : %s\n\n",
                  ifelse(all(g), "PASS", "FAIL")))
    } else {
      cat("  L1 VERDICT                 : INCOMPLETE (n_rep outside 50-100)\n\n")
    }
  }

  if (any(res$status != "returned")) {
    cat("Refusal reasons observed:\n")
    print(table(res$arm, res$status))
    bad <- res[res$status != "returned" & nzchar(res$reason), c("arm", "reason")]
    if (nrow(bad)) print(utils::head(sort(table(bad$reason), decreasing = TRUE), 10L))
  }

  cat(sprintf("\nElapsed: %.1f min\n",
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  cat("Raw:     ", file.path(OUT_DIR, "l1-anchor-raw.csv"), "\n")
  cat("Summary: ", file.path(OUT_DIR, "l1-anchor-summary.csv"), "\n")
  cat("calibrated: FALSE\n")
  cat("public_confint: refused\n")
  cat("coverage_claim: none\n")
  invisible(list(raw = res, summary = summary_tbl))
}

if (!sys.nframe()) {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
  run_dual_arm_probe()
}
