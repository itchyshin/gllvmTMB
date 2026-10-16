# CRAN 0.7.1 resubmission checkpoint

User authorized: read itchyshin@gmail.com CRAN Oct15 email, fix requests and resubmit; then explicitly asked to just do it without separate planning approval.

Workspace /Users/z3437171/local-scratch/gllvmTMB-cran-071-resubmit.
Branch codex/cran-071-resubmit-20261016. Source HEAD e158795cd (pushed).
Original workspace main untouched (189 behind origin/main, many active lanes).
Evidence /Users/z3437171/local-scratch/gllvmTMB-cran-071-evidence/.
System Git blocked by Xcode license; use /Users/z3437171/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/fallback/git.
Compile with DEVELOPER_DIR=/Library/Developer/CommandLineTools and single BLAS threads.

Completed: return docs, all unnecessary dontrun removed except external Julia;
undefined placeholder blocks labelled reference templates; animal grouping and
phylo labels repaired; sanity output suppressible; temp developer writes;
explicit roots for five shipped shell scripts; Rplots.pdf excluded; S3 help
markup explicit. Focused tests, 64 topics' example execution, source review,
artifact rights review and installed README/predict smoke passed at their named
source/artifact scopes. No likelihood or grammar changes.

Predecessors:
242183... archive had Rplots.pdf; retired. Windows release+devel uploaded.
d4ba4064... removed PDF; local full check 0E/0W/3NOTEs (newsubmission,
method markup, bootstrap timing). 1408PASS/33SKIP/0FAIL/0WARN tests. Windows
R-devel uploaded; release denied while prior filename queued. All predecessor
artifacts retained, not upload candidates.

Current: clean source at e158795cd is building upload candidate in upload-build.log.
R CMD build session31481. Earlier stable-build started before one roxygen staging
omission was committed, so not frozen; clean rebuild deliberately rerun.
Final candidate must be frozen, hash/inventory recorded, and checked with
R CMD check --as-cran --run-donttest (manual+vignette included, no forceSuggestsfalse).
Need Windows release/devel results for exact file, threeOS CI38862492778 (queued;
other branches queued over1h), refreshed artifact Grace and Pat/Rose reviews,
release ledger, updated cran-comments, then CRAN upload and newest confirmation.
Never claim submitted/confirmed/accepted without receipts.

Gmail connector is wrong account snakagaw@ualberta.ca. Use browser3 tab877433982,
mail.google.com/mail/u/0 itchyshin account, via cua_repl. CRAN email URL
https://mail.google.com/mail/u/0/#all/FMfcgzQhWfXrZjDzbnrdkfCRpnmfdqbf.
Windows search after:2026/10/15 subject:gllvmTMB currently only CRAN Oct15 email.

Next safest action: finish upload-build; freeze from clean source; run exact
check and upload to Windows (inspect HTML for ERROR, HTTP200 alone insufficient).
No CRAN upload yet. No simulation campaign. No branch merge/PR/site deploy.

## Local-check milestone update

Final archive SHA600b178631a79199d63c8568806394da2fdbfb986ef08fd3f85de960a9dc68f2,
4,428,282bytes,889entries, sourcee158795cd08292e6b2400912629ba409855ba955.
Canonical path is in evidence/artifact.json. Source at build start and freeze was
clean; this checkpoint and subsequent governance edits are build-excluded.
Immutable canonical and alias files chmod444.

Exact full upload-check/gllvmTMB.Rcheck/00check.log:0E/0W/2NOTEs
(newsubmission,extract_correlations6.016sec donttest).Tests1408pass/33skip/0fail/0warn.
Examples,vignette rebuild,PDF+HTML manuals,compiled-code checks all pass.
Exact-installed independent Pat/Rose smoke passes in0.94sec, no files written,
270finite correct predictions,accessors and covariance extraction pass.
Grace final archive delta review finds no source/rights blocker.
Release-ledger.json mechanically accepts tarball-clean; platform-clean and
submission-ready remain pending. Gate selftests pass.

Both Windows services accepted an identical-byte alias named
gllvmTMB_0.7.1-600b1786.tar.gz; receipt final-win-upload*.html/log.
Prior canonical-name uploads conflicted; they are predecessor results only.
Await result emails in itchyshin Gmail; none returned at latest refresh.
CI final source run38862492778 remains queued/no assigned runners (three OS).
Other repo lanes' runs queued over1h; do not cancel others' jobs.
No CRAN upload/confirmation yet. No more source edits planned.
