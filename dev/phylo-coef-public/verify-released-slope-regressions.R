source("dev/phylo-coef-public/helpers.R")
run_tests("(fixed-column-slope-family|phylo-column-slope-indep|phylo-slope-rhs-routing|ordinary-column-slope-phylo-coexistence|spatial-column-slope)")
lines <- unlist(lapply(c("R/brms-sugar.R", "R/animal-keyword.R", "NEWS.md"),
                       readLines, warn = FALSE), use.names = FALSE)
assert(!any(grepl(
  "deprecat.*(slope|phylo_slope|animal_slope|kernel_slope|spatial_slope)",
  lines, ignore.case = TRUE
)), "released slope helper deprecation wording found")
cat("released slope regressions verified\n")
