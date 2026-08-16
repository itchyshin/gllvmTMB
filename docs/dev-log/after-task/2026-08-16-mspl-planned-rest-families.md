# After-task: planned-only registry rows for remaining Phase-4 families

**Date:** 2026-08-16
**Lane:** `cursor/mspl-planned-rest-families`
**Worktree:** `/private/tmp/gllvmtmb-mspl-planned-rest-families`
**Branch:** `cursor/mspl-planned-rest-families` from `origin/main` @ `3e18de94`
**Roles (engaged):** Ada / Curie / Rose / Shannon

## 1. Goal

Oracles for student / ordinal_probit / betabinomial / truncated
Poisson+NB2 / multinomial were already on `main` (#1005, #1023,
#1024, #1025) with **no** `planned` registry row. Add those rows
and retarget the tests that asserted absence. Not admission.

## 2. Implemented

Twelve ordinary `q=1,2` cells are now `status = "planned"`,
`evidence = "phase4_prep"`:

| family | link | atom in notes |
|---|---|---|
| `student` | identity | \(W=(\nu+1)/(\nu+3)/\sigma^2\) (mean-inert) |
| `ordinal_probit` | probit | \(W=\mathrm{E}[s_\eta^2]\); \(\psi\) pinned at 1 |
| `betabinomial` | logit | PMF-summed exact \(I_\eta\), not \(N\mu(1-\mu)\) |
| `truncated_poisson` | log | \(W=\mathrm{Var}(Y\mid Y\ge 1)\), not Poisson \(\mu\) |
| `truncated_nbinom2` | log | truncated exact \(I\), not \(W=\mu\varphi/(\varphi+\mu)\) |
| `multinomial` | logit | \(I=\mathrm{diag}(p)-pp^\top\) on \(K-1\) contrasts |

`.gllvmTMB_mspl_family_link_name()` now returns `"identity"` for
`family_id` 9 and `"log"` for 10/11 (was falling through to
Bernoulli `"logit"`).

No C++ tape. No prepare widen. No NEWS. No public `se=TRUE`.
`R/mspl.R` and `src/` untouched. Public door stays
`fam_ids %in% c(0L, 1L, 2L, 5L, 15L)`.

## 3. Files Changed

- `R/mspl-registry.R`
- `tests/testthat/test-mspl-registry.R`
- `tests/testthat/test-mspl-gaussian-heywood-oracles.R`
- `tests/testthat/test-mspl-student-phase4-oracles.R`
- `tests/testthat/test-mspl-ordinal-phase4-oracles.R`
- `tests/testthat/test-mspl-betabinomial-phase4-oracles.R` (header only)
- `tests/testthat/test-mspl-truncated-phase4-oracles.R` (header only)
- `tests/testthat/test-mspl-multinomial-phase4-oracles.R` (header only)
- `tests/testthat/test-mspl-fenced-family-tapes.R`
- `tests/testthat/test-zz-mspl-rest-family-prepare-fence.R`
- `docs/dev-log/after-task/2026-08-16-mspl-planned-rest-families.md` (this file)

Not touched: `R/mspl.R`, `src/`, NEWS, validation-debt register,
research notes (their "no registry row" status lines are now stale),
`docs/dev-log/check-log.md` (left to the B1 freeze/holdout sibling).

## 3a. Decisions and Rejected Alternatives

- **Decision:** planned rows only; keep the live prepare reject.
  **Rationale:** user fence — no admit, no public door, no `se=TRUE`.
  **Rejected:** nbinom-style `#1007` door.
- **Decision:** one PR for all six names. **Rationale:** same
  missing-row gap; one allowlist update. **Rejected:** per-family PRs.
- **Decision:** do not rewrite the five research notes. **Rationale:**
  keep the PR small; after-task records the stale status line.
  **Rejected:** a five-note status rewrite in the same slice.

## 4. Checks Run

See check-log entry of the same date. Targeted `testthat::test_file`
on the registry, S12/O11, rest-family fence, and Heywood allowlist.

## 5. Tests of the Tests

S12 and O11 previously failed if a planned row existed — that was
the proof those oracles owned the "no row" pin. They now fail if
the row is missing, admitted, or not `phase4_prep`. The rest-family
registry pin flipped the same way. Live `gllvmTMB(..., estimator =
"mspl")` rejects in `test-zz-mspl-rest-family-prepare-fence.R` still
prove the public door is closed.

## 6. Consistency Audit

```sh
rg -n 'fam_ids %in%' R/mspl.R
# c(0L, 1L, 2L, 5L, 15L) — unchanged

rg -n 'status = "admitted"' R/mspl-registry.R
# binomial / gaussian / poisson only

rg -n 'student|ordinal_probit|betabinomial|truncated_|multinomial' R/mspl-registry.R
# planned_rest only; no admitted rows
```

Verdict: planned rows do not widen the door.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is a registry
bookkeeping follow-on to already-merged oracle PRs #1005 / #1023 /
#1024 / #1025.

## 8. What Did Not Go Smoothly

`#1026` on `main` still asserted these six names had no planned
row. That pin had to flip in the same PR or CI would fail. The
dirty MSPL worktree could not take this edit; a fresh worktree
from `origin/main` was required.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Board-looks-finished still had a registry hole: oracles
without `planned` rows. Close the hole before any door.

**Curie.** Retarget the tests that encoded "no row" before adding
the row. S12, O11, and the rest-family registry pin were the
failure-before-fix.

**Rose.** Five research notes still say "No registry row". That is
now false. Next slice should one-line those status paragraphs if
anyone cites them.

**Shannon.** Shared `R/mspl-registry.R` lane-check hits were
already-merged doorfix refs (`#1003`–`#1026`), not a competing
unmerged planned-row implementation.

## 10. Known Limitations And Next Actions

Still missing: public door, C++ tape, admission, `se=TRUE`, and
any covered claim for these six families. Prepare still rejects
`family_id` 8/9/10/11/14/16. Research-note status lines are stale.
Do not treat a `planned` row as a theorem transfer from Poisson,
Bernoulli, or Gaussian Hirose.
