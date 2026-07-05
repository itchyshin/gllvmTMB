## Recovery study: is a non-Gaussian trait's between-unit Psi identifiable?
## Confound-free: explicit indep() diagonal (pure Psi, no low-rank Lambda rotation;
## explicit -> NOT gated by auto_psi_B), clean per-trait extraction via extract_Sigma.
options(crayon.enabled = FALSE); suppressMessages(pkgload::load_all(".", quiet = TRUE))
one <- function(seed, sd_d, n_unit = 100L, n_rep = 8L) {
  set.seed(seed)
  b_g <- stats::rnorm(n_unit, sd = 0.6); b_d <- stats::rnorm(n_unit, sd = sd_d)
  grid <- expand.grid(unit = factor(seq_len(n_unit)), rep = seq_len(n_rep))
  mk <- function(tr){ d<-grid; d$trait<-tr; ii<-as.integer(d$unit)
    if(tr=="g") d$value<-0.2+b_g[ii]+stats::rnorm(nrow(d),sd=0.4) else d$value<-stats::rbinom(nrow(d),1,stats::plogis(0.3+b_d[ii])); d }
  df<-rbind(mk("g"),mk("x")); df$trait<-factor(df$trait,levels=c("g","x")); df$family<-factor(ifelse(df$trait=="g","g","x"),levels=c("g","x"))
  fl<-list(gaussian(),binomial()); attr(fl,"family_var")<-"family"
  f<-tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit), data=df, trait="trait", unit="unit", family=fl))), error=function(e) NULL)
  if(is.null(f)) return(c(pd=NA, psi_g=NA, psi_x=NA))
  S <- tryCatch(suppressMessages(gllvmTMB::extract_Sigma(f, level="unit", part="unique")$s), error=function(e) c(NA,NA))
  c(pd=as.numeric(isTRUE(f$sdr$pdHess)), psi_g=as.numeric(S)[1], psi_x=as.numeric(S)[2])
}
cat("Confound-free recovery (explicit indep diagonal; binomial trait = x; true gaussian Psi=0.36):\n")
for (sd_d in c(0.0, 0.7, 1.2)) {
  r <- sapply(c(11,23,37), function(s) one(s, sd_d))
  cat(sprintf("  true binomial Psi=%.2f: pdHess=%s | recovered Psi_x=%s | (gaussian Psi_g=%s)\n",
    sd_d^2, paste(r["pd",],collapse=","), paste(round(r["psi_x",],2),collapse=","), paste(round(r["psi_g",],2),collapse=",")))
}
cat("VERDICT: Psi_x tracks true (0->~0, 1.44->~1.4) & pdHess=TRUE => IDENTIFIABLE (fix estimation, do NOT zero).\n")
cat("         Psi_x stuck / pdHess=FALSE regardless of true => UNIDENTIFIED (zero-it fix correct).\n")
