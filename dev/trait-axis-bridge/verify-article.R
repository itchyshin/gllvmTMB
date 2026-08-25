## Render and navigation verification for the trait-axis bridge article.

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

article <- "vignettes/articles/where-does-the-tree-go.Rmd"
output_dir <- file.path(tempdir(), "trait-axis-bridge-render")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
rmarkdown::render(article, output_dir = output_dir, quiet = TRUE,
                  envir = new.env(parent = globalenv()))

config <- readLines("_pkgdown.yml", warn = FALSE)
if (!any(grepl("articles/where-does-the-tree-go", config, fixed = TRUE))) {
  stop("The bridge article is missing from pkgdown navigation.")
}

pkgdown::check_pkgdown()
cat("ARTICLE BUILD PASS\n")
