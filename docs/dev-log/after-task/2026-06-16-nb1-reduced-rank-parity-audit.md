# After Task: NB1 Reduced-Rank Parity Audit

## Goal

Test whether NB1 bridge evidence can move from no-latent fitted-object parity to
reduced-rank (`d = 1`) fitted-object parity.

## Implemented

No code or test behavior changed. This slice adds an evidence audit and updates
the project ledgers so reduced-rank NB1 stays partial instead of being promoted
from weak evidence.

## Mathematical Contract

The candidate reduced-rank NB1 model was:

```text
eta_ti = beta_t + lambda_t z_i
z_i ~ N(0, 1)
Var(y_ti) = mu_ti * (1 + phi_t)
df = p beta values + p loadings for d = 1 + p phi values = 6
```

The no-latent cell has parity; the reduced-rank cell still needs objective-form
or optimiser investigation.

## Files Changed

- `docs/dev-log/2026-06-16-nb1-reduced-rank-parity-audit.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-nb1-reduced-rank-parity-audit.md`

## Checks Run

- Rehydration:
  `git status --short --branch && git log --oneline -8`
  -> clean on `codex/r-bridge-grouped-dispersion`, tip `a2ba3e8`.
- Julia rehydration:
  `git -C ../GLLVM.jl-integration status --short --branch && git -C ../GLLVM.jl-integration log --oneline -5`
  -> clean on `codex/julia-per-trait-dispersion`, tip `903b5b9`.
- Pre-edit lane check:
  `gh pr list --state open --json number,title,headRefName,baseRefName,updatedAt,isDraft --limit 20`
  -> `[]`.
- Initial reduced-rank probe:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> existing fixture delta `1.035`; deterministic fixtures close but
  boundary-dominated.
- Native optimiser control probe:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> BFGS sometimes converged but still near `phi -> 0`.
- Julia optimiser tolerance probe:
  `julia --project='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' - <<'JL' ...`
  -> tightening `g_tol` from `1e-5` to `1e-11` did not move the Julia reduced-rank
  NB1 optima.
- Non-boundary seed search:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla - <<'RS' ...`
  -> best converged non-boundary candidate still had logLik delta `-0.07678`
  and max `phi` delta `1.73`.
- Stale-claim scans:
  `rg -n "NB1.*full parity|full native parity|full parity|complete bridge|CRAN-ready bridge|NB1.*covered.*Julia|Grouped NB1 reduced-rank fits match|reduced-rank NB1.*covered|reduced-rank NB1 parity remains unpromoted|0\.07678|Gamma.*native parity|native parity.*Gamma|Gamma.*covered.*Julia" docs/dev-log/2026-06-16-nb1-reduced-rank-parity-audit.md docs/dev-log/after-task/2026-06-16-nb1-reduced-rank-parity-audit.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md`
  -> expected audit, ledger, coordination-board, and historical scan-command
  hits only; no new NB1 full-parity or Gamma native-parity claim.
  `rg -n "NB1 stable no-X fitted-object fixture|NB1 still needs fitted-object objective parity|reduced-rank NB1 fitted-object parity is now covered|reduced-rank NB1.*matches native" docs tests R README.md NEWS.md vignettes | head -120`
  -> historical scan-command strings only; no current stale status wording.
- Whitespace:
  `git diff --check` -> clean.

## Tests Of The Tests

No test was added because the evidence did not justify a stable assertion. The
work here is a negative evidence audit: it prevents a false green test with an
arbitrary tolerance.

## Consistency Audit

`JUL-01` remains `partial` and now links to the reduced-rank NB1 audit. The
coordination board now says the next NB1 lane is objective-form / optimiser
investigation, not parity promotion.

AGENTS.md convention-change cascade is not triggered. No public function,
argument, formula grammar, roxygen block, generated Rd, README, NEWS, vignette,
or pkgdown navigation file changed.

## What Did Not Go Smoothly

The close-looking deterministic fixtures were tempting, but they sat on the NB1
dispersion boundary. Treating those as parity evidence would have created a
fragile and misleading row.

## Team Learning

- Gauss/Karpinski: reduced-rank NB1 needs same-parameter objective comparison to
  separate likelihood-form drift from optimiser/local-mode drift.
- Fisher/Curie: non-boundary fixture search is essential before admitting a
  reduced-rank parity row.
- Rose: no-latent NB1 parity and reduced-rank NB1 parity must remain separate
  claims.

## Known Limitations

The audit does not fix reduced-rank NB1 parity. It narrows the next technical
work to objective-form comparison and boundary handling.

## Next Actions

1. Expose or script a fixed-parameter reduced-rank NB1 objective comparison
   against native TMB.
2. Compare boundary conventions for NB1 `phi` near zero.
3. Revisit fitted reduced-rank parity only after same-parameter objective
   parity is proven.
