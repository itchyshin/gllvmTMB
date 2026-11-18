.libPaths(c('/tmp/gllvmtmb-two-kernel-staged-lib', .libPaths()))
library(gllvmTMB)
stopifnot(grepl('gllvmtmb-two-kernel-staged-lib', find.package('gllvmTMB')))
n <- 8L; sp <- c(paste0('H',1:n),paste0('P',1:n))
A <- .6^abs(outer(1:n,1:n,'-')); I <- diag(n)
K_phy <- rbind(cbind(A,.55*A),cbind(.55*A,A)); K_tip <- rbind(cbind(I,.55*I),cbind(.55*I,I))
dimnames(K_phy) <- dimnames(K_tip) <- list(sp,sp)
dat <- data.frame(species=factor(sp,levels=sp),row_id=factor(sp,levels=sp),H1=c(sin(1:n),rep(NA_real_,n)),H2=c(cos(1:n),rep(NA_real_,n)),P1=c(rep(NA_real_,n),sin((1:n)+.3)),P2=c(rep(NA_real_,n),cos(1:n)))
f <- traits(H1,H2,P1,P2) ~ 1 + kernel_latent(species,K=K_phy,d=1,name='phy',unique=TRUE) + kernel_latent(species,K=K_tip,d=1,name='tip',unique=TRUE)
cat('START',as.character(Sys.time()),'\n')
fit <- gllvmTMB(f,dat,family=gaussian(),unit='row_id',cluster='species',missing=miss_control(response='include'),control=gllvmTMBcontrol(se=FALSE),silent=TRUE,known_sigma_eps=.12)
saveRDS(fit,'dev/two-kernel-gaussian/fitcheck/fit.rds')
cat('CONVERGENCE',fit$opt$convergence,'KNOWN_SD',fit$known_sigma_eps,'\n')
stopifnot(identical(fit$known_sigma_eps,.12))
for (level in c('phy','tip')) {
 s <- extract_Sigma(fit,level=level,part='shared')$Sigma
 u <- extract_Sigma(fit,level=level,part='unique')$Sigma
 t <- extract_Sigma(fit,level=level,part='total')$Sigma
 print(list(level=level,shared=s,unique=u,total=t))
 stopifnot(all(dim(s)==c(4,4)), identical(dimnames(s),dimnames(u)),identical(dimnames(s),dimnames(t)),max(abs(t-s-u))<1e-10)
}
cat('EXTRACTION_PASS\n')
check <- function(label,expr,expect_error=FALSE) { x<-tryCatch(list(value=force(expr)),error=function(e) list(error=conditionMessage(e),class=class(e))); cat(label,if(!is.null(x$error)) paste('ERROR',x$error) else paste('OK length',length(x$value)),'\n'); if(expect_error == is.null(x$error)) stop(paste('unexpected result',label)); invisible(x) }
check('conditional_simulation',simulate(fit,nsim=1,condition_on_RE=TRUE))
check('unconditional_simulation',simulate(fit,nsim=1,condition_on_RE=FALSE),TRUE)
check('fixed_newdata',predict(fit,newdata=fit$data,re_form=~0))
check('conditional_newdata',predict(fit,newdata=fit$data,re_form=~. ),TRUE)
check('newdata_simulation',simulate(fit,nsim=1,newdata=fit$data,condition_on_RE=FALSE),TRUE)
cat('FITCHECK_PASS\n')
