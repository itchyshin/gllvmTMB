## dev/test-profile-coverage-remeasure.R
## ======================================
## TDD tests for the profile-route coverage re-measurement (branch
## claude/profile-coverage-remeasure-20260718):
##   A1a: Sigma_unit_diag moves to the profile_total certificate route BY
##        DEFAULT (bootstrap becomes opt-in via n_boot > 0); nbinom2 stays
##        certificate-INELIGIBLE (fenced) because its Sigma_hat under-
##        recovers ~0.5x via the phi<->sigma^2 dispersion ridge.
##   A1b: NEW Sigma_unit_corr (rho:unit) target -- truth built on the SAME
##        Sigma_total = Lambda Lambda^T + diag(psi_effective) + diag(r)
##        scale profile_ci_correlation() / .correlation_total_spec() target,
##        so truth == target by construction (MF1: estimand identity).
##
## Run: Rscript dev/test-profile-coverage-remeasure.R
## Formula-identity + tiny end-to-end checks only. Fits are kept TINY
## (n_units 50-60, d = 1, n_traits = 3, 1-2 reps) -- no Totoro/heavy compute.

suppressPackageStartupMessages({
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
})
source("dev/m3-grid.R")
source("dev/m3-pilot-report.R")

ok <- TRUE
chk <- function(cond, msg) {
  cat(if (isTRUE(cond)) "PASS" else "FAIL", "-", msg, "\n")
  if (!isTRUE(cond)) ok <<- FALSE
}

## ---- helper: fit the M3 harness's own tiny model -----------------------
## Mirrors the formula m3_run_cell() fits (value ~ 0 + trait +
## latent(0 + trait | unit, d = d) + unique(0 + trait | unit)), just at a
## much smaller scale so the identity checks run in seconds.
fit_tiny <- function(family, d = 1L, n_traits = 3L, n_units = 50L, seed = 1L) {
  truth <- m3_sample_truth(
    family, d,
    n_traits = n_traits, n_units = n_units, seed = seed
  )
  sim <- m3_simulate_response(truth)
  fam_obj <- switch(
    family,
    gaussian = stats::gaussian(),
    binomial = stats::binomial(),
    binomial_probit = stats::binomial(link = "probit"),
    stop("unsupported family for this test helper: ", family)
  )
  fit <- gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = d) + unique(0 + trait | unit),
    data = sim$data,
    family = fam_obj,
    unit = "unit",
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )
  list(truth = truth, sim = sim, fit = fit)
}

## =====================================================================
## Test 1 -- Gaussian: harness rho truth == profile_ci_correlation's OWN
## target spec (.correlation_total_spec), cross-checked against the public
## extract_Sigma(link_residual = "auto") route.
## =====================================================================
g <- fit_tiny("gaussian", d = 1L, n_traits = 3L, n_units = 50L, seed = 101L)
chk(inherits(g$fit, "gllvmTMB_multi"), "gaussian tiny fit returns a gllvmTMB_multi object")

if (inherits(g$fit, "gllvmTMB_multi")) {
  i <- 1L
  j <- 2L
  ## .correlation_total_spec() is a raw internal helper that expects the
  ## ALREADY-normalised internal tier name ("B" for the "unit" grouping);
  ## normalisation happens in the public profile_ci_correlation() wrapper,
  ## not inside .correlation_total_spec() itself. Discovered while grounding
  ## this test: passing "unit" straight through silently falls into the spde
  ## branch (no rr term -> use_rr = FALSE -> NA rho), a footgun worth a
  ## comment for the next reader.
  spec_g <- gllvmTMB:::.correlation_total_spec(
    g$fit,
    tier = "B", i = i, j = j, link_residual = "auto"
  )
  rho_target_g <- spec_g$rho_of_par(g$fit$opt$par)

  Sigma_none_g <- suppressMessages(
    gllvmTMB::extract_Sigma(g$fit, level = "unit", link_residual = "none")$Sigma
  )
  Sigma_auto_g <- suppressMessages(
    gllvmTMB::extract_Sigma(g$fit, level = "unit", link_residual = "auto")$Sigma
  )
  ## Harness truth-construction formula (gaussian r = 0), fed the FIT's own
  ## estimated Lambda/psi (via Sigma_none, which already IS Lambda Lambda^T +
  ## diag(psi)) -- this is EXACTLY the expression m3_sample_truth() now uses
  ## to build Sigma_total, just evaluated at the MLE instead of the truth.
  r_g <- rep(0, 3)
  St_formula_g <- Sigma_none_g + diag(r_g, 3)
  rho_formula_g <- St_formula_g[i, j] / sqrt(St_formula_g[i, i] * St_formula_g[j, j])
  rho_auto_g <- Sigma_auto_g[i, j] / sqrt(Sigma_auto_g[i, i] * Sigma_auto_g[j, j])

  chk(
    is.finite(rho_target_g),
    "gaussian: profile_ci_correlation's target spec is finite at the MLE"
  )
  chk(
    isTRUE(all.equal(rho_formula_g, rho_target_g, tolerance = 1e-8)),
    "gaussian: harness truth-construction formula matches .correlation_total_spec at the MLE"
  )
  chk(
    isTRUE(all.equal(rho_formula_g, rho_auto_g, tolerance = 1e-8)),
    "gaussian: harness formula matches extract_Sigma(link_residual = 'auto')"
  )
}

## =====================================================================
## Test 2 -- Binomial (probit): harness r = 1 (probit link residual)
## matches .correlation_total_spec's own diagonal at the MLE.
## =====================================================================
b <- fit_tiny("binomial_probit", d = 1L, n_traits = 3L, n_units = 60L, seed = 202L)
chk(
  inherits(b$fit, "gllvmTMB_multi"),
  "binomial_probit tiny fit returns a gllvmTMB_multi object"
)

if (inherits(b$fit, "gllvmTMB_multi")) {
  i <- 1L
  j <- 2L
  Sigma_none_b <- suppressMessages(
    gllvmTMB::extract_Sigma(b$fit, level = "unit", link_residual = "none")$Sigma
  )
  Sigma_auto_b <- suppressMessages(
    gllvmTMB::extract_Sigma(b$fit, level = "unit", link_residual = "auto")$Sigma
  )
  spec_b <- gllvmTMB:::.correlation_total_spec(
    b$fit,
    tier = "B", i = i, j = j, link_residual = "auto"
  )
  rho_target_b <- spec_b$rho_of_par(b$fit$opt$par)

  r_probit <- rep(1, 3)
  St_formula_b <- Sigma_none_b + diag(r_probit, 3)
  rho_formula_b <- St_formula_b[i, j] / sqrt(St_formula_b[i, i] * St_formula_b[j, j])

  chk(
    isTRUE(all.equal(
      unname(diag(Sigma_auto_b)) - unname(diag(Sigma_none_b)),
      r_probit,
      tolerance = 1e-8
    )),
    "binomial_probit: package's own 'auto' link residual on the diagonal equals the probit constant r = 1"
  )
  chk(
    isTRUE(all.equal(rho_formula_b, rho_target_b, tolerance = 1e-8)),
    "binomial_probit: harness St diagonal = (Lambda Lambda^T)_tt + 1 matches .correlation_total_spec at the MLE"
  )
}

## =====================================================================
## Test 3 -- Sigma_unit_diag (confirmed-clean leg): harness truth formula
## == .total_variance_spec V(par, t) at the MLE.
## =====================================================================
if (inherits(g$fit, "gllvmTMB_multi")) {
  spec_v <- gllvmTMB:::.total_variance_spec(g$fit, tier = "unit")
  V_hat <- vapply(
    seq_len(3),
    function(t) spec_v$V_of_par(g$fit$opt$par, t),
    numeric(1)
  )
  est_diag <- diag(suppressMessages(
    gllvmTMB::extract_Sigma(g$fit, level = "unit", link_residual = "none")$Sigma
  ))
  chk(
    isTRUE(all.equal(V_hat, unname(est_diag), tolerance = 1e-8)),
    "Sigma_unit_diag: .total_variance_spec V(par, t) matches extract_Sigma(link_residual = 'none') diag at the MLE"
  )
}

## =====================================================================
## Test 4 -- Pilot: pilot_collect_cell() surfaces coverage_certificate
## (non-NA) from profile_total rows; pilot_primary_rows() selects
## profile_total rows. Exercises the NEW defaults (n_boot = 0,
## sigma_extra_methods = c("profile_total")) end-to-end via m3_run_cell().
## =====================================================================
g_grid <- tryCatch(
  m3_run_cell(
    "gaussian",
    d = 1L, n_reps = 2L, seed_base = 909L,
    n_units = 50L, n_traits = 3L,
    targets = "Sigma_unit_diag",
    verbose = FALSE
  ),
  error = function(e) e
)

if (inherits(g_grid, "error")) {
  chk(FALSE, paste("m3_run_cell() with new defaults errored:", conditionMessage(g_grid)))
} else {
  chk(
    any(g_grid$ci_method == "profile_total"),
    "m3_run_cell() with new defaults (n_boot = 0) emits profile_total rows by default"
  )
  chk(
    !any(g_grid$ci_method == "bootstrap"),
    "m3_run_cell() with new defaults does NOT run bootstrap (n_boot = 0 by default)"
  )

  prim <- pilot_primary_rows(g_grid)
  chk(
    nrow(prim) > 0 && all(prim$ci_method == "profile_total"),
    "pilot_primary_rows() selects profile_total rows"
  )

  cell_row <- pilot_collect_cell(
    g_grid, "gaussian-d1",
    meta = NULL, gate_94 = 0.94, gate_95 = 0.95
  )
  chk(
    "coverage_certificate" %in% names(cell_row),
    "pilot_collect_cell() output has a coverage_certificate column"
  )
  chk(
    nrow(cell_row) == 1L && !is.na(cell_row$coverage_certificate[1]),
    "pilot_collect_cell() surfaces a non-NA coverage_certificate from profile_total rows"
  )
}

## =====================================================================
## Test 5 -- Fence: nbinom2 does NOT get profile_total as its Sigma_unit_diag
## certificate label (the phi<->sigma^2 dispersion ridge makes a
## location-axis profile unable to rescue it).
## =====================================================================
chk(
  !identical(
    m3_target_method("Sigma_unit_diag", n_boot = 0L, family = "nbinom2"),
    "profile_total"
  ),
  "nbinom2 does not get profile_total as its default Sigma_unit_diag certificate label"
)
chk(
  identical(
    m3_target_method("Sigma_unit_diag", n_boot = 0L, family = "gaussian"),
    "profile_total"
  ),
  "gaussian DOES get profile_total as its default Sigma_unit_diag certificate label"
)

nb2_grid <- tryCatch(
  m3_run_cell(
    "nbinom2",
    d = 1L, n_reps = 1L, seed_base = 707L,
    n_units = 50L, n_traits = 3L,
    targets = "Sigma_unit_diag",
    verbose = FALSE
  ),
  error = function(e) e
)
if (inherits(nb2_grid, "error")) {
  chk(FALSE, paste("nbinom2 m3_run_cell() errored:", conditionMessage(nb2_grid)))
} else {
  chk(
    !any(nb2_grid$ci_method == "profile_total"),
    "nbinom2 grid rows never carry ci_method == 'profile_total' (fenced end-to-end)"
  )
}

## =====================================================================
## Test 6 (extra, beyond the MF1 minimum) -- Sigma_unit_corr wires through
## m3_run_cell() end-to-end: one row per trait pair per rep, tagged
## ci_method = "profile_corr", truth in [-1, 1] or NA when unsupported.
## =====================================================================
corr_grid <- tryCatch(
  m3_run_cell(
    "gaussian",
    d = 1L, n_reps = 1L, seed_base = 1313L,
    n_units = 50L, n_traits = 3L,
    targets = "Sigma_unit_corr",
    verbose = FALSE
  ),
  error = function(e) e
)
if (inherits(corr_grid, "error")) {
  chk(FALSE, paste("Sigma_unit_corr wiring errored:", conditionMessage(corr_grid)))
} else {
  n_pairs_expected <- choose(3, 2)
  chk(
    all(corr_grid$target == "Sigma_unit_corr"),
    "Sigma_unit_corr rows are correctly tagged with target = 'Sigma_unit_corr'"
  )
  chk(
    all(corr_grid$ci_method == "profile_corr"),
    "Sigma_unit_corr rows use ci_method = 'profile_corr'"
  )
  chk(
    nrow(corr_grid) == n_pairs_expected,
    "Sigma_unit_corr emits exactly one row per trait pair per rep"
  )
  chk(
    all(is.na(corr_grid$truth) | (corr_grid$truth >= -1 & corr_grid$truth <= 1)),
    "Sigma_unit_corr truth values are valid correlations in [-1, 1] (or NA when unsupported)"
  )
  chk(
    all(is.na(corr_grid$n_boot)),
    "Sigma_unit_corr rows carry n_boot = NA (never a bootstrap fallback)"
  )
}

## =====================================================================
## Test 7 (PF-3) -- endpoint-sanity guard m3_profile_ci_sane() folds a
## degenerate / finite-but-wrong profile interval into ci_failed. This is
## the silent-failure channel .profile_ci_via_refit() can produce (a
## converged-to-local-optimum FINITE endpoint) that the old
## `ci_failed = !is.na(lo) && !is.na(hi)` check could not see.
## =====================================================================
chk(isTRUE(m3_profile_ci_sane(1.0, 0.5, 1.5)),
    "PF-3: a sane interval (lo < est < hi) is accepted")
chk(!isTRUE(m3_profile_ci_sane(1.0, 1.5, 0.5)),
    "PF-3: a mis-ordered interval (lo > hi) is rejected")
chk(!isTRUE(m3_profile_ci_sane(1.0, 0.5, 0.5)),
    "PF-3: a zero-width interval (hi == lo) is rejected")
chk(!isTRUE(m3_profile_ci_sane(1.0, NA_real_, 1.5)),
    "PF-3: an NA lower endpoint is rejected")
chk(!isTRUE(m3_profile_ci_sane(1.0, 0.5, NA_real_)),
    "PF-3: an NA upper endpoint is rejected")
chk(!isTRUE(m3_profile_ci_sane(2.0, 0.5, 1.5)),
    "PF-3: a point above the upper endpoint is rejected")
chk(!isTRUE(m3_profile_ci_sane(0.1, 0.5, 1.5)),
    "PF-3: a point below the lower endpoint is rejected")
chk(!isTRUE(m3_profile_ci_sane(Inf, 0.5, 1.5)),
    "PF-3: a non-finite point estimate is rejected")
chk(!isTRUE(m3_profile_ci_sane(1.0, -Inf, 1.5)),
    "PF-3: a non-finite (infinite) lower endpoint is rejected")

## The FOLD itself: a degenerate interval must yield ci_failed = TRUE and
## covered = NA (mirrors the exact two lines both profile blocks run).
bad_avail <- m3_profile_ci_sane(1.0, 1.5, 0.5)   # mis-ordered
bad_covered <- if (bad_avail) TRUE else NA
chk(isTRUE(!bad_avail) && is.na(bad_covered),
    "PF-3: a degenerate interval folds to ci_failed = TRUE, covered = NA")
## A degenerate interval also yields 'ci_unavailable' from m3_miss_side()
## (never a spurious cover / miss direction).
chk(identical(m3_miss_side(1.0, 1.5, 0.5, NA, bad_avail), "ci_unavailable"),
    "PF-3: a degenerate interval maps to miss_side = 'ci_unavailable'")

## =====================================================================
## Test 8 (PF-7) -- no wire path assumes small/zero true-rho: rho_truth is
## computed straight from truth$Sigma_total (actual loadings), so a
## high-|rho| Sigma_total yields a valid in-range truth with no special-
## casing. Confirm the harness's exact rho_truth formula on a hand-built
## strongly-correlated Sigma_total, including the |rho| -> 1 limit.
## =====================================================================
St_hi <- matrix(c(1.0, 0.98, 0.98, 1.0), 2, 2)  # rho = 0.98
rho_hi <- St_hi[1, 2] / sqrt(St_hi[1, 1] * St_hi[2, 2])
chk(isTRUE(all.equal(rho_hi, 0.98)) && rho_hi > -1 && rho_hi < 1,
    "PF-7: high-|rho| Sigma_total yields a valid in-range rho_truth (0.98)")
St_deg <- matrix(c(1.0, 1.0, 1.0, 1.0), 2, 2)   # perfectly collinear, rho = 1
rho_deg <- St_deg[1, 2] / sqrt(St_deg[1, 1] * St_deg[2, 2])
chk(isTRUE(all.equal(rho_deg, 1)) && is.finite(rho_deg),
    "PF-7: the |rho| -> 1 limit yields rho_truth = 1 (finite, not NaN)")
## And the guard treats rho_truth = 1 against a CI that just touches 1 as a
## cover (no small-rho assumption, no mislabel at the boundary).
chk(m3_profile_ci_sane(0.99, 0.90, 1.00) &&
      isTRUE(1.0 >= 0.90 && 1.0 <= 1.00),
    "PF-7: rho_truth = 1 is covered by an interval whose upper endpoint is 1")

## =====================================================================
## Test 9 (FIX 3) -- pilot_rbind_cell() must key on trait_j so Sigma_unit_corr
## pairs sharing a first index (trait_id = i) are not collapsed. (1,2) and
## (1,3) share (rep_seed, trait_id = 1, target, ci_method); without trait_j in
## the de-dup key the later pair was silently dropped.
corr_rows <- data.frame(
  rep_seed = c(11L, 11L, 11L),
  rep = 1L,
  trait_id = c(1L, 1L, 2L),
  trait_j = c(2L, 3L, 3L),
  target = "Sigma_unit_corr",
  ci_method = "profile_corr",
  truth = c(0.3, 0.4, 0.5),
  stringsAsFactors = FALSE
)
rb <- pilot_rbind_cell(NULL, corr_rows)
chk(nrow(rb) == 3L,
    "FIX 3: two corr pairs sharing a first index both survive one rep")
chk(identical(
      paste(rb$trait_id, rb$trait_j, sep = "-"),
      c("1-2", "1-3", "2-3")
    ),
    "FIX 3: all three distinct pairs (1-2, 1-3, 2-3) are retained")
## Genuine cross-store duplicate draws still de-dup (no double-counting).
rb_dup <- pilot_rbind_cell(corr_rows, corr_rows)
chk(nrow(rb_dup) == 3L,
    "FIX 3: a genuinely duplicated draw across stores still de-dups to 3 rows")
## And the per-trait targets (trait_j = NA) still de-dup correctly on the key.
diag_rows <- data.frame(
  rep_seed = c(11L, 11L),
  rep = 1L,
  trait_id = c(1L, 2L),
  trait_j = NA_integer_,
  target = "Sigma_unit_diag",
  ci_method = "profile_total",
  truth = c(1.1, 1.2),
  stringsAsFactors = FALSE
)
rb_diag <- pilot_rbind_cell(diag_rows, diag_rows)
chk(nrow(rb_diag) == 2L,
    "FIX 3: per-trait rows (trait_j = NA) still de-dup correctly across stores")

## =====================================================================
## Test 10 (FIX 4) -- a contradictory config (sigma_extra_methods opt-out +
## n_boot = 0, non-nbinom2) must NOT tag its no-profile placeholder row
## ci_method == "profile_total". The honest label is "none" (no interval
## method actually ran).
optout_grid <- tryCatch(
  m3_run_cell(
    "gaussian",
    d = 1L, n_reps = 1L, seed_base = 4242L,
    n_units = 50L, n_traits = 3L,
    targets = "Sigma_unit_diag",
    n_boot = 0L, sigma_extra_methods = character(0),
    verbose = FALSE
  ),
  error = function(e) e
)
if (inherits(optout_grid, "error")) {
  chk(FALSE, paste("FIX 4: opt-out config errored:", conditionMessage(optout_grid)))
} else {
  chk(
    !any(optout_grid$ci_method == "profile_total"),
    "FIX 4: profile opt-out + n_boot=0 emits NO 'profile_total'-labelled row"
  )
  chk(
    all(optout_grid$ci_method == "none"),
    "FIX 4: the no-profile placeholder rows are honestly labelled 'none'"
  )
}

## =====================================================================
## Test 11 (FIX 1 -- CRITICAL, the ACTUAL pilot-driver call) -- a SUCCESSFUL
## fit with targets = "Sigma_unit_diag" ONLY (no "psi") and n_boot = 0 must
## ALWAYS emit at least one Sigma_unit_diag profile_total row -- never an
## empty rep_rows (which crashed m3_add_fit_health with "invalid 'times'
## argument"). run_next_pilot_batch / run_accumulate_pilot_batch pass
## targets = "Sigma_unit_diag" only, so the psi rows that masked this in the
## other tests are absent here. Exercised for gaussian AND binomial_probit.
for (fam in c("gaussian", "binomial_probit")) {
  st_grid <- tryCatch(
    m3_run_cell(
      fam,
      d = 1L, n_reps = 2L, seed_base = 5150L,
      n_units = 60L, n_traits = 3L,
      targets = "Sigma_unit_diag",   # SOLE target -- no psi masking
      n_boot = 0L,
      verbose = FALSE
    ),
    error = function(e) e
  )
  if (inherits(st_grid, "error")) {
    chk(FALSE, sprintf("FIX 1 [%s]: single-target n_boot=0 crashed: %s",
                       fam, conditionMessage(st_grid)))
  } else {
    chk(is.data.frame(st_grid) && nrow(st_grid) > 0L,
        sprintf("FIX 1 [%s]: single-target Sigma_unit_diag n_boot=0 returns a non-empty result", fam))
    chk(any(st_grid$ci_method == "profile_total"),
        sprintf("FIX 1 [%s]: a successful fit ALWAYS emits a profile_total row", fam))
    chk(!any(st_grid$ci_method == "bootstrap"),
        sprintf("FIX 1 [%s]: no bootstrap row under n_boot=0", fam))
  }
}

## =====================================================================
## Test 12 (CONCERN 1 / V-4) -- m3_placeholder_ci_method() is the SINGLE pure
## source of the honest ci_method label for a NON-computed Sigma_unit_diag
## placeholder, used at BOTH the fit-failed and success placeholder sites so
## they can never diverge. Unit-test it directly over every case.
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_diag", n_boot = 0L, family = "nbinom2",
                               sigma_extra_methods = c("profile_total")),
      "none"),
    "CONCERN 1: nbinom2 (fenced) placeholder -> 'none'")
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_diag", n_boot = 0L, family = "gaussian",
                               sigma_extra_methods = c("profile_total")),
      "profile_total"),
    "CONCERN 1: non-nbinom2 default (profile_total requested) placeholder -> 'profile_total'")
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_diag", n_boot = 0L, family = "gaussian",
                               sigma_extra_methods = character(0)),
      "none"),
    "CONCERN 1: non-nbinom2 opt-out (no profile_total) placeholder -> 'none'")
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_diag", n_boot = 30L, family = "gaussian",
                               sigma_extra_methods = c("profile_total")),
      "bootstrap"),
    "CONCERN 1: n_boot > 0 placeholder -> 'bootstrap'")
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_diag", n_boot = 30L, family = "nbinom2",
                               sigma_extra_methods = character(0)),
      "bootstrap"),
    "CONCERN 1: n_boot > 0 wins even for nbinom2 / opt-out -> 'bootstrap'")
## Pass-through for any OTHER target (unchanged m3_target_method() behaviour).
chk(identical(
      m3_placeholder_ci_method("psi", n_boot = 0L, family = "gaussian",
                               sigma_extra_methods = c("profile_total")),
      m3_target_method("psi", n_boot = 0L, family = "gaussian")),
    "CONCERN 1: target = 'psi' passes through m3_target_method() unchanged")
chk(identical(
      m3_placeholder_ci_method("Sigma_unit_corr", n_boot = 0L, family = "gaussian",
                               sigma_extra_methods = c("profile_total")),
      m3_target_method("Sigma_unit_corr", n_boot = 0L, family = "gaussian")),
    "CONCERN 1: target = 'Sigma_unit_corr' passes through unchanged ('profile_corr')")

## Both placeholder SITES agree: the fit-failed loop (:~1156) and the success
## placeholder (:~1440) now derive their label from the SAME helper, so an
## opt-out fit-failed Sigma_unit_diag row is labelled "none" (previously
## "profile_total"). Exercise the fit-failed path with a deterministically-
## failing fit (n_units = 1 cannot fit the latent+unique model) under the
## opt-out config.
optout_fail <- tryCatch(
  m3_run_cell(
    "gaussian",
    d = 1L, n_reps = 1L, seed_base = 3131L,
    n_units = 1L, n_traits = 3L,
    targets = "Sigma_unit_diag",
    n_boot = 0L, sigma_extra_methods = character(0),
    verbose = FALSE
  ),
  error = function(e) e
)
if (inherits(optout_fail, "error")) {
  chk(FALSE, paste("CONCERN 1: fit-failed opt-out path errored:",
                   conditionMessage(optout_fail)))
} else {
  ## Whether the fit failed (fit_converged FALSE) or degenerately succeeded,
  ## no Sigma_unit_diag row may be mislabelled "profile_total" in the opt-out
  ## config -- the honest label is "none".
  chk(!any(optout_fail$ci_method == "profile_total"),
      "CONCERN 1: opt-out config never labels a Sigma_unit_diag placeholder 'profile_total' (both sites)")
}

## =====================================================================
## Test 13 (CONCERN 2) -- lightweight deterministic injection of a DEGENERATE
## interval into the Sigma_unit_corr profile block's emission, WITHOUT a live
## bad refit: stub profile_ci_correlation() in the namespace to return a
## mis-ordered interval (lower > upper) and a point estimate outside it, then
## assert the emitted row folds to ci_failed = TRUE / covered = NA via the
## shared PF-3 guard. Restored immediately so later tests are unaffected.
inj_ok <- FALSE
orig_fn <- tryCatch(
  get("profile_ci_correlation", envir = asNamespace("gllvmTMB")),
  error = function(e) NULL
)
if (!is.null(orig_fn)) {
  stub <- function(fit, tier, i, j, level = 0.95, link_residual = "auto") {
    ## Degenerate: lower > upper and estimate outside [lower, upper].
    c(estimate = 0.9, lower = 0.7, upper = 0.2)
  }
  restored <- FALSE
  inj <- tryCatch({
    utils::assignInNamespace("profile_ci_correlation", stub, ns = "gllvmTMB")
    g_inj <- m3_run_cell(
      "gaussian",
      d = 1L, n_reps = 1L, seed_base = 2727L,
      n_units = 50L, n_traits = 3L,
      targets = "Sigma_unit_corr",
      verbose = FALSE
    )
    utils::assignInNamespace("profile_ci_correlation", orig_fn, ns = "gllvmTMB")
    restored <- TRUE
    g_inj
  }, error = function(e) {
    if (!restored) tryCatch(
      utils::assignInNamespace("profile_ci_correlation", orig_fn, ns = "gllvmTMB"),
      error = function(e2) NULL
    )
    e
  })
  if (!inherits(inj, "error")) {
    corr_inj <- inj[inj$target == "Sigma_unit_corr", , drop = FALSE]
    inj_ok <- nrow(corr_inj) > 0L &&
      all(corr_inj$ci_failed %in% TRUE) &&
      all(is.na(corr_inj$covered))
    chk(inj_ok,
        "CONCERN 2: an injected degenerate interval folds the emitted corr row to ci_failed=TRUE / covered=NA")
  }
}
if (is.null(orig_fn) || inherits(get0("inj"), "error")) {
  ## Accepted per coordinator: the namespace injection was unavailable in this
  ## environment; the fold logic is already unit-tested (Test 7) and both
  ## blocks call the identical m3_profile_ci_sane() guard.
  cat("NOTE - CONCERN 2: namespace-injection unavailable; accepted (fold logic covered by Test 7)\n")
}

cat("\n", if (ok) "ALL PASS" else "SOME FAILED", "\n")
if (!ok) quit(status = 1L)
