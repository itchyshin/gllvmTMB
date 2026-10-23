#!/usr/bin/env Rscript
## Rebuild the joint-density tape at retained parameters; NO optimization.
library(gllvmTMB)
library(TMB)
rdir <- '/private/tmp/gllvm-tree-axis-latent-20260830/results'
x <- readRDS(file.path(rdir,'fit-M2.rds'))$fit
bad <- readRDS(file.path(rdir,'B2-attempt-1-result.rds'))$result$par
out <- list()
for (id in c('retained','BFGS')) {
  outer <- if(id=='retained') x$opt$par else bad
  pars <- x$tmb_obj$env$parList(x=outer,par=x$tmb_obj$env$last.par.best)
  obj <- TMB::MakeADFun(data=x$tmb_data,parameters=pars,map=x$tmb_map,
                       random=NULL,DLL='gllvmTMB',silent=TRUE)
  nll <- obj$fn(obj$par)
  # Lower bound from the normalizing constants of every active normal factor.
  n <- x$n_sites; p <- x$n_traits; C <- 2L; ns <- x$n_species
  bound <- n*p*(pars$log_sigma_eps + log(2*pi)/2) +
    n*(sum(pars$theta_diag_B)+p*log(2*pi)/2) +
    n*x$d_B*log(2*pi)/2 + ns*(sum(pars$theta_dep_chol[1:C])+C*log(2*pi)/2)
  out[[id]] <- list(joint_nll=nll,joint_normalizer_lower_bound=bound,
                   violates_bound=is.finite(nll)&&nll<bound-1e-6,
                   random_parameters=sum(vapply(pars[x$random],length,integer(1))))
  TMB::FreeADFun(obj)
}
print(out)
jsonlite::write_json(out,'/private/tmp/gllvm-tree-axis-latent-20260830/replay-joint.json',pretty=TRUE,auto_unbox=TRUE,digits=NA)
stopifnot(!out$retained$violates_bound)
cat('JOINT_REPLAY_COMPLETE_NO_OPTIMIZATION\n')
