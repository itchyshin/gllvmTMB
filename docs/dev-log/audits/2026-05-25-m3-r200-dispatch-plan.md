# M3 r200 dispatch plan — Curie + Fisher prep, not launched

**Date:** 2026-05-25
**Maintained by:** Curie (sim fidelity), Fisher (inference policy),
Rose (scope honesty), Shannon (coordination), Grace (CI / artefacts).
**Status:** **Plan only — no dispatch fired.** This memo prepares the
r200 dispatch on the cells that cleared §5 admission at r10 under the
patched DGP. It does not authorise the run. The maintainer authorises
the dispatch; this memo defines what would fire if they do.

**Backed by:**
- Design 50 §3 (estimand contract) + §5 (admission floor) + §9
  (no-status-change-without-evidence).
- Post-patch r10 rerun memo
  [`audits/2026-05-25-m3-postpatch-rerun.md`](./2026-05-25-m3-postpatch-rerun.md).
- Validation-debt rows CI-08 and CI-10 in
  [`docs/design/35-validation-debt-register.md`](../../design/35-validation-debt-register.md).
- Workflow file `.github/workflows/m3-production-grid.yaml`.

## 1. Why CI-08 / CI-10 must remain `partial` until r200 lands

The post-patch r10 rerun (run 26412130690) showed two cells hitting
Design 50 §5 `PASS_TO_SCALE`:

- **binomial × d=2**: median ratio 0.86, coverage on `Sigma_unit[tt]`
  0.94.
- **mixed × d=2**: median ratio 1.07, coverage 0.92.

These are diagnostic-only results at n_reps = 10. Per the Design 50
§5 contract, an r10 result with `PASS_TO_SCALE` only authorises an
r50 pilot, not promotion. Per Design 50 §9, register status moves
only when evidence actually changes status. **The promotion target
is empirical coverage ≥ 0.94 on `Sigma_unit[tt]` at R = 200** (Design
50 §5), with the §5 failure-rate and one-sided-miss gates also clean.

Fisher (2026-05-25): r10 has MCSE on coverage ≈ ±15 pp. r200 has
MCSE ≈ ±1.7 pp. An r10 coverage of 0.94 is not statistically
distinguishable from 0.80 — it is suggestive of promotion-worthiness,
not evidence of it. The status change requires r200.

Rose (2026-05-25): if anyone proposes to promote CI-08 / CI-10 to
`covered` on r10 evidence alone, escalate to the maintainer with
this memo and Design 50 §9 cited. The post-patch rerun is
encouraging; it is not promotion.

## 2. Scope: which cells, why

Three options at increasing budget:

| Option | Cells | Expected wall (GHA, max-parallel = 5) | Rationale |
|---|---|---|---|
| **A — narrow** | binomial × d=2 + mixed × d=2 | ~2 h | Only the two §5 `PASS_TO_SCALE` cells from r10. Cheapest path to walking CI-08 / CI-10 from `partial` → `covered` if coverage holds at r200. **Requires a workflow YAML subset patch** (see §4). |
| **B — binomial-focused** *(recommended by Curie + Fisher)* | binomial × d ∈ {1, 2, 3} + mixed × d=2 | ~3 h | All three binomial cells were at coverage 0.92 / 0.94 / 0.92 at r10. r200 on all three answers the family-wide question, not just one d-slice. **Requires a workflow YAML subset patch.** |
| **C — full grid** | All 15 cells | ~5–10 h | No workflow change. Maintains parity with the r10 rerun for direct comparison. Spends compute on cells (Gaussian, nbinom2, ordinal-probit) that did not pass r10 and will not pass r200; spends compute on cells we already understand. |

**Curie + Fisher recommendation:** Option B. Three binomial cells
+ one mixed cell at r200 gives a defensible family-wide CI-08 / CI-10
promotion path. Option A would only let CI-08 / CI-10 promote on a
single d-slice claim, which the validation-debt register row notes
typically cover the keyword family, not a single d. Option C
spends compute on cells that diagnostic-only evidence already says
will fail r200 (e.g. ordinal-probit COMPUTE_FAIL by §6 design).

The plan below uses Option B. If the maintainer prefers A or C, the
command in §5 changes accordingly (Option A skips two matrix
entries; Option C reverts the workflow YAML edit and dispatches as-is).

## 3. Branch / worktree plan

Per the standing two-agent worktree rule (Shannon, 2026-05-25 on
coordination-board):

```
git worktree add -b agent/m3-r200-dispatch \
  "/Users/z3437171/Dropbox/Github Local/gllvmTMB-m3-r200-dispatch" \
  origin/main
```

The dispatch PR lives entirely in this worktree. It does **not**
share files with `agent/set-c-r200-prep` (the docs-only prep
branch this memo lives on), and it does not share files with
Codex's `codex/diagnostic-*` branches.

If Option A or B is chosen, the worktree commits a one-file edit
to `.github/workflows/m3-production-grid.yaml` (matrix subset).
If Option C is chosen, the worktree contains no file edits; the
PR is purely the `gh workflow run` invocation + the result-review
memo.

## 4. Workflow YAML subset patch (Options A and B only)

The current matrix is:

```yaml
matrix:
  family: [gaussian, binomial, nbinom2, ordinal_probit, mixed]
  d: [1, 2, 3]
```

Option A patch (binomial × d=2 + mixed × d=2):

```yaml
matrix:
  include:
    - family: binomial
      d: 2
    - family: mixed
      d: 2
```

Option B patch (binomial × d ∈ {1,2,3} + mixed × d=2):

```yaml
matrix:
  include:
    - family: binomial
      d: 1
    - family: binomial
      d: 2
    - family: binomial
      d: 3
    - family: mixed
      d: 2
```

The patch is a small workflow-file edit on the r200 dispatch
branch only — it must not merge to main (Grace, 2026-05-25). The
intended pattern: open the dispatch PR with the patch, run the
workflow from the PR branch via `gh workflow run --ref
agent/m3-r200-dispatch`, then close the PR without merging once
the run completes and the result memo is committed. Alternatively
the maintainer can revert the patch as the last commit before
merging the result-memo PR to main.

## 5. Exact dispatch command

After the worktree is set up and (for A or B) the YAML subset
patch is committed and pushed:

```bash
gh workflow run "M3 production grid" \
  --ref agent/m3-r200-dispatch \
  -f n_reps=200 \
  -f init_strategy=single_trait_warmup \
  -f targets=psi,Sigma_unit_diag \
  -f n_boot=25 \
  -f seed_base=20260526 \
  -f retention_days=30
```

Notes on each input:

- `n_reps=200` — the promotion threshold per Design 50 §5.
- `init_strategy=single_trait_warmup` — matches the r10 rerun and
  PR #182's M3.4 warm-start + phi-clamp lane.
- `targets=psi,Sigma_unit_diag` — keep both. `Sigma_unit_diag` is
  the primary promotion target; `psi` stays as a diagnostic per
  Design 50 §3.
- `n_boot=25` — same as r10 rerun. Sufficient for non-degenerate
  percentile CIs; the §5 bootstrap-failure rate gate is on
  bootstrap-attempt failure, not on `n_boot` size.
- `seed_base=20260526` — **fresh value**, distinct from all prior
  M3 dispatches (`20260517` production, `20260524` smoke, `20260525`
  r10 rerun). Curie (2026-05-25): seed collisions create
  pseudo-replication between independent runs.
- `retention_days=30` — longer than the standard 14 because the
  r200 evidence has to remain accessible while the result memo +
  validation-debt register update PR are reviewed. Grace
  (2026-05-25): 30 days fits comfortably under GitHub Actions
  artefact storage retention defaults.

## 6. Expected artefacts (per cell)

For each matrix cell, the workflow uploads two RDS files:

- `m3-coverage-<family>-d<d>-grid.rds` — long grid: one row per
  (rep × trait), all Design 50 §3 columns + fit ledger + interval
  ledger.
- `m3-coverage-<family>-d<d>-summary.rds` — summary table: one row
  per cell with median estimate, coverage, fit-fail rate,
  bootstrap-fail rate, miss-side breakdown, `pilot_status`.

For Option B (4 cells), the run produces 8 RDS files total
(~10–50 MB cumulative). Option A produces 4 files; Option C
produces 30 files.

The retention is set on the workflow side; downloading after a
successful run is a one-liner:

```bash
gh run download <RUN_ID> --dir dev/precomputed/m3-r200-<date>/
```

## 7. Promotion rule (Design 50 §5 codified)

A cell promotes the corresponding validation-debt row from `partial`
to `covered` if **all** of:

1. **Empirical coverage on `Sigma_unit[tt]` ≥ 0.94** (the Design
   50 §5 r200 promotion gate; the r50 pilot floor is 0.90, the
   r200 promotion gate is 0.94).
2. **CI-missing rate ≤ 10 %**.
3. **Fit-failure rate ≤ 20 %** (≤ 30 % for `mixed`).
4. **Bootstrap-failure rate ≤ the same family-specific failure
   limit**.
5. **No one-sided miss pattern** (≥ 80 % of misses on one side
   triggers re-audit, not promotion).
6. The long-grid artefact contains the Design 50 §3 columns
   (`target`, `ci_method`, `ci_level`, `fit_phi_mode`,
   `link_residual`, `n_boot`, `n_cores_boot`, `seed_base`,
   `scenario`) for every row.

Status updates after the run:

- If binomial × d ∈ {1,2,3} all clear gate (Option B): **CI-08
  walks `partial` → `covered`** for the binomial-family slice of
  the empirical coverage gate. The row notes the d-slice and
  family explicitly; it does not silently generalise to nbinom2 or
  ordinal-probit (those cells were not in the r200 dispatch and
  remain `partial`).
- If mixed × d=2 clears gate: **CI-10 walks `partial` → `covered`
  for d=2**, with the row notes naming the d-slice. CI-10 for
  d ∈ {1, 3} stays `partial` (no r200 evidence on those cells).
- If any cell fails gate: validation-debt row stays `partial`; the
  result memo records the failure-mode (which gate it missed) and
  proposes the next slice (typically: longer `n_reps`, larger
  `n_boot`, or a fit-health diagnostic).

Rose (2026-05-25): the register update PR must cite the run URL,
artefact paths, and the specific cell that cleared each gate. Do
not roll up the per-cell evidence into a family-wide claim.

## 8. Hard boundaries

- **No dispatch until maintainer authorises.** This memo is a plan.
- **No premature register edit.** Even if Option B fires and all
  four cells clear gate, the register edit is a separate PR after
  the result memo lands.
- **No subset of the matrix patch merged to main.** The
  workflow YAML stays at the full 15-cell matrix on main; subset
  patches live only on the dispatch branch.
- **No edit to `R/diagnose.R`, `tests/testthat/test-sanity-multi.R`,
  `ROADMAP.md`, `docs/dev-log/check-log.md`, or
  `docs/dev-log/after-task/`** as part of this plan (per the
  maintainer's lane-assignment list, 2026-05-24).
- **No silent scope expansion.** A binomial r200 result does not
  authorise nbinom2 / ordinal-probit r200 conclusions. A d=2 r200
  result does not authorise d ∈ {1, 3} conclusions.
- **The Scenario A binomial signal stays attributed to the m3-grid
  DGP**, not to engine code in `#257 / #260 / #261`. The r200 run
  is verifying the engine on a corrected DGP; it is not relitigating
  the root-cause attribution.

## 9. What this memo does NOT do

- Does not fire any GHA workflow.
- Does not edit the M3 production-grid workflow YAML.
- Does not change any validation-debt register row.
- Does not change CI-08 / CI-10 status — they stay `partial`
  until and unless the r200 run completes and Design 50 §5 gates
  clear cell-by-cell.
- Does not touch joint-sdm.Rmd or any other article.
- Does not touch `R/*`, `src/*`, `NAMESPACE`, `DESCRIPTION`,
  `inst/extdata/*`, or any production user-facing surface.

— Curie + Fisher (drafted), Rose (scope-honesty signed off),
   Shannon (coordination), Grace (CI / artefacts noted)
