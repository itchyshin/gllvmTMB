# Design 72 -- Variational approximation (VA) as an alternative estimation method: feasibility audit

**Status:** READ-ONLY feasibility audit / design memo (Claude's "gather
evidence, draft decision" role). No engine code touched. This memo is the
Phase 0 artifact of a proposed VA work-stream; it does NOT authorise
implementation.
**Scope:** whether to add `method = c("LA", "VA")` to `gllvmTMB()` as an
alternative to the current TMB Laplace approximation, and -- critically --
whether VA gives MORE STABLE results on the non-Gaussian augmented-slope
cells that currently honest-skip on non-PD Hessian / non-convergence.
**Competitive frame:** the sister/competitor package `gllvm` (Niku, Hui,
Taskinen, Warton; CRAN; GitHub JenniNiku/gllvm) is also TMB-based and
offers VA as its PRIMARY method, plus LA and EVA. This memo identifies
where gllvmTMB can be BETTER than gllvm, not merely reach parity.
**Parent designs:** Design 04 (sister-package scope), Design 35
(validation-debt register; rows PHY-17/18, SPA-08/09/10), Design 64
(spatial_dep / spatial_latent slope derivation), Design 03-phylogenetic-gllvm,
Design 47 (sparse pedigree A-inverse), Design 65 (kernel_* engine).

Throughout, ASCII-only: `(x)` is the Kronecker product, `Q` a sparse
precision, `A = Q^{-1}` the corresponding covariance, `tr()` the trace,
`logdet()` the log-determinant, `KL(q||p)` the Kullback-Leibler divergence.

---

## 0. TL;DR for the maintainer

1. **VA is worth a bounded experiment, not a blind commitment.** The single
   honest test of the hypothesis -- "VA converges where Laplace's inner
   mode-find goes non-PD" -- is Phase 1: a narrow Gaussian + one-non-Gaussian
   prototype benchmarked against our EXISTING skip fixtures. Everything past
   Phase 1 is gated on that proof.
2. **VA probably DOES help the specific failure mode we have, but for a
   subtle reason.** Our skips (PHY-18, SPA-10, and the seven `sd_b`-channel
   cells) are dominated by *non-PD inner Hessian* on the augmented full-
   unstructured `dep` covariance for non-Gaussian families at small `n`. VA
   replaces the inner Newton mode-find + inner Hessian factorisation (the
   thing that goes non-PD) with a smooth joint maximisation of one ELBO. That
   removes the *mechanism* of our most common skip. It does NOT manufacture
   information that is not in the data, so the genuinely *under-identified*
   cells (e.g. binomial single-trial `dep` at tiny `n`) will still fail --
   just more gracefully (a flat ELBO, not a crash).
3. **The "better than gllvm" frontier is exactly our hard part: VA over
   STRUCTURED priors** (phylo `A^{-1}`, SPDE `Q`, meta `V`). gllvm's VA was
   designed for unstructured / reduced-rank latent variables; its structured-
   RE support leans on a nearest-neighbour GP approximation that "retains
   block structure" and on LA/EVA fallbacks (TO-VERIFY, see sec 1). Our
   covariances are *already sparse and exact* (`A^{-1}` Hadfield, `Q` SPDE).
   A structured VA that keeps the variational covariance sparse against those
   exact priors is the differentiator -- and the biggest technical risk.
4. **Statistical caveat that must ship with any VA option:** VA's lower bound
   is NOT the marginal likelihood, and VA variance components are biased
   DOWNWARD. AIC / LRT across `method = "LA"` vs `"VA"` are NOT comparable,
   and SEs need care. This is a documentation + extractor-contract obligation,
   not optional.

---

## 1. What gllvm does (evidence + TO-VERIFY)

### 1.1 The three methods

gllvm exposes `method = c("VA", "LA", "EVA")` (`gllvm::gllvm(..., method=)`).
Confirmed from gllvm documentation and papers (sources in sec 9):

- **VA (variational approximation)** -- the DEFAULT for the families where a
  closed-form bound exists. "Faster and more accurate than LA, but not
  applicable for all distributions and link functions" (Niku et al. 2019 MEE;
  gllvm docs). Closed-form VA bounds exist for: overdispersed counts
  (negative binomial, via a Poisson-Gamma reparameterisation -- Hui et al.
  2017), Poisson, binary/ordinal with PROBIT link, and Gaussian. Logit-link
  binomial and several other family/link pairs do NOT have a closed-form VA
  bound (this is precisely the gap EVA closes).
- **LA (Laplace)** -- the fallback "for other exponential family
  distributions when a fully closed form variational approximation cannot be
  obtained" (gllvm docs). This is the SAME class of method gllvmTMB uses today
  (TMB `random` argument).
- **EVA (extended variational approximation)** -- Korhonen, Hui, Niku,
  Taskinen (2023, Stat & Comput 33(1); arXiv 2107.02627). EVA applies a
  SECOND-ORDER Taylor / series expansion to the part of the variational
  objective that lacks a closed form, yielding a closed-form objective for
  "practically any response type or link function." This is gllvm's universal
  estimator; it is how they get VA-style speed/stability on logit binomial,
  Tweedie, etc.

### 1.2 How VA is wired on TMB (mechanism)

The defining structural fact (Hui et al. 2017; Niku et al. 2019 PLOS ONE
"Efficient estimation of GLLVMs"): VA introduces a Gaussian variational
distribution `q(u) = N(a, A_var)` over the latent variables `u`, where `a`
(variational means) and `A_var` (variational covariances, typically one
per site / row, diagonal or unstructured-small) are EXTRA PARAMETERS. The
intractable marginal log-likelihood is replaced by the ELBO

```
ELBO(theta, a, A_var)
   = E_q[ log p(y | u, theta) ]  -  KL( q(u) || p(u) )
   = sum_i E_q[ log p(y_i | u, theta) ]
       - 0.5 * sum_s [ tr(A_var,s) + a_s' a_s - logdet(A_var,s) - d ]
```

(the KL line is for a STANDARD NORMAL prior `p(u) = N(0, I)`, gllvm's
unstructured-LV case; `d` is the LV dimension). The crucial implementation
move: in TMB, the variational parameters `(a, A_var)` are treated as
ORDINARY parameters in `MakeADFun` (NOT in the `random` argument). There is
NO inner Laplace mode-find and NO inner Hessian factorisation. The whole
ELBO is one smooth function maximised jointly over `(theta, a, A_var)` by the
outer optimiser. This is the structural reason VA can be more stable: the
thing that goes non-PD under Laplace (the inner Hessian at the conditional
mode) simply does not exist in the VA objective.

`E_q[ log p(y_i | u, theta) ]` is where families differ. For the
closed-form families the Gaussian expectation of the log-likelihood is
analytic (e.g. for Poisson-log, `E_q[exp(eta)] = exp(a'lam + 0.5 lam'A_var lam)`
gives the moment-generating-function term in closed form). For families
without that, EVA Taylor-expands the term to second order around `a`,
producing a closed-form surrogate.

### 1.3 gllvm's structured / correlated random effects (the competitive gap)

- gllvm 2.0 (Korhonen et al. 2025; van der Veen contributions) adds
  STRUCTURED row effects via `~ struc(1 | groups)` with `struc in {corAR1,
  corExp, corCS}`, correlated LVs, nested/hierarchical designs, and
  PHYLOGENETIC random effects (vignette7). [SOURCE: gllvm 2.0 docs + PeerJ
  paper.]
- Search evidence states gllvm's phylogenetic models "rely on a nearest
  neighbour approximation (NNGP) for computationally scalable estimation"
  and that "the VA method retains block structure of the phylogenetic
  covariance matrix." [SOURCE: search summary of gllvm 2.0 / Matsuba et al.
  2024 MEE.] **TO-VERIFY:** the exact form of gllvm's structured-VA KL term
  and whether spatial fields go through LA rather than VA. I could not fetch
  the gllvm C++ TMB templates (`src/*.cpp`), vignette7, or the JMLR/PMC full
  texts -- see sec 8 (network).

**Where gllvmTMB can be BETTER (the thesis):**

| Axis | gllvm | gllvmTMB opportunity |
|---|---|---|
| Structured prior representation | NNGP approximation of the phylo covariance; "retains block structure" | We ALREADY hold the EXACT sparse `A^{-1}` (Hadfield, Design 47) and the EXACT SPDE `Q` (Design 64). A structured VA can use the exact sparse precision in the KL term -- no NN ordering artefact. |
| Data shape | matrix-in (site x species) + study-design API | stacked-trait long format: VA's per-row variational block maps naturally onto our `(unit, trait)` rows and mixed-family-per-trait dispatch. |
| Covariance grammar | reduced-rank LVs + a few `struc()` options | the 4x5 keyword grid + meta `V`: a VA bound that respects `dep` (full unstructured) and `meta_V` (known `V`) is outside gllvm's surface. |
| Honesty | (their choice) | validation-debt register: every VA cell gets a row with VA-vs-LA recovery evidence before it is advertised. |

The frontier is NOT "do VA" (gllvm did it first; Design 04 already concedes
we should not claim novelty for VA/EVA per se). The frontier is "do VA over
our EXACT structured sparse priors and our stacked-trait grammar, with the
validation-debt discipline." That is a defensible differentiator.

---

## 2. Mapping VA onto gllvmTMB's architecture

### 2.1 Where the Laplace integration happens today

`R/fit-multi.R` assembles one TMB object and lists every latent block in the
`random` argument (lines ~3062-3097): `z_B`, `s_B`, `z_W`, `s_W`, `p_phy`,
`q_sp`, `r_c2`, `e_eq`, `omega_spde*`, `g_phy*`, `b_phy_*`, `u_re_int`, the
missing-data fields, etc. `TMB::MakeADFun(..., random = random, ...)` then
applies the Laplace approximation: for each evaluation TMB does an inner
Newton solve to the conditional mode of those latent blocks and a sparse
Hessian factorisation. **This inner Hessian is what goes non-PD on the hard
cells.**

`src/gllvmTMB.cpp` structure (skim):

- DATA / PARAMETER macros declare the latent fields (the `random` blocks) and
  the hyperparameters.
- The latent PRIOR contributions are added as `nll += <density>` -- e.g. the
  sparse phylo GMRF penalty using `Ainv_phy_rr` (around lines 626-1112), the
  SPDE GMRF priors via `density::GMRF(Q_base)` / `SCALE(GMRF(Q), 1/tau)`
  (around lines 1131-1410), the `dep` full-unstructured Kronecker priors
  (`theta_dep_chol`, `theta_spde_dep_chol`).
- `eta(o)` is accumulated from fixed effects + every latent contribution
  BEFORE family dispatch (the family-agnostic design noted in Design 64 sec 0
  and the SPA-08/09 test headers).
- The family LIKELIHOOD is a single `if (fid == k)` ladder
  (`src/gllvmTMB.cpp:1621-1810+`, fids 0..15) appending `ll += <density>`.

### 2.2 The smallest VA insertion point

VA does NOT replace the family ladder or the eta assembly -- it replaces the
*integration strategy* for the latent blocks. Conceptually:

1. **Add variational parameters** mirroring each latent block we want to
   integrate variationally: variational means `a_*` (same shape as the latent
   field) and a variational covariance parameterisation `A_var,*` (per-block).
   These are NEW `PARAMETER` blocks, NOT in `random`.
2. **Replace the prior `nll += <density>` for that block with the KL term**
   `KL(q || prior)` (sec 3), and **replace `eta` reads of the latent field
   with reads of the variational mean `a`** plus a variance-correction term
   in the family expectation `E_q[log p(y|u)]`.
3. **The family ladder gains a parallel "expected log-likelihood" path** for
   VA: for closed-form families an analytic `E_q[log p]`; for the rest, the
   EVA second-order surrogate.
4. **R side:** a `method` argument that (a) selects which fields go into
   `random` (LA) vs which get variational parameters (VA), (b) toggles a
   `DATA_INTEGER(use_va)` switch in the template, (c) wires the new
   variational parameters and their maps.

The honest assessment of "smallest": this is NOT a one-line guard relax like
the family-allowlist work (PHY-12..18, SPA-09). VA touches the C++
likelihood/prior assembly and is therefore a HIGH-RISK change per CLAUDE.md
("likelihood / TMB / family changes"). It MUST go through maintainer
discussion + Codex implementation, not a Claude auto-merge. The smallest
*first* slice (Phase 1) is a SINGLE latent structure (plain `latent`/`unique`
Gaussian, plus one non-Gaussian family) behind `method = "VA"`, leaving every
other path on LA untouched -- ideally in a fresh template branch so the LA
template is never destabilised.

### 2.3 Two viable engineering shapes (decision for the maintainer)

- **(A) One template, `use_va` switch.** Add VA branches inside
  `gllvmTMB.cpp` guarded by `DATA_INTEGER(use_va)`. Pro: single DLL, shared
  eta/family code. Con: the template grows; every VA branch is a chance to
  destabilise the LA path; harder to review.
- **(B) Separate VA template** (`gllvmTMB_va.cpp`) compiled as a second DLL,
  R dispatches on `method`. Pro: LA template is byte-frozen; VA can evolve
  independently; mirrors how gllvm keeps method paths separable. Con: code
  duplication of eta assembly + family ladder; risk of drift between the two.

Recommendation leans (B) for Phase 1 (isolation protects the shipped LA
engine), with a later consolidation decision if VA graduates. This is an
explicit open question (sec 7).

---

## 3. The hard problem: VA over STRUCTURED priors

This is the "better than gllvm" frontier AND the biggest risk. The classic
VA-GLLVM ELBO (sec 1.2) assumes an UNSTRUCTURED standard-normal prior
`p(u) = N(0, I)`, which makes `KL` a sum of independent per-site terms. Our
priors are NOT `N(0, I)`. Work through each.

### 3.1 General structured KL

For a multivariate-normal prior `p(u) = N(0, Sigma_p)` with precision
`Q_p = Sigma_p^{-1}`, and a Gaussian variational posterior `q(u) = N(a, S)`:

```
KL( N(a,S) || N(0, Q_p^{-1}) )
   = 0.5 * [ tr(Q_p S) + a' Q_p a - logdet(Q_p S) - m ]
```

(`m = dim(u)`). The three load-bearing quantities are `tr(Q_p S)`,
`a' Q_p a`, and `logdet(S)` (note `logdet(Q_p)` is a constant in `theta`
only through the hyperparameters, e.g. `kappa`, `lambda_phy`). The scaling
question is whether `S` (the variational covariance) can stay STRUCTURED so
those three terms are cheap.

### 3.2 Phylogenetic prior (`A^{-1}`, the Hadfield path)

Prior: `vec(B) ~ N(0, Sigma_b (x) A_phy)` for the `dep` augmented slope, or
`g_phy ~ N(0, A_phy)` per LV column for `phylo_latent`. We hold `A_phy^{-1}`
EXACTLY and SPARSELY (`Ainv_phy_rr`, Design 47 / Hadfield-Nakagawa). So
`Q_p = Sigma_b^{-1} (x) A_phy^{-1}` is sparse and exact -- BETTER than
gllvm's NNGP approximation of the same object.

- `a' Q_p a` and `tr(Q_p S)` with sparse `Q_p`: cheap IF `S` is structured.
- **The variational-covariance choice is everything.** Options:
  - **Mean-field `S = diag`** (one variance per latent coordinate): cheapest;
    `tr(Q_p S) = sum_i Q_p,ii S_ii`, `logdet(S) = sum log S_ii`. But mean-field
    badly mis-states posterior correlation induced by a strong tree -- exactly
    where phylo signal lives. Expect MORE downward bias on phylo variance.
  - **Kronecker-structured `S = S_b (x) A_phy`** (variational covariance shares
    the prior's tree structure, only the `T`-or-`C`-dimensional trait factor
    `S_b` is free): this is the elegant analogue of gllvm's "retains block
    structure." Then `tr(Q_p S) = tr(Sigma_b^{-1} S_b) * tr(A_phy^{-1} A_phy)
    = tr(Sigma_b^{-1} S_b) * n_sp`, and `logdet(S) = n_sp logdet(S_b) + T
    logdet(A_phy)` -- both O(T^3) + sparse, NOT O((n_sp T)^3). This is the
    scalable, correct-structure route and is the concrete differentiator.
  - **Sparse-precision `S` with the same sparsity as `Q_p`** (a GMRF
    variational posterior): more flexible than Kronecker, still sparse, but
    the `logdet(S)` needs a sparse Cholesky each eval. Feasible (TMB does this
    for LA already) but heavier.

  **Risk:** the Kronecker route assumes the posterior factorises as
  trait-block (x) tree. That is exact for a Gaussian response with a single
  variance scale but only APPROXIMATE for non-Gaussian families (the data
  term couples coordinates). The quality of that approximation on our hard
  cells is an empirical question Phase 3 must measure -- it is NOT a free
  lunch.

### 3.3 Spatial SPDE prior (sparse `Q`)

Prior: `omega ~ N(0, Q^{-1})` with `Q = kappa^4 M0 + 2 kappa^2 M1 + M2`
(Design 64 sec 1), already used via `density::GMRF(Q_base)`. Here `Q_p = Q`
is sparse by construction -- the spatial case is the most natural fit for a
sparse-precision variational posterior `S^{-1}` sharing `Q`'s sparsity
pattern. `tr(Q S)` over matching sparsity is cheap; `logdet(S)` via the same
sparse Cholesky TMB already builds. For the `dep` spatial slope the prior is
`Sigma_field (x) Q^{-1}` (Design 64 sec 2) -- the Kronecker route of sec 3.2
applies verbatim with `A_phy -> Q^{-1}`.

**This is likely the EASIEST structured VA win** because the precision is
sparse natively and TMB's GMRF machinery is already in the template. SPA-10
(spatial_dep non-Gaussian, currently fully reserved) is the most direct test
of "does VA fix our skip."

### 3.4 Meta-analytic known `V`

Prior contribution involves a KNOWN sampling covariance `V` (Design 04;
`meta_V`). If `V` enters as a fixed `N(0, V)` block, the KL is the sec 3.1
formula with `Q_p = V^{-1}` (precomputed once, constant in `theta`). This is
the CHEAPEST structured case -- `Q_p` is data, not a function of parameters,
so `tr(Q_p S)` and `a'Q_p a` are linear/quadratic with a fixed matrix.
Lowest-risk structured VA, but also lowest-value for our convergence pain
(meta cells are not the ones skipping). Park it.

### 3.5 Where EVA is REQUIRED (no closed-form VA bound)

The closed-form `E_q[log p(y|u)]` exists for Gaussian, Poisson-log,
NB (via Poisson-Gamma), and probit binary/ordinal. It does NOT exist for:
logit binomial, Beta, Gamma-log in general, Tweedie, Student-t, lognormal,
the truncated/censored families, the delta two-part families. For ALL of
those, VA needs the EVA second-order surrogate (Taylor-expand
`E_q[log p(y|u)]` to second order around `a`):

```
E_q[ log p(y_i|u) ]  ~  log p(y_i | a)  +  0.5 * tr( H_i S_i )
```

where `H_i` is the Hessian of `log p(y_i | eta_i)` wrt the latent
contribution at the variational mean. This is closed-form for any twice-
differentiable family, which is why gllvm's EVA is "universal." **Note the
irony:** EVA reintroduces a per-observation Hessian `H_i` -- but it is the
Hessian of the DATA term at a FIXED point `a` (one evaluation, no inner
solve), not the joint inner Hessian that Laplace must keep PD across a Newton
iteration. So EVA still sidesteps our specific failure mechanism. Our hard
cells (poisson, nbinom2 closed-form; Gamma, Beta, ordinal-probit, logit
binomial via EVA) span BOTH the closed-form and EVA buckets, so a serious VA
effort needs EVA fairly early (Phase 2), not as an afterthought.

---

## 4. Statistical caveats (must ship with any VA option)

1. **The ELBO is a LOWER BOUND, not the marginal log-likelihood.** Therefore
   `logLik()`, `AIC()`, and likelihood-ratio tests are NOT comparable between
   `method = "LA"` and `method = "VA"`, and not even strictly comparable
   across two VA fits with different latent dimensions (the bound gap varies).
   The extractor contract (Design 06) MUST flag the method and refuse / warn
   on cross-method AIC. This mirrors gllvm's own caveats.
2. **Downward bias of variance components.** VA is known to UNDER-estimate
   variance/dispersion parameters (the mean-field assumption ignores
   posterior correlation, shrinking the apparent latent spread). This is
   well-documented for VA-GLLVMs (Hui et al. 2017; the EVA paper exists partly
   to mitigate accuracy issues). Concretely for us: VA estimates of
   `Sigma_b`, `sigma^2_phy`, SPDE marginal variance will likely sit LOW vs LA
   / vs truth. Our recovery bands (3x/4x for mean-dependent families) might
   ABSORB this, but a VA fit that "converges" with a biased-low variance is a
   trap -- the Phase 1 benchmark must report VA-vs-LA-vs-truth side by side,
   not just "VA converged."
3. **Standard errors.** SEs from the VA Hessian are anti-conservative
   (too small) because the variational objective is over-confident. gllvm
   addresses this with corrected/sandwich-style SEs (TO-VERIFY exact form).
   Any gllvmTMB VA `confint`/`sd_report` path needs the same correction or an
   explicit "VA SEs are optimistic" warning.
4. **Validation = VA vs LA on the SAME fixtures.** The honest test is to run
   VA on the exact recovery fixtures the LA cells use
   (`test-matrix-slope-phylo-dep.R`, `test-matrix-slope-spatial-dep.R`,
   `test-spatial-indep-slope-nongaussian.R`, etc.) and compare: (a) does VA
   converge with PD Hessian where LA skips? (b) is VA recovery inside the
   inherited band? (c) how far below LA / truth are the variance estimates?
   Only (a)+(b) together justify a register promotion.

---

## 5. The convergence hypothesis vs our ACTUAL skips

Grounding the memo in the real pain (Design 35 rows):

| Row | Cell | Why it skips today | Will VA help? |
|---|---|---|---|
| PHY-18 | `phylo_dep(1+x\|sp)` non-Gaussian | Full unstructured `C x C` (`C = 2T`) inner Hessian goes non-PD at small `n_sp`; GAP-B1 sweep showed it is finite-sample power, identifiable by `n_sp ~ 300`. | LIKELY. The non-PD is in the LA inner Hessian; VA has no inner Hessian. VA may converge at SMALLER `n_sp`, lowering the escalation cost. But the *identifiability* limit (binomial single-trial) is unchanged. |
| SPA-10 | `spatial_dep(1+x\|site)` non-Gaussian | Same: full unstructured `2T x 2T` field covariance non-PD across all 7 families at `n=100`; fully RESERVED (gaussian-only allowlist). | LIKELY, and this is the BEST first structured-VA target (sec 3.3): sparse `Q` + GMRF machinery already present, and the cell is the most thoroughly reserved (biggest upside). |
| SPA-09 | `spatial_latent(1+x\|site)` non-Gaussian | 3 of 7 families non-PD at the default seed (binomial-logit, ordinal_probit, nbinom2) -- seed/power artefact. | PLAUSIBLY. These are seed-fragile under LA; VA's smoother objective may remove the seed sensitivity. Good secondary benchmark. |
| PHY-17 | `phylo_latent(1+x\|sp,d=1)` | Currently COVERED (all 7 families) -- block-diagonal reduced-rank is well-behaved. | Use as a CONTROL: VA should match LA here. If VA can't match LA on the easy covered cell, the VA path is buggy. |
| 7x `sd_b`-channel cells | `phylo_dep` honest-skip cells reading the closed-form `sd_b` 2-vector | A harness/channel mismatch + converge/PD guard; partly a test-bug, partly non-PD. | PARTIAL. VA fixes the non-PD part; the channel mismatch is an R-side test issue independent of method. |

**The headline:** our dominant skip mechanism (non-PD inner Hessian on the
`dep` full-unstructured covariance for non-Gaussian families) is structurally
the thing VA removes. That is a genuine, mechanism-level reason to expect VA
to convert several `partial`/`reserved` rows to `covered` at SMALLER sample
sizes than LA needs. It is a hypothesis with a clear mechanism -- but it must
be measured, because VA trades the non-PD crash for a possible silent
downward bias (sec 4.2).

---

## 6. Phased plan + go/no-go gates

### Phase 0 -- this memo (DONE)
Evidence + decision draft. **Go/no-go:** maintainer decides whether to fund
Phase 1.

### Phase 1 -- proof of mechanism (the load-bearing experiment)
- Add `method = c("LA", "VA")` (LA default). VA wired for ONE latent
  structure only: plain `latent`/`unique` with **Gaussian** (closed-form,
  exact -- a correctness anchor where VA == LA == truth) PLUS **Poisson**
  (closed-form non-Gaussian).
- Mean-field diagonal `S` first (simplest), unstructured prior `N(0,I)` (NOT
  yet structured) -- i.e. reproduce gllvm's classic VA to establish the
  scaffold.
- **Benchmark on existing fixtures:** run VA on the Gaussian anchors and on
  a poisson cell; compare convergence, PD rate, recovery, and VA-vs-LA-vs-
  truth variance bias. Critically: take ONE currently-skipping non-Gaussian
  cell (the PHY-18 poisson VALIDATION cell or an SPA cell at the small `n`
  that LA skips) and check whether VA converges there.
- **Effort:** medium-high (new C++ path, new parameters, R `method`
  plumbing, benchmark harness). 1-2 focused engine PRs.
- **GO if:** VA matches LA to tolerance on the Gaussian anchor AND converges
  with usable recovery on at least one cell where LA skips. **NO-GO if:** VA
  cannot even match LA on Gaussian (path is wrong), or VA "converges" only by
  collapsing variance to ~0 (the bias trap), or it gives no convergence
  advantage on the skip cell (hypothesis falsified -- stop, document, keep
  LA-only).

### Phase 2 -- non-Gaussian family coverage (closed-form VA + EVA)
- Closed-form VA for NB (Poisson-Gamma), probit binary/ordinal.
- EVA second-order surrogate for the rest (logit binomial, Gamma, Beta,
  Tweedie, ...). This is where VA earns "universal" parity with gllvm.
- Per-family VA-vs-LA recovery cells; register rows updated with VA evidence.
- **Effort:** high (EVA is real math + per-family Hessian terms).
- **GO if:** VA/EVA cells pass recovery within inherited bands and the
  convergence advantage from Phase 1 generalises. **NO-GO if:** EVA bias is
  too large to fit inside the existing bands without widening them (widening
  bands to force green is forbidden -- Design 35).

### Phase 3 -- STRUCTURED-covariance VA (the differentiator)
- Spatial FIRST (sec 3.3: sparse `Q`, GMRF machinery present, SPA-10 is the
  highest-upside reserved row). Then phylo (sec 3.2: Kronecker-structured `S`
  against exact sparse `A^{-1}`). Meta `V` last / optional.
- This is where gllvmTMB can BEAT gllvm: exact sparse precisions, no NNGP
  ordering artefact, the 4x5 grid + `dep`.
- **Effort:** high-to-research. The Kronecker variational-covariance
  derivation and its non-Gaussian approximation quality are genuinely
  uncertain (sec 3.2 risk).
- **GO if:** structured VA converts PHY-18 / SPA-10 reserved cells to covered
  at sample sizes LA cannot reach, with recovery inside bands. **NO-GO if:**
  the structured KL is not scalable (variational covariance can't stay
  sparse/Kronecker) or the structured-VA bias on non-Gaussian families is
  worse than LA's finite-sample behaviour.

---

## 7. Recommendation

**Conditional GO on Phase 1 only.** VA is worth a bounded, falsifiable
experiment because (a) the mechanism that VA removes -- the inner Laplace
Hessian -- IS our dominant skip cause (sec 5), and (b) structured VA over our
exact sparse priors is a real, defensible differentiator from gllvm (sec 3),
not a me-too feature. But the hypothesis "VA gives MORE STABLE results" is
exactly that -- a hypothesis -- and VA carries a real downside (downward
variance bias, non-comparable AIC, optimistic SEs) that could make a
"converged" VA fit worse than an honest LA skip. So fund Phase 1 as a
proof-of-mechanism with a hard NO-GO if VA does not beat LA on a real skip
cell or only "converges" by collapsing variance.

Do NOT commit to Phases 2-3 now. Do NOT advertise VA anywhere (NEWS, README,
articles, roxygen) until a register row carries VA-vs-LA recovery evidence --
this is precisely the overpromise pattern Design 35 exists to prevent. VA is
a HIGH-RISK change (TMB/likelihood) per CLAUDE.md: maintainer discussion +
Codex implementation, never a Claude auto-merge.

**Biggest single technical risk: the structured-covariance KL (sec 3.2).**
Whether the variational covariance `S` can stay sparse/Kronecker against our
exact `A^{-1}` / `Q` priors WHILE remaining an adequate approximation for
NON-Gaussian families is the crux. If `S` must go dense to be accurate, the
scalability advantage evaporates and we are back to LA-class cost without
LA's marginal-likelihood. This is the make-or-break of the whole
"better than gllvm" thesis and the reason Phase 3 is gated behind a proven
Phase 1+2.

---

## 8. Network access note (provenance honesty)

WebSearch was available and used (sources sec 9). **WebFetch was blocked
(HTTP 403) for every academic / documentation target attempted**:
arxiv.org, link.springer.com, jmlr.org PDF, pmc.ncbi.nlm.nih.gov,
jenniniku.github.io, rdrr.io. The GitHub MCP is scoped to
`itchyshin/gllvmtmb` only, so I could NOT read the gllvm `src/*.cpp` TMB
templates or its R `method`-switch source directly. The gllvm internals in
this memo (variational-covariance parameterisation, the exact structured-VA
KL term, NNGP details, SE correction form) are reconstructed from WebSearch
SUMMARIES + first-principles VA-GLLVM knowledge and are flagged **TO-VERIFY**
where load-bearing. Anyone funding Phase 1 should confirm against the actual
gllvm sources and the full texts of Hui 2017 / Niku 2019 (both) / Korhonen
2023 before writing C++.

TO-VERIFY checklist:
- gllvm's exact variational covariance parameterisation (diagonal vs
  unstructured-per-site vs block).
- gllvm's structured/phylo VA KL term and whether spatial uses VA or LA.
- gllvm's SE correction (sandwich? corrected Hessian?).
- the unnamed Julia GLLVM port the maintainer mentioned (not located; no
  claims made about it here).

## 9. Open questions for the maintainer

1. **Engine shape (sec 2.3):** one template with a `use_va` switch (A) or a
   separate VA DLL (B)? Recommendation leans B for Phase 1 isolation.
2. **Mean-field vs structured `S` ordering:** start mean-field-diagonal to
   prove the scaffold (Phase 1), or jump straight to a structured `S` Phase 1
   because the diagonal case is the one most prone to the bias trap on our
   strong-prior cells?
3. **Scope discipline vs Design 04:** Design 04 says we "should not claim
   novelty for VA/EVA estimation." Does adding VA risk blurring the
   gllvmTMB/gllvm boundary, and is the differentiator (structured VA over
   exact sparse priors + stacked-trait grammar) sharp enough to justify it?
4. **Bias tolerance:** if VA converges where LA skips but with variance
   estimates biased low (still inside our 3x/4x bands), is that an acceptable
   register `covered`, or do we require a bias correction first?
5. **Who implements:** this is HIGH-RISK TMB code. Confirm Codex owns the
   engine slice with Claude reviewing, per the collaboration rhythm.
6. **Priority vs the open campaigns:** the dep-slope identifiability sweeps
   (GAP-B1) are landing non-Gaussian cells via bigger `n` under LA right now.
   Does VA leapfrog that campaign, or run parallel as a stability insurance
   policy?

---

## Sources (WebSearch; full texts not fetchable -- see sec 8)

- Hui, Warton, Ormerod, Haapaniemi, Taskinen (2017), "Variational
  approximations for generalized linear latent variable models," JCGS 26(1),
  35-43.
- Niku, Brooks, Herliansyah, Hui, Taskinen, Warton (2019), "Efficient
  estimation of generalized linear latent variable models," PLOS ONE
  (PMC6493759) -- VA/LA detail.
- Niku, Hui, Taskinen, Warton (2019), "gllvm: Fast analysis of multivariate
  abundance data ...," Methods in Ecology and Evolution 10(12).
- Korhonen, Hui, Niku, Taskinen (2023), "Fast and universal estimation of
  latent variable models using extended variational approximations," Stat &
  Comput 33(1) (arXiv 2107.02627).
- Korhonen et al. (2024), "A Review of GLLVMs and Related Computational
  Approaches," WIREs Comput Stat.
- gllvm 2.0 (van der Veen et al.), PeerJ / PMC12704334; gllvm docs
  (jenniniku.github.io) for `method` / `struc()` / phylo vignette7.
- Matsuba et al. (2024), MEE -- scalable phylogenetic GP / NNGP in gllvm.
