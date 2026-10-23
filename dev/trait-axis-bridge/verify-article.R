article <- "vignettes/articles/where-does-the-tree-go.Rmd"
article_source <- readLines(article, warn = FALSE)
article_text <- paste(article_source, collapse = "\n")

required_column_example <- c(
  "latitude:pathway",
  "phylo_slope(latitude | trait, tree = tree)",
  "latent(0 + trait | site_id, d = 2, unique = FALSE)",
  "pathway_difference",
  "`latitude:pathway` is a **fixed effect**",
  "There is no `column_coef()`",
  "`*_slope()` supplies random response-column deviations",
  "it does not estimate a separate IID-versus-phylogenetic",
  "The simulated C3 and C4 gradients differ by design",
  "{r community-data, echo = FALSE",
  "{r community-wide, echo = FALSE"
)
missing_column_example <- required_column_example[
  !vapply(required_column_example, grepl, logical(1),
          x = article_text, fixed = TRUE)
]
if (length(missing_column_example) > 0L) {
  stop(
    "The response-column example must separate fixed pathway moderation, ",
    "phylogenetic latitude-slope deviations, and residual site association. ",
    "Missing: ", paste(missing_column_example, collapse = "; ")
  )
}

forbidden_column_example <- c(
  "{r species-axis-data, include = FALSE}",
  "{r column-axis-data, include = FALSE}",
  "phylo_slope(moisture + canopy | trait",
  "responses to moisture and canopy cover",
  "C3 and C4 species have different average latitude gradients",
  "while the rows remain independent plots"
)
present_forbidden <- forbidden_column_example[
  vapply(forbidden_column_example, grepl, logical(1),
         x = article_text, fixed = TRUE)
]
if (length(present_forbidden) > 0L) {
  stop(
    "The response-column example retains the superseded teaching model: ",
    paste(present_forbidden, collapse = "; ")
  )
}

subtitle_source <- grep(
  '^[[:space:]]*subtitle = "', article_source, value = TRUE
)
subtitle_text <- sub('^[[:space:]]*subtitle = "', "", subtitle_source)
subtitle_text <- sub('",?[[:space:]]*$', "", subtitle_text)
subtitle_width <- vapply(
  strsplit(subtitle_text, "\\n", fixed = TRUE),
  function(x) max(nchar(x, type = "width")),
  integer(1)
)
if (length(subtitle_width) == 0L || any(subtitle_width > 72L)) {
  stop(
    "Article figure subtitles must wrap to at most 72 visible characters per line."
  )
}

## Render and navigation verification for the trait-axis bridge article.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

output_dir <- file.path(tempdir(), "trait-axis-bridge-render")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
render_env <- new.env(parent = globalenv())
rmarkdown::render(article, output_dir = output_dir, quiet = TRUE,
                  envir = render_env)

if (!exists("fit_columns", envir = render_env, inherits = FALSE)) {
  stop("The rendered article did not retain its response-column fit.")
}
fit_columns <- get("fit_columns", envir = render_env, inherits = FALSE)
required_fixed <- c("latitude:pathwayC3", "latitude:pathwayC4")
if (!all(required_fixed %in% fit_columns$X_fix_names)) {
  stop("The rendered fit is missing the two fixed pathway latitude slopes.")
}
if (!isTRUE(fit_columns$use$phylo_column_slope) ||
    !identical(fit_columns$use$phylo_column_slope_source, "phylo") ||
    !identical(fit_columns$use$phylo_dep_slope_cols, "latitude")) {
  stop("The rendered fit is not the expected phylogenetic latitude column-slope model.")
}
if (!setequal(fit_columns$random, c("z_B", "b_phy_aug"))) {
  stop("The rendered fit must contain only the latent-site and phylogenetic-slope random blocks.")
}
z_phy <- drop(fit_columns$tmb_data$Z_phy_aug[, 1L, 1L])
if (!isTRUE(all.equal(z_phy, fit_columns$data$latitude, tolerance = 1e-12))) {
  stop("The phylogenetic slope design must equal latitude and contain no intercept.")
}
slope_extract <- extract_Sigma(fit_columns, level = "column_slope")
if (!identical(slope_extract$predictors, "latitude") ||
    !identical(slope_extract$source$type, "phylo") ||
    !identical(slope_extract$source$grouping, "trait")) {
  stop("The rendered fit's column-slope extractor has incorrect public metadata.")
}
if (!identical(fit_columns$opt$convergence, 0L) ||
    !is.finite(fit_columns$fit_health$max_gradient) ||
    fit_columns$fit_health$max_gradient >= 1e-2) {
  stop("The rendered integrated teaching model did not reach the convergence gate.")
}

config <- readLines("_pkgdown.yml", warn = FALSE)
if (!any(grepl("articles/where-does-the-tree-go", config, fixed = TRUE))) {
  stop("The bridge article is missing from pkgdown navigation.")
}

pkgdown::check_pkgdown()
cat("ARTICLE BUILD PASS\n")
