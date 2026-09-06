# R-side marshalling design: opening GJL-GATE-STRUCTURED-TERMS for the ordinary/animal/kernel × indep/common/dep subset

Status: DESIGN ONLY, not implemented. Read-only scout on
`claude/julia-bridge-expansion-20260901` @ `ff9e75962`.

## 0. Scope note on the "9 qualified contracts" and the GLLVM.jl-side plan file

`docs/dev-log/core070/covariance-required-case-plan.json` (GLLVM.jl repo) is
**not visible from this repo** — this is `gllvmTMB` (R), a different local
checkout, and this scout is read-only inside it. Everything below is grounded
in this repo's own parser (`R/parse-multi-formula.R`, `R/brms-sugar.R`) and
native-engine mapping (`R/fit-multi.R`), per the fallback instruction. Where I
infer the intended Julia-side contract shape (`SourceCovariance(...)`), I say
so explicitly and mark it a proposal, not a confirmed cross-repo fact.

The "+ fixed" qualifier in the 9-contract grid is read as **`rho` held at its
fixed default (`rho = 1`, no estimation)**, not a fourth structural kind. This
reading is forced by evidence in §5: a brand-new fence
(`.structured_rho_dispatch_fence`, `R/structured-rho.R:143-151`, merged into
`main` today via PR #1232) already hard-refuses `engine = "julia"` for any
formula that carries a non-default structured-`rho` spec, independent of this
design. So "the safe subset" is automatically rho-fixed; nothing here needs to
touch estimated-rho.

## 1. The gate today

### 1.1 What `kinds` is and where the gate lives

`R/julia-bridge.R:3592-3600` (inside `.gllvmTMB_julia_dispatch`):

```r
kinds <- if (length(cs)) {
  vapply(cs, function(z) z$kind, character(1))
} else {
  character(0)
}
unsupported <- setdiff(unique(kinds), "rr")
if (length(unsupported) > 0) {
  stop(.gllvm_julia_gate_message("GJL-GATE-STRUCTURED-TERMS", ...), call. = FALSE)
}
```

`cs <- parsed$covstructs` (`R/julia-bridge.R:3585`), the list produced by
`parse_multi_formula()` before `.gllvmTMB_julia_dispatch` ever runs — see
`R/gllvmTMB.R:1149` (`parsed <- parse_multi_formula(formula)`) and
`R/gllvmTMB.R:1223` (`.gllvmTMB_julia_dispatch(parsed = parsed, ...)`). Each
element of `covstructs` is `list(kind, lhs, group, extra)`
(`R/parse-multi-formula.R:313`, `parse_covstruct_call()`), where **`kind` is
literally the R function name the user (or `rewrite_canonical_aliases()`)
wrote in the formula** — `rr`, `diag`, `propto`, `equalto`, `spde`,
`phylo_rr`, or `re_int` for bar syntax (`R/parse-multi-formula.R:343`).

So the gate today is a **single-kind allowlist**: only `kind == "rr"` passes.
Everything else — including every `indep()`/`common()`/`animal_*`/`kernel_*`
term, none of which are literally `rr` — is refused.

### 1.2 What each user-facing keyword resolves to (`kind`, via `rewrite_canonical_aliases()`, `R/brms-sugar.R`)

| user syntax | rewritten call | `kind` seen by the gate | extra markers |
|---|---|---|---|
| `latent(0+trait\|g, d=K)` / `dep(0+trait\|g)` | `rr(form, d=..., [.dep=TRUE])` | `rr` | `.dep` (dep only) |
| `indep(0+trait\|g, common=)` | `diag(form, .indep=TRUE, [common=])` | `diag` | `.indep`, `common` |
| `scalar(0+trait\|g)` | `diag(form, .indep=TRUE, common=TRUE)` | `diag` | `.indep`, `common=TRUE` |
| `phylo_latent(sp, d=K)` / `phylo_dep(0+trait\|sp)` | `phylo_rr(sp, d=..., [.dep=TRUE])` | `phylo_rr` | `.dep` (dep only) |
| `phylo_indep(0+trait\|sp)` | `phylo_rr(sp, .phylo_unique=TRUE, .indep=TRUE)` | `phylo_rr` | `.phylo_unique`, `.indep` |
| `animal_latent(...)` (`R/brms-sugar.R:3329`) | `phylo_rr(..., .animal_source=TRUE, d=...)` | `phylo_rr` | `.animal_source`, possibly `.dep`/`.indep` |
| `animal_indep(...)` (`R/brms-sugar.R:3420`) | `phylo_rr(..., .phylo_unique=TRUE, .indep=TRUE, .animal_source=TRUE)` | `phylo_rr` | as above |
| `animal_dep(...)` (`R/brms-sugar.R:3510-3567`) | `phylo_rr(..., d=.deferred_n_traits, .dep=TRUE, .animal_source=TRUE)` | `phylo_rr` | as above |
| `kernel_latent(unit, K=, d=)` (`R/brms-sugar.R:3635-3671`) | `phylo_rr(unit, vcv=K, .kernel_name=, .kernel_mode="latent", ...)` | `phylo_rr` | `.kernel_mode`, `vcv` = the literal `K` matrix |
| `kernel_indep(unit, K=, common=)` (`R/brms-sugar.R:3682-3692`) | `phylo_rr(unit, .phylo_unique=TRUE, .indep=TRUE, vcv=K, .kernel_mode="indep"[or "scalar" if `common=TRUE`])` | `phylo_rr` | as above |
| `kernel_dep(unit, K=)` (`R/brms-sugar.R:3710-3714`) | `phylo_rr(unit, d=.deferred_n_traits, .dep=TRUE, vcv=K, .kernel_mode="dep")` | `phylo_rr` | as above |

**Consequence for today's gate**: only plain (no-tree/no-K/no-pedigree)
`latent()`/`dep()` survive `unsupported <- setdiff(unique(kinds), "rr")`.
Ordinary `indep()`/`common()` (`kind = "diag"`) and **every** `animal_*` /
`kernel_*` / `phylo_*` keyword (`kind = "phylo_rr"`) are refused today,
regardless of family. This matches the brief's framing: the whole
ordinary/animal/kernel × indep/common/dep grid is currently closed except one
cell (ordinary `dep`/`latent`, kind `rr`) — and that one cell is itself
broken (§1.3).

### 1.3 The ordinary `dep()` defect — reproduced

`dep(0 + trait | g)` rewrites to `rr(form, d = .deferred_n_traits, .dep =
TRUE)` (`R/brms-sugar.R:4654-4671`) — `.deferred_n_traits` is a **bare R
symbol**, not a resolved integer, because the parser has no access to `data`
at parse time (comment at `R/brms-sugar.R:4658-4661`). The symbol is only
resolved in the **TMB-only** engine path, `R/fit-multi.R:1574-1592`
(`gllvmTMB_multi_fit()`, reached from `fit_once()` at `R/gllvmTMB.R:1229`,
which the Julia branch never reaches — it `return()`s at
`R/gllvmTMB.R:1223` before `fit_once` is defined/called).

So for `engine = "julia"`, `.deferred_n_traits` is **never** replaced. The
symbol rides untouched into `.gllvmTMB_julia_dispatch`, passes the
`unsupported` gate (`kind == "rr"`, not blocked), passes the multi-rr check
(one `rr` term), and then hits:

```r
# R/julia-bridge.R:3666-3668
K <- if (length(rr_terms) == 1L) {
  dval <- rr_terms[[1L]]$extra$d
  as.integer(if (is.null(dval)) 1L else dval)
```

Reproduced directly:

```r
> x <- as.name(".deferred_n_traits")
> as.integer(x)
Error in as.integer(x) : cannot coerce type 'symbol' to vector of type 'integer'
```

This is an **uncontrolled, generic R error** (`cannot coerce type 'symbol' to
vector of type 'integer'`) thrown from base `as.integer()`, not routed
through `.gllvm_julia_gate_message()`/a registered `GJL-GATE-*` id. It gives
the user no indication their formula used `dep()`, no pointer to
`engine = "tmb"`, and no gate id to search for — this is the
"EARLY-GENERIC-ERROR" the brief names: the term slips *past* the deliberate
capability gate and dies in an implementation detail instead. The identical
defect exists for `kernel_dep()` (also `d = .deferred_n_traits`,
`R/brms-sugar.R:3710-3713`) and `animal_dep()`
(`R/brms-sugar.R:3557`) — all three `*_dep()` spellings share one rewrite
pattern and one missing resolution step on the Julia path.

## 2. What the parser gives us at the dispatch site

### 2.1 Structure per kind, at `.gllvmTMB_julia_dispatch` entry (`cs <- parsed$covstructs`)

All covariance-structure terms share the shape `list(kind, lhs, group,
extra)` (`R/parse-multi-formula.R:313`). `extra` is a named list whose
**values are already evaluated R objects**, not language — `parse_covstruct_call()`
evaluates every named/positional extra argument in the formula's own
environment at parse time (`R/parse-multi-formula.R:277-280`:
`val <- tryCatch(eval(extra_args[[i]], envir = eval_env), ...)`). So by the
time the Julia dispatcher runs:

| kind | grouping | rank `d` | `V` source in `extra` | `unique`/mode markers |
|---|---|---|---|---|
| `rr` (ordinary `latent`/`dep`) | `cs$group` (bare column, or `.` for `re_int`) | `extra$d` — integer for `latent(d=)`; **unresolved symbol** for `dep()` (§1.3) | none — no external covariance matrix, plain unstructured/reduced-rank block over `group` levels | `.dep` marks full-rank unstructured; absent for reduced-rank `latent` |
| `diag` (ordinary `indep`/`common`) | `cs$group` | n/a (diagonal, no rank) | none | `.indep` always TRUE for this family; `common` (logical) ties all trait variances to one shared parameter; `.auto_unique` flags the *auto*-emitted Psi companion (must stay excluded — see `R/gllvmTMB.R:1197-1218`) |
| `phylo_rr` (`phylo_*`) | `cs$group` = species factor | `extra$d` (int, or `.deferred_n_traits` symbol for `phylo_dep`) | `extra$tree` (an `ape::phylo` object) **or** `extra$vcv` (already a numeric/`sparseMatrix`) — resolved as an actual R object, but a `tree` still needs `ape::vcv(tree)` to become a covariance matrix; that conversion happens only in `R/fit-multi.R:3946-3970`, never in the parser | `.phylo_unique` (diag-only via the phylo engine), `.dep`, `.indep` |
| `phylo_rr` (`animal_*`) | species/pedigree grouping | as above | `extra$vcv` carries a **sparse `Ainv`** (the inverse relatedness precision, not a covariance) when the user supplied `pedigree =` — per `R/fit-multi.R:3954-3960`, sparse input is detected and used directly as `Ainv_phy_rr`, i.e. downstream code branches on `is.matrix()` vs `inherits(..., "sparseMatrix")` and treats the two cases differently (covariance vs precision) | `.animal_source = TRUE`, plus `.dep`/`.indep`/`.phylo_unique` as above |
| `phylo_rr` (`kernel_*`) | `unit_arg` (bare grouping column) | as above | `extra$vcv` = the **literal user-supplied `K` matrix**, already a plain dense covariance/correlation matrix — no tree/pedigree conversion needed (`R/brms-sugar.R:3635-3639`, `kernel_meta$vcv <- K_expr`) | `.kernel_mode` ∈ `"latent"/"indep"/"dep"/"scalar"` (`sub("^kernel_", "", fn)`), `.kernel_name` |

### 2.2 Does the dispatch site have the evaluated `V` / group columns, or must it re-evaluate?

**Partially yes, partially no:**

- **Group columns**: yes, always. `cs$group` / `cs$lhs` are still unevaluated
  language (symbols/calls) at this point — they get materialized against
  `data` the same way the rest of `.gllvmTMB_julia_dispatch` already
  materializes `trait`/`unit_internal` (`R/julia-bridge.R:3722-3739`,
  `factor(data[[...]])`). Any new marshalling code has to do the equivalent
  `factor(data[[deparse(cs$group)]])` pull itself; nothing upstream does it
  generically for arbitrary covstruct groups today.
- **`V` for `kernel_*`**: yes, no re-evaluation needed — `extra$vcv` is
  already the literal dense matrix the user passed as `K`, sitting in R
  memory, dimnamed (per the kernel docs, `rownames(K)` must align to the
  grouping levels — `R/kernel-keywords.R:21`).
- **`V` for `phylo_*`/`animal_*`**: **no**, real work remains even though the
  *parser* already evaluated `extra$tree`/`extra$vcv` — the *engine-level*
  conversion (`ape::vcv(tree)` for a tree; sparse-`Ainv`-vs-dense-`vcv`
  branching for pedigree/animal terms; global `phylo_tree`/`phylo_vcv`
  override-and-agreement reconciliation across multiple phylo terms) lives
  only in `R/fit-multi.R:3930-3990` (TMB-only path) and would have to be
  reimplemented (or factored out and shared) for the Julia path. This is the
  single biggest reason animal/kernel-via-tree terms are riskier than kernel-
  via-explicit-K or ordinary terms.

## 3. TMB-side semantics to preserve (stated from this repo's own engine, not GLLVM.jl)

Reading `R/fit-multi.R` (phylo/kernel/animal block, roughly L1390-L2360,
L3930-L4260), the native engine maps each admitted covstruct into a
TMB-facing `(covariance matrix source, grouping factor, structural mode,
rank, diagonal-companion flag)` quintuple. Restated as the proposed Julia-side
`SourceCovariance` fields (my inference, **not confirmed against GLLVM.jl's
own contract** — see §0):

| gllvmTMB covstruct | `covariance` (source of `V`) | `groups` | `mode` | `rank` | `unique` |
|---|---|---|---|---|---|
| ordinary `latent(d=K)` | `NULL` (unstructured identity-metric block over `group` levels — no external `V`) | `cs$group` levels | `"latent"` (loadings-only, reduced rank `K`) | `K` | `FALSE` unless a companion `diag` auto-emitted (`.auto_unique`) |
| ordinary `dep()` | `NULL` | `cs$group` levels | `"dep"` (full unstructured `Sigma = LL^T`, rank = n_traits) | `n_traits` (once `.deferred_n_traits` is resolved) | implicit — `dep` "already includes the per-trait diagonal" (`R/fit-multi.R:1962-1968` guard text) |
| ordinary `indep()` | `NULL` | `cs$group` levels | `"indep"` (diagonal, one variance per trait unless `common=TRUE`) | n/a (diagonal) | n/a (it *is* the diagonal term) |
| `kernel_latent`/`kernel_indep`/`kernel_dep` | `extra$vcv` (the literal `K` matrix) | `unit_arg` levels, row/col-matched to `rownames(K)` | `.kernel_mode` (`"latent"`/`"indep"`/`"dep"`/`"scalar"`) | `extra$d` (latent) or n_traits (`dep`) or n/a (`indep`/`scalar`, diagonal) | `unique=TRUE` on `kernel_latent` adds a `Psi` companion; not available for `kernel_dep`/multi-kernel fits (doc note, `R/kernel-keywords.R:8-10`) |
| `phylo_latent`/`phylo_indep`/`phylo_dep` | `ape::vcv(extra$tree)` or `extra$vcv` directly, evaluated once and reconciled across terms (`R/fit-multi.R:3930-3990`) | species factor levels | as kernel row | as kernel row | as kernel row |
| `animal_latent`/`animal_indep`/`animal_dep` | pedigree → **sparse `Ainv`** (relatedness precision) via `pedigree_to_Ainv_sparse()` sugar, or a dense `vcv`/`A` supplied directly; the engine detects `sparseMatrix` vs `matrix` and branches (`R/fit-multi.R:3954-3960`) | pedigree/species grouping levels | as kernel row, `.animal_source=TRUE` label only changes the extractor's printed level name (`R/fit-multi.R:2356`) | as kernel row | as kernel row |

The load-bearing distinction the Julia side must not blur: **`kernel_*` `V`
is already a covariance**, while **`animal_*` `V` can arrive as a
precision** (`Ainv`, sparse) that the fitter must invert or solve against
rather than plug in directly as a covariance. Treating an `Ainv` as if it
were `V` would silently fit the wrong model — this is a correctness trap, not
a cosmetic one.

## 4. Proposed minimal marshalling design

### 4.1 Which kinds open first

Recommend **two slices**, ordered by evidence risk, not by the brief's literal
3×3 grid order:

**Slice A (safest — recommend opening first): ordinary `indep()` / `dep()` /
`common()`, family = gaussian only, rho fixed at default.**
- No external `V` matrix at all (`kind ∈ {"diag", "rr"}`, group is a plain
  factor already available via the same `factor(data[[...]])` pattern the
  dispatcher uses for `trait`/`unit_internal`).
- Requires exactly one new engine-agnostic fix (§4.3) plus a `diag`-kind
  admission and a `common`-flag passthrough — no `ape::vcv`, no sparse
  `Ainv`, no tree/pedigree reconciliation.
- This slice alone converts 2 of the 3 "ordinary" cells from refused to
  admitted, and repairs the third (`dep`) from "crashes with a raw R error"
  to "either fits or refuses with a named gate."

**Slice B (defer — higher risk, do only after Slice A has live paired
evidence): `kernel_*` (indep/dep/latent), family = gaussian only.**
- `V` is already a literal dense matrix (`extra$vcv`), so no
  tree-to-covariance or pedigree-to-precision conversion is needed — this is
  the *safer half* of the `phylo_rr`-kind terms.
- Still needs: dimname alignment between `K` and the grouping factor levels,
  `.kernel_mode` → `SourceCovariance(mode=)` mapping, and reuse (not
  reimplementation) of whatever ordering/relevel logic
  `R/fit-multi.R:1390-1450` already applies before handing `K` to TMB.

**Explicitly NOT opened in this design: `animal_*` / `phylo_*` (tree- or
pedigree-sourced `V`).** The `ape::vcv()` conversion and the
sparse-`Ainv`-vs-dense-`vcv` branch (§2.2, §3) are real engine logic
currently living only in `R/fit-multi.R`, not the parser — marshalling them
without factoring that logic into a shared, tested helper risks a silent
covariance/precision mix-up, which is a correctness bug, not a coverage gap.
This is a recommendation to phase them into a **Slice C**, gated behind
Slice A+B live evidence, not a claim that they cannot ever open.

### 4.2 Payload construction sketch (Slice A + B)

Extend `.gllvmTMB_julia_dispatch`'s existing `kinds`/`cs` walk (currently only
inspecting `kind == "rr"` for the single reduced-rank block,
`R/julia-bridge.R:3654-3665`) to build one `list()` per admitted covstruct
instead of the current single-`rr`-only path:

```r
# sketch — not implemented
structured_terms <- lapply(cs, function(z) {
  grp <- factor(data[[deparse(z$group)]])          # same materialisation
  switch(z$kind,                                     # pattern the dispatcher
    "diag" = list(                                   # already uses for
      mode      = if (isTRUE(z$extra$common)) "common" else "indep",
      groups    = as.integer(grp), group_levels = levels(grp),
      covariance = NULL, rank = NA_integer_, unique = FALSE
    ),
    "rr" = list(
      mode      = if (isTRUE(z$extra$.dep)) "dep" else "latent",
      groups    = as.integer(grp), group_levels = levels(grp),
      covariance = NULL,
      rank      = .gllvm_julia_resolve_d(z$extra$d, n_traits),  # §4.3
      unique    = FALSE
    ),
    "phylo_rr" = if (isTRUE(z$extra$.kernel_mode) ...) list(   # Slice B only;
      mode      = z$extra$.kernel_mode,                         # phylo_rr from
      groups    = as.integer(grp), group_levels = levels(grp),  # animal_*/
      covariance = .gllvm_julia_align_kernel_V(z$extra$vcv, levels(grp)),
      rank      = .gllvm_julia_resolve_d(z$extra$d, n_traits),
      unique    = isTRUE(z$extra$.kernel_unique)
    ) else stop(...)  # tree/pedigree-sourced phylo_rr: still refused
  )
})
```

`bridge_fit` (GLLVM.jl side, out of scope to design here) would need a new
keyword — e.g. `structured = list(...)` — carrying one `SourceCovariance`-
shaped entry per admitted term; the exact Julia-side call shape is a
GLLVM.jl-repo decision, not an R-side one, so this stays at the "what R must
hand across the boundary" level.

### 4.3 One shared fix both slices need: resolve `.deferred_n_traits` before the gate

Currently only `R/fit-multi.R:1574-1592` resolves the symbol, and only on the
TMB path. Proposal: factor that four-line resolution
(`nlevels(factor(data[[trait]]))`, then substitute into every covstruct whose
`extra$.dep` is `TRUE`) into a small shared helper (e.g.
`.gllvmTMB_resolve_deferred_d(covstructs, data, trait)`) callable from
**both** `R/fit-multi.R` and `.gllvmTMB_julia_dispatch`, called in the Julia
path **before** the `unsupported`/multi-rr checks so a `dep()` that fails for
a genuine reason (e.g. multiple `rr` terms) still gets the existing
`GJL-GATE-*` messages, not a raw coercion error.

### 4.4 Gates that stay exactly as they are

- `GJL-GATE-STRUCTURED-TERMS` (`R/julia-bridge.R:3599-3600`) stays as the
  refusal for every kind/mode not explicitly admitted by Slice A/B — i.e. it
  narrows from "only `rr`" to "only `rr`/`diag`/kernel-flavoured `phylo_rr`",
  but the *mechanism* (loud `stop()` naming `engine = "tmb"`) is unchanged.
- `GJL-GATE-MULTI-RR` (`R/julia-bridge.R:3651-3663`) is untouched; a
  `dep()`/`latent()` term still counts as one `rr` slot, so `dep() + latent()`
  on different groupings still trips this exactly as today.
- The brand-new `.structured_rho_dispatch_fence` (`R/structured-rho.R:143-151`,
  merged today) already refuses `engine = "julia"` for any estimated or
  non-default-fixed `rho`, upstream of everything in this design — no new
  gate needed for that boundary, just confirm it still fires (it runs at
  `R/gllvmTMB.R:681-682`, before `parse_multi_formula()` is even called, so
  it is unconditionally upstream of the structured-terms gate).
- `animal_*`/tree-or-pedigree `phylo_*` stay refused by
  `GJL-GATE-STRUCTURED-TERMS` (Slice C deferred, §4.1). If Slice A/B ship
  before Slice C, add one row to
  `.gllvm_julia_expected_capability_drifts()` (`R/julia-bridge.R:447-479`,
  the pattern the 2026-09-01 family-exposure commit just established) noting
  `animal_*`/tree-`phylo_*` as a registered, deliberate
  `r_narrower_than_julia`-shaped gap if GLLVM.jl's own engine already
  supports tree/pedigree covariances — that registry is the existing
  mechanism for "known gap, not silently missing."

### 4.5 Red tests

**Pure-R mapping tests** (no Julia needed — exercise the `parsed$covstructs →
structured_terms` translation directly, mirroring the existing
`tests/testthat/test-julia-bridge.R` style):
1. `indep(0+trait|g)` → one `diag`-kind term maps to `mode="indep"`, correct
   `group_levels` ordering (must match `factor(data[[group]])` level order,
   not row order — a classic NA/ordering trap named in §5).
2. `indep(0+trait|g, common=TRUE)` → `mode="common"`.
3. `dep(0+trait|g)` on data with `nlevels(trait) = 3L` → `rank == 3L`
   (confirms `.deferred_n_traits` resolved, not left as a symbol) — this test
   would have caught the §1.3 defect directly.
4. `dep(0+trait|g) + latent(0+trait|g2, d=1)` → still passes
   `GJL-GATE-MULTI-RR` refusal unchanged (regression guard on §4.4).
5. `kernel_indep(unit, K=K)` with `rownames(K)` in a **different order** than
   `levels(factor(data$unit))` → either a loud mismatch error or a documented
   realignment, never a silent misalignment (this is the grouping-factor
   ordering trap named in §5, made concrete).
6. A formula using the new `rho=` argument on any admitted keyword (e.g.
   `kernel_indep(unit, K=K, rho=0.5)`) still trips
   `.structured_rho_dispatch_fence` before reaching any of the new code
   (regression guard confirming the boundary in §4.4 stays intact).

**One live paired test per opened kind, `engine="julia"` vs `engine="tmb"`**
(gated by `ENV["GLLVM_PARITY_TESTS"] == "1"` per the repo's existing
Workflow-Q R-parity tier, `AGENTS.md` "Engine Quality Battery" item 3):
7. `family=gaussian, indep(0+trait|g)`: fit both engines on identical
   simulated data, assert `abs(logLik_julia - logLik_tmb) < 1e-6` (mirrors
   the existing lognormal live-parity precedent at
   `tests/testthat/test-julia-bridge.R:4205-4229`, per the family-exposure
   spec doc found at `docs/dev-log/julia-bridge/2026-09-01-family-exposure-specs.md:439`).
8. `family=gaussian, indep(0+trait|g, common=TRUE)`: same, plus assert the
   single shared variance estimate matches to the same tolerance.
9. `family=gaussian, dep(0+trait|g)`: same, plus assert the full
   unstructured `Sigma` (via each engine's own extractor) matches to a
   documented tolerance (not necessarily 1e-6 — `dep`'s Cholesky
   parameterisation may hit different local optima across engines; state
   whatever tolerance the test actually achieves rather than asserting one in
   advance).
10. (Slice B) `family=gaussian, kernel_indep(unit, K=K)`: same shape, plus an
    assertion that `rownames(K)`/grouping-level alignment round-trips
    correctly (test 5's live-fit counterpart).

## 5. Risks

**Kind-name drift, 0.7.0-frozen vs current `main`.** PR #1232
(`codex/structured-rho-landing-20260831`) merged into `main` **today**
(commit `65e41e1d7`, 2026-08-31 per the commit timestamp / "today" per the
session clock) and touched exactly the files this design depends on:
`R/brms-sugar.R` (+71 lines), `R/fit-multi.R` (+192), `R/gllvmTMB.R` (+15),
`R/kernel-keywords.R` (+15), `R/animal-keyword.R` (+34),
`R/structured-rho.R` (new, 431 lines). Diffed directly
(`git diff 101fafcc3 6eede9336`): it did **not** rename any `kind` string —
`kernel_latent`/`kernel_indep`/`kernel_dep` still rewrite to `phylo_rr` with
the same `.kernel_mode` values — but it **added** a `rho=` parameter to every
`kernel_*`/`animal_*`/ordinary `dep`-family keyword and a brand-new upstream
fence (`.structured_rho_dispatch_fence`) that runs before `parse_multi_formula()`
at all. Anyone implementing this design against a stale mental model of
"pre-#1232 main" would miss that fence and could wrongly assume `rho=`
support is something *this* design needs to add — it does not; §4.4 covers
why. Re-verify `kind` vocabulary against current `main` at implementation
time, not against this document's snapshot, since the file set that would
carry a future rename is exactly the file set #1232 just changed.

**The `dep()` early defect (§1.3) must be fixed or explicitly gated, never
silently swallowed.** If Slice A implementation only adds `diag`-kind
admission and forgets §4.3's shared `.deferred_n_traits` resolution, ordinary
`dep()` moves from "refused with a raw coercion error" to "refused with a
raw coercion error that now happens one line later" — no actual improvement.
The fix must land *before or alongside* opening the `rr`-kind `.dep` cell,
not after.

**Grouping-factor NA/ordering traps.** `factor(data[[group_col]])` orders
levels alphabetically by default, not by first appearance or by any order a
supplied `K`/`vcv`/pedigree object uses. `R/fit-multi.R` clearly treats this
as a solved-but-fragile problem elsewhere (dimname-matching logic scattered
through the phylo/kernel block, `R/fit-multi.R:1390-1450` and
`:3930-3990`) — any new Julia-side marshalling must either reuse that
existing realignment logic (factor it out, don't duplicate it) or add its own
explicit `match(rownames(K), levels(grp))` check that fails loudly on a
mismatch rather than silently re-indexing. `anyDuplicated`/`NA` handling for
the (trait, unit) cells is already gated for the *response* matrix
(`R/julia-bridge.R:3736-3745`, "duplicated (trait, unit) cells" /
"response mask" checks) but nothing currently checks duplicate or missing
levels in a *structured-term* grouping column — that is new surface this
design introduces and must guard explicitly (test 5 in §4.5).

**`V` evaluation-environment issues.** `parse_covstruct_call()` evaluates
`extra$vcv`/`extra$tree`/`extra$K` in the *formula's* environment
(`eval_env = parent.frame()`, `R/parse-multi-formula.R:254,277`) at parse
time, which for `gllvmTMB()`'s own call chain is the user's calling frame —
fine for a top-level script, but if a future caller builds the formula
programmatically (e.g. inside another function, or a `do.call()` wrapper) and
the referenced object (`K`, `tree`, `pedigree`) is not visible in that frame,
evaluation silently falls back to leaving the raw language object un-evaluated
(the `tryCatch(..., error = function(err) extra_args[[i]])` fallback at
`R/parse-multi-formula.R:279-280` swallows the error and returns the
*unevaluated call*, not a matrix). A downstream consumer that assumes
`extra$vcv` is always a materialized matrix (as this design's sketch in §4.2
does) would then fail confusingly on a language object rather than getting a
clear "object not found" error at parse time. Any Slice B marshalling code
must explicitly check `is.matrix(extra$vcv) || inherits(extra$vcv, "sparseMatrix")`
before use and raise a named, targeted error otherwise — never assume the
parser already guaranteed a materialized matrix.
