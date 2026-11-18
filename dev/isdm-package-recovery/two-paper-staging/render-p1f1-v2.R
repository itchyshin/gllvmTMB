## P1-F1 v2 -- the four Florence-gate fixes applied
## (2026-08-15 figure review: F1 commensurability caption, F2 range scale-bar,
##  F3 sign-orbit clause, F4 symmetric colour limits). Renders P1-F1 only;
## P2-F1 is retired pending redraw (review F5-F7). No fit, no campaign.
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
source(file.path(root, "spatial-isdm-gate-b-smoke-fixture.R"))
fixture <- spatial_isdm_gate_b_make_fixture()
truth <- fixture$truth
stopifnot(identical(truth$constants$field_correlation, 0))
out_dir <- file.path(root, "results", "two-paper-prototypes")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
library(ggplot2)

range_bar <- truth$constants$field_range   # 0.22 -- the Matern practical range
lim <- max(abs(c(truth$ecological_field, truth$gbif_bias_field)))  # F4 symmetric

field_df <- function(value, field) data.frame(
  lon = truth$coordinates$lon, lat = truth$coordinates$lat,
  value = value, field = field)
fields <- rbind(
  field_df(truth$ecological_field, "Ecological field u (known truth, unit scale)"),
  field_df(truth$gbif_bias_field,  "GBIF-only bias field h (known truth, unit scale)"))

bar <- data.frame(x = 0.05, xend = 0.05 + range_bar, y = -0.06,
                  field = unique(fields$field)[1])

p1 <- ggplot(fields, aes(lon, lat, fill = value)) +
  geom_raster() + coord_equal(expand = FALSE, clip = "off") +
  facet_wrap(~field, nrow = 1) +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B",
                       midpoint = 0, limits = c(-lim, lim),        # F4
                       name = "field value\n(unit scale)") +
  geom_segment(data = bar, aes(x = x, xend = xend, y = y, yend = y),
               inherit.aes = FALSE, linewidth = 1.1, colour = "#333333") +  # F2
  geom_text(data = bar, aes(x = x + range_bar/2, y = y - 0.045,
            label = sprintf("Matern practical range (%.2f) -- ~%.0f patches per side",
                            range_bar, 1/range_bar)),
            inherit.aes = FALSE, size = 2.9, colour = "#333333") +
  labs(title = "P1-F1 (v2). Synthetic two-field source-separation design",
       subtitle = "Known DGP truth: shared ecology reaches both sources; GBIF-only bias reaches GBIF rows only.",
       x = "synthetic longitude", y = "synthetic latitude",
       caption = paste0(
         "Both panels show UNIT-SCALE fields; what enters the likelihood is loading-scaled, per-species amplitudes\n",          # F1
         "differ between fields, and baseline GBIF effort sits near the recoverability frontier for h (effort-ladder pilot\n",  # F1
         "+ frontier campaign, 2026-08-15). Field sign is identifiable only jointly with its loadings; panels show the\n",      # F3
         "positive representative. Private design prototype; no fitted field, recovery result, or empirical claim.")) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), panel.grid = element_blank(),
        plot.subtitle = element_text(colour = "#4D4D4D"),
        plot.caption = element_text(hjust = 0, colour = "#4D4D4D"),
        panel.spacing = grid::unit(1.1, "lines"),
        plot.margin = margin(6, 8, 22, 6))
ggsave(file.path(out_dir, "P1-F1v2-synthetic-two-field-design.png"), p1,
       width = 9, height = 5.1, dpi = 220)
cat("written:", file.path(out_dir, "P1-F1v2-synthetic-two-field-design.png"), "\n")
