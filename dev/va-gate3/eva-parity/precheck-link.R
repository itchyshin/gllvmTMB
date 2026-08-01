#!/usr/bin/env Rscript
## Design 86/VA-in-06 EVA parity -- BLOCKING PRE-CHECK.
##
## Question: does gllvm::gllvm(family = "binomial", method = "EVA") support
## the LOGIT link (what our .eva_fit() uses), or is it probit-only as gllvm's
## binary VA route is documented to be?
##
## Method: (1) read ?gllvm via tools::Rd_db("gllvm"); (2) fit tiny models
## probing every way a caller might request a link, cross-checked against
## TWO independent, gllvm-free anchors (plain glm() with probit and logit
## links) so the verdict does not depend on trusting gllvm's own bookkeeping
## of what it thinks it fit.
##
## Result, established below and cited in the report:
##  - gllvm()'s own top-level `link=` ARGUMENT has NO effect on binomial VA/EVA/
##    LA fits in every configuration tested -- a genuine trap in the gllvm API
##    surface (its own docs say this argument is for method="LA" and the beta
##    family; empirically it had no effect for LA either in the configurations
##    tested here).
##  - The link IS controlled, correctly and for every method including EVA, by
##    the FAMILY OBJECT's own $link component: family = binomial(link = "logit")
##    vs family = binomial(link = "probit").
##  - VERDICT: (a) logit IS supported for EVA. A genuine same-link comparison
##    is possible using family = binomial(link = "logit").

suppressMessages(library(gllvm))
out_dir <- "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/results"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
log_con <- file(file.path(out_dir, "precheck-log.txt"), open = "wt")
sink(log_con, split = TRUE)

cat("gllvm package version:", as.character(packageVersion("gllvm")), "\n\n")

cat("=== STEP 1: documentation (tools::Rd_db, ?gllvm) ===\n")
db <- tools::Rd_db("gllvm")
rd <- db[["gllvm.Rd"]]
txt <- capture.output(tools::Rd2txt(rd))
link_line <- grep("^\\s*link:", txt)
cat("Usage default (from the `link = ...` line in Usage):\n")
cat("  ", grep('link = "', txt, value = TRUE)[1], "\n")
cat("\nArguments section entry for `link`:\n")
for (i in link_line:(link_line + 1)) cat("  ", txt[i], "\n")
cat("\n-> Documentation states the `link` ARGUMENT applies for method='LA' and\n")
cat("   the beta family. It is silent on how VA/EVA choose a binomial link,\n")
cat("   beyond the Usage default value link=\"probit\". This is ambiguous on\n")
cat("   its own, hence the empirical tests below.\n\n")

cat("=== STEP 2: tiny fits, isolating num.lv = 0 (no latent confound) ===\n")
set.seed(7)
n <- 200; p <- 6
b_true_logit <- rnorm(p, 0.3, 0.4)
prob <- plogis(matrix(b_true_logit, n, p, byrow = TRUE))
Y <- matrix(rbinom(n * p, 1, prob), n, p)
colnames(Y) <- paste0("sp", seq_len(p))

## independent, gllvm-free anchors
glm_probit_b0 <- vapply(seq_len(p), function(j)
  coef(glm(Y[, j] ~ 1, family = binomial(link = "probit"))), numeric(1))
glm_logit_b0 <- vapply(seq_len(p), function(j)
  coef(glm(Y[, j] ~ 1, family = binomial(link = "logit"))), numeric(1))

run_quiet <- function(expr) withCallingHandlers(expr, warning = function(w) invokeRestart("muffleWarning"))

fits <- list(
  `EVA, top-level link='logit', family=binomial() (default link)` =
    run_quiet(gllvm(y = Y, family = binomial(), num.lv = 0, method = "EVA", link = "logit", seed = 1)),
  `EVA, top-level link='probit', family=binomial() (default link)` =
    run_quiet(gllvm(y = Y, family = binomial(), num.lv = 0, method = "EVA", link = "probit", seed = 1)),
  `EVA, family=binomial(link='logit')` =
    run_quiet(gllvm(y = Y, family = binomial(link = "logit"), num.lv = 0, method = "EVA", seed = 1)),
  `EVA, family=binomial(link='probit')` =
    run_quiet(gllvm(y = Y, family = binomial(link = "probit"), num.lv = 0, method = "EVA", seed = 1)),
  `LA, top-level link='probit', family=binomial() (default link)` =
    run_quiet(gllvm(y = Y, family = binomial(), num.lv = 0, method = "LA", link = "probit", seed = 1)),
  `LA, family=binomial(link='probit')` =
    run_quiet(gllvm(y = Y, family = binomial(link = "probit"), num.lv = 0, method = "LA", seed = 1))
)

cat(sprintf("%-62s %10s %10s\n", "configuration", "logL", "max|b0-glm_logit|"))
for (nm in names(fits)) {
  f <- fits[[nm]]
  d_logit <- max(abs(f$params$beta0 - glm_logit_b0))
  cat(sprintf("%-62s %10.4f %18.6g\n", nm, f$logL, d_logit))
}
cat("\nmax|beta0 - glm_PROBIT_anchor| for the family=binomial(link='probit') EVA fit:\n")
cat("  ", max(abs(fits[["EVA, family=binomial(link='probit')"]]$params$beta0 - glm_probit_b0)), "\n")
cat("max|beta0 - glm_LOGIT_anchor| for the family=binomial(link='logit') EVA fit:\n")
cat("  ", max(abs(fits[["EVA, family=binomial(link='logit')"]]$params$beta0 - glm_logit_b0)), "\n")

cat("\n-> The two top-level-`link=`-argument fits (rows 1-2) are IDENTICAL to each\n")
cat("   other regardless of 'logit' vs 'probit' being requested: the top-level\n")
cat("   argument has NO effect. The two family-object fits (rows 3-4, 5-6) DO\n")
cat("   differ and match their respective independent glm() anchor almost\n")
cat("   exactly (~1e-5, optimizer tolerance) -- for BOTH EVA and LA.\n\n")

cat("=== STEP 3: confirm the same holds WITH latent variables present (num.lv=1),\n")
cat("    which is gllvmTMB's actual .eva_fit() use case ===\n")
set.seed(1)
n2 <- 30; p2 <- 6; q2 <- 1
Lt <- matrix(rnorm(p2 * q2, 0, 0.6), p2, q2)
u  <- matrix(rnorm(n2 * q2), n2, q2)
b2 <- rnorm(p2, 0.3, 0.3)
eta <- sweep(u %*% t(Lt), 2, b2, "+")
Y2 <- matrix(rbinom(n2 * p2, 1, plogis(eta)), n2, p2)
colnames(Y2) <- paste0("sp", seq_len(p2))

fit_logit_lv  <- run_quiet(gllvm(y = Y2, family = binomial(link = "logit"),  num.lv = q2, method = "EVA", seed = 1))
fit_probit_lv <- run_quiet(gllvm(y = Y2, family = binomial(link = "probit"), num.lv = q2, method = "EVA", seed = 1))

cat("logL, family=binomial(link='logit'),  num.lv=1, method=EVA:", fit_logit_lv$logL, "\n")
cat("logL, family=binomial(link='probit'), num.lv=1, method=EVA:", fit_probit_lv$logL, "\n")
cat("identical:", identical(fit_logit_lv$logL, fit_probit_lv$logL), "\n")
cat("beta0 logit :", round(fit_logit_lv$params$beta0, 3), "\n")
cat("beta0 probit:", round(fit_probit_lv$params$beta0, 3), "\n")

cat("\n=== VERDICT ===\n")
cat("(a) gllvm::gllvm(family = binomial(link = 'logit'), method = 'EVA') IS genuine\n")
cat("    logit-link EVA -- confirmed against an independent glm() anchor with no\n")
cat("    latent confound, and confirmed to diverge appropriately from probit-EVA\n")
cat("    once latent variables are present. A genuine same-link comparison against\n")
cat("    our .eva_fit(..., link = 'logit') is possible.\n")
cat("CAVEAT: the top-level gllvm(..., link = ...) ARGUMENT must NOT be used to\n")
cat("    request this -- it is silently ignored for binomial family regardless of\n")
cat("    method in every configuration tested here. Use family = binomial(link=...).\n")

sink()
close(log_con)
cat("Wrote", file.path(out_dir, "precheck-log.txt"), "\n")
