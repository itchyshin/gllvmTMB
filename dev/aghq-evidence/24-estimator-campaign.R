## =============================================================================
## 24 -- THE AGHQ ESTIMATOR CAMPAIGN (runner)
## =============================================================================
##
## Implements docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md. Read the design
## before touching this file; every choice here is justified there, not here.
##
## THE ONE DESIGN DECISION WORTH REPEATING IN THE CODE. Lambda_hat itself is stored for
## every fit (12 numbers, p*q). The primary estimand is therefore a POST-HOC choice: if
## the maintainer prefers Sigma_unit to the trait correlation (decision 1 in the design),
## nothing has to be re-run. That is deliberate -- it de-risks running the campaign before
## the estimand is approved, and it costs ~2 MB.
##
## ARMS (5 fits per replicate, all on the SAME data -- the design is PAIRED):
##   1 laplace        gllvmTMBcontrol()
##   2 laplace_ridge  gllvmTMBcontrol(aghq_ridge = 2)          <- the fair control
##   3 aghq_single    aghq = 9, aghq_ridge = Inf, aghq_multistart = FALSE  <- pre-#843
##   4 aghq           aghq = 9, aghq_ridge = Inf                <- shipped (multi-start)
##   5 aghq_ridge     aghq = 9 (ridge on by default)
## Since #843 the engine itself runs both starts and keeps the better FINAL objective,
## so the old derived `aghq_ms` arm is gone. `aghq_single` is retained so the campaign
## can still measure the pre-#843 behaviour and price what multi-start bought.
##
## USAGE
##   Rscript 24-estimator-campaign.R              # smoke: 1 cell, 10 seeds
##   STAGE=1 NSIM=400 CORES=100 Rscript 24-estimator-campaign.R
##   STAGE=2 NSIM=200 CORES=100 Rscript 24-estimator-campaign.R
## =============================================================================

suppressMessages(devtools::load_all(Sys.getenv("PKG", "/private/tmp/gllvmtmb-843-truthstart"), quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

DIR   <- Sys.getenv("OUTDIR", "/private/tmp/gllvmtmb-843-truthstart/dev/aghq-evidence")
STAGE <- Sys.getenv("STAGE", "smoke")
NSIM  <- as.integer(Sys.getenv("NSIM", "10"))
CORES <- as.integer(Sys.getenv("CORES", "4"))
MASTER_SEED <- 20260731L

OUT <- file.path(DIR, sprintf("24-campaign-stage%s-inc.csv", STAGE))
LOG <- file.path(DIR, sprintf("24-campaign-stage%s.log", STAGE))
say <- function(...) { s <- sprintf(...); cat(s); flush.console(); cat(s, file = LOG, append = TRUE) }

## ---- PROVENANCE (Williams item 6) -------------------------------------------
## The build date is recorded because a "shipped-engine" campaign run against a stale
## install is the same defect as one run against a reimplementation -- which is exactly
## what happened on 2026-07-31 (the installed binary was 13 days old). Never inferred
## from the branch again.
pkg_provenance <- function() {
  dsc <- tryCatch(readLines(system.file("DESCRIPTION", package = "gllvmTMB")), error = function(e) character(0))
  built <- grep("^Built:", dsc, value = TRUE)
  list(version = as.character(utils::packageVersion("gllvmTMB")),
       built = if (length(built)) sub("^Built:\\s*", "", built) else "load_all (source)",
       git = tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA_character_))
}

## ---- DGP (design §D.1) ------------------------------------------------------
## Byte-identical to 18/22/23 for binomial; the family switch only changes the response
## draw, so the latent structure is common across families by construction.
mk <- function(n, p, q, lam_sd, seed, family) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- switch(family,
    binomial = matrix(rbinom(n * p, 1, plogis(eta)), n, p),
    poisson  = matrix(rpois(n * p, exp(pmin(eta, 8))), n, p),
    gaussian = matrix(rnorm(n * p, eta, 1), n, p),
    stop("unsupported family: ", family))
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt, b = b)
}
fam_obj <- function(f) switch(f, binomial = binomial(), poisson = poisson(), gaussian = gaussian())
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

## ---- arms (design §M) -------------------------------------------------------
## ARMS REDEFINED 2026-07-31 after #843/#871/#874 landed. The previous set was
## written against a SINGLE-START engine and is now mislabelled:
##   - `aghq` (aghq_ridge = Inf) is MULTI-START by default now, not "the shipped
##     single start" the design called it;
##   - `aghq_alt` injected a start through the diagnostic hook, but the engine now
##     builds its own second start too, so that arm was neither one thing nor the
##     other;
##   - the derived `aghq_ms` = min(aghq, aghq_alt) is REDUNDANT -- running both
##     starts and keeping the better final objective is exactly what the engine
##     does internally.
## The historical single-start arm is kept, explicitly, so the campaign can still
## measure what the old evidence base measured and price the change.
ARM_CTL <- list(
  laplace       = function() gllvmTMBcontrol(),
  laplace_ridge = function() gllvmTMBcontrol(aghq_ridge = 2),
  aghq_single   = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf,
                                             aghq_multistart = FALSE),  # pre-#843
  aghq          = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf), # shipped: multi-start
  aghq_ridge    = function() gllvmTMBcontrol(aghq = 9)                    # shipped + ridge
)

## ---- one replicate: all 5 arms on the SAME data ------------------------------
one <- function(job) {
  d  <- mk(job$n, job$p, job$q, job$lam_sd, job$seed, job$family)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St))
  off <- upper.tri(Rt); nrmT <- norm(d$Lt, "F")
  fam <- fam_obj(job$family)

  fits <- list(); rows <- list()
  for (arm in names(ARM_CTL)) {
    ctl <- ARM_CTL[[arm]]()
    t0 <- Sys.time()
    f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = fam, control = ctl)),
                  error = function(e) structure(list(msg = conditionMessage(e)), class = "failed"))
    el <- as.numeric(Sys.time() - t0, units = "secs")
    if (inherits(f, "failed")) {
      ## design §P.4 -- failures are RECORDED, never silently absent
      rows[[arm]] <- data.frame(arm = arm, ok = FALSE, fail_msg = substr(f$msg, 1, 120),
                                converged = FALSE, elapsed_s = el, stringsAsFactors = FALSE)
      next
    }
    fits[[arm]] <- f
    L  <- f$report$Lambda_B[seq_len(job$p), seq_len(job$q), drop = FALSE]
    Sh <- L %*% t(L); Rh <- corr_of(Sh)
    rows[[arm]] <- data.frame(
      arm = arm, ok = TRUE, fail_msg = NA_character_,
      obj        = tryCatch(as.numeric(f$opt$objective), error = function(e) NA_real_),
      ## CONVERGENCE IS ENGINE-DEPENDENT, and reading the wrong field silently
      ## mislabels every AGHQ cell. `opt$convergence` on the AGHQ path is nlminb's
      ## code for the PER-PASS ITERATION CAP set by the continuation schedule -- it
      ## returns 1 ("iteration limit reached") on a perfectly healthy fit. The AGHQ
      ## loop's own verdict lives in `aghq$stop_reason`, and the ONLY value that means
      ## converged is the one beginning "converged (adaptation mode fixed...".
      ## Caught by the 10-seed smoke test, which showed 30-60% "non-convergence"
      ## that was entirely this artefact.
      conv       = tryCatch(as.integer(f$opt$convergence), error = function(e) NA_integer_),
      stop_reason = tryCatch(as.character(f$aghq$stop_reason %||% NA_character_),
                             error = function(e) NA_character_),
      converged  = if (isTRUE(f$aghq$used)) {
                     grepl("^converged", f$aghq$stop_reason %||% "")
                   } else {
                     isTRUE(tryCatch(f$opt$convergence == 0, error = function(e) FALSE))
                   },
      aghq_used  = isTRUE(f$aghq$used),
      rho_mae    = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),   # PRIMARY (design §E)
      rho_bias   = mean(Rh[off] - Rt[off], na.rm = TRUE),
      rho_rmse   = sqrt(mean((Rh[off] - Rt[off])^2, na.rm = TRUE)),
      sigma_rat  = median(sqrt(diag(Sh)) / sg_t),
      frob_rat   = norm(L, "F") / nrmT,
      ## Lambda_hat stored so the estimand stays a POST-HOC choice
      lambda_hat = paste(signif(as.numeric(L), 8), collapse = "|"),
      elapsed_s  = el, stringsAsFactors = FALSE)
  }
  if (!length(rows)) return(NULL)

  ## quadrature-moved rate (design §P.2, S2) -- did AGHQ move off the Laplace optimum?
  pshift <- NA_real_
  if (!is.null(fits$laplace) && !is.null(fits$aghq) &&
      identical(names(fits$laplace$opt$par), names(fits$aghq$opt$par))) {
    pshift <- max(abs(fits$laplace$opt$par - fits$aghq$opt$par))
  }

  out <- do.call(rbind, lapply(rows, function(r) {
    for (nm in c("obj","conv","stop_reason","converged","aghq_used","rho_mae","rho_bias",
                 "rho_rmse","sigma_rat","frob_rat","lambda_hat")) if (is.null(r[[nm]])) r[[nm]] <- NA
    r
  }))
  out <- cbind(job[rep(1, nrow(out)), c("family","n","p","q","lam_sd","seed")], out,
               par_shift = pshift, lambda_true = paste(signif(as.numeric(d$Lt), 8), collapse = "|"),
               row.names = NULL)
  utils::write.table(out, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  out
}

## ---- the grid (design §D.2) --------------------------------------------------
grid_for <- function(stage) {
  if (stage == "1")     expand.grid(family = "binomial", n = c(100L, 400L, 1600L),
                                    lam_sd = c(1, 3), stringsAsFactors = FALSE)
  else if (stage == "2") expand.grid(family = c("gaussian", "poisson"), n = c(100L, 1600L),
                                    lam_sd = 1, stringsAsFactors = FALSE)
  else                   expand.grid(family = "binomial", n = 100L, lam_sd = 1,
                                    stringsAsFactors = FALSE)   # smoke
}
cells <- grid_for(STAGE)
cells$p <- 6L; cells$q <- 2L

## per-replicate seeds derived ONCE from the master and STORED (design §D.4)
set.seed(MASTER_SEED)
seed_pool <- sample.int(.Machine$integer.max, nrow(cells) * NSIM)
jobs <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  cbind(cells[rep(i, NSIM), ], seed = seed_pool[((i - 1) * NSIM + 1):(i * NSIM)], row.names = NULL)
}))

if (file.exists(OUT)) file.remove(OUT)
if (file.exists(LOG)) file.remove(LOG)
pp <- pkg_provenance()
say("=== 24 AGHQ ESTIMATOR CAMPAIGN -- stage %s ===\n", STAGE)
say("gllvmTMB %s | built %s | git %s\n", pp$version, pp$built, paste(pp$git, collapse = ""))
say("master seed %d | %d cells x %d seeds = %d replicates x 5 arms = %d fits | %d cores\n\n",
    MASTER_SEED, nrow(cells), NSIM, nrow(jobs), 5 * nrow(jobs), CORES)
print(cells)

t0 <- Sys.time()
res <- mclapply(seq_len(nrow(jobs)), function(i) tryCatch(one(jobs[i, ]), error = function(e) NULL),
                mc.cores = CORES, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, file.path(DIR, sprintf("24-campaign-stage%s.csv", STAGE)), row.names = FALSE)
saveRDS(sessionInfo(), file.path(DIR, sprintf("24-campaign-stage%s-sessionInfo.rds", STAGE)))
say("\nelapsed %.1f min | %d rows\n", as.numeric(Sys.time() - t0, units = "mins"), nrow(res))

## ---- summarise: the paired contrasts (design §P.1) ---------------------------
source(file.path(DIR, "24-summarise.R"), local = TRUE)
