#!/usr/bin/env Rscript
## =============================================================================
## Arc 0, slice T2 -- PROFILE CURVATURE ALONG THE TRAILING EIGENVECTOR.
##
## Question this slice answers, per cell: when the fit is FORCED to move the
## between-site variance in the least-supported trait direction away from its
## fitted value, how sharply does the Laplace nll rise?
##   * a SHARP profile -> the data identifies that direction (against H2/H3);
##   * a FLAT profile  -> the data does not identify it (H2), and if the nll
##     also keeps improving outward, that is the H3 (divergent) signature.
##
## Usage (from /private/tmp/gllvmtmb-arc0-identifiability):
##   Rscript dev/arc0/20-profile.R [cells.csv] [profile.csv] [profile-curves.csv]
## Defaults, also settable as env vars:
##   cells   ARC0_CELLS  = /tmp/grid-ref.csv
##   out     ARC0_OUT    = dev/arc0/profile.csv
##   curves  ARC0_CURVES = dev/arc0/profile-curves.csv
## Other env knobs:
##   ARC0_MAX_CELLS   integer -- take only the first N cells after filtering
##   ARC0_ROW         integer -- run only that row of the filtered cell table
##   ARC0_MAX_EXTEND  integer -- max adaptive grid extensions per side (default 4)
##   ARC0_NO_MAIN     set to any value to source this file without running main
##
## The caller is expected to parallelise over cells with parallel::mclapply, so
## this file NEVER spawns workers of its own; the main block is a plain lapply.
## Map the caller's parallelism over arc0_profile_cell().
##
## HARD SCOPE: writes only inside dev/arc0/. Reads R/ and src/ but edits neither,
## and never recompiles TMB.
## =============================================================================

ARC0_DIR <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/arc0"
source(file.path(ARC0_DIR, "lib.R"))

## -----------------------------------------------------------------------------
## DESIGN DECISION 1 -- WHAT "lambda_q" MEANS OFF THE OPTIMUM.
##
## arc0_trailing() returns the trailing eigenpair (u_q, lambda_q) of the FITTED
## Sigma_B. Away from the fit we need lambda_q as a function of theta, and there
## are two candidates:
##
##   (a) the trailing EIGENVALUE of Sigma_B(theta). REJECTED. It is non-smooth at
##       eigenvalue crossings and, worse, it is escapable: the optimiser can meet
##       a target on "the smallest eigenvalue" by rotating WHICH trait direction
##       is smallest, so constraining (a) does not hold the direction of interest
##       fixed and the resulting profile answers a different question at each tau.
##   (b) the QUADRATIC FORM in the FIXED fitted direction,
##           g(theta) = u_q' Sigma_B(theta) u_q = || Lambda(theta)' u_q ||^2 .
##       ADOPTED. It is smooth (a PSD quadratic in Lambda), it is rotation-
##       invariant because it depends on Lambda only through Sigma_B (Lambda
##       itself is identified only up to a q x q rotation -- lib.R trap 3), and it
##       equals lambda_q EXACTLY at the fit because u_q is an eigenvector there,
##       which is what makes the tau = lambda_q_hat sanity check meaningful.
##       The statistic is then: the nll cost of forcing the between-site variance
##       in trait direction u_q to a stated level.
##
## Interpretive caveat, stated rather than hidden: with rank q < p the model can
## partly obey the constraint by tilting the rank-q column space away from u_q.
## That is not a defect of the statistic -- an identified model still pays nll to
## move variance out of a direction the data speaks to. A flat profile means
## exactly that the data does not pin the variance along u_q.
##
## DESIGN DECISION 2 -- ROUTE (i) PENALISED PROFILE, NOT ROUTE (ii) LINCOMB.
##
## g(theta) is QUADRATIC in Lambda, so TMB::tmbprofile's `lincomb` interface does
## not apply to it. The handover's alternative -- profile the LINEAR functional
## u_q' Lambda via lincomb -- was considered and rejected on a substantive
## ground, not a convenience one: u_q' Lambda is a q-vector that is NOT
## IDENTIFIED. Under `unique = FALSE` the likelihood is exactly flat along the
## q(q-1)/2 rotation directions of Lambda, so any fixed unit combination of
## u_q' Lambda inherits that built-in flatness. A flat lincomb profile would be
## unfalsifiable evidence -- it would look flat for a perfectly identified cell
## too. The identified functional is Sigma_B, hence g(theta), hence route (i).
## (Route (ii) would additionally require mapping trait-space u_q onto the packed
## theta_rr_B fill order; that map IS derived and verified below, because the
## penalty gradient needs it -- so the rejection is on identifiability, not on
## the difficulty of the mapping.)
##
## Route (i) as implemented: for each target tau, re-optimise the FULL fixed
## parameter vector under
##       nll(theta) + mu * ( log g(theta) - log tau )^2
## and report the UNPENALISED nll at the solution. The penalty is on the LOG
## scale because lambda_q spans orders of magnitude (2.4e6 and 2.2e3 on the
## degenerate smoke cell): a raw-scale penalty would be hopelessly ill-scaled
## across the grid, binding tightly at large tau and not at all at small tau.
## mu is raised over three continuation stages (1e2 -> 1e4 -> 1e6), and the
## ACHIEVED g is reported next to the requested tau. A cell where the constraint
## fails to bind is recorded as a FAILURE (status "penalty-not-bound"), never as
## a flat profile.
## -----------------------------------------------------------------------------

## --- theta_rr_B <-> Lambda_B packing ----------------------------------------
## VERIFIED EMPIRICALLY against a live fit (dev/arc0/probe-map.R, 2026-07-28,
## n=40/p=8/q=2/seed=1): reconstruction matched fit$report$Lambda_B with max abs
## diff 0 at the optimum, and single-entry perturbations of theta_rr_B[1,2,3,9,15]
## moved tmb_obj$report()$Lambda_B at exactly (1,1),(2,2),(2,1),(8,1),(8,2) with
## max|predicted - reported| = 0 in every case.
## Layout (src/gllvmTMB.cpp:798-808): head(rank) = diagonal, tail = strict lower
## triangle filled column-major; upper triangle is structurally zero.
arc0_pack_index <- function(i, j, p, rank) {   # 0-based (i, j); 1-based result
  if (j > i) return(NA_integer_)
  if (i == j) return(j + 1L)
  rank + (j * p - ((j + 1L) * j) %/% 2L + i - 1L - j) + 1L
}

## (row, col) of Lambda for each free theta_rr_B entry, so the analytic penalty
## gradient can be scattered back onto theta.
arc0_theta_layout <- function(p, q) {
  nt <- as.integer(p * q - q * (q - 1L) / 2L)
  ri <- integer(nt); ci <- integer(nt)
  for (j in 0:(q - 1L)) for (i in 0:(p - 1L)) {
    k <- arc0_pack_index(i, j, p, q)
    if (!is.na(k)) { ri[k] <- i + 1L; ci[k] <- j + 1L }
  }
  stopifnot(all(ri > 0L), all(ci > 0L))
  list(nt = nt, row = ri, col = ci)
}

arc0_lambda_from_theta <- function(th, lay, p, q) {
  L <- matrix(0, p, q)
  L[cbind(lay$row, lay$col)] <- th
  L
}

## --- the profiled functional and its exact gradient --------------------------
## g = ||L'u||^2 ;  dg/dL_ij = 2 u_i w_j  with  w = L'u.
arc0_g <- function(th, lay, p, q, u) {
  L <- arc0_lambda_from_theta(th, lay, p, q)
  w <- as.numeric(crossprod(L, u))
  list(g = sum(w * w), w = w)
}

## d/dtheta of  mu * (log g - log tau)^2  =  4 mu (log g - log tau) / g * w_j u_i
arc0_pen_grad_theta <- function(gw, u, lay, mu, log_tau) {
  g <- max(gw$g, 1e-300)
  (4 * mu * (log(g) - log_tau) / g) * gw$w[lay$col] * u[lay$row]
}

## Self-check of the analytic penalty gradient against a central difference.
## Pure arithmetic -- no fits -- so it runs on every invocation and costs nothing.
arc0_check_pen_grad <- function() {
  set.seed(11); p <- 8L; q <- 2L
  lay <- arc0_theta_layout(p, q)
  th <- stats::rnorm(lay$nt); u <- stats::rnorm(p); u <- u / sqrt(sum(u^2))
  mu <- 137; log_tau <- log(0.7)
  pen <- function(t) mu * (log(max(arc0_g(t, lay, p, q, u)$g, 1e-300)) - log_tau)^2
  an <- arc0_pen_grad_theta(arc0_g(th, lay, p, q, u), u, lay, mu, log_tau)
  fd <- vapply(seq_along(th), function(k) {
    h <- 1e-6; a <- th; b <- th; a[k] <- a[k] + h; b[k] <- b[k] - h
    (pen(a) - pen(b)) / (2 * h)
  }, numeric(1))
  max(abs(an - fd)) / max(1, max(abs(fd)))
}

## --- WRITING -----------------------------------------------------------------
## One append per cell (and one curve block per cell), each emitted as a SINGLE
## write, so concurrent mclapply children interleave at block granularity, not
## mid-line. Blocks are a few kB, inside the POSIX atomic-append regime. The
## header is written once, by whichever process finds the file absent/empty.
arc0_append_csv <- function(df, path) {
  hdr <- !file.exists(path) || file.size(path) == 0
  txt <- utils::capture.output(utils::write.csv(df, row.names = FALSE, quote = TRUE))
  if (!hdr) txt <- txt[-1]
  cat(paste0(paste(txt, collapse = "\n"), "\n"), file = path, append = TRUE)
  invisible(TRUE)
}

## -----------------------------------------------------------------------------
## One penalised solve at a single target tau.
## `start` is a full UNNAMED fixed-effect vector (b_fix, theta_rr_B).
## Anchoring: every start descends from fit$opt$par, the VERIFIED optimum.
## fit$tmb_obj$par is the STARTING vector (39.5 nll units away on the degenerate
## smoke cell, lib.R trap 2) and is never touched here.
## -----------------------------------------------------------------------------
arc0_solve_tau <- function(obj, start, ix_th, lay, p, q, u, tau,
                           mu_stages = c(1e2, 1e4, 1e6)) {
  log_tau <- log(tau)
  ## as.vector() strips the `logarithm` attribute TMB attaches via determinant();
  ## left on, it propagates into nlminb and into all.equal comparisons.
  fn_raw <- function(par) {
    v <- as.vector(tryCatch(obj$fn(par), error = function(e) NA_real_))
    if (length(v) != 1L || !is.finite(v)) 1e8 else v
  }
  gr_raw <- function(par) {
    v <- tryCatch(as.numeric(obj$gr(par)), error = function(e) NULL)
    if (is.null(v) || length(v) != length(par) || any(!is.finite(v))) {
      rep(0, length(par))
    } else v
  }
  par <- start; conv <- NA_integer_; msg <- ""
  for (mu in mu_stages) {
    local({
      m <- mu
      fn <- function(pp) {
        gw <- arc0_g(pp[ix_th], lay, p, q, u)
        fn_raw(pp) + m * (log(max(gw$g, 1e-300)) - log_tau)^2
      }
      gr <- function(pp) {
        gw <- arc0_g(pp[ix_th], lay, p, q, u)
        g <- gr_raw(pp)
        g[ix_th] <- g[ix_th] + arc0_pen_grad_theta(gw, u, lay, m, log_tau)
        g
      }
      o <- tryCatch(stats::nlminb(par, fn, gr,
                                  control = list(eval.max = 800L, iter.max = 500L)),
                    error = function(e) NULL)
      if (is.null(o) || any(!is.finite(o$par))) {
        msg <<- paste0(msg, "nlminb-failed;")
      } else {
        par <<- o$par; conv <<- o$convergence
        msg <<- paste0(msg, o$message, ";")
      }
    })
  }
  gw <- arc0_g(par[ix_th], lay, p, q, u)
  nll <- fn_raw(par)
  list(par = par, nll = if (is.finite(nll) && nll < 1e7) nll else NA_real_,
       achieved = gw$g, conv = conv, message = substr(msg, 1, 160))
}

## -----------------------------------------------------------------------------
## Full profile for ONE cell. THIS is the function the caller maps over.
## `cell` is a one-row data.frame with n, p, q, seed (plus optional cell_id,
## design, stratum, grp, rel_frob, which are carried through when present).
## Never throws: every failure mode returns a row with a `status`.
## -----------------------------------------------------------------------------
arc0_profile_cell <- function(cell, out_csv = NULL, curves_csv = NULL,
                              max_extend = 4L) {
  t0 <- Sys.time()
  n <- as.integer(cell$n); p <- as.integer(cell$p)
  q <- as.integer(cell$q); seed <- as.integer(cell$seed)
  gc0 <- function(nm, def) {
    v <- cell[[nm]]
    if (!is.null(v) && !is.na(v) && nzchar(as.character(v))) as.character(v) else def
  }
  cell_id <- gc0("cell_id", sprintf("n%d_p%d_q%d_s%d", n, p, q, seed))
  design  <- gc0("design",  sprintf("n%d_p%d_q%d", n, p, q))
  stratum <- gc0("stratum", sprintf("n%d_q%d", n, q))
  grp <- gc0("grp", if (!is.null(cell$rel_frob) && is.finite(cell$rel_frob)) {
    if (cell$rel_frob > 10) "degenerate" else "healthy"
  } else NA_character_)

  base <- data.frame(
    cell_id = cell_id, design = design, stratum = stratum, grp = grp,
    n = n, p = p, q = q, seed = seed,
    rel_frob_ref = if (is.null(cell$rel_frob)) NA_real_ else as.numeric(cell$rel_frob),
    stringsAsFactors = FALSE)

  fail <- function(status, msg = "") {
    cbind(base, data.frame(
      fit_objective = NA_real_, fit_convergence = NA_integer_, fit_pdhess = NA,
      lambda_q_hat = NA_real_, lambda_1_hat = NA_real_, eig_ratio = NA_real_,
      frob_lambda = NA_real_, curvature = NA_real_, curvature_method = NA_character_,
      halfwidth_lo = NA_real_, halfwidth_hi = NA_real_,
      halfwidth_lo_reached = NA, halfwidth_hi_reached = NA, flat_flag = NA,
      delta_nll_at_grid_edges = NA_character_,
      delta_nll_edge_lo = NA_real_, delta_nll_edge_hi = NA_real_,
      max_delta_nll = NA_real_, min_delta_nll = NA_real_, better_optimum_found = NA,
      grid_lo_logfac = NA_real_, grid_hi_logfac = NA_real_,
      penalty_bound_ok = NA, max_abs_log_bind_err = NA_real_,
      n_bind_fail = NA_integer_,
      sanity_nll_center = NA_real_, sanity_abs_diff = NA_real_, sanity_ok = NA,
      n_grid = 0L, n_grid_ok = 0L,
      elapsed_s = as.numeric(difftime(Sys.time(), t0, units = "secs")),
      status = status, message = substr(msg, 1, 200), stringsAsFactors = FALSE))
  }

  ## body in its own function so an early return() cannot skip the CSV append
  body_fn <- function() {
    dat <- arc0_data(n, p, q, seed)
    fit <- arc0_fit(dat)
    if (is.null(fit) || is.null(fit$opt)) return(fail("fit-failed"))

    sp <- arc0_spectrum(fit, p, q)
    tr <- arc0_trailing(fit, p, q)
    u  <- as.numeric(tr$vec); u <- u / sqrt(sum(u * u))
    lam_q <- as.numeric(tr$val); lam_1 <- max(sp$ev)
    if (!is.finite(lam_q) || lam_q <= 0) return(fail("trailing-nonpositive"))

    obj   <- fit$tmb_obj
    par0  <- unname(fit$opt$par)
    nll0  <- as.numeric(fit$opt$objective)
    ix_th <- which(names(fit$opt$par) == "theta_rr_B")
    lay   <- arc0_theta_layout(p, q)
    if (length(ix_th) != lay$nt) return(fail("theta-length-mismatch"))

    ## ANCHOR GUARD (lib.R trap 2): fn(opt$par) must reproduce opt$objective.
    ## Compared stripped of names AND attributes -- TMB hangs a `logarithm`
    ## attribute off the returned value, which makes all.equal() report a
    ## spurious mismatch even when the numbers agree to machine precision.
    chk <- as.vector(tryCatch(obj$fn(par0), error = function(e) NA_real_))
    if (!is.finite(chk) || !is.finite(nll0) ||
        abs(chk - nll0) > 1e-6 * max(1, abs(nll0))) {
      return(fail("anchor-mismatch",
                  sprintf("fn(opt$par)=%.8g objective=%.8g", chk, nll0)))
    }
    ## Also confirm the packing map reproduces the reported Lambda_B here.
    Lrep <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
    Lmap <- arc0_lambda_from_theta(par0[ix_th], lay, p, q)
    if (max(abs(Lrep - Lmap)) > 1e-8) return(fail("packing-map-mismatch"))

    ## --- GRID: multiplicative in lambda_q, i.e. equally spaced in log --------
    ## Natural-log offsets. The +-0.25 pair exists specifically to give a local,
    ## well-conditioned second difference for the curvature. Outer reach exp(6)
    ## ~ 400x, extended adaptively below when Delta-nll has not reached 1.92.
    off     <- c(0, 0.25, 0.5, 1, 2, 3, 4.5, 6)
    grid_up <- off[-1]
    grid_dn <- -off[-1]

    rows <- list(); k <- 0L
    push <- function(offset, sol, tau) {
      k <<- k + 1L
      rows[[k]] <<- data.frame(
        cell_id = cell_id, log_fac_req = offset, tau = tau,
        achieved_lambda_q = sol$achieved, nll = sol$nll,
        log_fac_ach = log(max(sol$achieved, 1e-300) / lam_q),
        bind_err = log(max(sol$achieved, 1e-300)) - log(tau),
        conv = sol$conv, stringsAsFactors = FALSE)
    }

    ## centre first -- this is the mandatory sanity check
    sol0 <- arc0_solve_tau(obj, par0, ix_th, lay, p, q, u, lam_q)
    push(0, sol0, lam_q)
    sanity_nll  <- sol0$nll
    sanity_diff <- abs(sanity_nll - nll0)
    start_out <- if (is.finite(sol0$nll)) sol0$par else par0

    ## walk outward in each direction, warm-starting from the previous solution
    walk <- function(offsets, start_par) {
      cur <- start_par
      for (o in offsets) {
        s <- arc0_solve_tau(obj, cur, ix_th, lay, p, q, u, lam_q * exp(o))
        push(o, s, lam_q * exp(o))
        if (is.finite(s$nll)) cur <- s$par
      }
      cur
    }
    cur_up <- walk(grid_up, start_out)
    cur_dn <- walk(grid_dn, start_out)

    ## adaptive extension: keep pushing out while Delta-nll has not hit 1.92
    dnll_of <- function(o) {
      d <- do.call(rbind, rows); r <- d[abs(d$log_fac_req - o) < 1e-9, , drop = FALSE]
      if (!nrow(r) || !is.finite(r$nll[1])) NA_real_ else r$nll[1] - nll0
    }
    extend <- function(sgn, cur) {
      last <- sgn * max(off)
      for (e in seq_len(max_extend)) {
        d <- dnll_of(last)
        if (is.finite(d) && d >= 1.92) break
        last <- last + sgn * 2
        s <- arc0_solve_tau(obj, cur, ix_th, lay, p, q, u, lam_q * exp(last))
        push(last, s, lam_q * exp(last))
        if (is.finite(s$nll)) cur <- s$par else break
      }
    }
    extend(+1, cur_up)
    extend(-1, cur_dn)

    cur <- do.call(rbind, rows)
    cur <- cur[order(cur$log_fac_req), , drop = FALSE]
    ok  <- is.finite(cur$nll) & is.finite(cur$achieved_lambda_q) &
      cur$achieved_lambda_q > 0

    ## Reference nll: the fitted optimum, UNLESS a constrained solve beat it --
    ## which would be H1 evidence and is flagged separately as
    ## better_optimum_found rather than being quietly absorbed.
    nll_ref <- min(c(nll0, cur$nll[ok]), na.rm = TRUE)
    cur$delta_nll <- cur$nll - nll_ref
    ## x = log(ACHIEVED lambda_q / fitted lambda_q). Achieved, never requested:
    ## a quadratic penalty binds approximately, so the requested tau is not the
    ## abscissa the nll was actually evaluated at.
    cur$x <- cur$log_fac_ach

    if (!is.null(curves_csv)) {
      arc0_append_csv(data.frame(
        cell_id = cur$cell_id, tau = cur$tau,
        achieved_lambda_q = cur$achieved_lambda_q, nll = cur$nll,
        delta_nll = cur$delta_nll, log_fac_req = cur$log_fac_req,
        log_fac_ach = cur$log_fac_ach, bind_err = cur$bind_err, conv = cur$conv,
        stringsAsFactors = FALSE), curves_csv)
    }

    d <- cur[ok, , drop = FALSE]
    if (!nrow(d)) return(fail("all-grid-failed"))

    ## binding check -- 2% in log lambda_q; with mu = 1e6 the observed residual
    ## is orders of magnitude smaller, so a breach means the penalty genuinely
    ## lost to the likelihood and the point is not on the constraint surface.
    bind_tol    <- 0.02
    bind_err    <- abs(d$bind_err)
    n_bind_fail <- sum(bind_err > bind_tol)
    bound_ok    <- n_bind_fail == 0L

    ## --- curvature: d2 nll / d(log lambda_q)^2 at the optimum ---------------
    ## Unequal-spacing 3-point second difference on the +-0.25 pair and the
    ## centre, in ACHIEVED x. Falls back to a local quadratic LS fit over |x|<=1.
    curvature <- NA_real_; cmeth <- "none"
    near <- d[abs(d$log_fac_req) <= 0.25 + 1e-9, , drop = FALSE]
    if (nrow(near) == 3L && length(unique(sign(near$log_fac_req))) == 3L) {
      near <- near[order(near$x), , drop = FALSE]
      x0 <- near$x[1]; x1 <- near$x[2]; x2 <- near$x[3]
      f0 <- near$nll[1]; f1 <- near$nll[2]; f2 <- near$nll[3]
      if (x0 < x1 && x1 < x2) {
        curvature <- 2 * (f0 * (x2 - x1) - f1 * (x2 - x0) + f2 * (x1 - x0)) /
          ((x1 - x0) * (x2 - x1) * (x2 - x0))
        cmeth <- "fd3"
      }
    }
    if (!is.finite(curvature)) {
      loc <- d[abs(d$x) <= 1, , drop = FALSE]
      if (nrow(loc) >= 3L) {
        cf <- tryCatch(stats::coef(stats::lm(nll ~ x + I(x^2), data = loc)),
                       error = function(e) NULL)
        if (!is.null(cf) && length(cf) == 3L && is.finite(cf[3])) {
          curvature <- 2 * unname(cf[3]); cmeth <- "quad-ls"
        }
      }
    }

    ## --- half-widths: FIRST crossing of Delta-nll = 1.92 on each side -------
    centre_delta <- d$delta_nll[which.min(abs(d$log_fac_req))]
    cross <- function(sgn) {
      s <- if (sgn > 0) d[d$x > 0, , drop = FALSE] else d[d$x < 0, , drop = FALSE]
      if (!nrow(s)) return(c(NA_real_, 0))
      s  <- s[order(abs(s$x)), , drop = FALSE]
      xs <- c(0, s$x); ys <- c(centre_delta, s$delta_nll)
      for (i in seq_along(xs)[-1]) {
        if (is.finite(ys[i]) && ys[i] >= 1.92) {
          if (!is.finite(ys[i - 1]) || ys[i] == ys[i - 1]) return(c(exp(xs[i]), 1))
          w <- (1.92 - ys[i - 1]) / (ys[i] - ys[i - 1])
          return(c(exp(xs[i - 1] + w * (xs[i] - xs[i - 1])), 1))
        }
      }
      c(NA_real_, 0)
    }
    ch <- cross(+1); cl <- cross(-1)

    edge_hi <- if (any(d$x > 0)) d$delta_nll[which.max(d$x)] else NA_real_
    edge_lo <- if (any(d$x < 0)) d$delta_nll[which.min(d$x)] else NA_real_
    flat <- max(d$delta_nll) < 1.92

    cbind(base, data.frame(
      fit_objective = nll0,
      fit_convergence = as.integer(fit$opt$convergence),
      fit_pdhess = isTRUE(fit$sd_report$pdHess),
      lambda_q_hat = lam_q, lambda_1_hat = lam_1, eig_ratio = lam_q / lam_1,
      frob_lambda = sp$frob,
      curvature = curvature, curvature_method = cmeth,
      halfwidth_lo = cl[1], halfwidth_hi = ch[1],
      halfwidth_lo_reached = cl[2] == 1, halfwidth_hi_reached = ch[2] == 1,
      flat_flag = flat,
      delta_nll_at_grid_edges = sprintf("%.6g;%.6g", edge_lo, edge_hi),
      delta_nll_edge_lo = edge_lo, delta_nll_edge_hi = edge_hi,
      max_delta_nll = max(d$delta_nll), min_delta_nll = min(d$delta_nll),
      better_optimum_found = (nll_ref < nll0 - 1e-3),
      grid_lo_logfac = min(cur$log_fac_req), grid_hi_logfac = max(cur$log_fac_req),
      penalty_bound_ok = bound_ok, max_abs_log_bind_err = max(bind_err),
      n_bind_fail = as.integer(n_bind_fail),
      sanity_nll_center = sanity_nll, sanity_abs_diff = sanity_diff,
      sanity_ok = is.finite(sanity_diff) && sanity_diff < 1e-2,
      n_grid = nrow(cur), n_grid_ok = as.integer(sum(ok)),
      elapsed_s = as.numeric(difftime(Sys.time(), t0, units = "secs")),
      status = if (!bound_ok) "penalty-not-bound" else "ok",
      message = "", stringsAsFactors = FALSE))
  }

  res <- tryCatch(body_fn(), error = function(e) fail("error", conditionMessage(e)))
  if (!is.null(out_csv)) arc0_append_csv(res, out_csv)
  res
}

## --- cell table --------------------------------------------------------------
## Accepts the raw campaign grid (/tmp/grid-ref.csv) or any pre-filtered table.
arc0_read_cells <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (all(c("arm", "family", "rel_frob") %in% names(x))) {
    x <- x[x$arm == "gtmb_laplace" & x$family == "bernoulli" &
             is.finite(x$rel_frob), , drop = FALSE]
    x$grp <- ifelse(x$rel_frob > 10, "degenerate", "healthy")
  }
  stopifnot(all(c("n", "p", "q", "seed") %in% names(x)))
  x
}

## --- main --------------------------------------------------------------------
arc0_t2_main <- function() {
  a <- commandArgs(trailingOnly = TRUE)
  gv <- function(i, env, def) {
    if (length(a) >= i && nzchar(a[i])) a[i] else
      if (nzchar(Sys.getenv(env))) Sys.getenv(env) else def
  }
  cells_csv  <- gv(1, "ARC0_CELLS",  "/tmp/grid-ref.csv")
  out_csv    <- gv(2, "ARC0_OUT",    file.path(ARC0_DIR, "profile.csv"))
  curves_csv <- gv(3, "ARC0_CURVES", file.path(ARC0_DIR, "profile-curves.csv"))
  mx <- as.integer(Sys.getenv("ARC0_MAX_EXTEND", "4"))

  g <- arc0_check_pen_grad()
  cat(sprintf("[arc0-T2] penalty-gradient self-check (rel max err): %.3e\n", g))
  stopifnot(g < 1e-5)

  arc0_load()
  cells <- arc0_read_cells(cells_csv)
  if (nzchar(Sys.getenv("ARC0_ROW"))) {
    cells <- cells[as.integer(Sys.getenv("ARC0_ROW")), , drop = FALSE]
  }
  if (nzchar(Sys.getenv("ARC0_MAX_CELLS"))) {
    cells <- utils::head(cells, as.integer(Sys.getenv("ARC0_MAX_CELLS")))
  }
  cat(sprintf("[arc0-T2] %d cells | out=%s | curves=%s\n",
              nrow(cells), out_csv, curves_csv))

  ## Sequential on purpose: the caller owns the parallelism (mclapply over
  ## arc0_profile_cell). Spawning workers here would oversubscribe.
  invisible(lapply(seq_len(nrow(cells)), function(i) {
    r <- arc0_profile_cell(cells[i, , drop = FALSE], out_csv, curves_csv, mx)
    cat(sprintf(
      paste0("[arc0-T2] %-16s %-11s lam_q=%-10.4g curv=%-11.4g flat=%-5s ",
             "bind_ok=%-5s hw=(%.4g, %.4g) sanity=%.2e n=%d %6.1fs %s\n"),
      r$cell_id, r$grp, r$lambda_q_hat, r$curvature, r$flat_flag,
      r$penalty_bound_ok, r$halfwidth_lo, r$halfwidth_hi, r$sanity_abs_diff,
      r$n_grid, r$elapsed_s, r$status))
    NULL
  }))
}

if (!nzchar(Sys.getenv("ARC0_NO_MAIN")) &&
    any(grepl("20-profile\\.R", commandArgs(trailingOnly = FALSE)))) {
  arc0_t2_main()
}
