## Design 108 s0.2 -- silent-divergence rate of the SHIPPED Laplace engine.
##
## Question: at what rate does the shipped Laplace route (already fitting
## binomial-probit, ordinal_probit, and missing-response data with no code
## changes) converge to a DEGENERATE loading while reporting a CLEAN
## convergence code -- across those three surfaces, at realistic size, with
## and without the aghq_ridge=2 remedy? This prices whether the 26-42 day
## Gate-A programme is worth running.
##
## REUSED (read in full before writing this file):
##   * dev/totoro-grid/run-grid.R -- the Totoro mirai-daemon runner idiom:
##     GRID_SMOKE / GRID_WORKERS env vars, daemons()/mirai_map()/.progress,
##     OPENBLAS_NUM_THREADS=1 pinned inside every worker, results written to
##     ~/gllvm_work/results as both .rds and .csv. Carried over unchanged.
##   * dev/heywood/link-coverage.R -- the probit fit+score idiom: a per-trait
##     "homog" loading_sd DGP, tcrossprod(Lambda_B) rel_frob against the true
##     Sigma_B = Lambda Lambda', check_gllvmTMB()'s binomial_prevalence_loading
##     row, .gllvmTMB_max_loading_by_trait(). NOTE: that script's OTHER two DGP
##     arms (sparse50, sparse75) are adversarial-by-design (built to manufacture
##     failures for detector calibration, ~73% degenerate under sparse75) -- this
##     campaign deliberately uses ONLY the "homog" arm. See README section
##     "Why this DGP is realistic".
##   * dev/heywood/missing-and-spatial-coverage.R PART 1 -- the missing-data
##     idiom: inject NA into a fraction of the flattened response vector
##     post-hoc, fit with the package DEFAULT missing-data handling
##     (miss_control(response = "drop")), which already exercises the
##     src/gllvmTMB.cpp:142 missing-response path -- no explicit
##     miss_control(response = "include") call is needed to reach it.
##   * dev/degeneracy/DETECTOR.md -- the metric definition: rel_frob =
##     ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F on the rotation-invariant
##     Sigma_B = Lambda Lambda', degenerate at rel_frob > 10, "silent" means
##     that AND the fit's own convergence == 0 & pdHess == TRUE.
##
## THE RIDGE ARM (R/gllvmTMB.R:1454, 1496-1512, verified by reading, not
## re-derived): `aghq_ridge` DEFAULTS to 2 as a gllvmTMBcontrol() ARGUMENT, but
## on the Laplace path it is OPT-IN ONLY -- it fires when the caller explicitly
## NAMES aghq_ridge (missing(aghq_ridge) == FALSE), never from the default. So:
##   arm "default" -> control = gllvmTMBcontrol()                 (ridge inert)
##   arm "ridge2"  -> control = gllvmTMBcontrol(aghq_ridge = 2)   (ridge fires)
## This is the single most important design requirement per the brief: without
## it we would only ever measure the un-remedied rate, which
## docs/dev-log/2026-07-30-heywood-gate-false-positive-sweep.md section 7
## already showed can be fixed (||Lambda||_F 979.1 -> 3.352 on ONE reproduction
## fit, on the Laplace path) -- i.e. the problem this campaign prices may
## already be closed by a one-line control change.
##
## THE sigma_lambda AXIS (added after the maintainer caught that the first
## design never visited the ridge's OWN documented failure regime;
## R/gllvmTMB.R:909-911, issue #847): "the remedy has a measured failure
## regime of its own (`aghq_ridge = 2` still runs away in 67% of fits at
## n = 1600, sigma_lambda = 3; see #847)". The original DGP used only the
## mild "homog" loading SD of 0.7, so a "ridge fixes silent divergence"
## conclusion drawn from that grid alone would never have visited the regime
## where the ridge is already known to fail most of the time.
## `sigma_lambda in {0.7, 3.0}` is now crossed with `arm` (and every other
## factor) throughout, and the large-n rung moved from 1500 to 1600 so that
## cell sits exactly on the #847 measurement rather than merely near it.
##
## MEASURED-BASIS REVISION (after a real Totoro probe at n=1600, p=27, q=2,
## binomial-probit, sigma_lambda=3: default 37.6s / rel_frob 0.178 / conv 0;
## ridge2 35.2s / rel_frob 0.148 / conv 0 -- ONE seed, neither arm diverged
## there). That priced replication as cheap, so: Part A's p axis is RESTORED
## to {12, 27} (was swapped for sigma_lambda under an affordability
## constraint that no longer binds) and its seed raised 10 -> 20; Part B's
## seed raised 3 -> 30 for a usable rate estimate against #847's 67%. See
## README "What was traded (revised on measured Totoro cost)".
##
## Compute: Totoro, <= 96 workers per the brief's ceiling. Results stay LOCAL
## (D-50) -- never a GitHub artifact, never committed as a CSV.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(mirai)
})

OUT <- file.path(Sys.getenv("HOME"), "gllvm_work", "results")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SMOKE  <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
NWORK  <- as.integer(Sys.getenv("GRID_WORKERS", "96"))

## ---------------------------------------------------------------- design ---
## PART A: moderate, realistic n ladder, full factorial across every arm,
## sigma_lambda, AND p. p was briefly swapped out for sigma_lambda under an
## affordability constraint that no longer binds once the Totoro n=1600 probe
## measured real per-fit costs (~37s at the largest cell, sub-2s at the
## smallest) -- see README "What was traded". p is RESTORED to {12, 27}
## (Ayumi's p = 27) and seed raised 10 -> 20 (small-n fits are cheap, and
## small n is where the signal likely concentrates -- see README).
partA <- expand.grid(
  family      = c("binomial_probit", "ordinal_probit", "gaussian_control"),
  miss        = c(0, 0.3),
  arm         = c("default", "ridge2"),
  sigma_lambda = c(0.7, 3.0),
  n           = c(60L, 150L, 400L),
  p           = c(12L, 27L),
  seed        = 1:20,
  stringsAsFactors = FALSE
)

## PART B: one large-n rung, n = 1600 (sits EXACTLY on the #847 measurement:
## "aghq_ridge = 2 still runs away in 67% of fits at n = 1600, sigma_lambda =
## 3"), at Ayumi's p = 27. seed raised 3 -> 30 now that a real Totoro probe
## measured ~35-38s/fit at this cell (binomial, sigma_lambda=3): 30 seeds is
## needed for a usable rate estimate against #847's 67% (3 seeds can only
## return 0/33/67/100%), and is affordable at that measured cost -- see
## README "What was traded".
partB <- expand.grid(
  family      = c("binomial_probit", "ordinal_probit", "gaussian_control"),
  miss        = c(0, 0.3),
  arm         = c("default", "ridge2"),
  sigma_lambda = c(0.7, 3.0),
  n           = 1600L,
  p           = 27L,
  seed        = 1:30,
  stringsAsFactors = FALSE
)

grid <- rbind(partA, partB)
grid$q <- 2L   ## fixed at Ayumi's q=2 throughout

if (SMOKE) {
  ## Mild corner (sigma_lambda=0.7, both arms) PLUS the new #847 worst-case
  ## corner (sigma_lambda=3.0, both arms) -- binomial_probit, miss=0, the
  ## smallest n/p, seed=1. 4 rows, stays fast.
  grid <- grid[grid$family == "binomial_probit" & grid$miss == 0 &
               grid$n == 60L & grid$p == 12L & grid$seed == 1L, ]
}

## Optional ad-hoc subsetting, for COSTING a single expensive corner through the
## campaign's OWN run_cell() rather than a re-implementation of it. Timing a
## separate hand-written probe measures the probe, not the campaign; this
## measures what will actually run. Filters are AND-ed and default to off, so
## an unset environment leaves the grid byte-identical.
##   GRID_FAMILY=ordinal_probit GRID_N=1600 GRID_SIGMA=3 GRID_MISS=0 GRID_SEEDS=1
.envf <- function(v) { x <- Sys.getenv(v, ""); if (nzchar(x)) x else NULL }
if (!is.null(.f <- .envf("GRID_FAMILY"))) grid <- grid[grid$family == .f, ]
if (!is.null(.f <- .envf("GRID_N")))      grid <- grid[grid$n == as.integer(.f), ]
if (!is.null(.f <- .envf("GRID_SIGMA")))  grid <- grid[grid$sigma_lambda == as.numeric(.f), ]
if (!is.null(.f <- .envf("GRID_MISS")))   grid <- grid[grid$miss == as.numeric(.f), ]
if (!is.null(.f <- .envf("GRID_SEEDS")))  grid <- grid[grid$seed <= as.integer(.f), ]
if (nrow(grid) == 0L) stop("GRID_* filters selected zero cells.", call. = FALSE)

## ------------------------------------------------------------------ cell ---
run_cell <- function(cell) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1")
  suppressPackageStartupMessages(library(gllvmTMB))
  relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")

  with(cell, {
    ## deterministic, cell-specific seed (mirrors the reused scripts' idiom
    ## of hashing every design factor into set.seed()).
    fam_ix <- match(family, c("binomial_probit", "ordinal_probit", "gaussian_control"))
    arm_ix <- as.integer(arm == "ridge2")
    sig_ix <- as.integer(sigma_lambda == 3.0)
    set.seed(seed * 9173L + n + p * 13L + round(miss * 100) +
              fam_ix * 7919L + arm_ix * 104729L + sig_ix * 251519L)

    ## "homog" DGP: uniform per-trait loading SD, no engineered sparsity or
    ## quasi-separation. Realistic, not adversarial -- see README. sigma_lambda
    ## is now a design factor (0.7 mild / 3.0 the #847 ridge-failure regime),
    ## not a hardcoded constant.
    sdl <- sigma_lambda
    Lam <- matrix(stats::rnorm(p * q, 0, sdl), p, q)
    Z   <- matrix(stats::rnorm(n * q), n, q)
    Sig_true <- Lam %*% t(Lam)
    eta <- Z %*% t(Lam)

    if (family == "binomial_probit") {
      B <- stats::rnorm(p, 0, 0.3)
      lp <- eta + matrix(B, n, p, byrow = TRUE)
      yv <- stats::rbinom(n * p, 1, stats::pnorm(as.numeric(t(lp))))
      resp_name <- "y"
      fam_r <- stats::binomial(link = "probit")
    } else if (family == "ordinal_probit") {
      alpha <- stats::rnorm(p, 0, 0.3)
      taus <- c(0, 0.7, 1.4)   ## K = 4, matches test-ordinal-recovery-depth.R
      lp <- eta + matrix(alpha, n, p, byrow = TRUE)
      ystar <- as.numeric(t(lp)) + stats::rnorm(n * p)
      yv <- 1L + (ystar > taus[1]) + (ystar > taus[2]) + (ystar > taus[3])
      resp_name <- "value"
      fam_r <- gllvmTMB::ordinal_probit()
    } else {  ## gaussian_control -- positive control, MUST recover
      B <- stats::rnorm(p, 0, 0.3)
      lp <- eta + matrix(B, n, p, byrow = TRUE)
      yv <- as.numeric(t(lp)) + stats::rnorm(n * p, 0, 0.4)
      resp_name <- "y"
      fam_r <- stats::gaussian()
    }

    if (miss > 0) {
      drop <- sample.int(length(yv), floor(length(yv) * miss))
      yv[drop] <- NA
    }

    dat <- data.frame(
      trait = factor(rep(seq_len(p), times = n)),
      site  = factor(rep(seq_len(n), each = p))
    )
    dat[[resp_name]] <- yv

    ## THE load-bearing design point: aghq_ridge is opt-in on the Laplace
    ## path, so the "default" arm must NOT name it.
    ctrl <- if (arm == "ridge2") gllvmTMB::gllvmTMBcontrol(aghq_ridge = 2)
            else                 gllvmTMB::gllvmTMBcontrol()

    fml <- stats::as.formula(sprintf(
      "%s ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
      resp_name, q))

    row0 <- function(secs, status = NA_character_, conv = NA_integer_,
                      pdhess = NA, obj = NA_real_, rf = NA_real_,
                      at = NA_real_, rl_max = NA_real_, max_loading = NA_real_,
                      check_status = NA_character_, note = "") {
      data.frame(family = family, miss = miss, arm = arm,
                 sigma_lambda = sigma_lambda, n = n, p = p,
                 q = q, seed = seed, seconds = secs, status = status,
                 convergence = conv, pdHess = pdhess, objective = obj,
                 rel_frob = rf, attenuation = at, rl_max = rl_max,
                 max_loading = max_loading, check_status = check_status,
                 silent_divergent = isTRUE(rf > 10 & identical(conv, 0L) & isTRUE(pdhess)),
                 note = note, stringsAsFactors = FALSE)
    }

    t0 <- proc.time()[["elapsed"]]
    r <- tryCatch(
      withCallingHandlers(
        gllvmTMB::gllvmTMB(fml, data = dat, unit = "site", family = fam_r,
                            control = ctrl),
        warning = function(w) invokeRestart("muffleWarning")),
      error = function(e) structure(list(msg = conditionMessage(e)),
                                     class = "cell_error"))
    secs <- proc.time()[["elapsed"]] - t0

    if (inherits(r, "cell_error"))
      return(row0(secs, status = "ERROR", note = r$msg))

    Lam_hat <- tryCatch(r$report$Lambda_B, error = function(e) NULL)
    conv <- tryCatch(as.integer(r$opt$convergence), error = function(e) NA_integer_)
    pdh  <- tryCatch(isTRUE(r$sd_report$pdHess), error = function(e) NA)
    obj  <- tryCatch(as.numeric(stats::logLik(r)), error = function(e) NA_real_)

    if (is.null(Lam_hat) || !is.matrix(Lam_hat) || !all(is.finite(Lam_hat)))
      return(row0(secs, status = "NO_LAMBDA", conv = conv, pdhess = pdh,
                   obj = obj, note = "Lambda_B missing or non-finite"))

    Sh <- tcrossprod(Lam_hat)
    rf <- relfrob(Sh, Sig_true)
    at <- sum(diag(Sh)) / sum(diag(Sig_true))

    lt  <- tryCatch(gllvmTMB:::.gllvmTMB_max_loading_by_trait(r), error = function(e) NULL)
    rlx <- if (!is.null(lt)) {
      v <- lt$relative_loading[is.finite(lt$relative_loading)]
      if (length(v)) max(v) else NA_real_
    } else NA_real_
    mlx <- if (!is.null(lt)) max(lt$max_loading, na.rm = TRUE) else NA_real_
    chk <- tryCatch(gllvmTMB::check_gllvmTMB(r), error = function(e) NULL)
    cst <- if (!is.null(chk)) {
      s <- chk$status[chk$component == "binomial_prevalence_loading"]
      if (length(s)) s[[1]] else NA_character_
    } else NA_character_

    row0(secs, status = "OK", conv = conv, pdhess = pdh, obj = obj, rf = rf,
         at = at, rl_max = rlx, max_loading = mlx, check_status = cst)
  })
}

## ------------------------------------------------------------------- run ---
cells <- split(grid, seq_len(nrow(grid)))
cat(sprintf("cells=%d  workers=%d  smoke=%s\n", length(cells), NWORK, SMOKE))

daemons(NWORK, dispatcher = TRUE)
on.exit(daemons(0), add = TRUE)
t0 <- proc.time()[["elapsed"]]
res <- mirai_map(cells, run_cell)[.progress]
elapsed <- proc.time()[["elapsed"]] - t0

ok <- vapply(res, is.data.frame, logical(1))
out <- do.call(rbind, res[ok])
tag <- if (SMOKE) "smoke" else "grid"
saveRDS(out, file.path(OUT, sprintf("design108-stage8-%s.rds", tag)))
write.csv(out, file.path(OUT, sprintf("design108-stage8-%s.csv", tag)), row.names = FALSE)

cat(sprintf("\nDONE in %.1f s | cells ok %d/%d | rows %d\n",
            elapsed, sum(ok), length(res), nrow(out)))
cat("status counts:\n"); print(table(out$status))
cat("\nsilent divergence rate overall (OK fits only):\n")
okrows <- out[out$status == "OK", ]
print(mean(okrows$silent_divergent, na.rm = TRUE))
cat("\nsilent divergence rate by family x arm:\n")
print(round(tapply(okrows$silent_divergent, list(okrows$family, okrows$arm), mean, na.rm = TRUE), 4))
cat("\nsilent divergence rate by family x miss:\n")
print(round(tapply(okrows$silent_divergent, list(okrows$family, okrows$miss), mean, na.rm = TRUE), 4))
cat("\nsilent divergence rate by sigma_lambda x arm (the #847 axis):\n")
print(round(tapply(okrows$silent_divergent, list(okrows$sigma_lambda, okrows$arm), mean, na.rm = TRUE), 4))
cat("\nhead:\n"); print(utils::head(out, 12))
