suppressMessages(library(gllvm))
set.seed(7)
n <- 200; p <- 6
b_true_logit <- rnorm(p, 0.3, 0.4)
prob <- plogis(matrix(b_true_logit, n, p, byrow = TRUE))
Y <- matrix(rbinom(n * p, 1, prob), n, p)
colnames(Y) <- paste0("sp", seq_len(p))

## Critical test: does family = binomial(link = "probit") (the FAMILY OBJECT's own link,
## not the separate top-level link= argument) actually change the EVA computation?
fit_eva_famprobit <- gllvm(y = Y, family = binomial(link = "probit"), num.lv = 0, method = "EVA", seed = 1)
fit_eva_famlogit  <- gllvm(y = Y, family = binomial(link = "logit"),  num.lv = 0, method = "EVA", seed = 1)
fit_eva_default   <- gllvm(y = Y, family = binomial(),                num.lv = 0, method = "EVA", seed = 1)

fit_la_famprobit <- gllvm(y = Y, family = binomial(link = "probit"), num.lv = 0, method = "LA", seed = 1)
fit_la_famlogit  <- gllvm(y = Y, family = binomial(link = "logit"),  num.lv = 0, method = "LA", seed = 1)

glm_probit_b0 <- vapply(seq_len(p), function(j) coef(glm(Y[, j] ~ 1, family = binomial(link = "probit"))), numeric(1))
glm_logit_b0  <- vapply(seq_len(p), function(j) coef(glm(Y[, j] ~ 1, family = binomial(link = "logit"))),  numeric(1))

cat("EVA, family=binomial(link='probit'):\n"); print(round(fit_eva_famprobit$params$beta0, 4))
cat("EVA, family=binomial(link='logit') :\n"); print(round(fit_eva_famlogit$params$beta0, 4))
cat("EVA, family=binomial() default     :\n"); print(round(fit_eva_default$params$beta0, 4))
cat("\nLA,  family=binomial(link='probit'):\n"); print(round(fit_la_famprobit$params$beta0, 4))
cat("LA,  family=binomial(link='logit') :\n"); print(round(fit_la_famlogit$params$beta0, 4))
cat("\nglm probit anchor:\n"); print(round(glm_probit_b0, 4))
cat("glm logit anchor:\n"); print(round(glm_logit_b0, 4))

cat("\n--- diffs vs glm_probit anchor ---\n")
cat("EVA famprobit vs glm_probit:", max(abs(fit_eva_famprobit$params$beta0 - glm_probit_b0)), "\n")
cat("LA  famprobit vs glm_probit:", max(abs(fit_la_famprobit$params$beta0  - glm_probit_b0)), "\n")
cat("--- diffs vs glm_logit anchor ---\n")
cat("EVA famlogit  vs glm_logit :", max(abs(fit_eva_famlogit$params$beta0  - glm_logit_b0)), "\n")
cat("LA  famlogit  vs glm_logit :", max(abs(fit_la_famlogit$params$beta0   - glm_logit_b0)), "\n")

cat("\nfit_eva_famprobit$link:", fit_eva_famprobit$link[1], "\n")
cat("fit_eva_famlogit$link:", fit_eva_famlogit$link[1], "\n")
cat("fit_eva_famprobit$logL:", fit_eva_famprobit$logL, " fit_eva_famlogit$logL:", fit_eva_famlogit$logL, "\n")
