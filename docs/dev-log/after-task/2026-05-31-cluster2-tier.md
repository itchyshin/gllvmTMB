# After Task: cluster2 -- second independent diagonal grouping tier

**Branch**: `agent/cluster2-tier`
**Date**: `2026-05-31`
**Roles (engaged)**: Boole (parser/engine), Gauss (family-agnostic claim), Rose (validation-debt register), Curie (recovery cell)

## 1. Goal

Implement the cluster2 random-effect tier (issue #342, sub-issues #355 parser+engine,
#356 per-family validation): a SECOND independent diagonal grouping so a user can fit two
crossed (or nested) plain diagonal per-trait variance components at once (e.g.
`cluster = "site"` AND `cluster2 = "year"`). Per the #342 design memo, cluster2 is a
byte-for-byte structural copy of the existing `cluster` (`diag_species` / `q_sp`) diagonal
tier, renamed for a second grouping (`diag_cluster2` / `r_c2`). It is family-agnostic: the
contribution is added to `eta` before family dispatch, so no per-family C++ branching is
required (the same reason `diag_species` works across all families today).

## 2. Implemented

- New public argument `cluster2 = NULL` on `gllvmTMB()` (default inactive). When set to a
  grouping column name, a `unique(0 + trait | <cluster2 col>)` term fits a per-trait
  variance at that second grouping.
- Engine slot `use_diag_cluster2` detected as `any(kinds == "diag" & groupings == cluster2_col)`,
  mirroring `use_diag_species`. Data (`cluster2_id`, `n_cluster2`), params
  (`theta_diag_cluster2`, `r_c2`), map-off-when-inactive, and `random` registration all
  parallel the diag_species path.
- C++: four additions in `src/gllvmTMB.cpp`, each a renamed copy of the diag_species lines
  (DATA, PARAMETER, NLL prior reporting `sd_c2`, and the `eta += r_c2(t, cluster2_id(o))`
  accumulation). No new likelihood / link / Laplace-structure change.
- Extractor: `extract_Sigma(fit, level = "cluster2", part = "unique")$s` returns the
  `sd_c2^2` diagonal; `level` match.arg vocab and `.normalise_level()` pass-through updated.
- Foot-gun guard: `latent`/`rr`/`dep` on the cluster2 column aborts with a `unit =`
  redirect (the engine has no reduced-rank slot at the cluster2 tier; mirrors the existing
  `rr | species` cluster-tier guard, avoiding the Sokal silent-collapse).
- `fit$cluster2_col` stored on the fit object (NULL when the slot is unused).

## 3. Files Changed

- Engine: `R/gllvmTMB.R` (arg + roxygen + threading), `R/fit-multi.R` (detector, id wiring,
  tmb_data / tmb_params / tmb_map / random / fit metadata, foot-gun guard), `src/gllvmTMB.cpp`
  (4 blocks).
- Extractor: `R/extract-sigma.R` (cluster2 branch + level vocab), `R/normalise-level.R`.
- Docs: `man/gllvmTMB.Rd`, `man/extract_Sigma.Rd` (roxygen-regenerated),
  `docs/design/35-validation-debt-register.md` (NEW row RE-11).
- Tests: `tests/testthat/test-cluster2-rename.R` (new).

## 3a. Decisions and Rejected Alternatives

- **Decision**: Followed the #342 memo (public `cluster2 = NULL` argument + `unique()` on the
  cluster2 column) rather than a new `cluster2()` formula keyword. **Rationale**: the memo is
  the binding design and explicitly says "no change to the brms-sugar.R keyword->kind
  dispatch"; the grouping is just a column name walked by the generic `(lhs | group)` parser.
  **Confidence**: high (matches the cluster-tier precedent exactly).
- **Decision**: cluster2 is diagonal-only (Slice E, the reduced-rank `latent` slot, deferred
  per the memo's recommendation). **Rejected alternative**: adding a `theta_rr_c2` / `z_c2`
  block now -- out of scope and the memo flags it for an explicit maintainer go.

## 4. Checks Run

- `devtools::load_all()` -> `LOAD_ALL_OK` (DLL compiles).
- `devtools::document()` -> `DOCUMENT_OK` (reverted 5 unrelated roxygen-drift `.Rd` files to
  keep the diff surgical; kept only `gllvmTMB.Rd` + `extract_Sigma.Rd`).
- `test-cluster2-rename.R` (NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1): PASS=24 FAIL=0 ERROR=0 SKIP=0.
- Equivalence gate hard check: `cluster`-routed vs `cluster2`-routed `unique(0+trait|species)`
  -> objective delta = 0.000e+00, sd delta = 0.000e+00 (exactly byte-identical).
- Regression: `test-cluster-rename.R` (13/0), `test-extract-sigma.R` (31/0),
  `test-sigma-rename.R` (9/0/1 pre-existing skip), `test-extract-sigma-table.R` (55/0),
  `test-tiers-poisson.R` (19/0), `test-tiers-beta.R` (36/0), `test-olre-separation.R` (23/0),
  `test-multi-random-intercepts.R` (24/0). TOTAL FAIL=0 ERROR=0.

## 5. Tests of the Tests

- Equivalence gate (byte-identical) and the `cluster2_col` / `diag_cluster2` assertions are
  net-new surface that can only pass with the implementation present (verified the gate
  delta is exactly 0, and that the cluster slot is inactive in the cluster2 fit and vice
  versa -- no double-counting).
- Regression guard: `cluster2 = NULL` default produces an objective identical to an explicit
  `cluster2 = NULL` fit; the `diag_cluster2` flag is FALSE and `cluster2_col` is NULL.
- Crossed recovery (heavy): Gaussian site (0.9) + year (0.5) crossed variances recovered
  within a 0.30 band, conv == 0.
- Family-agnostic smoke: Poisson fit converges with finite `sd_c2` (no per-family branch).

## 6. Consistency Audit

- `grep -n "cluster2|r_c2|diag_cluster2"` across `R/` + `src/`: every R-side flag has its
  matching C++ DATA/PARAMETER/NLL/eta line; the `random` vector, `tmb_map` off-switch, and
  `tmb_data` entries are all paired. `sd_c2` is REPORT-ed and consumed by both the extractor
  and the tests.
- `grep -n "allowed_groups"`: cluster2_col is the only addition to the rr/diag grouping
  allowlist; the `bad_groups` abort message is unchanged for the existing three slots.

## 7. Roadmap Tick

RE-11 added to `docs/design/35-validation-debt-register.md` (`covered`,
`test-cluster2-rename.R`).

## 7a. GitHub Issue Ledger

- #342 (umbrella), #355 (parser+engine), #356 (per-family validation): referenced in the PR
  body. Slices A-D (parser + engine + cpp + extractor + structural/equivalence/recovery
  tests) landed here. Slice F (full per-family recovery sweep `test-cluster2-families.R`) and
  Slice E (reduced-rank `latent` at cluster2, recommended defer) remain as follow-ups under
  #356 / #342. No issues closed by this PR.

## 8. What Did Not Go Smoothly

- The #342 memo line references were ~25 lines off from current `origin/main` (the file
  drifted since the memo was written); resolved by grepping for the anchor symbols
  (`use_diag_species`, `q_sp`, `theta_diag_species`) rather than trusting raw line numbers.
- `devtools::document()` regenerated 5 unrelated `.Rd` files (roxygen-version drift on main);
  reverted to keep the PR diff scoped to cluster2.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Boole**: the "rename + copy diag_species" recipe held exactly -- the only non-mechanical
  step was the disjointness rule (a `unique(0+trait|G)` term routes to whichever slot column
  matches G, so cluster2 must be a column distinct from unit / unit_obs / cluster, else the
  variance is double-counted across two active slots). The tests encode this explicitly.
- **Gauss**: family-agnosticism confirmed empirically (Gaussian recovery + Poisson smoke)
  and structurally (the eta contribution precedes the family switch).
- **Rose**: RE-11 is a single new row; no existing rows edited (concurrent-edit-safe).

## 10. Known Limitations And Next Actions

- Slice F: the full per-family recovery sweep (`test-cluster2-families.R`, mirroring the
  cluster-tier `test-tiers-*.R` pattern across binomial/probit, nbinom2, Beta,
  ordinal_probit, plus smoke families) is the remaining validation debt for #356.
- Slice E: a reduced-rank `latent(... | cluster2, d = K)` slot is deliberately NOT
  implemented (memo recommends keeping cluster2 diagonal-only). The foot-gun guard makes the
  boundary explicit.
- A non-confounding warning (when `cluster2_id` is a bijection of an existing tier's id
  vector) is noted in the memo as a nicety; not implemented here (out of the A-D slice scope).
