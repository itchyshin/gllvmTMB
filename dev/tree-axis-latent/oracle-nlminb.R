#!/usr/bin/env Rscript
## Exactly ONE approved private diagnostic optimization. Not an article fit.
## Hash-bound existing algebra; no package source, model, map or control change.
library(gllvmTMB)
source('dev/tree-axis-latent/fixture.R')
root<-'/private/tmp/gllvm-tree-axis-latent-20260830/repaired-nlminb-7c88'
provenance<-jsonlite::read_json(file.path(root,'provenance.json'),simplifyVector=TRUE)
stopifnot(identical(normalizePath(find.package('gllvmTMB')),provenance$library),
 identical(digest::digest(file=file.path(provenance$library,'libs/gllvmTMB.so'),algo='sha256'),provenance$dll_sha256),
 identical(unname(tools::md5sum('dev/tree-axis-latent/fixture.R')),provenance$fixture_md5))
for(path in names(provenance$source_sha256))stopifnot(identical(
 digest::digest(file=path,algo='sha256'),provenance$source_sha256[[path]]))
endpoint<-readRDS(file.path(root,'endpoint-score.rds'))
algebra_path<-'dev/tree-axis-latent/endpoint-score.R'
stopifnot(identical(digest::digest(file=algebra_path,algo='sha256'),endpoint$script_sha256))
## Evaluate only the already reviewed fixture/matrix setup and pure functions.
## Never source the whole endpoint script: it would repeat completed diagnostics.
lines<-readLines(algebra_path)
first<-which(lines=="f<-make_tree_axis_fixture('target')$community")
last<-grep('^out<-list\\(provenance=',lines)
stopifnot(length(first)==1L,length(last)==1L,last>first)
eval(parse(text=lines[first:(last-1L)]),envir=environment())
r<-readRDS(file.path(root,'fit-N2.rds'))
stopifnot(identical(unname(tools::md5sum(file.path(root,'fit-N2.rds'))),
 endpoint$endpoints[['N2-start1']]$receipt_md5),identical(r$R,R.version.string))
start<-r$optimizer_calls[[1L]]$start
stopifnot(identical(start,readRDS(file.path(root,'N2-attempt-1-start.rds'))),
 identical(start,readRDS('/private/tmp/gllvm-tree-axis-latent-20260830/results/fit-M2.rds')$optimizer_calls[[1L]]$start),
 identical(as.numeric(t(Y)),as.numeric(r$fit$tmb_data$y)),
 identical(colnames(Xfixed),names(coef(r$fit))),isTRUE(r$gaussian$all_na),isTRUE(r$gaussian$fixed_value_ok))
## No random seed is changed after the unchanged frozen fixture construction.
eps<-r$gaussian$fixed_value
check<-independent(r$optimizer_calls[[1L]]$result$par,eps,FALSE)
stopifnot(abs(check$value-endpoint$endpoints[['N2-start1']]$nll)<1e-10,
 max(abs(check$gradient-endpoint$endpoints[['N2-start1']]$gradient))<1e-10)
cache_par<-NULL;cache_result<-NULL;trace_index<-0L
outdir<-file.path(root,'oracle-N2-start1');trace_dir<-file.path(outdir,'trace')
eval_traced<-function(par,kind) {
 trace_index<<-trace_index+1L
 entry<-list(index=trace_index,kind=kind,par=par,entered=Sys.time())
 path<-file.path(trace_dir,sprintf('%05d.rds',trace_index))
 saveRDS(entry,path,compress=FALSE)
 warnings<-character();error<-NULL
 cached<-identical(par,cache_par)
 value<-tryCatch(withCallingHandlers({
   if(cached)cache_result else independent(par,eps,FALSE)
 },warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),
 error=function(e){error<<-conditionMessage(e);NULL})
 entry$warnings<-warnings;entry$error<-error;entry$cache_hit<-cached
 entry$finished<-Sys.time()
 if(!is.null(value)) {
   cache_par<<-par;cache_result<<-value
   entry$value<-value$value;entry$gradient<-value$gradient
 }
 saveRDS(entry,path,compress=FALSE)
 if(!is.null(error))stop(error)
 if(kind=='objective')value$value else value$gradient
}
obj<-list(fn=function(par)eval_traced(par,'objective'),gr=function(par)eval_traced(par,'gradient'))
args<-getFromNamespace('.gllvmTMB_nlminb_call_args','gllvmTMB')(
 par_init=start,obj=obj,opt_args=list(),iter_cap=NULL)
stopifnot(identical(args$start,start),identical(args$control,list(eval.max=2000,iter.max=1500)),
 identical(names(args),c('start','objective','gradient','control')))
## N2 was run with empty optArgs and no iter_cap: no bounds/scale were supplied.
## stats::nlminb defaults remain lower=-Inf, upper=Inf, scale=1, all tolerances default.
if(!dir.create(outdir,showWarnings=FALSE))stop('This single oracle attempt is already admitted')
dir.create(trace_dir)
metadata<-list(approval='Approve one exact-Gaussian oracle nlminb diagnostic from the frozen IID start, with unchanged controls and a 60-second cap. Raise the ceiling to 23 without borrowing wide slots. No production changes or gate waiver.',
 id='oracle-N2-start1',start=start,control=args$control,
 implicit_defaults=list(lower=-Inf,upper=Inf,scale=1),parameter_map=r$fit$tmb_map,
 gaussian=r$gaussian,provenance=provenance,algebra_sha256=endpoint$script_sha256,
 runner_sha256=digest::digest(file='dev/tree-axis-latent/oracle-nlminb.R',algo='sha256'),
 source_sha=system2('git',c('rev-parse','HEAD'),stdout=TRUE),
 original_receipt_md5=unname(tools::md5sum(file.path(root,'fit-N2.rds'))),
 cumulative_before=20L,ceiling=23L,cap_seconds=60L,attempts=1L)
saveRDS(metadata,file.path(outdir,'admission.rds'))
message('ORACLE_OPTIMIZER_ATTEMPT_ENTER id=oracle-N2-start1 cumulative=21 ceiling=23')
started<-Sys.time();fit_error<-NULL;warnings<-character()
opt<-tryCatch(withCallingHandlers(do.call(stats::nlminb,args),
 warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),
 error=function(e){fit_error<<-conditionMessage(e);NULL})
receipt<-list(metadata=metadata,optimizer=opt,error=fit_error,warnings=warnings,
 elapsed_seconds=as.numeric(difftime(Sys.time(),started,units='secs')),trace_entries=trace_index,
 package_gate_waived=FALSE,article_acceptance=FALSE)
## Save the optimizer return before any comparison that might fail.
saveRDS(receipt,file.path(outdir,'optimizer-return.rds'))
if(!is.null(opt)) {
 final<-independent(opt$par,eps,FALSE)
 compare<-lapply(seq_len(3L),function(i){
   old<-independent(r$optimizer_calls[[i]]$result$par,eps,FALSE)
   rel<-function(a,b)sqrt(sum((a-b)^2))/max(sqrt(sum(b^2)),1e-8)
   list(start=i,nll_difference=final$value-old$value,
     unit_total_relative_norm=rel(final$unit,old$unit),coefficient_sigma_relative_norm=rel(final$Sigma,old$Sigma),
     fixed_mean_relative_norm=rel(opt$par[names(opt$par)=='b_fix'],r$optimizer_calls[[i]]$result$par[names(opt$par)=='b_fix']))
 })
 receipt$final<-list(nll=final$value,max_gradient=max(abs(final$gradient)),
   gradient=final$gradient,unit=final$unit,coefficient_sigma=final$Sigma)
 receipt$versus_package<-compare
}
saveRDS(receipt,file.path(outdir,'receipt.rds'))
print(receipt[c('optimizer','error','warnings','elapsed_seconds','trace_entries','versus_package')])
if(!is.null(fit_error))quit(status=1L)
message('ORACLE_OPTIMIZER_ATTEMPT_RETURN code=',opt$convergence,' nll=',opt$objective)
cat('ONE_ORACLE_DIAGNOSTIC_RECORDED_NO_PACKAGE_GATE_WAIVER\n')
