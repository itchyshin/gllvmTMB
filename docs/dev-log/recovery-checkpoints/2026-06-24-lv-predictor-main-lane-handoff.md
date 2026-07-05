# Recovery Checkpoint: Predictor-Informed Latent Scores Main-Lane Handoff

## Current State

- Branch: `codex/lv-predictor-design-20260624`
- Start SHA: `1018c62d5fe2a94a803c863a777e238930946110`
- Worktree: `/private/tmp/gllvmtmb-lv-predictor-design-20260624`
- Dirty Dropbox checkout remains off-limits for PR work:
  `/Users/z3437171/Dropbox/Github Local/gllvmTMB`

## Goal

Create a design/spec PR for predictor-informed latent scores via a
future `latent(..., lv = ~ x)` API. This checkpoint is intentionally
not an implementation handoff for parser or TMB code.

## Coordination Checks Before Edits

- `git status --short --branch`
  - clean on `codex/lv-predictor-design-20260624...origin/main`
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,statusCheckRollup,url,updatedAt`
  - no open PRs
- `git log --all --oneline --since='6 hours ago'`
  - recent capability PRs only: `1018c62`, `cb6da22`, `b08b146`,
    `3f76530`, `7c675dd`
- `gh run list --repo itchyshin/gllvmTMB --limit 12 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt`
  - post-merge R-CMD-check and pkgdown for `1018c62` were green;
    scheduled Power pilot sweeps were pending / in progress and were
    not used as validation evidence.

## Design Contract

First public target:

```r
latent(1 | unit, d = 2, lv = ~ reporting_quality + policy_used)
```

Meaning:

```text
eta_it = X_it beta + lambda_t' z_i + q_it
z_i    = M_i alpha + e_i
e_i    ~ N(0, I_K)
Sigma  = Lambda Lambda' + Psi
B_lv   = Lambda alpha'
```

Hard scope for C1:

- ordinary unit-tier Gaussian `latent()` only;
- `lv` is fixed-effect-only;
- the outer `latent()` still supplies the latent-score innovation;
- `extract_Sigma()` remains conditional `Lambda Lambda^T + Psi`;
- primary estimand is `B_lv`, not raw `alpha`;
- reject `REML = TRUE`, non-Gaussian families, fixed/LV exact overlap,
  unsupported tiers, and structured-source `lv` forms until their own
  validation rows move.

## Next Safest Action

Complete the design/spec PR only:

1. Add `docs/design/73-predictor-informed-latent-scores.md`.
2. Update `01-formula-grammar.md`, `03-likelihoods.md`,
   `04-random-effects.md`, `05-testing-strategy.md`, and
   `06-extractors-contract.md` to point at Design 73.
3. Add blocked validation rows in `35-validation-debt-register.md`.
4. Update `61-capability-status.md`, `check-log.md`, and an after-task
   report.
5. Run markdown/stale-wording checks, commit, push, and open one PR.

## Do Not Do In This Slice

- Do not edit parser or TMB implementation.
- Do not add roxygen/Rd, README, vignette, NEWS, or pkgdown navigation
  claims.
- Do not run DRAC jobs, GPU jobs, or production simulations.
- Do not widen Julia bridge claims.
- Do not promote validation rows from design-only work.
