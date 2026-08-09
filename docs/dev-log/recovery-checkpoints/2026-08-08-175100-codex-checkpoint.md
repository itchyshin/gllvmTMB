# Codex recovery checkpoint — CRAN 0.7 validation

Date: 2026-08-08 17:51 MDT  
Branch: `cursor/cran-0.7-20260807`  
Working tree: intentionally dirty; no commit, push, version bump, candidate
freeze, or upload.

## Current state

- G1 source-truth repairs, reader-facing limits page, provenance rewrite, and
  historical seven-failure repairs are present in the shared lane.
- V3 production completed 12,400/12,400 attempts on Totoro. Immutable
  adjudication remains broad HOLD; only the Poisson family pair passes.
- The S11 numerical diagnosis separates the binomial stopping artifact from
  genuine Gaussian/NB2 weak-identification cases. No optimizer implementation
  change has been made.
- The v4 confirmation design is on disk as DRAFT with zero fits. It requires
  explicit maintainer authorization before the default warm-`nlminb` repair is
  implemented or compute is launched.
- Maintainer GPL-3/authorship/logo-rights confirmation remains required before
  release freeze.

## Commands and exact outcomes in this continuation

- Third provisional source build from the live lane: PASS; vignettes built.
- Provisional tarball:
  `/tmp/gllvmtmb-cran-preflight3.PfO019/gllvmTMB_0.6.0.tar.gz`.
- SHA-256: `e096f07e05cf79a8151da728dfec2afa75c9ebcc756a08d39e071666144f85f3`.
- Size/entries: 3,780,031 bytes; 696 entries.
- Inventory scan: no `inst/sim`, dev-log, ROADMAP/AGENTS/CLAUDE, CSL/BibTeX,
  m3 campaign files, generated root-vignette PNGs, or compiled objects.
- `git diff --check`: PASS.
- Focused source-tarball guards were repaired before this build:
  `test-release-core-sentinels.R` now uses a shipped pure helper and
  `test-loading-unpack-contract.R` skips its repository-only source scan when
  source files are absent. Their focused tests passed before the build.
- `R CMD check --as-cran` with network completed from unified exec session
  `82012`: 0 errors, 0 warnings, 1 NOTE. Installation, code checks, Rd,
  examples, donttest examples, installed tests, vignettes, vignette rebuild,
  PDF manual, and HTML manual passed. The NOTE combines the expected new
  submission status and the 404 for the not-yet-deployed current-limits page.

## Changed-file scope

`git diff --stat` currently reports 48 tracked files changed, 1,224 insertions,
and 1,015 deletions, plus the untracked release/simulation/test/article assets
listed by `git status --short`. These are the accumulated approved Ultra Plan
slices; preserve all concurrent work and never stage with `git add -A`.

## Next safest actions

1. Obtain explicit maintainer authorization for the narrow default optimizer
   repair and for GPL-3/authorship/logo redistribution (or exclude the logo).
2. Only after optimizer authorization: implement the repair, run the frozen
   pre-compute tests, hash-freeze v4, local smoke, Totoro pilot, and admitted
   production subset. DRAC is available as overflow; never use GitHub Actions.
3. Do not bump to 0.7.0 or freeze an exact candidate before G3 adjudication.
