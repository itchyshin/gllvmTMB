## WHICH gllvm SCALING CONVENTION IS CORRECT? — the arbiter.
##
## Two claims are in direct conflict in this repo:
##   (A) dev/bound-vs-estimates.md pitfall #1 (and ~10 dev scripts):
##       "theta carries a fixed identifiability constraint ... the fitted
##        linear-predictor loading is theta %*% diag(sigma.lv)"     -> SCALED
##   (B) docs/dev-log/handover/2026-08-05-claude-handover.md:
##       "gllvm's raw theta IS Lambda (its lvs already have sd ~ 0.9)" -> RAW
##       and it RETRACTED "gllvm shares the bias" on that basis.
##
## If (A) is right, gllvm's trace is ~0.508 and gllvm SHARES our attenuation,
## and the handover's retraction was itself an error. This matters enormously:
## the entire "our VA is uniquely biased, gllvm is not" premise depends on it.
##
## Decisive evidence sought, in order of strength:
##   1. Is theta's diagonal pinned at exactly 1? A pinned diagonal CANNOT carry scale.
##   2. Does Lambda %*% t(z) reproduce gllvm's OWN linear predictor (g$lp.link /
##      predict(g)) — a convention-free check against gllvm's own arithmetic?
##   3. Does the implied Sigma match the planted Sigma?

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source("dev/va-usability/attenuation-lib.R")
T0 <<- 20L
b  <- sim_cell(20262251L, "binomial_probit", 150L)
Y  <- matrix(b$d$y, nrow = 150L, ncol = T0, byrow = TRUE)
X  <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
g  <- gllvm::gllvm(y = Y, X = X, formula = ~ x, family = binomial(link = "probit"),
                   num.lv = 2, method = "VA", trace = FALSE)

th <- as.matrix(g$params$theta)
sg <- as.numeric(g$params$sigma.lv)
U  <- as.matrix(g$lvs)
scaled <- sweep(th, 2L, sg, "*")

cat("======== 1. IS theta's DIAGONAL PINNED? ========\n")
print(round(th[1:3, , drop = FALSE], 6))
cat(sprintf("theta[1,1]=%.15g  theta[2,2]=%.15g  theta[1,2]=%.15g\n", th[1,1], th[2,2], th[1,2]))
cat(sprintf("diagonal pinned at exactly 1: %s\n", all(abs(diag(th[1:2, 1:2]) - 1) < 1e-12)))
cat(sprintf("sigma.lv = %s\n", paste(round(sg, 6), collapse = ", ")))
cat(sprintf("sd(lvs)  = %s\n", paste(round(apply(U, 2, sd), 4), collapse = ", ")))
cat("\nREAD: a loading matrix whose diagonal is FIXED at 1 cannot represent the\n")
cat("      loading magnitude. If the diagonal is pinned, the scale MUST live in\n")
cat("      sigma.lv, and Lambda = theta %*% diag(sigma.lv).\n")

cat("\n======== 2. AGAINST gllvm'S OWN LINEAR PREDICTOR ========\n")
cat("names(g) containing lp/eta/fitted/linear/pred:\n  ")
cat(paste(grep("lp|eta|fitted|linear|pred", names(g), value = TRUE, ignore.case = TRUE),
          collapse = ", "), "\n")
## The LV contribution to eta is whatever remains after the fixed part.
## gllvm stores the fixed part as params$beta0 (col intercepts) and params$Xcoef.
b0 <- as.numeric(g$params$beta0)
xc <- tryCatch(as.matrix(g$params$Xcoef), error = function(e) NULL)
fixed_part <- matrix(b0, nrow = 150L, ncol = T0, byrow = TRUE)
if (!is.null(xc)) fixed_part <- fixed_part + outer(X$x, as.numeric(xc[, 1]))
eta_hat <- tryCatch(as.matrix(g$lp.link), error = function(e) NULL)
if (is.null(eta_hat)) eta_hat <- tryCatch(predict(g, type = "link"), error = function(e) NULL)
if (!is.null(eta_hat)) {
  if (!identical(dim(eta_hat), dim(fixed_part))) eta_hat <- t(eta_hat)
  lv_resid <- eta_hat - fixed_part
  for (nm in c("raw", "scaled")) {
    L <- if (nm == "raw") th else scaled
    pred <- U %*% t(L)
    cat(sprintf("  %-7s : max|eta_lv - U L'| = %.3e   corr = %.6f\n",
                nm, max(abs(lv_resid - pred)), stats::cor(as.numeric(lv_resid), as.numeric(pred))))
  }
  cat("  (the convention whose max abs difference is ~0 is gllvm's OWN arithmetic)\n")
} else {
  cat("  NOT AVAILABLE: gllvm exposes no linear predictor here. Falling back to 1 and 3.\n")
}

cat("\n======== 3. IMPLIED Sigma vs PLANTED ========\n")
cat(sprintf("  raw     trace ratio = %.4f   eta_var = %.4f\n",
            sum(rowSums(th^2)) / sum(b$sigma_jj_true),
            var(as.numeric(U %*% t(th))) / var(as.numeric(b$z_true %*% t(b$Lambda_true)))))
cat(sprintf("  scaled  trace ratio = %.4f   eta_var = %.4f\n",
            sum(rowSums(scaled^2)) / sum(b$sigma_jj_true),
            var(as.numeric(U %*% t(scaled))) / var(as.numeric(b$z_true %*% t(b$Lambda_true)))))
cat("  (target for both is 1; but note trace is NOT convention-free while\n")
cat("   the linear-predictor check in section 2 IS.)\n")
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
