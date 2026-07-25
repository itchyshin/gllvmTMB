# Design — repair the pkgdown build (TMB/glmmTMB ABI mismatch) and gate its deploy

**Date:** 2026-07-25 · **Author:** Claude · **Branch:** `claude/pkgdown-tmb-abi-20260725`
(off `main` @ `b87ab9ed`) · **Status:** approved by maintainer, ready to implement

This is a CI and documentation-infrastructure change. It touches **no package source**,
so it does not reopen the M3 API freeze (`NAMESPACE` SHA-256 `c97ae039`, 153 exports /
33 S3 methods). It makes no release, coverage, or capability claim.

## 1. Problem

The pkgdown workflow fails on `main`. Two consecutive runs failed (`fe8388d9`,
`b87ab9ed`); the `R-CMD-check` runs at the same commits **passed**. The rendered public
documentation site is therefore not being republished.

Root cause, from the failing run log:

```
Warning message:
In check_dep_version(dep_pkg = "TMB") : package version mismatch:
  glmmTMB was built with TMB package version 1.9.21
  Current TMB package version is 1.9.23
  Please re-install glmmTMB from source or restore original 'TMB' package
Execution halted
```

The chain is: `r-lib/actions/setup-r-dependencies@v2` with `needs: website` installs a
**binary** `glmmTMB` compiled against TMB 1.9.21, while the runner resolves TMB **1.9.23**
from the public RSPM. `pkgdown::build_site()` renders articles that load `glmmTMB`;
`base::dyn.load()` fails on the ABI mismatch; the job exits 1.

`glmmTMB` is a `Suggests` dependency used by the cross-package comparator articles and
tests. It is not optional for the site build, because `needs: website` pulls it and the
articles load it.

## 2. Why this cannot be verified locally

The project's standing rule is local checks before CI. **This defect is invisible
locally and that rule is deliberately excepted here.**

Verified on the maintainer's machine: local TMB is **1.9.21**, `glmmTMB` loads
successfully, and so do `gllvm` 2.0.11, `MCMCglmm` 2.36 and `metafor` 5.0.1. A local
`pkgdown::build_site()` would therefore succeed **whether or not the fix is correct** —
it exercises a matched pair the runner does not have. Local success would be evidence of
nothing.

CI is the only surface on which this defect is observable. The exception is recorded here
rather than taken silently.

## 3. Design

Three independent units. Units 1 and 2 are one file; unit 3 is in the vault.

### Unit 1 — make the TMB-linked dependency ABI-consistent

**File:** `.github/workflows/pkgdown.yaml`

After `setup-r-dependencies` and before `Build site`, rebuild `glmmTMB` from source so it
links against whatever TMB the runner actually resolved:

```yaml
- name: Rebuild TMB-linked packages from source
  run: install.packages("glmmTMB", type = "source", repos = "https://cloud.r-project.org")
  shell: Rscript {0}
```

**Interface:** the step's contract is "after this step, every TMB-linked package the site
build loads is ABI-compatible with the installed TMB." It depends only on TMB already
being installed. Nothing downstream needs to know how it achieved that.

**Rejected alternative — pin TMB to 1.9.21.** It would fight CRAN's current version,
silently rot at the next TMB release, and pin the docs build to an increasingly stale
toolchain. Rebuilding from source tracks whatever TMB is current, which is the property
we actually want.

**Deliberately minimal.** Only `glmmTMB` is rebuilt, because only `glmmTMB` is
demonstrably broken. `gllvm` and `sdmTMB` are also TMB-linked and could in principle hit
the same wall; they are **not** pre-emptively rebuilt. If one surfaces, the step extends
by one package name. Speculative rebuilding costs CI minutes for a failure that has not
occurred.

### Unit 2 — gate the Pages deploy to the default branch

**File:** `.github/workflows/pkgdown.yaml` (same file, separate concern)

The `pkgdown` job admits `workflow_dispatch`:

```yaml
if: ${{ github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success' }}
```

and the final step is unconditional:

```yaml
- id: deployment
  uses: actions/deploy-pages@v4
```

There is **no branch condition on deployment**. Dispatching pkgdown on any branch
therefore builds *and publishes that branch* to the live public documentation site.

Add a branch guard so deployment happens only for the default branch:

```yaml
- id: deployment
  if: ${{ github.event.workflow_run.head_branch == 'main' || github.ref == 'refs/heads/main' }}
  uses: actions/deploy-pages@v4
```

The guard names `main` explicitly. The `workflow_run` trigger lists `[main, master]`, but
this repository's default branch is `main` and `master` does not exist; the `master` entry
is vestigial. Naming one branch keeps the expression readable, and the trigger's own
branch filter already prevents `workflow_run` from firing on anything else.

Both trigger shapes must be covered, because they expose the branch differently:
`workflow_run` supplies `github.event.workflow_run.head_branch`, while `workflow_dispatch`
supplies `github.ref`. A `workflow_run` event always executes in the default-branch
context, so its `github.ref` is `refs/heads/main` regardless — which is harmless here only
because the trigger's `branches:` filter already restricts it.

**Two reasons for the guard, and the first is the load-bearing one.**

1. **It makes unit 1 verifiable.** With the guard, `workflow_dispatch` on a fix branch
   *builds without publishing* — which is precisely the evidence needed, with no outward
   effect. Without it, verifying the fix requires either publishing a branch build to the
   public site or merging unverified.
2. It removes a standing hazard. The file's own checkout comments record a prior incident
   where a superseded tree was deployed (commit `a4310885`, "2 topics missing from
   index"). An unguarded deploy reachable from any branch is the same class of problem.

This is a targeted improvement to code being modified in service of the current goal, not
unrelated refactoring.

### Unit 3 — refresh the Mission Control board

**File:** `~/shinichi-brain/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`
(vault, local-only per D-37)

The board's `now` block is stale by the entire M4→M5 arc. It reads "M4 UNDERWAY" and
"draft PR #780"; verified against git, M4 closed, PR #780 **merged** 2026-07-23, and the
work advanced through RC.1 freeze, a 3/3 NOT-READY review, submission WITHHELD on
win-builder R-devel, an RC.2 honesty reword, and a recorded RC.2 non-CRAN closeout.

A stale board is not cosmetic: this session was rehydrated from it and planned against a
six-day-old picture. Two recommendations were withdrawn as a direct result.

Edit the **curated fields only** — `now`, `next_safe_action`, `active_lane`,
`resume.do_not_repeat`, `capability.note`. Per the mission-control skill, do **not**
hand-type capability counts (derived from the capability surface) or Pages URLs
(auto-derived and liveness-filtered). Commit to the vault with scoped staging, never
`git add -A`.

## 4. Verification

| Unit | How it is verified | What would falsify it |
|---|---|---|
| 2 | Land first. Dispatch pkgdown on the fix branch; confirm the deploy step is **skipped** | Deploy step runs on a non-`main` branch |
| 1 | Same dispatch run: "Build site" completes green | `dyn.load` / version-mismatch error persists |
| 3 | Reload `http://127.0.0.1:8823/p/gllvmTMB/`; `now` reflects verified git state | Board still shows M4 UNDERWAY or draft #780 |

Order matters: unit 2 must land before the dispatch, or the verification run publishes.

After both pass, merge to `main`; the normal `workflow_run` trigger then deploys from
`main` as designed.

**Landing the fix is what proves it end-to-end.** A green build on the branch shows the
ABI repair works; the post-merge deploy from `main` shows the guard did not break the
normal path. Neither claim is made before its evidence exists.

## 5. Out of scope

- **No package source or API changes.** M3 is frozen at `c97ae039`; this touches CI
  configuration and a vault status file only.
- **The held calibration overclaim** (`a9ecd29f`, "real overclaim in the central
  calibration claim, held for maintainer") is a maintainer decision and is untouched.
- **Peer-comparator validation** (`gllvm`, `MCMCglmm` model-fit, `metafor::rma.mv`) is
  the intended next slice and is not started here.
- **Worktree cleanup.** `git worktree list` shows 27 entries, of which
  `/private/tmp/gllvmtmb-060-m1-builder` is a directory whose git linkage is gone. 119
  directories sit under `/private/tmp/gllvmtmb-*`. Recorded, not acted on — reclaiming
  them is a separate decision with its own risk.
- **No release action.** No freeze, tag, submission, or readiness claim. The rung remains
  NOT READY.

## 6. Risks

- Source-compiling `glmmTMB` adds a few minutes of CI time per docs build. Accepted: the
  alternative is a permanently broken site.
- If another TMB-linked package loads during article rendering, it may fail next with the
  same signature. The unit-1 step extends by one package name; this is a known, bounded
  follow-up rather than an unknown.
- The branch-guard expression must cover both trigger shapes (`workflow_run` supplies
  `head_branch`; `workflow_dispatch` supplies `github.ref`). Getting one wrong either
  blocks legitimate deploys from `main` or leaves the hazard open. The dispatch run
  verifies the `workflow_dispatch` arm; the post-merge run verifies the `workflow_run`
  arm. Both arms are exercised before the change is called done.
