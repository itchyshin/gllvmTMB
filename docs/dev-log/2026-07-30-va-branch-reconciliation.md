# VA/EVA branch reconciliation — content vs. commit-count, 2026-07-30

**Author:** Claude (Ada's reconciliation scout), worktree `/private/tmp/gllvmtmb-va-in-06`,
branch `claude/va-in-06-20260730`. Read-only git operations only throughout (no checkout,
merge, rebase, push, or branch deletion).

**Task:** the 2026-07-29 handover (`docs/dev-log/handover/2026-07-29-claude-handover-LANE2-va-eva.md`)
claims "~90 unmerged commits of VA/EVA work across at least twelve branches." Raw
`git rev-list --count` is misleading for squash-merged branches (proven case: PR #798 was
squash-merged as `72c2e53d`, so `claude/va-wiring-20260726` still shows 19 "unmerged" commits
by SHA even though its content is in `main`). This report re-derives a verdict per branch from
**content**, not commit counts.

---

## 0. Lane ownership — read this first

### 0a. Codex-lane preflight (the anticipated hazard)

`bash ~/shinichi-brain/tools/lane_preflight.sh` (run from this worktree):

```
─── LANE PRE-FLIGHT · gllvmtmb-va-in-06 · last 12h ───
 ME              : claude   (foreign lane = codex)
 OPEN PRs        :
      #860   claude/session-handover-20260730b          docs(handover): Claude → Claude close for the scale-consta
 origin/main     : 55 commit(s) in last 12h
───
 VERDICT         : no codex lane detected in the last 12h
                   Silence is WEAK evidence, not proof of sole ownership (D-87). A lane opened
                   minutes ago, or working uncommitted, is invisible here.
 STATE THIS LINE : PLATFORM: claude | LANE: <subject> | FOREIGN LANE: <none/codex+PR#>
───────────────────────────────────
```

`bash ~/shinichi-brain/tools/session_ownership.sh`:

```
──────── SESSION OWNERSHIP ────────
 PLATFORM        : Claude Code
 REPO            : gllvmtmb-va-in-06  (code repo — STRICTLY sequential; no sanctioned concurrent writer)
 CONTINUING FROM : Shinichi Nakagawa · 2026-07-30 · Merge pull request #853 from itchyshin/handover/2026-07-30-claude-close
 NEWEST HANDOVER : docs/dev-log/handover/2026-07-30-to-la-aghq-ridge-lane-gaussian-findings.md
 WORKING TREE    : clean
 STATE THIS LINE : PLATFORM: Claude Code | CONTINUING FROM: <who/none> | HANDS TO: <who/none>
───────────────────────────────────
```

For the five `codex/*` branches in scope (`design87-eva-parity-admission-20260723`,
`design100-progress-oracle-20260724`, `design102-recovery-envelope-20260724`,
`design103-covariance-mechanism-20260724`, `design90-eva-reliability-atlas-20260723`):
**no open PR** (`gh pr list --state open --search "head:<branch>"` empty for all five, and a
broader `gh pr list --state open` scan for any `design8[6-9]|design9[0-9]|design10[0-3]|va-|eva-`
head-ref returns zero rows), and the newest commit on any of them is **2026-07-25**, five days
before this audit. **Verdict: no live Codex lane on this specific subject.** These branches are
Codex-owned and this report does not merge, modify, or claim any of them — analysis is read-only,
per the mandate.

### 0b. A different, more urgent finding: my own assigned worktree is being actively, concurrently written to — by this same session, not Codex

This needs to be surfaced prominently even though it is not the Codex collision the task
anticipated. Mid-task, with only read-only `git`/`gh` commands run from me (`status`, `branch`,
`log`, `fetch`, `ls-remote`, `diff`, `show`, `cat-file`, `grep`), this worktree's `HEAD` moved:

| when checked | HEAD | source |
|---|---|---|
| task start | `c473364e` (2026-07-30 17:32, merge PR #853) | matches the brief |
| mid-task | `9b1e1cc0` | 2 new commits, not made by me |
| just before writing this report | `bf5adabb` | 4 new commits total, not made by me |

`git log --oneline c473364e..HEAD` at report time:

```
bf5adabb prereg(gate3): pre-register Gate 3 before any run; Gates 0/1/2 all PASS
c1bb7517 evidence(gate01+estimator): Gates 0/1 PASS; the GH-over-JJ choice is REJECTED
9b1e1cc0 fix(fence): q <= 2, not q <= 4 — the fence exceeded the gate it cites
f1550f25 docs(decision): VA ships in 0.6 — Amendment 1 reversed on admission
```

plus an untracked `dev/va-gate3/` directory present at report time. `git merge-base --is-ancestor
HEAD origin/main` is false — **these commits are local-only to this worktree, not on `origin/main`
or any remote ref** (confirmed: `git log --oneline origin/main --grep="VA ships in 0.6"` and
`--grep="q <= 2, not q <= 4"` both return nothing).

Reading the content explains it rather than raising alarm: `f1550f25` is
`docs/dev-log/2026-07-30-va-ships-in-06-reversal.md`, a maintainer decision record (Shinichi,
recorded by Claude, today) that **reverses the 2026-07-21 cut and ships an opt-in, hard-fenced
`engine = "va"` in 0.6** (binomial-logit + poisson-log, `latent(unique=FALSE)` only, `q<=2`,
`p<=80`, `n>=100`, no intervals). The untracked file I read mid-task,
`docs/dev-log/2026-07-30-rose-default-tier-reversal-gate.md`, opens with: *"Worktree:
`/private/tmp/gllvmtmb-va-in-06`, branch `claude/va-in-06-20260730`, at `origin/main` `c473364e`.
Read-only except this file."* — i.e. **another agent (Rose, adversarially reviewing a proposed
`default_tier` flip in the already-merged `R/va-r3-proto.R`) was given the identical worktree and
an identical read-only-except-my-own-file contract to mine**, and the commits above are almost
certainly Ada/main consolidating that swarm's output (Rose's review references "Fisher" and
"Polya" by name as the arguments she is rebutting, matching the `fisher`/`polya` names in this
session's addressable-agent list).

**Conclusion:** this is very likely a deliberate multi-agent adversarial-review pattern running
concurrently in the same worktree (each agent scoped to its own file), not a hostile lane
collision — but it is exactly the kind of bleed-through D-88 says to surface rather than assume
is fine. I made no attempt to interfere, commit, or resolve it; I only read. Two consequences for
this report: (1) my twelve-branch comparisons below hold against the frozen baseline
`origin/main@c473364e` stated in the brief, and I confirmed the 10 commits `origin/main` itself
gained during this session (`c473364e..origin/main`, now at `16448745`) touch no VA/EVA file
except one adjacent cross-lane handover
(`docs/dev-log/handover/2026-07-30-to-hvt1-va-r3-lane-variance-domain-gate-scale.md`, a
scale-constant-audit note about a gate in `R/va-r3-proto.R`, unrelated to branch mergedness) — so
none of the twelve verdicts below change. (2) **The "bearing on `engine=` wiring" answer for
several branches changes substantially as of today**: `engine="va"` is no longer a frozen/cut
research question, it is an approved, actively-gated 0.6 target, and the gate work (Gates 0–3) is
being executed live in this same worktree right now. That live work already covers the
JJ-vs-GH `default_tier` question end to end — this report does not duplicate it.

---

## 1. Method

Baseline throughout: `origin/main` at `c473364ee54fa24ae909c52af52e35ca46f4924f` (the SHA named in
the brief), fetched via `git fetch origin --prune`. `gh auth status` confirmed authenticated
(`itchyshin`, scopes `gist read:org repo`), so PR lookups are live, not git-only fallback.

Per branch:

```sh
git rev-list --count origin/main..origin/<branch>                       # raw (misleading) count
git log -1 --format='%ci %an %s' origin/<branch>                        # recency
gh pr list --state all --limit 200 --search "head:<branch>" \
  --json number,title,headRefName,state,mergedAt                        # PR lookup
git diff --name-status origin/main...origin/<branch>                    # 3-dot: what the branch adds since its fork
git diff origin/main origin/<branch> -- <file>                          # 2-dot: tip vs tip, per file
git cat-file -e origin/main:<file>                                      # existence check
git merge-base --is-ancestor origin/<branch-a> origin/<branch-b>        # ancestry between branches
```

A file with a 2-dot tip-diff of 0 is byte-identical to `main`. A non-zero diff was inspected line
by line to classify it as (a) whitespace, (b) `main` having evolved further (branch is an older
subset — not missing content), or (c) genuinely absent/divergent content.

---

## 2. Per-branch table

| Branch | Raw count | Verdict | Evidence | Bearing on `engine=` wiring |
|---|---:|---|---|---|
| `codex/design87-eva-parity-admission-20260723` | 37 | **SUPERSEDED** | Identical commit to `codex/design86-arc2r-20260723` (`f805bd5a`; confirmed `git rev-parse` on both refs). Only 2 package-surface files touched (`R/eva-proto.R`, `inst/tmb/gllvmTMB_eva.cpp`); both exist in `main` but as strictly *newer* versions (landed via commit `4dcf3d80`/`e5a59ba0`, part of merged PR #797 on `claude/va-wiring-20260726` — a different lane). `git diff origin/main origin/codex/design87… -- R/eva-proto.R`: 297 lines `main` has that the branch lacks vs. 1 the branch has that `main` lacks — main is a refined superset. The ~40 `dev/design86-*` and `docs/design/86-*`/`docs/dev-log/2026-07-2[2-3]-design86-*` files (contract, gate briefs, arc diagnostics, parameter JSON) are entirely absent from `main`. No open PR; last commit 2026-07-23. Independently corroborated by `dev/eva-record/EVA-RECORD.md` §4: *"UNKNOWN — no distinct design exists… the two branch diffs are empty."* | None directly. Design 86's admission path was formally retired 2026-07-23 (`HISTORICAL_MECHANISM_UNOBSERVABLE`). Today's `engine="va"` fence (GH-quadrature, binomial-logit+poisson-log, q≤2) is a different, narrower route than this arc's EVA/JJ exploration. |
| `claude/va-wiring-20260726` | 19 | **MERGED-IN-SUBSTANCE** | **PR #797** (merged 2026-07-27T12:33:07Z) and **PR #798** (merged 2026-07-28T11:54:48Z), both confirmed via `gh pr list --search "head:claude/va-wiring-20260726"`. Every file in the branch's 3-dot diff (`R/va-r3-proto.R`, `R/approximation-engine.R`, `inst/tmb/gllvmTMB_va_r3.cpp`, all `dev/aghq-*`, `docs/design/109-*`, all `docs/dev-log/2026-07-2[7-8]-*`) is byte-identical (`0`-line tip diff) in current `main`. Only `CLAUDE.md` shows a non-zero tip diff (169 lines) — confirmed by content inspection to be *later* lanes continuing to edit `CLAUDE.md`, not missing content: `git log --oneline origin/main -S "per-family registry" -- CLAUDE.md` returns `72c2e53d VA: family registry, calibrated standard errors, and three retractions (#798)`, and current `CLAUDE.md` line 112 carries the same text marked "(historical; see the bullet above)". | **High.** This branch *is* the `engine="va"` substrate — `R/va-r3-proto.R`, `R/approximation-engine.R`, the family registry, calibrated SEs. |
| `codex/design100-progress-oracle-20260724` | 15 | **SALVAGE** | Zero `R/`, `src/`, `inst/`, `NAMESPACE`, `DESCRIPTION` changes (confirmed via filtered `git diff --name-status`). 100% `dev/design9[5-9]-*`, `dev/design10[0-1]-*` (a JJ/VA "progress oracle" supervision harness + comparator experiments) and matching `docs/design/9[5-9]-*.md`, `docs/design/100-*.md`, `docs/dev-log/{after-task,handover,plan-actual}/2026-07-2[3-4]-design*` records — `git ls-tree -r --name-only origin/main \| grep -c 'design100\|design101\|design95\|design96\|design97\|design98'` = 0. No open PR; last commit 2026-07-25. | Low/indirect. Research-process record of the JJ-route exploration (designs 95–101), all closed `NO_GO`/`TECHNICAL_(IN)COMPLETE`/`INFRASTRUCTURE_(IN)COMPLETE` per `EVA-RECORD.md`. The live JJ-vs-GH `default_tier` debate happening in this same worktree right now supersedes needing to revisit this. |
| `claude/design86-eva-contract-20260722` | 13 | **SUPERSEDED** | `git merge-base --is-ancestor origin/claude/design86-eva-contract-20260722 origin/codex/design87-eva-parity-admission-20260723` → **true**: this branch is a direct git ancestor of the Codex arc above. All 4 files (the original Design 86 contract, gate-1 brief, ultra-plan, and the Codex handover that kicked off the arc) are absent from `main`; the contract file survives, extended, only inside the (also-unmerged) Codex branch. | None directly — historical only (Design 86 retired 2026-07-23). |
| `claude/va-implementation-20260725` | 3 | **GENUINELY UNMERGED CODE** | `.va_r3_check_separation()` — a ~62-line fail-closed guard in `R/va-r3-proto.R` detecting complete/quasi-complete separation in binomial-logit designs by IRLS divergence — exists on this branch, confirmed **absent from current `main`** (`grep -n "check_separation" R/va-r3-proto.R` → no match; broader `grep -rln "separat" R/va-r3-proto.R R/eva-proto.R R/approximation-engine.R` finds none). The companion change this guard was built to protect — relaxing `n_trials >= 2` to `n_trials >= 1` (admitting Bernoulli data) — **did** independently land in `main` via commit `4dcf3d80` (part of merged PR #797), *without* the guard: `main` currently accepts Bernoulli-shaped binomial VA fits with no separation check. Neither merged va-wiring handover (2026-07-27 or 2026-07-28) mentions "Bernoulli" — the guard was not consciously superseded, just not carried forward. No PR ever opened for this branch. | **Direct and timely.** Today's `engine="va"` fence targets exactly binomial-logit at `n>=100`. Landing this: rebase the ~70-line diff (`git diff origin/main...origin/claude/va-implementation-20260725 -- R/va-r3-proto.R`) onto current `R/va-r3-proto.R`, wire the call into the binomial validation branch, add a test. Small, self-contained, R-only (not a TMB-template edit, so not automatically HIGH-RISK under Design 72 §7). This is the single most concrete, shippable item this audit found. |
| `claude/va-phase1-proof` | 3 | **SUPERSEDED** | PR #431, **CLOSED as DRAFT, never merged** (its own after-task doc, itself separately merged via `va-phase1-record`/PR #432, states verbatim: *"DRAFT PR; do NOT merge. High-risk per CLAUDE.md merge authority."*). Code files (`R/va-proto.R`, `inst/tmb/gllvmTMB_va.cpp`, `inst/tmb/gllvmTMB_la_min.cpp`, `.github/workflows/va-phase1-benchmark.yaml`, `tests/va-benchmark/run-va-benchmark.R`) all confirmed absent from `main` (`git cat-file -e` fails for all 5; `git ls-tree -r --name-only origin/main \| grep -i 'va-proto\|gllvmTMB_va\.cpp\|la_min'` finds nothing under this name). The *findings* (VA converges everywhere Laplace's inner Hessian degenerates but collapses at the exact same n as Laplace — "genuine small-n under-identification, not a VA-specific artefact") were separately preserved on `main` via the merged after-task doc. The prototype's function is superseded by the far more complete `R/va-r3-proto.R` that did ship. | None directly — 2026-06-03 exploratory mechanism-proof, superseded in function; findings already on `main`. |
| `codex/design102-recovery-envelope-20260724` | 1 | **SALVAGE** | Single-commit archival push (`research(102): preserve the private recovery-envelope lane from volatile /private/tmp`). Zero package-surface changes. `dev/design102-recovery-envelope/{PLAN.md,ADJUDICATION-inputs,...}` absent from `main`. No PR; last commit 2026-07-25. | Indirect but substantive: per `EVA-RECORD.md`, "the only lane that ran a full DRAC campaign" (32 seeds × 3 N × 2 regimes, 2,304 attempts) — clean health gate but loading-covariance recovery failed (rel. error ≈0.67–3.36 at N=240). Worth reading as background for anyone extending Gate 3's covariance-recovery bar; not code to land. |
| `codex/design103-covariance-mechanism-20260724` | 1 | **SALVAGE** | Same single-commit archival pattern. `dev/design103-covariance-mechanism/ADJUDICATION.md` diagnosed Design 102's failure but adjudicated only 1 of 4 candidate mechanisms (ruled out *selection*); closed `TECHNICAL_PARTIAL`. Absent from `main`. No PR; last commit 2026-07-25. | Indirect — an open mechanism question (why does covariance recovery fail at N=240 with a clean numerical-health gate?) that a future, larger-n Gate-3 run may re-encounter. |
| `codex/design90-eva-reliability-atlas-20260723` | 1 | **SALVAGE** | Same archival pattern. `docs/design/90-upstream-eva-reliability-atlas.md` + 5 result JSON/RDS fixtures absent from `main`. No PR; last commit 2026-07-23. | None direct — targeted upstream released `gllvm`'s EVA reliability, not gllvmTMB's VA; closed `NO_GO` (terminal smoke stop) per `EVA-RECORD.md`, explicitly "not evidence about gllvmTMB." |
| `claude/va-feasibility-audit` | 1 | **MERGED-IN-SUBSTANCE** | **PR #430** merged 2026-06-03T07:35:15Z (`gh pr list`). Both files (`docs/design/72-variational-approximation-feasibility.md`, its after-task doc) present in `main`; the after-task doc is byte-identical (0-line diff). The 55-line diff on the design doc is entirely explained by a *later*, also-merged branch (`va-phase1-record`) amending the same file — confirmed by diffing that file against `claude/va-phase1-record`'s tip, which is 0. | Foundational — Design 72 is cited repeatedly in today's reversal record (its Phase-1 falsifying finding; its §7 TMB-edit governance rule). |
| `claude/va-phase1-record` | 1 | **MERGED-IN-SUBSTANCE** | **PR #432** merged 2026-06-03T08:33:12Z. All 3 files (`docs/design/72-*.md`, the after-task doc, `docs/dev-log/check-log.md`) byte-identical against `main`. | Historical, already fully absorbed. |
| `claude/eva-record-consolidation-20260725` | 1 | **SALVAGE (high value)** | `dev/eva-record/EVA-RECORD.md` (368 lines) — a fully-cited, cross-branch synthesis of the *entire* Designs 72/85–103 VA/EVA programme, decision timeline, gate ladders, and 4 governance-ledger contradictions (`LOOP/decision-queue.md` vs. `LOOP/GOAL.md` vs. the retired Design-86 contract vs. `CLAUDE.md`/`AGENTS.md` silence). Committed via `754a45f6`, message: *"rescue: land uncommitted scratch-worktree work before reclaim… No merge to main, no decision taken about the work itself."* Confirmed absent from `main`. Independently corroborates several of this report's own findings (the design87≡design86-arc2r identity; the codex branches' lack of package-surface changes) — found *after* I had already derived them independently, not before. **Caveat:** dated 2026-07-25, i.e. before PR #797/798 (2026-07-27/28) and before today's Amendment 4 reversal — its "nothing about EVA is admitted into gllvmTMB" bottom line is now stale on both counts and needs a dated addendum before anyone relies on it as current. | High — best available single source on "what happened before" Designs 86–103; whoever finishes Gate 3 for `engine="va"` should read it. Recommend landing to `main` (docs-only, low-risk per CLAUDE.md's merge-authority rules) with a short addendum noting the 07-27/28/30 developments, rather than leaving it stranded on a rescue-commit branch. |

Raw-count sum: 37+19+15+13+3+3+1+1+1+1+1+1 = **96**, consistent with the handover's "~90" estimate.
Verdict counts: **MERGED-IN-SUBSTANCE 3 · SALVAGE 5 · GENUINELY UNMERGED CODE 1 · SUPERSEDED 3 ·
UNKNOWN 0.**

Ancestry check among the five single-commit Codex archival branches
(`design90`/`design100`/`design102`/`design103`, pairwise `git merge-base --is-ancestor`): **none
is an ancestor of another** — each is an independent rescue of a separate `/private/tmp` scratch
worktree, not a chain.

---

## 3. What is genuinely left

1. **The separation guard** (`claude/va-implementation-20260725`, `.va_r3_check_separation()`) —
   real, small, unmerged, and directly in the domain (`n_trials>=1` binomial-logit) that today's
   `engine="va"` fence ships. The one item in this audit worth actually porting.
2. **`EVA-RECORD.md`** (`claude/eva-record-consolidation-20260725`) — the authoritative
   pre-reversal history of the whole VA/EVA programme, unmerged, going stale. Worth landing to
   `main` with a dated addendum rather than left on an orphaned rescue-commit branch.
3. **Three negative/partial DRAC results** (`design90`, `design102`, `design103`) — background
   evidence (upstream `gllvm` EVA reliability NO_GO; gllvmTMB covariance-recovery failure at
   N=240; an only-partially-adjudicated mechanism) worth citing if Gate 3 is extended, not code to
   land.
4. **The JJ-vs-GH `default_tier` question** is already being actively re-litigated in this same
   worktree, live, by a Rose/Fisher/Polya adversarial-review swarm, as of the last hour. This
   report does not duplicate that; see `docs/dev-log/2026-07-30-rose-default-tier-reversal-gate.md`
   and the two decision commits `f1550f25`/`9b1e1cc0` (both currently local-only to this worktree,
   not yet on any remote ref).
5. Everything else in scope (Design 86/87/95–101 EVA/JJ exploration) is closed research history —
   `NO_GO`, `TECHNICAL_(IN)COMPLETE`, or `HISTORICAL_MECHANISM_UNOBSERVABLE` — and does not need to
   be revisited to ship the narrower, GH-quadrature `engine="va"` fence recorded today.

---

## 4. Safe to delete

Content-verified, zero-diff against `main`, Claude-owned (no Codex-ownership concern):

- `claude/va-wiring-20260726` — PR #797 + #798 merged.
- `claude/va-feasibility-audit` — PR #430 merged.
- `claude/va-phase1-record` — PR #432 merged.

Content-superseded, Claude-owned, low risk but not zero — deleting these permanently removes
prototype code that exists nowhere else (function, not findings, since the findings are already
merged elsewhere):

- `claude/va-phase1-proof` — marked "DRAFT PR; do NOT merge" by its own author; superseded in
  function by `R/va-r3-proto.R`. GitHub retains the diff on closed PR #431 independent of the
  branch ref, which softens but does not eliminate the loss.
- `claude/design86-eva-contract-20260722` — fully subsumed (by ancestry) within
  `codex/design87-eva-parity-admission-20260723`, so deleting this ref loses nothing as long as
  that Codex branch still exists.

**Not recommending deletion of any `codex/*` branch** (`design87-eva-parity-admission-20260723`,
`design100-progress-oracle-20260724`, `design102-recovery-envelope-20260724`,
`design103-covariance-mechanism-20260724`, `design90-eva-reliability-atlas-20260723`) despite
several being technically superseded or archival-only in content — branch disposition for
Codex-owned refs is Codex's/the maintainer's call, not something this report should enact or
push the reader toward enacting unilaterally, per D-88.
