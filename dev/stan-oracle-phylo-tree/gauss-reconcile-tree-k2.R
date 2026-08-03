## =====================================================================
## Arc 2 reconciliation -- dataset B: out-of-sample confirmation on
## structure the transport was never tuned against.
##
## gauss-reconcile-tree.R (committed cd0c58cf, FROZEN, not edited here) is
## dataset A: rcoal(8), T=3, K=1 -- and K=1 makes the Kronecker/axis-ordering
## question and the general Lambda-packing question DEGENERATE (a single
## column has no "order" and no off-diagonal to force to zero). It also built
## its tree so that tip order == factor-level order, so the species -> A-row
## permutation was never actually exercised.
##
## Design mirrors Arc 1's dataset B (dev/stan-oracle-phylo/gauss-reconcile-
## phylo-k2.R, read for DESIGN only -- that arc used the DENSE vcv= route,
## not this arc's tree= route, so its actual transport code does not carry
## over): a SECOND, larger tree (rcoal(10), fresh seed), T=4 traits, K=2
## (rank 2, the smallest rank at which packing/axis questions are live),
## PERMUTED tip labels (levels(factor(species)) != tree$tip.label), and a
## RAGGED design (2 cells dropped outright, 5 more thinned to 1 replicate).
##
## TRANSPORT is FROZEN -- copied verbatim (mechanism, not literal dimensions)
## from gauss-reconcile-tree.R:
##   1. mu = b_fix; sigma_eps = exp(log_sigma_eps)
##   2. Lambda = theta_rr_phy, identity (no exp), diag-first then strict
##      lower triangle column-major, upper triangle exactly 0 (cpp:1145-1165)
##   3. a_node = g_phy PERMUTED via eng_of_stan (engine internal-first/tips-
##      last -> Stan tips-first)
##   4. parent map (0 = root) + branch_len = edge.length / height
##   5. NO ridge on this route
##   6. log_prob(adjust_transform = FALSE); Jacobian audit against
##      log(sigma_eps) at every point
##
## ONE ADAPTATION, forced by the permuted-tip design (see sec. 2 below): the
## Stan model's OWN contract (gllvm_phylo_tree.stan:62-68) is that a_node's
## first S rows are tips "in the SAME order as the species levels that
## produced ss[i]" -- i.e. FACTOR-LEVEL order, not tree-tip order. In dataset
## A these coincide (tip order WAS built equal to level order), so
## `prec$tip_node_index` (tree-tip order) and the level-order map are the same
## vector and either works. Here they genuinely differ, so `tip_e` below is
## built in LEVEL order (matching how `ss[i]` is computed), cross-checked two
## independent ways before it is trusted. Everything downstream (parent map,
## branch scaling, no-ridge, log_prob calls) is unchanged mechanism.
##
## Both engines run in ONE R session, data regenerated in-session; no value
## crosses a JSON boundary before any comparison (Arc 1 s.9.3).
## =====================================================================

suppressMessages({
  library(ape); library(Matrix); library(TMB); library(rstan)
})
rstan_options(auto_write = TRUE)

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree"
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))

here     <- file.path(pkg_root, "dev", "stan-oracle-phylo-tree")
stan_f   <- file.path(here, "gllvm_phylo_tree.stan")
stan_mt0 <- file.mtime(stan_f)

f17 <- function(x) sprintf("%.17g", x)
hdr <- function(s) cat("\n", strrep("=", 68), "\n", s, "\n", strrep("=", 68), "\n", sep = "")

## ---------------------------------------------------------------------
## 1. Dataset B: second, larger tree; T = 4; K = 2; PERMUTED tip labels;
##    RAGGED design (fresh seed, distinct from dataset A's 20260803L)
## ---------------------------------------------------------------------
set.seed(20260811L)
n_tip <- 10L; T_ <- 4L; K <- 2L; R <- 3L
tree <- rcoal(n_tip)
## Assign tip labels to tree tips in a SHUFFLED order, so that
## levels(factor(species)) (alphabetical string sort) != tree$tip.label.
## "sB1".."sB10" sort alphabetically as sB1,sB10,sB2,sB3,...,sB9 (lexicographic
## string sort), which is guaranteed to differ from any assignment order that
## is not itself that exact sequence -- verified below, not assumed.
tip_labels <- paste0("sB", c(7, 2, 9, 4, 10, 1, 8, 3, 6, 5))
stopifnot(length(unique(tip_labels)) == n_tip)
tree$tip.label <- tip_labels
stopifnot(!identical(sort(tip_labels), tip_labels))   # alnum sort != assigned tip order

A <- vcv(tree, corr = TRUE)                 # SIMULATION input only -- the tree=
                                             # route never feeds this dense object
                                             # to the engine (R/fit-multi.R:3157-3182)
stopifnot(identical(rownames(A), tree$tip.label))

trait_names <- paste0("tr", seq_len(T_))
alpha_true  <- c(0.6, -0.4, 0.1, 1.2)
Lam_true    <- matrix(c(1.1, 0.7, -0.5, 0.3,      ## col 1
                        0.0, 0.9,  0.4, -0.8),    ## col 2, upper-tri zero at [1,2]
                      nrow = T_, ncol = K)
sigma_eps_true <- 0.4
L_A    <- t(chol(A[tree$tip.label, tree$tip.label]))
G_true <- cbind(as.numeric(L_A %*% rnorm(n_tip)), as.numeric(L_A %*% rnorm(n_tip)))
rownames(G_true) <- tree$tip.label

rows <- list(); k <- 1L
for (sp in tree$tip.label) for (ti in seq_len(T_)) {
  eta_st <- alpha_true[ti] + sum(Lam_true[ti, ] * G_true[sp, ])
  for (r in seq_len(R)) {
    rows[[k]] <- data.frame(species = sp, trait = trait_names[ti],
                            value = eta_st + rnorm(1, sd = sigma_eps_true))
    k <- k + 1L
  }
}
df <- do.call(rbind, rows)

## ---- RAGGED: 2 cells removed entirely, 5 more thinned to 1 replicate -----
drop_cell <- function(d, sp, tr) d[!(d$species == sp & d$trait == tr), , drop = FALSE]
df <- drop_cell(df, "sB9", "tr3")     ## (sB9, tr3) -- no data at all
df <- drop_cell(df, "sB3", "tr1")     ## (sB3, tr1) -- no data at all
set.seed(31415L)
thin <- function(d, sp, tr) {
  idx <- which(d$species == sp & d$trait == tr)
  if (length(idx) <= 1) return(d)
  d[-idx[-1], , drop = FALSE]
}
for (pr in list(c("sB1", "tr2"), c("sB5", "tr4"), c("sB2", "tr1"),
                c("sB6", "tr3"), c("sB10", "tr4"))) {
  df <- thin(df, pr[1], pr[2])
}
df$species <- factor(df$species)              ## ALPHABETICAL levels -- NOT tree order
df$trait   <- factor(df$trait, levels = trait_names)
rownames(df) <- NULL
levs <- levels(df$species)
N <- nrow(df)

hdr("DATASET B (measured)")
cat("N =", N, " S =", n_tip, " T =", T_, " K =", K, " reps(nominal) =", R, "\n")
cat("tree tip order :", paste(tree$tip.label, collapse = ","), "\n")
cat("factor levels   :", paste(levs, collapse = ","), "\n")
cat("permutation live (levels != tip order):", !identical(levs, tree$tip.label), "\n")
cat("cells with zero data:", sum(table(df$species, df$trait) == 0), "of", n_tip * T_, "\n")
cat("min/max reps per nonzero cell:",
    paste(range(table(df$species, df$trait)[table(df$species, df$trait) > 0]), collapse = "/"), "\n")
stopifnot(!identical(levs, tree$tip.label))
stopifnot(all(table(df$species) > 0), all(table(df$trait) > 0))   # no species/trait totally empty

## ---------------------------------------------------------------------
## 2. TMB joint objective (tree= route)
## ---------------------------------------------------------------------
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = K, tree = tree),
  data = df, family = gaussian(),
  trait = "trait", unit = "species", cluster = "species",
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 30, eval.max = 40))))))
td <- fit$tmb_data
n_aug <- as.integer(td$n_aug_phy)

hdr("STRUCTURE (measured) -- n_aug arithmetic")
cat("n_tip", n_tip, " Nnode", tree$Nnode, " n_total", n_tip + tree$Nnode,
    " edges", nrow(tree$edge), " n_aug_phy(measured)", n_aug, "\n")
cat("2S-2 =", 2 * n_tip - 2, "   2S-1 =", 2 * n_tip - 1, "\n")
stopifnot(n_aug == (n_tip + tree$Nnode) - 1L)     # root excluded, per R/phylo-tree-precision.R:203-207
stopifnot(n_aug == 2L * n_tip - 2L)               # confirms the tmb-side-tree.md (a) finding again, on a fresh tree

joint_obj <- TMB::MakeADFun(data = td, parameters = fit$tmb_params,
                            map = fit$tmb_map, random = NULL,
                            DLL = "gllvmTMB", silent = TRUE)
nm    <- names(joint_obj$par)
n_rr  <- T_ * K - K * (K - 1L) / 2L               ## cpp:1151 expected_nt; 4*2 - 2*1/2 = 7
stopifnot(sum(nm == "b_fix") == T_)
stopifnot(sum(nm == "theta_rr_phy") == n_rr)
stopifnot(sum(nm == "g_phy") == n_aug * K)
cat("theta blocks: b_fix", sum(nm == "b_fix"), " log_sigma_eps", sum(nm == "log_sigma_eps"),
    " theta_rr_phy", sum(nm == "theta_rr_phy"), "(expected", n_rr, ") g_phy", sum(nm == "g_phy"),
    "(expected", n_aug * K, ")\n")

## Species-level factor coding must be the SAME between the df fed to Stan's
## `ss` and TMB's own species_id (paranoid but cheap; catches any accidental
## re-leveling between the two uses of `df$species`).
stopifnot(identical(as.integer(df$species) - 1L, as.integer(td$species_id)))

## ---------------------------------------------------------------------
## 3. Transport: engine augmented order -> Stan node order (adapted for the
##    permuted-tip design; mechanism verbatim from gauss-reconcile-tree.R)
## ---------------------------------------------------------------------
prec <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
lab  <- rownames(prec$precision)                  # engine order (internal-first, tips-last)

## tip_e: engine (1-indexed) position of each of the S tips, in FACTOR-LEVEL
## order -- NOT tree-tip order. gllvm_phylo_tree.stan:62-68 states a_node's
## first S rows must be "in the SAME order as the species levels that
## produced ss[i]"; ss[i] is as.integer(df$species[i]), i.e. LEVEL order.
## Dataset A's tree was built so tip order == level order, so
## `prec$tip_node_index` (tree-tip order) and this vector were the same
## there; here they are NOT, so the level-order map is built and used
## explicitly, and cross-checked two independent ways before being trusted.
tip_e <- match(levs, lab)                          ## direct: level -> engine position
stopifnot(!anyNA(tip_e))

species_id0  <- as.integer(td$species_id)          # 0-indexed level code per row
species_aug0 <- as.integer(td$species_aug_id)      # 0-indexed engine position per row
tip_e_check <- vapply(seq_len(n_tip) - 1L, function(s0) {
  species_aug0[match(s0, species_id0)] + 1L
}, integer(1))
stopifnot(identical(tip_e, tip_e_check))            # two independent derivations agree
cat("tip_e (level order, 1-indexed engine position), cross-checked identical:\n")
print(setNames(tip_e, levs))

int_e <- setdiff(seq_len(n_aug), tip_e)
eng_of_stan <- c(tip_e, int_e)                      # stan row v <- engine position
stan_of_eng <- integer(n_aug)
stan_of_eng[eng_of_stan] <- seq_len(n_aug)
stopifnot(!any(stan_of_eng == 0L))

## parent map + scaled branch lengths, in STAN row order (verbatim mechanism
## from gauss-reconcile-tree.R -- pure topology, unaffected by species order)
node_index <- prec$node_index
root_ape   <- prec$root
height     <- prec$height
parent_stan <- integer(n_aug); branch_stan <- numeric(n_aug)
for (e in seq_len(nrow(tree$edge))) {
  p_ape <- tree$edge[e, 1]; c_ape <- tree$edge[e, 2]
  v <- stan_of_eng[node_index[c_ape]]
  parent_stan[v] <- if (p_ape == root_ape) 0L else stan_of_eng[node_index[p_ape]]
  branch_stan[v] <- tree$edge.length[e] / height    # correlation = TRUE rescaling
}
stopifnot(all(branch_stan > 0))

## No ridge on this route (R/fit-multi.R:3157-3182 vs :3224) -- nothing to
## replicate on the Stan side; confirmed again here structurally: the
## engine's own Ainv is rebuilt with zero jitter added anywhere above.

## ---------------------------------------------------------------------
## 4. Lambda packing -- diag-first, then strict lower triangle column-major,
##    upper triangle exactly 0 (cpp:1145-1165). NOT degenerate at K = 2:
##    ported from cpp's 0-indexed formula and independently re-verified
##    against it (not merely copied): for 1-indexed (i, j), i > j (strict
##    lower), the packed position in the tail-of-theta_rr_phy vector is
##    (j-1)*p - j*(j-1)/2 + i - j.
## ---------------------------------------------------------------------
pack_Lambda <- function(trr, p, rank) {
  lam_diag  <- trr[seq_len(rank)]
  lam_lower <- trr[-seq_len(rank)]
  L <- matrix(0, p, rank)
  for (j in seq_len(rank)) {
    for (i in seq_len(p)) {
      if (j > i) {
        L[i, j] <- 0
      } else if (i == j) {
        L[i, j] <- lam_diag[j]
      } else {
        L[i, j] <- lam_lower[(j - 1) * p - j * (j - 1) / 2 + i - j]
      }
    }
  }
  L
}
## Self-test: theta_rr_phy_P1 below was written down by reading Lambda_P1's
## own entries off in (diag-first, strict-lower column-major) order; confirm
## pack_Lambda() recovers EXACTLY that matrix before it is trusted downstream.
Lambda_P1_target <- matrix(c(1.1, 0.7, -0.5, 0.3,
                             0.0, 0.9,  0.4, -0.8), nrow = T_, ncol = K)
theta_rr_phy_P1  <- c(1.1, 0.9, 0.7, -0.5, 0.3, 0.4, -0.8)
stopifnot(length(theta_rr_phy_P1) == n_rr)
stopifnot(identical(pack_Lambda(theta_rr_phy_P1, T_, K), Lambda_P1_target))
cat("pack_Lambda() self-test against a hand-built target Lambda: PASSED\n")

## ---------------------------------------------------------------------
## 5. Stan shell (compiled once; auto_write reuses the cached .rds if valid)
## ---------------------------------------------------------------------
stan_data <- list(
  N = N, n_t = T_, S = n_tip, K = K,
  tt = as.integer(df$trait), ss = as.integer(df$species), y = df$value,
  n_node = n_aug, parent = parent_stan, branch_len = branch_stan)

hdr("COMPILING / LOADING STAN MODEL")
sm   <- stan_model(stan_f, auto_write = TRUE)
fit0 <- sampling(sm, data = stan_data, chains = 0, refresh = 0)

## ---------------------------------------------------------------------
## 6. eval_pair(): TMB joint fn vs Stan log_prob at one theta point
## ---------------------------------------------------------------------
to_a_node <- function(ge) matrix(ge, nrow = n_aug, ncol = K)[eng_of_stan, , drop = FALSE]

eval_pair <- function(bf, ls, tr_, ge, label) {
  th <- numeric(length(joint_obj$par))
  th[nm == "b_fix"]         <- bf
  th[nm == "log_sigma_eps"] <- ls
  th[nm == "theta_rr_phy"]  <- tr_
  th[nm == "g_phy"]         <- ge
  tmb_nll <- joint_obj$fn(th)

  Lambda <- pack_Lambda(tr_, T_, K)
  a_node <- to_a_node(ge)
  sp     <- list(mu = bf, Lambda = Lambda, sigma_eps = exp(ls), a_node = a_node)
  up     <- unconstrain_pars(fit0, sp)
  lpF    <- log_prob(fit0, up, adjust_transform = FALSE, gradient = FALSE)
  lpT    <- log_prob(fit0, up, adjust_transform = TRUE,  gradient = FALSE)
  jac_diff <- abs((lpT - lpF) - ls)

  cat(sprintf("%-6s TMB %-22s Stan %-24s |diff| %-12s rel %-12s jac|diff| %s\n",
              label, f17(tmb_nll), f17(lpF), f17(abs((-tmb_nll) - lpF)),
              f17(abs((-tmb_nll) - lpF) / abs(lpF)), f17(jac_diff)))
  list(tmb = tmb_nll, stan = lpF, stan_T = lpT, diff = abs((-tmb_nll) - lpF),
       rel = abs((-tmb_nll) - lpF) / abs(lpF), jac_diff = jac_diff,
       sp = sp, bf = bf, ls = ls, tr_ = tr_, ge = ge)
}

## ---------------------------------------------------------------------
## 7. Three fresh theta points (distinct seeds from dataset A and from Arc 1)
## ---------------------------------------------------------------------
hdr("DATASET B: 3 points (T=4, K=2, ragged, permuted tips, tree= route)")

set.seed(20260812L); g1 <- round(rnorm(n_aug * K), 3)
P1 <- eval_pair(c(0.6, -0.4, 0.1, 1.2), log(0.4), theta_rr_phy_P1, g1, "B/P1")

set.seed(20260813L); g2 <- round(rnorm(n_aug * K, sd = 1.4), 3)
P2 <- eval_pair(c(-2.3, 1.6, 0.08, -0.95), log(1.35),
                c(-1.8, 2.1, 0.35, -1.95, 1.10, -0.60, 1.05), g2, "B/P2")

set.seed(20260814L); g3 <- round(rnorm(n_aug * K, sd = 0.6), 3)
P3 <- eval_pair(c(0, 0, 0, 0), log(0.12),
                c(2.8, -3.1, 0.85, 0.75, -1.6, 1.9, -0.55), g3, "B/P3")

## ---------------------------------------------------------------------
## 8. Three NEW controls -- degenerate at K = 1, live only here
## ---------------------------------------------------------------------
hdr("NEW CONTROLS (K>=2 only) -- shift in the Stan log-density vs B/P1")
base_lp <- P1$stan

## (a) axis/Kronecker ordering: read g_phy AXIS-fastest (byrow) instead of
## NODE-fastest (column-major, the true PARAMETER_MATRIX flattening,
## cpp:694 `PARAMETER_MATRIX(g_phy); // n_species x d_phy`). Same row
## permutation (eng_of_stan) applied afterward, to isolate purely the
## within-row (node,factor) attribution error, not a different species map.
a_node_axis <- matrix(g1, nrow = n_aug, ncol = K, byrow = TRUE)[eng_of_stan, , drop = FALSE]
sp_axis <- P1$sp; sp_axis$a_node <- a_node_axis
shift_axis <- log_prob(fit0, unconstrain_pars(fit0, sp_axis), adjust_transform = FALSE, gradient = FALSE) - base_lp
cat(sprintf("  %-46s shift %s\n", "(a) g_phy axis-fastest, not node-fastest", f17(shift_axis)))

## (b) loadings packing read ROW-major into the lower triangle instead of
## column-major (still diag-first; only the STRICT-LOWER fill order is wrong)
Lalt <- matrix(0, T_, K); ii <- 1L
for (i in seq_len(T_)) for (j in seq_len(K)) if (j <= i) {
  Lalt[i, j] <- theta_rr_phy_P1[ii]; ii <- ii + 1L
}
stopifnot(!identical(Lalt, Lambda_P1_target))   # confirm this really is a different matrix
sp_pack <- P1$sp; sp_pack$Lambda <- Lalt
shift_packing <- log_prob(fit0, unconstrain_pars(fit0, sp_pack), adjust_transform = FALSE, gradient = FALSE) - base_lp
cat(sprintf("  %-46s shift %s\n", "(b) Lambda packed row-major, not column-major", f17(shift_packing)))

## (c) forced-zero upper triangle set nonzero (Lambda[1,2] must be exactly 0
## under the rr() packing convention; K=1 has no upper triangle to break)
sp_zero <- P1$sp; sp_zero$Lambda[1, 2] <- 0.85
shift_zero <- log_prob(fit0, unconstrain_pars(fit0, sp_zero), adjust_transform = FALSE, gradient = FALSE) - base_lp
cat(sprintf("  %-46s shift %s\n", "(c) forced-zero Lambda[1,2] set to 0.85", f17(shift_zero)))

## ---------------------------------------------------------------------
## 9. Difference-of-differences (constant-free check) + integrity
## ---------------------------------------------------------------------
hdr("DIFFERENCE-OF-DIFFERENCES + INTEGRITY")
dod_P2 <- ((-P2$tmb) - P2$stan) - ((-P1$tmb) - P1$stan)
dod_P3 <- ((-P3$tmb) - P3$stan) - ((-P1$tmb) - P1$stan)
cat("(P2 - P1):", f17(dod_P2), "\n")
cat("(P3 - P1):", f17(dod_P3), "\n")
cat("max |diff| over 3 points:", f17(max(P1$diff, P2$diff, P3$diff)), "\n")
cat("max rel over 3 points   :", f17(max(P1$rel, P2$rel, P3$rel)), "\n")

stan_mt1 <- file.mtime(stan_f)
cat("gllvm_phylo_tree.stan mtime unchanged:", identical(stan_mt0, stan_mt1), "\n")
stopifnot(identical(stan_mt0, stan_mt1))

## ---------------------------------------------------------------------
## 10. Write results (RDS for exact precision; JSON per instructions --
##     NOTE: the comparisons above already happened entirely in-session,
##     before any serialization; jsonlite::write_json(digits=NA) is known
##     (tmb-side-tree.md) NOT to be bitwise exact, so the RDS / the %.17g
##     console output above are the authoritative record, not this JSON)
## ---------------------------------------------------------------------
results <- list(
  meta = list(n_tip = n_tip, T_ = T_, K = K, N = N, n_aug = n_aug,
              n_rr = n_rr, seed_tree = 20260811L, seed_thin = 31415L,
              tip_labels = tip_labels, levels = levs,
              permutation_live = !identical(levs, tree$tip.label),
              cells_zero = sum(table(df$species, df$trait) == 0)),
  points = list(
    P1 = list(tmb = P1$tmb, stan = P1$stan, diff = P1$diff, rel = P1$rel, jac_diff = P1$jac_diff),
    P2 = list(tmb = P2$tmb, stan = P2$stan, diff = P2$diff, rel = P2$rel, jac_diff = P2$jac_diff),
    P3 = list(tmb = P3$tmb, stan = P3$stan, diff = P3$diff, rel = P3$rel, jac_diff = P3$jac_diff)
  ),
  dod = list(P2_minus_P1 = dod_P2, P3_minus_P1 = dod_P3),
  controls = list(axis_fastest_not_node_fastest = shift_axis,
                  Lambda_packed_row_major       = shift_packing,
                  forced_zero_Lambda_1_2        = shift_zero),
  stan_mtime_unchanged = identical(stan_mt0, stan_mt1)
)
saveRDS(results, file.path(here, "gauss-reconcile-tree-k2.rds"))
jsonlite::write_json(results, file.path(here, "gauss-reconcile-tree-k2.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
cat("\nWrote gauss-reconcile-tree-k2.{rds,json}\n")
