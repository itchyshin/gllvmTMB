source("dev/phylo-coef-public/helpers.R")
devtools::load_all(quiet = TRUE)
pkgdown::build_article("articles/where-does-the-tree-go", lazy = FALSE,
                       new_process = FALSE, quiet = TRUE)
pkgdown::build_article("articles/api-keyword-grid", lazy = FALSE,
                       new_process = FALSE, quiet = TRUE)
paths <- file.path("pkgdown-site", "articles",
                   c("where-does-the-tree-go.html", "api-keyword-grid.html"))
assert(all(file.exists(paths)), "built coefficient article is missing")
where_source <- read_all("vignettes/articles/where-does-the-tree-go.Rmd")
grid_source <- read_all("vignettes/articles/api-keyword-grid.Rmd")
where_html <- read_all(paths[[1L]])
grid_html <- read_all(paths[[2L]])
html <- paste(where_html, grid_html, sep = "\n")
for (needle in c("column_coef", "phylo_coef", "estimated rho",
                 "traits(", "outside the 5 × 3 grid")) {
  assert(grepl(needle, html, fixed = TRUE), "built article token absent: %s", needle)
}
assert(!grepl("There is no <code>column_coef", html, fixed = TRUE),
       "stale no-column_coef wording remains in built HTML")
for (needle in c("K_tree <- vcv.phylo", "rho_truth <- 0.60",
                 "A_rho <- rho_truth * K_tree",
                 "t(chol(A_rho))", "K + 1e-8 I")) {
  assert(grepl(needle, where_source, fixed = TRUE),
         "where-does-the-tree-go source contract absent: %s", needle)
}
assert(!grepl("A_rho <- rho_truth * A +", where_source, fixed = TRUE),
       "article falsely builds the coefficient DGP from conditioned A")
assert(grepl("K + 1e-8 I", grid_source, fixed = TRUE),
       "grid article omits the dense-VCV endpoint seam")
assert(grepl("simulation planted", where_html, fixed = TRUE),
       "built article omits the planted-rho explanation")
cat("coefficient articles verified\n")
