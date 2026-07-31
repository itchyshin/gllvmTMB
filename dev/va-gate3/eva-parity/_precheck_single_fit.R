suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-va-in-06", quiet = TRUE))
suppressMessages(library(gllvm))

set.seed(1)
n <- 60; p <- 8; q <- 1
Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
u  <- matrix(rnorm(n * q), n, q)
b  <- rnorm(p, 0.3, 0.3)
eta <- sweep(u %*% t(Lt), 2, b, "+")
Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
colnames(Y) <- paste0("sp", seq_len(p))
Sig_true <- Lt %*% t(Lt)

lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
lg <- lg[order(lg$unit, lg$trait), ]
yv <- as.vector(t(Y))
X <- model.matrix(~ 0 + factor(lg$trait))

## verify mapping
stopifnot(length(yv) == n * p, sum(yv) == sum(Y))
Y_recon <- matrix(NA_real_, n, p)
Y_recon[cbind(lg$unit, lg$trait)] <- yv
stopifnot(isTRUE(all.equal(unname(Y_recon), matrix(as.numeric(unname(Y)), n, p))))
cat("mapping verified: sum(yv)=", sum(yv), " sum(Y)=", sum(Y), " dims match, reconstruction identical\n")

t0 <- proc.time()[["elapsed"]]
ours <- .eva_fit(y = yv, n_trials = rep(1, length(yv)), X = X,
                 unit_id = lg$unit, trait_id = lg$trait, q = q,
                 family = "binomial", link = "logit")
t_ours <- proc.time()[["elapsed"]] - t0

cat("\nours$status:", ours$status, "\n")
cat("ours$best$healthy:", ours$best$healthy, " max_abs_gradient:", ours$best$max_abs_gradient, "\n")
cat("names(ours$best$par):", paste(unique(names(ours$best$par)), collapse=","), "\n")
beta_hat_ours <- ours$best$par[names(ours$best$par) == "beta"]
cat("beta_hat_ours:", round(unname(beta_hat_ours),3), "\n")
cat("beta_true    :", round(b,3), "\n")
Lambda_ours <- ours$report$Lambda
cat("Lambda_ours dim:", dim(Lambda_ours), "\n")
cat("time ours:", t_ours, "s\n")

t0 <- proc.time()[["elapsed"]]
g <- gllvm(y = Y, family = binomial(link = "logit"), num.lv = q, method = "EVA", seed = 1)
t_g <- proc.time()[["elapsed"]] - t0
cat("\ngllvm convergence:", g$convergence, " logL:", g$logL, "\n")
cat("gllvm beta0:", round(g$params$beta0,3), "\n")
Lam_g <- as.matrix(g$params$theta) %*% diag(g$params$sigma.lv, q, q)
cat("Lam_g dim:", dim(Lam_g), "\n")
cat("time gllvm:", t_g, "s\n")

cat("\nSigma_true diag sum (trace):", sum(diag(Sig_true)), "\n")
Sh_ours <- Lambda_ours %*% t(Lambda_ours)
Sh_g <- Lam_g %*% t(Lam_g)
relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")
cat("rel_frob ours:", relfrob(Sh_ours, Sig_true), " kappa ours:", sum(diag(Sh_ours))/sum(diag(Sig_true)), "\n")
cat("rel_frob gllvm:", relfrob(Sh_g, Sig_true), " kappa gllvm:", sum(diag(Sh_g))/sum(diag(Sig_true)), "\n")

cat("\n--- per-species response sums (of", n, "trials) ---\n")
print(colSums(Y))
cat("beta_hat_ours full:\n"); print(round(unname(beta_hat_ours), 3))
cat("gllvm beta0 full:\n"); print(round(g$params$beta0, 3))
