# Handover — Response-column coefficient Arc 2

## Status

Arc 1 is complete as a clean, committed local foundation on
`codex/response-column-coef-arc1`, based on snapshot
`1bacee9a808b4106ce681502463baa317dcb9d9b`. It is not a public feature and
must not be presented as merge-ready until the branch is refreshed against the
live remote and the separate baseline article failure is reconciled.

Exact local continuation:

```sh
cd /private/tmp/gllvmTMB-column-coef-arc1-exact.IdLrx2
git status --short --branch
git log --oneline --decorate -6
```

## Read First

1. `AGENTS.md`
2. `docs/design/131-response-column-coefficient-foundation.md`
3. `docs/design/130-response-column-slope-family.md`
4. `docs/design/01-formula-grammar.md` (FG-20 surface)
5. `docs/design/35-validation-debt-register.md` (FG-20)
6. `docs/dev-log/after-task/2026-08-26-response-column-coefficient-foundation.md`
7. the final 2026-08-26 entry in `docs/dev-log/check-log.md`

## Arc 1 Delivered

- a trailing documented `gllvmTMB(..., column_data =)` argument;
- exact long keys on the resolved trait column and exact wide keys on the
  synthetic literal `trait` column;
- fixed-effect-only metadata joins with collision, grouping, covariance,
  offset, coefficient-basis, and internal-carrier guards;
- an internal top-level `shared()` marker for common wide fixed effects, while
  preserving user-defined functions named `shared`;
- inert parsers for `column_coef()`, `phylo_coef()`, `animal_coef()`,
  `kernel_coef()`, and `spatial_coef()`;
- explicit basis, bar, source, rho-intent, rank-overlap, and placement checks;
- a classed pre-engine fence; and
- focused regression evidence for existing `traits()` and `*_slope()` routes.

No helper is exported, no coefficient likelihood exists, and no TMB source was
changed.

## Protected Contracts

- `*_slope()` continues to mean slope-only response-column coefficients and
  remains unchanged and warning-free.
- `column_data` row order is irrelevant, but its key set is exact. Long input
  uses the resolved trait name; wide input uses literal `trait` and rejects a
  custom `trait =` value.
- metadata are fixed-effect-only and cannot overwrite `.y_wide_`,
  `.offset_wide_`, `.multinom_group_`, or `.multinom_L_`.
- `shared()` and every `*_coef()` marker must be top-level additive terms.
- absence of `shared()` leaves existing wide response-specific expansion
  unchanged; a user-defined `shared()` function is not captured.
- `rho` is source-correlation strength under the raw-scale-preserving blend;
  it is not generically a variance share.
- `column_coef()` has IID response-column structure and no rho.
- phylo/animal/kernel omitted rho means estimable intent; spatial omitted rho
  remains fixed at one until its joint rho-range identifiability gate.
- fixed `spatial_coef(rho = 0)` maps range off.
- one response-column coefficient source per model.

## Arc 2 Owed Work

1. Run lane preflight, refresh from live `origin/main`, inspect intervening
   changes, and rebase or recreate the Arc 1 commits without touching the
   separate dirty article lane.
2. Choose one smallest source-specific slice. Do not implement all five at
   once. `column_coef()` is the simplest IID engine; `phylo_coef()` is the
   scientifically central gllvm-like slice but also requires the rho mixture.
3. Write the exact symbolic-to-TMB layout table first: coefficient ordering,
   design matrix, `K_rho`, `Sigma_coef`, transforms, objective contribution,
   and reported parameters.
4. Add failing parser-to-engine, malformed-source, and known-DGP recovery tests
   before likelihood code. Curie must review the data-generating process.
5. Implement only that source, including source alignment and a deliberate
   map for fixed versus estimated rho.
6. Add an extractor contract and point-estimate recovery. Intervals and broad
   family coverage remain later gates.
7. Decide explicitly whether and how `screen_gllvmTMB()` propagates
   `column_data`; Arc 1 did not change it.
8. Review API names with Boole before export. An internal parser is not an API
   commitment.
9. Run targeted package/docs checks, then the repository's full macOS, Ubuntu,
   and Windows CI before any public teaching claim.

## Known External/Parallel State

The Arc 1 full article render reproduced a baseline failure in the unchanged
`where-does-the-tree-go.Rmd`: `extract_Sigma(..., level = "column_slope")` is
not supported. The article source was byte-identical to baseline and the
original worktree already contained separate article edits. Do not repair that
failure from this coefficient branch without a fresh lane decision.

GitHub access was unavailable during Arc 1, so current PR/issue state and
remote freshness were not verified. Reconcile both before integration.

## Still Deferred

Wide `*_coef()` grammar and public column-metadata teaching, latent predictor
covariance, non-Gaussian multi-predictor coefficients, intervals, simultaneous
response-column sources, and a general rho retrofit for the existing 5 x 3
covariance grid.
