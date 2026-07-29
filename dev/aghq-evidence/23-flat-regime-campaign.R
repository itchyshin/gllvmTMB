## ============================================================================
## FLAT-REGIME MAP — elevating S3's finding from 10 seeds to house standard,
## and settling the one confound S3 explicitly left open.
##
## THREE QUESTIONS, ONE GRID:
##  Q1 (DECISIVE, never run): is the near-flatness INHERENT (Rabe-Hesketh
##      small-cluster/high-signal mechanism) or an ARTEFACT of the DGP's
##      pmin(eta, 6) linear-predictor cap? Arm: eta_cap TRUE vs FALSE.
##      If the stall persists uncapped -> inherent. If it vanishes -> artefact,
##      and S3's practical guidance changes completely.
##  Q2: the REGIME MAP. S3 showed family is NOT the discriminator (gaussian
##      stalled 5/5 where poisson did not). Test that properly across
##      family x lam_sd x n.
##  Q3: the MATERIALITY FLOOR. S3's ~3e-4 came from ONE fixture. We need the
##      DISTRIBUTION of par_shift under a correctly-working engine (cap raised
##      so the n_ok>=2 labelling defect cannot fire).
##  Q4 (NEW, from the S2 literature sweep 2026-07-28 — a THIRD hypothesis S3
##      never considered): is the flatness a QUADRATURE artefact? The gllamm /
##      adaptive-quadrature literature reports that with TOO FEW quadrature
##      points the log-likelihood goes FLAT IN THE COVARIANCE PARAMETERS and
##      posterior SDs are computed as spuriously EXACTLY ZERO — numerically
##      indistinguishable from a true boundary estimate. S3 ran everything at
##      aghq = 9. Arm: aghq_k in {9, 25, 51}. If the flatness dissolves as
##      nodes rise, it is a quadrature-regime artefact and NOT the
##      Rabe-Hesketh mechanism — which would change the arc's conclusion again.
##      This also bears directly on the orphan note
##      docs/dev-log/2026-07-22-quadrature-regime-trap-*.md.
##
## The three hypotheses are mutually distinguishable by this grid:
##   H1 DGP artefact   -> stall vanishes when eta_cap = FALSE
##   H2 inherent regime -> stall tracks lam_sd, survives both other arms
##   H3 quadrature      -> stall vanishes as aghq_k rises
##
## USAGE:  Rscript flat-regime-campaign.R <arm> <n_seeds> <n_cores> <outfile>
##   arm = "smoke" | "regime" | "materiality"
## The SAME code path serves smoke and full run, so the smoke cannot pass while
## the real run takes a different branch.
## ============================================================================

args     <- commandArgs(trailingOnly = TRUE)
arm      <- if (length(args) >= 1) args[1] else "smoke"
n_seeds  <- if (length(args) >= 2) as.integer(args[2]) else 2L
n_cores  <- if (length(args) >= 3) as.integer(args[3]) else 2L
outfile  <- if (length(args) >= 4) args[4] else sprintf("flat-regime-%s.csv", arm)

Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressMessages(library(parallel))

PKG <- Sys.getenv("GLLVM_SRC", unset = "/private/tmp/gllvmtmb-arc0-identifiability")
LIB <- Sys.getenv("GLLVM_LIB", unset = "")
if (nzchar(LIB)) {
  .libPaths(c(LIB, .libPaths()))
  suppressMessages(library(gllvmTMB))
  cat("Loaded installed gllvmTMB from", LIB, "\n")
} else {
  suppressMessages(devtools::load_all(PKG, quiet = TRUE))
  cat("load_all() from", PKG, "\n")
}

## ---- DGP -------------------------------------------------------------------
## Identical to S3's mk() (itself copied from dev/aghq-evidence/21-wide-factorial.R)
## EXCEPT that the pmin(eta, 6) cap is now a controlled FACTOR, not a constant.
## That single change is what makes Q1 answerable.
mk <- function(n, p, q, lam_sd, seed, fam, eta_cap) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- if (fam == "binomial") rnorm(p, 0.3, 0.4) else rnorm(p, 0.8, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  eta_used <- if (eta_cap) pmin(eta, 6) else eta
  Y <- switch(fam,
    poisson  = matrix(rpois(n * p, exp(eta_used)), n, p),
    binomial = matrix(rbinom(n * p, 1L, plogis(eta_used)), n, p),
    gaussian = matrix(rnorm(n * p, eta_used, 1), n, p),
    stop("unknown family: ", fam))
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml,
       eta_max = max(eta), frac_capped = mean(eta > 6))
}

fam_obj <- function(fam) switch(fam,
  poisson = poisson(), binomial = binomial(), gaussian = gaussian())

## ---- one cell --------------------------------------------------------------
run_one <- function(cfg) {
  t0 <- Sys.time()
  out <- tryCatch({
    d <- mk(cfg$n, cfg$p, cfg$q, cfg$lam_sd, cfg$seed, cfg$fam, cfg$eta_cap)
    ctl_args <- list(n_init = 1L, init_jitter = 0, se = FALSE,
                     aghq = as.integer(cfg$aghq_k), aghq_ridge = Inf)
    ## aghq_iter_cap IS a real formal argument (R/gllvmTMB.R:1208-1226) — verified
    ## by S3; the other six aghq_* tunables are NOT and are silently dropped.
    if (!is.na(cfg$iter_cap)) ctl_args$aghq_iter_cap <- as.integer(cfg$iter_cap)
    fit <- suppressWarnings(gllvmTMB(
      d$fml, data = d$df, family = fam_obj(cfg$fam),
      control = do.call(gllvmTMBcontrol, ctl_args)))
    a <- fit$aghq
    data.frame(
      cfg[c("fam", "n", "p", "q", "lam_sd", "eta_cap", "seed", "iter_cap", "aghq_k")],
      par_shift   = if (is.null(a$par_shift)) NA_real_ else a$par_shift,
      passes      = if (is.null(a$passes)) NA_integer_ else a$passes,
      aghq_used   = if (is.null(a$used)) NA else a$used,
      stop_reason = if (is.null(a$stop_reason)) NA_character_ else a$stop_reason,
      stalled     = if (is.null(a$stop_reason)) NA else grepl("^STALLED", a$stop_reason),
      objective   = tryCatch(as.numeric(fit$opt$objective), error = function(e) NA_real_),
      convergence = tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_),
      eta_max     = d$eta_max, frac_capped = d$frac_capped,
      error       = NA_character_, stringsAsFactors = FALSE)
  }, error = function(e) data.frame(
      cfg[c("fam", "n", "p", "q", "lam_sd", "eta_cap", "seed", "iter_cap", "aghq_k")],
      par_shift = NA_real_, passes = NA_integer_, aghq_used = NA,
      stop_reason = NA_character_, stalled = NA, objective = NA_real_,
      convergence = NA_integer_, eta_max = NA_real_, frac_capped = NA_real_,
      error = conditionMessage(e), stringsAsFactors = FALSE))
  out$elapsed_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## ---- grids -----------------------------------------------------------------
grid_for <- function(arm, n_seeds) {
  base <- switch(arm,
    smoke = expand.grid(
      fam = c("poisson", "gaussian"), lam_sd = c(0.5, 3), n = 200L,
      eta_cap = c(TRUE, FALSE), iter_cap = NA_integer_, aghq_k = c(9L, 51L),
      stringsAsFactors = FALSE),
    ## Q1 + Q2. Default cap (the SHIPPED behaviour) — this is the regime map.
    regime = expand.grid(
      fam = c("poisson", "binomial", "gaussian"),
      lam_sd = c(0.5, 1, 2, 3), n = c(100L, 200L, 400L),
      eta_cap = c(TRUE, FALSE), iter_cap = NA_integer_, aghq_k = c(9L, 25L, 51L),
      stringsAsFactors = FALSE),
    ## Q3. Cap raised so the n_ok>=2 labelling defect cannot fire, giving the
    ## honest converged par_shift. SLOW (S3 saw 235 passes at cap 2), so a
    ## deliberately smaller grid.
    materiality = expand.grid(
      fam = c("poisson", "binomial", "gaussian"),
      lam_sd = c(0.5, 1, 2, 3), n = 200L,
      eta_cap = c(TRUE, FALSE), iter_cap = 25L, aghq_k = c(9L, 51L),
      stringsAsFactors = FALSE),
    stop("unknown arm"))
  base$p <- 6L; base$q <- 1L
  cells <- do.call(rbind, lapply(seq_len(nrow(base)), function(i)
    do.call(rbind, lapply(seq_len(n_seeds), function(s) {
      r <- base[i, , drop = FALSE]; r$seed <- 2000L + s; r
    }))))
  cells[order(cells$fam, cells$lam_sd, cells$n, cells$eta_cap, cells$aghq_k, cells$seed), ]
}

cells <- grid_for(arm, n_seeds)
cfgs  <- split(cells, seq_len(nrow(cells)))
cat(sprintf("ARM=%s  cells=%d (%d configs x %d seeds)  cores=%d\n",
            arm, length(cfgs), nrow(cells) / n_seeds, n_seeds, n_cores))
cat(sprintf("OUT=%s\n", outfile))

## ---- FIRST CELL EARLY, then scale -------------------------------------------
## Discipline: read cell 1's output before committing the grid. A run that
## returns all-NA silently is the failure mode this guards against.
cat("\n--- first cell (early abort check) ---\n")
first <- run_one(cfgs[[1]])
print(first[, c("fam", "lam_sd", "n", "eta_cap", "aghq_k", "seed", "par_shift",
                "passes", "stalled", "elapsed_s", "error")])
if (!is.na(first$error)) {
  stop("FIRST CELL ERRORED — aborting before the grid: ", first$error)
}
if (is.na(first$par_shift)) {
  stop("FIRST CELL returned NA par_shift — aborting; guard-blocked or misconfigured.")
}
cat(sprintf("first cell OK in %.1fs -> projected serial %.1f h, at %d cores ~%.2f h\n",
            first$elapsed_s, first$elapsed_s * length(cfgs) / 3600,
            n_cores, first$elapsed_s * length(cfgs) / 3600 / n_cores))

incfile <- sub("\\.csv$", "-inc.csv", outfile)
write.csv(first, incfile, row.names = FALSE)

if (length(cfgs) > 1L) {
  rest <- cfgs[-1]
  res <- mclapply(rest, function(cfg) {
    r <- run_one(cfg)
    ## incremental append — a killed run keeps everything already computed
    ## crash insurance only; 150 parallel appenders can interleave, so the
    ## AUTHORITATIVE result is the returned list combined below, not this file.
    try(write.table(r, incfile, sep = ",", append = TRUE,
                col.names = FALSE, row.names = FALSE, qmethod = "double"),
        silent = TRUE)
    r
  }, mc.cores = n_cores, mc.preschedule = FALSE)
  ok <- vapply(res, function(x) inherits(x, "data.frame"), logical(1))
  cat(sprintf("\ncompleted %d/%d additional cells (%d returned non-data.frame)\n",
              sum(ok), length(rest), sum(!ok)))
  ## authoritative combine from returned objects (immune to append interleaving)
  all_rows <- do.call(rbind, c(list(first), res[ok]))
  write.csv(all_rows, outfile, row.names = FALSE)
  cat(sprintf("wrote %d rows to %s\n", nrow(all_rows), outfile))
}

## ---- summary ---------------------------------------------------------------
tab <- tryCatch(read.csv(outfile, stringsAsFactors = FALSE), error = function(e) NULL)
if (!is.null(tab) && nrow(tab)) {
  cat("\n==== FIT HEALTH (report this BESIDE any rate, never complete-case alone) ====\n")
  cat(sprintf("total cells: %d | errored: %d | NA par_shift: %d | usable: %d\n",
              nrow(tab), sum(!is.na(tab$error)), sum(is.na(tab$par_shift)),
              sum(is.na(tab$error) & !is.na(tab$par_shift))))
  u <- tab[is.na(tab$error) & !is.na(tab$par_shift), ]
  if (nrow(u)) {
    cat("\n==== STALL RATE by family x lam_sd x eta_cap ====\n")
    agg <- aggregate(cbind(stalled = u$stalled, par_shift = u$par_shift),
                     by = list(fam = u$fam, lam_sd = u$lam_sd, n = u$n,
                               eta_cap = u$eta_cap, aghq_k = u$aghq_k),
                     FUN = mean, na.rm = TRUE)
    agg$n_cells <- aggregate(u$par_shift,
                     by = list(fam = u$fam, lam_sd = u$lam_sd, n = u$n,
                               eta_cap = u$eta_cap, aghq_k = u$aghq_k),
                     FUN = length)$x
    ## MCSE on a proportion — so nobody quotes a rate without its uncertainty
    agg$mcse <- sqrt(agg$stalled * (1 - agg$stalled) / agg$n_cells)
    print(agg[order(agg$fam, agg$n, agg$lam_sd, agg$eta_cap, agg$aghq_k), ], row.names = FALSE)

    cat("\n==== Q1 — THE DECISIVE CONTRAST: eta capped vs uncapped ====\n")
    q1 <- aggregate(u$stalled, by = list(eta_cap = u$eta_cap, fam = u$fam), FUN = mean)
    names(q1)[3] <- "stall_rate"
    print(q1, row.names = FALSE)
    cat("\nIf stall rate is ~unchanged uncapped -> flatness is INHERENT (Rabe-Hesketh).\n")
    cat("If it collapses uncapped -> it was a pmin(eta,6) DGP ARTEFACT.\n")
  }
}
cat("\nDONE\n")
