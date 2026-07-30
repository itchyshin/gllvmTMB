## Scale-equivariance oracle for issue #851.
##
## For a gaussian LVM, multiplying the response by k has KNOWN consequences for
## every reported quantity. That makes a complete, assumption-free acceptance
## test: fit the same data at scale 1 and scale k and check each law.
##
##   Lambda      -> k * Lambda          (loadings carry the response scale)
##   fixed eff.  -> k * beta
##   Sigma       -> k^2 * Sigma
##   correlations   invariant
##   communality    invariant
##   logLik      -> logLik - n * log(k) (Jacobian of the density transform)
##
## MEASURED ON origin/main, 2026-07-30 (n_sites = 150, p = 4, q = 1, seed 7):
##   k = 100  : every law holds to ~1e-4.
##   k = 5000 : EVERY law violated -- Lambda rel.err 1, Sigma rel.err 1,
##              fixed effects 9.5% out, logLik 49 units out, and CORRELATIONS
##              and COMMUNALITY rel.err 1.
##
## That last pair is the point worth carrying. Correlations and communality are
## scale-INVARIANT estimands, so it is tempting to assume they are protected. A
## ratio computed from a degenerate fit is garbage regardless of its invariance:
## the damage is upstream, in the optimisation, not in the transform. #851 is
## therefore not "the loadings collapse" -- it is "every reported quantity,
## including the headline JSDM outputs, becomes wrong above a scale threshold,
## with convergence = 0 and a positive-definite Hessian throughout".
##
## Use this as the acceptance criterion for any fix. A fix is done when both
## blocks pass, not when ||Lambda||/k looks stable.
##
## Run: Rscript dev/scale-equivariance-check.R

suppressMessages(devtools::load_all(quiet = TRUE))
set.seed(7); ntr <- 4L
base <- gllvmTMB::simulate_site_trait(n_sites=150L,n_species=3L,n_traits=ntr,mean_species_per_site=2L,
  Lambda_B=matrix(c(0.9,0.6,-0.5,0.4),ntr,1L), psi_B=rep(0.3,ntr), psi_W=rep(0.3,ntr),
  beta=matrix(0,ntr,2L), seed=7L)
fml <- value ~ 0 + trait + latent(0 + trait | site, d = 1) + unique(0 + trait | site_species)
fitk <- function(k) {
  d <- base$data; d$value <- d$value*k
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(fml,data=d,family=gaussian(),
    silent=TRUE, control=gllvmTMBcontrol(se=FALSE))))
}
chk <- function(name, a, b, k, power, tol=0.02) {
  a<-as.numeric(a); b<-as.numeric(b)
  if (!length(a)||!length(b)||anyNA(a)||anyNA(b)) { cat(sprintf("  %-26s SKIP\n",name)); return(invisible()) }
  pred <- a * k^power
  rel <- max(abs(b-pred)/pmax(abs(pred),1e-8))
  cat(sprintf("  %-26s %-14s rel.err %10.3g   %s\n", name,
      sprintf("y -> k^%g", power), rel, if (rel<tol) "OK" else "*** VIOLATED ***"))
}
for (k in c(100, 5000)) {
  cat(sprintf("\n===== SCALE-EQUIVARIANCE at k = %g (baseline: origin/main) =====\n", k))
  f1 <- fitk(1); fk <- fitk(k)
  chk("Lambda_B",     f1$report$Lambda_B,  fk$report$Lambda_B,  k, 1)
  chk("fixed effects", f1$opt$par[names(f1$opt$par)=="b_fix"], fk$opt$par[names(fk$opt$par)=="b_fix"], k, 1)
  s1 <- try(gllvmTMB::extract_Sigma(f1, level="unit")$Sigma, silent=TRUE)
  sk <- try(gllvmTMB::extract_Sigma(fk, level="unit")$Sigma, silent=TRUE)
  if (!inherits(s1,"try-error")) chk("Sigma_unit", s1, sk, k, 2)
  r1 <- try(gllvmTMB::extract_Sigma(f1, level="unit")$R, silent=TRUE)
  rk <- try(gllvmTMB::extract_Sigma(fk, level="unit")$R, silent=TRUE)
  if (!inherits(r1,"try-error")) chk("correlations (invariant)", r1, rk, k, 0)
  c1 <- try(gllvmTMB::extract_communality(f1, level="unit"), silent=TRUE)
  ck <- try(gllvmTMB::extract_communality(fk, level="unit"), silent=TRUE)
  if (!inherits(c1,"try-error")) chk("communality (invariant)", unlist(c1[sapply(c1,is.numeric)]), unlist(ck[sapply(ck,is.numeric)]), k, 0)
  n_obs <- nrow(base$data)
  cat(sprintf("  %-26s %-14s logLik(1)=%.3f  logLik(k)=%.3f  expected=%.3f  %s\n",
      "logLik", "- n log k", -f1$opt$objective, -fk$opt$objective,
      -f1$opt$objective - n_obs*log(k),
      if (abs((-fk$opt$objective) - (-f1$opt$objective - n_obs*log(k))) < 0.02*abs(f1$opt$objective)) "OK" else "*** VIOLATED ***"))
}
