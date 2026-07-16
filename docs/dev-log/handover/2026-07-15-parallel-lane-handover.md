# Handover → NEW LANE: parallel gllvmTMB work while the coverage grid runs

**Date:** 2026-07-15 · **From:** Claude lane A (coverage/certificate lane) · **To:** a fresh
lane (Claude or Codex) that will **ultra-plan and execute** the items below · **Branch state:**
`claude/release-0.5.0`, **large uncommitted body** (see §1).

## 0. One-paragraph context

gllvmTMB is in its 0.5 "cover-everything" dev cycle (release at 0.6, not 0.5). Lane A spent this
session diagnosing why the Design-66 interval-coverage pilot returned HOLD. Result: **gaussian was
a harness DGP bug (fixed + verified); binomial is healthy; nbinom2 is a KNOWN, literature-grounded
NB-dispersion-vs-latent-variance identifiability confound (fenced).** Lane A is now running the
**n_sim=2000 core-2 grid on Totoro** (gaussian+binomial) to earn the certificate, ~5–8h from
completion. This handover is the **parallel work** a second lane can do meanwhile. Full session
record: `docs/dev-log/after-task/2026-07-13-coverage-diagnosis-gaussian-fix.md`,
`docs/dev-log/2026-07-13-A2-pilot-coverage-HOLD.md`,
`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`.

## 1. 🔴 LANE BOUNDARY — read before touching anything

**Lane A (coverage lane) OWNS and the new lane MUST NOT TOUCH:**
- The **running Totoro grid** (`~/gllvm_work/grid2000/`) and any Totoro coverage compute. Do **not**
  launch heavy Totoro jobs — the grid is using ~8–24 cores and Totoro is shared (≤100-core rule).
- **The coverage certification** — the gaussian+binomial verdict + A3 (widget/NEWS label flips).
- The **gaussian DGP fix** in `dev/m3-grid.R` (just landed; do not edit the gaussian branch).

**Uncommitted-state hazard (THE coordination rule).** Lane A has a large uncommitted diff on
`claude/release-0.5.0`. **Files Lane A has modified — do NOT edit these in the new lane until the
maintainer commits Lane A's work:**
`R/fit-multi.R`, `src/gllvmTMB.cpp`, `R/bootstrap-sigma.R`, `R/diagnose.R`,
`R/extract-correlations.R`, `R/extract-sigma.R`, `R/predictive-diagnostics.R`,
`dev/m3-grid.R`, `dev/m3-pilot-report.R`, plus new files `R/reml-bridge.R` and the new tests.

**Two safe operating modes for the new lane:**
- **(A) Preferred:** maintainer commits Lane A's body first → new lane branches clean from that.
- **(B) Until then:** the new lane confines itself to (i) **new files** (design docs, prep docs,
  new tests) and (ii) files Lane A has **not** touched — notably `R/brms-sugar.R` (B3) is clean.
  Do design/prep now; defer edits to the shared package files (`src/gllvmTMB.cpp`, `R/fit-multi.R`,
  `dev/m3-pilot-report.R`) until (A). Use a **git worktree** for isolation.

## 2. The work menu (to ultra-plan — ranked by leverage)

### Item 0 — 🎯 THE interval-coverage item: re-score `Sigma_unit_diag` on the PROFILE / t-df route (NOT bootstrap/BCa)
**This is the actual certificate path and supersedes any "BCa" idea.** The n_sim=2000 Totoro grid
(done 2026-07-15) measured coverage on the **percentile-bootstrap** route → gaussian ~0.91,
binomial ~0.84, misses **4–11:1 truth-above-upper**. Direct check: the point estimate is
**near-unbiased** (ML Σ̂/truth 1.007, REML 1.014 at n=150 — REML barely moves it), so it's the
**right-skew** of a bounded LOCATION-axis variance component, NOT ML mean-bias and NOT Laplace
(gaussian Laplace is exact). **The fix is already-decided doctrine — DO NOT re-derive it:**
**[[Small-sample variance-component interval corrections — cross-repo map]]** (`~/shinichi-brain/Shinichi/methods/`),
`LEARNINGS-archive.md:38–39`, gllvmTMB#565, D-12, Design 73/75.
**Task:** re-score the SAME core cells (gaussian + binomial) on **(a) the direct log-SD PROFILE
route** (already "covered" per Design 73) and **(b) Wald on the log-SD scale with a t-quantile on
`g−1` (Satterthwaite/KR) df** — per-target (t helps location VCs, do NOT apply to dispersion φ;
ρ→Fisher-z). Compare to the bootstrap column already in `~/gllvm_work/grid2000/`. Expectation
(from drmTMB): profile lands near nominal (0.948–0.956 at adequate g). This is the "profile / t-df"
columns of the **2026-07-06 coverage-mapping campaign** — the grid we ran is its "bootstrap" column.
**Where.** `R/profile-ci.R` / `profile_targets()` (direct log-SD profile); `R/extract-correlations.R`
(Fisher-z pattern to mirror for log-SD); the m3 scorer `dev/m3-grid.R` currently routes
`Sigma_unit_diag` to bootstrap — add profile + t-df routes. ⚠️ `dev/m3-grid.R` is Lane-A-modified →
sequence after §1(A).
**Effort:** the headline methods slice; ~1 session. **BCa is explicitly OFF the table** (last resort).



### Item 1 — 🥇 Shared-dispersion (`disp.formula` / `disp_group=`): the nbinom2 fix
**Goal.** Let the NB2 dispersion `phi` be **pooled/grouped across traits** instead of one free
`phi` per trait, mirroring gllvm's `disp.formula`. This is the literature-endorsed remedy for the
NB-dispersion-vs-latent-variance ridge and the concrete lever to **un-fence nbinom2 for the 0.6
coverage certificate**.
**Evidence it works.** Lane A's mitigation ladder (`dev/nbinom2-mitigation-ladder.R`,
`dev/nbinom2-mitigation-ladder-results.rds`): median Σ̂/truth — default **0.45–0.52**, warm-start
identical (no help), **known-phi 0.78–0.82 rising with n**. The DGP uses ONE shared phi; the fit
estimates FIVE → over-parameterised. Pool them and Σ should recover. Cross-package basis:
`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md` §3 item 4 ("Optional
`disp.group=` for shared phi", ~50 LOC, gllvm `disp.formula`). Literature:
`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`.
**Where.** C++: `src/gllvmTMB.cpp:615` `PARAMETER_VECTOR(log_phi_nbinom2)` (length n_traits) — add a
`DATA_IVECTOR` group-index so multiple traits share one phi entry; R wiring in `R/fit-multi.R`
(family/phi mapping ~line 272+, control surface pattern at `R/fit-multi.R:3677/4524`); user surface
via `gllvmTMBcontrol()` or a `disp_group=` arg.
**Slices:** (a) design doc `docs/design/NN-shared-dispersion.md`; (b) C++ group-index + map; (c) R
wiring + arg; (d) recovery validation = re-run the nbinom2 ladder with shared phi → Σ→nominal?;
(e) a coverage smoke on 1–2 nbinom2 cells (LOCAL n_sim small, or a SEPARATE Totoro dir only once
the grid is done). ⚠️ **API/engine change → maintainer sign-off before merge** (repo rule). ⚠️
Touches Lane-A-modified files → do design (a) now, code (b–e) after §1(A).
**Effort:** the flagship; ~1 focused session.

### Item 2 — 🥈 Doc-honesty review prep (turnkey the "F" gate) — CONFLICT-FREE, start now
**Goal.** Make the with-Shinichi page-by-page pre-CRAN review a fast approve/tweak pass, not a cold
start. Build the checklist (the ~18 articles + reference/roxygen honesty exports) and **draft the
honesty-fenced wording**: nbinom2 = "known NB-dispersion/latent-variance confound, intervals
recovery-only / not coverage-certified"; delta/hurdle latent-scale correlation "do not advertise";
intervals framed recovery-only until the grid earns the certificate. **New files only** (e.g.
`docs/dev-log/2026-07-15-doc-honesty-review-checklist.md`). No package-file edits → no conflict.
**Effort:** ~half a session; high value, zero risk.

### Item 3 — 🥉 B3: bare `||` uncorrelated-slope grammar — CONFLICT-FREE FILE (`R/brms-sugar.R`)
**Goal.** Admit the unprefixed `latent(1 + x || g)` / `indep(1 + x || g)` block-diagonal (uncorrelated
random-slope) spelling, which currently aborts at parse. Lane A already built the **engine** for the
cluster2 diagonal case (B4, `unique(1+x|c2)`); this is the **bare-`||` parser/grammar spelling** on
top. `R/brms-sugar.R` is NOT in Lane A's modified set → safe to edit. ⚠️ **Formula-grammar change →
maintainer checkpoint before merge.** Pair with a recovery test.
**Effort:** ~half a session (parser + test).

### Item 4 — Repair #5: `ci_missing_rate` metric bug — needs §1(A) first
**Goal.** In `dev/m3-pilot-report.R`, `pilot_scale_gate_eval` computes
`ci_missing <- 1 - coverage_eligible_n / n_converged_fits` = **−4** because `coverage_eligible_n`
counts per-(draw×trait) interval checks (~5× at n_traits=5) while `n_converged_fits` counts draws.
Fix: add `n_traits` to the aggregate row (~`dev/m3-pilot-report.R:617`) and use
`denom = n_converged_fits * n_traits` in the gate (~line 274); update `dev/test-pilot-scale-gate.R`.
Changes no current verdict (gate passes on it trivially) but the CI-missing health gate is
meaningless until fixed. ⚠️ `dev/m3-pilot-report.R` is Lane-A-modified → defer to §1(A).
**Effort:** ~1–2h.

## 3. Recommended ultra-plan shape
Slice by conflict-safety, not just leverage:
- **Start immediately (conflict-free, no gate on Lane A):** Item 2 (doc-honesty prep, new files) +
  Item 1a (shared-dispersion **design doc**) + Item 3 (B3, `R/brms-sugar.R`, maintainer-checkpoint
  the grammar before merge).
- **After maintainer commits Lane A (§1A):** Item 1b–e (shared-dispersion C++ + validation) +
  Item 4 (Repair #5).
- Model routing (per `~/shinichi-brain/memory/MODEL-ROUTING.md`): design/prep → Sonnet; C++
  engine + recovery correctness → Opus/Fable; mechanical doc/test → Haiku.

## 4. Verification + closure (both lanes)
- Every code slice ships a test; heavy nbinom2 cells under `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`;
  sum the `error` column. Shared-dispersion "it works" = **recovery to truth on the ladder**, not an
  assertion (D-43 default NOT-DONE).
- Do NOT claim nbinom2 coverage-certified until a real shared-phi coverage run clears the gate.
- Close with an after-task report in `docs/dev-log/after-task/`. Coordinate merges with Lane A via a
  line in `docs/dev-log/check-log.md` (the async bus) — do not merge onto Lane A's uncommitted files.

## 5. What Lane A will hand back
When the grid lands (~5–8h): the gaussian+binomial coverage verdict + A3 (widget/NEWS flips for the
**earned** cells only; nbinom2 stays fenced **unless Item 1 lands and re-certifies it**). If Item 1
succeeds, the two lanes converge: nbinom2 joins the certificate.
