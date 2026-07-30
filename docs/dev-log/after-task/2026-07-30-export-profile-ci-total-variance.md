# After-task — export `profile_ci_total_variance()` with per-row `interval_status`

**2026-07-30 · Claude (Fable 5) · lane `claude/export-profile-ci-20260730`, off `main` @ `84bb2c44`**

Rehydrated from `docs/dev-log/handover/2026-07-30-claude-handover-export-profile-route.md`
and implemented its design section. Scope: give the certified interval route a user-facing
entry point without advertising a capability surface wider than the evidence.

## 1 · Scope

The D-43 certificate (`docs/dev-log/2026-07-29-certificate-disposition.md`) describes
`.profile_ci_total_variance()` — a function users could not call. The route they *can* call
for the same estimand, `bootstrap_Sigma()`, covered 0.78 in the same campaign. This arc
converts the evidence-surface gap into a capability-surface one.

## 2 · What changed

| file | change |
|---|---|
| `R/profile-derived.R` | +137 lines, **0 deletions** |
| `NAMESPACE` | +1 export |
| `man/profile_ci_total_variance.Rd` | new (roxygen-generated) |
| `tests/testthat/test-profile-ci-total-variance-export.R` | new, 24 tests |

Three additions, all new code:

- `.total_variance_in_certified_regime(fit, tier, level)` — the regime predicate.
- `.total_variance_interval_status(...)` — per-row claim-boundary marker.
- `profile_ci_total_variance()` — the export, a thin labelling layer.

**The internal `.profile_ci_total_variance()` is byte-unchanged** (verified: the diff has
zero `-` lines). This was deliberate. `dev/m3-grid.R:1553` calls it via `gllvmTMB:::` and is
the instrument that produced the certificate — the disposition records it as sha256-identical
to the committed version on Totoro. Fence 4 ("unexported → now-exported does not change what
was measured") therefore holds *structurally*, not merely by assertion.

## 3 · The fence

`interval_status` takes three values:

- `"certified-0.94"` — the row is inside the certified regime: all-Gaussian, `tier = "unit"`,
  a unit-tier latent of rank `d ∈ {1,2}`, `n_units ≥ 150`, `level = 0.95`, converged.
- `"route-only"` — a computed but uncertified interval.
- `"none"` — a point-only row with no interval.

Conservative by construction: `d = 0` (diagonal-only unit tier) and every `n` between 50 and
150 were **not measured**, so they are uncertified rather than "close enough".

Two deviations from the handover's literal text, both flagged for the maintainer:

1. **A third status, `"none"`.** The handover specified two. A row whose bounds are `NA` is
   point-only, and calling that a `"route-only"` *interval* would assert an interval that does
   not exist. `"none"` is the value `.correlation_interval_status()` already uses for exactly
   this case, so this follows the in-package idiom the handover told me to follow.
2. **The public surface echoes the canonical tier name.** `.total_variance_spec()` normalises
   `"unit"` → the internal `"B"` and the returned frame carried `"B"`. Emitting a
   soft-deprecated internal slot name from a brand-new export contradicts the standing rule
   that reader-facing surfaces carry no internal codes, so the wrapper maps it back. The
   internal route still returns `"B"`; only the export is mapped.

## 4 · Checks run

| check | result |
|---|---|
| new test file, light tier | **17 pass** |
| new test file, `GLLVMTMB_HEAVY_TESTS=1` | **24 pass, 0 fail** |
| `devtools::document()` | clean; NAMESPACE +1, one new Rd |
| `tools::checkRd()` on the new Rd | clean |
| diff shape | 137 insertions, **0 deletions** |
| live in-regime fit (n=150, Gaussian, d=1) | returns `"certified-0.94"` |
| same fit at `level = 0.90` / `tier = "unit_obs"` | drops to `"route-only"` |

**The certified branch was verified live, not only by stub.** This mattered: a fence that
never fires `"certified"` would look correct while being broken-closed, since every test
asserting `"route-only"` would still pass. A real n=150 Gaussian d=1 fit returns
`"certified-0.94"` on all three traits.

The labelling tests are deliberately **fit-free and in the light tier**. The handover records
that 798 heavy tests were skipped in a green CI run, so a fence checked only under
`GLLVMTMB_HEAVY_TESTS=1` would be unguarded in CI.

## 5 · Defect found and fixed in-arc

`.canonical_level_name()` is scalar-only (`length(level) != 1L` returns input unchanged), so
the first implementation silently passed the 3-row `tier` column straight through and the
frame still read `"B"`. Caught by the end-to-end test, not by the stub tests — the stubs never
exercised the real returned frame. Fixed with an element-wise `vapply()`.

## 6 · Policy checks

- `profile_ci_total_variance` is **not** on the withdrawn-export list in
  `tests/testthat/test-profile-ci-lv-effects.R:5`. That list fences the penalty-based
  *nonlinear* profile routes (communality, correlation, proportions, repeatability) — issue
  #813's subject. This route is the fix-and-refit χ²₁ route and is a different mechanism, so
  the export does not breach that fence.
- No test asserts a complete export set, so an additive export cannot break one.
- `\seealso` targets `extract_Sigma()` and `bootstrap_Sigma()` are both exported.

## 7 · NOT done — deliberately

- **`NEWS.md` is untouched.** Handover item 4 says an entry is now appropriate because the
  *capability* is new, but requires confirming with the maintainer first. Not my call.
- **The register is untouched.** `CI-08` stays `partial`.
- **The `.onLoad` message is untouched.** It still reads "no cell's interval coverage is
  certified", which is now arguably stale — but the maintainer's register-not-NEWS decision
  governs public claim surfaces, so changing it is a maintainer act.
- **`profile_ci_correlation()` / `profile_ci_communality()` naming** (handover item 5) — the
  pre-existing dot/no-dot inconsistency is untouched.

## 8 · Open question for the maintainer

The label `"certified-0.94"` marks **regime membership**, not a certified individual interval,
and the roxygen says so explicitly. But the certificate is evidence from **one simulated
Gaussian DGP**; the disposition lists "any real dataset" as NOT covered. So a real fit inside
the regime gets `"certified-0.94"` on the strength of simulation evidence. That is the
handover's specified design and I implemented it as specified rather than improvising — but
it is the one place where the label could be read more broadly than the evidence supports.
Worth a maintainer decision on the string itself.

## 9 · Follow-ups

- `tests/testthat/_snaps/plot-visual-snapshots/` compares rect widths at ~1e-5 px; two
  baselines differ from regenerated output only in the 6th–7th decimal (`0.000014` vs
  `0.000013`). That comparison will keep flapping across platforms/BLAS. Not touched — not
  this lane's file.
- Issue #813 step 1 (instrument `profile_communality()` with achieved `c2` + convergence
  status per grid point) is the maintainer's next named ask.

## 10 · Landing state

| branch | committed | pushed | merged |
|---|---|---|---|
| `claude/export-profile-ci-20260730` | y | y | **n — maintainer's act** |

**Not self-merged deliberately.** A new public export is an API change, which
`CLAUDE.md`'s merge-authority rule puts in the high-risk set requiring maintainer approval.

## 11 · Verification note — what is NOT covered

The full light-tier `testthat::test_local()` sweep was launched but had **not finished** when
this was written; it contended for CPU with a concurrent Codex CRAN-gate run in
`/private/tmp/gllvmtmb-cran-gate`. **No claim of "full suite green" is made here.**

What *was* verified is listed in §4 and §6: the new file at both tiers (24 pass), a live
in-regime fit returning `"certified-0.94"`, `checkRd` on the new Rd, and a targeted
regression run over every test file that asserts on the export set — 61 pass, 0 fail, 0 error.
The residual risk is a regression in a file none of those touch, which for a 137-insertion,
zero-deletion change that adds only new symbols is low but not zero.
