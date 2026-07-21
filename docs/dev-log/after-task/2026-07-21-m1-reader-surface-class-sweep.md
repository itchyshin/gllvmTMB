# After task — M1 reader-surface class sweep after a second D-43 withholding

**Date:** 2026-07-21 · **Platform:** Claude Code (sole writer) ·
**Branch:** `codex/gllvmtmb-060-m1-baseline-20260720` · **PR:** #778 (draft) ·
**Supersedes head:** `ca755c81` (itself superseding `25c76789`)

## 1. Goal

Repair the defects found by the **second** D-43 completion panel, which returned **3/3
NOT-DONE** on the claim "M1 is complete" — the second consecutive withholding. The first
panel withheld on a documentary self-contradiction; the second withheld because the repair
for it was a **targeted string removal rather than a class sweep**, and because that repair
introduced new instances of the same defect.

## 2. Implemented

**A mechanical guard, written first.** `tools/check-reader-surface.sh` fails when an internal
identifier or unshipped path appears on a user-facing surface: validation-register codes
(`[A-Z]{2,4}-[0-9]{2,}`), internal phase codes (`M[0-9]`), `Design NN` references, and
`docs/(design|dev-log)/` paths — the last because `.Rbuildignore` strips `^docs$`, making
them **dead links for the CRAN reader they address**. Scope: `README.md`, `NEWS.md`,
`DESCRIPTION`, `man/`, `vignettes/`.

Two exclusions, documented in the script itself: `refs.bib` (R Journal DOIs such as
`RJ-2018-017` match the register-code shape and are legitimate citations — a guard that fires
on a DOI trains the reader to ignore it), and absolute `https://github.com/...` URLs in
README (those resolve; only bare `docs/` paths are dead). Binary files are skipped after
`man/figures/logo.png` matched by chance.

**Building the guard before the fix was the method change.** It defined "done" objectively
and immediately showed the true scope: **12 files, not the 3 previously patched.**

**The class sweep, fixed at source.** Twelve roxygen blocks across eleven R files rewritten in
plain reader language, then `devtools::document()` re-run. Three of them —
`R/check-identifiability.R`, `R/coverage-study.R`, `R/methods-gllvmTMB.R` — carried violations
whose generated `.Rd` the earlier scan never surfaced; only a source-level sweep reaches those.
Plus `NEWS.md`, and `vignettes/articles/model-selection-latent-rank.Rmd`.

**Two doc-code contradictions the second panel caught in the first repair.** `?simulate`'s
`@param` had been corrected while its `\description{}` still documented the **non-default**
`condition_on_RE = TRUE` branch and a Gaussian-only residual; and `bootstrap_Sigma()`'s
Caveats claimed the simulator "conditions on the fitted random effects" — the opposite of the
corrected page. Both fixed at source. `bootstrap_Sigma()` now states plainly that intervals
are **not calibrated** for fits whose tier cannot be redrawn.

**A false instruction removed.** The previous repair rewrote a register-code sentence into
prose telling users to "check the help page for the specific keyword — it states what is and
is not covered." **Zero of the nine keyword help pages state coverage.** That replaced an
opaque-but-true statement with a readable-but-false one, which is worse. It now says plainly
that this release does **not** publish a per-route coverage table, and that a successful fit
is evidence of admissibility, not validation.

**Receipts made genuinely durable.** The prior "durable receipt" claim was overstated: the
RDS files sat in `/private/tmp`, which is ephemeral, while the evidence directory held only
`c6e1dd8a`. Both receipts plus the runner log are now mirrored under
`~/gllvmTMB-0.6-evidence/m1/final-receipt/<sha>/` with a `SHA256SUMS.txt`.

## 3a. Decisions and Rejected Alternatives

| Decision | Rejected alternative | Why |
|---|---|---|
| Write the guard **before** the sweep | Sweep, then add a guard | The guard defines "done" objectively. Sweeping first is how the previous attempt concluded it was finished while 9 of 12 files were untouched |
| Fix `man/` violations in **roxygen** | Edit generated `.Rd` | `.Rd` edits are overwritten by the next `document()`, and would silently reintroduce the class |
| State plainly that no coverage table exists | Add per-route coverage to nine `@details` blocks | Writing nine coverage statements I have not verified would repeat the exact defect being fixed — a confident claim about validation status |
| Retract the "origin/main carried zero" claim in place | Quietly correct it | The claim was propagated into a commit message, two PR comments and the check-log. A silent edit would leave three durable records disagreeing |
| Exclude DOIs and resolving URLs from the guard | Flag every match | A guard that reports legitimate citations as defects gets ignored, and an ignored guard is worse than none |

## 4. Files Touched

**New:** `tools/check-reader-surface.sh`, this report.
**Source (roxygen):** `R/bootstrap-sigma.R`, `R/brms-sugar.R`, `R/check-consistency.R`,
`R/check-identifiability.R`, `R/coverage-study.R`, `R/families.R`, `R/gllvmTMB.R`,
`R/gllvmTMB-wide.R`, `R/methods-gllvmTMB.R`, `R/traits-keyword.R`, `R/unique-keyword.R`.
**Generated:** ten `man/*.Rd`.
**Reader-facing:** `NEWS.md`, `vignettes/articles/model-selection-latent-rank.Rmd`.
**Records:** `docs/dev-log/known-residuals-register.md` (R-5 reopened and re-closed, R-7 status
corrected), `docs/dev-log/check-log.md` (retraction appended), `LOOP/checkpoint.md`.

No functional code changed. No `src/`, `DESCRIPTION`, or `NAMESPACE` changes.

## 5. Checks Run

| Check | Result |
|---|---|
| `tools/check-reader-surface.sh` | **PASS** (was FAIL with 11 violations before the sweep) |
| Complete non-heavy suite | see §6 |
| CRAN-configuration check | pending at time of writing |
| `devtools::document()` | regenerated ten Rd topics, no NAMESPACE change |

## 6. Tests of the Tests

The guard was **validated by its own failure first**: run before the sweep it reported 11
violations across 12 files; run after, it passes. A guard that had passed on the pre-sweep
tree would have been worthless, and that was checked rather than assumed.

Its exclusions were also tested against reality rather than reasoned about: the `refs.bib`
DOIs and the `logo.png` binary match were both discovered by running it, not predicted.

## 7. Roadmap Tick

M1 remains **WITHHELD**. This report closes the repair; it does not close M1. A third D-43
panel must convene against the repaired head.

## 7a. Issue Ledger

No issues closed. #750 remains retargeted to 0.7.

## 8. Consistency Audit

- `NEWS.md`'s self-claim is now an **enforced property** rather than an assertion.
- Three durable records (commit message, PR comments, check-log) had propagated the false
  "origin/main carried zero" claim. The check-log now carries an explicit retraction; the
  commit message is immutable and is corrected by the PR record.
- R-5 was marked RESOLVED on a two-page surface where one page was still wrong. Reopened,
  fixed, re-closed with the lesson recorded.
- R-7's Sites row said "all eight now identified" while its Status row four lines later still
  said two needed identifying. The stale clause had propagated to `check-log.md` and
  `LOOP/checkpoint.md`. All three corrected.

## 9. What Did Not Go Smoothly

**The repair for the first panel's finding was itself defective, in four distinct ways.** It
patched 3 of 12 files; it introduced a new register code *and* a dead `docs/` path into
`NEWS.md`; it replaced a true statement with a false one; and it asserted "origin/main carried
zero such codes" on the strength of grepping a single file, then propagated that into three
durable records.

The Rose principle — *when a mistake is found, assume ten more of the same kind and fix them
all* — is in this project's standing instructions and was available throughout. It was not
applied. The corrective is not "look harder next time"; it is the guard, which does not
depend on anyone looking.

## 10. Known Residuals

`docs/dev-log/known-residuals-register.md`: R-1, R-3, R-5 RESOLVED; R-4 resolved as far as
this package can; R-2 and R-6 SIGNED OFF; **R-7 AWAITING SIGN-OFF** (eight pre-existing
heavy-suite warnings, all sites now named, causation by exact set match).

## 11. Team Learning

- **Write the guard before the fix.** It defines "done" objectively and exposes the true
  scope. A sweep judged by the sweeper reliably stops at the last thing noticed.
- **Fixing the parameter you are looking at is not fixing the page.** `?simulate` had three
  surfaces; one was corrected and two left contradicting it.
- **A negative grep over one file is not a property of all files.** "origin/main carried zero"
  came from `NEWS.md` alone and was false of `vignettes/`.
- **Readable-but-false is worse than opaque-but-true.** Replacing register codes with a
  redirect to documentation that does not exist made the surface worse, not better.
- **Green CI cannot detect a document lying about itself.** Three OSes and an independent
  precommit review passed the contradiction that withheld M1.

## 12. Cross-Product Coverage

| Surface | Covered | **does NOT cover** |
|---|---|---|
| Reader-facing identifier hygiene | README, NEWS, DESCRIPTION, `man/`, `vignettes/` — enforced by `tools/check-reader-surface.sh` | **`inst/`, `data-raw/`, and any surface added later** — the guard's surface list is fixed and must be extended deliberately |
| `simulate()` / `bootstrap_Sigma()` doc-code agreement | `@param`, `\description{}`, and Caveats now agree that redraw is the default and unhandled tiers fall back | **the capability gap itself** — SPDE spatial and diagonal phylogenetic tiers still are not redrawn; documented, not fixed |
| Per-route validation status | stated plainly that no coverage table exists | **actual per-route coverage** — nine keyword help pages still do not state it, deliberately, rather than asserting unverified status |
| Register accuracy | R-5 reopened/re-closed; R-7 status corrected; stale clauses removed from three files | **the eight warnings' underlying causes** — R-7 records sites and causation, not diagnosis |
| Guard scope | register codes, `M[0-9]`, `Design NN`, `docs/` paths | **other classes of internal leakage** — agent names, dates, phase language in prose are not detected |
| Evidence durability | receipts mirrored with SHA-256 under the evidence directory | **the superseded heads** — `25c76789`'s receipts remain only in `/private/tmp` and are not mirrored |
