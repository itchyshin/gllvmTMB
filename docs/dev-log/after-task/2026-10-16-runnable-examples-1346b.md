# After Task: Runnable help examples, part B (keyword and family pages)

**Branch**: `claude/b16-L7-runnable-examples` (red proof: `claude/b16-L7-red-proof`)
**Date**: `2026-10-16`
**Roles (engaged)**: `Pat / Curie / Grace / Rose / Boole`

## 1. Goal

Issue #1346, part B of 4. Thirteen help pages built from seven lane-owned files had
examples that `example()` and `R CMD check` never executed: every one sat inside
`\dontrun{}`. The pages were `animal_scalar`, `animal_unique`, `animal_indep`,
`animal_latent`, `animal_dep`, `animal_slope`, `pedigree_to_Ainv_sparse`,
`diag_re`, `traits`, `spde`, `kernel_latent`, `isdm_sources` and `families`.
The task was to replace each block with a small, self-contained example that runs
in seconds on simulated data, and to add a test that keeps it that way.

## 2. Implemented

- All 13 pages now run their examples. None keeps a `\dontrun{}` block; none needs
  Julia or an external resource.
- Three examples could not have run when they were unwrapped, so they are rebuilt:
  - `?diag_re` and `isdm_sources()` used `df` / `dat` without defining them.
  - The integrated two-source example on `?families` also used an undefined
    `dat`.
  - The mixed-family example on `?families` gave a binomial trait continuous
    values and errors with "`y` (successes) must satisfy 0 <= y <= n_trials".
- The animal-model pages now simulate data correctly:
  - The old draw was trait-major (`kronecker(diag(2), A)`) but was assigned to an
    individual-major data frame, so the simulated genetic structure was scrambled.
  - The new draw is `bv <- t(chol(A)) %*% Z %*% chol(G)`, i.e.
    `vec(bv) ~ N(0, G %x% A)`, stacked with `as.vector(t(bv))`.
  - Each page now simulates the G its own model assumes. Base R replaces the
    suggested-only `MASS`.
  - Every call states `cluster = "individual"`, the slot that carries the
    relatedness matrix, and `trait = "trait"`.
- The deprecated pages (`animal_scalar`, `animal_unique`) also fit the recommended
  `animal_indep()` spelling and print the two log-likelihoods, which are equal.
- After review, five examples were redesigned so the fitted model is identified
  and the fit is healthy (section 3a): `diag_re`, `kernel_latent`, both iSDM
  examples, and `spde`.
- The two `?families` examples that were already in `\donttest{}` (censored
  Poisson and zero-inflated Poisson) run in about 0.25 s each, so they now run
  unwrapped. They no longer assert the optimiser's convergence code or cite an
  internal review label.
- New forcing test `tests/testthat/test-examples-run-1346b.R`:
  - It asserts that the 13 pages keep no `\dontrun{}`.
  - It runs each page's `tools::Rd2ex()` code, with `\donttest` kept, and
    requires at least one executable expression, no error and no warning.
  - Visible values are auto-printed from the example environment, as
    `R CMD check` does.

## 3. Files Changed

- Roxygen `@examples` lines only: `R/animal-keyword.R`, `R/unique-keyword.R`,
  `R/traits-keyword.R`, `R/spde-keyword.R`, `R/kernel-keywords.R`,
  `R/isdm-sources.R`, `R/families.R`. No code line and no other roxygen tag
  changed.
- Regenerated Rd: `man/animal_dep.Rd`, `man/animal_indep.Rd`, `man/animal_latent.Rd`,
  `man/animal_scalar.Rd`, `man/animal_slope.Rd`, `man/animal_unique.Rd`,
  `man/pedigree_to_Ainv_sparse.Rd`, `man/diag_re.Rd`, `man/traits.Rd`, `man/spde.Rd`,
  `man/kernel_latent.Rd`, `man/isdm_sources.Rd`, `man/families.Rd`.
- New: `tests/testthat/test-examples-run-1346b.R`, this report.
- Not changed: `NAMESPACE` (no exported surface changed), `NEWS.md` (its lines are
  in the PR body, per the lane instructions), `DESCRIPTION`.

## 3a. Decisions and Rejected Alternatives

- **Identified models only.** An adversarial review found three examples whose
  printed split was not estimable.
  - `diag_re` had 4 traits with `d = 2` plus Psi: 11 free parameters for 10
    covariances, and two Psi collapsed to about 0. The fix is 5 traits with 60
    individuals (14 parameters for 15 covariances). With 40 individuals Psi
    still collapsed, so 40 was rejected.
  - The two iSDM examples fitted a 2-species `latent(d = 1, unique = TRUE)`
    (4 parameters for 3 covariances) to data with no cell effect. They now
    simulate a shared cell effect and fit it loadings-only.
  - Confidence: high; each choice is checked with `check_gllvmTMB()`.
- **`spde` seed.** `seed = 1` gave a non-PD Hessian and a collapsed spatial
  variance.
  - I took the first seed at the page's own 60 sites with no failing check
    (`seed = 2`). I rejected seed 6, whose practical range of 0.300 would have
    "matched" the simulator's `spatial_range`.
  - That match would be spurious: the two are different quantities (exponential
    scale versus Matern practical range), as the example now says.
- **Explicit `unique = TRUE` on ordinary `latent()`.** It is the default, so the
  model is unchanged. It makes the Lambda Lambda^T + Psi decomposition visible on
  the page and keeps a fresh-session `example()` free of the one-time "now
  includes Psi" warning. Rejected: leaving `latent()` bare, which warns on first
  use in every session.
- **`traits()` needs tidyr, which is only suggested.**
  - `?traits` guards its example with `requireNamespace("tidyr")`.
  - `kernel_latent()` moved to the long form, since the page is about kernels,
    not wide input.
  - Rejected: leaving them unguarded, which fails a no-Suggests check.
- **`\donttest{}` on `?families`.** Removed, because both blocks run in about
  0.25 s and the lane rule keeps `\donttest` for examples over 5 s. `R CMD check
  --as-cran` already ran them, so CRAN exposure does not change.
- **Rd regenerated with roxygen2 8.0.0** (`Config/roxygen2/version`).
  - On base this reproduces `man/` byte for byte.
  - On local R 4.3.3 it rewrites `NAMESPACE`'s `S3method(stats::sigma, …)`
    lines; that toolchain drift was reverted, not committed.

## 4. Checks Run

Environment: Claude cloud session, Ubuntu 24.04, R 4.3.3, TMB 1.9.10 and Matrix
1.6-5 (Ubuntu archive). CRAN hosts are blocked by the session's network policy,
so `fmesher`, `splancs`, `pkgload` 1.5.3 and roxygen2 8.0.0 were built from the
`github.com/cran` and `r-lib` git mirrors.

- Forcing test on base (`NOT_CRAN=true`):
  - The first version gave **2 failures**: 13/13 pages contain `\dontrun`, and
    11/13 execute 0 expressions.
  - The final version is also red on base; that red-proof run is PR #1552.
- Forcing test on the branch: **6 expectations pass** in about 8 s.
- `R CMD check --as-cran --run-donttest --no-manual --ignore-vignettes` on the
  built tarball, with `R_CRAN_WEB` pointing at an empty local package database so
  that the orphaned-dependency query works offline.
  - `checking examples ... OK`; `checking Rd line widths ... OK`.
  - The two WARNINGs and five NOTEs are all independent of this change:
    `tools::sha256sum` (absent in R 4.3.3), the existing `TMB:::` use, the
    duplicated `\argument` on the julia-methods page (another lane's file), the
    BH LinkingTo note, installed size, timestamps and compilation flags.
- Per-page example timings (`gllvmTMB-Ex.timings`, elapsed seconds): see
  PR #1553. The slowest page, `diag_re`, takes 1.56 s.
- `devtools::test()`: the full suite, run in four shards. My file passes.
  - Twenty-one other files fail or error.
  - Re-run on base with the same harness and the same compiled `src/`, the same
    21 files give **identical** failure and error counts. They fail on this
    environment, not on this change: R 4.3.3, Ubuntu glmmTMB 1.1.8, an older
    vdiffr, no `tools::sha256sum`, and pre-existing docs checks.
- `bash tools/check-reader-surface.sh` PASS; `bash tools/check-actions-boundary.sh`
  PASS; `bash tools/check-push-traps.sh` PASS.

## 5. Tests of the Tests

- **Failure before the fix:** the test is red on base (13 `\dontrun` pages, 11
  pages executing nothing). Red proof: PR #1552.
- **Injected faults**, in a scratch copy of `man/`. Each one is caught by the final
  test:
  - an error;
  - a warning;
  - a failing S3 print method defined inside the example;
  - an object that exists only in the developer's workspace.
- **Fixed in the test along the way:** the print-method fault was missed at
  first, because `print()` was dispatched from the test frame. It is now
  dispatched from the example environment.
- **`R CMD check` layout:** run from `<pkg>.Rcheck/tests`, with no `man/`
  alongside, the test falls back to the installed Rd database.
  - An `R CMD check --as-cran --run-donttest` with `GLLVMTMB_TEST_SHARD=3/4`
    (the shard that holds the file) ran the static test there, and it passed.
  - The execution test skipped in that run, because plain `R CMD check` leaves
    `NOT_CRAN` unset; CI's rcmdcheck sets it. So the file was also run with
    `NOT_CRAN=true` against that check's installed library, from a directory
    with no `man/`: 6/6 expectations pass.

## 6. Consistency Audit

- The lane's `gllvmTMB(` call sites were enumerated per the after-task protocol
  (`rg -n "gllvmTMB\\(" R` on the 7 lane files, classified by a script as long
  or wide).
  - Verdict: every long-format call in the 13 pages now passes `trait =`.
  - Wide `traits(...)` calls do not.
- `rg -n "\bS_B\b|\bS_W\b"` on the 7 lane files. Verdict: no legacy S/U notation.
- `git diff aec24e1 -- R | grep "^+" | rg "\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|meta_known_V|gllvmTMB_wide"`.
  Verdict: no deprecated alias added.
- `git diff aec24e1 -- R man | grep "^+" | rg "[A-Z]{2,5}-[0-9]{2}|Design [0-9]+|D-[0-9]{2,3}|test-[a-z-]+\.R|Grounded in"`.
  - Verdict: no register code or test-file reference added.
  - The old "Grounded in test-animal-keyword.R" lines and the "2026-09-02
    review R5" comment were removed.
- `git diff -U0 aec24e1 -- R/ | grep -E '^[+-]' | grep -vE "^[+-]#'"`. Verdict:
  empty; only roxygen lines changed.

## 7. Roadmap Tick

N/A. No ROADMAP row tracks help-page examples.

## 7a. GitHub Issue Ledger

- #1346: inspected; worked as part B of 4. Referenced as `refs #1346` only.
- Red proof: PR #1552. Fix: PR #1553.
- No new issue was created. Two out-of-scope observations are recorded for the
  maintainer in PR #1553 (section 10).

## 8. What Did Not Go Smoothly

- CRAN and Posit package hosts were blocked, so the toolchain had to be built
  from git mirrors.
- `R CMD check --as-cran` hard-sets the orphaned-dependency check. It needed a
  local stand-in for CRAN's package database.
- The first conversions ran but taught degenerate fits. Only an adversarial
  review caught them: "it runs" is not "it is a good example".
- The forcing test's first print emulation missed example-defined S3 methods.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Pat:** an example must be checked as a model, not only as code. Count
  parameters against covariance entries and run `check_gllvmTMB()` before
  shipping a printed decomposition.
- **Curie:** fault injection is what showed the forcing test's blind spot.
- **Grace:** guard Suggests in examples; `traits()` silently pulls in tidyr.
- **Rose:** two comments over-claimed: "canonical" against a page whose own prose
  says otherwise, and a range comparison between different quantities. Both were
  reworded.
- **Boole:** keywords that carry a relatedness matrix use the `cluster` slot, not
  the id column inside the keyword.

## 10. Known Limitations And Next Actions

- **Observed, not fixed (outside this lane):**
  - With an id column not named `species` and no `cluster =`, `animal_*()` fails
    with "`phylo_vcv` rownames do not cover all species levels … placeholder …
    supply a tree/vcv that covers these species". The working fix,
    `cluster = "<id column>"`, is not named.
  - `extract_Sigma(level = "phy")` refuses `animal_scalar()` /
    `animal_indep(common = TRUE)` fits with "Fit has no `phylo_latent()` term".
  - `?animal_scalar` prose still calls the soft-deprecated keyword the
    "Canonical name" and carries no deprecated badge.
- **Left for other lanes:**
  - `kernel_slope`, `phylo_unique`, `spatial_unique` and the other
    `R/brms-sugar.R` pages: part A, PR #1551.
  - `R/output-methods.R`, `R/extract-omega.R`, `R/bootstrap-sigma.R` and
    `R/julia-bridge.R`: a later wave.
- **Local test runs used R 4.3.3.** CI on R release is the authority for the
  suite and for the examples' printed output.
