# Session Handoff: three open PRs to land, then resume the `B_lv` ADEMP coverage campaign

**Meta:** 2026-07-09 · from Claude (Ada) · fresh-session recommended · **TARGET = the next Claude.**

You are the next Claude, taking over `gllvmTMB`. This is a **state handoff, not a mid-task one** — no
code work is dangling in the working tree. The frontier is **three open PRs** (all low-risk, all yours to
merge) plus the still-open **`B_lv` calibrated-interval evidence** arc that a one-cell pilot has now begun.

Read this, verify the three PRs' CI, land them, then continue the coverage campaign.

---

## Critical Context (read before you touch anything)

1. **Three PRs are open and waiting — land them, don't rebuild their work.**
   - **[#737](https://github.com/itchyshin/gllvmTMB/pull/737)** `docs/multilatent-capability-findings` —
     docs-only capability record (multi-latent tiers, functional-phylo/QG recipes). **MERGEABLE / CLEAN.**
   - **[#738](https://github.com/itchyshin/gllvmTMB/pull/738)** `claude/arc-b-funcphylo-validation` —
     **finishes Arc B**: functional-phylogeography validated (12/12 converged, spatial loading cosine
     median 0.993), extractable (#588 was already fixed on `main` `35fe3513` → closed), documented
     (`docs/design/78-functional-phylogeography-recipe.md`). Tests + docs only, no engine source.
     **MERGEABLE / CLEAN.**
   - **[#739](https://github.com/itchyshin/gllvmTMB/pull/739)** `claude/fix-723-mixed-family-extractors`
     (the branch you are on) — greens the **nightly `full-check`** (issue #723). **MERGEABLE / UNSTABLE**:
     every check passes *except one `recovery` job still `pending`* — it is the last green away from mergeable.

2. **#723 was largely STALE — the CI fix is test-expectation + config, not an engine change.** The 27
   mixed-family M1 extractor failures #723 describes were **already fixed on `main`**; the 07-09 nightly was
   down to 3 failures, all stale test expectations: a fixture size hardcoded at 60 that #715 rebuilt to
   `n_sites=240`, and four `expect_equal(opt$convergence, 0L)` sites the converged-verdict arc had retired.
   #739 migrates them to `expect_converged()`, silences a 42k-line bootstrap log flood
   (`fit-multi.R:4204` → `.frequency = "once"`), and makes `full-check.yaml` ubuntu-only for nightly/dispatch
   (Windows was hitting the 120-min cap), full 3-OS on release tags only.

3. **The scale-free convergence verdict is now infrastructure — use it, don't re-hand-roll `pdHess`.**
   Merged since the 07-08 handover: `fit_health$converged` (`e41ff288`) and `expect_converged()`
   (`R/diagnose.R`), with **46 skip-guard test files migrated** through it and a **CI vacuity guard**
   (a gate that skips every cell must not pass, `4859aa28`). This is the *"`pdHess=FALSE` is not failure"*
   doctrine turned into a testable verdict. New gated recovery/coverage tests should route through
   `expect_converged()`, never raw `nlminb` status codes.

4. **The `B_lv` CI trio is STILL BUILT + exported on `main` — do not rebuild it.** (Unchanged from 07-08.)
   `extract_lv_effects()` (Wald), `profile_ci_lv_effects()`, `bootstrap_ci_lv_effects()`, analytic gradient
   for the refit driver — all on `main`. The remaining work is **evidence**, not machinery.

5. **The coverage campaign has now STARTED — a one-cell pilot exists (local, untracked).**
   `results/lv-effects-ci-coverage/gauss-S60-K1-smalln/task-00001.csv` is a single-task pilot from
   `dev/lv-effects-ci-coverage.R`. **`results/` is untracked and never-commit** (heavy sim output) — do not
   `git add` it. This is the *"ADEMP campaign, heavy compute"* work: scale it up on **Totoro or DRAC**, not a
   laptop.

---

## Goals / mission
Drive **gllvmTMB to v1.0**. Headline feature: **structured × X_lv** (maintainer-approved FULL v1.0 scope,
2026-07-07), which already composes + recovers `B_lv` in R as orthogonal **Model A**
(`docs/design/76-structured-xlv-phylo.md` §7). Per maintainer: **finish the R capability first**; Julia parity
and the public article come last. **Point recovery ≠ calibrated intervals — keep separate.**

## Plans / roadmap (beyond the immediate steps)
- **Now:** land the three PRs; resume the `B_lv` ADEMP coverage campaign → close `CI-08`/`CI-10` → promote
  `LV-08` *only* on delivered, Rose-audited evidence.
- **Then:** native-TMB `B_lv` CIs (#19), mixed-family `X_lv`, R↔Julia parity, the public article.
- **Post-1.0 (not now):** generic multi-tier reduced-rank (Arc B rescoped this to post-1.0); ELR (#24);
  boundary chi-bar-square cutoff (#23); exotic-family `X_lv`.

---

## What changed since the 2026-07-08 handover (already merged to `main`)
- **Convergence-verdict arc** — `#733`–`#736`: `fit_health$converged` + `expect_converged()`, 46 skip-guard
  files migrated, CI vacuity guard, phylo-q assertions moved to the optimum not the status code.
- **Variance-readout fixes** — `4b406514` (H² denominator = species-level variance), `20ab493f` (each diag
  covstruct claimed by exactly one tier).
- **Arc B design investigation** — captured in the still-open #737/#738 (multi-latent tier map, the
  `cluster` -keys-tree / `unit` -keys-co-located-latent routing rule, `cluster2` diagonal-only + hard-rejected
  in TMB, QG structural aliases).

## Current Working State
- **Working / green:** `origin/main` @ `882e4c8c`. Local working tree clean except the untracked
  never-commit `results/` pilot dir.
- **In progress (open PRs):** #737 (clean), #738 (clean), #739 (one `recovery` check pending, rest green).
- **Barely started:** the `B_lv` coverage campaign — one pilot cell only.
- **Stale docs (tracked, #14):** the two interacting-model execution-plan docs
  (`docs/dev-log/2026-07-06-option-a-xlv-phylo-*.md`) still describe the superseded model — revise to Model A
  or mark superseded.

## Key Decisions & Rationale (still binding)
- **Model A (orthogonal), not the interacting model** — Design 76 §7. No new likelihood, no grammar change.
- **Profile is the hero interval, t-based cutoff** (D-12 / #22). Wald + bootstrap are the flanks.
- **`pdHess=FALSE` is not failure** — route CIs through profile/bootstrap; the converged verdict now encodes this.
- **Arc B rescoped** to validation + docs; generic multi-tier RR deferred to post-1.0 (maintainer framing:
  spatial structure is the object of inference, phylogeny is a diagonal control).

---

## Landing State (git ledger)

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| `docs/multilatent-capability-findings` | y | y | [#737](https://github.com/itchyshin/gllvmTMB/pull/737) CLEAN | **CARRIED-OVER** — ready to merge |
| `claude/arc-b-funcphylo-validation` | y | y | [#738](https://github.com/itchyshin/gllvmTMB/pull/738) CLEAN | **CARRIED-OVER** — ready to merge |
| `claude/fix-723-mixed-family-extractors` `b0864aba` | y | y | [#739](https://github.com/itchyshin/gllvmTMB/pull/739) UNSTABLE | **CARRIED-OVER** — merge once the pending `recovery` check goes green |
| `handover/2026-07-09-claude` (this doc + CLAUDE.md pointer) | y | y | this PR | **LANDED on push** — docs-only, human merges |
| `results/lv-effects-ci-coverage/` (pilot output) | **n** | n | none | **NEVER-COMMIT** — untracked heavy sim output, leave on disk |

**Why carried-over, not landed:** #737/#738/#739 are self-mergeable low-risk PRs (docs / tests / CI-config),
but per the merge-authority rule I am not auto-merging on your behalf at a handover boundary — #739 also has a
check still pending. Resume command for each: `gh pr merge <n> --squash` once green.

---

## Next Immediate Steps (ordered)
1. **Verify + land the three open PRs** (all low-risk → your merge authority):
   ```sh
   gh pr checks 739          # wait for the pending `recovery` job to go green
   gh pr merge 737 --squash  # docs, CLEAN
   gh pr merge 738 --squash  # Arc B validation, CLEAN
   gh pr merge 739 --squash  # once UNSTABLE → green
   ```
   Merge #737/#738 first (they are CLEAN now); #739 the moment its last check passes.
2. **Confirm the two carried-over maintainer blockers are still open** (they were open at 07-08; verify they
   were not settled in between): the **profile t-df default** (`n_units − d − 1` vs adaptive `df_eff`) and the
   **compute venue** (Totoro vs DRAC). Both gate the campaign — settle *before* running at scale.
3. **Scale the `B_lv` ADEMP coverage campaign** from the one-cell pilot. Runner: `dev/lv-effects-ci-coverage.R`
   + `dev/lv-effects-ci-coverage-slurm.sh` (and the Wald sibling `dev/lv-wald-coverage.R`). Per Design 76 §5:
   ≥500 reps/cell, **target-explicit** coverage, **MCSE**, **failed-fit denominators**. Include the known-hard
   `p=80, K=2, λ=0.5` cell **sized up** (under-powered, not broken — the #715 lesson). Stream per-seed to disk.
   **Ask "Totoro or DRAC?" before launching** — standing default, this is not a laptop job.
4. **Only then** close `CI-08` / `CI-10` and promote `LV-08` — **strictly on delivered evidence, Rose audit
   first**. `docs/design/61-capability-status.md` forbids promotion until the pilot reports coverage + MCSE +
   denominators.
5. **Housekeeping:** revise or mark-superseded the two stale interacting-model docs (#14).

## Blockers / Open Questions
- 🔴 **Maintainer — profile t-df choice** (step 2). Changes every interval the campaign measures. Settle first.
- 🔴 **Maintainer — compute venue** (Totoro vs DRAC) for the ADEMP campaign.
- 🟡 **#739's last `recovery` check** is pending — merge is blocked only on it going green (not a code problem).

## Gotchas & Failed Approaches (do not retry)
- **Do NOT `git add results/`** — untracked, never-commit heavy sim output.
- **Do NOT rebuild the `B_lv` trio or the interacting model** — trio is on `main`; Model A composes existing
  capabilities.
- **Do NOT trust `git branch -a` as evidence of parked work** — measure `git rev-list --count origin/main..<b>`.
- **`gh pr checks --watch` can exit 0 on a STALE run** — re-read `gh pr checks <n>` for the HEAD commit before
  merging.
- **`obj$report(fit$opt$par)` errors ("Wrong parameter length")** — `B_lv` is a pure function of the *fixed*
  params; compute from `fit$opt$par` by name (`theta_rr_B`, `alpha_lv_B`).
- **Route recovery/coverage assertions through `expect_converged()`**, not raw `nlminb` status — that raw
  assertion is exactly the platform-flaky pattern #739 just retired in four places.

---

## Mission control

| Item | State |
|---|---|
| Repo / branch | `gllvmTMB` @ `origin/main` = `882e4c8c` · tree clean (bar untracked `results/`) |
| Open PRs | **#737** docs CLEAN · **#738** Arc B CLEAN · **#739** CI UNSTABLE (1 check pending) — all low-risk, mergeable by you |
| Just shipped (main) | scale-free convergence verdict (`fit_health$converged` + `expect_converged`, 46 files migrated) · variance-readout fixes |
| `B_lv` CI trio | **BUILT + exported on main** — Wald ✓ · profile ✓ · bootstrap ✓ · analytic gradient ✓ |
| Structured × X_lv | **Model A composes + recovers in R** (Design 76 §7) — no new likelihood |
| The actual gap | **Calibrated-interval evidence** — `CI-08`/`CI-10` open/failing gates; 1-cell pilot in `results/` |
| Next arc (by leverage) | 1) land 3 PRs → 2) settle t-df + venue → 3) scale ADEMP coverage on Totoro/DRAC → 4) close CI-08/CI-10, promote LV-08 on evidence |
| Version | DESCRIPTION stays `0.2.0` until the 0.3.0 cut |

---

## How to Resume
1. **Rehydrate, in order:** this doc → `docs/design/76-structured-xlv-phylo.md` §7 (Model A) →
   `docs/design/61-capability-status.md` (CI-08/CI-10 gates; register discipline) →
   `docs/design/78-functional-phylogeography-recipe.md` (Arc B, once #738 lands) →
   `docs/dev-log/handover/2026-07-08-claude-handover.md` (prior arc) → `AGENTS.md` / `CLAUDE.md` →
   `~/.claude/memory/memory_summary.md` (D-12 profile doctrine, compute defaults).
2. **Confirm state, don't assume it:** `git log --oneline -6 origin/main`; `gh pr list`;
   `gh pr checks 739`.
3. Speak as **Ada**. Spawn **Rose** before any public/register claim — `LV-08` / `CI-08` / `CI-10` are register
   gates and coverage inference is correctness-critical.
4. **Claude vs Codex:** land the PRs, design the ADEMP, write the runners + prose **here**; hand the **live
   heavy campaign** (real fits at scale, `R CMD check`, rendering) to **Codex** or straight to **Totoro/DRAC**.

### One-command resume (paste in your authenticated terminal, from the repo root)
- **Interactive:**
  ```
  claude "Rehydrate from docs/dev-log/handover/2026-07-09-claude-handover.md + the CLAUDE.md pointer. First land the three open PRs (#737, #738 are CLEAN; #739 the moment its pending recovery check goes green). Then confirm the maintainer's profile t-df and compute-venue calls are still open, and resume the B_lv ADEMP coverage campaign from the one-cell pilot in results/ — tell me whether it should run on Totoro or DRAC before launching at scale."
  ```
- **Autonomous, clean context:** same prompt via `claude -p "…" --max-budget-usd <cap>`.
