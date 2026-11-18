# Issue 1467 completion plan

Goal: deliver and push tested LV summaries with uncertainty, one-axis plots,
correct factor contrasts, and an explicit, discoverable ridge workflow.
Follow-up authorised on 2026-10-08: repair the real trait-column spelling with lv, push and verify CI, then prepare a collaborator reply for review. Posting remains outside scope.

1. Correct loading-ridge posterior curvature and metadata at every sdreport path.
2. Expose matched approximate posterior SDs for axis and trait LV coefficients.
3. Suggest explicit loading_ridge = 2 for unstable ordinary binomial latent fits;
   keep Inf as the general ML default and document its statistical meaning.
4. Refit exact data, verify numerical curvature and propagated SDs, run relevant
   regressions and a fresh package build/check. Expected refits 1-3 minutes;
   focused tests 5-15 minutes; fresh build/check without full suite 15-30 minutes.
5. Integrate current main, independently review, commit, push the named branch,
   create a fix PR, verify its checks, and close the evidence report.

Acceptance: finite labelled posterior SDs on the real ridge fit; ordinary d1
SEs retained; factor/plot regressions green; failed ordinary d2 visible;
legacy ridge SDs fail closed; full runnable ridge code documented; unchanged
ML default; current-main integration and remote receipts present.

Follow-up acceptance: both placeholder and resolved column spellings agree for d1, d2 and ridge d2; custom column names work; augmented-model rejection stays intact; supplied-data refits and neighbouring tests pass; final remote checks pass before drafting the reply. Expected local tests and refits 5-15 minutes, remote CI about 30 minutes.
