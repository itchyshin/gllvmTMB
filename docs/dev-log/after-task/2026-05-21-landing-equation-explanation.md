# After-Task: Landing equation explanation

**Date:** 2026-05-21  
**Branch:** `codex/symbol-syntax-alignment-2026-05-21`  
**Lead:** Ada  
**Review perspectives:** Pat (new-reader clarity), Boole (syntax alignment),
Noether (symbol consistency), Rose (stale-claim prevention), Grace (pkgdown)

## Purpose

The landing page showed `Sigma = Lambda Lambda^T + Psi` without telling a
first-time reader what the equation helps them understand. This slice rewrites
that homepage block so the equation becomes a plain-language map between the
model, the R syntax, and the interpretation.

## Files Changed

- `README.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-landing-equation-explanation.md`

## What Changed

The homepage now explains the Gaussian stacked-trait starting path as a split
of the trait covariance matrix into shared and trait-specific parts:

- `Sigma` is the total covariance among traits, extracted with
  `extract_Sigma(fit, level = "unit")`.
- `Lambda Lambda^T` is the shared latent-axis part, fitted with
  `latent(..., d = K)`.
- `Psi` is the trait-specific leftover variance, fitted with `unique(...)`.

The reader-facing takeaway is now explicit: total trait covariance equals
shared multivariate structure plus response-specific variation.

## Checks

Completed:

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,statusCheckRollup`
- `git log --all --oneline --since="6 hours ago"`
- `Rscript --vanilla -e 'pkgdown::build_home()'`
- Browser check at `http://127.0.0.1:8765/index.html`
- `git diff --check`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- `rg -n "diag\\(S\\)|diag\\(s\\)|boldsymbol\\{S\\}|gllvmTMB_wide|two-U|Sigma = Lambda Lambda\\^T \\+ Psi" README.md docs/dev-log/after-task/2026-05-21-landing-equation-explanation.md`

Outcome:

- `pkgdown::check_pkgdown()` reported `No problems found.`
- The stale-wording scan had expected matches only: the new homepage
  interpretation sentence, the after-task description of the old issue, and
  the existing README soft-deprecation note for `gllvmTMB_wide()`.

## Reviewer Notes

- **Pat:** The page now defines the equation in terms of what a user sees:
  traits varying together versus response-specific variation.
- **Boole:** The table keeps R syntax beside the symbol so the equation does
  not float away from the formula grammar.
- **Noether:** The notation uses `Sigma`, `Lambda`, and `Psi`; no legacy
  `S`, `s`, or `U` notation was introduced.
- **Rose:** The wording stays preview-safe and does not claim validation
  beyond the current first public path.
- **Grace:** Homepage render succeeded; full pkgdown check remains the next
  gate.

## Limitations

This is a landing-page wording fix, not a full homepage redesign. The broader
landing-page and Get Started path still need joint HTML review before launch.
