## Domain-growth campaign (A2) -- stage 2: per-(s,E) summary with MCSE, the
## anchor-consistency kill rule vs A1, and the P1-F4 N_cells-frontier figure.
## Usage: Rscript 2c_summarise_domain.R <rows_dir> <out_dir>
suppressMessages({library(ggplot2)})

args <- commandArgs(trailingOnly = TRUE)
rows_dir <- args[1]; out_dir <- args[2]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(rows_dir, pattern = "^s.*_rep[0-9]+\\.rds$", full.names = TRUE)
cat("rows found:", length(files), "\n")
rows <- lapply(files, readRDS)
fld <- function(r, nm, d = NA_real_) if (!is.null(r[[nm]])) r[[nm]] else d
df <- data.frame(
  s      = vapply(rows, fld, 0, nm = "scale"),
  n_cell = vapply(rows, fld, 0, nm = "n_cell"),
  E      = vapply(rows, fld, 0, nm = "E"),
  err    = vapply(rows, function(x) !is.na(fld(x, "error", NA_character_)), TRUE),
  conv   = vapply(rows, fld, 0, nm = "conv"),
  pd     = vapply(rows, function(x) isTRUE(x$pd_fd), TRUE),
  lam    = vapply(rows, fld, 0, nm = "lam_norm"),
  lamT   = vapply(rows, fld, 0, nm = "lam_norm_true"),
  cosd   = vapply(rows, fld, 0, nm = "cos_truth"),
  q      = vapply(rows, fld, 0, nm = "q_hat"),
  qT     = vapply(rows, fld, 0, nm = "q_true"),
  tfit   = vapply(rows, fld, 0, nm = "time_fit"))
df$rel <- abs(df$lam - df$lamT) / df$lamT

mcse_p <- function(p, n) sqrt(p * (1 - p) / n)
agg <- do.call(rbind, lapply(split(df, interaction(df$s, df$E, drop = TRUE)), function(g) {
  n <- nrow(g)
  data.frame(s = g$s[1], n_cell = g$n_cell[1], E = g$E[1], n = n,
    n_err = sum(g$err), conv_rate = mean(g$conv == 0),
    pd_rate = mean(g$pd), pd_mcse = mcse_p(mean(g$pd), n),
    med_rel = median(g$rel), iqr_lo = quantile(g$rel, .25), iqr_hi = quantile(g$rel, .75),
    mean_cos = mean(g$cosd), cos95 = mean(g$cosd > 0.95),
    bias_q = mean(g$q - g$qT), bias_q_mcse = sd(g$q - g$qT)/sqrt(n),
    mean_tfit = mean(g$tfit))
}))
agg <- agg[order(agg$E, agg$n_cell), ]
write.csv(agg, file.path(out_dir, "domain-summary.csv"), row.names = FALSE)
print(agg, digits = 3, row.names = FALSE)

## ---- anchor-consistency kill rule vs A1 (r = 0.22 arm) ----
a1 <- read.csv(file.path(out_dir, "replication-summary.csv"))
cat("\n=== anchor-consistency (s=1 vs A1 r=0.22) ===\n")
ok_all <- TRUE
for (Ei in c(1, 2)) {
  a <- agg[agg$s == 1 & agg$E == Ei, ]
  e <- a1[a1$r == 0.22 & a1$E == Ei, ]
  z <- abs(a$pd_rate - e$pd_rate) / sqrt(a$pd_mcse^2 + e$pd_mcse^2)
  ok <- z <= 3; ok_all <- ok_all && ok
  cat(sprintf("  E=%g: pd %f vs %f  |z| = %.2f  %s\n",
      Ei, a$pd_rate, e$pd_rate, z, if (ok) "OK" else "DRIFT -- STOP"))
}
if (!ok_all) stop("anchor drift vs A1 -- do not use these results")

## ---- P1-F4: the N_cells frontier ----
okabe <- c("1" = "#0072B2", "2" = "#D55E00")
agg$Ef <- factor(agg$E)
p1 <- ggplot(agg, aes(n_cell, pd_rate, colour = Ef, group = Ef)) +
  geom_ribbon(aes(ymin = pmax(0, pd_rate - pd_mcse), ymax = pmin(1, pd_rate + pd_mcse),
                  fill = Ef), alpha = .15, colour = NA) +
  geom_line(linewidth = .7) + geom_point(size = 2) +
  scale_colour_manual(values = okabe, name = "GBIF effort E") +
  scale_fill_manual(values = okabe, guide = "none") +
  scale_x_log10(breaks = c(360, 810, 1440, 2250)) +
  labs(x = NULL, y = "P(positive-definite Hessian)",
       title = "P1-F4. The N-cells frontier (domain growth at fixed range)",
       subtitle = "Identifiability and amplitude recovery of the GBIF-only field vs number of cells; per-cell effort and per-patch sampling FIXED; ribbons are Monte Carlo SE (200 reps/cell)") +
  theme_minimal(base_size = 11)
p2 <- ggplot(agg, aes(n_cell, med_rel, colour = Ef, group = Ef)) +
  geom_ribbon(aes(ymin = iqr_lo, ymax = iqr_hi, fill = Ef), alpha = .15, colour = NA) +
  geom_line(linewidth = .7) + geom_point(size = 2) +
  geom_hline(yintercept = .25, linetype = 3) +
  scale_colour_manual(values = okabe, name = "GBIF effort E") +
  scale_fill_manual(values = okabe, guide = "none") +
  scale_x_log10(breaks = c(360, 810, 1440, 2250)) + scale_y_log10() +
  labs(x = "number of grid cells (log scale; domain grows, cell size and range fixed)",
       y = "median |amplitude error| / truth (IQR band)",
       caption = paste0(
         "Domain grown at fixed Matern range (0.22) and fixed cell size, so patch count rises WITHOUT diluting\n",
         "per-patch sampling -- the arm A1 could not test. Predictor-scale truth constant across levels (discrete-\n",
         "anchored, within 3%). Field sign identified only jointly with loadings (positive representative).\n",
         "Synthetic known-truth campaign; design guidance only; no empirical claim.")) +
  theme_minimal(base_size = 11)
suppressWarnings({
  if (requireNamespace("patchwork", quietly = TRUE)) {
    ggsave(file.path(out_dir, "P1-F4-ncells-frontier.png"),
           patchwork::wrap_plots(p1, p2, ncol = 1, heights = c(1, 1.15)),
           width = 7.2, height = 6.6, dpi = 220)
  } else {
    ggsave(file.path(out_dir, "P1-F4a-pd.png"), p1, width = 7.2, height = 3.4, dpi = 220)
    ggsave(file.path(out_dir, "P1-F4b-amp.png"), p2, width = 7.2, height = 3.9, dpi = 220)
  }
})
cat("figure(s) written to", out_dir, "\n")
