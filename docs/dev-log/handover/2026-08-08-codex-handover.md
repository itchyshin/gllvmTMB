# Session Handoff: gllvmTMB CRAN 0.7 → Codex (track pick locked)

Meta: **2026-08-08 Saturday morning** · from Claude (Cursor acting as Claude-side author) → a **NEW Codex session** · repo `gllvmTMB`  
You are Codex, picking this up cold. You never saw the authoring chat. Everything you need is in this file, `AGENTS.md`, and the linked repo docs.

---

## Critical Context

Shinichi answered the three G0 track questions on the morning of **2026-08-08**. First CRAN upload identity stays **`0.7.0`**. **#949 VA Arc-1 stays on `main`** (fenced: `calibrated = FALSE`, Laplace default). **Do not revert VA.** First CRAN is **not imminent**: he wants **more testing**, not Ada’s “(a) none”. The CRAN portal is offline until **19 Aug 2026**; even after that, **do not aim for the first portal day**. Upload remains **Shinichi-only**.

Work in the **0.7 CRAN worktree**, not the VA merge-fence and not Path A:

| Tree | Branch / SHA | Role |
| --- | --- | --- |
| `/private/tmp/gllvmtmb-cran-0.7-20260807` | `cursor/cran-0.7-20260807` @ `51480001` (G0 lock; this handover lands on the same branch) | **YOUR lane** |
| `/private/tmp/gllvmtmb-cran-path-a-0.6.1` | `v0.6.1-rc.1` @ `6a58683c` | **PROTECTED failure archive** (S7 STOP: PDF `≈` ERROR + galamm 404). Do not remint as CRAN 0.6.1 or retag as 0.7 |
| `/private/tmp/gllvmtmb-va-arc1-merge-fence` | leftover after #949 | **Not the CRAN lane** |
| `origin/main` | `d7bee2fa` | #949 squash. `DESCRIPTION` still **`0.6.0`** |

G0 planning artefact (identity + D-113 *menu*, not a test programme):  
`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`.

🔴 **MULTI-LANE.** Rehydrate from `docs/dev-log/handover/2026-07-25-active-lane-split.md` and **every** lane pointer it names. Do not absorb Profile/D-112, eta, VGH-at-scale, or the VA fat tip.

---

## Goals / mission

Package mission is in `AGENTS.md`: stacked-trait long-format GLLVMs; 5×3 keyword grid; no silent public-claim widening.

This lane’s “why”: deliver an **honest first CRAN candidate at `0.7.0`** only after (i) leave-M5 hygiene, (ii) Rose claim-fence, and (iii) a **maintainer-approved testing/INCLUDE programme**. D-49 stays fail-closed (**NOT READY** until a tarball-clean 0.7 freeze exists). Distance from upload is deliberate (vault [[DECISIONS#D-89|D-89]]).

---

## Plans / roadmap (beyond the next steps)

Planning-side G0 number is **locked**: upload string = `0.7.0` (vault D-66 clarifying note 2026-08-07 evening @ `1994a8e`). D-113 remains the long **capability** programme (EVA, Ayumi/#332, AGHQ claims, #750, SEPARABLE, slope-per-family). That list is **not** automatically the first tarball.

Shinichi’s 2026-08-08 morning lock: treat 0.7.0 as **not imminent**; inventory remaining testing/validation debt from the **repo** (register + tests + issues + G0 honesty notes) and **propose** a concrete INCLUDE + test programme. **Do not assume** #750 / #332 / one-slope are the next tests unless the G0 file **and** `docs/design/35-validation-debt-register.md` still say those are the right next tests after you re-derive.

Post-0.7 / other-lane deferred menus (carry forward; do not drop): Design 108 Stage 7 [#911](https://github.com/itchyshin/gllvmTMB/issues/911); VA-vs-Laplace recovery study; VGH degeneracy-at-scale (approved, unstarted); AGHQ D3 (`τ = 2`) unowned; D-112 coverage re-measure **PARKED**; paper/capstone Design 66; drmTMB CRAN still FAR AWAY; EVA remains Codex-owned research unless reassigned — **not** an admitted `integration` value.

---

## What Was Accomplished

This authoring session did **not** run `R CMD check` or bump `DESCRIPTION`. It locked maintainer answers into durable files and handed you the live toolchain.

| # | thing | where |
| --- | --- | --- |
| 1 | G0 lock: first CRAN upload identity = `0.7.0`; Path A parked | `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md` · commit `51480001` |
| 2 | D-113 *menu* inventoried as honesty vs capability (Ada default tarball named) | same G0 file |
| 3 | Path A `v0.6.1-rc.1` @ `6a58683c` retained as failed RC (1E/1W/2N) | Path A worktree + tag (pushed) |
| 4 | VA Arc-1 **already on `origin/main`** via [#949](https://github.com/itchyshin/gllvmTMB/pull/949) @ `d7bee2fa` | do not revert |
| 5 | Vault evening amendments D-66 / D-89 / D-113 | `~/shinichi-brain` @ `1994a8e` (HEAD later moved; evening text still in `memory/DECISIONS.md`) |
| 6 | Morning Q1–Q3 answers locked (this handover + G0 addendum + vault D-89/D-113 morning note) | this file |

Ada’s default tarball (now **confirmed Q1 = YES**): leave-M5 hygiene + Rose fence + later `0.7.0` bump; **keep #949**. Q2 is **not** Ada’s “(a) none” — more testing. Q3: **reconsider** upload timing; portal reopen is not a deadline.

---

## Current Working State

- **Working:** G0 identity lock; #949 on main; Laplace default; D-112 recovery-only; `DESCRIPTION` `0.6.0`; no open GitHub PRs on `itchyshin/gllvmTMB` as of 2026-08-08 morning (`gh pr list --state open` → empty).
- **In progress:** this handover branch (`cursor/cran-0.7-20260807`) carrying G0 + snapshot refresh. Live checks, leave-M5 Rd/URL fixes, Rose fence, and the testing-debt inventory are **yours**.
- **Not working / blocked:** D-49 rung still **NOT READY** (no tarball-clean 0.7 candidate). Path A rc.1 is **not** a 0.7 receipt. Portal offline **5–19 Aug 2026**.

---

## Key Decisions & Rationale

1. **Q1 YES — keep Ada default shape + keep VA.** Hygiene + Rose + (later) 0.7 bump. Reverting #949 would discard a fenced, already-merged estimator without making the PDF/`≈` or galamm 404 go away.
2. **Q2 YES INCLUDE / more testing — not “(a) none”.** Combined with Q3: he believes the package still has a lot to do. First CRAN is **not imminent**. You inventory debt and **propose** a programme; you do not silently start all six D-113 tracks.
3. **Q3 RECONSIDER timing.** Portal offline until 19 Aug 2026. After that, **do not aim for first portal day**. More testing first. Upload = Shinichi only. “On the table after 19 Aug” ≠ a deadline.
4. **Laplace remains default.** AGHQ / VA stay opt-in and fenced. No `method=` export story. EVA stays unadmitted.
5. **D-112 holds.** Recovery-only intervals; no coverage re-measure as a CRAN blocker.
6. **Do not remint `6a58683c` as 0.7.** New freeze on this lane after hygiene + authorised tests.
7. **Merge authority.** Do **not** merge this (or any) PR without explicit instruction. Do **not** CRAN upload.

Vault cross-links: [[DECISIONS#D-49]] · [[DECISIONS#D-50]] · [[DECISIONS#D-66]] · [[DECISIONS#D-89]] · [[DECISIONS#D-112]] · [[DECISIONS#D-113]].

---

## Landing State

`handoff_gate.sh` **FAILS** (declared, not invisible). Paste-equivalent 2026-08-08 morning:

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `gllvmTMB` `cursor/cran-0.7-20260807` `51480001` + this handover commit | y (after this commit) | at handover push | open after `gh pr create` | **this lane — land handover PR; human merges** |
| `origin/main` `d7bee2fa` (#949) | y | y | #949 **merged** | LANDED |
| Path A `cursor/cran-path-a-0.6.1-20260807` `657c6b38` (park stamp) | y | **n** (ahead 1 of its origin) | none | **CARRIED-OVER** — docs-only park; tag `v0.6.1-rc.1` @ `6a58683c` **is** pushed. Resume: `git -C /private/tmp/gllvmtmb-cran-path-a-0.6.1 push` if Shinichi wants the park note on origin. Not required to start 0.7 work |
| Path A freeze/tag `v0.6.1-rc.1` `6a58683c` | y | y | n/a | **PROTECTED** failure archive |
| VA merge-fence `cursor/va-arc1-merge-fence-20260807` `67f38910` | y | y | #949 merged | leftover WT; **CARRIED-OVER** untracked `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-{arc,ultra-plan}.md` — do not stage from the 0.7 lane |
| Shared git-dir historical local branches (hundreds of `agent/*` `claude/*` `codex/*`) | mixed | **n** | mixed | **CARRIED-OVER** — not this lane; do not push or delete |
| Dropbox `claude/profile-coverage-remeasure-20260718` | dirty | n | n/a | **PROTECTED** D-112; do not touch |
| `~/shinichi-brain` `memory/DECISIONS.md` morning D-89/D-113 note | y if vault commit landed | n/a (no remote; D-37) | n/a | LANDED locally when committed; **AGENT_LOG.md already dirty** with unrelated reciprocal-action receipt — morning line may sit uncommitted; do not `git add -A` the vault |
| `lanes/*/results`, campaign CSVs, secrets | — | — | — | **never stage** |

Anything not in this table does not exist for the next agent.

---

## Next Immediate Steps

Classify on arrival (`OWED` · `DONE` · `DEFER` · `PROTECTED`). Execute **only OWED**.

| # | Item | Class | Notes |
| ---: | --- | --- | --- |
| 0 | Rehydrate: `AGENTS.md` → this doc → lane split → G0 → register | **OWED** (arrival) | Spawn Rose (`.codex/agents/systems-auditor.toml`) before any public claim |
| 1 | Leave-M5 hygiene on **this** 0.7 tree: Unicode `≈` (U+2248) in `R/gllvmTMB.R` → `man/gllvmTMBcontrol.Rd` (and Rose-scan other Rd); galamm URL 404 `https://lcbc-uio.github.io/galamm/` in `vignettes/gllvmTMB.Rmd` | **OWED** | Do **not** patch freeze SHA `6a58683c` in place |
| 2 | Rose claim-fence: DESCRIPTION, NEWS, README, Rd, articles, `cran-comments.md` | **OWED** | D-112 recovery-only; `certified-0.94` vs “no cell certified”; AGHQ “calibrated 9-node” ≠ coverage; Laplace is default; VA/AGHQ/EVA not certified; #750 docs match code; MIS-32 / VA `mi()` / SEPARABLE not implied shipped |
| 3 | **Inventory remaining testing/validation debt** and **propose** a concrete INCLUDE + test programme | **OWED** | Re-derive from `docs/design/35-validation-debt-register.md`, `docs/design/05-testing-strategy.md`, open issues, G0 honesty notes. Do **not** assume #750/#332/one-slope. Stop for Shinichi before implementing the programme |
| 4 | Live `export NOT_CRAN=true` + `R CMD check --as-cran` after hygiene | **OWED** | Confirms leave-M5 cleared. Skip-count matters (see Gotchas) |
| 5 | `DESCRIPTION` / NEWS / citation bump to **0.7.0** | **DEFER** | Not yet. After hygiene + authorised test programme |
| 6 | New 0.7 freeze + exact-tag D-49 remint | **DEFER** | Path A rc.1 receipts are predecessor evidence only |
| 7 | win-builder / macbuilder | **DEFER** | Later, closer to a real candidate — not day-one |
| 8 | Totoro / DRAC campaigns | **DEFER** unless the proposed programme needs them | **D-50:** never GHA artifacts for sims |
| 9 | Path A `v0.6.1-rc.1` retained | **DONE** / **PROTECTED** | Failure archive |
| 10 | Keep #949 VA on the CRAN tree | **DONE** / **PROTECTED** | Fenced; no claim widening; no revert |
| 11 | Portal ≥19 Aug 2026 | **DEFER** | Calendar floor, **not** a deadline; not first portal day |
| 12 | CRAN upload | **DEFER** / forbidden | Shinichi-only |
| 13 | Merge this handover PR | **DEFER** | Human merges. **Do not auto-merge** |

---

## Blockers / Open Questions

🔴 **Needs Shinichi (OPEN GATE):** after you publish the testing-debt inventory + proposed INCLUDE programme, he must approve scope (what to implement vs fence-only vs park) **before** the 0.7 bump, freeze, or any campaign that is more than a cheap local probe.

Already answered (do not re-ask): Q1 keep VA + Ada hygiene shape; Q2 more testing not “(a) none”; Q3 not first portal day.

Still not yours to decide: AGHQ D3 owner; VGH-at-scale start vs other lanes; EVA public route; Laplace→AGHQ/VA default flip.

---

## Gotchas & Failed Approaches

1. **This checkout is not a generic workspace.** VA merge-fence and Path A look like “the repo”; they are not this programme.
2. **Path A `--as-cran` at `6a58683c` was 1E/1W/2N.** PDF manual dies on Unicode `≈` in `man/gllvmTMBcontrol.Rd` (roxygen in `R/gllvmTMB.R`, e.g. binomial recovery “r ≈ 0.59”). Galamm vignette URL 404s. Carry the fix forward; do not treat rc.1 as clean.
3. **`NOT_CRAN=true` is mandatory.** Without it the suite silently skips a large fraction of assertions (historical factor ~15× on some files). A green default `R CMD check` can hide regressions.
4. **`opt$convergence` / VA `converged` are not health signals** on several engines. Recovery vs truth is the estimand. Do not promote “converged = TRUE” into a CRAN claim.
5. **Do not stage `lanes/*/results`, campaign outputs, or secrets.** `lanes/` LOOP markdown on this branch is tracked on purpose; results dirs are not.
6. **#908 is MERGED** (`lanes/` excluded from the tarball). CLAUDE.md’s older “#908 UNMERGED” bullet is a historical snapshot line — do not resurrect that NOTE hunt.
7. **Do not implement all D-113.** Inventory ≠ start EVA / SEPARABLE / full slope list.
8. **Shared git dir has hundreds of unpushed historical branches.** Ignore them. Do not `git push --all`.

---

## How to Resume

Pasteable one-command (from the 0.7 worktree, or a fresh clone of this branch):

```
Rehydrate from docs/dev-log/handover/2026-08-08-codex-handover.md + the AGENTS.md snapshot, then continue with the Next Immediate Steps.
```

Read order:

1. `AGENTS.md` (native; D-50 + keyword grid + Definition of Done)
2. This file
3. `docs/dev-log/handover/2026-07-25-active-lane-split.md` (every lane row)
4. `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md` (identity + honesty menu)
5. `docs/design/35-validation-debt-register.md` + `docs/design/05-testing-strategy.md`
6. Vault `~/shinichi-brain/memory/DECISIONS.md` D-49, D-50, D-66, D-89, D-112, D-113
7. `.codex/agents/systems-auditor.toml` (Rose) before any reader-facing claim

Workspace:

```bash
cd /private/tmp/gllvmtmb-cran-0.7-20260807
# or: git fetch origin && git switch cursor/cran-0.7-20260807
git status -sb
git log -1 --oneline
```

### Codex-tuned live toolchain (YOU own this)

Planning-side (Claude/Cursor) locked the G0 **number** and the Q1–Q3 answers. **You** run the compiler, checks, test expansion, leave-M5 Rd/URL fixes, and — **when authorised** — the DESCRIPTION 0.7 bump and exact-tag remint.

```bash
export NOT_CRAN=true
# TMB compiles from src/ on first load_all / INSTALL
Rscript --vanilla -e 'devtools::load_all(".", compile = TRUE)'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'devtools::test()'
R CMD build .
R CMD check --as-cran gllvmTMB_*.tar.gz
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
```

- **GitHub Actions:** package checks + docs only. **Never** store simulation/recovery/power outputs as Actions artifacts (D-50).
- **win-builder / macbuilder:** later, not day-one.
- **Totoro / DRAC:** only if the approved test programme needs campaigns. Results stay local + dev-log.

Rose team mirror: `.codex/agents/*.toml` — at least `systems-auditor.toml` (Rose), `simulation-tester.toml` (Curie), `reproducibility-engineer.toml` (Grace) when you touch checks/CRAN.

### Claude ↔ Codex routing

| Who | Next |
| --- | --- |
| **Codex (you)** | Live checks; leave-M5; Rose fence edits that need rendered Rd / `--as-cran`; testing-debt inventory + proposed programme; test expansion once authorised; 0.7 bump + remint when authorised |
| **Claude / Cursor** | Already locked G0 number + Q1–Q3. Further planning/prose if the inventory raises a design fork |
| **Shinichi** | Approve proposed INCLUDE + test programme; merge PRs; CRAN upload |

---

## Files Created / Modified

From `git diff --name-only origin/main...HEAD` on this branch **plus** this handover slice:

**Already on `51480001` (G0 evening):**

- `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`
- `docs/dev-log/after-task/2026-08-07-cran-0.7-g0-lock.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/handover/2026-07-25-active-lane-split.md`
- `lanes/gllvmtmb-cran-0.7/LOOP/GOAL.md`
- `lanes/gllvmtmb-cran-0.7/LOOP/checkpoint.md`

**This handover slice:**

- `docs/dev-log/handover/2026-08-08-codex-handover.md` (this file)
- `AGENTS.md` (rehydrate pointer)
- `CLAUDE.md` (Live Phase Snapshot prepend)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (CRAN 0.7 / Path A rows + morning refresh)
- `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md` (2026-08-08 morning lock)
- `lanes/gllvmtmb-cran-0.7/LOOP/checkpoint.md`
- `lanes/gllvmtmb-cran-0.7/LOOP/GOAL.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-08-codex-handover-cran-0.7.md`
- vault `~/shinichi-brain/memory/DECISIONS.md` (D-89 / D-113 morning note) — separate repo

---

## Mission control

| repo | branch / main / CI | what shipped | plan by leverage |
| --- | --- | --- | --- |
| gllvmTMB | `origin/main` `d7bee2fa` green enough to base 0.7; **0 open PRs** at handoff; this branch docs-only | G0 `0.7.0` identity; #949 VA fenced on main; Path A rc.1 archived dirty | **1** leave-M5 + Rose + `--as-cran` · **2** testing-debt inventory + proposed INCLUDE · **3** Shinichi gate · **4** bump/freeze only after that · **never** first-day portal upload |

---

## Shannon (read-only, this handoff)

- **Working tree (0.7):** branch `cursor/cran-0.7-20260807`, clean before this slice except the G0 commit ahead of `origin/main`.
- **PR census:** `gh pr list --state open` → **none**. WIP cap healthy. Pre-edit collision check: no commits `--since="6 hours ago"` on shared rule files.
- **File overlap:** this PR will touch `AGENTS.md`, `CLAUDE.md`, `docs/dev-log/check-log.md`, `docs/dev-log/after-task/`, handover map — no competing open PR.
- **After-task:** paired (`2026-08-07-cran-0.7-g0-lock.md` + this slice’s report).
- **Message bus:** this doc + check-log + PR body (not chat-only).
- **Verdict:** **WARN** — gate failed on unpushed historical branches + Path A park ahead-1 + VA untracked plans + dirty vault AGENT_LOG; all **declared**. No FAIL that blocks writing this handoff.
