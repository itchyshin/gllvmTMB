# VA lane reconciliation: `origin/codex/va-gh-all-families` — 2026-08-17

## Context

`origin/codex/va-gh-all-families` (tip `f4c6e98c`, last touched 2026-08-07) has
been dormant since Mission Control was repointed to `origin/main`
(`docs/dev-log/check-log.md`, 2026-08-16 entry: *"That branch still carries
two unmerged VA Arc-2 doc commits — they are the VA lane's to land, and I
deliberately did not."*). Shinichi asked for the branch to be reconciled and
cleaned up. This audit is read-only on git history; it changes nothing on any
branch.

Reproduction commands (run from the worktree, branch `claude/design66-scoping-20260816`,
based on `origin/main`):

```
git merge-base origin/main origin/codex/va-gh-all-families
# -> 5bf18ab30d7034e1c90c383fb4621d916b3a48cd (2026-08-03)
git cherry origin/main origin/codex/va-gh-all-families | awk '{print $1}' | sort | uniq -c
# -> 175 "+"  (confirms the task brief's patch-id count)
git diff --name-status origin/main...origin/codex/va-gh-all-families   # 485 files, 436 A / 49 M vs merge-base
git diff --name-status origin/main origin/codex/va-gh-all-families -- $(branch-touched paths)
# -> 33 identical to main tip, 452 differ (411 absent from main entirely, 41 present-but-diverged)
```

## What landed

**The branch was already merged once, on purpose, up to a deliberate cut
point.** PR #949 ("VA Arc-1 scalar VA fence — path transplant") is merged to
main (`d7bee2fa`, referenced in `docs/dev-log/after-task/2026-08-07-va-arc1-merge-fence-transplant.md`
and `docs/dev-log/handover/2026-07-25-active-lane-split.md:114`). Its
inventory doc records the exact pins taken from this branch's own lineage:

- closeout `537e6da4` ("va: promote H7 GH across scalar families",
  2026-08-06 09:48) for the bulk of `R/`, `tests/`, `dev/va-speed/00-23`, etc.
- pre-PoisG `4435cd1e` specifically for `R/va-r3-proto.R`,
  `test-va-r3-prototype.R`, and `inst/tmb/gllvmTMB_va_r3.cpp`
- NEWS honesty `98839853`

`537e6da4` is a genuine ancestor of the dormant branch
(`git merge-base --is-ancestor 537e6da4 origin/codex/va-gh-all-families` →
true), confirmed by `git log --oneline 537e6da4..origin/codex/va-gh-all-families`
returning exactly **57 commits** — the true "unlanded" remainder, not 175.
The 175-vs-57 gap is exactly the patch-id artefact the task brief predicted:
the transplant was a **path-level reconstruction** (cherry-picking file
states, not literal commits), so patch-ids never match even though content
does.

Separately, commit `ae340bdd` on main (2026-08-09, "harden bounded 0.6
validation surface") independently ported the **substance** of the branch's
Arc-2 adjudication commit `7bf56c4a` into `docs/design/35-validation-debt-register.md`
(VA-06/09/12/13), citing `7bf56c4a` and the audit filenames by name/path —
see "Arc-2 adjudication status" below.

## What is genuinely absent (by class)

Comparing the 485 branch-touched files (relative to merge-base `5bf18ab3`)
directly against the **current** `origin/main` tip (`fe16d37a`, 2026-08-17):

| Class | Count | Meaning |
|---|---|---|
| (a) identical to main | 33 | byte-identical on both sides |
| (b) differs, main newer/superseding | ~444 | main was touched later than the branch on every one of these paths, and where checked the divergence is main moving on (bug fixes, doc rewrites, design-register updates, campaign synthesis) rather than the branch holding something main lacks |
| (c) differs, branch holds not-yet-landed content still worth keeping | 8 files (~1.3% of touched files) | listed below |

By top-level directory (452 non-identical files: 411 absent from main
entirely + 41 present on both but diverged):

| Dir | Absent from main | Diverged (present, differs) | Note |
|---|---|---|---|
| `dev/` | 221 | 5 | almost all `dev/va-speed/24-38`, `dev/va-usability/*`, `dev/va-gh-h7-campaign/*` — campaign scratch (`.rds`, `.txt` logs, numbered probe scripts) whose *findings* are already synthesized into `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` (on main) |
| `docs/` | 117 | 7 | `docs/dev-log/` (97) checkpoint/LOOP docs + `docs/design/` (20) unnumbered working notes, superseded by the numbered Design 108/110/117/123 docs that did land |
| `lanes/` | 70 | 0 | LOOP-kit checkpoint directories for sub-campaigns (`va-s1-binomials`, `va-s0b-exact`, etc.) — machinery, not deliverables |
| `tests/` | 2 | 3 | the 2 absent tests are `test-va-gh-h7-campaign.R` (campaign harness) and `test-va-poisg-expectation.R` (tests the rejected PoisG feature — see below) |
| `tools/` | 1 | 0 | **class (c)** — see below |
| `R/` | 0 | 15 | every file's `main` last-touch date is later than the branch's; see next section |
| `src/`-equivalent (`inst/tmb/`) | 0 | 1 | `gllvmTMB_va_r3.cpp` — see next section |
| `man/`, `NAMESPACE`, `NEWS.md`, `_pkgdown.yml`, `CLAUDE.md` | 0 | 9 | generated/prose files main has since regenerated/rewritten |

**Class (c) file list — the only content judged genuinely absent and worth
keeping:**

1. `tools/check-push-traps.sh` (53 lines, commit `9d560616`, 2026-08-04) — a
   small, self-contained guard against local branches that track
   `origin/main` and can `git push` straight onto it ("Found 2026-08-04: 43 of
   566 local branches tracked `origin/main`, and 16 of them were ahead of
   it"). No dependency on any other VA content. Confirmed absent:
   `git cat-file -e origin/main:tools/check-push-traps.sh` fails.
2. `docs/dev-log/handover/2026-08-04-claude-handover.md` — referenced by (1)
   as the source of that finding; also absent from main.
3. The **2026-08-05 "Containment record + scope note"** addendum inside
   `docs/design/85-highdim-nongaussian-va-formal-contract.md` (not the whole
   file — see "R/src question" note below on why the rest of that file's diff
   is not being recommended). This corrects a claim that is **still false on
   `origin/main` today**: main's copy of Design 85 (last touched 2026-07-20,
   pre-dating this correction) still reads *"The prototype remains internal,
   non-exported, and outside the shipped `gllvmTMB()` method surface"* — but
   `gllvmTMB()` has routed to it since **2026-07-31** via commit `8def9781`
   ("route `integration=\"va\"` from `gllvmTMB()` to the variational engine"),
   which **is** on main (`docs/dev-log/after-task/2026-07-31-va-integration-routing.md`
   cites it directly). The branch's addendum is the only place this
   contradiction is written down and fixed.
4–7. `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`,
   `.dcf`, `.md`, and `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-closeout.md`
   (266 lines) — the raw Arc-2 campaign artefacts. Not present on main
   (`git cat-file -e` fails for all four), **yet main's own validation-debt
   register cites the `.csv`/`.dcf`/`.md` triple by exact path** in VA-06,
   VA-09, and VA-13 (`docs/design/35-validation-debt-register.md`). Those
   citations are dangling on `main` today.
8. `dev/va-usability/A2-ATTENUATION.md` — cited by path in main's VA-13 row
   ("the nearest thing to Gate-3 evidence... is `dev/va-usability/A2-ATTENUATION.md`")
   but the whole `dev/va-usability/` directory is absent from main
   (`git ls-tree origin/main -- dev/va-usability/` returns nothing). Another
   dangling citation in main's own register.

## The R/ and src/ question specifically

**No.** Every one of the 15 diverging `R/` files and the 1 diverging
`inst/tmb/*.cpp` file has a `main` last-commit date strictly later than its
branch last-commit date:

```
R/families.R            main 2026-08-16 20:36  branch 2026-08-06 08:04
R/fit-multi.R            main 2026-08-16 20:36  branch 2026-08-06 09:48
R/gllvmTMB.R              main 2026-08-16 19:10  branch 2026-08-07 09:00
R/methods-gllvmTMB.R      main 2026-08-16 10:47  branch 2026-08-04 12:29
R/va-r3-proto.R           main 2026-08-15 22:36  branch 2026-08-07 09:00
inst/tmb/gllvmTMB_va_r3.cpp  main 2026-08-09 04:58  branch 2026-08-07 09:00
... (all 16 files show the same pattern)
```

`R/va-r3-proto.R` is the diagnostic case (121 diff lines). Diffing
`origin/main` against the branch tip shows a **two-way** divergence, both
resolved in main's favour:

- **Main has something the branch lacks**: a bug fix, issue #985, "scale the
  start-agreement tolerance by objective magnitude" (main commits `4f5e3f01`
  and `3bc91953`) — fixes a knife-edge CI flake (green on macOS, failing on
  ubuntu) that the branch's version does not have.
- **The branch has something main lacks**: a `"poisg"` VA evaluator
  (cloglog PoisG closed-form ELBO, commit `b53be434`). This is **not**
  stranded-and-wanted — it was **deliberately excluded** from the PR #949
  transplant, on evidence, and the decision is documented on main in
  `docs/dev-log/audits/2026-08-07-va-series-synthesis.md`: *"Λ→0 / Σ collapse
  at every n/p tested (ours + gllvm VA)... not a Σ estimator; keep cloglog
  auto on GH"* and `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-inventory.md`:
  *"PoisG feat `b53be434` — OUT of first PR"*. The two absent test files
  (`test-va-poisg-expectation.R`, part of `tests/`'s A-status count) exist
  only to test this excluded feature.

Conclusion: the `R/`/`src` divergence is **main pulling ahead with a bug fix
main independently made**, plus **a feature the branch has that was
evidence-rejected, not overlooked**. There is no stranded R/src capability.

## Arc-2 adjudication status

The branch's `docs: close VA H7 Arc 2 adjudication` (`7bf56c4a`, authored by
Shinichi directly, 2026-08-06 23:48) is **substantively on `origin/main`
already**, via `ae340bdd` (2026-08-09, "harden bounded 0.6 validation
surface"). Main's current `docs/design/35-validation-debt-register.md`
Section 15 rows VA-06, VA-09, VA-12, VA-13 all cite `Arc-2 closeout commit
7bf56c4a` by hash and carry the same headline numbers as the branch's own
commit:

- VA-06: 20 PASS / 16 FAIL (fixed-effect VA-Wald, 36-cell campaign)
- VA-09: 1 PASS / 24 FAIL / 11 INCONCLUSIVE (point-route recovery)
- VA-13: 15 PASS / 20 FAIL / 1 INCONCLUSIVE (latent posterior-SD)
- VA-12: qualitative "INCONCLUSIVE... fewer than 90% of seeds" language

`git log --all --oneline -S"UNCALIBRATED" -- docs/design/35-validation-debt-register.md`
confirms the branch's own CALIBRATED/UNCALIBRATED phrasing (in `7bf56c4a`
itself) never reached main — whoever wrote `ae340bdd` re-derived the summary
independently in PASS/FAIL language rather than merging the branch's file, so
the two copies read differently but report the same numbers.

**What main does NOT have**: the raw artefacts main's own register cites —
`docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.{csv,dcf,md}`,
the 266-line closeout narrative, and `dev/va-usability/A2-ATTENUATION.md`
(class-(c) items 4–8 above). The **adjudication verdict** is redundant to
port; the **backing files main's own citations point at** are not.

## VERDICT

**SALVAGE-8-FILES.** The branch is correctly dormant and its bulk (476 of
485 touched files, 98.4%) is either byte-identical to main, superseded by
later main work, campaign scratch already synthesized elsewhere, or a
deliberately evidence-rejected feature (PoisG). The remainder is not a
capability gap — it is eight small, low-risk documentation/tooling files that
back citations `main` already makes to them, plus one honesty correction
`main`'s own docs still need. This is not an engine or R/src recovery job.

## Recommended action for Shinichi

1. **Cherry-pick or manually port these 8 files** from
   `origin/codex/va-gh-all-families` onto `main` (small, additive, no `R/`/`src`
   risk):
   - `tools/check-push-traps.sh`
   - `docs/dev-log/handover/2026-08-04-claude-handover.md`
   - `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.csv`
   - `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.dcf`
   - `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-adjudication.md`
   - `docs/dev-log/audits/2026-08-07-va-gh-h7-arc2-totoro-closeout.md`
   - `dev/va-usability/A2-ATTENUATION.md`
   - the "Containment record + scope note, 2026-08-05" paragraph from
     `docs/design/85-highdim-nongaussian-va-formal-contract.md` (hand-merge
     this one hunk into main's copy; do not take the whole-file diff, since
     main's copy has not otherwise moved and the rest of the branch's diff
     is not evidenced as needed).
2. **After step 1 lands, delete `origin/codex/va-gh-all-families`.** Nothing
   else on it is wanted: `R/`, `src/`/`inst/tmb/`, `NAMESPACE`, `NEWS.md`,
   `man/`, `CLAUDE.md`, and the 41 other diverged files are all superseded by
   later main commits (every one checked has a later main touch-date); the
   985 remaining `dev/`, `docs/dev-log/`, and `lanes/` files are campaign
   scratch/checkpoints with no unique durable content; the two absent test
   files test the deliberately-excluded PoisG feature.
3. No `R/`/`src/` action needed — confirmed no code capability is stranded.
