# After Task: Design 125 claim + S2 ADEMP pre-reg (profile-led MSPL CI)

**Branch**: `claude/lane-mspl-profile-led-ci`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Rose / Fisher / Shannon
**Workspace**: `/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`

## 1. Goal

Close the docs baton for **S1** (claim Design **125**) and record that
**S2** (ADEMP pre-registration draft) landed under that claim, so the
next sitting starts at **S3 ∥ S4** without rediscovering SHAs or
reopening B1 / Design 118 / #1077.

## 2. Implemented

| Item | State | Evidence |
|---|---|---|
| Design 125 path | claimed STUB | `docs/design/125-mspl-profile-led-intervals.md` |
| Claim SHA | **`b68b20b4`** | `docs(design): claim Design 125 profile-led MSPL intervals stub` |
| Triad Confirm | **SIGNED** | Confirm landed in commit **`7de94fc7`**; card `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` |
| S2 ADEMP pre-reg | **draft done** | `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` (commits `7bab0943` / `04c344fd`) |
| #1077 | **still draft** | tip `fb44d7b5`; **not** undrafted |
| Poisson W G0 | **UNSIGNED** | `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` |
| NEXT after S2 | **S3 ∥ S4** | `LOOP/checkpoint.md`, `LOOP/arcs.md` |

No `R/`, `src/`, registry, NEWS, public `se=TRUE` / `confint`, Totoro,
or Design 118 edits.

## 3. Files Changed (this after-task sitting)

- `docs/dev-log/after-task/2026-08-17-mspl-design-125-profile-led.md` (this file)
- `docs/dev-log/handover/2026-08-17-cursor-handover.md` (OWED / mission-control refresh)
- `docs/dev-log/check-log.md` (prepend)

Prior S1/S2 artifacts (already on this branch, cited not rewritten here):

- `docs/design/125-mspl-profile-led-intervals.md` @ `b68b20b4`
- `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`
- `LOOP/checkpoint.md`, `LOOP/arcs.md`

## 3a. Decisions and Rejected Alternatives

- **Decision:** keep Design **125** as the sole claim id for this
  construction. **Rationale:** lane_preflight NEXT FREE was 125;
  Design 124 already taken on other refs. **Rejected:** inventing a
  parallel design number. **Confidence:** high.
- **Decision:** leave #1077 draft and Poisson W UNSIGNED. **Rationale:**
  triad Confirm authorises *roles* only; undraft + SE doors need separate
  G0s. **Rejected:** undraft #1077 in this sitting. **Confidence:** high.
- **Decision:** NEXT = S3 (Poisson W chase / PARK SE doors note) ∥ S4
  (Rose fence), not live profile. **Rationale:** LOOP checkpoint after
  S2. **Rejected:** Totoro / public `confint`. **Confidence:** high.

## 4. Checks Run

```sh
test -f docs/design/125-mspl-profile-led-intervals.md
test -f docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
git rev-parse --short b68b20b4   # expect b68b20b4
git rev-parse --short 7de94fc7   # expect 7de94fc7
rg -n 'Status: STUB|Design 125|b68b20b4|#1077|MSPL-04' \
  docs/design/125-mspl-profile-led-intervals.md
rg -n 'Design id: \*\*125\*\*|UNSIGNED|#1077|S3.*S4' \
  docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
rg -n 'SIGNED|7de94fc7|Design 125|S2|S3|UNSIGNED|#1077' \
  docs/dev-log/handover/2026-08-17-cursor-handover.md \
  LOOP/checkpoint.md
# deliberately not run: undraft #1077, confint, Totoro, Design 118 edits, push
```

## 5. Tests of the Tests

N/A — docs-only; no testthat.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| Design path + claim `b68b20b4` | present in Design stub + LOOP + this report |
| Confirm ref `7de94fc7` | present in LOOP checkpoint + this report |
| #1077 draft / no undraft | consistent across Design, pre-reg, handover |
| Poisson W UNSIGNED | consistent; do not invent KEEP/REPLACE/PARK |
| NEXT after S2 = S3 ∥ S4 | LOOP checkpoint + arcs agree |

## 7. Roadmap Tick

N/A — docs claim + pre-reg draft; no ROADMAP chip.

## 7a. GitHub Issue Ledger

No new issue. Related open draft PR
[#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) inspected as
**still draft** — this sitting does **not** undraft it.

## 8. What Did Not Go Smoothly

Handover `2026-08-17-cursor-handover.md` still carried overnight
mission-control text that listed triad Confirm as UNSIGNED while the
Blockers table already said SIGNED — refreshed in the same sitting so
OWED matches live LOOP state (S1+S2 done; NEXT S3∥S4).

## 9. Team Learning

- **Ada:** Design number claimed by commit; do not race-claim 125 again.
- **Rose:** reader/handover surfaces must agree on SIGNED vs UNSIGNED;
  #1077 draft is a hard fence, not a soft TODO.
- **Fisher:** ADEMP draft ≠ signed pre-reg ≠ coverage campaign.
- **Shannon:** one lane (`claude/lane-mspl-profile-led-ci`); no
  `git add -A`; no push from this sitting.

## 10. Known Limitations And Next Actions

- Pre-reg and Design 125 remain **unsigned** / **STUB**.
- **Poisson W** stays **UNSIGNED** (default if silent: PARK further SE doors).
- **#1077** stays draft tip `fb44d7b5`.
- **NEXT:** **S3** (Poisson W UNSIGNED / PARK SE doors note) and/or
  **S4** Rose fence on S1–S2; then V1. No live profile, no Totoro, no
  public `se=TRUE` without separate G0s.
