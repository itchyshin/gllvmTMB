# Session Handoff: Design 108 **Gate A CLOSED** — next arc is the recovery study

**Meta:** 2026-08-02 · from Claude · to Claude · fresh context required
**Capability widget (step 0):** Mission Control — `sh "$HOME/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/start.sh"` → `http://127.0.0.1:8823/p/gllvmTMB/`

## Mission-control summary

| Field | Value |
| --- | --- |
| Repo | `gllvmTMB` |
| `origin/main` at write | `d34309f6` (+ #911 pending) |
| This session shipped | Design 108 **Stages 4, 6, 7** + **R3** (the profile route) + a 4,320-fit measurement campaign |
| Gate A | **CLOSED** (Stage 6 closes it; Stage 7 makes the phylo tier real) |
| 🔴 Next (needs Shinichi) | **Run the VA-vs-Laplace recovery comparison BEFORE Stages 3/5** — see §"Next Immediate Steps" |
| Everything | still **FENCED** — no export, no `method=`, no public claim |

## Critical Context

1. **The programme's own justification has weakened.** Design 108 §0.2 justifies 17–26 days partly
   on Laplace silently diverging. This session measured it: the rate **decays monotonically with n**
   (18.1% at n≤150 → 0.6% at n≥1600) and `aghq_ridge = 2` drives it to ~0 across the whole ladder.
   At the real envelope (5,000–10,000 species) silent divergence is close to a non-problem.
   **Do not build more capability on that premise without re-testing it.**
2. **Two unvalidated premises now sit under the programme**, and one campaign answers both:
   (a) does VA recover `Sigma_B` better than Laplace at all? (b) is the augmented phylo route
   statistically right — Design 106 §3.6 predicts its factorised ELBO sits *further* below the
   marginal likelihood, and that is **untested**.
3. **The envelope is N = 5,000 → 10,000 (hard cap), T = 20–30**, q=2, two tiers, **both
   `unique = TRUE`** (Shinichi, this session). The repo's "5397 × 27" north star is consistent
   with that. A separate 10,000 × 7 model runs in ~30 min on the shipped Laplace engine.
4. **Multi-lane.** Read `docs/dev-log/handover/2026-07-25-active-lane-split.md`. Cursor/Codex lanes
   merged during this session (#890, #895, #899, #900, #903, #906). Do not claim their surfaces.
5. **The Dropbox primary checkout is PROTECTED/dirty** on
   `claude/profile-coverage-remeasure-20260718` (D-112) and was hundreds of commits behind all
   session. **Never plan from its files** — use `git show origin/main:<path>`.

## Goals / mission

Design 108 Gate A = "her model shape can be expressed"; Gate B = "her data is fitted well".
North star is Ayumi's BIRDBASE model. First CRAN target remains **0.6.0** with recovery-only
interval framing (D-112); none of this VA work widens a public claim.

## What Was Accomplished

**Merged to `main`:**

| PR | What |
|---|---|
| #894 | 2026-08-02 handover + its CI whitespace fix |
| **#896** | **Stage 4** — tail-safe `log Phi` + binomial-probit (family code 4). **VERDICT AD-SAFE**, adversarially ESTABLISHED against a 3,744-cell break grid |
| #898 | closeout: the §0.2 n-ladder analysis + Melissa's plan-actual |
| **#902** | the **"67% runaway"** correction — wrong arm *and* no regime |
| #905 | design-doc fixes: H=61 reach, stale `family == 3` |
| **#907** | **Stage 6** (multi-tier — Gate A closes) + **R3** (the `profile=` route) |
| #909 | after-task for Stage 6 + R3; **Stage 9's premise re-scoped** |
| #897 | *(issue)* ordinal_probit has no degeneracy detector |

**Open:** **#911 — Stage 7** (structured phylogenetic KL). CI was **pending** at write.

### The three results that matter most

**1. R3 — the programme's actual blocker, removed.** `MakeADFun(..., random = NULL)` put every
variational coordinate in the dense outer problem; nlminb's PORT workspace is O(P²), measured
directly and matching `n(n+27)/2` doubles **to 2% at n=16,000**. At the real envelope that is
**1,127 GB at N=5,000 and 4,508 GB at N=10,000** — arithmetically impossible, not slow.
The opt-in `profile_variational = TRUE` collapses the outer problem from `114N + 206` to **206,
constant in N**. Measured peak RSS exponent **1.70 → 0.966**; at N=8,000 the joint route hit
≥6,460 MB and did not finish 3 iterations in 23 min, profile used 1,697 MB in 12.5 s.
It passes the arc plan's **L3** gate (gradient of the ORIGINAL joint objective at the profiled
solution, max **6.28e-5**) **where the joint route fails that same test in 4 of 12 cells (5.70e-3)**.

**2. Stage 7 inverted the received framing on the phylo route.** Inner-Hessian sparsity under
`profile=`: the **augmented** route holds `nnz/dim` **flat at 4.35 → 4.28 over an 8× range in
tips**, adding exactly `d × nnz_lower(Ainv)` entries. The **tips-only** route gives
6.76 → 7.72 → **11.36** — an **O(N²) inner solve**. *The route that costs 1.5× more coordinates is
the one that is affordable.* This inverts Design 106 §6.4(5) for the `profile=` path.

**3. The §0.2 campaign (3,600 fits + a 720-fit logit arm, Totoro, pinned `910ebd54`).**
Silent divergence decays with n (above). **511/3,600 fits degenerate; 425 (83.2%) reported
`convergence = 0` AND `pdHess = TRUE`.** The flags are not lying — `convergence` is nlminb's exit
code and `pdHess` is a local Cholesky test; a degenerate optimum is a *real* optimum.
The shipped detector caught **272/272** degenerate binomial-probit fits but **never runs on
ordinal_probit** (239/239 unflagged) → issue #897.

## Current Working State

**Working / landed:** Stages 4, 6 and R3 on `main`; `R CMD check` 0/0/0; the full VA regression
(10 files) green at every step.

**In progress:** **#911 (Stage 7)** — committed `d4d3e4e5`, pushed, PR open, **CI pending**.

**Not started:** Stages 3 and 5; Stage 8; Stage 9 (needs re-scoping, not running).

**Protected / foreign:** the Dropbox checkout (D-112); all Cursor/Codex lanes.

## Key Decisions & Rationale

- **Everything stays FENCED until Stage 8.** Design 108: Stage 8 is *"required before any statement
  about her model."* Stage 4 declined to widen the fence for probit; Stage 6 and Stage 7 followed.
- **`profile_variational` defaults to FALSE.** `sdreport()` across the profiled block is untested
  (arc plan §6.2). Default is **byte-identical** to the joint route. Do not flip it without SEs.
- **Proposition 2 is realised structurally, not by convergence.** A diagonal tier allocates **zero**
  off-diagonal entries (52 vs 377 per level at T=26). "Simplifying" it onto the dense path would
  pass every test at 7.25× the cost.
- **`log Phi`: NO CHANGE to the shipped engine** — see `dev/logphi-reconciliation/FINDINGS.md`.

## Files Created / Modified (this session)

On `main` via the PRs above:
`inst/tmb/gllvmTMB_va_r3.cpp` · `R/va-r3-proto.R` · `R/va-routing.R` · `R/approximation-engine.R` ·
`R/integration-fence.R` (comment only) · `R/gllvmTMB.R` (comment only) ·
`tests/testthat/test-va-probit-adsafety.R` (new) · `test-va-r3-profile.R` (new) ·
`test-va-mixed-family.R` · `test-va-r3-prototype.R` · `test-approximation-engine.R` ·
`docs/design/35-validation-debt-register.md` (VA-12) · `docs/design/105-va-family-densities.md` ·
`docs/design/108-va-parity-programme.md` (Stage 6 LANDED; Stage 9 re-scoped) ·
`dev/design108-stage4/va-claim-fence.sh` (new) · `dev/design108-stage8/` (new: campaign harness,
README, n-ladder analysis, logit arm) ·
`docs/dev-log/after-task/2026-08-02-design108-stage4-probit-adsafety.md` ·
`docs/dev-log/after-task/2026-08-02-design108-stage6-tiers-and-r3-profile.md` ·
`docs/dev-log/plan-actual/2026-08-02-design108-stage4.md`

On #911 (Stage 7, unmerged): `inst/tmb/gllvmTMB_va_r3.cpp` · `R/va-r3-proto.R` ·
`R/approximation-engine.R` · `tests/testthat/test-va-r3-structured-phylo.R` (new) + 3 test files.

This handover adds: this doc · `dev/logphi-reconciliation/` (FINDINGS.md + 6 scripts).

## Landing State

| Artifact | Committed | Pushed | PR | State |
|---|---|---|---|---|
| Stages 4, 6, R3, corrections | yes | yes | #896/#902/#905/#907/#909 | **LANDED** |
| **Stage 7** `d4d3e4e5` | yes | yes | **#911 OPEN, CI pending** | **CARRIED-OVER** — merge when green; `gh pr checks 911` |
| `dev/logphi-reconciliation/` | in this handover | with this PR | this PR | **LANDED when this merges** |
| `/private/tmp/gllvmtmb-stage7` | n/a | n/a | n/a | disposable WT; delete after #911 merges |
| `/private/tmp/gllvmtmb-logphi`, `-r3-profile`, `-handover` | n/a | n/a | n/a | disposable WTs; `git worktree remove` each |
| Dropbox `claude/profile-coverage-remeasure-20260718` | mixed/dirty | no | none | **PROTECTED (D-112)** — never `git clean` from another lane |
| ~13 legacy unpushed local branches | mixed | no | none | **CARRIED-OVER** — pre-existing `handoff_gate` noise, not this session's |

Campaign results are **LOCAL (D-50)**: `totoro:~/gllvm_work/results/design108-stage8-grid.csv`
(3,600 rows) and `d108-logit-847.csv` (720 rows). Pinned build at
`totoro:~/gllvm_work/d108-stage8/src910ebd54`.

## Next Immediate Steps (classify before acting)

1. **OWED — rehydrate only:** open Mission Control; read `AGENTS.md`, this doc, and
   `2026-07-25-active-lane-split.md`; run `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"`;
   classify every item below `OWED` / `DONE` / `RETRACTED` / `PROTECTED`.
2. **OWED — land #911** (Stage 7) once CI is green: `gh pr checks 911` then `gh pr merge 911 --merge`.
   Then write its after-task report — **Stage 7 has none yet** (Stage 6's was also late; see
   `2026-08-02-design108-stage6-tiers-and-r3-profile.md` §9).
3. **🔴 OWED — the recommended next arc, needs Shinichi's go: the VA-vs-Laplace recovery
   comparison, BEFORE Stages 3 and 5.** Rationale in Critical Context 1–2. It is runnable *now*:
   Stage 4 gave probit, Stage 6 gave multi-tier, R3 made it affordable, and the harness exists at
   `dev/design108-stage8/`. Ask: **does VA recover `Sigma_B` better than Laplace on probit, at
   realistic size, with two tiers?** Include an **augmented-vs-tips-only ELBO arm** to test
   Design 106 §3.6 at the same time. If VA ties or loses, ~7 days of Stages 3/5 are saved.
4. **DEFERRED — Stage 5** (ordinal_probit, 1–2 d). Its `log Phi` precondition is **discharged**
   (`dev/logphi-reconciliation/FINDINGS.md`), but that note carries a **hard requirement**: the VA
   template has NO differencing machinery (`log1mexp`/`logspace_sub`/`*_pnorm_diff` grep = 0), and
   a naive `logspace_sub` is **1e2–1e4× worse** than the shipped `gll_log_pnorm_diff`. Stage 5 must
   port `gll_log1mexp` (`src/gllvmTMB.cpp:50`) and `gll_log_pnorm_diff` (`:106`) with
   `va_r3_log_pnorm` substituted inside. **Design 108's row-5 wording ("logspace_sub of two log
   Phis") understates this.**
5. **DEFERRED — Stage 3** (lognormal, 0.5 d, EXACT). Cheapest item on the board.
6. **DEFERRED — #897.** Its spec exists but **its reasoning was largely overturned** by an
   adversarial pass: the recommendation *"survives directionally, but nearly every reason given for
   it is wrong"*, and its operating characteristics were *"a pooled mixture over three design axes
   the original never examined"* (arm, sigma_lambda, p). **Redo the justification before
   implementing.** Also fix the detector's **25% false-positive rate** (232/928) first, or
   extending it just spreads noise.
7. **PROTECTED:** do not widen `R/integration-fence.R` or `R/va-routing.R`; do not flip
   `profile_variational`; do not touch the Dropbox checkout, root `LOOP/`, or Codex/Cursor lanes.

## Blockers / Open Questions

🔴 **Needs Shinichi:** approve the recovery study as the next arc (step 3) instead of Stages 3/5.

## Gotchas & Failed Approaches

- **`pgrep -f "<pattern>"` matches its own command line.** Cost 45 minutes once this session (a
  monitor never fired on a job that had finished in 29.9 s). Split the literal: `"foo""-bar"`.
- **`R_LIBS_USER` REPLACES the user library.** Setting it to a private lib hid every dependency and
  would have failed all 3,600 campaign cells identically. Prepend the full path list instead.
  Caught only because a single probe ran first — **smoke-first paid for itself three times.**
- **`git log origin/main..HEAD` on a stale ref reports phantom "unmerged" commits.** Fetch first,
  then `git merge-base --is-ancestor`.
- **Before `git worktree remove --force`, check for untracked files.** Two irreplaceable artifacts
  (the n-ladder analysis and Melissa's reconciliation) were nearly destroyed that way.
- **An in-code comment is a claim, not evidence.** `R/gllvmTMB.R:909-911`'s "67%" was wrong twice
  and had propagated into three documents. It was cited (by me) before being checked.
- **`ask-brain` BEFORE deriving, not after.** R3 was scoped as new work; a designed plan for it
  already existed at `docs/dev-log/recovered/2026-07-27-va-speed-arc-plan.md`.
- **Design 106 §4.2's coordinate counts EXCLUDE the `diag(Psi)` tier**, which §4.2 itself calls
  *"the single largest cost lever in the model."* That omission made a first-pass scale analysis
  read MARGINAL when it was BLOCKING; only an adversarial pass caught it.
- **`n_aug = 2N − 2`, not `2N − 1`** (Stage 7 correction; the builder drops the root).
- **Stage 7 found a silent-wrong-answer bug**: on the augmented route every tip's 0-based index is
  ≥1 and ≤ n_aug−1, so **both arms of the base-detection sniff match** and every observation
  attaches to the wrong node. Fixed; structured callers must declare 0-based.

## How to Resume

```sh
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"
cd "$REPO"
bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"
git fetch origin main && git log origin/main --oneline -5
gh pr list --state open
# Read: AGENTS.md -> this doc -> 2026-07-25-active-lane-split.md
sh "$HOME/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/start.sh"
```

**Never plan from the Dropbox working tree** — it is PROTECTED and far behind. Cut a fresh
worktree: `git worktree add /private/tmp/gllvmtmb-<arc> -b claude/<arc> origin/main`.

Safe verify (fast, no campaign):

```sh
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-va-r3-profile.R")'
```

Totoro (no fresh Duo needed, D-64):

```sh
SOCK=$(ls ~/.ssh/cm-*totoro* | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes totoro 'nproc; uptime'
```

Do not stage: the Dropbox `.claude/` or `.uinit/` dirs, the dirty profile-coverage files, any
campaign `.csv`/`.rds` (D-50 — results stay local), or foreign lane trees.

### Paste-ready Claude resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
