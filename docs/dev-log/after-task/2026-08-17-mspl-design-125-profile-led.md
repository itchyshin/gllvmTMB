# After Task: Design 125 claim + S2 ADEMP (profile-led MSPL CI) — C1

**Branch**: `claude/lane-mspl-profile-led-ci`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Rose / Fisher / Shannon
**Workspace**: `/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`

## 1. Goal

Close **C1** (after-task + Cursor handover refresh) for the Design **125**
profile-led MSPL intervals lane: pin claim SHAs, Confirm-in-ref, S2 file,
#1077 draft fence, and Poisson W card status so the next sitting does not
rediscover state from overnight chat.

## 2. Implemented

| Item | State | Evidence |
|---|---|---|
| Design 125 path | claimed @ `b68b20b4`; programme stub **APPROVED** | `docs/design/125-mspl-profile-led-intervals.md` |
| Triad Confirm | **SIGNED** | Confirm-in-ref **`7de94fc7`**; card `2026-08-17-mspl-ci-wald-plus-profile.md` |
| S2 ADEMP pre-reg | **SIGNED** (sibling finished) | `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` |
| #1077 | **still draft** | tip `fb44d7b5`; Confirm / Design APPROVED ≠ undraft |
| Poisson W card | **UNSIGNED** | `2026-08-17-mspl-poisson-W-G0.md` Status line; silent default = PARK SE doors; do **not** invent KEEP/REPLACE or flip Status without paste |
| Decision queue | **SIGNED** G1–G4e | `LOOP/decision-queue.md` (G1 PARK SE doors operational; card stays UNSIGNED until KEEP/REPLACE) |
| NEXT (live LOOP) | V1 → C1; G2 OPEN-READY-PR | `LOOP/checkpoint.md` — **not** H1; **not** undraft #1077 |

No `R/`, `src/`, registry, NEWS, public `se=TRUE` / `confint`, Totoro,
Design 118 edits, or #1077 undraft.

## 3. Files Changed (this C1 sitting)

- `docs/dev-log/after-task/2026-08-17-mspl-design-125-profile-led.md` (this file)
- `docs/dev-log/handover/2026-08-17-cursor-handover.md` (OWED / mission-control)
- `docs/dev-log/check-log.md` (prepend)

Cited (sibling / earlier commits, not rewritten here):

- `docs/design/125-mspl-profile-led-intervals.md` @ `b68b20b4`
- `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` (S2)
- `LOOP/checkpoint.md`, `LOOP/arcs.md`, `LOOP/decision-queue.md`

## 3a. Decisions and Rejected Alternatives

- **Decision:** treat Poisson W **card Status** as authoritative (**UNSIGNED**).
  **Rationale:** Rose notes `8907c8c7` / `6ee2a284`; Design 125 § still says
  card UNSIGNED; G1 PARK is operational silent default. **Rejected:** flipping
  card to SIGNED without KEEP/REPLACE paste. **Confidence:** high.
- **Decision:** #1077 stays draft despite Design APPROVED + ADEMP SIGNED.
  **Rationale:** G4c FORK-DEFER + G3 WAIT. **Rejected:** undraft. **Confidence:** high.
- **Decision:** C1 docs only; do not open the G2 non-draft PR in this commit.
  **Rationale:** user asked scoped handover/after-task; no push. **Rejected:**
  opening PR here. **Confidence:** high.

## 4. Checks Run

```sh
test -f docs/design/125-mspl-profile-led-intervals.md
test -f docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
git rev-parse --short b68b20b4   # expect b68b20b4
git rev-parse --short 7de94fc7   # expect 7de94fc7
rg -n '^\*\*Status:\*\*' docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
rg -n 'APPROVED|b68b20b4|#1077|UNSIGNED' docs/design/125-mspl-profile-led-intervals.md
rg -n 'SIGNED|UNSIGNED|b68b20b4|7de94fc7|#1077|S3|G2' \
  docs/dev-log/after-task/2026-08-17-mspl-design-125-profile-led.md \
  docs/dev-log/handover/2026-08-17-cursor-handover.md \
  LOOP/checkpoint.md
# deliberately not run: undraft #1077, confint, Totoro, Design 118 edits, push
```

## 5. Tests of the Tests

N/A — docs-only; no testthat.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| Design path + claim `b68b20b4` | present |
| Confirm ref `7de94fc7` | present |
| #1077 still draft | consistent |
| Poisson W card Status UNSIGNED | consistent with card + Rose notes |
| S2 ADEMP file present | cited |

## 7. Roadmap Tick

N/A — docs C1; no ROADMAP chip.

## 7a. GitHub Issue Ledger

No new issue. Draft PR
[#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) remains draft —
this sitting does **not** undraft it. G2 (OPEN-READY-PR) is a separate
docs PR of Design 125 + Confirm + LOOP kit, not #1077.

## 8. What Did Not Go Smoothly

Sibling advanced S2→APPROVED/SIGNED and S4/V1 while C1 drafted; LOOP tip
moved under this sitting. Handover OWED was rewritten to live
`LOOP/checkpoint.md` rather than freezing “S2 TBD”. A parallel check-log
line briefly claimed Poisson W “SIGNED PARK” while the card Status stayed
UNSIGNED — C1 treats the **card** as authoritative.

## 9. Team Learning

- **Ada:** claim SHA `b68b20b4` is durable; APPROVED is a later Status flip.
- **Rose:** UNSIGNED Status line ≠ “no PARK default”; do not invent SIGNED.
- **Fisher:** ADEMP SIGNED ≠ campaign launch ≠ undraft #1077.
- **Shannon:** scope-stage C1 files only; sibling owns LOOP/prereg races.

## 10. Known Limitations And Next Actions

- **#1077** stays draft tip `fb44d7b5`.
- Poisson W **card** stays **UNSIGNED** (silent default PARK SE doors).
- **NEXT (LOOP):** finish V1 if needed → open **non-draft docs PR** (G2);
  do **not** start H1; do **not** undraft #1077; do **not** Totoro /
  public `se=TRUE`.
