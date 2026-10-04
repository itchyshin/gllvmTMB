## ordiplot() documents `...` as passed to plot(). The inner plot() call
## also sets xlab, ylab, pch, col, and asp, so a user override used to
## error with "matched by multiple actual arguments" (#1408).
##
## No fit: a constructed object with the extract_ordination() slots is
## enough to reach the plot() call.

make_tiny_ordiplot_fit <- function(d = 2L, n_units = 4L, n_traits = 3L) {
  traits <- paste0("T", seq_len(n_traits))
  units <- paste0("unit", seq_len(n_units))
  scores <- matrix(
    c(-1, 0, 1, 0.5, -0.4, 0.2, 0.8, -0.1),
    nrow = n_units,
    ncol = d
  )
  Lambda <- matrix(
    c(0.4, -0.3, 0.2, 0.5, 0.1, -0.2),
    nrow = n_traits,
    ncol = d
  )
  rownames(Lambda) <- traits
  colnames(Lambda) <- paste0("LV", seq_len(d))
  structure(
    list(
      data = data.frame(
        trait = factor(rep(traits, each = n_units), levels = traits),
        unit = factor(rep(units, times = n_traits), levels = units)
      ),
      trait_col = "trait",
      unit_col = "unit",
      use = list(rr_B = TRUE, rr_W = FALSE),
      d_B = d,
      d_W = 0L,
      n_sites = n_units,
      report = list(Lambda_B = Lambda),
      tmb_obj = list(
        env = list(
          last.par.best = stats::setNames(
            as.vector(t(scores)),
            rep("z_B", n_units * d)
          )
        )
      )
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

test_that("ordiplot() user xlab ylab pch col asp override plot defaults", {
  fit <- make_tiny_ordiplot_fit()
  assign(".gllvmTMB_ordiplot_plot_args", NULL, envir = globalenv())
  on.exit(rm(".gllvmTMB_ordiplot_plot_args", envir = globalenv()), add = TRUE)
  suppressMessages(trace(
    graphics::plot.default,
    tracer = quote({
      dots <- list(...)
      assign(
        ".gllvmTMB_ordiplot_plot_args",
        list(
          xlab = xlab,
          ylab = ylab,
          asp = asp,
          pch = dots$pch,
          col = dots$col
        ),
        envir = globalenv()
      )
    }),
    print = FALSE
  ))
  on.exit(suppressMessages(untrace(graphics::plot.default)), add = TRUE)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(
    ordiplot(
      fit,
      xlab = "a",
      ylab = "b",
      pch = 1,
      col = "red",
      asp = NA,
      biplot = FALSE
    )
  )
  captured <- get(".gllvmTMB_ordiplot_plot_args", envir = globalenv())
  expect_identical(captured$xlab, "a")
  expect_identical(captured$ylab, "b")
  expect_identical(captured$pch, 1)
  expect_identical(captured$col, "red")
  expect_identical(captured$asp, NA)
})
