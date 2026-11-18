# Plan vs actual — the 2026-08-17 OWED-items ultra-plan (Melissa)

**Plan:** `~/.claude/plans/read-agents-md-and-docs-dev-log-handover-vast-fountain.md`
**Lanes:** `claude/fix-1092-penalised-gradient` (PR #1106) · `claude/1080-dispersion-naming`
(PR #1108) · `claude/1082-one-worked-example` (PR #1107)
**Verdict:** delivered, with **one drift** and **four adaptive deviations**, all recorded.

## Six axes

### 1. Scope — ADAPTIVE ×2

- **Planned** four executable items (#1094, #1092, #1080, #1082) plus an item-3 write-up.
  **Actual:** all five delivered as scoped. No silent narrowing; the DEFER fence held —
  no Design 122 re-run, no `#1080` rename, no `sigma_eps` estimand work, no families
  beyond the one #1082 example.
- **ADAPTIVE:** a **register restoration** was added that no slice planned — `b4c9109e`
  had silently reverted DIA-11/DIA-12 to their pre-#1089 text. Found while editing the
  neighbouring DIA-08 row. Landed as its own labelled commit rather than folded into the
  fix, so it can be reverted independently. Justified: in-scope file, out-of-scope cause,
  separated cleanly.
- **ADAPTIVE:** a **behaviour question was surfaced and deliberately left undecided** (the
  spatial-block ridge vs the warning that promises spatial terms are exempt). Correctly
  escalated rather than resolved unilaterally — it is estimand-visible.

### 2. Evidence / verification — **DRIFT (caught, repaired)**

**The planned fail-before/pass-after gate was run and passed — and was insufficient.** The
first #1092 fix passed 11/11 while being a **silent no-op** on `latent()` +
`spatial_latent()` fits, because every fixture had a single penalised block. The Phase-4
adversarial pass refuted it by measurement.

Classification: **drift, not adaptive.** The plan's S3 brief said "route every reader" and
the reader audit *was* exhaustive; what went unverified was the *definition of the quantity
being reconstructed*. The verification design had a hole the plan did not anticipate.

**Repaired in-plan:** `.gllvmTMB_ridge_block_names` as one source of truth across applier,
gradient instrument and logLik disclosure; a two-block regression test proven to fail
against the one-block fix by reverting and re-running; a fixture guard added after a first
attempt at that fixture collapsed and passed identically under both versions.

**Routed to Rose:** the generalisable rule — *when you fix an instrument, verify what it is
supposed to measure, not only where it is read* — belongs in `LESSONS.md` beside the
entry at `:2337` it extends, because `:2337` was followed faithfully here and was not
sufficient.

### 3. Model routing — ON PLAN

| Slice | Planned | Actual | Note |
|---|---|---|---|
| S0 recon | Haiku low | Haiku, `model` param | fixture inventory |
| S1 merge | Haiku low | **orchestrator** | one `gh` call; spawning a child would have cost more than it saved |
| S2/S3/S4 | Sonnet | **orchestrator (Opus)** | see below |
| S5 #1080 | Sonnet med | Sonnet | |
| S6 #1082 | Sonnet med | Sonnet | |
| S7 memo | Sonnet med | Sonnet | |
| S9 verify | **Opus high** | Opus, fresh context | **the slice that earned the plan** |
| S8/S10/S11 | Haiku / orchestrator | orchestrator | |

**ADAPTIVE:** S3 was planned as a Sonnet build child and executed by the orchestrator on
Opus instead. Justified in hindsight — it turned into coupled judgment across three
functions plus an estimand escalation — but it was **not recorded at the time**, which is
the reportable part. Fan-out budget respected: **6/6 children**, one ceiling (S9), no
seventh.

**ADAPTIVE:** the plan recorded that D-151/D-152 could not be executed (non-interactive
session: usage bars unreadable, `/model` unavailable to the agent). The user switched to
Fable and later to Opus mid-run. Recorded, not a defect.

### 4. Safety gates — ON PLAN

Phase 0.2 lane pre-flight ran (foreign lanes active; `#1092` verified unclaimed by
assignee, comments, PR, and branch). Phase 0.25 sweep receipt present and **non-vacuous** —
each line cites its command or query, and the deterministic grep found `LESSONS.md:2337`
after the semantic search returned nothing relevant. D-88 respected: ~20 live Cursor
`mspl-*` lanes own the VA/EVA/MSPL gradient sites and were not touched. D-139/D-50 not
triggered (no campaign). Local-checks-before-push honoured in intent; see axis 6.

### 5. Public claims — ON PLAN, one correction

No export, no NEWS, no README, no capability promotion. `#1082` is fenced as one example
awaiting reader-path review. Register rows carry evidence paths.

**Correction recorded:** the after-task report initially stated the math contract over
`theta_rr_B` alone and claimed 11/11; both were amended to the two-block contract and
19/19 once the review landed. A stale check claim ("re-run clean") was replaced with **no
check verdict is claimed** — two runs are void (one polluted by a self-inflicted log file
inside the package, one superseded by the fix).

### 6. Handoff state — OPEN AT WRITING

Three PRs open, CI in flight; a third `devtools::check` running against corrected code. No
`--as-cran` claim made. Nothing is `CARRIED-OVER` in the sense of unlanded work: every
lane is pushed and its state is described in its PR.

## Drift ledger entry

| Class | Instance | Owner |
|---|---|---|
| *Verification design proves the fix runs, not that the fix is complete* | #1092 first version: 11/11 green on a no-op; every fixture exercised one of two penalised blocks | Rose — candidate `LESSONS.md` entry extending `:2337` |

Worth aggregating monthly if it recurs: the near-identical shape appeared **twice in one
day in the same defect** — Design 122 §15 fixed TEST A and left the other readers; this
lane fixed the readers and left the second block. Both passed their own tests.

---

# Addendum — the mixture ultra-plan (Arcs A + B), same day (Melissa)

**Plan:** the approved A+B mixture plan. **Verdict:** delivered; one drift class
RECURRED and is now ledger-worthy.

- **Scope:** A complete (narrow pushed to #1106 with decisions + honest check chain;
  #1103/#1105 merged; #1106 handed over unmerged). B complete through the repair cycle;
  PR correctly withheld pending #1106 (the plan's own gate). DEFER fence held.
- **Evidence:** fail-first honoured in B1/B2 and in the repair; B3's docs-only
  exception stated. Full check deferred to PR-open with the contention reason recorded
  — adaptive, not drift.
- **Routing:** as planned (2 Haiku scouts, 1 reused Sonnet builder across 8 commits,
  1 Opus ceiling refute). Budget 4/6 children, 1/1 ceiling.
- **Safety gates:** preflight re-run; foreign lanes untouched; compiler-race
  infrastructure failures were NOT pooled with estimator/test failures — twice.
- **DRIFT (recurring class):** *"instrument fixed at one member of its class"* —
  third instance in one day (TEST A/K1 · theta_rr_B/spde · sd_B/sd_W), the last
  DESPITE the rule being verbatim in the builder brief. Route to Rose for
  [[PLAN-DRIFT-LEDGER]] as a class: prose rules do not survive contact; require the
  structural form (shared named constant/map) + adversarial refute for ANY instrument
  fix. The refute stage caught it both times it ran — it is load-bearing, not
  ceremonial.
