## 1. Goal

Keep the effective unpenalised ordinary-Laplace loading default, record the completed 24,000-fit comparison, and explain when to try loading_ridge = 2 with recovery and coverage trade-offs.

## 2. Implemented

The README links to a new sensitivity section in the existing fit-diagnostics article. It recommends a separate ridge-2 fit for extreme or unstable ordinary between-unit loadings, describes what the Gaussian prior penalises, and explains why a healthy penalised Hessian is insufficient. The article reports the four-scale availability counts, paired recovery example, separate positive/zero-effect coverage, Monte Carlo uncertainty and persistent Poisson undercoverage. Long and wide calls fit the same example and print their covariance difference. A portable aggregate/method record, decision entry and EXT-31 addendum retain the evidence without promoting general calibration. No package source, formal default or runtime behaviour changed.

## 3a. Decisions and Rejected Alternatives

Shinichi explicitly chose to retain effective Inf after the completed study. The formal loading_ridge = NULL and separate AGHQ default 2 stay unchanged. Ridge 2 is a sensitivity choice with a scientific loading prior, not an automatic Hessian repair. Do not select a prior scale solely on positive-definite curvature, pool target-specific coverage, or hide unavailable intervals. No additional campaign, source implementation, release or external reply was needed.

## 4. Files Touched

Reader-facing example files: README.md and vignettes/articles/fit-diagnostics.Rmd only. R/gllvmTMB.R, man/gllvmTMBcontrol.Rd, NAMESPACE, NEWS.md, _pkgdown.yml and other articles were verified unchanged. Internal records: docs/dev-log/decisions.md, the EXT-31 row in docs/design/35-validation-debt-register.md, docs/dev-log/research/2026-10-18-loading-ridge-comparison/ and this report. The research directory retains all six aggregate CSV/JSON outputs, the 6,000-task manifest, six original runner/analysis scripts, availability and supervisor receipts, hashes, provenance, verification and final article-render log. Raw RDSs and the full CSV archive remain at their documented original paths.

## 5. Checks Run

Copied evidence matched the completed campaign byte for byte; all 24,000 attempts and 144,000 effect rows are represented, 500 datasets per cell/scale. pkgdown::check_pkgdown() passed. The changed article rendered with lazy = FALSE and executed all five small fits. Its long/wide ridge covariance difference printed 0. The rendered anchor matches the README link. git diff --check passed; no R/src/man changes exist. Constructor readback confirms the unchanged defaults. The independent statistical and Rose review passed. Exact commands and limits are in the research verification.md.

The original campaign's complete raw-fit audit remains 24,000/24,000 pairs passing 17 checks, including 18,000 finite-ridge provenance/negative controls. Those fits were not repeated for this documentation task. Full package tests, new recovery tests and three-OS CI are not applicable to this no-runtime-change slice. Roxygen was not regenerated because no roxygen or function signature changed; the current control help already matches the described semantics.

## 6. Tests of the Tests

The numerical record preserves failed/unavailable denominators and paired Monte Carlo uncertainty. Original deliberate row-order, truth and curvature-metadata controls are retained through the frozen methods and audit receipts. Empty-vector covariance comparisons are explicitly rejected in the saved audit. This slice checked copied-file hashes and final HTML anchor/code outputs rather than adding a test that merely mirrors prose.

## 7a. Issue Ledger

No GitHub issue, PR comment, push or merge. Public documentation remains a local reviewed change on codex/ridge-default-guidance-20261018. The active control-help source in PR 1567 and shared check-log in PR 1561 were left untouched; this slice records its checks in its new isolated research record. No existing lane or untracked material in the primary checkout changed.

## 8. Consistency Audit

Independent statistical and narrow Rose perspectives checked all new public numerical claims against the retained CSVs, the formal NULL/effective Inf distinction, separate AGHQ controls, scope and MAP/credible-interval qualifications. Positive and zero targets stay separate. EXT-31 remains partial, and the existing MSPL-05 status is unchanged because this comparison did not compare MSPL. No likelihood, formula grammar, new export, default, family or covariance convention changed, so Gauss/Boole source reviews and convention-wide example regeneration were not needed.

## 9. What Did Not Go Smoothly

The initial render used fit-diagnostics rather than articles/fit-diagnostics; correcting the nested pkgdown name produced a successful final render. Existing Pandoc math deprecation notices remain. The optional brain reranker could not access its sandboxed configuration; retained repo evidence supplied the factual basis. The protected control-help source was excluded from edits after the PR overlap check. No substantive numerical or model error was found in this documentation slice.

## 10. Known Residuals

The study covers the specified fixed-truth, predictor-informed rank-two native-Laplace cells only. Some nominal 95% intervals still under-cover, and ridge 2 had 66 unavailable fits versus 64 with Inf. Available finite intervals and all-attempt covered fractions are distinct. The documentation is rendered locally, not deployed; no release or whole-package/platform readiness is claimed. Existing local gllvmTMB 0.7.1 supplied article execution rather than a fresh compilation.

## 11. Team Learning

Reused the completed evidence and binary provenance rather than rerunning simulations. A bounded independent reviewer checked statistical wording and Rose consistency. The existing source help was already accurate enough to leave the active PR untouched. The new durable decision is recorded in the repo decisions log; no canonical brain memory file was edited. Prose assessment records cover the exact saved drafts.

## 12. Cross-Product Coverage

Covers README guidance, the existing diagnostics article, paired long/wide sensitivity examples, the effective ordinary-Laplace default decision, retained current-engine aggregate evidence and EXT-31 traceability.

Does NOT cover a default change, new likelihood/estimator, general Hessian repair, general 95% coverage, covariance or latent-score intervals, arbitrary ranks/families, intercept-only ordination calibration, MSPL/AGHQ/VA/Julia comparisons, live-site deployment or a new campaign.
