#!/usr/bin/env Rscript
## The one approved primary article render: three first-start fits, not a
## replacement standalone validation block. Wide calls remain displayed only.
library(gllvmTMB)
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/coefficient-standardization-7c88"
ledger <- readRDS(file.path(root,"validation-Q2-Q3-QW2-QW3.rds"))
stopifnot(isTRUE(ledger$pass))
# Morphology is unchanged; its current-source continuity is required separately.
continuity <- readRDS(file.path(root,"prefit-gate.rds"))
stopifnot(isTRUE(continuity$pass))
manifest <- jsonlite::read_json(file.path(root,"provenance.json"),simplifyVector=TRUE)
expected <- c(list.files("R",pattern="[.]R$",full.names=TRUE),"src/gllvmTMB.cpp",
  "inst/include/gllvmTMB/detail/column_prior.hpp","NAMESPACE","DESCRIPTION")
stopifnot(setequal(names(manifest$source_sha256),expected),
  identical(normalizePath(find.package("gllvmTMB")),manifest$library),
  identical(digest::digest(file=file.path(manifest$library,"libs/gllvmTMB.so"),algo="sha256"),manifest$dll_sha256))
for(p in expected) stopifnot(identical(digest::digest(file=p,algo="sha256"),manifest$source_sha256[[p]]))
.article_dir <- file.path(root,"primary-render-1")
stopifnot(dir.create(.article_dir,showWarnings=FALSE))
.article_ids <- c("G1","Q2","Q3")
.article_entries <- 0L
trace(".gllvmTMB_run_nlminb",where=asNamespace("gllvmTMB"),print=FALSE,
  tracer=quote({
    .GlobalEnv$.article_entries <- .GlobalEnv$.article_entries+1L
    stopifnot(.GlobalEnv$.article_entries<=3L)
    .article_id <- .GlobalEnv$.article_ids[[.GlobalEnv$.article_entries]]
    .article_reference_root <- if (.article_id == "G1")
      "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88" else .GlobalEnv$root
    .article_reference <- readRDS(file.path(.article_reference_root,paste0("fit-",.article_id,".rds")))
    stopifnot(identical(args$start,.article_reference$optimizer_calls[[1]]$start))
    saveRDS(list(id=.article_id,start=args$start,entered=Sys.time()),
      file.path(.GlobalEnv$.article_dir,paste0(.article_id,"-start.rds")))
    message("PRIMARY_RENDER_ATTEMPT_ENTER ",.article_id)
  }),
  exit=quote({
    .article_result <- returnValue()
    saveRDS(.article_result,file.path(.GlobalEnv$.article_dir,paste0(.article_id,"-result.rds")))
    stopifnot(identical(as.integer(.article_result$convergence),0L),
      is.finite(.article_result$objective),max(abs(args$gradient(.article_result$par)))<1e-2)
    message("PRIMARY_RENDER_ATTEMPT_EXIT ",.article_id)
  }))
pkgdown::check_pkgdown()
pkgdown::build_article("articles/where-does-the-tree-go",lazy=FALSE,new_process=FALSE,quiet=FALSE)
untrace(".gllvmTMB_run_nlminb",where=asNamespace("gllvmTMB"))
stopifnot(.article_entries==3L)
saveRDS(list(fits=list(morphology=fit_morphology,iid=fit_columns,phylo=fit_phylo_coef),
  standalone_count=41L,primary_render_entries=.article_entries,
  article_sha256=digest::digest(file="vignettes/articles/where-does-the-tree-go.Rmd",algo="sha256")),
  file.path(.article_dir,"receipt.rds"))
cat("TREE_AXIS_PRIMARY_ARTICLE_RENDER_PASS\n")
