# HELD-item reconciliation audit (2026-06-20, Claude/Ada)

Synthesis of a 4-agent **read-only** audit of the four maintainer-HELD
reconciliation items named in the post-#101 handover. Each finding is grounded in
git/gh commands the agents actually ran. **Nothing was merged, deleted, rebased,
or force-pushed.** This memo turns four "decide" items into evidence-based
recommendations with explicit risk tiers.

Repo state at audit time: gllvmTMB `origin/main` = `a040e6d` (8 PRs merged this
session; 0 open gllvmTMB PRs). GLLVM.jl `origin/main` = `186af2d` (#101 merged).

---

## Item 1 — dirty branch `codex/r-bridge-grouped-dispersion` (the working checkout)

**Correction to the handover framing:** the branch is **120 ahead / 7 behind**
`origin/main` (merge-base `0567cd7`), and its PR **#489 is CLOSED**. It also has a
large **uncommitted** working tree (173 modified + 158 untracked files).

- **Net-new value lives ONLY in the uncommitted working tree** — two exported
  functions absent from `main` (`git grep` on `origin/main` returns none):
  - `extract_coevolution_modules` — `R/extract-sigma.R:1574` (~121 lines)
  - `diagnose_kernel_separability` — `R/kernel-helpers.R:311` (~269 lines + 5
    private `.kernel_separability_*` helpers)
  - both with untracked man pages and exercised by enlarged tests
    (`test-coevolution-two-kernel.R` now 2226 lines; `test-coevolution-recovery.R`),
    ~291 net test lines.
- **The 120 committed commits are mostly SUPERSEDED:** the coevolution C++
  (`src/gllvmTMB.cpp`) is **byte-identical** to what `#494` landed; the 41
  julia-bridge commits are subsumed by `#492/#493` (main's `julia-bridge.R` is
  newer/larger); 45 commits are dashboard/heartbeat process noise.
- **Recommendation (confidence: high):** **CHERRY-PICK-SUBSET** — do not
  rebase/merge the branch. Salvage only the two new functions + their helpers +
  man + test deltas into **one focused PR off current `main`** (they layer cleanly
  on `#494`). Abandon the 120 commits and closed #489; discard the check-log
  churn and 149 process artifacts. **Two new public exports = high-risk API →
  needs your sign-off before merge** (per CLAUDE.md).

## Item 2 — GLLVM.jl draft PR #94 (`a1-nongaussian-ci`)

- OPEN/DRAFT, **CONFLICTING/DIRTY**, 176 files, **130 ahead / 129 behind** main
  (the PR body's "26 behind" is stale). No CI configured (no green signal).
- **Genuinely-unique, absent from main** (blob-hash + symbol verified):
  `src/families/genpoisson.jl` (GP-1, citation-grounded, under+over-dispersion),
  `studentt.jl`, `truncpoisson.jl`, `truncnb.jl`, standalone `lognormal.jl`,
  `src/anova.jl` (LRT), `src/diagnostics.jl` (PIT/randomized-quantile residuals),
  + structured-speed prototypes.
- **Most is superseded** by merged `#95/#99/#100/#101` (non-Gaussian engine,
  bridge, missing-data, REML, RE layer); `reml.jl` / `boundary_inference.jl` are
  byte-identical to main; many files are renamed reimplementations.
- **A prior audit of #94 already exists ON MAIN**
  (`docs/dev-log/2026-06-15-pr94-unique-content-audit.md` +
  `…-successor-issue-drafts.md`), same conclusion, with **8 successor issues
  drafted but NONE filed** (verified: `gh issue list` shows only #65/#9).
- **Recommendation (high):** do NOT merge/rebase/broad-cherry-pick.
  **needs-maintainer-split** → **file the 8 already-drafted successor issues**
  (genpoisson + studentt first — most complete), port each as a fresh narrow PR
  onto current main with FD-gradient (≤1e-6) + Poisson-limit + ADEMP tests, then
  **close #94 as superseded by #95**. Filing public issues is outward-facing →
  surfaced for your go.

## Item 3 — GLLVM.jl divergent branch + J2

- **J2** (`claude/jl-bridge-capabilities-20260619`, un-pushed, no PR):
  **ABANDON.** Its sole contribution, a local `bridge_capabilities()`, is fully
  superseded by main's richer #101 `bridge_capabilities()` (confirmed on
  `origin/main:src/bridge.jl:431`, 982-line bridge vs J2's 403). Its own
  after-task already says "fold/do not duplicate #101". Nothing to cherry-pick.
- **Divergent** (`codex/non-gaussian-fitter-gradients`, PR **#60 CLOSED**):
  119 ahead / 128 behind; ~half docs-churn, but carries **real not-on-main
  performance substrate** — `src/structured_schur.jl` (+842, Schur/Woodbury
  logdet), `src/families/structured_poisson.jl` (+1533, structured Poisson
  Laplace), and ForwardDiff/implicit-gradient additions in `laplace.jl`/`fit.jl`
  + dedicated tests. The *inference* capability already reached main via #101.
- **Recommendation (high):** delete J2; for the divergent branch,
  **needs-maintainer-split** — decide whether the **structured-Poisson /
  Schur-Woodbury speed path** is still wanted post-#101. If yes, port those 3–4
  files fresh off main (drop the 58 board-churn commits); if no, abandon (it's
  closed, stale, conflict-heavy).

## Item 4 — unique→Psi convention cascade (`codex/unique-latent-psi-split-20260619`)

- Two bundled lanes. **(A) Julia bridge lane** (commit `07181cf`) is **already
  merged to main** via a separate path → abandon (re-conflicts an older variant).
  **(B) The Psi migration** is the real payload and **not on main**: a
  **grammar/parser/engine change** — `latent()` auto-emits a paired diagonal Psi
  (`residual = TRUE`, `common = FALSE`), `residual = FALSE` opt-out,
  `extract_Sigma(part = "psi")`, new `.auto_residual`/`.auto_psi`/`drop_psi`
  dispatch in `R/fit-multi.R`, and `lifecycle::deprecate_soft()` warnings for
  `unique()`/`*_unique()`. **No `src/` (C++) touches.**
- **Soft-deprecation rule: COMPLIANT** — no removal over-claim; all
  `*_unique()` exports remain in NAMESPACE; NEWS/AGENTS say "remains compatibility
  syntax / do not claim removal while exports are live".
- 11 merge conflicts, **mostly the redundant bridge lane** + a trivial check-log
  append; `brms-sugar.R` adds 88 tab-indented lines into a space-only file (should
  be normalized).
- **Recommendation (high):** **SPLIT-AND-CHERRY-PICK / DEFER.** The Psi migration
  is a **high-risk formula-grammar change → needs your grammar sign-off** (per
  CLAUDE.md/ROADMAP). After sign-off: reconstruct a clean branch off main with
  only the Psi pathspecs, normalize `brms-sugar.R` to spaces, one reviewable PR.
  If the grammar decision is unsettled, **DEFER** the whole lane.

---

## What this session can/should do vs. what needs you

**Autonomous (build + verify, merge held) — actionable now:**
- **Item 1 salvage**: build the two-coevolution-function PR off `main`
  (`extract_coevolution_modules`, `diagnose_kernel_separability` + helpers +
  man + test deltas), verified against main's #494 engine. Merge held for the
  API sign-off.

**🔴 Needs your decision (high-risk / outward-facing):**
1. **Item 1**: approve the two new public exports (then the salvage PR can merge).
2. **Item 2**: approve filing the 8 drafted `#94` successor issues + closing #94.
3. **Item 3**: keep or drop the structured-Poisson / Schur-Woodbury speed path?
   (J2 → abandon either way.)
4. **Item 4**: the `latent()`-carries-Psi-by-default grammar decision — confirm,
   or defer the Psi cascade.

**Safe housekeeping (recommended, not yet done):** delete the un-pushed J2 branch;
`git worktree prune` + remove the worktrees of already-merged branches
(closure1/2/3, coev-integrate, bridge-admission-split, integrate/bridge-overnight).
The HELD branches' worktrees stay until the above decisions land.

*Evidence: workflow run `wf_d37991cd-a1e` (4 read-only agents, 100 tool calls).*
