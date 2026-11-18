# Morning brief — MSPL overnight (Poisson experimental-point ADMITTED)

Meta: 2026-08-16 · second continuation after #1018 · AUTHOR=cursor ·
TARGET=cursor · worktrees under `/tmp` and `/private/tmp` only
(not Dropbox). Repo-root `LOOP/` was not touched. `git add -A`
was not used. #1006 is now on `main`. B1 still running.

You are Cursor. Reconcile with live `git` before any mutation.

## Critical Context

1. **LA-MSPL** = Laplace + soft outer criterion (not EVA/VA/AGHQ-MSPL).
2. **Poisson ordinary q1/q2 is `admitted` / `admit_packet` on
   `main` @ `32faad9d` (#1017).** Experimental point only.
   **#990 smoke was operational PASS / admit-evidence FAIL.**
   Not NEWS covered. Not public SE. Do not admit
   NB/Tweedie/Beta/hurdle/ordinal/student.
3. **Public `vcov()` / `confint()` / `sdreport()` stay fail-closed.**
4. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE).
5. **Compute host actually used: Totoro.** DRAC full array remains
   **impossible tonight** (quota + `MaxArraySize`).
6. **Do not start a second Totoro/DRAC full B1.**

## Compute (D-139)

| Step | Host | Result |
|---|---|---|
| Canary `--mode=canary` B010, 1 outer, 5 boot | **Totoro** | **HEALTHY**, wall ≈1–2 min |
| Full B1 (7,920 tasks, 140 workers) | **Totoro** | **STILL ALIVE** pid `2779264` since `2026-08-16T01:53:53Z` |
| Full B1 DRAC array | fir / `/project` | **NOT STARTED** — quota; `MaxArraySize=10000` < 26400 |

Latest peek at `2026-08-16T10:29Z` (elapsed **8h36**, shards
**7136** of 7,920, 283 R workers, load ≈140, **0** FATAL/Killed).
Earlier 03:23Z peek was 1h29 / 2095. Throughput slowed on the
hard tail (~2 shards/min) then recovered. No second launch.
SE covered? **no**.

```sh
ssh totoro 'ps -p 2779264 -o pid,etime || echo finished
ls ~/gllvmtmb-local-artifacts/b1-full-20260816/shards | wc -l
pgrep -c -f run-b1-shard.R'
```

If the job dies, record why in the D-139 receipt. Restart a full
20 h job only if death was an obvious spawn fail in the first
10 minutes (that window is closed).

## What landed on `main` this continuation

| PR | What | SHA / note |
|---|---|---|
| [#1010](https://github.com/itchyshin/gllvmTMB/pull/1010) | Overnight brief + D-139 receipt | `8e4e680a` |
| [#975](https://github.com/itchyshin/gllvmTMB/pull/975) | Beta Phase-4 prep (planned) | `83e41098` |
| [#976](https://github.com/itchyshin/gllvmTMB/pull/976) | nbinom1 Phase-4 prep (planned) | `dd6b6ce2` |
| [#1008](https://github.com/itchyshin/gllvmTMB/pull/1008) | Poisson admit-packet atoms (still planned) | `235be4b4` |
| [#972](https://github.com/itchyshin/gllvmTMB/pull/972) | Poisson Phase-4 E1–E7 oracles (planned) | `a923014f` |
| [#973](https://github.com/itchyshin/gllvmTMB/pull/973) | Tweedie Phase-4 prep (planned) | `04f897ab` |
| [#1017](https://github.com/itchyshin/gllvmTMB/pull/1017) | **Poisson ordinary q1/q2 experimental-point admit** | `32faad9d` |
| [#1018](https://github.com/itchyshin/gllvmTMB/pull/1018) | Morning brief after Poisson admit + B1 peek | `829638bb` |
| [#1013](https://github.com/itchyshin/gllvmTMB/pull/1013) | VA-light start-agreement tolerance (flake owner) | `3bc91953` |
| [#1006](https://github.com/itchyshin/gllvmTMB/pull/1006) | **Gaussian-identity SE curvature pin** (internal; not public) | `a7027b9d` |

Earlier sitting already on `main`: #989 #993 #994 #1002.
No NEWS covered. No public vcov. No other-family admit.

## Doors still open

| PR | Role | State | Action |
|---|---|---|---|
| [#996](https://github.com/itchyshin/gllvmTMB/pull/996) | Gaussian SE pin (older) | superseded by #1006 on `main` | leave / close if still open |
| [#997](https://github.com/itchyshin/gllvmTMB/pull/997) | Poisson SE next cells | asserts `admitted` / `admit_packet`; CI still hits VA-light `delta_lognormal_log` flake after #1013 | **leave**; do not merge red |
| [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | NB planned door | draft; stacked; no CI on `main` | leave; do not admit NB |
| [#1014](https://github.com/itchyshin/gllvmTMB/pull/1014) | Tweedie/Beta planned door | draft; **in flight**; touches `R/mspl-registry.R` | **do not collide**; no CI yet |
| [#974](https://github.com/itchyshin/gllvmTMB/pull/974) | nbinom2 Phase-4 prep | FAIL + CONFLICTING | leave |
| [#1003](https://github.com/itchyshin/gllvmTMB/pull/1003)–[#1005](https://github.com/itchyshin/gllvmTMB/pull/1005) | Gamma/lnorm, hurdle, student/ordinal | FAIL or CONFLICTING (#1005 SUCCESS but CONFLICTING) | leave |
| [#995](https://github.com/itchyshin/gllvmTMB/pull/995) [#998](https://github.com/itchyshin/gllvmTMB/pull/998) [#999](https://github.com/itchyshin/gllvmTMB/pull/999) [#1000](https://github.com/itchyshin/gllvmTMB/pull/1000) | Expected-red SE doors | still red | leave |
| [#981](https://github.com/itchyshin/gllvmTMB/pull/981) | B0/B1 harness | CONFLICTING; Totoro uses `a3b31e62` | do not merge dirty |

#1001 was already closed (superseded by #1008).

## Poisson admit (DONE)

#1017 landed the G0 flip. Evidence token is `admit_packet`, not
`oracle_local` and not `covered`. Notes record #990 operational
PASS / admit-evidence FAIL. Public SE still withheld.

Do **not** write NEWS covered. Do **not** open public SE.
Do **not** admit any other family.

## Current Working State

- **Working:** Totoro full B1 pid `2779264` (still alive at
  8h36 / 7136 shards).
- **Landed:** Poisson experimental-point admit; Phase-4 prep
  #972 #973 #975 #976; packet #1008; Gaussian pin #1006;
  VA-light tolerance #1013.
- **Not working / blocked:** DRAC full (quota); #997 CI still
  red on VA-light flake; public vcov; NEWS covered;
  Tweedie/Beta implementer still in flight.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `main` @ `a7027b9d` | y | y | #1006 + #1017 + earlier | LANDED |
| Totoro full B1 | n (running) | n | none | **CARRIED-OVER** pid `2779264` |
| DRAC full | n | n | none | **CARRIED-OVER** — quota |
| Codex Lane B | n (foreign) | y | none from Cursor | **PROTECTED** |
| `cursor/mspl-se-tweedie-beta-impl` / #1014 | y | y | #1014 draft | **CARRIED-OVER** — do not edit |

## Next Immediate Steps

1. Keep peeking Totoro B1. Do not start a second full job.
2. Leave #997 until Ubuntu is green on the `admitted` /
   `admit_packet` asserts (VA-light flake is not this PR).
3. #1006 is done. Do not open public vcov. Do not NEWS covered.
4. Do not absorb #1014 or edit `R/mspl-registry.R` while that
   implementer is live.
5. Leave expected-red doors open. Do not absorb Codex Lane B.

## HARD STOPS (unchanged)

second full B1 · public vcov · NEWS covered · all-family admit ·
binomial SE rebuild / Codex absorb · `git add -A` · Dropbox ·
repo-root `LOOP/` · GitHub Actions as campaign host

## Resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-16-cursor-handover-mspl-overnight.md.
Reconcile with live git. Poisson ordinary q1/q2 is already admitted
experimental point (#1017). Gaussian pin #1006 is on main (internal
only). Totoro full B1 pid 2779264 is already running — do not
launch another. Leave #997 until CI is green. Do not merge #1014.
```
