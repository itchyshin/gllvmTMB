lib <- normalizePath("dev/covariance-teaching/library", mustWork = FALSE)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
cat("Setup library:", lib, "\n")
devtools::document(quiet = TRUE)
status <- system2(file.path(R.home("bin"), "R"),
                  c("CMD", "INSTALL", "--preclean", "--no-multiarch",
                    paste0("--library=", shQuote(lib)), "."))
stopifnot(status == 0L)
pkgdown::check_pkgdown()
cat("SETUP_DOCUMENT_PKGDOWN_VERIFIED\n")
