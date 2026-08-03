## Independent check of the algebra Arc 2 rests on.
## Pure R + ape + Matrix. No TMB, no Stan, no reading of either side's output.
##
## Three claims to verify:
##  C1. The edge-recursion precision (Felsenstein/Hadfield Markov form, root fixed at 0)
##      equals the engine's .gllvm_phylo_tree_precision(tree, correlation = TRUE)$precision.
##  C2. Marginalising the internal nodes (invert the augmented precision, restrict to tips)
##      reproduces ape::vcv(tree, corr = TRUE).
##  C3. The DENSITY identity the Stan model depends on:
##        sum_v normal_lpdf(a_v | a_parent(v), sqrt(b_v))
##          == -0.5 * (n_aug*log(2*pi) + log|A_aug| + a' Ainv a)
##      i.e. a sum of independent per-edge increments equals the multivariate form.

suppressMessages({ library(ape); library(Matrix) })
set.seed(4242L)

pkg <- "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree"
suppressMessages(devtools::load_all(pkg, quiet = TRUE))

f17 <- function(x) sprintf("%.17g", x)

report <- function(tree, label) {
  cat("\n=====", label, " (n_tip =", Ape <- length(tree$tip.label), ") =====\n")

  n_tip  <- length(tree$tip.label)
  n_node <- tree$Nnode
  n_tot  <- n_tip + n_node
  edge   <- tree$edge; el <- tree$edge.length
  root   <- setdiff(unique(edge[,1]), edge[,2])
  stopifnot(length(root) == 1L)

  ## engine's builder (this is the thing under test)
  eng <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
  P_eng <- as.matrix(eng$precision)
  n_aug <- nrow(P_eng)

  cat("n_tip:", n_tip, " Nnode:", n_node, " n_aug(engine):", n_aug,
      " 2S-2 =", 2*n_tip-2, " 2S-1 =", 2*n_tip-1, "\n")
  cat("root in augmented set? ", if (n_aug == 2*n_tip-1) "YES" else "NO", "\n")

  ## ---- C1: rebuild the precision from the edge recursion, independently ----
  ## Node order: internal-first (excluding root), then tips -- read off the
  ## engine's OWN rownames, so ordering is transport, not mathematics.
  lab <- rownames(P_eng)
  ## map ape node id -> augmented position, via labels
  ape_lab <- c(tree$tip.label, if (!is.null(tree$node.label)) tree$node.label else
                                 paste0("Node", seq_len(n_node) + n_tip))
  ## engine labels internal nodes; recover its id ordering by matching tips and
  ## assuming the remaining positions are internal in its own order.
  pos <- eng$node_index                       # ape id -> augmented position (0 if excluded)
  height <- eng$height
  scale  <- height                            # correlation = TRUE

  P_rec <- matrix(0, n_aug, n_aug)
  for (e in seq_len(nrow(edge))) {
    p <- edge[e,1]; c_ <- edge[e,2]
    b <- el[e] / height                       # scaled so root-to-tip = 1
    ic <- pos[c_]
    P_rec[ic,ic] <- P_rec[ic,ic] + 1/b
    if (p != root) {
      ip <- pos[p]
      P_rec[ip,ip] <- P_rec[ip,ip] + 1/b
      P_rec[ip,ic] <- P_rec[ip,ic] - 1/b
      P_rec[ic,ip] <- P_rec[ic,ip] - 1/b
    }
  }
  d1 <- max(abs(P_rec - P_eng))
  cat("C1 max|P_recursion - P_engine| =", f17(d1), "\n")

  ## ---- C2: marginalise internal nodes -> tips-only covariance ----
  Cov_aug <- solve(P_eng)
  tip_pos <- pos[seq_len(n_tip)]
  Cov_tip <- Cov_aug[tip_pos, tip_pos]
  dimnames(Cov_tip) <- list(tree$tip.label, tree$tip.label)
  A_dense <- ape::vcv(tree, corr = TRUE)
  A_dense <- A_dense[tree$tip.label, tree$tip.label]
  d2 <- max(abs(Cov_tip - A_dense))
  cat("C2 max|marginalised - ape::vcv(corr=TRUE)| =", f17(d2), "\n")

  ## ---- C3: the density identity ----
  a <- rnorm(n_aug)                           # arbitrary augmented score vector
  ## (i) sum of per-edge increment log-densities, root pinned at 0
  lp_inc <- 0
  for (e in seq_len(nrow(edge))) {
    p <- edge[e,1]; c_ <- edge[e,2]
    b <- el[e] / height
    mu <- if (p == root) 0 else a[pos[p]]
    lp_inc <- lp_inc + dnorm(a[pos[c_]], mean = mu, sd = sqrt(b), log = TRUE)
  }
  ## (ii) the multivariate form using the engine's precision + its log-det
  logdetA <- -eng$log_det_precision            # log|A_aug| = -log|A_aug^-1|
  quad    <- as.numeric(t(a) %*% P_eng %*% a)
  lp_mvn  <- -0.5 * (n_aug*log(2*pi) + logdetA + quad)
  cat("C3 increment-sum   =", f17(lp_inc), "\n")
  cat("C3 multivariate    =", f17(lp_mvn), "\n")
  cat("C3 |difference|    =", f17(abs(lp_inc - lp_mvn)), "\n")

  ## cross-check the engine's stored log-det against a direct determinant
  ld_direct <- as.numeric(determinant(P_eng, logarithm = TRUE)$modulus)
  cat("C3b log_det_precision stored =", f17(eng$log_det_precision),
      " direct =", f17(ld_direct),
      " |diff| =", f17(abs(eng$log_det_precision - ld_direct)), "\n")
  ## and against the closed form n_aug*log(scale) - sum(log(edge_length))
  ld_closed <- n_aug*log(scale) - sum(log(el))
  cat("C3c closed form =", f17(ld_closed), " |diff vs stored| =",
      f17(abs(ld_closed - eng$log_det_precision)), "\n")

  invisible(list(d1 = d1, d2 = d2, d3 = abs(lp_inc - lp_mvn)))
}

t1 <- ape::rcoal(6)
t1$tip.label <- paste0("sp", 1:6)
r1 <- report(t1, "rcoal(6)")

t2 <- ape::rcoal(12)
t2$tip.label <- paste0("x", 1:12)
r2 <- report(t2, "rcoal(12)")

## a star phylogeny: every tip a direct child of the root -> NO internal nodes
t3 <- ape::stree(7, type = "star")
t3$edge.length <- rep(1, nrow(t3$edge))
t3$tip.label <- paste0("s", 1:7)
r3 <- report(t3, "star(7)")

cat("\n===== SUMMARY =====\n")
for (nm in c("rcoal(6)", "rcoal(12)", "star(7)")) {
  r <- switch(nm, "rcoal(6)" = r1, "rcoal(12)" = r2, "star(7)" = r3)
  cat(sprintf("%-10s C1=%s  C2=%s  C3=%s\n", nm, f17(r$d1), f17(r$d2), f17(r$d3)))
}
