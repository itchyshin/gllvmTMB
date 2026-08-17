# After Task: Poisson W=diag(mu) G0 paste card

**Branch**: `docs/mspl-poisson-W-G0`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Ranga / Rose / Fisher
**Workspace**: `/private/tmp/gllvmtmb-mspl-poisson-w-g0`

## 1. Goal

File a short UNSIGNED G0 paste card so Shinichi can choose KEEP /
REPLACE \(W_*\) / PARK SE doors for the live Poisson GLM-outer
\(W=\operatorname{diag}(\mu)\) atom documented in #1064. Docs only.
No tape replace.

## 2. Implemented

- Research card
  `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md`
  with three paste-ready lines and Ranga's one-sided flag
  (\(W=\mu\) is \(0/+\infty\); soft Jeffreys rewards \(+\infty\);
  \(Q_0\) is the reporting target; \(W_*\) before more SE doors).
- Check-log prepend for this sitting.

No `R/`, `src/`, registry, NEWS, or admit flip.

## 3. Files Changed

- `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (new)
- `docs/dev-log/after-task/2026-08-17-mspl-poisson-W-G0.md` (this file)
- `docs/dev-log/check-log.md` (prepend)

## 3a. Decisions and Rejected Alternatives

- **Decision:** three paste lines only (KEEP / REPLACE / PARK SE
  doors), not a long B1-style brief. **Rationale:** #1064 already
  holds the measurement; this card is the G0 menu. **Rejected:**
  execute REPLACE in this PR. **Confidence:** high.
- **Decision:** recommend Ranga's order (PARK SE doors until KEEP
  or REPLACE) without signing for Shinichi. **Rationale:** G0 is
  unsigned until he pastes. **Rejected:** auto-sign PARK.
  **Confidence:** high.

## 4. Checks Run

```sh
rg -n 'KEEP|REPLACE|PARK SE doors|Ranga|W=\\\\operatorname|one-sided' \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
rg -n 'src/|se=TRUE|NEWS covered|admitted' \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
# expect: no implementation claim; se=TRUE / NEWS / admitted only as fences
```

Not run: `devtools::test()`, `--as-cran`, pkgdown (docs-only card).

## 5. Tests of the Tests

N/A — no testthat. Prophylactic: a later tape replace must not
land from this card; W7 in `test-mspl-W-onesided-oracles.R` still
pins Poisson `return eta`.

## 6. Consistency Audit

```
rg 'return eta' src/gllvmTMB.cpp
rg 'UNSIGNED|Paste one' docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
rg 'No src' docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md docs/dev-log/after-task/2026-08-17-mspl-poisson-W-G0.md
```

Verdict: live Poisson still `return eta`; card is UNSIGNED; no
`src/` edit in this PR.

## 7. Roadmap Tick

N/A — G0 paste card, no ROADMAP chip.

## 7a. GitHub Issue Ledger

No new issue. Evidence is merged
[#1064](https://github.com/itchyshin/gllvmTMB/pull/1064). This card
does not un-admit Poisson and does not open a tape-replace issue
until Shinichi pastes REPLACE.

## 8. What Did Not Go Smoothly

The estimator-programme worktree was dirty on
`cursor/mspl-poisson-admit-packet`. This slice used a fresh
worktree from `origin/main` so the card would not mix with that
packet.

## 9. Team Learning

**Ada:** G0 is a paste, not an overnight tape edit.
**Ranga:** one-sided \(W=\mu\) is the flag; \(Q_0\) reporting
target does not license an SE door on that atom.
**Rose:** #1064 already said “one-sidedly only”; admission did
not make \(W=\mu\) two-sided.
**Fisher:** toy-cell \(P_J\) rising with \(\beta_0\) is existence
risk, not a coverage number.

## 10. Known Limitations And Next Actions

- Card is UNSIGNED until Shinichi pastes one line.
- KEEP or REPLACE then needs a separate implementation PR.
- PARK SE doors is a freeze, not a tape edit.
- Next safe action: wait for the paste. Do not replace `return eta`
  from this sitting.
