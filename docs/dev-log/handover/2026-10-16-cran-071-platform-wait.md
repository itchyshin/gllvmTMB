# Session Handoff: gllvmTMB 0.7.1 CRAN resubmission awaits platforms

Meta: 2026-10-16 07:13 UTC · Codex · external-check checkpoint

## Critical Context

The maintainer authorized reading the CRAN email in itchyshin@gmail.com, fixing
its requests and resubmitting. He then asked to just do it without a separate
plan approval. That authority persists. The corrected archive has NOT been
submitted to CRAN: exact Windows reports and three-OS CI remain unavailable.
Do not mistake source repairs or accepted Win-builder uploads for CRAN submission.

Use the historical 0.7.1 release source, not current development main. The
historical-branch exception is recorded in the September release reports.
Original main checkout and other lanes were preserved.

## What Was Accomplished

All five manual-review request categories were addressed: method return values;
registered/accessibly imported prediction generic verified; unnecessary dontrun
removed; informational diagnostics made suppressible; default/test file writes
made explicit or temporary. Newly exposed animal and phylo examples were fixed.
S3 method help metadata was made explicit. Root Rplots.pdf is excluded.

Exact archive: SHA-256
600b178631a79199d63c8568806394da2fdbfb986ef08fd3f85de960a9dc68f2,
4,428,282 bytes, 889 entries. Generating source:
e158795cd08292e6b2400912629ba409855ba955, clean at build start and freeze.
Canonical file and same-byte Windows alias are read-only in the SHA directory
under /Users/z3437171/local-scratch/gllvmTMB-cran-071-evidence/.

Full exact R CMD check --as-cran --run-donttest passed 0 errors, 0 warnings,
2 explained notes (new submission; six-second bootstrap donttest example).
Tests: 1,408 passes, 33 skips, zero failures/warnings. Vignette rebuild, compiled
code and PDF/HTML manuals passed. Independent exact-installed README/predict
smoke passed in 0.94 seconds, including no ordinary console output or workdir writes.
Grace and Pat/Rose verified final artifact identity and payload. The executable
release ledger accepts tarball-clean, not platform-clean or submission-ready.

## Current Working State

Workspace: /Users/z3437171/local-scratch/gllvmTMB-cran-071-resubmit
Branch: codex/cran-071-resubmit-20261016
Installed-source commit remains e158795cd; later commits change build-excluded
cran-comments and docs only. See git log/status for current governance HEAD.
Evidence directory: /Users/z3437171/local-scratch/gllvmTMB-cran-071-evidence/.

Both Windows services accepted same-byte alias gllvmTMB_0.7.1-600b1786.tar.gz.
Inspect final-win-upload-R-release.html and final-win-upload-R-devel.html, not
older receipts. Their file-size fields are 4,428,282 bytes. HTTP200 alone is
insufficient: one predecessor R-release upload returned an HTML ERROR.
No final result email arrived even after roughly half an hour.

Current three-OS workflow:
https://github.com/itchyshin/gllvmTMB/actions/runs/38862492778
All jobs remained queued with no assigned runners at the final check. Other
branches' runs were also queued over an hour; do not cancel their work.
Superseded runs created by this lane were cancelled before fix-up pushes.

## Key Decisions and Rationale

Keep the frozen file unchanged. No native code, family, estimator or grammar
change occurred; no new statistical validation or broad interval claim is made.
Do not shrink bootstrap examples into poorly replicated models to erase a
six-second donttest timing note. No public development-site deployment was made.

## Landing State

| State | Artifact / branch | Why / resume |
|---|---|---|
| COMMITTED + PUSHED | codex/cran-071-resubmit-20261016 | All source repairs and local-check reports are on origin. No PR/main merge: deliberate historical-release exception. Resume in the workspace above. |
| CARRIED-OVER | same branch: Windows/CI gate and CRAN upload | External results unavailable. Resume with the commands below; then resubmit the canonical exact file and complete the newest confirmation. |
| RETAINED LOCAL | immutable archive, raw logs, ledger and independent reviews | Evidence directory above; not GitHub campaign artifacts. Same-host resume can read them directly. |
| PROTECTED / OUTSIDE THIS TASK | all other local branches and worktrees | Handoff gate reports 691 unpublished commits across foreign/historical branches. They are not this release lane's work. Do not push, merge or alter them. Re-run the gate before a separately assigned lane. |

The handoff gate ran before this document and exited 1 because of those other
branches. Our own branch was clean and synchronized with origin. Shannon's
scope-bound verdict is WARN: 56 open development PRs, no release-branch PR,
external checks pending, and no claim of cross-team completion or merge order.
The after-task report and message bus are committed in this branch.

FINDINGS-OF-RECORD: none

## Resume Commands / OWED

1. Rehydrate with lane_preflight, git status/diff/log and the recovery checkpoint.
   System Git triggers an Xcode licence prompt. Prepend
   /Users/z3437171/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback
   to PATH. Compile only if needed with DEVELOPER_DIR=/Library/Developer/CommandLineTools.
   No acceptance of new Xcode terms is needed for the working compiler route.
2. Read evidence/artifact.json, CHECK-STATE.json, release-ledger.json, REQUESTS.md,
   upload-check/gllvmTMB.Rcheck/00check.log and artifact-{grace,pat-rose}.md.
   Verify SHA from the canonical path. Do not rebuild absent a real source defect.
3. `gh run view 38862492778 -R itchyshin/gllvmTMB --json status,conclusion,jobs`
   Read actual logs when complete. Do not equate queued with passing.
4. Read itchyshin Gmail through Chrome (browser3, existing Gmail tab877433982),
   searching `in:anywhere after:2026/10/15 subject:gllvmTMB`. Verify account title.
   Gmail connector is authenticated to snakagaw@ualberta.ca and cannot see this mail.
   Identify the checksum-labelled final upload, then fetch its actual Windows logs.
   Older canonical-name or other hashes are predecessor evidence only.
5. Close the exact-artifact Windows/CI/timing and independent readiness reviews;
   update cran-comments and executable release ledger honestly. Gate script:
   `python3 ~/shinichi-brain/tools/cran_release_gate.py <evidence>/release-ledger.json`.
6. Only after applicable gates pass, resubmit canonical gllvmTMB_0.7.1.tar.gz from
   artifact.json (not an alias or a fresh build), record hash/size/timestamp/ID,
   and complete only the newest maintainer confirmation. Record submitted and
   confirmed separately. CRAN acceptance/publication remain separate later rungs.
7. Update check-log, after-task, ledger and this dated checkpoint with outcomes.

## DONE / PROTECTED

Do not repeat the already completed local check, source sweeps or installed smoke
without a new change/failure. Do not move current main into this release. Do not
silently backport into development or merge other PRs. Do not modify credentials,
account budgets or runner settings to unqueue CI. No simulation campaign is owed.

## Evidence and Reports

- docs/dev-log/after-task/2026-10-16-cran-071-resubmission.md
- docs/dev-log/recovery-checkpoints/2026-10-16-0645-codex-cran-checkpoint.md
- docs/dev-log/check-log.md (2026-10-16 entries)
- cran-comments.md (still explicitly draft/pending platforms)
- Source changed-file inventory: `git diff --name-only 53ade2c64..e158795cd`.
- Raw checks, immutable files and assessment records: evidence directory above.

No CRAN upload, confirmation, acceptance, package release tag or public-site
deployment occurred in this lane. No local fit/check process remains running.
