# After Task: Paper 2 fixed named multi-kernel engine slice

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-18`
**Roles (engaged)**: `Ada / Boole / Emmy / Gauss / Noether / Fisher / Curie / Rose / Grace / Pat / Shannon`

## 1. Goal

Implement the first real Paper 2 Option B engine slice without widening the scientific claim: fixed named dense `kernel_latent()` tiers should fit as separate model components, extract by name, and preserve the guard `PR green != bridge complete != release ready != scientific coverage passed`.

## 2. Implemented

- Added a generic fixed dense multi-kernel TMB block for two or more named `kernel_latent()` tiers over the same grouping levels.
- Each active tier now has its own dense `K_r`, inverse/log determinant, `Lambda_r`, and latent field.
- The Paper 2 first wave is latent-only; explicit `kernel_unique()` / `*_unique()` Psi is deferred to post-arc compatibility/deprecation planning.
- Kept the one-name `kernel_*()` route on the existing phylo-equivalent path so KER-02 equivalence remains protected.
- Updated `extract_Sigma()` and `extract_Gamma()` to resolve named multi-kernel components by `level = name`.
- Added/updated validation rows:
  - `KER-03` covered for fixed named multi-kernel engine evidence.
  - `COE-03` partial for component-specific two-kernel extraction.
  - `COE-04` blocked for recovery/separation diagnostics.
- Updated Design 65, NEWS, roxygen/Rd, dashboard JSON, and the master ledger to remove the old live claim that two named kernels wait for a second engine slot.

## 3. Files Changed

Engine and API:

- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/kernel-keywords.R`
- `src/gllvmTMB.cpp`
- `man/kernel_latent.Rd`

Tests:

- `tests/testthat/test-coevolution-two-kernel.R`

Evidence and docs:

- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/audits/2026-06-18-master-finish-plan-psi-coevolution-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-paper2-fixed-multikernel-engine.md`

## 3a. Decisions and Rejected Alternatives

Decision: add a dense multi-kernel block only when two or more distinct `kernel_*()` names are present.
Rationale: preserves KER-02 byte-equivalence for the one-name path while unblocking Paper 2 fixed two-component syntax.
Rejected alternative: repoint all `kernel_*()` terms through the new block immediately. That would unnecessarily risk the proven phylo-equivalent path.
Confidence: high for the engine boundary; scientific confidence remains gated by COE-04.

Decision: use flat TMB parameter vectors with per-tier offsets.
Rationale: different ranks can coexist without unused random-effect columns.
Rejected alternative: rectangular `PARAMETER_ARRAY` random fields with partial maps. That is harder to audit and easier to make singular.
Confidence: high after non-heavy and heavy kernel/coevolution tests.

Decision: require first-wave multi-kernel tiers to use the same grouping factor and level set, and keep `kernel_dep()` single-tier.
Rationale: this is the smallest fixed Option B engine slice. Crossed/different kernel groups and multi-tier full unstructured covariance need their own design and recovery gates.
Rejected alternative: broad generic kernel unification in one pass.
Confidence: high.

Decision: keep Paper 2 fixed multi-kernel fits latent-only for now.
Rationale: explicit kernel-level Psi is a hindrance for non-Gaussian and cross-family coevolution interpretation; the `*_unique()` surface should become compatibility/deprecation work after this arc rather than being made central here.
Rejected alternative: include paired `kernel_unique()` in the first multi-kernel teaching/API path.
Confidence: high for the teaching/API boundary; the replacement Psi grammar still needs design.

## 4. Checks Run

- `/opt/homebrew/bin/gh pr list --state open`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were current mission-control/article-lane commits.
- `git diff --check`
  -> clean before shared-file edits and clean after final edits.
- `/usr/local/bin/Rscript --vanilla -e 'parse("R/fit-multi.R"); parse("R/extract-sigma.R")'`
  -> R files parsed.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 1 | PASS 26`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 38`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `man/kernel_latent.Rd`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 112`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 138`.
- `/usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> failed before checking because Pandoc was not on the shell PATH.
- `PATH="/opt/homebrew/Cellar/pandoc/3.9.0.2/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `PATH="/opt/homebrew/Cellar/pandoc/3.9.0.2/bin:$PATH" _R_CHECK_FORCE_SUGGESTS_=false /usr/local/bin/Rscript --vanilla -e 'res <- rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "never", check_dir = "check"); print(res)'`
  -> 0 errors, 1 warning, 0 notes. Warning was Apple clang/R header `-Wfixed-enum-extension`; generated `check/` scratch removed.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  -> valid JSON.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> valid JSON.

## 5. Tests of the Tests

The modified C3 test now exercises the feature combination directly: two named `kernel_latent()` tiers, separate `extract_Sigma()` results by level, separate `extract_Gamma()` blocks by level, and a fail-loud guard that rejects `kernel_unique()` inside the multi-kernel Paper 2 path. The old single-name KER-02 equivalence test still passes, protecting the path we intentionally left alone. Heavy coevolution tests passed with no skips, confirming the C0-C2 recovery/equivalence lanes still hold.

## 6. Consistency Audit

Stale scan:

`rg -n "two independent named tiers remain reserved|REJECTS two distinct|second engine slot|SECOND TMB data|STOPPED / reserved|pending a second engine slot|must use one .*name" R tests docs/design docs/dev-log/audits NEWS.md man`

Verdict: no live hits after updating the current test comment and master ledger. Historical after-task reports were deliberately excluded because they record past state.

## 7. Roadmap Tick

Design 65 C3.1 changed from reserved to done for the fixed named multi-kernel engine slice. The release/science roadmap did not move: `COE-03` remains partial and `COE-04` is blocked.

## 7a. GitHub Issue Ledger

No issue was mutated. Boundaries preserved:

- no push;
- no mutation of GLLVM.jl #101;
- PR #489 remains draft/partial;
- release issue #486 remains the release gate.

## 8. What Did Not Go Smoothly

Plain `Rscript` and `gh` were not on the default shell PATH; direct paths were used. `pkgdown::check_pkgdown()` failed until Homebrew Pandoc was put on PATH. The first fixed-directory `rcmdcheck` stopped because optional suggests `mirt` and `nadiv` are not installed and `_R_CHECK_FORCE_SUGGESTS_` was true; the preserved local check was rerun with `_R_CHECK_FORCE_SUGGESTS_=false`. The remaining warning is from Apple clang/R headers, not from this slice.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: The right success boundary is not "Paper 2 done"; it is "fixed named multi-kernel engine slice landed, recovery/inference still gated."

Boole: The public grammar can stay simple: `kernel_*()` is canonical, `relmat` remains compatibility sugar, and `unique()` is explicit Psi rather than deprecated.

Emmy: Flat parameter vectors with explicit offsets keep the fit object and extractor contract coherent across variable ranks.

Gauss: The new likelihood block mirrors the existing phylo MVN prior shape, with per-tier dense precision and no rho estimation claim.

Noether: Component interpretation is per tier: `Gamma_shape_r = Lambda_row,r %*% t(Lambda_col,r)`. There is still no universal total `Gamma`.

Fisher and Curie: Passing engine tests is not recovery calibration. COE-04 needs an ADEMP-style grid before Paper 2 scientific claims move.

Rose: Old "second engine slot" wording survived in comments and the master ledger after code passed. Stale scans need to include tests and ledgers, not only public prose.

Grace: Local check evidence is good but not clean release evidence: 0 errors with one compiler/header warning under local `rcmdcheck`, and no CI push was performed.

Pat: Reader-facing articles should not be promoted yet. The engine can fit the shape, but the article council still needs one-decision-at-a-time review.

Shannon: The pre-edit lane check found only the current draft PR. No push or cross-repo mutation occurred.

## 10. Known Limitations And Next Actions

- `COE-03` remains partial: component-specific extraction exists, but recovery/separation/inference gates are not passed.
- `COE-04` is blocked pending the two-component recovery grid, kernel-similarity diagnostics, null/selective-absence tests, and interval/rho plan.
- Explicit Psi replacement and `*_unique()` deprecation remain post-arc design work.
- Multi-tier `kernel_dep()`, crossed/different kernel groups, sparse generic kernel tiers, in-engine `rho`, and re-pointing `phylo_*` / `animal_*` / `spatial_*` onto the kernel core remain future work.
- No bridge, release, or scientific-coverage claim should move from this slice alone.
