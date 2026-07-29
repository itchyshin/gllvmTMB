# Article executable-honesty ledger — 13 confirmed defects

Lane 2 (`claude/docs-honesty-20260728`), 2026-07-28. Worktree at `origin/main` @ `869e92b5`,
DESCRIPTION 0.6.0.

Method: 7 per-article auditors → 1 adversarial refuter per candidate, each instructed to default
to *refuted*. **15 candidates → 13 confirmed, 2 refuted.** Truth was established by static
reading of the 0.6.0 worktree's `NAMESPACE` and `R/*.R`. The locally installed package is
**0.5.0** and was excluded as ground truth by instruction.

⚠️ **Nothing was executed.** No article was knitted and no fit was run. Every entry is a
source-level contradiction. They are strong — several are unconditional `cli_abort`s on a
literal argument value — but a knit is what would make them *observed* rather than *derived*.

Companion: `2026-07-28-article-verification-gap.md` explains why these survived — the articles
are in `.Rbuildignore` and pkgdown builds only post-merge, so `eval=FALSE` chunks are executed
by nothing.

---

## BLOCKER

### 1. `joint-sdm.Rmd:318` — the article teaches a **withdrawn API**

The chunk calls `extract_correlations(fit_jsdm, tier = "unit", pair = pair_ij, method = "profile")`.
`R/extract-correlations.R:407` runs `match.arg(method)` — `"profile"` is still in the choices
vector — and then `:408-414` aborts **unconditionally**, class
`gllvmTMB_nonlinear_profile_withdrawn`, *before* `link_residual <- match.arg(link_residual)` at
`:415`. There is no option, argument, or escape hatch; a grep for the condition class finds only
aborts, no handler.

The defect is wider than the chunk. Prose at **311-316** claims profile reports a different
number on the bare Σ_B scale; **334-345** discusses the profile interval's `NA` behaviour and
`link_residual` handling. All describe removed behaviour, and the article carries **no
withdrawal note** anywhere.

*Refuter's narrowing, adopted:* execution halts at line 319, so the `rbind` at 330-332 never
runs — the original "also fails" was imprecise.

## HIGH

### 2. `covariance-correlation.Rmd:411` — narrates interval bounds the call cannot produce

`corr_B <- extract_correlations(fit_B, tier = "unit")` takes the default `method = "none"`, whose
row builder hard-codes `lower = NA_real_`, `upper = NA_real_` (`R/extract-correlations.R:662-676`).
But **405-406** says it "supplies the point estimates and Fisher-z interval bounds"; the
`fig.cap` at **415** and the `caption =` at **422** both assert Fisher-z bounds are displayed;
**428-432** says the plot renders "the Fisher-z interval columns already present in `corr_B`".

**It does not error** — and that is what makes it bad. `plot_correlations()` sets
`.has_interval <- is.finite(lower) & is.finite(upper)` (`R/plot-covariance-tables.R:389-390`),
FALSE everywhere, so the lower triangle renders with **empty labels** under a caption asserting
bounds are shown. A reader sees a plot that silently contradicts its own caption.

### 3. `joint-sdm.Rmd:216` — offers `method = "bootstrap"` as an available alternative

Same withdrawn-path family as (1). See the audit record for the exact reachability argument.

### 4. `joint-sdm.Rmd:390` — Wald/communality claim

## MEDIUM

5. `joint-sdm.Rmd:393` — profile-bounds claim for the binary communality proportion.
6. `response-families.Rmd:206` — **`mixed_long` is never defined.** Four independent search
   methods (`grep -rn`, `rg -n`, `git grep -n`, `find -exec grep -l`) all return nothing. The
   chunk's first statement operates on an object that does not exist.
7. `covariance-correlation.Rmd:194` — deprecated form taught as current.
8. `api-keyword-grid.Rmd:303` — `"kernel"` is prescribed as an `extract_Sigma()` `level` value;
   the choices vector has no `"kernel"` (`R/extract-sigma.R:677-692`). *Refuter partly narrowed:
   the mechanism is confirmed but the finding's `kind` was wrong — `match.arg(level)` fires only
   under a condition, so classify by the mechanism, not the label.*
9. `api-keyword-grid.Rmd:330` — bar-form availability claim across `phylo_`/`animal_`/`kernel_`/
   `spatial_`.

## LOW

10. `joint-sdm.Rmd:178` — Ψ_B companion / fit-message claim. *Refuter: "confirmed but
    overreaches and needs narrowing"* — take the narrowed version, not the original.
11. `response-families.Rmd:329` — rootogram family-support comment.
12. `covariance-correlation.Rmd:331` — Ψ diagonal return-shape claim.
13. `function-map-cheatsheet.Rmd:381` — deprecated form taught as current.

---

## Refuted — do not act on these

* **`api-keyword-grid.Rmd:269`** — refuted on three grounds; the article mirrors the package's
  own canonical phrasing at `R/kernel-keywords.R:12`. Not a defect.
* **`gllvm-vocabulary.Rmd:342`** — **the line does not exist.** The file is 318 lines. A literal
  grep for `correlation_ellipse` and for `plot(` returns zero hits in that file. The auditor
  filed a real finding against the wrong article.

That second one is the case for the refutation pass in one line: a confident, specific,
plausible `file:line` that was simply **not real**. It would have been believed without a
verifier whose default was *refuted*.

## Scope note

Six articles are affected. Per CLAUDE.md, broad article rewrites need maintainer discussion, so
**no article prose has been edited.** This ledger records; it does not fix.
`missing-data.Rmd` is fenced out of this lane (lane 3 owns it) and was not audited here.
