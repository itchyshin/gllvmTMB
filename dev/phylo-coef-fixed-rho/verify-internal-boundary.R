devtools::load_all(quiet = TRUE)

read_flat <- function(path) {
  if (!file.exists(path)) return("")
  paste(readLines(path, warn = FALSE), collapse = " ")
}

namespace <- read_flat("NAMESPACE")
pkgdown <- read_flat("_pkgdown.yml")
news <- read_flat("NEWS.md")
readme <- read_flat("README.md")
article <- read_flat("vignettes/articles/where-does-the-tree-go.Rmd")
rd_files <- list.files("man", pattern = "[.]Rd$", full.names = TRUE)
rd <- paste(vapply(rd_files, read_flat, character(1L)), collapse = "\n")

stopifnot(
  !grepl("export[(]phylo_coef[)]", namespace, fixed = FALSE),
  !grepl("alias[{]phylo_coef[}]", rd, fixed = FALSE),
  !grepl("phylo_coef", pkgdown, fixed = TRUE),
  !grepl("phylo_coef", news, fixed = TRUE),
  !grepl("phylo_coef", readme, fixed = TRUE),
  grepl("There is no `column_coef()`", article, fixed = TRUE)
)

## Historical Design 55/56 deprecation proposals remain superseded; the
## warning-free slope family is not deprecated or changed by this slice.
d55 <- read_flat("docs/design/55-structural-slope-grammar.md")
d56 <- read_flat("docs/design/56-augmented-lhs-engine-stage3.md")
stopifnot(
  grepl("supersedes this document's", d55, fixed = TRUE),
  grepl("The helpers remain public", d55, fixed = TRUE),
  grepl("supersedes the helper migration and", d56, fixed = TRUE),
  grepl("does not replace the public response-column slope helper family", d56,
        fixed = TRUE)
)

cat("PHYLO_COEF_INTERNAL_BOUNDARY_OK\n")
