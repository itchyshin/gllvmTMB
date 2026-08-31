#!/usr/bin/env Rscript
## No outer optimization. Keep the original DLL, fits and replay files immutable.
library(gllvmTMB)
library(TMB)
root <- '/private/tmp/gllvm-tree-axis-latent-20260830'
stopifnot(grepl('repaired-library', find.package('gllvmTMB'), fixed = TRUE))
out <- list(library = find.package('gllvmTMB'))
x <- readRDS(file.path(root, 'results/fit-M2.rds'))$fit
r <- readRDS(file.path(root, 'replay-BFGS.rds'))
p <- x$tmb_obj$env$parList(x = r$outer, par = r$full_par)
obj <- MakeADFun(x$tmb_data, p, map = x$tmb_map, random = NULL,
                 DLL = 'gllvmTMB', silent = TRUE)
rep <- obj$report(obj$par)
observation <- -sum(dnorm(x$tmb_data$y, rep$eta, exp(p$log_sigma_eps), log=TRUE))
other <- -sum(dnorm(p$z_B, log=TRUE)) - sum(dnorm(as.vector(p$s_B),
                  sd=rep(exp(p$theta_diag_B), ncol(p$s_B)), log=TRUE))
L <- matrix(c(exp(p$theta_dep_chol[1]),p$theta_dep_chol[3],0,
              exp(p$theta_dep_chol[2])), 2, 2)
B <- p$b_phy_aug[,,1]
W <- t(forwardsolve(L,t(B)))
prior <- .5*(length(B)*log(2*pi)+nrow(B)*2*sum(log(diag(L)))+sum(W^2))
joint <- obj$fn(obj$par)
out$bad_joint <- list(native=joint, oracle=observation+other+prior,
  coefficient_native=joint-observation-other, coefficient_oracle=prior,
  relative_error=abs(joint-(observation+other+prior))/(observation+other+prior))
stopifnot(is.finite(joint), joint>0, out$bad_joint$relative_error<1e-10)
FreeADFun(obj)
for (id in c('M2','M3')) {
  fit <- readRDS(file.path(root,paste0('results/fit-',id,'.rds')))$fit
  obj <- MakeADFun(fit$tmb_data,fit$tmb_obj$env$parList(),map=fit$tmb_map,
                   random=fit$random,DLL='gllvmTMB',silent=TRUE)
  value <- obj$fn(fit$opt$par)
  gradient <- obj$gr(fit$opt$par)
  out[[id]] <- list(nll=value, previous_nll=fit$opt$objective,
    difference=value-fit$opt$objective, max_gradient=max(abs(gradient)))
  stopifnot(is.finite(value), abs(value-fit$opt$objective)<1e-6,
            all(is.finite(gradient)))
  FreeADFun(obj)
}
print(out)
jsonlite::write_json(out,file.path(root,'repair-fixed-points.json'),
                     pretty=TRUE, auto_unbox=TRUE, digits=NA)
cat('REPAIR_FIXED_POINTS_PASS_NO_OUTER_OPTIMIZATION\n')
