source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
o  <- readRDS("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/p1.rds")
cl <- o$cell; Y <- cl$Y; n <- cl$n; p <- cl$p; q <- cl$q

log1pexp <- function(x) ifelse(x > 33, x + log1p(exp(-x)), log1p(exp(x)))
bpp_f    <- function(x) { e <- exp(-abs(x)); e / (1 + e)^2 }   # stable s(x)(1-s(x))

parts <- function(Lam, beta0, M, A) {
  eta <- sweep(M %*% t(Lam), 2, beta0, "+")
  V   <- t(apply(A, 1, function(Ai) diag(Lam %*% Ai %*% t(Lam))))
  ent <- sum(apply(A, 1, function(Ai) 0.5*determinant(Ai, logarithm=TRUE)$modulus -
                                      0.5*sum(diag(Ai)))) - 0.5*sum(M^2) + n*q/2
  list(eta=eta, V=V, ent=as.numeric(ent))
}
eva_obj <- function(Lam,b0,M,A){ z<-parts(Lam,b0,M,A)
  sum(Y*z$eta - log1pexp(z$eta) - 0.5*bpp_f(z$eta)*z$V) + z$ent }
va_obj  <- function(Lam,b0,M,A){ z<-parts(Lam,b0,M,A)
  xi <- sqrt(z$eta^2 + z$V); lam <- (plogis(xi)-0.5)/(2*xi)
  sum((Y-0.5)*z$eta + plogis(xi,log.p=TRUE) - 0.5*xi - lam*(z$eta^2 + z$V - xi^2)) + z$ent }
## penalty magnitude: the ONLY term in EVA that punishes a large latent variance
eva_pen <- function(Lam,b0,M,A){ z<-parts(Lam,b0,M,A); sum(0.5*bpp_f(z$eta)*z$V) }
eva_dat <- function(Lam,b0,M,A){ z<-parts(Lam,b0,M,A); sum(Y*z$eta - log1pexp(z$eta)) }

cat("== VALIDATION of my reconstructions against gllvm's own reported logL ==\n")
for (nm in c("VA","EVA")) {
  f <- o[[nm]]; L <- gllvm::getLoadings(f); M <- as.matrix(f$lvs)
  cat(sprintf("%-4s fit: gllvm logL=%12.5f | my VA(JJ)=%12.5f | my EVA=%12.5f\n",
      nm, f$logL, va_obj(L,f$params$beta0,M,f$A), eva_obj(L,f$params$beta0,M,f$A)))
}
f <- o$EVA; L <- gllvm::getLoadings(f); M <- as.matrix(f$lvs); A <- f$A; b0 <- f$params$beta0

cat("\n== A: EVA objective along a scaling ray THROUGH THE FITTED EVA SOLUTION ==\n")
cat("   (loadings and intercepts x s; variational M, A held at the fitted values)\n")
cat("      s        EVA obj      EVA data term   EVA variance penalty     VA(JJ) obj   attenuation\n")
for (s in c(1e-4,1e-3,1e-2,0.1,0.3,1,3,10,100)) {
  Ls <- L*s; bs <- b0*s
  cat(sprintf("%9.4g %14.4f %16.4f %20.6g %16.2f %12.4g\n", s,
      eva_obj(Ls,bs,M,A), eva_dat(Ls,bs,M,A), eva_pen(Ls,bs,M,A),
      va_obj(Ls,bs,M,A), att(Ls%*%t(Ls), cl$Sig_true)))
}

cat("\n== B: EVA objective along a scaling ray THROUGH THE TRUTH ==\n")
cat("   (Lam = true Lt x s, beta0 = true b x s, M = true u, A = fitted-EVA A)\n")
cat("      s        EVA obj      EVA data term   EVA variance penalty     VA(JJ) obj   attenuation\n")
for (s in c(0.25,0.5,1,2,4,8,20,60,200,1000)) {
  Ls <- cl$Lt*s; bs <- cl$b*s
  cat(sprintf("%9.4g %14.4f %16.4f %20.6g %16.2f %12.4g\n", s,
      eva_obj(Ls,bs,cl$u,A), eva_dat(Ls,bs,cl$u,A), eva_pen(Ls,bs,cl$u,A),
      va_obj(Ls,bs,cl$u,A), att(Ls%*%t(Ls), cl$Sig_true)))
}

cat("\n== C: is the EVA optimum genuinely BETTER (higher objective) than the truth? ==\n")
Ltru <- cl$Lt; btru <- cl$b
cat(sprintf("EVA objective at gllvm's runaway EVA solution : %14.4f\n", eva_obj(L,b0,M,A)))
cat(sprintf("EVA objective at the TRUE parameters (M=u)    : %14.4f\n", eva_obj(Ltru,btru,cl$u,A)))
fv <- o$VA; Lv <- gllvm::getLoadings(fv)
cat(sprintf("EVA objective at the VA solution             : %14.4f\n",
            eva_obj(Lv,fv$params$beta0,as.matrix(fv$lvs),fv$A)))
cat(sprintf("VA(JJ)  at gllvm's runaway EVA solution      : %14.2f\n", va_obj(L,b0,M,A)))
cat(sprintf("VA(JJ)  at the VA solution                   : %14.4f\n",
            va_obj(Lv,fv$params$beta0,as.matrix(fv$lvs),fv$A)))
cat(sprintf("VA(JJ)  at the TRUE parameters (M=u)         : %14.4f\n", va_obj(Ltru,btru,cl$u,A)))
