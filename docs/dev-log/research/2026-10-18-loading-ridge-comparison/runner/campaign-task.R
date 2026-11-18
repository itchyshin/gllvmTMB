#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
stopifnot(length(args)==2L)
root <- normalizePath(args[1],mustWork=TRUE); chunk <- normalizePath(args[2],mustWork=TRUE)
.libPaths(unique(c(file.path(root,'library'),strsplit(Sys.getenv('R_LIBS_USER'),.Platform$path.sep,fixed=TRUE)[[1]],path.expand('~/R/lib'),.libPaths())))
suppressPackageStartupMessages(library(gllvmTMB))
source(file.path(root,'runner','generate.R'))
m <- full_manifest(); tasks <- scan(chunk,what=integer(),quiet=TRUE)
stopifnot(length(tasks)>0L,!anyDuplicated(tasks),all(tasks %in% m$task))
worker <- tools::file_path_sans_ext(basename(chunk))
dir.create(file.path(root,'progress'),recursive=TRUE,showWarnings=FALSE)
heartbeat <- function(task,tau,phase) {
  line <- data.frame(utc=format(Sys.time(),tz='UTC',usetz=TRUE),epoch=as.numeric(Sys.time()),pid=Sys.getpid(),task=task,tau=tau,phase=phase)
  write.table(line,file.path(root,'progress',paste0(worker,'.csv')),sep=',',row.names=FALSE,col.names=!file.exists(file.path(root,'progress',paste0(worker,'.csv'))),append=file.exists(file.path(root,'progress',paste0(worker,'.csv'))),quote=TRUE)
  saveRDS(line,file.path(root,'progress',paste0(worker,'-latest.rds')))
}
num1 <- function(x) if(length(x)==1L) as.numeric(x) else NA_real_
save_summary <- function(r,fx,out,label) {
  finite_matrix <- function(s) is.matrix(s) && identical(dim(s),c(6L,6L)) && all(is.finite(s))
  row <- data.frame(task=r$task$task,rep=r$task$rep,family=r$task$family,n=r$task$n,strength=r$task$strength,tau=label,fit_error=if(is.null(r$errors$fit)) '' else r$errors$fit,errors=paste(names(r$errors),collapse=';'),convergence=num1(r$convergence),pdHess=if(length(r$pdHess)) r$pdHess else NA,fit_elapsed=r$fit_elapsed,total_elapsed=r$total_elapsed,intervals_available=if(is.null(r$effects)) 0L else sum(r$effects$available),max_trait_loading_sd_ratio=NA_real_,loading_frobenius_ratio=NA_real_,typical_trait_shared_sd_ratio=NA_real_,typical_trait_total_sd_ratio=NA_real_,prediction_mean_RMSE=NA_real_,curvature_matches=NA,stringsAsFactors=FALSE)
  for(p in c('shared','unique','total')) {
    S <- r$Sigma[[p]]$Sigma
    row[[paste0('Sigma_',p,'_relative_F')]] <- if(finite_matrix(S)) norm(S-fx$truth[[p]],'F')/norm(fx$truth[[p]],'F') else NA_real_
    row[[paste0('Sigma_',p,'_diag_RMSE')]] <- if(finite_matrix(S)) sqrt(mean((diag(S)-diag(fx$truth[[p]]))^2)) else NA_real_
    row[[paste0('Sigma_',p,'_offdiag_RMSE')]] <- if(finite_matrix(S)) sqrt(mean((S-fx$truth[[p]])[upper.tri(S)]^2)) else NA_real_
  }
  S <- r$Sigma$shared$Sigma
  if(finite_matrix(S)) row$max_trait_loading_sd_ratio <- sqrt(max(diag(S)))/max(sqrt(rowSums(fx$truth$Lambda^2)))
  if(finite_matrix(S)) {row$loading_frobenius_ratio <- sqrt(sum(diag(S)))/norm(fx$truth$Lambda,'F');row$typical_trait_shared_sd_ratio <- median(sqrt(diag(S))/sqrt(rowSums(fx$truth$Lambda^2)))}
  S <- r$Sigma$total$Sigma
  if(finite_matrix(S)) row$typical_trait_total_sd_ratio <- median(sqrt(diag(S))/sqrt(diag(fx$truth$total)))
  pred <- r$prediction
  if(is.data.frame(pred) && 'est' %in% names(pred)) pred <- pred$est
  if(!identical(r$model_rows$row_id,fx$data$row_id)) pred <- NULL
  if(is.numeric(pred) && length(pred)==nrow(fx$data) && all(is.finite(pred))) row$prediction_mean_RMSE <- sqrt(mean((as.numeric(pred)-fx$data$true_mean)^2))
  if(is.finite(r$tau)) {
    c <- r$curvature
    row$curvature_matches <- is.list(c) && identical(c$objective,'likelihood_plus_gaussian_loading_prior') && identical(c$interpretation,'local_approximate_posterior_curvature_at_map') && identical(c$ridge_tau,r$aghq$ridge_tau) && identical(c$parameter_names,r$parameter_names) && identical(c$parameter_vector,r$opt_par)
  }
  write.csv(row,file.path(out,paste0('arm-',label,'.csv')),row.names=FALSE)
  e <- r$effects
  if(is.null(e)) e <- data.frame(trait=names(fx$truth$B),predictor='x',estimate=NA_real_,std.error=NA_real_,lower=NA_real_,upper=NA_real_,uncertainty_status=if(is.null(r$errors$fit)) 'extractor_error' else 'fit_error',truth=as.numeric(fx$truth$B),available=FALSE,covered=NA)
  e$task <- r$task$task;e$rep <- r$task$rep;e$family <- r$task$family;e$n <- r$task$n;e$strength <- r$task$strength;e$tau <- label
  write.csv(e,file.path(out,paste0('effects-',label,'.csv')),row.names=FALSE)
}
run_task <- function(task_id) {
cell <- m[m$task==task_id,,drop=FALSE]; fx <- pilot_fixture(cell)
out <- file.path(root,'results',sprintf('task-%04d',cell$task)); dir.create(out,recursive=TRUE,showWarnings=FALSE)
immutable <- function(object,path) { if(file.exists(path)) stop('Refusing overwrite: ',path); saveRDS(object,path) }
fixture_path <- file.path(out,'fixture.rds')
if(file.exists(fixture_path)) { old <- readRDS(fixture_path);stopifnot(identical(old$cell,fx$cell),identical(old$data,fx$data),identical(old$truth,fx$truth)) } else immutable(fx,fixture_path)

checks <- pilot_alignment(fx); badrows <- fx$data[nrow(fx$data):1,,drop=FALSE]; badtruth <- fx$truth; badtruth$B[1] <- badtruth$B[1]+1
negative <- c(row_order_detected=!pilot_alignment(fx,data=badrows)['row_map'],wrong_truth_detected=!pilot_alignment(fx,truth=badtruth)['truth'])
stopifnot(all(checks),all(negative))
for(tau in c(Inf,1,2,4)) {
  label <- if(is.infinite(tau)) 'Inf' else as.character(tau)
  result_path <- file.path(out,paste0('result-',label,'.rds'))
  if(file.exists(result_path)) { previous <- readRDS(result_path);stopifnot(identical(previous$task,cell),identical(previous$tau,tau));save_summary(previous,fx,out,label);heartbeat(cell$task,label,'retained_arm');next }
  result <- list(task=cell,tau=tau,data_seed=cell$data_seed,init_seed=cell$init_seed,alignment=checks,negative_controls=negative,errors=list(),warnings=character(),session=utils::sessionInfo())
  capture <- function(name,expr) tryCatch(withCallingHandlers(expr,warning=function(w){result$warnings <<- c(result$warnings,paste(name,conditionMessage(w)));invokeRestart('muffleWarning')}),error=function(e){result$errors[[name]] <<- conditionMessage(e);NULL})
  heartbeat(cell$task,label,'fit_start')
  set.seed(cell$init_seed)
  form <- if(cell$family=='binomial') cbind(successes,failures) ~ 0+trait+latent(0+trait|unit,d=2,lv=~x) else y ~ 0+trait+latent(0+trait|unit,d=2,lv=~x)
  fam <- switch(cell$family,binomial=binomial(link='probit'),gaussian=gaussian(),poisson=poisson())
  start <- proc.time()[['elapsed']]
  fit <- capture('fit',gllvmTMB(form,data=fx$data,unit='unit',trait='trait',family=fam,control=gllvmTMBcontrol(loading_ridge=tau)))
  result$fit_elapsed <- proc.time()[['elapsed']]-start
  if(!is.null(fit)) {
    fit_path <- file.path(out,paste0('fit-',label,'.rds'))
    if(file.exists(fit_path)) stop('Raw fit exists without result; archive interrupted attempt before resuming: ',fit_path)
    immutable(fit,fit_path)
    result$convergence <- fit$opt$convergence; result$opt_message <- fit$opt$message
    result$pdHess <- if(is.null(fit$sd_report)) NA else isTRUE(fit$sd_report$pdHess); result$sdreport_error <- fit$sdreport_error
    result$curvature <- attr(fit$sd_report,'loading_ridge_curvature'); result$aghq <- fit$aghq
    result$parameter_names <- names(fit$opt$par);result$opt_par <- fit$opt$par
    result$psi <- list(use=fit$use,tmb_map=fit$tmb_map,parameter_names=names(fit$opt$par),tmb_parameter_names=names(fit$tmb_params),theta_diag_B_count=sum(names(fit$opt$par)=='theta_diag_B'))
    result$model_rows <- list(n=nrow(fit$data),unit=as.character(fit$data[['unit']]),trait=as.character(fit$data[['trait']]),row_id=fit$data$row_id,visit=fit$data$visit,tmb_trials=fit$tmb_data$n_trials,tmb_data=fit$tmb_data,design=fit$X)
    result$effects <- capture('effects',extract_lv_effects(fit,type='trait_effect',method='wald'))
    result$Sigma <- setNames(lapply(c('shared','unique','total'),function(p) capture(p,extract_Sigma(fit,level='unit',part=p,link_residual='none'))),c('shared','unique','total'))
    result$prediction <- capture('prediction',predict(fit,type='response'))
    result$coef <- capture('coef',coef(fit))
    if(is.finite(tau) && !is.null(result$effects)) {
      tampered <- fit; attr(tampered$sd_report,'loading_ridge_curvature')$ridge_tau <- tau+123
      neg <- capture('curvature_negative_control',extract_lv_effects(tampered,type='trait_effect',method='wald'))
      result$curvature_negative_control <- list(output=neg,pass=!is.null(neg) && all(is.na(neg$std.error)) && all(neg$uncertainty_status=='loading_ridge_point_only_no_lv_se'))
    }
    result$route_error <- length(result$errors)>0
    if(!is.null(result$effects)) {
      e <- result$effects; e$truth <- fx$truth$B[match(e$trait,names(fx$truth$B))]
      e$available <- is.finite(e$lower)&is.finite(e$upper); e$covered <- ifelse(e$available,e$lower<=e$truth & e$upper>=e$truth,NA)
      result$effects <- e
    }
  }
  result$total_elapsed <- proc.time()[['elapsed']]-start
  save_summary(result,fx,out,label)
  immutable(result,file.path(out,paste0('result-',label,'.rds')))
  heartbeat(cell$task,label,'arm_complete')
  cat(sprintf('task=%d tau=%s seconds=%.3f errors=%s\n',cell$task,label,result$total_elapsed,paste(names(result$errors),collapse=',')));flush.console()
  rm(fit);gc()
}

}
for(task_id in tasks) { run_task(task_id);gc() }
heartbeat(NA_integer_,NA_character_,'worker_complete')
