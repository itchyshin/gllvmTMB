# Design 68 -- Phase 5 categorical / non-Gaussian missing PREDICTORS: function-by-function design + drmTMB borrow-map

**Status: DESIGN / ANALYSIS ONLY (2026-05-31).** No engine code, no TMB fits, no
test files. This document deep-dives the Phase-5 sections that Design 67
sketched (its sections 2.2, 2.3, 3.3) into an implementable, function-by-function
design for the FINITE-STATE exact-summation path -- missing CATEGORICAL /
discrete predictors in the gllvmTMB stacked-long, multivariate `traits()`
engine. It is the discrete-predictor counterpart to Design 67 section 3.5 (which
gave this level of detail for the Gaussian-Laplace Phase 2a).

Part of GitHub issue #332 (gllvmTMB missing-data umbrella). Companion to
Design 67 (`docs/design/67-missing-predictor-design.md`, the lane overview) and
grounded in Design 59 (`docs/design/59-missing-data-layer.md`, the authoritative
shared-contract text -- NOT edited here).

The concrete porting source is the drmTMB lane, which has ALREADY IMPLEMENTED
the finite-state predictor path under its own slice ladder:

- **MD6a** -- binary 2-state SUM (`mi_family == 1`),
- **MD6b** -- ordered K-state cumulative-logit SUM (`mi_family == 2`),
- **MD6c** -- unordered K-state baseline-softmax SUM (`mi_family == 3`).

(The `fit$missing_data$version` tags in the drmTMB tests are literally
`"MD6a"` / `"MD6b"` / `"MD6c"` -- verified in
`tests/testthat/test-missing-predictor-binary.R:82`, `-ordered.R:90`,
`-categorical.R:90`. Design 67 referred to these loosely as "Phase 5
binary/ordered/unordered"; the drmTMB slice numbers are MD6a/b/c, the slot AFTER
MD5 imputation summaries.)

> **Anchor-drift note.** drmTMB and gllvmTMB have both moved since Design 67 was
> written. All `file:line` anchors below were re-verified by reading the current
> trees. Two anchors in particular drifted and are corrected here:
> (1) the drmTMB discrete-row response gate is now at
> `src/drmTMB.cpp:1163-1170` (Design 67 cited `:1059-1066`); it moved because a
> beta predictor block (`mi_family == 4`) was inserted ahead of it. The task
> prompt's `:1165-1166` points at the load-bearing two lines of that gate.
> (2) `drm_missing_predictor_state_design()` is now at
> `R/missing-data.R:1774` (Design 67 cited `:1567-1607`).
> A genuinely NEW drmTMB data point: `mi_family == 4` is a BETA continuous
> predictor integrated by FIXED Gauss-Legendre QUADRATURE
> (`mi_quad_nodes` / `mi_quad_weights`, `src/drmTMB.cpp:1046-1146`), not by a
> Laplace latent -- see section 1.4. It is out of scope for THIS doc (which is the
> discrete path) but it sharpens the Design 67 section 1.2 "continuous families ->
> Laplace" rule: drmTMB chose quadrature, not a latent, for bounded beta.

---

## 0. Scope and conservative order

**In scope (design only):** the finite-state exact-summation engine for missing
DISCRETE predictors in gllvmTMB -- binary, ordered (cumulative logit), unordered
(baseline-category softmax); the multivariate per-unit-product SUM (the crux);
the `X_fix_state` long-and-stacked state-design matrix and its K-cap; the
discrete-row response gate; the `cumulative_logit()` / `categorical()`
constructor decision; the function-by-function drmTMB -> gllvmTMB borrow-map;
and the section 9 verification gates for Phase 5.

**Out of scope (unchanged from Design 59 section 4 / Design 67 section 0):** the
Gaussian-Laplace path (Design 67 section 2.1, section 3.5 -- Phases 2a/2b/2c/3); continuous
non-Gaussian predictors (lognormal/Gamma/beta -> Laplace or quadrature, later
slices, section 1.4); measurement error; MNAR / bootstrap-SE / phylo-signal as API
(they are section 9 gates); any Bayesian path; `engine != "laplace"`.

**Conservative order (binding for this lane):**

```
  binary (MD6a)  ->  ordered/cumulative_logit (MD6b)  ->  unordered/categorical (MD6c)
```

Continuous before discrete (so all of Design 67 section 3.5 lands first); within the
discrete path, ordered before unordered; FACTORS LAST (Design 59 section 7). Each
step lands only with its slice issue and its section 9 tests written first
(tests-as-binding-contract). Count predictors (Poisson / NB) are DEFERRED -- they
have no finite support; restated in section 8.

---

## 1. The finite-state SUM math, per family (log-space, `logspace_add`)

### 1.0 The shared marginalisation identity

For a discrete missing predictor `x` with finite support `{1, ..., K}`, the
observed-data contribution of a unit is the predictor `x` marginalised out
EXACTLY by summing over its support (Ibrahim 1990; Ibrahim, Chen & Lipsitz
1999 -- the joint `p(y | x) p(x)` factorisation of Design 59 section 2):

```
  p(y | z) = sum_{k=1..K}  p(x = k | z) * p(y | x = k, z)
```

There is NO latent parameter for `x` (contrast the Gaussian path, where
`x_mis` is a TMB random effect integrated by Laplace). The sum is finite,
exact, cheap, and differentiable, so it is evaluated DIRECTLY in the negative
log-likelihood at every TMB evaluation. In log space, with `logspace_add` for
numerical stability:

```
  nll -= logspace_add_over_k(  log p(x = k | z)  +  log p(y | x = k, z)  )
```

where `logspace_add_over_k` is the iterated two-argument `logspace_add`
(equivalently a `log-sum-exp` over the K state terms). This is the SAME
identity drmTMB implements three times; gllvmTMB reuses the identity unchanged
and only changes the GROUPING of the response term (section 3, the multivariate
twist).

A single REUSE invariant governs all three families and is the central claim of
this design: **the SUM introduces NO new RESPONSE family.** `log p(y | x = k, z)`
is evaluated by the EXISTING gllvmTMB per-family kernel
(`src/gllvmTMB.cpp:1412-1614`, the `fid == ...` dispatch) at a STATE-SUBSTITUTED
eta. The only novelty is (a) which eta the kernel sees, (b) that its output is
summed inside `logspace_add` rather than added directly to `nll`, and (c) that
the unit's per-trait kernel outputs are PRODUCT-combined before the sum (section 3).

### 1.1 Binary (MD6a, `mi_family == 1`) -- K = 2

Predictor model: Bernoulli logit, `logit p(x=1 | z) = eta_x = X_x beta_x`.
drmTMB (`src/drmTMB.cpp:832-864`) computes the two log-state-priors with
`logspace_add` and forms the 2-term mixture:

```
  log_p1 = -logspace_add(0, -eta_x)        # = log p(x = 1 | z)
  log_p0 = -logspace_add(0,  eta_x)        # = log p(x = 0 | z)
  nll  -= logspace_add( log_p1 + log_y1 ,  log_p0 + log_y0 )
```

where in drmTMB `log_y1 = w * dnorm(y, mu1, sigma)` and
`log_y0 = w * dnorm(y, mu0, sigma)` are the per-row Gaussian RESPONSE log-
densities at the two hypothetical states (`src/drmTMB.cpp:851-855`). For
OBSERVED `x`, drmTMB adds the ordinary single-state term
`mi_x * log_p1 + (1 - mi_x) * log_p0` and applies the predictor's eta delta to
`mu` (`:844-846`).

gllvmTMB reuses `log_p1` / `log_p0` verbatim (predictor side is unit-level,
identical math). The RESPONSE side `log_y1` / `log_y0` becomes a PRODUCT over
the unit's trait rows (section 3): `log_y_k = sum_t log p(y_{u,t} | x = k)`,
each `log p(y_{u,t} | x = k)` produced by the EXISTING `fid` kernel at the
state-substituted eta. The reuse of the binary logit prior is direct (no new
math); the gllvmTMB Bernoulli RESPONSE kernel (`fid == 1`,
`src/gllvmTMB.cpp:1415-1439`) is unrelated to the binary PREDICTOR prior and is
NOT touched -- they only coincide when a one-trait binary-response model is run
as the cross-package contract test (section 7).

### 1.2 Ordered (MD6b, `mi_family == 2`) -- cumulative logit, K states

Predictor model: cumulative-logit ordered model with cutpoints
`c_1 < c_2 < ... < c_{K-1}` reconstructed from a free log-increment vector.
drmTMB (`src/drmTMB.cpp:866-966`):

```
  mi_cutpoints(0) = theta_ord(0)
  mi_cutpoints(j) = mi_cutpoints(j-1) + exp(theta_ord(j))     # j = 1 .. K-2
```

The per-state log-prior is the cumulative-logit cell probability, in log space
via the package's stable helpers (drmTMB `drm_log_inv_logit`,
`drm_log1m_inv_logit`, `drm_log_inv_logit_diff` from `src/drm_numeric.h`):

```
  state 0     : log P(x = 1) = log_inv_logit(c_1 - eta_x)
  state K-1   : log P(x = K) = log1m_inv_logit(c_{K-1} - eta_x)
  state k     : log P(x = k+1) = log_inv_logit_diff(c_{k} - eta_x, c_{k-1} - eta_x)
```

and the K-term mixture is summed with iterated `logspace_add`
(`src/drmTMB.cpp:938-942`). For OBSERVED `x`, drmTMB adds only the single
matching state's log-prior (`:897-911`).

**Cutpoint reconstruction REUSE -- and the one parametrisation difference.**
gllvmTMB ALREADY has the identical log-increment reconstruction in its ORDINAL
RESPONSE family `ordinal_probit` (fid 14, `src/gllvmTMB.cpp:1579-1583`):

```
  cuts(0) = 0;                                           // tau_1 fixed at 0
  cuts(j) = cuts(j-1) + exp(ordinal_log_increments(...)); // j = 1 .. K-2
```

The increment LOOP is byte-for-byte the drmTMB loop and should be PORTED as a
shared helper. But there is ONE deliberate difference the implementer must NOT
elide:

- gllvmTMB's ordinal_probit RESPONSE fixes `tau_1 = 0` for identifiability
  (the intercept in `eta` absorbs the location), so it has `K - 2` FREE
  cutpoints (`tau_2 ... tau_{K-1}`).
- drmTMB's ordered PREDICTOR keeps `mi_cutpoints(0) = theta_ord(0)` FREE,
  giving `K - 1` free cutpoints, because the cumulative-logit predictor has no
  separate response intercept to absorb the first cutpoint -- the predictor's
  `eta_x = X_x beta_x` typically has an intercept, so the FIRST cutpoint must
  stay free to avoid a confound with that intercept, OR (the cleaner choice)
  the predictor model OMITS its own intercept and frees all `K - 1` cutpoints.

**Recommendation:** for the gllvmTMB ordered PREDICTOR, mirror drmTMB exactly --
`K - 1` free cutpoints via `theta_ord = (theta_ord(0), log-increments...)`,
with the FIRST entry a free location and the rest log-increments. Reuse
gllvmTMB's increment-loop helper for entries `1 .. K-2` only; entry `0` is the
free base. This keeps the SUM math identical across packages (the section 7
cross-package gate depends on it). Do NOT reuse the fid-14 `tau_1 = 0`
convention for the predictor -- that is a RESPONSE identification choice and
would silently shift the predictor likelihood.

Also distinct: the PREDICTOR ordered LINK is cumulative LOGIT; the RESPONSE
ordinal_probit (fid 14) is a PROBIT threshold model. They share only the
log-increment cutpoint loop, not the link (section 5).

### 1.3 Unordered (MD6c, `mi_family == 3`) -- baseline-category softmax, K states

Predictor model: baseline-category softmax with the first level as baseline
(`eta_state(0) = 0`). drmTMB (`src/drmTMB.cpp:968-1044`) packs `beta_mi` as
`(K-1)` blocks of `n_coef` (block `k-1` is the linear predictor for state `k`):

```
  eta_state(0) = 0
  eta_state(k) = X_x[i,] . beta_mi[block (k-1)]           # k = 1 .. K-1
  log_denom    = logsumexp_k eta_state(k)                 # stable max-subtraction
  log P(x = k+1 | z) = eta_state(k) - log_denom
```

The K-term mixture is summed with iterated `logspace_add`
(`src/drmTMB.cpp:1018-1022`); the softmax `log_denom` uses the explicit
max-subtraction guard (`:985-993`) rather than a library logsumexp, which the
port should keep. For OBSERVED `x`, drmTMB adds only the matching state's
log-prior (`:1001-1003`).

This is the one family that introduces a genuinely NEW predictor-model block
(the softmax prior); the SUM identity and the response-side reuse are otherwise
identical to MD6a/MD6b.

**Baseline-level invariance** is a mathematical property of the softmax (the
likelihood is invariant to which level is baseline, up to a reparametrisation
of `beta_mi`); it is a section 9 GATE (section 7), not a code branch.

### 1.4 Why count predictors are deferred, and the beta-quadrature aside

Binary / ordered / unordered all have FINITE support, so the SUM is exact and
finite. Poisson / NB predictors have COUNTABLY INFINITE support -- there is no
finite K. Design 67 section 1.2 already deferred them; this is restated in section 8.
Two non-finite routes exist (truncated SUM over a documented window; or a
continuous-relaxation Laplace latent) and BOTH are deferred to a later slice
that must decide and justify a truncation bound or a relaxation. Do NOT promise
count predictors in v1.

The drmTMB beta predictor (`mi_family == 4`, `src/drmTMB.cpp:1046-1146`) is the
informative aside: beta has UNCOUNTABLE bounded support `(0,1)`, and drmTMB
integrates it by FIXED Gauss-Legendre QUADRATURE (`mi_quad_nodes` /
`mi_quad_weights`) -- a finite weighted sum over quadrature nodes, structurally
the SAME `logspace_add`-over-nodes pattern as the discrete SUM, but with
`log(weight_q) + log_density(node_q) + log_y(node_q)` terms
(`src/drmTMB.cpp:1087-1106`). This is NOT a Laplace latent. It is a useful
template for FUTURE bounded-continuous gllvmTMB predictors (beta / logit-normal):
the engine machinery (state/node loop, per-node response kernel, `logspace_add`,
gate) is reused with quadrature nodes in place of discrete states. Out of scope
here; noted so the implementer sees the unifying pattern.

---

## 2. The discrete-row response GATE (the load-bearing subtlety)

### 2.1 What the gate does and why it is mandatory

The SUM REPLACES the ordinary per-row response term; it does not add to it. For
a row whose unit has a missing discrete predictor, the per-state response
density `p(y | x = k)` is ALREADY folded into the `logspace_add` mixture
(section 1). If the ordinary family-dispatch block ALSO added its `nll -= ...`
term, the response `y` would be DOUBLE-COUNTED -- counted once inside the
mixture and once outside. The gate prevents this.

drmTMB's gate, the load-bearing two lines (`src/drmTMB.cpp:1163-1170`, with the
condition at `:1165-1166`):

```cpp
    } else {                                  // V_known_type != 2 (the usual path)
      for (int i = 0; i < y.size(); ++i) {
        if (
          observed_y(i) == 1 &&
          !(has_mi == 1 && mi_family != 0 && mi_observed(i) == 0)   // <- the gate
        ) {
          nll -= weights(i) * dnorm(y(i), mu(i), obs_sigma(i), true);
        }
      }
    }
```

Read the gate condition as: "add the ordinary response term ONLY IF the response
is observed AND it is NOT the case that this is a discrete-missing
(`mi_family != 0`) row whose predictor value is missing (`mi_observed(i) == 0`)."
`mi_family != 0` excludes the Gaussian-Laplace path (`mi_family == 0`), where
there is NO replacement -- the Gaussian path corrects `mu` by a delta and the
ordinary term DOES still fire (Design 67 section 2.1; `src/drmTMB.cpp:806`). The
beta-quadrature path (`mi_family == 4`) similarly handles its own row inside
the quadrature branch and skips the ordinary term for missing rows
(`src/drmTMB.cpp:1086`, the `else if (observed_y(i) == 1)` branch). So the gate
fires only for `mi_family in {1, 2, 3}` -- exactly the finite-state families
this doc covers.

### 2.2 Where and how to gate gllvmTMB's stacked-long family loop

gllvmTMB's likelihood is a single stacked-long loop over `(unit, trait)` cells
(`src/gllvmTMB.cpp:1400-1623`), with `family_id_vec(o)` dispatch. The loop is
ALREADY structured for the gate, because Phase 1 (response mask) put a wrapping
guard in place. The current shape:

```cpp
  for (int o = 0; o < y.size(); o++) {
    int fid = family_id_vec(o);
    Type nll_before_row = nll;                  // line 1405
    if (is_y_observed(o)) {                     // line 1411  <- Phase 1 mask gate
      if (fid == 0) { ... }
      else if (fid == 1) { ... }
      ...
      else if (fid == 14) { ... }               // ordinal_probit response
      else { error("unknown family_id"); }
    }                                           // line 1616  end is_y_observed
    Type row_nll = nll - nll_before_row;        // line 1621
    nll = nll_before_row + row_nll * weights_i(o);
  }
```

The discrete-predictor gate EXTENDS the `is_y_observed(o)` condition at line
1411, exactly mirroring drmTMB:

```cpp
    // Proposed (DESIGN ONLY) gate for discrete missing predictors:
    if (is_y_observed(o) &&
        !(has_mi == 1 && mi_family >= 1 && mi_family <= 3 &&
          mi_unit_observed(mi_unit_id(o)) == 0)) {
      // ... ordinary family dispatch (unchanged) ...
    }
```

Key differences from drmTMB, and the gllvmTMB-specific correctness points:

1. **Per-UNIT, not per-row, observed flag.** drmTMB's `mi_observed(i)` is
   indexed by response row. gllvmTMB's missing predictor is a UNIT-level
   quantity broadcast to all of the unit's trait rows, so the gate must consult
   `mi_unit_observed(mi_unit_id(o))` -- "is the predictor value of THIS row's
   unit missing?" -- using the `mi_unit_id` long-row -> unit index that Design 67
   section 2.0 / section 2.3 introduced and that Phase 2a already builds. When the unit's
   `x` is missing, EVERY trait row of that unit is gated OFF here, because the
   whole trait vector enters the per-unit mixture (section 3).
2. **The weight is still applied.** Line 1621-1622 scales `row_nll` by
   `weights_i(o)`. For a gated-off row `row_nll == 0`, so the weight scaling is
   a no-op -- correct. The mixture term's own per-trait weighting is handled
   inside the SUM accumulation (section 3.3), not here.
3. **The `mi_family == 0` Gaussian path is NOT gated** (the `mi_family >= 1`
   lower bound), matching drmTMB -- the Gaussian path's delta-corrected eta
   leaves the ordinary term in place.

This gate is rated ADAPT (CRITICAL) in the borrow-map (section 4.3): the IDEA is a
one-line condition extension ported from drmTMB, but the INDEXING
(`mi_unit_observed(mi_unit_id(o))` vs `mi_observed(i)`) is the multivariate
adaptation, and getting it wrong silently double-counts (or drops) `y`.

---

## 3. THE MULTIVARIATE PER-UNIT-PRODUCT TWIST (the hardest part, no drmTMB precedent)

### 3.1 Why a per-row SUM is WRONG

drmTMB is uni-/bivariate: a missing predictor enters ONE response's design, so
its per-row SUM `sum_k p(x=k) p(y_i | x=k)` is correct as written. gllvmTMB is
fully multivariate: the same unit `u` contributes MANY long rows (one per
trait), and the SAME hypothetical `x = k` feeds the eta of EVERY trait row of
`u` simultaneously. The missing `x` is one quantity shared across the unit's
whole trait vector, not an independent draw per trait.

If one naively applied drmTMB's per-row SUM to each trait row independently, the
result would be:

```
  WRONG:  prod_t [ sum_k p(x=k | z_u) p(y_{u,t} | x=k) ]
```

This treats each trait as carrying its OWN independent copy of the missing `x`
and its own copy of the predictor prior -- the prior `p(x=k|z_u)` would be
counted `T` times (once per trait), and the states would be allowed to differ
across traits, which is statistically incoherent (there is ONE `x` for the
unit). The correct quantity sums over states OUTSIDE the trait product:

```
  RIGHT:  sum_k [ p(x=k | z_u) * prod_t p(y_{u,t} | x=k) ]
```

The predictor prior is counted ONCE per unit, and a SINGLE state `k` feeds all
traits. This is the per-unit mixture-of-products.

### 3.2 The derivation (Design 67 section 2.3, made precise)

Condition on the continuous latent structure of the unit -- the latent axis
scores, phylogenetic / spatial fields, and grouped random effects that enter
`eta` -- call it `b` collectively. Under the standard gLLVM conditional-
independence assumption (responses are independent GIVEN `eta`; Warton et al.
2015; Ovaskainen et al. 2017; Hui 2016), the unit's trait cells factorise GIVEN
both the latent `b` and the hypothetical state `x = k`:

```
  p(y_{u,.} | x = k, b)  =  prod_{t in traits(u)} p(y_{u,t} | x = k, b)
```

Marginalising the single discrete `x` over its support, holding `b` fixed:

```
  p(y_{u,.} | b)  =  sum_{k=1..K}  p(x = k | z_u)  *  prod_t p(y_{u,t} | x = k, b)
```

In log space, the per-unit contribution is:

```
  log p(y_{u,.} | b)
    = logspace_add_over_k(  log p(x = k | z_u)  +  sum_t log p(y_{u,t} | x = k, b)  )
```

This is a per-UNIT log-sum-exp over K states of (state log-prior + SUM over the
unit's trait rows of per-trait state-conditional log-densities). The inner
`prod_t` becomes an inner `sum_t` in log space -- accumulated into a per-unit,
per-state accumulator BEFORE the outer `logspace_add` over states.

### 3.3 The exact engine shape (Design 67 section 2.3 steps 1-6, specified)

Let `M` = number of units with a missing discrete predictor value;
`mi_unit_id(o)` map each long row `o` to a unit index in `0..M-1` (or a sentinel
for units whose `x` is observed); `K = mi_n_state`. The engine evaluates, at
every TMB call, inside the `objective_function::operator()` AFTER `eta(o)` is
fully assembled (gllvmTMB assembles `eta(o)` in the loop at
`src/gllvmTMB.cpp:1297-1395`, so the state-substituted eta is available before
the likelihood loop at `:1400`):

```
  STEP 1.  Per-state response log-density for each long row of a missing unit.
           For long row o with mi_unit_id(o) = u (u not sentinel) and each
           state k in 0..K-1:
             eta_state(o, k) = eta(o)
                               - b_fix(mi_col) * X_fix(o, mi_col)     # remove obs contribution
                               + b_fix(mi_col) * X_fix_state(o*K + k, mi_col)   # add state-k contribution
             # equivalently eta(o) - fixed_mi_contribution + state_fixed_mi (drmTMB form, sec 3.4)
             ll_otk = <existing fid kernel>(y(o), eta_state(o,k), <trait dispersion>)   # log density
           The kernel is the EXISTING fid dispatch (sec 1.0); only eta differs.

  STEP 2.  Accumulate per-trait log-densities into a per-unit, per-state acc:
             acc(u, k) += weights_i(o) * ll_otk        # sum over the unit's trait rows
           (weights enter HERE, per trait row, NOT via the outer weight scaling,
            because the outer scaling at :1621 is bypassed for gated rows.)

  STEP 3.  Add the predictor log-prior once per unit per state:
             acc(u, k) += log p(x = k | z_u)           # binary/ordered/unordered prior (sec 1.1-1.3)

  STEP 4.  Collapse states once per unit:
             nll -= logspace_add_over_k( acc(u, .) )    # iterated logspace_add over K terms

  STEP 5.  Gate OFF the ordinary per-row response term for ALL trait rows of u
           (sec 2.2): the per-trait densities are already in acc(u,k), so the
           family-dispatch block must not also fire for these rows.

  STEP 6.  Report posterior state weights and the EBLUP summary per missing unit:
             w(u, k) = exp( acc(u, k) - logspace_add_over_k(acc(u, .)) )
             # binary    -> conditional probability  p(x=1 | y_u)        (= w(u,1))
             # ordered   -> expected score  sum_k (k+1) * w(u, k)
             # unordered -> modal category  argmax_k w(u, k)
           REPORT/ADREPORT these (sec 4.4 outputs); they mirror drmTMB
           mi_state_probability + expected_score (src/drmTMB.cpp:943-957).
```

**Implementation ordering note.** Steps 1-3 require TWO passes structured around
units, not one pass over rows:

- A natural shape is a FIRST pass over all long rows that, for each row `o`
  belonging to a missing unit, computes `ll_otk` for all K states and adds
  `weights_i(o) * ll_otk` into `acc(mi_unit_id(o), k)` (an `M x K` matrix of
  `Type`, initialised to zero). The predictor prior (step 3) is added per unit
  after the row pass, or folded in by initialising `acc(u, .)` to the K
  log-priors before the row pass.
- A SECOND, short pass over the `M` missing units does step 4 (`logspace_add`
  over K) and step 6 (posterior weights / EBLUP), subtracting once per unit
  into `nll`.
- The ordinary family loop (`:1400`) runs as today for all NON-missing-unit
  rows, with the gate (section 2.2) skipping the missing-unit rows.

This keeps the SUM EXACT and differentiable, with the `acc` matrix the only new
intermediate. `acc` is `M x K` of AD `Type` -- small (M missing units, K small).

### 3.4 The state-substituted eta -- delta-swap vs full-swap

There are two equivalent ways to obtain `eta_state(o, k)`; both appear in
drmTMB and either is acceptable, but they must be applied consistently:

- **Delta-swap (drmTMB binary, `src/drmTMB.cpp:848-849`):**
  `mu_state = mu(i) + beta_mu(mi_col) * (state_value - X_mu(i, mi_col))`.
  Only the mi column's contribution is corrected; the rest of `eta` stands.
  Cheapest; needs only the scalar `state_value` and the observed
  `X_fix(o, mi_col)`. Best when the mi predictor enters `eta` as a SINGLE
  column (a numeric-coded binary, or a single contrast column).
- **Full-swap (drmTMB ordered / unordered, `src/drmTMB.cpp:927-932`,
  `:1007-1012`):**
  `mu_state = mu(i) - fixed_mu(i) + state_fixed_mu`, where
  `state_fixed_mu = sum_col X_mi_state_mu(i*K + state, col) * beta_mu(col)` is
  the FULL fixed-effect linear predictor with the predictor column(s) forced to
  category `k`. This is necessary when a FACTOR predictor expands to MULTIPLE
  contrast columns (K-1 dummy columns), so forcing `x = k` changes several
  columns at once -- a single-column delta is insufficient.

**Recommendation for gllvmTMB:** use the FULL-SWAP via `X_fix_state` (section 4) for
ordered and unordered (factors expand to several columns), and the delta-swap
for binary (single column). gllvmTMB's analogue of `mu(i) - fixed_mu(i)` is
`eta(o) - (X_fix(o,.) . b_fix)` -- but gllvmTMB does NOT currently store a
per-row `fixed_mu`; it stores the assembled `eta(o)` (fixed + all random
contributions). So the gllvmTMB full-swap is:

```
  eta_state(o, k) = eta(o)
                    - (X_fix(o, .) . b_fix)              # remove ALL fixed-effect contribution
                    + (X_fix_state(o*K + k, .) . b_fix)  # add state-k fixed-effect contribution
```

i.e. swap the ENTIRE fixed-effect linear predictor for its state-`k` version,
leaving every random-effect contribution (latent axes, phylo/spatial fields,
grouped intercepts) untouched -- those do NOT depend on `x`. This is exactly
drmTMB's `mu - fixed_mu + state_fixed_mu` with gllvmTMB's `eta` in place of
drmTMB's `mu`, and `X_fix` in place of `X_mu`. Only the rows of `X_fix_state`
for missing units need be materialised (section 4.2).

### 3.5 Interaction with the OUTER Laplace over the continuous latent

The SUM is EXACT INSIDE the integrand. The clean, correct ordering (Design 67
section 2.3 sub-case ii):

1. The continuous latent `b` (latent axes, phylo / spatial fields, grouped
   random effects, AND any GAUSSIAN missing predictor `x_mis` from Design 67
   section 2.1) is integrated by the OUTER Laplace approximation -- TMB's standard
   random-effect machinery (`R/fit-multi.R:2508-2529` random set,
   `:2549` `MakeADFun`).
2. At EACH inner evaluation of the integrand (each `nll` call), the DISCRETE
   `x` is summed EXACTLY over its K states by the per-unit mixture-of-products
   (section 3.3). The discrete sum is differentiable, so AD propagates its gradient
   to the outer optimisation and to the Laplace curvature normally.

So: continuous latent -> Laplace (approximate, outer); discrete `x` -> exact SUM
(inner, at every integrand evaluation). The discrete `x` is NEVER a Laplace
latent. This is the single most important correctness invariant of the discrete
path, and the error the whole section guards against: do NOT declare a
`PARAMETER` for the discrete `x` and do NOT add it to the `random` set. (Design 59
section 6's `random = {b, b_x, x_mis}` set includes `x_mis` ONLY for the Gaussian
predictor; discrete predictors add NOTHING to `random`.)

The interaction is benign because the SUM lives entirely inside the integrand:
the Laplace approximation sees a smooth marginal `nll` that already has the
discrete states summed out, exactly as it would see any other analytically-
marginalised quantity. drmTMB's continuous random effects (its grouped /
structured covariate-prior intercepts) are Laplace-integrated around the same
SUM (`src/drmTMB.cpp:767-792` declare them random; the SUM at `:832-1042`
evaluates at every call) -- the gllvmTMB ordering is identical, with more
continuous latent axes in the outer integral.

---

## 4. `X_fix_state` design + the K-memory cap (open question 2)

### 4.1 Shape and layout

`X_fix_state` is the long-and-stacked state-design matrix: the gllvmTMB analogue
of drmTMB's `X_mi_state_mu`. drmTMB's `drm_missing_predictor_state_design()`
(`R/missing-data.R:1774-1814`) builds, for each observation `i` and state `s`,
the response model matrix with the predictor column forced to category `s`,
stacked with STATE as the FAST index:

```
  X_mi_state_mu  has  n_obs_response * n_state  rows;
  row index = i * n_state + state               (state fast; src/drmTMB.cpp:928)
  out[seq.int(state, by = n_state, length.out = n), ] <- X_state   (R/missing-data.R:1810)
```

gllvmTMB's analogue:

```
  X_fix_state  has  n_obs_long * K  rows  and  p  columns,
  where n_obs_long = number of STACKED-LONG rows (units x traits),
  row index = o * K + k                          (state fast, matching drmTMB)
  column j  = the fixed-effect design value of long row o with the mi
              predictor column(s) forced to category k.
```

Built R-side by looping over states, forcing the mi factor to level `k`,
rebuilding the long fixed-effect design with the EXISTING gllvmTMB long-design
builder, and slotting it into the `o*K + k` rows -- a direct port of
`drm_missing_predictor_state_design()` over LONG rows (section 4.5, `gll_mi_state_design()`).
A guard (ported from drmTMB `:1805-1808`) asserts the state model-matrix columns
match the base design columns exactly (so the contrast coding is stable).

### 4.2 The memory problem and the resolution (open question 2)

`n_obs_long` is ALREADY large: units x traits. Times `K` and `p` columns,
materialising the FULL `X_fix_state` is `O(n_obs_long * K * p)` -- larger than
drmTMB's `O(n_response * K * p)` by the trait multiplicity. For small-K factors
(the v1 target) this is acceptable; for large K it is not.

Two mitigations, in increasing effort:

- **(a) Materialise, but only the MISSING-unit rows.** The SUM (section 3.3) is
  needed ONLY for rows of units whose `x` is missing -- a fraction of all long
  rows. Restrict `X_fix_state` to the `(sum_t |traits(u)|) over missing units u
  times K` rows, indexed by a compact `mi_state_row(o)` map. This is the
  RECOMMENDED v1 default: it bounds memory by the AMOUNT OF MISSINGNESS, not the
  whole dataset, and is a small change to the drmTMB builder (filter rows to
  missing units before stacking). drmTMB materialises all rows because its
  `n_response` is small; gllvmTMB should filter because `n_obs_long` is not.
- **(b) Compute state-eta on the fly (no materialisation).** Because the
  full-swap (section 3.4) only needs the FIXED-EFFECT linear predictor with the mi
  column(s) set to `k`, and the mi predictor is typically ONE factor expanding
  to known contrast columns, the per-state fixed contribution can be computed
  from the BASE `X_fix(o,.) . b_fix` plus a per-state CORRECTION on just the mi
  columns -- no stacked matrix at all. This is the delta-swap generalised to a
  small contrast block. DEFER this optimisation; it is the escape hatch for big
  K, not the v1 path.

**Recommended K-cap for v1 (the resolved open question 2):**

- **Hard cap: `K <= 12` finite states** for ordered/unordered predictors in v1.
  Above 12, ERROR LOUDLY (a `cli::cli_abort`) with a message naming the cap and
  pointing the user to (i) combine sparse categories, (ii) treat a high-
  cardinality ordered variable as continuous and use the Gaussian `mi()` path,
  or (iii) wait for the on-the-fly state-eta slice (mitigation b). 12 covers the
  overwhelming majority of real ordered scales (Likert, condition scores) and
  unordered factors (habitat, region) while keeping `M x K` accumulators and the
  filtered `X_fix_state` small. Binary is K = 2 (no cap needed).
- Materialise the FILTERED `X_fix_state` (mitigation a) for v1; do NOT
  materialise the whole-dataset stacked matrix.
- Pair the cap with the drmTMB weak-identifiability guards
  (`sum(observed) > n_parameter`, `R/missing-data.R:1014`, `:1182`, `:1390`) so
  a high-K model with thin data fails on identifiability before it fails on
  memory.

The cap of 12 is a judgement call balancing real-world category counts against
`M x K` cost; it is easy to raise later and is enforced by a loud error, not a
silent truncation. A NEW open question this surfaces is whether the cap should
scale with `M` (few missing units could afford larger K) -- see section 9.

### 4.3 Why state is the fast index

Keeping `row = o * K + k` (state fast) MATCHES drmTMB's `i * n_state + state`
layout (`src/drmTMB.cpp:928`, `:1008`, `:1030`) and its R builder's
`seq.int(state, by = n_state, ...)` slotting (`R/missing-data.R:1810`). The
gllvmTMB `manual_*_mi_loglik` brute-force gate references (section 7) reshape
`X_*_state %*% beta` with `byrow = TRUE` and `ncol = K`
(drmTMB `test-missing-predictor-categorical.R:49-54`) -- that reshape assumes
state-fast ordering. Match it so the cross-package gate (section 7) and the brute-
force references stay aligned.

### 4.4 Outputs (REPORT / ADREPORT)

Per missing unit, REPORT the posterior state weights `w(u, .)` and the EBLUP
summary (section 3.3 step 6): conditional probability (binary), expected score
(ordered), modal category (unordered). These populate
`fit$missing_data$predictors$<var>` (the shared-contract registry, Design 59
section 4b) and the `imputed()` / `imputed_predictors()` output frame. `std_error`
is `NA` for finite-state routes in v1 (drmTMB
`drm_imputed_missing_predictor_se()` returns NA for discrete;
`R/missing-data.R:2410`); the discrete imputation reports a fitted conditional
DISTRIBUTION, not a single latent mode with a Hessian SE. The `source` /
`uncertainty_status` strings mirror drmTMB:
`"conditional_probability"` (binary), `"conditional_expected_score"` (ordered),
`"conditional_modal_category"` (unordered) -- verified in the drmTMB build
functions (`R/missing-data.R:1055`, `:1228`, `:1448`) and tests
(`-binary.R:101`, `-ordered.R:107`, `-categorical.R:110`).

### 4.5 `X_fix_state` builder placement

`gll_mi_state_design()` runs R-side after the long fixed-effect design is built
(the gllvmTMB long-design assembly that produces `X_fix`), using the SAME
terms / contrasts object so the state matrices are column-compatible. It is
called only for ordered / unordered (`family in c("ordinal","categorical")`),
matching drmTMB's early return (`R/missing-data.R:1775-1777`); binary uses the
single-column delta-swap and needs no stacked design.

---

## 5. Constructor decision (open question 1) -- `cumulative_logit()` / `categorical()`

**Resolution: adopt Design 67 section 1.3 option A.** Add gllvmTMB
`cumulative_logit()` and `categorical()` PREDICTOR-family constructors with
ALIGNED NAMES and return-shape to drmTMB's, exported from gllvmTMB.

drmTMB's constructors (verified):

- `cumulative_logit()` returns a `drm_family` object with
  `list(name = "cumulative_logit", family = "cumulative_logit", n_response = 1,
  dpars = "mu", links = c(mu = "identity"))` (`R/family.R:260-271`).
- `categorical()` returns a `drm_impute_family` object with
  `list(name = "categorical", family = "categorical",
  link = "baseline_softmax")` (`R/missing-data.R:120-129`).

gllvmTMB ALREADY has an ORDINAL RESPONSE family `ordinal_probit` (fid 14,
Hadfield threshold model, `src/gllvmTMB.cpp:1564-1600`) but NO exported
`cumulative_logit()` / `categorical()` constructors. For the predictor surface,
gllvmTMB adds constructors of the same NAME and return-shape (the shared-contract
"aligned names", Design 59 section 4b). They are predictor-model family tags
consumed by `impute_model(family = ...)`, NOT response families for
`gllvmTMB()`.

Two confirmations the implementer must honour:

1. **The predictor ordered LINK is cumulative LOGIT**, matching drmTMB,
   DISTINCT from the existing RESPONSE `ordinal_probit` (fid 14) which is a
   PROBIT threshold model. Keeping the predictor link = logit (a) keeps the
   finite-state SUM math byte-identical across packages (the section 7 cross-package
   gate depends on it), and (b) avoids a silent probit/logit mismatch with the
   drmTMB lane. A probit predictor link, if ever wanted, is a NAMED extension
   (a future `cumulative_probit()`), not the v1 default.
2. **The cutpoint log-increment loop is REUSED** from gllvmTMB's existing
   ordinal_probit reconstruction (`src/gllvmTMB.cpp:1579-1583`) -- but with
   `K - 1` free cutpoints for the predictor, NOT the `K - 2` (with `tau_1 = 0`)
   used by the response (section 1.2). Port the loop body; do NOT port the
   `tau_1 = 0` fixing.

`impute_model(family = binomial(link = "logit"))` reuses base R's
`stats::binomial`; the family-type dispatcher (gllvmTMB's port of
`drm_impute_family_type()`, `R/missing-data.R:131-172`) must REJECT non-logit
binomial links with the same loud error drmTMB raises (`:136-141`), because the
binary SUM math (section 1.1) is written for the logit prior.

---

## 6. Family-machinery REUSE invariant (no new RESPONSE family)

Restating the section 1.0 invariant, because it is the load-bearing reuse claim and
the borrow-map (section 4 / section 7 of Design 67) leans on it:

- The discrete SUM reuses the EXISTING gllvmTMB per-family RESPONSE kernels
  (Gaussian fid 0, Bernoulli fid 1, Poisson fid 2, ..., ordinal_probit fid 14,
  NB1 fid 15 -- the full dispatch at `src/gllvmTMB.cpp:1412-1614`) UNCHANGED. It
  changes only (a) WHICH eta they evaluate at (state-substituted, section 3.4), and
  (b) that their output is accumulated into `acc(u, k)` and summed inside
  `logspace_add` rather than added directly to `nll`. NO new response family id
  is introduced by missing predictors.
- The PREDICTOR-side priors (binary logit, ordered cumulative-logit, unordered
  softmax) are predictor-model families, orthogonal to the response families.
  They reuse the cutpoint log-increment loop (ordered) and the stable
  `log_inv_logit` helpers; the softmax block (unordered) is the only genuinely
  NEW math.
- A missing ordered PREDICTOR (cumulative_logit) and an ordinal RESPONSE trait
  (ordinal_probit, fid 14) are INDEPENDENT dimensions and may co-occur. They
  share only the log-increment cutpoint parametrisation -- a reuse opportunity
  (port the loop), not a semantic link (Design 67 section 2.4).
- The Gaussian-predictor Laplace path (Design 67 section 2.1) and the discrete SUM
  path are mutually exclusive PER missing variable (a variable is either
  continuous-latent or discrete-summed), set by `impute_model(family=)`. The
  two can co-occur across DIFFERENT missing variables in one fit (the engine
  carries both a Gaussian `x_mis` block and a discrete SUM block); v1 may scope
  to ONE missing predictor per fit (matching drmTMB's single `mi_*` slot) and
  defer multiple simultaneous missing predictors to a later slice -- see section 9.

---

## 7. Verification gates for Phase 5 (Design 59 section 9, Design 67 section 6)

Each gate is written FIRST (tests-as-binding-contract). The drmTMB tests are the
template; the gllvmTMB adaptation is the per-UNIT product (section 3) and the
multivariate cross-package collapse.

### 7.1 Per-family SUM == independent brute-force marginalisation

The canonical gate, ported from drmTMB's `manual_*_mi_loglik` helpers
(`test-missing-predictor-binary.R:26-73`, `-ordered.R:37-...`,
`-categorical.R:35-80`): a hand-rolled R reference that, INDEPENDENTLY of the
TMB engine, forms `sum_k p(x=k|z) p(y|x=k)` and compares it to
`as.numeric(logLik(fit))` at `tolerance = 1e-6`.

- **gllvmTMB adaptation (the multivariate twist made testable):** the R
  reference must, for each missing UNIT, compute the per-state PRODUCT over the
  unit's trait rows
  `prod_t p(y_{u,t} | x = k)` (sum of per-trait log-densities), add the state
  log-prior ONCE, then log-sum-exp over states -- the section 3.2 identity. A
  per-row reference (drmTMB's form applied row-wise) is the WRONG reference and
  must NOT match; a deliberate per-row-vs-per-unit discrimination test
  (constructed so the two differ) guards the twist.
- One reference per family (binary mixture of 2; ordered cumulative-logit
  mixture of K; unordered softmax mixture of K), each reusing the gllvmTMB
  predictor-prior helpers (port of `drm_ordinal_probability_matrix`
  `R/missing-data.R:1329`, `drm_categorical_probability_matrix` `:1571`).

### 7.2 EBLUP recovery

- **Binary:** recover the conditional PROBABILITY `p(x=1 | y_u)` for missing
  units; the imputed estimate is in `[0,1]`, finite, and tracks the true
  generating state when the response is informative
  (`-binary.R:101-104`).
- **Ordered:** recover the EXPECTED SCORE `sum_k (k+1) w(u,k)`; the imputed
  score is in `[1, K]` and tracks the true ordered value
  (`-ordered.R:107`).
- **Unordered:** recover the MODAL CATEGORY `argmax_k w(u,k)`; the imputed
  category is a valid level and matches the true category at a rate above chance
  when the response discriminates (`-categorical.R:110-115`).
- Each recovery sim also recovers the analysis-model `beta` (response fixed
  effects) AND the predictor-model `beta_x` -- the joint-estimation check
  (Design 59 section 9; Curie). `std_error` is `NA` for these routes (section 4.4); SE
  COVERAGE is NOT a v1 gate for discrete predictors (no Hessian SE), unlike the
  Gaussian path.

### 7.3 The >= 3-level ordered guard

Ordered predictors need >= 3 categories; a 2-level ordered factor with
`cumulative_logit()` ERRORS, directing the user to `binomial()`. Plus: every
observed category must be populated (no empty observed level). Ported from
drmTMB `drm_validate_ordinal_missing_predictor()` (`R/missing-data.R:1303-1327`)
and its tests (`-ordered.R:140-192`): the gate fires the messages
"ordered predictor" (unordered factor passed to cumulative_logit),
"fixed effects only" (random effect in the v1 ordered predictor model -- v1 is
fixed-effect-only for discrete, matching drmTMB), and
"Every ordered predictor category" (empty observed category).

### 7.4 Baseline-level invariance (unordered)

The unordered softmax likelihood is invariant to which factor level is baseline.
Gate: relevel the unordered predictor (move a different level to baseline),
refit, and assert (a) `logLik(fit)` is unchanged (tolerance 1e-6), (b) the
imputed conditional probabilities per missing unit are unchanged (up to the
relabelling), and (c) the modal-category imputation is unchanged. drmTMB has no
explicit relevel test, but Design 67 section 6 lists this as a gllvmTMB gate; it is a
mathematical property of the baseline-category softmax and a cheap, high-value
contract test. Also port the drmTMB ">= 3 categories" guard for unordered
(a 2-level factor with `categorical()` errors with "at least three", directing
to `binomial()`; `-categorical.R:204-221`).

### 7.5 Cross-package contract: gllvmTMB-one-trait == drmTMB-univariate

The strongest faithfulness check (Design 67 section 6). For the SAME small dataset
with a SINGLE missing discrete predictor and ONE response trait, gllvmTMB (with
`traits()` collapsed to one trait) and drmTMB-univariate must agree on (a) the
imputed value / state probabilities and (b) `beta_x`, to tolerance. With one
trait the per-unit product (section 3) collapses to a single factor -- exactly
drmTMB's per-row SUM -- so any disagreement signals a broken port (most likely a
gate-indexing error, section 2.2, or a cutpoint-parametrisation mismatch, section 1.2).
Run this for all three families (binary / ordered / unordered).

### 7.6 Weak-identifiability warning

Surface a count of OBSERVED-vs-MISSING predictor values and warn when the
response provides little discrimination among states (Design 67 section 2.3
weak-identifiability tie-in; Design 59 section 9 / Codex review #4). In the
multivariate case the response-side evidence for the missing `x` is the WHOLE
trait vector of the unit, so the warning should consider how strongly the
unit's traits associate with `x` (few observed `x`, or weak trait-`x`
association, => SUM dominated by the prior => unreliable imputation). Port the
drmTMB weak-identification GUARDS (`sum(observed) > n_parameter`,
`R/missing-data.R:1014`, `:1182`, `:1390`) as hard errors, and add the
multivariate discrimination WARNING as a softer signal.

### 7.7 Non-regression / no-op

A fit with no `mi()` discrete predictor is BYTE-IDENTICAL to today (the SUM
block, the `X_fix_state`, and the gate are all gated behind `has_mi == 1 &&
mi_family in {1,2,3}`; when absent, an exact no-op). Mirror the drmTMB
response-mask combination tests (`-binary.R:107-...`, which also check
`nobs(fit) == sum(observed_y)` and `residuals` are `NA` on masked rows).

| Phase 5 slice | Primary gates |
|---|---|
| binary (MD6a) | 7.1 (2-state brute force) + 7.2 (probability EBLUP) + 7.5 (cross-package) + 7.6 + 7.7 |
| ordered (MD6b) | 7.1 (K-state brute force) + 7.2 (expected-score) + 7.3 (>=3-level + empty-category guard) + 7.5 + 7.6 + 7.7 |
| unordered (MD6c) | 7.1 (K-state softmax brute force) + 7.2 (modal-category) + 7.4 (baseline invariance + >=3 guard) + 7.5 + 7.6 + 7.7 |
| all | 7.5 cross-package collapse; 7.6 weak-identifiability; 7.7 no-op non-regression |

---

## 8. Conservative order, and why count predictors are deferred

**Order:** binary -> ordered -> unordered (factors last). Rationale:

- Binary (K = 2, single column, delta-swap, no `X_fix_state`) is the smallest
  correct finite-state slice -- it exercises the SUM identity, the gate, and the
  per-unit product with K = 2 and no stacked design matrix.
- Ordered (K states, full-swap, `X_fix_state`, cutpoint reconstruction) adds the
  stacked state design and the cutpoint loop, but the cumulative-logit prior is
  a 1-D ordered structure (simpler than softmax).
- Unordered (K states, full-swap, `X_fix_state`, NEW softmax prior, baseline
  level) is last: it adds the only genuinely new predictor-model block and the
  baseline-invariance concern. "Factors last" (Design 59 section 7).

**Count predictors (Poisson / NB) are DEFERRED -- restated:** they have
COUNTABLY INFINITE support, so there is NO finite K and the exact SUM does not
terminate. Two routes exist and BOTH are deferred to a later slice that must
decide and justify: (i) a TRUNCATED SUM over a finite window `0..K_max` with a
documented, data-driven truncation bound and an error/warning when the bound is
likely violated; or (ii) a CONTINUOUS-RELAXATION Laplace latent (treat the count
on a transformed scale). Do NOT promise count predictors in v1; the
family-type dispatcher (port of `drm_impute_family_type()`,
`R/missing-data.R:167-171`) must REJECT count predictor families with the same
"needs later family-specific slices" loud error drmTMB raises.

---

## 9. The function-by-function borrow-map (PORT / ADAPT / NEW)

Legend: **PORT** = lift with minimal change; **ADAPT** = same idea, real rework
for stacked-long / multivariate; **NEW** = no drmTMB precedent. This extends
Design 67 section 3.3 with the finite-state specifics and gllvmTMB target names.

### 9.1 R surface / parsing / family dispatch

| drmTMB function (`R/`) | gllvmTMB target | port? | difference |
|---|---|---|---|
| `impute_model(formula, family=)` (`missing-data.R:88`) | `impute_model()` (same name) | PORT | package-agnostic wrapper; same return shape |
| `cumulative_logit()` (`family.R:260`) | `gll cumulative_logit()` | PORT (add) | aligned name + return shape; section 5 |
| `categorical()` (`missing-data.R:120`) | `gll categorical()` | PORT (add) | aligned name + return shape; section 5 |
| `drm_impute_family_type()` (`missing-data.R:131`) | `gll_impute_family_type()` | PORT | same allow-list; reject non-logit binomial + count, same loud errors |
| `drm_standardize_impute_model()` (`missing-data.R:174`) | `gll_standardize_impute_model()` | PORT | bare formula -> Gaussian sugar |
| `drm_validate_single_impute_formula()` | `gll_validate_single_impute_formula()` | PORT | LHS = mi var, name match, no nested mi, no `.` |
| `drm_binary_missing_predictor_response()` (`:1082`) | `gll_binary_mi_response()` | PORT | factor/logical/char/0-1 numeric coding -> {0,1}; exactly-2-level guard |
| `drm_ordinal_missing_predictor_response()` (`:1255`) | `gll_ordered_mi_response()` | PORT | ordered-factor / integer-score coding; rejects unordered factor |
| `drm_validate_ordinal_missing_predictor()` (`:1303`) | `gll_validate_ordered_mi()` | PORT | >= 3 categories + every observed category populated (gate 7.3) |
| `drm_categorical_missing_predictor_response()` (`:1475`) | `gll_unordered_mi_response()` | PORT | unordered factor coding; >= 3 categories guard (gate 7.4) |

### 9.2 R model-build

| drmTMB function | gllvmTMB target | port? | difference |
|---|---|---|---|
| `drm_build_bernoulli_missing_predictor_model()` (`:973`) | `gll_build_binary_mi_model()` | ADAPT | build per-UNIT `x_obs`, `mi_unit_id`, `X_x`, glm.fit warm-start `beta_x`; weak-id guard `sum(obs)>ncol(X)` (`:1014`); single-column delta-swap, no `X_fix_state` |
| `drm_build_ordinal_missing_predictor_model()` (`:1139`) | `gll_build_ordered_mi_model()` | ADAPT | K-state; cutpoint warm-start from empirical cumulative logits (`:1191-1194`); `theta_start` with K-1 free cutpoints (section 1.2); calls `gll_mi_state_design()` |
| `drm_build_categorical_missing_predictor_model()` (`:1347`) | `gll_build_unordered_mi_model()` | ADAPT | K-state softmax; baseline-category warm-start from log odds vs baseline (`:1403-1407`); `(K-1)*p` beta blocks; calls `gll_mi_state_design()` |
| `drm_missing_predictor_state_design()` -> `X_mi_state_mu` (`:1774`) | `gll_mi_state_design()` -> `X_fix_state` | ADAPT | the BIG structural port: stacked over LONG rows x states (state fast, `o*K+k`), FILTERED to missing-unit rows (section 4.2 mitigation a); same column-stability guard (`:1805`) |
| `drm_missing_predictor_metadata()` (`:1902`) | `gll_mi_metadata()` | PORT | populates `fit$missing_data$predictors$<var>` registry (Design 59 section 4b); add the version tag `"MD6a"`/`"MD6b"`/`"MD6c"` analogue |
| `drm_empty_missing_predictor_model()` (`:765`) | `gll_empty_mi_model()` | PORT | no-op default keeps non-mi fits unchanged (gate 7.7) |
| `drm_tmb_missing_predictor_data()` (`:1940`) | `gll_tmb_mi_data()` | ADAPT | packs `tmb_data` slots; add `mi_unit_id`, `mi_unit_observed`, `X_fix_state` (filtered), `mi_state_row`; names are gllvmTMB-long |
| -- (drmTMB binary glm.fit; ordered/unordered cumulative/odds warm-starts) | reuse the same warm-starts | PORT | warm-starts are package-agnostic; they only set `beta_x` / `theta_ord` starting values |

### 9.3 C++ likelihood (`src/drmTMB.cpp` -> `src/gllvmTMB.cpp`)

| drmTMB C++ block | gllvmTMB target | port? | difference |
|---|---|---|---|
| DATA/PARAMETER mi slots (`mi_family`, `mi_col`, `mi_observed`, `mi_missing_index`, `X_mi`, `mi_n_state`, `X_mi_state_mu`, `beta_mi`, `theta_ord`) (`src/drmTMB.cpp:24-39`) | gllvmTMB analogues + `mi_unit_id`, `mi_unit_observed`, `mi_state_row` | ADAPT | add long->unit indices; `X_mi_state_mu` -> filtered `X_fix_state`; `mi_observed` becomes per-unit `mi_unit_observed` |
| `mi_family == 1` binary 2-state SUM (`:832-864`) | binary per-UNIT mixture | ADAPT | reuse `log_p1`/`log_p0` prior verbatim; RESPONSE term becomes `sum_t` over trait rows into `acc(u,k)`, log-sum-exp once per unit (section 3.3); delta-swap eta |
| `mi_family == 2` ordered K-state SUM (`:866-966`) | ordered per-UNIT mixture | ADAPT | reuse cutpoint loop (gllvmTMB fid-14 helper, but K-1 free cutpoints, section 1.2); per-UNIT product; full-swap eta via `X_fix_state` |
| `mi_family == 3` unordered K-state SUM (`:968-1044`) | unordered per-UNIT mixture | ADAPT (+ NEW softmax) | softmax prior block is NEW; per-UNIT product; full-swap eta; baseline `eta_state(0)=0` + max-subtraction logsumexp guard |
| state-substituted `mu`: delta-swap (`:848`) / full-swap `mu - fixed_mu + state_fixed_mu` (`:932`,`:1012`) | `eta_state(o,k)` (section 3.4) | ADAPT | gllvmTMB has assembled `eta(o)`, not `fixed_mu(i)`; full-swap = `eta(o) - X_fix(o,.).b_fix + X_fix_state(o*K+k,.).b_fix` |
| per-unit `acc(u,k)` accumulation + `logspace_add_over_k` (NEW pattern; drmTMB sums per-row) | the `M x K` accumulator + 2-pass shape | **NEW** | the multivariate per-unit-product engine (section 3.3); NO drmTMB precedent -- drmTMB never groups response densities by a unit |
| discrete-row response gate (`:1163-1170`, cond `:1165-1166`) | extend `is_y_observed(o)` guard (`src/gllvmTMB.cpp:1411`) | ADAPT (CRITICAL) | gate condition uses per-UNIT `mi_unit_observed(mi_unit_id(o))`; gate ALL trait rows of a missing unit (section 2.2) |
| `mi_state_probability` / `expected_score` REPORT (`:943-957`, `:1023-1037`) | per-unit posterior weights + EBLUP REPORT/ADREPORT | PORT | binary probability / ordered expected score / unordered modal category (section 4.4) |
| `drm_log_inv_logit` / `_diff` helpers (`src/drm_numeric.h`) | gllvmTMB equivalents | PORT (add) | gllvmTMB has `logspace_add`/`logspace_sub` but lacks the named `log_inv_logit` helpers; add a small header or inline them for the ordered prior |

### 9.4 Extractors / output

| drmTMB | gllvmTMB | port? | difference |
|---|---|---|---|
| `imputed()` + discrete `source` strings (`:1055`,`:1228`,`:1448`) | `imputed.gllvmTMB` / `imputed_predictors()` | PORT | same return frame; `source` in {conditional_probability, conditional_expected_score, conditional_modal_category}; `std_error = NA` |
| `drm_imputed_missing_predictor_se()` (discrete -> NA) (`:2410`) | port | PORT | discrete -> NA SE in v1 (section 4.4) |
| state-probability registry slot (`conditional_probabilities`, `conditional_modal_category`) (`-categorical.R:88`,`:115`) | `fit$missing_data$predictors$<var>` fields | PORT | aligned field names; carry per-unit posterior weights |

### 9.5 What is NOT borrowed (gllvmTMB-only)

- The `M x K` per-unit accumulator and the 2-pass mixture-of-products engine
  (section 3.3) -- **NEW**, the core gllvmTMB contribution.
- `mi_unit_id` / `mi_unit_observed` / `mi_state_row` long->unit indices --
  **NEW** indexing (Design 67 section 2.0 introduced `mi_unit_id`; the discrete path
  adds the observed-flag and state-row maps). Reused from the Gaussian Phase 2a
  build (built once, consumed by both paths).
- The filtered (missing-units-only) `X_fix_state` (section 4.2) -- an ADAPT of
  drmTMB's builder with a filtering step drmTMB does not need.

---

## 10. Open questions

**Resolved here (the two the task posed):**

1. **Constructor names (open question 1):** ADOPT option A -- add gllvmTMB
   `cumulative_logit()` and `categorical()` predictor-family constructors with
   names + return-shape aligned to drmTMB (section 5). The predictor ordered link is
   cumulative LOGIT (distinct from the RESPONSE `ordinal_probit` probit, fid 14);
   the cutpoint log-increment loop is reused from fid 14 but with `K - 1` free
   cutpoints (NOT the response's `tau_1 = 0`, `K - 2` convention).
2. **`X_fix_state` K-cap (open question 2):** hard cap `K <= 12` finite states
   for v1, enforced by a loud `cli::cli_abort` above the cap (section 4.2);
   materialise the FILTERED (missing-units-only) `X_fix_state`, not the
   whole-dataset stacked matrix; defer on-the-fly state-eta (mitigation b) to a
   later slice. Binary is K = 2 (uncapped, single-column delta-swap, no
   `X_fix_state`). Pair the cap with the ported weak-identifiability guards.

**NEW open questions this analysis surfaced (for the maintainer):**

3. **K-cap vs M (amount of missingness).** The fixed cap `K <= 12` ignores that
   memory cost is `O((rows of missing units) * K * p)`, so a fit with FEW
   missing units could afford a larger K. Should the cap scale with the number
   of missing units / rows (e.g. allow larger K when `M` is small), or stay a
   flat, predictable constant? Recommend the flat constant for v1 (predictable,
   easy to document) and revisit only if a real use case needs high-K with low
   M.

4. **One missing discrete predictor per fit, or several?** drmTMB carries a
   SINGLE `mi_*` slot (one missing predictor). gllvmTMB's `impute = list(...)`
   surface admits several entries. The discrete engine (section 3.3) and the gate
   (section 2.2) are written for ONE missing discrete predictor's `mi_unit_id` /
   `mi_family`. Supporting MULTIPLE simultaneous missing discrete predictors
   needs either (a) a JOINT SUM over the product space of their supports
   (combinatorial -- `K1 * K2 * ...` states, expensive) under a joint predictor
   model, or (b) an independence assumption across missing predictors (sum each
   marginally -- only valid if they are conditionally independent given `z`).
   Neither is in drmTMB. Recommend v1 scopes to ONE missing discrete predictor
   per fit (matching drmTMB), with a loud error on multiple, and defers the
   multi-predictor decision to a dedicated slice. (A Gaussian `mi()` and a
   discrete `mi()` on DIFFERENT variables can still co-occur, since the Gaussian
   one is a Laplace latent and does not enter the discrete SUM -- but even that
   should be gated to v2 unless a slice validates it.)

5. **Discrete-predictor + structured covariate prior (phylo/spatial) for the
   PREDICTOR model.** drmTMB's discrete predictor models are FIXED-EFFECT ONLY
   (the "fixed effects only" guard, gate 7.3; `-ordered.R:172`). A phylogenetic
   or grouped prior on a DISCRETE missing predictor (e.g. an ordered trait with
   phylogenetic structure on its cumulative-logit `eta_x`) is neither in drmTMB
   nor scoped here. It would add a Laplace-integrated `b_x` to the predictor's
   `eta_x` WHILE the discrete states are still summed exactly -- a clean
   composition (continuous prior latent, discrete state SUM), but unvalidated.
   Recommend deferring; flag as the natural Phase-5-structured follow-on.

---

## 11. Summary of decisions (for reviewers)

1. **Finite-state SUM, not Laplace.** Discrete missing predictors are
   marginalised EXACTLY by `nll -= logspace_add_over_k(log p(x=k|z) +
   log p(y|x=k))`, with NO latent parameter and NOTHING added to the `random`
   set. Reuses the existing per-family RESPONSE kernels at state-substituted eta;
   introduces NO new response family (section 1, section 6).
2. **The gate is mandatory.** The SUM REPLACES the ordinary per-row response
   term; gllvmTMB extends the `is_y_observed(o)` guard
   (`src/gllvmTMB.cpp:1411`) with a per-UNIT `mi_unit_observed(mi_unit_id(o))`
   condition, mirroring drmTMB `src/drmTMB.cpp:1165-1166`. Omitting it
   double-counts `y` (section 2).
3. **The multivariate per-unit-product is the NEW engine (no drmTMB precedent).**
   `sum_k [ p(x=k|z_u) * prod_t p(y_{u,t}|x=k) ]`: an `M x K` accumulator filled
   by a row pass, then `logspace_add` over K once per unit, then the gate. A
   per-row SUM is WRONG (it counts the prior T times and lets states differ
   across traits). The discrete SUM is EXACT inside the integrand; only the
   continuous latent is Laplace-approximated (section 3).
4. **`X_fix_state` cap = 12, filtered to missing units** (open question 2);
   binary uses a single-column delta-swap and no stacked design; ordered /
   unordered use the full-swap via `X_fix_state` (section 3.4, section 4).
5. **Constructors: option A** -- add aligned `cumulative_logit()` (cumulative
   LOGIT, K-1 free cutpoints, distinct from the probit `ordinal_probit` fid 14)
   and `categorical()` (baseline softmax) (open question 1; section 5).
6. **Order: binary -> ordered -> unordered**, factors last; count predictors
   deferred (no finite support) (section 8).
7. **Gates** mirror the drmTMB `manual_*_mi_loglik` brute-force references at
   tolerance 1e-6, plus the gllvmTMB-specific per-row-vs-per-unit discrimination
   test and the gllvmTMB-one-trait == drmTMB-univariate cross-package collapse
   (section 7).

---

## 12. Anchors (verified by reading the current trees)

**drmTMB (`/Users/z3437171/Dropbox/Github Local/drmTMB`):**

- `src/drmTMB.cpp:24-41` -- mi DATA/PARAMETER slots
  (`mi_family`, `mi_col`, `mi_observed`, `mi_missing_index`, `X_mi`,
  `mi_n_state`, `X_mi_state_mu`, `mi_quad_nodes`, `mi_quad_weights`).
- `src/drmTMB.cpp:762-830` -- `mi_family == 0` Gaussian latent (Laplace; section 1.4,
  out of scope).
- `src/drmTMB.cpp:832-864` -- `mi_family == 1` binary 2-state SUM.
- `src/drmTMB.cpp:866-966` -- `mi_family == 2` ordered K-state cumulative-logit SUM.
- `src/drmTMB.cpp:968-1044` -- `mi_family == 3` unordered baseline-softmax K-state SUM.
- `src/drmTMB.cpp:1046-1146` -- `mi_family == 4` beta predictor via FIXED quadrature
  (section 1.4; out of scope, template for future bounded-continuous).
- `src/drmTMB.cpp:1163-1170` (condition `:1165-1166`) -- the discrete-row response
  GATE.
- `src/drm_numeric.h:35,41,47` -- `drm_log_inv_logit`, `drm_log1m_inv_logit`,
  `drm_log_inv_logit_diff`.
- `R/missing-data.R:88` -- `impute_model()`; `:120` -- `categorical()`;
  `:131` -- `drm_impute_family_type()`; `:174` -- `drm_standardize_impute_model()`.
- `R/family.R:260` -- `cumulative_logit()`.
- `R/missing-data.R:973` / `:1139` / `:1347` -- bernoulli / ordinal / categorical
  build functions; `:1303` -- `drm_validate_ordinal_missing_predictor()`;
  `:1774` -- `drm_missing_predictor_state_design()` -> `X_mu_state`;
  `:1902` -- `drm_missing_predictor_metadata()`;
  `:1940` -- `drm_tmb_missing_predictor_data()`;
  `:2410` -- `drm_imputed_missing_predictor_se()`.
- `R/missing-data.R:1014`,`:1182`,`:1390` -- weak-identifiability guards
  (`sum(observed) > n_parameter`).
- `tests/testthat/test-missing-predictor-binary.R:26-73` (manual brute force),
  `:82` (version `"MD6a"`); `-ordered.R:90` (`"MD6b"`), `:140-192` (guards);
  `-categorical.R:35-80` (manual brute force), `:90` (`"MD6c"`),
  `:204-221` (>=3 guard).

**gllvmTMB (worktree `/private/tmp/gll-md-phase5`):**

- `src/gllvmTMB.cpp:37` -- `is_y_observed`; `:48` -- `X_fix` (n_obs x p);
  `:49-50` -- `trait_id` / `site_id`; `:52` -- `n_traits`;
  `:223-224` -- `Ainv_phy_rr` / `log_det_A_phy_rr`; `:307` -- `weights_i`;
  `:310` -- `b_fix`.
- `src/gllvmTMB.cpp:476-478` -- `eta_fix = X_fix * b_fix`, `eta(o) = eta_fix(o)`.
- `src/gllvmTMB.cpp:1297-1395` -- eta assembly loop (state-substitution point).
- `src/gllvmTMB.cpp:1400-1623` -- stacked-long likelihood loop;
  `:1405` `nll_before_row`; `:1411` `if (is_y_observed(o))` (the gate hook);
  `:1412-1614` `fid` family dispatch; `:1616` end-guard;
  `:1621-1622` weight scaling.
- `src/gllvmTMB.cpp:1564-1600` -- ordinal_probit (fid 14) RESPONSE family;
  `:1579-1583` -- cutpoint log-increment reconstruction (reuse, with the K-2 vs
  K-1 caveat, section 1.2).
- `R/fit-multi.R:974` -- `model.frame(..., na.action = na.pass)` (mi-intercept
  point); `:2508-2529` -- `random` set accumulation (`x_mis` append hook for the
  Gaussian path; discrete adds NOTHING here); `:2549` -- `MakeADFun`.
