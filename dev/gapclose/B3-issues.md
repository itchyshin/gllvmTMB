# B3 — issues to file with the gap-closure draft PR (drafts; filed via `gh issue create`)

Each issue names the GLLVM.jl reference implementation (branch/commit on GLLVM.jl `origin/main`
unless marked) so the R port can start from a working oracle. Source of the list:
`tools/parity_ledger.R --ref origin/main` (Julia-only rows dispositioned `PORT`) plus the matched
rows where R is `planned` and Julia `implemented`. Owner decision 2026-09-02: parity both ways for
user-facing capabilities; bridge stays R->Julia.

## 1. Zero-inflated families zip / zinb / zib (ARC D checkpoint, first)
R has no zero-inflated family; the bridge cannot reach Julia's either (`.GLLVM_JULIA_BRIDGE_FAMILIES`).
Julia: `fit_zip_gllvm`, `fit_zinb_gllvm`, `fit_zib_gllvm` (+ `_cov` variants), `src/families/`,
tests `test/test_zero_inflated.jl`, `test_zi{p,nb,b}_x_identity.jl`. Port plan: symbolic alignment
table first (add-simulation-test skill), TMB likelihoods in `src/gllvmTMB.cpp`, constructors in
`R/families.R`, 14-slot registry rows (Design 02), recovery on a known DGP (Totoro pre-run, then a
DRAC job array), register rows, NEWS scope statement. Gauss/Noether review; maintainer sign-off
before merge (new family).

## 2. Cumulative-logit ordinal response family (distinct name)
R ships `ordinal_probit()` only; R's `cumulative_logit()` is a missing-PREDICTOR imputation family,
so the new response family needs a distinct name (owner decision pending in the decision map's fog
table; default: new name for the response family). Julia: `Ordinal` (cumulative logit),
`src/families/ordinal.jl`, `test/test_ordinal_fit.jl`.

## 3. Automatic latent-rank selection `select_lv()` and boundary-corrected LRT / `anova`
R offers `logLik()` only for comparing `d = 1` vs `d = 2`; no `anova` method, no chi-bar-square
boundary p-value. Julia: `select_lv` (`src/model_selection.jl`, `test/test_model_selection.jl`),
`chibar2_pvalue` / `variance_lrt` / `profile_ci_variance` (`src/boundary_inference.jl`,
`test/test_boundary_inference.jl`).

## 4. `ordination_uncertainty()`
R ordination scores are point-only (`extract_ordination()`, `ordiplot()`). Julia:
`src/ordination_uncertainty.jl`, `test/test_ordination_uncertainty.jl`.

## 5. `censored_poisson()` engine
Exported constructor, register `blocked` (FAM-16 tracks truncated families only). Julia has the
working engine: `fit_censored_poisson_gllvm`, `src/families/censored_poisson.jl`,
`test/test_censored_poisson.jl`. Either build the likelihood or stop exporting the constructor.

## 6. Fourth-corner / trait–environment estimand
Trait x environment interactions are expressible in the formula grammar, but there is no named
fourth-corner estimand or extractor. Julia: `FourthCornerFit`, `fit_fourthcorner_gllvm`,
`confint_fourthcorner`, `src/families/fourthcorner.jl`, `test/test_fourthcorner.jl`.

## 7. Constrained / concurrent / reduced-rank ordination and the quadratic response (0.8 headline)
Julia: `ConstrainedOrdinationFit`, `ConcurrentOrdinationFit`, `RRRFit`, `fit_*_gllvm`,
`confint_constrained`, `confint_rrr`; `QuadraticFit`, `fit_quadratic_gllvm`;
`test/test_constrained_ordination.jl`, `test_rrr.jl`, `test_quadratic.jl`. Owner default: 0.8.

## 8. Bare aborts without a next step: the remainder behind the ratchet
`tests/testthat/test-gapclose-next-steps.R` pins the package-wide count of aborts with no
next-step bullet at 658 (may only fall). Inventory of the first 14 files:
`dev/gapclose/abort-inventory.tsv` (495 calls, 318 bare, 24 "Internal:") — the user-reachable set
and all "Internal:" aborts were fixed in the gap-closure PR; the rest is this issue. Rule:
AGENTS.md "tell the reader what to try next".

## Cross-lane (not issues here; written handoffs)
- GLLVM.jl lane: their ledger's `mi()` row says `planned` while `fit_gllvm_mi*` + tests exist
  (ledger drift); ordinary `dep()` under `engine = "julia"` fails before the labelled gate
  (`FIT-MODE-ORD-DEP-PUBLIC-R-BRIDGE`) — bridge lane (#1236) work; `offset()` rejected by the bridge;
  `latent(unique = TRUE)` Psi dropped with only a warning.

### Facts received from the GLLVM.jl lane, 2026-09-02 (recorded, not verified here)
- NB2 second-order hole on the Julia side: `confint`'s finite-difference joint Hessian goes singular
  at a degenerate huge-dispersion optimum where R's `sdreport` still returns finite SEs; CI on Julia
  1.12.7 shows NaN Wald endpoints on the NB2 grouped-covariate bridge cell (`test_bridge_x.jl:350`).
  Do not count NB2 Wald through `engine = "julia"` as receipted; the R ledger's bridge CI rows stay
  `scope-limited`.
- Their zero-inflated ADEMP recovery campaign finished on Totoro (6,000 fits, 0 errors; findings doc in
  flight): ARC D (issue 1 above) has a working Julia oracle and a DGP grid to mirror.
- Both handoffs above are tickets T13/T14 in GLLVM.jl `docs/dev-log/core070/true-parity-decision-map.md`;
  their `mi()` row stays `planned` until a pasted test receipt.
