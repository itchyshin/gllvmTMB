# r200 post-promotion register-wording pre-draft

**Date:** 2026-05-25
**Author:** Shannon (cross-team coordination), with Rose
(scope honesty) and Fisher (inference policy) lenses.
**Status:** **Template only.** Not a dispatch authorization.
Not a register edit. Pre-drafts the exact text that will go
into `docs/design/35-validation-debt-register.md` rows
**CI-08** and **CI-10** under each Design 50 §5 outcome,
so that the post-r200 register-edit PR can move quickly
without rewriting the language under time pressure.

## 1. What this is, what this is not

**This is**: a wording template for the CI-08 / CI-10 row
edits that will be needed once r200 evidence lands.

**This is not**:

- A dispatch authorization. Per Design 50 §5 + §9 and the
  r200 dispatch plan (PR #267,
  [`2026-05-25-m3-r200-dispatch-plan.md`](2026-05-25-m3-r200-dispatch-plan.md)),
  the maintainer authorises r200 and Codex queue item 4
  (workflow plumbing) must land first.
- A register edit. CI-08 and CI-10 stay `partial` until the
  register-edit PR (separate slice, post-r200 review) is
  opened.
- A claim that any specific outcome will land. Outcomes
  depend on the actual r200 results.

## 2. Current state on `main`

Both rows are currently `partial`. Quoted verbatim from
`docs/design/35-validation-debt-register.md` at `397cc9e`:

> **CI-08**: `coverage_study()` ≥ 94 % empirical coverage
> gate (PR #120). Status: `partial` (M3.3 production gate
> failed). Test evidence: `test-coverage-study.R`;
> `dev/precomputed/coverage-gaussian-d2.rds` (R = 200,
> PR-0C.COVERAGE); audit
> `2026-05-19-m3-production-grid-artifact-review.md` (R =
> 200 Actions run 26100827665). Notes: M3.3 profile-psi
> production run completed 2026-05-19: workflow passed
> 15/15 jobs, but only Gaussian d=1 and Gaussian d=3
> cleared the 94 % gate; 13/15 cells remain below gate and
> 236/3000 replicate fits failed. No production RDS
> promoted to `inst/extdata/`; Design 50 now requires
> surface admission, target-explicit total
> `Sigma_unit[tt]`, and a diagnostic report before
> coverage claims move.

> **CI-10**: profile / Wald / bootstrap on mixed-family
> fits. Status: `partial`. Test evidence: audit
> `2026-05-19-m3-production-grid-artifact-review.md`.
> Notes: M3.3 mixed-family production cells did not clear
> the profile-psi coverage gate: d=1 0.820, d=2 0.685,
> d=3 0.550, with 105/600 failed replicate fits. Design 50
> keeps this as triage evidence until target-explicit
> mixed-family surfaces pass admission and promotion gates.

## 3. Design 50 §5 promotion thresholds (recap)

For any cell to **promote** to `covered` via r200 evidence,
all of the following must hold per Design 50 §5:

1. Empirical coverage on target `Sigma_unit_diag` ≥ **0.94**
   (the "94% gate").
2. CI-missing rate ≤ **10%**.
3. Fit-failure rate ≤ **20%** (≤ **30%** for mixed-family
   cells, per the §5 carve-out).
4. Bootstrap-failure rate ≤ the same family-specific limit.
5. No one-sided miss pattern (≥ **80%** of misses on one
   side).
6. `pilot_status == "PASS_TO_SCALE"` already achieved at r50
   (the r10 / r50 admission floor); the post-patch r10 (PR
   #266) showed `binomial × d=2` and `mixed × d=2` already
   at `PASS_TO_SCALE`.

Per the r200 dispatch plan (PR #267) recommended scope is
**Option B**: 4 cells — binomial d ∈ {1, 2, 3} + mixed d=2.
Wording below assumes that scope. Adjust cell lists if the
dispatched scope differs.

## 4. Three outcome categories

For each cell at r200, three possible outcomes:

- **Outcome A**: clears the 0.94 gate AND all secondary
  gates → cell promotes (contributes to row → `covered` with
  explicit scope text).
- **Outcome B**: clears 0.90 (r50 admission floor) but not
  the 0.94 promotion gate → cell stays `partial` with the r200
  evidence cited as diagnostic.
- **Outcome C**: fails the 0.90 floor OR a secondary gate →
  cell stays `partial` with the r200 evidence cited as
  failure.

The 4 cells × 3 outcomes give 12 micro-cases. The wording
below handles row-level rollup: a row promotes to `covered`
only when its scope-text cells all hit Outcome A; otherwise
the row stays `partial` with an updated note that records
the partial result.

## 5. Pre-draft text — CI-08

CI-08 r200 scope under Option B touches binomial d ∈ {1, 2, 3}.
CI-08 covers the broader `coverage_study()` gate; the row's
public claim should expand only to the cells that pass and
should explicitly preserve the unmoved status of nbinom2 /
ordinal-probit / Gaussian d=2 / mixed cells.

### 5.1 If all three binomial cells hit Outcome A

```text
| CI-08 | `coverage_study()` ≥ 94 % empirical coverage gate
  (PR #120) | `covered` for binomial × d ∈ {1, 2, 3} on
  target `Sigma_unit_diag`; `partial` for Gaussian d=2,
  nbinom2, ordinal-probit, mixed-family d ∈ {1, 3}, and
  ordinal-probit overall |
  `test-coverage-study.R`;
  `dev/precomputed/m3-r200-binomial-d1.rds`,
  `dev/precomputed/m3-r200-binomial-d2.rds`,
  `dev/precomputed/m3-r200-binomial-d3.rds`
  (Actions run `<RUN_ID>`, retention <DAYS> days);
  audit
  `docs/dev-log/audits/2026-05-NN-m3-r200-binomial-promotion.md` |
  M3.3b r200 promotion 2026-05-NN: binomial × d ∈ {1, 2, 3}
  empirical coverage on `Sigma_unit_diag` at <COV1>/<COV2>/<COV3>
  ≥ 0.94 under patched DGP (PR #263 / #264), with fit-failure
  rate ≤ 20%, CI-missing ≤ 10%, no one-sided miss > 80%, and
  `pilot_status == PASS_TO_SCALE` retained from PR #266.
  Gaussian / nbinom2 / ordinal-probit cells not re-dispatched
  in this slice and stay `partial`; previous M3.3 evidence
  preserved in note history below. |
```

### 5.2 If one or two binomial cells hit Outcome A and the rest Outcome B

```text
| CI-08 | `coverage_study()` ≥ 94 % empirical coverage gate
  (PR #120) | `partial` (binomial × d=<K> cleared 0.94 gate
  at r200; binomial × d=<L>/<M> at <COV> ≥ 0.90 admission
  floor but below 0.94 promotion gate; other families
  unmoved) |
  (same evidence paths as 5.1) |
  M3.3b r200 partial promotion 2026-05-NN: binomial × d=<K>
  cleared 0.94 (<COV>); binomial × d=<L> at <COV> and
  binomial × d=<M> at <COV> remain `partial` with diagnostic
  evidence. Failure-rate gates within thresholds. Other
  families' status unchanged from M3.3 production-grid
  evidence (2026-05-19). |
```

### 5.3 If any binomial cell hits Outcome C

```text
| CI-08 | `coverage_study()` ≥ 94 % empirical coverage gate
  (PR #120) | `partial` (M3.3b r200 binomial slice did not
  fully clear admission gates) |
  (same evidence paths) |
  M3.3b r200 2026-05-NN: binomial × d=<K> failed the
  admission floor at <COV> OR <GATE> exceeded threshold (see
  audit). Cells that did clear are recorded in note but not
  promoted because per Design 50 §5 the row's promotion claim
  must align with the cell list; mixed-cell rollup stays
  `partial` until a clean slice runs. |
```

### 5.4 Citation requirements (all outcomes)

The CI-08 evidence cell must cite:

- the GHA run ID (`Actions run <RUN_ID>`) with retention days;
- the per-cell RDS artifact paths in `dev/precomputed/`;
- the audit memo path (NEW under `docs/dev-log/audits/`)
  with the cell × trait coverage table, failure ledger, and
  one-sided-miss check;
- the patched DGP attribution (PR #263 / #264) to ensure the
  evidence is read with the post-2026-05-25 DGP.

## 6. Pre-draft text — CI-10

CI-10 r200 scope under Option B touches mixed-family d=2
only. CI-10's promotion is therefore narrower than CI-08's;
the row should not generalise to mixed d=1 / d=3.

### 6.1 If mixed × d=2 hits Outcome A

```text
| CI-10 | profile / Wald / bootstrap on mixed-family fits |
  `covered` for mixed-family × d=2 on target
  `Sigma_unit_diag`; `partial` for mixed-family × d ∈ {1, 3}
  and broader mixed-family combinations |
  `test-confint-bootstrap.R`;
  `dev/precomputed/m3-r200-mixed-d2.rds`
  (Actions run `<RUN_ID>`, retention <DAYS> days);
  audit
  `docs/dev-log/audits/2026-05-NN-m3-r200-binomial-promotion.md` |
  M3.3b r200 promotion 2026-05-NN: mixed-family × d=2
  empirical coverage on `Sigma_unit_diag` at <COV> ≥ 0.94
  under patched DGP, with fit-failure rate ≤ 30%
  (Design 50 §5 mixed carve-out), CI-missing ≤ 10%,
  bootstrap-failure rate within family-specific limit, no
  one-sided miss > 80%, and `pilot_status == PASS_TO_SCALE`
  retained from PR #266. Mixed × d=1 (ratio 1.08, cov 0.82)
  and mixed × d=3 (ratio 1.03, cov 0.83) not re-dispatched
  in this slice and stay `partial`. |
```

### 6.2 If mixed × d=2 hits Outcome B

```text
| CI-10 | profile / Wald / bootstrap on mixed-family fits |
  `partial` (mixed × d=2 cleared 0.90 admission floor at
  r200 but not 0.94 promotion gate) |
  (same evidence paths) |
  M3.3b r200 partial 2026-05-NN: mixed × d=2 at <COV> ≥ 0.90
  admission floor but below 0.94 promotion gate.
  Failure-rate gates within thresholds. Status remains
  `partial`; promotion would require larger N or a different
  scope choice. |
```

### 6.3 If mixed × d=2 hits Outcome C

```text
| CI-10 | profile / Wald / bootstrap on mixed-family fits |
  `partial` (M3.3b r200 mixed × d=2 did not clear admission
  gates) |
  (same evidence paths) |
  M3.3b r200 2026-05-NN: mixed × d=2 failed at <COV> or
  <GATE> exceeded threshold (see audit). Row stays
  `partial`. |
```

## 7. Procedure when r200 results land

1. **r200 dispatch completes.** Codex / Ada / Grace runs the
   Option B 4-cell dispatch after the workflow-plumbing PR
   has landed and after maintainer authorisation. The GHA
   actions URL + per-cell RDS artifact list is captured.
2. **Per-cell review.** Following the post-run artifact
   review checklist from the r200 readiness review (PR #268
   audit `2026-05-25-r200-readiness-review.md` §"Post-run
   artifact review checklist"), each cell is classified into
   Outcome A / B / C against the §3 thresholds. Failed fits
   and missing intervals stay in the long grid; they do not
   disappear into summaries.
3. **NEW audit memo** under `docs/dev-log/audits/` is written:
   `2026-05-NN-m3-r200-binomial-promotion.md`. It records:
   per-cell coverage, IQR, miss-side, failure ledger,
   `pdHess` status, run URL, RDS paths, retention days,
   patched-DGP attribution, and the per-cell Outcome A/B/C
   verdict.
4. **Register-edit PR** opens with the row text from §5
   and §6 above, populated with the actual `<COV*>`,
   `<RUN_ID>`, `<K>/<L>/<M>` values. Rose pre-publish audit
   on the wording before merge. No other rows move in the
   same PR.
5. **Roadmap tick** in the after-task report for the
   register-edit PR: which rows changed status, with
   evidence path.

## 8. Honesty rules baked into the templates

- **Cell-scoped promotion text.** Every "covered" claim in §5
  and §6 names the specific cells; no row generalises beyond
  the dispatched scope. Per Design 50 §9.
- **Patched-DGP attribution.** Every outcome's note cites
  PR #263 / #264 so future readers do not confuse pre-patch
  and post-patch evidence.
- **Preserved partial cells.** Every outcome's note
  explicitly names the cells that did not move, so the row
  retains scope clarity.
- **Failure-rate gates checked.** Every covered outcome
  states that the secondary gates (fit-fail, CI-miss,
  bootstrap-fail, one-sided-miss) were within thresholds.
- **No generalisation across families.** A binomial-cell
  promotion in CI-08 does not move nbinom2 or ordinal-probit
  rows. A mixed × d=2 promotion in CI-10 does not move
  mixed × d=1 or d=3. The note history preserves the prior
  M3.3 evidence.
- **No retraction of prior caveat language.** The 2026-05-19
  M3.3 evidence and the Design 50 admission rule stay in
  the note's history; they are not deleted.

## 9. Cross-references

- [Design 50 §5 + §9](../../design/50-m3-3b-surface-admission.md)
  — admission thresholds, promotion rule, status-change rule.
- [`2026-05-25-m3-r200-dispatch-plan.md`](2026-05-25-m3-r200-dispatch-plan.md)
  — dispatch plan + scope options (Option B recommended).
- [`2026-05-25-m3-postpatch-rerun.md`](2026-05-25-m3-postpatch-rerun.md)
  — r10 post-patch evidence; binomial × d=2 + mixed × d=2 at
  `PASS_TO_SCALE`.
- [Design 42](../../design/42-m3-dgp-grid.md) — patched DGP
  rule (binomial-`psi` zeroing, 2026-05-25).
- [`2026-05-25-jason-cross-package-binomial-sigma-scout.md`](2026-05-25-jason-cross-package-binomial-sigma-scout.md)
  — DGP attribution evidence for PR #263 / #264.
- [PR #268 audit `2026-05-25-r200-readiness-review.md`](https://github.com/itchyshin/gllvmTMB/pull/268/files)
  — workflow-plumbing prerequisite + post-run review
  checklist.

— Shannon (drafter), Rose (scope honesty), Fisher
(inference policy).
