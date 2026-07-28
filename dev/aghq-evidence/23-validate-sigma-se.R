## VALIDATE the delta-method Sigma SE before ANY coverage campaign is run on it.
##
## The point, stated plainly: a coverage study built on an unvalidated Jacobian cannot
## distinguish "the engine's curvature is wrong" from "my derivative is wrong". So the SE
## route is checked against an INDEPENDENT estimator -- the package's own
## bootstrap_Sigma() -- before it is used to measure anything.
##
## Two checks, in increasing strength:
##   V1. INDEX MAP. Rebuilding Lambda from theta_rr_B must reproduce the template's own
##       reported Lambda_B exactly. If this fails nothing else means anything. (Also
##       asserted inside sigma_se_delta() on every call.)
##   V2. AGAINST THE BOOTSTRAP. The delta SE must agree with a bootstrap SD of the same
##       Sigma entry. These are different estimators of the same quantity, so exact
##       agreement is not expected -- but an order-of-magnitude disagreement, or a
##       systematic ratio far from 1, means the Jacobian is wrong.
##
## Run on LAPLACE fits: the delta route is about the parameterisation, not the engine, and
## Laplace is the cheaper and better-understood path to validate the arithmetic on.
LIB <- Sys.getenv("AGHQ_LIB", ""); if (nzchar(LIB)) .libPaths(c(LIB, .libPaths()))
suppressMessages(library(gllvmTMB))
source(Sys.getenv("SE_SRC", "22-sigma-se-delta.R"))

mk <- function(n,p,q,lam_sd,seed){ set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); Y<-matrix(rbinom(n*p,1,plogis(eta)),n,p)
  colnames(Y)<-paste0("sp",seq_len(p)); df<-as.data.frame(Y); df$site<-factor(seq_len(n))
  list(df=df, Lt=Lt, fml=as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y),collapse=", "), q))) }

P <- 4L; Q <- 2L; NB <- as.integer(Sys.getenv("VB_BOOT", "500"))
cat(sprintf("validating delta Sigma SE against bootstrap_Sigma (B = %d)\n\n", NB))

for (sd_ in c(3001L, 3002L, 3003L)) {
  d <- mk(400L, P, Q, 1.0, sd_)
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data=d$df, family=binomial(),
        control=gllvmTMBcontrol(n_init=1, init_jitter=0, se=TRUE))), error=function(e) e)
  if (inherits(f, "error")) { cat(sprintf("seed %d: FIT FAILED: %s\n", sd_, conditionMessage(f))); next }

  tab <- sigma_se_delta(f, P, Q)
  if (is.null(tab)) { cat(sprintf("seed %d: delta SE unavailable (%s)\n", sd_,
                        attr(tab,"reason") %||% "no sdreport / no theta_rr_B")); next }
  cat(sprintf("seed %d: V1 index map OK (guard inside sigma_se_delta passed)\n", sd_))

  bs <- tryCatch(suppressWarnings(bootstrap_Sigma(f, n_boot = NB, level = "unit",
                   what = "Sigma", seed = 99L)), error = function(e) e)
  if (inherits(bs, "error")) {
    cat(sprintf("  V2 SKIPPED -- bootstrap_Sigma errored: %s\n", substr(conditionMessage(bs),1,90)))
    print(utils::head(tab, 4)); next
  }
  ## bootstrap_Sigma() exposes PERCENTILE CI bounds, not raw draws (draws = NULL), so the
  ## comparison is CI WIDTH against CI WIDTH -- the quantity a user actually receives from
  ## each route. Two different estimators of the same interval: exact agreement is not
  ## expected, an order-of-magnitude gap means the Jacobian is wrong.
  lo_b <- bs$ci_lower[[1]]; hi_b <- bs$ci_upper[[1]]
  if (is.null(lo_b) || is.null(hi_b)) {
    cat("  V2 SKIPPED -- bootstrap returned no CI bounds\n"); print(utils::head(tab,4)); next
  }
  tabc <- sigma_ci(tab)
  tabc$w_delta <- tabc$hi - tabc$lo
  tabc$w_boot  <- mapply(function(s,t) hi_b[s,t] - lo_b[s,t], tabc$s, tabc$t)
  tabc$ratio   <- tabc$w_delta / tabc$w_boot
  cat("  V2 delta CI width vs bootstrap CI width:\n")
  pr <- tabc[, c("s","t","part","est","se","w_delta","w_boot","ratio")]
  num <- vapply(pr, is.numeric, logical(1))
  pr[num] <- lapply(pr[num], round, 4)
  print(pr, row.names = FALSE)
  cat(sprintf("  median width ratio = %.3f  (1.0 = agreement; 10x = wrong Jacobian)\n\n",
              median(tabc$ratio, na.rm = TRUE)))
}
cat("DONE\n")
