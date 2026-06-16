# After-Task Report: Julia Per-Trait Dispersion And Cutpoints Spec

Date: 2026-06-16

Branch: `codex/julia-per-trait-dispersion-spec`

## Task

Write the per-trait dispersion and ordinal cutpoint specification for the
`GLLVM.jl` -> `gllvmTMB` bridge, using the current native R/TMB contract and
paired Julia runtime evidence. This is immediate work-sequence item 4 in the
twin finish programme.

## Files Changed

- `docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md`
- `docs/dev-log/after-task/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md`
- `docs/dev-log/shannon-audits/2026-06-16-julia-per-trait-dispersion-spec.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## Definition-Of-Done Check

1. Implementation: not applicable. This is a spec/readout slice only.
2. Simulation recovery test: not applicable. No feature was implemented or
   advertised.
3. Documentation: complete for this design step. The spec records current truth,
   payload shapes, scale maps, `df` rules, ordinal cutpoint shape, test matrix,
   issue boundary, and reviewer ownership.
4. Runnable user-facing example: not applicable. No public capability was
   promoted.
5. Check-log entry: added with exact source-inspection, coordination, and
   stale-wording scan commands.
6. Review pass: Shannon and Rose perspectives applied. Gauss/Noether/Fisher/
   Curie/Hopper/Karpinski are assigned for the implementation lane; they are not
   claimed as active signoffs on this docs-only spec.

## Commands Run

```sh
git status --short --branch
git diff --stat
git diff
tail -n 100 docs/dev-log/check-log.md
ls -t docs/dev-log/recovery-checkpoints
sed -n '1,220p' docs/dev-log/recovery-checkpoints/2026-06-10-102134-codex-lambda-boundary-claude-note.md
git log --oneline --decorate -12
gh pr list --state open --json number,title,headRefName,baseRefName,isDraft,updatedAt,url --repo itchyshin/gllvmTMB
git log --all --oneline --since="6 hours ago"
git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task docs/dev-log/shannon-audits
sed -n '1,240p' R/julia-bridge.R
rg -n "per-trait|dispersion|cutpoint|ordinal|nbinom|Gamma|Beta|nbinom1|nbinom2" docs/design/03-likelihoods.md R/julia-bridge.R tests/testthat/test-julia-bridge.R
sed -n '1,260p' src/bridge.jl
sed -n '480,780p' src/bridge.jl
sed -n '1,320p' src/families/grouped_dispersion.jl
sed -n '320,760p' src/families/grouped_dispersion.jl
sed -n '1,260p' src/families/ordinal.jl
sed -n '1,240p' docs/src/gllvmtmb-parity.md
sed -n '1,260p' docs/src/response-families.md
rg -n "fit_nb_gllvm\\(|fit_nb_gllvm_grouped|fit_nb1_gllvm\\(|fit_beta_gllvm\\(|fit_gamma_gllvm\\(|dispersion = fill|df = p \\+ _bridge_rr_df|cutpoints|ordinal|n_categories" src/bridge.jl
rg -n "fit_nb1_gllvm_grouped|NB1GroupedFit|GammaGroupedFit|fit_gamma_gllvm_grouped|_nparams\\(fit::NB1|_nparams\\(fit::Gamma" src/families/grouped_dispersion.jl
rg -n "grouped|dispersion|cutpoint|ordinal|df|nparams|shared" test/test_grouped_dispersion*.jl test/test_ordinal*.jl
sed -n '1,160p' docs/design/03-likelihoods.md
sed -n '360,490p' docs/design/03-likelihoods.md
```

Commands using `src/bridge.jl`, `src/families/*.jl`, and `docs/src/*.md` were run
from `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`. Commands using
`R/`, `tests/`, and `docs/design/` were run from the `gllvmTMB` checkout.

## Results

- The current `gllvmTMB` branch is clean and contains the draft-landing and
  Xcoef addendum commits.
- Open PR census returned none.
- Recent commits are only the current Codex finish-programme commits and the
  existing `engine-julia` handover commits.
- `GLLVM.jl-integration` already has grouped-dispersion fitters and tests for
  NB2, NB1, Beta, and Gamma. The tests include exact-reduction checks from
  constant per-trait nuisance vectors to shared scalar likelihoods.
- `GLLVM.jl-integration/src/bridge.jl` still routes NB2, NB1, Beta, and Gamma
  no-X one-part bridge rows through shared scalar fitters, fills the returned
  `dispersion` vector from one scalar, and counts `+1` nuisance parameter in
  `df`.
- `GLLVM.jl-integration/src/families/ordinal.jl` still uses one shared ordered
  cutpoint vector. The bridge returns `cutpoints` as a vector and
  `n_categories` as one integer.
- Native `gllvmTMB` design docs and R wrapper snippets confirm the R/TMB oracle
  uses per-trait dispersion/cutpoint parameter blocks where these families carry
  nuisance parameters.

## Verification

```sh
git diff --check
rg -n "full bridge parity|CRAN-ready bridge|complete bridge|done|finished|release-ready|AI-REML|non-Gaussian REML|implemented|covered|per-trait dispersion parity|per-trait ordinal cutpoint parity" docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md docs/dev-log/after-task/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md docs/dev-log/shannon-audits/2026-06-16-julia-per-trait-dispersion-spec.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md
```

Expected scan hits are negative claim-boundary language, future implementation
requirements, or historical check-log entries.

## Deliberately Not Run

- No `devtools::document()`, because roxygen sources and generated Rd files were
  not touched.
- No `devtools::test()`, `devtools::check()`, `pkgdown::check_pkgdown()`, or
  `Pkg.test()`, because this was a docs-only design slice.
- No GitHub issue was updated or closed. Issue work waits for live issue reads
  and implementation evidence.

## Follow-Up

Start `codex/julia-per-trait-dispersion` only after Ada accepts this spec as the
implementation contract. The first code slice should route no-X complete NB2,
NB1, Beta, and Gamma bridge rows through grouped fitters with `group = 1:p`,
then add exact `df`, payload-label, and native parity tests before touching
ordinal cutpoints.
