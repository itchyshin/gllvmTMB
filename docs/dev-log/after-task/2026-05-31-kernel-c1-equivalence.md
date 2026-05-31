# After Task: C1 Dense `kernel_*()` Equivalence

**Branch**: `codex/kernel-c1-equivalence`
**Date**: `2026-05-31`
**Status**: Local PR-ready / pre-merge. C1 implementation and local
evidence are present after rebasing through `origin/main` at #398.
The full objective is not complete: C2, the coevolution article, CI,
review, merge, and final article publication remain later work.
**Roles (engaged)**: Ada, Boole, Curie, Fisher, Rose, Pat, Grace,
Shannon

## 1. Goal

Implement Design 65 C1 for a single named dense kernel tier: expose
`kernel_latent()`, `kernel_unique()`, `kernel_indep()`, and
`kernel_dep()` as user-facing formula markers that reproduce the dense
`phylo_*()` `vcv = A` path to less than `1e-6`, then stop before C2
coevolution claims.

## 2. Implemented

- New exported marker functions in `R/kernel-keywords.R`.
- Parser rewrite in `R/brms-sugar.R` maps `kernel_*()` to the existing
  dense phylo-equivalent relatedness path with `.kernel_*` metadata.
- `R/fit-multi.R` stores one named kernel level and refuses mixed
  `kernel_*()` / `phylo_*()` terms in the same dense tier.
- `extract_Sigma(fit, level = "<kernel name>")` aliases to the
  internal phylo-equivalent tier while returning the public kernel
  level name.
- Wide `traits(...)` parsing preserves the `kernel_*()` keyword family.
- C1 tests cover paired `kernel_latent + kernel_unique`, bare
  `kernel_latent`, and companion `kernel_unique`, `kernel_indep`, and
  `kernel_dep` equivalence to dense `phylo_*()` paths.
- `docs/design/35-validation-debt-register.md` now marks `KER-02`
  covered by `test-kernel-equivalence.R`; `COE-02` remains blocked for
  C2.
- Non-public article planning note records that the coevolution article
  waits for C2 recovery evidence and needs paired long/wide examples.

## 3. Files Changed

Implementation:

- `R/kernel-keywords.R`
- `R/brms-sugar.R`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/traits-keyword.R`

Tests:

- `tests/testthat/test-kernel-equivalence.R`

Documentation and generated files:

- `man/kernel_latent.Rd`
- `NAMESPACE`
- `_pkgdown.yml`
- `NEWS.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/spikes/2026-05-31-coevolution-article-plan.md`

Process artifacts:

- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-31-114332-codex-c1-kernel-equivalence.md`
- `docs/dev-log/after-task/2026-05-31-kernel-c1-equivalence.md`

## 3a. Decisions and Rejected Alternatives

Decision: C1 deliberately reuses the existing dense
`phylo_* (vcv = A)` relatedness path instead of adding a new C++ block.

Rationale: the C1 gate is equivalence to `phylo_*()` with `vcv = A`.
Routing through the existing path makes that equivalence structural and
keeps the first engine slice small.

Rejected alternative: add a parallel kernel-specific TMB random-effect
block immediately. That would make equivalence harder to audit and
increase merge risk before the generic surface has earned trust.

Confidence: high for C1 dense-kernel equivalence; no claim is made for
C2 coevolution recovery.

## 4. Checks Run

- `git fetch --all --prune` plus PR/branch/issue sweep showed Design 65
  and C0 have merged, the old Design 65/C0 remote branches are deleted,
  and no newer C1/C2 kernel PR exists.
- `git grep -n -E "kernel_latent|kernel_unique|kernel_indep|kernel_dep|extract_Gamma|make_cross_kernel" origin/main -- R tests docs/design man NAMESPACE _pkgdown.yml NEWS.md`
  -> `origin/main` has C0 (`make_cross_kernel`) and Design 65 only;
  `KER-02` / `COE-02` remained blocked before this branch.
- Coordination comment posted on #396 because it temporarily touched
  `docs/design/35-validation-debt-register.md`:
  `https://github.com/itchyshin/gllvmTMB/pull/396#issuecomment-4588032528`.
  #396 has since merged and this branch was rebased through it.
- Rebased through current `origin/main` at #398. The #396 Design 35
  FG/FAM updates and the #398 missing-data bugfix are present.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> completed; regenerated `NAMESPACE` and `man/kernel_latent.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel-equivalence")'`
  -> latest run `FAIL 0 | WARN 0 | SKIP 0 | PASS 38`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check` -> clean.
- `tail -5 man/kernel_latent.Rd && grep -c '^\\keyword' man/kernel_latent.Rd`
  -> Rd terminates cleanly; `0` keyword tags.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors`, `3 warnings`, `4 notes`, exit code 1. Warnings are
  outside C1: `impute_model.Rd` links to `mi` without an anchor and
  `gllvmTMB.Rd` has undocumented `impute`; plus install-stage warning.
  Notes are existing package-level `air.toml`, NEWS headings, unused
  `nlme`, and predictive-diagnostic visible bindings /
  `stats::residuals`. This was not patched in the kernel lane.

## 5. Tests of the Tests

The test file intentionally checks both the maintainer's exact C1 gate
and the broader named kernel family:

- paired decomposition: `kernel_latent(K = A) + kernel_unique(K = A)`
  vs `phylo_latent(vcv = A) + phylo_unique(vcv = A)`;
- bare latent: `kernel_latent(K = A)` vs `phylo_latent(vcv = A)`;
- companion modes: `kernel_unique()`, `kernel_indep()`, and
  `kernel_dep()` vs their dense `phylo_*()` equivalents;
- extractor naming: `extract_Sigma(level = "known")` returns the named
  kernel level while using the internal phylo-equivalent tier;
- parser metadata: `kernel_indep()` and `kernel_dep()` carry the
  expected mode and `vcv` metadata through the formula rewrite;
- negative syntax coverage: missing named `K`, empty `name`, mixed
  kernel/phylo terms, and mismatched kernel names fail loud.

The tests are equivalence tests rather than recovery tests. C2 owns
known-`Gamma` recovery, null-vs-cross likelihood separation, loading
constraints, and single-`W` sensitivity.

## 6. Consistency Audit

- `rg -n "kernel_latent|kernel_unique|kernel_indep|kernel_dep|make_cross_kernel|extract_Gamma|KER-02|COE-02|IN:|PARTIAL:|PLANNED:" R/kernel-keywords.R man/kernel_latent.Rd NEWS.md docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/dev-log/spikes/2026-05-31-coevolution-article-plan.md _pkgdown.yml`
  -> expected C1 keyword and scope-boundary hits; public prose says
  `extract_Gamma()` and coevolution recovery remain C2.
- `rg -n "gllvmTMB_wide|relmat.*deprecat|deprecat.*relmat|meta_known_V|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" R/kernel-keywords.R man/kernel_latent.Rd NEWS.md docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/dev-log/spikes/2026-05-31-coevolution-article-plan.md`
  -> expected legacy/migration references only; C1 does not ship relmat
  deprecation.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S|diag\\(S\\)|diag\\(U\\)|diag\\(s\\)" R/kernel-keywords.R man/kernel_latent.Rd NEWS.md docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md docs/dev-log/spikes/2026-05-31-coevolution-article-plan.md tests/testthat/test-kernel-equivalence.R`
  -> no matches.
- `rg -n "gllvmTMB\\(" R/kernel-keywords.R man/kernel_latent.Rd tests/testthat/test-kernel-equivalence.R NEWS.md docs/design/01-formula-grammar.md docs/dev-log/spikes/2026-05-31-coevolution-article-plan.md`
  -> C1 examples are wide `traits(...)` examples or existing grammar
  text; no new long-format public example omits `trait =`.
- `rg -n "^#' @export|kernel_latent|kernel_unique|kernel_indep|kernel_dep|make_cross_kernel" R/kernel-keywords.R R/kernel-helpers.R _pkgdown.yml NAMESPACE`
  -> `kernel_latent` topic covers all four C1 aliases in `_pkgdown.yml`
  and all four are exported in `NAMESPACE`; existing
  `make_cross_kernel` remains exported and indexed.
- `rg -n "^\\| (KER-02|COE-02)" docs/design/35-validation-debt-register.md`
  -> `KER-02` covered with C1 evidence; `COE-02` blocked for C2.

Rose pre-publish status for the C1 public surfaces: PASS. Grace status:
WARN because full local `devtools::check()` still has unrelated
missing-data Rd warnings.

## 7. Roadmap Tick

Issue #361's C1 checklist should advance when the C1 PR is opened and
merged. No `ROADMAP.md` row has been edited on this branch.

## 7a. GitHub Issue Ledger

- #361 inspected as the umbrella roadmap issue for C0-C5. C1 is the
  active slice, and the issue serializes engine PRs.
- #360 (Design 65) and #368 (C0) are merged on `origin/main`.
- #371 and #372, the earlier overlapping parser/engine/register PRs,
  are merged. C1 was rebased after them.
- #396 temporarily overlapped Design 35. A coordination comment was
  posted, #396 merged, and C1 was rebased through it.
- #395 touches `_pkgdown.yml` article navigation, not the reference
  topic line where C1 adds `kernel_latent`.
- #397 is article-only.
- #390 is missing-data design docs and does not touch Design 35.

No new issue was created. The C2 article follow-up is recorded as a
non-public dev-log spike until C1 lands.

## 8. What Did Not Go Smoothly

The branch repeatedly became locally ready before the merge lane
cleared. The right move was to keep rebasing as team PRs landed rather
than opening a conflicting engine/register PR.

`air format` was available but too broad for the current legacy file
style: it reformatted large parts of `R/fit-multi.R` and
`R/extract-sigma.R`. Those changes were reverted, and only the C1 edits
were reapplied.

A public-doc phrase briefly over-claimed sparse precision support for
`K`; it was corrected to the dense PSD C1 contract before regenerating
`man/kernel_latent.Rd`.

## 9. Team Learning

Ada kept C1 scoped to equivalence and resisted starting C2 while the
engine lane was still moving.

Boole checked that `kernel_*()` is outside the source-specific 4 x 5
grid but still uses the same quartet language: `latent`, `unique`,
`indep`, and `dep`.

Curie pushed the evidence from parser-only metadata to fit equivalence
for the companion modes, making `KER-02` supportable as `covered`.

Fisher kept the coevolution claim out of public prose. C1 can say dense
kernel equivalence; C2 must prove `Gamma` recovery and null-vs-cross
separation.

Pat's article-path concern is captured in the spike: the eventual
public article needs paired long-format and wide `traits(...)` examples.

Rose checked scope wording in NEWS, Design 01, Design 35, and the
article plan so that `extract_Gamma()` and coevolution recovery remain
planned, not advertised.

Grace's package-surface evidence is mixed: focused tests, roxygen, and
pkgdown pass; full local check still has unrelated missing-data Rd
warnings.

Shannon now passes for the C1 lane: no open kernel C1/C2 PR exists, and
the remaining open PR overlaps are article/navigation/design-doc lanes,
not the C1 engine surface.

## 10. Known Limitations And Next Actions

Next safest action: commit, push, open the C1 PR, watch CI, and merge
only if CI and review are clean.

C2 remains mandatory before any public coevolution article:
`extract_Gamma()`, known-`Gamma` recovery, null-vs-cross log-likelihood
separation, loading-constraint verification, and single-`W` sensitivity.
