# Session Handoff — pkgdown repaired · CI economy · the phylogeny-on-columns question settled

**Meta:** 2026-07-25 · author = Claude · target = next Claude · fresh context recommended.

You are Claude, picking up `gllvmTMB`. **Read `docs/dev-log/handover/2026-07-25-active-lane-split.md`
first** — this repository runs multiple fenced lanes and is not a single writable workspace.
This document is the *release/infrastructure + phylogeny-question* lane. It does not replace
the lane split; it is one of the docs the split points at.

**Codex owns the EVA / VA / JJ family (`design90`–`design98`) and the eta-simulation lane at
`/private/tmp/gllvmtmb-design100-progress-oracle`. Do not run, edit, claim, or absorb them.**

## Goals / mission

Shinichi's stated goal this session: get `gllvmTMB` to the point where statisticians like
**Ben Bolker** (glmmTMB), **David Warton / Bert van der Veen** (gllvm), and **Jarrod Hadfield**
(MCMCglmm) would accept, use, and approve it. That reframes the work as **evidence and
credibility**, not feature count — which matches the board's own verdict: the honest rung is
**NOT READY**, and *"the gap to submission is EVIDENCE, not capability."*

(**metafor / Wolfgang Viechtbauer is NOT a gllvmTMB comparator** — Shinichi, 2026-07-25: it
belongs to drmTMB. Do not carry it into a gllvmTMB comparator set.)

## What was accomplished

### 1. pkgdown was broken on `main` and is now repaired — PR #787 MERGED (`a900c4ae`)

Two consecutive pkgdown runs failed on `main` while `R-CMD-check` passed at the same commits,
so the public documentation site had stopped republishing. Root cause, traced by reading the
namespace chain rather than guessing:

```
`mirt::itemstats()` written as inline PROSE in pre-fit-response-screening.Rmd
  -> pkgdown/downlit resolves the autolink
  -> loadNamespace("mirt") -> SimDesign -> qs2 -> stringfish
  -> unresolved Intel TBB symbols -> dyn.load fails -> Execution halted
```

A backticked mention in a sentence was pulling in a broken binary toolchain. Fixes:

1. Install **hard deps + an explicit list** instead of ~20 `Suggests` the site never uses. The
   list is the union of two local scans (packages used inside R code chunks across all
   vignettes; `Suggests` that gllvmTMB's own code loads via `requireNamespace()`). Drops `mirt`
   *and* `glmmTMB`, killing both root causes.
2. **`cache-version: 2`** — narrowing alone did **nothing**, because the action caches the whole
   R library and the dropped packages stayed installed. **A dependency narrowing requires a
   cache-version bump to take effect.** This is the durable lesson.
3. **Split `build` and `deploy` jobs.** The `github-pages` environment protection rule was
   failing the single job *before any step ran* on non-default branches — so a pkgdown change
   could not be tested anywhere except `main`. **That is why a broken site reached `main` twice
   unnoticed.** Docs are now verifiable before merge.

Design note with the full reasoning + a §7 recording two things the design got wrong:
`docs/dev-log/2026-07-25-pkgdown-tmb-abi-design.md`.

### 2. CI economy — PR #788 OPEN, not merged

`full-check` ran **nightly**, ubuntu-only, ~65 min ≈ **2,000 Actions-minutes/month**, re-proving
the same regression result on a repo that does not change daily. Moved to **weekly** (Mondays
06:00 UTC). `workflow_dispatch` still covers on-demand; the 3-OS matrix still runs on release tags.

**Deliberately NOT changed: `R-CMD-check`'s push-to-`main` trigger.** It superficially violates
the same standing rule, but it costs ~1–2 min *and `pkgdown` fires from it via `workflow_run`* —
removing it would silently stop the docs deploying. Measured before acting.

### 3. Mission Control was stale by the whole M4→M5 arc — corrected

The board read *"M4 UNDERWAY / draft PR #780"*. Re-derived from git: **#780 MERGED 2026-07-23**;
the tenth chain green on **3 OSes including Windows** (the real Windows failure in `check-log`
from 07-19 was fixed by 07-23); M4 mechanical half complete; **RC.1 candidate freeze** happened;
the RC.1 review returned **3/3 NOT-READY** with submission **WITHHELD** on win-builder R-devel;
an RC.2 honesty reword landed; the **RC.2 non-CRAN closeout is recorded**.

**This is not cosmetic.** This session rehydrated from that board and planned against a six-day-old
picture — including a proposal to audit and cut the public surface, which would have **reopened
M3's signed API freeze** (`NAMESPACE` SHA-256 `c97ae039`, 153 exports / 33 S3 methods, verified).
Withdrawn once git was consulted. Vault commit `b8430fe`.

### 4. The phylogeny-on-columns question — SETTLED BY EXPERIMENT

This is the scientifically substantive part and the reason this handover exists. Every row below
is a **fit that was run**, not an inference. All re-runnable.

| Finding | Evidence |
|---|---|
| **Phylogeny binds to the `unit` axis** | `unit="species"`: tree1 −23.143060 vs tree2 −23.073338 — tree changes the likelihood |
| **In the JSDM layout it is silently ignored** | `unit="site"` + `phylo_indep(1+env\|species)` + a tree: **three different trees → identical logLik to 6 d.p.** |
| **The transposed layout works** | `unit="species", trait="site"`: tree1 (true) **−165.46** vs tree2 (wrong) **−211.18** |
| **Works on presence/absence** | binomial `phylo_indep`: true tree **−235.25** beats wrong tree **−256.19** |
| **`phylo_dep` fails to converge** | binomial, both trees: `ERROR: All 1 restarts failed` |
| **Ordination + phylogeny ALIAS** | with `latent(0+trait\|species,d=2)`: the **wrong** tree scored better (−16.38 vs −23.47) |
| **The global tree cannot reach the column axis** | `unit="site"`, `dep(0+trait\|site)` / `latent(...)`, no `phylo_*()` term: two trees → **identical** logLik |
| **Both tree-supply routes are equivalent** | top-level `phylo_tree=` vs in-keyword `tree=`: **identical −242.161158** |

**Conclusion:** gllvmTMB *can* fit the model (phylogenetically structured species-specific slopes)
but **only by calling species the `unit`** — i.e. entering data as Species × Site. It **cannot**
do it in the natural **Site × Species** layout that every community ecologist uses. gllvm does
this natively via `colMat`.

**Shinichi's decision (2026-07-25):** *add the capability* — `unit = site`, `trait = species`,
phylogeny controlled on the column — rather than documenting the transposition. Rationale: the
transposition confused both Shinichi and the agent across a long exchange; it would defeat applied
users entirely. **This is a new variance-share axis → AGENTS.md Design rule 5: design-doc first,
simulation recovery on a known DGP, Boole/Gauss/Noether review, and maintainer authorization
before any likelihood work.**

### 5. A real bug found — supplied-but-unused trees are silent

| Situation | Behaviour |
|---|---|
| `phylo_*()` present, **no tree** | ✅ typed ERROR — correct and loud |
| tree supplied, `phylo_*()` grouping ≠ `unit` | ❌ **silently ignored** |
| tree supplied, **no `phylo_*()` term at all** | ❌ **silently ignored** |

gllvmTMB reliably catches a **missing** tree and never catches an **ignored** one. Both silent
cases hand the user a fit that looks phylogenetic and is not. **A user could publish a
"phylogenetic JSDM" containing no phylogeny.** One coherent fix: warn or refuse whenever a
supplied tree ends up unused. Small, contained, no likelihood change — do this regardless of
whether the capability in §4 is built.

### 6. Corroboration from the brain (`dr3-gllvm-jsdm-distilled`, flagged **UNVERIFIED**)

- gllvm's capability = **van der Veen & O'Hara, "Fast fitting of phylogenetic mixed-effects
  models"** (arXiv 2408.05333): *"phylogenetically structured species-specific slopes,
  per-covariate phylo-signal (Pagel's λ)"*, scaled by **sparse phylogenetic precision via NNGP**.
- The **ordination + phylogeny aliasing found in §4 is a documented open problem**, not our
  defect: *"combining spatial + phylogenetic + latent structure simultaneously without the
  stacked approximations degrading … The corpus does not solve this — it's genuine white space."*
- Rotation-invariance of latent axes *"remains unsettled"* — relevant to Shinichi's instinct to
  "keep the rotation regardless".
- **No prior decision exists** on phylo binding to `unit`, or on a Site × Species capability. The
  decision in §4 overturns nothing.

## Key decisions and rationale

- **Do not cut the public surface.** M3's API freeze is signed and checksummed; a surface audit
  would reopen it. Proposed then withdrawn this session.
- **`metafor` is drmTMB's comparator, not gllvmTMB's** (Shinichi).
- **Build the Site × Species capability rather than teach the transposition** (Shinichi).
- **Leave `R-CMD-check`'s push trigger alone** despite the standing rule — pkgdown depends on it.
- **Comparator gaps are real and verified:** there is **no `gllvm` fit anywhere in the test
  suite** (the only `gllvm::` call is in `dev/jason-binomial-scout.R`, a scratch script), and
  **MCMCglmm is reproduced only at the `inverseA()` MATRIX level**, never as a model-fit
  comparison. glmmTMB cross-checks are real (`expect_lt(abs(...), 0.05)`).

## Landing state

| Artifact / branch | Committed | Pushed | PR | State |
| --- | ---: | ---: | --- | --- |
| pkgdown repair | yes | yes | **#787 MERGED** `a900c4ae` | LANDED on `main` |
| `full-check` weekly | yes | yes | **#788 OPEN** | awaiting human merge |
| This handover | yes | yes | PR (see chat) | docs-only; human merges |
| Mission Control board | yes (vault `b8430fe`) | n/a — vault is local-only (D-37) | none | LANDED |
| **Profile-lane checkout** | **NO** | **NO** | none | ⚠️ **CARRIED-OVER — see below** |

### ⚠️ Uncommitted work in the primary Dropbox checkout

`/Users/z3437171/Dropbox/Github Local/gllvmTMB` on
`claude/profile-coverage-remeasure-20260718` holds **uncommitted** changes, some made by THIS
session. **Do not reset, clean, stash, or overwrite them.**

- `CLAUDE.md` — **edited this session** to carry the 2026-07-25 lane-split snapshot (it was
  still the 07-19 "moves to Codex" banner and actively misdirected this session at startup).
  **Uncommitted and therefore fragile.**
- `docs/dev-log/check-log.md` — two appended entries from this session.
- `docs/dev-log/recovery-checkpoints/2026-07-25-072436-claude-checkpoint.md` — new.
- 9 further carried-over paths from prior sessions (Tier-2a drafts, the 07-22 quadrature note,
  two unreviewed `.new.svg` plot snapshots awaiting an accept-or-discard call).

## Files created / modified

- `.github/workflows/pkgdown.yaml` — dep narrowing, `cache-version: 2`, build/deploy split (merged)
- `.github/workflows/full-check.yaml` — nightly → weekly (PR #788)
- `docs/dev-log/2026-07-25-pkgdown-tmb-abi-design.md` — design note + §7 outcome/corrections (merged)
- `docs/dev-log/handover/2026-07-25-claude-handover-phylo-column.md` — this file
- `docs/dev-log/check-log.md` — 2 entries (**uncommitted**, profile checkout)
- `CLAUDE.md` — lane-split snapshot (**uncommitted**, profile checkout)
- `docs/dev-log/recovery-checkpoints/2026-07-25-072436-claude-checkpoint.md` (**uncommitted**)
- `~/shinichi-brain/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json` (vault `b8430fe`)

## Next immediate steps

1. **Merge PR #788** (CI economy) if you agree with the reasoning.
2. **Fix the silent unused-tree bug (§5).** Highest value-per-line item found. Typed refusal or
   warning when a supplied tree ends up unused. Independent of everything else.
3. **Commit or consciously park the uncommitted profile-checkout changes** — especially
   `CLAUDE.md`, which is the file that misdirects fresh sessions while it stays uncommitted.
4. **Design doc for the column-axis phylo tier** (Shinichi's decision, §4). Name the aliasing
   problem as the central risk up front — the literature says it is unsolved.
5. **Owed and not delivered this session:** the **wide-format** (`traits(...)`) version of the
   phylogenetic-JSDM example, and **side-by-side numeric outputs from gllvm vs gllvmTMB** to
   demonstrate equivalence rather than assert it. **The gllvm side needs `randomX = ~env`** —
   `colMat` acts only on RANDOM column effects; a probe without it returns identical logLik for
   different trees and proves nothing (this failure was made twice).

## Blockers / open questions

- **The held calibration overclaim `a9ecd29f`** — *"real overclaim in the central calibration
  claim (held for maintainer)"*. Blocks honest release language; everything downstream inherits
  it. **Shinichi's decision, not an agent's.**
- **R-2** — the `phylo_*` slope cell under binomial-logit is `SIGNED OFF` as a *declared estimator
  limitation*: σ²_slope over-estimated ~50–60%, 21 seeds across three sample sizes fail, no
  shrinkage with n, Gaussian control clean, **test kept skipped by maintainer decision**, and
  *"recovery for this cell remains unverified, and 0.6 must not claim otherwise."* This is the
  **JSDM data type**, so it gates any phylogenetic-JSDM claim. **Experiment B** (≥60 seeds, mean
  SIGNED bias, both scales, realized vs population Σ_b, iid control arm; Totoro, results LOCAL
  per D-50) is the pre-registered work that resolves it.
- **Two wedged queued CI runs** (orphans of merged #786) — `gh run cancel` returned **HTTP 500**
  twice. Stuck GitHub-side; may need to age out.
- **Half-migrated test naming:** `test-phylo-indep-slope-*.R` (new) vs
  `test-phylo-unique-slope-*.R` (soft-deprecated). The R-2 binomial-logit file uses
  `phylo_unique` 4× and `phylo_indep` 0×, while NEWS tells users to use `indep`. Rose territory.

## Gotchas / failed approaches

- **THREE deprecated-syntax errors were made and shown to Shinichi in a table labelled "syntax
  equivalence".** Current canonical forms:
  - `tree =` **inside** the `phylo_*()` keyword. The top-level **`phylo_tree =` is deprecated**
    (`R/gllvmTMB.R:185` "legacy global"; runtime warning at `:622`).
  - **`vcv =` is soft-deprecated → `A =` / `Ainv =`** (M2.8b, 2026-05-17, "A-vs-V naming boundary").
  - **`*_unique()` is soft-deprecated → `*_indep()`.**
- **`.frequency_id` warnings are easy to hide.** The `phylo_tree` deprecation fires once per
  session via cli; every test script this session grepped output for `logLik|ERROR` and
  **filtered the package's own deprecation warning out**. Do not grep away warnings.
- **`git status --porcelain` erroring into an empty string reads as "clean".** A dead worktree
  (`/private/tmp/gllvmtmb-060-m1-builder` — directory present, git linkage gone) produced a false
  "CLEAN — safe to recycle". Test the exit code, not just the output.
- **"FITTED OK" is not evidence.** The silent no-op fits cleanly. Every capability claim in §4
  rests on *changing the tree and watching the likelihood move* — do that, not `try(fit)`.
- **`indep` vs `dep` is a MODELLING choice, not a deprecation.** `indep`→diagonal Σ,
  `dep`→full Σ; both carry A on the grouping. Do not conflate with the `unique`→`indep` rename.
- **Do NOT re-run an `n_each` ladder** hunting a variance-bias sign flip — drmTMB ran it
  (M=40, 80 seeds, glmer oracle: +0.3%, −9.9%, −13.7%, −23.1%), monotonically more negative.
- **Do NOT fix pkgdown deps package-by-package.** Tried (glmmTMB → stringfish → qs2); it is
  whack-a-mole. Narrow the set **and bump `cache-version`**.

## How to resume

From an authenticated terminal at the repository root:

```sh
claude "Read AGENTS.md, CLAUDE.md, and docs/dev-log/handover/2026-07-25-active-lane-split.md, then docs/dev-log/handover/2026-07-25-claude-handover-phylo-column.md; continue with its Next Immediate Steps. Leave the Codex EVA and eta-simulation lanes untouched."
```

Rehydration recipe: read `AGENTS.md` → `CLAUDE.md` snapshot → the **lane split** → this doc →
`docs/dev-log/2026-07-25-pkgdown-tmb-abi-design.md`. Open Mission Control
(`sh "$HOME/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/start.sh"`,
then `/p/gllvmTMB/`) — but **re-derive milestone state from git**, as the board warns and as this
session learned the hard way. Spawn the **Rose** lens before any public claim.

## Mission control

| Item | State | Owner / next leverage |
| --- | --- | --- |
| pkgdown docs site | **REPAIRED**, merged `a900c4ae` | watch the first post-merge deploy from `main` |
| `full-check` weekly | PR #788 open | human merge |
| Silent unused-tree bug | found, unfixed | **highest value-per-line**; typed refusal |
| Site × Species phylo capability | decided, not designed | design-doc first (rule 5) + authorization |
| Ordination + phylo aliasing | measured; known white space | validation before any advertising |
| R-2 / Experiment B | signed-off limitation | Totoro, ≥60 seeds, signed bias, LOCAL (D-50) |
| Held calibration overclaim `a9ecd29f` | HELD | **Shinichi only** |
| Release rung | **NOT READY** | gap is EVIDENCE, not capability |
| Codex EVA + eta lanes | fenced | Codex only — no Claude mutation |
