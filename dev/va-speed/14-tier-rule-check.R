## Is the CONDITIONAL rule (D-28) actually implemented in the VA engine?
##  W-tier (observation residual): unique estimated ONLY for gaussian and OD-Poisson;
##      every other family gets it from the link.
##  B-tier (between-unit): unique estimated for ALL families -- the link supplies only
##      the observation-level residual, never a higher-level variance.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

mk <- function(fam, link, uniq) {
  set.seed(1); N<-40L; T0<-4L; q<-1L; ntr<-6L
  d <- data.frame(unit=rep(1:N,times=T0), trait=rep(1:T0,each=N))
  d$y <- switch(fam,
    gaussian_anchor = rnorm(N*T0),
    poisson         = rpois(N*T0, 3),
    binomial        = rbinom(N*T0, ntr, 0.5),
    binomial_probit = rbinom(N*T0, ntr, 0.5))
  X <- unname(model.matrix(~0+factor(d$trait, levels=1:T0)))
  v <- gllvmTMB:::.va_r3_validate_data(y=d$y, n_trials=rep(ntr,nrow(d)), X=X,
        unit_id=d$unit, trait_id=d$trait, q=q, family=fam, link=link, unique=uniq)
  o <- gllvmTMB:::.va_r3_make_objective(v, H=15L, eval_method="gh")
  tb <- table(names(o$par))
  g <- function(k) if (is.na(tb[k])) 0L else as.integer(tb[k])
  cat(sprintf("  %-16s unique=%-5s | log_sigma(W-tier) %d | log_sd_tier(B-tier psi) %2d | tiers %d\n",
              fam, uniq, g("log_sigma"), g("log_sd_tier"), v$tier_layout$n_tiers))
}
cat("=== W-tier: is `unique` estimated only where the link does NOT supply it? ===\n")
cat("    (log_sigma is the observation-level residual SD)\n")
mk("gaussian_anchor","identity",TRUE)
mk("poisson",        "log",     TRUE)
mk("binomial",       "logit",   TRUE)
mk("binomial_probit","probit",  TRUE)
cat("\n=== B-tier: is psi carried for ALL families when requested? ===\n")
cat("    (log_sd_tier is the between-unit diagonal psi; must be family-agnostic)\n")
mk("gaussian_anchor","identity",FALSE)
mk("binomial_probit","probit",  FALSE)
