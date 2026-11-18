#!/usr/bin/env Rscript
## Independent no-fit Gaussian algebra diagnostic; not a fitting engine.
library(gllvmTMB)
source('dev/tree-axis-latent/fixture.R')
f <- make_tree_axis_fixture('target')$community
Y <- as.matrix(f$wide[f$species]); X <- cbind(1,f$sites$latitude)
Xfixed <- model.matrix(~0+pathway+latitude:pathway,f$long)
out <- list()
for(id in c('M2','M3')) {
 r <- readRDS(file.path('/private/tmp/gllvm-tree-axis-latent-20260830/results',paste0('fit-',id,'.rds')))
 stopifnot(identical(as.numeric(t(Y)),as.numeric(r$fit$tmb_data$y)),
           identical(rownames(r$public$unit$total),f$species))
 E <- Y-matrix(drop(Xfixed%*%coef(r$fit)[colnames(Xfixed)]),nrow=nrow(Y),byrow=TRUE)
 R <- r$public$unit$total + diag(exp(2*r$gaussian$fixed_value),ncol(Y))
 U <- chol(R); Uinv <- solve(U)
 K <- if(id=='M2') diag(ncol(Y)) else r$public$column_coef$K_rho
 C <- t(Uinv)%*%K%*%Uinv
 G <- X%*%r$public$column_coef$Sigma%*%t(X)
 ec <- eigen(C,symmetric=TRUE); eg <- eigen(G,symmetric=TRUE)
 stopifnot(min(ec$values)>0,min(eg$values)>-1e-10)
 scale <- 1+outer(pmax(eg$values,0),ec$values)
 T <- t(eg$vectors)%*%E%*%Uinv%*%ec$vectors
 nll <- .5*(length(Y)*log(2*pi)+nrow(Y)*2*sum(log(diag(U)))+sum(log1p(outer(pmax(eg$values,0),ec$values)))+sum(T^2/scale))
 out[[id]] <- list(direct_gaussian_nll=nll,reported_nll=r$objective,difference=nll-r$objective)
}
print(out)
jsonlite::write_json(out,'/private/tmp/gllvm-tree-axis-latent-20260830/direct-Gaussian-check.json',pretty=TRUE,auto_unbox=TRUE,digits=NA)
cat('DIRECT_GAUSSIAN_NLL_COMPARISON_RECORDED: no optimization, no new acceptance threshold\n')
