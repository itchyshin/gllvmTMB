roots <- c("README.md", "NEWS.md", "ROADMAP.md", "_pkgdown.yml")
files <- roots[file.exists(roots)]
vignettes <- if (dir.exists("vignettes")) list.files("vignettes", recursive = TRUE, full.names = TRUE,
                                                       pattern = "[.](Rmd|qmd|Rnw|R)$", ignore.case = TRUE) else character()
files <- c(files, vignettes)
text <- paste(unlist(lapply(files, function(path) readLines(path, warn = FALSE, encoding = "UTF-8")), use.names = FALSE), collapse = "\n")
if (grepl("iJSDM.*response-information|response-information.*recovery", text, ignore.case = TRUE)) stop("public response-information claim found", call. = FALSE)
cat("response information wording verification passed\n")
