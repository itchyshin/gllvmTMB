#!/usr/bin/env Rscript
## Wide-condition VA/EVA/JJ/Laplace comparison — Totoro runner.
##
## Compute: Totoro, <= 64 workers (150-core ceiling is shared with Codex).
## OPENBLAS_NUM_THREADS=1 is pinned in EVERY worker: without it each R process
## spawns its own BLAS pool and 64 workers consume 400+ threads, blowing the
## ceiling while running slower from contention.
##
## Results stay LOCAL (D-50) — rsync'd back, never a GitHub artifact.
##
## Arms, named by their ALGEBRA rather than by a package flag, because calling
## gllvm's binomial route "VA" is what made "EVA looks better than VA" seem
## plausible earlier:
##   A gtmb_gh      gllvmTMB GH-VA, eval_method="gh", H=15
##   B gtmb_jj      gllvmTMB JJ-VA, eval_method="jj"   (same engine as A)
##   C gllvm_va     gllvm method="VA"  (= JJ/Polya-Gamma for binomial; exact for Poisson)
##   D gllvm_eva    gllvm method="EVA" (2nd-order Taylor surrogate)
##   E gtmb_laplace gllvmTMB Laplace, Psi SUPPRESSED via latent(..., unique=FALSE)

suppressMessages({
  library(gllvmTMB); library(gllvm); library(mirai)
})

OUT <- file.path(Sys.getenv("HOME"), "gllvm_work", "results")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SMOKE <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
NWORK <- as.integer(Sys.getenv("GRID_WORKERS", "64"))
FITSEC <- as.integer(Sys.getenv("GRID_FIT_SECONDS", "300"))

## ---------------------------------------------------------------- design ---
grid <- expand.grid(
  family = c("poisson", "bernoulli"),
  n      = c(40L, 100L, 200L, 400L),
  p      = c(8L, 20L, 40L, 80L),
  q      = c(2L, 4L),
  seed   = 1:10,
  stringsAsFactors = FALSE
)
grid <- grid[grid$q < grid$p, ]           # rank must be under trait count
if (SMOKE) grid <- grid[grid$n == 40L & grid$p == 8L & grid$seed == 1L, ][1:2, ]

## ------------------------------------------------------------------ cell ---
run_cell <- function(cell, FITSEC) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1",
             MKL_NUM_THREADS = "1")
  suppressMessages({ library(gllvmTMB); library(gllvm) })
  relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")

  with(cell, {
    set.seed(seed)
    Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
    u  <- matrix(rnorm(n * q), n, q)
    b  <- rnorm(p, 0.3, 0.3)
    eta <- sweep(u %*% t(Lt), 2, b, "+")
    Y <- if (family == "poisson") matrix(rpois(n * p, exp(eta)), n, p)
         else                     matrix(rbinom(n * p, 1, plogis(eta)), n, p)
    colnames(Y) <- paste0("sp", seq_len(p))
    Sig_true <- Lt %*% t(Lt)
    lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
    lg <- lg[order(lg$unit, lg$trait), ]
    yv <- as.vector(t(Y)); X <- model.matrix(~ 0 + factor(lg$trait))
    fam_gtmb <- if (family == "poisson") "poisson" else "binomial"
    link_gtmb <- if (family == "poisson") "log" else "logit"
    fam_r <- if (family == "poisson") poisson() else binomial()

    ## every arm returns one row; a failure is a ROW, never a silent omission
    row <- function(arm, obj = NA_real_, secs = NA_real_, status = NA_character_,
                    Lam = NULL, note = "") {
      rf <- at <- NA_real_
      if (!is.null(Lam) && is.matrix(Lam) && all(is.finite(Lam))) {
        Sh <- Lam %*% t(Lam)
        rf <- relfrob(Sh, Sig_true)
        at <- sum(diag(Sh)) / sum(diag(Sig_true))
      }
      data.frame(family = family, n = n, p = p, q = q, seed = seed, arm = arm,
                 objective = obj, seconds = secs, status = status,
                 rel_frob = rf, attenuation = at, note = note,
                 stringsAsFactors = FALSE)
    }
    timed <- function(expr) {
      t0 <- proc.time()[["elapsed"]]
      v <- tryCatch(withCallingHandlers(expr, warning = function(w) invokeRestart("muffleWarning")),
                    error = function(e) structure(list(msg = conditionMessage(e)),
                                                  class = "cell_error"))
      list(v = v, secs = proc.time()[["elapsed"]] - t0)
    }
    out <- list()

    for (em in c("gh", "jj")) {
      if (em == "jj" && family == "poisson") next   # JJ is binomial-only
      arm <- if (em == "gh") "gtmb_gh" else "gtmb_jj"
      r <- timed(gllvmTMB:::.approximation_engine_fit(
        engine = "va_r3", y = yv, n_trials = rep(1L, length(yv)), X = X,
        unit_id = lg$unit, trait_id = lg$trait, q = q,
        family = fam_gtmb, link = link_gtmb, H = 15L, eval_method = em))
      out[[arm]] <- if (inherits(r$v, "cell_error"))
        row(arm, secs = r$secs, status = "ERROR", note = r$v$msg)
      else row(arm, -r$v$score$negative_elbo_gh, r$secs, r$v$status,
               r$v$engine_result$report$Lambda)
    }

    for (mth in c("VA", "EVA")) {
      arm <- if (mth == "VA") "gllvm_va" else "gllvm_eva"
      r <- timed(gllvm::gllvm(y = Y, family = fam_r, num.lv = q,
                              method = mth, seed = 1))
      out[[arm]] <- if (inherits(r$v, "cell_error"))
        row(arm, secs = r$secs, status = "ERROR", note = r$v$msg)
      else {
        Lam <- tryCatch(as.matrix(r$v$params$theta) %*%
                          diag(r$v$params$sigma.lv, q, q), error = function(e) NULL)
        row(arm, r$v$logL, r$secs,
            if (isTRUE(r$v$convergence)) "converged" else "not_converged", Lam)
      }
    }

    df <- as.data.frame(Y); df$site <- factor(seq_len(n))
    fml <- as.formula(sprintf(
      "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
      paste(colnames(Y), collapse = ","), q))
    r <- timed(gllvmTMB(fml, data = df, family = fam_r))
    out[["gtmb_laplace"]] <- if (inherits(r$v, "cell_error"))
      row("gtmb_laplace", secs = r$secs, status = "ERROR", note = r$v$msg)
    else {
      ll <- tryCatch(as.numeric(logLik(r$v)), error = function(e) NA_real_)
      ## extract_Sigma_B() returns a LIST (Sigma_B, R_B), not a matrix.
      ## CAVEAT carried in the note: this Sigma_B may include a per-trait
      ## link-implicit residual variance on its diagonal, whereas the VA arms
      ## report Lambda Lambda^T exactly. Treat cross-arm rel_frob for this arm
      ## as indicative, not like-for-like, until that is confirmed.
      Sb <- tryCatch(gllvmTMB::extract_Sigma_B(r$v)$Sigma_B, error = function(e) NULL)
      pd <- tryCatch(isTRUE(r$v$sd_report$pdHess), error = function(e) NA)
      rr <- row("gtmb_laplace", ll, r$secs,
                paste0("conv", r$v$opt$convergence, "_pdHess", pd),
                note = "Sigma_B may include link-implicit residual on diag")
      if (is.matrix(Sb) && all(is.finite(Sb))) {
        rr$rel_frob <- relfrob(Sb, Sig_true)
        rr$attenuation <- sum(diag(Sb)) / sum(diag(Sig_true))
      }
      rr
    }
    do.call(rbind, out)
  })
}

## ------------------------------------------------------------------- run ---
cells <- split(grid, seq_len(nrow(grid)))
cat(sprintf("cells=%d  arms<=5  workers=%d  smoke=%s\n",
            length(cells), NWORK, SMOKE))

daemons(NWORK, dispatcher = TRUE)
on.exit(daemons(0), add = TRUE)
t0 <- proc.time()[["elapsed"]]
res <- mirai_map(cells, run_cell, FITSEC = FITSEC)[.progress]
elapsed <- proc.time()[["elapsed"]] - t0

ok <- vapply(res, is.data.frame, logical(1))
out <- do.call(rbind, res[ok])
tag <- if (SMOKE) "smoke" else "grid"
saveRDS(out, file.path(OUT, sprintf("%s.rds", tag)))
write.csv(out, file.path(OUT, sprintf("%s.csv", tag)), row.names = FALSE)

cat(sprintf("\nDONE in %.1f s | cells ok %d/%d | rows %d\n",
            elapsed, sum(ok), length(res), nrow(out)))
cat("rows per arm:\n"); print(table(out$arm))
cat("non-finite objectives per arm:\n")
print(tapply(out$objective, out$arm, function(z) sum(!is.finite(z))))
cat("\nhead:\n"); print(utils::head(out, 12))
