# A3 fixes — R5, S3, S4 (from fresh-Opus review `verify-opus.md`)

Worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902`
Branch: `claude/gapclose-20260902`. No commit made. No `devtools::document()`,
`load_all()`, `test()`, or render run.

## Scope

Per the coordinator's message: `README.md` (fully, including the WARNING block
that A3 had missed), `R/zzz.R`, `DESCRIPTION`, and the package-level roxygen
(which lives in `R/zzz.R`'s `"_PACKAGE"` block — there is no separate
`R/gllvmTMB-package.R` in this repo; confirmed by `grep -rl "@docType
package|_PACKAGE" R/*.R` → only `R/zzz.R`). Also hand-synced
`man/gllvmTMB-package.Rd` (its `\description{}` is generated verbatim from
`DESCRIPTION`'s `Description:` field, so once `document()` runs later it will
regenerate to the same corrected text; I hand-edited it now so it reads
correctly in the meantime — it is not one of the files A1 is described as
regenerating a claim from, so this is a courtesy sync, not a substitute for the
real `document()` run).

**Not touched, and left as-is on purpose:** `man/profile_ci_total_variance.Rd`
(R8's `PVT-02` register-code leak and its own `route-only` occurrence) — its
source is `R/profile-derived.R`, which the coordinator's message explicitly
excluded ("do not touch other R/ files"). The required proof grep also does not
check `man/`, confirming this file is out of scope for this pass.
`vignettes/articles/current-limits.Rmd` stays excluded per the grep command and
per my earlier A3 scope decision (it is the page that formally defines this
vocabulary).

## R5 — the five terms on the surfaces a user meets first

Fixed in `R/zzz.R` (`.onAttach` startup banner, printed on every
`library(gllvmTMB)`), `DESCRIPTION` (CRAN `Description:` field), and
`README.md` (WARNING admonition, three lines up from where A3 stopped). Also
hand-synced `man/gllvmTMB-package.Rd` line 10, which is generated from
`DESCRIPTION`.

**One canonical plain phrasing used everywhere** (closing R5's reviewer-noted
inconsistency between README's "still only an approximate calculation" and
DESCRIPTION/banner's "remain route-only" — I standardised on the README
wording, since that was already reviewed as clear):

> "Total-variance penalty profiles are still only an approximate calculation:
> even in previously checked cases, we have not confirmed they match the exact
> answer."

And for the unparseable sentence ("Three exact native, pinned, unrotated
ordinary-Gaussian standardized-loading Wald cells have target-specific
certificates only in one frozen DGP, conditional on eligible fits; other
parameter regimes and neighbouring cells do not inherit them." / the
DESCRIPTION and banner's shorter version of the same claim), the same plain
paragraph now reads, verbatim, in `README.md`, `DESCRIPTION`, `R/zzz.R`, and
`man/gllvmTMB-package.Rd`:

> "Point estimates are the primary output, and how well they are supported
> depends on the exact model and route used. Broad package-wide interval
> coverage is not yet confirmed. A handful of interval calculations for
> standardized factor loadings have been checked and shown accurate, but only
> for one Gaussian model, in a few fixed sample-size and rank combinations,
> fitted to one fixed simulated dataset with known true values, and only for
> fits that converge cleanly; this does not carry over to any other sample
> size, rank, or dataset."

Word-by-word mapping to the jargon it replaces (all five confusing terms named
by the reviewer are gone from every touched surface):

- **"cells"** (a sample-size × rank combination) → "sample-size and rank
  combinations."
- **"pinned"** / **"unrotated"** (the loadings held to one fixed scale and
  orientation, so "which cell" is unambiguous) → dropped; the surrounding
  sentence no longer needs the concept because it just says the result is for
  one fixed dataset with known true values, not a general claim.
- **"frozen DGP"** (the fixed, pre-registered simulated data-generating
  process) → "one fixed simulated dataset with known true values."
- **"target-specific certificates"** → "have been checked and shown accurate."
- **"neighbouring cells [do not inherit them]"** → "this does not carry over
  to any other sample size, rank, or dataset."
- **"fix-and-refit endpoints"** → dropped; folded into "we have not confirmed
  they match the exact answer" (README/DESCRIPTION/banner all already say this
  for the total-variance-profile sentence).
- **"route- and regime-specific"** → "how well they are supported depends on
  the exact model and route used."
- **"route-only"** (DESCRIPTION/banner's own remaining instance) → "still only
  an approximate calculation ... we have not confirmed they match the exact
  answer" (the same phrase now used in README).

## S3 — "the two model shapes recommended for real analyses" had no antecedent

Traced the referent in `vignettes/articles/current-limits.Rmd`'s "What
production confirmation found" section: "Gaussian `indep()`, Gaussian `dep()`,
Poisson-log rank-1 `latent(unique = TRUE)`, and Binomial(10)-logit rank-1
`latent(unique = TRUE)` passed their prespecified small/large core
point-estimation gates. **Gaussian `latent(unique = TRUE)` and NB2-log
`latent(unique = TRUE)` remained characterization-only.**" Since the sentence
in `README.md`/`vignettes/gllvmTMB.Rmd` is specifically about the Gaussian
*latent* teaching model (not `indep()`/`dep()`, which the previous sentence
already covers), "the production pair" that stayed at characterization-only
status is this pair. Both files now name them explicitly:

> "...but for the two specific latent-model shapes tested in production —
> Gaussian `latent(unique = TRUE)` and NB2-log `latent(unique = TRUE)` — we
> have so far only measured how they behave, not shown they recover known
> parameters, so treat this as a teaching example, not a proven method."

Applied in `README.md` and `vignettes/gllvmTMB.Rmd` identically.

## S4 — "Bare-bar `(1 + x | g)` slopes remain reserved" (README.md:56-57)

Replaced with a sentence naming the route that actually fits (per the
reviewer's own verification, `conv = 0`) and saying plainly that the lme4-style
spelling is not accepted:

> "The lme4-style bare-bar spelling `(1 + x | g)` is not accepted yet; for a
> random-slope model, use `latent(1 + x | g, d = K)` instead."

(`vignettes/gllvmTMB.Rmd` never had a bare-bar sentence, so no change was
needed there for S4.)

## Verification

- `Rscript -e 'read.dcf("DESCRIPTION")'` — parses cleanly (23 fields).
- `Rscript -e 'parse("R/zzz.R")'` — parses cleanly.
- No `document()`/`load_all()`/`test()`/render run, per instructions.

### Proof (exact command given)

```
$ grep -rnE "dependable-core claim|characterization-only|tested-regime evidence|production pair|route-only" \
    README.md DESCRIPTION R/zzz.R R/gllvmTMB-package.R vignettes/ --exclude=current-limits.Rmd
ugrep: warning: R/gllvmTMB-package.R: No such file or directory   # this file doesn't exist; package
                                                                    # roxygen lives in R/zzz.R (see Scope)
(no matches in any existing file — exit 1 when re-run without the nonexistent path)
```

Re-run without the nonexistent path (identical file set, minus the path that
never existed), for a clean exit code:

```
$ grep -rnE "dependable-core claim|characterization-only|tested-regime evidence|production pair|route-only" \
    README.md DESCRIPTION R/zzz.R vignettes/ --exclude=current-limits.Rmd
(no matches — exit 1)
```

Also checked `man/gllvmTMB-package.Rd` (not part of the required command, but
touched by me):

```
$ grep -nE "dependable-core claim|characterization-only|tested-regime evidence|production pair|route-only" man/gllvmTMB-package.Rd
(no matches — exit 1)
```

And a broader sweep for the individual jargon words named in R5 (cells,
pinned, unrotated, frozen DGP, target-specific certificates, neighbouring
cells, fix-and-refit endpoints, route- and regime-specific) across the same
five touched files — the only hits left are unrelated, pre-existing uses of
the ordinary English word "cells" (missing-*response*-cells in a data frame)
and "unrotated" (loading-sign interpretation elsewhere in the vignette), not
the banned phrases:

```
$ grep -rnE "\bcells\b|\bpinned\b|\bunrotated\b|frozen DGP|target-specific certificates|neighbouring cells|fix-and-refit endpoints|route- and regime-specific" \
    README.md DESCRIPTION R/zzz.R man/gllvmTMB-package.Rd vignettes/gllvmTMB.Rmd
README.md:186:Missing response cells are allowed. In a wide `traits(...)` data frame,
README.md:190:`predict_missing()` reconstructs masked response cells when
vignettes/gllvmTMB.Rmd:236:### What if some response cells are missing?
vignettes/gllvmTMB.Rmd:382:Do not over-interpret the signs of these unrotated loadings. Use them
```

## Diff stat (files touched in this fix pass)

```
$ git diff --stat -- README.md DESCRIPTION R/zzz.R man/gllvmTMB-package.Rd vignettes/gllvmTMB.Rmd
 DESCRIPTION             | 17 +++++++++++------
 R/zzz.R                 | 17 +++++++++++------
 README.md               | 28 ++++++++++++++++------------
 man/gllvmTMB-package.Rd |  2 +-
 vignettes/gllvmTMB.Rmd  |  9 +++++----
 5 files changed, 44 insertions(+), 29 deletions(-)
```

(Combined with the original A3 pass, `vignettes/articles/api-keyword-grid.Rmd`,
`vignettes/articles/current-limits.Rmd`, and
`vignettes/articles/profile-likelihood-ci.Rmd` also carry changes from the
earlier report, `dev/gapclose/A3-report.md`.)

---

## Follow-up — verifier scripts pinned the old jargon (coordinator round 3)

Full-suite run flagged four failures: the boundary was removed from the prose
but two test surfaces still pinned the literal old strings — `dev/interval-calibration/verify-claims.R`
(source of `tests/testthat/test-interval-calibration-claims.R:22-36`, the
"interval claim verification" test that shells out to it) and the "CI-13
certificates" test at `tests/testthat/test-interval-calibration-claims.R:126-179`
itself. Fixed both so the boundary claim is still enforced, in the new plain
words. No commit, no `document()`, no `load_all()`.

### What changed and why

**`vignettes/articles/profile-likelihood-ci.Rmd` needle** (verifier's own
requirement, `dev/interval-calibration/verify-claims.R`): `"Every computed
interval is labelled \`route-only\`"` → `"Every computed interval carries a
status marking it as calculated but not proven to match the exact
profile-likelihood answer"` (the exact sentence now in the article; the
second needle, `"exact constrained-refit convergence"`, was untouched by A3
and still matches, so it was left alone).

**The "frozen DGP" / "conditional on eligible fits" checks.** These two
phrases are pinned in far more places than the four surfaces I rewrote —
`grep -rl "frozen DGP"` finds it in 27 files, `grep -rl "conditional on
eligible fits"` in 23. Only four of those (`R/zzz.R`, `DESCRIPTION`,
`README.md`, `man/gllvmTMB-package.Rd`) got the A3 plain-language rewrite; the
rest (`NEWS.md`, `R/loading-ci.R`, `vignettes/articles/current-limits.Rmd`,
`docs/design/*.md`, `docs/dev-log/**/*.md`, `_pkgdown.yml`,
`cran-comments.md`, `man/loading_ci.Rd`, `docs/dev-log/artifacts/interval-calibration/public-route-census.csv`)
are untouched and still say "frozen DGP" / "conditional on eligible fits"
verbatim. So a blanket string swap would have broken the check for those 13
untouched files. Both verifier surfaces were split instead:

- **`dev/interval-calibration/verify-claims.R`**: the 5-file for-loop was
  split into a `c("DESCRIPTION", "README.md", "man/gllvmTMB-package.Rd")`
  group (now requires the two plain-language needles) and a
  `c("man/loading_ci.Rd", "docs/design/75-inference-route-truth-matrix.md")`
  group (still requires the two original needles, unchanged). The
  `R/zzz.R`-specific `require_fixed()` block also needed its own two
  R/zzz.R-only needles updated — `"pinned unrotated ordinary-Gaussian"` →
  `"for one Gaussian model"` and `"standardized-loading Wald cells"` →
  `"standardized factor loadings"` — since that sentence was rewritten too
  and the old needles no longer matched. The `_pkgdown.yml`/`cran-comments.md`
  loop, and every other `require_fixed()` call in the file, are untouched.
- **`tests/testthat/test-interval-calibration-claims.R`** ("CI-13
  certificates" test, :126-179): `claim_surfaces` was split into
  `plain_language_surfaces` (the same four files) and
  `original_wording_surfaces` (the other 13, unchanged list), each checked
  against the phrasing it actually contains. The `detailed` block
  (`R/loading-ci.R`, `NEWS.md`, `vignettes/articles/current-limits.Rmd`,
  checking the three numeric loading vectors) was not touched.

**Canonical plain-language needles used everywhere** (identical across
`R/zzz.R`, `DESCRIPTION`, `README.md`, `man/gllvmTMB-package.Rd` — confirmed
by grep below):

- `"one fixed simulated dataset with known true values"` (replaces "frozen
  DGP")
- `"only for fits that converge cleanly"` (replaces "conditional on eligible
  fits")

These two phrases previously straddled a markdown/roxygen line-wrap in
`README.md`, `DESCRIPTION`, and `R/zzz.R` (they were intact as a single
line only in the unwrapped `man/gllvmTMB-package.Rd`), so `grepl(...,
fixed = TRUE)` over the newline-joined text could not find them. Rewrapped
the paragraph at different line breaks in those three files — wording
unchanged, only where the line breaks fall — so each phrase now sits on one
physical line in every file. Re-verified both files still parse
(`read.dcf("DESCRIPTION")`, `parse("R/zzz.R")`) and the rendered message /
field content is unchanged apart from the wrap points.

### Verification

```
$ Rscript --vanilla dev/interval-calibration/verify-claims.R
INTERVAL_CLAIMS_OK
$ echo $?
0
```

```
$ Rscript -e 'testthat::test_file("tests/testthat/test-interval-calibration-claims.R", reporter = "summary")'
interval-calibration-claims: .....................

══ DONE ════════════════════════════════════════════════════════════════════════
```

Per-test breakdown (via `as.data.frame(test_file(..., reporter = "silent"))`):
6 test_that blocks, **0 failed, 0 error, 0 warning** — including "interval
claim verification passes on the synchronized surfaces" and "CI-13
certificates name the frozen DGP and eligible-fit condition", the two that
were failing before this fix.

Confirmed the four plain-language surfaces are identical (not just each
individually non-empty):

```
$ for f in R/zzz.R DESCRIPTION README.md man/gllvmTMB-package.Rd; do
    grep -c "one fixed simulated dataset with known true values" "$f"
    grep -c "only for fits that converge cleanly" "$f"
  done
1
1
1
1
1
1
1
1
```

Not weakened: `require_fixed()`/`expect_true(all(grepl(...)))` are the same
fail-closed functions as before — only the needle strings changed, and each
file is still checked against a real sentence that is actually present, so
deleting the boundary sentence from any of the four files (or from
`profile-likelihood-ci.Rmd`) will still make the corresponding check fail.

### Diff stat (this follow-up round)

```
$ git diff --stat -- README.md DESCRIPTION R/zzz.R man/gllvmTMB-package.Rd dev/interval-calibration/verify-claims.R tests/testthat/test-interval-calibration-claims.R
 DESCRIPTION                                       |  9 ++--
 R/zzz.R                                           |  9 ++--
 README.md                                         |  5 +-
 dev/interval-calibration/verify-claims.R          | 28 ++++++++---
 tests/testthat/test-interval-calibration-claims.R | 61 ++++++++++++++++++++---
 5 files changed, 88 insertions(+), 24 deletions(-)
```

(`man/gllvmTMB-package.Rd` shows no diff in this round because it was already
fixed in the previous round and needed no further rewrap — it is a single
unwrapped line, so it never had the line-break problem.)
