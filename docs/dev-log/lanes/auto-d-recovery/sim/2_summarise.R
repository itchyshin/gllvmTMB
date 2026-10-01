## Rscript 2_summarise.R [--out SIMOUT] [--results RESDIR]
args <- commandArgs(trailingOnly = TRUE)
getarg <- function(flag, default) { i <- match(flag, args); if (is.na(i)) default else args[i + 1L] }
out <- getarg("--out", Sys.getenv("AUTOD_OUT", "docs/dev-log/lanes/auto-d-recovery/sim/out"))
resdir <- getarg("--results", "docs/dev-log/lanes/auto-d-recovery/results")
dir.create(resdir, recursive = TRUE, showWarnings = FALSE)
files <- list.files(file.path(out, "res"), pattern = "^task_.*\\.rds$", full.names = TRUE)
stopifnot(length(files) > 0L)
crits <- c("bic_sites", "bic", "aic", "aicc")
rows <- lapply(files, function(f) {
  x <- readRDS(f)
  cbind(x$grid[, c("family", "n_units", "n_traits", "d", "rep")],
        aborted = x$fit$aborted, seconds = x$fit$seconds,
        t(x$fit$sel), redraws = x$redraws)
})
dat <- do.call(rbind, rows)
mcse <- function(p, n) ifelse(n > 0, sqrt(p * (1 - p) / n), NA_real_)
cell_keys <- c("family", "n_units", "n_traits", "d")
cells <- unique(dat[cell_keys]); cells <- cells[do.call(order, cells), ]
res <- do.call(rbind, lapply(seq_len(nrow(cells)), function(k) {
  sub <- merge(dat, cells[k, ], by = cell_keys)
  n <- nrow(sub)
  do.call(rbind, lapply(crits, function(cr) {
    dh <- sub[[cr]]; d <- sub$d[1]
    ok <- !is.na(dh)
    pc <- mean(ok & dh == d, na.rm = TRUE); pu <- mean(ok & dh < d); po <- mean(ok & dh > d)
    pcs <- if (any(ok)) mean(dh[ok] == d) else NA_real_
    ns <- mean(!ok)
    data.frame(cells[k, ], criterion = cr, n = n,
      p_correct = pc, mcse_correct = mcse(pc, n),
      p_under = pu, mcse_under = mcse(pu, n),
      p_over = po, mcse_over = mcse(po, n),
      p_correct_given_selected = pcs, mcse_pcgs = mcse(pcs, sum(ok)),
      no_selection = ns, mcse_nosel = mcse(ns, n),
      median_sec = stats::median(sub$seconds), p90_sec = unname(stats::quantile(sub$seconds, 0.9)),
      stringsAsFactors = FALSE)
  }))
}))
utils::write.csv(res, file.path(resdir, "recovery-table.csv"), row.names = FALSE)

## guard rejection rate by fitted d (per family), from the stored tables
gr <- do.call(rbind, lapply(files, function(f) {
  x <- readRDS(f); tb <- x$fit$table
  if (is.null(tb)) return(NULL)
  data.frame(family = x$grid$family, d_fit = tb$d, rejected = !(tb$status %in% c("ok", "warm_start")))
}))
grt <- if (!is.null(gr)) stats::aggregate(rejected ~ family + d_fit, gr, mean) else NULL
tim <- stats::aggregate(seconds ~ family, dat, function(s) c(median = stats::median(s), p90 = unname(stats::quantile(s, 0.9))))

f3 <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))
md <- c("# auto-d recovery: results", "",
        sprintf("Datasets: %d. Rows with `aborted` count as not correct. MCSE = sqrt(p(1-p)/n).", nrow(dat)), "",
        "## bic_sites (default criterion)", "",
        "| family | n_units | p | d | n | P(correct) (MCSE) | P(under) | P(over) | P(correct given selected) | no-selection |",
        "|---|---|---|---|---|---|---|---|---|---|")
h <- res[res$criterion == "bic_sites", ]
for (i in seq_len(nrow(h))) with(h[i, ], md <<- c(md, sprintf(
  "| %s | %d | %d | %d | %d | %s (%s) | %s | %s | %s | %s |", family, n_units, n_traits, d, n,
  f3(p_correct), f3(mcse_correct), f3(p_under), f3(p_over), f3(p_correct_given_selected), f3(no_selection))))
md <- c(md, "", "## P(correct) by criterion", "",
        "| family | n_units | p | d | bic_sites | bic | aic | aicc |", "|---|---|---|---|---|---|---|---|")
for (k in seq_len(nrow(cells))) {
  r <- res[res$family == cells$family[k] & res$n_units == cells$n_units[k] &
           res$n_traits == cells$n_traits[k] & res$d == cells$d[k], ]
  v <- vapply(crits, function(cr) { z <- r[r$criterion == cr, ]; sprintf("%s (%s)", f3(z$p_correct), f3(z$mcse_correct)) }, "")
  md <- c(md, sprintf("| %s | %d | %d | %d | %s |", cells$family[k], cells$n_units[k], cells$n_traits[k], cells$d[k], paste(v, collapse = " | ")))
}
if (!is.null(grt)) {
  md <- c(md, "", "## Guard rejection rate by fitted d", "", "| family | fitted d | rejection rate |", "|---|---|---|")
  for (i in seq_len(nrow(grt))) md <- c(md, sprintf("| %s | %d | %s |", grt$family[i], grt$d_fit[i], f3(grt$rejected[i])))
}
md <- c(md, "", "## Wall time per dataset (s)", "", "| family | median | p90 |", "|---|---|---|")
for (i in seq_len(nrow(tim))) md <- c(md, sprintf("| %s | %.1f | %.1f |", tim$family[i], tim$seconds[i, "median"], tim$seconds[i, "p90"]))
writeLines(md, file.path(resdir, "recovery-table.md"))
cat("wrote", file.path(resdir, c("recovery-table.csv", "recovery-table.md")), "\n")
