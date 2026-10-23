library(gllvmTMB)
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88/fd-runtime-1"
label <- commandArgs(TRUE)[[1]]
dest <- file.path(root,paste0("evaluation-",label,".rds"))
stopifnot(!file.exists(dest),label %in% c("old","new"))
r <- readRDS(file.path(root,"failing-endpoint.rds"))
td <- r$fit$tmb_data
obj <- TMB::MakeADFun(td,r$parameters,map=r$fit$tmb_map,
  random=r$fit$random,DLL="gllvmTMB",silent=TRUE)
stopifnot(identical(names(obj$par),names(r$fit$opt$par)),td$use_diag_B==0L)
par <- r$fit$opt$par
pos <- which(names(par)=="eta_column_coef_rho")
theta <- par[names(par)=="theta_dep_chol"]
L <- matrix(c(exp(theta[1]),theta[3],0,exp(theta[2])),2)
Sigma <- tcrossprod(L)
d <- 1/td$column_coef_source_inv_d
K <- diag(d) %*% td$column_coef_source_U %*%
  diag(td$column_coef_source_lambda) %*% t(td$column_coef_source_U) %*% diag(d)
D <- diag(d^2)
ids <- td$trait_id+1L
X <- td$Z_phy_aug[,,1]
stopifnot(identical(dim(X),c(length(td$y),2L)))
coef_cells <- X %*% Sigma %*% t(X)
fixed <- drop(r$fit$X_fix %*% par[names(par)=="b_fix"])
resid <- td$y-fixed
sigma <- exp(par[names(par)=="log_sigma_eps"])
stopifnot(length(sigma)==1L)
exact <- function(eta) {
  rho <- plogis(eta)
  Kr <- rho*K+(1-rho)*D
  V <- Kr[ids,ids]*coef_cells + diag(sigma^2,length(ids))
  C <- chol(V); Vi <- chol2inv(C); a <- drop(Vi%*%resid)
  value <- .5*(length(ids)*log(2*pi)+2*sum(log(diag(C)))+sum(resid*a))
  Vdot <- rho*(1-rho)*(K-D)[ids,ids]*coef_cells
  gradient <- .5*sum((Vi-tcrossprod(a))*Vdot)
  c(value=value,gradient=gradient)
}
out <- list(library=find.package("gllvmTMB"),
  dll_sha256=digest::digest(file=file.path(find.package("gllvmTMB"),"libs/gllvmTMB.so"),algo="sha256"),
  endpoint_sha256=digest::digest(file=file.path(root,"failing-endpoint.rds"),algo="sha256"),
  script_sha256=digest::digest(file=file.path(root,"evaluate.R"),algo="sha256"),
  par=par,outer_optimizer_calls=0L,points=list())
for(eta in c(-1.2,-.15,.9)) {
  h <- 1e-4
  probe <- par; probe[pos]<-eta
  upper <- lower <- probe;upper[pos]<-eta+h;lower[pos]<-eta-h
  vu <- obj$fn(upper); vl <- obj$fn(lower)
  ga <- as.numeric(obj$gr(probe)[pos])
  vb <- obj$fn(probe)
  full <- obj$env$last.par
  inner <- max(abs(obj$env$f(full,order=1)[obj$env$random]))
  ex <- exact(eta); eu <- exact(eta+h); el <- exact(eta-h)
  entry <- c(eta=eta,native_value=vb,native_score=ga,native_fd=(vu-vl)/(2*h),
    exact_value=unname(ex["value"]),exact_score=unname(ex["gradient"]),
    exact_fd=unname((eu["value"]-el["value"])/(2*h)),inner_max_gradient=inner,
    upper_value_error=unname(vu-eu["value"]),lower_value_error=unname(vl-el["value"]))
  out$points[[as.character(eta)]] <- entry
  print(entry)
  saveRDS(out,dest)
}
TMB::FreeADFun(obj)
cat("FIXED_POINT_EVALUATION_COMPLETE_NO_OPTIMIZER\n")
