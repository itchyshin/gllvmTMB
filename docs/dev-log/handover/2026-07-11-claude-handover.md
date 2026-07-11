# gllvmTMB — Claude handover, 2026-07-11

**Supersedes** `2026-07-10-claude-handover.md` (which framed the release as
"v1.0.0 release-ready"). That framing is retired — see below.

## Headline: first CRAN release is 0.5.0, NOT 1.0 (D-42)

A 5-perspective panel (Rose, Pat, Emmy, Curie, Darwin) voted **5–0** to number the
first CRAN release **0.5.0**, grounded in the capability docs. Rationale, evidence,
and the full file list are in `docs/dev-log/after-task/2026-07-11-version-0.5.0-renumber.md`
and brain decision **D-42** (`~/shinichi-brain/memory/DECISIONS.md`). One-line why:
interval coverage failed its production gate (CI-08/CI-10), delta/hurdle latent-scale
correlation is "do not advertise", the API was still moving (grid 4×5→4×4) days
before tagging, and 1.0 is reserved (D-40) for the maturity milestone gllvmTMB has
not met (Julia parity, the paper, the coverage campaign all still ahead).

## State

- **Engineering unchanged and solid:** all five arcs A–E merged (#737–#745) on `main`
  `e4188105`, cross-OS `--as-cran` 0E/0W/0N, 4478 tests / 0 failures. NOT submitted
  to CRAN.
- **Renumber sweep landed** (this session, in the working tree — **not yet
  committed**): DESCRIPTION, NEWS, cran-comments, README, inst/CITATION, _pkgdown
  comment, CLAUDE.md status line, and the issue-closeout script's release-identity
  strings all read 0.5.0. Verified: DESCRIPTION == NEWS-top == `0.5.0`, NEWS parser
  clean. Repo previously carried three version numbers (1.0.0 / 0.2.0 / 0.2.0) — now
  unified to 0.5.0.

## The live task — the one-by-one doc walk (IN PROGRESS)

**Method (Shinichi's chosen workflow):** for each pkgdown page, run a **Pat / Rose /
Fisher** review panel (a `Workflow`: new-user/CRAN, claim-vs-evidence honesty,
statistical correctness), reusing a **shared estate-map** built once from the
landing-page skim (no re-skim per page). Present the three comment sets + a
consolidation; Shinichi decides; fix on his call; commit per page. Give him the live
`/articles/<slug>.html` link for each page (live = pre-fix deploy until rebuilt).

**Standing checks every page must pass** (the estate-map carries these):
- **Honesty fencing:** every interval marked recovery-grade / coverage NOT calibrated
  (CI-08/CI-10); diagnostics are displays, not calibration; delta/hurdle latent-scale
  correlation = do-not-advertise.
- **No register-code leak:** `MIS-*/DIA-*/RE-*/MET-*/MIX-10/CI-08/10` belong only in
  tier-3b/register, never reader-facing prose.
- **Orientation:** the NOT-PCA/NMDS contrast (model-based ordination) where a page
  shows ordination; raw loadings paired with the rotation caveat + `getLoadings()`,
  not `fit$report$*`; EXPERIMENTAL / 0.5.0 / pre-CRAN stated IN PROSE.
- **⭐ Stale / time-relevant content (Shinichi, standing, 2026-07-11):** flag anything
  that was accurate when written but now needs updating — internal dev-process leaks
  ("under audit", "rendered HTML review pass"), "coming soon" / roadmap tables, old
  version refs, superseded claims. First instance: the morphometrics "What this
  article does not cover" rung table (trimmed to a plain scope sentence).
- **Grid is 4×4** (reconciled); the `unique()` deprecation history stays out of reader
  docs.

**Progress:** Page 1 Landing (README, `e9dbe709`) · Page 2 Get-started (`70ad03fd`) ·
Page 3 Morphometrics (`2db7ff4d`) — all panel'd + fixed. **Next: Page 4** per the
reader path (model-selection-latent-rank, then joint-sdm / covariance-correlation).

Open alongside: the QG **`animal-model`** cut/keep call; the mis-slugged
`simulation-recovery-validated` article (repo-wide rename is a maintainer act);
`choose-your-model` routing to internal-draft pages. PR #746 is **merged** (into main
and the release branch).

## Maintainer acts pending (Shinichi's, not the agent's)

1. Commit/land the renumber sweep (agent left it uncommitted for review).
2. Run `dev/issue-closeout-2026-07-10.sh` (agent safety-blocked from bulk closes;
   strings already reworded to 0.5.0).
3. Tag **`v0.5.0`** (no `v1.0.0` tag exists — nothing to rename); cut the GitHub
   release as `v0.5.0`.
4. One clean `devtools::check(args="--as-cran")` before submission (Codex lane).
5. The CRAN submission itself.

## Resume

Read this file + `docs/dev-log/after-task/2026-07-11-version-0.5.0-renumber.md` +
D-42. Then continue the one-by-one pkgdown/function-doc walk with Shinichi. Earlier
arc detail: `docs/dev-log/handover/2026-07-09-claude-handover-arcs.md`. Standing
guard: `phylo_latent(unique=TRUE)` = structured + DIAGONAL ψ, NOT a non-phylo
ordination.
