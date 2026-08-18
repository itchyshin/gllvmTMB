# After Task: Design 125 fork-B L1 ADEMP harness + local smoke

**Branch**: `cursor/mspl-forkB-l1-smoke-20260818`  
**Date**: `2026-08-18`  
**Roles (engaged)**: Curie, Fisher, Rose, Grace

## 1. Goal

Give the L1 local smoke a named harness that reports ADEMP dual coverage,
Wilson intervals, availability, and typed refusal — and either record L1
numbers on one anchor cell or stop as blocked-on-L0. Public doors stay closed.

## 2. Implemented

`dev/mspl-forkB-l1-ademp.R` is the L1 measurement harness. If the loaded
package has no `tape=` argument on `.gllvmTMB_mspl_profile_feasibility()`,
`mspl_forkB_l1_run_cell()` returns `status = "blocked-on-L0"` and does not
walk fork A as a substitute. Against the L0 worktree (PR #1126, not then on
`main`) a 50-rep local smoke on `L1-anchor-n80-T8` recorded availability 1,
refusal 0, \(\widehat{\mathrm{cov}}_{\mathrm{eff}}=0.88\), Wilson
[0.762, 0.944], L1 gate PASS. `calibrated = FALSE`; `public_confint = refused`;
`coverage_claim = none`.

## 3. Files Changed

- `dev/mspl-forkB-l1-ademp.R` — harness
- `dev/mspl-forkB-l1-smoke.R` — local runner (`--pkg=` can point at L0)
- `tests/testthat/test-mspl-forkB-l1-ademp-harness.R` — Wilson / refusal / L0 gate
- `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md` — receipt
- `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.rds` — 50-row object
- `docs/dev-log/after-task/2026-08-18-mspl-forkB-l1-harness.md` — this file
- `docs/dev-log/check-log.md` — this sitting

Not touched: `R/`, `src/`, `NEWS.md`, register, #1077, `LOOP/` (REPLACE GOAL_MET).

## 3a. Decisions and Rejected Alternatives

- **Decision:** E1 only. **Rationale:** the probe still refuses non-`b_fix`
  coordinates. **Rejected:** inventing an E2 walk. **Confidence:** high.
- **Decision:** treat “Wilson not entirely below 0.80” as Wilson *upper* ≥ 0.80.
  **Rationale:** that is the ADEMP sentence; the lower bound here is 0.762.
  **Rejected:** requiring Wilson lower ≥ 0.80 (would FAIL this cell). **Confidence:** high.
- **Decision:** measure against the L0 worktree rather than wait for #1126 to
  merge. **Rationale:** L1’s job is numbers or blocked-on-L0; L0 was measurable
  locally. **Rejected:** silent fork-A substitute. **Confidence:** high.

## 4. Checks Run

```sh
devtools::test(filter = "mspl-forkB-l1-ademp-harness")
# FAIL 0 | WARN 0 | SKIP 0 | PASS 30

Rscript --vanilla dev/mspl-forkB-l1-smoke.R --n_rep=1 --cell=L1-anchor-n40-T4 \
  --pkg=$HOME/local-scratch/lanes/gllvmTMB-mspl-forkB-L0 --no-write
# 1-rep timing 1.0 s; tape=Q_0 fork=B confirmed on a separate probe

Rscript --vanilla dev/mspl-forkB-l1-smoke.R --n_rep=50 --cell=L1-anchor-n80-T8 \
  --pkg=$HOME/local-scratch/lanes/gllvmTMB-mspl-forkB-L0 \
  --out=docs/dev-log/research
# 95.1 s; L1-PASS; numbers in the receipt

rg -n "se = TRUE|NEWS covered|MSPL-04" \
  dev/mspl-forkB-l1-ademp.R \
  docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md \
  docs/dev-log/after-task/2026-08-18-mspl-forkB-l1-harness.md
# no public-claim hits (MSPL-04 only as still blocked)

# deliberately not run: Totoro, T*, public se/vcov/confint, undraft #1077,
# NEWS covered, git add -A, isdm-package-recovery, full devtools::test()
```

## 5. Tests of the Tests

- Wilson 20/50 is entirely below 0.80 (upper < 0.80) — would catch a gate that
  always PASSes.
- All-miss rows fail `l1_wilson_eff_not_below_080`.
- R-SAT is dropped from the availability denominator and still priced in
  `cov_eff`.
- On main (no `tape=`), `mspl_forkB_l1_run_cell()` is `blocked-on-L0`.

## 6. Consistency Audit

| pattern | verdict |
|---|---|
| `se = TRUE` as a shipping claim | absent |
| `NEWS covered` | absent |
| `MSPL-04` flipped off `blocked` | absent; receipt says still blocked |
| Totoro campaign | receipt says not run |
| #1077 undraft | not touched (`gh pr view 1077 --json isDraft` left for the L0 lane) |

## 7. Roadmap Tick

N/A — no ROADMAP row; Design 125 L1 is a local ADEMP gate only.

## 7a. GitHub Issue Ledger

No relevant open issue closed. Sibling L0 plumbing is PR #1126. #1077 stays draft.

## 8. What Did Not Go Smoothly

L0 was not on `main` when L1 ran. The harness is correct on main (blocked-on-L0);
the numbers required `load_all()` of the L0 worktree. Re-run after #1126 merges
before treating the 0.88 figure as a `main`-reproducible receipt.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie.** The harness tests the gate arithmetic without a live 50-rep fit in
CI. That is the right split: CI stays cheap; the smoke stays local.

**Fisher.** Dual coverage plus Wilson on both \(\mathrm{cov}_{\mathrm{ret}}\) and
\(\mathrm{cov}_{\mathrm{eff}}\) is what ADEMP asked for. Passing L1 with
0.88 and a Wilson lower of 0.762 is not “coverage looks like 0.95.”

**Rose.** The easy cheat was walking fork A when `tape=` was missing. The
harness refuses that.

**Grace.** No Totoro, no Actions campaign artifact, no NEWS.

## 10. Known Limitations And Next Actions

- E2 not measured.
- L2 (near-tail + multi-seed) not run.
- L0 (#1126) must merge before this receipt is reproducible from `main`.
- Do not escalate to Totoro on this cell. T\* numbers are still unsigned.
- Hard OUTs remain: no public `se` / `vcov` / `confint`, no undraft #1077,
  no MSPL-04 `covered`.
