# Check-log: first-wave twin documentation remediation

**Goal:** Correct the approved public documentation findings D001, D008, D039 in gllvmTMB and D011, D012, D036 in GLLVM.jl. D010 remains pending its bridge/inference owner.

**Commands and results:**

- All five affected R articles rendered after the final edits: all exited 0. The integrated multi-source HTML showed `optimizer_convergence` PASS and `pd_hessian` WARN with the revised curvature explanation. Morphometrics, covariance/correlation, random-regression, and pitfalls pages showed the visible executable data/setup chunks.
- `pkgdown::check_pkgdown()`: passed, no problems found.
- The first full article build loaded a stale installed `gllvmTMB` whose `extract_correlations()` rejected `entries = "all"`; the source checkout's function signature includes `entries`. After installing the exact checkout in `/private/tmp/gllvm-doc-remediation-lib`, a second full article build passed the covariance page and proceeded through the integrated multi-source page. The 42-article run was stopped after exceeding its 15-minute estimate, so the full set did not finish.
- Using the same exact temporary package library, `pkgdown::build_article()` succeeded for `articles/morphometrics`, `articles/random-regression-reaction-norms`, and `articles/pitfalls`. Together with the two affected pages generated during the partial full build, all five affected HTML files were generated under ignored `pkgdown-site/articles/`.
- Julia Documenter/VitePress build with deployment disabled: exited 0. Doctests, cross references, and page rendering passed; VitePress completed. Warnings were large bundle size and default `package.json` template substitution.
- Exact documented Julia Poisson CV examples ran with explicit `using Distributions: Poisson`; random-cell and site-block routes both returned finite results.
- `git diff --check` passed in both worktrees. Style checks on all changed prose returned zero findings; the pitfalls checklist has an explicit style waiver. MathJax deprecation warnings were non-fatal; the first stale-library run also reported a denied write to the shared sass cache.

**Scope:** Documentation and examples only. No engine changes, deployment, parity claim, or interval calibration claim.
