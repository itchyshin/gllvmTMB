suppressMessages(library(gllvm))
set.seed(1)
n <- 30; p <- 6; q <- 1
Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
u  <- matrix(rnorm(n * q), n, q)
b  <- rnorm(p, 0.3, 0.3)
eta <- sweep(u %*% t(Lt), 2, b, "+")
Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
colnames(Y) <- paste0("sp", seq_len(p))

cat("=== fit A: method=EVA, family=binomial, link default (probit) ===\n")
fitA <- tryCatch(gllvm(y = Y, family = binomial(), num.lv = q, method = "EVA", seed = 1),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(fitA)) cat("fitA class ok, logL =", fitA$logL, "\n")

cat("\n=== fit B: method=EVA, family=binomial, link='logit' explicit ===\n")
fitB <- tryCatch(gllvm(y = Y, family = binomial(), num.lv = q, method = "EVA", link = "logit", seed = 1),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(fitB)) cat("fitB class ok, logL =", fitB$logL, "\n")

cat("\n=== fit C: method=EVA, family=binomial(link='logit') passed via family object ===\n")
fitC <- tryCatch(gllvm(y = Y, family = binomial(link = "logit"), num.lv = q, method = "EVA", seed = 1),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(fitC)) cat("fitC class ok, logL =", fitC$logL, "\n")

cat("\n=== fit D: method=VA (not EVA), family=binomial, link='logit' explicit (for reference) ===\n")
fitD <- tryCatch(gllvm(y = Y, family = binomial(), num.lv = q, method = "VA", link = "logit", seed = 1),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(fitD)) cat("fitD class ok, logL =", fitD$logL, "\n")

## Inspect whether the fitted objects actually differ (are A and B/C identical -> link ignored?)
if (!is.null(fitA) && !is.null(fitB)) {
  cat("\nidentical logL A vs B:", identical(fitA$logL, fitB$logL), "\n")
  cat("max abs diff coef (beta0) A vs B:", max(abs(fitA$params$beta0 - fitB$params$beta0)), "\n")
}
if (!is.null(fitA) && !is.null(fitC)) {
  cat("identical logL A vs C:", identical(fitA$logL, fitC$logL), "\n")
}

## What does the fitted object record as its link / family?
cat("\n=== fitA$family ===\n"); print(fitA$family)
if (!is.null(fitA$call)) { cat("\n=== fitA$call ===\n"); print(fitA$call) }

cat("\n\n=== supplementary: does method=VA respect the link= argument at all? ===\n")
fitE <- tryCatch(gllvm(y = Y, family = binomial(), num.lv = q, method = "VA", seed = 1),
                  error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
if (!is.null(fitE)) cat("fitE (VA, link default/probit) logL =", fitE$logL, "\n")
cat("fitD (VA, link=logit) logL =", fitD$logL, "\n")
cat("identical logL fitE vs fitD:", identical(fitE$logL, fitD$logL), "\n")
