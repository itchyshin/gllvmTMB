# After Task: plain-language auto-Psi skip note for multinomial traits (refs #1580)

**Branch**: `cursor/fix-1580-multinomial-psi-note-ae5d`
**Date**: `2026-11-19`

## Goal

Issue #1580 listed one unfixed item: the note printed for a Gaussian + `multinomial()` fit with the default `latent()` exposed internals ("Mapped `theta_diag_B[t]` and the corresponding `s_B` row off") and listed "binary / categorical-contrast / single-observation ordinal" traits when only multinomial contrasts were affected.

## Mathematical contract

None. No likelihood, grammar, estimand, family or default change. The identifiability gate that maps the between-unit Psi off for these traits is untouched; only the text of the note changed.

## Files

- `R/fit-multi.R` -- `.auto_psi_skip_message()`: header names the one kind that was skipped; closing bullet is plain language.
- `tests/testthat/test-issue-1580-message-text.R` -- three new tests (header per kind, no internal names, a real Gaussian + multinomial fit).
- `NEWS.md`, `docs/dev-log/check-log.d/2026-11-19-fix-1580-multinomial-psi-note.md`, this report.

No roxygen, Rd, README, vignette, design-doc or validation-debt edit: no exported behaviour moved.

## Decision recorded

A fit that skips more than one kind (for example binary + ordinal) keeps the combined header unchanged, because `test-degenerate-laplace-optima.R:309` pins that exact wording and test expectations were not to move. Only single-kind fits get the specific header.

## Checks

See the check-log fragment: new file 33 pass / 0 fail (23 fail on main); six neighbouring files 0 fail.

## Tests of the tests

On main (`902c069c`) the three new tests fail (23 expectations): the header lists all three kinds for a multinomial-only skip and the note contains `theta_diag_B[t]` and `s_B`.

## Consistency

Rose: reader-facing text uses `Psi` (matching the existing note) and no register codes. Boole/Gauss/Noether: not engaged, no grammar or likelihood touch.

## GitHub issue ledger

Uses `refs #1580`; does not close it. Two sibling strings with the same internal-name pattern (W-tier single-trial binomial note, explicit-`indep()` ordinal warning) were left alone.

## Limitations

The two sibling strings above still print `theta_diag_W[t]` / `theta_diag_B[t]`.
