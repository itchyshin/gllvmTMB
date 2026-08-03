// gllvm_phylo_tree.stan
//
// Independent Stan oracle for the AUGMENTED-NODE variant of the phylogenetic
// reduced-rank latent Gaussian GLLVM, long format, loadings-only:
//
//     value ~ 0 + trait + phylo_latent(species, d = K, unique = FALSE)
//
// Implements EXACTLY the joint log-density of
//   dev/stan-oracle-phylo/model-spec-phylo.md  section 8.5
// -- the Markov / increment factorisation of Brownian motion over ALL
// non-root tree nodes -- NOT section 8.1 (the tips-only dense-correlation-
// matrix form implemented by dev/stan-oracle-phylo/gllvm_phylo.stan). The two
// files are the SAME model on DIFFERENT sample spaces (spec s.0, s.8.5) and
// must never be conflated or have their fixed inputs transported directly.
//
// Sections 1-3 and 6-7 of the spec (data layout, observation model, linear
// predictor, fixed parameters theta, Lambda's rotation convention) are
// UNCHANGED from section 8.1 and are reproduced here in the same structure
// as gllvm_phylo.stan; ONLY the phylogenetic latent block differs, per this
// task's instruction to make the two files differ ONLY in that block.
//
// CRITICAL DESIGN CONSTRAINT (the whole point of this file): it NEVER takes a
// covariance matrix, a precision matrix, or a Cholesky factor of either as
// data for the phylogenetic prior. That prior is built entirely from a
// parent-index array and a branch-length vector -- FROM THE TREE -- via the
// Markov/increment factorisation of spec s.8.5. See the companion note
// dev/stan-oracle-phylo-tree/stan-side-tree.md for: the full interface
// contract; the derivation that the sum of per-node normal_lpdf terms below
// equals the standard -1/2*(n*log(2pi) + log|A_aug| + quadratic form) MVN
// form; the node-count arithmetic; and the fence declaration.
//
// Derived only from model-spec-phylo.md section 8.5 (plus sections 1-8.1 for
// the unchanged surrounding model) and dev/stan-oracle-phylo/gllvm_phylo.stan
// as a style/structure template. No file under src/, no TMB-building R file,
// no reconciliation file, and no tmb-side file was read.
//
// NOTE ON NAMING: the spec calls the number of traits `T`. `T` is reserved in
// the Stan language (truncation syntax `T[a, b]`), so it is spelled `n_t`
// here, exactly as in gllvm_phylo.stan. The augmented node-value matrix is
// spelled `a_node` (lower-case) rather than a capitalised single letter,
// DELIBERATELY: this file must never expose anything that reads as the
// forbidden object "A" (the tips-only phylogenetic correlation matrix of
// spec s.5/s.8.1) -- see the companion note for why that matters.

data {
  // ---- long-format data (spec sections 1-2; UNCHANGED from section 8.1) --
  int<lower=1> N;                          // long-format rows
  int<lower=2> n_t;                        // traits          (spec: T)
  int<lower=1> S;                          // species / tips  (spec: S)
  int<lower=1> K;                          // phylo latent rank (spec: K = d)

  array[N] int<lower=1, upper=n_t> tt;     // trait   index t(i) of row i
  array[N] int<lower=1, upper=S>   ss;     // species index s(i) of row i --
                                           // ALSO the row of a_node holding
                                           // that species' TIP value, under
                                           // the node-indexing convention
                                           // below (no separate tip map).
  vector[N] y;                             // response

  // ---- augmented-node tree structure (spec section 8.5) -------------------
  //
  // NODE-INDEXING CONVENTION (chosen here; NOT read from, or matched to, any
  // R-side object -- the task instructs designing this from the mathematics
  // alone):
  //   * Rows 1..S        of a_node (declared below) are the TIPS, in the SAME
  //     order as the species levels that produced `ss[i]` above -- i.e. tip
  //     node index == species index, so no separate tip-to-node map is
  //     needed.
  //   * Rows S+1..n_node  are the NON-ROOT INTERNAL nodes, in any fixed order
  //     (the order only has to agree across `parent` and `branch_len`;
  //     nothing below assumes a particular tree traversal).
  //   * The ROOT is NOT a row of a_node at all: its value is fixed at 0
  //     (spec s.8.5, "a_{root,k} = 0") and is never estimated or stored.
  //     `parent[v] == 0` is the sentinel meaning "v's parent IS the root".
  //
  // n_node = |V|, the number of NON-ROOT nodes (tips + non-root internal;
  // spec s.8.5's V). For a rooted, fully bifurcating tree with S tips,
  // n_node = 2*S - 2 (companion note s.3 derives this arithmetic). That
  // count is NOT hard-coded or asserted here: the computation below only
  // needs "one parent and one branch length per non-root node", which holds
  // for any rooted tree topology, bifurcating or not -- n_node is simply
  // supplied as data.
  int<lower=1> n_node;

  // parent[v]: index (1..n_node) of node v's parent AMONG THE NON-ROOT NODES,
  // or 0 if v's parent is the root itself (see convention above). No
  // ordering requirement such as "parent[v] < v" is imposed or needed: the
  // density below only ever looks up a_node[parent[v], k] or substitutes the
  // fixed constant 0 for the root; it never recurses and needs no
  // topological sort to be evaluated (a topological order is used only in
  // the companion note's supplementary closed-form derivation, not here).
  array[n_node] int<lower=0, upper=n_node> parent;

  // Branch length b_v from node v up to parent[v] (spec s.8.5): the
  // ELAPSED-TIME / VARIANCE contribution of that edge under Brownian motion.
  // ASSUMED already scaled so root-to-tip depth = 1 for every tip -- spec
  // s.8.5's own phrasing ("branch length b_v on the same scale that makes
  // root-to-tip depth 1"), carrying over the s.5 identifiability fiat that
  // fixes the global BM-rate/Lambda scale confound to the tree-native
  // representation. NOT rescaled by this file -- exactly as gllvm_phylo.stan
  // takes L_A pre-built and never re-derives it from the tree. See the
  // companion note for the (flagged) ultrametric-tree caveat this carries.
  vector<lower=0>[n_node] branch_len;
}

parameters {
  // ---- theta (spec section 6; UNCHANGED from section 8.1) ----------------
  vector[n_t] mu;                          // trait-specific intercepts, 0 + trait
                                           // unconstrained; no reference level

  matrix[n_t, K] Lambda;                   // phylogenetic loadings, T x K.
                                           // DELIBERATELY an unconstrained plain
                                           // matrix: spec section 7.2 forbids
                                           // imposing the lower-triangular /
                                           // positive-diagonal ROTATION CONVENTION
                                           // as a constrained Stan type, because
                                           // that would change the measure and
                                           // hence the density being compared.

  real<lower=0> sigma_eps;                 // residual SD, ONE scalar shared across
                                           // all traits and all rows (spec s.2)

  // NOTE: there is NO psi block. unique = FALSE is loadings-only (spec s.3.3),
  // and there is NO free phylogenetic variance/scale parameter (spec s.4.3):
  // it would be exactly non-identified against Lambda -- the identical
  // argument applies unchanged to a free scale on branch_len (see companion
  // note): rescaling branch_len by any c > 0 is exactly confounded with
  // Lambda -> sqrt(c) * Lambda, so the scale must be fixed by convention
  // (the root-to-tip-depth-1 fiat above), never estimated.

  // ---- augmented-node latent block, held fixed for the oracle check -------
  // (spec section 0: the joint check is HIERARCHICAL; latent values are an
  // explicit block and are NEVER integrated out.)
  //
  // THIS is the ONLY block that differs from gllvm_phylo.stan: there, G is
  // S x K (tips only, spec s.8.1). Here, a_node is n_node x K (tips AND
  // non-root internal nodes) -- the augmented representation of spec s.8.5.
  matrix[n_node, K] a_node;
}

model {
  // ---- linear predictor (spec section 3; UNCHANGED from section 8.1) -----
  // eta_i = mu_{t(i)} + lambda_{t(i)}' g_{s(i)}, with g_{s(i)} read off the
  // TIP rows of a_node (rows 1..S), per the indexing convention above.
  vector[N] eta;
  for (i in 1:N) {
    eta[i] = mu[tt[i]] + dot_product(Lambda[tt[i]], a_node[ss[i]]);
  }

  // ---- (D) data / Gaussian observation term, N terms ---------------------
  // y_i ~ N(eta_i, sigma_eps^2); Stan takes an SD, so sigma_eps directly.
  target += normal_lpdf(y | eta, sigma_eps);

  // ---- (G-tree) augmented-node phylogenetic term, spec section 8.5 -------
  // The Markov/increment factorisation of Brownian motion over the tree:
  //     a_{v,k} | a_{parent(v),k} ~ N(a_{parent(v),k}, branch_len[v]),
  //     a_{root,k} == 0,
  // independently across k = 1..K and across the n_node non-root nodes v
  // (spec s.8.5's boxed display). branch_len[v] is a VARIANCE -- the
  // document-wide convention that N(a, b) takes b as a variance (spec s.2;
  // confirmed by s.8.5's own log-density display, whose -1/2 log(b_v) term
  // is exactly -log(SD) for SD = sqrt(b_v)) -- so the Stan SD argument is
  // sqrt(branch_len[v]): the identical variance-to-SD conversion pattern
  // used for psi in Arc 0 (model-spec.md s.4.2/s.7.2) and here applied to
  // the branch-length scale.
  for (k in 1:K) {
    for (v in 1:n_node) {
      real a_parent_val;
      if (parent[v] == 0) {
        a_parent_val = 0;                  // parent is the root, fixed at 0
      } else {
        a_parent_val = a_node[parent[v], k];
      }
      target += normal_lpdf(a_node[v, k] | a_parent_val, sqrt(branch_len[v]));
    }
  }

  // No priors. No Jacobian adjustments. No third density term: spec s.8.5 is
  // the SAME model as s.8.1, which has exactly 2 density terms -- (D) and one
  // latent block -- here factored into n_node * K univariate pieces instead
  // of K multivariate ones (companion note s.2 shows the two are the same
  // number).
}

generated quantities {
  // Reporting only; never used in the density (spec section 4.3, unchanged
  // by which latent parameterisation is used -- s.8.5 is the SAME model as
  // s.8.1, just a different sample space for the latent block).
  // Loadings-only: Sigma_phy = Lambda Lambda', singular of rank K < T.
  matrix[n_t, n_t] Sigma_phy = Lambda * Lambda';
}
