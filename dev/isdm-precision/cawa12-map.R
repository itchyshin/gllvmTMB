## ---------------------------------------------------------------------------
## cawa12-map.R -- the twelve-species relative-intensity map
##
## DESIGN: one FLAGSHIP panel plus eleven small multiples, NOT twelve equal
## panels. The domain is about 250 km wide by 500 km tall, so a map panel is
## twice as tall as it is wide; twelve of them at vignette width give each
## species roughly 1.4 inches with no room for axes, a scale, or a location
## overlay, and the figure degenerates into wallpaper. One large panel carries
## the axes, the labelled isolines and the sampled locations -- everything a
## reader needs in order to learn how to read a panel of this figure -- and
## the eleven small panels then only have to be COMPARABLE, which they are
## because they share the colour scale, the isoline levels and the limits.
##
## Panels are ordered by the correlation of each species' log-intensity
## surface with the flagship's, computed on the reference fit, so the grid
## reads as a gradient from "most like the flagship" to "least" rather than
## as an arbitrary sequence. That ordering is a fit-derived quantity, not a
## design flourish: it is what makes eleven thumbnails legible at all.
##
## COLOUR IS NEVER THE ONLY CHANNEL:
##   * isolines at fixed relative-intensity levels are drawn on EVERY panel
##     with a white halo under a dark core, so they read on both ends of the
##     ramp and survive greyscale and photocopying;
##   * a rail under each panel places that species' 5th-95th percentile and
##     median on the shared scale by POSITION and LENGTH -- amplitude is
##     exactly what a shared colour ramp compresses away.
##
## Cells outside the mesh hull are HATCHED, not filled flat grey. A flat grey
## sits at mid-luminance, so against the dark end of viridis it reads in
## greyscale as ELEVATED intensity -- the inverse of what the mask means.
## Hatching is a texture, not a tone, and cannot be misread as a value.
##
## The fence is drawn INSIDE the canvas because a PNG lifted into a talk or a
## thesis keeps its pixels and loses its caption.
##
## Geometry is solved from par("din") against BOTH the width and the height
## budget and the tighter constraint wins, so a change of figure size shrinks
## the panels rather than clipping them.
##
## Base R only; no dependency beyond what gllvmTMB already imports.
##
## Entry point: cawa12_map_plot(readRDS("cawa12-mapdata.rds"))
## ---------------------------------------------------------------------------

CAWA12_SHORT <- c(
  CAWA = "Canada Warbler",   OVEN = "Ovenbird",
  TEWA = "Tennessee W.",     BLPW = "Blackpoll W.",
  BBWA = "Bay-breasted W.",  BTNW = "Bl-th Green W.",
  CMWA = "Cape May W.",      MAWA = "Magnolia W.",
  SWTH = "Swainson's Thr.",  WTSP = "White-thr Sparrow",
  YRWA = "Yellow-rumped W.", RBNU = "Red-br Nuthatch"
)

#' Draw the twelve-species map.
#'
#' @param md Object from `cawa12-mapdata.rds`.
#' @param levels_nat Isoline levels on the natural (relative intensity) scale.
#' @param n_cols Number of small-multiple columns.
#' @param fence In-plot warning text.
#' @return Invisibly, the geometry and scale actually used.
cawa12_map_plot <- function(md,
                            levels_nat = c(0.1, 0.3, 1, 3),
                            n_cols = 4L,
                            fence = paste("SIMULATED DATA -- no uncertainty",
                                          "shown, no real observations")) {
  gx <- md$gx; gy <- md$gy
  nx <- length(gx); ny <- length(gy)
  oo <- md$out_of_hull
  flag <- md$flagship
  ord <- c(flag, setdiff(md$panel_order, flag))
  small <- ord[-1]

  ## log10 relative intensity; out-of-hull cells are not values, so they take
  ## no part in the scale and are never coloured.
  lz <- log10(md$est)
  lz[oo, ] <- NA_real_
  lo <- min(lz, na.rm = TRUE); hi <- max(lz, na.rm = TRUE)
  nb <- 64L
  brk <- seq(lo, hi, length.out = nb + 1L)
  pal <- grDevices::hcl.colors(nb, "viridis")
  keep <- levels_nat > 10^(lo + 0.02 * (hi - lo)) &
          levels_nat < 10^(hi - 0.02 * (hi - lo))
  levs <- levels_nat[keep]
  lev <- log10(levs)

  dx <- diff(gx)[1] / 2; dy <- diff(gy)[1] / 2
  xl <- c(min(gx) - dx, max(gx) + dx)
  yl <- c(min(gy) - dy, max(gy) + dy)
  W <- diff(xl); H <- diff(yl)
  ## Room under the map for the rail. It was 0.115 H and the flagship's x-axis
  ## tick labels then landed ON the rail (seen in the render, not predicted);
  ## widening the strip and pushing the rail up against the map separates the
  ## two bands by about half an inch at vignette size.
  strip <- 0.17 * H
  ylp <- c(yl[1] - strip, yl[2])
  asp <- (H + strip) / W                # panel aspect, map + rail

  zmat <- function(sp) matrix(lz[, sp], nrow = nx, ncol = ny)

  ## -- geometry, solved against width AND height ----------------------------
  din <- graphics::par("din"); Win <- din[1]; Hin <- din[2]
  title_h <- 0.62; foot_h <- 0.98       # inches reserved top and bottom
  lab_h   <- 0.30                       # label strip above every panel
  fl_mai  <- c(0.40, 0.60, lab_h, 0.05) # flagship: bottom, left, top, right
  th_pad  <- 0.045                      # thumbnail side padding
  mid_gap <- 0.10
  side_m  <- 0.11                       # keep ink off the canvas edge
  n_rows  <- ceiling((length(small) + 1L) / n_cols)   # +1 slot for the key

  row_h <- function(t) asp * t + lab_h
  ## flagship spans all rows: asp * w + fl_mai[1] + fl_mai[3] = n_rows * row_h
  w_of <- function(t) (n_rows * row_h(t) - fl_mai[1] - fl_mai[3]) / asp
  ## width budget
  t_w <- (Win - 2 * side_m - fl_mai[2] - fl_mai[4] - mid_gap -
            n_cols * 2 * th_pad -
            (n_rows * lab_h - fl_mai[1] - fl_mai[3]) / asp) /
         (n_cols + n_rows)
  ## height budget
  t_h <- ((Hin - title_h - foot_h) / n_rows - lab_h) / asp
  t <- min(t_w, t_h)
  w <- w_of(t)
  block_w <- fl_mai[2] + w + fl_mai[4] + mid_gap + n_cols * (t + 2 * th_pad)
  block_h <- n_rows * row_h(t)
  x_off <- (Win - block_w) / 2
  y_top <- Hin - title_h - (Hin - title_h - foot_h - block_h) / 2

  ## ~24 hatch strokes across a panel, whatever the panel's width in inches
  hatch_dens <- function(width_in) 24 / width_in

  ndc <- function(x0, x1, y0, y1)
    c(x0 / Win, x1 / Win, y0 / Hin, y1 / Hin)

  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  graphics::par(oma = c(0, 0, 0, 0), xpd = NA)
  graphics::plot.new()                  # claim the device once

  ## Hatch density is per INCH of device, so it must be scaled to the panel:
  ## the value that reads well on the 2.4-inch flagship leaves only one or two
  ## strokes across a 0.8-inch thumbnail, and the mask then reads in greyscale
  ## as a near-WHITE patch -- worse than the flat grey it replaced, because
  ## white is the top of the ramp. Measured on the draft: at density 15 the
  ## thumbnail mask was indistinguishable from peak intensity in greyscale.
  ## Cross-hatching adds a second axis so the texture cannot resolve to a tone.
  draw_hull <- function(dens, lwd) {
    if (!any(oo)) return(invisible())
    gxo <- md$grid$X[oo]; gyo <- md$grid$Y[oo]
    graphics::rect(gxo - dx, gyo - dy, gxo + dx, gyo + dy,
                   col = "white", border = NA)
    graphics::rect(gxo - dx, gyo - dy, gxo + dx, gyo + dy, col = "grey20",
                   border = NA, density = dens, angle = 45, lwd = lwd)
    graphics::rect(gxo - dx, gyo - dy, gxo + dx, gyo + dy, col = "grey20",
                   border = NA, density = dens * 0.6, angle = 135, lwd = lwd)
    ## A hard outline around the masked REGION. Downsampling to the width a
    ## reader actually sees (about 700 px in an html_vignette) averages a fine
    ## hatch back towards a flat tone; an outline survives it, and no value
    ## surface anywhere on these panels has a hard boundary, so the outline
    ## cannot be read as data.
    M <- matrix(oo, nx, ny)
    idx <- which(M, arr.ind = TRUE)
    i <- idx[, 1]; j <- idx[, 2]
    edge <- function(sel, x0, y0, x1, y1)
      if (any(sel)) graphics::segments(x0[sel], y0[sel], x1[sel], y1[sel],
                                       col = "grey15", lwd = lwd * 1.1)
    left  <- i == 1L  | !M[cbind(pmax(i - 1L, 1L), j)]
    right <- i == nx  | !M[cbind(pmin(i + 1L, nx), j)]
    down  <- j == 1L  | !M[cbind(i, pmax(j - 1L, 1L))]
    up    <- j == ny  | !M[cbind(i, pmin(j + 1L, ny))]
    edge(left,  gx[i] - dx, gy[j] - dy, gx[i] - dx, gy[j] + dy)
    edge(right, gx[i] + dx, gy[j] - dy, gx[i] + dx, gy[j] + dy)
    edge(down,  gx[i] - dx, gy[j] - dy, gx[i] + dx, gy[j] - dy)
    edge(up,    gx[i] - dx, gy[j] + dy, gx[i] + dx, gy[j] + dy)
  }

  ## Rail: the full shared range as a hairline rail, this species' 5th-95th
  ## percentile as a solid bar, the median as a notch.
  ## `rail_off` is measured DOWNWARD from the map's bottom edge. On the
  ## flagship the x-axis ticks and their labels are drawn immediately under
  ## that edge -- measured in the render, whatever par("usr") reports -- so
  ## the rail has to sit below them; on the axis-free thumbnails it sits
  ## tight under the map.
  draw_rail <- function(sp, lwd, rail_off) {
    q <- stats::quantile(lz[, sp], c(0.05, 0.5, 0.95), na.rm = TRUE)
    x0 <- xl[1] + 0.06 * W; x1 <- xl[2] - 0.06 * W
    f <- function(v) x0 + (v - lo) / (hi - lo) * (x1 - x0)
    yc <- yl[1] - rail_off * H; hh <- 0.019 * H
    graphics::rect(x0, yc - hh * 0.4, x1, yc + hh * 0.4,
                   col = "grey93", border = "grey60", lwd = lwd * 0.7)
    graphics::rect(f(q[1]), yc - hh, f(q[3]), yc + hh,
                   col = "grey35", border = NA)
    graphics::segments(f(q[2]), yc - hh * 1.7, f(q[2]), yc + hh * 1.7,
                       col = "white", lwd = lwd * 2.2)
    graphics::segments(f(q[2]), yc - hh * 1.7, f(q[2]), yc + hh * 1.7,
                       col = "black", lwd = lwd * 0.9)
    invisible(q)
  }

  ## Isolines with a white halo under a dark core: readable on the dark end of
  ## viridis AND on the pale end, which a single-colour line is not.
  ## Inline contour labels were TRIED and REMOVED: at this panel size
  ## contour() broke each line to make room for a label that then rendered
  ## illegibly, leaving white gashes across the surface. The isoline levels
  ## are instead the SAME values as the colour-bar ticks, so the bar labels
  ## them once for all twelve panels.
  draw_iso <- function(sp, lwd) {
    z <- zmat(sp)
    graphics::contour(gx, gy, z, levels = lev, add = TRUE, drawlabels = FALSE,
                      col = "white", lwd = lwd * 2.1)
    graphics::contour(gx, gy, z, levels = lev, add = TRUE, drawlabels = FALSE,
                      col = "grey15", lwd = lwd)
  }

  panel <- function(sp, region, mai, axes, dens, lwd, label_cex) {
    graphics::par(fig = region, mai = mai, new = TRUE)
    graphics::plot.new()
    graphics::plot.window(xlim = xl, ylim = ylp, xaxs = "i", yaxs = "i")
    graphics::image(gx, gy, zmat(sp), col = pal, breaks = brk, add = TRUE,
                    useRaster = TRUE)
    draw_hull(dens, lwd)
    draw_iso(sp, lwd)
    if (axes) {
      graphics::points(md$points$X, md$points$Y, pch = 21, bg = "white",
                       col = "black", cex = 0.36, lwd = 0.45)
      ## The rail strip extends this panel's y range BELOW the map, so the
      ## default axis position and pretty() both run into the strip: draft 2
      ## grew an orphan "5900" tick sitting under the panel, and the x axis
      ## floated below the rail instead of on the map's edge. Pin both axes
      ## to the map's own edges and restrict the ticks to the map's range.
      atx <- pretty(xl); atx <- atx[atx > xl[1] & atx < xl[2]]
      aty <- pretty(yl); aty <- aty[aty > yl[1] & aty < yl[2]]
      graphics::axis(1, at = atx, pos = yl[1], cex.axis = 0.62, tcl = -0.22,
                     mgp = c(2, 0.20, 0), lwd = 0, lwd.ticks = 0.7)
      graphics::axis(2, at = aty, pos = xl[1], cex.axis = 0.62, tcl = -0.22,
                     mgp = c(2, 0.42, 0), las = 1, lwd = 0, lwd.ticks = 0.7)
      ## Below the rail, not between axis and rail: drawn inside the plot
      ## region it landed under the rail, which is drawn after the axes.
      graphics::mtext("UTM easting (km)", side = 1, line = 0.75, cex = 0.6)
      graphics::mtext("UTM northing (km)", side = 2, line = 1.75, cex = 0.6)
    }
    graphics::rect(xl[1], yl[1], xl[2], yl[2], border = "black", lwd = lwd)
    draw_rail(sp, lwd, if (axes) 0.125 else 0.048)
    graphics::mtext(sp, side = 3, line = 0.52, cex = label_cex, font = 2)
    graphics::mtext(CAWA12_SHORT[[sp]], side = 3, line = 0.03,
                    cex = label_cex * 0.84, col = "grey25")
  }

  ## -- flagship --------------------------------------------------------------
  fx0 <- x_off
  fx1 <- x_off + fl_mai[2] + w + fl_mai[4]
  panel(flag, ndc(fx0, fx1, y_top - block_h, y_top), fl_mai,
        axes = TRUE, dens = hatch_dens(w), lwd = 0.85, label_cex = 0.80)

  ## -- small multiples, filled ROW-WISE so the ordering reads left to right --
  gx0 <- fx1 + mid_gap
  slot_w <- t + 2 * th_pad
  cell <- function(i) {
    r <- (i - 1L) %/% n_cols; cc <- (i - 1L) %% n_cols
    x0 <- gx0 + cc * slot_w
    y1 <- y_top - r * row_h(t)
    ndc(x0, x0 + slot_w, y1 - row_h(t), y1)
  }
  th_mai <- c(0, th_pad, lab_h, th_pad)
  for (i in seq_along(small))
    panel(small[i], cell(i), th_mai, axes = FALSE, dens = hatch_dens(t),
          lwd = 0.5, label_cex = 0.62)

  ## -- key slot: shared colour bar, isoline key, hatch key -------------------
  graphics::par(fig = cell(length(small) + 1L),
                mai = c(0, th_pad, lab_h, th_pad), new = TRUE)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, 1), ylim = c(0, 1), xaxs = "i", yaxs = "i")
  by0 <- 0.30; by1 <- 0.88
  yy <- seq(by0, by1, length.out = nb + 1L)
  graphics::rect(0.04, yy[-(nb + 1L)], 0.40, yy[-1], col = pal, border = NA)
  graphics::rect(0.04, by0, 0.40, by1, border = "black", lwd = 0.6)
  aty <- by0 + (lev - lo) / (hi - lo) * (by1 - by0)
  graphics::segments(0.40, aty, 0.47, aty, lwd = 0.6)
  graphics::text(0.50, aty, format(levs), adj = 0, cex = 0.55)
  graphics::text(0.04, by1 + 0.075, "relative intensity", adj = 0, cex = 0.58)
  graphics::text(0.04, by1 + 0.030, "(log scale)", adj = 0, cex = 0.52,
                 col = "grey30")
  ## isoline key: same halo construction as the panels
  graphics::segments(0.06, 0.22, 0.30, 0.22, col = "white", lwd = 1.7)
  graphics::segments(0.06, 0.22, 0.30, 0.22, col = "grey15", lwd = 0.8)
  graphics::text(0.34, 0.245, "isolines", adj = 0, cex = 0.52)
  graphics::text(0.34, 0.195, "at the ticks", adj = 0, cex = 0.52)
  ## hatch key: the mask is defined inside the figure, not only in the caption
  graphics::rect(0.06, 0.06, 0.30, 0.16, col = "white", border = "black",
                 lwd = 0.5)
  graphics::rect(0.06, 0.06, 0.30, 0.16, col = "grey20", border = NA,
                 density = hatch_dens(t), angle = 45, lwd = 0.5)
  graphics::rect(0.06, 0.06, 0.30, 0.16, col = "grey20", border = NA,
                 density = hatch_dens(t) * 0.6, angle = 135, lwd = 0.5)
  graphics::text(0.34, 0.135, "outside", adj = 0, cex = 0.52)
  graphics::text(0.34, 0.085, "mesh hull", adj = 0, cex = 0.52)

  ## -- titles and footer -----------------------------------------------------
  graphics::par(fig = c(0, 1, 0, 1), mai = c(0, 0, 0, 0), new = TRUE)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0, Win), ylim = c(0, Hin),
                        xaxs = "i", yaxs = "i")
  med_stab <- stats::median(md$stability$median_cor)
  graphics::text(Win / 2, Hin - 0.24,
                 "Relative intensity for twelve boreal songbirds, one integrated fit",
                 cex = 0.86, font = 2)
  graphics::text(Win / 2, Hin - 0.46, sprintf(paste(
    "shared log colour scale; panels ordered by similarity of the surface to",
    "the flagship's (r = %.2f down to %.2f)"),
    max(md$sim_to_flagship[small]), min(md$sim_to_flagship[small])),
    cex = 0.58, col = "grey30")
  f1 <- foot_h
  graphics::text(Win / 2, f1 - 0.20, paste(
    "rail under each panel: that species' 5th-95th percentile on the shared",
    "scale, notch at the median -- amplitude is what one shared ramp hides"),
    cex = 0.55, col = "grey30")
  graphics::text(Win / 2, f1 - 0.36, paste(
    "hatched cells lie outside the mesh hull, where the spatial field is",
    "exactly zero rather than estimated; circles: all 360 sampled locations"),
    cex = 0.55, col = "grey30")
  graphics::text(Win / 2, f1 - 0.52, sprintf(paste(
    "reference seed %d of %d accepted fits; the surfaces reproduce across",
    "seeds (median within-species r = %.2f, lowest %.2f)"),
    md$ref_seed, length(md$ok_seeds), med_stab, min(md$stability$min_cor)),
    cex = 0.55, col = "grey30")
  graphics::text(Win / 2, 0.16, fence, cex = 0.74, font = 2, col = "#B2182B")

  invisible(list(range_log10 = c(lo, hi), levels = levs, order = ord,
                 flagship_in = c(w, asp * w), thumb_in = c(t, asp * t),
                 fig_in = din, block_in = c(block_w, block_h),
                 median_stability = med_stab))
}
