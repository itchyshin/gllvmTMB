#!/usr/bin/env Rscript
# One-shot private Design-97 discriminator. It never reuses Design-96 inputs.
source(file.path("dev", "design97-fullcov-jj", "fullcov-jj-oracle.R"))
stopifnot(requireNamespace("TMB", quietly=TRUE), requireNamespace("jsonlite", quietly=TRUE), requireNamespace("digest", quietly=TRUE))

out <- file.path("dev", "design97-fullcov-jj", "results")
if (dir.exists(out)) stop("Design-97 results root already exists; refusing rerun or overwrite")
if (!dir.create(out, recursive=TRUE, showWarnings=FALSE)) stop("Cannot exclusively create Design-97 results root")
atomic_json <- function(path, object) {
  if (file.exists(path)) stop("Refusing overwrite: ", path)
  con <- file(path, open="wx"); on.exit(close(con), add=TRUE)
  writeLines(jsonlite::toJSON(object, auto_unbox=TRUE, null="null", na="null", digits=16, pretty=TRUE), con)
}
checksum <- function(x) digest::digest(serialize(x, NULL, version=2), algo="sha256", serialize=FALSE)
truth <- list(beta=c(-.40,.15,.35,-.25,.20), loading=rbind(c(.80,0),c(.20,.70),c(-.35,.30),c(.45,-.20),c(-.20,-.45)))
truth_loading_free <- c(log(truth$loading[1,1]), truth$loading[2,1], log(truth$loading[2,2]), as.vector(t(truth$loading[3:5,,drop=FALSE])))
truth_free <- d97_loading_from_free(truth_loading_free, 5L)
stopifnot(max(abs(truth_free-truth$loading)) < 1e-14)
make_fixture <- function(label, seed, n) {
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed)
  u <- matrix(rnorm(n*2L), n, 2L)
  probability <- plogis(sweep(u %*% t(truth$loading), 2L, truth$beta, "+"))
  y <- matrix(rbinom(n*5L, 1L, as.vector(probability)), n, 5L)
  list(label=label, seed=seed, y=y, u=u, probability=probability, beta=truth$beta, loading=truth$loading,
    checksum=checksum(y), precheck=all(is.finite(y)) && all(y %in% c(0,1)) && all(colSums(y)>0) && all(colSums(y)<n))
}
local_pack <- function(mean, chol) c(as.vector(mean),as.vector(chol))
local_unpack <- function(x,n) list(mean=matrix(x[seq_len(2L*n)],n,2L),chol=matrix(x[(2L*n+1L):(5L*n)],n,3L))
diagonal_pack <- function(mean,log_sd) c(as.vector(mean),as.vector(log_sd))
diagonal_unpack <- function(x,n) list(mean=matrix(x[seq_len(2L*n)],n,2L),log_sd=matrix(x[(2L*n+1L):(4L*n)],n,2L))
two_phase <- function(par, fn, gr=NULL) {
  p1 <- nlminb(par, fn, gr, control=list(iter.max=800L, eval.max=1000L))
  p2 <- if (is.null(gr)) optim(p1$par, fn, method="BFGS", control=list(reltol=1e-12,maxit=1000L)) else optim(p1$par, fn, gr, method="BFGS", control=list(reltol=1e-12,maxit=1000L))
  list(phase1=p1, phase2=p2)
}
fixed_global <- function(fixture) {
  n <- nrow(fixture$y); beta <- fixture$beta
  lf <- d97_global_pack(beta, c(log(fixture$loading[1,1]),fixture$loading[2,1],log(fixture$loading[2,2]),as.vector(t(fixture$loading[3:5,,drop=FALSE]))))
  beta <- lf[1:5]; loading_free <- lf[6:14]
  ds <- list(mean=matrix(0,n,2L),log_sd=matrix(log(.8),n,2L)); fs <- list(mean=matrix(0,n,2L),chol=cbind(rep(log(.8),n),rep(0,n),rep(log(.8),n)))
  dfn <- function(x) { z<-diagonal_unpack(x,n); -d97_diagonal_elbo(fixture$y,beta,loading_free,z$mean,z$log_sd) }
  ffn <- function(x) { z<-local_unpack(x,n); -d97_jj_elbo(fixture$y,beta,loading_free,z$mean,z$chol) }
  dfit <- two_phase(diagonal_pack(ds$mean,ds$log_sd),dfn); ffit <- two_phase(local_pack(fs$mean,fs$chol),ffn)
  grad_d <- max(abs(d97_central_gradient(dfn,dfit$phase2$par))); grad_f <- max(abs(d97_central_gradient(ffn,ffit$phase2$par)))
  gh <- d97_gh_log_marginal(fixture$y,beta,loading_free,61L)
  rec <- function(fit,gradient,label) list(label=label, phase1_convergence=fit$phase1$convergence, phase2_convergence=fit$phase2$convergence, objective=fit$phase2$value, gradient_max=gradient, bound=-fit$phase2$value, gh_gap=gh+fit$phase2$value, healthy=is.finite(fit$phase2$value)&&is.finite(gradient)&&fit$phase1$convergence==0L&&fit$phase2$convergence==0L&&gradient<1e-4)
  list(gh_log_marginal=gh, diagonal=rec(dfit,grad_d,"diagonal"), full=rec(ffit,grad_f,"full"))
}
free_global <- function(fixture, dll) {
  n <- nrow(fixture$y); traits <- ncol(fixture$y); beta0 <- qlogis(pmin(.95,pmax(.05,colMeans(fixture$y)))); lf0 <- c(log(.40),0,log(.40),rep(0,2L*traits-4L)); global0 <- d97_global_pack(beta0,lf0)
  gh_fn <- function(x) { z<-d97_global_unpack(x,traits); -d97_gh_log_marginal(fixture$y,z$beta,z$loading_free,31L) }
  gh_fit <- two_phase(global0,gh_fn); gh_z <- d97_global_unpack(gh_fit$phase2$par,traits); gh_grad <- max(abs(d97_central_gradient(gh_fn,gh_fit$phase2$par)))
  obj <- TMB::MakeADFun(data=list(y=fixture$y),parameters=list(beta=beta0,loading_free=lf0,mean=matrix(0,n,2L),chol_free=cbind(rep(log(.8),n),rep(0,n),rep(log(.8),n))),DLL=dll,silent=TRUE)
  jj_fit <- two_phase(obj$par,obj$fn,obj$gr); jj_z <- d97_unpack(jj_fit$phase2$par,n,traits); jj_grad <- max(abs(obj$gr(jj_fit$phase2$par)))
  metric <- function(z) { L<-d97_loading_from_free(z$loading_free,traits); Sigma<-L%*%t(L); pi<-d97_marginal_probability(z$beta,z$loading_free,61L); list(beta=z$beta,loading_free=z$loading_free,covariance=Sigma,eigen=eigen(Sigma,symmetric=TRUE,only.values=TRUE)$values[1:2],marginal_probability=pi,beta_rmse=sqrt(mean((z$beta-truth$beta)^2)),covariance_max_error=max(abs(Sigma-truth$loading%*%t(truth$loading))),probability_rmse=sqrt(mean((pi-d97_marginal_probability(truth$beta,truth_loading_free,61L))^2))) }
  mk <- function(label,fit,z,gradient) { m<-metric(z); c(list(label=label,phase1_convergence=fit$phase1$convergence,phase2_convergence=fit$phase2$convergence,objective=fit$phase2$value,gradient_max=gradient),m,healthy=is.finite(fit$phase2$value)&&is.finite(gradient)&&fit$phase1$convergence==0L&&fit$phase2$convergence==0L&&gradient<1e-4&&is.finite(m$eigen[2])&&m$eigen[2]>1e-6) }
  list(gh_mle=mk("gh_mle",gh_fit,gh_z,gh_grad),full_jj=mk("full_jj",jj_fit,jj_z,jj_grad))
}
cpp <- file.path("dev","design97-fullcov-jj","src","design97_fullcov_jj.cpp"); TMB::compile(cpp,flags="-O0"); dyn.load(TMB::dynlib(sub("[.]cpp$","",cpp)))
atomic_json(file.path(out,"manifest.json"),list(design=97L,source_sha256=checksum(readBin(cpp,"raw",n=file.info(cpp)$size)),oracle_sha256=checksum(readBin("dev/design97-fullcov-jj/fullcov-jj-oracle.R","raw",n=file.info("dev/design97-fullcov-jj/fullcov-jj-oracle.R")$size)),R=R.version.string,TMB=as.character(utils::packageVersion("TMB")),platform=R.version$platform,quadrature=list(optimisation=31L,metrics=61L),started_utc=format(Sys.time(),tz="UTC",usetz=TRUE)))
fixed <- make_fixture("fixed",97002L,48L); free <- make_fixture("free",97003L,72L); atomic_json(file.path(out,"fixture-fixed.json"),fixed); atomic_json(file.path(out,"fixture-free.json"),free)
if (!fixed$precheck || !free$precheck) stop("PRECHECK_FAIL: fixture record retained; no fit attempted")
g2 <- fixed_global(fixed); atomic_json(file.path(out,"gate2-fixed.json"),g2)
g3 <- free_global(free,"design97_fullcov_jj"); atomic_json(file.path(out,"gate3-free.json"),g3)
recovery <- function(x) isTRUE(x$healthy)&&x$beta_rmse<.35&&x$covariance_max_error<.50&&x$probability_rmse<.08
E <- recovery(g3$gh_mle); J <- recovery(g3$full_jj); I <- isTRUE(g2$full$healthy)&&isTRUE(g2$diagonal$healthy)&&(g2$full$gh_gap < g2$diagonal$gh_gap-1e-6)
health <- isTRUE(g2$full$healthy)&&isTRUE(g2$diagonal$healthy)&&isTRUE(g3$gh_mle$healthy)&&isTRUE(g3$full_jj$healthy)
verdict <- if (!health) "SMOKE_STOP" else if (!E) "FIXTURE_INFORMATION_STOP" else if (!J) "JJ_GLOBAL_SIGNAL" else if (I) "MEAN_FIELD_SIGNAL" else "APPROXIMATION_ONLY"
atomic_json(file.path(out,"summary.json"),list(design=97L,verdict=verdict,health=health,recovery_flags=list(exact_mle=E,full_jj=J),fullcov_gap_improvement=I,gate2=g2,gate3=g3,completed_utc=format(Sys.time(),tz="UTC",usetz=TRUE)))
cat("Design 97 verdict:",verdict,"\n")
