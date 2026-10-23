# Session Handoff: LA-MSPL overnight arc → Design 125 profile-led CI

Meta: 2026-08-17 · AUTHOR=cursor · TARGET=cursor · overnight closeout +
Design 125 claim / S2 ADEMP draft
Worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`
(branch `claude/lane-mspl-profile-led-ci`; not Dropbox). Lane `LOOP/` is
in use for this `/goal` kit. `git add -A` was not used.

You are Cursor. Rehydrate from this file + `AGENTS.md` + live `git` +
`LOOP/checkpoint.md`. Classify every item **OWED · DONE · RETRACTED ·
PROTECTED** before mutating. Execute only **OWED**.

## Mission-control summary

| Field | Value |
|---|---|
| Repo | `itchyshin/gllvmTMB` |
| Tip for rehydrate | this branch tip (ahead of `origin/main`; re-fetch before merge) |
| What shipped overnight | D-157 B1 PARK; point admits; internal SE pins; Ranga \(Q_0\); W-onesided #1064; Gamma/lnorm oracles #1063; CI triad docs #1075; Poisson W G0 #1076; #1078 as-cran guard |
| What landed this lane | Triad Confirm **SIGNED**; Design **125 APPROVED**; ADEMP **SIGNED**; Poisson W **PARK SE doors**; S4 Rose **PASS**; V1 **PASS**; G2 OPEN-READY-PR |
| What is SIGNED (approve-all) | G1 PARK SE doors · G2 OPEN-READY-PR · G3 WAIT · G4a–G4e; Design 125 APPROVED; ADEMP SIGNED |
| Plan by leverage | (1) human review of G2 docs PR · (2) still NOT undraft #1077 / Totoro / public se / invent KEEP/REPLACE · (3) H1 blocked until fork |
| PROTECTED | Codex Lane B binary intervals; no public `se=TRUE` / NEWS covered without G0; #1077 stays draft |

## Critical Context

1. **LA-MSPL** = Laplace + soft outer criterion (not EVA/VA/AGHQ-MSPL).
2. **D-157 B1 PARK is SIGNED.** No second campaign. `MSPL-04` stays
   `blocked`. No Totoro relaunch. Later intervals = **new construction +
   new pre-registration**, not Design 118 recalibration, not \(n\to 2000\).
3. **Point admits on main:** binomial, gaussian, poisson
   (**experimental**). Everything else stays **planned**.
4. **Internal SE pins live** (availability only, D-149): Bernoulli,
   Gaussian, Poisson, nbinom, Beta (door #1055). Tweedie hang fixed;
   **public Tweedie door CLOSED**.
5. **Ranga + papers (#1061/#1062):** \(Q_0\) = paper Wald reporting
   target if/ever SE forms; \(Q_P\)/\(Q_0\) PD = availability only.
   CI calibration ≠ SE availability.
6. **CI triad Confirm SIGNED** (under D-157; no new D-) in commit
   **`7de94fc7`** — Profile = signature; Wald \(Q_0\) = availability;
   Bootstrap = asymmetry. Exact Confirm in
   `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md`.
7. **Design 125 claimed** at **`b68b20b4`** —
   `docs/design/125-mspl-profile-led-intervals.md` (**APPROVED**; MSPL-04 stays
   `blocked`).
8. **S2 ADEMP pre-reg SIGNED** (sibling finished) —
   `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`
   (cites Design 125; not a campaign launch).
9. **Poisson W card (#1076) SIGNED — PARK SE doors** — tape unchanged;
   KEEP/REPLACE not invented; further SE-series doors parked.
10. **Profile scaffold DRAFT #1077** — **still draft** tip `fb44d7b5`;
    still refuses public `confint`. Design APPROVED ≠ undraft permission.
11. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE).
    Do not absorb/rebase/merge from Cursor MSPL.
12. **Multi-lane:** ownership map is
    `docs/dev-log/handover/2026-07-25-active-lane-split.md`. Read
    **every** lane row. This doc owns the LA-MSPL overnight → Design 125
    profile-led baton only.

## Goals / mission (if applicable)

Finish the LA-MSPL estimator programme honestly: covered claims only
where evidence exists; public SE/intervals withheld until separate G0s;
no Design 118 reopen after B1 FAIL.

## Plans / roadmap (if applicable)

Design 125 **APPROVED** + ADEMP **SIGNED** on this branch. Decision queue
G1–G4e SIGNED. Immediate NEXT per `LOOP/checkpoint.md`: finish **V1** if
needed → **C1** (this sitting) → **G2** non-draft docs PR when asked.
**H1 blocked** (G3 WAIT + G4c FORK-DEFER). Optional #1065 planned-only.
Codex Lane B remains foreign. No live profile / undraft #1077.

## What Was Accomplished (DONE / SIGNED)

| Item | Evidence |
|---|---|
| D-157 B1 PARK | Brief SIGNED; #1069 sign + #1072 retarget; paste archived in overnight brief |
| Point admits | binomial, gaussian, poisson (experimental) |
| Internal SE pins | Bernoulli, Gaussian, Poisson, nbinom, Beta (#1055 door); Tweedie hang fixed, public door CLOSED |
| Ranga \(Q_0\) | #1061 / #1062 — paper reporting target; \(Q_P\)/\(Q_0\) availability |
| W-onesided audit | #1064 |
| Gamma / lognormal rate+loading oracles | #1063 |
| CI triad docs + Confirm | #1075 landed; Confirm **SIGNED** in `7de94fc7` |
| Design 125 stub | claim SHA **`b68b20b4`** — **APPROVED** programme stub |
| S2 ADEMP pre-reg | **SIGNED** — `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` |
| S4 Rose fence | **PASS** — closed stale co-primary wording in bootstrap sketch |
| V1 verify | **done** / in progress per LOOP — #1077 draft; MSPL-04 blocked |
| Poisson W G0 card | #1076 **SIGNED — PARK SE doors** (tape unchanged) |
| Profile CI scaffold | **DRAFT** #1077 — still draft after Confirm; tip `fb44d7b5` |
| as-cran lane-b guard | #1078 on `main` @ `a5c83011` |

Key research / design paths:

- `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md` (SIGNED PARK)
- `docs/dev-log/research/2026-08-17-mspl-overnight-brief.md` (FINALIZED)
- `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` (**SIGNED** triad Confirm; under D-157; Confirm-in-ref `7de94fc7`)
- `docs/design/125-mspl-profile-led-intervals.md` (claim `b68b20b4`)
- `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` (S2 **SIGNED**)
- `docs/dev-log/after-task/2026-08-17-mspl-design-125-profile-led.md`
- `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (**SIGNED — PARK SE doors**)
- `docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md`

## Current Working State

- **Working / landed on `main`:** D-157 PARK; overnight brief finalized;
  triad + Poisson W cards filed; pins + point admits as above; #1078.
- **This lane (unpushed docs ahead of main):** Confirm `7de94fc7`;
  Design 125 @ `b68b20b4` **APPROVED**; S2 ADEMP **SIGNED**; LOOP kit;
  after-task `2026-08-17-mspl-design-125-profile-led.md`.
- **In progress / open PRs:**
  - [#1065](https://github.com/itchyshin/gllvmTMB/pull/1065) nbinom
    admit-packet science — **planned only**; CONFLICTING / CI issues —
    resume fix allowed, **no admit**.
  - [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) draft
    fenced profile-CI scaffold — **still draft** (Confirm SIGNED does
    **not** undraft).
  - [#981](https://github.com/itchyshin/gllvmTMB/pull/981) B0
    prerequisites — **CONFLICTING; leave**.
- **Not working / blocked:** public `se=TRUE` / `vcov` / `confint` /
  NEWS `covered` without G0; Design 118 recalibration; B1 relaunch;
  live profile intervals; undraft #1077.

## Key Decisions & Rationale

| Decision | Why |
|---|---|
| D-157 B1 PARK | Official hold-out G1 14/132 = 10.6%; no second campaign; later intervals = new construction |
| \(Q_0\) reporting target | Papers report unpenalized observed \(J\) at MSPL \(\tilde\theta\); \(Q_P\) is availability companion |
| CI triad Confirm SIGNED | D-12 heroizes profile; B1 FAIL kills Wald-as-brand; bootstrap keeps asymmetry; roles locked under D-157 |
| No public SE from pins | D-149 — PD Hessians ≠ calibrated intervals |
| Do not absorb Lane B | Separate Codex ownership; binary SE foreign to this lane |

## Landing State

`handoff_gate.sh` on this worktree (2026-08-17): **XX** — HEAD tip of
old `docs/mspl-ci-wald-plus-profile` had 1 unpushed local SHA whose
**content already landed via merge commits** (#1075/#1076 etc.); plus
~447 unpushed commits on **stale foreign local branches** (agent/*)
unrelated to this overnight arc. This handover branch is cut clean
from `origin/main` @ `a5c83011`.

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `origin/main` @ `a5c83011` (+ #1075/#1076/#1071/#1072/#1073/#1078 …) | y | y | merged | **LANDED** |
| D-157 B1 PARK + overnight brief | y | y | #1069/#1071/#1072 | **LANDED** |
| CI triad docs + Confirm | y | Confirm on this branch | #1075 + `7de94fc7` | **DONE** (SIGNED) |
| Design 125 claim | y | n (this lane) | — | **DONE** @ `b68b20b4` |
| S2 ADEMP pre-reg | y | n (this lane) | — | **DONE** (draft; unsigned) |
| Poisson W G0 card | y | y | #1076 | **SIGNED — PARK SE doors** |
| Profile scaffold `cursor/mspl-profile-ci-scaffold` | y | y | #1077 draft | **CARRIED-OVER** — still draft; do not undraft |
| nbinom admit packet | y | y | #1065 | **CARRIED-OVER** — planned only; fix CONFLICTING/CI; no admit |
| B0 #981 | y | y | #981 CONFLICTING | **CARRIED-OVER** — leave |
| Codex Lane B `codex/lane-b-mspl-interval-feasibility` | n (foreign) | y (private) | none from Cursor | **PROTECTED** |
| Stale local `agent/*` unpushed tips | y (local) | n | none | **CARRIED-OVER** — not this lane; do not push/merge from MSPL WT |
| This handover branch `handover/2026-08-17-cursor` | this PR | with PR | docs PR | **LANDED when PR merges** |

Resume commands for CARRIED-OVER rows:

```sh
# #1065 planned-only fix (optional while G0s wait)
gh pr checkout 1065
# rebase/fix CONFLICTING + CI only; stay planned; no admit; no NEWS covered

# #1077 — still draft; do not undraft without separate Shinichi G0
gh pr view 1077 --json isDraft,headRefOid,url

# #981 — leave
gh pr view 981
```

## Next Immediate Steps (OWED)

| Class | Item |
|---|---|
| **DONE** | Triad Confirm SIGNED (`7de94fc7`) |
| **DONE** | Design 125 claimed (`b68b20b4`) + APPROVED |
| **DONE** | S2 ADEMP pre-reg SIGNED (`2026-08-17-mspl-profile-led-prereg-ademp.md`) |
| **DONE** | S3/S4 arcs (G1 PARK operational; Rose PASS) |
| **DONE** | C1 after-task + this handover refresh |
| **OWED** | Rehydrate `LOOP/checkpoint.md` vs live tip; finish any remaining **V1** checks |
| **OWED** | **G2** — open **non-draft docs PR** (Design 125 + Confirm + LOOP/pre-reg) when Shinichi asks; does **not** undraft #1077 |
| **OWED** | Optional #1065 planned-only CI fix |
| **PROTECTED** | Codex Lane B; Dropbox WT; `git add -A`; #1077 draft |
| **RETRACTED** | “wait triad G0 before Design work” — Confirm SIGNED |
| **RETRACTED** | “S2 TBD” — S2 SIGNED |
| **RETRACTED** | “NEXT = S3∥S4 only” — S3/S4 done; live NEXT = V1/C1/G2 |

Hard fences (not OWED work): undraft #1077 · live profile `confint` ·
H1 smoke · public `se=TRUE` · Totoro · Design 118 reopen · B1 relaunch ·
inventing KEEP/REPLACE tape change without a new G0.

## Blockers / Open Questions

| ID | Status | Ask |
|---|---|---|
| CI triad confirm | **SIGNED** (`7de94fc7`) | Exact Confirm in `2026-08-17-mspl-ci-wald-plus-profile.md` |
| Design 125 | **APPROVED** @ `b68b20b4` | MSPL-04 stays blocked until evidence path |
| S2 ADEMP | **SIGNED** | T\* still need explicit numbers before Totoro |
| Poisson W card | **SIGNED — PARK SE doors** | Tape unchanged; KEEP/REPLACE later if needed |
| G2 docs PR | **OWED** when asked | Non-draft docs PR; not #1077 |
| G3 / H1 | **WAIT** | No local profile smoke until fork A/B/C |
| #1065 | open | CI/CONFLICTING — fix allowed; admit forbidden |
| #1077 | **still draft** | FORK-DEFER; needs separate undraft G0 |
| #981 | CONFLICTING | leave |

## Gotchas & Failed Approaches

- Do **not** treat B1 FAIL as a cue to recalibrate Design 118 or push
  \(n\to 2000\). D-157 forbids both.
- Do **not** treat internal \(Q_P\)/\(Q_0\) pins as public SE or NEWS
  `covered`.
- Do **not** silently swap Poisson `W=diag(mu)` — PARK freezes SE doors;
  KEEP/REPLACE needs a new paste, not a quiet tape edit.
- Do **not** merge red / CONFLICTING doors (#981, #1065 until green).
- Do **not** use Dropbox checkout; do **not** `git add -A`.
- Lane `LOOP/` on this worktree is the live `/goal` kit — do not
  confuse with historical Arc 1A under `docs/dev-log/lanes/`.
- Stale lane-split rows still say “B1 aftermath UNSIGNED” in places —
  **superseded by D-157 SIGNED PARK**; this handover + refreshed split
  are authoritative for the MSPL overnight → Design 125 baton.

## Sibling lanes (carry-forward — do not orphan)

Read the full table in
`docs/dev-log/handover/2026-07-25-active-lane-split.md`. Especially:

| Lane | Start here | Note |
|---|---|---|
| Codex binary SE | classify-only; Lane B path in split | **PROTECTED** |
| CRAN 0.7 | `2026-08-08-codex-handover.md` | Codex live toolchain; no bump from this lane |
| Design 108 / VA | named VA handovers in split | fenced; separate G0 |
| iSDM G2d | `2026-08-10-codex-handover-g2d.md` | plan-only |
| Historical MSPL kits | 2026-08-15/16 handovers | closed — do not reopen |

## Files Created / Modified (this handover sitting)

- `docs/dev-log/handover/2026-08-17-cursor-handover.md` (this file; OWED refresh)
- `docs/dev-log/after-task/2026-08-17-mspl-design-125-profile-led.md`
- `docs/dev-log/check-log.md` (prepend)
- Earlier overnight sitting also touched lane-split + CLAUDE snapshot

## Environment / toolchain (Cursor)

```sh
cd /Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci
git fetch origin
git status --short --branch
git log --oneline -15
# safe verification for docs-only:
rg -n 'SIGNED|Design 125|b68b20b4|7de94fc7|S3|UNSIGNED|#1077' \
  docs/dev-log/handover/2026-08-17-cursor-handover.md \
  LOOP/checkpoint.md \
  docs/design/125-mspl-profile-led-intervals.md \
  docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
# never stage: Dropbox foreign dirt, campaign artifacts, secrets, .env
```

Live fits / `R CMD check` / Totoro: only if an OWED step after a
separate Shinichi G0 explicitly requires them. Default next sitting is
**G2 docs PR when asked** (or #1065 planned-only CI fix) — **not** H1.

## HARD STOPS

second B1 / Totoro relaunch · Design 118 recalibration · public
`se=TRUE` / `vcov` / `confint` / NEWS covered without G0 · undraft #1077
· live profile intervals · nbinom/Tweedie/other admit · Codex Lane B
absorb · `git add -A` · Dropbox WT · inventing Poisson W KEEP/REPLACE/PARK
· GitHub Actions as campaign host

## How to Resume

1. Read `AGENTS.md`.
2. Read this file.
3. Read `docs/dev-log/handover/2026-07-25-active-lane-split.md` (all rows).
4. Reconcile with `git fetch` + `origin/main`.
5. Classify OWED/DONE/RETRACTED/PROTECTED.
6. Continue **only** the OWED Next Immediate Steps above.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-17-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
