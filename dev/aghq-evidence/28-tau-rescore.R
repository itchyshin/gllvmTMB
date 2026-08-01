## Rescore the retained 12,000-fit campaign for candidate scale-aware ridge tau.
## This diagnoses the pilot distribution; it CANNOT validate an adaptive rule,
## because the CSV contains no counterfactual refits under tau_raw/tau_used.

input <- Sys.getenv(
  "INPUT",
  file.path("dev", "aghq-evidence", "24-campaign-stage1.csv")
)
out_csv <- Sys.getenv(
  "OUT_CSV",
  file.path("dev", "aghq-evidence", "28-tau-rescore.csv")
)
out_md <- Sys.getenv(
  "OUT_MD",
  file.path("dev", "aghq-evidence", "28-tau-rescore.md")
)

x <- utils::read.csv(input, stringsAsFactors = FALSE, check.names = FALSE)
required <- c(
  "family", "n", "p", "q", "lam_sd", "task", "seed", "arm", "ok",
  "frob_rat", "rho_mae", "lambda_hat", "lambda_true"
)
stopifnot(all(required %in% names(x)))

unpack <- function(value, p, q, label) {
  z <- suppressWarnings(as.numeric(strsplit(value, "|", fixed = TRUE)[[1L]]))
  if (length(z) != p * q || any(!is.finite(z))) {
    stop(sprintf("invalid %s: expected %d finite values, found %d",
                 label, p * q, length(z)))
  }
  matrix(z, nrow = p, ncol = q)
}

x$tau_est <- mapply(
  function(value, p, q) {
    L <- unpack(value, p, q, "lambda_hat")
    norm(L, "F") / sqrt(p * q)
  },
  x$lambda_hat, x$p, x$q,
  SIMPLIFY = TRUE, USE.NAMES = FALSE
)
x$tau_truth <- mapply(
  function(value, p, q) {
    L <- unpack(value, p, q, "lambda_true")
    norm(L, "F") / sqrt(p * q)
  },
  x$lambda_true, x$p, x$q,
  SIMPLIFY = TRUE, USE.NAMES = FALSE
)
x$tau_raw <- pmax(1, x$tau_est)
x$tau_ratio <- x$tau_est / x$tau_truth
x$runaway <- x$frob_rat > 2

## The calibration source is fixed before looking at tails: unpenalised,
## multi-start AGHQ. Never substitute plain Laplace here.
ref <- x[x$arm == "aghq" & x$ok, , drop = FALSE]
stopifnot(nrow(ref) == 2400L)
key <- c("family", "n", "p", "q", "lam_sd", "task", "seed")
stopifnot(!anyDuplicated(ref[key]))

qprobs <- c(0, 0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99, 1)
qnames <- c("min", "p01", "p05", "p25", "p50", "p75", "p95", "p99", "max")
caps <- c(4, 5, 6, 8)

summarise_group <- function(g) {
  tq <- stats::quantile(g$tau_est, qprobs, na.rm = TRUE, names = FALSE)
  rq <- stats::quantile(g$tau_ratio, qprobs, na.rm = TRUE, names = FALSE)
  out <- data.frame(
    family = g$family[1L], n = g$n[1L], p = g$p[1L], q = g$q[1L],
    lam_sd = g$lam_sd[1L], N = nrow(g),
    runaway_rate = mean(g$runaway),
    stringsAsFactors = FALSE
  )
  for (i in seq_along(qnames)) out[[paste0("tau_", qnames[i])]] <- tq[i]
  for (i in seq_along(qnames)) out[[paste0("ratio_", qnames[i])]] <- rq[i]
  for (cap in caps) {
    out[[paste0("cap", cap, "_hit")]] <- mean(g$tau_raw > cap)
    nonrun <- !g$runaway
    out[[paste0("cap", cap, "_hit_nonrun")]] <-
      if (any(nonrun)) mean(g$tau_raw[nonrun] > cap) else NA_real_
  }
  out
}

groups <- split(ref, interaction(ref$n, ref$lam_sd, drop = TRUE))
summary <- do.call(rbind, lapply(groups, summarise_group))
rownames(summary) <- NULL
summary <- summary[order(summary$lam_sd, summary$n), ]
utils::write.csv(summary, out_csv, row.names = FALSE)

fmt <- function(z, digits = 3L) formatC(z, format = "f", digits = digits)
lines <- c(
  "# #847 tau pilot tail rescore",
  "",
  "This is a diagnostic rescore of the retained 12,000-fit campaign. It does",
  "**not** validate an adaptive penalty: fresh paired refits are required.",
  "The scale source is fixed to unpenalised multi-start AGHQ (`arm = aghq`),",
  "never plain Laplace.",
  "",
  "| n | sigma_lambda | N | runaway | tau median | tau p95 | tau p99 | tau max | ratio median | cap 4 nonrun clipped | cap 5 | cap 6 | cap 8 |",
  "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(summary))) {
  r <- summary[i, ]
  lines <- c(lines, sprintf(
    "| %d | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
    r$n, fmt(r$lam_sd, 0), r$N, fmt(r$runaway_rate),
    fmt(r$tau_p50), fmt(r$tau_p95), fmt(r$tau_p99), fmt(r$tau_max),
    fmt(r$ratio_p50), fmt(r$cap4_hit_nonrun), fmt(r$cap5_hit_nonrun),
    fmt(r$cap6_hit_nonrun), fmt(r$cap8_hit_nonrun)
  ))
}
lines <- c(
  lines,
  "",
  "## Decision boundary",
  "",
  "The pilot tail is unsafe without a cap: across all 2,400 reference fits,",
  sprintf("`tau_est` p99 is %s and the maximum is %s.",
          fmt(stats::quantile(ref$tau_est, 0.99)), fmt(max(ref$tau_est))),
  "Cap 4 is excluded before fresh fitting because it clips more than 5% of",
  "truth-classified non-runaway sigma_lambda = 3 pilots in the stored data.",
  "Caps 5, 6, and 8 proceed as candidates, with uncapped retained only as an",
  "unsafe control. Selection requires fresh paired penalised refits and a",
  "disjoint-seed confirmation; this file chooses no cap."
)
writeLines(lines, out_md)

cat(sprintf("wrote %s (%d rows) and %s\n", out_csv, nrow(summary), out_md))
