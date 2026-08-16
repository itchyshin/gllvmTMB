## Render only the two authorised design prototypes (P1-F1 and P2-F1).
## This script deliberately does not fit, optimise, profile, or campaign-run.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this private renderer with Rscript <file>.")
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
source(file.path(root, "spatial-isdm-gate-b-smoke-fixture.R"))
fixture <- spatial_isdm_gate_b_make_fixture()
truth <- fixture$truth
if (!identical(truth$constants$field_correlation, 0)) {
  stop("P1-F1 requires zero DGP cross-field correlation.")
}

out_dir <- file.path(root, "results", "two-paper-prototypes")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
library(ggplot2)

theme_private <- theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), panel.grid = element_blank(),
        plot.subtitle = element_text(colour = "#4D4D4D"),
        panel.spacing = grid::unit(1.1, "lines"))
field_df <- function(value, field) data.frame(
  lon = truth$coordinates$lon, lat = truth$coordinates$lat, value = value, field = field
)
fields <- rbind(
  field_df(truth$ecological_field, "Ecological field u (known truth)"),
  field_df(truth$gbif_bias_field, "GBIF-only bias field h (known truth)")
)

p1 <- ggplot(fields, aes(lon, lat, fill = value)) +
  geom_raster() + coord_equal(expand = FALSE) + facet_wrap(~field, nrow = 1) +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B",
                       midpoint = 0, name = "field value") +
  labs(title = "P1-F1. Synthetic two-field source-separation design",
       subtitle = "Known DGP truth: shared ecology reaches both sources; GBIF-only bias reaches GBIF rows only.",
       x = "synthetic longitude", y = "synthetic latitude",
       caption = "Private design prototype; no fitted field, recovery result, or empirical claim.") +
  theme_private
ggsave(file.path(out_dir, "P1-F1-synthetic-two-field-design.png"), p1,
       width = 9, height = 4.7, dpi = 220)

nodes <- data.frame(
  x = c(1, 1, 3, 3, 5, 6.8), y = c(2.2, 0.8, 2.2, 0.8, 1.5, 1.5),
  label = c("GBIF\nPoisson", "PA cloglog\n3 visits", "shared ecological\nstate",
            "GBIF-only\nbias covariate", "rank-one Lambda Lambda^T\n+ diagonal Psi",
            "frozen A-D gate\nCase C: NO_CANDIDATE"),
  type = c("source", "source", "state", "bias", "covariance", "gate")
)
edges <- data.frame(x = c(1.35, 1.35, 1.35, 3.35, 3.35),
                    y = c(2.2, 0.8, 2.2, 2.2, 0.8),
                    xend = c(2.65, 2.65, 2.65, 4.65, 4.65),
                    yend = c(2.2, 2.2, 0.8, 1.5, 1.5))
p2 <- ggplot() +
  geom_segment(data = edges, aes(x, y, xend = xend, yend = yend),
               arrow = grid::arrow(length = grid::unit(0.14, "inches")), colour = "#555555") +
  geom_label(data = nodes, aes(x, y, label = label, fill = type), size = 3.5, linewidth = 0.25) +
  geom_segment(aes(x = 5.45, y = 1.5, xend = 6.45, yend = 1.5),
               arrow = grid::arrow(length = grid::unit(0.14, "inches")), colour = "#555555") +
  scale_fill_manual(values = c(source = "#D9EAF7", state = "#DCECCB",
                                bias = "#F9D5C4", covariance = "#E8D8F1", gate = "#F4CCCC"), guide = "none") +
  coord_cartesian(xlim = c(0.25, 7.65), ylim = c(0.1, 3), clip = "off") +
  labs(title = "P2-F1. Frozen numerical and diagonal-Psi diagnostic design",
       subtitle = "A numerical-admission predicate and P diagonal-Psi recovery criterion are reported separately.",
       caption = "Private design prototype; not a recovery frequency, causal explanation, or empirical analysis.") +
  theme_private +
  theme(axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(),
        plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(colour = "#4D4D4D"),
        plot.caption = element_text(hjust = 0), plot.margin = margin(8, 18, 8, 8))
ggsave(file.path(out_dir, "P2-F1-frozen-numerical-psi-design.png"), p2,
       width = 9, height = 4.7, dpi = 220)

sidecar <- c(
  "# Private prototype receipt", "",
  "- figure_ids: P1-F1, P2-F1",
  "- role: synthetic known-truth design / frozen diagnostic design",
  "- caption_gate: prototype only; no result claim authorised",
  paste0("- fixture_md5: ", unname(tools::md5sum(file.path(root, "spatial-isdm-gate-b-smoke-fixture.R")))),
  paste0("- renderer_md5: ", unname(tools::md5sum(script_path))),
  paste0("- R: ", R.version.string),
  "- P1 denominator: synthetic DGP C=360, S=3, r=3; not a fitted attempt",
  "- P2 denominator: no attempt; schematic only",
  "- uncertainty: not applicable; no estimates are displayed",
  "- data/licence/privacy: no empirical records used",
  "- prohibited: recovery, prediction, ecology, occupancy, detection, abundance, causal bias removal, scalability"
)
writeLines(sidecar, file.path(out_dir, "prototype-receipt.md"))
