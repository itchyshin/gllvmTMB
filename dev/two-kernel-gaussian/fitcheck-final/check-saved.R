.libPaths(c('/tmp/gllvmtmb-two-kernel-final-lib',.libPaths()))
library(gllvmTMB)
fit <- readRDS('dev/two-kernel-gaussian/fitcheck-final/fit.rds')
stopifnot(identical(fit$known_sigma_eps,.12))
for (level in c('phy','tip')) {
 s <- extract_Sigma(fit,level=level,part='shared')$Sigma
 u <- extract_Sigma(fit,level=level,part='unique')$s
 t <- extract_Sigma(fit,level=level,part='total')$Sigma
 stopifnot(length(u)==4L,identical(rownames(s),names(u)),identical(dimnames(s),dimnames(t)))
 gap <- max(abs(t-s-diag(u)))
 cat('TIER',level,'total_gap',format(gap,digits=16),'unique',paste(format(u,digits=7),collapse=','),'\n')
 stopifnot(gap < 1e-10)
}
cat('EXTRACTION_PASS\n')
check <- function(label,expr,expected_class=NULL) { x<-tryCatch(list(value=force(expr)),error=function(e) list(error=conditionMessage(e),class=class(e))); cat(label,if(!is.null(x$error)) paste('ERROR',x$error) else paste('OK length',length(x$value)),'\n'); if(is.null(expected_class)) {if(!is.null(x$error)) stop(paste('unexpected error',label))} else if(is.null(x$error)||!expected_class %in% x$class) stop(paste('wrong rejection',label)); invisible(x) }
check('conditional_simulation',simulate(fit,nsim=1,condition_on_RE=TRUE))
check('unconditional_simulation',simulate(fit,nsim=1,condition_on_RE=FALSE),'gllvmTMB_multi_kernel_simulation_unsupported')
check('fixed_newdata',predict(fit,newdata=fit$data,re_form=~0))
check('conditional_newdata',predict(fit,newdata=fit$data,re_form=~. ),'gllvmTMB_multi_kernel_predict_newdata_unsupported')
check('newdata_simulation',simulate(fit,nsim=1,newdata=fit$data,condition_on_RE=FALSE),'gllvmTMB_multi_kernel_simulation_newdata_unsupported')
cat('FITCHECK_PASS\n')
