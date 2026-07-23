# After-task — M4 opens: D-41 warning, reader-overclaim audit, dossier fences

**Date:** 2026-07-22 · **Platform:** Claude Code (solo lane) · **Branch:**
`claude/0.6-m1-close-20260722` · **Arc:** M4 (reader-ready), mechanical half.

## 1. Goal

Advance gllvmTMB 0.6 past M1/M3 (both closed) into M4, doing the mechanical + additive-honesty work
that does not need Shinichi's page-by-page review, and stopping at the candidate-freeze gate. No merge,
tag, freeze, submission, or readiness claim.

## 2. Implemented

1. **D-41 experimental warning on all four accepted channels** — grounded from `memory/DECISIONS.md`
   D-41 (accepted mechanism = startup message + lifecycle badge + pkgdown/README callout + DESCRIPTION
   line; **not** a per-export badge). `.onAttach` in `R/zzz.R` (verified firing), a `README.md`
   `[!WARNING]` callout, a `_pkgdown.yml` home-sidebar Status callout, and a DESCRIPTION sentence.
2. **Reader-surface overclaim audit** — a 10-agent workflow over six surfaces, each candidate
   adversarially verified. Hard surfaces clean; dossier at
   `docs/dev-log/2026-07-22-m4-overclaim-audit-dossier.md`.
3. **Four dossier fences applied (additive-safe)** — dropped "validated" at `kernel-helpers.R:13`;
   added a consistent `@section Interval calibration:` to `extract_phylo_signal`, `loading_ci`,
   `extract_repeatability`.
4. **Class sweep** of `man/` + shipped vignette + DESCRIPTION for `validat*`/`calibrat*` — no residual
   overclaim (the rest are honest negations or the MCMCglmm reference-implementation correctness note).
5. **The pkgdown deprecation-date fix** (earlier this session): `_pkgdown.yml:319` had one blanket
   "0.5.0" over two families deprecated at different versions (0.2.0 unique-family, 0.5.0 scalar).
6. **M4→M5 runbook** — `docs/dev-log/2026-07-22-m4-to-m5-runbook.md`.

## 3a. Decisions and Rejected Alternatives

- **D-41 is 4 channels, not a badge on 153 exports.** An earlier scorecard implied per-export badges;
  the brain's accepted mechanism does not. Rejected the mass badge sweep. *(Grounded, not guessed.)*
- **Additive-safe fences may be applied autonomously; meaning-changes are held.** A fence that only
  makes a claim smaller cannot become a false claim (the Decision-1 logic Shinichi accepted). Anything
  that would add or alter a claim is held for the page review — the standing "reader wording with
  Shinichi" rule.
- **Reinstated one finding the audit panel refuted.** The `confirmed_count: 0` was corrected by a human
  re-read of the workflow journal — the "read the log, not the summary" rule applied to my own
  workflow.

## 4. Files Touched

`R/zzz.R`, `R/brms-sugar.R`, `DESCRIPTION`, `README.md`, `_pkgdown.yml`, `R/kernel-helpers.R`,
`R/extract-omega.R`, `R/loading-ci.R`, `R/extract-repeatability.R`, `man/gllvmTMB-package.Rd` +
4 regenerated Rd topics. Docs: the audit dossier, the M4→M5 runbook, `check-log.md`, `LOOP/checkpoint.md`.
**All R changes are roxygen comments — zero code change** (verified: no non-comment `+` line in `R/`).

## 5. Checks Run

Ninth chain green at the D-41 SHA `70e070be` (local `0|779|7290`, 3-OS all OS `Status: OK` building
`gllvmTMB_0.6.0.tar.gz`, heavy `FAIL 0`, CRAN-config 0/0/1 `SHA_STABLE`). Tenth chain dispatched at
the fences SHA `aa939ce8` (result recorded in `check-log.md`). `check_pkgdown()` passes.

## 6. Tests of the Tests

`.onAttach` verified **firing** via `pkgload::load_all(attach = TRUE)` — the earlier `library()` probe
was wrong (it loaded the installed old package). The transfer-check path list is the corrected
shipped set including `NEWS.md`/`README.md`/`inst/`. Suite read from `as.data.frame()` structured
counts, never grep of reporter prose.

## 7a. Issue Ledger

No issue state changed. #750 ("Target release: 0.6") and #345 (CRAN umbrella) remain the M4/M5
touchpoints; triage recorded earlier (`docs/dev-log/2026-07-22-a-iss-open-issue-triage.md`).

## 8. Consistency Audit

The `_pkgdown.yml`-vs-`brms-sugar.R` deprecation-date contradiction is resolved (0.2.0 unique-family /
0.5.0 scalar). The `kernel-helpers.R` internal inconsistency (line 13 "validated" vs line 281 forbidding
it) is resolved. No new contradiction introduced.

## 9. What Did Not Go Smoothly

- My `.onAttach` verification first ran against the installed package and showed nothing — a false
  negative I caught and corrected with `load_all(attach = TRUE)`.
- The audit consolidation reported `confirmed_count: 0`; the real count was one medium + three
  page-review candidates. The workflow's summary needed a human journal re-read — a reminder the
  discipline applies to one's own tooling.

## 10. Known Limitations And Next Actions

- **M4's core is unstarted and is Shinichi's:** the page-by-page reader review. The dossier makes it a
  focused sitting, not a blank hunt.
- **The three CI-topic caveats are agent-proposed wording** — subject to the page review; one-line
  reverts if he prefers different phrasing.
- **Candidate freeze, RC tag, final tag, submission, readiness claim** remain gated. Rung: NOT READY,
  below source-clean (D-49/D-66).
- **`cran-comments.md`** (stale, `.Rbuildignore`d) is deferred to M5-f per the runbook.

## 11. Team Learning

- **Rose:** additive-safe is the honest autonomy boundary for reader wording — apply what can only
  shrink a claim, surface it as a diff, hold the rest.
- **Curie:** grounding D-41 from the brain before touching 153 exports saved a large wrong sweep.
- **Ada:** the "read the log not the summary" rule now has a self-referential instance — a workflow's
  own consolidation was wrong and a journal re-read fixed it.
