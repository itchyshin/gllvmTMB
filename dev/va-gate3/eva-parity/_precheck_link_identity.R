suppressMessages(library(gllvm))
set.seed(7)
n <- 200; p <- 6
## no latent structure -- pure per-species intercept, so num.lv=0 isolates the link
b_true_logit <- rnorm(p, 0.3, 0.4)
prob <- plogis(matrix(b_true_logit, n, p, byrow = TRUE))
Y <- matrix(rbinom(n * p, 1, prob), n, p)
colnames(Y) <- paste0("sp", seq_len(p))

fit_eva  <- gllvm(y = Y, family = binomial(), num.lv = 0, method = "EVA", seed = 1)
fit_la_probit <- gllvm(y = Y, family = binomial(), num.lv = 0, method = "LA", link = "probit", seed = 1)
fit_la_logit  <- gllvm(y = Y, family = binomial(), num.lv = 0, method = "LA", link = "logit",  seed = 1)

## independent anchor: plain glm per species column, both links, no gllvm involved at all
glm_probit_b0 <- vapply(seq_len(p), function(j) coef(glm(Y[, j] ~ 1, family = binomial(link = "probit"))), numeric(1))
glm_logit_b0  <- vapply(seq_len(p), function(j) coef(glm(Y[, j] ~ 1, family = binomial(link = "logit"))),  numeric(1))

cat("true beta (logit-generating):\n"); print(round(b_true_logit, 3))
cat("\nfit_eva$params$beta0:\n"); print(round(fit_eva$params$beta0, 3))
cat("fit_la_probit$params$beta0:\n"); print(round(fit_la_probit$params$beta0, 3))
cat("fit_la_logit$params$beta0:\n"); print(round(fit_la_logit$params$beta0, 3))
cat("\nglm_probit_b0 (independent anchor):\n"); print(round(glm_probit_b0, 3))
cat("glm_logit_b0 (independent anchor):\n"); print(round(glm_logit_b0, 3))

cat("\nmax abs diff: EVA vs glm_probit:", max(abs(fit_eva$params$beta0 - glm_probit_b0)), "\n")
cat("max abs diff: EVA vs glm_logit :", max(abs(fit_eva$params$beta0 - glm_logit_b0)), "\n")
cat("max abs diff: EVA vs LA_probit :", max(abs(fit_eva$params$beta0 - fit_la_probit$params$beta0)), "\n")
cat("max abs diff: EVA vs LA_logit  :", max(abs(fit_eva$params$beta0 - fit_la_logit$params$beta0)), "\n")
cat("\nlogL eva:", fit_eva$logL, " LA_probit:", fit_la_probit$logL, " LA_logit:", fit_la_logit$logL, "\n")
