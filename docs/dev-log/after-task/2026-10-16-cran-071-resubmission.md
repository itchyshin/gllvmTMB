# gllvmTMB 0.7.1 CRAN review repairs

## 1. Goal
Address the five requests in Konstanze Lauseker's 15 October 2026 email and resubmit one checked 0.7.1 archive. The exact archive has passed local and three-platform checks. Windows R-devel reports an unexplained file NOTE, disclosed in the submission comments. Fresh independent review and the executable ledger passed; resubmission remains pending. No CRAN upload is claimed.

## 2. Implemented
Added shared accessor return documentation; replaced unnecessary dontrun blocks; labelled incomplete reference syntax as templates; corrected animal-example unit metadata; made sanity diagnostics suppressible; moved developer-test output into temporary fixtures; required explicit output destinations in five shipped simulation launch scripts.

## 3a. Decisions and Rejected Alternatives
Retained the historical 0.7.1 release branch rather than incorporating development main. Prediction methods are already registered with stats::predict; generic re-export is unnecessary. Retained the Julia example's external-software exception. No likelihood, parameterisation, formula grammar or capability extension is intended.

## 4. Files Touched
The source commit's full changed-file inventory is authoritative. R roxygen changes and generated man pages are paired. Console behavior changes are confined to sanity_multi and its quiet diagnostic wrapper. File-writing changes affect developer test fixtures and five inst/sim/lane-b shell scripts. No README, root vignette, article, DESCRIPTION, public site or validation-debt claim was changed. Example changes span animal-keyword, bootstrap-sigma, brms-sugar, check-consistency, confint-inspect, coverage-study, diagnose, extract-correlations, extract-cutpoints, extract-omega, extract-repeatability, extract-sigma-table, extract-sigma, extract-two-psi-cross-check, extractors, families, gllvmTMB, isdm-sources, kernel-keywords, loading-ci, loading-profile, output-methods, plot-loadings-confidence-eye, profile-targets, re-uncertainty, ridge-path, rotate-loadings, slope-sd-ci, spde-keyword, standard-errors, suggest-lambda-constraint, traits-keyword, unique-keyword, vcov-coef and z-confint-gllvmTMB. Remaining example blocks were inspected for undefined placeholders; the Julia external-software example remains dontrun.

## 5. Checks Run
Focused sanity-messages, sanity-multi and diagnose tests pass. pkgdown::check_pkgdown reports no problems. All Rd files and 64 extracted example scripts parse. Six animal examples execute successfully. File-write worker reports BFGS, G2d, G2e and G2f tests pass, plus MSPL simulation-contract tests with one conditional skip. Shell bash -n and missing-variable failure checks pass. The predecessor600b exact tarball check passed with 0 errors, 0 warnings and 2 explained notes; its test subset passed 1,408 assertions with 33 skips and no failures or warnings. Vignette rebuild and both manual formats passed. Fresh-candidate Windows and three-OS CI results are recorded in the current platform update below. Evidence lives in /Users/z3437171/local-scratch/gllvmTMB-cran-071-evidence/.

Stale/default scans: rg 'saveRDS|save\(|write[.(_]|dir.create|sink\(|pdf\(|png\(' R; rg 'write|save|dir.create|setwd|path.expand|~/' tests vignettes R; rg '\\dontrun' man; rg 'predict' man/gllvmTMB.Rd man/slope_sd_ci.Rd NAMESPACE. No new simulation campaign was run. Source-gate checks do not certify a later archive.

## 6. Tests of the Tests
The new diagnostic test verifies message delivery, suppression, empty stdout and unchanged flags. Required shell variables fail before writing when unset. Temporary-package fixtures preserve developer runners' path/provenance contracts instead of disabling those checks.

## 7a. Issue Ledger
The external CRAN email is the request ledger. Five requested categories are tracked in the evidence REQUESTS.md. No issue was closed and no reply sent.

## 8. Consistency Audit
Independent Rose/Emmy source review found no P0/P1 blocker in the return documentation, labelled templates and console changes. Separate Grace and Pat/Rose reviews verified the final archive identity, payload and installed workflow. Fresh independent Grace, Rose and Pat reviews each voted READY on the exact archive after platform evidence was retained. The release remains experimental and historical-source scoped.

## 9. What Did Not Go Smoothly
The Gmail connector points to snakagaw@ualberta.ca; the email was found in the existing itchyshin@gmail.com browser tab. System Git triggers an unaccepted Xcode licence; a bundled Git works. Native worktree creation failed for the same reason, so a separate fallback-Git worktree was created. Setting DEVELOPER_DIR to CommandLineTools permits compilation without accepting new licence terms. Initial diagnostic archives precede later example repairs and are not submission files.

## 10. Known Residuals
CRAN upload and confirmation remain pending; final panel and submission-ready ledger have passed. The current Windows R-devel file NOTE remains unexplained; no source defect was established. No CRAN acceptance or publication is claimed. Broad interval coverage and later development features remain outside scope.

## 11. Team Learning
Converting dontrun to donttest reveals broken examples; parse checks alone cannot establish runnable examples. A file-write audit must include shipped shell launchers and developer tests, even when package runtime already uses tempdir.

## 12. Cross-Product Coverage
This task covers the R gllvmTMB 0.7.1 CRAN maintenance candidate only. It does NOT cover Julia implementation or parity, later development features, new statistical validation, a main-branch integration, or public-site deployment.

## Predecessor candidate update (07:13 UTC)

Previous source e158795cd08292e6b2400912629ba409855ba955 produced archive
600b178631a79199d63c8568806394da2fdbfb986ef08fd3f85de960a9dc68f2,
4,428,282 bytes and 889 entries. Clean status was captured before the build and
at freeze. The archive contains no Rplots.pdf or development/checkpoint folders.
The full exact check passed 0 errors, 0 warnings and 2 explained notes
(new submission and a six-second donttest bootstrap example). Tests:
1,408 passes, 33 skips, 0 failures and 0 warnings. Vignette rebuild and PDF/HTML
manuals passed. The executable release ledger accepts tarball-clean only;
platform-clean and submission-ready remain unproven. Both Windows services
accepted an identical-byte checksum-labelled alias. CI run 38862492778 remains
queued. CRAN upload and confirmation have not occurred.

Neighbour fixes: five phylo examples now match tree tips to simulated species;
11 print/summary methods have explicit S3 documentation metadata. A source
example sweep created root Rplots.pdf; Grace caught its inclusion in the first
archive, which was retired. A new Rbuildignore rule prevents recurrence.

Remaining done-contract items are deliberately not claimed: the release uses
the recorded historical-source exception rather than merging later main;
three-OS checks and exact Windows evidence are pending. No new likelihood,
family, keyword or estimator was added, so simulation recovery/likelihood review
is not applicable. Curie's new-model recovery sign-off is not implied by these
maintenance tests. No article was changed; every runnable help example was exercised by the source sweep or full exact
run-donttest check; template-only blocks were parsed as Rd. Public
pkgdown remains the separate development site.

## Full-CI correction after resume

The candidate600b archive is now a predecessor, not the submission file. Its
local CRAN-selected check passed as recorded above, but the broader macOS source
CI found one stale stdout assertion in test-mspl-api.R360 after sanity_multi()
was changed to message(). Focused reproduction produced1failure/54passes.
The MSPL assertion and integration-tour capture now use type="message";
focused verification produced82passes and0failures/0warnings/0skips. Existing
suppression checks cover empty stdout and unchanged diagnostic flags.

Windows reports for600b were0E/0W/1NOTE on R-release and0E/0W/2NOTEs on
R-devel. The extra devel note names rootRplots.pdf, absent from the archive;
a same-byte rerun is pending to investigate possible server residue. Both
vignette rebuilds took21seconds; full check times were513/566seconds, retained
as a conservative timing risk. The superseded CI run was cancelled after the
macOS failure. Fresh archive/platform/panel evidence is required after the
included test correction. No CRAN resubmission or confirmation has occurred.

The user requested Codex's own browser. It works, is signed in to itchyshin
Gmail, and reaches the CRAN form; a Mac unlock is no longer needed for this route.
Automatic continuation remains active during the maintainer's absence.


## Fresh candidate update (10:55 UTC)

Clean source876b4fab7a50404ce2765e8924f69b5085e2d0c4 produced immutable archive
dd8a811fbc273774db44b3284ca7cac7b724da5539c5fafebc14fcac0a2df557,
4428330bytes and889entries. Payload comparison found only the two test changes
and R's Packaged timestamp; runtime code/help/data/native source are unchanged.
The exact as-cran/run-donttest check passed0errors/0warnings/2explainednotes,
1408passedassertions/33skips/0failures/0warnings, rebuilt vignette and both manuals.
The exact installed workflow passed270predictions, convergence0 and no workdir
writes. Its existing latent-default transition warning was retained.

Both Windows services accepted the checksum-labelled dd8a811f alias. Their
reports and full3OSCI38889563471 are pending. Current highest proven rung is
therefore tarball-clean. Independent final panel, submission and confirmation
remain owed; no CRAN upload or acceptance is claimed. Automatic continuation
uses the latest evidence state JSON and the working in-app browser.

## Current platform update and diagnostic closeout

Source876b passed full three-OS CI38889563471: each R CMD check returned Status: OK.
Ubuntu had14,939passes/1,113skips/13testwarnings; Windows14,939/1,113/12;
macOS14,938/1,114/12. No failures occurred. Actual logs and warning details are
retained in recheck2-ci-completed-results.json and recheck2-ci-*-job.log.
These source checks are distinct from exact-archive CRAN-mode results.

Exact dd8a Win-builder R-release QicMZ3125JJ1 reported0errors/0warnings/1NOTE
(new submission), check318s/install188s/vignette13s. R-devel647fw01UDi6L reported
0errors/0warnings/2NOTEs (new submission and rootRplots.pdf), check340s/install168s/
vignette13s. Both had1,408passes/33skips/0failures/0warnings. The archive contains
no Rplots.pdf. Its absence is established; the service discrepancy is unexplained.
The covering comments disclose it without alleging service contamination.

Isolated Windows R-devel diagnostic38916443924 stopped with HTTP403 while
fetching its pinned draft asset, before R setup, installation or package checking.
It supplies no package-check result. Its complete log and terminal receipt are
retained; no diagnostic artifacts were created. No permissions were broadened,
no replacement source build was used, and no blind check was dispatched.
Original workflow bytes from876b were restored and pushed in8cb5570e4.
The temporary unpublished release414918132 was deleted after its receipt was
saved; GET now returns404, and no diagnostic tag ref exists. Source and immutable
archive remain unchanged by all diagnostic/governance commits.

Fresh independent Grace/Rose/Pat reviews each voted READY. The historical-source
exception remains; no later main-branch work, new estimator, Julia parity, new
sanitizer result, broad coverage or live CRAN state is claimed. The executable ledger passed submission-ready; submission and confirmation remain owed.

## Final submission gate

Fresh Grace, Rose and Pat each independently recomputed dd8a identity and voted
READY within their remit. Parent-saved reports final-panel-{grace,rose,pat}.md
and final-panel.json retain the findings. The executable release ledger passed
submission-ready; its selftest rejected all planted incomplete-release controls.
Comments disclose new-submission, six-second bootstrap and unexplained devel
Rplots NOTEs. No new source or archive change is required.

Grace adjudicated the full-CI test warnings: six penalized-logLik notices,
two comparator allzero-row notices, one degenerate multinomial covariance,
one unused unit_obs in a rejection test, two deprecated extractor calls, plus
one Ubuntu runaway binomial loading. These are not collectively healthy fits
or expected warnings; the unhealthy fits remain statistical limitations. Every
affected file is outside ordinary CRAN test selection, and exact CRAN tests had
zero warnings. No maintenance regression requiring an archive change was found.

Windows install output includes1,117Eigen ignored-attributes warnings and one
Boost maybe-uninitialized warning per service; local install has three Eigen
unused-variable warnings. Static initialization supports a compiler/template
interpretation for Boost, not a memory-safety proof. Installation is not described
as warning-free. Current load/foreign-call/compiled checks and exercised TMB fits
supply proportional compiled-boundary evidence; no sanitizer/valgrind pass is
claimed. fmesher imports sf transitively, so sf installation is not optional even
though listed in Suggests. No new load-time regression was established.

Rose's governance requests were closed: speculative 'spurious' wording removed;
rights dispositions reconciled to exact archive; request/artifact/ledger status
updated; original workflow restoration and unpublished fixture cleanup verified.
Pat found no blocking reader confusion; future fixed-effects-only prediction
wording and an extra biological interpretation sentence are nonblocking polish.
No new feature or article work was started. Upload and confirmation are next;
acceptance, scheduling and live CRAN publication remain unproven.
