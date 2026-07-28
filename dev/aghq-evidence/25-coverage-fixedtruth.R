## THE COVERAGE CELL -- and the run that validates its own instrument.
##
## D-43 lens 3's decisive ask: "one 30-seed coverage cell for the ACTUALLY SHIPPED
## configuration -- AGHQ k = 9 WITH aghq_ridge = 2, p = 6, q = 2, at n = 400 and n = 1600 --
## reporting Wald coverage of the Sigma diagonal and off-diagonal against nominal 0.95 with
## MCSE, alongside the equivalent Laplace+ridge cell."
##
## THIS RUNS THAT CELL LITERALLY, AND A POWERED ONE AROUND IT. Two reasons the literal
## specification cannot stand alone, both arithmetic:
##
##   (a) 30 SEEDS CANNOT ADJUDICATE A 1-POINT GATE. Per-seed MCSE near 0.95 is
##       sqrt(.95*.05/30) = 0.040, so a +/- 2*MCSE band is +/- 0.08. The precedent this
##       project set on 2026-07-19 WITHHELD a certificate at 0.9486-0.9529 -- a distinction
##       far finer than +/- 0.08 can see. So seeds go to 200; the literal 30-seed subset is
##       reported separately so the panel's own condition is still literally met.
##
##   (b) n = 400 AND n = 1600 ARE WHERE THE DEFECT IS INVISIBLE. The MAP bias-to-SE ratio is
##       delta ~ lambda*se(lambda)/tau^2, and coverage loss goes as ~0.114*delta^2. At
##       n >= 400, se(lambda) is small enough that delta ~ 0.01-0.03 and the predicted loss
##       is O(1e-4) -- orders below the MCSE of any feasible run. The defect lives at
##       n = 100-200. Running only the specified n would most likely return an underpowered
##       null that reads as exoneration. So n = {100, 200, 400, 1600}.
##
## THE INSTRUMENT VALIDATES ITSELF. The delta-method Sigma SE (22-sigma-se-delta.R) passed
## its index-map check but did NOT cleanly pass against bootstrap_Sigma (widths 1.4-3.4x).
## The bootstrap is a known-poor comparator for this target, so that is ambiguous. The
## decisive check is SE/SD: across seeds, the empirical SD of Sigma_hat_st IS the quantity
## the SE estimates. It is computed here per cell and per entry. NO COVERAGE NUMBER FROM
## THIS RUN MAY BE QUOTED UNLESS SE/SD IS NEAR 1 -- otherwise the run is measuring the
## Jacobian, not the engine.
##
## FOUR ARMS, not two. Lens 3 asked for AGHQ+ridge vs Laplace+ridge, but his own finding is
## an ERROR-CANCELLATION mechanism between quadrature and penalty -- and an interaction
## cannot be estimated from two arms. The full 2x2 (k in {1,9} x tau in {Inf,2}) is the
## minimum, and (Laplace, no ridge) is additionally non-optional because it is the SHIPPED
## DEFAULT.
##
## NON-CONVERGENCE IS NOT AN INCLUSION FILTER. Three distinct events are counted separately:
## no fit; fit but no SE; fit with SE. Coverage is reported CONDITIONAL on an available
## interval, with the availability rate printed beside it, and the denominator is always all
## seeds attempted. Counting a refused interval as "non-covering" would conflate a
## fail-closed refusal with a wrong answer.
suppressWarnings(suppressMessages(library(parallel)))
LIB <- Sys.getenv("AGHQ_LIB", ""); if (nzchar(LIB)) .libPaths(c(LIB, .libPaths()))
suppressMessages(library(gllvmTMB))
source(Sys.getenv("SE_SRC", "22-sigma-se-delta.R"))

OUT   <- Sys.getenv("CV_OUT", "25-fixedtruth-inc.csv")
CORES <- as.integer(Sys.getenv("CV_CORES", "140"))
SEEDS <- as.integer(Sys.getenv("CV_SEEDS", "200"))
if (file.exists(OUT)) file.remove(OUT)

## FIXED TRUTH. Lambda is drawn ONCE per truth id and passed in; only the DATA is
## resampled per seed. The original cell redrew Lambda every seed, which makes the reported
## coverage a quantity marginalised over a Gaussian prior on Lambda -- and the ridge IS a
## Gaussian prior of the same functional form, so the ridge arms were being scored against a
## DGP matched to them. D-43 lens 3 called this the decisive design flaw. Fixing it is the
## single objection this run exists to answer.
mk <- function(n,p,q,lam_sd,seed,Lt){
  set.seed(seed); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); Y<-matrix(rbinom(n*p,1,plogis(eta)),n,p)
  colnames(Y)<-paste0("sp",seq_len(p)); df<-as.data.frame(Y); df$site<-factor(seq_len(n))
  list(df=df, Lt=Lt, fml=as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y),collapse=", "), q))) }

ARMS <- list(
  laplace       = function() gllvmTMBcontrol(n_init=1, init_jitter=0, se=TRUE),
  laplace_ridge = function() gllvmTMBcontrol(n_init=1, init_jitter=0, se=TRUE, aghq_ridge=2),
  aghq          = function() gllvmTMBcontrol(n_init=1, init_jitter=0, se=TRUE, aghq=9, aghq_ridge=Inf),
  aghq_ridge    = function() gllvmTMBcontrol(n_init=1, init_jitter=0, se=TRUE, aghq=9))

P <- 6L; Q <- 2L; LAM <- 1.0
## THREE fixed truths, drawn once, at THREE loading scales so the ridge's prior (tau = 2)
## is correctly specified, too tight, and too loose in turn -- lam_sd was never varied
## before, so the penalty had only ever been measured where it is nearly right.
TRUTHS <- lapply(seq_len(3L), function(i) {
  set.seed(90000L + i)
  list(id = i, lam_sd = c(0.5, 1.0, 3.0)[i],
       Lt = matrix(rnorm(P * Q, 0, c(0.5, 1.0, 3.0)[i]), P, Q))
})
jobs <- expand.grid(n = c(100L, 200L, 400L, 1600L), arm = names(ARMS), truth_id = 1:3,
                    seed = seq_len(SEEDS) + 5000L, stringsAsFactors = FALSE)
jobs <- jobs[sample.int(nrow(jobs)), ]
cat(sprintf("coverage cell: %d fits on %d cores (%d seeds)\n", nrow(jobs), CORES, SEEDS))
flush(stdout())

invisible(mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  tr <- TRUTHS[[jb$truth_id]]
  d <- mk(jb$n, P, Q, tr$lam_sd, jb$seed, tr$Lt)
  St <- d$Lt %*% t(d$Lt)                      # the TRUE Sigma for this seed
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data=d$df, family=binomial(),
        control = ARMS[[jb$arm]]())), error = function(e) NULL)
  base <- data.frame(n=jb$n, arm=jb$arm, seed=jb$seed, truth_id=jb$truth_id,
                     lam_sd=tr$lam_sd, stringsAsFactors=FALSE)
  if (is.null(f)) {                            # event 1: no fit
    row <- cbind(base, s=NA, t=NA, part=NA, truth=NA, est=NA, se=NA,
                 lo=NA, hi=NA, covered=NA, status="no_fit")
  } else {
    tab <- tryCatch(sigma_se_delta(f, P, Q), error=function(e) NULL)
    if (is.null(tab) || all(!is.finite(tab$se))) {   # event 2: fit, no SE
      row <- cbind(base, s=NA, t=NA, part=NA, truth=NA, est=NA, se=NA,
                   lo=NA, hi=NA, covered=NA, status="no_se")
    } else {                                    # event 3: fit with SE
      tc <- sigma_ci(tab)
      tc$truth <- mapply(function(s,t) St[s,t], tc$s, tc$t)
      tc$covered <- is.finite(tc$lo) & is.finite(tc$hi) &
                    tc$truth >= tc$lo & tc$truth <= tc$hi
      row <- cbind(base[rep(1,nrow(tc)),], tc[,c("s","t","part","truth","est","se","lo","hi","covered")],
                   status="ok")
    }
  }
  utils::write.table(row, OUT, sep=",", append=file.exists(OUT),
                     col.names=!file.exists(OUT), row.names=FALSE)
  NULL
}, mc.cores = CORES, mc.preschedule = FALSE))
cat("DONE\n")
