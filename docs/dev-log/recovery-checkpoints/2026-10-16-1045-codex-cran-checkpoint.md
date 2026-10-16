# CRAN 0.7.1 continuation: stale full-CI assertion

User authorization remains active: fix CRAN requests, resubmit, confirm, and
continue while the maintainer is away. No corrected CRAN upload has occurred.

Workspace: /Users/z3437171/local-scratch/gllvmTMB-cran-071-resubmit
Branch: codex/cran-071-resubmit-20261016
Governance HEAD at intake: cef00ce83. Source for candidate600b: e158795cd.
Git status was clean before this checkpoint and the worker's test correction.
Use bundled fallback Git; system Git is blocked by the Xcode licence.

Codex in-app browser (iab) works and is signed in to itchyshin@gmail.com,
despite the locked Mac and blocked Chrome-extension route. Tabs1(mail),2(CRAN
form),3(Windows upload receipt),4(CI) were marked for handoff. Use iab from now on.

Candidate600b1786 Windows reports arrived. R-release result GQ8KTa7O0QrF:
0errors/0warnings/1NOTE(new submission), check513s/install282s/vignette21s.
R-devel result YBOILF4lQ1I4: 0errors/0warnings/2NOTEs(newsubmission and root
Rplots.pdf), check566s/install273s/vignette21s. The exact archive has no PDF.
Grace traced R-devel's source-directory snapshot to before installation or
examples; server residue is plausible, not proven. Same bytes uploaded again
to R-devel as gllvmTMB_0.7.1-600b1786-r2.tar.gz at about10:37UTC, with receipt
4428282bytes/noERROR. That rerun is now diagnostic predecessor evidence because
the included test needs correction below. Keep all old logs and archives.

CI38862492778 macOS completed with1ERROR: test-mspl-api.R360 still captures
stdout from sanity_multi(), which the authorized repair changed to message().
14937PASS/1114SKIP/13WARN/1FAIL. Full log is evidence/ci-macos-job.log.
The test is included in the archive but skipped in its CRAN-selected subset.
The earlier local0E/0W check remains true for that subset; it did not establish
that this full-source assertion passed. Worker cran_console owns focused
reproduction and test-only correction, with related capture sites audited.
No product/likelihood/grammar repair is currently indicated.

Parent cancelled only this superseded CI run, preserving all foreign runs.
Do not push a fix until that run is terminal. Parent owns release records;
worker owns test assertions. New source archive must be built after committing
the included test change; old hash/platform evidence must not be reassigned.

Next: verify worker's focused reproduction/fix, commit scoped tests+records,
build from a clean commit, freeze/hash/inventory a fresh candidate, run exact
as-cran/run-donttest check, send fresh Windows checks, run full3OSCI at that
source, close independent panel/ledger/comments, then submit and confirm.
Automatic continuation complete-gllvmtmb-0-7-1-resubmission remains active.

No pending local fit/check process is owned by the parent at this checkpoint.
The worker may have a bounded focused test running; obtain its exact result.
No main merge, release tag, public-site deployment, or foreign-lane edit is owed.
