#!/usr/bin/env Rscript

# Generate the two printable companions to the public function-map article.
# Run from the package root: Rscript tools/build-function-cheatsheets.R

source("dev/function-map-inventory.R")

exports <- sub(
  '^export\\(([^)]+)\\)$', '\\1',
  grep('^export\\(', readLines("NAMESPACE", warn = FALSE), value = TRUE)
)
namespace_lines <- readLines("NAMESPACE", warn = FALSE)
fitted_methods <- c("predict", "simulate")
method_exports <- fitted_methods[vapply(fitted_methods, function(fun) {
  any(grepl(paste0("^S3method\\(", fun, ",gllvmTMB_multi\\)$"), namespace_lines))
}, logical(1))]
missing <- setdiff(function_map_primary_exports, c(exports, method_exports))
if (length(missing)) {
  stop("Primary function-map entries are not exported: ",
       paste(missing, collapse = ", "), call. = FALSE)
}
if (length(intersect(function_map_primary_exports, function_map_compatibility))) {
  stop("Compatibility functions entered the primary map.", call. = FALSE)
}
export_classification <- function_map_classify_exports(exports)
if (!identical(sort(names(export_classification)), sort(exports)) ||
    anyNA(export_classification) ||
    !all(export_classification %in% c("featured", "compatibility", "reference_only"))) {
  stop("Every exported function must have a function-map classification.", call. = FALSE)
}

output_dir <- "pkgdown/assets/cheatsheets"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

ink <- "#173042"
muted <- "#526875"
paper <- "#F7FAFB"
wrap <- function(x, width) paste(strwrap(x, width = width), collapse = "\n")

draw_header <- function(title, subtitle) {
  par(mar = c(0, 0, 0, 0), xpd = NA)
  plot.new(); plot.window(xlim = c(0, 1), ylim = c(0, 1))
  rect(0, 0, 1, 1, col = paper, border = NA)
  rect(0, .89, 1, 1, col = "#052B3F", border = NA)
  text(.045, .955, "gllvmTMB", col = "white", font = 2, adj = c(0, .5), cex = 1.35)
  text(.045, .912, title, col = "white", adj = c(0, .5), cex = .9)
  text(.955, .912, "https://itchyshin.github.io/gllvmTMB/", col = "#D8E8ED",
       adj = c(1, .5), cex = .56)
  text(.045, .862, subtitle, col = muted, adj = c(0, .5), cex = .7)
}

draw_panel <- function(x0, y0, width, height, item, compact = FALSE) {
  rect(x0, y0 - height, x0 + width, y0, col = "white", border = item$colour, lwd = 1.3)
  rect(x0, y0 - .055, x0 + width, y0, col = item$colour, border = NA)
  text(x0 + .018, y0 - .027, item$label, col = "white", adj = c(0, .5), font = 2, cex = .74)
  text(x0 + .02, y0 - .075, wrap(item$purpose, if (compact) 36 else 42),
       col = ink, adj = c(0, 1), cex = if (compact) .59 else .65)
  shown_functions <- if (compact) item$functions else head(item$functions, 2)
  function_label <- paste0(
    if (compact) "Functions: " else "Key functions: ",
    paste0(shown_functions, "()", collapse = ", "),
    if (!compact && length(item$functions) > length(shown_functions)) "; see HTML" else ""
  )
  y_fun <- y0 - if (compact) .145 else .16
  text(x0 + .02, y_fun, wrap(function_label, if (compact) 78 else 39),
       col = item$colour, adj = c(0, 1), font = 2, cex = if (compact) .53 else .56)
  text(x0 + .02, y_fun - if (compact) .045 else .052,
       wrap(item$route, if (compact) 39 else 46), col = muted, adj = c(0, 1),
       cex = if (compact) .53 else .58)
}

map_path <- file.path(output_dir, "gllvmTMB-function-map.pdf")
grDevices::pdf(map_path, width = 16, height = 9, useDingbats = FALSE)
draw_header("Function map", "A task-based guide to the current public workflow. Read the HTML article for links and full boundaries.")
coords <- list(c(.045, .79), c(.365, .79), c(.685, .79), c(.045, .42), c(.365, .42), c(.685, .42))
for (i in seq_along(function_map_inventory)) {
  xy <- coords[[i]]
  draw_panel(xy[1], xy[2], .27, .29, function_map_inventory[[i]])
}
text(.5, .055,
     "Typical route: Prepare and specify  ->  Fit  ->  Check fit health  ->  Interpret covariance.  Prediction, simulation, and uncertainty are conditional branches.",
     col = ink, cex = .68)
text(.5, .026,
     "Navigation aid only: a documented function can still be unsuitable for a particular family, data set, or covariance tier.",
     col = muted, cex = .59)
grDevices::dev.off()

sheet_path <- file.path(output_dir, "gllvmTMB-function-cheatsheet.pdf")
grDevices::pdf(sheet_path, width = 11.69, height = 8.27, useDingbats = FALSE)
draw_cheatsheet_panel <- function(x0, y0, width, height, item) {
  rect(x0, y0 - height, x0 + width, y0, col = "white", border = item$colour, lwd = 1.25)
  rect(x0, y0 - .05, x0 + width, y0, col = item$colour, border = NA)
  text(x0 + .018, y0 - .025, item$label, col = "white", adj = c(0, .5),
       font = 2, cex = if (nchar(item$label) > 32) .54 else .68)
  text(x0 + .018, y0 - .067, wrap(item$purpose, 42), col = ink,
       adj = c(0, 1), cex = .52)
  text(x0 + .018, y0 - .125,
       wrap(paste0("Functions: ", paste0(item$functions, "()", collapse = ", ")), 39),
       col = item$colour, adj = c(0, 1), font = 2, family = "mono", cex = .47)
  text(x0 + .018, y0 - .185, wrap(item$route, 42), col = muted,
       adj = c(0, 1), cex = .48)
}
draw_header(
  "Function cheatsheet",
  "Six current first-use routes. The HTML article carries links, examples, and full scope boundaries."
)
sheet_coords <- list(
  c(.045, .81), c(.515, .81), c(.045, .55),
  c(.515, .55), c(.045, .29), c(.515, .29)
)
for (i in seq_along(function_map_inventory)) {
  xy <- sheet_coords[[i]]
  draw_cheatsheet_panel(xy[1], xy[2], .44, .22, function_map_inventory[[i]])
}
text(.5, .025,
     "Long and wide data both enter through gllvmTMB(); choose the task first, then check the linked article for family, tier, and interval boundaries.",
     col = muted, adj = c(.5, .5), cex = .48)
grDevices::dev.off()

message("Wrote ", map_path, " and ", sheet_path)
