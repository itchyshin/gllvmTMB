.rho_spatial_fixture <- function() {
  locations <- data.frame(group=paste0("g",1:6),x=c(0,1,0,1,.3,.7),
                          y=c(0,0,1,1,.4,.6))
  dat <- expand.grid(trait=paste0("t",1:4),rep=1:2,group=locations$group)
  dat$group <- factor(dat$group,levels=rev(locations$group))
  dat$obs <- interaction(dat$group,dat$rep,drop=TRUE)
  dat$x <- locations$x[match(dat$group,locations$group)]
  dat$ycoord <- locations$y[match(dat$group,locations$group)]
  dat$y <- sin(seq_len(nrow(dat))/3)
  mesh <- make_mesh(dat,c("x","ycoord"),cutoff=.15)
  list(data=dat,mesh=mesh)
}

.rho_spatial_reference <- function(par,obj,payload,rho) {
  p <- obj$env$parList(par);td <- payload$data
  kappa <- exp(p$log_kappa_spde)
  Q <- as.matrix(kappa^4*td$spde_M0+2*kappa^2*td$spde_M1+td$spde_M2)
  A <- as.matrix(td$A_proj)
  K <- A %*% solve(Q,t(A))
  group <- td$spatial_rho_group_id
  Kr <- rho*K+(1-rho)*(outer(group,group,"==")*sqrt(outer(diag(K),diag(K))))
  nt <- td$n_traits;S <- matrix(0,nt,nt)
  if(td$spde_lv_k>0) {
    L <- matrix(0,nt,td$spde_lv_k)
    diag(L) <- p$theta_rr_spde_lv[seq_len(td$spde_lv_k)]
    L[lower.tri(L)] <- p$theta_rr_spde_lv[-seq_len(td$spde_lv_k)]
    S <- tcrossprod(L)
  }
  if(td$spde_lv_k==0 || td$spde_lv_unique==1) S <- S+diag(exp(-2*p$log_tau_spde),nt)
  ti <- td$trait_id+1L
  V <- Kr*S[ti,ti];diag(V) <- diag(V)+exp(2*p$log_sigma_eps)
  residual <- as.numeric(td$y-td$X_fix %*% p$b_fix)
  .5*(length(residual)*log(2*pi)+as.numeric(determinant(V,logarithm=TRUE)$modulus)+
        drop(crossprod(residual,solve(V,residual))))
}
