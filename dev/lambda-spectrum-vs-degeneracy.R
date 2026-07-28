## Does a RELATIVE spectral check on Lambda_B separate degenerate fits from
## healthy ones, where the absolute loading_thresh does not?
##
## Established earlier today: the relative-collapse fix flags 0 of 22 of the
## Laplace campaign's degenerate cells, because those fits use
## latent(..., unique = FALSE) -- "Psi SUPPRESSED" -- and are bernoulli, so
## they carry no psi and no residual sd. The 59/70 finding
## (convergence == 0 AND pdHess == TRUE on genuinely degenerate fits) is
## therefore STILL UNDIAGNOSED.
##
## HYPOTHESIS (recorded as untested in
## docs/dev-log/2026-07-27-relative-collapse-does-not-explain-59of70.md):
## with unique = FALSE the only structure is Lambda_B, so a degenerate fit is a
## near-collinear LOADING matrix rather than a collapsed variance. The existing
## check is `any(abs(diag(Lambda_B)) < 1e-3)` -- ABSOLUTE, and on the Cholesky
## DIAGONAL rather than on the implied spectrum of Lambda_B Lambda_B'. That is
## the same shape of blind spot the psi threshold had.
##
## PREDICTION: eigen(Lambda_B Lambda_B')'s trailing/leading ratio is small for
## degenerate cells and not small for healthy ones.
##
## THE CONTROL IS THE POINT. A small ratio among degenerate fits proves nothing
## on its own -- rank-deficiency might be common in healthy fits too. This
## refits BOTH degenerate and healthy cells from the same grid and asks whether
## the statistic SEPARATES them. If it does not, this hypothesis dies like the
## last one.

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-res-check", quiet = TRUE))

ref <- read.csv("/tmp/grid-ref.csv", stringsAsFactors = FALSE)
## family MUST be filtered: every degenerate cell is bernoulli, and the refit
## below always simulates with rbinom(). Without this, a poisson "healthy" cell
## is re-simulated as bernoulli at the same seed and reproduces the exact
## dataset of a degenerate bernoulli cell -- which made the first run report
## byte-identical statistics for both groups.
la <- ref[ref$arm == "gtmb_laplace" & is.finite(ref$rel_frob) &
            ref$family == "bernoulli", ]
la$degenerate <- la$rel_frob > 10

## Match the two groups on n/p/q so the comparison is not confounded by size.
PER_GROUP <- as.integer(Sys.getenv("PER_GROUP", "12"))
deg <- la[la$degenerate, ]
hea <- la[!la$degenerate, ]
deg <- deg[order(deg$n * deg$p), ]
deg <- head(deg, PER_GROUP)
## take healthy cells from the SAME (n,p,q) combinations that appear in deg
## Exact (n,p,q) matching was tried and FAILED to produce a usable control:
## degeneracy is concentrated in the SMALL cells (at n=40, p=8 nearly every
## fit is degenerate), so the cheapest degenerate cells have almost no healthy
## counterparts at the same size -- 16 degenerate matched only 1 healthy. That
## concentration is itself a finding. Instead take healthy cells spanning the
## same size RANGE and report n/p/q per cell, so any size confounding stays
## visible in the output rather than hidden by the matching.
## (the size bound was computed from the TRUNCATED deg set, which is all
## n=40/p=8, so it stayed just as restrictive -- take the cheapest healthy
## cells outright instead and let the per-cell n/p/q printout expose any
## size confounding)
## No seed exclusion is needed: within arm=gtmb_laplace and family=bernoulli
## every (n,p,q,seed) is unique (281 rows, 281 unique keys), so a healthy cell
## is by construction a different dataset from any degenerate one. A blanket
## seed exclusion was tried first and was destructive -- seeds repeat across
## configs, so it emptied the healthy group entirely at larger PER_GROUP.
hea <- hea[order(hea$n * hea$p), ]
hea <- head(hea, PER_GROUP)
cells <- rbind(transform(deg, grp = "degenerate"),
               transform(hea, grp = "healthy"))
cat(sprintf("refitting %d degenerate + %d healthy cells (matched on n,p,q)\n\n",
            sum(cells$grp == "degenerate"), sum(cells$grp == "healthy")))

rows <- list()
OUT <- "/private/tmp/gllvmtmb-res-check/dev/lambda-spectrum-vs-degeneracy.csv"

for (i in seq_len(nrow(cells))) {
  ce <- cells[i, ]
  set.seed(ce$seed)
  p <- ce$p; q <- ce$q; n <- ce$n
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u <- matrix(rnorm(n * q), n, q)
  b <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q))

  fit <- tryCatch(gllvmTMB(fml, data = df, family = binomial()),
                  error = function(e) NULL)
  if (is.null(fit)) next

  Lam <- tryCatch(fit$report$Lambda_B, error = function(e) NULL)
  if (is.null(Lam)) next
  Lam <- Lam[seq_len(p), seq_len(q), drop = FALSE]
  S <- Lam %*% t(Lam)
  ev <- sort(eigen(S, symmetric = TRUE, only.values = TRUE)$values,
             decreasing = TRUE)
  ev_q <- ev[seq_len(q)]
  ratio <- min(ev_q) / max(ev_q)                       # the proposed statistic
  dg <- abs(diag(Lam[seq_len(q), seq_len(q), drop = FALSE]))
  abs_min_diag <- min(dg)                              # what the CURRENT check sees
  flags <- tryCatch(.gllvmTMB_boundary_flags(fit), error = function(e) "err")

  rows[[length(rows) + 1L]] <- data.frame(
    grp = ce$grp, n = n, p = p, q = q, seed = ce$seed,
    rel_frob = ce$rel_frob,
    eig_ratio = ratio, min_abs_diag = abs_min_diag,
    current_flags = if (!length(flags)) "" else paste(flags, collapse = ";"),
    conv = tryCatch(fit$opt$convergence, error = function(e) NA),
    pdHess = tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA),
    stringsAsFactors = FALSE)
  utils::write.csv(do.call(rbind, rows), OUT, row.names = FALSE)
  cat(sprintf("[%2d/%2d] %-10s n=%3d p=%2d q=%d  eig_ratio=%.3e  min|diag|=%.3e  flags=%s\n",
              i, nrow(cells), ce$grp, n, p, q, ratio, abs_min_diag,
              if (!length(flags)) "<none>" else paste(flags, collapse = ";")))
  flush(stdout())
}

d <- do.call(rbind, rows)
cat("\n================= SEPARATION =================\n")
for (g in c("degenerate", "healthy")) {
  s <- d[d$grp == g, ]
  if (!nrow(s)) next
  cat(sprintf("%-11s n=%2d  eig_ratio  median %.3e  [%.3e, %.3e]\n",
              g, nrow(s), median(s$eig_ratio), min(s$eig_ratio), max(s$eig_ratio)))
  cat(sprintf("%-11s        min|diag| median %.3e  [%.3e, %.3e]\n",
              "", median(s$min_abs_diag), min(s$min_abs_diag), max(s$min_abs_diag)))
}
dd <- d[d$grp == "degenerate", ]; hh <- d[d$grp == "healthy", ]
if (nrow(dd) && nrow(hh)) {
  cat(sprintf("\nCURRENT absolute check (min|diag| < 1e-3) would flag: %d/%d degenerate, %d/%d healthy\n",
              sum(dd$min_abs_diag < 1e-3), nrow(dd),
              sum(hh$min_abs_diag < 1e-3), nrow(hh)))
  ## Best achievable separation by a relative eigen-ratio threshold.
  cands <- sort(unique(c(d$eig_ratio, 10^seq(-8, -1))))
  best <- NULL
  for (th in cands) {
    tp <- sum(dd$eig_ratio < th); fp <- sum(hh$eig_ratio < th)
    sc <- tp / nrow(dd) - fp / nrow(hh)
    if (is.null(best) || sc > best$sc) best <- list(th = th, tp = tp, fp = fp, sc = sc)
  }
  cat(sprintf("BEST relative eig_ratio threshold %.3e: flags %d/%d degenerate, %d/%d healthy (Youden %.2f)\n",
              best$th, best$tp, nrow(dd), best$fp, nrow(hh), best$sc))
  cat("\nIf the two groups' eig_ratio ranges OVERLAP, the statistic does not\n")
  cat("separate them and this hypothesis dies like the relative-psi one.\n")
}
