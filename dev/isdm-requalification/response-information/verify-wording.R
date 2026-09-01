paths <- c("README.md", "NEWS.md", "ROADMAP.md", "_pkgdown.yml", "vignettes")
files <- unlist(lapply(paths[file.exists(paths)], function(path) {
  if (dir.exists(path)) list.files(path, recursive = TRUE, full.names = TRUE) else path
}), use.names = FALSE)
files <- files[file.info(files)$isdir %in% FALSE]
text <- paste(unlist(lapply(files, function(path) readLines(path, warn = FALSE)), use.names = FALSE), collapse = "\n")
if (grepl("iJSDM.*response-information|response-information.*recovery", text, ignore.case = TRUE)) stop("public response-information claim found", call. = FALSE)
cat("response information wording verification passed\n")
