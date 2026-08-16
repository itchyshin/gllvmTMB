## Design 118 -- Phase B2 calibrator library, pure functions.
## docs/design/118-mspl-interval-calibration-protocol.md (the BINDING copy):
##   s2.3 (the pre-registered ladder M0..M5 and registered signs),
##   s2.4 (fit-to-coverage rule, leave-whole-cells-out K=8 CV, the
##         admission margin, the [0.01, 0.40] clip = fence-line-4 refusal),
##   s2.5 (n = 600, Wilson 90%, three-way verdict + one-shot escalation),
##   s5.6 (gates G1..G5), s8 DEV-3 (F-AMD refusal semantics, read off the
##   shard rows), s8 DEV-10 (the 5 H3 cloglog n_site = 192 cells are
##   ATTRIBUTED to issue #1020, never in a gate denominator).
##
## Sourced by fit-calibrator.R and evaluate-holdout.R AFTER
## inst/sim/b0-fence-roc/lib-b0-fence-roc.R and
## inst/sim/b1-calibration/lib-b1-calibration.R (this file reuses
## b1_grid, b1_seed_base, b1_simulate_outer_data, b0_trait_counts,
## b1_profile_trace_endpoint, `%||%`). No side effects at source time.
##
## INTERPRETATION REGISTER -- points where Design 118 s2/s5 is silent and a
## choice had to be made. Each is flagged loudly in fit-calibrator.R's
## summary; none is a silent choice (assignment discipline):
##   INT-W1  s2.4 writes the objective as sum_c w_c (cov_c - 0.95)^2 but
##           never defines w_c. Implemented: w_c = 1 (equal weight per
##           unit); defensible because every cell registers the same
##           n = 600 (s2.5), so equal-cell and replicate-proportional
##           weights coincide up to availability differences.
##   INT-G1  the coverage unit c is the (cell, calibration-target) pair,
##           matching consolidate-b1.R's committed grain and the archive's
##           own failure accounting ("C007 t2"); CV folds are formed by
##           CELL (s2.4: "folds by cell"), so a cell's three targets never
##           straddle folds.
##   INT-F1  fold assignment is deterministic round-robin over cells sorted
##           by cell_id (s2.4 fixes K = 8 and fold-by-cell but not the
##           assignment); no RNG, fully reproducible.
##   INT-P1  the s2.1 #2 observable pi_max = max_t max(p_hat_t, 1-p_hat_t)
##           is computed from the OBSERVED per-trait success proportions
##           k_t/n_t over ALL n_trait traits (re-simulated deterministically
##           from the stored seed and cross-checked against the stored k);
##           s2.1 does not say observed-vs-fitted, but its companion
##           m_min = min_t min(#1_t, #0_t) is a raw count and the harness
##           stores no per-trait fitted prevalence.
##   INT-S1  rows whose s_j is NA (Hessian not "ok" / probe refit failed)
##           contribute 0 to the M4 term log(1+s_j); counted and reported.
##   INT-M5  s2.3 registers "link main effect (2 df)" but the calibration
##           split contains only {logit, cloglog} (probit is entirely held
##           out, s5.1 H1), so at most 1 df is estimable; an all-zero link
##           column is dropped and recorded. If M5 is ever ADMITTED this is
##           a STOP-point: applying it to probit hold-out cells is not
##           defined by the registration.
##   INT-C1  during calibrator FITTING, a row whose alpha*(v; gamma) lands
##           on/outside the clip is excluded from the coverage estimand
##           (mirrors the shipped fence-line-4 refusal, s2.4/s1.3); rows
##           whose ladder term is non-finite (e.g. logit(pi_max) = Inf at a
##           saturated non-target trait) are likewise refused and counted --
##           a registered-form gap flagged as a STOP-point if M3+ is reached.

## ---- Registered constants ------------------------------------------------
b2_alpha_nominal <- 0.05
b2_alpha_clip <- c(0.01, 0.40)        ## s2.4 clip; landing on it = refusal (fence line 4, s1.3)
b2_coverage_target <- 0.95            ## s2.4 objective centre
b2_band <- c(0.92, 0.98)              ## s2.5 / s5.6 G1 equivalence band
b2_wilson_conf <- 0.90                ## s2.5 Wilson 90%
b2_admission_drop <- 0.005            ## s2.4 admission margin
b2_k_folds <- 8L                      ## s2.4 K
b2_escalation_reps <- 2000L           ## s2.5 one-shot escalation target
b2_availability_floor <- 0.95         ## s5.6 G3
b2_refusal_anchor_max <- 0.10         ## s5.6 G4
b2_g1_pass_frac <- 0.90               ## s5.6 G1
b2_g2_floor <- 0.90                   ## s5.6 G2
b2_rungs <- c("M0", "M1", "M2", "M3", "M4", "M5")  ## s2.3 ladder, strict order

## Profile deviance threshold at level alpha: (1/2) chisq_1(1 - alpha)
## (s2: measured constant 1.920729410347059 at alpha = 0.05).
b2_threshold <- function(alpha) stats::qchisq(1 - alpha, df = 1L) / 2

## ---- Split assertions (s5.7 rule 1 / the freeze discipline) -------------
## Both the row-level `split` column AND the registered grid must agree:
## a mislabelled split column must not smuggle hold-out rows into fitting.
b2_assert_train_only <- function(rows, grid = b1_grid()) {
  if (!nrow(rows)) stop("b2_assert_train_only(): no rows supplied.", call. = FALSE)
  if (!all(rows$split %in% "train")) {
    bad <- unique(rows$cell_id[!(rows$split %in% "train")])
    stop(
      "SPLIT VIOLATION (Design 118 s5.7): non-train rows in calibrator input: ",
      paste(bad, collapse = ", "), call. = FALSE
    )
  }
  reg <- grid$split[match(rows$cell_id, grid$cell_id)]
  if (any(is.na(reg))) {
    stop(
      "Unknown cell_id(s) in calibrator input: ",
      paste(unique(rows$cell_id[is.na(reg)]), collapse = ", "), call. = FALSE
    )
  }
  if (!all(reg == "train")) {
    bad <- unique(rows$cell_id[reg != "train"])
    stop(
      "SPLIT VIOLATION (Design 118 s5.7): cell(s) registered as hold-out ",
      "present in calibrator input: ", paste(bad, collapse = ", "), call. = FALSE
    )
  }
  invisible(TRUE)
}

b2_assert_holdout_cells <- function(cell_ids, grid = b1_grid()) {
  reg <- grid$split[match(cell_ids, grid$cell_id)]
  if (any(is.na(reg))) {
    stop(
      "Unknown cell_id(s): ", paste(cell_ids[is.na(reg)], collapse = ", "),
      call. = FALSE
    )
  }
  if (!all(reg == "holdout")) {
    stop(
      "SPLIT VIOLATION (Design 118 s5.7): cell(s) registered as TRAIN passed ",
      "to hold-out evaluation: ", paste(cell_ids[reg != "holdout"], collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

## ---- DEV-10 (s8): the attributed #1020 cells -----------------------------
## H3 cloglog x n_site = 192 -- 5 cells, all hold-out, expected to fail on a
## PRE-EXISTING package boundary (issue #1020). Identified from the
## registered grid, never from the data; their failures are ATTRIBUTED and
## must never enter a pass/fail denominator.
b2_dev10_cells <- function(grid = b1_grid()) {
  grid$cell_id[grid$block == "H3" & grid$link == "cloglog" & grid$n_site == 192L]
}

## ---- Seed arithmetic (inverse of b1_outer_seed) --------------------------
b2_outer_id_from_seed <- function(seed, cell_id, grid = b1_grid()) {
  base <- grid$seed_base[match(cell_id, grid$cell_id)]
  if (any(is.na(base))) stop("Unknown cell_id in seed inversion.", call. = FALSE)
  out <- as.integer(seed) - as.integer(base)
  if (any(out < 1L | out > 2000000L)) {
    stop("Seed inversion out of range: seed does not belong to its cell's family.",
      call. = FALSE
    )
  }
  out
}

b2_shard_of_outer <- function(outer_id, outer_per_shard = 10L) {
  as.integer(ceiling(as.integer(outer_id) / as.integer(outer_per_shard)))
}

## ---- pi_max (s2.1 #2, INT-P1) --------------------------------------------
## Deterministic re-simulation of the outer dataset's per-trait counts from
## the registered seed; exact under the registered DGP. `check_k`/`check_target`
## allow a cross-check against the stored k for the calibration targets --
## any mismatch means the RNG stream differs from the campaign's and the
## observable would be wrong, so it aborts.
b2_pi_max_for <- function(cell_row, outer_id, check_target = NULL, check_k = NULL) {
  data <- b1_simulate_outer_data(cell_row, outer_id)
  counts <- b0_trait_counts(data)
  if (!is.null(check_target)) {
    got <- counts$k[match(as.integer(check_target), counts$target)]
    if (!identical(as.integer(got), as.integer(check_k))) {
      stop(
        "pi_max re-simulation mismatch (cell ", cell_row$cell_id[[1L]],
        ", outer ", outer_id, "): stored k = ", paste(check_k, collapse = "/"),
        " vs re-simulated ", paste(got, collapse = "/"),
        " -- RNG stream differs from the campaign's.", call. = FALSE
      )
    }
  }
  p <- counts$k / counts$n_obs
  max(pmax(p, 1 - p))
}

## ---- The ladder design matrix (s2.3) -------------------------------------
## Columns are named; the fitted map stores the names it used so the same
## columns can be rebuilt at evaluation time. Link dummies are always built
## for BOTH non-reference links (cloglog, probit; logit = reference) so
## column identity is stable across splits; all-zero columns are dropped at
## fit time and recorded (INT-M5).
b2_h_matrix <- function(v, rung) {
  n <- nrow(v)
  cols <- list()
  if (rung %in% c("M1", "M2", "M3", "M4", "M5")) cols$gamma0 <- rep(1, n)
  if (rung %in% c("M2", "M3", "M4", "M5")) cols$c_n <- as.numeric(v$c_n)
  if (rung %in% c("M3", "M4", "M5")) {
    cols$logit_pi_max <- stats::qlogis(as.numeric(v$pi_max))
  }
  if (rung %in% c("M4", "M5")) {
    s <- as.numeric(v$s_j)
    s[!is.finite(s)] <- 0 ## INT-S1
    cols$log1p_s_j <- log1p(s)
  }
  if (rung == "M5") {
    cols$link_cloglog <- as.numeric(v$link == "cloglog")
    cols$link_probit <- as.numeric(v$link == "probit")
  }
  if (!length(cols)) {
    return(matrix(numeric(0), nrow = n, ncol = 0L))
  }
  do.call(cbind, cols)
}

## Registered sign constraints (s2.3): named by design column. gamma0 (M1)
## carries no registered sign; M5's link effect carries none.
b2_registered_signs <- c(c_n = 1, logit_pi_max = 1, log1p_s_j = 1)

## ---- alpha*(v; gamma) with clip-as-refusal (s2.4 / s1.3 fence line 4) ----
## logit alpha*(v) = logit alpha + h(v)  (s2.3). p = 0 columns (M0) returns
## alpha EXACTLY (no logistic round-trip), so the alpha* = alpha identity is
## bit-exact.
b2_alpha_star <- function(gamma, H, alpha = b2_alpha_nominal) {
  n <- nrow(H)
  if (length(gamma) == 0L) {
    return(list(alpha_star = rep(alpha, n), clip_refused = rep(FALSE, n)))
  }
  if (length(gamma) != ncol(H)) stop("gamma/H mismatch.", call. = FALSE)
  eta <- stats::qlogis(alpha) + as.numeric(H %*% gamma)
  bad <- !is.finite(eta)
  a <- stats::plogis(eta)
  a[bad] <- NA_real_
  refused <- bad | (a <= b2_alpha_clip[[1L]]) | (a >= b2_alpha_clip[[2L]])
  refused[is.na(refused)] <- TRUE
  list(
    alpha_star = pmin(pmax(a, b2_alpha_clip[[1L]]), b2_alpha_clip[[2L]]),
    clip_refused = refused
  )
}

## ---- Profile-trace per-row precompute ------------------------------------
## The s2.4 fitting rule re-evaluates every stored interval at candidate
## alpha* values inside a CV'd optimizer -- too slow to call
## b1_profile_trace_endpoint() per (row x candidate). This block reduces a
## row's stored trace to three exact numbers:
##   tau_avail_min/max : the interval endpoint at threshold tau exists
##                       (both sides bracket) iff tau_avail_min < tau <=
##                       tau_avail_max;
##   tau_cover         : the interval covers `truth` iff additionally
##                       tau >= tau_cover.
## Exactness is with respect to b1_profile_trace_endpoint()'s OWN semantics
## (same row filter, same per-side sort, same first-bracketing-pair
## interpolation): with the centre row present (delta 0 = the side minimum)
## the first bracketing pair for threshold tau is (k-1, k) where k is the
## first row whose delta >= tau, so the endpoint is piecewise linear and
## monotone in tau and availability is the single band (delta_1, max delta].
## Rows violating the fast-path preconditions (any non-finite delta after
## the filter, or the innermost row not the delta minimum) fall back to a
## dense direct evaluation with the registered function itself and are
## counted. fit-calibrator.R additionally verifies a random sample of rows
## against the registered function and aborts on any disagreement.
b2_side_summary <- function(trace, side, truth) {
  sub <- trace[
    trace$side %in% c(side, "centre") & trace$finite %in% TRUE &
      trace$convergence %in% 0L, , drop = FALSE
  ]
  if (nrow(sub) < 2L) {
    ## matches the registered function: < 2 usable rows -> endpoint NA at
    ## every threshold -> never available.
    return(list(tau_min = Inf, tau_max = -Inf, tau_cover = Inf, fast_ok = TRUE))
  }
  sub <- sub[
    if (identical(side, "lower")) order(-sub$target_value) else order(sub$target_value), ,
    drop = FALSE
  ]
  x <- as.numeric(sub$target_value)
  y <- as.numeric(sub$objective_delta)
  n <- length(y)
  if (any(!is.finite(y)) || any(!is.finite(x)) || y[[1L]] > min(y)) {
    return(list(tau_min = NA_real_, tau_max = NA_real_, tau_cover = NA_real_, fast_ok = FALSE))
  }
  tau_min <- y[[1L]]
  tau_max <- max(y)
  beyond <- function(val) if (identical(side, "lower")) val <= truth else val >= truth
  if (beyond(x[[1L]])) {
    ## centre already at/beyond truth on this side: covered at any
    ## available threshold.
    return(list(tau_min = tau_min, tau_max = tau_max, tau_cover = 0, fast_ok = TRUE))
  }
  ## Record rows: the possible "first row with delta >= tau" values. For
  ## tau in (v_{m-1}, v_m] the first bracketing pair is (k_m - 1, k_m).
  cm <- cummax(y)
  rec <- which(y > c(-Inf, cm[-n]))
  ks <- rec[rec > 1L]
  tau_cover <- Inf
  prev_v <- y[[1L]]
  for (k in ks) {
    i0 <- k - 1L
    if (beyond(x[[k]])) {
      if (x[[k]] == x[[i0]]) {
        tau_cover <- prev_v
      } else {
        tau_star <- y[[i0]] + (truth - x[[i0]]) * (y[[k]] - y[[i0]]) / (x[[k]] - x[[i0]])
        tau_cover <- max(tau_star, prev_v)
      }
      break
    }
    prev_v <- y[[k]]
  }
  list(tau_min = tau_min, tau_max = tau_max, tau_cover = tau_cover, fast_ok = TRUE)
}

## Dense fallback for rows failing the fast-path preconditions: derive the
## same three numbers numerically from the registered function on a fine
## threshold grid (resolution reported by the caller; expected count 0).
b2_profile_summary_dense <- function(trace, truth, n_grid = 1200L) {
  taus <- seq(1e-4, 4.0, length.out = n_grid)
  lo <- vapply(taus, function(t) b1_profile_trace_endpoint(trace, t, "lower"), numeric(1L))
  up <- vapply(taus, function(t) b1_profile_trace_endpoint(trace, t, "upper"), numeric(1L))
  avail <- is.finite(lo) & is.finite(up)
  if (!any(avail)) {
    return(list(tau_avail_min = Inf, tau_avail_max = -Inf, tau_cover = Inf, fast = FALSE))
  }
  cov <- avail & lo <= truth & up >= truth
  list(
    tau_avail_min = taus[[min(which(avail))]] - diff(taus)[[1L]],
    tau_avail_max = taus[[max(which(avail))]],
    tau_cover = if (any(cov)) taus[[min(which(cov))]] else Inf,
    fast = FALSE
  )
}

## One row's full precompute from its (already outer/target-subset) trace.
b2_profile_precompute <- function(trace, truth) {
  lo <- b2_side_summary(trace, "lower", truth)
  up <- b2_side_summary(trace, "upper", truth)
  if (!lo$fast_ok || !up$fast_ok) {
    return(b2_profile_summary_dense(trace, truth))
  }
  list(
    tau_avail_min = max(lo$tau_min, up$tau_min),
    tau_avail_max = min(lo$tau_max, up$tau_max),
    tau_cover = max(lo$tau_cover, up$tau_cover),
    fast = TRUE
  )
}

## Direct (registered-function) endpoints at level alpha -- used by the
## hold-out gate evaluation and by the identity checks. s2: the profile
## interval at level alpha is the threshold crossing at (1/2) chisq_1(1-alpha).
b2_profile_endpoints_at <- function(trace, alpha) {
  thr <- b2_threshold(alpha)
  c(
    lower = b1_profile_trace_endpoint(trace, thr, "lower"),
    upper = b1_profile_trace_endpoint(trace, thr, "upper")
  )
}

## Direct covered/available at level alpha from a trace (registered
## semantics; the slow path the precompute is verified against).
b2_profile_eval_direct <- function(trace, truth, alpha) {
  ep <- b2_profile_endpoints_at(trace, alpha)
  avail <- is.finite(ep[["lower"]]) && is.finite(ep[["upper"]])
  list(
    available = avail,
    covered = avail && truth >= ep[["lower"]] && truth <= ep[["upper"]],
    lower = ep[["lower"]], upper = ep[["upper"]]
  )
}

## ---- Bootstrap per-row precompute (s2.1 percentile re-levelling) ---------
## The percentile interval at level alpha* is the (alpha*/2, 1-alpha*/2)
## type-7 quantile pair of the stored replicate vector (s2: "the alpha*/2
## and 1-alpha*/2 empirical percentiles"; quantile type 7 matches the
## harness's own endpoint computation). Coverage is monotone decreasing in
## alpha*, so a row reduces to one number: the largest alpha* at which the
## interval still covers truth.
b2_boot_alpha_cover_max <- function(vals, truth) {
  v <- sort(as.numeric(vals))
  nu <- length(v)
  if (nu < 2L) return(-Inf)
  p_lo <- if (truth >= v[[nu]]) {
    1
  } else if (truth < v[[1L]]) {
    -Inf
  } else {
    j <- max(which(v <= truth))
    h <- if (v[[j + 1L]] > v[[j]]) j + (truth - v[[j]]) / (v[[j + 1L]] - v[[j]]) else j
    (h - 1) / (nu - 1)
  }
  p_hi <- if (truth <= v[[1L]]) {
    0
  } else if (truth > v[[nu]]) {
    Inf
  } else {
    j2 <- min(which(v >= truth))
    h <- if (v[[j2]] > v[[j2 - 1L]]) {
      (j2 - 1L) + (truth - v[[j2 - 1L]]) / (v[[j2]] - v[[j2 - 1L]])
    } else {
      j2 - 1L
    }
    (h - 1) / (nu - 1)
  }
  2 * min(p_lo, 1 - p_hi)
}

## Direct bootstrap covered at level alpha (the slow path the precompute is
## verified against; mirrors the shard's own endpoint arithmetic).
b2_boot_eval_direct <- function(vals, truth, alpha) {
  ep <- stats::quantile(as.numeric(vals), c(alpha / 2, 1 - alpha / 2), type = 7L, names = FALSE)
  truth >= ep[[1L]] && truth <= ep[[2L]]
}

## ---- Row evaluation at candidate alpha* ----------------------------------
## `pre` is a data.frame with columns:
##   construction ("profile"/"boot"), unit (cell x target key),
##   cell_id, tau_avail_min, tau_avail_max, tau_cover (profile rows),
##   alpha_cover_max (boot rows).
b2_eval_rows <- function(pre, alpha_star, clip_refused) {
  n <- nrow(pre)
  avail <- logical(n)
  covered <- logical(n)
  is_prof <- pre$construction == "profile"
  if (any(is_prof)) {
    tau <- b2_threshold(alpha_star[is_prof])
    a <- !clip_refused[is_prof] & !is.na(tau) &
      tau > pre$tau_avail_min[is_prof] & tau <= pre$tau_avail_max[is_prof]
    a[is.na(a)] <- FALSE
    avail[is_prof] <- a
    covered[is_prof] <- a & tau >= pre$tau_cover[is_prof]
  }
  if (any(!is_prof)) {
    a <- !clip_refused[!is_prof]
    avail[!is_prof] <- a
    covered[!is_prof] <- a & alpha_star[!is_prof] <= pre$alpha_cover_max[!is_prof]
  }
  covered[is.na(covered)] <- FALSE
  list(avail = avail, covered = covered)
}

## Per-unit coverage among available rows (unit = (cell, target), INT-G1).
b2_unit_coverage <- function(unit, avail, covered) {
  na_ <- tapply(avail, unit, sum)
  nc_ <- tapply(covered, unit, sum)
  keep <- !is.na(na_)
  data.frame(
    unit = names(na_)[keep],
    n_avail = as.integer(na_[keep]),
    n_covered = as.integer(nc_[keep]),
    coverage = ifelse(na_[keep] > 0L, nc_[keep] / na_[keep], NA_real_),
    stringsAsFactors = FALSE
  )
}

## s2.4 objective: sum_c w_c (cov_c - 0.95)^2, w_c = 1 (INT-W1). Units with
## no available rows drop out; if none remain the candidate is inadmissible
## (+Inf).
b2_objective_value <- function(unitcov, target = b2_coverage_target) {
  u <- unitcov[unitcov$n_avail > 0L & !is.na(unitcov$coverage), , drop = FALSE]
  if (!nrow(u)) return(Inf)
  sum((u$coverage - target)^2)
}

b2_objective <- function(gamma, H, pre, alpha) {
  as_ <- b2_alpha_star(gamma, H, alpha)
  e <- b2_eval_rows(pre, as_$alpha_star, as_$clip_refused)
  b2_objective_value(b2_unit_coverage(pre$unit, e$avail, e$covered))
}

## ---- Rung fitting (s2.4: "not a likelihood fit") -------------------------
b2_fit_rung <- function(rung, v, pre, alpha, start = NULL) {
  H <- b2_h_matrix(v, rung)
  keep_cols <- if (ncol(H)) colSums(abs(H), na.rm = TRUE) > 0 else logical(0)
  dropped <- colnames(H)[!keep_cols]
  H <- H[, keep_cols, drop = FALSE]
  p <- ncol(H)
  if (p == 0L) {
    return(list(
      rung = rung, gamma = numeric(0), terms = character(0),
      value = b2_objective(numeric(0), H, pre, alpha), dropped_columns = dropped
    ))
  }
  obj <- function(g) b2_objective(g, H, pre, alpha)
  if (p == 1L) {
    ## M1: gamma0 alone; the whole-map range beyond which every row clips
    ## (s2.4) bounds the search.
    lo <- stats::qlogis(b2_alpha_clip[[1L]]) - stats::qlogis(alpha)
    hi <- stats::qlogis(b2_alpha_clip[[2L]]) - stats::qlogis(alpha)
    o <- stats::optimize(obj, interval = c(lo, hi), tol = 1e-6)
    gamma <- o$minimum
    value <- o$objective
  } else {
    st <- start %||% rep(0, p)
    if (length(st) < p) st <- c(st, rep(0, p - length(st)))
    o <- stats::optim(
      st, obj, method = "Nelder-Mead",
      control = list(maxit = 4000L, reltol = 1e-10)
    )
    gamma <- o$par
    value <- o$value
  }
  names(gamma) <- colnames(H)
  list(rung = rung, gamma = gamma, terms = colnames(H), value = value, dropped_columns = dropped)
}

## Registered-sign check (s2.3: wrong sign => term dropped, contradiction
## reported; feeds gate G5, s5.6).
b2_sign_check <- function(gamma) {
  bad <- character(0)
  for (nm in names(gamma)) {
    want <- b2_registered_signs[[nm]] %||% NULL
    if (!is.null(want) && !is.na(gamma[[nm]]) && sign(gamma[[nm]]) == -want) {
      bad <- c(bad, sprintf("%s = %.4g (registered sign: >= 0)", nm, gamma[[nm]]))
    }
  }
  list(ok = !length(bad), contradictions = bad)
}

## ---- Folds (s2.4: leave-whole-cells-out, K = 8; INT-F1) ------------------
b2_folds <- function(cell_ids, k = b2_k_folds) {
  cells <- sort(unique(as.character(cell_ids)))
  if (length(cells) < k) {
    stop(
      "Only ", length(cells), " cell(s) for K = ", k,
      " leave-whole-cells-out CV (s2.4); pass --k-folds <= number of cells.",
      call. = FALSE
    )
  }
  fold_of_cell <- ((seq_along(cells) - 1L) %% k) + 1L
  fold_of_cell[match(as.character(cell_ids), cells)]
}

## Out-of-fold unit coverage for one rung.
b2_cv_rung <- function(rung, v, pre, alpha, folds, start = NULL) {
  oof <- vector("list", max(folds))
  fold_gammas <- vector("list", max(folds))
  for (f in sort(unique(folds))) {
    tr <- folds != f
    te <- folds == f
    fit <- b2_fit_rung(rung, v[tr, , drop = FALSE], pre[tr, , drop = FALSE], alpha, start = start)
    H_te <- b2_h_matrix(v[te, , drop = FALSE], rung)
    H_te <- H_te[, fit$terms, drop = FALSE]
    as_ <- b2_alpha_star(fit$gamma, H_te, alpha)
    e <- b2_eval_rows(pre[te, , drop = FALSE], as_$alpha_star, as_$clip_refused)
    oof[[f]] <- b2_unit_coverage(pre$unit[te], e$avail, e$covered)
    fold_gammas[[f]] <- fit$gamma
  }
  unitcov <- do.call(rbind, oof)
  list(unitcov = unitcov, fold_gammas = fold_gammas)
}

b2_cv_metrics <- function(unitcov, target = b2_coverage_target) {
  u <- unitcov[unitcov$n_avail > 0L & !is.na(unitcov$coverage), , drop = FALSE]
  if (!nrow(u)) {
    return(list(max_err = Inf, mae = Inf, n_units = 0L, n_dropped_units = nrow(unitcov)))
  }
  list(
    max_err = max(abs(u$coverage - target)),
    mae = mean(abs(u$coverage - target)),
    n_units = nrow(u),
    n_dropped_units = nrow(unitcov) - nrow(u)
  )
}

## ---- The ladder walk (s2.3 order + s2.4 admission + s2.3 sign rule) ------
## Returns the selection path and the final full-data fit of the selected
## rung. Admission of M_{k+1} over M_k (s2.4): out-of-fold
## max_c |cov_c - 0.95| drops by >= 0.005 AND the MAE does not rise; ties to
## the simpler model; STOP at the first non-admission. A wrong-signed new
## coefficient in the full-data fit drops the term (= non-admission) and the
## contradiction is recorded (s2.3, gate G5).
b2_select_map <- function(v, pre, alpha, folds, rungs = b2_rungs,
                          max_rung = "M5", label = "") {
  path <- list()
  selected <- "M0"
  selected_metrics <- NULL
  selected_gamma <- numeric(0)
  prev_start <- NULL
  for (rung in rungs) {
    if (match(rung, b2_rungs) > match(max_rung, b2_rungs)) break
    full <- b2_fit_rung(rung, v, pre, alpha, start = prev_start)
    sign_rep <- b2_sign_check(full$gamma)
    cv <- b2_cv_rung(rung, v, pre, alpha, folds, start = prev_start)
    met <- b2_cv_metrics(cv$unitcov)
    admitted <- FALSE
    note <- ""
    if (rung == "M0") {
      admitted <- TRUE ## the comparator is always on the path (s2.3)
    } else if (!sign_rep$ok) {
      note <- paste(
        "sign contradiction, term dropped (s2.3):",
        paste(sign_rep$contradictions, collapse = "; ")
      )
    } else {
      drop_ <- selected_metrics$max_err - met$max_err
      mae_ok <- met$mae <= selected_metrics$mae
      admitted <- (drop_ >= b2_admission_drop) && mae_ok
      note <- sprintf(
        "max_err drop = %.4f (need >= %.3f), mae %s",
        drop_, b2_admission_drop, if (mae_ok) "did not rise" else "ROSE"
      )
    }
    path[[rung]] <- list(
      rung = rung, gamma_full = full$gamma, terms = full$terms,
      dropped_columns = full$dropped_columns,
      objective_full = full$value,
      cv_max_err = met$max_err, cv_mae = met$mae,
      cv_n_units = met$n_units, cv_n_dropped_units = met$n_dropped_units,
      sign_ok = sign_rep$ok, sign_contradictions = sign_rep$contradictions,
      admitted = admitted, note = note
    )
    if (rung != "M0" && !admitted) break ## s2.4: stop at first non-admission
    if (admitted) {
      selected <- rung
      selected_metrics <- met
      selected_gamma <- full$gamma
      prev_start <- unname(full$gamma)
    }
  }
  final <- path[[selected]]
  list(
    label = label, selected = selected,
    gamma = selected_gamma, terms = final$terms,
    cv_max_err = final$cv_max_err, cv_mae = final$cv_mae,
    path = path
  )
}

## alpha*(v) from a frozen map spec (list(rung, gamma, terms)) -- the
## evaluation-side counterpart of b2_select_map's output.
b2_map_alpha_star <- function(spec, v, alpha = b2_alpha_nominal) {
  H <- b2_h_matrix(v, spec$rung)
  H <- H[, spec$terms, drop = FALSE]
  b2_alpha_star(spec$gamma, H, alpha)
}

## ---- Wilson CI, three-way verdict, escalation (s2.5) ---------------------
## Mirrors consolidate-b1.R's committed arithmetic exactly.
b2_wilson_ci <- function(x, n, conf = b2_wilson_conf) {
  if (n == 0L) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(1 - (1 - conf) / 2)
  phat <- x / n
  denom <- 1 + z^2 / n
  centre <- phat + z^2 / (2 * n)
  half <- z * sqrt(phat * (1 - phat) / n + z^2 / (4 * n^2))
  pmax(0, pmin(1, c((centre - half) / denom, (centre + half) / denom)))
}

## s2.5: PASS iff Wilson 90% CI inside [0.92, 0.98]; FAIL iff the point
## itself is outside; INDETERMINATE otherwise.
b2_verdict <- function(phat, ci, band = b2_band) {
  if (is.na(phat)) return("NO_DATA")
  if (phat < band[[1L]] || phat > band[[2L]]) return("FAIL")
  if (ci[[1L]] >= band[[1L]] && ci[[2L]] <= band[[2L]]) return("PASS")
  "INDETERMINATE"
}

## s2.5 one-shot escalation, hold-out gate cells only: INDETERMINATE at
## n < 2000 -> escalate once; INDETERMINATE at n >= 2000 -> recorded FAIL
## (fail-closed).
b2_apply_escalation <- function(verdict, n_reps) {
  escalate <- verdict == "INDETERMINATE" & n_reps < b2_escalation_reps
  recorded <- ifelse(
    verdict == "INDETERMINATE" & n_reps >= b2_escalation_reps, "FAIL", verdict
  )
  list(verdict = recorded, escalate_to_2000 = escalate)
}

## ---- Gates G1..G4 (s5.6), evaluated on gate-ELIGIBLE rows only -----------
## `summary`: one row per (cell, target) with columns verdict, coverage,
## escalate_to_2000. `cell_avail`: one row per cell with `availability`.
## `anchors`: one row per anchor cell with `refusal_rate`. DEV-10 cells must
## already be excluded by the caller (s8 DEV-10: attributed, never in the
## denominator).
b2_gates <- function(summary, cell_avail, anchors, sign_ok) {
  pending <- any(summary$escalate_to_2000 %in% TRUE)
  g1_frac <- if (nrow(summary)) mean(summary$verdict == "PASS") else NA_real_
  g2_ok <- !any(summary$coverage < b2_g2_floor, na.rm = TRUE)
  g3_ok <- !any(cell_avail$availability < b2_availability_floor, na.rm = TRUE)
  g4_ok <- !any(anchors$refusal_rate > b2_refusal_anchor_max, na.rm = TRUE)
  list(
    g1_frac_pass = g1_frac,
    g1_ok = !is.na(g1_frac) && g1_frac >= b2_g1_pass_frac,
    g2_ok = g2_ok, g3_ok = g3_ok, g4_ok = g4_ok, g5_ok = isTRUE(sign_ok),
    pending_escalation = pending
  )
}
