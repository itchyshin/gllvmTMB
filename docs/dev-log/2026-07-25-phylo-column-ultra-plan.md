# Ultra-plan — Site × Species phylogeny capability + comparator evidence

**Lane:** `claude/phylo-column-20260725` · worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-phylo-column` · based on `main` @ `a0f568d1`.
**Platform:** Claude (solo). **Date:** 2026-07-25.
**Brief:** `docs/dev-log/handover/2026-07-25-claude-handover-phylo-column.md` Part II §II.4.

```
🎯 GOAL
Solo platform: CLAUDE. Lane: claude/phylo-column-20260725 (fresh worktree off main a0f568d1).
Deliverable: (a) a top-level tree argument letting gllvmTMB fit phylogeny on the RESPONSE/column
axis in the natural Site × Species layout, design-doc-first per AGENTS.md rule 5; (b) the
comparator evidence the board names as the gap to submission.
HEADLINE: S2 — get gllvm's colMat + randomX actually responding to a tree change. Nothing
downstream is trustworthy without a reference implementation seen to move.
IN PARALLEL: S1 silent-unused-tree fix (independent, highest value-per-line); S0 re-derivation
of the handover's own two-tree claims (re-run, do not inherit).
DEFER: NNGP/sparse scalability (use the existing Hadfield–Nakagawa A⁻¹ instead); per-covariate
phylo signal; MCMCglmm fit-level comparator.
DISCIPLINE: every capability claim gets the TWO-TREE TEST — change the tree, watch the
likelihood move. "It fitted" is not evidence. Compute on Totoro if it grows (D-50, results
LOCAL). Rung stays NOT READY; no release, tag, freeze, or submission from this lane.
FENCED: Codex EVA/VA/JJ (design90–98) and the eta-simulation lane — no Claude mutation.
```

## Context

gllvmTMB can fit phylogenetically structured species effects **only by calling species the
`unit`** — i.e. entering data as Species × Site. It cannot do it in the **Site × Species**
layout every community ecologist uses. gllvm does this natively via `colMat`. Shinichi's
decision (2026-07-25): add the capability rather than document the transposition, because the
transposition confused the package's own author across a long exchange and will defeat applied
users.

The framing goal is credibility with Ben Bolker, David Warton / Bert van der Veen, and Jarrod
Hadfield — which makes this an **evidence** arc, not a feature-count arc. (metafor /
Viechtbauer is drmTMB's comparator, not gllvmTMB's.)

## Decisions locked with Shinichi (2026-07-25)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Top-level argument, not formula syntax.** The tree is supplied once to `gllvmTMB()`. | A formula describes how **predictors** act. Correlation among the response columns is a standing fact about the response set, not a predictor relationship. Forcing it into formula syntax is what made the model unspellable and what three sessions argued about. |
| D2 | **`phylo_*()` stays unit-axis only.** No new `phylo_*` keyword, no axis argument on the family. | Preserves a clean invariant — `phylo_*()` ALWAYS means "this grouping is phylogenetic" — so the two axes can never again be confused. This is the exact confusion that produced three reversals. |
| D3 | **Single shared phylogenetic signal in v1.** Per-covariate signal (gllvm `colMat.rho.struct = "term"`) deferred and stated. | Identifiability is already the open risk (S4 aliasing; R-2's σ²_slope over-estimation under binomial). Get one signal to recover before adding more. |
| D4 | **NNGP explicitly deferred — use the existing Hadfield–Nakagawa sparse A⁻¹.** | `R/phylo-tree-precision.R` already implements it (Hadfield & Nakagawa 2010, re-implemented from the same algorithm). REUSE, not new numerics. JSDM species counts are 10²–10³ where sparse-Cholesky is fine. Ship a measured scaling bound rather than an unvalidated implicit claim. |

**Consequence of D1 that removed a design fork:** the same top-level argument yields either model
depending on what else is in the formula —

- top-level tree, **no** `latent()` → species covary only by the tree (Σ = σ²[λA + (1−λ)I])
- top-level tree **plus** `latent(0 + trait | site, d = 2)` → ordination tier + phylogenetic tier

The user selects by what they write. This matches the package's existing two-term idiom
(CLAUDE.md's standing guard: a non-phylo ordination is *"a second `latent` term"*).

**Open design content (NOT a Shinichi decision — rule-5 work):** internally the tree acts on a
species-level random-effect covariance, so the design doc must state exactly which tier the
top-level argument resolves to, and the semantics when `latent()` is also present.

### PARKED (Shinichi, 2026-07-25): which tier the tree attaches to

Phylogeny does not *add* a species correlation — the multivariate model already estimates one.
It **constrains** one already present, or adds a second tier beside it. So the open question is
*which* covariance gets constrained. Four candidates, which are different biological claims
rather than implementations of one idea:

| Where | Biological claim | Available for JSDM data? |
|---|---|---|
| Residual Σ_R across species | related species have correlated *unexplained* variation | **No** — Gaussian only; binomial/Poisson have no free residual covariance, and presence/absence IS the JSDM data type. Eliminates itself. |
| Species intercepts | related species are similarly common | only if intercepts are *random*; `0 + trait` makes them fixed |
| Site-level species tier `(0 + trait \| site)` — the ΛΛᵀ + diag(ψ) of `latent()` | related species **co-occur** similarly | yes |
| Species-specific slopes β_j | related species **respond to environment** similarly | yes — the paper's Figure 1, and gllvm's `colMat` + `randomX` |

**Why this is harder for gllvmTMB than for gllvm (Shinichi's observation).** gllvm has ONE level
on which a random column effect can live, so `colMat` has exactly one destination and their API
needs no way to name it. gllvmTMB has multiple grouping levels (`unit` / `unit_obs` / `cluster`),
so "put the tree on the species effects" is **underdetermined** here. gllvm gives us the
mechanism but not the disambiguation. This is genuine extra structure, not confusion.

**Status: PARKED.** Not resolved by argument. S2 answers part of it empirically — where the
field's reference implementation actually puts the structure is worth knowing before choosing.
The Hadfield / MCMCglmm route may supply the answer (and the Hadfield–Nakagawa sparse A⁻¹ is
already reused per D4). If it cannot be resolved, it stays parked rather than being guessed.

**Open scope question:** whether v1 covers intercept-only, species-specific slopes, or both.
Shinichi: *"Need to think more."* Not blocking S0–S2.

## Prior-work sweep receipt (Phase 0.25)

| Surface | Evidence run | Finding | Call |
|---|---|---|---|
| Repo git state | `git status -sb`, `git branch -a`, `git worktree list`, `git stash list`, `git log --all --since=14d` | 25 worktrees; Codex owns `design90`–`design103` + eta lane; no branch/worktree/stash for column-axis phylo | **build the gap** — nothing to resume |
| Design docs + dev-log | grep `colMat\|column axis\|trait-axis\|JSDM\|van der Veen\|Warton\|Pagel\|randomX\|NNGP` over `docs/design/`, `docs/dev-log/` | `01-formula-grammar.md` defines the trait axis; `72-variational-approximation-feasibility.md` cites gllvm 2.0 / NNGP; `03-phylogenetic-gllvm.md` is the unit-axis contract. **No column-axis design doc exists.** | **build the gap** |
| Validation-debt register | read `docs/design/35-validation-debt-register.md` §4 | PHY-01…PHY-18 all unit-axis; PHY-12–18 `covered`. **No column-axis row.** | new row needed |
| Sister repo (GLLVM.jl) | `grep -r "colMat\|phylo.*column" GLLVM.jl/` | phylo code present (`em_phylo.jl`, `sparse_phy_grad.jl`); **no column-axis capability** | nothing to reuse |
| Brain | `search_notes(search_all_projects=true)` × 2: "gllvm colMat phylogeny column species axis JSDM randomX van der Veen"; "gllvmTMB comparator evidence Bolker Hadfield Warton" | `dr3-gllvm-jsdm-distilled` (UNVERIFIED) — gllvm capability = van der Veen & O'Hara arXiv 2408.05333; ordination+phylo aliasing is **documented open white space**, not our defect. **No prior decision on column-axis phylo.** | reuse the note as context; D1–D4 overturn nothing |
| Code reuse | `R/phylo-tree-precision.R`, `R/fit-multi.R:2854-2856` | Hadfield–Nakagawa sparse A⁻¹ exists and is reusable on the trait axis; `use_any_phy_term` bookkeeping already exists for the S1 guard | **reuse both** |

**Verdict:** genuinely new = the column-axis tier + its design doc + the comparator evidence.
Everything numerical it needs already exists in-repo.

## Slice table

| # | Slice | Member | Model · effort | Dep | Status |
|---|---|---|---|---|---|
| S0 | **Re-derive** the handover's two-tree claims (E1 silent no-op · E2 global can't reach columns · E3 transposed-layout positive control · E4 supply routes) | Curie | Sonnet · med | — | **RUNNING** |
| S2 | **gllvm `colMat` + `randomX` reference** — two-tree test + the no-`randomX` negative control | Jason | Sonnet · med | — | **RUNNING** |
| S1 | **Fix the silent unused-tree bug** — typed refusal/warning when a supplied tree never enters the likelihood | Boole | Sonnet · med | S0 | pending |
| S3 | **Design doc: column-axis phylo tier** (rule 5) — name aliasing as the central risk up front | Noether + Boole | Opus · high | S2 | pending |
| S4 | **Aliasing study** — ordination vs phylogeny competing for the species axis | Fisher | Sonnet · high | S2 | pending |
| S5 | **R-2 / Experiment B** — ≥60 seeds, mean SIGNED bias, both scales, realized vs population Σ_b, iid control arm | Curie | Sonnet · med | — | pending (Totoro) |
| S6 | **Worked example + wide `traits(...)` format** | Pat + Darwin | Sonnet · med | S3, S5 | pending |
| S7 | MCMCglmm **fit-level** comparator (currently matrix-level only) | Gauss | Sonnet · med | S2 | deferred |
| — | **Verify** — D-43 panel if any milestone claim is made | 2× Sonnet + 1× Opus, fresh | — | all | pending |

**Sequencing.** S0 and S2 are independent and go first. S2 is the headline: without a reference
implementation seen to respond to the tree, design B's aliasing cannot be distinguished from our
own bug. S3 does not start before S2 produces a gllvm fit that behaves.

## S0 / S2 results (2026-07-25) — the premise moved

Both slices ran in this lane; scripts and verbatim results in `dev/`.

### S2 — gllvm reference: WORKING, but the handover's prescribed mechanism is wrong

- Two-tree test **passes**: logLik(true) −662.849670 vs logLik(wrong) −672.582973, gap **9.73**,
  true tree better; signal ρ = 0.963 (true) vs pinned at the 0.000 boundary (wrong).
- **`randomX = ~ env` did NOT work.** The argument exists in gllvm 2.0.11's signature, but
  supplying it left `col.eff = FALSE` and the column-random-effect design matrix a degenerate
  1×1 zero — identical logLik −613.512827 for both trees, difference exactly 0. The working
  mechanism is **bar syntax in the main formula** (`~ (env | 1)`), as gllvm's own phylogenetic
  vignette uses. **The handover's prescribed fix would have failed a third time.**
- `colMat` enters as `Σ_e = kron(ρC + (1−ρ)I, R)` — exactly the single shared signal form of D3.
- It attaches to whatever sits inside the column-effect bar: intercept-only gives a 2.64 logLik
  gap between trees, slope-only 13.55. **gllvm does not choose a tier; the user does.**
- **gllvm has exactly ONE grouping level for random column effects** (columns of `y`), measured
  — a 3-level covariate on the bar RHS merely replicated the species block 3×. Shinichi's
  observation confirmed: gllvmTMB's multiple levels are new territory, not a solved question.

### S0 — the handover's central claim is PARTIALLY REFUTED

Same data throughout (real phylogenetic species effect embedded under `tree_A`); the 101/202/303
seeds label the **trees**, not the fits.

| Keyword | tree_A (TRUE) | tree_B | tree_C | Reading |
|---|---|---|---|---|
| `phylo_indep()` | 35.592834 | 35.592834 | 35.592834 | **no-op CONFIRMED**, mechanism proven |
| `phylo_dep()` | **46.834572** | **49.776670** | 49.360143 | tree enters — **and the TRUE tree LOSES by 2.94** |

- `phylo_indep()`'s no-op is **provable, not merely observed**: the diagonal Λ_phy gives each
  species its own independent factor column, and in this layout species *t* is observed only at
  its own diagonal cell, so the tree's off-diagonals are mathematically unreachable. Fitted
  variances were large (0.03–4.3), so this is not a zero-boundary artefact.
- The mechanism is **statistical non-identifiability, not a wrong-axis code bug** — `src/gllvmTMB.cpp`
  indexes the phylo eta term off the cluster/species column directly, independent of `unit`.
- E2 (deprecated global `phylo_tree=` with no consuming keyword) **CONFIRMED inert**.
  E3 positive control **passed decisively** (−8.730365 true vs −28.430023 wrong), so the harness
  can detect a real effect. E4: both supply routes identical (−329.779599).
- **New bug found (separate):** `phylo_scalar()` and `phylo_indep(common = TRUE)` throw
  `propto() found in formula but phylo_vcv is NULL` even when `tree =` is supplied in-keyword.

**Net effect on the plan.** The handover's blanket claim ("phylogeny cannot reach the column
axis") is **too broad** — but its practical conclusion survives, with a changed diagnosis:
*no keyword currently does column-axis phylogeny correctly.* The diagonal family cannot see the
tree at all; the full-rank family sees it and prefers the wrong one. With `phylo_dep()` estimating
a free 55-parameter Σ across 10 species, Σ can absorb what A should explain — the same aliasing
already measured for ordination, now visible in a basic keyword.

**CAVEAT — one realization.** The wrong-tree-wins result is a single dataset at n = 30 sites,
10 species. It must be replicated across seeds before it is stated as a property of the estimator
rather than of this draw. **Not yet a claim.**

## Standing rules for this lane

1. **The TRUE-TREE-WINS test** (upgraded 2026-07-25, from S0). Every capability claim changes a
   known input and checks that **the true tree scores best** — not merely that the likelihood
   moved. The handover's "does the logLik move" criterion is too weak: `phylo_dep()` passes it
   while ranking the true tree last. `try(fit)` returning cleanly is not evidence either — the
   silent no-op fits fine.
2. **Re-run, don't inherit.** The source handover's conclusions are re-runnable claims; its
   author reversed position three times in one session and every reversal was caught by external
   pushback rather than self-checking. Every number has a script behind it — run the script.
3. **Do not grep away warnings.** A prior session filtered console output for `logLik|ERROR` and
   thereby deleted the package's own deprecation warnings.
4. **Test exit codes, not just output.** `git status --porcelain` erroring into an empty string
   read as "clean".
5. **Deprecated syntax is a live trap.** `tree =` inside the keyword (top-level `phylo_tree =` is
   deprecated); `A =`/`Ainv =` (not `vcv =`); `*_indep()` (not `*_unique()`).
6. **Predeclare stop conditions.** S4 may return "these cannot be separated at realistic n" and
   S5 may dissolve R-2 into a sampling artefact. Both are legitimate results.

## Hard constraints inherited

- **M3 API freeze** — `NAMESPACE` SHA-256 `c97ae039`, 153 exports / 33 S3 methods. D1 adds an
  argument, not an export, but it is still an API change requiring Shinichi's authorization
  before implementation.
- **AGENTS.md rule 5** — new variance-share axis ⇒ design-doc first + simulation recovery on a
  known DGP + Boole/Gauss/Noether review.
- **D-50** — campaigns on Totoro/DRAC, never GitHub Actions; results stay local.
- **Codex fences** — EVA/VA/JJ (`design90`–`design98`) and the eta-simulation lane untouchable.
- **Rung stays NOT READY.** No release, freeze, tag, or submission from this lane.
