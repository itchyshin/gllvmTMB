#!/usr/bin/env Rscript
## One fixed-outer-point evaluation, including TMB's inner mode calculation.
## This is a diagnostic, never an optimizer result or convergence waiver.
library(gllvmTMB); library(TMB)
root <- '/private/tmp/gllvm-tree-axis-latent-20260830'
stopifnot(grepl('repaired-library',find.package('gllvmTMB'),fixed=TRUE))
x <- readRDS(file.path(root,'results/fit-M2.rds'))$fit
bad <- readRDS(file.path(root,'results/B2-attempt-1-result.rds'))$result$par
obj <- MakeADFun(x$tmb_data,x$tmb_obj$env$parList(),map=x$tmb_map,
                random=x$random,DLL='gllvmTMB',silent=TRUE)
warnings <- character(); error <- NULL
val <- withCallingHandlers(tryCatch(obj$fn(bad),error=function(e) {
  error <<- conditionMessage(e); NA_real_
}),warning=function(w) {
  warnings <<- c(warnings,conditionMessage(w)); invokeRestart('muffleWarning')
})
out <- list(marginal_nll=val,error=error,warnings=warnings,
  joint_nll=obj$env$f(obj$env$last.par,order=0),
  max_inner_gradient=max(abs(obj$env$f(obj$env$last.par,order=1)[obj$env$random])))
print(out)
jsonlite::write_json(out,file.path(root,'repair-bad-marginal.json'),
                     pretty=TRUE,auto_unbox=TRUE,digits=NA)
FreeADFun(obj)
