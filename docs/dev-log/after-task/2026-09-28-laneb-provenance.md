# After Task: Lane B MSPL Provenance Correction

**Branch**: `codex/cran-071-first-20260927`
**Date**: 2026-09-28
**Roles (engaged)**: Ada

## 1. Goal

Resolve the question raised by the Lane B C++ header's claim that it was mechanically ported from an external prototype, and record accurate provenance for the historical 0.7.1 release candidate.

## 2. Implemented

Shinichi confirmed that the compiled header under audit is ours. This confirmation does not extend to every file in the Lane B directory. Inspection of the MSPL authors' supplementary `mv_MSPAL.R` showed the shared Jeffreys information penalty calculated directly as `log(det(crossprod(X * sqrt(w)))) / 2`. The package header instead implements a guarded C++ maximum-volume algorithm with exact-dyadic rank checks and multiprecision fallback. The paper repository supplies reproduction scripts, data, results, and a PDF; it is not presented as an R package. The incorrect mechanical-port wording was removed and the source comparison recorded in the rights receipt, gate ledger, and check log.

## 3. Files Changed

- `src/lane_b_jeffreys_maxvol_atomic_v8.h`
- `docs/dev-log/release/2026-09-27-071-component-rights.md`
- `.unlazy/cran-071/GATES.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-09-28-laneb-provenance.md`

`inst/COPYRIGHTS` was inspected but left unchanged because a newer unrelated provenance change exists on other refs. Its existing blanket statement covers gllvmTMB-specific code as GPL-3 by Shinichi Nakagawa.

## 3a. Decisions and Rejected Alternatives

Decision: identify the paper as the mathematical source of the Jeffreys atom, and identify this C++ implementation as original gllvmTMB code. Rationale: the inspected R function uses a direct determinant calculation; it does not implement the header's guarded maximum-volume algorithm. Rejected alternative: keep the “mechanically ported” note or treat the GPL-2-or-later R script as a copied component. Confidence: high for the inspected companion script and user-confirmed authorship; the comparison does not make a claim about unrelated, uninspected prototypes.

## 4. Checks Run

- Read the GitHub source of `Scripts/Functions/mv_MSPAL.R`. Its file header states GPL-2-or-later; `mv_penalty()` contains `log(det(crossprod(X * sqrt(w)))) / 2`.
- Read the companion repository root and README. It lists `Data/`, `Results/`, `Scripts/`, `README.md`, and `softpen_supplementary.pdf`; README describes R scripts for analysis reproduction. No `DESCRIPTION` or `NAMESPACE` is shown in the root listing.
- Inspected the Lane B header implementation and corrected only its provenance comment; no executable code changed.
- Updated the CRAN gate and component receipt. G1 remains open. No package test or R CMD check was rerun because this change only updates a C++ comment and release evidence; all prior tarballs remain predecessors.

## 5. Tests of the Tests

No test changed. The package test suite continues to cover the implementation on its previous candidate, but those results do not validate a new tarball.

## 6. Consistency Audit

- `rg -n "HOLD|external prototype|mechanically ported|rights chain is unresolved|rights, a clean" .unlazy/cran-071/GATES.md docs/dev-log/release/2026-09-27-071-component-rights.md docs/dev-log/check-log.md`; the gate and component receipt were corrected; older check-log entries remain as dated historical records and are superseded by the appended correction.
- `rg -n "Mechanically ported from the SHA-verified external prototype bundle|Guarded backend core from the frozen external R&D prototype" src/lane_b_jeffreys_maxvol_atomic_v8.h`; no matches.

## 7. Roadmap Tick

N/A. No roadmap status changed.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or changed. The provenance correction is a release gate item and requires no new issue to establish the source comparison.

## 8. What Did Not Go Smoothly

The first release receipt overstated what the header's old comment proved. The historical release worktree is outside the session's default writable roots; the gate update was completed through the approved elevated filesystem path. An attempted lane-lease write to the brain registry was denied by filesystem permissions, so the command's “GRANTED” text is not treated as a durable lease receipt.

## 9. Team Learning

Ada corrected the claim by comparing the actual paper companion code with the package implementation and retaining Shinichi's authorship confirmation as the source for authorship. Next time, treat a provenance comment as a lead to verify rather than proof of third-party code lineage.

## 10. Known Limitations And Next Actions

This resolves one rights question only. Rerun the full component and rights scan on the exact new archive, obtain fresh reviewer votes, rerun local and platform checks, and pass the submission ledger before calling the candidate ready to upload. Shinichi must perform the CRAN upload and confirmation steps himself.
