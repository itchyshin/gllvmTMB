# Handover — Claude team → **Codex team** — gllvmTMB (+ GLLVM.jl)

**Date:** 2026-06-21 · **From:** Ada (Claude lane, autonomous owner-directed) · **To:** the Codex team picking the work back up · **Mode:** push-LIVE, evidence-first, one defended slice at a time.

> **Why you're getting this.** The prior handover (#517, on `main`) recorded the maintainer's
> 2026-06-21 note *"no Codex lane at the moment — it is all Claude now, including the engine."*
> That has now been **reversed**: the maintainer is handing the gllvmTMB + GLLVM.jl work **back to
> Codex**. This note is the complete, self-contained state so you lose nothing. **The repo is
> authoritative — rehydrate from `git`/`gh` + this note + the plan/design files, not from chat.**
> Read top-to-bottom before touching anything. The deeper lineage lives in
> `docs/dev-log/claude-handover-2026-06-21-latent-unique.md` (#517) and
> `docs/dev-log/claude-handover-2026-06-21.md` (the earlier `60fb621`-era note).

---

## 0. Who you are / how to operate

- You are **Ada** for this work: decompose, route to the standing review team, enforce after-task +
  claim-boundary discipline. Owner: **Shinichi Nakagawa**. Correctness over cost. Finish landable
  slices; don't punt.
- **`AGENTS.md` is the source of truth** (you read it natively). `CLAUDE.md` mirrors it for the Claude
  lane. The standing-review roster (mirror in `.codex/agents/*.toml`): **Ada** (orchestrator), **Rose**
  (claim-boundary / scope honesty), **Fisher** (inference), **Curie** (simulation / recovery), **Boole**
  (parser / formula grammar), **Noether** (math / engine contract), **Emmy** (R-API surface), **Darwin**
  (theory / biology), **Florence** (figures — real QA gate, not polish), **Pat** (cross-check), **Grace**
  (figure-quality), **Jason** (cross-package scout), **Shannon** (coordination / cross-team audit).
- **Every promotion/landing is Rose + Fisher verified before it ships, and you re-verify locally
  yourself — do NOT trust a sub-agent verdict.** Both reviewers caught real defects in the Claude arc
  (a silent marker-mismatch byte-identity break; an auto-Ψ regression on binary). The gate works; use it.
- **Division of labour now flips to you:** the **Codex lane runs the live R/TMB + Julia toolchain**
  (real fits, `R CMD check`/`devtools::check()`, simulations, pkgdown, Julia builds) — which is exactly
  the heavy-execution work that was awkward in the Claude lane. There is **no parallel Claude lane** at
  the moment unless the maintainer re-opens one; coordinate via the repo (check-log + after-task + PR
  comments), not chat.

---

## 1. Repos, branches, worktrees, environment (HAZARDS)

### gllvmTMB
- **`origin/main` = `c106df4`** (PR **#518** merged). This is **ahead** of the #517 handover's recorded
  `5e64983` and the older note's `60fb621`. `git fetch` and confirm.
- **`GLLVM.jl` `origin/main` = `c81be2f`** (PR #112, GP-1). Its main checkout
  (`/Users/z3437171/Dropbox/Github Local/GLLVM.jl`) is on `claude/jl-bridge-capabilities-20260619`
  (clean) — not `main`. Switch to a fresh worktree off `origin/main` for new work.

### ★ YOUR dirty branch — the elephant, decide first (§4 item 0)
The owner's MAIN checkout `/Users/z3437171/Dropbox/Github Local/gllvmTMB` is on
**`codex/r-bridge-grouped-dispersion`** — **Codex's own branch**, and it is **stale + dirty**:
- **120 commits ahead / 60 behind `origin/main`** (forked at `0567cd7`); **last commit 2026-06-18**
  (`5346391`, 3 days old).
- **Uncommitted: 173 modified tracked files (+32,828 / −21,509) + 162 untracked** (mostly 2026-06-18
  after-task reports). Proof of staleness: this tree's newest `after-task` is dated **2026-06-19**;
  `origin/main` already carries the **2026-06-20** and **2026-06-21** after-task reports this branch
  never saw.
- **The uncommitted body overlaps work the Claude team has since MERGED:** it is a large
  `unique()`→`indep()` / Ψ **spelling cascade + coevolution** edit, but #508 (article cascade),
  #513 (`unique()` article finish), and **#518** (the `residual`→`unique` rename) all landed since.
  Much of the spelling cascade is therefore **likely superseded**; the **committed coevolution work**
  in the 120 commits may still hold novel pieces worth cherry-picking.
- **GUARD (standing, from both prior handovers): do NOT commit to or revert this branch** as a
  reflex. It is yours, so you *may* decide its fate — but treat it as a deliberate triage decision
  (salvage / rebase / cherry-pick / abandon), not an accidental `git add`. See §4 item 0 for the
  concrete triage recipe.

### Worktrees (clutter to prune)
- gllvmTMB has ~8 `/private/tmp/gllvmtmb-*` worktrees from the day's PRs (most **merged → prunable**)
  plus the **active #519** worktree `/private/tmp/gllvmtmb-phylo-unique-fold` (`c7e21a1`) and the
  superseded #516 worktree `/private/tmp/gllvmtmb-phylofold`. Also `~/.codex/worktrees/5846/gllvmTMB`
  (detached). `git worktree list` to see all; `git worktree prune` the merged ones.
- GLLVM.jl has ~16 **locked** `.claude/worktrees/agent-*` (from a Workflow fan-out — clutter, locked)
  plus your own `~/.codex/worktrees/5846/GLLVM.jl{,-phylo-bridge}` (stale 2026-06-08 Codex branches).

### Environment
- R 4.5.2. Julia 1.10.0 at `/Users/z3437171/.juliaup/bin`. macOS has **no `timeout`**.
- **`cwd` resets to the owner's MAIN checkout between Bash calls** → use absolute paths / `git -C`.
- GLLVM.jl: **never `Pkg.test`** (broken) — run `julia --project=. test/runtests.jl` or include single
  files; **never `git add -A`** (stage by name); bench repo stays LOCAL.

---

## 2. Doctrine (don't violate)

- **Claim boundary.** Keep *fitted* vs *parsed-but-planned* vs *docs/roadmap* separate. Run a
  **missing-cell audit** before any status claim. **Never self-promote** a validation-debt register row
  (Design 35) or a COE-03/COE-04 coverage row — maintainer-gated. No release / CRAN / coverage / power
  claim without the full evidence chain.
- **Merge authority.** Low-risk (docs, dev-log, after-task, audits, design notes, **test-only**
  additions, individual article rewrites, CI/pkgdown/asset tweaks) you may self-merge when CI is green.
  **High-risk needs EXPLICIT per-item maintainer "yes merge":** deletions of public exports, API /
  **grammar** / likelihood / TMB / family changes, broad article rewrites. The `ROADMAP.md` "Discussion
  Checkpoints" set is authoritative (note: that section was lost in a reset — flagged in check-log; a
  candidate canonical home is pending the maintainer).
- **Don't revert Claude/human changes.** Stop for maintainer discussion before deletions, grammar,
  likelihood, family, or broad-article changes.
- **If a gate can't pass honestly, STOP and report blocked** — never weaken a test to go green.

### ★ CANONICAL Ψ MODEL (internalise before touching anything Ψ/`latent`)
`Σ = Λ Λᵀ + Ψ` (Greek **Psi/psi**; the 2026-05-14 reversal supersedes old `S`/`s` and "two-U"; `two_U`
→`two_psi`). Every grouping level decomposes `Σ_level = Λ Λᵀ + Ψ`; **Ψ = specific(residual) part +
distribution(overdispersion) part**:
- **Gaussian & Poisson** — distribution part = 0 ⇒ Ψ is *only* the specific term ⇒ **the ONLY families
  where an explicit `unique()` was ever needed.**
- **All other non-Gaussian** (NB1/NB2, Beta, Gamma, GP-1, lognormal, Tweedie, Student-t, …) — specific
  part ≈ 0, overdispersion **already carried by the family's own dispersion** ⇒ explicit Ψ is
  **REDUNDANT (double-counts).** *"non-Gaussian is the key."*
- **Binary/Bernoulli (single-trial)** — no free dispersion (like Poisson) BUT Ψ is **UNIDENTIFIED**
  (the link's implicit scale *is* the between-unit residual) ⇒ must **auto-skip** Ψ. This was the #509
  bug; multi-trial binomial (`cbind`, `n_trials>1`) is identified and left alone.
- **Identifiability framing (for the article/docs — the maintainer cares):** the *total* `Σ_level` is
  identified for all families/levels/mixed (**the selling point**); the shared/specific **split** is
  rank-K + replication-sensitive (**phylo is the worst case** — one tree = one realization). Lead with
  **total Σ + correlations**; present the split as an ordination *view* with rank/replication caveats;
  prefer **communality** `h²ₜ = (ΛΛᵀ)ₜₜ / Σₜₜ` over raw specific variances in user prose.

### ★ GRAMMAR NOW (post-#518 — this CHANGED since memory/the older note)
- The `latent()` argument **`residual=` was RENAMED to `unique=`** (PR #518, `656ead1`), with
  `residual=` kept as a **one-shot soft-deprecated alias**. So: `latent(..., unique=TRUE)` (**default**)
  → `Σ = ΛΛᵀ + Ψ`; `latent(..., unique=FALSE)` → `ΛΛᵀ` only (rank-deficient, rotation-invariant). The
  internal marker is now `.auto_unique` (was `.auto_residual`). The #517 "PENDING DECISION" (unique vs
  specific; alias vs hard-rename) is **RESOLVED** — you do **not** need to re-ask it.
- Separately, the standalone keyword **`unique()` / `*_unique()` is soft-deprecated (loud fire-on-use)**
  in favour of `indep()`. `latent()` carries Ψ by default; `latent(..., unique=FALSE)` = old Λ-only.
- **Only ordinary `latent()` folds Ψ today.** `phylo_/spatial_/animal_/kernel_latent` do **not** fold
  yet → the migration is the **source folds, slice by slice**, then **`*_unique()` removal LAST**
  (Stage E). The 4×5 keyword grid + `phylo_*`/`spatial_*`/`animal_*` rows + the generic
  `kernel_*()` quartet (Design 65, C1 ≡ phylo for dense `K` < 1e-6) all remain.
- **The 4 grouping levels are `unit / unit_obs / cluster / cluster2`.** (`cluster2` parser+engine =
  #355, per-family validation = #356, roadmap #342 — **not yet implemented**; standing requirement to
  build + validate across ALL distributions.)

---

## 3. What the Claude team landed (the arc you're continuing)

**All facts below are git-verified merges. Test counts are the prior Claude lane's local runs —
re-baseline them yourself (you own the live toolchain now).**

### gllvmTMB → `main`
- **#505** `unique()`→Ψ migration (auto-per-family Ψ in `latent()`); review-hardened (caught a real
  `.latent_psi`/`.auto_residual` marker-mismatch byte-identity break).
- **#508** articles `unique()`→`indep()` deprecation cascade (13 reader-path articles; kept
  source-specific `*_unique()`, `part="unique"`, the 4×5 grid).
- **#509** the critical engine fix — (a) `R/fit-multi.R` **per-trait B-tier auto-Ψ binary skip**
  (mirrors the W-tier OLRE skip; pins `theta_diag_B[t]` + maps `s_B` off for single-trial binary;
  honours `diag_B_common`; explicit `unique()`/`indep()` untouched via the auto-marker); (b)
  `R/profile-derived.R` `profile_ci_correlation` **boundary clamp** (`lower ≤ est ≤ upper`; fixes the
  rank-1 `d=1` ±1 latent-corr case the ±0.999 grid couldn't bracket — #505-exposed, proven orthogonal).
- **#510** coevolution **nbinom1 + Beta** two-kernel recovery gates (COE-04). Seeds: nb1 = 5201/5202,
  Beta = 6103/6104.
- **#511** close-loops: #343 slope-gate reps + NaN-SE guard; **keep-fixed-rho decision** recorded
  (closes the in-engine-rho loop, `189b695`). **#512** pkgdown reference-index fix (added 3 coevolution
  topics; fixed failing pkgdown CI). **#513** `unique()` article finish. **#514** grammar-contract
  pairing-rule narrative fix (B4). **#515** Stage-A source-fold **design** doc
  (`docs/design/2026-06-21-source-specific-latent-psi-fold.md`). **#517** handover doc. **#518** the
  `residual`→`unique` rename (§2).
- **Prior local heavy-suite baseline:** *9580 PASS / 0 FAIL* at `60fb621` (prior Claude run; **NOT**
  re-verified here — `main` has advanced +8 commits since). **Re-run to re-baseline (§7).**

### GLLVM.jl
- **#112** generalized Poisson **GP-1** family (`#104`, profile-over-α fit). **#111** masked analytic
  Laplace gradient for NB/Gamma/Beta (masked analytic now complete across all 5 non-Gaussian families).
  **#96 closed** — mode-finder convexity/backtrack safeguard verified live in
  `src/families/laplace.jl` (`_laplace_mode_should_backtrack`, gates Poisson/Binomial/NB/Beta/Gamma/Exp).
- **Draft PR #113** (`claude/studentt-105-20260620`) — **Student-t (#105)** ported onto the current
  engine: family math intact; `fit_studentt_gllvm` rewritten to the current Optim scalar-aux pattern
  (the old `marginal_loglik_laplace_aux_value_grad` path retired); `simulate(fit::StudentTFit)` added;
  `test_studentt.jl` updated. **NOT built/verified — this is a Codex Julia-lane task (§4).**

---

## 4. The in-flight + immediate next slices

**Item 0 — decide the fate of your dirty `codex/r-bridge-grouped-dispersion` branch (do this first).**
Concrete triage (read-only first, no destructive step until you've scoped it):
1. `git -C <repo> log --oneline origin/main..codex/r-bridge-grouped-dispersion` — the 120 committed
   commits; isolate the **coevolution** ones not already on `main` (`git log --oneline --left-right
   origin/main...HEAD`).
2. `git stash` (or a scratch diff) the **uncommitted** 173-file cascade and diff representative files
   against `main` — most of the `unique()`→`indep()`/`unique=` spelling is **already merged** (#508/
   #513/#518); confirm and discard the superseded parts.
3. Decide: **cherry-pick** the genuinely-novel coevolution commits onto a fresh branch off `origin/main`
   → land via normal DoD; **abandon** the superseded spelling cascade. Surface the call to the
   maintainer before any force-push or branch deletion (history rewrite = high-risk).

**Item 1 — verify + land PR #519 (phylo-fold, "PR B"), then close #516.** This is the live grammar
slice. `#519` (`claude/phylo-unique-fold-20260621`, worktree `/private/tmp/gllvmtmb-phylo-unique-fold`)
folds `phylo_latent()` Ψ by default using `unique=` and fixes the equivalence-test cascade that sank
#516. State at handover: **OPEN, not draft, MERGEABLE, CI in flight**. Before merge:
- **★ Run the FULL `devtools::check()` locally — NOT just the phylo test files.** The #516 breakage was
  *outside* the phylo files (equivalence tests `test-kernel-equivalence.R:203`, `test-canonical-keywords.R`,
  `test-animal-keyword.R`, `test-matrix-animal-nongaussian.R` assert `bare phylo_latent ≡ a non-folding
  form`; the fix sets the *compared* form to `unique=FALSE`). The 11-file local run passing but the full
  check failing is **exactly what bit the last session.** There is a dedicated `recovery` CI workflow too.
- Grammar change ⇒ **high-risk ⇒ explicit maintainer "yes merge"** before landing.
- Then **close #516** (state CONFLICTING, superseded — do not merge it).
- Mechanics to reuse (don't reinvent) are in #517 §5 and the `#515` design doc: rewriter in
  `R/brms-sugar.R` after the `latent` fold block (~L2853); dedup in `R/fit-multi.R` (~L340–366,
  `is_auto_phylo_psi`); test `tests/testthat/test-phylo-latent-residual-fold.R`.

**Item 2 — build + verify GLLVM.jl Student-t draft #113 (Julia lane — your wheelhouse).** Check out
`claude/studentt-105-20260620` in a fresh worktree; build; run the acceptance gates: density vs
`Distributions`, marginal-FD ≤ 1e-6, Gaussian-limit, simulate→fit recovery, outlier robustness,
`link_residual`. If green, flip out of draft and request maintainer sign-off (family = high-risk).

**Item 3 (cheap) — continue source folds after #519:** `spatial_latent` → `animal_latent` →
`kernel_latent`, slice by slice, each with its own equivalence-cascade fix + FULL check; then slice 1b
(augmented `phylo_latent(1+x|sp)`), Stage B (roxygen `@param`/man/grid/NEWS/register + the fire-on-use
warning for the bare-`*_latent` default flip), Stage C (deprecation messaging), Stage D (articles),
**Stage E = `*_unique()` removal, LAST.** Plan file: `~/.claude/plans/memoized-snuggling-balloon.md`.

---

## 5. Other remaining work (backlog by theme — issue numbers)

- **Release / CRAN (#344 v0.2.0 gate, #345 CRAN+paper):** #483 regenerate NAMESPACE/man for the
  `engine=julia` bridge exports + S3 methods (**CRAN blocker**); #484 author `cran-comments.md`; #485
  document `engine=julia` in NEWS dev section; #486 `--as-cran` punch list (0E/2W/3N).
- **Grammar / engine:** #341 random-slope completion (`indep` slope done cheap; `dep`/`latent`/spatial
  + nbinom1 wiring outstanding); #342/#355/#356 **`cluster2`** 4th grouping tier (parser+engine+per-
  family validation — standing requirement, **grammar change ⇒ discussion-gated**).
- **Coevolution (#361, C0–C5):** keep-fixed-rho decided (#511); remaining = mixed-family two-kernel
  recovery gates, in-engine rho estimation parked (#507 recommends keep fixed). Never self-promote
  COE-03/04 register rows.
- **Missing-data layer (#332 shared contract):** #335 Phase 2a obs-level continuous `mi()` (fixed
  covariate model) → #336 2b (grouped RE) → #337 2c (group/species broadcast) → #338 Phase 3
  phylogenetic `mi()` (flagship). FIML / marginal-ML via Laplace — **no Bayesian/MCMC path.** Full
  design in `~/.claude/memory/design-missing-data-drmtmb-gllvmtmb.md`. Queued, not started.
- **Simulation / coverage / power:** #346 framework; #348 family-validation completion; #349 power
  capstone (Design 66). CI-08 / CI-10 power-pilot undercoverage flagged on the dashboard.
- **Articles / docs:** #347 article completion (public learning path); #340 capability-matrix live
  board; #230 article-surface reset + user-first tooling gate. **Long + wide `traits(...)` example is a
  hard publication gate** for tutorials / landing / README. Maintainer also raised reorganising articles
  into the pkgdown surface like drmTMB (bank not-yet-ready ones).
- **Bridge:** #488 bridge-gate drift audit (R wrapper may reject `engine="julia"` features GLLVM.jl
  already supports). GP-1 R-bridge exposure needs R↔Julia parity infra.
- **#343** CI / engineering health — the flaky `test-multi-trial-binomial.R` slope gate was addressed
  (#511 reps + NaN guard; `e5e483b`); issue broadened, still open — monitor on `main` CI.
- **GLLVM.jl families queue:** #106 lognormal, #107 zero-trunc Poisson/NB, #108 ANOVA/LRT, #109
  check_fit diagnostics, #110 structured Schur (after #113). Archived drafts may exist — `git log --all`.

---

## 6. Constraints (READ — these will bite)

- **★ FULL `devtools::check()` before pushing any grammar change** — touched-test-file runs miss the
  equivalence-cascade breakages (the #516 lesson, §4).
- **`document()` after any export/roxygen change** — #483 exists because NAMESPACE/man drifted from the
  bridge exports; a CRAN blocker. Regenerate, don't hand-edit.
- **GitHub issue-CLOSE needs an EXPLICIT per-issue maintainer "yes" in the prompt** — a multi-select
  answer does **not** register and the classifier blocks it. If denied, STOP and surface (lesson carried
  from the sister drmTMB lane; applies cross-repo).
- **Heavy tests are gated** behind `GLLVMTMB_HEAVY_TESTS=1` (`tests/testthat/setup.R`); `skip_on_cran()`
  needs `NOT_CRAN=true` or they silently skip under `Rscript`.
- **Never `git add -A`** — stage by name. **Don't revert Claude/human work.**
- **Dashboard discipline** (`docs/dev-log/dashboard/`): bump **both** `version.txt` **and** `index.html`
  `const BUILD` (else the served board hot-reload-loops); `rsync` to the served dir; `curl` the live
  ports (8770 / 8765) to confirm; don't promote a covered/partial/blocked row silently.
- **`check-log.md` is a shared message bus** — check PR overlap before editing; agent-to-agent handoffs
  go in the repo (PR comment or a directed `check-log.md` line), not chat.
- **Surface review touchpoints at every stopping point:** open-PR links, after-task paths, and 🔴
  **Needs you:** blockers. The maintainer does not browse PRs.
- **Commit / attribution per `AGENTS.md`** (Codex uses its own attribution; the Claude lane used
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`). Every state-changing slice leaves an
  after-task report in `docs/dev-log/after-task/YYYY-MM-DD-*.md`.
- **Family-id map** (`R/fit-multi.R`): 0=gaussian, 1=binomial, 2=poisson, 4=Gamma, 5=nbinom2, 7=Beta,
  12/13=delta_*, 14=ordinal_probit, 15=nbinom1.

---

## 7. Verification cookbook

```r
# gllvmTMB — focused tests:
devtools::test(filter = "<focused regex>")

# gllvmTMB — FULL heavy suite (re-baseline; do this to confirm main is green):
Sys.setenv(GLLVMTMB_HEAVY_TESTS = "1", NOT_CRAN = "true")
devtools::load_all(".", compile = FALSE)
testthat::test_dir("tests/testthat")

# gllvmTMB — docs + full check (run the FULL check before any grammar push):
devtools::document()
pkgdown::check_pkgdown()
devtools::check()                 # FULL — catches the equivalence cascade outside touched files
# fast variant when not touching grammar:
# devtools::check(document = FALSE, manual = FALSE, args = "--no-tests")

git diff --check                  # whitespace hygiene
```

```bash
# GLLVM.jl — single/all tests (NEVER Pkg.test; runtests.jl is the entry):
cd <GLLVM.jl worktree> && /Users/z3437171/.juliaup/bin/julia --project=. test/runtests.jl
# R-parity (gated):  GLLVM_PARITY_TESTS=1 ...
```

**Toolchain noise vs real regressions:** Apple clang `R_ext/Boolean.h ... '-Wfixed-enum-extension'`
is *environment* noise, not a branch regression — reproduce the warning path before stalling.
`pkgdown` success ≠ R-CMD-check success (check both are wired on push).

**Where things live:** Plan `~/.claude/plans/memoized-snuggling-balloon.md`; design
`docs/design/2026-06-21-source-specific-latent-psi-fold.md` (#515), Design 65 (coevolution kernel),
Design 35 (validation-debt register), `docs/design/04-sister-package-scope.md` (what gllvmTMB does /
does NOT do). Doctrine: `~/.claude/memory/memory_summary.md` (★ Ψ model + snapshots) and
`~/.claude/memory/MEMORY.md`; Codex's own `~/.codex/memories/` mirrors much of it.

---

## 8. One-line status

`origin/main` = `c106df4` (#518; `latent(unique=)` rename landed). Claude lane is paused; the Codex lane
resumes. **First three moves:** (0) triage your stale dirty `codex/r-bridge-grouped-dispersion` branch;
(1) verify + FULL-check + maintainer-approve PR #519 (phylo Ψ fold), then close #516; (2) build + verify
GLLVM.jl Student-t draft #113. Nothing is a safe silent merge — grammar/engine/family all need an
explicit maintainer "yes." Re-run the heavy suite to re-baseline before claiming `main` green.
