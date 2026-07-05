# Session Handoff: gllvmTMB Gamma checkpoint and completion-arc next slice
Meta: 2026-07-05 05:26 MDT - from Codex - target Claude - repo `gllvmTMB`

You are Claude, picking up from Codex after a clean local checkpoint on
`gllvmTMB`. Start from the repository files, not chat memory.

## Critical Context

The active branch is `codex/r-bridge-grouped-dispersion`, clean at
`dff9b363 fix: decouple gamma dispersion from sigma eps`, and ahead of
`origin/codex/r-bridge-grouped-dispersion` by 200 commits. This branch is
local-only in the current state. Do not push, open a PR, or merge unless
Shinichi explicitly authorizes it.

The latest completed slice locally addresses `gllvmTMB#622`: ordinary
`Gamma(link = "log")` rows now estimate per-trait `phi_gamma` shape/CV instead
of sharing Gaussian/lognormal `sigma_eps`. That is a native R/TMB correctness
repair, not Julia parity, not mixed-family interval calibration, and not
source-specific `lv = ~ env` support.

## Goals / Mission

The current strategic goal is to finish `gllvmTMB` first as the R/TMB
completion arc, while keeping Julia bridge parity quiet unless Shinichi
explicitly reopens that lane. The work should stay evidence-led: a route is
`covered`, `partial`, `blocked`, or `planned` only when the validation register
and tests say so.

Use the uncertainty ladder already agreed with Shinichi:

- Wald is acceptable for fast scouting and stable fixed-effect-like targets.
- Estimated-likelihood / fixed-nuisance LR is a cheap diagnostic canary for
  hard structural models.
- Full profile likelihood-ratio intervals are the preferred public
  likelihood-framework engine where feasible.
- Bootstrap and ADEMP simulation are calibration or rescue evidence, not the
  default centerpiece.
- `pdHess = TRUE` is not enough for calibrated CI claims.

## Mission-Control Summary

| Repo / Surface | Branch / State | What Shipped | Next Leverage | Guard |
| --- | --- | --- | --- | --- |
| `gllvmTMB` | `codex/r-bridge-grouped-dispersion` clean at `dff9b363`, ahead 200 | Native Gamma `phi_gamma[t]` decoupled from `sigma_eps`; focused Gamma and mixed tests pass | Profile-route truth slice across `unit`, `unit_obs`, `cluster`, `cluster2`, structural-slope, source, and kernel targets | No push/PR/merge without Shinichi; no broad compute while local gates remain unsettled |
| Inference surfaces | Route matrix partly hardened | `unit_obs` fitted canaries, cluster/cluster2 diagonal wrappers, named-kernel blocked route, Gamma profile smoke evidence | Build a complete estimand x tier x method matrix for profile/Wald/estimated-likelihood/bootstrap | Do not advertise "all profile intervals exist" |
| Missing / mixed correctness | Local issue reconciliation in progress | Mixed-family named-list guards and response-weight checks passed locally | Decide next focused PR after profile-route truth: missing response/predictor correctness or mixed dispatch polish | Mixed-family CIs remain blocked |
| Julia / `GLLVM.jl` bridge | Quiet in this arc | Pure-R bridge layer passed; live rows skipped without `GLLVM_JL_PATH` | Only wording and truth-boundary checks unless Shinichi reopens parity | No Julia dependency or parity requirement in this R completion slice |
| Mission Control widget | Served at `http://127.0.0.1:8770/` | Last refreshed before the Gamma `dff9b363` checkpoint | Refresh only after Shinichi wants the local operating board updated | Dashboard text can lag local commits; validate JSON before serving |

## What Was Accomplished

Latest local commit:

- `dff9b363 fix: decouple gamma dispersion from sigma eps`

Recent supporting commits immediately before it:

- `6392e326 docs: record focused validation pack`
- `faf6daac docs: reconcile issue 678 local fix`
- `9724c38a test: lock mixed-family name guards`
- `a5b9d1b0 test: lock profile route parser boundaries`
- `4817db59 docs: refresh completion mission control`
- `97712555 test: make source clamp audit check-safe`

The Gamma slice:

- added `log_phi_gamma` / `phi_gamma` for ordinary Gamma rows in the native
  TMB path;
- kept `sigma_eps` for Gaussian/lognormal residual scale only;
- updated R mapping, initialization, residual/sigma extractors, profile target
  inventory, bridge wording, tests, design docs, generated Rd, NEWS, check-log,
  and after-task report;
- kept bridge grouped-Gamma parity as follow-up rather than claiming it was
  solved.

## Current Working State

- Working: local branch clean at `dff9b363`.
- Working: focused Gamma, mixed-family, route-matrix, bridge pure-R, and heavy
  non-skipped Gamma tests listed in the after-task report passed locally.
- In progress: the broader `gllvmTMB` completion arc; current best next slice
  is profile-route truth across structural tiers before further capability
  promotion.
- Not working / blocked: live GLLVM.jl bridge tests were skipped because
  `GLLVM_JL_PATH` is not configured here; full `devtools::check()` and
  `pkgdown::check_pkgdown()` were not rerun after `dff9b363`; public issue
  closure for #622 waits for push/PR/merge authority.

## Key Decisions & Rationale

- Gamma now means
  `Y_it | eta_it ~ Gamma(shape = phi_gamma[t], scale = exp(eta_it) / phi_gamma[t])`.
  This matches the design docs and avoids the old scalar-CV aliasing with
  Gaussian/lognormal `sigma_eps`.
- Keep `source-specific lv = ~ env` for `phylo_latent()`, `animal_latent()`,
  `spatial_latent()`, and `kernel_latent()` fail-loud unless a dedicated
  implementation, tests, docs, and maintainer sign-off land.
- Mixed-family point/postfit routes may be guarded as covered, but mixed-family
  CIs remain blocked until direct interval evidence exists.
- Claude should help most with review, planning, prose, and issue triage.
  Codex should keep owning live R/TMB implementation, compiled checks,
  pkgdown, and simulation runs.
- `AGENTS.md` was not edited for this handover because this repo has no
  "Live Phase Snapshot" block to prepend to. This handover file is the durable
  start point.

## Files Created / Modified

This handover commit creates:

- `docs/dev-log/handover/2026-07-05-claude-handover.md`

The latest completed implementation commit `dff9b363` modified:

- `NEWS.md`
- `R/extract-omega.R`
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `R/gllvmTMB.R`
- `R/init-warmstart.R`
- `R/julia-bridge.R`
- `R/methods-gllvmTMB.R`
- `R/output-methods.R`
- `R/profile-targets.R`
- `R/unique-keyword.R`
- `docs/design/02-family-registry.md`
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/after-task/2026-07-05-gamma-phi-decoupling.md`
- `docs/dev-log/check-log.md`
- `man/diag_re.Rd`
- `man/extract_Sigma.Rd`
- `man/extract_residual_split.Rd`
- `man/gllvmTMB.Rd`
- `src/gllvmTMB.cpp`
- `tests/testthat/test-cluster2-families.R`
- `tests/testthat/test-family-gamma.R`
- `tests/testthat/test-gamma-recovery-depth.R`
- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-link-residual-15-family-fixture.R`
- `tests/testthat/test-m3-4-warmstart-phi-clamp.R`
- `tests/testthat/test-matrix-gamma-spatial.R`
- `tests/testthat/test-matrix-gamma-unit.R`
- `tests/testthat/test-matrix-slope-gamma.R`
- `tests/testthat/test-tiers-gamma.R`

Use `git diff --name-only origin/codex/r-bridge-grouped-dispersion...HEAD` if
you need the full 200-commit local branch path list. Do not stage that full
diff blindly.

## Next Immediate Steps

1. Rehydrate in this order:
   - `/Users/z3437171/shinichi-brain/AGENTS.md`
   - `AGENTS.md`
   - `CLAUDE.md`
   - `docs/dev-log/handover/2026-07-05-claude-handover.md`
   - `docs/dev-log/after-task/2026-07-05-gamma-phi-decoupling.md`
   - latest entries in `docs/dev-log/check-log.md`
   - `docs/design/35-validation-debt-register.md` rows `FAM-09`, `CI-11`,
     `MIX-02`, `EXT-33`, `JUL-01`, and `JUL-01A`
   - `docs/design/73-profile-likelihood-route-matrix.md`
   - `docs/design/74-augmented-profile-target-table.md`
2. Verify state:
   ```sh
   cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
   git status --short --branch
   git rev-parse --short HEAD
   git log --oneline -8
   ```
3. Draft the next profile-route truth slice before editing code:
   - rows: `unit`, `unit_obs`, `cluster`, `cluster2`, `phy`, `spatial`,
     named kernel, `unit_slope`, and future split source tiers;
   - targets: `Sigma`, `rho`, `communality`, variance proportions, direct
     scale parameters, selected loadings/effects where already implemented;
   - methods: Wald, profile-LR, estimated-likelihood canary, bootstrap;
   - output state: `covered`, `partial`, `blocked`, or `planned`, with test
     paths and validation-row IDs.
4. Ask Rose/Fisher/Noether to review the matrix for overclaims before any
   public-facing wording changes.
5. Hand live implementation back to Codex unless Shinichi explicitly asks
   Claude to do prose-only docs or issue triage.

## Blockers / Open Questions

- Shinichi has not authorized a push/PR/merge from this branch. The branch is
  200 commits ahead, so a cloud or fresh-machine Claude may not see it until it
  is pushed or otherwise copied.
- Full package-level release checks after `dff9b363` are still open:
  `pkgdown::check_pkgdown()` and
  `devtools::check(args = "--no-manual", quiet = TRUE)`.
- Live Julia bridge parity is not checked in this R session because
  `GLLVM_JL_PATH` was not configured.
- Mission Control at `http://127.0.0.1:8770/` may not reflect `dff9b363`.
  Refresh only if Shinichi wants the local operating board updated.
- The next implementation arc should be chosen deliberately: recommended first
  is profile-route truth; missing response/predictor correctness and mixed
  dispatch polish can follow as focused PRs.

## Gotchas & Failed Approaches

- Do not treat `pdHess = TRUE` as calibrated interval evidence.
- Do not turn the Gamma repair into a non-Gaussian interval-calibration claim.
- Do not revive source-specific `lv = ~ env` support language from old notes.
- Historical after-task notes may mention older Gamma scalar-CV language; the
  current truth is `dff9b363` plus
  `docs/dev-log/after-task/2026-07-05-gamma-phi-decoupling.md`.
- Mission Control is local operating truth, not public pkgdown/CRAN evidence;
  it can lag the latest local branch if the JSON was not refreshed.
- Avoid broad Totoro/DRAC compute while local focused tests and denominator
  designs are still being refined. Totoro/DRAC are for gated calibration or
  multi-seed evidence after the route design is clean.

## How to Resume

From Shinichi's authenticated terminal:

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
claude "Rehydrate from docs/dev-log/handover/2026-07-05-claude-handover.md + AGENTS.md + CLAUDE.md, then review the clean dff9b363 Gamma checkpoint and propose the next profile-route truth PR before any code. Do not push, open PRs, or widen source-specific lv / mixed-family CI claims without maintainer approval."
```

Autonomous clean-context variant with a budget cap:

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
claude -p "Rehydrate from docs/dev-log/handover/2026-07-05-claude-handover.md + AGENTS.md + CLAUDE.md, then prepare the next gllvmTMB completion slice plan around profile-route truth. Do not push, open PRs, or edit likelihood/formula grammar without maintainer approval." --max-budget-usd 10
```


---

# Session Handoff: completion-arc — merge landed + M1–M5 audited + delta/D-28 resolved
Meta: 2026-07-05 13:48 MDT · from Claude · target Claude (next session) · repo `gllvmTMB`

You are Claude, picking up from the previous Claude session (Codex is out ~3 days —
Shinichi said "you own the project"). **This env compiles and runs live R/TMB** — I ran
real fits this session (merge suite, recovery studies). So the "live-implementation" items
below are YOURS to do, not blocked on Codex. Start from repo files, not chat.

## Critical Context (read or you'll go wrong)

1. **Branch `codex/r-bridge-grouped-dispersion` @ `ba60185f`, PUSHED (local == origin).**
   The 99-conflict fold-arc merge (main → this branch) is DONE: full suite **4168/0**,
   R CMD check **0/0/0** (skipping vignettes + missing Suggests), adopted onto live as a
   `--no-ff` merge commit. It is **273 commits ahead of main**.
2. **Hard guard — do NOT push to `main` / open a PR-to-main / merge without Shinichi.**
   Branch pushes for backup ARE authorized (that's why origin is current). The big
   273-commit PR-to-main is deferred to Shinichi.
3. **THE pdHess GOTCHA (I burned several commits on this — see Gotchas).** On a default
   gllvmTMB fit `fit$sdr` is `NULL`, so `isTRUE(fit$sdr$pdHess)` is `FALSE` for EVERY fit.
   It is NOT a convergence signal. To check a Hessian, run `sdreport` (`se = TRUE` /
   `TMB::sdreport(fit$obj)`).

## What Was Accomplished

- **The merge** (bulk of the session): 99 conflicts → green → check 0/0/0 → adopted → pushed.
  Guards re-layered (source `lv=` abort, spatial trait-anchor, phylo mode-dispatch, dup-slope),
  #608/#626/#628/#643 re-applied, `spatial_latent(unique=)` SPDE fold restored, positional
  control args restored.
- **M1 truth matrix — DONE + verified** ([Design 75](../../design/75-inference-route-truth-matrix.md)):
  all tiers × Wald/profile/est-lik/bootstrap, covered/partial/blocked/planned, RE-*/CI-* IDs.
- **M2 missing/mixed** — D-28 verified; **`interval_status` marker SHIPPED** in
  `extract_correlations()` (nominal / route-only / none; `R/extract-correlations.R`); MIX-10
  "blocked" exposed as never-wired; **delta resolved** (Shinichi's design, below) across
  Design 02/57 + register + README/NEWS/ROADMAP/2 vignettes.
- **M3 slope** — `unit_slope` fisher-z block runtime-CONFIRMED (refuses, no fabrication);
  profile canary enforced (`profile-derived.R:692`); phy/spde generalize by the same path.
- **M4 non-Gaussian** — D-28 residuals + auto-Psi + OLRE audited. Chased a phantom
  "non-convergence" (the pdHess NULL bug) → RETRACTED (see Gotchas). Solid: the non-Gaussian
  **between-unit Ψ is identifiable** (recovery study).
- **M5 release** — user-facing status-drift swept (NEWS/README/ROADMAP/2 vignettes, pdHess
  overclaim softened, `man/` clean).
- **D-28 principle made explicit** (Design 02 Link Residual Contract + `~/.claude/memory/`):
  lowest-level Ψ = unique + link-specific; **OD-Poisson is the ONLY family with both.**

## Current Working State

- **Working:** everything committed + pushed; suite green; check 0/0/0; branch == origin.
- **In progress / next (yours — live R/TMB OK):** delta latent-on-main wiring; the real
  FAM-17 boundary reproduction *with sdreport*; phy/spde slope runtime airtighten; pkgdown
  render-check; Mission Control refresh; register CI-08/CI-10 promotion once evidenced.
- **Blocked on Shinichi:** the push-to-main / PR decision.

## Key Decisions & Rationale

- **Delta mixed-family = HANDLED (route-only), not blocked.** Latent on the **positive**
  submodel only; occurrence submodel **fixed-effects-only** → single latent scale →
  correlation on the **positive-part residual**; reported `interval_status="route-only"`.
  ([Design 02 §Hurdle/delta].) Post-CRAN: RE on the occurrence part (two-scale case).
- **interval_status marker** — makes calibration boundary visible in-output (nominal vs
  route-only vs none). Additive column; verified claim-safe.
- **D-28 / OD-Poisson** — see above; OD-Poisson uniquely carries both because it adds a
  separate estimated OLRE on top of the Poisson link residual (others bake overdispersion in).

## Files Created / Modified

107 commits since `4d8f7589`; ~64 docs, 45 tests, 29 vignettes, 29 man, 17 `R/`, 4 data-raw.
Full list: `git diff --name-only 4d8f7589..HEAD`. Highest-signal:
- `R/extract-correlations.R` (interval_status marker), `R/brms-sugar.R` (guards + positional),
  `R/fit-multi.R`, `R/kernel-helpers.R`, `R/extract-sigma.R`.
- Design: `02-family-registry.md` (delta resolution + D-28 principle), `35-validation-debt-register.md`
  (MIX-10 → partial), `57-mixed-family-link-residual.md` (banner), `75-inference-route-truth-matrix.md`.
- Dev-log: [Codex handoff](../2026-07-05-codex-handoff-completion-arc.md) (live-fit items, with
  the pdHess RETRACTION banner), [session closure](../after-task/2026-07-05-completion-arc-session-closure.md)
  (state of the arc), after-task notes (merge / missing-mixed / structural-slope).
- `data-raw/diagnostics/2026-07-05-nongaussian-psi-recovery-study.R` (reusable recovery study).
- This handover doc.

## Next Immediate Steps (ordered)

1. **Rehydrate** (below) + spawn the review lens (Rose) before any claim.
2. **Reproduce the real FAM-17 delta boundary WITH `sdreport`** (`se = TRUE`) before touching
   any convergence code — the earlier "bug" was the pdHess-NULL phantom. Use the recovery
   study script as the seed; run a gaussian control first.
3. If a real convergence issue exists: it's Λ-side low-rank identifiability, NOT the Ψ (do
   NOT zero the non-Gaussian between-unit Ψ — it's identifiable).
4. Delta latent-on-main wiring per Design 02 (positive-part residual; occurrence guard).
5. phy/spde slope-tier runtime airtighten; pkgdown; Mission Control.
6. Surface the **push-to-main decision** to Shinichi.

## Blockers / Open Questions

- Does a real (sdreport-confirmed) delta latent convergence problem exist? Unproven — the
  earlier signal was spurious.
- Shinichi's push-to-main / PR call (273 commits ahead).

## Gotchas & Failed Approaches (do NOT retry)

- **`isTRUE(fit$sdr$pdHess)` is a PHANTOM on default fits** (`fit$sdr` is `NULL`). I built a
  multi-commit "non-Gaussian Ψ gate" diagnosis on it — all retracted. Rule: verify the object
  exists; run a control case EARLY; trust recovery-vs-truth over second-order flags.
- **Do NOT "zero the non-Gaussian Ψ"** — the confound-free recovery study shows it recovers.
- **Do NOT hand one subagent a broad multi-file task** — `general-purpose` subagents (which
  have the Agent tool) hallucinate an orchestrator role. Scope ≤~5 files, forbid spawning.
- The register's `gllvmTMB_auto_residual_delta_undefined` class **does not exist** — swept out.

## How to Resume

Fresh Claude session, from repo root:
```
claude "Rehydrate from docs/dev-log/handover/2026-07-05-claude-handover.md (last section) +
the AGENTS.md snapshot, read the session-closure + Codex-handoff notes, spawn Rose, then
continue with the Next Immediate Steps. This env runs live R/TMB. Do NOT push to main / open
a PR without Shinichi. pdHess check needs sdreport."
```
Read order: this doc → [session closure](../after-task/2026-07-05-completion-arc-session-closure.md)
→ [Codex handoff](../2026-07-05-codex-handoff-completion-arc.md) (has the retraction banner) →
AGENTS.md/CLAUDE.md. `~/.claude/memory/memory_summary.md` carries the D-28 principle + this
session's corrections.

## Mission / Goals (the durable "why")

Finish the gllvmTMB R/TMB **completion arc** — evidence-locked M1–M5 (profile-route truth,
missing/mixed, structural-slope hardening, non-Gaussian safety, release-hardening) — BEFORE
reopening Julia/GLLVM.jl parity. Claude leads audits/design/claim-boundary/prose; here Claude
also runs the live R/TMB (env compiles). Guards: no push/PR-to-main without Shinichi; no
mixed-family CI claims; no pdHess as calibrated-CI evidence; no Julia-parity broadening.

## Mission control

| Milestone | State | Next actor |
|---|---|---|
| Fold-arc merge | ✅ green (4168/0), check 0/0/0, pushed | Shinichi (push-to-main call) |
| M1 truth matrix | ✅ done (Design 75, verified) | — |
| M2 missing/mixed | ✅ design + marker shipped; delta wiring pending | next Claude (live) |
| M3 structural slope | ✅ unit_slope confirmed; phy/spde pending | next Claude (live) |
| M4 non-Gaussian safety | ✅ audited; pdHess thread retracted; Ψ identifiable | next Claude (sdreport repro) |
| M5 release-hardening | ✅ prose swept; pkgdown/Mission Control pending | next Claude (live) |
