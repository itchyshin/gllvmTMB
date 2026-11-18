# After Task: MSPL remaining-gap board (gllvmTMB only)

**Branch**: `cursor/mspl-remaining-gap-board`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Rose / Shannon / Fisher

## 1. Goal

Write a live family-by-family gap board so the next sitting can see
what is merge-wait vs needs-code vs needs-evidence, after Shinichi
redirected work onto gllvmTMB's own MSPL and parked drmTMB.

## 2. Implemented

- Census of all 17 `family_id`s against `origin/main` @ `af1edd2c`
  and the open sibling PRs (#974, #1003–#1005, #1007, #1014,
  #998–#1000, #995).
- Named the three families with **no** prep and **no** sibling PR:
  betabinomial, truncated_poisson + truncated_nbinom2, multinomial.
- Recorded the morning merge order and the admit / public-SE /
  Lane B fences.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-remaining-gap-board.md`
- `docs/dev-log/after-task/2026-08-16-mspl-remaining-gap-board.md`
- `docs/dev-log/check-log.md`

## 3a. Decisions and Rejected Alternatives

**Decision:** do not edit `R/mspl-registry.R` from this sitting's
new family preps. **Rationale:** #1003/#1004/#1007/#1014 already
own that file. **Rejected:** add planned rows now and rebase
through every sibling merge. **Confidence:** high.

## 4. Checks Run

```sh
git fetch origin
git log -1 --oneline origin/main
# af1edd2c

gh pr list --state open --limit 40
git show origin/main:R/mspl-registry.R | rg -n 'status = '
# admitted binomial / gaussian / poisson; excluded nbinom2; 0 planned
```

## 5. Tests of the Tests

N/A — docs-only coordination note.

## 6. Consistency Audit

```
rg -n 'admitted|planned|excluded' docs/dev-log/research/2026-08-16-mspl-remaining-gap-board.md
# verdict: board matches origin/main (0 planned rows) and names sibling PRs
rg -n 'NEWS covered|se=TRUE|Lane B' docs/dev-log/research/2026-08-16-mspl-remaining-gap-board.md
# verdict: fences stated
```

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is a census, not
a capability change.

## 8. What Did Not Go Smoothly

`origin/main` still has zero `planned` rows, so Mission Control's
"mostly planned" picture is the *open PR* surface. Easy to misread
if someone only looks at `R/mspl-registry.R` on main.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** next work is the three unowned families plus a merge-wait
drain, not drmTMB and not a new admit.
**Rose:** sibling registry PRs must land before anyone else edits
`R/mspl-registry.R`.
**Shannon:** expected-red SE pins (#998/#999/#1000) stay unmerged
until their doors exist.
**Fisher:** Poisson is admitted as experimental point only; #990
admit-evidence FAIL still stands.

## 10. Known Limitations And Next Actions

See the board's "Recommended next 3". This note will stale the
moment a sibling PR merges — re-run the rehydrate commands.
