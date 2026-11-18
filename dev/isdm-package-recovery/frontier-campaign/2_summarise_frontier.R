## Frontier campaign -- stage 2: per-level summary with MCSE, predeclared
## frontier estimates with bootstrap CIs, and the P1-F2 figure.
## Usage: Rscript 2_summarise_frontier.R <rows_dir> <out_dir>
## Every aggregate ships its MCSE (Williams et al. 2024 item 11). Failed or
## non-converged fits are retained and reported, never dropped (item 10b).
suppressMessages({library(ggplot2)})

args <- commandArgs(trailingOnly = TRUE)
rows_dir <- args[1]; out_dir <- args[2]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

TRUTH_LAM <- 16.14775; TRUTH_Q <- 2.553824
TRUTH_GAMMA <- c(0.30, -0.20, 0.15)
LAM_TRUTH_VEC <- c(11.27983, -8.77320, 7.51988)

files <- list.files(rows_dir, pattern = "^E.*_rep[0-9]+\\.rds$", full.names = TRUE)
cat("rows found:", length(files), "\n")
rows <- lapply(files, readRDS)

fld <- function(r, nm, default = NA_real_) if (!is.null(r[[nm]])) r[[nm]] else default
df <- data.frame(
  E        = vapply(rows, fld, 0, nm = "E"),
  rep      = vapply(rows, fld, 0, nm = "rep"),
  err      = vapply(rows, function(r) !is.na(fld(r, "error", NA_character_)), TRUE),
  conv     = vapply(rows, fld, 0, nm = "conv"),
  pd       = vapply(rows, function(r) isTRUE(r$pd_fd), TRUE),
  lam      = vapply(rows, fld, 0, nm = "lam_norm"),
  cosd     = vapply(rows, fld, 0, nm = "cos_truth"),
  q_hat    = vapply(rows, fld, 0, nm = "q_hat"),
  min_ev   = vapply(rows, fld, 0, nm = "min_ev"),
  t_total  = vapply(rows, fld, 0, nm = "time_total"),
  counts   = vapply(rows, fld, 0, nm = "counts_gbif"),
  sign_flip= vapply(rows, function(r) isTRUE(r$sign_flip), TRUE))

## Wald coverage on the pdHess subset (aligned for the sign orbit)
cover_row <- function(r) {
  if (!isTRUE(r$pd_fd) || is.null(r$se) || any(!is.finite(r$se[c(10:12, 20:22)])))
    return(c(lam = NA, gam = NA))
  s <- if (isTRUE(r$sign_flip)) -1 else 1
  lam_ok <- all(abs(r$theta[20:22] - s * LAM_TRUTH_VEC) <= 1.96 * r$se[20:22])
  gam_ok <- all(abs(r$theta[10:12] - TRUTH_GAMMA)       <= 1.96 * r$se[10:12])
  c(lam = lam_ok, gam = gam_ok)
}
cv <- t(vapply(rows, cover_row, c(lam = NA, gam = NA)))
df$cov_lam <- cv[, 1]; df$cov_gam <- cv[, 2]
df$rel_amp_err <- abs(df$lam - TRUTH_LAM) / TRUTH_LAM

mcse_p <- function(p, n) sqrt(p * (1 - p) / n)
agg <- do.call(rbind, lapply(split(df, df$E), function(g) {
  n <- nrow(g); npd <- sum(g$pd)
  data.frame(E = g$E[1], n = n, n_err = sum(g$err),
    conv_rate = mean(g$conv == 0),
    pd_rate = mean(g$pd), pd_mcse = mcse_p(mean(g$pd), n),
    med_rel_amp = median(g$rel_amp_err), iqr_lo = quantile(g$rel_amp_err, .25),
    iqr_hi = quantile(g$rel_amp_err, .75),
    bias_lam = mean(g$lam) - TRUTH_LAM, bias_lam_mcse = sd(g$lam)/sqrt(n),
    rmse_lam = sqrt(mean((g$lam - TRUTH_LAM)^2)),
    mean_cos = mean(g$cosd), cos95 = mean(g$cosd > 0.95),
    bias_q = mean(g$q_hat) - TRUTH_Q, bias_q_mcse = sd(g$q_hat)/sqrt(n),
    cov_lam = mean(g$cov_lam[g$pd], na.rm = TRUE),
    cov_gam = mean(g$cov_gam[g$pd], na.rm = TRUE),
    pd_frac = npd / n, mean_counts = mean(g$counts),
    mean_time = mean(g$t_total))
}))
agg <- agg[order(agg$E), ]
write.csv(agg, file.path(out_dir, "frontier-summary.csv"), row.names = FALSE)
print(agg, digits = 3)

## Predeclared frontier estimators (design E): isotonic interpolation + bootstrap
crossing <- function(E, y, thr, increasing = TRUE) {
  o <- order(E); E <- E[o]; y <- y[o]
  y <- if (increasing) cummax(y) else cummin(y)   # isotonic in E
  hit <- if (increasing) y >= thr else y <= thr
  if (!any(hit) || all(hit)) return(NA_real_)
  i <- which(hit)[1]; if (i == 1) return(E[1])
  # log-linear interpolation between bracketing levels
  exp(approx(y[(i-1):i], log(E[(i-1):i]), xout = thr)$y)
}
est_frontiers <- function(d) {
  a <- do.call(rbind, lapply(split(d, d$E), function(g)
    data.frame(E = g$E[1], pd = mean(g$pd), rel = median(g$rel_amp_err))))
  c(E_pd  = crossing(a$E, a$pd, 0.5, increasing = TRUE),
    E_rec = crossing(a$E, a$rel, 0.25, increasing = FALSE))
}
point <- est_frontiers(df)
set.seed(20260815)
boot <- t(replicate(1000, {
  est_frontiers(do.call(rbind, lapply(split(df, df$E), function(g)
    g[sample(nrow(g), replace = TRUE), ])))
}))
ci <- apply(boot, 2, quantile, c(.025, .975), na.rm = TRUE)
cat(sprintf("\nE*_pd  = %.2f  [%.2f, %.2f]\nE*_rec = %.2f  [%.2f, %.2f]\n",
    point["E_pd"], ci[1, "E_pd"], ci[2, "E_pd"],
    point["E_rec"], ci[1, "E_rec"], ci[2, "E_rec"]))
saveRDS(list(point = point, ci = ci, boot = boot),
        file.path(out_dir, "frontier-estimates.rds"))

## ---- P1-F2: the frontier curve (Florence gate + Tufte annotations) ----
okabe <- c("#0072B2", "#D55E00")
p1 <- ggplot(agg, aes(E, pd_rate)) +
  geom_ribbon(aes(ymin = pmax(0, pd_rate - pd_mcse), ymax = pmin(1, pd_rate + pd_mcse)),
              fill = okabe[1], alpha = .2) +
  geom_line(colour = okabe[1], linewidth = .7) + geom_point(colour = okabe[1], size = 2) +
  geom_hline(yintercept = .5, linetype = 3) +
  annotate("rect", xmin = ci[1, "E_pd"], xmax = ci[2, "E_pd"],
           ymin = -Inf, ymax = Inf, alpha = .12, fill = okabe[1]) +
  geom_vline(xintercept = point["E_pd"], linetype = 2, colour = okabe[1]) +
  scale_x_log10(breaks = c(.5, 1, 2, 4, 8, 16)) +
  labs(y = "P(positive-definite Hessian)", x = NULL,
       title = "P1-F2. The GBIF-information recoverability frontier",
       subtitle = sprintf(
         "Identifiability of the GBIF-only field vs GBIF effort; E*_pd = %.2f [%.2f, %.2f], E*_rec = %.2f [%.2f, %.2f]; ribbons are Monte Carlo SE",
         point["E_pd"], ci[1, "E_pd"], ci[2, "E_pd"],
         point["E_rec"], ci[1, "E_rec"], ci[2, "E_rec"])) +
  theme_minimal(base_size = 11)
p2 <- ggplot(agg, aes(E, med_rel_amp)) +
  geom_ribbon(aes(ymin = iqr_lo, ymax = iqr_hi), fill = okabe[2], alpha = .2) +
  geom_line(colour = okabe[2], linewidth = .7) + geom_point(colour = okabe[2], size = 2) +
  geom_hline(yintercept = .25, linetype = 3) +
  annotate("rect", xmin = ci[1, "E_rec"], xmax = ci[2, "E_rec"],
           ymin = -Inf, ymax = Inf, alpha = .12, fill = okabe[2]) +
  geom_vline(xintercept = point["E_rec"], linetype = 2, colour = okabe[2]) +
  scale_x_log10(breaks = c(.5, 1, 2, 4, 8, 16)) +
  scale_y_log10() +
  labs(x = "GBIF effort multiplier E (log scale)",
       y = "median |amplitude error| / truth (IQR band)",
       caption = paste0(
         "Synthetic known-truth campaign, 200 replicates per level, fields redrawn per replicate; ",
         "field sign identified only jointly with loadings (positive representative shown).\n",
         "Design guidance only; no empirical claim. n and MCSE per level in frontier-summary.csv.")) +
  theme_minimal(base_size = 11)
suppressWarnings({
  if (requireNamespace("patchwork", quietly = TRUE)) {
    ggsave(file.path(out_dir, "P1-F2-recoverability-frontier.png"),
           patchwork::wrap_plots(p1, p2, ncol = 1, heights = c(1, 1.1)),
           width = 7.2, height = 6.4, dpi = 220)
  } else {
    ggsave(file.path(out_dir, "P1-F2a-pd-rate.png"), p1, width = 7.2, height = 3.4, dpi = 220)
    ggsave(file.path(out_dir, "P1-F2b-amplitude-error.png"), p2, width = 7.2, height = 3.8, dpi = 220)
  }
})
cat("figure(s) written to", out_dir, "\n")
