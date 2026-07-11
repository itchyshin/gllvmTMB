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

## The live task — the reason for today (NOT done)

**The one-by-one human review of the pkgdown pages and function docs, WITH
Shinichi** — slow, deliberate, page by page; not a batch rewrite. This is where the
honesty-fencing lands and where 0.5.0 becomes CRAN-*ready*:

- intervals framed **recovery-only**, not coverage-calibrated;
- delta/hurdle latent-scale correlation stated **unsupported** ("do not advertise");
- the mis-slugged `simulation-recovery-validated` article (its own banner already
  says it is NOT coverage-validated) — repo-wide rename is a maintainer call;
- the `api-keyword-grid` 4×4-vs-4×5 arity contradiction vs CLAUDE.md/_pkgdown.yml;
- `choose-your-model` still routing readers to internal-draft pages;
- `response-families.Rmd` renders zero numbers (global `eval=FALSE`).

Open alongside: **PR #746** (automated article cleanup — 2 cut, 26 improved, pkgdown
reorganised) and the QG **`animal-model`** cut/keep call.

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
