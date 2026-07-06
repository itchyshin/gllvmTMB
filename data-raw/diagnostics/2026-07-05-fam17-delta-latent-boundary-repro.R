## FAM-17 delta-lognormal latent boundary reproduction — WITH the REAL sdreport.
## Question: the register's FAM-17 caveat says a latent delta-lognormal cell landed
## on a boundary (convergence = 1, pdHess = TRUE). Is that a REAL identifiability
## failure, or a benign optimizer-termination-code artifact?
## Discipline (systematic-debugging + the pdHess-phantom lesson):
##   * gaussian control FIRST — prove the harness reads a REAL pdHess (must be TRUE);
##   * read fit$sd_report$pdHess  (NOT the nonexistent fit$sdr$pdHess phantom);
##   * report convergence code + REAL pdHess + max|gradient| at the optimum;
##   * benign signature  = conv!=0 BUT pdHess=TRUE AND max|grad|~0 AND estimates recover;
##   * real-boundary sig = pdHess=FALSE (real) OR large max|grad|.
options(crayon.enabled = FALSE)
suppressMessages(pkgload::load_all(".", quiet = TRUE))

probe <- function(label, fit, extra = NULL) {
  if (is.null(fit)) { cat(sprintf("[%-20s] FIT FAILED / errored\n", label)); return(invisible(NULL)) }
  conv    <- fit$opt$convergence
  msg     <- fit$opt$message %||% NA
  has_sdr <- !is.null(fit$sd_report)
  pd      <- if (has_sdr) isTRUE(fit$sd_report$pdHess) else NA
  grad    <- tryCatch(max(abs(fit$tmb_obj$gr(fit$opt$par))), error = function(e) NA_real_)
  cat(sprintf("[%-20s] conv=%s | REAL pdHess=%s | max|grad|=%.3g | sd_report=%s | msg=%s\n",
              label, conv, pd, grad, if (has_sdr) "present" else "NULL", msg))
  if (!is.null(extra)) extra(fit)
  invisible(fit)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

## ---------- (0) Gaussian control: latent(0+trait|unit, d=1) must be PD ----------
set.seed(101)
n_u <- 120L; n_r <- 6L; Tn <- 3L
b   <- stats::rnorm(n_u, sd = 1)
lam <- c(1.0, 0.8, 0.6); mu <- c(0.5, 1.0, 1.5)
gg  <- expand.grid(unit = factor(seq_len(n_u)), rep = seq_len(n_r))
dfg <- do.call(rbind, Map(function(tr, t) {
  d <- gg; d$trait <- tr; ii <- as.integer(d$unit)
  d$value <- mu[t] + lam[t] * b[ii] + stats::rnorm(nrow(d), sd = 0.5); d
}, letters[1:Tn], 1:Tn))
dfg$trait <- factor(dfg$trait, levels = letters[1:Tn])
fit_g <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 1),
  data = dfg, trait = "trait", unit = "unit", family = gaussian()))),
  error = function(e) { cat("gaussian control ERROR:", conditionMessage(e), "\n"); NULL })
probe("gaussian latent d1", fit_g)

## ---------- delta-lognormal DGP (from test-delta-lognormal-recovery.R) ----------
set.seed(2025)
n_ind <- 800L; Td <- 3L; mu_d <- c(1.0, 1.5, 2.0); sig_d <- 0.7
y <- matrix(NA_real_, n_ind, Td)
for (t in seq_len(Td)) {
  eta <- mu_d[t]; p <- 1 / (1 + exp(-eta))
  y[, t] <- stats::rbinom(n_ind, 1, p) * stats::rlnorm(n_ind, eta, sig_d)
}
dfd <- data.frame(
  individual = factor(rep(seq_len(n_ind), each = Td)),
  trait = factor(rep(letters[1:Td], n_ind), levels = letters[1:Td]),
  value = as.vector(t(y)))

## ---------- (a) delta fixed-effect (the COVERED recovery cell) ----------
fit_d0 <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  value ~ 0 + trait, data = dfd, unit = "individual",
  family = gllvmTMB::delta_lognormal()))),
  error = function(e) { cat("delta fixed ERROR:", conditionMessage(e), "\n"); NULL })
probe("delta fixed-effect", fit_d0, extra = function(f) {
  bfix <- tryCatch(summary(f$sd_report, "fixed"), error = function(e) NULL)
  if (!is.null(bfix)) { bf <- bfix[grepl("^b_fix$", rownames(bfix)), "Estimate"]
    cat(sprintf("     recovered b_fix = %s (truth %s)\n",
                paste(round(bf, 2), collapse = ","), paste(mu_d, collapse = ","))) }
})

## ---------- (b) delta LATENT d=1 (the FAM-17 boundary cell) ----------
fit_d1 <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | individual, d = 1),
  data = dfd, trait = "trait", unit = "individual",
  family = gllvmTMB::delta_lognormal()))),
  error = function(e) { cat("delta latent ERROR:", conditionMessage(e), "\n"); NULL })
probe("delta latent d1", fit_d1, extra = function(f) {
  bfix <- tryCatch(summary(f$sd_report, "fixed"), error = function(e) NULL)
  if (!is.null(bfix)) { bf <- bfix[grepl("^b_fix$", rownames(bfix)), "Estimate"]
    cat(sprintf("     recovered b_fix = %s (truth %s)\n",
                paste(round(bf, 2), collapse = ","), paste(mu_d, collapse = ","))) }
  sig <- tryCatch(as.numeric(f$report$sigma_lognormal_delta), error = function(e) NA)
  cat(sprintf("     sigma_lognormal = %s (truth %.2f)\n", paste(round(sig, 2), collapse = ","), sig_d))
})

cat("\nVERDICT KEY: gaussian control MUST show pdHess=TRUE (harness sane).\n")
cat("  delta latent  pdHess=TRUE + max|grad|~0 + b_fix recovered => BENIGN conv-code artifact.\n")
cat("  delta latent  pdHess=FALSE (real) or large max|grad|       => REAL boundary (then localise Lambda vs Psi).\n")
