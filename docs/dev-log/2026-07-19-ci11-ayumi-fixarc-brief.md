# CI-11 — Ayumi QC follow-up: reply draft + 3-bug fix brief (2026-07-19)

Source: Ayumi-495/BIRDBASE_pcm#1 (real BIRDBASE data, gllvmTMB 0.5.0, branch claude/cross-family-intervals-20260718,
commit 20773d7). Functional QC only — not coverage-calibrated. Gate-2 of Design 39 (CI-11 register) = SATISFIED,
and it surfaced 3 real bugs + confirmed the wald plumbing + corroborated the bootstrap fence.

## The 3 bugs (severity order)

### BUG 2 (HIGHEST) — profile route SILENT NON-RETURN (Gaussian submodel)
- Symptom: `extract_cross_correlations(profile_fit, level="unit", contrasts=TRUE, method="profile", link_residual="auto")`
  on a HEALTHY Gaussian submodel (conv 0, PD Hessian, grad 5.85e-05) **did not return and raised no catchable error**
  (pre-call marker survived; no result saved). Worse than under-coverage — an uncatchable failure.
- Likely cause (UNVERIFIED): an unguarded loop / non-terminating bracket search or a C++-level crash in the profile
  fix-and-refit path, hit by this real data shape (multinomial nominal + Gaussian partner, masked missing).
- Fix: (a) wrap the profile route so it ALWAYS returns intervals or `stop()`s with an informative, catchable message
  (no silent non-return); (b) get a minimal reproducer from Ayumi → diagnose the underlying non-termination/crash.
- Verify (LIVE): the exact call returns finite intervals OR a catchable error; add a regression test on the reprex.

### BUG 1 — bootstrap `multiple_r` all-NA (multinomial simulate missing)
- Symptom: `method="bootstrap"` on the phy fit → 10 multiple_r rows, all lower/upper NA. `bootstrap_Sigma(..., what="cross_corr")`
  reports `n_failed = 100`, 0 effective finite multiple_r draws/pair. Warning: **family-aware `simulate()` not implemented
  for family ID 14 (multinomial)** → affected rows fall back to Gaussian-on-link draws → all refits fail → 80%
  effective-draw threshold → NA bounds. Point estimates still returned.
- Root cause: no multinomial branch in the family-aware `simulate()` used by the bootstrap refit path.
- Fix: (a) implement a multinomial (baseline-category) `simulate()` branch so bootstrap can draw multinomial responses;
  (b) surface the failed-refit / effective-draw diagnostics (n_failed, effective_draws per target) as a STATUS in
  `extract_cross_correlations()` output — not only inside `bootstrap_Sigma()`. Register disposition (bootstrap fenced)
  is UNCHANGED — this just gives the fence a concrete named mechanism.
- Verify (LIVE): bootstrap on a multinomial fit returns finite draws (or an explicit, honest status), n_failed→low.

### BUG 3 — profile lognormal non-finite contrast endpoints (7/10)
- Symptom: `method="profile", link_residual="none"` on a Gaussian... (lognormal `Clutch_Midpoint`) submodel → 10
  contrast rows, 7 with non-finite endpoints, no explicit status. (No multiple_r profile expected — aggregate block
  functional isn't a profile target; consistent with the register.)
- Root cause (UNVERIFIED): profile brackets don't close for lognormal partners under `link_residual="none"`.
- Fix: add an explicit per-row `profile_status` (e.g. "non_finite" / "unbracketed") so failures are transparent, not
  silent Inf/NA; investigate the lognormal link-residual handling in the profile route.
- Verify (LIVE): rows carry honest status; where brackets can close, endpoints are finite.

## Control that PASSED (keep as evidence)
Wald/Fisher-z on all fit types → 10 multiple_r + 100 contrast_r rows, all finite/bracketed/in-range, no dup/missing
status. Corroborates the register's `wald = partial (heuristic, usable)`. The full ordinary fits had non-PD Hessians
(Ayumi treated wald as plumbing-QC only) — expected, not a bug.

## Register-wording implications (gate-2 done → update, then gate-3 D-43)
- **profile: DROP unqualified "most robust reference route."** Add: "on real mixed-family fits shows open failure
  modes — silent non-return (Gaussian) and non-finite endpoints (lognormal) — root cause open; not turnkey."
- **bootstrap: fenced (unchanged)** + name the mechanism (multinomial simulate missing → all refits fail).
- **wald: partial-heuristic (unchanged)** — corroborated on real data.

## Hardening-map additions (3 lines)
H-xfc-A: multinomial `simulate()` (family ID 14) missing → bootstrap NA; + expose failed-refit diagnostics in extractor.
H-xfc-B: profile route silent non-return (Gaussian) → must return or raise catchable error. [HIGHEST]
H-xfc-C: profile lognormal non-finite contrast endpoints → explicit per-row status.

## Code review of Ayumi's repo (Ayumi-495/BIRDBASE_pcm, read-only, 2026-07-19) — SHE USED IT CORRECTLY
Reviewed `scripts/13_fit_cross_family_4000.R`, README, AGENTS.md, `outputs/4000sp/cross_family_4000_results_summary.md`.
- API usage is CORRECT: `family_list` + `attr(., "family_var")`, `miss_control(response="include")` (supported, MIS-01..04),
  isolated 2-trait profile submodels to isolate extractor behaviour, careful `check_gllvmTMB()` health gating. No misuse.
- **Her `unique=FALSE` is EVIDENCE-BASED, not a guess.** Her 4000sp summary: the maximal rank-2 (`unique=TRUE`) fit had a
  **non-PD Hessian** because the ordinary per-trait Ψ was **boundary-pinned**; she switched to `unique=FALSE` rank-1 to fix
  definiteness (it did, but still failed the gradient gate — she treats neither as inferential). So she independently hit
  the Ψ-boundary problem → chose loadings-only → landed on the ΛΛ' rank-1 boundary. Exactly the trade we flagged.
- **Independent corroboration of the degeneracy mechanism:** her summary reports the rank-1 fit **"produced repeated
  multiple_r magnitudes for several partner traits"** — the fingerprint of rank-1 shared-loading collapse (correlations
  become deterministic loading ratios). This is real-data evidence the correlations are near-degenerate/±1, which is the
  likely trigger for the profile bracket-search failure (B2) and non-finite endpoints (B3). So: the fix is a
  BOUNDARY-AWARE profile guard (return or raise catchable + honest status), NOT just "use unique=TRUE" (her evidence shows
  unique=TRUE trades the ΛΛ' boundary for a Ψ boundary — both need graceful handling).

## Two groundings from the register (2026-07-19, read-only grep)
- **BUG 1 root is KNOWN — register row MIS-05.** `simulate.gllvmTMB_multi()` (`.draw_y_per_family()`, PR #157) is
  family-aware for **6 families only: gaussian / binomial / poisson / lognormal / Gamma / nbinom2**; **multinomial +
  ordinal FALL BACK with a one-time warning.** So the multinomial (family ID 14) bootstrap fell back to Gaussian-on-
  link and failed → n_failed=100 → NA. Fix B1 = **extend `.draw_y_per_family()` to multinomial** (baseline-category
  draws) + expose the diagnostic. This is a scoped, known-gap fix, not a mystery. (`test-m1-8-bootstrap-mixed-family.R`.)
- **BUGS 2 & 3 may be `unique=FALSE` DEGENERACY, not (only) a profile bug.** Ayumi ran the profile tests on
  loadings-only (`unique=FALSE`, rank-1) submodels. Rank-1 loadings-only ⇒ Σ=ΛΛ' ⇒ the latent cross-trait
  correlations are structurally at/near **±1** (a boundary), potentially mitigated by link-residual variance for
  non-Gaussian partners but NOT for Gaussian. Profiling a correlation pinned at a ±1 boundary is exactly where a
  bracket search hangs (B2, Gaussian) or returns non-finite endpoints (B3, lognormal). **KEY reproducer step: re-run
  B2/B3 with `unique=TRUE`** (adds Ψ → interior correlations). If they vanish → boundary-degeneracy artifact (the fix
  is a boundary guard + honest status). If they persist → deeper profile-route bug. EITHER WAY the route must return
  or raise a catchable error — but the reproducer isolates the cause fast.

## Sequencing
1. Reply to Ayumi (below) — she posts / maintainer posts (do NOT post on her behalf without explicit OK).
2. Fix the 3 (LIVE R/TMB arc — needs real fits + regression tests). Executor = live-toolchain (Codex, in-repo) OR a
   Claude window; NOT concurrent with Codex's active 0.6 arc (sequential rule).
3. Verify each fix on a reproducer; update hardening map + register wording.
4. Fresh D-43 (gate-3) on the updated register wording.
5. Re-invite Ayumi to re-test the SAME setup.

---

## FINAL reply to Ayumi (issue #1) — NOT yet posted (needs maintainer OK to post)

@Ayumi-495 — thanks, this is exactly the functional QC we hoped for. I went through the issue and your repo
(`scripts/13_fit_cross_family_4000.R` and the 4,000-species results summary), and first: **you're using the
extractor correctly — nothing to change in your setup.** The three failures are genuine package gaps, not misuse.

**On `unique = FALSE` — your call was right.** Your own diagnosis (rank-2 → non-PD Hessian from a boundary-pinned Ψ →
drop to rank-1 loadings-only to restore definiteness, while treating neither fit as inferential) is exactly the
sensible trade. And your note that the rank-1 fit "produced repeated `multiple_r` magnitudes" is the correct read —
that's rank-1 shared-loading collapse, not identical biology. That observation actually helps us: it says the
correlations sit near a ±1 boundary, which is very likely what trips the profile route below.

**1. Bootstrap `n_failed = 100` / NA `multiple_r`.** A package limitation, not your setup. Family-aware `simulate()`
currently dispatches for gaussian/binomial/poisson/lognormal/Gamma/nbinom2 only — **multinomial (and ordinal) fall
back with a one-time warning**, so every bootstrap refit for the multinomial response drew on the wrong scale and
failed (the 100/100). Two fixes queued: (a) add the multinomial baseline-category `simulate()` branch so bootstrap
can draw; (b) surface `n_failed` / effective-draw counts directly in `extract_cross_correlations()` output — you
shouldn't have to dig into `bootstrap_Sigma()` for them. Until (a) lands, treat bootstrap on multinomial responses
as unsupported.

**2. Gaussian profile call not returning.** Yes — a silent non-return with no catchable error is a bug, full stop,
and it's our top priority. The route must return intervals or `stop()` with an informative message. Our working
hypothesis is the rank-1 near-±1 correlation boundary breaking the profile bracket search — but that's ours to fix
either way. A **minimal reproducer** (the `profile_fit` object, or the small 2-trait script + data, plus the exact
call) would let us pin it fastest.

**3. Non-finite lognormal profile endpoints.** Partly expected — profile brackets can fail to close near that
boundary — but 7/10 non-finite with no status is poor UX. We'll add an explicit per-row status so it's transparent
rather than silent, and look at the lognormal `link_residual = "none"` path.

**Are you testing it as intended?** Yes, precisely — real mixed-family data, careful `check_gllvmTMB()` health
gating, and honest framing as functional QC (not calibrated intervals or biological inference). No need to rerun at
d = 2 or more species yet; we'll fix these three and then ping you to re-run the same setup as a regression check.
If it's easy, a reproducer for #2 is the single most useful thing right now. Thanks again — genuinely helpful.
