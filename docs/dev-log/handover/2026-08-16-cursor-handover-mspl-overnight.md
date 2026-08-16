# Morning brief — MSPL overnight (KEEP PLANNED except Poisson admit *after* #1008 green)

Meta: 2026-08-16 · from Cursor overnight → Shinichi @ ~05:00 local ·
AUTHOR=cursor · TARGET=cursor · worktrees under `/tmp` and
`/private/tmp` only (not Dropbox). Repo-root `LOOP/` was not
touched. `git add -A` was not used.

You are Cursor. Reconcile with live `git` before any mutation.

## Critical Context

1. **LA-MSPL** = Laplace + soft outer criterion (not EVA/VA/AGHQ-MSPL).
2. **Poisson stays `planned` on the landed packet.** Shinichi G0
   tonight allows planned→admitted **only after #1008 CI is green**,
   as experimental point, not NEWS covered, not public SE. The
   #990 smoke was operational PASS / admit-evidence FAIL — record
   that honestly in the admit note. Do not admit
   NB/Tweedie/Beta/hurdle/ordinal/student.
3. **Public `vcov()` / `confint()` / `sdreport()` stay fail-closed.**
4. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE).
5. **Compute host actually used: Totoro.** DRAC full array was
   preferred and is **impossible tonight**.

## Compute (D-139)

| Step | Host | Result |
|---|---|---|
| Canary `--mode=canary` B010, 1 outer, 5 boot | **Totoro** | **HEALTHY**, wall ≈1–2 min, 3 rows `status=ok`, typed screen-refuse on one coordinate |
| Full B1 (7,920 tasks, 140 workers) | **Totoro** | **RUNNING** since `2026-08-16T01:53:53Z` pid `2779264` |
| Full B1 DRAC array | fir / `/project` | **NOT STARTED** — quota exceeded; `MaxArraySize=10000` < 26400 |

Exact DRAC command (after quota is freed) is in
`docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md`.
Do not `--launch` a second Totoro full. Do not use GitHub Actions
as a campaign host. SE covered? **no**.

```sh
ssh totoro 'tail -20 ~/gllvmtmb-local-artifacts/b1-full-20260816/logs/full-launch.log
ls ~/gllvmtmb-local-artifacts/b1-full-20260816/shards | wc -l
ps -p 2779264 -o pid,etime || echo finished'
```

## What landed on `main` this sitting

| PR | What | SHA / note |
|---|---|---|
| [#989](https://github.com/itchyshin/gllvmTMB/pull/989) | SE withhold + Q0 non-PD pins | `0f4a0bc1` |
| [#993](https://github.com/itchyshin/gllvmTMB/pull/993) | SE pin series charter | `579caa19` |
| [#994](https://github.com/itchyshin/gllvmTMB/pull/994) | B1 dry-run receipt + launcher | `4d4bf255` |
| [#1002](https://github.com/itchyshin/gllvmTMB/pull/1002) | Design 118 §8 DEV-5..9 | `58089758` |

No admit flip. No NEWS covered. No public vcov.

## Green / watch / red doors

Prefer the **rebased** successors. Do not force-push sibling branches.

| PR | Role | Merge rule |
|---|---|---|
| [#1006](https://github.com/itchyshin/gllvmTMB/pull/1006) | Gaussian SE pin rebase (prefer over DIRTY #996 / #995) | squash if CI green; no admit |
| [#1008](https://github.com/itchyshin/gllvmTMB/pull/1008) | Poisson admit-packet rebase (prefer over DIRTY #1001) | squash if CI green; **still planned** |
| [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | NB1/NB2 **planned** door (sibling) | squash if CI green; do **not** admit NB |
| [#997](https://github.com/itchyshin/gllvmTMB/pull/997) | Poisson SE next cells (69 pass locally) | squash if CI green |
| [#972](https://github.com/itchyshin/gllvmTMB/pull/972)–[#976](https://github.com/itchyshin/gllvmTMB/pull/976) | Phase-4 prep (planned only) | squash if CI green and still planned; #974 when green |
| [#1003](https://github.com/itchyshin/gllvmTMB/pull/1003)–[#1005](https://github.com/itchyshin/gllvmTMB/pull/1005) | Gamma/lnorm, hurdle, student/ordinal prep | squash if CI green and not DIRTY; rebase check-log if needed |
| [#995](https://github.com/itchyshin/gllvmTMB/pull/995), [#998](https://github.com/itchyshin/gllvmTMB/pull/998), [#999](https://github.com/itchyshin/gllvmTMB/pull/999), [#1000](https://github.com/itchyshin/gllvmTMB/pull/1000) | Expected-red SE doors | **leave open** until implementers turn them green |
| [#981](https://github.com/itchyshin/gllvmTMB/pull/981) | B0/B1 harness (compute uses this SHA) | CONFLICTING; do not merge dirty; harness is on Totoro @ `a3b31e62` |
| [#996](https://github.com/itchyshin/gllvmTMB/pull/996), [#1001](https://github.com/itchyshin/gllvmTMB/pull/1001) | Superseded by #1006 / #1008 | close after successors merge |

At brief-write time Ubuntu R-CMD-check was still **queued** for
the implementer PRs (Actions backlog). Re-check before merging.

## Poisson admit (OWED — gated on #1008 CI)

Shinichi G0: flip Poisson ordinary q1/q2 `planned` → `admitted`
as **experimental point** after #1008 is green.

Must update in the same commit (or the tests stay red):

- `R/mspl-registry.R` — those two rows only
- `tests/testthat/test-mspl-registry.R` — admitted count / family set
- `tests/testthat/test-mspl-poisson-admit-packet.R` A8 + fit
  `registry_status` (today asserts `planned`)
- PR body Rose fence: admit = atom packet + tonight's G0; #990
  smoke = operational PASS / admit-evidence FAIL

Do **not** write NEWS covered. Do **not** open public SE.
Do **not** admit any other family.

## Current Working State

- **Working:** Totoro full B1; #1006 / #1008 waiting on CI.
- **In progress:** sibling #1007 NB planned door; Phase-4 prep PRs.
- **Not working / blocked:** DRAC full (quota); Poisson admit
  (wait #1008 green); public vcov; NEWS covered.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `main` @ `58089758` | y | y | #989 #993 #994 #1002 | LANDED |
| `cursor/mspl-se-gaussian-pin-rebased` | y | y | #1006 | LANDED as PR; merge if CI green |
| `cursor/mspl-poisson-admit-rebased` | y | y | #1008 | LANDED as PR; still planned |
| `cursor/mspl-overnight-brief` | y | this PR | this file + receipt update | LANDED as docs |
| Totoro canary artifacts | n (local Totoro) | n | none | **CARRIED-OVER** under `~/gllvmtmb-local-artifacts/b1-canary-20260816` |
| Totoro full B1 | n (running) | n | none | **CARRIED-OVER** pid `2779264` |
| DRAC full | n | n | none | **CARRIED-OVER** — quota; command in the receipt |
| Codex Lane B | n (foreign) | y | none from Cursor | **PROTECTED** |
| Shared `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` | dirty sibling | n | #1001 | **CARRIED-OVER** — do not use for new branches |

## Next Immediate Steps

1. `gh pr checks 1006 1008 1007 997 972 973 974 975 976`. Squash-merge
   each CI-green PR that does not enable public vcov / NEWS covered /
   an unauthorised admit.
2. After #1008 green: Poisson admit flip (two ordinary cells only)
   with the Rose-fenced PR body. Then merge.
3. Peek Totoro full B1. Do not start a second full job.
4. Leave expected-red doors open. Do not absorb Codex Lane B.

## HARD STOPS (unchanged)

public vcov · NEWS covered · all-family admit · binomial SE rebuild /
Codex absorb · `git add -A` · Dropbox · repo-root `LOOP/` ·
GitHub Actions as campaign host

## Resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-16-cursor-handover-mspl-overnight.md.
Reconcile with live git. Merge only CI-green no-public-vcov no-NEWS-covered PRs.
Poisson admit only after #1008 is green. Totoro full B1 is already running —
do not launch another. DRAC is quota-blocked.
```
