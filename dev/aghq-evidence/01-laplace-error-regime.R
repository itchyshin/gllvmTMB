## Where is Laplace ACTUALLY wrong? Literature (Pinheiro & Chao 2006; Joe 2008): the
## error is O(1/n_i) in observations PER CLUSTER -- here traits per site T -- and grows
## with the latent signal. So: FEW traits, STRONG loadings. That is the regime AGHQ is
## for, and the regime the earlier tests never entered.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet=TRUE))
source("dev/aghq-r-reference.R")
sp <- function(x) pmax(x,0)+log1p(exp(-abs(x)))

probe <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt <- matrix(rnorm(p*q,0,lam_sd),p,q); u <- matrix(rnorm(n*q),n,q); b <- rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); Y<-matrix(rbinom(n*p,1,plogis(eta)),n,p)
  colnames(Y)<-paste0("sp",1:p); df<-as.data.frame(Y); df$site<-factor(1:n)
  fml<-as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = 1, unique = FALSE)",
                          paste(colnames(Y),collapse=", ")))
  oracle <- function(bv,Lv){tot<-0; for(i in 1:n){
    f<-function(z) sapply(z,function(zz){e<-bv+Lv*zz; exp(sum(Y[i,]*e-sp(e)))})
    tot<-tot+log(integrate(function(z) f(z)*dnorm(z),-Inf,Inf,rel.tol=1e-12)$value)}; -tot}
  la <- suppressWarnings(gllvmTMB(fml,data=df,family=binomial()))
  bh <- as.vector(la$opt$par[names(la$opt$par)=="b_fix"])
  Lh <- as.vector(la$report$Lambda_B[1:p,1,drop=TRUE])
  o_at_la <- oracle(bh,Lh)
  cat(sprintf("\n--- T=%d traits/site, n=%d, lambda_sd=%.1f, seed=%d ---\n", p,n,lam_sd,seed))
  cat(sprintf("  LAPLACE objective %.6f   vs oracle at same par %.6f   LAPLACE ERROR %+.4f nll\n",
              la$opt$objective, o_at_la, la$opt$objective - o_at_la))
  for (k in c(9L,25L)) {
    g <- suppressWarnings(try(gllvmTMB(fml,data=df,family=binomial(),
          control=gllvmTMBcontrol(aghq=k, aghq_n_adapt=80L)), silent=TRUE))
    if (inherits(g,"try-error")) {cat(sprintf("  AGHQ k=%-2d ERROR\n",k)); next}
    bg<-as.vector(g$opt$par[names(g$opt$par)=="b_fix"])
    Lg<-as.vector(g$report$Lambda_B[1:p,1,drop=TRUE])
    cat(sprintf("  AGHQ k=%-2d objective %.6f   vs oracle at ITS par %.6f   AGHQ ERROR %+.2e nll\n",
                k, g$opt$objective, oracle(bg,Lg), g$opt$objective - oracle(bg,Lg)))
    cat(sprintf("            |Lambda| est %.4f  true %.4f  |  Laplace est %.4f\n",
                sqrt(sum(Lg^2)), sqrt(sum(Lt^2)), sqrt(sum(Lh^2))))
  }
}
probe(80, 2, 1, 1.5, 101)   # T=2: the regime Laplace is worst in
probe(80, 3, 1, 2.0, 102)   # T=3, strong signal
