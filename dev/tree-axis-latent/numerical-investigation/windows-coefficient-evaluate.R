library(gllvmTMB)
library(testthat)
main <- function() {
 label <- commandArgs(TRUE)[[1]]
 root <- '/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88/windows-trial-2'
 dest <- file.path(root,paste0(label,'.rds')); stopifnot(!file.exists(dest),label %in% c('old','current'))
 blocked <- function(...) stop('No outer optimizer allowed')
 local_mocked_bindings(nlminb=blocked,optim=blocked,.package='stats')
 local_mocked_bindings(.gllvmTMB_run_nlminb=blocked,.package='gllvmTMB')
 ex <- parse(file.path(root,'diagnostic-1.R.txt')); stopifnot(length(ex)==1L)
 safe <- function(x) {
  if (is.call(x)) return(is.name(x[[1]]) && as.character(x[[1]]) %in% c('list','c','structure','-','integer','numeric') && all(vapply(as.list(x)[-1],safe,logical(1))))
  if (is.name(x)) return(as.character(x) %in% c('NaN','NA','NA_real_','NA_integer_','NULL','Inf','TRUE','FALSE'))
  is.atomic(x) || is.null(x)
 }
 stopifnot(safe(ex[[1]])); win <- eval(ex[[1]],envir=baseenv())
 stopifnot(identical(win$calls[[1]]$result,win$calls[[2]]$result),length(win$calls[[1]]$nonfinite_trials)==1L)
 source('tests/testthat/helper-column-coef-animal.R',local=TRUE)
 fx <- .make_animal_coef_fixture(seed=13142L)
 capture <- function() {
  payload <- NULL
  local_mocked_bindings(MakeADFun=function(data,parameters,map,random,...) {
   payload <<- list(data=data,parameters=parameters,map=map,random=random)
   stop('payload captured before tape')
  },.package='TMB')
  err <- tryCatch(.fit_animal_coef_test(fx,value~0+trait+animal_coef(0+x+z|trait,A=fx$A,rho=1)),error=identity)
  stopifnot(inherits(err,'error'),conditionMessage(err)=='payload captured before tape')
  payload
 }
 p <- readRDS(file.path(root,'capture-current.rds')); d <- p$data
 saved <- readRDS('/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88/animal-warning-review-1/new.rds')$records[[1]]
 common <- intersect(names(d),names(saved$data))
 differences <- common[!vapply(common,function(nm)identical(d[[nm]],saved$data[[nm]]),logical(1))]
 stopifnot(identical(differences,'site_species_id'),d$use_rr_B==0L,d$use_lv_B==0L,d$use_diag_B==0L,
   identical(p$random,'b_phy_aug'),identical(p$map,saved$map))
 # Retain the actual saved model data verbatim. The fresh parameters are valid;
 # its differing unit index is inactive (no ordinary unit random effects).
 p$data <- saved$data; d <- p$data
 stopifnot(d$use_phylo_dep_slope==1L,d$use_column_coef_estimated_rho==0L)
 K <- fx$A+diag(1e-8,nrow(fx$A)); ids <- d$phylo_slope_aug_id+1L
 stopifnot(max(abs(solve(K)-as.matrix(d$Ainv_phy_slope)))<1e-10)
 Z <- d$Z_phy_aug[,,1]; X <- as.matrix(d$X_fix)
 exact <- function(par) {
  theta <- par[names(par)=='theta_dep_chol']; stopifnot(length(theta)==3L)
  a<-exp(theta[1]);cc<-exp(theta[2]);b<-theta[3]
  L<-matrix(c(a,b,0,cc),2); Sigma<-tcrossprod(L)
  sigma<-exp(par[names(par)=='log_sigma_eps']); stopifnot(length(sigma)==1L)
  e<-d$y-drop(X%*%par[names(par)=='b_fix'])
  V<-K[ids,ids]*(Z%*%Sigma%*%t(Z))+diag(sigma^2,length(ids))
  C<-chol(V);Vi<-chol2inv(C);alpha<-drop(Vi%*%e);W<-Vi-tcrossprod(alpha)
  val<-.5*(length(ids)*log(2*pi)+2*sum(log(diag(C)))+sum(e*alpha))
  deriv<-list(matrix(c(2*a*a,a*b,a*b,0),2),matrix(c(0,0,0,2*cc*cc),2),matrix(c(0,a,a,2*b),2))
  gr<-c(-drop(crossprod(X,alpha)),sigma^2*sum(diag(W)),vapply(deriv,function(S) .5*sum(W*K[ids,ids]*(Z%*%S%*%t(Z))),numeric(1)))
  names(gr)<-names(par)
  list(value=val,gradient=gr,L=L,Sigma=Sigma,kappa_L=kappa(L,exact=TRUE),min_eigen_V=min(eigen(V,symmetric=TRUE,only.values=TRUE)$values))
 }
 out<-list(label=label,library=find.package('gllvmTMB'),dll_sha256=digest::digest(file=file.path(find.package('gllvmTMB'),'libs/gllvmTMB.so'),algo='sha256'),script_sha256=digest::digest(file=file.path(root,'evaluate-3.R'),algo='sha256'),trial_sha256=digest::digest(file=file.path(root,'diagnostic-1.R.txt'),algo='sha256'),payload=p,outer_optimizer_calls=0L,points=list())
 points<-list(endpoint=win$calls[[1]]$result$par,trial=win$calls[[1]]$nonfinite_trials[[1]]$par)
 for(nm in names(points)) {
  obj<-TMB::MakeADFun(p$data,p$parameters,map=p$map,random=p$random,DLL='gllvmTMB',silent=TRUE)
  point<-points[[nm]]; stopifnot(identical(names(point),names(obj$par)))
  warn<-character();err<-NULL
  val<-tryCatch(withCallingHandlers(obj$fn(point),warning=function(w){warn<<-c(warn,conditionMessage(w));invokeRestart('muffleWarning')}),error=function(e){err<<-conditionMessage(e);NA_real_})
  gr<-inner<-NULL
  if(is.finite(val)) {
   gr<-tryCatch(obj$gr(point),error=function(e)conditionMessage(e))
   inner<-tryCatch(max(abs(obj$env$f(obj$env$last.par,order=1)[obj$env$random])),error=function(e)conditionMessage(e))
  }
  ref<-exact(point)
  out$points[[nm]]<-list(par=point,native_value=val,native_gradient=gr,inner_gradient=inner,warnings=warn,error=err,exact=ref,value_error=val-ref$value)
  print(list(label=label,point=nm,native=val,exact=ref$value,error=val-ref$value,native_max_gradient=if(is.numeric(gr))max(abs(gr)) else gr,exact_max_gradient=max(abs(ref$gradient)),inner_gradient=inner,kappa_L=ref$kappa_L,min_eigen_V=ref$min_eigen_V,warnings=warn))
  saveRDS(out,dest);TMB::FreeADFun(obj)
 }
 cat('WINDOWS_SAVED_TWO_POINT_CHECK_COMPLETE_NO_OUTER_OPTIMIZER\n')
}
main()
