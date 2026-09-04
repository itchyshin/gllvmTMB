args <- commandArgs(trailingOnly = TRUE)
lib_path <- path.expand(args[[1]])
dir.create(lib_path, recursive = TRUE, showWarnings = FALSE)
Sys.setenv(OPENBLAS_NUM_THREADS = "1", MAKEFLAGS = "-j4")
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes", lib = lib_path, repos = "https://cloud.r-project.org")
}
remotes::install_local(".", lib = lib_path, upgrade = "never", quiet = TRUE,
                       dependencies = FALSE, build_vignettes = FALSE)
.libPaths(c(lib_path, .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
if (!"extract_latent_scores" %in% ls(getNamespace("gllvmTMB"), all = TRUE)) {
  stop("extract_latent_scores missing after install")
}
cat("install OK\n")
