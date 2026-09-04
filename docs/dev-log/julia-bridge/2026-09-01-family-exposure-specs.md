# Family-exposure discovery specs — engine="julia" (ultracode scouts, 2026-09-01)

Five read-only scouts traced each unexposed family across both repos.
Implementation order follows risk: each slice is red-first and fit-only
unless the spec evidences more.

## truncated_poisson

### r_family_constructors

R/families.R:314-326 defines the ONLY native constructor: truncated_poisson(link = 'log'). It calls .gllvm_family('truncated_poisson', substitute(link), link, 'log', full = FALSE) (families.R:319-320) — full=FALSE means no dev.resids/aic/initialize slots (same pattern as lognormal/censored_poisson/multinomial). It overrides linkinv to the untruncated-to-truncated-mean map mu/(-expm1(-mu)) (families.R:321-324). No R-level aliases exist (no truncpois()/tpoisson() wrapper — grep across R/*.R found none). R/fit-multi.R:1215 hard-errors "truncated_poisson: only the log link is currently supported" — despite the link= argument existing, only log is actually usable natively.

For .gllvm_julia_family_scalar (julia-bridge.R:685-750): add the switch arm `truncated_poisson = "truncated_poisson"` (bare-string case, same style as `lognormal = "lognormal"` at line 733). The existing generic path already handles the family-OBJECT form: only binomial-class family objects get special link-branching (lines 686-706); every other family object falls through to `family <- family$family` (line 706) then tolower+switch, so truncated_poisson()'s $family field ("truncated_poisson", set at families.R:319) resolves correctly through the new switch arm with NO additional object-specific branch needed. Also add "truncated_poisson" to .GLLVM_JULIA_BRIDGE_FAMILIES (julia-bridge.R:20-32) and to the error-message family list at line 745. Do NOT add link-based branching: both R and Julia are hard-fenced to log-only, so one unconditional string mapping is correct (mirroring how the switch never branches on link except for binomial).

### julia_requirements

Traced in src/bridge.jl (GLLVM.jl-core070-aghq-20260830). key=="truncated_poisson" branch: lines 1078-1102, reached via `_bridge_family_key` (lines 143-161; accepts "truncated_poisson"/"truncpois"/"truncatedpoisson", all case-insensitive, normalising to "truncated_poisson"). Requirements/behavior of the route:

- Payload beyond Y: NONE beyond `y` (p×n matrix) and `d` (latent dim K). No trials/N matrix (not a binomial-family route), no zero-inflation structure (this is truncation, not ZI), no X, no X_lv, no options besides d — options["ci_method"] is read only to REJECT anything but "none".
- Response validation (lines 448-457, 1078-1092): every Y entry must be finite, >= 1, an exact integer, and losslessly representable as Int (`v == y[i]` after Float64 round-trip). Fractional or zero/negative values throw ArgumentError — never silently rounded or clipped. This must be enforced by R before marshalling, or the bridge call throws.
- Dispersion returned: `dispersion = fill(NaN, p)` (bridge.jl:1090) — i.e. the payload explicitly reports NO dispersion parameter (truncated Poisson has none; matches R native, which likewise defines no phi/sigma for this family). `sigma_eps = NaN` too.
- X / grouped dispersion / masks: NOT supported. `"truncated_poisson"` is present in `_BRIDGE_ONEPART_FAMILIES` (line 185) but ABSENT from `_BRIDGE_X_FAMILIES` (line 202), `_BRIDGE_XLV_FAMILIES` (line 191), `_BRIDGE_MASK_FAMILIES` (~line 559), and `_BRIDGE_GROUPED_DISPERSION_FAMILIES` (~line 567) — none of these lists include it (there is no per-trait/grouped dispersion concept for this family at all, unlike NB2/Beta/Gamma). test_bridge_truncated_poisson.jl:47-49 pins `!("truncated_poisson" in GLLVM._BRIDGE_X_FAMILIES)`, `!(... _BRIDGE_XLV_FAMILIES)`, `!(... _BRIDGE_MASK_FAMILIES)` directly. Passing `mask=`, `X=`, or `X_lv=` to bridge_fit with this family throws ArgumentError (test lines 91-99, verified against the actual guard code path — mask/X/X_lv are rejected before any fit is attempted for families outside those tuples).
- CI: `_bridge_ci_guard_truncated_poisson` (bridge.jl:633-638) throws ArgumentError for any `ci_method != "none"`, because `TruncatedPoissonFit` is not in the native `_CIFit` union — "truncated_poisson" is listed in `_BRIDGE_NO_CI_FAMILIES` (line ~558-559, alongside per-trait ordinal and lognormal).
- Postfit (residuals/simulate/predict via scalar-mean extractor): "truncated_poisson" is in `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES` (line ~567) — TruncatedPoissonFit has no getLV/residuals/simulate adapter on this engine at all.
- Sigma/correlation/communality ARE returned, but via the SAME self-contained fallback lognormal uses: raw ΛΛᵀ from the loadings only (bridge.jl:1094-1102), not a distribution-aware link-residual extractor — communality is hardcoded to 1 for every trait (comm = ones(p)), not a real family-specific decomposition.
- R dispatch currently marshals NONE of X/X_lv/masks/grouped-dispersion/CI for this family — because the family isn't wired into the bridge switch at all yet (there is no existing R-side capability list membership to check; all of it must be added as explicit ABSENCES, i.e. this family must be left OUT of every R capability list except .GLLVM_JULIA_BRIDGE_FAMILIES itself).

### dispersion_public_parameter

Native R truncated_poisson has NO fitted dispersion/scale parameter at all — it is a zero-truncated Poisson (mean-only, log link). Confirmed via R/enum.R (fid=10, no dispersion column) and R/extract-sigma.R:288-299, where the fid==10 branch computes a DERIVED latent-scale residual-variance approximation (`sigma2_d = log1p(1/mu_t)`, an untruncated lognormal-Poisson approximation per Cameron & Trivedi 2013 ch.4) purely for the Sigma/correlation summary machinery — this is not a model parameter, has no name in summary()/print() output, and is not stored as `.phi`-style dispersion the way nbinom2/beta/gamma/lognormal are (contrast lognormal's real fitted sigma at R/families.R and julia-bridge.R:854 `lognormal = "sigma"`). families.R:319-320 constructs it with `full = FALSE`, meaning no dev.resids/aic slots either — consistent with "no dispersion to report."

Given this, `.gllvm_julia_public_dispersion_parameter` (julia-bridge.R:847-857) should NOT add a `truncated_poisson = "..."` case; it should fall through to the existing default `"dispersion"` arm, and more importantly `.gllvm_julia_normalise_result`'s dispersion-labelling logic should never be exercised for this family in practice because the Julia payload reports `dispersion = fill(NaN, p)` (bridge.jl:1090) and "truncated_poisson" is absent from `.GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES`, so the grouped-dispersion branch (julia-bridge.R:895-980) is skipped and the plain `else if (!is.null(res$dispersion) && p > 0L)` branch at ~981 will run, naming the all-NaN vector with trait names but not attaching any `dispersion_public`/`dispersion_public_parameter` label. This is CORRECT behavior — surfacing a labelled NaN "dispersion" would misrepresent a family that has none.

### capability_gating

Given the Julia route's actual coverage (no-X, no dispersion, no CI, no postfit extractor — verified above against src/bridge.jl and test_bridge_truncated_poisson.jl), truncated_poisson must stay OUT of every R capability list except .GLLVM_JULIA_BRIDGE_FAMILIES itself and .GLLVM_JULIA_ORDINATION_FAMILIES (which julia-bridge.R:73 defines as literally == .GLLVM_JULIA_BRIDGE_FAMILIES, so it is unconditionally included there — same treatment as lognormal). Specifically it must stay OUT of:
- .GLLVM_JULIA_X_FAMILIES (line ~78) — Julia has no X route for this family (absent from Julia's _BRIDGE_X_FAMILIES).
- .GLLVM_JULIA_XLV_FAMILIES (line ~85) — absent from Julia's _BRIDGE_XLV_FAMILIES.
- .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES / .GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES (lines ~40-46) — no dispersion of any kind exists for this family.
- .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES (line ~53) and everything derived from it: .GLLVM_JULIA_PREDICT_FAMILIES, .GLLVM_JULIA_RESIDUAL_FAMILIES, .GLLVM_JULIA_SIMULATE_FAMILIES — Julia has no scalar-mean postfit extractor (truncated_poisson is in Julia's _BRIDGE_NO_SCALAR_POSTFIT_FAMILIES).
- .GLLVM_JULIA_MASK_FAMILIES / .GLLVM_JULIA_MASK_CI_FAMILIES (lines ~76, ~103) — Julia rejects mask= outright for this family (test line 91-92 pins this).
- .GLLVM_JULIA_CI_NO_X_FAMILIES currently == setdiff(.GLLVM_JULIA_BRIDGE_FAMILIES, .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES) (lines ~99-102) — this naive setdiff would WRONGLY include truncated_poisson once it's added to BRIDGE_FAMILIES, since it only excludes ordinal families. This list needs an explicit fix: either add truncated_poisson (and lognormal, which has the identical problem — check whether that was already fixed for lognormal's 2026-09-01 landing) to the exclusion, or redefine .GLLVM_JULIA_CI_NO_X_FAMILIES as an explicit allow-list rather than a setdiff, because Julia's `_bridge_ci_guard_truncated_poisson` throws on ANY ci_method != "none" (TruncatedPoissonFit is not in Julia's native _CIFit union) — CI is not "narrower," it is ABSENT. Same applies to .GLLVM_JULIA_MASK_CI_FAMILIES (setdiff of MASK_FAMILIES) — moot since truncated_poisson won't be in MASK_FAMILIES to begin with, so the setdiff correctly excludes it, but verify this explicitly in a test rather than assuming the setdiff is right.
- .GLLVM_JULIA_X_CI_FAMILIES (== .GLLVM_JULIA_X_FAMILIES) — excluded transitively once X_FAMILIES excludes it.
- .GLLVM_JULIA_MIXED_COMPONENT_FAMILIES (line ~93-97) — Julia's mixed-family dispatch is not evidenced for this family; do not add it (it currently only has gaussian/poisson/binomial and there is no reason to widen it here).

Where inclusion IS genuinely safe and evidenced: only .GLLVM_JULIA_BRIDGE_FAMILIES (the fit-only admission list) and .GLLVM_JULIA_ORDINATION_FAMILIES (Sigma/correlation/communality are returned by the Julia payload — albeit via the same coarse ΛΛᵀ-only fallback lognormal uses, comm hardcoded to 1 — so "ordination" extraction is exercisable, matching the precedent already set for lognormal in this exact codebase). This is the conservative fit-only exposure: gllvmTMB(family = truncated_poisson(), engine = "julia") should fit and return alpha/loadings/Sigma/correlation/communality/loglik, with NO X, NO dispersion label, NO CI, NO predict/residuals/simulate.

### live_test_sketch

test_that("truncated_poisson round-trips through engine = 'julia' (live)", {
  skip_if_no_julia()
  set.seed(419)
  n_unit <- 40L
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = factor(c("t1", "t2", "t3")),
    KEEP.OUT.ATTRS = FALSE
  )
  beta <- c(0.9, 0.7, 1.1)[as.integer(df$trait)]
  lam  <- c(0.35, -0.3, 0.25)[as.integer(df$trait)]
  z <- rnorm(n_unit)[as.integer(df$unit)]
  mu <- exp(beta + lam * z)
  # zero-truncated Poisson draw: rejection-sample away zeros so every
  # response is a positive integer (y >= 1), matching both engines'
  # validation (R fit-multi.R:3678-3688; Julia bridge.jl:1078-1092).
  rtpois <- function(mu) {
    y <- rpois(length(mu), mu)
    while (any(y == 0L)) {
      z0 <- y == 0L
      y[z0] <- rpois(sum(z0), mu[z0])
    }
    y
  }
  df$value <- rtpois(mu)
  stopifnot(all(df$value >= 1))

  fit_j <- gllvmTMB(
    value ~ 1 + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", trait = "trait",
    family = truncated_poisson(), engine = "julia", ci_method = "none"
  )
  fit_r <- gllvmTMB(
    value ~ 1 + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", trait = "trait",
    family = truncated_poisson()
  )
  expect_s3_class(fit_j, "gllvmTMB_julia")
  expect_true(is.finite(logLik(fit_j)))
  expect_lt(abs(as.numeric(logLik(fit_j)) - as.numeric(logLik(fit_r))), 1e-4)
})

# Pure-R capability-gate companions (no skip_if_no_julia needed), mirroring
# the lognormal precedent at test-julia-bridge.R:517-527 and :606-611:
test_that("truncated_poisson family mapping and gates", {
  expect_identical(.gllvm_julia_family("truncated_poisson"), "truncated_poisson")
  expect_identical(.gllvm_julia_family(truncated_poisson()), "truncated_poisson")
  expect_true("truncated_poisson" %in% .GLLVM_JULIA_BRIDGE_FAMILIES)
  expect_false("truncated_poisson" %in% .GLLVM_JULIA_X_FAMILIES)
  expect_false("truncated_poisson" %in% .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES)
  expect_false("truncated_poisson" %in% .GLLVM_JULIA_MASK_FAMILIES)
  expect_false("truncated_poisson" %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES)
})

### risks

- Zero-inflated-vs-zero-truncated conflation: this family is NOT a zero-inflated Poisson (there's no structural-zero mixture) — it is the Poisson distribution CONDITIONED on Y>=1 (support starts at 1, mass renormalised by 1-P(Y=0)). If whoever wires this reuses any ZIP-shaped R marshalling path (the bridge does route zip/zinb/zib as distinct two-part families) that would be a parameterization-family mismatch, not just incompleteness. Keep truncated_poisson entirely separate from the zip/zinb/zib wiring.
- Link mismatch is a live risk if link-checking is skipped: R's truncated_poisson(link='log') constructor accepts a link= argument syntactically, but fit-multi.R:1215 hard-errors on non-log links natively, and Julia's fit_truncated_poisson_gllvm equally hard-errors on non-LogLink (src/families/truncated_poisson.jl:103). The R-Julia switch entry must not silently accept a non-log-link truncated_poisson() object and forward it to Julia (which would silently fit a different eta parameterization for the SAME nominal family name) -- add an explicit link=='log' check at the switch site, mirroring the binomial link branch pattern already in .gllvm_julia_family_scalar.
- The 'mu' in R's linkinv (families.R:321-324, mu/(-expm1(-mu))) is the TRUNCATED (observable) mean, computed from the untruncated eta=log(mu_untruncated) via the truncation-adjustment formula. The Julia fit reports alpha/loadings on the UNTRUNCATED-mean log-linear predictor (bridge.jl note: 'log link on untruncated mu'). If any downstream code path calls predict()/fitted() and applies R's truncated-mean linkinv to Julia's alpha/loadings without checking that both sides mean the SAME thing by 'eta', point estimates would parse correctly (they're both on the untruncated log-mu scale, matching test_bridge_truncated_poisson.jl's direct atol=1e-8 comparison of br.alpha vs oracle.beta) but any naively-added predict() capability could silently double-apply or skip the truncation adjustment. Since predict is being kept gated (per capability_gating above), this is a dormant risk to flag for whenever postfit surfaces are added later, not a blocker for the conservative fit-only exposure now.
- Dispersion-parameter naming risk: because truncated_poisson genuinely has NO dispersion, if a switch entry is added to .gllvm_julia_public_dispersion_parameter (which it should NOT be, per dispersion_public_parameter above) that mints a label like 'dispersion' or 'phi' for this family, downstream summary()/print() code could start displaying a spurious all-NaN 'dispersion' row for a family that natively never has one -- verify no such label gets attached, and that the all-NaN res$dispersion vector from Julia is either dropped entirely or clearly marked non-substantive in the normalised result, not surfaced as if it were a real estimated quantity.
- The .GLLVM_JULIA_CI_NO_X_FAMILIES setdiff-based definition (julia-bridge.R line ~99, setdiff(.GLLVM_JULIA_BRIDGE_FAMILIES, .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES)) will silently and WRONGLY include truncated_poisson in whatever downstream consumer reads that list once truncated_poisson is added to BRIDGE_FAMILIES, because the setdiff only strips ordinal families, not lognormal or truncated_poisson (both of which Julia's _bridge_ci_guard_* functions reject outright). This is a correctness bug waiting to happen at the exact moment this family is exposed -- confirm whether the identical bug already exists for lognormal (added earlier the same day per the test diffs) and fix both together rather than assuming the existing lognormal landing already handled it.
- Response-shape mismatch: R's y>=1 integer check (fit-multi.R:3677-3688) runs only on UNMASKED rows (masked_response guard), but Julia's bridge_fit has NO masking route at all for this family (mask= throws ArgumentError unconditionally per test line 91-92) -- so if R ever tried to pass a masked design to the Julia truncated_poisson route (even with all-valid unmasked truncated-Poisson rows plus masked cells elsewhere in a mixed-family fit), the marshalling layer must reject that combination explicitly before calling into Julia, not rely on Julia's blanket mask= reject to catch it after values have already been prepared.

## zib (zero-inflated binomial)

### r_family_constructors

CRITICAL FINDING: R's gllvmTMB has NO native "zib" / zero-inflated-binomial family constructor at all. Exhaustive grep of R/families.R and every R/*.R file for "zib", "zibinomial", "zero_inflated_binomial", "zi_binomial", "ZIB", "zip", "zinb", "zero_inflated", "zeroinfl" returns zero hits. R/families.R defines gaussian/lognormal (R/families.R:221)/lognormal_mix/binomial/poisson/negbinomial/beta/gamma/ordinal/delta_* etc., but nothing zero-inflated. So there is no answer to "how does a native user spell this family" — a native gllvmTMB() user cannot fit this family in either engine today.

Consequently .gllvm_julia_family_scalar's switch() (R/julia-bridge.R:713-748) has no "zib"/"zibinomial"/etc. case; today it falls through to the GJL-GATE-FAMILY stop() at R/julia-bridge.R:733-748 ("unsupported family '...'").

What the Julia bridge itself accepts as aliases (src/bridge.jl:159, pinned by test/test_bridge_zib.jl:56-59): key ∈ {"zib","zibinomial","zero_inflated_binomial","zi_binomial"} (case/whitespace-insensitive — "ZIB" and "  Zero_Inflated_Binomial  " both pass) → bridge string "zib". So IF/when R adds a native spelling, .gllvm_julia_family_scalar must map whichever R-side alias(es) are chosen to the single bridge string "zib" (mirroring the existing switch(fam, binomial_probit = "binomial_probit", ...) pattern). But choosing and adding that R-side constructor (e.g. a new zero_inflated_binomial()/zib() with a $family field and canonical link "logit", matching Julia's LogitLink-only success-part) is new native-family work outside R/julia-bridge.R and outside "expose an existing family through the bridge" — unlike lognormal, which already had a native constructor (R/families.R:221) before its 2026-09-01 bridge exposure, zib has no such prerequisite met.

### julia_requirements

Traced in src/bridge.jl's "zib" branch (src/bridge.jl:1424-1462) plus _bridge_zib_trials (src/bridge.jl:588-615) and bridge_capabilities (src/bridge.jl:686-735):

1. Trials N (REQUIRED, non-standard shape): ZIB is NOT in _BRIDGE_TRIALS_FAMILIES (src/bridge.jl:198-201; confirmed by test_bridge_zib.jl:64 `!("zib" in GLLVM._BRIDGE_TRIALS_FAMILIES)`). It needs ONE shared scalar Int trials count, not R's usual per-observation cbind(successes,failures) two-column response. `N=nothing` throws ArgumentError ("N=1 would be the aliased zero-inflated Bernoulli"); a p×n N array is accepted only if every entry is equal, then collapsed to that scalar; unequal entries error rather than silently taking N[1,1] (src/bridge.jl:588-615). The R side's existing binomial trials marshaling is entirely driven by `.GLLVM_JULIA_BINOMIAL_FAMILIES` membership (R/julia-bridge.R:32-36, 3649-3689, 3826-3838) which builds N via two-column cbind(successes,failures) response detection — that mechanism is wrong for zib and zib must NOT be added to `.GLLVM_JULIA_BINOMIAL_FAMILIES`/`.GLLVM_JULIA_TRIALS`-style lists. A distinct R-side path (e.g. threading an explicit N=/trials= argument straight into gllvm_julia_fit's existing N parameter, bypassing cbind detection) would be required — not present today.

2. Response range: Y must be integer, all cells in 0:N (src/bridge.jl:1429-1431).

3. Zero-inflation structure: the Julia payload returns a distinct `beta_zero::Vector{Float64}` field (structural-zero logit intercepts per trait, length p) IN ADDITION to `alpha` (success-part logit intercepts = fit.βc) — this is new relative to every other exposed family. `dispersion` is returned as all-NaN (src/bridge.jl:1447: `dispersion = fill(NaN, p)`) — ZIB has no classical dispersion parameter; the interesting extra parameter is beta_zero, and R's normalise/flatten code has no field for it yet.

4. Masks: hard-blocked. `M === nothing || throw(ArgumentError(...))` (src/bridge.jl:1425-1427) — fit_zib_gllvm has no mask kwarg at all, unconditionally, unlike e.g. beta-binomial. Confirmed by test B3 (test_bridge_zib.jl:174-177, 11).

5. X (fixed effects): the underlying Julia engine DOES have `fit_zib_gllvm_cov` (native X support, exercised directly in test/test_zib_x_identity.jl — dual-offset structural-zero γz and success-part γc, FD-verified), but `zib` is explicitly NOT in `_BRIDGE_X_FAMILIES` (src/bridge.jl:198-201; test_bridge_zib.jl:62, 178-181: `bridge_fit(...; X=...)` throws ArgumentError). So X is a real engine capability the bridge_fit route intentionally does not yet expose ("a separate arc gated on a +X CI engine" — src/bridge.jl:754, test comment line 61). R must NOT marshal X for zib even though R's `.GLLVM_JULIA_X_FAMILIES` mechanism exists generically — including zib there would call a route that errors.

6. X_lv (predictor-informed latent scores): not in `_BRIDGE_XLV_FAMILIES` (src/bridge.jl:200); bridge_fit(...; X_lv=...) throws (test_bridge_zib.jl:182-184).

7. Grouped dispersion: not applicable — zib is not in `_BRIDGE_GROUPED_DISPERSION_FAMILIES` (src/bridge.jl:546-547) and returns NaN dispersion uniformly (no grouping concept).

8. CI (no-X): genuinely wired and verified. zib is NOT in `_BRIDGE_NO_CI_FAMILIES` (src/bridge.jl:558-559; confirmed test line 69), so `ci_method ∈ {"wald","profile","bootstrap"}` all route through `_bridge_compute_ci_ng`/`_family_ci(::ZIBFit)`. test_bridge_zib.jl:190-212 shows a live Wald-CI parity check against the native `confint(oracle, ...; method=:wald)` oracle with max|Δ| ≤ 1e-8 — this is the one genuinely evidenced, safe-to-enable capability.

9. Predict/residuals/simulate (Julia-side granularity, finer than R's bundled list): predict IS wired (zib ∈ predict_families, since predict_families = all onepart, src/bridge.jl:703); residuals IS wired (zib not in `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES`, src/bridge.jl:566-567); but simulate is NOT wired — zib ∈ `_BRIDGE_NO_SIMULATE_FAMILIES` (src/bridge.jl:572, confirmed test lines 70-72: `!hasmethod(GLLVM.simulate, Tuple{GLLVM.ZIBFit,Int})`). R's corresponding gating variable, `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` (R/julia-bridge.R:52-66), is a SINGLE list that simultaneously drives PREDICT_FAMILIES, RESIDUAL_FAMILIES, and SIMULATE_FAMILIES together — it has no finer split matching Julia's predict/residuals=yes-but-simulate=no distinction. Adding zib to that one R list would incorrectly advertise simulate() as safe when the Julia route has no simulate method and would error.

10. Ordination/loadings: always safe — `getLoadings`/`Sigma`/`correlation`/`communality` are returned for every one-part family unconditionally (src/bridge.jl:1440-1445; postfit_ordination is `true` for all onepart families at src/bridge.jl:733), matching R's `.GLLVM_JULIA_ORDINATION_FAMILIES = .GLLVM_JULIA_BRIDGE_FAMILIES` auto-inclusion pattern (R/julia-bridge.R:67). Communality is a "shared-block fallback" == 1 for every trait (note text, and test line 136) — ZIBFit has no link-residual extractor, so Sigma/correlation come from ΛΛᵀ directly, same honest fallback used elsewhere.

### dispersion_public_parameter

No grep evidence of any existing R-native public name for a zero-inflation/structural-zero probability parameter for a response-family mixture. Searches for "structural.zero", "zero.inflat", "pi_zero", "p_zero", "zi_prob", "psi" across R/*.R turn up only unrelated uses of "structural zero" (fixed-coefficient constraints, off-diagonal correlation-matrix structural zeros in screen-separation.R / z-confint-gllvmTMB.R / va-intervals.R / profile-route-matrix.R) — none is a response-mixture zero-inflation parameter. `.gllvm_julia_public_dispersion_parameter()` (R/julia-bridge.R:851-861) has switch cases for negbinomial="sigma", nb1="phi", beta="sigma", gamma="sigma", lognormal="sigma", with a default fallback of "dispersion" for anything unmatched — there is no "zib" case, so today it would silently fall through to the generic "dispersion" label, which is doubly wrong: (a) it doesn't exist as a name in native R docs (there is no native path to check against, per Q1), and (b) ZIB's payload dispersion field is all-NaN anyway (see Q2 #3) — the real per-trait quantity worth naming publicly is `beta_zero` (structural-zero logit intercept), which has no established public name in either the R codebase or a native gllvmTMB extractor. This is a genuine naming gap, not merely an omission — a maintainer decision is needed before this label can be set correctly rather than guessed.

### capability_gating

Given the Julia route's actual support (Q2) and the complete absence of a native R constructor (Q1), the conservative fit-only exposure of "zib" must stay OUT of every one of these R-side gating lists (R/julia-bridge.R:18-107):

- `.GLLVM_JULIA_BINOMIAL_FAMILIES` (R/julia-bridge.R:32-36) — MUST exclude. This list drives both `cbind_binomial` capability AND the actual response-marshaling code path (cbind(successes,failures) two-column detection, R/julia-bridge.R:3649-3689, 3826-3838). Including zib here would silently route it through the wrong N-construction mechanism (per-observation trials instead of the required single shared scalar).
- `.GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES` / `.GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES` (R/julia-bridge.R:37-46) — MUST exclude; no grouped-dispersion concept applies (dispersion is NaN).
- `.GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES` (R/julia-bridge.R:48-51) — MUST exclude; not ordinal.
- `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` (R/julia-bridge.R:52-59) — MUST exclude for a fit-only exposure, even though Julia genuinely supports predict/residuals for zib, BECAUSE this one R list bundles predict+residuals+simulate together and Julia's simulate is unsupported for zib (`_BRIDGE_NO_SIMULATE_FAMILIES`). Including zib here would falsely advertise `postfit_simulate = TRUE` for a route with no `simulate(::ZIBFit)` method, which would error at call time. (A future finer split mirroring Julia's three separate lists — `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES` vs `_BRIDGE_NO_SIMULATE_FAMILIES` — could safely enable predict+residuals for zib later, but that R-side refactor is out of scope for a minimal, conservative exposure.)
- `.GLLVM_JULIA_MASK_FAMILIES` / `.GLLVM_JULIA_MASK_CI_FAMILIES` (R/julia-bridge.R:68-75, 103-106) — MUST exclude; fit_zib_gllvm has no mask kwarg, hard ArgumentError on any mask (Q2 #4).
- `.GLLVM_JULIA_X_FAMILIES` / `.GLLVM_JULIA_X_CI_FAMILIES` (R/julia-bridge.R:77-84, 107) — MUST exclude; bridge_fit hard-rejects X for zib even though the underlying Julia engine has fit_zib_gllvm_cov (Q2 #5). This is the sharpest trap: "the engine can do it" ≠ "the bridge route exposes it" — don't infer X-safety from GLLVM.jl's test suite alone.
- `.GLLVM_JULIA_XLV_FAMILIES` (R/julia-bridge.R:85-92) — MUST exclude; bridge_fit hard-rejects X_lv (Q2 #6).
- `.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES` (R/julia-bridge.R:94-98) — MUST exclude unless/until zib is explicitly validated inside a mixed-family vector fit (test_bridge_zib.jl:186-187 explicitly confirms per-trait mixed-family vectors currently reject zib too).

Lists where inclusion is genuinely safe and evidenced, IF zib is added to `.GLLVM_JULIA_BRIDGE_FAMILIES` at all:
- `.GLLVM_JULIA_CI_NO_X_FAMILIES` (R/julia-bridge.R:99-102, `setdiff(BRIDGE_FAMILIES, PERTRAIT_ORDINAL_FAMILIES)`) — automatic inclusion is correct and matches evidenced Julia behavior: zib is not ordinal, and Julia's no-X Wald/profile/bootstrap CI is real and tested to 1e-8 against the native oracle (Q2 #8). This is the one CI capability safe to advertise.
- `.GLLVM_JULIA_ORDINATION_FAMILIES` (`= .GLLVM_JULIA_BRIDGE_FAMILIES`, R/julia-bridge.R:67) — automatic inclusion is correct; loadings/Sigma/correlation/communality are always returned (Q2 #10), matching every other exposed family's fallback pattern.
- `cbind_binomial` capability column is correctly FALSE for zib (it is driven by `.GLLVM_JULIA_BINOMIAL_FAMILIES`, which zib must not join) — this is a capability-matrix row that should read false, not a list to add zib to.

Net: adding "zib" only to `.GLLVM_JULIA_BRIDGE_FAMILIES` (plus, separately, whatever new response/trials marshaling code the scalar-N contract requires) is the narrowest slice that would make the auto-generated capability matrix (R/julia-bridge.R:335-359) come out correct by construction, since `fixed_effect_X`, `missing_response`, `predictor_informed_lv`, and the three `ci_x_*`/`ci_mask_*` columns are all `family %in% <list>` lookups that default to FALSE unless explicitly added — but `ci_no_x_*` and `postfit_ordination` would flip TRUE automatically and correctly. This still leaves the response-marshaling problem (N as a single scalar, not cbind) and the missing native R constructor (Q1) as separate, larger prerequisites that a families-list edit alone does not solve.

### live_test_sketch

Since R has no native zib() constructor (Q1), a "paired round-trip" test in the style of the lognormal live test (test-julia-bridge.R:4205-4229, which compares fit_j against fit_r = a native R fit) is NOT possible for zib — there is no native R fit to compare against, and the twin fence in the Julia lane explicitly says so: "no twin light Δ — the twin gllvmTMB has no ZIB, so a Δ would be invented" (src/bridge.jl:754; test_bridge_zib.jl:15-16 "Twin fence: gllvmTMB has NO ZIB, so there is no light RCall Δ to run and none may be invented. No parity, ADEMP, or coverage claim is made or tested here.").

The only test that can honestly be written today is a bridge-admission / plumbing test exercising the low-level `gllvm_julia_fit()` entry point directly with an explicit scalar N (bypassing the top-level gllvmTMB()+cbind() formula path entirely, since no native family object or response-marshaling exists yet), following the make_long/skip_if_no_julia conventions (test-julia-bridge.R:10-30):

```r
test_that(\"zib round-trips through gllvm_julia_fit (live, no native comparator)\", {\n  skip_if_no_julia()\n  set.seed(9401)\n  p <- 3L; n_unit <- 40L; Ntr <- 6L\n  # zero-inflated binomial draw, ONE shared scalar N (not cbind)\n  betaz <- 0.4 * rnorm(p) - 0.8\n  betac <- 0.25 * rnorm(p)\n  z <- rnorm(n_unit)\n  Y <- matrix(0L, nrow = p, ncol = n_unit)\n  for (t in seq_len(p)) for (s in seq_len(n_unit)) {\n    pi_zero <- plogis(betaz[t])\n    mu <- plogis(betac[t] + 0.3 * z[s])\n    Y[t, s] <- if (runif(1) < pi_zero) 0L else rbinom(1, Ntr, mu)\n  }\n  fit <- gllvm_julia_fit(\n    y = Y, family = \"zib\", num.lv = 1L, N = Ntr,\n    units_are_rows = FALSE, ci_method = \"wald\"\n  )\n  expect_identical(fit$family, \"zib\")\n  expect_identical(fit$trials, Ntr)\n  expect_true(is.finite(fit$loglik))\n  expect_true(all(is.na(fit$dispersion)))\n  expect_true(!is.null(fit$beta_zero))\n  expect_length(fit$beta_zero, p)\n  expect_identical(fit$ci_method, \"wald\")\n  # X / mask must still be rejected loudly at the boundary\n  expect_error(\n    gllvm_julia_fit(y = Y, family = \"zib\", num.lv = 1L, N = Ntr,\n                     X = array(rnorm(p * n_unit), c(p, n_unit, 1))),\n    class = \"error\"\n  )\n  expect_error(\n    gllvm_julia_fit(y = Y, family = \"zib\", num.lv = 1L,\n                     mask = matrix(TRUE, p, n_unit)),\n    \"requires an explicit trials\"  # N required before mask is even reached\n  )\n})\n```\n\nThis mirrors the repo's `skip_if_no_julia()` gate and asserts only what the Julia lane itself proves (finite loglik, correct trials echo, NaN dispersion, beta_zero present, CI populated, X/mask rejected) — it deliberately does NOT assert any tolerance against a native R fit, because none exists. If/when a native zib()/zero_inflated_binomial() constructor is added to R/families.R, a genuine paired round-trip (mirroring the lognormal test's `abs(logLik(fit_j) - logLik(fit_r)) < tol` pattern) becomes possible and should replace this plumbing-only test.

### risks

- Exposing "zib" is not additive to an existing feature the way lognormal was — there is no native R family to be consistent with (R/families.R has zero zero-inflated constructors of any kind: no zip, zinb, or zib). Any R-side spelling, alias set, or link default chosen now would be invented from scratch rather than mirrored from an existing native path, so R and Julia could silently diverge on convention (e.g. does N=1 mean Bernoulli-ZI or is it disallowed the way Julia disallows it? does zib() default to logit-only or accept probit/cloglog the way binomial() does? Julia's payload hard-codes LogitLink() only — src/bridge.jl:1443 `_bridge_link_name(LogitLink())` — with no alternate-link route, so an R constructor with a `link=` argument would be misleading unless restricted to logit.).
- The trials-N contract is a genuine parameterization trap: R's only existing binomial-trials marshaling mechanism is `.GLLVM_JULIA_BINOMIAL_FAMILIES` + cbind(successes,failures) two-column response detection (R/julia-bridge.R:3649-3689, 3826-3838), which is architecturally incompatible with ZIB's required single shared scalar N. If zib were carelessly added to `.GLLVM_JULIA_BINOMIAL_FAMILIES` to reuse the trials plumbing, it would build a per-observation N matrix from cbind() and pass it through — Julia's `_bridge_zib_trials` only accepts that IF every cell is equal, so a genuine varying-trials binomial-style call would either silently collapse (wrong) or throw at the Julia boundary with a confusing error, rather than R catching the mismatch with a clear R-level message.
- N=1 is a live footgun, not just an edge case: Julia's own docstring calls out that N=1 makes ZIB the zero-inflated Bernoulli, where the structural-zero intercept (beta_zero) and the success intercept (alpha) are exactly aliased on a flat likelihood ridge with no warning from the optimizer (src/bridge.jl:452-458, 588-593). If R ever defaults N or lets a user pass N=1 without comment, results would look converged (finite loglik, no error) but be numerically meaningless. R's gate must actively reject N=1 with an explicit identifiability message, not just require N to be supplied.
- "The engine can do X" is not evidence the bridge exposes X: fit_zib_gllvm_cov exists natively in GLLVM.jl and is FD-verified in test_zib_x_identity.jl, but bridge_fit deliberately excludes zib from `_BRIDGE_X_FAMILIES` pending a +X CI engine (src/bridge.jl:754). A scout or reviewer skimming only the Julia src/ (not bridge.jl's family lists) could wrongly conclude X is safe to marshal from R — it is not, today.
- The `dispersion` field returning all-NaN for zib (src/bridge.jl:1447) means any R-side code path that assumes `.gllvm_julia_public_dispersion_parameter()` always names a meaningful scalar (as it does for negbinomial/nb1/beta/gamma/lognormal) would either print "NA" under a fabricated label or, worse, silently apply the generic "dispersion" fallback naming to a field that is structurally NaN by design, not by missing data — this could read to a user as a fitting failure rather than an expected non-parameter.
- Communality/Sigma/correlation for zib are explicitly a "shared-block fallback" (ΛΛᵀ only, communality fixed at 1 for every trait) because ZIBFit has no link-residual extractor (src/bridge.jl note text, test line 136) — if R's `.gllvm_julia_public_dispersion`/normalise code or downstream summary()/print() methods apply the same latent-scale-vs-response-scale residual-diagonal adjustment they do for gaussian/lognormal (R/julia-bridge.R:1481, "gaussian_noop <- families %in% c('gaussian','lognormal')"), the resulting Sigma_y could be silently wrong for zib rows unless a `zib` line is added to whatever no-op/fallback family set governs that adjustment.
- No paired round-trip / oracle-of-truth test is possible against the R twin (twin gllvmTMB has no ZIB — Julia lane's own decision doc says inventing a ZIP/ZINB contrast as a substitute Δ is explicitly forbidden, src/bridge.jl:754 and test_bridge_zib.jl:15-16). Any claim of "parity" for zib would be unsupported by any evidence in either repo; exposure can only ever be framed as a Julia-only capability, not an R-Julia parity feature — the exposure PR's language must avoid the word "parity" the same way the Julia note field explicitly does (`@test !occursin("parity", lowercase(br.note))`, test_bridge_zib.jl:148).

## zinb

### r_family_constructors

NO native R constructor exists for "zinb" in this checkout. `grep -n "^[a-zA-Z_.]* <- function" R/families.R` enumerates every native family constructor (Beta, lognormal, gengamma, gamma_mix, lognormal_mix, truncated_poisson, student, tweedie, censored_poisson, delta_gamma(_mix), delta_gengamma, delta_lognormal(_mix), delta_poisson_link_gamma/lognormal, betabinomial, delta_beta, ordinal_probit, multinomial) plus nbinom2/nbinom1/nbinom2_mix (R/families.R:213-813, 280-349) - none is zero-inflated. A repo-wide grep (`grep -rln -i "zinb|zero.inflated.negative|zi_nbinom|zinbinom" --include="*.R" .`, plus src/ and man/ sweeps) is empty except two non-constructor hits: R/aghq-control.R:199 and the string "zero-inflated" appearing only in error-message prose in R/fit-multi.R:3665 ("Exact zeros need a hurdle/delta, zero-inflated, or count-family model"). The R/aghq-control.R:180-205 hit is inside `.aghq_start_index()`'s `high_curvature` character vector, matched by `grepl(pattern, family_label, fixed=TRUE)` against whatever family-label text happens to be present - a forward-looking AGHQ start-index heuristic, not evidence of an actual zinb constructor. That same vector also lists "hurdle_poisson"/"hurdle_nbinom2"/"hurdle_gaussian", and `grep -n "hurdle" R/families.R` returns nothing either - so this list names several families that do not exist in the package yet.

Consequence for the bridge: every family currently exposed through `.gllvm_julia_family_scalar` (R/julia-bridge.R:707-751, e.g. `lognormal = "lognormal"` at line 734) maps FROM an existing native `family()` object's `$family` string - a 1:1 native-constructor -> bridge-string convention. zinb has no native constructor to alias from, so that convention cannot be followed. Mechanically nothing blocks exposure anyway: `.gllvm_julia_family_scalar` computes `fam <- tolower(as.character(family))` and switches on it before any native-family validation, and for `engine = "julia"`, `family` is passed unvalidated straight into `.gllvmTMB_julia_dispatch()` (R/gllvmTMB.R:1207-1236) - native-family checks (`gllvmTMB_multi_fit`) only run on the `engine = "tmb"` branch. So a user would have to spell it as a bare string `family = "zinb"` (there is no `zinb()` to call), and the switch would need a new case, e.g. `zinb = "zinb"`, alongside plausible aliases the Julia side already accepts (`zinegbin`, `zero_inflated_negbin`, `zi_negbin`, `zinegativebinomial`, `zero_inflated_nbinom2` - src/bridge.jl:157-158). This is a genuine design gap, not a mechanical omission: exposing "zinb" would be the first bridge family with no native R analogue at all, and the maintainer needs to consciously decide whether a bare-string-only family belongs in `.GLLVM_JULIA_BRIDGE_FAMILIES` before anyone adds the case.

### julia_requirements

Traced the "zinb" route end-to-end in src/bridge.jl (checkout /private/tmp/GLLVM.jl-core070-aghq-20260830, branch codex/core070-aghq-20260830).

Family-key mapping (src/bridge.jl:157-158): "zinb" plus aliases zinegbin/zero_inflated_negbin/zi_negbin/zinegativebinomial/zero_inflated_nbinom2 all normalise to key "zinb".

No-X route (src/bridge.jl:1398-1420): `Yi = round.(Int, Yf)`; explicitly throws if a mask is supplied - "bridge_fit: missing-response masks are not wired for family=\"zinb\" yet" (line 1401) - so masks are hard-gated, not merely undocumented. Calls `fit_zinb_gllvm(Yi; K=K)` (a p x n Int response, no N/trials matrix - zinb is a plain count family, not binomial-style). Assembles via `_bridge_assemble(fit, "zinb", "zinb_rr", ...)` returning: `alpha` = count-part intercepts (fit.βc), `dispersion` = fill(fit.r, p) (ONE shared scalar r broadcast to every trait - not grouped/per-trait), `link` = fill("log", p) (count-part link is hardwired log; zero-part link is hardwired logit via `π = logistic(ηz)`, no alternative wired), `Sigma`/`corr`/`comm` built only from the shared block Λc*Λc' (Λz=0, so zero-inflation carries no latent-variable loading in this convention), plus an extra field `beta_zero = fit.βz` (structural-zero-logit intercepts) merged onto the base payload. `postfit_simulate` for zinb: NOT wired - `_BRIDGE_NO_SIMULATE_FAMILIES = ("zip","zinb","zib")` (line 572) because ZINBFit has a `residuals` extractor but no `simulate` method yet (comment at 559-570).

X (fixed-effect covariate) route (src/bridge.jl:1556-1559, 1700-1732): zinb IS in `_BRIDGE_X_FAMILIES` (line 202-203, alongside poisson/binomial/negbinomial/nb1/beta/gamma/betabinomial/ordinal/ordinal_probit/zip), so `bridge_fit(...; X=...)` is accepted for zinb; `X` is a p x n x q array (per-trait covariate design broadcast per site). Calls `fit_zinb_gllvm_cov(Yi; X=Xarr, K=K, γ_fixed=coef_fixed)`, returning a `ZINBCovFit` with SEPARATE zero/count coefficients: `βz,γz` (zero-part intercept + shared covariate slope) and `βc,γc` (count-part intercept + shared covariate slope), Λz still fixed at 0 (only Λc loads), and ONE shared scalar `r` (docs/dev-log/decisions/2026-08-13-zinb-x-identity.md, cited at src/families/twopart.jl:1461). `_bridge_assemble_zinb_cov` (src/bridge.jl:1701-1732) returns `beta_cov=βc, beta_zero=βz, gamma=γc, gamma_z=γz, gamma_c=γc`. CI under X uses a finite-difference Hessian (comment: \"Wald/profile/bootstrap CI under X are routed (finite-difference Hessian)\").

XLV (predictor-informed latent score): zinb is NOT in `_BRIDGE_XLV_FAMILIES` (line 196: only gaussian, poisson, negbinomial, gamma, beta, + the three binomial links) - `bridge_fit(...; X_lv=...)` throws for zinb.

Grouped/per-trait dispersion: zinb is NOT in `_BRIDGE_GROUPED_DISPERSION_FAMILIES` (line 546-547: negbinomial, nb1, beta, gamma, betabinomial only) - the returned dispersion is one scalar r broadcast identically to every trait, not a per-trait/grouped vector, unlike native-parity families such as negbinomial.

Trials/N (cbind-binomial marshalling): zinb is NOT in `_BRIDGE_TRIALS_FAMILIES` (line 193: binomial* + betabinomial only) - no N/trials matrix is read or required.

Does R dispatch currently marshal any of this? No. `.GLLVM_JULIA_X_FAMILIES` in R/julia-bridge.R:77-84 is `c("gaussian","poisson","binomial","negbinomial","beta","gamma")` - it does not even include every Julia-side `_BRIDGE_X_FAMILIES` member (nb1, betabinomial, ordinal, ordinal_probit, zip are already gated OUT on the R side despite Julia support), so R is already deliberately narrower than the Julia engine; zinb would need a brand-new entry, and today none of the R marshalling helpers (`.gllvm_julia_family_scalar`, `.GLLVM_JULIA_BRIDGE_FAMILIES`, `.GLLVM_JULIA_X_FAMILIES`, dispersion-label switch) mention zinb at all - everything must be added from scratch, there is nothing partially wired to extend.

### dispersion_public_parameter

R/julia-bridge.R:834-857 defines the native-facing dispersion transform/label. `.gllvm_julia_public_dispersion(family, values)`: for `family == "negbinomial"` returns `1/sqrt(values)`; for `"nb1"` returns `values` unchanged; for `"beta"`/`"gamma"` returns `1/sqrt(values)`; else passthrough. `.gllvm_julia_public_dispersion_parameter(family)`: `negbinomial -> "sigma"`, `nb1 -> "phi"`, `beta -> "sigma"`, `gamma -> "sigma"`, `lognormal -> "sigma"`, default `"dispersion"`.

There is no `zinb` case in either function today (falls through to the identity transform / `"dispersion"` label). Whether that default is RIGHT depends on the underlying parameterization: `fit.r` in ZINBFit/ZINBCovFit is the exact same NB2 size parameter as the "negbinomial" bridge route - `_tp_pieces(f::ZINB,...)` builds `NegativeBinomial(r, r/(r+μ))` (src/families/twopart.jl:1322-1325), i.e. Julia's `Distributions.NegativeBinomial(size, prob)` with `size=r`, identical to how the plain "negbinomial" bridge route parameterizes its count. So if the maintainer wants "sigma" to mean the same statistical quantity across every NB2-family exposed by this bridge, zinb's count dispersion should get the SAME transform as negbinomial: `1/sqrt(r)` labeled `"sigma"` - NOT the untransformed-passthrough default. But this is a bridge-invented convention, not a grep-confirmed native label: gllvmTMB has no native ZINB extractor/summary to check against (no native family exists at all - see r_family_constructors), so there is no ground-truth "how does native R call this" the way there is for negbinomial/nb1/beta/gamma/lognormal. The zero-inflation parameter (`beta_zero`, the structural-zero logit intercepts) has NO public-dispersion analogue in the existing switch at all - it is a wholly separate quantity (probability-of-structural-zero, not a variance/CV dispersion) and would need its own naming decision (e.g. a `zero_inflation` field), not folding into `dispersion_public_parameter`.

### capability_gating

Given the traced Julia route (see julia_requirements) and the "conservative fit-only exposure" precedent already visible in how R gates other families narrower than Julia supports:

MUST stay OUT (Julia does not support, or R already narrows other families the same way):
- `.GLLVM_JULIA_XLV_FAMILIES` (R/julia-bridge.R:85-92) - zinb is not in Julia's `_BRIDGE_XLV_FAMILIES` (src/bridge.jl:196); X_lv throws for zinb in Julia. Hard exclude.
- `.GLLVM_JULIA_MASK_FAMILIES` / mask-CI (R/julia-bridge.R:68-76, 103-106) - Julia explicitly throws "missing-response masks are not wired for family=\"zinb\" yet" (src/bridge.jl:1401). Hard exclude.
- `.GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES` and `.GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES` (R/julia-bridge.R:37-47) - zinb is not in Julia's `_BRIDGE_GROUPED_DISPERSION_FAMILIES` (src/bridge.jl:546); dispersion is one broadcast scalar r, not grouped/per-trait. Hard exclude.
- `.GLLVM_JULIA_SIMULATE_FAMILIES` (= `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES`, R/julia-bridge.R:52-60,66) - Julia's `_BRIDGE_NO_SIMULATE_FAMILIES` explicitly includes "zinb" (src/bridge.jl:572) because `ZINBFit`/`ZINBCovFit` have no `simulate` method. Note: on the Julia side `residuals`/`predict` ARE wired for zinb (it is only excluded from `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES`'s simulate subset, not the whole postfit set) - but R's own `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` bundles predict+residual+simulate as ONE list reused for all three (`.GLLVM_JULIA_RESIDUAL_FAMILIES <- .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES`, line 65), so R cannot currently turn on residuals/predict for zinb without also implying simulate unless that R-side list is first split apart (a bigger refactor than adding zinb alone) - until then the conservative move is to leave zinb out of this whole bundle, i.e. treat predict/residual/simulate as gated together for this family on the R side, consistent with the "conservative fit-only exposure" pattern already used for lognormal (R/julia-bridge.R:525: lognormal is explicitly kept OUT of `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` even though it has some Julia-side residual/predict wiring too - see `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES` including "lognormal", src/bridge.jl:565-566).
- `.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES` (R/julia-bridge.R:94-98) - only gaussian/poisson/binomial; zinb was never a candidate and Julia's `bridge_fit` explicitly forbids X/X_lv/mask for the mixed-family vector path regardless (src/bridge.jl:521-535). Exclude by default/no change needed.
- `.gllvm_julia_public_dispersion_parameter` - do NOT silently fall through to the untransformed default; either add an explicit (flagged-as-invented) case or leave `dispersion` unset/labelled clearly provisional until the maintainer signs off (see dispersion_public_parameter finding).
- Trials/`cbind_binomial` - zinb is not in `_BRIDGE_TRIALS_FAMILIES`; no R marshalling needed, none should be added.

Genuinely SAFE to include, evidenced by the Julia route actually supporting it AND matching an existing R-side pattern:
- `.GLLVM_JULIA_BRIDGE_FAMILIES` fit-only, no-X (R/julia-bridge.R:18-30) - Julia's no-X `fit_zinb_gllvm` route is complete, tested (test/test_zinb_x_identity.jl has an FD-verified gradient check and a bridge_fit no-X smoke test), and returns finite loglik/converged/iterations like every other one-part family. Safe to add IF the family-constructor gap (r_family_constructors) is accepted by the maintainer as a deliberate bare-string exposure.
- `.GLLVM_JULIA_CI_NO_X_FAMILIES` (R/julia-bridge.R:99-102, currently `setdiff(BRIDGE_FAMILIES, PERTRAIT_ORDINAL_FAMILIES)`) - Julia's `_BRIDGE_NO_CI_FAMILIES` does NOT include zinb (src/bridge.jl:552-557 lists only per-trait ordinal + lognormal + truncated_poisson), and `ci_no_x_wald/profile/bootstrap` all evaluate true for zinb in `bridge_capabilities()` (src/bridge.jl:713-716). Safe, evidenced.
- `.GLLVM_JULIA_X_FAMILIES` / `.GLLVM_JULIA_X_CI_FAMILIES` (R/julia-bridge.R:77-84,107) - zinb IS in Julia's `_BRIDGE_X_FAMILIES` and is NOT in `_BRIDGE_NO_CI_X_FAMILIES` (which is empty - src/bridge.jl:206, comment "ZIP+X and ZINB+X now route CI"); `ci_x_wald/profile/bootstrap` evaluate true for zinb. Safe to add for X fit + CI-under-X, evidenced by test/test_zinb_x_identity.jl's `bridge_fit(...; X=...)` smoke test and FD gradient check.
- `postfit_predict`/`postfit_coef`/`postfit_fit_stats`/`postfit_summary`/`postfit_ordination` on the Julia capability surface are all true for zinb (`predict_families = Set(onepart)` includes it, src/bridge.jl:701) - but per the SIMULATE_FAMILIES note above, R's bundled list structure means these can't be cleanly split out yet without a refactor; recommend keeping the WHOLE postfit bundle (predict/residual/simulate) gated OFF for zinb in this exposure slice, and revisiting once R's `.GLLVM_JULIA_RESIDUAL_FAMILIES`/`SIMULATE_FAMILIES` are decoupled from `PREDICT_FAMILIES`.

Net conservative recommendation: expose zinb for no-X fit + no-X CI (Wald/profile/bootstrap) + X fit + CI-under-X only. Leave X_lv, masks, grouped dispersion, cbind/trials, predict/residual/simulate, and mixed-family all gated OUT.

### live_test_sketch

Mirrors the lognormal live round-trip test (tests/testthat/test-julia-bridge.R:4205-4229) and the Julia-side no-X/X-with-covariate smoke pattern (test/test_zinb_x_identity.jl:135-155), but CANNOT do R-vs-Julia logLik parity like lognormal's test does, because there is no native R zinb() to fit against (see r_family_constructors) - this is the central difference from every other exposed family's test. The sketch below is therefore split into (a) a Julia-internal consistency check R can drive via JuliaCall directly (bridge_fit no-X vs bridge_fit X=0 agree, mirroring the Julia unit test), and (b) an engine="julia" round-trip smoke test that only checks the fit runs, converges, and returns finite loglik/dispersion - explicitly NOT a cross-engine equality assertion.

```r
test_that("zinb round-trips through engine = 'julia' (live, Julia-forward - no native R comparator)", {
  skip_if_no_julia()
  set.seed(4201)
  n_unit <- 60L
  p <- 3L
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  # Zero-inflated NB2 simulator matching Julia's mixture convention exactly
  # (structural zero w.p. pi=logistic(etaz), else NegativeBinomial(r, r/(r+mu))):
  # see src/families/twopart.jl:1314-1334 (`_tp_pieces(f::ZINB, ...)`).
  z <- rnorm(n_unit)[as.integer(df$unit)]
  lam <- c(0.5, -0.3, 0.2)[as.integer(df$trait)]
  betaz <- c(-0.5, -0.8, -0.3)[as.integer(df$trait)]  # structural-zero logits
  betac <- c(0.6, 0.4, 0.5)[as.integer(df$trait)]     # count-part log-mean intercepts
  r_true <- 6
  pi_true <- plogis(betaz)
  mu_true <- exp(betac + lam * z)
  is_struct_zero <- rbinom(nrow(df), 1, pi_true) == 1L
  df$value <- ifelse(
    is_struct_zero, 0L,
    rnbinom(nrow(df), size = r_true, mu = mu_true)
  )
  stopifnot(mean(df$value == 0) > 0.15)  # enough zeros for a zero-inflated fit to be identifiable

  fit_j <- gllvmTMB(
    value ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", trait = "trait",
    family = "zinb",  # bare string: no native zinb() constructor exists
    engine = "julia", ci_method = "none"
  )
  expect_s3_class(fit_j, "gllvmTMB_julia")
  expect_true(is.finite(logLik(fit_j)))
  expect_true(fit_j$converged)
  expect_true(all(fit_j$dispersion > 0))  # shared scalar r > 0, broadcast per trait
  expect_identical(fit_j$dispersion_public_parameter, "sigma")  # IF the negbinomial-matching label is adopted

  # No native-R comparator exists (gllvmTMB has no zinb()/hurdle_nbinom2() family) -
  # do NOT assert logLik(fit_j) against a `family("tmb")` fit the way lognormal's
  # test does; that comparator does not exist and must not be invented.
})

test_that("zinb X=0 bridge fit matches no-X bridge fit (Julia-internal identity, no R comparator)", {
  skip_if_no_julia()
  # Mirrors test/test_zinb_x_identity.jl's "zero-X fit_zinb_gllvm_cov ~ fit_zinb_gllvm"
  # testset via the same bridge_fit() entry point R calls.
  jl <- .gllvm_julia_env()  # however the bridge caches the JuliaCall session
  Y <- matrix(rpois(3 * 40, 2) * rbinom(3 * 40, 1, 0.6), nrow = 3)  # crude zero-inflated counts
  X0 <- array(0, dim = c(3, 40, 1))
  br0 <- .gllvm_julia_call("bridge_fit", y = Y, family = "zinb", d = 1)
  brx <- .gllvm_julia_call("bridge_fit", y = Y, family = "zinb", d = 1, X = X0)
  expect_equal(br0$loglik, brx$loglik, tolerance = 1e-2)
  expect_equal(br0$dispersion[1], brx$dispersion[1], tolerance = 1e-2)
})

test_that("zinb stays gated for X_lv, masks, and grouped dispersion on engine = 'julia'", {
  expect_false("zinb" %in% .GLLVM_JULIA_XLV_FAMILIES)
  expect_false("zinb" %in% .GLLVM_JULIA_MASK_FAMILIES)
  expect_false("zinb" %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES)
  expect_false("zinb" %in% .GLLVM_JULIA_SIMULATE_FAMILIES)
})
```

### risks

- No native R family exists to alias from (see r_family_constructors) - zinb would be the first bridge family exposed as a bare string with no native family() constructor, breaking the established 1:1 convention every other exposed family follows; this is a maintainer design decision, not a mechanical port, and should not be added silently inside a routine bridge-expansion PR.
- No R-vs-Julia parity is possible at all - `docs/dev-log/...` and the Julia bridge notes say explicitly "no twin light RCall Δ (twin ZINB cut)" (src/bridge.jl:751-752, 1730) because gllvmTMB literally has no ZINB to compare against. Every other exposed family's live test (e.g. lognormal, tests/testthat/test-julia-bridge.R:4205-4229) asserts logLik(engine='julia') ≈ logLik(engine='tmb') to 1e-4; that assertion is structurally impossible for zinb and must not be faked or approximated with an unrelated family.
- Mixture vs. hurdle confusion - the Julia ZINB is explicitly a MIXTURE (structural zero OR count-process zero; the comment in src/families/twopart.jl:1028-1039 stresses "Unlike the hurdle families the count process is active at every observation"). gllvmTMB's existing delta_* families are hurdle/two-part-with-exact-zero-point-mass models (R/families.R:419-566, R/fit-multi.R:3691-3699 "Delta families: response must be non-negative... exact zero point mass"). If zinb's docs/vignettes don't sharply distinguish mixture from the delta/hurdle convention already familiar to gllvmTMB users, downstream users are likely to misinterpret the structural-zero probability the same way they'd read a delta-family zero-mass parameter, which is a materially different statistical object.
- Dispersion label has no ground truth to validate against - `.gllvm_julia_public_dispersion_parameter` has no zinb case; adopting the negbinomial convention (1/sqrt(r), labelled "sigma") is a reasonable INFERENCE from matching the same NegativeBinomial(r, r/(r+mu)) parameterization (verified at src/families/twopart.jl:1322-1325), not a confirmed native label, since no native zinb summary/extractor exists anywhere in the repo to check it against.
- Zero-inflation parameter (beta_zero) has no place in the existing payload-normalisation machinery at all - `.gllvm_julia_normalise_result` (R/julia-bridge.R:859+) names/dimnames alpha, communality, beta_cov, loadings, etc., but was never extended for a `beta_zero` field; shipping zinb without adding that normalisation path would leave the structural-zero intercepts as a raw unnamed vector, unlike every other exported quantity.
- Count-part link is hardcoded to log and zero-part link to logit with no alternative wired in Julia (`link = fill("log", p)` at src/bridge.jl:1414; `π = logistic(ηz)` hardcoded in `_tp_pieces` at src/families/twopart.jl:1318) - if any future R-side family() constructor for zinb offers a `link`/`link_z` argument, it must error loudly rather than silently accept and ignore a non-default link, mirroring how other bridge families gate unsupported links today (e.g. the binomial link gate at R/julia-bridge.R:690-702).
- Missing-response masks are hard-unsupported (explicit Julia-side throw, src/bridge.jl:1401) - any R-side exposure must propagate that as a loud error for NA-containing responses under family="zinb", not a silent listwise drop.
- R's postfit capability lists (`.GLLVM_JULIA_RESIDUAL_FAMILIES`/`SIMULATE_FAMILIES` both aliased to `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES`, R/julia-bridge.R:65-66) are coarser than Julia's actual per-capability granularity (Julia gives zinb residuals+predict but not simulate); naively adding zinb to that one shared R list to get residuals would incorrectly also advertise simulate, which Julia does not support for this family.

## betabinomial

### r_family_constructors

Native constructor: betabinomial(link = "logit") at R/families.R:578-589. It validates the link against c("logit","cloglog") (line 579-585) and builds .gllvm_family("betabinomial", link_name, link_name, c("logit","cloglog")) - so the CONSTRUCTOR nominally admits two links. But R's own TMB fit path hard-errors on cloglog: R/fit-multi.R:1210-1211 `if (fid == 8L && !identical(f$link, "logit")) cli::cli_abort("betabinomial: only the logit link is currently supported.")`. So native gllvmTMB (engine="tmb") is de facto logit-only for betabinomial today, which matches Julia's hardcoded-logit fit_beta_binomial_gllvm_grouped(...; link::Link = LogitLink()) (src/families/beta_binomial.jl:510) - the bridge never overrides this default (bridge.jl:1336 and :1538 call the fitter without a `link` kwarg).

`.gllvm_julia_family_scalar()` (R/julia-bridge.R:685-752) needs a new switch arm, e.g. `betabinomial = "betabinomial"`, alongside the existing beta/gamma/lognormal/ordinal arms (~line 732-736). Because betabinomial is NOT special-cased the way `binomial` is (binomial's link is switched explicitly at lines 686-704: logit/probit/cloglog -> "binomial"/"binomial_probit"/"binomial_cloglog"), a bare `betabinomial = "betabinomial"` arm would silently DROP the link and accept betabinomial(link="cloglog") too, routing it into Julia's always-logit fitter with no error. This needs its own explicit link guard before the switch (error unless link=="logit"), not a plain string match. gllvmTMB's error message list at fit-multi.R:1170 and methods-gllvmTMB.R:1626 both already advertise betabinomial() to users, so this is a real reachable path, not a hypothetical.

### julia_requirements

Traced in src/bridge.jl (checkout /private/tmp/GLLVM.jl-core070-aghq-20260830):

- Family key: `_bridge_family_key` maps "betabinomial"|"beta_binomial"|"beta.binomial" -> "betabinomial" (line 153); listed in `_BRIDGE_ONEPART_FAMILIES` (179).
- Trials N is REQUIRED conceptually: betabinomial is in `_BRIDGE_TRIALS_FAMILIES = (_BRIDGE_BINOMIAL_FAMILIES..., "betabinomial")` (line 193) - it reads the same p x n integer N matrix as binomial (R's cbind(success,failure) shape). If N is omitted the no-X route defaults `Ni = fill(1, p, n)` (line 1334) i.e. silently fits a degenerate N=1 "beta-Bernoulli" - not caught as an error in Julia.
- No-X route (line 1332-1346): `fit_beta_binomial_gllvm_grouped(Yi; K, N=Ni, group=collect(1:p), mask=M)` - `group=collect(1:p)` means dispersion phi is estimated PER-SPECIES (not shared across all traits, unlike Gamma's no-X route which uses `group=fill(1,p)`). Confirmed by test/test_bridge_grouped_dispersion.jl:87 `br.dispersion_group_id == collect(1:p)`.
- X route (grouped_cov, line 1536-1542): `fit_beta_binomial_gllvm_grouped_cov(Yi; X=Xarr, K, N=Nm, group=collect(1:p), γ_fixed=coef_fixed)` - fully supported and tested (test/test_bridge_x.jl:155-183, live-fitted against an oracle to 1e-8; also a Wald-CI variant at :379-420). Requires the p x n x q `X` array plus `N`.
- Mask (missing response): betabinomial is in `_BRIDGE_MASK_FAMILIES` (bridge.jl:541-544) and `_BRIDGE_MASK_CI_FAMILIES` (549-552) - both no-X point fit and no-X masked CI are wired and tested (test/test_bridge_capabilities.jl:228-235: missing_response, ci_mask_wald/profile/bootstrap all TRUE for betabinomial).
- Dispersion returned: `fit.φ` (phi), one value per group (per-species when no-X since group=collect(1:p); per-group when X supplied). `_bridge_dispersion_payload(fit.φ, fit.group, "phi", "Var = N*mu*(1-mu)*(1+(N-1)*phi/(phi+1))", "gllvm Beta precision phi = a+b (twin log_phi_betabinom); direct passthrough")` (line 1337-1339) - the raw bridge label for this field is the string "phi" (confirmed live: test/test_bridge_grouped_dispersion.jl:86 `br.dispersion_parameter == "phi"`).
- X_lv (predictor-informed latent score): betabinomial is NOT in `_BRIDGE_XLV_FAMILIES` (line 196: gaussian, poisson, negbinomial, gamma, beta, binomial*) - not supported at all in Julia for this family.
- Postfit scalar-mean extractors: betabinomial is explicitly in `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES` (566-567) - no `residuals`/`simulate` method exists for BetaBinomialFit or its grouped/grouped_cov siblings. `postfit_predict`/`postfit_ordination`/coef/fit_stats/summary DO work generically (getLV/getLoadings apply to every fit type).
- CI: NOT in `_BRIDGE_NO_CI_FAMILIES` (558-559, which lists only per-trait-ordinal + lognormal + truncated_poisson), so Wald/profile/bootstrap ARE routed for betabinomial, both no-X and X (grouped_cov), via `_family_ci` using a finite-difference Hessian (comment at bridge.jl:556-557; confirmed live in test/test_bridge_grouped_dispersion.jl:89-98 and test/test_bridge_x.jl:379-420).

Does R currently marshal these pieces? NO for the two load-bearing pieces (N and the two-column response), and NO for X/masks:
- R's cbind(successes,failures) -> Y+N parsing is hard-gated to `.GLLVM_JULIA_BINOMIAL_FAMILIES` only: R/julia-bridge.R:3650-3667 `if (!any(fam_str %in% .GLLVM_JULIA_BINOMIAL_FAMILIES)) stop(...)`. betabinomial is NOT in that set, so a two-column response with family=betabinomial currently hard-errors with GJL-GATE-FAMILY before reaching the bridge at all.
- The `Narg` (trials matrix) construction is likewise gated to `.GLLVM_JULIA_BINOMIAL_FAMILIES` (R/julia-bridge.R:3826-3841) - betabinomial gets `Narg <- NULL` today, i.e. no trials are ever passed even if the cbind gate were bypassed.
- `.GLLVM_JULIA_X_FAMILIES` (julia-bridge.R:77-84) and `.GLLVM_JULIA_MASK_FAMILIES` (68-76) both omit betabinomial (and also omit nb1, despite nb1's Julia X/mask routes being equally supported and tested - this is the repo's established precedent: Julia-side support does not by itself earn R-side exposure; each family's R marshaling is added and evidenced separately).

So: exposing betabinomial through the R bridge requires NEW R-side plumbing, not just a family-string switch entry - specifically extending the cbind/N marshaling gates (currently keyed on `.GLLVM_JULIA_BINOMIAL_FAMILIES`) to also admit betabinomial, ideally via a new shared constant (e.g. `.GLLVM_JULIA_TRIALS_FAMILIES <- c(.GLLVM_JULIA_BINOMIAL_FAMILIES, "betabinomial")`) used at both gate sites, since without N marshaling the family is unusable (defaults to a meaningless N=1 fit). X and masks can be deferred as a later, separately-evidenced PR (following the nb1 precedent).

### dispersion_public_parameter

The native TMB engine's public/report name for this parameter is `phi_betabinom`, not plain "phi":
- Internal TMB parameter: `log_phi_betabinom` (R/fit-multi.R:5524, :6349; R/init-warmstart.R:70,106,125; R/va-r3-proto.R:1322,2158,2263).
- Report field pulled by user-facing methods: `fit$report$phi_betabinom` at R/methods-gllvmTMB.R:1571 (used inside predict/simulate machinery) and R/predictive-diagnostics.R:377; R/extract-sigma.R:252 `phi_vec <- as.numeric(fit$report$phi_betabinom %||% ...)`; R/family-cdf-args.R:178-185 documents it explicitly: "phi_betabinom is the Beta-mixing precision: a = mu*phi, b = (1-mu)*phi".
- Documented publicly in the family table at R/gllvmTMB.R:396: `| betabinomial (\`phi_betabinom\`) | precision of the Beta mixing | ... |`.
- Profile-CI labels use it too: R/profile-targets.R:194-195 `tmb_parameter = "log_phi_betabinom", label_prefix = "phi_betabinom"`.

So `.gllvm_julia_public_dispersion_parameter()` (R/julia-bridge.R:847-857), which currently switches negbinomial="sigma", nb1="phi", beta="sigma", gamma="sigma", lognormal="sigma", default="dispersion", needs a `betabinomial = "phi_betabinom"` arm to match native naming - NOT plain "phi" (Julia's raw bridge field name) and NOT the generic "dispersion" fallback. This mirrors the beta/gamma precedent: Julia's raw label there is also "phi"/"alpha" but R renames it to the native-facing "sigma" - the mapper's job is native-parity naming, independent of Julia's internal label.

### capability_gating

Conservative fit-only exposure - the minimal safe PR, mirroring the nb1/lognormal precedent (Julia support alone does not earn R exposure; each capability is evidenced and wired independently):

STAY OUT initially (even though several are Julia-ready):
- `.GLLVM_JULIA_X_FAMILIES` / `ci_x_*` - Julia's grouped_cov route is tested (test_bridge_x.jl:155-183, :379-420), but R has zero X-marshaling test coverage for betabinomial specifically; follow the nb1 precedent (Julia-ready, R-gated) rather than adding it in the same PR as the base family.
- `.GLLVM_JULIA_XLV_FAMILIES` - genuinely unsupported in Julia too (`_BRIDGE_XLV_FAMILIES` excludes betabinomial); must stay out regardless.
- `.GLLVM_JULIA_MASK_FAMILIES` / `ci_mask_*` - Julia-ready and tested, but needs a new `.gllvm_julia_mask_placeholder()` entry (e.g. `betabinomial = 0`, matching binomial's placeholder) plus its own R test before inclusion; defer with X to the same follow-up PR.
- `.GLLVM_JULIA_SCORE_POSTFIT_FAMILIES` (-> residuals/simulate) - genuinely unsupported: Julia's `_BRIDGE_NO_SCALAR_POSTFIT_FAMILIES` explicitly includes betabinomial (no residuals/simulate method exists for BetaBinomialFit). Must stay out; this is a hard Julia-side gap, not just an R conservatism choice.
- `.GLLVM_JULIA_MIXED_COMPONENT_FAMILIES` - betabinomial is not (and should not be) in the mixed-family list; Julia's mixed-family fitter doesn't support it (bridge.jl only routes gaussian/poisson/binomial there per the mixed dispatch).

Genuinely SAFE to include, with evidence:
- `.GLLVM_JULIA_BRIDGE_FAMILIES` / `fit_no_x` - safe once the link guard (logit-only) and the cbind/N marshaling extension (see julia_requirements) both land; both sides are tested (Julia: test_bridge_grouped_dispersion.jl:80-99; needs paired R test).
- `cbind_binomial`-equivalent trials support is NOT optional - without it the family is meaningless (defaults to N=1), so it must ship in the SAME PR as the base family, not deferred. This differs from the nb1/X precedent: X is a genuine "later" capability, but trials-N is load-bearing for betabinomial's very identity.
- `ci_no_x_wald` / `ci_no_x_profile` / `ci_no_x_bootstrap` - safe to include. Julia's no-X CI route is tested end-to-end (test_bridge_grouped_dispersion.jl:89-98) and betabinomial is explicitly NOT in Julia's `_BRIDGE_NO_CI_FAMILIES`. R's `.GLLVM_JULIA_CI_NO_X_FAMILIES` is `setdiff(.GLLVM_JULIA_BRIDGE_FAMILIES, .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES)` (line 99-102) so this comes for free once betabinomial joins BRIDGE_FAMILIES and is not ordinal - no extra gating code needed, but SHOULD be paired with an explicit R live test before being claimed as "evidenced" rather than merely "not accidentally excluded" (note: this auto-inclusion mechanism already grants ci_no_x_* to lognormal today even though lognormal has no Julia CI adapter - `_BRIDGE_NO_CI_FAMILIES` includes "lognormal" - so this is a pre-existing gap in the R capability table's precision, not something betabinomial introduces; worth flagging to the maintainer but out of this scout's scope to fix).
- `postfit_coef` / `postfit_fit_stats` / `postfit_summary` / `postfit_ordination` / `postfit_predict` - safe, generic across every family (getLoadings/getLV apply universally; predict via cutpoints doesn't apply here but the flat alpha/dispersion/link-based predict path does).
- `postfit_residuals` / `postfit_simulate` - must stay OUT; this is a genuine Julia-side capability gap (no extractor exists), not an R conservatism choice.

### live_test_sketch

Mirroring the lognormal live round-trip at tests/testthat/test-julia-bridge.R:4205-4230, using cbind(success, failure) syntax (the native gllvmTMB binomial-family convention) with a fixed trial size so the beta-binomial's extra-binomial dispersion is identifiable:

```r
test_that("betabinomial round-trips through engine = 'julia' (live)", {
  skip_if_no_julia()
  set.seed(109)
  n_unit <- 60L
  n_trait <- 3L
  trials <- 8L  # fixed N per cell; must be >1 so BB dispersion is identifiable
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = factor(paste0("t", seq_len(n_trait))),
    KEEP.OUT.ATTRS = FALSE
  )
  lam <- c(0.5, -0.3, 0.4)[as.integer(df$trait)]
  z <- rnorm(n_unit)[as.integer(df$unit)]
  eta <- 0.1 + lam * z
  phi <- 9  # Beta-mixing precision (a = mu*phi, b = (1-mu)*phi)
  mu <- plogis(eta)
  a <- mu * phi; b <- (1 - mu) * phi
  pr <- rbeta(nrow(df), a, b)
  df$succ <- rbinom(nrow(df), size = trials, prob = pr)
  df$fail <- trials - df$succ

  fit_j <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", trait = "trait",
    family = betabinomial(), engine = "julia", ci_method = "none"
  )
  fit_r <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE),
    data = df, unit = "unit", trait = "trait",
    family = betabinomial()
  )
  expect_s3_class(fit_j, "gllvmTMB_julia")
  expect_true(is.finite(logLik(fit_j)))
  expect_lt(abs(as.numeric(logLik(fit_j)) - as.numeric(logLik(fit_r))), 1e-4)

  # link-guard: cloglog must NOT silently route to Julia's logit-only fitter
  expect_error(
    gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE),
      data = df, unit = "unit", trait = "trait",
      family = betabinomial(link = "cloglog"), engine = "julia"
    ),
    "logit"
  )
})
```

Notes: trials must be > 1 (Bernoulli-degenerate N=1 aliases the BB precision, same aliasing problem the Julia bridge documents for ZIB at bridge.jl:585-593); `d = 1` (one latent factor) keeps this a smoke-level parity check, matching the lognormal test's scale. Add a second `skip_if_no_julia()` block for the grouped_cov (X) case only once R's X-marshaling for betabinomial lands (out of scope for this first PR per capability_gating above).

### risks

- Link mismatch (silent wrong answer, not just incomplete): betabinomial(link="cloglog") is a VALID native R call (R/families.R:579-585 admits logit and cloglog) but the Julia route is hardcoded to LogitLink() with no override plumbed through the bridge. If `.gllvm_julia_family_scalar()` gets only a bare `betabinomial = "betabinomial"` switch arm (i.e. it is NOT special-cased like `binomial` is at lines 686-704), a cloglog request would silently be fit as logit with no error - a materially different model, not a rounding difference. Must add an explicit link guard before/inside the switch that errors on anything but "logit" (matching the fact that even engine="tmb" itself currently only supports logit for this family per fit-multi.R:1210-1211, so this restriction is at least consistent with current R behavior, just not currently enforced pre-dispatch for engine="julia").
- Trials-N omission defaults to a degenerate model, not an error: both Julia (`Ni = N === nothing ? fill(1,p,n) : ...`, bridge.jl:1334) and, if the cbind gate is naively widened without also widening the Narg-construction gate (both currently keyed on `.GLLVM_JULIA_BINOMIAL_FAMILIES`, julia-bridge.R:3651 and :3829), R would silently fit N=1 beta-binomial - a beta-Bernoulli where the extra-binomial dispersion parameter is only weakly identified from Bernoulli-scale data, giving a plausible-looking but scientifically meaningless fit with no warning. Both gate sites must be updated together, not just one.
- Dispersion label drift if the public-name mapper is skipped: if `.gllvm_julia_public_dispersion_parameter()` (julia-bridge.R:847-857) is left un-updated, betabinomial falls through to the generic "dispersion" fallback while every other exposed non-Gaussian family (nb1, beta, gamma, negbinomial, lognormal) gets a family-specific native-parity name. Since the native TMB engine's public name is specifically `phi_betabinom` (not "phi", not "dispersion", not "sigma") a comparison/report table joining engine="tmb" and engine="julia" fits side-by-side would show a name mismatch for this one family, even though the underlying quantity is numerically the same Beta-mixing precision (bridge.jl:1339 documents it as "direct passthrough" of the twin log_phi_betabinom).
- Mask placeholder omission: if response masks are ever wired for betabinomial without adding a `betabinomial = 0` entry to `.gllvm_julia_mask_placeholder()` (julia-bridge.R:1139-1158), the fill call throws a clear R-level stop() rather than silently mis-filling - low risk, but flag it as a required companion edit if/when masks are added.
- Per-species vs shared dispersion convention: the no-X Julia route uses `group = collect(1:p)` (bridge.jl:1336), i.e. ONE phi per species/trait, unlike Gamma's no-X route which shares one alpha across all traits (`group = fill(1,p)`, bridge.jl:1321). If R's marshaling or documentation assumes a single shared betabinomial dispersion (by analogy to Gamma), the returned `dispersion_group_id` shape (length p, not length 1) would surprise downstream code. Confirm this per-species convention against gllvmTMB's own native default (native TMB's `phi_betabinom` report field is also per-trait per R/methods-gllvmTMB.R:1571, so this is consistent - but it must be checked explicitly rather than assumed).

## zip

### r_family_constructors

NO native R constructor for "zip" exists in this repo. R/families.R (827 lines; grep for function definitions) has no zip/zeroinfl/zero_inflated_poisson/ziP constructor, and grep -rln "inflat" R/ finds zero real hits (only unrelated prose about statistical "inflation" in diagnose.R, loading-ci-bootstrap.R, unique-keyword.R). The only occurrences of the literal string "zip" anywhere in R/ are: (1) R/aghq-control.R:199, inside .aghq_start_index()'s high_curvature vector, a grepl()-matched label used only to tune AGHQ quadrature start-index heuristics, alongside other never-implemented labels ("hurdle_poisson", "hurdle_nbinom2", "hurdle_gaussian", "delta_gamma", "delta_lognormal", "zinb"); and (2) R/fit-multi.R:3647-3665, generic error-hint prose ("zero-inflated" mentioned as a hypothetical model class) with no functional family behind it. src/gllvmTMB.cpp (the compiled TMB template) also has zero matches for zip/zero_inflated/zeroinfl. So there is no native family object or alias to grep from the way lognormal(link="log") (R/families.R:221) backed the lognormal exposure -- the "twin fence": gllvmTMB (the R twin) has deliberately never implemented ZIP; the Julia test suite says so explicitly (test/test_bridge_zip_nox.jl:10-11, "the twin gllvmTMB cut ZIP, so there is no light RCall Delta to run and none may be invented"). A user can only spell this family as a bare character string: family = "zip" (or an alias) reaches .gllvmTMB_julia_dispatch() unvalidated, because engine = "julia" (R/gllvmTMB.R:1212) branches to the bridge before any native-family object check runs; only engine="tmb" would ever need a real family() object. Recommended switch entries for .gllvm_julia_family_scalar() (R/julia-bridge.R:685-751), mirroring Julia's own aliases at src/bridge.jl:156 ("zip","zipoisson","zero_inflated_poisson","zi_poisson" all -> "zip"): add zip = "zip", zipoisson = "zip", zero_inflated_poisson = "zip", zi_poisson = "zip" to the switch (fam is already tolower()'d at R/julia-bridge.R:707, so case-insensitivity is free). No R link argument applies -- Julia's ZIP count part is fixed to a log link and the structural-zero part to logit (src/bridge.jl:1387-1391, "log" hardcoded), so there is no native link choice to preserve or reject.

### julia_requirements

Traced in src/bridge.jl. Payload input: Y only (rounded to Int inside the route, src/bridge.jl:1368 "Yi = round.(Int, Yf)"); no trials/N matrix is read or required (zip is absent from _BRIDGE_TRIALS_FAMILIES, src/bridge.jl:193, so cbind_binomial is false for it in bridge_capabilities). No explicit "zero-inflation structure" or truncation option is read from `options` at all -- the model is a fixed two-part structure baked into fit_zip_gllvm: shared-block loadings Lambda_c on the count linear predictor, Lambda_z = 0 on the structural-zero part (no latent loading on the zero-inflation logit), confirmed by the note text at src/bridge.jl:749-750 ("structural-zero logits beta_zero, count intercepts alpha=beta_c, Lambda_z=0"). Dispersion: NONE -- the no-X route returns dispersion = fill(NaN, p) (src/bridge.jl:1382) and public dispersion_parameter machinery is simply not exercised (all-NaN dispersion is dropped by R's own .gllvm_julia_coef_payload "any(is.finite(...))" guard at R/julia-bridge.R:1210, so this is naturally safe). Instead the payload carries a genuinely NEW two-part field shape absent from every other admitted family: beta_zero (structural-zero logits per trait, src/bridge.jl:1394), and for the X route also gamma_z/gamma_c/gamma (separate slopes for the zero and count linear predictors, src/bridge.jl:1695-1696) alongside beta_cov/alpha for the count intercepts. R's current generic .gllvm_julia_coef_payload() (R/julia-bridge.R:1187-1223ish) only knows to copy alpha/mean_coef/beta_cov/gamma/gamma_status/loadings/dispersion/dispersion_group/cutpoints -- it has NO awareness of beta_zero, gamma_z, or gamma_c, so those fields would currently be silently dropped rather than exposed; new extraction/labeling code is required, not just a family-list flip. X (fixed-effect covariates): SUPPORTED on the Julia side via fit_zip_gllvm_cov (src/bridge.jl:1551-1554, dispatched inside _bridge_fit_onepart_cov because "zip" is in _BRIDGE_X_FAMILIES, src/bridge.jl:202-203), with Wald/profile/bootstrap CI under X via a finite-difference Hessian (test/test_bridge_x.jl:219-249 point-fit oracle match to 1e-8, :409-434 Wald CI oracle match to <1e-8). But R currently marshals X only for families already listed in .GLLVM_JULIA_X_FAMILIES (R/julia-bridge.R:77-83, gate GJL-GATE-X-FAMILY at R/julia-bridge.R:3743-3748) -- zip is not in that list today, so X is gated off pending the new payload-label work above, even though the Julia route itself is proven. Grouped dispersion: NOT APPLICABLE (zip has no dispersion parameter to group; it is absent from _BRIDGE_GROUPED_DISPERSION_FAMILIES, src/bridge.jl:546-547). Masks: EXPLICITLY UNSUPPORTED and loud about it -- both the no-X route (src/bridge.jl:1369-1370, "M === nothing || throw(ArgumentError(...missing-response masks are not wired for family=\"zip\" yet...))") and bridge_capabilities (zip absent from _BRIDGE_MASK_FAMILIES, src/bridge.jl:541-544) agree; test/test_bridge_zip_nox.jl:115-119 pins that a mask throws ArgumentError. R's mask marshaling (.gllvm_julia_fill_masked_response, R/julia-bridge.R:1161-1185) is already gated per-family via .GLLVM_JULIA_MASK_FAMILIES, so this needs zero new R work -- just do not add zip to that list. X_lv (predictor-informed latent score): NOT supported -- zip is absent from _BRIDGE_XLV_FAMILIES (src/bridge.jl:196, which lists gaussian/poisson/negbinomial/gamma/beta/binomial-family only); must stay out of .GLLVM_JULIA_XLV_FAMILIES. Predict/residuals/simulate (postfit): Julia's bridge_capabilities computes postfit_predict=true and postfit_residuals=true for zip (it is absent from both _BRIDGE_NO_SCALAR_POSTFIT_FAMILIES, src/bridge.jl:566-567, and predict_families = all onepart, src/bridge.jl:703) but postfit_simulate=false (zip IS in _BRIDGE_NO_SIMULATE_FAMILIES, src/bridge.jl:572, "the three zero-inflated fit types...have a residuals method but no simulate method on this engine"). R's SCORE_POSTFIT_FAMILIES list (R/julia-bridge.R:53-60) is a single undifferentiated list that gates predict, residual, AND simulate together (.GLLVM_JULIA_PREDICT_FAMILIES/.RESIDUAL_FAMILIES/.SIMULATE_FAMILIES all derive from it, R/julia-bridge.R:62-65) -- there is no existing R mechanism to grant predict+residuals while withholding simulate for one family, so this Julia/R capability-granularity mismatch is itself a reason to keep zip out of that list entirely for a conservative first exposure, not just an incidental gap.

### dispersion_public_parameter

Cannot be answered by grepping native R summary/extractor code because none exists -- there is no summary()/coef() precedent for a zero-inflation logit or two-part coefficient anywhere in this R lane (confirmed by the R/families.R and R/fit-multi.R searches above). .gllvm_julia_public_dispersion_parameter() (R/julia-bridge.R:847-857) has entries only for negbinomial="sigma", nb1="phi", beta="sigma", gamma="sigma", lognormal="sigma", with a bare "dispersion" fallback for everything else. Since zip carries no dispersion scalar at all (Julia returns dispersion = fill(NaN, p) on both the no-X and X routes, src/bridge.jl:1382 and 1685), the existing fallback default ("dispersion") is harmless and technically sufficient -- it will never actually surface because R's own .gllvm_julia_coef_payload "any(is.finite(dispersion))" guard (R/julia-bridge.R:1210) drops all-NaN dispersion from the payload before any label is used. No new switch entry is strictly required for correctness. What DOES need a new, currently-nonexistent public label is the structural-zero logit (beta_zero) and, under X, the split gamma_z/gamma_c slopes -- there is no gllvmTMB naming convention to mirror for these (the field-standard R convention from pscl::zeroinfl/VGAM is "zero_"/"count_" coefficient prefixes, but that is an external-ecosystem convention I am recommending by analogy, not something grounded in this repo's own code -- flag this to the maintainer as a naming decision to make explicitly, not something this scout found already decided).

### capability_gating

Conservative fit-only (no-X) recommendation, evidenced against the actual Julia route: (1) ADD "zip" to .GLLVM_JULIA_BRIDGE_FAMILIES (R/julia-bridge.R:18-30) with new switch entries in .gllvm_julia_family_scalar (as above) -- this is the minimum needed for family mapping/gate text (GJL-GATE-FAMILY) to work at all. (2) KEEP OUT of .GLLVM_JULIA_X_FAMILIES (R/julia-bridge.R:77-83) and .GLLVM_JULIA_XLV_FAMILIES (R/julia-bridge.R:88-93, XLV correctly gated: zip absent from _BRIDGE_XLV_FAMILIES on the Julia side too, src/bridge.jl:196) -- even though Julia's fit_zip_gllvm_cov + CI is proven (test/test_bridge_x.jl:219-249, 409-434), R's generic coef-payload extractor does not yet know how to label beta_zero/gamma_z/gamma_c, so admitting X now would either silently drop those fields or expose an unlabeled/undocumented shape. (3) KEEP OUT of .GLLVM_JULIA_MASK_FAMILIES (R/julia-bridge.R:68-76) -- correctly matches the Julia side, which throws ArgumentError on any mask for zip (src/bridge.jl:1369-1370, pinned by test/test_bridge_zip_nox.jl:115-119). (4) KEEP OUT of .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES and .GLLVM_JULIA_PERTRAIT_GROUPED_DISPERSION_FAMILIES (R/julia-bridge.R:32-47) -- zip has no dispersion parameter to group; not applicable, not merely gated. (5) KEEP OUT of .GLLVM_JULIA_SCORE_POSTFIT_FAMILIES (R/julia-bridge.R:53-60), which drives .GLLVM_JULIA_PREDICT_FAMILIES/.RESIDUAL_FAMILIES/.SIMULATE_FAMILIES together -- Julia grants predict+residuals but explicitly withholds simulate for zip (src/bridge.jl:572), and R's list cannot express that split without new code, so admitting predict/residual/simulate now would either wrongly claim simulate works or need a bespoke carve-out; safer to gate the whole trio off for this first slice. (6) KEEP OUT of ci_no_x_* / .GLLVM_JULIA_CI_NO_X_FAMILIES-equivalent scoping too, UNLESS the maintainer explicitly wants no-X Wald/profile/bootstrap CI in this same slice -- Julia's no-X CI route for zip is well-evidenced (test/test_bridge_zip_nox.jl:95-113, Wald max|Delta| <= 1e-8 vs native confint) and R's CI dispatch is generically family-list-gated the same way X is, so this is the one place where genuinely safe inclusion beyond bare admission is defensible if the maintainer wants it -- but note it still needs the beta_zero label decision from Q3 resolved first, since CI output will carry named parameters for the zero-inflation logit that the R summary layer does not yet know how to present. (7) SAFE TO INCLUDE, evidenced: .GLLVM_JULIA_ORDINATION_FAMILIES (R/julia-bridge.R:66-67) is defined as = .GLLVM_JULIA_BRIDGE_FAMILIES directly, and Julia's bridge_capabilities shows postfit_ordination=true unconditionally for every onepart family including zip (src/bridge.jl fill(true, length(onepart)) for that column) -- so once zip is admitted to BRIDGE_FAMILIES at all, ordination inclusion is automatic and correctly evidenced, no extra gating decision needed. Net: a genuinely conservative first PR is (1)+(7) only -- bare no-X point-fit admission plus the ordination side effect that comes free with it -- with X, masks, grouped dispersion, predict/residual/simulate, and CI all deliberately left gated pending payload-label work.

### live_test_sketch

A TRUE paired round-trip (both engines, same data, logLik tolerance) is NOT possible for zip and should not be attempted: the twin fence is explicit and intentional (test/test_bridge_zip_nox.jl:10-11, "the twin gllvmTMB cut ZIP, so there is no light RCall Delta to run and none may be invented. No parity, ADEMP, or coverage claim is made or tested here."). engine=\"tmb\" has no ZIP fitter to compare against (no C++ support, confirmed above), so there is no `fit_r <- gllvmTMB(..., family = zip())` to write, unlike the lognormal live test at tests/testthat/test-julia-bridge.R:4205-4229 which fits both engines and asserts abs(logLik diff) < 1e-4. The honest live test mirrors the make_long/skip_if_no_julia conventions (tests/testthat/test-julia-bridge.R:10-30) but is a single-engine self-consistency check, e.g.: `test_that(\"zip round-trips through engine = 'julia' (live, no R-native comparator)\", { skip_if_no_julia(); set.seed(42); n_unit <- 60L; df <- expand.grid(unit = factor(seq_len(n_unit)), trait = factor(c(\"t1\",\"t2\",\"t3\")), KEEP.OUT.ATTRS = FALSE); lam <- c(0.5, -0.3, 0.4)[as.integer(df$trait)]; z <- rnorm(n_unit)[as.integer(df$unit)]; pi_zero <- c(0.35, 0.25, 0.4)[as.integer(df$trait)]; mu <- exp(c(0.8, 0.5, 1.0)[as.integer(df$trait)] + lam * z); df$value <- ifelse(runif(nrow(df)) < pi_zero, 0L, rpois(nrow(df), mu)); fit_j <- gllvmTMB(value ~ 0 + trait + latent(1 | unit, d = 1, unique = FALSE), data = df, unit = \"unit\", trait = \"trait\", family = \"zip\", engine = \"julia\", ci_method = \"none\"); expect_s3_class(fit_j, \"gllvmTMB_julia\"); expect_true(is.finite(logLik(fit_j))); expect_true(all(df$value >= 0)) })`. Note: data must be genuinely zero-inflated Poisson-generated (extra zeros beyond the Poisson mass), not plain Poisson, or the structural-zero logit will be unidentified/drift to an extreme boundary -- mirrors the repo's own simulator _bzip_sim in test/test_bridge_zip_nox.jl:20-34 (structural zeros at logit(beta_z), counts at Poisson(exp(beta_c + Lambda*z))). Do NOT claim logLik parity against engine=\"tmb\" in any test description or NEWS entry -- that claim would be false, since no comparator exists.

### risks

- The single most important risk: there is no native R ZIP family at all (not in R/families.R, not in src/gllvmTMB.cpp) -- exposing 'zip' through engine="julia" creates an engine-julia-only family with no R-native fallback and, per the Julia test suite's own explicit 'twin fence' comment, no parity claim may ever be made for it (test/test_bridge_zip_nox.jl:10-11). Any documentation, NEWS entry, or test description implying R/Julia parity for zip would be factually wrong.
- R's coef-payload extractor (.gllvm_julia_coef_payload, R/julia-bridge.R:~1187-1223) has no awareness of the two-part fields beta_zero/gamma_z/gamma_c that zip's Julia payload actually carries (src/bridge.jl:1394, 1695-1696) -- admitting X (or even no-X, for beta_zero) without adding explicit extraction/labeling code means those fields are silently dropped rather than exposed, which is a correctness gap disguised as a capability gap.
- R's SCORE_POSTFIT_FAMILIES list conflates predict/residual/simulate into one gate, but Julia explicitly grants predict+residuals while withholding simulate for zip (src/bridge.jl:572) -- naively adding zip to that one R list to get predict working would incorrectly also claim simulate works, a capability that provably does not exist on the Julia engine (no simulate method on ZIPFit/ZIPCovFit).
- Parameterization/convention mismatch risk for any future summary() layer: Julia's zip fixes the count-part link to log and the structural-zero part to logit unconditionally (src/bridge.jl:1387-1391, "log" literal; no link option is read from `family`/`options`), so if a maintainer later tries to accept a family object with a different link (e.g. zip(link="log") vs a hypothetical probit zero part), the bridge would silently ignore it rather than erroring -- the R-side switch/mapping must not accept a link argument for this family until Julia actually reads one.
- dispersion_public_parameter naming for the structural-zero logit (beta_zero) has no grounded precedent in this codebase (see Q3) -- whatever label is chosen (e.g. pscl/VGAM-style 'zero_(Intercept)' convention) is a new design decision, not a rediscovery of an existing gllvmTMB convention; picking the wrong name now creates a public-API naming debt once users start writing code against it.
- Y is silently rounded to Int inside the Julia no-X and X routes (round.(Int, Yf) / round.(Int, Ydata), src/bridge.jl:1368, 1553) with no validation that the input is actually non-negative-integer count data -- passing continuous or negative response values would not error, it would silently coerce, which could hide a user data-shape mistake specific to this family (Poisson-family routes elsewhere in the bridge presumably have the same behavior, but it is worth confirming this isn't a NEW gap introduced only for zip).
- Grepping alone cannot resolve the r_family_constructors and dispersion_public_parameter questions because the thing being grepped for (a native R zip family) does not exist -- this scout's answers to those two questions are necessarily 'nothing found' plus a recommendation by analogy to external R conventions (pscl/VGAM), not a citation of existing gllvmTMB precedent; flag this explicitly to whoever consumes this spec so 'grounded in code' claims aren't overstated for those two fields specifically.


## Implementation dispositions (2026-09-01, this lane)

- lognormal: EXPOSED (5c94daa08), fit-only, live paired round-trip green.
- truncated_poisson: EXPOSED (this slice), fit-only, log-link guard, no
  dispersion label (family has none); CI setdiff defect fixed for BOTH
  lognormal and truncated_poisson via .GLLVM_JULIA_NO_CI_FAMILIES.
- betabinomial: EXPOSED (this slice), fit-only + load-bearing trials-N
  marshalling (.GLLVM_JULIA_TRIALS_FAMILIES at both cbind/N gate sites),
  logit-only guard, grouped-dispersion labeling as phi_betabinom.
  X/masks deferred to a separately evidenced follow-up (nb1 precedent).
- zip / zinb / zib: PARKED — MAINTAINER DECISION REQUIRED. All three scouts
  found no native R family constructor exists; exposure would create
  engine-julia-only public families with no R-native fallback and (per the
  Julia twin fence) no parity claim permitted, breaking the 1:1 convention
  every exposed family follows. Not to be added silently inside a routine
  bridge-expansion slice. Decision options: (a) add native R ZI families
  first (own programme), (b) expose as explicitly engine-restricted families
  with loud documentation, (c) leave to the delta/hurdle track.

## Verification close (2026-09-01)

Pure-R bridge test file: 585 pass / 0 fail / 22 skip. Live (paired with the
core070 GLLVM.jl lane): 1468 pass / 14 fail, the 14 being exactly the three
PRE-EXISTING pairing tests (capabilities drift vs a broader-than-shipping
Julia lane; grouped-dispersion routing; Gaussian logLik) whose failure count
and names are unchanged from the pre-slice baseline. All three exposures
(lognormal, truncated_poisson, betabinomial) carry green live paired
round-trips vs engine="tmb". Lane remains local/unpushed; landing is the
maintainer's gate.
