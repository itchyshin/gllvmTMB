## THE CAMPAIGN, RUN THROUGH THE SHIPPED ENGINE.
##
## WHY THIS EXISTS. A D-43 review lens found that only 2 of 16 evidence scripts in this
## directory call the real gllvmTMB(), both at n <= 30. EVERY multi-seed and large-n number
## in the claim -- the 954-fit suite, the n = 3200 descent, every sigma/rho/runaway figure --
## came from dev/aghq-r-reference.R, whose own header says it "is NOT a shipping route and
## must never become one". That reference was built deliberately as an INDEPENDENT ORACLE,
## and its independence is exactly what disqualifies it as evidence ABOUT the engine.
##
## So: same design, same DGP, same arms -- through `gllvmTMB()` itself.
##
## PRE-REGISTERED, before the run:
##   P1. The shipped engine reproduces the reference's DIRECTION at n = 100: Laplace's
##       sigma biased low with a substantial runaway fraction; AGHQ+ridge near 1 with fewer.
##   P2. At n = 1600 the shipped AGHQ arm sits closer to 1 than the shipped Laplace arm.
##   P3. Laplace+ridge is included because it is the fair control and because the panel
##       found it closes much of the small-n gap on its own.
## If P1 or P2 FAILS, the reference does not represent the engine and every number derived
## from it must be withdrawn -- which is a more important result than a confirmation.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

OUT <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/18-shipped-inc.csv"
if (file.exists(OUT)) file.remove(OUT)
CORES <- as.integer(Sys.getenv("SHIP_CORES", "6"))   # Codex shares this machine

## DGP byte-identical to the reference campaign, so the two are comparable.
mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y  <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt)
}
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

ARMS <- list(
  laplace       = function() gllvmTMBcontrol(),
  laplace_ridge = NULL,                                    # not reachable; see note below
  aghq          = function() gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf),
  aghq_ridge    = function() gllvmTMBcontrol(aghq = 9)     # ridge on by default
)
## NOTE, stated rather than hidden: `Laplace + ridge` is NOT reachable through the shipped
## control surface -- the ridge is applied only on the AGHQ path. The panel was right that
## this coupling is one this codebase authored, and it is why the fair control cannot be run
## here. Recorded as a scope limit of THIS script, not as an argument that the control is
## illegitimate.
ARMS$laplace_ridge <- NULL

P <- 6L; Q <- 2L; LAM <- 1.0
jobs <- expand.grid(n = c(100L, 1600L), seed = 2001:2015,
                    arm = c("laplace", "aghq", "aghq_ridge"),
                    stringsAsFactors = FALSE)
cat(sprintf("shipped-engine campaign: %d fits on %d cores\n", nrow(jobs), CORES)); flush(stdout())

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d  <- mk(jb$n, P, Q, LAM, jb$seed)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St)); off <- upper.tri(Rt)
  ctl <- ARMS[[jb$arm]]()
  t0 <- Sys.time()
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                          control = ctl)),
                error = function(e) NULL)
  if (is.null(f)) return(NULL)
  L  <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  Sh <- L %*% t(L); Rh <- corr_of(Sh)
  row <- data.frame(
    n = jb$n, seed = jb$seed, arm = jb$arm,
    aghq_used = isTRUE(f$aghq$used),
    frob_rat  = norm(L, "F") / norm(d$Lt, "F"),
    sigma_rat = median(sqrt(diag(Sh)) / sg_t),
    rho_absd  = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),
    conv      = tryCatch(f$opt$convergence, error = function(e) NA),
    elapsed_s = as.numeric(Sys.time() - t0, units = "secs"),
    stringsAsFactors = FALSE)
  utils::write.table(row, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  row
}, mc.cores = CORES, mc.preschedule = FALSE)

res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, sub("-inc", "", OUT), row.names = FALSE)
cat(sprintf("\n=== SHIPPED ENGINE, p=%d q=%d, %d seeds ===\n", P, Q, 15))
cat(sprintf("%6s %-12s | %5s %10s %10s %10s %9s %8s\n",
            "n", "arm", "nfit", "sigma", "rho |e|", "frob rat", "runaway%", "aghq?"))
for (n in sort(unique(res$n))) for (a in c("laplace", "aghq", "aghq_ridge")) {
  s <- res[res$n == n & res$arm == a, ]
  if (!nrow(s)) next
  cat(sprintf("%6d %-12s | %5d %10.3f %10.3f %10.3f %8.0f%% %8s\n", n, a, nrow(s),
              median(s$sigma_rat, na.rm = TRUE), median(s$rho_absd, na.rm = TRUE),
              median(s$frob_rat, na.rm = TRUE), 100 * mean(s$frob_rat > 2, na.rm = TRUE),
              sprintf("%.0f%%", 100 * mean(s$aghq_used))))
}
