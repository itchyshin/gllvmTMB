## Does our SHIPPED LAPLACE engine collapse psi the way the AC tier does?
## AC gave 0.0001 against a planted 0.6 at n_trials=6, where our GH tier recovered
## 0.6207. Laplace is a different approximation entirely -- it should not share AC's
## bound-tightness pathology, but that is a prediction, not a measurement.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages({ devtools::load_all(".", quiet=TRUE); library(gllvm) })
N0 <- 100L; T0 <- 10L; q0 <- 1L; PSI <- 0.6
rel_frob <- function(A,B) sqrt(sum((A-B)^2))/sqrt(sum(B^2))

build <- function(ntr, psi_sd, seed=1L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0*q0,0,.8),T0,q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0*q0),N0,q0); u <- matrix(rnorm(N0*T0,0,psi_sd),N0,T0)
  eta <- sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+") + u
  y <- rbinom(N0*T0,ntr,pnorm(as.vector(eta)))
  d <- data.frame(y=y,unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  list(d=d,ntr=ntr,lam=lam,
       Y={M<-matrix(NA_real_,N0,T0);M[cbind(d$unit,d$trait)]<-d$y;M})
}
ours_la <- function(b) {
  d2 <- b$d; d2$trait <- factor(d2$trait); d2$unit <- factor(d2$unit)
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | unit, d = 1L), data=d2,
        unit="unit", trait="trait", family=stats::binomial(link="probit"),
        weights=rep(b$ntr,nrow(d2)), control=gllvmTMB::gllvmTMBcontrol()))),
       error=function(e) structure(list(m=conditionMessage(e)),class="err"))
  s <- proc.time()[["elapsed"]]-t0
  if (inherits(f,"err")) return(list(secs=s,psi=NA_real_,rf=NA_real_,note=substr(f$m,1,40)))
  SL <- tryCatch(gllvmTMB::extract_Sigma(f,level="unit",part="shared",
          link_residual="none")$Sigma, error=function(e) NULL)
  SU <- tryCatch(gllvmTMB::extract_Sigma(f,level="unit",part="unique",
          link_residual="none")$Sigma, error=function(e) NULL)
  list(secs=s, psi=if(is.null(SU)) NA_real_ else sqrt(median(diag(SU))),
       rf=if(is.null(SL)) NA_real_ else rel_frob(SL,b$lam%*%t(b$lam)), note="ok")
}
cat("planted psi SD =", PSI, "  (N=100, T=10, binomial-probit)\n\n")
cat(sprintf("%-9s %-30s %-22s\n","n_trials","ours-LA (secs / psi / rel_frob)","gllvm-LA (secs / rel_frob)"))
for (ntr in c(1L,6L,20L)) {
  b <- build(ntr, PSI)
  L <- ours_la(b)
  t0 <- proc.time()[["elapsed"]]
  g <- tryCatch(gllvm::gllvm(y=b$Y,family=binomial(link="probit"),num.lv=q0,
        method="LA",Ntrials=ntr,seed=1L,trace=FALSE),
       error=function(e) structure(list(m=conditionMessage(e)),class="err"))
  gs <- proc.time()[["elapsed"]]-t0
  grf <- if (inherits(g,"err")) NA_real_ else {
    th <- as.matrix(g$params$theta); sg <- tryCatch(g$params$sigma.lv,error=function(e) NULL)
    Lg <- if(!is.null(sg)) sweep(th,2L,sg,"*") else th; rel_frob(Lg%*%t(Lg), b$lam%*%t(b$lam)) }
  cat(sprintf("%-9d %7.1fs / %7s / %-8s     %7.1fs / %s\n", ntr, L$secs,
      ifelse(is.na(L$psi),"NA",sprintf("%.4f",L$psi)),
      ifelse(is.na(L$rf),"NA",sprintf("%.4f",L$rf)), gs,
      ifelse(is.na(grf),"NA",sprintf("%.4f",grf)))); flush.console()
}
