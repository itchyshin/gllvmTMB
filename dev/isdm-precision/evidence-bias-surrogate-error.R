suppressMessages(devtools::load_all(".", quiet = TRUE))
env_surface <- function(ns=26, ell=0.25, seed=1){ set.seed(seed)
  gx <- seq(0,1,length.out=ns); g <- expand.grid(lon=gx,lat=gx)
  S <- exp(-as.matrix(dist(g))/ell)
  z <- as.numeric(t(chol(S+diag(1e-6,nrow(S))))%*%rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g }
rd <- function(gr,lo,la,col) gr[[col]][max.col(-(outer(lo,gr$lon,"-")^2+outer(la,gr$lat,"-")^2))]

sim <- function(fuzz, rho, meas_err, model_access, seed, beta=0.9, gamma=1.2, ell=0.25) {
  set.seed(seed); gr <- env_surface(26, ell, seed)
  g2 <- env_surface(26, ell, seed+500L)
  ## access correlated with env at level rho
  gr$access <- as.numeric(scale(rho*gr$env + sqrt(max(1-rho^2,0))*g2$env))
  sp <- c("sp1","sp2"); alpha <- c(-0.3,0.1)
  arm <- function(n, src, fz, biased) {
    lo <- runif(n); la <- runif(n)
    et <- rd(gr,lo,la,"env"); ac <- rd(gr,lo,la,"access")
    er <- if (fz>0){ lf<-pmin(pmax(lo+rnorm(n,0,fz*ell),0),1)
                     af<-pmin(pmax(la+rnorm(n,0,fz*ell),0),1); rd(gr,lf,af,"env")} else et
    ## the analyst's SURROGATE for access, measured with error
    ac_obs <- ac + rnorm(n, 0, meas_err)
    do.call(rbind, lapply(seq_along(sp), function(j) {
      eta <- alpha[j] + beta*et + if (biased) gamma*ac else 0
      data.frame(cell_id=factor(paste0(src,"_",seq_len(n))), trait=sp[j],
                 value=rpois(n, exp(eta)), env=er, access=ac_obs, src=src) })) }
  d_po <- arm(400,"po",0,TRUE); d_sv <- arm(100,"survey",fuzz,FALSE)
  f1 <- function(dat){ dat$trait<-factor(dat$trait,levels=sp); dat$cell_id<-factor(dat$cell_id)
    acc <- if (model_access) "+access" else ""
    src <- if (length(unique(dat$src))>1){dat$src<-factor(dat$src); "+src"} else ""
    fml <- stats::as.formula(paste0("value~0+trait+trait:env",acc,src))
    f <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(fml,data=dat,trait="trait",
      unit="cell_id",family=poisson(),silent=TRUE))),error=function(e)NULL)
    if(is.null(f)||f$opt$convergence!=0) return(NA_real_)
    b<-f$opt$par[names(f$opt$par)=="b_fix"]; mean(unname(b[grep(":env$",f$X_fix_names)])) }
  c(precise=f1(d_po), integrated=f1(rbind(d_po,d_sv))) }

cond <- list(
  list(lab="independent + modelled exactly (the article)", rho=0,   err=0,   mod=TRUE),
  list(lab="confounded rho=0.7 + modelled exactly",        rho=0.7, err=0,   mod=TRUE),
  list(lab="confounded rho=0.7, surrogate sd 0.5 error",   rho=0.7, err=0.5, mod=TRUE),
  list(lab="confounded rho=0.7, NOT modelled",             rho=0.7, err=0,   mod=FALSE))
for (cc in cond) {
  M <- t(sapply(1:12, function(r) sim(1.0, cc$rho, cc$err, cc$mod, seed=7000+r)))
  helped <- sum(abs(M[,"integrated"]-0.9) < abs(M[,"precise"]-0.9), na.rm=TRUE)
  cat(sprintf("%-44s precise %.3f integ %.3f | integration HELPED %2d/12\n",
      cc$lab, mean(M[,"precise"],na.rm=TRUE), mean(M[,"integrated"],na.rm=TRUE), helped))
}
