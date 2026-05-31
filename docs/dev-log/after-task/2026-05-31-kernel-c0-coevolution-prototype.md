# 2026-05-31 -- C0 cross-lineage coevolution kernel helper + prototype

## Task Goal

Implement Design 65 C0 without engine code: add
`make_cross_kernel(A_H, A_P, W, rho)`, prove it builds a PSD block
kernel, and validate that a planted host-partner `Gamma` can be
recovered through the existing dense `phylo_latent(vcv = K_star) +
phylo_unique(vcv = K_star)` path on block-missing `traits(...)` data.

## Mathematical Contract

C0 builds a correlation-scale block kernel:

```text
K_star = [A_H   C_HP
          C_HP' A_P]

C_HP = rho L_H W_scaled L_P'
```

where `L_H L_H' = A_H`, `L_P L_P' = A_P`, and `W_scaled` has spectral
norm at most one. The heavy prototype then simulates
`G ~ N(0, K_star)` and trait signal `G Lambda'`; the target
coevolution surface is the host-partner block
`Gamma_true = Lambda_H Lambda_P'`.

This is not a formula-grammar, likelihood, family, parser, C++,
`extract_Gamma()`, or `relmat` deprecation change. `kernel_*()` remains
planned for C1.

## Files Created Or Changed

- `R/kernel-helpers.R`: new exported `make_cross_kernel()` helper and
  input guards.
- `man/make_cross_kernel.Rd`: generated help.
- `NAMESPACE`: export for `make_cross_kernel`.
- `NEWS.md`: user-facing C0 scope-boundary note.
- `_pkgdown.yml`: reference navigation entry.
- `tests/testthat/test-coevolution-prototype.R`: fast helper tests,
  rejection tests, and heavy recovery prototype.
- `dev/coevolution-prototype.R`: developer script with tree-based C0
  simulation and partner-weighted regression baseline.
- `docs/design/35-validation-debt-register.md`: C0 rows `KER-01`,
  `COE-01`, `KER-02`, and `COE-02`, reapplied after PR #363 merged.
- `docs/dev-log/check-log.md`: exact command log.
- `docs/dev-log/after-task/2026-05-31-kernel-c0-coevolution-prototype.md`:
  this report.

`docs/design/65-cross-lineage-coevolution-kernel.md` was restored to
the canonical main version from #360 after the worktree showed an older
local condensed draft. It has no remaining diff.

## Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` ->
  completed, loading `gllvmTMB`; re-run after the #363 fast-forward +
  NEWS addition also completed.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-prototype")'`
  -> `FAIL 0 | WARN 0 | SKIP 1 | PASS 9`; re-run after the #363
  fast-forward + NEWS addition gave the same result.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-prototype")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 16`; re-run after the #363
  fast-forward + NEWS addition gave the same result in `11.2s`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` ->
  `No problems found`; re-run after the #363 fast-forward + NEWS
  addition also returned `No problems found.`
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors`, `1 warning`, `4 notes`; not green. The warning was
  the package-install warning reported by R CMD check with quiet output.
  The notes were existing package-level notes: top-level `air.toml`,
  NEWS headings without version info, unused `nlme` import, and visible
  binding / `stats::residuals` diagnostics. Re-run after the #363
  fast-forward + NEWS addition gave the same `0 errors`, `1 warning`,
  `4 notes`; the new `Cross-lineage kernel prototype (#361, 2026-05-31)`
  heading was not listed among the NEWS heading parse notes.
- `tail -5 man/make_cross_kernel.Rd` -> examples close normally.
- `grep -c '^\\keyword' man/make_cross_kernel.Rd` -> `0`.
- Rose pre-publish audit for `NEWS.md`, `_pkgdown.yml`, roxygen, and
  generated Rd touched by this PR -> PASS. The exported helper appears
  in `NAMESPACE` and `_pkgdown.yml`, and the public prose cites the
  relevant validation-register rows.

## Consistency Audit

- `rg -n "make_cross_kernel|KER-01|COE-01|KER-02|COE-02" R/kernel-helpers.R man/make_cross_kernel.Rd docs/design/35-validation-debt-register.md _pkgdown.yml tests/testthat/test-coevolution-prototype.R dev/coevolution-prototype.R`
  -> C0 helper, generated help, tests, dev prototype, pkgdown nav, and
  validation rows use the same scope language.
- `rg -n "kernel_latent\\(|kernel_unique\\(|extract_Gamma\\(|relmat.*deprecat|deprecat.*relmat" README.md NEWS.md vignettes docs/design R man`
  -> matches are Design 65 planned-gate text and Design 35 blocked /
  partial rows only; no public README, NEWS, vignette, R, or man page
  advertises the engine as shipped.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/kernel-helpers.R man/make_cross_kernel.Rd dev/coevolution-prototype.R tests/testthat/test-coevolution-prototype.R docs/design/35-validation-debt-register.md _pkgdown.yml`
  -> no legacy S/U notation in touched files.
- `rg -n "gllvmTMB\\(" R/kernel-helpers.R man/make_cross_kernel.Rd dev/coevolution-prototype.R tests/testthat/test-coevolution-prototype.R docs/design/35-validation-debt-register.md _pkgdown.yml`
  -> only wide `traits(...)` C0 prototype/test calls plus unrelated
  existing register references; no long-format call missing `trait =`.

## Tests Of The Tests

The fast test covers the acceptance contract for `make_cross_kernel()`:
correct dimensions, dimnames, symmetry, exact within-lineage diagonal
blocks, unit diagonal, and PSD. Rejection tests cover invalid `rho` and
non-correlation-scaled relatedness input.

The heavy test combines the new helper with an existing neighboring
feature: dense `phylo_latent(vcv = K_star) + phylo_unique(vcv =
K_star)` on wide `traits(...)` data with structural missing cells. It
checks optimizer convergence, PD Hessian, dropped-cell accounting,
dimension/name integrity for the recovered block, and
`abs(cor(vec(Gamma_hat), vec(Gamma_true))) > 0.9`.

The AR(1) prototype fixture failed the recovery threshold
(`abs(cor) = 0.174864`) before the test was switched to the Design 65
tree-based DGP. The accepted tree fixture (`seed = 2`, `n_H = 36`,
`n_P = 72`, `n_rep = 5`) recovered with `abs(cor) = 0.946358` and
`pd_hessian = TRUE`.

## What Did Not Go Smoothly

The worktree had an older local rewrite of Design 65. Leaving it in
the branch would have overwritten the canonical #360 design contract,
so it was restored to `HEAD`.

Open PR #363 originally edited `docs/design/35-validation-debt-register.md`.
A coordination comment was posted. PR #363 then merged at `5261672`;
this branch was fast-forwarded to `origin/main` and the C0 register rows
were reapplied cleanly.

Open PR #367 edits `R/brms-sugar.R`, `R/fit-multi.R`, and
`R/extract-sigma.R`, which are the natural surfaces for C1
`kernel_*()` parser and extractor equivalence work. A coordination
comment was posted there too; engine edits should wait until #367
lands or this branch can rebase cleanly.

The full `devtools::check()` run is not green because of an install
warning and four notes. The targeted C0 suite and pkgdown check are
green, but Grace should not treat this as a full package green light.

## Team Learning

Ada kept C0 bounded: helper, prototype, validation rows, and no engine
code. The restored Design 65 file prevented a subtle contract
regression.

Boole confirmed the formula surface did not change. The roxygen text
and register rows say `kernel_*()` is planned, not implemented.

Curie focused the simulation on a deterministic tree-based DGP, not a
friendly synthetic correlation matrix. The heavy test now carries the
known-`Gamma` recovery evidence C0 needs.

Fisher treats the C0 recovery as necessary but not sufficient. C2 still
owns null-vs-cross logLik separation, loading-constraint verification,
and the single-`W` sensitivity simulation.

Rose caught the public-surface risk: exported helper prose must carry
row IDs and scope boundaries. The register collision with #363 remains
the only consistency warning.

Grace's result is mixed: `pkgdown::check_pkgdown()` is clean, but
`devtools::check()` is not green.

Shannon's coordination state is warn, not pass. Same-file Design 35
editing from PR #363 has cleared, so C0 can proceed. C1 code work
should still pause until PR #367 clears the parser/extractor files.

## Design Docs

Design 65 remains canonical from #360, with no local diff.

Design 35 has local C0 rows:

- `KER-01`: `make_cross_kernel()` helper, covered by fast tests.
- `COE-01`: prototype recovery, partial until C2.
- `KER-02`: generic `kernel_*()` engine, blocked until C1.
- `COE-02`: validated coevolution engine and `extract_Gamma()`, blocked
  until C2.

Those rows should be committed only after the PR #363 collision is
cleared.

## pkgdown And Documentation

`make_cross_kernel()` has roxygen documentation, a runnable small
matrix example, generated Rd, NAMESPACE export, and a `_pkgdown.yml`
reference entry. No article was created because coevolution should not
be advertised before C2.

## Roadmap Tick

N/A. Issue #361's C0 checklist is advanced by this local branch, but
no roadmap source row was edited.

## GitHub Issue Ledger

- #361 inspected earlier as the roadmap umbrella for C0-C5.
- #363 inspected and commented because it overlaps the Design 35
  register rows required by this C0 branch, then merged before commit:
  `https://github.com/itchyshin/gllvmTMB/pull/363#issuecomment-4587393394`.
- #367 inspected and commented because it overlaps the C1 parser /
  extractor surfaces:
  `https://github.com/itchyshin/gllvmTMB/pull/367#issuecomment-4587437653`.
- #362, #364, and #366 were inspected during lane check and judged not
  file-overlapping with this C0 slice except for the broader active-PR
  coordination context.
- No new issue was created.

## Known Limitations And Next Actions

Next safest action is to commit and open the C0 PR. After C0 is merged
and #367 no longer owns the relevant parser/extractor surfaces, start
C1 on a fresh rebase from `main` and do not proceed past C1 until
`kernel_latent(K = A) + kernel_unique(K = A)` is equivalent to the
phylo path to less than `1e-6`.

C2 remains mandatory before public coevolution advertising: known
`Gamma` recovery through the generic engine, null-vs-cross logLik
separation, loading constraints for identifiable `Gamma`, and
single-`W` sensitivity.
