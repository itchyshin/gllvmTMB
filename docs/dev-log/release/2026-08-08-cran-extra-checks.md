# CRAN extra-check audit

Date: 2026-08-08  
Identity: continuing 0.6 development; not the exact 0.7 candidate  
Status: mechanical audit complete; two deliberate follow-ups remain

## Result

The current source clears the first-submission checks below:

- `NEWS.md` and `cran-comments.md` exist.
- There is no `README.Rmd`, so `README.md` is the authoritative source.
- The README now gives the future CRAN installation command
  `install.packages("gllvmTMB")` and the current GitHub-development command.
- No non-HTTPS or relative Markdown link was found in the README.
- DESCRIPTION's 47-character title is title case and avoids the standard
  forbidden/redundant phrases.
- DESCRIPTION does not begin with “This package”, the package name, or
  “Functions for”; it supplies method references and expands SPDE/GMRF on first
  use as stochastic partial differential equation/Gaussian Markov random field.
- `Authors@R` contains Shinichi Nakagawa as `aut`, `cre`, and `cph`; explicit
  consent is recorded in the release-rights authorization receipt.
- GPL-3 and the bundled-component provenance ledger are present. The standard
  GPL-3 licence text has no package-specific year field to update.
- `LazyData` is absent, matching the absence of a `data/` directory.
- All 156 namespace exports have an Rd alias. The only export without its own
  `\value{}` section is `generics::tidy()`, an imported/re-exported generic
  whose upstream topic owns the return contract. `ordiplot()` was a genuine
  local omission and now documents its invisible scores/loadings return.
- The third provisional source tarball excluded internal simulation/dev files,
  generated root-vignette PNGs, CSL/BibTeX inputs, compiled objects, and local
  planning files.

`urlchecker::url_check(".")` fetched 31 URLs and found one unique unresolved
target at four source locations:

```text
https://itchyshin.github.io/gllvmTMB/articles/current-limits.html
```

This is the new canonical limitations page. The source, navigation, and local
render are correct, but the page has not yet reached `main`; the site deploys
only from `main`. Online 0.6 documentation publication is authorised, so this
404 will be closed through the normal merge + successful pkgdown deployment,
not by deleting the link.

## Example audit

The package contains 75 `\dontrun{}` blocks. The full provisional
`R CMD check --as-cran` nevertheless passed examples and donttest examples.
Most `\dontrun{}` blocks are model fits, optional Julia/GLLVM software, or
structured examples that are inappropriate for the fast default check. This
count is not treated as a failure, but it is a pre-19-August improvement lane:

1. convert pure constructors, algebra, and malformed-input demonstrations to
   runnable examples where they can execute without fitting;
2. retain `\dontrun{}` for external software or genuinely expensive fits;
3. use `\donttest{}` only when the exact-candidate check budget remains
   acceptable, because CRAN-style checks may execute it;
4. never turn a commented invalid call into apparently runnable evidence.

Thirty-three exports do not own an example block. They are a mixture of
compatibility aliases, imported generics, plotting/side-effect helpers,
deprecated spellings, and internal-facing exports. This is not a CRAN-check
failure. Before the exact candidate, the reader-facing core subset will receive
a focused runnable-example audit rather than adding 33 artificial or expensive
examples merely to satisfy a count.

## Remaining exact-candidate actions

1. Merge and deploy the limitations page from `main`, then rerun the URL check
   and require HTTP 200.
2. Replace the intentionally historical 0.6 `cran-comments.md` evidence only
   after G3, the 0.7 identity reconciliation, and exact-artifact/platform
   checks. No old receipt will be relabelled.

This audit does not authorize a version bump, GitHub 0.7 release, or CRAN
submission.
