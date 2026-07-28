## THE FAMILY AXIS — the last unmeasured half of the (T, M, family) routing map.
##
## Run in an ISOLATED worktree (detached at 1d6a82af) because a concurrent lane is
## editing R/ in the shared one. src/ was verified unmodified there, so the compiled
## .so is this checkout's own build.
##
## THE POSITIVE CONTROL IS THE POINT. Laplace is EXACT for a gaussian latent-linear
## model, so AGHQ's lever there must measure ~ZERO. If it does not, the harness is
## wrong and no other row means anything. That check runs first and is reported first.
##
## "Lever" = |sigma_ratio - 1| under Laplace MINUS the same under AGHQ+ridge.
## Positive = AGHQ+ridge is closer to unbiased. Reported per family, medians over seeds.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-family-axis", quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))
OUT <- "/private/tmp/gllvmtmb-family-axis/dev/aghq-evidence/19-family-inc.csv"
if (file.exists(OUT)) file.remove(OUT)

## Per-family simulator from a linear predictor, respecting each support.
SPEC <- list(
  gaussian = list(fam = function() gaussian(),
                  sim = function(eta) rnorm(length(eta), eta, 0.5)),
  poisson  = list(fam = function() poisson(),
                  sim = function(eta) rpois(length(eta), exp(pmin(eta, 5)))),
  binomial = list(fam = function() binomial(),
                  sim = function(eta) rbinom(length(eta), 1, plogis(eta))),
  nbinom2  = list(fam = function() nbinom2(),
                  sim = function(eta) rnbinom(length(eta), mu = exp(pmin(eta, 5)), size = 3)),
  Gamma    = list(fam = function() Gamma(),
                  sim = function(eta) rgamma(length(eta), shape = 3, rate = 3 / exp(pmin(eta, 5))))
)

mk <- function(famname, n, p, q, seed) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, 0.8), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(SPEC[[famname]]$sim(as.vector(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt)
}

P <- 6L; Q <- 2L; N <- 200L
jobs <- expand.grid(fam = names(SPEC), seed = 3001:3010, arm = c("laplace", "aghq_ridge"),
                    stringsAsFactors = FALSE)
cat(sprintf("family axis: %d fits\n", nrow(jobs))); flush(stdout())

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d  <- mk(jb$fam, N, P, Q, jb$seed)
  St <- d$Lt %*% t(d$Lt); sg_t <- sqrt(diag(St))
  ctl <- if (jb$arm == "laplace") gllvmTMBcontrol() else gllvmTMBcontrol(aghq = 9)
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df,
                                          family = SPEC[[jb$fam]]$fam(), control = ctl)),
                error = function(e) NULL)
  if (is.null(f)) return(data.frame(fam = jb$fam, seed = jb$seed, arm = jb$arm,
                                    used = NA, sigma_rat = NA_real_, reason = "fit error",
                                    stringsAsFactors = FALSE))
  L <- tryCatch(f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE], error = function(e) NULL)
  sr <- if (is.null(L)) NA_real_ else median(sqrt(diag(L %*% t(L))) / sg_t)
  row <- data.frame(fam = jb$fam, seed = jb$seed, arm = jb$arm,
                    used = isTRUE(f$aghq$used), sigma_rat = sr,
                    reason = substr(paste(f$aghq$reason, collapse = ";"), 1, 60),
                    stringsAsFactors = FALSE)
  utils::write.table(row, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  row
}, mc.cores = 6L, mc.preschedule = FALSE)

res <- do.call(rbind, Filter(Negate(is.null), res))
cat(sprintf("\n=== FAMILY AXIS, n=%d p=%d q=%d, 10 seeds ===\n", N, P, Q))
cat(sprintf("%-10s | %9s %9s | %9s | %6s\n", "family", "LA |s-1|", "AGHQ|s-1|", "LEVER", "used%"))
for (fm in names(SPEC)) {
  a <- res[res$fam == fm & res$arm == "laplace" & is.finite(res$sigma_rat), ]
  b <- res[res$fam == fm & res$arm == "aghq_ridge" & is.finite(res$sigma_rat), ]
  if (!nrow(a) || !nrow(b)) { cat(sprintf("%-10s | %s\n", fm, "no usable fits")); next }
  la <- abs(median(a$sigma_rat) - 1); ag <- abs(median(b$sigma_rat) - 1)
  cat(sprintf("%-10s | %9.4f %9.4f | %+9.4f | %5.0f%%\n", fm, la, ag, la - ag,
              100 * mean(res$used[res$fam == fm & res$arm == "aghq_ridge"], na.rm = TRUE)))
}
cat("\nPOSITIVE CONTROL: gaussian's LEVER must be ~0 (Laplace is exact there).\n")
cat("If it is not, the harness is wrong and no other row is interpretable.\n")
