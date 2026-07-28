## Does the relative-collapse fix explain the Laplace campaign's 59/70?
##
## after-task 2026-07-27-start-method-res-worse-optimum.md sec 6a asserts the
## silent-degenerate-fit finding from the Laplace campaign -- convergence == 0
## AND pdHess == TRUE on 59 of 70 genuinely degenerate fits -- is "the same
## failure mode" as the Heywood psi collapse that motivated
## .gllvmTMB_relative_collapse(). The handover asks for that to be TESTED:
## re-running the grid should flip a large share of those cells to flagged, and
## if it does not the explanation is wrong and must be corrected.
##
## This re-fits the ACTUAL degenerate cells, identified by family/n/p/q/seed
## from the original grid.csv, using the same DGP (dev/totoro-grid/run-grid.R
## lines 49-58) and the same model, then asks the NEW detector about each fit.
##
## Structural prediction, to be confirmed or refuted by the numbers below:
## the grid's Laplace arm fits latent(..., unique = FALSE) -- "Psi SUPPRESSED",
## run-grid.R line 18 -- and every degenerate cell is bernoulli, which has no
## residual sd. The relative check reaches only sd/variance components; the
## loading check stayed ABSOLUTE at 1e-3. So there should be nothing for the
## fix to act on, and the flip rate should be ~0.

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-res-check", quiet = TRUE))

ref <- read.csv("/tmp/grid-ref.csv", stringsAsFactors = FALSE)
deg <- ref[ref$arm == "gtmb_laplace" &
             is.finite(ref$rel_frob) & ref$rel_frob > 10, ]
cat(sprintf("degenerate Laplace cells in the original grid: %d\n", nrow(deg)))
cat(sprintf("  of which conv0_pdHessTRUE (the '59'): %d\n",
            sum(deg$status == "conv0_pdHessTRUE")))

## Keep the run bounded: the smaller cells first, they are the cheap ones.
deg <- deg[order(deg$n * deg$p), ]
MAX_CELLS <- as.integer(Sys.getenv("MAX_CELLS", "24"))
deg <- head(deg, MAX_CELLS)
cat(sprintf("re-fitting %d of them (cheapest by n*p)\n\n", nrow(deg)))

rows <- list()
OUT <- "/private/tmp/gllvmtmb-res-check/dev/relative-collapse-vs-59of70.csv"

for (i in seq_len(nrow(deg))) {
  cell <- deg[i, ]
  set.seed(cell$seed)
  p <- cell$p; q <- cell$q; n <- cell$n
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u <- matrix(rnorm(n * q), n, q)
  b <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))

  fml <- as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q
  ))

  fit <- tryCatch(gllvmTMB(fml, data = df, family = binomial()),
                  error = function(e) structure(list(msg = conditionMessage(e)),
                                                class = "cell_error"))
  if (inherits(fit, "cell_error")) {
    rows[[length(rows) + 1L]] <- data.frame(
      n = n, p = p, q = q, seed = cell$seed, orig_status = cell$status,
      refit = "ERROR", conv = NA, pdHess = NA, flags = fit$msg,
      flagged = NA, stringsAsFactors = FALSE)
    cat(sprintf("[%2d/%2d] n=%3d p=%2d q=%d seed=%d  ERROR\n",
                i, nrow(deg), n, p, q, cell$seed)); flush(stdout())
    next
  }

  conv <- tryCatch(fit$opt$convergence, error = function(e) NA)
  pdh <- tryCatch(isTRUE(fit$sd_report$pdHess), error = function(e) NA)
  ## The question: does the NEW detector say anything about this fit?
  flags <- tryCatch(.gllvmTMB_boundary_flags(fit), error = function(e) "flagfail")
  flag_str <- if (!length(flags)) "" else paste(flags, collapse = ";")

  rows[[length(rows) + 1L]] <- data.frame(
    n = n, p = p, q = q, seed = cell$seed, orig_status = cell$status,
    refit = "ok", conv = conv, pdHess = pdh, flags = flag_str,
    flagged = nzchar(flag_str), stringsAsFactors = FALSE)
  utils::write.csv(do.call(rbind, rows), OUT, row.names = FALSE)
  cat(sprintf("[%2d/%2d] n=%3d p=%2d q=%d seed=%d  conv=%s pdHess=%s flags=%s\n",
              i, nrow(deg), n, p, q, cell$seed, conv, pdh,
              if (nzchar(flag_str)) flag_str else "<none>")); flush(stdout())
}

d <- do.call(rbind, rows)
utils::write.csv(d, OUT, row.names = FALSE)

ok <- d[d$refit == "ok", ]
cat("\n================ VERDICT ================\n")
cat(sprintf("cells re-fitted ok        : %d\n", nrow(ok)))
cat(sprintf("flagged by the NEW detector: %d (%.0f%%)\n",
            sum(ok$flagged, na.rm = TRUE),
            100 * mean(ok$flagged, na.rm = TRUE)))
cat(sprintf("still conv==0 AND pdHess  : %d\n",
            sum(ok$conv == 0 & ok$pdHess, na.rm = TRUE)))
cat("\nflag breakdown:\n"); print(table(ok$flags))
cat("\nIf the flagged share is ~0, after-task sec 6a's claim that this is\n")
cat("'the same failure mode' is REFUTED for these cells, and the relative-\n")
cat("collapse fix -- which is a real fix for the Gaussian Heywood case -- does\n")
cat("NOT explain the campaign's 59/70.\n")
