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
