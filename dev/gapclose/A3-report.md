# A3 — jargon rewrite, keyword-grid reorder, current-limits rows, CLAUDE.md pointer

Worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902`
Branch: `claude/gapclose-20260902`. No commit made (as instructed).

## Files touched

- `README.md`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/current-limits.Rmd` (new table rows only)
- `CLAUDE.md` — **not edited**; see "Task 4" section below for why.

(The working tree also shows pre-existing, uncommitted changes to `R/`,
`_pkgdown.yml`, `docs/design/35-validation-debt-register.md`, and
`inst/CITATION` from another slice sharing this worktree — none of that is
mine; confirmed by `git status` before I started and by the fact I never
opened those files.)

## Task 1 — the five undefined terms

Scope decision: I rewrote every occurrence in `README.md`, `vignettes/gllvmTMB.Rmd`,
and `vignettes/articles/profile-likelihood-ci.Rmd` (a page that uses "route-only"
without ever defining it). I deliberately left `vignettes/articles/current-limits.Rmd`'s
own prose/table alone — that file is the one place these terms **are** formally
defined (its "What the status labels mean" section plus the following paragraph
literally define `narrow tested-regime point evidence`, `narrow clean-data point
evidence`, and `characterization-only`; `dependable-core`/`dependable core` is
defined there too). Task 3 also scopes my current-limits.Rmd edit to *adding* rows
in the existing style, not rewriting the existing ~15-row table or its glossary —
doing so would be a large, non-surgical rewrite outside both tasks' stated scope.
**Flagging this as a deliberate scope call** in case the orchestrator wants the
current-limits.Rmd glossary simplified too (that would be a separate, bigger slice).

Term-by-term (plain replacement used):

1. **"dependable-core claim"** → "recover known parameters" / "proof the method
   works" (i.e., a claim that the estimate has been shown, not just measured, to
   recover the true value).
2. **"characterization-only"** → "we have so far only measured how [it] behaves —
   we have not yet shown [it] recover[s] known parameters."
3. **"narrow tested-regime [point] evidence"** → "[point estimates] have only been
   checked to recover known parameters under the specific conditions tested so far"
   / "evidence limited to the specific conditions we tested."
4. **"production pair"** → "the two model shapes recommended for real analyses."
5. **"route-only"** → "still only an approximate calculation" (prose); for the
   `profile-likelihood-ci.Rmd` table cell, which describes the literal status
   string the function returns (`R/profile-derived.R:940`,
   `status <- rep("route-only", ...)`, and `test-profile-ci-total-variance-export.R`
   checks this literal value): "carries a status marking it as calculated but not
   proven to match the exact profile-likelihood answer." **Caveat:** this is a real
   code-facing literal, not just prose jargon; the plain-language rewrite no longer
   tells the reader the literal string `"route-only"` they will actually see printed
   by `profile_ci_total_variance()`. Flagging this in case the orchestrator wants the
   literal value kept alongside the plain explanation.

### rg proof (README.md, vignettes/gllvmTMB.Rmd, vignettes/articles/profile-likelihood-ci.Rmd)

```
$ rg -n "dependable-core|characterization-only|narrow tested-regime|production pair|route-only" \
    README.md vignettes/gllvmTMB.Rmd vignettes/articles/profile-likelihood-ci.Rmd
(no matches — exit code 1)
```

Full-vignettes sweep (shows the intentional current-limits.Rmd survivors only):

```
$ rg -n "dependable-core|characterization-only|narrow tested-regime|production pair|route-only" vignettes/ README.md
vignettes/articles/current-limits.Rmd:37:dependable-core claim. The Gaussian latent decomposition remains useful as a
vignettes/articles/current-limits.Rmd:67:`latent(unique = TRUE)` remained characterization-only.
vignettes/articles/current-limits.Rmd:69:That result is deliberately narrower than a dependable-core label. Not every
vignettes/articles/current-limits.Rmd:94:| Ordinary Gaussian `latent()` | ... **Characterization-only:** ...
vignettes/articles/current-limits.Rmd:139:computed row is therefore `route-only`; the former `certified-0.94` labels are
```

## Task 2 — api-keyword-grid.Rmd reorder

Moved "## Source strength within a structured term" (the `rho = NULL` research
fence) from directly after the intro to a new "## Advanced: estimating the source
strength" section placed near the end (between "## What not to combine" and
"## If the first choice is too complex"). "## Choose in two steps" is now the
first section after the intro. Added one plain lead-in sentence where the old
section used to sit:

> "Most readers only need the two choices below; the optional `rho` setting on a
> structured term is covered later, in [Advanced: estimating the source
> strength](#advanced-estimating-the-source-strength)."

Every sentence of the moved section is unchanged — verified with `git diff` (pure
relocation, no rewording).

New section order: `## Choose in two steps` → `## The 5 × 3 grid` → `## What the
modes estimate` → `## Ordinary long and wide syntax` → `## Exact source-specific
syntax` → `## Dense kernels (the fifth grid row)` → `## What sits outside the
grid` → `## What not to combine` → `## Advanced: estimating the source strength`
→ `## If the first choice is too complex`.

Added one sentence clarifying when to use which `phylo_slope` grammar (in "What
sits outside the grid", after the existing "Group-indexed ... answer a different
grouping-axis question" sentence):

> "In short: use `phylo_slope(x | trait, tree = tree)` when the slope of `x`
> should vary **across response columns** (e.g. across traits or species treated
> as responses) and use `phylo_slope(x | species)` when the slope of `x` should
> vary **across the sampled grouping units** (e.g. across individuals or sites)
> that the tree relates."

## Task 3 — current-limits.Rmd new rows

Added five rows to the "Current decision table" (inserted before the existing
last row, "Wald, bootstrap, or profile intervals"), all status `Experimental/partial`
per the article's own vocabulary (no register codes used; `rg` confirms zero hits
for FG-20/ISDM-03/FG-18/FAM-20/STR-RHO-EST in the file):

| Analysis or result | Current status | What you may report | What you must not infer |
|---|---|---|---|
| Response-column coefficient models (`column_coef()`, `phylo_coef()`, `animal_coef()`, `kernel_coef()`, `spatial_coef()`) | Experimental/partial | Gaussian point estimates for a random intercept, slope, or both, varying across response columns, fitted through long or `traits(...)` wide data. `phylo_coef()` and `kernel_coef()` can fix a numeric mixture strength or estimate one interior value; `animal_coef()` fixes it; `spatial_coef()` fixes it at 1 and estimates the spatial range | Calibrated intervals, non-Gaussian responses, an estimated mixture strength for the animal or spatial routes, or recovery outside the tested Gaussian cells |
| Prediction at new locations for integrated (iSDM) fits (`predict()` on `isdm_sources()` fits) | Experimental/partial | Point predictions, including maps, at new in-hull coordinates for the ordinary intercept-only spatial tier; training-row predictions reproduce the fitted values exactly | Held-out map accuracy — the preregistered accuracy campaign did not pass its gate; a standard error or confidence interval on `newdata` predictions (`se.fit` is refused there); or predictions for spatial slope tiers, which remain unsupported |
| Predictor-informed latent scores (`latent(..., lv = ~ x)`) | Experimental/partial | Point estimates of the rotation-invariant effect of a predictor acting through the shared latent axes, combining traits from more than one response family in one model, in the specific tested construction and evidence cells | Broad recovery or calibration across arbitrary family combinations; support for missing latent-score predictors, combined fixed-and-latent-score predictors, REML, or a structured (phylogenetic/spatial/kernel) source on this term |
| Multinomial structured routes | Experimental/partial | Fixed-effect point estimates and probability predictions for one unordered multinomial response are well tested. Several structured extensions (a phylogenetic route, a shared-latent cross-family route, pedigree- or kernel-sourced routes, and ordinary group random intercepts) exist and each has its own narrower tested evidence | Fitting more than one multinomial response in the same model; augmented (intercept-and-slope) structured forms; or calibrated intervals on any structured multinomial route |
| Estimated source strength (`rho = NULL` on `phylo_*`/`animal_*`/`kernel_*`/`spatial_*` terms) | Experimental/partial | Bounded point-recovery evidence for a native Gaussian model with complete replicated trait vectors, one known relatedness source, retained observation-level residual variance, and no competing ordinary covariance term | General recovery across other source/covariance-mode combinations — most combinations tested so far did not pass; any confidence interval on the estimated strength, which does not yet exist; or recovery for augmented (intercept-and-slope) forms |

**One correction to the task brief:** the task's parenthetical for row 3 said
"Gaussian and pure binomial only; other families refuse." Per NEWS.md 0.7.1
("Predictor-informed latent axes now compose across registered native response
families") and register row FG-18 ("Ordinary unit-tier `latent(..., lv = ~ x)`
now composes registered native response families under one complete-response
block ... Live loadings-only rank-2/rank-3 canaries cover the five-family
ordinal/multinomial route"), that boundary is stale — the row above states the
current (still narrow, still `partial`) boundary instead: it composes across
families in specific tested/canary cells, not "Gaussian+binomial only."

Grounded in: `NEWS.md` lines 1-124 (0.7.1 and unreleased sections) and
`docs/design/35-validation-debt-register.md` rows FG-18 (line 119), FG-20
(line 122), ISDM-03 (line 533), STR-RHO-EST (line 944), FAM-20/FAM-20A-F
(lines 174, 184-189).

### rg proof (no register codes leaked)

```
$ grep -n "FG-20\|ISDM-03\|FG-18\|FAM-20\|STR-RHO-EST" vignettes/articles/current-limits.Rmd
(no matches — exit code 1)
```

## Task 4 — CLAUDE.md pointer fix: NOT DONE, branch mismatch found

The stale bullet/pointer described in the task
(`**START HERE:** docs/dev-log/handover/2026-08-20-codex-handover-rand-slope-terrapin-mspl.md`)
**does not exist anywhere in this worktree's `CLAUDE.md`** (branch
`claude/gapclose-20260902`). `grep -n "rand-slope-terrapin-mspl\|terrapin\|D-113 TRACK 6"
CLAUDE.md` returns nothing here. This worktree's Live Phase Snapshot currently
opens with the 2026-08-20 SDM-article-set bullet, not the D-113 track-6 bullet.

I traced it: that bullet was added by commit `d330b8dda` ("docs(handover): Claude
-> Codex, rand-slope/D-113 track 6 + terrapin bug lane") on branch
`claude/codex-handover-20260820-randslope-terrapin` — a **different branch**
from mine (and, per the session's own `gitStatus`, the branch the parent/orchestrating
session is checked out on). My worktree forked from a point that does not
include that commit, so there is nothing here to fix.

Also worth flagging for whoever applies the real fix: the task's suggested
replacement is itself not quite right. I checked
`docs/dev-log/handover/2026-08-20-codex-handover.md` on both my branch and on
`claude/codex-handover-20260820-randslope-terrapin` — on both, that file is the
**SDM-article-set/prediction-uncertainty lane's** handover (a same-day filename
collision between two unrelated lanes, which commit `d330b8dda`'s own message
acknowledges: "a concurrent sibling lane's own same-day bullet"). It contains no
rand-slope, terrapin, PR #1164/#1166/#1171, or MSPL content at lines 70-113 or
anywhere else (`grep` for those terms returns nothing).
`docs/dev-log/handover/2026-08-19-claude-handover-rand-slope.md` **does** cover
the rand-slope/D-113-track-6 side (PR #1164/#1166, `slope_sd_ci()`, the board
correction) but **not** the terrapin external-bug lane or the MSPL sweep — I could
not find any existing file (searched all refs with
`git log --all -S "terrapin-systematic-map"`) that documents those two pieces;
commit `d330b8dda` only added the CLAUDE.md bullet and pointer, it never created
the file it points to.

**Recommendation for the orchestrator:** this fix needs to land on
`claude/codex-handover-20260820-randslope-terrapin` (or wherever that bullet
currently lives on `main`), and the correct pointer is probably
`docs/dev-log/handover/2026-08-19-claude-handover-rand-slope.md` alone (drop the
non-existent `-rand-slope-terrapin-mspl` filename and the false claim that
`2026-08-20-codex-handover.md` covers this lane) — with a note that the terrapin
bug lane and MSPL sweep still need their own written handover, since none
currently exists anywhere in git history.

## Verification method

Read each target region with the Read tool before editing; edited with Edit
(exact-match replacements only, no reflow of untouched paragraphs); re-checked
with `rg -n` after each file. No `devtools::load_all()`/`document()`/`test()`/
render was run, per the task's restriction. No commit was made.
