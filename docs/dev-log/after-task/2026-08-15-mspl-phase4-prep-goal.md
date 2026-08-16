# After Task: MSPL Phase-4 prep-goal verification (#971–#976)

**Branch**: `cursor/mspl-phase4-prep-goal`
**Date**: `2026-08-15`
**Roles (engaged)**: Ada / Curie / Rose / Shannon
**Lane LOOP**: `docs/dev-log/lanes/cursor-mspl-phase4-prep-goal/LOOP/`

```text
🎯 GOAL
Solo: Cursor
Deliverable: Poisson + NB2 + NB1 + beta + Tweedie Phase-4 notes and oracles landed on stacked PRs; #971 closeout verified
HEADLINE: thicken count-family MSPL prep without admitting anyone
DEFER: admit, SE, NEWS covered, prepare widen, Totoro>30min, Codex interval lane
```

## 1. Goal

Verify the already-landed Phase-4 prep stack. Do not redo family
science. Do not merge. Do not admit.

## 2. Implemented

Nothing new in `src/` or `R/mspl.R`. This lane recorded independent
verifier counts, wrote the LOOP kit, and stopped at the human merge
gate.

| PR | URL | State | Measured | Status note |
|---|---|---|---|---|
| #971 | https://github.com/itchyshin/gllvmTMB/pull/971 | **MERGED** `cb126576` | **29/29 PASS (168 expects)**; TSV **64/64** | `src/`/`R/mspl.R` empty; Ubuntu CI pending at verify |
| #972 | https://github.com/itchyshin/gllvmTMB/pull/972 | OPEN | **102/102 PASS** | Poisson `planned`/`phase4_prep`; no defect |
| #973 | https://github.com/itchyshin/gllvmTMB/pull/973 | OPEN | **62/62** | Tweedie; “51” was wrong; wording `90a156cf` |
| #974 | https://github.com/itchyshin/gllvmTMB/pull/974 | OPEN | **72/72** | NB2 stays **excluded** |
| #975 | https://github.com/itchyshin/gllvmTMB/pull/975 | OPEN | **65/65** | beta; wording `daa76352` |
| #976 | https://github.com/itchyshin/gllvmTMB/pull/976 | OPEN | **68/68** | NB1; no `nbinom1` registry row |

Already done by family lanes (not redone here): notes + oracles on
#972–#976. This lane fixed nothing in family science. Tweedie and
beta wording fixes were pushed on those family branches, not here.

## 3. Files Changed

- `docs/dev-log/lanes/cursor-mspl-phase4-prep-goal/LOOP/{GOAL,arcs,checkpoint,ultra-plan}.md`
- `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/GOAL.md` (successor pointer only)
- `docs/dev-log/after-task/2026-08-15-mspl-phase4-prep-goal.md`
- `docs/dev-log/plan-actual/2026-08-15-mspl-phase4-prep-goal.md`
- `docs/dev-log/check-log.md` (this entry)

No NEWS, no register flip, no `R/mspl.R`, no `src/`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** record independent verifier counts as the A1–A6
  ledger; do not rebase #972–#976 onto `main`.
- **Rationale:** all five tips are CLEAN vs `origin/main` and only
  one commit behind (`cb126576`, the #971 merge). Content rebase is
  unnecessary. Force-push to `main` is forbidden.
- **Rejected:** agent-merge of #972–#976; retarget-from-agent;
  planned→admitted.
- **Confidence:** high on counts and merge-tree; CI on #971 merge
  commit was still pending.

## 4. Checks Run

```sh
gh pr view 971 --json state,mergedAt,mergeCommit
# MERGED 2026-08-15T16:51:21Z  cb126576  by itchyshin

gh pr checks 971
# ubuntu-latest (release)  pending
# merge-commit run: https://github.com/itchyshin/gllvmTMB/actions/runs/31896665218  pending

# TSV
# docs/dev-log/research/2026-08-15-mspl-gaussian-multiseed-point-grid.tsv
# rows=64 finite_TRUE=64

git diff -- src/ R/mspl.R
# empty (conductor)

# Independent verifier structured counts (authoritative for this closeout):
# #971  29/29 PASS (168 expects)
# #972  102/102 PASS
# #973  62/62
# #974  72/72
# #975  65/65
# #976  68/68

# File-derived expect_ counts (re-derive, especially Tweedie 62 vs 51):
# poisson #972 oracles  84 expect_ calls (reporter 102 — loops)
# tweedie               62 expect_   matches 62/62
# nbinom2               72 expect_   matches 72/72
# beta                  65 expect_   matches 65/65
# nbinom1               68 expect_   matches 68/68

git merge-tree --write-tree origin/main origin/cursor/mspl-phase4-{poisson,tweedie,nbinom2,beta,nbinom1}
# all CLEAN vs main; each 1 behind main = cb126576 only
```

## 5. Tests of the Tests

Prophylactic verification only. Family oracles already encode
boundary / refuse-Hirose / no-live-`estimator="mspl"` paths. This
lane did not add tests.

## 6. Consistency Audit

```sh
rg -n "fam_ids %in% c\\(0L, 1L\\)" R/mspl.R
# R/mspl.R:182  prepare fence unchanged on conductor and all five family tips

rg -n "status = \"planned\"|phase4_prep|nbinom2|nbinom1" R/mspl-registry.R
# poisson q1/q2 planned / phase4_prep
# nbinom2 remains excluded ("NB2 waits for Phase 4 after Poisson admission gate")
# no nbinom1 / tweedie / beta registry row

# Family PRs do not touch NEWS.md (git diff --stat vs point-continue)
```

Verdict: no NEWS “covered” for these families; no planned→admitted;
prepare still `{0,1}`.

## 7. Roadmap Tick

N/A — verification / prep only; no ROADMAP chip change.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. Work is the #971–#976
PR stack, not an issue closeout.

## 8. What Did Not Go Smoothly

- #971 merged while this GOAL still said “do not merge”; the merge
  was Shinichi’s, not this lane.
- One Tweedie report said 51; the test file and reporter are **62**.
- Family PRs still target the old stacked base
  `cursor/mspl-point-programme-continue`. They do **not** need a
  content rebase onto `main`, but a human merge-to-`main` needs the
  PR base retargeted.
- #974 `mergeState` flickered UNKNOWN then CLEAN.
- Leftover untracked family copies in the conductor were not staged.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** Verification lane, not a science rewrite. Stopped at merge.

**Curie.** Counts are reporter PASS / expect_ re-derives, not exit
codes. Tweedie 62 closes the 51 rumour.

**Rose.** Fence holds: no NEWS covered, no admit, prepare `{0,1}`.

**Shannon.** Family PRs remain stacked on the merged #971 branch.
Report retarget; do not rebase or force-push `main`.

## 10. Known Limitations And Next Actions

- Still **not admitted**: Poisson (planned only), NB2 (excluded),
  NB1 / beta / Tweedie (no registry row).
- No SE. No NEWS covered. Prepare not widened.
- 🔴 **Needs Shinichi:** retarget #972–#976 to `main` (CLEAN; 1
  behind = merge commit only), merge after CI; **still no admit**.
  Check #971 Ubuntu CI on `cb126576` before treating that merge as
  green.
