# Design 107 — Missing-data support for the VA objective

**Status:** design, internal-research only. Authorises no export, no `method=`
argument, no public capability claim. No code, no `R/`, no `src/`, no
`inst/tmb/` change is implied by this document. `NAMESPACE c97ae039`
untouched. Written read-only against `inst/tmb/gllvmTMB_va_r3.cpp` (378
lines) and `src/gllvmTMB.cpp` (2595 lines); neither file is modified here.

**Why this is first.** Ayumi's model (`Ayumi-495/BIRDBASE_pcm#3`) uses
`miss_control(response = "include")` — response missingness is *retained*,
not dropped to complete cases. `gllvmTMB_va_r3.cpp` currently hard-errors
unless every `N*T` cell is present ("`every unit-trait cell must occur
exactly once`", line 198). Her data cannot enter the VA engine at all today.
Everything below specifies the minimal, verifiable change that removes that
gate.

---

## 1. The algebra: response missingness is benign for the ELBO

### 1.1 The expected log-likelihood is already a sum over cells

The ELBO the template computes (lines 353–356) is

```
ELBO(beta, Lambda, {m_i, S_i}) = expected_loglik - total_kl
                                = sum_i sum_t E_q(u_i)[log p(y_it | eta_it)]
                                  - sum_i KL(q(u_i) || N(0, I_q))
```

with `eta_it = x_it' beta + lambda_t' u_i` and `q(u_i) = N(m_i, S_i)`. This is
exactly the double sum realised by the row loop at lines 292–351: each row
`r` maps to one `(i, t) = (unit_id(r), trait_id(r))` cell, computes
`ell = E_q[log p(y_it | eta_it)]` in closed form or by quadrature, and
accumulates it into `expected_loglik_by_unit(i)` (line 350).

Introduce an observation indicator `O_it in {0, 1}`. The missing-data-aware
objective is simply

```
expected_loglik = sum_i sum_t O_it * E_q(u_i)[log p(y_it | eta_it)]
```

A missing cell (`O_it = 0`) contributes **exactly** zero to this sum — not
approximately zero, not a zero-imputed value passed through the density, but
a term that is not in the sum at all. This is the same "drop the missing
term" recipe already used for the Laplace engine's response mask (see §4);
nothing about the VA/ELBO structure requires anything more elaborate. The
`v_it = ||L_i' lambda_t||^2` and `mu_it` quantities are well-defined for
every `(i,t)` regardless of `O_it` (they depend only on `beta, Lambda, m_i,
L_i`, never on `y`), so there is no difficulty in principle even evaluating
them for missing cells — the point is that the *density* term `log p(y_it |
eta_it)` must never be evaluated on a missing cell, both because `y_it` is
not a real observation there and, more importantly, because doing so would
silently reintroduce the very information the missingness is supposed to
withhold.

### 1.2 The KL term is unchanged — confirmed against the formula, not asserted

`kl_by_unit(i)` (lines 254–266) is built from `trace(S_i)`, `m_i' m_i`,
`logdet(S_i)`, and `q` alone:

```cpp
kl_by_unit(i) = 0.5 * (trace_S + mean_sq - logdet_S - q);
```

Nothing in that expression references `y`, `unit_id`, `trait_id`, or any
per-cell quantity — it is a function of the unit's own variational
coordinates against the fixed `N(0, I_q)` prior. It is per-*unit*, not
per-*cell*, by construction (Design 160's parameterisation). Introducing
`O_it` therefore leaves `total_kl` and every `kl_by_unit(i)` bit-for-bit
identical for identical `(m_i, log_L_diag(i,.), L_off(i,.))`. This was asked
to be confirmed rather than asserted; the confirmation is that the formula
above contains no term that could change.

### 1.3 The condition: this requires missingness to be ignorable, and it is the SAME condition Laplace already assumes

Dropping missing cells from the expected-log-lik sum yields a valid ELBO —
a lower bound on `log p(y_obs | theta)` — only under the standard
missing-data-mechanism assumption: **MAR (missing at random) with distinct
parameters**, i.e. ignorability (Rubin 1976; Little & Rubin 2019). This is
not a new assumption introduced by the VA route. It is the identical
condition already invoked in `docs/design/59-missing-data-layer.md`
("**Why ML is valid here.** FIML is valid under MAR with distinct parameters
and a correctly specified joint model") for the shipped Laplace engine's
`miss_control(response = "include")` path, which uses the *exact same*
"skip the term for unobserved rows" recipe (§4 below). So the VA template
inherits Design 59's existing MAR caveat verbatim; it does not need, and
should not invent, a separate missing-data theory. The one thing worth
saying plainly to a user (Ayumi's data will not be MCAR by design — bird
non-detection is rarely independent of the true value) is that MAR is an
assumption about the *mechanism*, not something the package can verify from
the data, and non-random detection processes (occupancy-type missingness)
are a substantive MNAR risk that neither this template nor the Laplace
engine currently model.

---

## 2. What breaks: validation-only versus genuinely structural

Reading `inst/tmb/gllvmTMB_va_r3.cpp` end to end, **nothing in the actual
arithmetic requires completeness.** Every requirement that currently forces
`n_obs == N*T` is a *validation gate*, not a structural necessity of the sum,
the KL, the variance projection, or the REPORT vectors. Concretely:

- **The cell-count check (lines 173–199).** `cell_count[i*T+t]` is
  incremented once per row and then required to equal exactly 1 for every
  cell (line 197: `if (cell_count[cell] != 1) error(...)`). This is pure
  defensive validation of the *shape* of the input; it does not participate
  in `expected_loglik`, `total_kl`, or the gradient in any way. Relaxing it
  to "`<= 1`, and exactly the cells with `is_y_observed == 1` are the ones
  counted" is a pure loosening of a gate, not a rewrite of any computation.
  The companion check at line 151 (`if (n_obs != N * T) error(...)`) is the
  gate that currently forces the *dense* row layout (one row per cell,
  always); see §5 for why the recommendation keeps this gate and reinterprets
  it, rather than removing it.

- **The per-unit accumulation loop (lines 292–351).** The loop is already
  written as "for each row `r`, add its `ell` to `expected_loglik_by_unit(i)`"
  (line 350: `expected_loglik_by_unit(i) += ell;`). This is algebraically
  identical to the `O_it`-weighted sum in §1.1 for whatever subset of rows is
  present, or whatever subset has `is_y_observed(r) == 1` if the dense
  convention is kept. **This loop requires no change to its accumulation
  logic** — only a gate around whether `ell` for a given row is computed
  and added at all (see §5).

- **The variance projection (lines 302–314).** `v = ||L_i' lambda_t||^2` is a
  function of `unit_id(r)` and `trait_id(r)` only — it does not reference
  `y(r)`, `n_trials(r)`, or any other row's observedness. It is exactly as
  well-defined for a missing cell as for an observed one, and there is no
  reason to suppress computing it (it is a legitimate diagnostic even at
  missing cells — see §5's REPORT recommendation).

- **The REPORT vectors (lines 277–286, 360–375).** `mu_by_obs`, `v_by_obs`,
  `expected_loglik_by_obs`, `softplus_expectation_by_obs` are already sized
  and indexed **per row** (`n_obs`), not per cell in a dense `N x T` sense —
  they are naturally "ragged-compatible" already. Nothing about their shape
  needs to change if some rows are masked rather than dropped. `Lambda`,
  `Sigma_B`, `m`, `L_flat`, `S_flat` are per-trait or per-unit and are
  untouched by any of this.

**Net conclusion for §2:** the "every cell exactly once" requirement is
100% enforced by validation code (lines 151, 173–199) that exists because
the template's author chose to also use completeness as an implicit
correctness check on the R-side data assembly, not because the ELBO/KL
computation needs it. Removing/relaxing that validation is safe *provided*
the row loop is also updated to gate the density evaluation itself (§5) —
otherwise a "relaxed" validation would silently let a sentinel `y` value
flow into `log p(y | eta)` and corrupt `expected_loglik_by_unit`.

---

## 3. Identifiability: what happens to q(u_i) as observed cells shrink

### 3.1 Few observed cells

Restricting the per-unit ELBO to the rows actually observed for unit `i`:

```
ELBO_i(m_i, S_i) = sum_{t : O_it = 1} E_q[log p(y_it | eta_it)]
                   - KL(q(u_i) || N(0, I_q))
```

As the observed set for unit `i` shrinks, the data term contributes less
curvature and less pull away from the prior, but it never becomes
ill-posed: the KL term is a strictly convex function of `(m_i, S_i)` with a
unique global minimum, so the per-unit objective always has a well-defined
optimiser — it is just increasingly dominated by the prior term as
information from data disappears. This is qualitatively benign (the
posterior shrinks toward the prior, as expected under a Bayesian-style
regulariser), and does not by itself destabilise the optimiser, because the
KL Hessian w.r.t. `(m_i, log_L_diag(i,.), L_off(i,.))` never degenerates —
unlike, e.g., a fixed effect with a genuinely flat likelihood, a variational
covariance block is always regularised by its own prior-matching term.

### 3.2 Zero observed cells — verified against the KL formula, not asserted

For a unit with **no** observed cells, `O_it = 0` for all `t`, so the data
term in `ELBO_i` is identically zero for *any* `(m_i, S_i)` — the objective
for that unit's block reduces to

```
ELBO_i(m_i, S_i) = - KL(q(u_i) || N(0, I_q))
```

to be maximised (equivalently, `negative_elbo` minimised). Since
`KL(q || p) >= 0` with equality **iff** `q = p` (a standard, exact property
of KL divergence, not an approximation), the unique maximiser of `-KL_i` is
`q(u_i) = N(0, I_q)` exactly: `m_i = 0`, `S_i = I_q`, i.e.
`log_L_diag(i, .) = 0` and `L_off(i, .) = 0`. Substituting `S_i = I_q`,
`m_i = 0` into the KL formula (lines 263–264) gives

```
trace_S = q,  mean_sq = 0,  logdet_S = 0
kl_by_unit(i) = 0.5 * (q + 0 - 0 - q) = 0
```

So the claim in the brief — "its q should equal the prior exactly and
contribute zero KL" — **is correct, and follows algebraically from the KL
formula already in the template**, not merely a plausible default. A
zero-observed-cell unit is a well-posed, benign input at the level of the
objective function: it contributes exactly zero to both `expected_loglik`
and `total_kl`, and its variational block has a unique, non-degenerate
optimum at the prior.

### 3.3 The caveat this does NOT cover

The argument above is about the mathematical optimum of the *objective*,
not about whether a general-purpose optimiser (`nlminb`, TMB's inner/outer
loop) actually reaches `(0, I_q)` in finite iterations from an arbitrary
starting point, nor about numerical conditioning when many units
simultaneously have few or zero observed cells (their gradient contribution
to the *shared* parameters `beta` and `Lambda` is also near zero, so they
become uninformative passengers for those parameters — correct behaviour,
but worth confirming empirically that it does not inflate standard errors
or ill-condition the joint Hessian; see §6).

---

## 4. The existing package convention: `is_y_observed`

`src/gllvmTMB.cpp` (the shipped Laplace engine) already solves exactly this
problem, and its convention is worth reading precisely before deciding
whether the VA template should match it.

- **Declaration (line 88):**
  `DATA_IVECTOR(is_y_observed); // 1 = response observed, 0 = missing (n_obs).`
  with the comment: *"Phase 1 response mask: rows with 0 add nothing to the
  likelihood and their y entry is a safe sentinel (filled on the R side).
  All-ones under `miss_control(response="drop")` -> an exact no-op."*
  Critically, this is a **dense** convention: `n_obs` still enumerates every
  row (every trait observation slot) — missing cells are *present* as rows
  with a sentinel `y`, not *absent* from the data.

- **Usage — the density is gated, not just zeroed (lines 2371–2382):**
  ```cpp
  // Phase 1 response mask: a row with is_y_observed(o) == 0 contributes
  // nothing to the likelihood. Its y(o) is a safe sentinel, so we must NOT
  // evaluate any family density on it (that is the sentinel-invariance
  // guarantee, design 59 sec.9).
  if (family_id_vec(o) != 16 && is_y_observed(o) && !mi_missing_row) {
    nll -= obs_loglik(o, eta(o));
  } else if (family_id_vec(o) != 16 && is_y_observed(o) && mi_missing_row) {
    ...
  }
  ```
  The `is_y_observed(o)` conjunct appears in **both** live branches — a row
  with `is_y_observed(o) == 0` falls through **both** conditions and the
  density function `obs_loglik` is never called on it at all. This is
  stronger than "add a zero contribution": it is "never evaluate the
  density," which matters because a sentinel `y` might not even be a valid
  argument to the family's log-density (e.g. a non-integer sentinel handed
  to a Poisson/binomial density). The same discipline governs the
  multinomial anchor-row branch (line 2338: `if (is_anchor &&
  is_y_observed(o))`).

- **The name "sentinel-invariance guarantee"** is explicitly Design 59 §9's
  vocabulary — the property that the ELBO/NLL and its gradient must be
  bit-identical regardless of *what* placeholder value R fills into a masked
  `y` cell, because the density is never evaluated there. This is a
  checkable, named test, not just a description.

### Recommendation

**Yes — the VA template should adopt the identical convention**: the same
`DATA_IVECTOR(is_y_observed)` name, the same dense/sentinel row layout
(every `(i,t)` cell remains a row; `n_obs` stays `N*T`), and the same
"skip the density call entirely" discipline, rather than switching to a
ragged/dropped-row representation where missing cells simply are not present
as rows. Three reasons:

1. **Shared R-side data assembly.** The R code that turns a wide/long data
   frame with `NA` responses into `(y, n_trials, X, unit_id, trait_id,
   is_y_observed)` can be written once (or trivially adapted) and reused
   between the Laplace and VA templates, rather than maintaining two
   different missing-data row conventions.
2. **Minimal disruption to existing structural checks.** The dense
   convention lets `n_obs == N*T` (line 151) stay exactly as is; only the
   "count == 1" gate (line 197) needs to allow a masked cell to be "present
   but flagged," and only the per-family range validation (lines 181–194)
   needs to be conditioned on `is_y_observed(r)`.
3. **A precedent test exists.** Sentinel-invariance (Design 59 §9) is
   already a named, implemented QA pattern in this repository. Reusing the
   convention lets the same test be applied verbatim to the VA template
   rather than inventing a new one.

The one place the two engines are *not* identical and should not be forced
to be: `is_y_observed` in the Laplace engine also interacts with the
missing-*predictor* machinery (`mi_missing_row`, lines 2360–2399), which is
out of scope here — the VA template's `is_y_observed` should govern
*response* missingness only, matching the scope named in the task brief.

---

## 5. Minimal implementation sketch (specification, no code)

**Data changes**
- Add `DATA_IVECTOR(is_y_observed)`, length `n_obs`, dense (one entry per
  cell, matching the existing `unit_id`/`trait_id`/`y`/`n_trials` layout).
  `n_obs` continues to equal `N*T` (line 151 unchanged).
- R-side sentinel policy for masked cells: fill `y` and `n_trials` with
  values that trivially satisfy each family's structural validity
  constraints (e.g. `y = 0`, `n_trials = 1`) purely so the row can pass
  through indexing without triggering a spurious error — **not** because
  those values are ever used in a computation (they are never fed to a
  density call; see below).

**Validation changes**
- Line 151 (`n_obs != N*T`): unchanged.
- Lines 173–199 (`cell_count`): the "occurs exactly once" check continues to
  hold structurally (dense convention means every cell is still exactly one
  row); what must change is that the **family-specific range/integer checks
  on `y`/`n_trials`** (lines 181–194) are only applied when
  `is_y_observed(r) == 1` — a masked row's sentinel should not be required to
  satisfy, e.g., the binomial `0 <= y <= n` constraint.
- Add a validation pass on `is_y_observed` itself: length `n_obs`, entries in
  `{0, 1}` (mirroring the style of the existing GH-node/weight validation at
  lines 200–205).
- Explicitly **not** an error: a unit whose rows are all `is_y_observed ==
  0`. Per §3.2 this is a valid, benign input, not a degenerate one — the
  validation code must not reject it.

**Loop changes**
- Row loop (lines 292–351): compute `mu` and `v` unconditionally for every
  row (they do not depend on `y` and remain useful diagnostics — see REPORT
  below). Gate the **family-density branch** (`ell = ...`, lines 320–343)
  and its accumulation into `expected_loglik_by_unit(i)` (line 350) behind
  `if (is_y_observed(r))`, mirroring the Laplace engine's "never call the
  density on a masked row" discipline (§4) rather than computing `ell` on
  the sentinel and zeroing it afterward. For a masked row,
  `expected_loglik_by_obs(r)` is set to `0` and `softplus_expectation_by_obs(r)`
  is left at its `setZero()` default; no family branch is entered.
- KL loop (lines 241–275): **no change** — confirmed unaffected in §1.2/§2.
- REPORT block (lines 360–375): no structural change. Consider also
  `REPORT(is_y_observed)` for downstream bookkeeping symmetry with the
  Laplace engine's `predict_missing()` path, since `mu_by_obs`/`v_by_obs`
  are already reported for every row and are the natural inputs to a future
  missing-response prediction on the VA side.

**What is genuinely new to test, not merely inferred algebraically**
- **Sentinel invariance** on the VA template (Design 59 §9's test, applied
  here): vary the sentinel `y`/`n_trials` values at masked cells and confirm
  the ELBO and its gradient are bit-identical.
- **Zero-observed-unit convergence in practice**: confirm that TMB's
  optimiser actually drives a zero-observed unit's `(m_i, log_L_diag(i,.),
  L_off(i,.))` to `(0, 0, 0)` from a generic starting point, and that this
  does not stall or destabilise the joint optimisation of `beta`/`Lambda`
  (§3.3's open question — the objective is well-posed; whether the
  optimiser reliably finds it is untested).
- **Recovery under MCAR/MAR at varying missingness rates**: confirm
  `Sigma_B`/`beta` recovery does not degrade beyond what reduced effective
  sample size predicts (wider intervals, not bias) — this is an empirical
  question the algebra in §1 does not answer.
- **Hessian/SE conditioning** when many units have very few observed cells
  simultaneously (a joint-optimisation concern that the per-unit argument in
  §3 does not cover).
- **Interaction with `eval_method == 1` (Jaakkola–Jordan)** and the
  binomial-specific range checks (lines 183–189): confirm the masked-row
  gate composes cleanly with the existing `family == 1` validation once that
  validation is conditioned on `is_y_observed`.
- Flag to Ayumi's use case specifically: her missingness is very unlikely to
  be MCAR (bird detection is not independent of the true trait), so even
  after this lands, the MAR/ignorability assumption in §1.3 is a modelling
  judgement she is making, not something the package verifies — worth
  saying explicitly rather than letting "the template now accepts missing
  data" read as "the template validates the missing-data assumption."

---

## Summary

1. The ELBO's expected-log-lik term is a sum over cells; masking a cell out
   of that sum is exact, not approximate. The KL term is per-unit and is
   algebraically unaffected — confirmed against the formula in
   `gllvmTMB_va_r3.cpp` lines 254–266, not merely asserted. The condition
   required is standard MAR/ignorability, and it is the **same** condition
   `docs/design/59-missing-data-layer.md` already invokes for the shipped
   Laplace engine — no new assumption is introduced.
2. Nothing in the template's arithmetic requires completeness. The
   `n_obs == N*T` check (line 151) and the cell-count-exactly-one check
   (lines 173–199) are validation gates, not structural necessities; the
   accumulation loop, variance projection, and REPORT vectors are already
   written in a form compatible with masked/ragged data.
3. A unit with zero observed cells has a provably benign optimum:
   `q(u_i) -> N(0, I_q)` exactly, contributing exactly zero KL — verified
   from the KL formula, not assumed. Few-observed-cell units are
   well-posed for the same reason but are untested in practice for
   optimiser convergence and joint-Hessian conditioning.
4. The Laplace engine's `is_y_observed` convention (dense rows, sentinel
   `y`, density call gated out entirely) should be adopted verbatim by the
   VA template for consistency of R-side data assembly and reuse of the
   existing sentinel-invariance test.
5. The implementation is a validation relaxation plus one `if` gate around
   the family-density branch — not a rewrite of the KL, variance
   projection, or REPORT logic. What is untested (and must be, before this
   is trusted) is optimiser behaviour at sparse/zero-observed units and
   recovery quality under realistic (non-MCAR) missingness rates.
