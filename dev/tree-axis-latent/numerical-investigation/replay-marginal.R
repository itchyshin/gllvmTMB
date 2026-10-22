#!/usr/bin/env Rscript
## Fixed-outer-parameter objective evaluations only; no outer optimization.
library(gllvmTMB);library(TMB)
x<-readRDS('/private/tmp/gllvm-tree-axis-latent-20260830/results/fit-M2.rds')$fit
bad<-readRDS('/private/tmp/gllvm-tree-axis-latent-20260830/results/B2-attempt-1-result.rds')$result$par
out<-list()
for(id in c('retained','BFGS')) {
  cat('START_POINT',id,'\n')
  pars<-x$tmb_obj$env$parList()
  obj<-TMB::MakeADFun(data=x$tmb_data,parameters=pars,map=x$tmb_map,
                      random=x$random,DLL='gllvmTMB',silent=TRUE)
  outer<-if(id=='retained')x$opt$par else bad
  warnings<-character()
  val<-withCallingHandlers(tryCatch(obj$fn(outer),error=function(e)NA_real_),warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  joint<-obj$env$f(obj$env$last.par,order=0)
  inner_gradient<-obj$env$f(obj$env$last.par,order=1)[obj$env$random]
  out[[id]]<-list(marginal_nll=val,joint_nll=joint,max_inner_gradient=max(abs(inner_gradient)),
                  max_random=max(abs(obj$env$last.par[obj$env$random])),warnings=warnings)
  print(out[[id]])
  saveRDS(list(summary=out[[id]],full_par=obj$env$last.par,outer=outer),paste0('/private/tmp/gllvm-tree-axis-latent-20260830/replay-',id,'.rds'))
  TMB::FreeADFun(obj)
}
jsonlite::write_json(out,'/private/tmp/gllvm-tree-axis-latent-20260830/replay-marginal.json',pretty=TRUE,auto_unbox=TRUE,digits=NA)
cat('MARGINAL_REPLAY_COMPLETE_NO_OUTER_OPTIMIZATION\n')
