# Session Handoff: Cursor MSPL Estimator Arc Series

Meta: 2026-08-14 · from Codex to Cursor · planning session compacted once; scope frozen at the handover milestone

You are Cursor, taking over a long-horizon `gllvmTMB` programme in which LA-MSPL may earn a major role parallel to LA-ML. You inherit no chat history. This committed handover and the committed programme document are authoritative.

## Critical Context

1. **Laplace and MSPL are different axes.** Laplace approximates the latent/random-effect integral. LA-ML and LA-MSPL optimize different outer criteria built on that shared approximation. The exact marginal likelihood and its Laplace approximation are distinct quantities.
2. **This is a big arc series, not a bulk feature unlock.** The unit of admission is `family/link × boundary × covariance structure × parameterization`. Complete each bounded arc, stop at its evidence gate, and do not let success in one cell promote another.
3. **Two MSPL sibling lanes remain protected and separately owned.** Do not absorb, rebase, clean, stage, merge, or “finish” them from this lane:
   - `claude/design-117-separation-programme` in `/Users/z3437171/Dropbox/Github Local/gllvmTMB` — dirty design/separation lane;
   - `codex/lane-b-mspl-interval-feasibility` in `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB` — private uncertainty/jackknife/coverage lane, 14 local commits ahead of its remote when handed over.
4. **LA-ML remains default and reference.** The current LA-MSPL surface remains experimental, opt-in, point-estimation-first, and fenced. No inference, model-comparison, automatic-fallback, general-family, or default claim is earned.
5. **Hao's skepticism is a programme asset.** Every route must be capable of failing on scientific risk, prediction, calibration, penalty sensitivity, invariance, Laplace error, or usability. Finite/interior estimates alone never pass.

## Goals / Mission

Develop LA-MSPL as a rigorously falsifiable parallel estimator programme relative to LA-ML while preserving `gllvmTMB`'s current model grammar, scientific claim boundaries, and usability. Reuse the common R/TMB/Laplace engine, but admit penalty atoms only after symbolic alignment, numerical verification, known-DGP recovery, healthy-regime no-harm, and route-specific review.

The durable programme is:

- `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

Read it completely before planning or editing. It contains the equations, current evidence, literature limits, three-registry architecture, phased programme, validation design, stop rules, specialist concerns, and the first 10-hour slice.

## Plans / Roadmap

The series is ordered by evidence leverage. Only the first arc is immediately `OWED`; later arcs are `QUEUED` and require their own plan/evidence gate.

| Arc | Status at handover | Purpose | Terminal gate |
|---|---|---|---|
| **Arc 0 — rehydrate and reconcile** | **OWED first action** | Compare this dated handover with live git, GitHub, the protected lanes, and current `origin/main`; classify every item | Exact live-state receipt; no mutation before classification |
| **Arc 1A — internal provenance parity** | **OWED substantive arc** | Separate resolved integration, outer criterion, numerical kernel, and penalty provenance internally without changing results or accepted calls | Exact objective/gradient/report/warning/error/routing parity; Rose + Gauss/Noether PASS |
| **Arc 1B — public compatibility policy** | **QUEUED; separate approval** | Decide what explicit `estimator="ml"` means outside Laplace | API/lifecycle plan, docs/tests, explicit Shinichi approval |
| **Arc 2 — current Bernoulli registry/evidence** | **QUEUED** | Express existing logit/probit/cloglog and structure fences as registry cells; complete or rescope failure-inclusive B2 evidence | No surface widening; hard cells retained; point-estimation verdict only |
| **Arc 3 — matched Gaussian Heywood anchor** | **QUEUED** | Translate the Gaussian factor-paper boundary theorem into the exact `Sigma = Lambda Lambda' + Psi` route | Symbolic/TMB alignment, response-scale and rotation invariance, recovery and healthy no-harm evidence |
| **Arc 4 — Poisson** | **QUEUED** | Derive a new count-family information/boundary route from scratch | All-zero/near-zero and healthy DGP gates; exposure-aware information; no inherited Gaussian/binary claim |
| **Arc 5 — NB2 then NB1** | **QUEUED** | Separate mean and dispersion boundaries by parameterization | Family-specific recovery, prediction, penalty-sensitivity, and identifiability gates |
| **Arc 6 — ordinal/multinomial and other families** | **QUEUED late** | Treat cutpoint, contrast/simplex, bounded-mean, shape, and mixture limits separately | Per-family theory/evidence; no pooled admission |
| **Arc 7 — structured sources and mixed-family composition** | **QUEUED late** | Extend only proved homogeneous ordinary cells using source-specific invariant coordinates | Structure-specific recovery/invariance and connected-design coverage |
| **Arc 8 — inference/model comparison/policy** | **PROTECTED research frontier** | Define and calibrate uncertainty, comparison, recommendation/fallback/default statuses | Separate repeated-sampling and theory gates; never inherited from point-estimation success |

At the start of each substantive arc, use the repository's ultra-plan discipline: live preflight, brain/repo orientation, one bounded implementation plan, compute estimate, independent review, retained failures, after-task closeout, and a fresh task when the milestone closes.

## What Was Accomplished

- Rehydrated the 2026-08-12 handover and live repository state.
- Reconciled current `origin/main`, current MSPL R/TMB implementation, Design 88, NEWS, validation register, B2 partial evidence, issue ledger, and the active uncertainty lane.
- Read both supplied primary papers directly:
  - mixed-effects logistic MSPL, DOI `10.1007/s11222-023-10217-3`;
  - Gaussian factor-analysis MSPL, DOI `10.1017/psy.2026.10092`.
- Ran Ask Brain across projects and a grounded Notebook/Ranga skeptical prior-art campaign.
- Obtained independent reviews from Gauss, Curie/Fisher, Rose/Noether, and Ranga.
- Resolved two final P1s:
  - the programme now distinguishes `ell_marg` from the conditional-mode/Hessian Laplace approximation `ell_LA`;
  - Phase 1 is split into strict-parity internal Arc 1A and separately approved public-policy Arc 1B.
- Wrote and committed the authoritative programme document at `1e5a1d48`.
- Filed the Notebook distillation in the local-only Shinichi brain at commit `f392938`.
- Fired Notebook companion artifacts; they were pending at close:
  - briefing `35b920dc-7d7d-4290-8630-f97689c26f78`;
  - skeptical audio `73d92dc9-330e-430c-9537-4d7a7fcbb225`;
  - whiteboard video `281ba585-a75a-4ae0-b1b1-9a7ae5ee318d`.

## Current Working State

- **Working:** the programme document passes the formal after-task validator, `git diff --check`, claim searches, local-link checks, and final Rose/Noether review. Final verdict: PASS, no P0/P1 blocker.
- **In progress:** none in this branch. Arc 1A is not implemented.
- **Protected elsewhere:** the separation-design lane and interval/jackknife/coverage lane named above.
- **Blocked:** no statistical blocker to planning Arc 1A. The shared `2026-07-25-active-lane-split.md` is divergent across ten refs; it was deliberately not edited from this branch. Use this direct handover path, then re-derive lane state live.
- **Compute:** none authorized or required for Arc 1A. Any later fit/simulation needs a time estimate; above 30 minutes requires a pre-run receipt and fresh approval. Campaigns use Totoro/DRAC, never GitHub Actions.

## Key Decisions & Rationale

1. **LA-MSPL is a potentially major parallel research estimator, not a replacement default.** Positive binary evidence justifies investment; incomplete hard cells and absent general theory prohibit promotion.
2. **Use three registries:** family/link information, boundary/penalty, and route/evidence. This prevents one penalty from being generalized by convenience.
3. **Gaussian Heywood is the first new scientific route.** Its primary paper is the closest theory-to-implementation match. Poisson is next because it is a simpler new likelihood, but it still needs a new derivation.
4. **The mixed-logistic paper does not prove generic Laplace MSPL.** Its approximate-likelihood results require extra approximation conditions; numerical Laplace support is not a general theorem.
5. **Do not call the composite estimator ordinary MAP or Firth.** Only the fixed-effect atom is Jeffreys-based; loading/spatial atoms and scales are distinct GLLVM extensions.
6. **Inference constructions stay distinct:** penalized profile, penalty-off curvature at the MSPL point, estimator-refit bootstrap, and any future sandwich target are not interchangeable.
7. **No automatic silent fallback.** A future fallback requires a validated latent-design trigger, the same estimand, explicit user opt-in, and provenance for both attempted fits.
8. **Do not merge protected branches wholesale.** Extract only separately reviewed, current-main-based slices if later authorized.

## Files Created / Modified

### This ordinary repository branch

- `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- `docs/dev-log/handover/2026-08-14-cursor-handover.md`

### Separate local-only Shinichi brain commit `f392938`

- `projects/deep-research/dr34-la-mspl-parallel-estimator-distilled.md`
- `projects/deep-research/README.md`
- `memory/PROJECT-NOTEBOOKS.md`

### Explicitly not modified

- `AGENTS.md`, `CLAUDE.md`, and the divergent active-lane split pointer;
- all R, C++, tests, NEWS, Rd, articles, DESCRIPTION, validation-register status, and release files;
- every file in the two protected sibling worktrees.

## Landing State

The first handoff-gate run correctly reported this planning branch as unpushed. This handover commit is intended to be pushed with the programme branch and opened as a draft PR; verify the final row live rather than trusting this dated statement.

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `gllvmTMB` `codex/mspl-estimator-programme-roadmap` programme `1e5a1d48` + this handover | yes | expected before close | draft expected | **LANDED when remote/PR verified; otherwise CARRIED-OVER** |
| Shinichi brain `master` `f392938` | yes | n/a: local-only vault | none | **LANDED** |
| `claude/design-117-separation-programme` `9518d1bf` + dirty files | mixed | no upstream | none | **PROTECTED / CARRIED-OVER — separate owner** |
| `codex/lane-b-mspl-interval-feasibility` `8b23cfd2`, 14 ahead at handover | yes locally | remote behind | none | **PROTECTED / CARRIED-OVER — separate owner** |

Protected-lane resume checks—run only to classify, not to mutate:

```sh
git -C "/Users/z3437171/Dropbox/Github Local/gllvmTMB" status -sb
git -C "/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB" status -sb
```

## Mission Control

| Repo / lane | Branch or main | CI / shipped state | Plan by leverage |
|---|---|---|---|
| `gllvmTMB` MSPL programme → Cursor | `codex/mspl-estimator-programme-roadmap` | Docs-only programme; formal checks PASS; no package behavior | Rehydrate → Arc 1A strict provenance parity → independent review |
| Separation-design sibling | `claude/design-117-separation-programme` | Dirty/unpushed; wording has known MAP/Firth concern in branch evidence | **PROTECTED**; consult only; do not stage or merge |
| Interval/jackknife/coverage sibling | `codex/lane-b-mspl-interval-feasibility` | Private evidence branch, locally 14 ahead of remote | **PROTECTED**; uncertainty remains separate; no public inference claim |
| `origin/main` | `882a6acb` at programme orientation | Current experimental Bernoulli MSPL, ML default | Re-fetch and re-derive before branching; repository is technical truth |
| Shinichi brain | local `master` `f392938` | Ranga synthesis landed locally; no remote by design | Read DR34 for literature map; repo and primary papers outrank it |

## Next Immediate Steps

Cursor must first classify these steps against live state:

1. **OWED — rehydrate:** open `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`; read `AGENTS.md`, this handover, and the full programme document.
2. **OWED — live reconciliation:** run lane preflight, `git status -sb`, `git fetch origin --prune`, recent history, open PRs, and the two protected-lane status checks. Classify every row `OWED`, `DONE`, `RETRACTED`, or `PROTECTED`.
3. **OWED — confirm landing:** verify this branch exists on origin and record its draft PR. If the programme PR has merged, start Arc 1A from updated `origin/main`; if not, continue from the handed-over branch or create a clearly stacked Cursor branch without losing the programme commit.
4. **OWED — ultra-plan Arc 1A:** propose the exact no-numerical-change/no-accepted-call-change internal provenance implementation. Name R/TMB fields, adapter strategy, parity fixtures, files, tests, and Rose/Gauss/Noether gates.
5. **OWED after plan approval — implement Arc 1A only:** preserve all current routes, results, warnings/errors, and accepted calls exactly. Do not implement Arc 1B policy.
6. **OWED — verify and close Arc 1A:** targeted MSPL tests, exact objective/gradient/report parity, formal after-task report, independent review, scoped commit/PR, and handback before Arc 2.
7. **QUEUED, not immediate:** Arc 2 and later arcs from the roadmap. Do not bulk-implement the series in one PR or cross an evidence gate silently.

## Blockers / Open Questions

- **Arc 1B policy:** should explicit `estimator = "ml"` outside Laplace error, deprecate, or be replaced by a cleaner criterion API? Separate user decision.
- **B2 hard cells:** current comparative evidence is incomplete selectively; Arc 2 must authenticate, finish, or explicitly rescope it.
- **Penalty scaling in growing dimension:** current softness arguments do not establish ML-equivalence when `p_free / N_eff` stays non-negligible.
- **Inference target:** public intervals and model comparison remain blocked; do not let the private sibling lane settle this implicitly.
- **Shared active-lane pointer:** divergent across refs. Do not “fix” it opportunistically inside Arc 1A.

## Gotchas & Failed Approaches

- Do not write `ell_LA = log integral`; that equality defines the exact marginal log likelihood. `ell_LA` is its conditional-mode/Hessian approximation.
- Do not combine Arc 1A with a new typed error for `estimator="ml", integration="va"`; that would violate accepted-call parity and belongs to Arc 1B.
- Do not treat `estimator_id = 2` penalty-off evaluation as ordinary public ML. It is stable-kernel provenance at the MSPL point.
- Do not call all penalized fits MAP or Firth.
- Do not infer scientific benefit from finiteness, convergence code zero, or an interior covariance alone.
- Do not transfer the Gaussian factor theorem to binary/count GLLVMs or the mixed-logistic theorem to probit/cloglog/counts.
- Do not compare MSPL penalized objectives, penalty-off values, AIC/BIC, or LRT across ranks as if they were maximized common likelihoods.
- Do not stage the normal checkout's dirty/untracked files or anything in the interval worktree.
- Do not allocate a new numbered design while duplicate design slots remain across refs.
- Do not update the stale shared active-lane split without first resolving its multi-ref collision.

## Live Environment and Safe Commands

Preferred working directory for rehydration:

```sh
cd "/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap"
```

Thread safety for any later fit or compiled test:

```sh
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NOT_CRAN=true
```

Safe read-only opening checks:

```sh
"/Users/z3437171/Dropbox/Github Local/Shinichi/tools/lane_preflight.sh" "/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap"
git status -sb
git log -5 --oneline
git diff origin/main...HEAD --stat
gh pr list --state open
```

Safe validation of the handed-over documentation:

```sh
Rscript "/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R" \
  docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md
git diff --check
```

For Arc 1A, estimate runtime before any fit. Targeted tests should begin with the existing MSPL API test file; do not run a simulation campaign during the provenance arc.

## How to Resume

Start a fresh Cursor agent with the repository/worktree opened at:

```text
/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
```

Then paste:

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-14-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```

Do not assume Cursor extensions, terminal authentication, GitHub login, R/TMB availability, or remote-compute sockets. Verify each before relying on it.

Read AGENTS.md and docs/dev-log/handover/2026-08-14-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
