# CI-11 Ayumi repair — plan-versus-actual reconciliation

**Melissa reconciliation, 2026-07-19.** The approved CI-11 plan required a bounded
categorical simulator repair, integration of current `main`, proof of the
phylogenetic masked route, an independent final review, a pinned public
re-test request, and an honest closeout.

| Planned gate | Receipt | Reconciliation |
| --- | --- | --- |
| Preserve the bounded repair, then integrate `main` without rewriting history | Categorical repair checkpointed as `57cb3171`; `origin/main` integrated by merge `1d3bb788` | Met. The later mask-preservation correction is a separate, bounded commit. |
| Prove the relevant phylogenetic/masked bootstrap route | Small 70-species `phylo_latent(..., d = 1, unique = FALSE)` live fixture, a multinomial trait, masked ordinal-probit partner, and direct `bootstrap_Sigma(..., level = "phy", what = "cross_corr")` | Met after a post-integration review found that refits had converted masked responses into simulated observations. Commit `a7eda6023a6d321902a6944ba86eb6c19a122ceb` restores the original mask in every refit. |
| Establish family completeness and diagnostic visibility | Ordinal-probit threshold simulation added; existing grouped baseline-category multinomial softmax confirmed; `n_failed`/effective-draw diagnostics and profile non-finite status surfaced | Met. The repair is ordinal-probit simulation; multinomial was not newly implemented. |
| Mechanical evidence | Focused regression, generated Rd, `pkgdown::check_pkgdown()`, live smoke, and `git diff --check` | Met locally. |
| Fresh D-43 | Fresh three-lens review completed after the integration and mask correction | Met; reviewers accepted the bounded plumbing evidence and its claim fence. |
| Collaborator re-test request | Pinned SHA pushed and an @Ayumi-495 issue reply posted | Met. The reply corrects the withdrawn silent-failure record and asks for the identical phylogenetic QC plus fit-health and diagnostic receipts. |

## Scope and non-claims

This is not a 3-OS CI receipt, an interval-calibration result, profile-speed
work, or an Ayumi real-data result. The local fixture establishes the
simulator/refit plumbing for a small masked phylogenetic case only. It does
not un-fence CI-11 coverage, establish finite-sample calibration, or claim
that the 500-species analysis is resolved; Ayumi's identical re-run is the
next external evidence gate.

## Process note

The initial ordinary fixture was necessary but insufficient. The
phylogenetic/masked gate exposed a real refit-mask defect before publication,
and the repair was amended rather than represented as covered by the earlier
test. The final public wording therefore distinguishes ordinal repair from
pre-existing multinomial support and endpoint-status visibility from profile
runtime improvement.
