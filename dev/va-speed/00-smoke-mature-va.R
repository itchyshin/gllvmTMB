## Smoke test for the mature-VA build worktree. Proves the environment works
## BEFORE any implementation lands: load_all, VA-R3 DLL compile, one tiny
## binomial-probit fit through the GH tier we are about to add a sibling to.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
cat("load_all OK\n")

## Registry: confirm binomial_probit is code 4 and currently GH-only.
e <- gllvmTMB:::.va_r3_family_entry(4L)
cat("family:", e$family, "| link:", e$link,
    "| tiers:", paste(e$tiers, collapse = ","),
    "| default:", e$default_tier,
    "| expectation:", e$expectation, "\n")

## The eval_method code is currently a BOOLEAN collapse -- this is the thing
## Item 1 must widen. Record its present behaviour so the change is visible.
fam4 <- 4L  # binomial_probit
cat("eval_method_code(auto, probit) =",
    gllvmTMB:::.va_r3_eval_method_code("auto", fam4), "\n")
cat("resolve(auto, probit) =",
    gllvmTMB:::.va_r3_resolve_eval_method("auto", fam4), "\n")
cat("jj refused for probit:",
    inherits(try(gllvmTMB:::.va_r3_resolve_eval_method("jj", fam4),
                 silent = TRUE), "try-error"), "\n")

## Tiny probit fit: N=60, T=4, q=1. Small enough to be fast, big enough to
## exercise the GH path and the DLL compile.
set.seed(1)
N <- 60L; T0 <- 4L; q <- 1L; ntr <- 6L
lam <- matrix(rnorm(T0 * q, 0, 0.8), T0, q); lam[upper.tri(lam)] <- 0
a   <- matrix(rnorm(N * q), N, q)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y   <- rbinom(N * T0, ntr, pnorm(as.vector(eta)))
d   <- data.frame(y = y,
                  unit  = rep(seq_len(N), times = T0),
                  trait = rep(seq_len(T0), each  = N))
X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))

t0 <- proc.time()[["elapsed"]]
fit <- gllvmTMB:::.va_r3_fit(
  y = d$y, n_trials = rep(ntr, nrow(d)), X = X,
  unit_id = d$unit, trait_id = d$trait, q = q,
  family = "binomial_probit", link = "probit", unique = TRUE,
  n_starts = 1L, H = 15L,
  control = list(eval.max = 200L, iter.max = 100L))
secs <- round(proc.time()[["elapsed"]] - t0, 1)

cat("fit returned:", !is.null(fit), "| secs:", secs,
    "| status:", as.character(fit$status), "\n")
cat("objective:", format(fit$best$objective, digits = 10), "\n")
cat("finite objective:", is.finite(fit$best$objective), "\n")

## The AD-safety property the new tier must also satisfy: he() finite, not just gr().
obj <- attr(fit, "va_r3_objective")
if (!is.null(obj)) {
  g <- try(obj$gr(fit$best$par), silent = TRUE)
  h <- try(obj$he(fit$best$par), silent = TRUE)
  cat("gr finite:", if (inherits(g, "try-error")) NA else all(is.finite(g)),
      "| he finite:", if (inherits(h, "try-error")) NA else all(is.finite(h)), "\n")
} else cat("objective attr not attached to fit (check separately in S5)\n")

cat("SMOKE_OK\n")
