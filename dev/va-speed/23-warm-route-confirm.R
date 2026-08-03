## Confirm the warm-started route SERIALLY: same optimum as GH-cold, fewer iterations,
## and -- the part not previously measured -- less WALL-CLOCK. Interleaved, order
## rotating, nothing else running.
## Lane directory. Env var wins so the SAME script runs on this desktop and on
## Totoro without forking a second copy that can silently drift from this one.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
N0<-100L;T0<-10L;q0<-1L;NTR<-6L;PSI<-0.6
rf <- function(A,B) sqrt(sum((A-B)^2))/sqrt(sum(B^2))
mk <- function(seed){ set.seed(seed)
  lam<-matrix(rnorm(T0*q0,0,.8),T0,q0);lam[upper.tri(lam)]<-0
  a<-matrix(rnorm(N0*q0),N0,q0);u<-matrix(rnorm(N0*T0,0,PSI),N0,T0)
  eta<-sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+")+u
  d<-data.frame(y=rbinom(N0*T0,NTR,pnorm(as.vector(eta))),
                unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  list(d=d,X=unname(model.matrix(~0+factor(d$trait,levels=1:T0))),lam=lam) }
args_for <- function(b) list(y=b$d$y,n_trials=rep(NTR,nrow(b$d)),X=b$X,
  unit_id=b$d$unit,trait_id=b$d$trait,q=q0,family="binomial_probit",
  link="probit",unique=TRUE,profile_variational=TRUE)
score <- function(par,b){ L<-gllvmTMB:::.va_r3_unpack_theta_rr(par[names(par)=="theta_rr"],T0,q0)
  list(rf=rf(L%*%t(L),b$lam%*%t(b$lam)), psi=median(exp(par[names(par)=="log_sd_tier"]))) }
## Machine load at measurement time -- verbatim from 23-speed-vs-gllvm-clean.R.
## A timing number carries no weight unless it can be shown the machine was quiet.
## PORTABLE: this script runs both on the macOS desktop and on Totoro (Linux).
## `sysctl vm.loadavg` does not exist on Linux and an unguarded [[1]] subscript
## turns a missing reading into a hard crash mid-campaign rather than an NA.
loadavg <- function() {
  if (file.exists("/proc/loadavg")) {
    v <- tryCatch(readLines("/proc/loadavg", n = 1L, warn = FALSE),
                  error = function(e) character(0))
    if (!length(v)) return(NA_real_)
    return(suppressWarnings(as.numeric(strsplit(trimws(v), " +")[[1]][1])))
  }
  s <- tryCatch(system("sysctl -n vm.loadavg", intern = TRUE, ignore.stderr = TRUE),
                error = function(e) character(0))
  if (!length(s) || is.na(s[1])) return(NA_real_)
  parts <- strsplit(trimws(gsub("[{}]", "", s[1])), " +")[[1]]
  if (length(parts) < 1L) return(NA_real_)
  suppressWarnings(as.numeric(parts[1]))
}

## ---- WARM-UP (untimed). The TMB objective is COMPILED on first use; without
## this the first timed arm would carry a C++ compile. Both routes are exercised
## because they enter the template by different paths.
cat(sprintf("== warm-up (untimed) starting %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()
wu <- mk(999L); Awu <- args_for(wu)
invisible(tryCatch(do.call(gllvmTMB:::.va_r3_fit,
  c(Awu, list(eval_method="gh", n_starts=1L, H=15L,
              control=list(eval.max=800L,iter.max=400L)))), error=function(e) NULL))
invisible(tryCatch(do.call(gllvmTMB:::.va_r3_fit_warm,
  c(Awu, list(H=15L, control=list(eval.max=800L,iter.max=400L)))), error=function(e) NULL))
cat(sprintf("== warm-up done %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()

cat(sprintf("%-5s %-8s %8s %6s %9s %9s %9s %6s\n","seed","arm","secs","iters","objective","rel_frob","psi","load"))
res <- list()
for (s in 1:3) {
  b <- mk(s); A <- args_for(b)
  ord <- if (s %% 2 == 1) c("cold","warm") else c("warm","cold")
  for (arm in ord) {
    la <- loadavg()
    t0 <- proc.time()[["elapsed"]]
    f <- if (arm=="cold") do.call(gllvmTMB:::.va_r3_fit,
              c(A, list(eval_method="gh", n_starts=1L, H=15L,
                        control=list(eval.max=800L,iter.max=400L))))
         else do.call(gllvmTMB:::.va_r3_fit_warm,
              c(A, list(H=15L, control=list(eval.max=800L,iter.max=400L))))
    secs <- proc.time()[["elapsed"]]-t0
    sc <- score(f$best$par, b)
    cat(sprintf("%-5d %-8s %8.1f %6s %9.2f %9.5f %9.4f %6.1f\n", s, arm, secs,
        paste(f$best$iterations,collapse=","), f$best$objective, sc$rf, sc$psi, la))
    flush.console()
    res[[length(res)+1]] <- data.frame(seed=s,arm=arm,secs=secs,
      obj=f$best$objective,rf=sc$rf,psi=sc$psi,load=la)
  }
}
r <- do.call(rbind,res)
cat("\n--- medians ---\n"); print(aggregate(cbind(secs,rf,psi)~arm,r,median),row.names=FALSE,digits=5)
w<-r[r$arm=="warm",]; c2<-r[r$arm=="cold",]
cat(sprintf("\nSPEEDUP (median wall-clock): %.2fx\n", median(c2$secs)/median(w$secs)))
cat(sprintf("accuracy delta (warm - cold, median): %+.5f\n", median(w$rf)-median(c2$rf)))
cat(sprintf("psi recovered? warm %.4f  cold %.4f  (truth %.1f)\n",
            median(w$psi), median(c2$psi), PSI))
## Validity condition, printed WITH the result so the two cannot be separated.
##
## NOT an absolute-load threshold. This box is an interactive desktop: Firefox,
## WindowServer, Cursor, Defender and a filesystem scanner hold baseline load at
## ~10-15 with CPU only ~50% idle even when no compute is running. A "load < 3"
## gate would fire on every run, and a check that always fires is a check nobody
## heeds. What actually invalidates a PAIRED, ORDER-ROTATED comparison is not a
## high ambient load -- both arms pay that equally -- but (a) another heavy
## compute job competing for cores, and (b) load DRIFTING between the paired
## arms, which breaks the pairing.
## Count OTHER live R binaries, excluding self BY PID. Two traps this avoids:
## the shell wrapper's command line contains the Rscript invocation text and so
## matches a bare "exec/R" grep, and counting-minus-one is off by however many
## wrappers happen to be alive. Anchor to the R binary, drop self's own pid.
other_R <- tryCatch({
  ps  <- system("ps ax -o pid=,command=", intern = TRUE)
  ## \\S* (no spaces) forces the R binary to BE the command, not merely appear
  ## inside a later argument -- the shell wrapper's own command line quotes the
  ## Rscript invocation and would otherwise match a greedy ".*" pattern.
  hit <- grep("^\\s*[0-9]+\\s+\\S*/bin/exec/R\\b", ps, value = TRUE)
  pid <- as.integer(sub("^\\s*([0-9]+).*$", "\\1", hit))
  sum(pid != Sys.getpid(), na.rm = TRUE)
}, error = function(e) NA_integer_)
spread <- diff(range(r$load, na.rm=TRUE))
cat(sprintf("\nload during timing: median %.1f, range %.1f-%.1f (spread %.1f)\n",
            median(r$load, na.rm=TRUE), min(r$load, na.rm=TRUE),
            max(r$load, na.rm=TRUE), spread))
cat(sprintf("other R processes seen at close: %s\n",
            if (is.na(other_R)) "UNKNOWN" else as.character(max(0L, other_R))))
cat(sprintf("VERDICT: %s\n",
  if (isTRUE(!is.na(other_R) && other_R > 0L))
    "VOID -- another R job was competing; do NOT quote as a speed result"
  else if (isTRUE(spread > 0.5 * median(r$load, na.rm=TRUE)))
    "WEAK -- load drifted materially across arms; treat the ratio as indicative only"
  else
    "USABLE -- paired, order-rotated, no competing R job, load stable across arms"))
cat("\nWARM_ROUTE_DONE\n")
