# After Task: Spatial Derived-Profile Gap

**Branch**: `codex/r-bridge-grouped-dispersion`  
**Date**: `2026-07-03`  
**Roles (engaged)**: `Ada / Fisher / Gauss / Noether / Rose`

## 1. Goal

Clarify whether current profile-likelihood and extractor machinery supports
final Ayumi-style spatial total-covariance claims from
`spatial_latent(..., unique = TRUE)`.

## 2. Implemented

No package engine code was changed. The repository now records the narrower
capability boundary: profile likelihood exists, but current spatial derived
profiles and spatial correlations target the low-rank
`Lambda_spde Lambda_spde'` surface, not
`Lambda_spde Lambda_spde' + diag(Psi_spde)`.

## 3. Files Changed

- `docs/dev-log/audits/2026-07-03-spatial-derived-profile-gap.md`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-03-spatial-derived-profile-gap.md`

## 3a. Decisions and Rejected Alternatives

Decision: downgrade SPA-02 and the spatial part of CI-07 to partial for
source-specific total covariance.

Rationale: `spatial_latent()` currently maps off the per-trait `omega_spde`
path, reports `Sigma_spde = Lambda_spde Lambda_spde'`, and profiles spatial
correlations with `use_diag <- FALSE`.

Rejected alternative: treat existing low-rank spatial profiles as sufficient
for total spatial-correlation/commonality claims. Confidence: high.

## 4. Checks Run

```sh
gh pr list --state open --limit 20
git log --all --oneline --since='6 hours ago' --decorate
```

Both returned no entries before shared-doc edits.

```sh
nl -ba R/extract-sigma.R | sed -n '1188,1210p'
nl -ba R/profile-derived.R | sed -n '630,705p'
nl -ba R/fit-multi.R | sed -n '880,905p;3378,3395p;3778,3785p'
nl -ba src/gllvmTMB.cpp | sed -n '1354,1412p'
nl -ba docs/design/35-validation-debt-register.md | sed -n '176,185p;340,346p'
```

Outcome: confirmed the low-rank-only spatial latent covariance and the
absence of a spatial unique diagonal in derived spatial profiles.

```sh
git diff --check -- docs/dev-log/audits/2026-07-03-spatial-derived-profile-gap.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md
```

Outcome before the article/after-task follow-up: passed with no output.

```sh
rg -n "SPA-02.*covered|CI-07.*covered|spatial_latent.*spatial_unique.*covered|rho:spatial.*final|spatial total-covariance.*covered|spatial commonality.*final|spatial.*bootstrap.*correlation|bootstrap_Sigma.*spde" docs/design README.md NEWS.md vignettes R tests docs/dev-log/audits -S
```

Outcome: found current article gate overstatements in
`vignettes/articles/functional-biogeography.Rmd` and
`vignettes/articles/profile-likelihood-ci.Rmd`; corrected both. Remaining
hits were historical audit text or unrelated covered rows.

## 5. Tests of the Tests

No tests were added in this documentation/audit slice. The next implementation
slice must add RED tests for parser state, random-effect contents, TMB report
contents, total-covariance extractors, and profile target parity.

## 6. Consistency Audit

`SPA-02` and `CI-07` now both point to the gap audit and use `partial`
status for source-specific total spatial covariance. The functional
biogeography and profile-likelihood article gates no longer advertise all
spatial / correlation inference rows as broadly covered.

## 7. Roadmap Tick

N/A. No roadmap row changed in this audit-only slice.

## 7a. GitHub Issue Ledger

No issue was commented or closed in this slice. The user explicitly asked not
to reply to Ayumi yet during the analysis lane.

## 8. What Did Not Go Smoothly

The initial biological-analysis figures exposed a package-capability gap:
rank-1 spatial correlations looked too close to `-1` and `1` because the
current spatial latent path has no unique diagonal companion. This required
stopping the analysis and writing the capability boundary before continuing.

## 9. Team Learning

**Fisher:** profile likelihood is present, but the inferential target matters.
The current spatial profile is a low-rank shared-field profile, not a total
spatial-covariance profile.

**Gauss:** the engine currently chooses between per-trait SPDE fields and
shared low-rank SPDE fields. `spatial_latent(unique = TRUE)` must keep both
`omega_spde_lv` and `omega_spde` active.

**Noether:** the formula-to-estimand alignment is wrong if captions say
spatial latent plus unique while extraction uses only
`Lambda_spde Lambda_spde'`.

**Rose:** stale capability wording already existed in two public article
gates; the register and article wording now agree.

## 10. Known Limitations And Next Actions

Next implementation slice:

1. add `spatial_latent(..., unique = TRUE/FALSE)` parser state;
2. keep both spatial random-effect blocks active for `unique = TRUE`;
3. report `Sigma_spde_shared`, unique spatial Psi, and `Sigma_spde_total`;
4. update `extract_Sigma()`, `extract_correlations()`, and derived profile
   helpers to target total spatial covariance by default;
5. add known-DGP recovery and profile parity tests before advertising final
   Ayumi spatial correlation/commonality figures.
