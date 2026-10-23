# 0.7.1 Codex-only trust-release ultra-plan

## Goal

```text
Solo platform: Codex
Deliverable: an exact-byte gllvmTMB 0.7.1 release candidate with retained source,
tarball, cross-platform, and reader-surface evidence.
HEADLINE: earn trust through three narrow closures, then prove one frozen artifact.
IN PARALLEL: Codex read-only reviews and mechanical verification only; production
changes and integration are serial.
DEFER: MSPL expansion; calibration/coverage; iSDM expansion; broad predict(newdata=);
new public random-slope claims; tags; CRAN upload; release announcement.
DISCIPLINE: candidate hash controls all evidence; no old receipt is reused; one
candidate push at a time; done means validated RC, not submitted.
```

## Approval and operating boundary

Shinichi approved this plan on 2026-08-24 for the isolated worktree
`/private/tmp/gllvmtmb-0701-trust-release`, branch
`codex/0701-trust-release`, initially based on
`a94a156fa2522319ba7ab3625648109300128ecc`. Codex is the sole platform and
integrator for this week. The older random-slope handover and all other active
worktrees are protected and excluded.

The approval covers bounded edits, commits, a release pull request, matching
CI, merge, a manual full-matrix CI dispatch, and within-scope repairs. It does
not cover deferred work, a tag, CRAN submission, publication, or an announcement.
Each mutation arc begins with `lane_preflight` and a path lease; a refused
lease stops the arc.

## Public contract

| Issue | Allowed closure | Explicitly excluded |
| --- | --- | --- |
| #1190 | Warn when a supplied `unit_obs` or `cluster` argument is unused by every covariance keyword. | New covariance/random-effect capability; likelihood or parameter changes. |
| #1194 | Keep `extract_Sigma_B()` and `extract_Sigma_W()` exported as soft-deprecated compatibility wrappers with a visible migration path. | Removal, rename, semantic change, or package-wide vocabulary rewrite. |
| #1189 | State a conservative VA boundary: Laplace default, VA opt-in and uncalibrated. | Promoting VA/MSPL, standard errors, confidence intervals, or a default estimator. |

Existing random-slope documentation is retained. New 0.7.1 prose must not
imply broad recovery, interval calibration, source-tier support, or family-wide
admission. Existing MSPL material is likewise retained as opt-in experimental
documentation; no new 0.7.1 prose expands or promotes it.
Candidate evidence may be described only as `source-clean`, `tarball-clean`,
and `platform-clean` once the exact gates pass; it is never CRAN-ready,
submitted, accepted, or released.

## Arc and acceptance sequence

1. Record issue contracts, claim fences, active-lane state, and leases.
2. Implement and test #1190's supplied-and-unused warning, including consumed,
   both-slot, `NULL`, long, and wide acceptance cases.
3. Close #1194 with matching runtime warning, help, migration teaching, and
   silent internal compatibility use.
4. Add the #1189 documentation fence without changing VA/MSPL machinery.
5. Integrate one candidate with regenerated documentation, scope scans,
   check-log, and ledger updates.
6. From an empty candidate worktree, retain the source SHA, tarball SHA-256,
   size, inventory, forbidden-path scan, installed-artifact evidence, and
   local check logs. Any source-byte change restarts this gate.
7. Dispatch and inspect the manual macOS/Ubuntu/Windows matrix and
   candidate-aligned pkgdown evidence for that frozen SHA. Do not push while
   either is in progress.
8. Obtain fresh Rose, Grace, and Pat verdicts; two NOT-READY votes withhold the
   candidate. Then retain the completion receipt and after-task report, stating
   explicitly that no CRAN submission occurred.

## Repair and stop policy

A failed local check, tarball, inventory, platform matrix, pkgdown gate, or
candidate-aligned review allows a within-scope repair and a complete rerun of
all invalidated candidate gates. The plan pauses for a new decision if a lease
is refused, a direct-to-main change overlaps a planned file, #1190 needs a
likelihood/parameter change, #1194 needs removal or semantic change, #1189
needs new empirical VA/MSPL work, the source changes after claim-bearing
evidence, or a review identifies a claim outside this contract.

## 2026-08-24 fence amendment

Shinichi resolved the reader-surface gate after the initial sweep: retain the
existing MSPL and random-slope reader surfaces. The 0.7.1 fence applies only
to new 0.7.1 release prose. MSPL remains explicitly opt-in experimental and
outside this release's feature scope; existing random-slope documentation is
not recast as a new candidate claim.
