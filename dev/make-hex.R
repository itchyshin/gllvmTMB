# dev/make-hex.R
# Build the gllvmTMB hex logo. Simpler "v6" design matching the
# maintainer's reference: dark navy hex, large "gllvmTMB" wordmark
# (white-to-cyan gradient effect), a soft dotted-wave network at the
# bottom, faint dotted contour lines in the top half, a clean rim.
# Replaces the busier v5 design (phylogeny + spatial heatmap + trait
# grid + icons + "FLEXIBLE / FAST / POWERFUL" tagline).

set.seed(7)

out_path <- "man/figures/logo.png"
W <- 1200
H <- 1390

png(out_path, width = W, height = H, units = "px",
    res = 200, bg = "transparent", type = "cairo-png")
op <- par(mar = c(0, 0, 0, 0), oma = c(0, 0, 0, 0), bg = NA, xpd = NA)

plot.new()
plot.window(xlim = c(-1, 1), ylim = c(-1.155, 1.155), asp = 1)

# Hex outline (pointy top)
ang <- seq(90, 90 - 360, length.out = 7) * pi / 180
hx  <- cos(ang)
hy  <- sin(ang)

# Palette
col_bg     <- "#0a1f3d"   # deep navy
col_bg_mid <- "#15396b"   # mid navy
col_wm_w   <- "#ffffff"   # white wordmark
col_wm_c   <- "#3aa0ff"   # cyan accent
col_dot1   <- "#3aa0ff"   # blue
col_dot2   <- "#5cd6c0"   # teal
col_dot3   <- "#7fd86b"   # soft green
col_dot4   <- "#f7c948"   # warm yellow
col_dot5   <- "#f59866"   # soft amber
col_border <- "#5b9eff"   # rim

# Helper: keep dots inside the hex
in_hex <- function(x, y, inset = 1) {
  R <- inset
  abs(y) <= R &
    abs(x * sqrt(3)/2 + y/2) <= R * sqrt(3)/2 &
    abs(x * sqrt(3)/2 - y/2) <= R * sqrt(3)/2
}

# Background hex
polygon(hx, hy, col = col_bg, border = NA)

# Faint dotted contour-style waves in the upper half
for (k in 1:3) {
  amp <- 0.05 + 0.02 * k
  y0  <- 0.55 - 0.10 * k
  xs  <- seq(-0.85, 0.85, length.out = 200)
  ys  <- y0 + amp * sin(2 * pi * xs / 0.7 + k)
  for (j in seq_len(length(xs))) {
    if (j %% 2 == 0) next
    points(xs[j], ys[j], pch = 19,
           col = adjustcolor(col_border, 0.18),
           cex = 0.18)
  }
}

# Sparse "starry" dots in the upper portion (clipped to hex)
n_stars <- 60
sx <- runif(n_stars, -0.95, 0.95)
sy <- runif(n_stars,  0.10, 0.95)
sz <- runif(n_stars,  0.20, 0.80)
keep <- in_hex(sx, sy, inset = 0.92)
points(sx[keep], sy[keep], pch = 19,
       col = adjustcolor(col_border, 0.35), cex = sz[keep])

# WORDMARK: "gllvm" white + "TMB" cyan, side by side
text(0, 0.16, labels = "gllvm",
     family = "sans", font = 2, cex = 4.4, col = col_wm_w,
     pos = 2, offset = 0)
text(0, 0.16, labels = "TMB",
     family = "sans", font = 2, cex = 4.4, col = col_wm_c,
     pos = 4, offset = 0)

# Network arc with coloured dots at the lower-middle band
arc_x <- seq(-0.55, 0.55, length.out = 6)
arc_y <- -0.18 + 0.05 * sin(seq(-pi/2, pi/2, length.out = 6))
arc_cols <- c(col_dot1, col_dot1, col_dot2, col_dot3, col_dot4, col_dot5)
# connecting curve
xx <- seq(-0.65, 0.65, length.out = 200)
yy <- -0.18 + 0.06 * sin(seq(-pi/2, pi/2, length.out = 200) * 1.2)
lines(xx, yy, col = adjustcolor(col_border, 0.40), lwd = 1.6, lend = 1)
# the dots themselves
points(arc_x, arc_y, pch = 19, col = arc_cols, cex = 2.0)
points(arc_x, arc_y, pch = 21, col = adjustcolor("white", 0.35),
       bg = NA, cex = 3.4, lwd = 0.8)

# Dotted-wave "data cloud" in the lower band
n_cloud <- 700
cloud_x <- runif(n_cloud, -0.85, 0.85)
cloud_y_base <- -0.55 + 0.06 * sin(cloud_x * 4) + 0.04 * sin(cloud_x * 1.5)
cloud_y <- cloud_y_base + rnorm(n_cloud, sd = 0.04)
# colour gradient left -> right (blue -> green -> yellow)
norm_x <- (cloud_x - min(cloud_x)) / diff(range(cloud_x))
pal <- colorRampPalette(c(col_dot1, col_dot2, col_dot3, col_dot4, col_dot5))(120)
idx <- pmin(120L, pmax(1L, ceiling(norm_x * 120)))
cloud_col <- adjustcolor(pal[idx], 0.65)
points(cloud_x, cloud_y, pch = 19, col = cloud_col, cex = 0.30)

# Hex border (clean cyan rim, 2-stroke for crispness)
lines(hx * 1.005, hy * 1.005, col = "#04101f", lwd = 1.2, lend = 1, ljoin = 1)
lines(hx, hy, col = col_border, lwd = 5, lend = 1, ljoin = 1)

par(op)
dev.off()
invisible(NULL)
