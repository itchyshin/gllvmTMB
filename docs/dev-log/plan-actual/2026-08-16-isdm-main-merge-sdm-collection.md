# Plan vs actual — isdm→main merge + SDM collection (2026-08-16)

Reconciler: Melissa. Plan: the approved ultra-plan "Land isdm on main, then the
pkgdown SDM collection" (`generic-giggling-tulip.md`). Lanes:
`codex/isdm-range-amplitude-orthogonal` ([#1031](https://github.com/itchyshin/gllvmTMB/pull/1031)) then
`claude/sdm-collection-20260816` ([#1034](https://github.com/itchyshin/gllvmTMB/pull/1034)).

## Scope

**Clean.** Both deliverables landed as specified, nothing else. A: #1031 merged
(`main` @ `2b87aa98`), verified to carry `R/isdm-sources.R`, the three integrated
articles, and the composed `report_obs_nll`/`estimator_id` template. B: the
`_pkgdown.yml` diff matches the plan's instructions down to the ordering; the
"do not touch" list held — the staged drafts are untouched and the new article
was written fresh at the planned path.

## Evidence and verification

**Clean, with one imprecision caught by the reconciler.** All checks verified
independently, not just asserted: fold delta genuinely zero-conflict; suites
re-run on the final tree (isdm 305/0; mspl 1630/2, the 2 confirmed red on bare
`origin/main:R/mspl.R` by direct diff); `check_pkgdown()` and the full-chunk
render real; every Rose-lens fix present in the committed `.Rmd`. The catch:
the fold-delta was characterised as "touched only `R/methods-gllvmTMB.R` among
shared files" — `R/mspl-registry.R` also changed (+46/−8) in the same delta.
Additive, MSPL-only, no isdm-side edits, both suites were re-run regardless —
harmless here, but the framing understated the diff surface.

## Model routing

**ADAPTIVE (disclosed, pre-registered).** B2 and B4 ran inline on the
orchestrator instead of dispatched children — the plan's own MODEL/BARS section
pre-authorised exactly this fallback after three classifier-blocked dispatches
earlier in the day. Read-only children ran as planned: the Rose audit and this
reconciliation (2 Sonnet, both read-only; 2 of the 4 authorised).

## Safety gates

**Clean.** D-139 correctly not triggered (all compute seconds on the Mac, as
pre-declared); D-43 correctly not fired (no `covered` promotion); D-88 held —
the MSPL pin was flagged in #1031's body and never fixed; the docs-class
self-merge authority for #1034 verified against the actual diff (NEWS,
`_pkgdown.yml`, after-task, one new `.Rmd`; no `R/`, `src/`, or tests).

## Public claims

**Clean.** #1031's body pre-empts misattribution of the pre-existing mspl-pin
red, exactly as the plan's TEAM RAISED demanded. The article's
relative-intensity estimand fence is intact in the shipped prose; no register
codes on the reader surface; the CI claim (single ubuntu job, pass, 39m48s)
verified via `gh pr checks`.

## Handoff state

**ADAPTIVE (disclosed, in progress at reconciliation time).** #1034 open with
CI running and self-merge armed for green — B6's planned shape. One in-flight
addition beyond the plan's knowledge: `mspl-binary-jsdm` landed on `main`
mid-arc and was cross-linked into the new menu — a strict within-authority
extension of the plan's spatial-models cross-link decision, disclosed at the
time.

## For the drift ledger

1. **Verify "the delta touched only file X" with `git diff --stat` on the
   path-glob, never the single-file framing** — a second file
   (`R/mspl-registry.R`) was in the delta; harmless here, but a reconciliation
   that skipped the direct diff would have missed it.
2. **Pre-registering fallback routing in the plan converts silent drift into
   labelled ADAPTIVE.** When an infrastructure block is already visible before
   approval (three classifier-blocked dispatches), write the fallback into the
   plan — this is now supported by four occurrences over two arcs.
