#!/usr/bin/env Rscript
## Twelve predeclared fixed outer parameter points; NO outer optimizer.
## Compare fresh tape state to the unmodified default reused inner-start policy.
oracle_path<-'dev/tree-axis-latent/oracle-nlminb.R'
oracle_receipt<-readRDS('/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88/oracle-N2-start1/receipt.rds')
stopifnot(identical(digest::digest(file=oracle_path,algo='sha256'),oracle_receipt$metadata$runner_sha256))
lines<-readLines(oracle_path);end<-grep('^cache_par<-',lines)
stopifnot(length(end)==1L)
## This reviewed prefix validates all source/receipt hashes and loads only the
## pure Gaussian algebra. It ends before tracing, admission or nlminb code.
eval(parse(text=lines[seq_len(end-1L)]),envir=environment())
base<-r$optimizer_calls[[1L]]$result$par
base_oracle<-independent(base,eps,FALSE)
direction<-base_oracle$gradient/sqrt(sum(base_oracle$gradient^2))
initial_params<-r$fit$tmb_obj$env$parList()
plan<-data.frame(id=seq_len(12L),state=rep(c('fresh','reused'),each=6L),
 step=c(0,0,1e-4,-1e-4,1e-6,-1e-6,0,1e-4,-1e-4,1e-6,-1e-6,0))
outdir<-file.path(root,'repeatability-N2-start1')
if(!dir.create(outdir,showWarnings=FALSE))stop('Refusing to repeat the admitted twelve-point diagnostic')
metadata<-list(plan=plan,base=base,direction=direction,initial_params=initial_params,
 initial_params_sha256=digest::digest(initial_params,algo='sha256'),
 initial_state_description='Identical retained N2 fit parList for every fresh tape and initial reused tape; not zero random effects',
 source_provenance=provenance,runner_sha256=digest::digest(file='dev/tree-axis-latent/repeatability.R',algo='sha256'),
 outer_optimizer_calls=0L,point_limit=12L,process_cap_seconds=60L,cumulative_attempts=21L,ceiling=23L,
 inner_control=r$fit$tmb_obj$env$inner.control,inner_method=r$fit$tmb_obj$env$inner.method,
 random_start=r$fit$tmb_obj$env$random.start)
saveRDS(metadata,file.path(outdir,'admission.rds'))
make_obj<-function(){
 obj<-TMB::MakeADFun(r$fit$tmb_data,initial_params,map=r$fit$tmb_map,random=r$fit$random,DLL='gllvmTMB',silent=TRUE)
 stopifnot(identical(obj$env$inner.control,metadata$inner_control),
   identical(obj$env$inner.method,metadata$inner_method),identical(obj$env$random.start,metadata$random_start))
 obj
}
state_snapshot<-function(obj)list(last_par_sha256=digest::digest(obj$env$last.par,algo='sha256'),
 best_par_sha256=digest::digest(obj$env$last.par.best,algo='sha256'),value_best=obj$env$value.best)
inner_snapshot<-function(obj){
 par<-obj$env$last.par
 joint<-obj$env$f(par,order=0)
 inner_score<-obj$env$f(par,order=1)[obj$env$random]
 list(joint=joint,full_mode=par,inner_gradient=inner_score,
   max_inner_gradient=max(abs(inner_score)),
   random_parameters=length(obj$env$random),mode_sha256=digest::digest(par,algo='sha256'))
}
reused<-NULL;results<-list()
for(i in seq_len(nrow(plan))) {
 if(plan$state[i]=='fresh')obj<-make_obj() else {
   if(is.null(reused))reused<-make_obj()
   obj<-reused
 }
 par<-base+plan$step[i]*direction
 result<-list(id=i,state=plan$state[i],step=plan$step[i],par=par,before=state_snapshot(obj),entered=Sys.time())
 path<-file.path(outdir,sprintf('point-%02d.rds',i));saveRDS(result,path)
 warnings<-character();error<-NULL
 computed<-tryCatch(withCallingHandlers({
   value<-obj$fn(par);after_value<-state_snapshot(obj);inner_value<-inner_snapshot(obj)
   gradient<-as.numeric(obj$gr(par));after_gradient<-state_snapshot(obj);inner_gradient<-inner_snapshot(obj)
   exact<-independent(par,eps,FALSE)
   list(value=value,gradient=gradient,oracle_value=exact$value,oracle_gradient=exact$gradient,
     value_difference=value-exact$value,gradient_difference=gradient-exact$gradient,
     after_value=after_value,after_gradient=after_gradient,inner_after_value=inner_value,
     inner_after_gradient=inner_gradient,
     half_logdet=as.numeric(value-inner_value$joint+inner_value$random_parameters*log(2*pi)/2))
 },warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),
 error=function(e){error<<-conditionMessage(e);NULL})
 result$computed<-computed;result$warnings<-warnings;result$error<-error;result$finished<-Sys.time()
 saveRDS(result,path);results[[as.character(i)]]<-result
 message('FIXED_POINT_RETURN id=',i,' state=',plan$state[i],' step=',plan$step[i],
   ' value_error=',computed$value_difference,' max_score_error=',max(abs(computed$gradient_difference)))
 if(plan$state[i]=='fresh')TMB::FreeADFun(obj)
 if(!is.null(error))stop('Fixed-point diagnostic failed: ',error)
}
TMB::FreeADFun(reused)
stopifnot(length(results)==12L)
saveRDS(list(metadata=metadata,results=results),file.path(outdir,'receipt.rds'))
cat('TWELVE_FIXED_POINT_DIAGNOSTIC_RECORDED_NO_OUTER_OPTIMIZATION\n')
