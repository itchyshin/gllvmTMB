# S1 RECON — CRAN Path A cleanup inventory (0.6.1 submit-ready)

**Worktree:** `/private/tmp/gllvmtmb-cran-path-a-0.6.1`  
**Branch:** `cursor/cran-path-a-0.6.1-20260807`  
**Freeze-base SHA (at recon):** `13e212c119bfeefb3fb46bb4e7b17eef0609933c`  
**Base:** `origin/main` `5bf18ab30d7034e1c90c383fb4621d916b3a48cd` + scaffold  
**Mode:** READ-ONLY scout · 2026-08-07  
**Agent:** [S1 RECON](182e4907-6ef2-437c-a31d-e298c9e99ec6)

---

## Verdict

Cleanup is honesty/identity work, not a default-engine contradiction — except one real D-112 clash:
DESCRIPTION says no coverage is certified while `profile_ci_total_variance()` exports `certified-0.94`.

## DESCRIPTION

- Version `0.6.0` (S3 → `0.6.1`)
- URLs/BugReports/License/Maintainer OK
- Description: experimental; “no cell's interval coverage is certified” — **tensions with** `profile_ci_total_variance`

## NEWS.md

- Header `0.6.0`; needs `0.6.1` section + Laplace-default / AGHQ–VA opt-in scope boundary
- AGHQ “calibrated 9-node” easy to misread as coverage calibration
- No “CRAN ready”; VA silent on tip (safer)

## README.md

- “not on CRAN yet” + experimental badge — correct pre-upload
- Citation version `0.6.0` (S3)
- Sister line: gllvmTMB as TMB-Laplace alternative — good fence

## cran-comments.md

- Stale 0.6.0 / SHA `c0af58d3` / withheld policy
- `.Rbuildignore`d — S4 rewrite; platform rows TBD until exact-tag

## Claim ledger (fence list)

| File | Why |
| --- | --- |
| `R/profile-derived.R` + Rd | `certified-0.94` vs DESCRIPTION / D-112 |
| `NEWS.md` | 0.6.1 scope boundary; disambiguate “calibrated” |
| `DESCRIPTION` | Reconcile coverage sentence; Version S3 |
| `README.md` / `inst/CITATION` | Version S3 |
| `cran-comments.md` | S4 identity rewrite |
| `_pkgdown.yml` comments | 0.6.1 identity note (S5) |

## PR #949

OPEN, not merged — **out of freeze**. Title: Arc-1 scalar VA fence.

## S2 / S3 lists

**S2:** soften or reconcile `certified-0.94` vs DESCRIPTION; NEWS Laplace/AGHQ–VA fence; disambiguate AGHQ “calibrated”.  
**S3:** DESCRIPTION, NEWS 0.6.1 section, `inst/CITATION`, README citation, light `_pkgdown.yml` comment.

## Runbook traps

Exact-tag rule; cran-comments ignored by check; no patch inside M5; name D-49 rung; win-builder at M5.
