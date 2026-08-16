## Replication-axis campaign -- stage 2: per-(r,E) summary with MCSE, the
## anchor-consistency kill-rule check, and the P1-F3 figure.
## Usage: Rscript 2b_summarise_replication.R <rows_dir> <effort_summary_csv> <out_dir>
suppressMessages({library(ggplot2)})

args <- commandArgs(trailingOnly = TRUE)
rows_dir <- args[1]; effort_csv <- args[2]; out_dir <- args[3]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(rows_dir, pattern = "^r.*_rep[0-9]+\\.rds$", full.names = TRUE)
cat("rows found:", length(files), "\n")
rows <- lapply(files, readRDS)
fld <- function(r, nm, d = NA_real_) if (!is.null(r[[nm]])) r[[nm]] else d
df <- data.frame(
  r    = vapply(rows, fld, 0, nm = "r"),
  E    = vapply(rows, fld, 0, nm = "E"),
  err  = vapply(rows, function(x) !is.na(fld(x, "error", NA_character_)), TRUE),
  conv = vapply(rows, fld, 0, nm = "conv"),
  pd   = vapply(rows, function(x) isTRUE(x$pd_fd), TRUE),
  lam  = vapply(rows, fld, 0, nm = "lam_norm"),
  lamT = vapply(rows, fld, 0, nm = "lam_norm_true"),
  cosd = vapply(rows, fld, 0, nm = "cos_truth"),
  q    = vapply(rows, fld, 0, nm = "q_hat"),
  qT   = vapply(rows, fld, 0, nm = "q_true"))
df$rel <- abs(df$lam - df$lamT) / df$lamT
df$patches <- 1 / df$r

mcse_p <- function(p, n) sqrt(p * (1 - p) / n)
agg <- do.call(rbind, lapply(split(df, interaction(df$r, df$E, drop = TRUE)), function(g) {
  n <- nrow(g)
  data.frame(r = g$r[1], E = g$E[1], patches = 1/g$r[1], n = n,
    n_err = sum(g$err), conv_rate = mean(g$conv == 0),
    pd_rate = mean(g$pd), pd_mcse = mcse_p(mean(g$pd), n),
    med_rel = median(g$rel), iqr_lo = quantile(g$rel, .25), iqr_hi = quantile(g$rel, .75),
    mean_cos = mean(g$cosd), cos95 = mean(g$cosd > 0.95),
    bias_q = mean(g$q - g$qT), bias_q_mcse = sd(g$q - g$qT)/sqrt(n))
}))
agg <- agg[order(agg$E, agg$r), ]
write.csv(agg, file.path(out_dir, "replication-summary.csv"), row.names = FALSE)
print(agg, digits = 3, row.names = FALSE)

## ---- predeclared kill rule: anchor cells must reproduce the effort campaign
eff <- read.csv(effort_csv)
cat("\n=== anchor-consistency check (r = 0.22 vs effort campaign) ===\n")
ok_all <- TRUE
for (Ei in c(1, 2, 4)) {
  a <- agg[agg$r == 0.22 & agg$E == Ei, ]
  e <- eff[eff$E == Ei, ]
  z <- abs(a$pd_rate - e$pd_rate) / sqrt(a$pd_mcse^2 + e$pd_mcse^2)
  ok <- z <= 3
  ok_all <- ok_all && ok
  cat(sprintf("  E=%g: pd %f vs %f  |z| = %.2f  %s\n",
      Ei, a$pd_rate, e$pd_rate, z, if (ok) "OK" else "DRIFT -- STOP"))
}
if (!ok_all) stop("anchor drift: pipeline inconsistency -- do not use these results")

## ---- P1-F3: does replication move the frontier at fixed effort? ----
okabe <- c("1" = "#0072B2", "2" = "#D55E00", "4" = "#009E73")
agg$Ef <- factor(agg$E)
p1 <- ggplot(agg, aes(patches, pd_rate, colour = Ef, group = Ef)) +
  geom_ribbon(aes(ymin = pmax(0, pd_rate - pd_mcse), ymax = pmin(1, pd_rate + pd_mcse),
                  fill = Ef), alpha = .15, colour = NA) +
  geom_line(linewidth = .7) + geom_point(size = 2) +
  scale_colour_manual(values = okabe, name = "GBIF effort E") +
  scale_fill_manual(values = okabe, guide = "none") +
  labs(x = NULL, y = "P(positive-definite Hessian)",
       title = "P1-F3. Spatial replication vs GBIF effort",
       subtitle = "Identifiability and amplitude recovery of the GBIF-only field; ribbons are Monte Carlo SE (200 reps/cell)") +
  theme_minimal(base_size = 11)
p2 <- ggplot(agg, aes(patches, med_rel, colour = Ef, group = Ef)) +
  geom_ribbon(aes(ymin = iqr_lo, ymax = iqr_hi, fill = Ef), alpha = .15, colour = NA) +
  geom_line(linewidth = .7) + geom_point(size = 2) +
  geom_hline(yintercept = .25, linetype = 3) +
  scale_colour_manual(values = okabe, name = "GBIF effort E") +
  scale_fill_manual(values = okabe, guide = "none") +
  scale_y_log10() +
  labs(x = "Matern practical ranges per domain side (spatial replication)",
       y = "median |amplitude error| / truth (IQR band)",
       caption = paste0(
         "Range shrunk on the frozen 360-cell grid/118-node mesh; predictor-scale truth held EXACTLY constant\n",
         "via discrete-anchored normalisation (continuum drift up to 0.83 corrected). Field sign identified only\n",
         "jointly with loadings (positive representative). Synthetic known-truth campaign; design guidance only.")) +
  theme_minimal(base_size = 11)
suppressWarnings({
  if (requireNamespace("patchwork", quietly = TRUE)) {
    ggsave(file.path(out_dir, "P1-F3-replication-axis.png"),
           patchwork::wrap_plots(p1, p2, ncol = 1, heights = c(1, 1.15)),
           width = 7.2, height = 6.6, dpi = 220)
  } else {
    ggsave(file.path(out_dir, "P1-F3a-pd.png"), p1, width = 7.2, height = 3.4, dpi = 220)
    ggsave(file.path(out_dir, "P1-F3b-amp.png"), p2, width = 7.2, height = 3.9, dpi = 220)
  }
})
cat("figure(s) written to", out_dir, "\n")
