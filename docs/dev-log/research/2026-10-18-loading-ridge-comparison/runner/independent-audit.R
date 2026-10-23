#!/usr/bin/env Rscript
# Inspect retained numeric objects only. Never call serialized native pointers.
args <- commandArgs(TRUE)
stopifnot(length(args) >= 1L)
root <- normalizePath(args[1], mustWork = TRUE)
partial <- '--partial' %in% args
generator <- file.path(root, 'generate.R')
if(!file.exists(generator)) generator <- file.path(root,'runner','generate.R')
source(generator)
manifest <- full_manifest()
paths <- list.files(file.path(root, 'results'), '^result-.*\\.rds$',
                    recursive = TRUE, full.names = TRUE)
near <- function(a,b,tol=1e-8) length(a)>0L && identical(dim(a),dim(b)) && length(a)==length(b) &&
  all(is.finite(a)) && all(is.finite(b)) && max(c(0,abs(a-b))) <= tol*max(c(1,abs(b)))
rows <- vector('list',length(paths))
for (i in seq_along(paths)) {
  p <- paths[i]
  ans <- list(path=p,task=NA_integer_,tau=NA_real_,family=NA_character_,n=NA_integer_,strength=NA_real_,rep=NA_integer_,fit_present=FALSE,
              finite_ridge=FALSE,fit_error=FALSE,audit_error='')
  ans <- tryCatch({
    r <- readRDS(p); fx <- readRDS(file.path(dirname(p),'fixture.rds'))
    ans$task <- r$task$task; ans$tau <- r$tau
    for(k in c('family','n','strength','rep')) ans[[k]] <- r$task[[k]]
    ans$finite_ridge <- is.finite(r$tau); ans$fit_error <- !is.null(r$errors$fit)
    expected <- manifest[manifest$task==ans$task,,drop=FALSE]
    ans$manifest <- nrow(expected)==1L && identical(r$task,expected) && identical(fx$cell,expected)
    ans$seeds <- identical(r$data_seed,expected$data_seed) && identical(r$init_seed,expected$init_seed)
    ans$generator_checks <- all(r$alignment) && all(r$negative_controls) && all(pilot_alignment(fx))
    L <- fx$truth$Lambda
    ans$truth_identity <- near(as.numeric(L%*%fx$truth$alpha),as.numeric(fx$truth$B)) &&
      near(tcrossprod(L),fx$truth$shared) && near(fx$truth$unique,diag(.16,6)) &&
      near(fx$truth$total,tcrossprod(L)+diag(.16,6)) && abs(fx$truth$B[3])<1e-12
    fp <- file.path(dirname(p),sub('^result-','fit-',basename(p)))
    ans$fit_present <- file.exists(fp)
    ans$fit_custody <- ans$fit_present != ans$fit_error
    if (ans$fit_present) {
      f <- readRDS(fp)
      ans$model_rows <- identical(r$model_rows$row_id,fx$data$row_id) &&
        identical(r$model_rows$unit,as.character(fx$data$unit)) &&
        identical(r$model_rows$trait,as.character(fx$data$trait)) &&
        identical(r$model_rows$visit,fx$data$visit) && identical(f$data$y,fx$data$y) &&
        identical(as.character(f$data$unit),as.character(fx$data$unit)) &&
        identical(as.character(f$data$trait),as.character(fx$data$trait))
      ans$trials <- expected$family!='binomial' ||
        identical(as.numeric(r$model_rows$tmb_trials),as.numeric(fx$data$trials))
      di <- which(names(f$opt$par)=='theta_diag_B')
      ans$psi_estimated <- isTRUE(f$use$diag_B) && length(di)==6L &&
        all(f$tmb_data$diag_B_skip==0) && 's_B'%in%f$random &&
        sum(names(f$sd_report$par.random)=='s_B')==6L*expected$n
      ans$parameter_binding <- identical(r$opt_par,f$opt$par) &&
        identical(r$parameter_names,names(f$opt$par)) &&
        identical(f$sd_report$par.fixed,f$opt$par)
      c <- r$curvature
      ans$curvature <- !ans$finite_ridge || (is.list(c) &&
        identical(c,attr(f$sd_report,'loading_ridge_curvature')) &&
        identical(c$objective,'likelihood_plus_gaussian_loading_prior') &&
        identical(c$interpretation,'local_approximate_posterior_curvature_at_map') &&
        identical(c$ridge_tau,r$tau) && identical(c$ridge_tau,f$aghq$ridge_tau) &&
        identical(c$parameter_names,names(f$opt$par)) && identical(c$parameter_vector,f$opt$par) &&
        identical(c$loading_indices,which(names(f$opt$par)=='theta_rr_B')))
      neg <- r$curvature_negative_control
      ans$negative_control <- !ans$finite_ridge || (isTRUE(neg$pass) &&
        is.data.frame(neg$output) && nrow(neg$output)==6L &&
        all(is.na(neg$output$std.error)) && all(is.na(neg$output$lower)) &&
        all(is.na(neg$output$upper)) &&
        all(neg$output$uncertainty_status=='loading_ridge_point_only_no_lv_se'))
      e <- r$effects
      ans$effect_identity <- is.data.frame(e) && nrow(e)==6L &&
        identical(as.character(e$trait),names(fx$truth$B)) &&
        near(as.numeric(e$truth),as.numeric(fx$truth$B)) &&
        near(as.numeric(e$estimate),as.numeric(f$report$B_lv_unit)) &&
        near(as.numeric(f$report$B_lv_unit),as.numeric(f$report$Lambda_B%*%t(f$report$alpha_lv_B)))
      ans$interval_flags <- identical(e$available,is.finite(e$lower)&is.finite(e$upper)) &&
        identical(e$covered,ifelse(e$available,e$lower<=e$truth&e$upper>=e$truth,NA))
      ans$pdHess <- isTRUE(f$sd_report$pdHess)
      ans$available_effect_n <- sum(e$available)
      expected_status <- if(ans$finite_ridge) {
        if(ans$pdHess) 'loading_ridge_posterior_sd_no_sampling_ci_validation' else 'loading_ridge_non_pd_posterior_hessian_no_lv_se'
      } else if(ans$pdHess) 'wald_sdreport_no_ci_validation' else 'sdreport_non_pd_hessian_no_lv_se'
      ans$interval_status <- all(e$uncertainty_status==expected_status) &&
        (ans$pdHess || !any(e$available))
      ss <- r$Sigma
      unique_s <- ss$unique$s
      unique_matrix <- diag(as.numeric(unique_s),6L)
      dimnames(unique_matrix) <- list(names(unique_s),names(unique_s))
      ans$sigma_order <- all(vapply(ss[c('shared','total')],function(s) identical(rownames(s$Sigma),names(fx$truth$B)) &&
        identical(colnames(s$Sigma),names(fx$truth$B)),logical(1))) &&
        identical(names(unique_s),names(fx$truth$B)) && length(unique_s)==6L
      ans$sigma_identity <- near(ss$total$Sigma,ss$shared$Sigma+unique_matrix) &&
        near(ss$shared$Sigma,tcrossprod(f$report$Lambda_B)) &&
        near(as.numeric(unique_s),as.numeric(exp(2*f$opt$par[di])))
      # Public part='unique' returns variance vector s, not a Sigma matrix.
      # These supplementary recovery metrics correct that representation mismatch.
      ans$derived_unique_relative_F <- norm(unique_matrix-fx$truth$unique,'F')/norm(fx$truth$unique,'F')
      ans$derived_unique_diag_RMSE <- sqrt(mean((unique_s-diag(fx$truth$unique))^2))
      ans$derived_unique_offdiag_RMSE <- 0
      pred <- switch(expected$family,binomial=pnorm(f$report$eta),gaussian=f$report$eta,poisson=exp(f$report$eta))
      ans$conditional_prediction <- near(as.numeric(r$prediction$est),as.numeric(pred))
      rm(f)
    }
    ans
  }, error=function(e) {ans$audit_error <- conditionMessage(e);ans})
  rows[[i]] <- ans
  if(i%%100L==0L) {cat('audited',i,'/',length(paths),'\n');flush.console();gc()}
}
fields <- unique(unlist(lapply(rows,names)))
tab <- do.call(rbind,lapply(rows,function(r) as.data.frame(setNames(lapply(fields,function(k)
  if(is.null(r[[k]])) NA else r[[k]]),fields),stringsAsFactors=FALSE)))
dir.create(file.path(root,'summary'),showWarnings=FALSE)
write.csv(tab,file.path(root,'summary','independent-audit.csv'),row.names=FALSE)
unique_fields <- c('task','family','n','strength','rep','tau','fit_present','fit_error',
  'sigma_order','sigma_identity','derived_unique_relative_F','derived_unique_diag_RMSE','derived_unique_offdiag_RMSE')
unique_rows <- tab[intersect(unique_fields,names(tab))]
unique_rows$source <- "public extract_Sigma(part='unique')$s, variance vector verified against exp(2*theta_diag_B) and total-minus-shared"
write.csv(unique_rows,file.path(root,'summary','unique-recovery.csv'),row.names=FALSE)
checks <- setdiff(names(tab),c('path','task','tau','family','n','strength','rep','fit_present','finite_ridge','fit_error','audit_error','pdHess','available_effect_n',
  'derived_unique_relative_F','derived_unique_diag_RMSE','derived_unique_offdiag_RMSE'))
counts <- data.frame(check=checks,evaluated=vapply(tab[checks],function(x)sum(!is.na(x)),integer(1)),
                     failed=vapply(tab[checks],function(x)sum(!is.na(x)&!x),integer(1)))
write.csv(counts,file.path(root,'summary','independent-audit-counts.csv'),row.names=FALSE)
print(counts,row.names=FALSE)
complete <- nrow(tab)==24000L && !anyDuplicated(paste(tab$task,tab$tau)) &&
  setequal(tab$task,manifest$task) && all(table(tab$task)==4L)
cat('RESULT_ARMS',nrow(tab),'FINITE_RIDGE_ARMS',sum(tab$finite_ridge),'FIT_ERRORS',sum(tab$fit_error),
    'AUDIT_ERRORS',sum(nzchar(tab$audit_error)),'COMPLETE',complete,'\n')
if(any(counts$failed>0L)||any(nzchar(tab$audit_error))||(!partial&&!complete)) quit(status=1L)
