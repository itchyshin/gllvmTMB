# After Task: restore the spatial-rho article build

## 1. Goal

Repair scheduled pkgdown run1077 (39039732147), which failed on cedf274 before the cbind integration. Preserve the article, truthful notices and existing build/check policies.

## 2. Implemented

Reuse the three commits already proposed in PR1492 in an isolated task-owned branch merged with current main927d. Both estimated spatial-rho examples name the observed location column. The existing notice correction remains silent only when the token is consumed, while default-rho notices remain. Harden nested-call cleanup to restore the previous context, and qualify help wording for an actual column named coords. No model,likelihood,formula admission,public API or native-code change.

## 3. Files Changed

Inherited from PR1492: NEWS.md,R/brms-sugar.R,R/gllvmTMB.R,three spatial Rd files,test-issue-1361-spatial-location-token.R,two articles (structured-source-strength and isdm-canada-warbler),and its historical after-task report. Additional hardening: same source/help/NEWS files plus tests/testthat/test-pkgdown-spatial-rho-context.R and this report. The old report remains historical evidence,not a claim about current-main verification.

## 3a. Decisions and Rejected Alternatives

Reuse the existing fix rather than duplicate its implementation or overwrite its owner's branch. Correct the false warning rather than silence it through chunk options. Preserve both sides of the sole NEWS merge conflict. Restore previous context rather than unconditionally clear it: a nested-call regression demonstrated three failures. Do not change check policy,skip pages,expand access or retry the unrelated denied description edit.

## 4. Checks Run

Current-main minimal repro: absent coords column raises the exact spatial-group error; valid group reaches payload setup but emits the false ignored-token notice. No optimizer entered. New nested regression against unmodified PR1492:3failures/2passes; with restoration:5passes. Roxygen8.0.0 regenerated only the three spatial help files. Focused tests (NOT_CRAN=true):303passes,0failures/errors/warnings/skips. All27chunks of structured-source-strength.Rmd rendered,including the spatial-long and spatial-wide fits. pkgdown::check_pkgdown(), all-R parsing,three tools::checkRd() calls and tools/test-check-pkgdown-public-surface.R passed. Local R4.6.0,TMB1.9.21,testthat3.3.2,pkgdown2.2.0,rmarkdown2.31. Actual complete workflow remains the gate. Commands and full logs:dev/pkgdown-1077.

## 5. Tests of the Tests

Nested public entry calls reproduce context loss on the PR code and pass with scoped restoration,including error unwinding before optimization. Existing warning regressions cover long/wide inputs,all three spatial helpers,fixed/estimated rho,direct desugaring and positive default-rho controls. Current-main old-code run of those tests:13failures/8passes, proving the warning regressions detect the old behavior. These tests do not establish article optimization or scientific parameter recovery; rendering is a separate gate.

## 6. Consistency Audit

Independent Rose/Grace review found no code blocker. Literal scans: `rg -n "always read locations|\| *coords.*rho *= *(NULL|0?\.5)" R/brms-sugar.R man/spatial_*.Rd vignettes/articles/structured-source-strength.Rmd vignettes/articles/isdm-canada-warbler.Rmd` found no remaining affected claim/example. The internal comment and warning body qualify the default-rho case. Preserve all scientific scope caveats and six-by-three keyword grammar. Help must permit coords when it really names an observed location-ID column.

## 7. Roadmap Tick

N/A: repairs an existing documented example and notice,no new capability.

## 8. What Did Not Go Smoothly

The existing fix was unmerged and18commits behind main; its historical tests did not prove the current build. NEWS had a merge conflict,with both contributions retained. Local compiler discovery remains blocked by the Xcode license; only the unchanged prebuilt native DLL is used for bounded local probes,while CI performs fresh compilation. No license acceptance/bypass. Shared check-log.md is touched by several protected open PRs; no shared-log edit or third-party coordination message was made. This unique report records the work while integration ownership is reconciled.

## 9. Team Learning

Grace/Rose read-only review found the actual parser/example mismatch and two small hardening issues; both are addressed and current verification is being gathered. No external agent was contacted. Shannon census preserved all other branches and edits; no owner branch was pushed.

## 10. Known Limitations and Next Actions

The actual complete pkgdown workflow is BLOCKED: auto-review denied the push of codex/pkgdown-1077-verify to itchyshin/gllvmTMB, because explicit human authorization to publish a branch/create a PR was not established. The exec was rejected before starting; no push ran, no PR was created and no workflow was dispatched. No alternate route or retry was attempted. Focused current-main integration regressions and independent review passed. Explicit publication approval is required before the denied operation can be retried. A branch build does not publish the live site; integration and a successful main deployment remain separate gates. No prior merge-everything authorization is assumed for unrelated work. No release,issue closure,third-party contact,security-setting change or denied-description retry.
