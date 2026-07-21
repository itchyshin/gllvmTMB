# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** `LOOP/GOAL.md` — read its **2026-07-21 MAINTAINER AMENDMENT** first: EVA is
CUT from 0.6 to 0.7; 0.6 is Laplace-only.

**STATE: M1 IS WITHHELD.** A D-43 completion panel returned **3/3 NOT-DONE** on the claim
"M1 is complete". Four blocking must-fixes have been applied; the head is being
re-qualified. **The previously qualified SHA `25c76789` is SUPERSEDED** — its A11 receipts
and its three green CI runs no longer describe the working tree.

## Why M1 was withheld

The engineering was found sound by all three reviewers. The failures were **documentary and
receipt-level — which is exactly what this milestone certifies.**

1. **Register codes on reader surfaces.** `NEWS.md` asserted "reader-facing pages no longer
   expose internal validation identifiers" while carrying **7** such codes; `origin/main`
   carried **0**, so the estate introduced them, against a standing repo rule. Also in 2
   rendered articles and 1 man page.
2. **The R-2 figures had no command trace** — measured but never logged — while `NEWS.md`
   quoted a stale pre-rework figure and omitted the intercept-variance bias entirely.
3. **The binomial slope routes are structurally tested only** and do not certify variance
   recovery, yet `NEWS.md` steers users from the soft-deprecated `phylo_unique()` onto
   `phylo_indep()` — the uncertified route — with no warning.
4. **R-6 and the 8 heavy-suite warnings were missing from the register.**

**A conceded error in my own reasoning:** I had argued items 2 and 4 could not enter the
register because a further commit would change the qualified SHA. That was **self-defeating**
— items 1–3 required source edits regardless, so the freeze bought nothing. Withdrawn.

## MUST-FIXES APPLIED (all four)

- Register codes stripped from `NEWS.md`, both articles, and `R/extract-correlations.R`;
  Rd regenerated. Where codes carried the meaning (per-route admission), the text was
  **rewritten in plain words**, not merely deleted. **Verified 0 codes in the RENDERED html**,
  not just in source.
- R-2 re-measured with the command, tree SHA and timestamp logged in `check-log.md`. It
  **reproduced 0.82 / 0.78 / 0.367 exactly**, so the figures stand rather than being struck.
  `NEWS.md` now states all three targets, including the previously undisclosed intercept bias.
- The limitation is restated as a **data-regime condition** (single-trial binary, few
  observations per grouping level) covering both `*_indep()` and `*_unique()` forms, with the
  structural-only test status stated explicitly.
- Register: R-6 SIGNED OFF (guard deferred to 0.7); new **R-7** records the 8 warnings, their
  sites, the causation evidence, and its limits — **two sites remain unnamed**.
  R-7 is `AWAITING SIGN-OFF`, not waived.

## RE-QUALIFICATION STATUS

The repair is **documentation-only** — `R/extract-correlations.R` changed by one roxygen
comment; no functional code changed.

- Both changed articles: **re-rendered and verified** (0 register codes in html; ordinal
  refusal oracle intact).
- Complete non-heavy suite: **running**.
- Still to do: source/CRAN-configuration check, new receipt commit, durable runners, CI.

## NEXT

1. Finish the suite; expect it unchanged from `FAIL 0 | WARN 0 | SKIP 779 | PASS 7287`
   (nothing functional changed) — investigate any deviation rather than accepting it.
2. Re-run the CRAN-configuration check (it validates `NEWS.md` and `man/`, both edited).
3. New receipt commit → new head → durable runners.
4. **🛑 CI re-spend needs maintainer sign-off.** One cycle was authorised and consumed.
   Options put to the maintainer: full cycle again, or Ubuntu + heavy only (the 3-OS matrix
   passed on functionally identical code and M5 must repeat it after the version bump anyway).

## OPEN GATES (need human)

- **R-7 awaits sign-off** — 8 pre-existing heavy warnings, 2 sites still unidentified.
- **CI re-spend** for the new head.
- Re-run the D-43 panel after re-qualification; M1 cannot close on the withheld verdict.
- M3 freeze + version bump · M4 **page decisions** · M4 candidate freeze · M5 RC/final tags ·
  submission.

## TRAPS THIS ARC ACTUALLY HIT

pkgdown reported exit 0 while artifacts were absent (destination is `pkgdown-site`, not
`docs/`) · a focused run reported `FAIL 0` while the assertion under test was skipped behind
`skip_if_not_heavy()` · `expect_warning()` in testthat 3e returns the **condition**, not the
value · a code comment read in isolation nearly became a false finding · an apparent false
`#750 SHIPPED` claim was **true on its own branch** · a limitation was nearly published
against code a 357-line rework had replaced · **and a milestone was nearly certified on a
document that contradicted itself.**

**Read the log, open the artifact, check which branch you are reading — and do not certify
release truth without checking the reader-facing surface for the exact defect you claim to
have removed.**

## TRUTH LIVES IN

Branch `codex/gllvmtmb-060-m1-baseline-20260720`, draft PR #778 (three comments record the
evidence and the panel), this `LOOP/` kit, `docs/dev-log/known-residuals-register.md`,
`docs/dev-log/2026-07-21-eva-cut-to-0.7.md`. Working tree is **dirty with the must-fix edits**;
no commit has yet been made for them.

## RESUME

```text
Read LOOP/GOAL.md (incl. the 2026-07-21 amendment) -> LOOP/checkpoint.md ->
LOOP/decision-queue.md -> docs/dev-log/known-residuals-register.md.
M1 is WITHHELD (D-43 3/3 NOT-DONE); four must-fixes are applied and the head is being
re-qualified. Finish local re-qualification, then STOP: CI re-spend needs maintainer
sign-off, and the D-43 panel must be re-run before M1 can close.
```
