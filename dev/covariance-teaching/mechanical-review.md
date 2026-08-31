# Mechanical review: covariance teaching correction

**Reviewer:** Luna
**Baseline:** `da6398a9d8df78c04dc4645dfa3fd4c3bd8d75e3`
**Scope:** static review only; no R execution, fitting, compilation, commit, or source edit.

## Verdict

The article changes preserve the evaluated fit surface. The three affected
articles retain exactly the baseline evaluated `gllvmTMB()` calls: covariance
correlation `3 -> 3`, cross-family correlations `2 -> 2`, and spatial models
`4 -> 4`. The added wide formulas are all in chunks explicitly marked
`eval = FALSE`.

The four requested figure descriptions are present and limited to the intended
plots: `covariance-correlation.Rmd` lines 290, 375, and 433, and
`cross-family-correlations.Rmd` line 332. No new `fig.alt` metadata was added
to the spatial article.

## Evidence

I compared each article's evaluated chunk bodies against the baseline with a
static chunk extractor. The evaluated code was identical for all three files
(18, 8, and 13 evaluated chunks respectively). A synthetic change to the
`fit_A` expression was detected as a mismatch, and changing the early
structural chunk from `eval = FALSE` to `eval = TRUE` increased the evaluated
chunk count. These negative controls show that the comparison detects both
expression edits and accidental evaluation changes.

`dev/covariance-teaching/verify-invariants.R` contains the parent invariant
checks: evaluated-chunk AST identity, the approved changed-file allow-list,
and the spatial positive counterexample (same total covariance with distinct
shared diagonals and positive diagonal Psi). I inspected these checks without
running them; the static controls above provide the mechanical sensitivity
check for the two failure modes requested here.

The refresh check confirms that the changed roxygen block belongs to
`extract_cross_correlations()` (the block begins at line 789 and the function
definition is at line 886); the apparent `extract_correlations` hunk label is
only diff context. The ordinary `extract_correlations()` roxygen block around
lines 304–315 and `man/extract_correlations.Rd` are unchanged. The generated
`man/extract_cross_correlations.Rd` carries the matching wording, and the sole
executable source change is the approved diagnostic-label replacement. No
classes, function signatures, or executable expressions were changed.

## Commands and limits

Static commands inspected `git diff --unified=0`, `git show <baseline>:<path>`,
`rg`/`awk` chunk headers and calls, and the parent invariant script. No R,
`devtools`, `pkgdown`, model fit, or compilation command was run. This review
does not validate rendered HTML, generated Rd files, or scientific numerical
results.
