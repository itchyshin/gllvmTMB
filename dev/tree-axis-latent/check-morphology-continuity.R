#!/usr/bin/env Rscript
## Re-evaluate frozen M1/W1 parameters on repaired source; no outer optimizer.
library(gllvmTMB)
root<-Sys.getenv("GLLVM_TREE_AXIS_ORIGINAL"); outdir<-Sys.getenv("GLLVM_TREE_AXIS_RESULTS")
provenance<-jsonlite::read_json(file.path(outdir,"provenance.json"),simplifyVector=TRUE)
stopifnot(identical(normalizePath(find.package("gllvmTMB")),provenance$library),
  identical(digest::digest(file=file.path(provenance$library,"libs/gllvmTMB.so"),algo="sha256"),provenance$dll_sha256))
paths<-setNames(file.path(root,paste0("fit-",c("M1","W1"),".rds")),c("M1","W1"))
result<-list(provenance=provenance,receipt_md5=as.list(tools::md5sum(paths)),checks=list())
for(id in names(paths)) {
  r<-readRDS(paths[[id]]); fit<-r$fit
  obj<-TMB::MakeADFun(fit$tmb_data,fit$tmb_obj$env$parList(),map=fit$tmb_map,
    random=fit$random,DLL="gllvmTMB",silent=TRUE)
  result$checks[[id]]<-lapply(r$restart_snapshots$attempts,function(a) {
    value<-obj$fn(a$par); gradient<-max(abs(obj$gr(a$par)))
    transient<-fit; transient$tmb_obj<-obj; transient$opt$par<-a$par
    obj$env$last.par.best<-obj$env$last.par; transient$report<-obj$report()
    differences<-unlist(lapply(c("phy","unit"),function(level) {
      c(shared=max(abs(extract_Sigma(transient,level=level,part="shared",link_residual="none")$Sigma-a$covariance[[level]]$shared)),
        unique=max(abs(extract_Sigma(transient,level=level,part="unique",link_residual="none")$s-a$covariance[[level]]$unique)),
        total=max(abs(extract_Sigma(transient,level=level,part="total",link_residual="none")$Sigma-a$covariance[[level]]$total)))
    }))
    list(nll=value,old_nll=a$objective,nll_difference=value-a$objective,max_gradient=gradient,
      covariance_max_difference=max(differences),pass=is.finite(value) && abs(value-a$objective)<1e-6 &&
        is.finite(gradient) && gradient<1e-2 && all(is.finite(differences)) && max(differences)<1e-8)
  })
  TMB::FreeADFun(obj)
}
result$pass<-all(vapply(unlist(result$checks,recursive=FALSE),function(x)isTRUE(x$pass),logical(1)))
out<-file.path(outdir,"morphology-continuity.rds");stopifnot(!file.exists(out));saveRDS(result,out)
print(result$checks)
if(!isTRUE(result$pass))stop("Morphology continuity failed")
cat("MORPHOLOGY_CONTINUITY_PASS_NO_OUTER_OPTIMIZATION\n")
