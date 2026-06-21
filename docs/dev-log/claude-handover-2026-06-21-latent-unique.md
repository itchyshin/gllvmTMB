# Claude session handover — 2026-06-21 (latent-only migration: phylo fold + residual→unique rename)

From: Claude (Ada), long autonomous session. To: the next Claude session.
**The repo is authoritative — rehydrate from git/gh + this note + the plan file, not from memory.**

## 0. TL;DR

The `latent_*`-only migration is mid-flight. Today: (1) closed several loops + fixed pkgdown +
finished the `unique()` article cleanup; (2) deep-verified that ordinary `latent()` delivers
`Σ = ΛΛᵀ + Ψ` correctly per family and across the **4 grouping levels**; (3) implemented + locally
verified the **`phylo_latent` Ψ-fold (slice 1)** — but its PR (**#516**) is **RED** on a known
equivalence-test cascade; (4) the maintainer decided to **rename the `residual` argument → `unique`**
(a fresh, cheap rename). Two PRs are queued for you, but **first confirm the rename choices with the
maintainer** (§3). Do NOT merge #516 as-is.

## 1. Repo state (PRs) — origin/main = 5e64983

- **MERGED today:** #511 (close-loops: #343 reps + NaN-guard + fixed-rho decision), #512 (pkgdown
  reference-index fix), #513 (`unique()` article finish), #514 (B4 grammar-contract pairing-rule
  fix), #515 (Stage-A source-fold **design** doc).
- **OPEN + RED — do NOT merge:** **#516** (`feat(grammar): fold diagonal Psi into phylo_latent()`),
  branch `claude/phylo-fold-20260621`, worktree `/private/tmp/gllvmtmb-phylofold`. The full
  R-CMD-check **failed**: the default-flip (bare `phylo_latent` now folds Ψ) breaks the **equivalence
  tests** that assert `bare phylo_latent ≡ <a form that does NOT fold>`: confirmed
  `test-kernel-equivalence.R:203` (kernel ≡ phylo) and `test-canonical-keywords.R` (phylo_dep ≡
  phylo_latent), and the same shape exists in `test-animal-keyword.R` / `test-matrix-animal-nongaussian.R`
  (animal ≡ phylo). #516 will be **superseded** by the rename (§3/§4) — reuse its mechanics (§5), don't merge it.

## 2. The plan + what is verified

- **Plan file:** `~/.claude/plans/memoized-snuggling-balloon.md`. **Design:**
  `docs/design/2026-06-21-source-specific-latent-psi-fold.md` (PR #515, on main).
- **Verified (3-perspective deep sweep):** ordinary `latent()` folds Ψ correctly per family;
  `Σ = ΛΛᵀ + Ψ → correlations` for all families + mixed (**the selling point**) is delivered;
  the four grouping levels are **unit / unit_obs / cluster / cluster2**; **non-Gaussian Ψ IS
  estimated at the non-residual levels** (proof: `test-cluster2-families.R` recovers Ψ for all 7
  wired families; phylo recovery for poisson/gamma/ordinal). **KEY:** only ordinary `latent()` folds
  today; `phylo_/spatial_/animal_/kernel_latent` do **not** yet → the migration is the source folds
  (slice by slice) → then `*_unique()` removal LAST.

## 3. ★ PENDING DECISION (this conversation, NOT yet in the repo): rename `residual` → `unique`

The maintainer decided to rename the `latent(residual = TRUE/FALSE)` argument →
**`unique = TRUE/FALSE`** — because it matches `extract_Sigma(part = "unique")`, "residual" misleads
above the lowest level, and the arg is **fresh** (shipped yesterday, #505) so renaming is cheap
before adoption. **First action next session: confirm with the maintainer:**
- (a) **`unique`** (Claude's recommendation — matches `part = "unique"`) **vs `specific`** (cleaner
  FA term, but mismatches the extractor unless `part="unique"` is also renamed → more churn);
- (b) keep **`residual` as a one-shot soft-deprecated alias** (safe) **vs hard-rename** (fresh enough
  to skip the alias).

**Semantics to document precisely:** `unique = TRUE` → `Σ_level = ΛΛᵀ + Ψ` (fit the explicit
per-trait specific Ψ at this level); `unique = FALSE` → `ΛΛᵀ` only (rank-deficient, rotation-invariant).
The estimated Ψ is *"trait variance not captured by the K shared axes, at this level"* — at higher
levels (cluster, phylo) that IS the level's unique variance; at the **lowest** level the trait's
*total* unique variance also absorbs the family's contribution (Gaussian σ²; non-Gaussian → the
family's own dispersion/link scale, so explicit Ψ is redundant/skipped apart from Poisson/Gaussian).
So at the bottom, Ψ is *one component* of the unique variance, not all of it.

## 4. Next-session plan (two focused PRs, each FULLY verified)

- **PR A — rename `residual` → `unique` on `latent()`** (the shipped fold): add `unique =`; keep
  `residual =` as a one-shot soft-deprecated alias → `unique` (so fresh code doesn't break); rename
  the internal marker `.auto_residual` → `.auto_unique` (and `is_auto_psi`/`auto_residual_off_family`
  helpers if you like); migrate "residual" prose → "specific/unique" (reserve "residual" for the
  lowest level only); update tests/examples; **run the FULL `devtools::check()` green.**
- **PR B — redo the phylo fold (was #516) with `unique =`** + the **equivalence cascade**: re-apply
  the phylo fold (§5) using `unique =`; fix the broken equivalence tests by setting the *compared*
  `phylo_latent(...)` to `unique = FALSE` (loadings-only ≡ loadings-only — preserves their intent).
  **★ Run the FULL local R-CMD-check (not just the phylo test files) before pushing** — the
  breakages are OUTSIDE the phylo files; that is exactly what bit this session (the 11-file local run
  passed but the full check failed). There is a dedicated **`recovery`** CI workflow too.
- Then: spatial / animal / kernel folds (slice by slice), slice 1b (augmented `phylo_latent(1+x|sp)`),
  then Stage B (hardening/docs — roxygen `@param`, man, AGENTS/CLAUDE grid, NEWS, register; the
  fire-on-use warning for the bare-`*_latent` default change), Stage C (deprecation messaging),
  Stage D (articles), Stage E (`*_unique()` removal — LAST).

## 5. Phylo-fold mechanics (reuse from branch `claude/phylo-fold-20260621`, don't reinvent)

- **Rewriter** (`R/brms-sugar.R`, immediately after the `if (identical(fn,"latent"))` fold block
  ~line 2853): `if (identical(fn,"phylo_latent"))` → read/validate `residual` (default TRUE), drop it
  from the call; `residual=FALSE` → return `phylo_rr(...)` alone; else emit
  `phylo_rr(...) + phylo_rr(e[[2L]], .phylo_unique=TRUE, .auto_residual=TRUE, <pass_through tree/vcv>)`.
  Augmented `phylo_latent(1+x|sp)` is handled+returned EARLIER (the `.latent_slope` block), so the
  fold only sees the intercept-only form (guarded).
- **Dedup** (`R/fit-multi.R` ~340-366, beside the `diag` auto-Ψ dedup): `is_auto_phylo_psi` =
  `kind=="phylo_rr" && .phylo_unique && .auto_residual`; an explicit `phylo_unique()` at the same
  grouping supersedes it (drop the auto one) → byte-identity + avoids the >1-phylo_unique abort; the
  `auto_residual_off_family` (ordinal/delta) gate is extended to drop the phylo companion too.
- **Test:** `tests/testthat/test-phylo-latent-residual-fold.R` (byte-identity + loadings-only + dedup;
  TDD, written RED-first; `simulate_pgllvm`-style DGP with an added phylo diagonal).
- **Grammar-doc cascade** already in the branch: `docs/design/01-formula-grammar.md` pairing-rule note
  updated (phylo folds; spatial/animal/kernel still paired). Re-do for `unique=` in PR B.
- Local verification that PASSED (but missed the equivalence cascade): fold 3/3, critical cascade
  19/19, heavy recovery 27/27.

## 6. Conceptual framing (the maintainer cares — for the eventual article/docs)

Every grouping level decomposes `Σ_level = ΛΛᵀ + Ψ` ("**specific**" variance at each level); the
classical "residual" is just Ψ at the *lowest* level. The **total** `Σ_level` is identified; the
shared/specific **split** is rank-K + replication-sensitive — phylo is the worst case ("two Σ from
one level": a single tree is one realization → the split is barely identified even though total Σ_phy
is fine). **Design stance:** lead with **total Σ_level + correlations** (identified, all
families/levels/mixed — the selling point); present the split as an ordination *view* with explicit
rank/replication caveats; prefer **communality proportions** `h²ₜ = (ΛΛᵀ)ₜₜ/Σₜₜ` over raw specific
variances in user prose; keep `dep()` as the complete-but-heavy unstructured alternative (no rank, no
split, T(T+1)/2 params). No decomposition is *both* parsimonious *and* a clean absolute split — that's
a factor-analysis identifiability fact, not a code gap.

## 7. Other open items (lower priority)

- #343 flaky gate: resolved (#511; more reps + NaN-SE guard). A spawned background chip exists to scan
  other MC recovery gates for the same `as.integer(<NaN comparison>)` → un-guarded `sum()` NA-leak.
- F2: `docs/dev-log/decisions.md` records "keep `two_U`" but the code uses `two_psi` (Noether sweep
  finding) — stale, maintainer's call (1-line amendment).
- ~40 stale `git worktree` entries in `/private/tmp` and worktree dirs from prior sessions — harmless
  clutter, could `git worktree prune` the merged ones.
- **Do NOT touch** the dirty `codex/r-bridge-grouped-dispersion` checkout (the working dir) — it's
  Codex's, per the original handover. **Note: "no Codex lane at the moment" (maintainer 2026-06-21) —
  it is all Claude now**, including the engine work.

## 8. First actions for the next session

1. Read this note + `~/.claude/plans/memoized-snuggling-balloon.md` + the #515 design doc +
   `~/.claude/memory/memory_summary.md` (the ★ Ψ model + snapshot).
2. `git fetch`; confirm `origin/main = 5e64983` (or later) and #516 open/red.
3. **ASK the maintainer to confirm §3** (unique vs specific; alias vs hard-rename) before coding.
4. Then PR A (rename) → PR B (phylo fold redone with `unique=` + equivalence cascade). **Run the FULL
   R-CMD-check / `devtools::check()` locally before pushing each** — the phylo-only test runs miss the
   equivalence breakages.
