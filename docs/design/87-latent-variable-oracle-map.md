# Design 87 — The latent-variable oracle map: what an external package can and cannot settle

**Maintained by:** Jason (cross-package / literature scout), Rose (scope honesty).
**Status:** Decision document. Closes items 2 and 3 of
[issue #800](https://github.com/itchyshin/gllvmTMB/issues/800) — "Scope a
`gllvm` comparison harness — no corpus exists to adopt" and "Decide which
latent-variable cases can have any external reference, and state plainly
which cannot." Dated 2026-08-02. Decides nothing about implementation order;
records what is and is not possible.
**Numbering note:** Designs 81–82 are unused and 83–86 are already allocated
to multinomial and high-dimensional VA work (`83-multinomial-response-family.md`,
`84-phylogenetic-multinomial-tier2.md`, `85-highdim-nongaussian-va-formal-contract.md`,
`86-eva-gate1-parameters.json`). This document is therefore Design 87.
**Naming correction (2026-08-02):** this document originally used `scalar`
as if it were a fifth co-equal mode alongside `indep`/`dep`/`latent`. Per
Design 79 §5/§5.1, `scalar` is not a mode at all — it is the soft-deprecated
spelling of the `common = TRUE` parsimony modifier on `indep` (and
source-specific `phylo_indep(common = TRUE)`, `animal_indep(common =
TRUE)`, `spatial_indep(common = TRUE)`, `kernel_indep(common = TRUE)`).
Every mention below is corrected accordingly; `*_scalar()` is kept only
where explicitly flagged as the deprecated alias. §1 restates the cell
count under the corrected terminology (the total, 20, is unchanged — only
the vocabulary is). No verdict (which cells have an oracle, which are
NONE) changed; §1 and §6 also gained clarifying qualifiers where the old
"`indep`" wording had become ambiguous between the `common = TRUE` and
default (`common = FALSE`) sub-cases.
**Backed by:** direct inspection of installed `gllvm` 2.0.13 (`NAMESPACE`,
`tools::Rd_db`, vignettes 7 and 9, one fresh diagnostic fit run this session);
`tests/testthat/test-comparator-gllvm.R`; `dev/s2-gllvm-colmat-reference.R` +
`-RESULTS.md`; `dev/s7-gllvm-comparator-RESULTS.md`; `dev/s9-binary-comparator-RESULTS.md`;
`docs/design/05-testing-strategy.md`; `docs/design/54-cross-package-scout-protocol.md`;
`docs/design/79-covariance-mode-taxonomy.md`; `docs/design/72-variational-approximation-feasibility.md`;
`docs/design/04-sister-package-scope.md`; `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`;
installed `MCMCglmm` and `galamm` NAMESPACEs/`Rd_db`.

---

## 0. Verification ledger

Evidence tags used throughout: **[V]** verified first-hand this session
(ran or read directly); **[V-prior]** established by a prior artifact in
this repo, cited, not re-derived; **[R]** recall / not verified this
session or the cited artifact — treated as a lead, not a claim.

| Claim | Tag | How |
|---|---|---|
| `gllvm` 2.0.13 installed, no `testdata/` dir, 6 shipped datasets, GPL-2 | [V] | `find.package`, `list.dirs`, `data(package=)`, `DESCRIPTION` |
| `gllvm`'s 56 exports, `?gllvm` full argument list | [V] | `getNamespaceExports`, `tools::Rd_db` |
| `colMat` structures column-effect (environmental-slope) covariance only, never the `num.lv` ordination loadings | [V-prior] | `dev/s2-gllvm-colmat-reference-RESULTS.md` §A/§D (two-tree decisive test + negative controls) |
| Absent `colMat`, a `gllvm` random column effect has **one shared variance across all species, zero cross-species covariance** — i.e. structurally `indep(common = TRUE)`, never the default `indep(common = FALSE)`/`dep` | [V] | fresh fit this session (§2.3 below): `getEnvironCov()` returned a diagonal matrix with the *same* value (0.892) on every entry |
| `gllvm`'s `lvCor`/`row.eff` correlation options (`corAR1`, `corExp`, `corCS`, `corMatern`, `propto`) exist and structure the site/row axis | [V] | vignette 9 (`Correlation structures for latent variables and row effects`) read directly |
| A Poisson and a binary unconstrained-ordination `gllvm` comparator already exist, shipped, passing | [V] | read `tests/testthat/test-comparator-gllvm.R` in full |
| `gllvmTMB` is Laplace-only; VA/EVA vs Laplace log-likelihoods are not directly comparable, VA is a biased-downward ELBO | [V-prior] | `docs/design/72-variational-approximation-feasibility.md`; `docs/design/85-...md` (Laplace is the only admissible route) |
| `MCMCglmm`'s `idh`/`us`/`idv` variance functions, `pedigree`, `ginverse` arguments; its family list | [V] | `tools::Rd_db("MCMCglmm")` read directly |
| `galamm` exports `factor_loadings`, `gfam`, fits via Laplace with an explicit constraint | [V] (exports only) | `getNamespaceExports("galamm")` |
| `Hmsc` facts (licence, `TD` fixture, 4 families, phylo-on-`Beta` not on `Lambda`, spatial latent factors, posterior-mean-≠-MLE) | [V-prior] | `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`, itself tagged [V]/[A] there — not re-verified here, only cited |
| `phyr`, `sdmTMB`, `VAST` capabilities | [R] | **not installed** on this machine, not in `Suggests`; every claim about them below is explicitly marked unverified |
| `glmmTMB`'s `rr()`/`propto()`/`equalto()` comparator status (`covered`/`covered`/`partial`) | [V-prior] | `docs/design/05-testing-strategy.md` table, read directly; not re-fitted this session |
| `gllvmTMB` has no `orderedBeta`-style family; has `delta_beta`, `multinomial`, `ordinal_probit`, ~30 family constructors total | [V] | `grep` over `R/families.R` |

---

## 1. Executive summary

Per Design 79 §5, the canonical grid is **3 modes** (`indep` / `dep` /
`latent`) × **5 sources** (no-prefix / `phylo_` / `animal_` / `spatial_` /
`kernel_`) = **15 top-level cells**. `scalar` is not a fourth mode — it is
the `common = TRUE` parsimony modifier on `indep` (Design 79 §5.1); `unique`
is a separate soft-deprecated compatibility alias, diagonal-only, that
inherits `indep`'s default (`common = FALSE`) answer, as does the
`*_latent(unique = TRUE)` diagonal companion (CLAUDE.md: "Standalone
`phylo_unique`/`animal_unique` carry diagonal-only structure"). Neither
`scalar` nor `unique` is a mode of its own.

For **oracle purposes**, though, `common = TRUE` and the default `common =
FALSE` are not interchangeable inside `indep`: §2.3 shows `gllvm`'s `colMat`
mechanism reaches only `common = TRUE` (one shared variance), never the
default per-trait-distinct variances or `dep`'s free covariance. So the map
below tracks **4 oracle-relevant columns per source** —
`indep(common = TRUE)`, `indep` (default), `dep`, `latent` — for **5 × 4 =
20 structurally distinct questions**, the same total this document used
before this naming correction; only the vocabulary changes (3 canonical
modes, not 5, with `indep` counted twice for oracle purposes because its
two sub-cases have different oracle answers; `scalar` and `unique` are both
compatibility aliases that fold into `indep`, not modes of their own).

> **Counts corrected 2026-08-02.** An earlier version of this section read
> 6 / 6 / 3 / 5, which did not reconcile against §3.1's own table: the "6
> strong" bullet named only five members, and it conflated two different
> things that the table's legend distinguishes — **✓✓ = "already built and
> passing in this repo"** (a shipped comparator test) versus a mechanism
> merely *verified by a scout fit this session*. The "5 NONE" figure was also
> counting non-grid items (`meta_V()`, the compound families) that §6 lists
> but that are not cells of this 5 × 4 grid. The tally below is re-derived
> cell by cell from the table and sums to 20. **§3.1's table remains the
> authority; these are its totals, not an independent claim.**

**Of those 20 cells:**
- **2 have a shipped comparator that passes in this repo** — the only cells
  where "already built and passing" is literally true: the no-prefix
  `latent` (`test-stage2-rr-diag.R` via `glmmTMB::rr()+diag()`, **and**
  `test-comparator-gllvm.R` via `gllvm`'s unconstrained ordination), and
  `phylo_indep(common = TRUE)` (`test-stage3-propto-equalto.R` via
  `glmmTMB::propto()`).
- **5 have a verified mechanism but no comparator built**: the no-prefix
  `indep(common = TRUE)` (`gllvm` with no `colMat`, verified by the §2.3
  fit; plus `glmmTMB`/`lme4`'s shared-variance RE), the no-prefix `indep`
  and `dep` (`glmmTMB`/`lme4`'s `diag()`/`us()` — textbook), and
  `animal_indep(common = TRUE)` / `kernel_indep(common = TRUE)` (`gllvm`'s
  `colMat`, which follows from its documented behaviour; the §2.3 fit was
  run *without* `colMat`).
- **7 have a plausible but unverified reference**, six of them resting on
  `MCMCglmm`'s posterior mean rather than an MLE: the default
  (`common = FALSE`) `indep` and `dep` cells for `phylo_`, `animal_` and
  `kernel_` via `idh`/`us` + `pedigree`/`ginverse`; plus `spatial_latent`
  (`gllvm`'s `lvCor(corExp/corMatern)` and `Hmsc`'s spatial latent factors —
  neither fitted, and `lvCor` is a dense exact GP against our SPDE
  approximation, so agreement could only be approximate).
- **3 are genuinely uncertain and would need a scout before either building
  or declaring them unvalidatable**: `spatial_indep(common = TRUE)`,
  `spatial_indep` (default), `spatial_dep` — `gllvm`'s own spatial
  mechanisms (`row.eff`, `lvCor`) do not cleanly match these cells'
  definitions (§3.2), and a candidate `glmmTMB` route (`mat()`/`exp()`
  covariance structures) was not checked this session.
- **3 have NO possible external reference and must rest on known-truth
  simulation alone**: `phylo_latent`, `animal_latent`, `kernel_latent`
  (source-structured relatedness combined with reduced-rank ordination —
  no package does this). Note §6 lists more items than this under "cannot
  be externally validated" — `meta_V()` and the compound families — but
  those are **not cells of this grid**, which is why the earlier count of 5
  did not reconcile. Separately, any `*_latent(unique = TRUE)`
  diagonal companion for a structured source inherits
  `indep`'s absence of a `gllvm` oracle even where the loadings piece has
  one).
- Outside the structural grid: **phylogenetic multinomial** (Design 84,
  already partially implemented) and **`meta_V()`** known-sampling-covariance
  meta-analysis have no package-level peer at all — see §6.

**The single most useful new finding** (verified this session, not assumed):
`gllvm`'s `colMat` mechanism is **not** a general phylogenetic/animal/kernel
comparator across `indep`/`dep`/`latent` — it is a Pagel's-lambda blend on a
**single shared variance**, i.e. structurally `*_indep(common = TRUE)`
only, never the default `*_indep()` (`common = FALSE`) or `*_dep()`, for
any source. `gllvm` therefore cannot serve as the oracle for the default
(`common = FALSE`) `phylo_indep`/`phylo_dep`/`animal_indep`/`animal_dep`/
`kernel_indep`/`kernel_dep` at all — it reaches only their `common = TRUE`
sub-case; `MCMCglmm` is the correct (if weaker, posterior-mean) reference
for that default-`indep`/`dep` half of the grid.

**Top-3 comparisons worth building first**: (1) `spatial_latent` via
`gllvm`'s `lvCor(corExp/corMatern)` — same conceptual model (GP-correlated
latent scores), unbuilt, moderate confidence; (2) a `phylo_indep(common =
TRUE)`/`animal_indep(common = TRUE)` `MCMCglmm` scout to corroborate the
already-covered `gllvm`/`glmmTMB` route with a genuinely independent
(Bayesian, pedigree-native) implementation; (3) the default (`common =
FALSE`) `phylo_indep`/`animal_indep` `MCMCglmm` `idh` + `pedigree`
comparator, because it is the one place `gllvm` structurally cannot help at
all and a reference otherwise does exist.

---

## 2. `gllvm` 2.0.13: verified facts

### 2.1 No corpus to adopt

```r
> find.package("gllvm")
[1] "/Users/z3437171/Library/R/arm64/4.6/library/gllvm"
> packageVersion("gllvm")
[1] '2.0.13'
> list.dirs(find.package("gllvm"))
# data, doc, help, html, libs, Meta, R  — no testdata/, no fixtures directory
> data(package = "gllvm")$results[, "Item"]
[1] "Skabbholmen"  "beetle"  "eSpider"  "fungi"  "kelpforest"  "microbialdata"
```

Six datasets, all real ecological data (no simulated known-truth fixture).
Two are directly relevant to source-structured comparisons: `fungi` ships
`Y`, `X`, a phylogenetic `tree`, `C = ape::vcv(tree)`, and pairwise `dist`
(used in vignette 7, "Phylogenetic random effects"); `kelpforest` ships a
site/year/transect design used in vignette 9's spatial/temporal
correlation-structure example. Neither carries a *known* generating
parameter set — they are real surveys, not simulations — so they can only
support a "did both packages land on a similarly-good fit" comparison, never
a recovery claim. **A corpus genuinely does not exist to adopt; a harness
must be built** (confirms the issue's own framing).

### 2.2 The two mechanisms `gllvm` actually has for cross-species covariance

Reading `?gllvm`'s full argument list plus `?getEnvironCov.gllvm`/
`?getResidualCov.gllvm` and the S2 scout's fitted-object evidence
(`dev/s2-gllvm-colmat-reference-RESULTS.md`), `gllvm` has exactly two
routes to a cross-species covariance, and no others:

1. **`num.lv`/`num.lv.c`/`num.RR` ordination** — $\Sigma = \Theta\Theta^{\mathsf T}$
   (+ a diagonal dispersion term for families that have one). This is the
   `latent()` mode. No `colMat`/tree/pedigree can touch it — confirmed
   directly: "there is no code path connecting `colMat` to the
   `Theta Theta'` ordination covariance" (S2 §D).
2. **`colMat`-blended random column effects** on whatever term(s) sit in a
   bar-syntax `formula` (`~ (x | 1)`), with `col.eff == "random"`:
   $\Sigma_e = \mathrm{kron}(\rho C + (1-\rho)I,\ R)$, where $C$ is the
   supplied similarity matrix (tree-derived, pedigree-derived, or an
   arbitrary p.d. matrix — `gllvm` does not distinguish these three
   sources; they are the same argument) and $\rho$ is one signal parameter
   (or one per covariate term under `colMat.rho.struct = "term"`).

There is no third mechanism — no per-trait-distinct-variance,
zero-cross-trait-covariance column effect, and no free unstructured
cross-species covariance outside full-rank ordination.

### 2.3 New finding: `colMat`'s $R$ is a single shared variance, never per-species

Fit `gllvm(y = Y, X = data.frame(env), formula = ~ (0 + env | 1), num.lv = 0,
family = "poisson")` on data simulated with **8 genuinely different**
per-species slope variances/covariances (no `colMat` supplied):

```
> fit$params$sigmaB
           env
[1,] 0.8920233
> gllvm::getEnvironCov(fit)$cov
      sp1    sp2    sp3    sp4    sp5    sp6    sp7    sp8
sp1  0.892  0      0      0      0      0      0      0
sp2  0      0.892  0      0      0      0      0      0
...  (identical 0.8920233 on every diagonal entry, zero off-diagonal)
```

One scalar variance is fit and applied identically to all 8 species; there
is no per-species variance parameter and no cross-species covariance
parameter anywhere in `fit$params`, with or without `colMat`. This is
`gllvm`'s **only** column-effect covariance shape: `*_indep(common =
TRUE)` (source-blended when `colMat` is supplied, ordinary
`indep(common = TRUE)` when it is not; `*_scalar()`/`scalar()` is the
soft-deprecated alias for the same thing, Design 79 §5.1). It is
structurally incapable of representing the default `*_indep()`'s
(`common = FALSE`) per-trait-distinct-but-uncorrelated variances or
`*_dep()`'s free covariance, for any source. This was not previously stated
explicitly anywhere in this repo's `gllvm` scout material and materially
narrows what `gllvm` can be an oracle for.

### 2.4 `lvCor` and `row.eff`: a genuine but axis-shifted spatial/temporal mechanism

Vignette 9 documents `corAR1`, `corCS`, `corExp`, and `corMatern`
correlation structures, settable independently for (a) the latent-variable
scores $u_{q\cdot}$ across sites (`lvCor`) and (b) community-level row
effects (`row.eff = ~struc(1|group)`, with `dist`/`distLV` giving
coordinates). Both are genuine Gaussian-process-style mechanisms on the
row/site axis. Two caveats prevent a clean match to gllvmTMB's `spatial_*`
grid:

- **Row effects are community-shared**: `row.eff`'s realized value is added
  *identically* to every species' linear predictor — it is not "each trait
  draws from a shared-variance spatially-correlated field"
  (`spatial_indep(common = TRUE)`'s definition), it is "every trait shares
  the literal same field." This is a
  strictly different (more restrictive) model.
- **`lvCor`-on-ordination** (structure the LV scores $u_i$ by site
  coordinates, then let species-specific $\Theta_j$ loadings scale them) is
  the closer match — conceptually the same idea as `spatial_latent`
  (spatially-correlated latent factors, species-specific mixing) — but it
  uses a dense, exact `corExp`/`corMatern` covariance function rather than
  gllvmTMB's SPDE/GMRF sparse approximation, so any agreement would be
  approximate (same asymptotic GP target, different finite-sample
  approximation), not exact. **This route was not fitted or tested this
  session** — it is a plausible, moderate-confidence candidate, not a
  verified comparator, and is listed in §7 as the top build priority.

### 2.5 Families

`gllvm`'s 16 named family options: `negative.binomial`/`negative.binomial1`,
`poisson`, `binomial` (probit/logit/cloglog), `ZIB`/`ZNIB`/`ZIP`/`ZINB`,
`gaussian`, `tweedie`, `gamma`, `exponential`, `beta` (logit/probit),
`ordinal` (probit/logit), `betaH` (beta hurdle), `orderedBeta`.
`gllvmTMB`'s roughly 30 family constructors (`R/families.R`, `grep`-counted
this session) overlap directly on poisson/binomial/gaussian/gamma/
negative-binomial (`nbinom1`/`nbinom2`)/tweedie/beta/`ordinal_probit`.
`gllvmTMB` has no `orderedBeta` analogue (confirmed absent by `grep`);
`gllvm` has no analogue of `gllvmTMB`'s `multinomial()`, `delta_*` compound
families, `gengamma`/`gamma_mix`/`lognormal_mix`, `student`, or
`censored_poisson`/`truncated_poisson`. Every family-level comparison
inherits §2.6's estimator caveat regardless of overlap.

### 2.6 The VA/EVA-vs-Laplace trap

`gllvmTMB` fits by TMB Laplace approximation exclusively (`R/gllvmTMB.R`;
reaffirmed as the only admissible route by Design 85). `gllvm` defaults to
variational approximation (`method = "VA"`, falling back to `"EVA"` when VA
is not implemented for a family) and only uses Laplace (`method = "LA"`)
when explicitly requested. Design 72 (feasibility audit, this repo)
establishes that VA's ELBO is a **biased-downward** bound, not the
marginal likelihood, and explicitly states "AIC/LRT across `method = "LA"`
vs `"VA"` are NOT comparable" — VA matches Laplace point estimates only "to
~2 significant figures" and only in well-identified regimes. **A raw
log-likelihood match between a `gllvmTMB` (Laplace) fit and a default
`gllvm` (VA) fit is therefore not validating the same quantity** unless
`gllvm` is explicitly run with `method = "LA"` (available for a subset of
families) or the comparison is deliberately loosened to "did both reach a
comparably good optimum" rather than "do the numbers match." The shipped
comparator test (`test-comparator-gllvm.R`) already handles this correctly
— it uses a 1%/0.01 *relative* log-likelihood tolerance with an explicit
comment citing exactly this reasoning, not an exact-match assertion.

---

## 3. The oracle map

### 3.1 Table

Legend: **✓✓** = already built and passing in this repo; **✓** = verified
mechanism exists, not yet built as a comparator; **~** = plausible
mechanism, capability not verified this session (flagged, not asserted);
**MCMCglmm(post.)** = Bayesian posterior mean, not an MLE — a real but
weaker reference (see §3.2); **NONE** = no package can validate this cell;
simulation-only.

| source \ mode | `indep(common = TRUE)` | `indep` (default) | `dep` | `latent` |
|---|---|---|---|---|
| **no prefix** | `glmmTMB`/`lme4` shared-variance RE ✓ · `gllvm` (no `colMat`) ✓✓ (verified §2.3) | `glmmTMB`/`lme4` `diag(0+trait\|g)` ✓ — textbook | `glmmTMB`/`lme4` `us(0+trait\|g)` ✓ — textbook | `glmmTMB::rr()+diag()` ✓✓ **covered** (`test-stage2-rr-diag.R`) · `gllvm::gllvm(num.lv=)` ✓✓ **shipped** (`test-comparator-gllvm.R`, Poisson + binary) · `galamm` ~ (Laplace + explicit λ-constraint, untested here) |
| **`phylo_`** | `gllvm` `colMat` ✓✓ (verified §2.3, Pagel's-λ blend on shared variance) · `glmmTMB::propto()` ✓✓ **covered** (`test-stage3-propto-equalto.R`) | `MCMCglmm` `idh(trait):animal`+`pedigree`/`inverseA` MCMCglmm(post.) ~ (untested here) · `gllvm` **NONE** (gllvm reaches only `common = TRUE`, verified §2.3) | `MCMCglmm` `us(trait):animal`+`pedigree` MCMCglmm(post.) ~ (untested here) · `gllvm` **NONE** | **NONE** — no package puts a tree on reduced-rank ordination loadings (`gllvm`'s `colMat` cannot touch `Theta`, S2 §D; `Hmsc`'s phylo signal structures `Beta`/trait-regression, not `Lambda`, per the Hmsc audit) |
| **`animal_`** | `gllvm` `colMat` (pedigree-as-`C`) ✓✓ — same mechanism as phylo, verified · `MCMCglmm` `idv`+`pedigree` ✓ (`MCMCglmm`'s native use case) · `glmmTMB::propto()` (pedigree A) ✓ | `MCMCglmm` `idh`+`pedigree` MCMCglmm(post.) ~ (untested here, but this is literally what `MCMCglmm` was built for) | `MCMCglmm` `us`+`pedigree` MCMCglmm(post.) ~ (untested here) | **NONE** — same reasoning as `phylo_latent` |
| **`spatial_`** | `gllvm` `row.eff`/`lvCor` **mismatched** (community-shared field, not per-trait draws from a shared-variance field — §2.4); `glmmTMB` `mat()`/`exp()`+`diag()` candidate **[R], unverified** | same mismatch as `indep(common = TRUE)`; **not confidently established** either way — needs a scout, not a clean NONE | same; **not confidently established** | `gllvm` `lvCor(corExp/corMatern)` ~ (conceptually matched, exact-GP vs SPDE-approx, unbuilt — top build priority §7) · `Hmsc` `HmscRandomLevel(sDim=)` MCMCglmm/Hmsc(post.) ~ (genuine spatial-latent-factor peer per the Hmsc audit, untested here) |
| **`kernel_`** | `gllvm` `colMat` bare-matrix form ✓✓ (verified — `?gllvm`'s `colMat` doc explicitly allows "only a (p.d.) matrix of similarity," no tree/pedigree semantics required) · `MCMCglmm` `idv`+`ginverse(K)` ~ | `MCMCglmm` `idh`+`ginverse(K)` MCMCglmm(post.) ~ (untested here) · `gllvm` **NONE** | `MCMCglmm` `us`+`ginverse(K)` MCMCglmm(post.) ~ (untested here) · `gllvm` **NONE** | **NONE** — same reasoning as `phylo_latent`, no tie to any tree/pedigree assumption needed to make the point |

`unique` is not a separate column: standalone `*_unique()` is diagonal-only
and answers exactly as `indep` (default, `common = FALSE`) above; the
`*_latent(unique = TRUE)` diagonal companion inherits the same answer as
its row's `indep` cell even in rows where the loadings-only piece has a
reference (e.g. `phylo_latent`'s loadings piece is already NONE, so this
only bites materially for a hypothetical future `spatial_latent(unique =
TRUE)` or `kernel_latent(unique = TRUE)`, where the loadings piece might
have a partial reference but the +diag(ψ) piece would not). `scalar` folds
the same way, into `indep`'s `common = TRUE` sub-case (§2.3, §3.2) — like
`unique`, it is a compatibility spelling (Design 79 §5.1), not a mode of
its own.

### 3.2 Notes on the non-obvious calls

**Why `gllvm` colMat is marked NONE for the default `indep` (`common =
FALSE`) / `dep`, not just "weaker."**
This is a structural absence, verified by fitting (§2.3), not a judgement
call about fit quality. There is no argument combination, documented or
undocumented, that produces a per-species-distinct or freely-covarying
column effect in `gllvm` short of full ordination (which is a different
decomposition — rank-reduced loadings, not a same-rank covariance).

**Why `MCMCglmm` is marked `~` (plausible) rather than `✓` for `indep`/`dep`.**
The mechanism is documented (`idh`/`us` variance functions, `pedigree`
argument, generic `ginverse` for non-pedigree relatedness — all confirmed
present in `?MCMCglmm` this session) but **no fit was attempted**. Two real
risks before trusting it as a working reference: (1) `MCMCglmm`'s family
list (confirmed this session: gaussian, poisson, categorical, multinomial,
ordinal, threshold, exponential, geometric, zero-inflated/altered/truncated/
hurdle-Poisson, zero-inflated/hurdle-binomial) has no negative-binomial,
gamma, tweedie, or beta option, so it only reaches a subset of
`gllvmTMB`'s families even where the covariance structure matches; (2) a
posterior mean under `MCMCglmm`'s (inverse-Wishart-family) prior is not an
MLE — disagreement is not diagnostic of an engine bug, and agreement is not
proof of MLE correctness, only evidence the two are in the same
neighbourhood (this mirrors the Hmsc audit's identical caveat about
posterior-mean comparators, §3c/§4 there).

**Why `spatial_*` `indep(common = TRUE)`/`indep`/`dep` are "not confidently
established" rather than a clean ✓ or NONE.** This is an honest gap in this session's
verification, not a claim either way. `gllvm`'s only source-structured
spatial mechanisms are `row.eff` (community-shared, wrong shape) and
`lvCor` (an ordination-axis mechanism, i.e. the `latent` column). Whether
`glmmTMB`'s native `mat()`/`exp()` single-random-effect covariance
structures could be stacked with `diag()`/`us()` the same way `rr()+diag()`
already validates ordinary `latent()` was not checked this session — it is
recorded as a candidate, not asserted as working or absent.

**Why `phylo_latent`/`animal_latent`/`kernel_latent` are a clean NONE, not
"not confidently established."** This one *was* checked from both
directions: `gllvm`'s `colMat` is proven incapable of touching the
ordination axis (S2 §D, a positive empirical result — the two-tree test
showed `colMat` moves the environmental-slope likelihood but the pure
ordination baseline with no bar-formula random effect is unaffected by
`colMat` at all, S2 §E negative control), and `Hmsc`'s phylogenetic
mechanism (per the existing, verified Hmsc audit) structures the
trait-regression coefficients `Beta` via a `rho`-blended prior on `Gamma`,
not the ordination loadings `Lambda`. Both are checked absences, not gaps
in this session's coverage.

---

## 4. Families axis

Section 2.5 gives the full family lists. The point for this document: the
oracle-map answer above is essentially unaffected by which specific family
is chosen from the overlapping set (poisson/binomial/gaussian/gamma/
negative-binomial/tweedie/beta/ordinal) — the structural question (which
mechanism, which axis) dominates. Families with **no comparator at all**
regardless of structure: `multinomial()`, every `delta_*` compound family,
`gengamma`/`gamma_mix`/`lognormal_mix`, `student`, `censored_poisson`/
`truncated_poisson`. Combining any of these with a source-structured
`indep`/`dep`/`latent` term compounds a structural NONE with a family-level
NONE — the phylogenetic-multinomial case (Design 84, §6 below) is the
concrete example already partially implemented in this package.

---

## 5. `gllvm` comparison-harness scope

A harness beyond the two cells already shipped
(`tests/testthat/test-comparator-gllvm.R`: Poisson and binary, ordinary
unconstrained ordination, Procrustes-aligned loadings) should assert, in
priority order:

1. **Log-likelihood, relative tolerance, never exact.** Per §2.6, use a
   `method = "LA"` `gllvm` fit when possible (matches `gllvmTMB`'s
   estimator exactly) or a generous relative band (the shipped tests use
   1%) when only VA/EVA is available for that family. State explicitly in
   the test comment which estimator was used and why — the existing file
   already does this correctly; new cells should follow the same
   convention.
2. **Procrustes-aligned loadings + per-factor correlation**
   (`compare_loadings()`, `R/rotate-loadings.R:428`, already exported and
   already used) for any `latent`-mode cell. 0.95 per-factor correlation
   is the house bar (`test-re09-latent-unique-unit.R`'s convention, reused
   by the shipped `gllvm` comparator).
3. **Relative Frobenius error on $\Sigma = \Lambda\Lambda^{\mathsf T}(+\Psi)$**
   after Procrustes rotation, normalised by the reference matrix's norm —
   catches a right-shape-wrong-scale fit that correlation alone would miss.
   The shipped tests use 10% (Poisson) and 25% (binary, noisier per-obs
   information); a new cell should re-derive its own band empirically
   rather than reuse these numbers blind.
4. **Signal-parameter direction, not value, for the `colMat`
   `indep(common = TRUE)` cells.** Per S2, `rho.sp` is not on a scale directly comparable to
   `gllvmTMB`'s phylogenetic signal parameterisation, but the qualitative
   behaviour (correct tree → non-boundary $\rho$; wrong tree → boundary
   $\rho$ = 0 with a boundary warning) is a genuine, cheap, falsifiable
   check, and is exactly what the S2 two-tree test already demonstrated
   works.
5. **Fixtures.** No shipped `gllvm` corpus exists (§2.1); use synthetic
   DGPs matching the shipped comparator file's convention (explicit
   `Lambda_true`, mixed-sign loadings, documented seed), not `gllvm`'s own
   example datasets (`fungi`/`kelpforest` have no known truth, only a
   real-data plausibility check).
6. **Cost.** The existing binary cell required `n_sites = 300` and
   `gllvm`'s `n.init = 3` to avoid local-optimum collapse (documented in
   `dev/s9-binary-comparator-RESULTS.md`'s sweep) — budget accordingly;
   this is not a < 5s test. Keep it `skip_on_cran()` and
   `skip_if_not_installed("gllvm")`, matching the existing file.

**The one thing not to build**: a `colMat`-based comparator that is
labelled "phylogenetic `latent()` validation." Per §3.1/§3.2 that
comparison is not possible with `gllvm` at all — building it would produce
a test that looks like coverage but validates a different decomposition
(exactly the anti-pattern the shipped comparator file's own header comment
already warns against, and the reason it explicitly declined that
comparison).

---

## 6. What cannot be externally validated

Stated plainly, per the task:

- **`phylo_latent()`, `animal_latent()`, `kernel_latent()`** — any family,
  any rank. No package combines a known relatedness/tree/kernel structure
  with reduced-rank ordination loadings the way these keywords do.
  Simulation-recovery is the only route.
- **The default (`common = FALSE`) `phylo_indep()` / `phylo_dep()` /
  `animal_indep()` / `animal_dep()` / `kernel_indep()` / `kernel_dep()`, if
  `MCMCglmm` is ruled out or its posterior-mean caveat is judged too weak to
  count as "external validation."** As given, these have a
  plausible-but-untested `MCMCglmm` reference (§3.1); if the standard is an
  MLE-level oracle specifically, they too are NONE. (Their `common = TRUE`
  sub-case is unaffected by this caveat — it already has an MLE-quality
  `gllvm`/`glmmTMB::propto()` oracle, §3.1.)
- **Phylogenetic multinomial** (`phylo_latent()` × `multinomial()`, Design
  84, already partially implemented as of 0.6). Compounds two independent
  NONEs (§3.1's `phylo_latent` row, §4's `multinomial` family) — the
  clearest concrete instance of an already-shipped feature with no
  possible external reference.
- **`meta_V()`** (known-sampling-covariance meta-analysis). Outside the
  scope of every package considered here (`gllvm`, `Hmsc`, `MCMCglmm`,
  `galamm` — none model a *known*, externally supplied sampling covariance
  matrix as the sole source of one variance component); the natural peers
  are meta-analysis packages (`metafor::rma.mv`) not evaluated in this
  document because they are not latent-variable/GLLVM peers and were out
  of this scout's remit.
- **Any `delta_*` compound family, `gengamma`, `gamma_mix`,
  `lognormal_mix`, `student`, `censored_poisson`/`truncated_poisson`,
  crossed with any source-structured mode.** No peer family exists in
  `gllvm`, `Hmsc`, or `MCMCglmm` regardless of the covariance structure
  chosen.

These are not gaps in scouting effort — §3.2 traces the specific evidence
(a positive empirical result for `gllvm`'s colMat/ordination separation,
a read of `Hmsc`'s own phylo mechanism) for the two structural NONEs that
matter most. The families list is a straightforward absence, checked by
enumeration.

---

## 7. Cost / priority ordering

**Worth building first** (§1's top-3, expanded):

1. **`spatial_latent` via `gllvm`'s `lvCor(corExp)`/`lvCor(corMatern)`.**
   Unbuilt, moderate confidence, conceptually the right comparator (GP-
   correlated latent scores with species-specific mixing), and closes a
   currently-empty row in the shipped comparator file. Cost: similar to
   the existing ordination comparators (one synthetic DGP, one `gllvm`
   fit, Procrustes alignment) plus the work of confirming `lvCor`'s
   coordinate convention matches `gllvmTMB`'s SPDE mesh convention.
2. **`MCMCglmm` `idh(trait):animal`/`us(trait):animal` + `pedigree` scout
   for `phylo_indep`/`phylo_dep`/`animal_indep`/`animal_dep`.** This is the
   one place `gllvm` structurally cannot help at all (§2.3) and a
   plausible reference exists but has never been fit against `gllvmTMB` in
   this repo. Cost: moderate — MCMC needs a burn-in/thinning/convergence
   check on top of the usual fixture work, and the posterior-mean-vs-MLE
   framing needs to be stated in the test, not just implied.
3. **`MCMCglmm` corroboration of `phylo_indep(common = TRUE)`/
   `animal_indep(common = TRUE)`.** Lower
   priority than 1–2 because this cell is already double-covered
   (`gllvm` + `glmmTMB::propto()`), but a third, genuinely independent
   (Bayesian, pedigree-native) implementation agreeing would meaningfully
   strengthen confidence in the shared-variance-blend decomposition ahead
   of any release claim resting on it.

**Not worth building**, with reasons:

- **Any `colMat`-labelled "phylogenetic ordination" comparator.** Not
  possible; see §5's closing note.
- **A `phyr`/`sdmTMB`/`VAST` comparator without first installing and
  auditing the package.** None is installed or in `Suggests`; every claim
  about their capabilities in this document is `[R]` (recall/unverified).
  Before spending build effort, an install-and-audit pass equivalent to
  §2's `gllvm` treatment is a prerequisite, not optional — do not build
  from memory of what these packages are reputed to do.
- **A `Hmsc` validation *programme*** (as opposed to a single bounded
  `phylo_latent + spatial_unique` capstone tie-breaker). The existing
  Hmsc audit already reached this conclusion independently (§5b there):
  cross-package agreement with a Gibbs sampler is the weakest evidence
  available and cannot certify coverage, which is the actual blocker. This
  document's independent read of the same package (§3.1/§3.2, phylo
  structures `Beta` not `Lambda`) supports the same conclusion from a
  different angle.
- **Real-data (`fungi`/`kelpforest`) comparators as a *primary* validation
  route.** No known truth, so at best a "plausible fit" smoke test, never
  a recovery claim — fine as a secondary sanity check once a synthetic
  comparator exists, not a substitute for one.

---

## Related

`docs/design/04-sister-package-scope.md` (package roster and boundary
rules), `docs/design/05-testing-strategy.md` (comparator table this
document extends — note its `gllvm::gllvm()` binary-GLLVM row still reads
`claimed (M2 work)` and should be updated to `covered` given
`tests/testthat/test-comparator-gllvm.R`, which is outside this document's
one-file scope), `docs/design/54-cross-package-scout-protocol.md` (when to
invoke a scout), `docs/design/79-covariance-mode-taxonomy.md` (the 5×4
mode/source taxonomy this map is built on), `docs/design/72-...VA-feasibility.md`
and `docs/design/85-...VA-formal-contract.md` (the Laplace-only decision
behind §2.6), `docs/design/83-multinomial-response-family.md` and
`84-phylogenetic-multinomial-tier2.md` (the concrete no-reference example
in §6), `docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md`
(the `Hmsc` facts relied on throughout, not re-derived here),
`tests/testthat/test-comparator-gllvm.R`,
`dev/s2-gllvm-colmat-reference-RESULTS.md`,
`dev/s7-gllvm-comparator-RESULTS.md`, `dev/s9-binary-comparator-RESULTS.md`
(the prior scout work this document builds directly on).
