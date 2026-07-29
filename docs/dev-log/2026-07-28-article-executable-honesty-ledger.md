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
13. `convergence-start-values.Rmd:381` — deprecated form taught as current. The checklist said
    "Try residual starts for non-Gaussian reduced-rank models" while **the same article's own
    section at line 222** is headed "The residual start is soft-deprecated (0.6.0)" and line 215
    marks it *(soft-deprecated — see below; use the default starts)*. A self-contradiction
    inside one article.

    > **Correction:** this was filed in the first draft of this ledger as
    > `function-map-cheatsheet.Rmd:381`. That file is 280 lines long. The error was mine, not
    > the auditor's — that agent covered three files, and my extraction took the *last* path
    > from a comma-joined string as the attribution for every finding in the group. Caught by
    > opening the file and finding no line 381. Same failure mode as the refuted
    > `gllvm-vocabulary.Rmd:342` below, from a different cause.

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

---

## Fix status

Shinichi authorised fixing the unambiguous defects and chose the approach for the two that
needed a content decision (2026-07-28).

| # | Status | Commit |
|---|---|---|
| 1 BLOCKER `joint-sdm.Rmd` | **fixed** — dead chunk and stale prose cut, replaced with a withdrawal note in the abort's own wording | `9ca80ba9` |
| 3 HIGH `joint-sdm.Rmd:216` | **fixed** — `"profile"` removed from the available-alternatives list, and the scale caveat that applied only to that path | `9ca80ba9` |
| — consequential | **fixed** — "three CI methods" framing corrected; my own edit invalidated the count | `9ca80ba9` |
| 2 HIGH `covariance-correlation.Rmd:411` | **fixed** — `method = "fisher-z"` added, fix-forward per decision | `1bb5a827` |
| 13 `convergence-start-values.Rmd:381` | **fixed** — checklist item aligned with the article's own deprecation section | this commit |
| 4, 5 (ICC Wald fallback; ICC profile → `NA`) | **not fixed, deliberately** — runtime claims. Unlike `extract_correlations()`, `extract_communality()` genuinely accepts `method = "profile"` and does not abort (`R/extractors.R:207,214`), so the article may well be right. Verifying needs a fit. |
| 6, 7, 8, 9, 10, 11, 12 | **open** — need either a fit or a content judgement |

### Regression guard

`tests/testthat/test-article-prescribed-calls.R` now parses every article chunk (including
`eval = FALSE`) and asserts prescribed calls resolve, named arguments are in formals, literal
values are among declared choices, and no withdrawn value is used. Verified to **fail** on
finding 1 before the fix and pass after.

It catches 1 of the 13 findings, and that limit is the honest point: the other 12 are prose
claims, which no static parser can adjudicate. The guard closes the *invalid-call* class only.

**The test had three bugs that each made it pass vacuously**, all found by insisting it fail
first: `parse()` returns an `expression`, for which `is.call()` is FALSE, so the walker never
descended; `as.list()` on a call yields the empty symbol for missing arguments, which errors on
*any* evaluation — including a predicate written to detect it; and `formals()` entries without
defaults are that same empty symbol. A guard test that silently passes is worse than no guard.

## Scope note

Six articles are affected. Per CLAUDE.md this review is meant to be slow and deliberate, so
only defects with a single defensible answer were fixed; everything needing a content call is
left open above. `missing-data.Rmd` is fenced out of this lane (lane 3 owns it) and was not
audited here.

**Adjacent — flagged, then fixed on Shinichi's instruction.** `R/diagnose.R:1081` emitted a
non-convergence hint recommending "residual starts for non-Gaussian latent fits", the same
soft-deprecated form corrected in finding 13. Printed output is a reader surface under
CLAUDE.md. Initially left alone under the surgical-changes rule since it is a behaviour change
rather than documentation; Shinichi ruled it in.

Guarded by `tests/testthat/test-no-deprecated-recommendations.R`, which scans string literals
across `R/` and asserts none *recommends* the residual start. Two deliberate exemptions: it
reads literals from `parse()`, so code **comments** are excluded — necessary, because
`R/fit-multi.R:3912` legitimately names the mechanism in a comment — and messages that mention
the deprecation are allowed, since it is the recommendation that is the defect. Verified to fail
on exactly one offender before the fix and pass after.
