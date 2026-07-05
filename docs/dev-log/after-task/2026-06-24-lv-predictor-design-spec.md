# After Task: Predictor-Informed Latent-Score Design Spec

**Branch**: `codex/lv-predictor-design-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Boole / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Create the source-of-truth design for a future
`latent(..., lv = ~ x)` capability before touching parser or TMB code.
The goal was to define the mathematical contract, blocked validation
rows, first implementation slice, extractor surface, and R-Julia parity
boundary carefully enough that later implementation PRs can move one
gate at a time.

## 2. Implemented

- Added Design 73 for predictor-informed latent scores.
- Reserved the future term-local `lv = ~ ...` grammar surface in the
  formula grammar, with C1 scoped to ordinary Gaussian unit-tier
  `latent()` only.
- Recorded the future likelihood contract:
  `z_i = M_i alpha + e_i`, `e_i ~ N(0, I_K)`, while preserving the
  ordinary `latent()` diagonal `Psi` companion.
- Added blocked validation rows `FG-18`, `RE-13`, `EXT-31`, and
  `LV-01` through `LV-07`.
- Updated the testing, random-effect, extractor, and capability-status
  docs so the future work is visible without advertising runtime support.
- Added a recovery checkpoint for this lane.

## 3. Mathematical Contract

This is a design/spec PR. It does not change public R runtime behavior,
TMB likelihood code, generated Rd files, NAMESPACE, vignettes, NEWS, or
pkgdown navigation.

The planned model is:

```text
eta_it = X_it beta + lambda_t' z_i + q_it
z_i    = M_i alpha + e_i
e_i    ~ N(0, I_K)
q_i    ~ N(0, Psi)
```

The ordinary conditional trait covariance exposed by `extract_Sigma()`
remains:

```text
Sigma = Lambda Lambda' + Psi
```

The preferred public estimand for predictor-informed scores is:

```text
B_lv = Lambda alpha'
```

Raw `alpha` and raw `Lambda` are not sufficient pass/fail targets for
rank `K > 1` because they are rotation-dependent. The implementation
route must therefore report and test the trait-scale `B_lv`, plus
`Sigma` and `Psi`.

The latent-score term is an **innovation** model, not a residual-score
model. The word residual is reserved for the existing diagonal `Psi`
vocabulary around ordinary `latent()` fits. A no-innovation mean-only
model is a separate reduced-rank fixed-effect or constrained-ordination
mode, not an option hidden inside ordinary `latent()`.

## 4. Files Changed

Design source:

- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-lv-predictor-design-spec.md`
- `docs/dev-log/recovery-checkpoints/2026-06-24-lv-predictor-main-lane-handoff.md`

Status-inventory cascade:

- `README.md`, `ROADMAP.md`, `NEWS.md`, roxygen, generated `man/*.Rd`,
  vignettes, and `_pkgdown.yml` were intentionally not changed. This PR
  does not create a runtime capability or a user-facing feature claim.

## 4a. Decisions and Rejected Alternatives

Decision: use `latent(..., lv = ~ x)` for the ordinary innovation model.

Rationale: the syntax keeps the latent-score predictor formula local to
the `latent()` term, distinguishes predictor-informed scores from
ordinary fixed effects, and keeps future structured-source variants
behind explicit validation rows.

Rejected alternative: implement a mean-only constrained-ordination
surface in the same argument. That would hide a different model
(`z_i = M_i alpha` with no innovation) under ordinary `latent()` and
blur the distinction between predictor-informed latent scores and
reduced-rank fixed effects.

Decision: drop the `lv` intercept internally and treat `lv = ~ x` as
equivalent to `lv = ~ 0 + x`.

Rationale: ordinary latent scores already have zero-mean innovations;
an axis intercept is not separately identified in the intended first
implementation.

Rejected alternative: expose raw `alpha` as the main scientific output.
For `K > 1`, raw axes are rotation-dependent. The trait-scale
`B_lv = Lambda alpha'` is the stable public target.

Decision: keep all runtime rows blocked.

Rationale: no parser, TMB, extractor, or recovery test exists in this
PR. The design rows are a map, not evidence of support.

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open PRs before shared design/dev-log edits.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS; recent shared-file history was the merged power-pilot lane:
  `1018c62`, `b08b146`, and `7c675dd`, plus local closed branches.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 8 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> PASS for gating workflows on current main: R-CMD-check run
  `28122717337` and pkgdown run `28123499603` completed successfully on
  `1018c62`. Scheduled Power pilot sweep runs `28125143612` and
  `28118670213` were pending/in progress and were not used as evidence.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "latent lv OR constrained ordination OR predictor-informed OR GLLVM.jl parity" --limit 20 --json number,title,url,updatedAt`
  -> PASS; located issue #340 as the relevant capability board and
  issue #488 as an adjacent Julia bridge-drift audit.
- `gh issue view 340 --repo itchyshin/gllvmTMB --json number,title,state,url,updatedAt,body`
  -> PASS; inspected the capability board.
- `gh issue view 347 --repo itchyshin/gllvmTMB --json number,title,state,url,updatedAt,body`
  -> PASS; inspected and classified article completion as adjacent, not
  changed by this PR.
- `gh issue view 488 --repo itchyshin/gllvmTMB --json number,title,state,url,updatedAt,body`
  -> PASS; inspected and classified bridge-gate drift as adjacent, not
  changed by this PR.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no pkgdown problems found.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-24-lv-predictor-design-spec.md`
  -> PASS.

## 6. Tests of the Tests

No package tests were added because this is a design/spec PR. The future
test contract is now explicit:

- parser tests for acceptance of ordinary Gaussian unit-tier
  `latent(..., lv = ~ x)`;
- typed rejections for random terms, offsets, `mi()`, smooths,
  response/trait columns, nonconstant within-unit predictors,
  rank-deficient `X_lv`, exact fixed-RHS overlap, `REML = TRUE`,
  non-Gaussian families, unsupported tiers/sources, and augmented
  random-regression combinations;
- CRAN-safe rank-1 Gaussian recovery and heavy rank-1/rank-2 recovery
  of `B_lv`, `Sigma`, and `Psi`;
- extractor tests for trait-scale `B_lv`, raw `alpha` rotation warnings,
  and ordination components `total`, `mean`, and `innovation`.

## 7. Consistency Audit

- `rg -n "latent\\([^\\n]*lv\\s*=|predictor-informed|latent-score mean|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31" docs R tests/testthat vignettes README.md NEWS.md`
  -> PASS; hits are the intended Design 73 surface, validation rows,
  linked design-doc updates, and the lane recovery checkpoint.
- `rg -n "REML|AI-REML|Gaussian-only|non-Gaussian.*REML|REML.*non-Gaussian" docs/design/73-predictor-informed-latent-scores.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`
  -> PASS; hits keep `REML = TRUE` rejected for `lv` and preserve the
  Gaussian-only REML / AI-REML boundary.
- `rg -n "Julia|GLLVM.jl|parity|engine = \"julia\"|engine = 'julia'" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`
  -> PASS; hits are row-backed Julia bridge boundaries and Design 73's
  explicit no-broad-parity statement.
- `rg -n "residual = FALSE|residual score|old no-residual|unique = FALSE" docs/design/73-predictor-informed-latent-scores.md docs/design/01-formula-grammar.md`
  -> PASS; Design 73 now uses current `unique = FALSE` wording, and
  remaining no-residual references are existing formula-grammar context.

## 8. Roadmap Tick

N/A. This PR adds blocked design rows and a source-of-truth spec, but it
does not change a `ROADMAP.md` status chip or capability progress bar.

## 8a. GitHub Issue Ledger

- Issue #340, `Capability matrix -- live status board`, was inspected.
  This PR updates the validation register source of truth, but no
  covered/partial row is promoted.
- Issue #347, `[roadmap] Article completion (public learning path)`,
  was inspected and left unchanged because websites/articles can wait
  until capability rows move or stale public claims need removal.
- Issue #488, `Bridge-gate drift: R wrapper may reject engine="julia"
  features GLLVM.jl already supports (audit)`, was inspected as an
  adjacent Julia-bridge boundary. No Julia gate is changed here.

No issue was closed. No new issue was created because Design 73 plus the
new validation rows are the durable implementation ledger for this
specific capability.

## 9. What Did Not Go Smoothly

The main risk was vocabulary drift. The user's source plans used both
`residual` language and the newer `innovation` framing. This PR resolves
that by reserving "innovation" for `e_i` and keeping "residual" for the
existing diagonal `Psi` context.

The first broad `lv =` scan also caught historical `num.lv =` usages in
Julia bridge tests and cross-package examples. That was harmless but too
noisy for future auditing, so the final recorded scan uses a narrower
`latent(... lv = ...)` pattern.

## 10. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep this at the design boundary. The capability is important
enough to deserve a full contract before any parser/TMB edit, but no
runtime claim moves until tests exist.

Boole: term-local `lv = ~ ...` is understandable, but only if C1 rejects
ambiguous combinations loudly: fixed-RHS overlap, augmented random
regression, unsupported tiers, and nonconstant unit-level predictors.

Curie: the first real implementation must make recovery tests target
`B_lv`, `Sigma`, and `Psi`. Raw axes alone would let a rotated but
scientifically equivalent fit fail incorrectly.

Fisher: power, coverage, and non-Gaussian claims are separate evidence
lanes. `LV-05` stays blocked until family-specific diagnostics and
coverage gates exist.

Grace: the design is platform-safe because it adds documentation only.
The future implementation should keep C1 Gaussian and CRAN-safe before
heavy recovery tests or DRAC CPU simulations broaden the evidence.

Rose: every public claim is traceable to blocked rows. The capability
status page now says the lane is important but not live, which prevents a
future website or bridge note from accidentally advertising it early.

Shannon: work stayed in the clean `/private/tmp` worktree and no second
open PR existed before shared design/dev-log edits.

## 11. Known Limitations And Next Actions

- `FG-18`, `RE-13`, `EXT-31`, and `LV-01` through `LV-07` remain
  blocked.
- No parser support for `lv` exists.
- No TMB parameters, ADREPORTs, or likelihood code exist.
- No `extract_lv_effects()` export or `extract_ordination(component = )`
  runtime support exists.
- No Gaussian recovery, missing-response, factor-predictor, non-Gaussian,
  tier-expanded, structured-source, or Julia bridge support exists.

Next slices, in order:

1. Parser/API guard PR for ordinary Gaussian unit-tier `latent(..., lv = ~ x)`.
2. TMB Gaussian C1 implementation with `alpha_lv_B` and `B_lv` ADREPORT.
3. Extractor PR for trait-scale `B_lv` and ordination components.
4. CRAN-safe rank-1 recovery, then heavy rank-1/rank-2 recovery.
5. Only after R evidence exists, a named GLLVM.jl design/implementation row.
