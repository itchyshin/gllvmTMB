# Design 56 — Augmented-LHS engine generalisation (Stage 3) [stub]

**Maintained by:** Boole (parser-spec author), Gauss (TMB
template author), Noether (math-vs-implementation alignment),
Rose (scope honesty), Shannon (cross-team coordination).
**Lead authors when written in full:** maintainer + Boole +
Gauss + Noether.
**Status:** **STUB** — escalation slot opened 2026-05-26 by
Design 55 §A1 closeout memo. This is not the full design doc;
it is the place that doc will live and a structured todo for
what it must contain.
**Triggered by:**
[`docs/dev-log/audits/2026-05-26-design-55-a1-closeout.md`](../dev-log/audits/2026-05-26-design-55-a1-closeout.md)
— Design 55 §A1 attempt closed with parser-only hypothesis
structurally disconfirmed.

## 1. Why this stub exists

The codebase has long referred to "Design 07" as the
conventional shorthand for the augmented-LHS engine
generalisation work (visible in `R/brms-sugar.R:1573`'s error
message: *"require Design 07 Stage 3 engine work"*). The
numbered design doc itself was never written — it was a
placeholder name in code comments only.

Design 55's A1 attempt revealed that the engine work is
genuinely required to ship any of Phase A's structural-slope
capability. Per Design 55 §8, this stub opens the placeholder
into a concrete design slot. When the maintainer authorises
the Stage 3 work, this stub becomes the parent design doc;
until then, every code reference to "Design 07" or "Stage 3"
points here.

## 2. Scope when written in full

The full Design 56 must specify:

### 2.1 Parameter-shape generalisation

- Promote `b_phy_slope` from `vector<Type>` (length
  `n_aug_phy`) to `matrix<Type>` (`n_aug_phy × n_lhs_cols`).
- Promote `x_phy_slope` from `vector<Type>` (length `n_obs`)
  to `matrix<Type>` (`n_obs × n_lhs_cols`).
- Analogous promotions for `b_phy_diag`, `b_spde_*`,
  `b_animal_*` (any structural block that may absorb augmented
  LHS).

### 2.2 The `n_traits` → `n_lhs_cols` audit

Per the long-standing 9-site `n_traits` hardcoding audit in
`R/fit-multi.R` (`n_lhs_cols = T × (1 + Q)` where `Q` is the
number of additional LHS components beyond the trait stack —
zero for intercept-only, one for intercept + slope on a single
covariate):

- Enumerate each `n_traits` site in `R/fit-multi.R` (the
  audit shorthand named these as "nine sites").
- Decide per site whether the literal stays as `n_traits` or
  becomes `n_lhs_cols`.
- Add `DATA_INTEGER(n_lhs_cols)` to the TMB template; thread
  through every block that touches structural random effects.

### 2.3 The `2 × 2` (intercept, slope) covariance

For each structural family + keyword admitted by Design 55
§5's applicability matrix:

- Define the prior on the bivariate intercept + slope. For
  `unique` and `latent`: matrix-normal with `Σ_b` a `2 × 2`
  covariance per family. For `indep`: diagonal `Σ_b` (no
  cov(intercept, slope)). For `dep`: full unstructured
  `2T × 2T`. `scalar` is not applicable per Design 55 §5.
- Parameterise via `theta_b` with `log_sd_b_int`,
  `log_sd_b_slope`, `cor_int_slope` (or equivalent
  Cholesky-decomposed form).
- Verify identifiability for each (family × keyword × LHS)
  cell.

### 2.4 Cross-family generalisation

- For each non-Gaussian family in Phase B scope (binomial,
  nbinom2, ordinal-probit, mixed-family), trace whether the
  link-residual machinery (`R/extract-sigma.R:99-280`
  `link_residual_per_trait()`) composes cleanly with the new
  matrix-shape `b_*` parameters.
- Phase B's B0 scoping audit captures the per-cell
  identifiability conclusions.

### 2.5 The fail-loud / silent-collapse boundary

Design 56 must specify the **invariant** that prevents the
Sokal silent-collapse anti-pattern from recurring:

- Before any keyword accepts an augmented LHS at the parser
  level, the engine block it routes through must already
  understand `n_lhs_cols > T`.
- The `.assert_no_augmented_lhs()` guard at
  `R/brms-sugar.R:1543-1576` cannot be loosened in the same
  PR that doesn't also extend the engine block; the
  invariant is checked at PR review time and asserted at fit
  time.

### 2.6 Migration of `phylo_slope()` and `animal_slope()`

- The existing scalar-only `phylo_slope(x | sp)` engine path
  (currently `b_phy_slope` as a vector) becomes a special
  case of the new general path (intercept-only column in the
  augmented Z matrix; equivalent to `phylo_unique(0 + x | sp)`).
- Soft-deprecation per Design 55 §6 happens in this PR
  sequence.
- Validation-debt rows RE-02, FG-15, PHY-06, ANI-06 walk
  Gaussian → `covered` as the relevant Phase A cells'
  recovery tests land.

## 3. Implementation phases (when this doc is written in full)

Sketch only; the full doc will refine these.

- **Phase 56.0**: full Design 56 (this stub → real doc).
- **Phase 56.1**: TMB template edit — promote `b_phy_slope`
  to matrix; add `n_lhs_cols`; gate behind `use_phylo_slope` +
  new `use_phylo_slope_correlated` flag.
- **Phase 56.2**: R-side wrapper — build augmented Z matrix
  from parsed LHS; pass into TMB data.
- **Phase 56.3**: parser-only changes from Design 55 §4
  shipped *together* with the engine changes (no PR
  separates them).
- **Phase 56.4**: recovery test for `phylo_unique(1 + x | sp)`
  Gaussian (the test Design 55 §A1 originally specified;
  now runs against the correct engine).
- **Phase 56.5**: walk the remaining Design 55 §5
  applicability cells.
- **Phase 56.6**: validation-debt register updates per Design
  55 §A6.

## 4. Effort estimate

Per Design 55 §A1 estimate when engine work is required:
**+1-2 weeks** beyond the parser-only baseline. Realistic
calendar: ~2-3 weeks of focused work from authorisation to
Phase A close.

## 5. Authorisation gate

This stub is opened by the A1 closeout memo. The full
Design 56 is **not authorised to be written** without
maintainer go-ahead. Reasoning: writing the full Stage 3
design commits the team to a multi-week engine slice and
requires explicit lead-author assignment (Boole + Gauss +
Noether + maintainer).

When the maintainer authorises Stage 3:
1. Replace this stub with the full design content per §2.
2. Assign lead-authors and reviewers per the maintainer's
   call.
3. Phase A of Design 55 unblocks; A2 onwards proceeds against
   the new engine.

Until then, this stub is the durable record that Stage 3 work
exists as a queued lane. Design 55 §A1 is closed; Phase A
beyond A1 is blocked; Phase B is blocked behind Phase A.

## 6. Cross-references

- [Design 55 — Structural-dependence × random-slope grammar
  (Phase A0)](55-structural-slope-grammar.md) — parent design
  that this stub is the escalation slot for; §8 stop
  condition + §4.5 engine-change rationale.
- [Design 55 A1 closeout memo](../dev-log/audits/2026-05-26-design-55-a1-closeout.md)
  — the empirical case for why this stub exists.
- `R/brms-sugar.R:1530-1576` — `.assert_no_augmented_lhs()`
  guard + Sokal silent-collapse documentation; the error
  message that has been referring to "Design 07 Stage 3" all
  along now points here.
- `R/brms-sugar.R:2317-2325` — `phylo_unique` bare-name
  rewrite path (must be extended to accept bar form).
- `src/gllvmTMB.cpp` `b_phy_slope` block — primary site of
  the matrix-shape promotion.
- `R/fit-multi.R` — nine hardcoded `n_traits` sites per the
  long-standing audit.
- [Design 04 — Random effects](04-random-effects.md) §"Items
  11/12" — the original `reserved` / `planned` status of
  random slopes inside structural keywords.
- Validation-debt rows **RE-02** / **RE-03** / **FG-15** /
  **PHY-06** / **ANI-06** — all blocked behind this design.

— Stub opened 2026-05-26 by Claude/Shannon (coordinator).
Full authoring deferred to maintainer authorisation.
