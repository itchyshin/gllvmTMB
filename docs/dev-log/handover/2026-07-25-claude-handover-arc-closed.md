# Session Handoff — Site × Species phylo arc CLOSED · capability cancelled · comparator evidence landed

**Meta:** 2026-07-25 · author = Claude · target = next Claude · fresh context recommended.

You are Claude, picking up `gllvmTMB`. **Read
`docs/dev-log/handover/2026-07-25-active-lane-split.md` first** — this repository runs multiple
fenced lanes and is not a single writable workspace. This document is the *phylo-arc / evidence*
lane and supersedes `2026-07-25-claude-handover-phylo-column.md`, which planned a capability that
has since been **cancelled**.

**Codex owns the EVA / VA / JJ family (`design90`–`design98`) and the eta-simulation lane at
`/private/tmp/gllvmtmb-design100-progress-oracle`. Do not run, edit, claim, or absorb them.**

## Goals / mission

The framing goal remains credibility with **Ben Bolker** (glmmTMB), **David Warton / Bert van der
Veen** (gllvm), and **Jarrod Hadfield** (MCMCglmm) — which the board scores as an **evidence** gap,
not a capability gap. (**metafor / Viechtbauer is NOT a gllvmTMB comparator** — it belongs to
drmTMB.)

**The next arc is UNCHOSEN and that is deliberate.** Shinichi, 2026-07-25: *"probably not CRAN nor
paper — we want to think about it."* **Ask before opening a lane.** Do not assume release or
manuscript work.

### 🔖 Standing interest to carry forward: EVA

Shinichi, 2026-07-25, unprompted: *"I am still interested in EVA stuff too — please remember."*
**Record this; do not let it fall off the menu.** Current EVA state, which constrains how it can be
picked up:

- **EVA is CUT from 0.6 and deferred to 0.7** (2026-07-21). It does not gate the release.
- **It is CODEX-OWNED** — the `design90`–`design98` worktrees plus the eta-simulation lane. A Claude
  session must not run, edit, claim, or absorb them. Picking EVA up on the Claude side is a **lane
  reassignment and needs Shinichi's explicit decision**, not an agent's initiative.
- **Design 85 is NEGATIVE evidence** and authorises no VA/EVA API or scientific claim;
  `docs/design/85-*` is READ-ONLY. A fresh **Gate-0 scope freeze** is required because the
  redirected sparse-binary target lies outside Design 85's admitted data contract.
- **Design 86 exists but is DESIGN-ONLY** (Amendment 3, 2026-07-22), fenced to
  `docs/design/86-*.md`, and does not gate 0.6.

So the honest shape of "do EVA": it starts with a **scope decision and a Gate-0 freeze**, not with
code, and it starts with a conversation about lane ownership. Raise it with him rather than waiting
for him to raise it again.

## What was accomplished

Everything below is **merged and pushed to `main`**, `a0f568d1..84ca8290`.

### 1. The Site × Species capability was CANCELLED — by decision, on evidence

The lane opened per the prior handover's §II.4 ultra-plan brief. Mid-arc Shinichi cancelled the
capability half: *"can we not do this now… esp we actually have a way to hack it?"* The
transposition workaround was **verified in-lane** under the stricter test (E3 positive control,
`unit = species`: true tree −8.730365 vs wrong −28.430023), and `phylo_dep()` — the keyword that
*does* reach the column axis — was then shown to mislead on tree choice. Building new API against a
signed freeze to avoid a data transposition was judged a poor trade.

**Consequence: no new export, no new argument, no likelihood change. `NAMESPACE c97ae039` is
untouched.**

The API reasoning is preserved in the after-task report so it need not be re-derived if the question
returns: the tree would have entered as a **top-level argument, not formula syntax** (a formula
describes how *predictors* act; correlation among response columns is a standing fact about the
response set), and **`phylo_*()` would have stayed unit-axis only**.

### 2. Two user-facing bug fixes — `a1b9b23e`, the only `R/` change in the arc

| Bug | Before | Now |
|---|---|---|
| Supplied tree cannot enter the likelihood | **silently ignored** — a user could fit a "phylogenetic JSDM", see large fitted phylogenetic variances, and publish an analysis containing no phylogeny | `cli_abort` when nothing consumes it; `cli_warn` when a term exists but is structurally unreachable |
| `propto()` + in-keyword `tree =` | false `"phylo_vcv is NULL"` abort | accepted; reuses `.gllvm_phylo_tree_precision()` + `.resolve_sparse_propto_precision()` |

The second is more consequential than it first looks: it broke **`phylo_indep(common = TRUE)`, the
canonical spelling**, not merely the soft-deprecated `phylo_scalar()`. Verified numerically — the
`tree =` route matches the dense `vcv =` route to **1e-8**, so it computes the right precision
rather than merely stopping the error.

The 1(b) guard is deliberately **narrow**: tests assert it does **not** fire for `phylo_dep()` in the
identical pathological layout (which genuinely admits the tree), nor for the legitimate
`unit = species` layout.

### 3. First `gllvm` fit-level comparators in the package's history

`tests/testthat/test-comparator-gllvm.R` — Poisson ordination (`67cc5a13`) and binary GLLVM
(`9c111a5a`). Before today the only `gllvm::` call in the repo was a scratch script.

**The board's headline gap claim is now partly false and has been corrected:** *"there is NO gllvm
fit anywhere in the test suite"* was true until 2026-07-25. **MCMCglmm remains matrix-level only**
(`inverseA()`), never a model-fit comparison — that half of the gap is genuinely open.

### 4. `NEWS.md` slope claim verified; a coverage gap closed — `83e6b1c4`

`NEWS.md` asserted the `*_unique()` **slope** forms "retain their legacy shared 2×2 channels; they
are not aliases for the current `*_indep()` shape" — untested. **CLAIM VERIFIED**: `n_lhs_cols` 2 vs
6, free parameters 7 vs 13, `sd_b`/`cor_b` with no `Sigma_b_dep` vs a 6×6 block-diagonal
`Sigma_b_dep`; both fits non-degenerate. NEWS needed no correction. Also added canonical `*_indep()`
twins for nbinom1 on the phylo and spatial tiers, which had been reachable **only** through the
deprecated spelling.

### 5. The keyword grid was wrong in every rule file — `1defda40`

`AGENTS.md`, `CLAUDE.md`, and `docs/design/01-formula-grammar.md` all taught a **4 × 5** grid with
`scalar` and `unique` as mode columns and `kernel_*()` outside the grid. The published article
(`vignettes/articles/api-keyword-grid.Rmd`) is the latest and says:

> **5 × 3** — five correlation **sources** (none, animal, phylo, spatial, kernel) × three
> **modes** (`indep`, `dep`, `latent`), with `scalar` and `unique` as **modifiers**:
> `scalar = indep(..., common = TRUE)`, `unique = latent(..., unique = TRUE)`.

This mattered: those two files prime **every** session before anything else is read, so they taught a
superseded grid as canonical — plausibly why handovers kept restating it. They also documented the
`*_unique()` soft-deprecation at length while saying **nothing** about the scalar family being
soft-deprecated (`NEWS.md:188–192`). Design-rule-3 cascade applied to all three files plus six stale
cross-references.

### 6. D-43 panel — **3/3 NOT-DONE, unanimous. NOTHING PROMOTED.**

Two promotion claims were put to a fresh three-lens adversarial panel (evidence sufficiency ·
scope/claim language · adversarial re-execution). Both withheld.

- **`docs/design/05-testing-strategy.md:71` stays `claimed (M2 work)`.**
- **No validation-debt register row was added for `phylo_dep`.**

The panel caught **three real defects**, all of them the author's:

1. **The mandatory closure artifacts never reached `main`.** The after-task report and check-log
   entry were committed into a worktree *after* it was switched to the comparator branch, then
   `comparator-binary` was merged on the (then-true, later-false) reasoning that it contained them.
   Fixed — `a818ae8f` is now an ancestor of `origin/main`.
2. `dev/s7-*` cited `test-gllvm-comparator.R`, a file that does not exist (renamed to
   `test-comparator-gllvm.R` per the documented convention). Fixed in `10f66ef9`.
3. **Two overclaims falsified by re-execution** — see the next section. Corrected on `main` in
   `84ca8290`.

## Key decisions and rationale

- **Cancel the capability** (Shinichi). Workaround verified; the column-axis keyword misleads.
- **Top-level argument, not formula syntax**, had it been built (Shinichi). A formula describes how
  predictors act; response-column correlation is not a predictor relationship.
- **Single shared phylo signal**, per-covariate deferred (Shinichi). Matches gllvm's own
  `ρC + (1−ρ)I` default.
- **NNGP deferred — reuse the existing Hadfield–Nakagawa sparse A⁻¹** (Shinichi). `R/phylo-tree-precision.R`
  already implements it; this is a reuse finding, not merely a deferral.
- **Warn, not abort, for the structurally-unreachable case.** The fit is real and well-identified;
  aborting would break legitimate use. **Revisit-worthy** — a silently non-phylogenetic publication
  is a severe outcome for a warning.
- **Promote nothing on a failed panel.** Both reviewers offered narrower wording they *would*
  accept; re-promotion needs a **fresh** panel, not a re-reading of the failed one.
- **Leave the two wedged CI runs** (`30158126939`, `30158115396`) — cancel failed HTTP 500 ×4,
  force-cancel ×2. Wedged GitHub-side. **Do not re-attempt.**

## ⚠ Corrections — do NOT re-cite these numbers

Both figures appeared in this session's own chat and in committed evidence files before being
falsified. The evidence files now carry `CORRECTION` blocks (`84ca8290`).

| Retired claim | What re-execution measured |
|---|---|
| s9: "5/5 seeds pass, worst factor **0.9947**" | **10/14** across all seeds tried; **5/9** outside the original sweep; worst factor **0.572**. `n.init` 10 and 20 do **not** rescue seeds 11, 23, 2026 |
| s10: "`phylo_dep` systematically prefers wrong trees, **0/20**" | A **tree-identity confound**: `tree_A` wins **0 of 30** fits under *every* truth including when wrong (p ≈ 1.5e-5), and `tree_A` was the designated true tree. Real effect **4/30 = 0.133** vs chance 0.333 (p ≈ 0.004) |
| s10: the saturation mechanism (free Σ absorbs A) | **REFUTED** — the m-sweep is non-monotone and *reverses* at m = 15 (6/10 wins); a star tree scores far worse, pointing the opposite way |
| s10: "no warnings captured from any fit" | **60 warnings fire** on the control arm — from the diagnostic shipped in `a1b9b23e` |

What survived attack: the comparator test is **non-vacuous** (P(false pass) = 0.0001; 7/9 mutations
trip it), the three tree-fits **are** equal-parameter (df = 57) with all trees ultrametric, and the
s10 replication reproduces **bit-for-bit**.

## Files created / modified

From `git diff --name-only a0f568d1..84ca8290`:

- **Source (1):** `R/fit-multi.R`
- **Tests (4):** `tests/testthat/test-comparator-gllvm.R`, `test-phylo-tree-unused-guard.R`,
  `test-tiers-nbinom1-canonical-twins.R`, `test-unique-indep-slope-semantics.R`
- **Rule files (3):** `AGENTS.md`, `CLAUDE.md`, `docs/design/01-formula-grammar.md`
- **Dev-log (3):** `docs/dev-log/2026-07-25-phylo-column-ultra-plan.md`,
  `docs/dev-log/after-task/2026-07-25-phylo-column-cancelled-and-comparator-evidence.md`,
  `docs/dev-log/check-log.md`
- **Research artifacts (9):** `dev/s0-*`, `dev/s1-*`, `dev/s2-*`, `dev/s7-*`, `dev/s8-*`, `dev/s9-*`,
  `dev/s10-*` (scripts + RESULTS)
- **This handover (2):** this file + the `CLAUDE.md` snapshot edit on the handover branch

**Not modified, deliberately:** `NEWS.md`, `README`, `ROADMAP.md`, `DESCRIPTION`, `NAMESPACE`,
`man/*.Rd`, all vignettes, `docs/design/05-testing-strategy.md`,
`docs/design/35-validation-debt-register.md`.

## Checks run

| Command | Outcome |
|---|---|
| `devtools::test()` full, on the merged result | **7373 passed, 0 failed, 0 error**, 781 skipped, 2 warnings |
| `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter="phylo")` | **2615 passed, 0 failed, 0 error**, 14 skipped |
| `devtools::test(filter="phylo")` | 245 passed, 0 failed |
| new guard tests | 20 passed, 0 failed |
| `devtools::test(filter="unique\|indep\|canonical")` | 460 expectations, 0 failures |

The 2 warnings are gllvm's own informational *"rows full of zeros in y"*, captured not suppressed.
**Deliberately not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, `build_articles()` — no
roxygen, `NAMESPACE`, `DESCRIPTION`, or user-facing prose changed. `GLLVMTMB_RUN_B2_LOGIT=1` not set
(R-2's signed-off limitation; would fail for unrelated reasons).

## Next immediate steps

**First: ask Shinichi what the arc is.** He reserved the choice and ruled out CRAN and the paper.

Small, self-contained candidates if one is wanted meanwhile:

1. **Commit the s9 seed-sweep script.** Its absence is why the falsified robustness figure went
   unchecked. Then the `:71` promotion can be re-submitted with regime-qualified wording — a panel
   reviewer said `covered` becomes defensible once the overstated paragraph is corrected, which it
   now is.
2. **Design the tree-identity confound out** of the `phylo_dep` experiment before any re-panel.
3. **Decide whether the unused-tree guard should abort rather than warn.**
4. **MCMCglmm fit-level comparator** — the remaining half of the named comparator gap.

Larger, unchanged from before this arc: R-2 / Experiment B (Totoro, ≥60 seeds); the capstone
metric-repair (separate fenced lane, gates CRAN + the methods paper); the **held calibration
overclaim `a9ecd29f`** (Shinichi only).

## Blockers / open questions

- **Held calibration overclaim `a9ecd29f`** — blocks honest release language; Shinichi's alone.
- **`CLAUDE.md` WILL CONFLICT.** Changed on `main` (5 × 3 grid) *and* separately committed at
  `cf3665d0` on `claude/profile-coverage-remeasure-20260718`. Resolve deliberately when that branch
  merges — do not blind-accept either side.
- **Stale worktree:** `/Users/z3437171/local-scratch/worktrees/gllvmtmb-pkgdown-abi` holds `main` at
  `9c1cd2c4`, many commits behind. Update or remove before working there.
- **Doc-vs-practice discrepancy, unresolved:** `10-after-task-protocol.md` requires explicit
  `trait = "..."` on every long-format call site, but that is the **default** and **197/1122 (18%)**
  of existing suite call sites pass it. Rose territory — relax the rule or plan a migration.
- Two wedged CI runs — leave them.

## Gotchas / failed approaches

- **`randomX = ~ env` is INERT in gllvm 2.0.11.** The prior handover blamed two failures on omitting
  it; supplying it leaves `col.eff = FALSE` and the design matrix a degenerate 1×1 zero. **Bar
  syntax in the main formula** (`~ (env | 1)`) is the working mechanism. Following the old handover
  would have failed a third time.
- **A failed command can look like a clean result.** A `cd` into a non-existent worktree broke an
  `&&` chain; with `;` instead, a `git reset --hard` would have run **in the primary checkout on the
  fenced profile lane**. Use explicit `git -C <path>`, never directory chaining.
- **A sub-agent's completion report is not evidence.** One returned *"Good — clean, scoped changes"*
  with no files, counts, or verdicts, and stopped without waiting for the check it claimed to await.
  Its work was sound; the state had to be re-derived from `git` and a fresh test run. **Verify from
  the repo.**
- **Agents over-claim register rows.** One reported the Poisson comparator closed `:71`; that row
  specifies **binary**.
- **The naive form of the S0 experiment gives the right answer for the wrong reason** — collinear
  `0 + trait` + `phylo_indep()` drives the phylo variance to the zero boundary, producing "identical
  logLik" that cannot distinguish structural unreachability from nothing-left-to-explain.
- **Do not grep away warnings** (`logLik|ERROR` filters delete the package's own deprecations), and
  **test exit codes, not just output**.
- **Merge topology:** "branch B was cut from A, so merging B covers A" stops being true the moment a
  new commit lands on A. That is exactly how the closure artifacts were stranded.

## Mission control

| Item | State | Owner / next leverage |
|---|---|---|
| Site × Species capability | **CANCELLED** by decision, evidence preserved | do not re-open without a new decision |
| Unused-tree guard + `propto` fix | **LANDED** `a1b9b23e` | consider abort-vs-warn |
| gllvm comparator (Poisson + binary) | **LANDED** `67cc5a13`, `9c111a5a` | binary row NOT promoted |
| MCMCglmm fit-level comparator | **still matrix-level only** | the open half of the comparator gap |
| NEWS slope claim | **VERIFIED** `83e6b1c4` | — |
| 5 × 3 keyword grid | **CORRECTED** `1defda40` | watch for `CLAUDE.md` conflict |
| D-43 panel | **3/3 NOT-DONE** | nothing promoted; re-promotion needs a fresh panel |
| `05-testing-strategy.md:71` | `claimed (M2 work)` | needs s9 script + regime-qualified wording |
| Held overclaim `a9ecd29f` | **HELD** | Shinichi only |
| Release rung | **NOT READY** | gap is EVIDENCE, not capability |
| Codex EVA + eta lanes | fenced | Codex only — no Claude mutation |
| **Next arc** | **UNCHOSEN — ask Shinichi** | not CRAN, not the paper |

## How to resume

Rehydration: `docs/dev-log/handover/2026-07-25-active-lane-split.md` → this doc →
`docs/dev-log/after-task/2026-07-25-phylo-column-cancelled-and-comparator-evidence.md` → `AGENTS.md`
→ `CLAUDE.md`. Open Mission Control
(`sh "$HOME/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/start.sh"`, then
`/p/gllvmTMB/`) — but **re-derive milestone state from git**, as the board itself warns. Spawn the
**Rose** lens before any public claim.

From an authenticated terminal at the repository root:

```sh
claude "Rehydrate from docs/dev-log/handover/2026-07-25-claude-handover-arc-closed.md + the CLAUDE.md snapshot, then ASK Shinichi which arc to open — he ruled out CRAN and the paper and reserved the choice. Leave the Codex EVA and eta-simulation lanes untouched."
```

**Claude vs Codex:** this handover targets **Claude** (planning, refactor, prose, logic/CI checks).
Nothing here requires the live toolchain beyond `devtools::test()`, which this session ran locally.
Route to Codex only if the next arc needs sustained live R/TMB or simulation work.
