# Session Handoff: LA-MSPL overnight arc — B1 PARK + CI triad G0s

Meta: 2026-08-17 · AUTHOR=cursor · TARGET=cursor · overnight arc closeout
Worktree: `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` only
(not Dropbox). Repo-root `LOOP/` was not touched. `git add -A` was not used.

You are Cursor. Rehydrate from this file + `AGENTS.md` + live `git`.
Classify every item **OWED · DONE · RETRACTED · PROTECTED** before mutating.
Execute only **OWED**.

## Mission-control summary

| Field | Value |
|---|---|
| Repo | `itchyshin/gllvmTMB` |
| Tip for rehydrate | `origin/main` @ `a5c83011` (+ later merges; re-fetch) |
| What shipped overnight | D-157 B1 PARK; point admits; internal SE pins; Ranga \(Q_0\); W-onesided #1064; Gamma/lnorm oracles #1063; CI triad docs #1075; Poisson W G0 #1076; #1078 as-cran guard |
| What is UNSIGNED | Triad confirm G0; Poisson W KEEP/REPLACE/PARK SE doors |
| Plan by leverage | (1) wait/record two G0s · (2) optional #1065 planned-only fix · (3) no real profile CI until triad G0 |
| PROTECTED | Codex Lane B binary intervals; no public `se=TRUE` / NEWS covered without G0 |

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
6. **CI triad docs (#1075) UNSIGNED G0** — Profile = signature;
   Wald \(Q_0\) = quick baseline; Bootstrap = asymmetry. Needs Shinichi
   paste before any real profile-interval implementation.
7. **Poisson W G0 (#1076) UNSIGNED** — KEEP / REPLACE \(W_*\) /
   PARK SE doors.
8. **Profile scaffold DRAFT #1077** — wait triad G0; still refuses
   public `confint`.
9. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE).
   Do not absorb/rebase/merge from Cursor MSPL.
10. **Multi-lane:** ownership map is
    `docs/dev-log/handover/2026-07-25-active-lane-split.md`. Read
    **every** lane row. This doc owns the LA-MSPL overnight / intervals
    baton only.

## Goals / mission (if applicable)

Finish the LA-MSPL estimator programme honestly: covered claims only
where evidence exists; public SE/intervals withheld until separate G0s;
no Design 118 reopen after B1 FAIL.

## Plans / roadmap (if applicable)

Beyond the immediate G0 stop: new interval construction under the triad
(profile primary); optional nbinom admit-packet science while staying
`planned`; family SE-series doors frozen pending Poisson W G0; Codex
Lane B remains foreign.

## What Was Accomplished (DONE / SIGNED)

| Item | Evidence |
|---|---|
| D-157 B1 PARK | Brief SIGNED; #1069 sign + #1072 retarget; paste archived in overnight brief |
| Point admits | binomial, gaussian, poisson (experimental) |
| Internal SE pins | Bernoulli, Gaussian, Poisson, nbinom, Beta (#1055 door); Tweedie hang fixed, public door CLOSED |
| Ranga \(Q_0\) | #1061 / #1062 — paper reporting target; \(Q_P\)/\(Q_0\) availability |
| W-onesided audit | #1064 |
| Gamma / lognormal rate+loading oracles | #1063 |
| CI triad docs | #1075 — Profile / Wald \(Q_0\) / Bootstrap roles (**UNSIGNED G0**) |
| Poisson W G0 card | #1076 (**UNSIGNED**) |
| Profile CI scaffold | **DRAFT** #1077 — wait triad G0 |
| as-cran lane-b guard | #1078 on `main` @ `a5c83011` |

Key research paths (already on `main`):

- `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md` (SIGNED PARK)
- `docs/dev-log/research/2026-08-17-mspl-overnight-brief.md` (FINALIZED)
- `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` (UNSIGNED triad)
- `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (UNSIGNED)
- `docs/dev-log/research/2026-08-17-mspl-profile-bootstrap-ci-next.md`

## Current Working State

- **Working / landed on `main`:** D-157 PARK; overnight brief finalized;
  triad + Poisson W cards filed; pins + point admits as above; #1078.
- **In progress / open PRs:**
  - [#1065](https://github.com/itchyshin/gllvmTMB/pull/1065) nbinom
    admit-packet science — **planned only**; CONFLICTING / CI issues —
    resume fix allowed, **no admit**.
  - [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) draft
    fenced profile-CI scaffold — **wait triad G0**.
  - [#981](https://github.com/itchyshin/gllvmTMB/pull/981) B0
    prerequisites — **CONFLICTING; leave**.
- **Not working / blocked:** public `se=TRUE` / `vcov` / `confint` /
  NEWS `covered` without G0; Design 118 recalibration; B1 relaunch;
  real profile intervals before triad G0.

## Key Decisions & Rationale

| Decision | Why |
|---|---|
| D-157 B1 PARK | Official hold-out G1 14/132 = 10.6%; no second campaign; later intervals = new construction |
| \(Q_0\) reporting target | Papers report unpenalized observed \(J\) at MSPL \(\tilde\theta\); \(Q_P\) is availability companion |
| CI triad (proposed, UNSIGNED) | D-12 already heroizes profile; B1 FAIL kills Wald-as-brand; bootstrap keeps asymmetry |
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
| CI triad docs | y | y | #1075 | **LANDED** (G0 still UNSIGNED) |
| Poisson W G0 card | y | y | #1076 | **LANDED** (G0 still UNSIGNED) |
| Profile scaffold `cursor/mspl-profile-ci-scaffold` | y | y | #1077 draft | **CARRIED-OVER** — wait triad G0; resume on that branch |
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

# #1077 after triad G0 only
gh pr checkout 1077
# do not implement real profile intervals until Shinichi pastes triad confirm

# #981 — leave
gh pr view 981
```

## Next Immediate Steps (OWED)

1. **Rehydrate git.** `git fetch origin && git checkout main &&
   git pull` (or stay on this docs branch until merge). Classify
   handover items OWED/DONE/RETRACTED/PROTECTED against live tip.
2. **If Shinichi pastes triad + Poisson W G0s:** record SIGNED in the
   two research cards + `decisions.md` / check-log; then proceed only
   as those pastes authorize.
3. **Else STOP at those two G0s.** Optionally continue fixing **#1065
   only** (stay `planned`; no admit; no public door).
4. **Do not implement real profile intervals until triad G0.**
   #1077 stays draft/fence until then.
5. Do **not** reopen Design 118, relaunch B1/Totoro, open public
   `se=TRUE`, or absorb Codex Lane B.

## Blockers / Open Questions

| ID | Status | Ask |
|---|---|---|
| CI triad confirm | **UNSIGNED** | Profile = signature; Wald \(Q_0\) = quick; Bootstrap = asymmetry? Paste in `2026-08-17-mspl-ci-wald-plus-profile.md` |
| Poisson W | **UNSIGNED** | KEEP / REPLACE \(W_*\) / PARK SE doors? Paste in `2026-08-17-mspl-poisson-W-G0.md` |
| #1065 | open | CI/CONFLICTING — fix allowed; admit forbidden |
| #1077 | draft | blocked on triad G0 |
| #981 | CONFLICTING | leave |

## Gotchas & Failed Approaches

- Do **not** treat B1 FAIL as a cue to recalibrate Design 118 or push
  \(n\to 2000\). D-157 forbids both.
- Do **not** treat internal \(Q_P\)/\(Q_0\) pins as public SE or NEWS
  `covered`.
- Do **not** silently swap Poisson `W=diag(mu)` — that is the UNSIGNED
  G0 (#1076); #1064 audited one-sidedness only.
- Do **not** merge red / CONFLICTING doors (#981, #1065 until green).
- Do **not** use Dropbox checkout; do **not** `git add -A`; do **not**
  write repo-root `LOOP/`.
- Stale lane-split rows still say “B1 aftermath UNSIGNED” in places —
  **superseded by D-157 SIGNED PARK**; this handover + refreshed split
  are authoritative for the MSPL overnight baton.

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

- `docs/dev-log/handover/2026-08-17-cursor-handover.md` (this file)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (MSPL pointer refresh)
- `CLAUDE.md` (Live Phase Snapshot pointer → lane split + this doc)
- `docs/dev-log/check-log.md` (handover entry)

## Environment / toolchain (Cursor)

```sh
cd /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
git fetch origin
git status --short --branch
git log --oneline origin/main -15
# safe verification for docs-only:
rg -n 'D-157|UNSIGNED|triad|#1065|#1077' \
  docs/dev-log/handover/2026-08-17-cursor-handover.md \
  docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md \
  docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md
# never stage: Dropbox foreign dirt, campaign artifacts, secrets, .env
```

Live fits / `R CMD check` / Totoro: only if an OWED step after G0
explicitly requires them. Default next sitting is **docs + G0 wait**
(or #1065 planned-only CI fix).

## HARD STOPS

second B1 / Totoro relaunch · Design 118 recalibration · public
`se=TRUE` / `vcov` / `confint` / NEWS covered without G0 · real profile
intervals before triad G0 · nbinom/Tweedie/other admit · Codex Lane B
absorb · `git add -A` · Dropbox WT · repo-root `LOOP/` · GitHub Actions
as campaign host

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
