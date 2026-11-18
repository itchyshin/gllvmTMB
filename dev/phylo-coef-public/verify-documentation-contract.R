source("dev/phylo-coef-public/helpers.R")
devtools::document(quiet = TRUE)
exports <- readLines("NAMESPACE", warn = FALSE)
for (fn in c("column_coef", "phylo_coef")) {
  assert(any(exports == sprintf("export(%s)", fn)), "missing export for %s", fn)
  assert(file.exists(sprintf("man/%s.Rd", fn)), "missing Rd for %s", fn)
}
text <- read_all(c("R/column-coef-foundation.R", "R/gllvmTMB.R",
                   "R/extract-sigma.R", "NEWS.md", "_pkgdown.yml",
                   "docs/design/01-formula-grammar.md",
                   "man/column_coef.Rd", "man/phylo_coef.Rd",
                   "man/extract_Sigma.Rd", "man/gllvmTMB.Rd"))
for (needle in c("column_coef", "phylo_coef", "column_coef\"", "Gaussian",
                 "public Gaussian point models", "engine-fenced")) {
  assert(grepl(needle, text, fixed = TRUE), "documentation token absent: %s", needle)
}
for (path in c("R/column-coef-foundation.R", "man/phylo_coef.Rd", "NEWS.md",
               "vignettes/articles/where-does-the-tree-go.Rmd",
               "vignettes/articles/api-keyword-grid.Rmd")) {
  assert(grepl("K + 1e-8 I", read_all(path), fixed = TRUE),
         "dense-VCV endpoint seam absent from %s", path)
}
cat("public coefficient documentation verified\n")
