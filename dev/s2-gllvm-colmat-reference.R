## S2 -- gllvm colMat reference implementation (phylogeny acting on the
## species/column axis via random column effects).
##
## Purpose: establish a WORKING reference where the fitted log-likelihood
## responds to a change of tree, using gllvm::gllvm()'s `colMat` argument.
## This is a standalone research script -- it does NOT touch gllvmTMB
## package source. Run with:
##   Rscript --vanilla dev/s2-gllvm-colmat-reference.R
##
## Do NOT filter warnings with grep. All warnings are captured verbatim
## via withCallingHandlers() and printed/reported as-is.

suppressPackageStartupMessages({
  library(gllvm)   # 2.0.11
  library(ape)     # 5.8.1
})

cat("gllvm version:", as.character(packageVersion("gllvm")), "\n")
cat("ape version:", as.character(packageVersion("ape")), "\n")
cat("R version:", R.version.string, "\n\n")

## ---------------------------------------------------------------------
## Helper: run an expression, capture ALL warnings verbatim (do not
## muffle/drop them), and catch errors without stopping the script.
## ---------------------------------------------------------------------
fit_capture <- function(expr) {
  warns <- character(0)
  t0 <- Sys.time()
  val <- withCallingHandlers(
    tryCatch(expr, error = function(e) e),
    warning = function(w) {
      warns[[length(warns) + 1]] <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  t1 <- Sys.time()
  list(val = val, warnings = warns, secs = as.numeric(t1 - t0, units = "secs"))
}

report <- function(tag, r) {
  cat("---", tag, "---\n")
  cat("class:", paste(class(r$val), collapse = ", "), "\n")
  cat("time (s):", round(r$secs, 3), "\n")
  if (length(r$warnings)) {
    cat("warnings:\n")
    for (w in r$warnings) cat("  - ", w, "\n", sep = "")
  } else {
    cat("warnings: (none)\n")
  }
  if (inherits(r$val, "gllvm")) {
    cat("converged (finite logLik):", is.finite(r$val$logL), "\n")
    cat("logLik:", sprintf("%.6f", r$val$logL), "\n")
    cat("col.eff:", r$val$col.eff$col.eff, "\n")
    cat("dim(spdr):", paste(dim(r$val$col.eff$spdr), collapse = " x "), "\n")
    if (!is.null(r$val$params$rho.sp)) {
      cat("rho.sp (phylogenetic signal):", paste(sprintf("%.6f", r$val$params$rho.sp), collapse = ", "), "\n")
    } else {
      cat("rho.sp: not present in params\n")
    }
  } else if (inherits(r$val, "error")) {
    cat("ERROR:", conditionMessage(r$val), "\n")
  }
  cat("\n")
}

## =======================================================================
## SETUP: simulate a small JSDM data set with phylogenetically structured
## species slopes under a known tree.
## =======================================================================
SEED <- 1
set.seed(SEED)
n <- 30   # sites
m <- 12   # species
sp_names <- paste0("sp", 1:m)

tree_true <- ape::rcoal(m, tip.label = sp_names)
Ctrue_full <- ape::vcv(tree_true, corr = TRUE)
Ctrue <- Ctrue_full[sp_names, sp_names]

sigma_slope <- 1
mu_slope <- 0.6
slopes_true <- MASS::mvrnorm(1, mu = rep(mu_slope, m), Sigma = sigma_slope^2 * Ctrue)
intercepts <- rnorm(m, mean = 0.5, sd = 0.3)
env <- rnorm(n)

eta <- outer(env, slopes_true) + matrix(intercepts, n, m, byrow = TRUE)
Y <- matrix(rpois(n * m, lambda = exp(eta)), n, m)
colnames(Y) <- sp_names
Xdf <- data.frame(env = env)

cat("=== SETUP ===\n")
cat("n (sites):", n, " m (species):", m, " seed:", SEED, "\n")
cat("zero rows in Y:", sum(rowSums(Y) == 0), "  zero cols in Y:", sum(colSums(Y) == 0), "\n")
cat("range(Y):", paste(range(Y), collapse = " - "), "  mean(Y):", round(mean(Y), 3), "\n")
cat("true slopes (phylo-correlated under tree_true):\n")
print(round(slopes_true, 3))

## Independent "wrong" tree with the SAME tip labels, generated under a
## different seed -- different topology/branch lengths.
set.seed(999)
tree_wrong <- ape::rcoal(m, tip.label = sp_names)
Cwrong_full <- ape::vcv(tree_wrong, corr = TRUE)
Cwrong <- Cwrong_full[sp_names, sp_names]

topo_dist <- ape::dist.topo(tree_true, tree_wrong)
cat("\ntree_true vs tree_wrong topological distance (ape::dist.topo):", topo_dist, "\n")
cat("max abs diff between Ctrue and Cwrong entries:", round(max(abs(Ctrue - Cwrong)), 4), "\n\n")

## =======================================================================
## STEP 4: THE DECISIVE TWO-TREE TEST
## Working recipe (established below, after the trap is reproduced in
## STEP 5/6): random column (species) effects are created via BAR SYNTAX
## in the main `formula` argument -- formula = ~ (env | 1) -- NOT via the
## top-level `randomX = ~ env` argument. See "gllvm model assumptions"
## section of the RESULTS.md for the source-level diagnosis.
## =======================================================================
cat("################################################################\n")
cat("STEP 4 -- DECISIVE TWO-TREE TEST (formula = ~ (env | 1), colMat attached)\n")
cat("################################################################\n\n")

r_true <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ (env | 1),
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("tree_true (correct tree)", r_true)

r_wrong <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ (env | 1),
        colMat = Cwrong, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("tree_wrong (independent tree, same tip labels)", r_wrong)

ll_true <- r_true$val$logL
ll_wrong <- r_wrong$val$logL
cat("logLik(tree_true)  =", sprintf("%.6f", ll_true), "\n")
cat("logLik(tree_wrong) =", sprintf("%.6f", ll_wrong), "\n")
cat("difference (true - wrong) =", sprintf("%.6f", ll_true - ll_wrong), "\n\n")

## =======================================================================
## STEP 5 (required): NEGATIVE CONTROL -- reproduce the trap deliberately.
## 5a: literal top-level `randomX = ~ env` argument (NO bar syntax in
##     formula). Per source-level diagnosis this leaves col.eff == FALSE
##     and the column-random-effect design (spdr) degenerate (1x1 zero),
##     so colMat has nothing to act on.
## 5b: no random column effect mechanism at all (plain fixed formula,
##     no bars, no randomX) -- colMat is still passed to see whether it
##     is silently accepted with no effect.
## =======================================================================
cat("################################################################\n")
cat("STEP 5 -- NEGATIVE CONTROL (reproducing the trap)\n")
cat("################################################################\n\n")

cat("--- 5a: literal top-level randomX = ~ env (no bar syntax) ---\n\n")
rc_true_5a <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env, randomX = ~ env,
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("5a tree_true", rc_true_5a)

rc_wrong_5a <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env, randomX = ~ env,
        colMat = Cwrong, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("5a tree_wrong", rc_wrong_5a)

cat("logLik(tree_true, 5a)  =", sprintf("%.6f", rc_true_5a$val$logL), "\n")
cat("logLik(tree_wrong, 5a) =", sprintf("%.6f", rc_wrong_5a$val$logL), "\n")
cat("difference =", sprintf("%.10f", rc_true_5a$val$logL - rc_wrong_5a$val$logL), "\n\n")

cat("--- 5b: no randomX at all, plain fixed formula = ~ env, colMat still passed ---\n\n")
rc_true_5b <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env,
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("5b tree_true", rc_true_5b)

rc_wrong_5b <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env,
        colMat = Cwrong, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("5b tree_wrong", rc_wrong_5b)

if (inherits(rc_true_5b$val, "gllvm") && inherits(rc_wrong_5b$val, "gllvm")) {
  cat("logLik(tree_true, 5b)  =", sprintf("%.6f", rc_true_5b$val$logL), "\n")
  cat("logLik(tree_wrong, 5b) =", sprintf("%.6f", rc_wrong_5b$val$logL), "\n")
  cat("difference =", sprintf("%.10f", rc_true_5b$val$logL - rc_wrong_5b$val$logL), "\n\n")
}

## =======================================================================
## MAINTAINER ADDITION -- gllvm model assumptions
## =======================================================================
cat("################################################################\n")
cat("MODEL ASSUMPTIONS EXPERIMENTS\n")
cat("################################################################\n\n")

## A. Where does colMat enter -- intercepts, slopes, or both?
cat("--- A1: random INTERCEPT only, formula = ~ env + (1 | 1), colMat attached ---\n\n")
rA_true_int <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env + (1 | 1),
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("A1 tree_true (intercept-only random)", rA_true_int)

rA_wrong_int <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env + (1 | 1),
        colMat = Cwrong, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("A1 tree_wrong (intercept-only random)", rA_wrong_int)

if (inherits(rA_true_int$val, "gllvm") && inherits(rA_wrong_int$val, "gllvm")) {
  cat("logLik diff (intercept-only, true - wrong):",
      sprintf("%.6f", rA_true_int$val$logL - rA_wrong_int$val$logL), "\n\n")
}

cat("--- A2: random SLOPE only, formula = ~ (0 + env | 1), colMat attached ---\n\n")
rA_true_slope <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ (0 + env | 1),
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("A2 tree_true (slope-only random)", rA_true_slope)

rA_wrong_slope <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ (0 + env | 1),
        colMat = Cwrong, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("A2 tree_wrong (slope-only random)", rA_wrong_slope)

if (inherits(rA_true_slope$val, "gllvm") && inherits(rA_wrong_slope$val, "gllvm")) {
  cat("logLik diff (slope-only, true - wrong):",
      sprintf("%.6f", rA_true_slope$val$logL - rA_wrong_slope$val$logL), "\n\n")
}

## B. Grouping levels for random column effects: does the bar RHS
## resolve to a genuine second grouping axis distinct from species, or
## does it just multiply the number of species-level term-blocks?
cat("--- B: bar RHS grouping test, formula = ~ (env | fam), a 3-level covariate ---\n\n")
Xdf_fam <- data.frame(env = env, fam = rep(c("A", "B", "C"), length.out = n))
rB <- fit_capture(
  gllvm(y = Y, X = Xdf_fam, formula = ~ (env | fam),
        colMat = Ctrue, num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("B (env | fam)", rB)
if (inherits(rB$val, "gllvm")) {
  cat("dim(spdr) for (env|fam):", paste(dim(rB$val$col.eff$spdr), collapse = " x "), "\n")
  cat("dim(Br) for (env|fam):", paste(dim(rB$val$params$Br), collapse = " x "), "\n")
  cat("(compare to dim(spdr) = 30 x 2 and dim(Br) = 2 x 12 for the plain (env|1) model)\n\n")
}

## C. colMat.rho.struct: single (default) vs term-specific signal parameter.
cat("--- C: colMat.rho.struct = 'term' (per-covariate signal parameter) ---\n\n")
rC <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ (env | 1),
        colMat = list(Ctrue, dist = as.matrix(ape::cophenetic.phylo(tree_true))),
        colMat.rho.struct = "term", nn.colMat = m,
        num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("C colMat.rho.struct = 'term'", rC)

## D. Residual/observation-level species covariance for a family with a
## free dispersion parameter (gaussian): is there any BETWEEN-species
## covariance term at all (distinct from the num.lv ordination and from
## colMat-linked random column effects) that colMat could attach to?
cat("--- D: gaussian family, num.lv = 0, no random column effect -- inspect params ---\n\n")
Yg <- eta + matrix(rnorm(n * m, sd = 0.5), n, m)  # continuous responses
colnames(Yg) <- sp_names
rD <- fit_capture(
  gllvm(y = Yg, X = Xdf, formula = ~ env,
        num.lv = 0, family = "gaussian",
        sd.errors = FALSE, seed = SEED)
)
report("D gaussian, no random column effect", rD)
if (inherits(rD$val, "gllvm")) {
  cat("params names:", paste(names(rD$val$params), collapse = ", "), "\n")
  cat("phi (per-species dispersion/SD), length", length(rD$val$params$phi), ":\n")
  print(round(rD$val$params$phi, 4))
  cat("(phi is a per-species scalar -- diagonal only; no off-diagonal species\n")
  cat(" covariance term exists here for colMat to act on.)\n\n")
}

## E. Row/column intercept structure: are species intercepts fixed by
## default, and does colMat have any effect without an explicit random
## bar term including species effects at all (formula with NO bars,
## NO randomX, and NO colMat)?
cat("--- E: baseline model, formula = ~ env, no colMat, no random column effect ---\n\n")
rE <- fit_capture(
  gllvm(y = Y, X = Xdf, formula = ~ env,
        num.lv = 0, family = "poisson",
        sd.errors = FALSE, seed = SEED)
)
report("E baseline (no colMat at all)", rE)
if (inherits(rE$val, "gllvm")) {
  cat("params names:", paste(names(rE$val$params), collapse = ", "), "\n")
  cat("beta0 (species intercepts), length", length(rE$val$params$beta0), ":\n")
  print(round(rE$val$params$beta0, 3))
  cat("Xcoef (common env slope):", round(rE$val$params$Xcoef, 4), "\n")
  cat("(species intercepts beta0 are fitted per-species by default -- as FIXED\n")
  cat(" effects, no random/colMat structure attached, since col.eff stayed FALSE.)\n\n")
}

## =======================================================================
## Save a compact summary object for reproducibility/inspection.
## =======================================================================
summary_list <- list(
  seed = SEED, n = n, m = m,
  topo_dist = as.numeric(topo_dist),
  step4 = list(ll_true = ll_true, ll_wrong = ll_wrong, diff = ll_true - ll_wrong,
               warnings_true = r_true$warnings, warnings_wrong = r_wrong$warnings,
               rho_sp_true = r_true$val$params$rho.sp,
               rho_sp_wrong = r_wrong$val$params$rho.sp),
  step5a = list(ll_true = rc_true_5a$val$logL, ll_wrong = rc_wrong_5a$val$logL,
                diff = rc_true_5a$val$logL - rc_wrong_5a$val$logL,
                warnings_true = rc_true_5a$warnings, warnings_wrong = rc_wrong_5a$warnings),
  step5b = list(
    ll_true = if (inherits(rc_true_5b$val, "gllvm")) rc_true_5b$val$logL else NA,
    ll_wrong = if (inherits(rc_wrong_5b$val, "gllvm")) rc_wrong_5b$val$logL else NA,
    warnings_true = rc_true_5b$warnings, warnings_wrong = rc_wrong_5b$warnings
  )
)
saveRDS(summary_list, file.path("dev", "s2-gllvm-colmat-reference-summary.rds"))

cat("\n=== SCRIPT COMPLETE ===\n")
