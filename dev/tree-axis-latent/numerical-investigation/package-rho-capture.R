library(gllvmTMB)
library(testthat)
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88/fd-runtime-1"
path <- "tests/testthat/test-column-coef-phylo-estimated-rho.R"
.fd_captures <- list()
trace("gllvmTMB", where=asNamespace("gllvmTMB"), print=FALSE, exit=quote({
  .fd_fit <- returnValue()
  if (inherits(.fd_fit,"gllvmTMB_multi")) {
    .fd_capture <- list(fit=.fd_fit, parameters=.fd_fit$tmb_obj$env$parList(),
      full=.fd_fit$tmb_obj$env$last.par.best,
      library=find.package("gllvmTMB"),
      dll_sha256=digest::digest(file=file.path(find.package("gllvmTMB"),"libs/gllvmTMB.so"),algo="sha256"),
      test_sha256=digest::digest(file=.GlobalEnv$path,algo="sha256"))
    .GlobalEnv$.fd_captures[[length(.GlobalEnv$.fd_captures)+1L]] <- .fd_capture
    saveRDS(.fd_capture,file.path(.GlobalEnv$root,"failing-endpoint.rds"))
  }
}))
code <- parse(path)
for (i in seq_along(code)) {
  x <- code[[i]]
  if (is.call(x) && identical(x[[1]],as.name("<-"))) eval(x,envir=globalenv())
}
selected <- which(vapply(code,function(x) is.call(x) && identical(x[[1]],as.name("test_that")) &&
  identical(x[[2]],"estimated-rho objective has finite-difference gradient oracles away from the optimum"),logical(1)))
stopifnot(length(selected)==1L)
failure <- tryCatch({eval(code[[selected]],envir=globalenv());NULL},error=function(e) conditionMessage(e))
untrace("gllvmTMB",where=asNamespace("gllvmTMB"))
stopifnot(length(.fd_captures)==1L)
r <- .fd_captures[[1]]
theta <- r$fit$opt$par[names(r$fit$opt$par)=="theta_dep_chol"]
L <- matrix(c(exp(theta[1]),theta[3],0,exp(theta[2])),2)
report <- list(test_failure=failure,fit_calls=length(.fd_captures),
  convergence=r$fit$opt$convergence,optimizer_message=r$fit$opt$message,
  objective=r$fit$opt$objective,outer=r$fit$opt$par,
  integrated=r$fit$integrated_gaussian_diag_B,use_diag_B=r$fit$tmb_data$use_diag_B,
  L=L,Sigma=L%*%t(L),singular_values=svd(L)$d,kappa_L=kappa(L,exact=TRUE),
  sigma_eps=exp(r$parameters$log_sigma_eps))
saveRDS(report,file.path(root,"capture-summary.rds"));print(report)
