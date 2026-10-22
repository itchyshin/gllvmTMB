#!/usr/bin/env Rscript
## Presentation-only rebuild after the primary render; reuse its fitted objects.
## Refuse every optimizer call. Public article source keeps runnable fit chunks.
library(gllvmTMB)
run_id <- commandArgs(trailingOnly=TRUE)
stopifnot(length(run_id)==1L,grepl("^[1-9][0-9]*$",run_id))
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88"
source_path <- file.path(root,"primary-render-1/receipt.rds")
r <- readRDS(source_path)
fit_morphology <- r$fits$morphology
fit_columns <- r$fits$iid
fit_phylo_coef <- r$fits$phylo
knitr::opts_hooks$set(eval=function(options) {
  if(options$label %in% c("morphology-long","community-long")) options$eval <- FALSE
  options
})
trace(".gllvmTMB_run_nlminb",where=asNamespace("gllvmTMB"),print=FALSE,
  tracer=quote(stop("No optimizer permitted in presentation-only rebuild")))
pkgdown::build_article("articles/where-does-the-tree-go",lazy=FALSE,new_process=FALSE,quiet=FALSE)
untrace(".gllvmTMB_run_nlminb",where=asNamespace("gllvmTMB"))
receipt <- list(outer_optimizer_calls=0L,
  fitted_objects_sha256=digest::digest(file=source_path,algo="sha256"),
  article_sha256=digest::digest(file="vignettes/articles/where-does-the-tree-go.Rmd",algo="sha256"),
  html_sha256=digest::digest(file="pkgdown-site/articles/where-does-the-tree-go.html",algo="sha256"))
path <- file.path(root,paste0("presentation-render-",run_id,".rds"))
stopifnot(!file.exists(path));saveRDS(receipt,path)
cat("TREE_AXIS_PRESENTATION_RENDER_PASS_NO_OUTER_OPTIMIZER\n")
