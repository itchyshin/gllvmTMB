# Inference Route Truth Matrix (Day 1 of the completion arc)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4d8f7589`
Agent: Claude (taking over from Codex per `docs/dev-log/handover/2026-07-05-claude-handover.md`)

## Goal

Deliver the Day-1 truth-lock artefact for the `gllvmTMB` R/TMB completion arc:
a complete estimand x tier x method inference-route truth matrix across `unit`,
`unit_obs`, `cluster`, `cluster2`, `phy`, `spatial`, `kernel_named`,
`unit_slope`, and the augmented structural split tiers. For each target, record
Wald / profile-LR / estimated-likelihood / bootstrap status with test paths and
validation-row IDs, grounded in the code rather than memory.

## Outcome

Created `docs/design/75-inference-route-truth-matrix.md`. It is the method-axis
companion to Design 73 (profile-axis) and Design 74 (augmented target shapes).

Key structural finding: the internal ledger `.profile_route_matrix()` emits
**profile-only** rows, while `confint()` / `extract_*(ci = TRUE)` dispatch four
method words. Wald and bootstrap are wired in dispatch but absent from the
ledger; **estimated-likelihood / fixed-nuisance LR is unimplemented** across
`R/` and `src/` (`planned` on every cell). Multi-component phylogenetic signal
is the only live `fallback` (`wald(numeric)`).

The matrix keeps the hard guards intact: augmented tiers stay `blocked` except
the Gaussian `rho:unit_slope:i,j` canary (`partial`); structural-zero
cluster/cluster2 correlations get no interval on any method; mixed-family CIs
stay blocked on every method; `pdHess = TRUE` is never cell evidence.

## Checks Run

This is a read-only design audit. No test file, `devtools::check()`, or
`pkgdown::check_pkgdown()` was run because no code, likelihood, grammar, or
generated Rd changed. Evidence-gathering commands:

```sh
gh pr list --state open --limit 20                                  # no open PRs
git log --all --oneline --since='6 hours ago' --max-count=20        # no lane collision
rg -in "estimated.?likelihood|fixed.?nuisance|profile_out_nuisance" R src  # absent
rg -n "method <- match.arg" R/z-confint-gllvmTMB.R R/extractors.R   # 3-method dispatch
```

Grounding reads: `R/profile-route-matrix.R` (profile-only ledger),
`R/z-confint-gllvmTMB.R` (method dispatch + Sigma parm tokens),
`R/extractors.R` (`extract_Sigma`/derived `method = c("profile","wald","bootstrap")`),
`R/profile-derived.R` (`wald(numeric)` fallback, `.communality_wald_ci`).

## Consistency Audit

Stale-wording scan (`partial support|ready to expose|pdHess passed|mixed-family
CI|source-specific.*lv|bootstrap rescue`) over `R docs tests man NEWS.md`
returned one benign hit: a NEWS not-supported disclaimer listing mixed-family
CIs. No overclaim wording introduced.

Every method-column status carries an explicit evidence basis: profile is
authoritative (copied from the code ledger); Wald and bootstrap are
dispatch-confirmed with per-cell test debt flagged; estimated-likelihood is
`planned`.

## Files Created / Modified

- Created `docs/design/75-inference-route-truth-matrix.md`.
- Appended a check-log entry to `docs/dev-log/check-log.md`.
- Created this after-task report.

No R, C++, Rd, NEWS, README, vignette, or validation-register file changed.

## Team Notes

Fisher owns the uncertainty ladder encoded here: Wald is a scout, profile-LR is
the preferred engine, estimated-likelihood is a not-yet-built diagnostic tier,
bootstrap is opt-in calibration -- none certified as calibrated coverage.

Rose's overclaim gate: the doc states in three places that "covered" for
Wald/bootstrap means the route dispatches, never that coverage is calibrated.

Noether's alignment gate is deferred: symbolic <-> R <-> TMB review is required
before any augmented or spatial cell is promoted, but nothing was promoted here.

Shannon notes no push or PR was opened; the branch remains local, ahead 201.

## Roadmap Tick

N/A for capability. This is Phase 0 / Phase 1 truth-lock evidence under the
completion ultra-plan
(`docs/dev-log/while-away/2026-07-04-gllvmtmb-completion-ultra-plan.md`), not a
new advertised route.

## Known Limitations And Next Actions

- The internal ledger still disagrees with dispatch reality. Recommended next
  slice (Fisher lane, for Codex): extend `.profile_route_matrix()` to emit
  `wald` / `bootstrap` / `estimated_likelihood` method rows matching Design 75,
  with a pure route test per method.
- Wald and bootstrap cells rest on dispatch reading; per-cell focused tests for
  the derived-summary companions are outstanding test debt.
- Before any Design 75 cell informs user-facing wording or a validation-register
  status, Rose + Fisher + Noether must review the affected rows.
- No push/PR/merge without Shinichi's authorization.
