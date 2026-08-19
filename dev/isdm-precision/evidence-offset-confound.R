suppressMessages(devtools::load_all(".", quiet = TRUE))
sp <- c("A","B","C"); TRUE_B <- c(0.9,-0.4,0.5)
run <- function(vary_within, seed=5) {
  set.seed(seed); n_po<-200; n_sv<-120
  ev_po <- rnorm(n_po); ev_sv <- rnorm(n_sv)
  ## effort: constant within arm (the article's setup) vs varying within arm
  if (vary_within) { e_po <- exp(rnorm(n_po,0,0.6)); e_sv <- exp(rnorm(n_sv,0,0.6)) }
  else             { e_po <- rep(3.0,n_po);          e_sv <- rep(1.0,n_sv) }
  mk <- function(ev,ef,src,a0) do.call(rbind, lapply(seq_along(sp), function(j)
    data.frame(site=paste0(src,"_",seq_along(ev)), env=ev, eff=ef,
      log_eff=log(ef), src=src, trait=sp[j],
      value=rpois(length(ev), ef*exp(a0[j]+TRUE_B[j]*ev)))))
  d <- rbind(mk(ev_po,e_po,"po",c(0.6,0.4,0.5)), mk(ev_sv,e_sv,"survey",c(0.6,0.4,0.5)))
  d$trait<-factor(d$trait,levels=sp); d$src<-factor(d$src); d$site<-factor(d$site)
  cat(sprintf("\n--- effort %s within arm ---\n",
      if (vary_within) "VARIES" else "CONSTANT"))
  cat(sprintf("cor(log_eff, src==po) = %+.4f\n",
      cor(d$log_eff, as.numeric(d$src=="po"))))
  W <- NULL
  f <- withCallingHandlers(
    try(suppressMessages(gllvmTMB(value ~ 0+trait+trait:env+src+offset(log_eff),
        data=d, trait="trait", unit="site", family=poisson(), silent=TRUE)),
        silent=TRUE),
    warning=function(w){ W <<- c(W, conditionMessage(w)); invokeRestart("muffleWarning") })
  if (inherits(f,"try-error")) { cat("ERROR\n"); return(invisible()) }
  b <- f$opt$par[names(f$opt$par)=="b_fix"]
  e <- unname(b[grep(":env$", f$X_fix_names)])
  cat(sprintf("conv %s | obj %.3f | slopes %.3f %.3f %.3f | mean|err| %.4f\n",
      f$opt$convergence, f$opt$objective, e[1],e[2],e[3], mean(abs(e-TRUE_B))))
  cat("warnings raised:", if (is.null(W)) "NONE" else paste(W, collapse=" | "), "\n")
}
run(FALSE); run(TRUE)

cat("\n=== Does the source intercept absorb a constant-within-arm offset? ===\n")
set.seed(5); n_po<-200; n_sv<-120
ev_po<-rnorm(n_po); ev_sv<-rnorm(n_sv); e_po<-rep(3.0,n_po); e_sv<-rep(1.0,n_sv)
mk <- function(ev,ef,src,a0) do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(site=paste0(src,"_",seq_along(ev)), env=ev, log_eff=log(ef), src=src,
    trait=sp[j], value=rpois(length(ev), ef*exp(a0[j]+TRUE_B[j]*ev)))))
d <- rbind(mk(ev_po,e_po,"po",c(0.6,0.4,0.5)), mk(ev_sv,e_sv,"survey",c(0.6,0.4,0.5)))
d$trait<-factor(d$trait,levels=sp); d$src<-factor(d$src); d$site<-factor(d$site)
g <- function(fml) { f <- suppressWarnings(suppressMessages(gllvmTMB(fml,data=d,
  trait="trait",unit="site",family=poisson(),silent=TRUE)))
  b<-f$opt$par[names(f$opt$par)=="b_fix"]; e<-unname(b[grep(":env$",f$X_fix_names)])
  cat(sprintf("  obj %.4f | slopes %.4f %.4f %.4f\n", f$opt$objective,e[1],e[2],e[3])) }
cat("with offset + src :\n"); g(value ~ 0+trait+trait:env+src+offset(log_eff))
cat("src only, NO offset:\n"); g(value ~ 0+trait+trait:env+src)
cat("offset only, NO src:\n"); g(value ~ 0+trait+trait:env+offset(log_eff))
