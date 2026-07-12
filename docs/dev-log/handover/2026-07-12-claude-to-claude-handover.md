# gllvmTMB — Claude → Claude handover (2026-07-12, PM)

Meta: 2026-07-12 · from Claude · handover at high context. Supersedes the AM
Codex→Claude handover (`2026-07-12-claude-handover.md`) for current state.
Branch: `claude/release-0.5.0`, tip pushed to origin.

## Critical Context (read or you will go wrong)

1. **The strategy PIVOTED.** We are **no longer rushing 0.5.0 to CRAN.** Shinichi
   decided (this session): first **build up capabilities** so the first CRAN
   release is *"systematic, not comprehensive, but quite finished and usable for
   particular structures and particular common distributions."* The old
   "ship thin 0.5.0 now, defer to 1.0" plan is superseded.
2. **Locked scope** for the finished first release:
   - **Distributions:** gaussian, poisson, nbinom1, nbinom2, binomial (core only).
   - **Structures:** ordinary (scalar/indep/dep/latent) + phylogenetic + **spatial (SPDE)**.
   - **Slopes:** FULL scope — intercept + ≥1 slope across unit/unit_obs/cluster/cluster2
     tiers AND ordinary indep/dep (the biggest engine item).
   - Deferred: beta, Gamma, tweedie, student, gengamma, truncated, categorical,
     delta/hurdle latent-corr, animal QG, full coverage calibration.
   - "Finish a cell" = engine fits + recovery evidence + diagnostics + missing-data + docs.
3. **Codex is OUT for ~3 days.** Claude leads the campaign. "Whichever platform is
   in-session owns what the task needs" — you can run live R (fits, tests, checks)
   yourself; do it.
4. **Hand over to a fresh Claude session at ~90% context** (Shinichi's standing
   instruction). Resume from this doc + the two campaign docs below.

## What Was Accomplished (this session)

- Rehydrated; fresh Rose pre-publish audit → docs honest, nothing blocking.
- Committed the release-prep estate in reviewed slices (article finalization,
  export trim, accessors) — see Landing State.
- **NA-guard fix** (`extract_Sigma`/`Omega` `if(any())` on NA link-residuals).
- Added **`extract_loadings()` + `extract_residual_cov()`/`extract_residual_cor()`**
  snake_case accessors (getLoadings etc. stay as gllvm-compat).
- **Navbar deploy-gap** diagnosed: the fix is on the branch; the public site
  deploys **only from `main`** (workflow trigger + github-pages env rule), so it
  lands at the release merge. Lesson filed (repo + brain + a new
  `pkgdown-deploy-from-main` skill auto-compiled).
- **Capability-surface widget** (Artifact) built + iterated to a gap-map:
  https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d
- **Phase-0 capability audit** (4 parallel agents) → consolidated gap map.
- **Tier-1 bugs, 4/4 fixed + tested** (see Landing State).
- **Tier-3 coverage started:** non-Gaussian missing-response (poisson/nbinom2/
  binomial) sentinel-invariance tested. README missing-response row qualified.
- Confirmatory `--as-cran` = **0E/0W/1N**; full suite FAIL 0 / PASS 4471.

## Current Working State

- **Working / green:** current tree passes `--as-cran` 0E/0W/1N; full suite FAIL 0.
- **In progress:** the capability build-up campaign (Tier 3 coverage started).
- **Attempted, reverted:** an nbinom1 × `phylo_dep` recovery cell — it SKIPPED on
  seed 101 (non-convergence / band). nbinom1 structured recovery needs a proper
  **seed sweep + band tuning** per the strict `test-tiers-nbinom1.R` convention
  (Phase-2 discipline). Reverted so no always-skipping test was left behind.

## Key Decisions & Rationale

- **0.5.0 = build-to-focused-scope, not thin-now** (Shinichi, 2026-07-12). Supersedes
  the earlier D-42 "ship thin" framing for *timing* (0.5.0 is still the version).
- **Slope scope = FULL** (unit_obs/cluster2 + ordinary indep/dep).
- **getLoadings/getResidual* kept** as gllvm-compat; snake_case aliases added.
- **T1.3 half is intended:** `extract_repeatability(method="profile")` fallback is
  tested design (test-profile-ci.R), not a bug — left alone.
- **Navbar fix rides the release merge**, not a branch deploy (env guard is
  intentional; not overridden).

## Landing State

| Artifact / branch | Committed | Pushed | State |
|---|---|---|---|
| `claude/release-0.5.0` tip `c2d93609`+docs | y | y (through c2d93609) | LANDED (feature branch; NOT merged to main) |
| Article finalization `eacbd0f6` · export trim `660b9178` · NA fix `6f84b3f0` · accessors `eef85ef1`,`b18b683b` · lesson `5a569660` · Tier-1 `aa76b84c`,`4dfd2e2b`,`db9ecb06`,`f7c0198b` · missing-resp `c2d93609` | y | y | LANDED |
| Campaign docs (gap map + plan) | pending this commit | — | LANDING NOW with the handover |
| **Held files**: `.Rbuildignore`, `.github/workflows/pkgdown.yaml`, `CONTRIBUTING.md`, `ROADMAP.md` | n | n | **CARRIED-OVER** — Shinichi's disposition decision (task #5); not in the A/B/C slices. Resume: inspect diffs, decide commit-or-drop with Shinichi. |
| Draft-restoration tracking (Shinichi chose "tracking issue/doc, keep deleted") | n | n | **CARRIED-OVER** — create an "Article restoration queue" issue/doc from the 15 cut articles' return conditions in `docs/design/61-capability-status.md`. |
| `main`, `v0.5.0` tag, CRAN | untouched | — | Shinichi's calls; paused |

## Next Immediate Steps (Claude-doable, priority order)

1. **🔴 `scalar()` (no-prefix) + `kernel_scalar()` — DO THIS FIRST (Shinichi,
   flagged twice; approved for 0.5.0, task #7).** Fills the two `—` cells in the
   covariance grid (none→scalar, kernel→scalar). `scalar` = one shared trait
   variance, zero cross-trait covariance (see the grid footnote). Parser is
   Claude-doable; check whether the engine already has a shared-variance path
   (indep with all θ tied via `tmb_map`, like `common = TRUE`) so no TMB C++
   change is needed. Add parser + engine wiring + tests + roxygen; then update
   `api-keyword-grid.Rmd` (fills the two cells; reconcile vs `indep(common=TRUE)`)
   AND flip those two widget cells from `—` to live. Do NOT expand scalar to carry
   a slope (that's 1.0).
2. **nbinom1 recovery cells** (thinnest family) — `phylo_dep`/`phylo_latent`/
   `spatial_dep`/`spatial_latent`. Match `test-tiers-nbinom1.R` convention: seed
   sweep for conv+PD Hessian, inherited bands, honest-skip. A first `phylo_dep`
   draft was attempted this session and skipped on seed 101 — sweep seeds.
3. **Non-Gaussian `mi()` predictor coverage** — audit confirmed it works (probes
   in `scratchpad/audit-missing.md`); write equivalence/health tests.
4. **T2.3 binomial exact-residual diagnostic** (moderate R).
5. **Refresh `61-capability-status.md`** (stale 2026-06-28) from the verified audit
   (the widget is already being kept current — see the standing rule above).
6. **Heaviest, later / cautious:** T2.1/T2.2 structural slopes (unit_obs/cluster2,
   ordinary indep/dep) + the Phase-2 recovery campaign on **Totoro/DRAC**.

Run heavy tests with `GLLVMTMB_HEAVY_TESTS=1`.

## Blockers / Open Questions

- Held-files disposition (task #5) — Shinichi.
- Merge/tag/CRAN — paused, Shinichi's call.
- Visual/mobile QA of rendered pages (task #2) still undone.

## Gotchas & Failed Approaches

- **Heavy tests skip** unless `GLLVMTMB_HEAVY_TESTS=1` (setup.R). A "PASS 0 / SKIP n"
  means the flag was unset, not that the tests ran.
- **Background `Rscript --as-cran` launches were intermittently permission-denied.**
  A plain `run_in_background: true` Rscript (no nohup, no `dangerouslyDisableSandbox`)
  worked once approved; the local Mac needed 8 Suggests installed (now installed:
  DHARMa future future.apply ggforce galamm mirt vegan vdiffr).
- **nbinom1 + structured recovery needs seed sweeps** — don't expect first-seed
  convergence; the file documents this. Match the "never relax an assertion,
  honest-skip instead" rule.
- **Public pkgdown site deploys only from `main`** — never claim a reader-facing
  fix is live from a branch commit or local render.
- Raw params compare unfairly under d=1 loading sign ambiguity — compare
  `extract_Sigma` (rotation-invariant), not `opt$par`.

## How to Resume

**FIRST, show the capability-surface widget** (Shinichi's standing rule — it opens
every new lane): live at
https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d ; source at
`docs/dev-log/capability-surface.html`. **Keep it current as you go** (edit source →
`Artifact(url=<that URL>)` to redeploy in place → `cp` back to the repo path → commit).

Then read, in order: this doc → `docs/dev-log/2026-07-12-capability-buildup-campaign.md`
(campaign plan + live status; the widget's standing rule is recorded there too) →
`docs/dev-log/2026-07-12-capability-audit-gapmap.md` (the tiered gap map) → the four
`scratchpad/audit-*.md` reports if you need cell-level detail. Then continue the Next
Immediate Steps. Spawn a Rose/statistical-reviewer lens before any "finished cell" claim.

One-command resume (paste in an authenticated terminal):

```sh
claude "Rehydrate from docs/dev-log/handover/2026-07-12-claude-to-claude-handover.md + the two campaign docs. First show me the capability-surface widget (docs/dev-log/capability-surface.html / its artifact URL), then continue the capability build-up. START with scalar() + kernel_scalar() (Shinichi's top priority, task #7), then nbinom1 recovery cells. Keep the widget updated as you go."
```
