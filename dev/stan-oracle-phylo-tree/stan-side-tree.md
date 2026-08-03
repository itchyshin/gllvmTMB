# Stan-side note — augmented-node phylogenetic oracle (`gllvm_phylo_tree.stan`)

**Companion to** `dev/stan-oracle-phylo-tree/gllvm_phylo_tree.stan`, implementing
`dev/stan-oracle-phylo/model-spec-phylo.md` **section 8.5** (the augmented-node /
tree-native variant), as distinct from `dev/stan-oracle-phylo/gllvm_phylo.stan`, which
implements section 8.1 (tips-only, dense correlation matrix).

Author role: Noether (math-vs-specification alignment). Date: 2026-08-03.

---

## 1. Interface contract

Every data field in `gllvm_phylo_tree.stan`, in declaration order.

| field | type | dimension | meaning | indexing / convention | assumption |
|---|---|---|---|---|---|
| `N` | `int` | scalar | number of long-format rows | 1-indexed rows $i=1,\dots,N$ | spec §1 |
| `n_t` | `int` | scalar | number of traits, spec's $T$ | 1-indexed $t=1,\dots,n_t$ | renamed only because `T` is a Stan reserved word (truncation syntax); identical role to `gllvm_phylo.stan`'s `n_t` |
| `S` | `int` | scalar | number of species / tree tips, spec's $S$ | 1-indexed $s=1,\dots,S$ | unchanged from spec §1 / §8.1 |
| `K` | `int` | scalar | phylogenetic latent rank, spec's $K$ (`d`) | 1-indexed $k=1,\dots,K$ | unchanged |
| `tt` | `array[N] int`, $1\le\texttt{tt}[i]\le n_t$ | $N$ | trait index $t(i)$ of row $i$ | unchanged from §8.1 |
| `ss` | `array[N] int`, $1\le\texttt{ss}[i]\le S$ | $N$ | species index $s(i)$ of row $i$ | **also** the row of `a_node` holding species $s(i)$'s tip value (see below) | tips occupy `a_node` rows $1,\dots,S$ in the same order as the species factor levels that produced `ss` |
| `y` | `vector` | $N$ | response | unchanged |
| `n_node` | `int` | scalar | $\lvert\mathcal V\rvert$, the number of **non-root** nodes (tips + non-root internal nodes) | — | for a rooted, fully bifurcating tree with $S$ tips, $n_\text{node}=2S-2$ (§3 below); **not asserted as a Stan constraint** — the model only needs "one parent, one branch length per non-root node," which holds for any rooted topology, so `n_node` is accepted as supplied |
| `parent` | `array[n_node] int`, $0\le\texttt{parent}[v]\le n_\text{node}$ | $n_\text{node}$ | index of node $v$'s parent among the non-root nodes | `parent[v] == 0` is the **sentinel** for "$v$'s parent is the root" | **no ordering requirement** (e.g. `parent[v] < v`) — the Stan code looks up `a_node[parent[v], k]` directly and never recurses, so any acyclic parent map is fine computationally; the tree must still be a genuine rooted tree (single root, no cycles) for the result to be the density claimed in §2 — this is **not checked** by Stan and is the caller's responsibility |
| `branch_len` | `vector`, $\ge 0$ | $n_\text{node}$ | branch length $b_v$ of the edge from $v$ up to `parent[v]` | — | **pre-scaled**: supplied already on the scale where root-to-tip depth $=1$ for every tip (spec §8.5's own phrasing); this file performs **no** rescaling. See the flagged caveat in §5 about what this assumes of the tree |

**Parameters** (identical role to `gllvm_phylo.stan` except `a_node` replaces `G`):

| field | type | dimension | meaning |
|---|---|---|---|
| `mu` | `vector` | $n_t$ | trait intercepts, spec §6, unconstrained |
| `Lambda` | `matrix` | $n_t\times K$ | phylogenetic loadings, spec §6–§7; **plain unconstrained matrix**, no triangular/positive-diagonal Stan type (§7.2 forbids it — it would change the measure) |
| `sigma_eps` | `real`, $>0$ | scalar | shared residual SD, spec §2 |
| `a_node` | `matrix` | $n_\text{node}\times K$ | the augmented latent BM node values $a_{vk}$, spec §8.5. Rows $1,\dots,S$ = tips (row $s$ = species $s$'s score); rows $S+1,\dots,n_\text{node}$ = non-root internal nodes, in whatever fixed order matches `parent`/`branch_len`. Held fixed for the joint-density check (spec §0); not integrated out. |

**Root encoding — the one genuinely free design choice, stated plainly:** the root itself
is not a row of `a_node`, is not data, and is not a parameter — it is the literal
constant $0$ used inline wherever `parent[v] == 0`. This mirrors $a_{\text{root},k}\equiv0$
in §8.5 exactly and avoids ever materialising a value for a node that the spec defines as
degenerate.

**Why no `tip_node` map is needed:** because I chose "tips = rows $1,\dots,S$ of `a_node`,
same order as the species factor levels," `ss[i]` (already required for the data term)
doubles as the tip-row index. An implementation that numbers nodes differently (e.g. tips
interleaved with internal nodes in postorder) would need an explicit `tip_node[S]` map;
this file's caller must instead present `a_node`, `parent`, and `branch_len` in the
row order this file assumes, or add a permutation step before calling it.

---

## 2. Derivation

### 2.1 Setup

Fix one latent axis $k$. Write $\mathcal V=\{1,\dots,n_\text{node}\}$ for the non-root
nodes, $p:\mathcal V\to\{0,1,\dots,n_\text{node}\}$ the parent map ($p(v)=0$ meaning "parent
is the root"), and $b_v=\texttt{branch\_len}[v]>0$. Per model-spec-phylo.md §8.5,

$$
a_{v,k}\mid a_{p(v),k}\ \sim\ \mathcal N\bigl(a_{p(v),k},\,b_v\bigr),\qquad a_{\text{root},k}\equiv 0,
$$

independently across $k$, with $\mathcal N(a,b)$ taking $b$ as a **variance** (the
document-wide notation convention, model-spec.md §2 / model-spec-phylo.md §2, carried
into §8.5's own display). Unrolling the recursion from any $v$ up to the root,

$$
a_{v,k}=\sum_{w\,\preceq\, v}\varepsilon_{w,k},\qquad \varepsilon_{w,k}\stackrel{\text{ind}}{\sim}\mathcal N(0,b_w),
$$

where $w\preceq v$ means "$w=v$ or $w$ is an ancestor of $v$" (the root contributes the
fixed $0$ and is excluded from the sum). This is a **linear** map of the jointly
independent Gaussian vector $\varepsilon_{\cdot k}=(\varepsilon_{v,k})_{v\in\mathcal V}$, so
$a_{\cdot k}$ is itself multivariate normal, mean $\mathbf 0$, with some covariance
$A_\text{aug}\in\mathbb R^{n_\text{aug}\times n_\text{aug}}$ ($n_\text{aug}:=\lvert\mathcal
V\rvert=n_\text{node}$ — the same object, spec-symbol vs. Stan-field name):

$$
a_{\cdot k}\ \sim\ \mathcal N_{n_\text{aug}}\bigl(\mathbf 0,\ A_\text{aug}\bigr).
$$

### 2.2 The two expressions for the same density

**(A) Standard MVN form.** By definition of the multivariate normal density,

$$
\log p(a_{\cdot k}) = -\tfrac12\Bigl(n_\text{aug}\log(2\pi)+\log\lvert A_\text{aug}\rvert+a_{\cdot k}^\top A_\text{aug}^{-1}a_{\cdot k}\Bigr). \tag{A}
$$

**(B) Chain-rule / Markov-factorisation form.** The recursive definition of $a_{\cdot k}$
*is* its generative order, so the joint density factors as the product of the local
conditionals (the defining property of a directed Gaussian graphical model /
Bayesian network — not an extra assumption, just the chain rule applied along the tree):

$$
p(a_{\cdot k})=\prod_{v\in\mathcal V}p\bigl(a_{v,k}\mid a_{p(v),k}\bigr),\qquad
p\bigl(a_{v,k}\mid a_{p(v),k}\bigr)=\phi\bigl(a_{v,k};\,a_{p(v),k},\,b_v\bigr),
$$

with $\phi(\cdot;m,b)$ the univariate normal density, mean $m$, **variance** $b$. Taking logs,

$$
\log p(a_{\cdot k}) = \sum_{v\in\mathcal V}\left[-\tfrac12\log(2\pi)-\tfrac12\log b_v-\frac{(a_{v,k}-a_{p(v),k})^2}{2b_v}\right]. \tag{B}
$$

This is **exactly** model-spec-phylo.md §8.5's boxed display, and exactly what
`gllvm_phylo_tree.stan`'s `model` block computes (the `target += normal_lpdf(a_node[v,k] |
a_parent_val, sqrt(branch_len[v]))` loop, summed over $v$ and $k$; `sqrt(branch_len[v])`
converts the variance $b_v$ to the SD `normal_lpdf` wants).

**(A) and (B) are both, by construction, $\log p(a_{\cdot k})$ for the same random
vector** — so they are equal as real numbers, for every fixed $(b_v)_{v\in\mathcal V}$ and
every fixed $a_{\cdot k}$:

$$
\boxed{\ \sum_{v\in\mathcal V}\left[-\tfrac12\log(2\pi)-\tfrac12\log b_v-\frac{(a_{v,k}-a_{p(v),k})^2}{2b_v}\right]
= -\tfrac12\Bigl(n_\text{aug}\log(2\pi)+\log\lvert A_\text{aug}\rvert+a_{\cdot k}^\top A_\text{aug}^{-1}a_{\cdot k}\Bigr).\ }
$$

This is the identity the task asked me to exhibit. Summing over $k=1,\dots,K$
(independence across axes, §8.5) and writing $a\in\mathbb R^{n_\text{aug}\times K}$ for the
full `a_node` matrix, the total phylogenetic term is

$$
\sum_{k=1}^K\log p(a_{\cdot k}) = -\frac{n_\text{aug}K}{2}\log(2\pi)-\frac K2\log\lvert A_\text{aug}\rvert-\frac12\operatorname{tr}\!\bigl(a^\top A_\text{aug}^{-1}a\bigr),
$$

which mirrors model-spec-phylo.md §8.1's "(G) block written compactly"
($-\tfrac{SK}2\log2\pi-\tfrac K2\log|A|-\tfrac12\operatorname{tr}(G^\top A^{-1}G)$) with
$A\to A_\text{aug}$, $S\to n_\text{aug}$, $G\to a$ — the same object, larger sample space,
per §8.5's framing ("same model, different sample space").

**I do not derive $A_\text{aug}$'s closed form** beyond what is needed above (only its
*existence*, from linearity), because that closed form is exactly the object the package
is documented as building internally (§8.5's citation of the Hadfield–Nakagawa sparse
$A_\text{phy}^{-1}$); deriving it independently is useful (§2.3) but not required for
correctness of the Stan file, which never forms $A_\text{aug}$ or its inverse at all — it
only ever evaluates univariate normal log-densities.

### 2.3 Supplementary: why the precision is sparse, and a closed form for $\log|A_\text{aug}|$

Not required by the task, but a useful independent check, and it explains *why* the
Hadfield–Nakagawa precision (cited, not used, in model-spec-phylo.md §8.5) is sparse,
purely from the recursion above — without reading any implementation.

Fix any topological order of $\mathcal V$ in which every node follows its parent (e.g. a
preorder traversal from the root; this order is used only for this closed-form argument,
**not** required of the data as supplied to Stan — §2.1's argument and the Stan code both
work with `parent` in any order). Let $L_{vw}=1$ if $w\preceq v$ ($w=v$ or $w$ an ancestor
of $v$), else $0$; under the chosen order $L$ is unit lower-triangular. Unrolling the
recursion, $a_{\cdot k}=L\varepsilon_{\cdot k}$ with $\varepsilon_{\cdot k}\sim\mathcal
N(0,D)$, $D=\operatorname{diag}(b_v)_{v\in\mathcal V}$, so $A_\text{aug}=LDL^\top$ and

$$
\log\lvert A_\text{aug}\rvert = \log\lvert L\rvert^2+\log\lvert D\rvert = \sum_{v\in\mathcal V}\log b_v \qquad(\lvert L\rvert=1,\text{ unit triangular}).
$$

Inverting the recursion directly, $\varepsilon_{v,k}=a_{v,k}-a_{p(v),k}$, so $L^{-1}$ has
at most one off-diagonal nonzero per row (a $-1$ at column $p(v)$, absent when $p(v)=$
root), giving

$$
A_\text{aug}^{-1}=L^{-\top}D^{-1}L^{-1}=\sum_{v\in\mathcal V}\frac1{b_v}\bigl(e_v-e_{p(v)}\bigr)\bigl(e_v-e_{p(v)}\bigr)^\top
\qquad(e_{p(v)}:=\mathbf 0\text{ when }p(v)=\text{root}),
$$

a sum of rank-one terms each supported on $\{v,p(v)\}$ — i.e. $A_\text{aug}^{-1}$ is nonzero
only on the diagonal and at tree edges: the **sparse, graph-Laplacian-like precision**
model-spec-phylo.md §8.5 attributes to Hadfield & Nakagawa (2010). Cross-checking against
§2.2: $a^\top_{\cdot k}A_\text{aug}^{-1}a_{\cdot k}=\sum_v(a_{vk}-a_{p(v)k})^2/b_v$ and
$\log|A_\text{aug}|=\sum_v\log b_v$ reproduce (A) term-for-term from (B) directly, an
independent check that the two routes agree.

A further consequence, also not stated in model-spec-phylo.md (which gives no closed form
for $\log|A_\text{aug}|$): the tip sub-block of $A_\text{aug}$ (rows/columns
$1,\dots,S$ under this file's node-indexing convention) is, by the ordinary marginalisation
property of the multivariate normal (take the relevant sub-covariance, no adjustment), the
same object as the tips-only $A$ of spec §5/§8.1 — **provided** the branch-length scaling
assumption of §1/§5 below holds. This is the formal link between this file and
`gllvm_phylo.stan`; it rests on standard Brownian-motion-on-a-tree theory (Felsenstein
1985), not on anything read from the implementation.

---

## 3. Node count

**Claim (model-spec-phylo.md §8.5):** for a rooted, fully bifurcating tree with $S$ tips,
$\lvert\mathcal V\rvert = 2S-2$ non-root nodes, or $2S-1$ **including** the root.

**Arithmetic.** "Fully bifurcating" means every internal node has exactly 2 children. Let
$I$ = number of internal nodes (root included), so total nodes $=S+I$. A tree on $S+I$
nodes has exactly $S+I-1$ edges. Every edge is the single edge from a node down to one of
its children, and every internal node contributes exactly 2 such edges (bifurcating, no
degree-1 "pass-through" internal nodes), so edges $=2I$ as well. Equating,

$$
S+I-1 = 2I \quad\Longrightarrow\quad I = S-1,
$$

so total nodes $=S+I=S+(S-1)=2S-1$. The root is one specific internal node; removing it
leaves

$$
\lvert\mathcal V\rvert = (2S-1)-1 = 2S-2
$$

non-root nodes — matching the spec exactly. Of these, $S$ are tips and
$(2S-2)-S=S-2$ are non-root internal nodes (check: $S+(S-2)=2S-2$ ✓.). Edges = non-root
nodes, since every non-root node has exactly one edge to its parent, so $n_\text{node}$
(this file's node count, "one parent + one branch length per row") $=\lvert\mathcal
V\rvert=2S-2$ **is also the edge count** — the natural quantity for a Stan `parent`/
`branch_len` pair to index.

**Root inclusion, stated plainly:** the root is **excluded** from $\mathcal V$, from
`n_node`, and from every row of `a_node` — it is not estimated, not stored, and enters the
model only as the literal constant $0$ substituted via the `parent[v] == 0` sentinel.
Including the root would give $2S-1$, the number sometimes quoted for "total nodes"; this
file's `n_node` is always the non-root count, $2S-2$ for a bifurcating tree.

**Generality beyond bifurcating trees.** `gllvm_phylo_tree.stan` does not hard-code
$n_\text{node}=2S-2$ anywhere — the Stan computation only needs "one parent index and one
branch length per non-root node," which holds for a tree with any per-node branching
factor (a polytomy just means several $v$ share the same `parent[v]`). The $2S-2$ figure
is specific to the fully-bifurcating case the spec derives it for and is the number
`n_node` will equal *if* the supplied tree is fully resolved; for a tree with polytomies,
`n_node` will be smaller than $2S-2$ (fewer internal nodes) and the Stan file still
computes the correct density for whatever topology `parent`/`branch_len` actually encode.

---

## 4. Fence declaration

**Files read in full, and relied on:**

- `dev/stan-oracle-phylo/model-spec-phylo.md` — the primary source; read in full
  (all of sections 0–12).
- `dev/stan-oracle-phylo/gllvm_phylo.stan` — Arc 1's tips-only model; read in full, as the
  designated style/structure template.
- `dev/stan-oracle/model-spec.md` — the Arc 0 ordinary-Gaussian spec; read in full, for the
  inherited data-layout / observation-model / linear-predictor / theta conventions that
  carry through sections 1–7 unchanged.

**Directory listings only (filenames/sizes, no content):** `ls -la` on
`dev/stan-oracle-phylo/` and `dev/stan-oracle/` to see what files exist in each directory
(needed to locate the permitted files above and to avoid stepping on the forbidden ones by
accident). This surfaced filenames such as `reconciliation-phylo.md`,
`tmb-side-phylo.R`/`.md`, `stan-side-phylo.R`/`.md`, `gauss-reconcile-phylo*.R/.json`,
`tmb-fixture-phylo.json/.rds`, and, on the Arc 0 side, `gllvm_ordinary.stan`,
`reconciliation.md`, `tmb-side.R`/`.md`, `stan-side.R`/`.md`, and the `gauss-reconcile*` /
`tmb-fixture*` files — **none of these were opened; only their names and byte sizes were
seen.**

**One additional line-count-only command, disclosed for full transparency:** `wc -l` was
run on four files' line counts, including `dev/stan-oracle/gllvm_ordinary.stan` (85 lines)
and `dev/stan-oracle-phylo/gllvm_phylo.stan` (108 lines — itself a fully permitted file).
`wc -l` on `gllvm_ordinary.stan` returned only a line count; **no line of that file's text
was displayed to or read by me**, and it played no role in any modelling decision here —
every convention this file reuses from "Arc 1's style" (loop-based `eta` construction,
`_lpdf`/`target +=` throughout, unconstrained plain-matrix `Lambda`, the naming pattern
`n_t` for the trait count) is drawn from `gllvm_phylo.stan`, which is on the permitted
list, not from `gllvm_ordinary.stan`. I list the `wc -l` call here because full disclosure
of every command touching a file under `dev/stan-oracle/` costs little and the fence's
value depends on that discipline, not because I believe it crossed the fence: a byte count
carries no information about the file's mathematical or code content.

**Explicitly NOT opened, at any point:** `src/gllvmTMB.cpp` or anything else under `src/`;
`R/fit-multi.R`, `R/phylo-tree-precision.R`, `R/va-r3-proto.R`, `R/eva-proto.R`,
`R/brms-sugar.R`; `dev/stan-oracle-phylo/reconciliation-phylo.md`;
`dev/stan-oracle-phylo/tmb-side-phylo.R`, `tmb-side-phylo.md`, `stan-side-phylo.R`,
`stan-side-phylo.md`; `dev/stan-oracle-phylo/gauss-reconcile-phylo.R`,
`gauss-reconcile-phylo-k2.R`, and every `.json`/`.rds` fixture under
`dev/stan-oracle-phylo/`; every file under `dev/stan-oracle/` except `model-spec.md`.

---

## 5. What this model does not cover

Scope is inherited from model-spec-phylo.md §8.5, which is itself scoped to the same
model as §8.1 on a different sample space. Concretely, out of scope:

- **`unique = TRUE` / the $\Psi_\text{phy}$ diagonal companion.** This file is
  loadings-only (spec §3 point 3, §7); adding it would add a third density term (an
  independent per-tip-per-trait block) that this file does not implement.
- **Non-Gaussian families.** The observation model is `gaussian()`, identity link (spec
  §2), unchanged from §8.1.
- **Covariates beyond the trait intercepts.** `0 + trait` only (spec §1, §3); the
  `0 + trait + (0 + trait):x` extension is noted in the spec as leaving §4–§8 unchanged but
  is not implemented here.
- **A free phylogenetic scale parameter.** No $\sigma^2_\text{phy}$ (or equivalent
  branch-length-rescaling parameter) multiplies `branch_len`; per spec §4.3/§5 (tips-only)
  and this note's parameters-block comment (augmented case), any such parameter would be
  exactly non-identified against `Lambda`.
- **The $K<T$ gate and the lower-triangular/positive-diagonal $\Lambda$ convention** are
  documented requirements/conventions (spec §7) but are **not** encoded as Stan
  constraints, by design (§7.2: encoding them would change the measure being compared).
- **Non-ultrametric branch-length rescaling.** The "root-to-tip depth $=1$" convention
  (§1) is achievable by a single global rescaling only when every tip already has equal
  root-to-tip path length (an ultrametric tree). model-spec-phylo.md §8.5 states the
  convention but does not address the non-ultrametric case. This file assumes the supplied
  `branch_len` already satisfies the convention; if it does not (a non-ultrametric input
  tree rescaled only globally), the tip sub-block of the induced $A_\text{aug}$ will **not**
  have unit diagonal and will not equal an `ape::vcv(tree, corr = TRUE)`-style correlation
  matrix. Reconciling that case is not attempted here.
- **Data validation.** Stan does not check that `parent`/`branch_len` encode a genuine
  single-rooted, acyclic tree of exactly `n_node` non-root nodes; a malformed input (a
  cycle, an orphaned subtree, a `parent` value that is never itself a valid node) will not
  raise an error and will silently evaluate a density for whatever graph was supplied. This
  is the caller's responsibility.
- **Which representation the real target uses.** This file presupposes that OPEN item 1 of
  model-spec-phylo.md §12 (tips-only vs. augmented) resolves to "augmented" for whatever it
  is compared against; it is written as option (b) of §8.5's three-way fallback ("implement
  §8.5 in Stan too... this is oracle work, not source-reading"). If the comparison target
  turns out to be tips-only after all, `gllvm_phylo.stan` (§8.1) is the applicable oracle,
  not this file.
- **Alignment of species factor levels to node order**, inherited unresolved exactly as
  spec §12 item 3 states it for the tips-only case: this file assumes `ss[i]` and the tip
  rows of `a_node` are aligned by the caller; a silent permutation mismatch would not be
  detected.
