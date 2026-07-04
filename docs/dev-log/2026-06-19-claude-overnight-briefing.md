# Claude overnight run — morning briefing (read me first)

Run window: 2026-06-19 ~18:40 MDT → overnight. Agent: Claude Code (Ada,
orchestrating; ultracode). Maintainer away; worked autonomously within the
handover's hard guards.

**Hard guard held all night:** PR green != bridge complete != release ready !=
scientific coverage passed. Nothing was merged, version-bumped, or
scientifically promoted. No formula-grammar / likelihood / family / TMB change.
GLLVM.jl / PR #101 untouched. The only push was the one you authorized (#492).

---

## UPDATE 2026-06-20 ~05:30 MDT — merge wave (you authorized "merge everything")

- ✅ **PR #492 merged → `main`** (squash a1bcd49): bridge admission landed.
- ✅ **#489 closed** (superseded); no stale draft.
- ✅ **PR #493 merged → `main`** (squash 15b7482): full overnight integration
  (S1 cbind + S2 corr point-only + S3 hardening + gllvm_julia_fit example +
  normaliser tests + latent/traits/animal examples + 15 input-validation
  guards). Verified: full pure-R FAIL 0 / PASS 3155, live Julia bridge FAIL 0 /
  PASS 1228, pkgdown clean, no doc drift; CI green.
- ✅ **PR #494 merged → `main`** (squash 69c7674): coevolution multi-kernel TMB
  engine + COE-03/04 gates (new exports `predict_cross_covariance`,
  `profile_cross_rho`, effect-scale `extract_Gamma`). Verified full pure-R
  FAIL 0 / PASS 3191, heavy gate FAIL 0 / PASS 424; CI green. COE-03/04 stay
  `partial` (no register promotion).
- ⏳ **Partial-closure batch 1** (add-evidence-only fan-out, Rose-audited):
  EXT-10 cutpoint breadth, FG-14/MET-01 single-V `meta_V` `glmmTMB::equalto()`
  comparator, LAM-02 Gaussian recovery, FAM-15 truncated (nbinom1 hard-stopped),
  MIS-09 plot-snapshot QA — each verified in its own worktree, then batched into
  one PR. None promotes a row; Rose logged row-owners (EXT-10 is under-marked,
  not under-tested). COE doc-hedge + COE recovery cells (A6, A1–A5) next, off the
  now-coevolution-bearing `main`.
- 🔴 **unique-Psi split HELD for you** — a broad convention migration editing
  AGENTS.md / CLAUDE.md / NEWS + dozens of files, and it conflicts on check-log.
  I will not force a grammar/rule-file cascade in unreviewed. Clean split branch
  `codex/unique-latent-psi-split-20260619` is ready for your call.
- 🔴 **120-commit dirty branch** (`codex/r-bridge-grouped-dispersion`:
  dashboard/articles + the *uncommitted-only freshest* coevolution work) needs
  your reconciliation — not cleanly mergeable by me without risk.

## TL;DR — what you need to decide (🔴 = needs you)

1. 🔴 **Merge PR #492** (clean bridge-admission split, JUL-01/JUL-01A). Routine
   PR CI green; held for your approval (high-risk code PR).
2. 🔴 **Dispose of draft #489** — superseded by #492 for the bridge lane. Close,
   or repoint?
3. 🔴 **Three staged local branches** (un-pushed, PR-free, all verified green) —
   decide whether to PR/merge:
   - `claude/doc-examples-20260619` (doc-only, off `main`; 870f374 + facd82b —
     12 functions documented)
   - `claude/bridge-followups-20260619` (doc + tests, off `c061ce2`/#492 head;
     full suite FAIL 0 / PASS 3114)
   - `claude/input-validation-tests-20260619` (tests-only, off `main`; edb6dc1 —
     15 guards, FAIL 0 / PASS 76)
4. 🔴 **CLAUDE.md:120 dangling reference** — cites a ROADMAP "Discussion
   Checkpoints" section that no longer exists; the right replacement target is a
   doc-authority call (see "Flagged, not fixed" below). Left unedited.
5. 🔴 **Paired-`unique()` examples convention** — a grounded sweep found ~20
   exported diagnostic/profile/extractor functions lacking `@examples` whose
   only known-good fixtures use the **soft-deprecated paired `latent()+unique()`**
   form (e.g. `profile_repeatability`, `extract_ICC_site`, `getResidualCov`).
   Paste-ready drafts exist but I deferred them: publishing them would teach
   deprecated syntax, and a naive `unique()`→`indep()` swap can change model
   structure (risks a redundancy abort). Decide: publish the compat form, or
   hand-author `indep()`/default-`latent()` equivalents? Drafts preserved in the
   finder output (see the doc/test sweep note below).
6. 🔴 **Sign off S1 (cbind binomial bridge)** — a response-grammar change on
   `claude/bridge-finish-20260619`, built + LIVE-verified (exact parity), but
   per CLAUDE.md grammar changes need your sign-off before merge.
7. 🔴 **Julia "done" = land PR #101 + reconcile + land #492** (your authority).
   The Julia engine is largely **built in #101, not missing** — see the
   "Julia + R-bridge finish push" section and the finish-map.

Everything else below is FYI / evidence.

---

## What landed tonight (all non-destructive)

### A. Bridge lane → PR #492 (you authorized the push)
- Pushed the clean bridge split `codex/bridge-admission-split-20260619` @
  `c061ce2` and opened **PR #492**. 5 commits on `main` 0567cd7, 33
  bridge-scoped files. Supersedes the bridge portion of draft #489.
- Routine PR CI green: `recovery` + `ubuntu-latest (release)`, mergeable.
  **Note on "3-OS":** routine PR CI is ubuntu-only *by design* (cost discipline
  in `R-CMD-check.yaml`). The 3-OS matrix runs only pre-release
  (`workflow_dispatch` `full_matrix=true`) or in the nightly `full-check.yaml`.
  So the split does NOT yet have 3-OS evidence — run one before release.

### B. Mission-control dashboard truth pass (you asked to look at the widget)
- `docs/dev-log/dashboard/status.json` + `sweep.json`: named PR #492, reframed
  the stale "#489 is the bridge" cards, "split next" → "split executed",
  cross-linked the real release-gating coverage rows CI-08 (13/15 cells below
  the 94% gate, 236/3000 fits failed) and CI-10 (mixed-family d=1 0.820 /
  d=2 0.685 / d=3 0.550, 105/600 failed) into the Power-pilot card.
- Version r37 → r38 in `version.txt` AND `index.html` `const BUILD` (both
  required or the live board hot-reload-loops). Served on 8770/8765 (both 200).
- Fixed an overclaim I initially introduced ("3-OS matrix in progress") after
  reading the CI config — corrected across dashboard + dev-log.

### C. Documentation slices (DoD doc-completeness)
- `claude/doc-examples-20260619` (off `main`, commit `870f374`):
  - **S7**: added `@examples` to `latent()` and `traits()` — the two headline
    grammar entry points had none. Grounded in known-good calls
    (`simulate_site_trait()` long; README canonical `traits(t1,t2,t3) ~ 1 +
    latent(1|unit,d=2)` wide). Default-Psi convention; no `unique()`.
  - **OC1**: corrected the stale `_pkgdown.yml` comment claiming the v0.2.0
    tag/release "does not exist yet" (both exist: tag 416f8e4; release
    2026-06-04). Comment-only — did NOT add a `releases:` block (your call).
  - Verified: `document()` clean, `pkgdown::check_pkgdown()` clean,
    `git diff --check` clean. Unrelated `extract_correlations.Rd` roxygen drift
    reverted to stay surgical.
- `claude/bridge-followups-20260619` (off `c061ce2`, commit `9f16865`):
  - **S8**: added a `\dontrun` `@example` to `gllvm_julia_fit()` (exported,
    had none), grounded in its real signature.
  - **S5 deliberately skipped**: `gllvm_julia_gate_registry()` already
    self-documents via `@return` + a `head()` example; enumerating 19 volatile
    gate ids in prose would only add drift.
  - **S1–S3 (done, commit `6b55884`)**: pure-R negative tests for the bridge
    normaliser `stop()`/status branches (`.gllvm_julia_normalise_result`,
    `.gllvm_julia_normalise_ci`, `.gllvm_julia_mask_placeholder`).
    Independently re-verified by the orchestrator:
    **FAIL 0 | WARN 0 | SKIP 14 | PASS 373** (baseline 357; +16; no new skips —
    the 14 skips are the unchanged live-Julia rows).

### D. Dev-log / evidence closure
- `docs/dev-log/check-log.md`: full session entry.
- `docs/dev-log/after-task/2026-06-19-overnight-bridge-pr492-dashboard.md`.
- `docs/design/35-validation-debt-register.md`: JUL pointer note naming #492
  (rows stay `partial` — nothing promoted).
- Recovery checkpoints under `docs/dev-log/recovery-checkpoints/`.

---

## Julia + R-bridge finish push (late in the run) — READ THIS

Grounded by a 4-investigator sweep + verified live toolchain (Julia 1.10.0 at
`~/.juliaup/bin`). Full scope: [bridge finish-map](2026-06-19-bridge-finish-map.md);
detail: [after-task](after-task/2026-06-19-julia-bridge-finish-slices.md).

**⭐ The key finding:** the "heaps of Julia stuff" is largely **already built and
tested — it lives in PR #101's tree** (the integration engine, f7be594, which
powers 1212 passing live bridge tests across all 8 families + X + masks + mixed +
grouped-dispersion + simulate + Wald/profile/bootstrap CIs). **Finishing the
Julia side is a landing/reconciliation + merge-decision program, not a
Julia-coding sprint.** I deliberately did NOT re-implement #101's features on the
local engine — that would only create merge conflicts.

**Verified, un-pushed branches from this push:**
- `claude/bridge-finish-20260619` (off c061ce2) — **S1** cbind(succ,fail)
  binomial routing (d2b3e2f; LIVE-verified, exact parity Δ=0; ⚠ response-grammar
  change → **your sign-off** before merge), **S2** extract_correlations point-only
  for julia (cec51a9), **S3** gate hardening (6217540). Combined LIVE FAIL 0 /
  PASS 1212; pure-R +17.
- `claude/jl-bridge-capabilities-20260619` (GLLVM.jl, off
  codex/non-gaussian-fitter-gradients, NOT #101) — **J2** honest local
  `bridge_capabilities()` (34e8d93) + after-task (e81eabc); runtests exit 0,
  60/60 new, two honesty divergences from the integration table fixed to local
  reality (ordinal Wald true; simulate false).

**The path to "Julia + bridge done" (your-authority steps):**
1. land PR #101 (wide engine) → GLLVM.jl `main`;
2. reconcile the narrow local engine with it;
3. land gllvmTMB bridge PR #492 + decide bridge family/feature exposure;
4. promote JUL-01/JUL-01A with parity evidence.
The only genuinely-new autonomous Julia work that isn't duplicating #101 is
research-shaped (analytic Wald Hessians, etc.) — available on request, but it is
not what "bridge done" means.

## Doc/test hardening sweep (earlier in the run)

A grounded finder pass (4 module auditors + Ada rank) inventoried the package's
`@examples` gaps and cleanly-reachable untested error branches: **32 example
drafts + 15 pure-R input-validation test slices**, each cited to a known-good
source. Two isolated worktree branches apply the **convention-safe** subset
(final commit SHAs + counts in the after-task report
`docs/dev-log/after-task/2026-06-19-overnight-doc-test-hardening.md`):

- `claude/doc-examples-20260619` — `@examples` for `gllvmTMBcontrol` (runnable),
  `flag_unreliable_loadings`, `meta_V`/`meta_known_V`, and the six `animal_*`
  keywords. (latent/traits already landed earlier.)
- `claude/input-validation-tests-20260619` (off main) — pure-R `expect_error`
  tests for documented aborts in `make_cross_kernel`, `pedigree_to_A`,
  `flag_unreliable_loadings`, the `gllvmTMB()` REML guard, and profile helpers.

Deferred for your decision (item 5 above): the ~20 paired-`unique()`
diagnostic/profile/extractor example drafts. The full grounded draft set is in
the finder output (workflow run, "PART 1/PART 2"); I can apply your chosen form
on request.

## Flagged, NOT fixed (need your judgement)

- **CLAUDE.md:120** cites `ROADMAP.md "Discussion Checkpoints"` as the
  authoritative high-risk set, but `grep "Discussion Checkpoints" ROADMAP.md`
  returns 0 (lost in a reset). Candidate canonical homes: ROADMAP's
  Article-Gate-Matrix / Infrastructure-Gates, or CLAUDE.md's own
  "Merge authority" section. I left CLAUDE.md unedited — you pick the target.
- **fig.alt accessibility gap** in 7 flagged articles (cap present, alt=0). NOT
  done tonight: the canonical article version is unresolved (~271 lines of
  uncommitted article rewrites on the dirty branch), so editing a clean split
  would clobber the rewrite on merge. Canonicalize the article version first.

---

## Release-blocker map (unchanged tonight; for planning)

- CI-08 / CI-10 coverage rows failing (M3.3 production gate; mixed-family).
- #486 final release-branch `--as-cran` evidence (blocked).
- #349 HPC unrun.
- JUL bridge partial vs #488; COE-03/COE-04 partial (no in-engine rho, no rho
  intervals, no Type-I calibration, narrow non-Gaussian breadth).
- #492 (and #489) merge order unresolved.
- lambda-constraint non-PD Hessian Confidence-Eye figure blocks that article.
- Version identity: DESCRIPTION 0.2.0 vs NEWS "(development version)".

## Decision-gated (left for you; not touched)
Merge/branch/release authority; any register-row promotion; in-engine rho /
intervals / Type-I calibration; module rank/uncertainty; broad non-Gaussian
coevolution breadth; `*_unique()`/`kernel_unique()` lifecycle (grammar); any
GLLVM.jl edit; navbar "make public" promotions; version bump / CRAN submission.

## How to inspect
- Dashboard: `http://127.0.0.1:8770/` (or 8765). Source
  `docs/dev-log/dashboard/`; after edits `rsync -a docs/dev-log/dashboard/
  /tmp/gllvm-dashboard/`.
- Branches: `git branch --list "claude/*"`; `git log --oneline main..claude/...`.
- PR #492: `gh pr view 492`; `gh pr checks 492`.
