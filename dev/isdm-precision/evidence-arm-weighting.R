suppressMessages(devtools::load_all(".", quiet = TRUE))
env_surface <- function(n_side, ell=0.25, seed=1){ set.seed(seed)
  gx <- seq(0,1,length.out=n_side); g <- expand.grid(lon=gx,lat=gx)
  S <- exp(-as.matrix(dist(g))/ell)
  z <- as.numeric(t(chol(S+diag(1e-6,nrow(S))))%*%rnorm(nrow(g)))
  g$env <- as.numeric(scale(z)); g }
read_env <- function(gr,lo,la) gr$env[max.col(-(outer(lo,gr$lon,"-")^2+outer(la,gr$lat,"-")^2))]

sim_once <- function(fuzz, n_po, n_srv, beta=0.9, ell=0.25, seed=1) {
  set.seed(seed); gr <- env_surface(26, ell, seed)
  sp <- c("sp1","sp2"); alpha <- c(-0.3,0.1)
  mk <- function(n, envfun, src) {
    lo <- runif(n); la <- runif(n); et <- read_env(gr,lo,la)
    er <- envfun(lo,la,et)
    do.call(rbind, lapply(seq_along(sp), function(j) data.frame(
      cell_id=factor(paste0(src,"_",seq_len(n))), trait=sp[j],
      value=rpois(n, exp(alpha[j]+beta*et)), env=er, src=src)))
  }
  d_po  <- mk(n_po,  function(lo,la,et) et, "po")
  d_srv <- mk(n_srv, function(lo,la,et) {
      lf <- pmin(pmax(lo+rnorm(length(lo),0,fuzz*ell),0),1)
      af <- pmin(pmax(la+rnorm(length(la),0,fuzz*ell),0),1)
      read_env(gr,lf,af) }, "survey")
  fit1 <- function(dat){ dat$trait <- factor(dat$trait,levels=sp)
    dat$cell_id <- factor(dat$cell_id)
    rhs <- if(length(unique(dat$src))>1){dat$src<-factor(dat$src)
      value~0+trait+trait:env+src} else value~0+trait+trait:env
    f <- tryCatch(suppressWarnings(suppressMessages(gllvmTMB(rhs,data=dat,
      trait="trait",unit="cell_id",family=poisson(),silent=TRUE))),error=function(e)NULL)
    if(is.null(f)||f$opt$convergence!=0) return(NA_real_)
    b <- f$opt$par[names(f$opt$par)=="b_fix"]
    mean(unname(b[grep(":env$",f$X_fix_names)])) }
  c(precise=fit1(d_po), fuzzed=fit1(d_srv), integrated=fit1(rbind(d_po,d_srv)))
}
BETA <- 0.9
for (design in list(c(220,220), c(400,100), c(100,400))) {
  cat(sprintf("\n=== PO n=%d (precise) , SURVEY n=%d (fuzzed) ===\n", design[1], design[2]))
  for (f in c(0, 0.5, 1.0)) {
    M <- t(sapply(1:15, function(r) sim_once(f, design[1], design[2], seed=2000+r)))
    d_int_pre <- M[,"integrated"] - M[,"precise"]
    mid <- (M[,"precise"]+M[,"fuzzed"])/2
    cat(sprintf("fuzz %.2f | precise %.3f fuzzed %.3f integ %.3f | integ-precise %+.3f (%d/%d<0) | |integ-midpoint| %.4f\n",
      f, mean(M[,"precise"],na.rm=TRUE), mean(M[,"fuzzed"],na.rm=TRUE),
      mean(M[,"integrated"],na.rm=TRUE), mean(d_int_pre,na.rm=TRUE),
      sum(d_int_pre<0,na.rm=TRUE), sum(!is.na(d_int_pre)),
      mean(abs(M[,"integrated"]-mid),na.rm=TRUE)))
  }
}
