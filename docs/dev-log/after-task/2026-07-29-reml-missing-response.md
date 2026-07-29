# After-task — REML accepts the FIML response mask

Date: 2026-07-29 · Platform: Claude Code · Branch: `claude/reml-mask-20260729`
Base: `origin/main` @ `01ad94ba`

## 1. Goal

Close the last gap the missing-data audit left open: `REML = TRUE` aborted on any masked response, so
the one estimator whose correction interacts with the missing-data policy was the one policy it
could not be combined with.

## 2. Implemented

The restriction is lifted, because it was **conservative rather than load-bearing**.

REML here is TMB's standard idiom — `b_fix` joins the random vector and Laplace integrates it out
(`R/fit-multi.R`, *"Gaussian REML is implemented by integrating the fixed-effect coefficient
block"*). Masked rows contribute exactly zero to the joint likelihood through the `is_y_observed`
gate, so the joint stays a Gaussian LMM **over the observed rows**; the Laplace step is still exact
there, and integrating `b_fix` over it yields the restricted likelihood for those rows.

Two pieces of evidence that this was already half-anticipated: the rank check immediately below the
guard reads `X_fix[!masked_response, , drop = FALSE]` — masked-row handling written and then fenced
off — and `X_reml` is used **only** for that rank check, never passed to TMB.

## 3a. Decisions and rejected alternatives

- **Rejected: treating `|REML − ML|` as evidence REML is better.** The two log-likelihoods are not on
  a common scale; REML's is computed after integrating out the fixed effects. The difference is an
  **engagement** check only. This is stated in the commit, the docs, and the PR because it is an easy
  and consequential misreading.
- **Rejected: deleting the failing guardrail assertion.** `test-gaussian-reml.R` asserted REML +
  `include` must error. It was removed from the *"what REML refuses"* block with the reason recorded
  inline and a pointer to where the supported behaviour is now pinned. Coverage moves, not vanishes.
- **Rejected: lifting more than one restriction.** Non-Gaussian REML, observation weights, rank
  deficiency and `mi()` predictor models still abort, and a test pins that they do.
- **Rejected: making REML a default.** Out of scope, and not free — REML fits with different fixed
  effects are not comparable by AIC or LRT.

## 4. Files touched

Modified: `R/fit-multi.R`, `R/gllvmTMB.R`, `man/gllvmTMB.Rd`, `man/miss_control.Rd`,
`tests/testthat/test-gaussian-reml.R`
Created: `tests/testthat/test-reml-missing-response.R`, this report

## 5. Checks run

| Check | Result |
|---|---|
| targeted REML tests | 7 pass / 0 fail |
| `test-gaussian-reml.R` after the edit | 45 pass / 0 fail |
| full suite (`NOT_CRAN=true`) | **7922 pass / 0 fail / 782 skip** |
| `rcmdcheck` | **0 ERRORS / 0 WARNINGS / 0 NOTES** |
| diff scope vs `origin/main` | exactly 6 files, all mine |

Measured (n=40, 2 traits, 3 masked cells):

```
REML drop     logLik = -38.66251349   nobs = 77
REML include  logLik = -38.66251349   nobs = 77
|difference|  = 1.42e-14
|REML - ML|   = 7.244415   (engagement only)
```

`drop` physically removes those cells, so REML-under-`drop` **is** "REML on the reduced data" —
which makes that comparison the correctness question itself, not a proxy for it.

## 6. Tests of the tests

Every test asserts **engagement before equivalence**: REML must differ from ML in both policies
before the two policies are compared. Without that, an equivalence between two secretly identical
computations proves nothing.

This is not hypothetical. Earlier in this arc an AGHQ probe reported perfect agreement while
silently falling back to Laplace, because the model was ineligible for Stage 1a. The engagement
assertion is the guard against exactly that class of self-deception.

A separate test pins that the untouched REML guards still fire.

## 7a. Issue ledger

The REML × masked-response gap is closed. `mi()` predictor models under REML remain unsupported and
are unaffected.

## 8. Consistency audit

- Swept for every doc site stating the old limitation: two (`@param REML`, and the `miss_control()`
  details block). Both corrected, Rd regenerated, diff confined to the two affected pages.
- Checked the two suite warnings were not mine: `test-comparator-gllvm.R` contains **zero**
  references to `REML` or `miss_control`. Pre-existing.
- Re-checked the diff against `origin/main` after rebasing, to confirm no phantom changes from
  concurrent lanes.

## 9. What did not go smoothly

**The full suite caught a failure the targeted tests could not.** `test-gaussian-reml.R` asserted the
restriction as a contract. Had I trusted the 7 green targeted tests, the branch would have gone up
broken. The targeted-test/full-suite distinction earned its cost here.

**My guardrail-test fix was uncommitted when the suite passed.** `load_all()` reads the working
tree, so the suite was green against files that were not staged — the branch as it then stood was
broken. A green suite says nothing about what is committed.

**`main` moved 4 commits ahead mid-task** (two further honesty lanes). The pre-rebase diff showed
phantom deletions of files those lanes had added, which would have been alarming in review.

## 10. Known residuals

- **Nothing here shows REML is preferable to ML.** Only that the mask composes with it.
- Gaussian only, as before. Non-Gaussian REML remains unimplemented.
- `mi()` predictor models under REML remain unsupported.
- The mechanism argument (Laplace exact for a Gaussian LMM over observed rows) is verified
  numerically on one configuration, not proved symbolically or swept across designs.
- A clean local check is not a clean CRAN check: macOS only, `--no-manual --no-build-vignettes`.

## 11. Team learning

**A test that asserts a restriction is recorded intent — read it before removing it.** The evidence
said the guard was conservative and the removal looks right, but the code cannot say whether the
original author had a reason it does not state. That question belongs to the maintainer, and the PR
asks it explicitly rather than assuming the answer.

**Engagement before equivalence.** When comparing two routes, first prove they are actually different
computations. Otherwise a green equivalence may just mean nothing ran.

**Green suite ≠ committed work.** `load_all()` reads the working tree; `git status` is the check that
matters before pushing.

## 12. Cross-product coverage — the negative space

- No claim that REML is better, more efficient, or preferable.
- No coverage or interval claim.
- Does not touch non-Gaussian REML, weights-under-REML, or `mi()`-under-REML.
- Does not change any default: `REML = FALSE` remains the default fit.
- Does not verify the restricted likelihood against an external reference implementation — the
  correctness argument is internal consistency (`include` == `drop`, both ≠ ML) plus the mechanism.
