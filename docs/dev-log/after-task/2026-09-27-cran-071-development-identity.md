# After Task: Development source identity after the 0.7.1 freeze

**Branch**: `codex/cran-071-dev-identity-20260927`  
**PR**: #1325  
**Date**: 2026-09-27  
**Reader**: the maintainer checking what the development site and CRAN candidate represent.

## 1. Goal

Identify the continuing development source as `0.8.0.9000` while keeping the planned first CRAN submission tied to the earlier, bounded `0.7.1` source. The site banner makes this distinction visible to readers.

## 2. Implemented

Commit `907a32844` changes the package version, the README citation version, and the pkgdown status and release comments. Commit `f2bb74fcc` makes the site banner explicitly say **Experimental development documentation for 0.8.0.9000**. The banner points readers to current limitations and tells them that convergence alone does not establish reliability for every extension. The changed pkgdown navbar labels use plain punctuation; they do not add or remove pages.

### Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, or vignette changed. This is a source and documentation identity change, with wording changes to existing pkgdown navigation labels.

## 3a. Decisions and Rejected Alternatives

The development branch uses `0.8.0.9000` to keep it distinct from the frozen `0.7.1` candidate. The site describes the newer development source as experimental. This avoids presenting the current branch or development site as the exact source proposed for CRAN.

## 4. Files Touched

- `DESCRIPTION`: version `0.7.1` to `0.8.0.9000`.
- `README.md`: package version in the citation text.
- `_pkgdown.yml`: experimental development banner, two navbar labels, and comments on the unreleased development site and planned `0.7.1` submission.
- `docs/dev-log/after-task/2026-09-27-cran-071-development-identity.md`: this report, to be added before closeout.

No example, `NEWS.md`, `ROADMAP.md`, design document, vignette, or generated `man/*.Rd` file changed in the two implementation commits.

## 5. Checks Run

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed, reporting `✔ No problems found.`
- `Rscript --vanilla -e 'pkgdown::build_home(quiet = TRUE)'`: exit 0. The generated `pkgdown-site/index.html` visibly says **Experimental development documentation for 0.8.0.9000** and identifies the planned CRAN source as the earlier bounded `0.7.1`. The generated site directory is ignored by Git.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/current-limits", quiet = TRUE)'`: exit 0. The homepage's `articles/current-limits.html` link resolves to a rendered page titled **Current limitations and boundaries**. An initial call using `"current-limits"` failed because pkgdown requires the `articles/` prefix for this article; it did not change source.
- `Rscript --vanilla -e 'source("/Users/z3437171/shinichi-brain/tools/check-after-task.R"); check_after_task("docs/dev-log/after-task/2026-09-27-cran-071-development-identity.md")'`: exit 0 for this report's required structure. The full `check-after-task.R` CLI printed `after-task structure check passed` but exited 1 because three other development ledgers have unmet gates: `ijsdm-response-information-forensics`, `ijsdm-response-information`, and `temporal-ar1`. It did not reject this report's structure and does not establish that those other arcs are complete.
- YAML parsing of `_pkgdown.yml`: passed. The exact parser command was not retained in this report's evidence.
- `git diff 9539352f6..HEAD --check`: passed with no output on the two implementation commits.
- Initial PR head `907a32844`: GitHub Actions run `36346565194` completed successfully, with all four Ubuntu release shards green.
- Implementation head `f2bb74fcca303e3c7a5d501c1ff996ee2558b28d`: GitHub Actions run `36349026685` completed successfully, with all four Ubuntu release shards green. That run verifies the visible banner edit. The report-only commit will create a new PR head whose checks must be inspected before merge.
- No local `R CMD check` was run for this PR.

## 6. Tests of the Tests

No test code or model behavior changed. No new test required a failure-before-fix, boundary, or feature-combination check. All four checks passed for the implementation head; the report-only commit still needs its own PR check result.

## 7a. Issue Ledger

No issue was inspected, commented on, closed, or created for this identity-only PR. The issue tracker was not checked for a relevant open issue, so this report does not claim that none exists.

## 8. Consistency Audit

- `rg -n '0\.7\.1|0\.8\.0\.9000|first CRAN|0\.6\.0|Experimental' DESCRIPTION README.md _pkgdown.yml`: found `0.8.0.9000` in `DESCRIPTION`, README citation, and pkgdown banner/comments. The banner and comments identify the earlier `0.7.1` source as the planned CRAN candidate. README still calls the software experimental. The only `0.6.0` occurrence in these files was removed from the pkgdown comments by the implementation diff.
- `git diff --name-only 9539352f6..HEAD`: returned exactly `DESCRIPTION`, `README.md`, and `_pkgdown.yml` before this report was added. This supports the narrow file inventory above; it is not a repository-wide prose audit.
- `git diff 9539352f6..HEAD --check`: no whitespace errors on the two implementation commits.

No model keyword, example, or citation convention changed, so the formula and roxygen example cascade does not apply. The locally rendered homepage has been inspected; the deployed site has not been verified.

## 9. What Did Not Go Smoothly

The first successful CI run covered `907a32844`; the subsequent banner edit required a fresh run, which spent over an hour partly queued before all four shards passed. The locally rendered homepage shows the banner, but the public site has not been checked after deployment. The highest verified status is implementation-head CI and local rendering passed, with report-commit CI and deployment pending.

## 10. Known Residuals

Check the PR run created by this report-only commit before merge. After pkgdown deployment, inspect the live banner and version distinction. Keep the frozen `0.7.1` CRAN artifact and the `0.8.0.9000` development source separate in any release claim. This PR does not establish CRAN submission, external acceptance, or a new model capability.

## 11. Team Learning

**Ada:** The release and development sources need separate names in both package metadata and reader-facing site text. The two commits keep the CRAN candidate at the earlier bounded source while the working branch moves ahead. At closeout, check the final commit and CI head together.

**Grace:** The local pkgdown check and YAML parse cover configuration validity. All four Ubuntu shards passed for `f2bb74fcc`. Check the report-only PR head and inspect the published banner after deployment before making the final site claim.

**Rose:** The file inventory and targeted version search found the intended three-file identity change. The next audit should compare the final rendered site with this source and confirm that older release wording has not reappeared.

## 12. Cross-Product Coverage

N/A. No `ROADMAP.md` row changed in this PR.

No model contract or design document changed. `_pkgdown.yml` now displays the development status and planned CRAN source in the site banner. The two changed navbar labels retain their existing article links. The locally rendered homepage confirms the banner; the public deployment remains unverified.

This PR does NOT cover model behavior, simulation recovery, R API examples, generated help, the frozen `0.7.1` CRAN artifact, CRAN submission, or the deployed pkgdown site. No `ROADMAP.md` row changed.
