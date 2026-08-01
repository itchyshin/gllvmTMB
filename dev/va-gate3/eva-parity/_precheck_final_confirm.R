suppressMessages(library(gllvm))
set.seed(1)
n <- 30; p <- 6; q <- 1
Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
u  <- matrix(rnorm(n * q), n, q)
b  <- rnorm(p, 0.3, 0.3)
eta <- sweep(u %*% t(Lt), 2, b, "+")
Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
colnames(Y) <- paste0("sp", seq_len(p))

## With num.lv=1 (genuine latent-variable EVA, matching our use case) -- does
## family = binomial(link = "logit") vs family = binomial(link = "probit")
## now produce genuinely DIFFERENT fits under method = "EVA"?
fit_logit  <- gllvm(y = Y, family = binomial(link = "logit"),  num.lv = q, method = "EVA", seed = 1)
fit_probit <- gllvm(y = Y, family = binomial(link = "probit"), num.lv = q, method = "EVA", seed = 1)

cat("logL logit-EVA :", fit_logit$logL,  " link recorded:", fit_logit$link[1], "\n")
cat("logL probit-EVA:", fit_probit$logL, " link recorded:", fit_probit$link[1], "\n")
cat("identical logL:", identical(fit_logit$logL, fit_probit$logL), "\n")
cat("max abs diff beta0:", max(abs(fit_logit$params$beta0 - fit_probit$params$beta0)), "\n")
cat("beta0 logit :", round(fit_logit$params$beta0, 3), "\n")
cat("beta0 probit:", round(fit_probit$params$beta0, 3), "\n")
cat("ratio (logit/probit) per species:", round(fit_logit$params$beta0 / fit_probit$params$beta0, 3), "\n")
