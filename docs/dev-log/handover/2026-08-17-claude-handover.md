# Claude → Claude handover — 2026-08-17

You are Claude, picking up the gllvmTMB **evidence / diagnostics** lane. The authoring chat is
gone; this document and the repo are authoritative. Everything below is landed on `main` unless
the Landing State ledger says otherwise.

**START BY RUNNING** `bash ~/shinichi-brain/tools/lane_preflight.sh <repo-path>` — this repo has
**40+ live lanes** and commits land straight to `main` all day. Then reconcile this document
against `git log origin/main` before believing any of it.

---

## Goals / mission

Shinichi, 2026-08-17, verbatim: *"we are not writing the paper yet — we want to finish the package
as much as possible"*, and the target is **0.7, not a 1.0 push from 0.5**. CRAN is off the table.
So the standing filter is: user-visible package completeness, honest evidence surfaces, no new
public claims beyond what is measured.

---

## Critical context (read this before acting)

1. **`main` moves constantly.** 60+ non-merge commits/day from Cursor and Codex lanes. Never
   assume a file you read an hour ago is current.
2. **The evidence surfaces drift, and the CODE is the truth.** Three independent instances landed
   today: the capability board under-reported VA by eleven families, the REML column claimed
   "later work" for a route that had been measured and closed, and DIA-12 named three residual
   families when the code had thirteen *and* advertised a simulation fallback that was drawing
   from the wrong distribution for nine families. **Re-derive from source before trusting a
   board, a register row, or a doc.**
3. **`aghq_ridge` is applied at R level, OUTSIDE the TMB objective** (issue #1092, OPEN). So
   `tmb_obj$fn()` / `tmb_obj$gr()` describe a function the optimiser was not minimising.
   **No gradient-based convergence judgement on a ridged fit is currently trustworthy**, including
   `fit$fit_health$max_gradient`. This is the single most important open defect.
4. **A pre-registered kill criterion was ignored.** Design 122's K1 (gradient bar) had its data on
   disk before launch, was never tabulated, and the halt never fired. An independent adjudicator
   later computed it in minutes: 37.5% of L0 and **100% of L2** over tolerance. Every accuracy
   number in the Design 122 campaign is therefore **provisional** pending #1092.

---

## What was accomplished (all merged to `main`)

| PR | What |
|---|---|
| #1050 | Diagnostics article honesty content; Design 121 (Cox–Reid REML pre-registration); slope-article recovery + staging |
| #1066 | Design 66 scoping proposal, all decision boxes approved; Cox–Reid A+B campaign (1,600 fits) — **K1 fired**, Cox–Reid worsens bias |
| #1074 | Capability board: VA ENGINE column restored across all 18 scalar cells; REML column records a *tested negative*; gaps box reframed to 0.7.0; VA-lane salvage (8 items) |
| #1085 | **Exact family-CDF residuals: 4/17 → 13/17 families** |
| #1086 | **`simulate()` correctness: 8/17 → 16/17 families**; multi-trial binomial was silently Bernoulli (#1079, now CLOSED) |
| #1089 | Nine family pips promoted; DIA-11/DIA-12 repaired |
| #1091 | Design 122 confirmatory campaign results — 21,600 fits, measurements only |
| #1093 | **Independent K1–K4 adjudication** |

Also landed: the **compute-admission slice** (Design 124, `dev/campaign-admission/`) — checksummed
manifests, immutable destinations, result schema, a 3-rung smoke ladder. Design 122's campaign was
its first real customer.

### The two scientific results

- **Non-Gaussian REML is closed with a pre-registered negative.** Cox–Reid made median |bias|
  *worse* in both families (binomial 7.26 → 10.84 pp; ordinal 3.08 → 4.39 pp; paired-median MCSE
  22–53× under threshold). `allow_nongaussian_reml` stays opt-in and unpromoted. Design 121 §9.
- **VA shows no demonstrated payoff over the cheap ridge**, and the campaign as run cannot certify
  one (see K1 above). VA reliably buys tail suppression (degeneracy 0.16% vs L2 5.36%, L0 15.01%
  on the intersection denominator) — but the ridge already buys most of it (14.8% → 5.3%) at
  ~94 s/fit against VGH's ~769 s. **K4 fired in the "transfers" direction**, so the *motivation*
  for a non-Laplace route survives; it is simply not shown to require this one.
  `dev/design122-campaign/ADJUDICATION.md`.

---

## Landing State ledger

**LANDED:** everything in the table above, plus the brain updates
(`~/shinichi-brain/memory/{AGENT_LOG,LESSONS,WHAT-WORKS}.md`, committed locally — the vault is
local-only per D-37, no remote).

**CARRIED-OVER:**

| Item | Branch | Why | Resume |
|---|---|---|---|
| Saturation-warning fix (the surviving part of #1083) | `claude/saturation-warning-families-20260817` | PR **#1094 OPEN**, CI was pending at handover | `gh pr checks 1094`; merge on green. Nothing else needed. |

**UNTRACKED SCRATCH — do NOT stage, safe to delete** (deletion was permission-blocked at
handover): `.pr-body.md` in `/private/tmp/gllvmtmb-simulate`, `.pr.md` in
`/private/tmp/gllvmtmb-satwarn`, and in `/private/tmp/gllvmtmb-doc-lane-20260816`:
`.commitmsg`, `.issue-body.md`, `.pr-adj.md`, `.pr-body-pips.md`,
`dev/design122-campaign/.pr-body.md`, and two rendered `vignettes/articles/*.html`.

**FOREIGN, NOT MINE — leave alone:** the `handoff_gate` reports many `tmp/rebase-*` and
`worktree-agent-*` branches with unpushed commits. None are this lane's.

---

## Files created / modified (this session's real diff)

- `R/predictive-diagnostics.R` — nine exact-CDF residual branches; `unknown_link` status
- `R/methods-gllvmTMB.R` — `.draw_y_per_family()` rewritten for 16 families; NA-not-a-wrong-number fallback; per-call warning
- `R/gllvmTMB.R` — `@param REML` honesty paragraph
- `docs/design/121-coxreid-validation-slice.md` (new, + §9 outcome)
- `docs/design/122-va-vs-laplace-recovery.md` (new, + §14–§17)
- `docs/design/124-campaign-admission.md` (new)
- `docs/design/35-validation-debt-register.md` — DIA-11, DIA-12, ten FAM rows
- `docs/dev-log/capability-surface.html` — ENGINE column, REML column, pips, gaps box, version
- `vignettes/articles/fit-diagnostics.Rmd`, `vignettes/articles/random-slopes-nongaussian.Rmd` (recovered + unhidden), `_pkgdown.yml`
- `dev/campaign-admission/`, `dev/coxreid-ab/`, `dev/coxreid-prerun/`, `dev/va-vs-laplace-prerun/`, `dev/design122-campaign/` (incl. 21,600-row results + `ADJUDICATION.md`)
- `docs/paper-drafts/` (two chapter-ready negatives — filed, NOT a paper push)
- `tests/testthat/`: `test-exact-rq-residuals-families.R`, `test-simulate-families.R`, `test-saturated-residual-lognormal.R`
- after-task reports + `docs/dev-log/check-log.md` directed notes

---

## Next immediate steps (OWED, in order)

1. **Merge #1094** if still open (`gh pr checks 1094`). No decisions in it.
2. **Fix #1092** — the ridge/objective mismatch. Preferred: put the penalty inside the TMB
   objective so `fn()`/`gr()` are self-consistent; smaller alternative: a penalised-gradient
   accessor with `fit_health$max_gradient` routed through it. **Write a test that fails against
   current code first**, and grep for *every* reader of that gradient in the same commit — the
   lesson of today is that this exact root cause was fixed once for TEST A and left everywhere
   else.
3. **After #1092: re-read Design 122's K1** against the existing 21,600 rows. The data does not
   need re-running; the *instrument* does. Only then are the campaign's accuracy numbers
   non-provisional.
4. **#1082's remaining half** — worked examples in `vignettes/articles/response-families.Rmd`
   (only Poisson currently fits; every other family is a table row). **This wants Shinichi's eye
   on the reader path** — draft, then review with him; do not batch-write eight examples.
5. **#1080** — dispersion naming hazards (`phi_gamma` is a SHAPE, `phi_gamma_delta` is a CV,
   `sigma_student` is a SCALE). Doc + an internal accessor so call sites cannot re-derive wrongly.

---

## Blockers / open questions (Shinichi's, not yours)

- Whether to re-run any of Design 122 after #1092, or accept the re-read.
- **K3's governance construction is mismatched** — it uses a mean-paired-difference MCSE against a
  difference-of-RMSEs statistic whose bootstrap SE is up to 9× larger. Amend before reuse.
- Deleting `origin/codex/va-gh-all-families` — reconciled and emptied of value (8 items salvaged);
  safe to delete, his call.
- `extract_cutpoints()` rejects VA-route fits (unowned). Fixing it would let Design 122 withdraw
  its §17 scope-out. Flagged to the ordinal lane via `check-log.md`.

---

## Gotchas / failed approaches

- **Do not hand-roll a fix a lane-check hook says another branch already made.** My first VA
  ENGINE column was wrong for two families (Gamma and lognormal have *analytic exact* VA paths,
  not GH); the dormant branch had it right.
- **A numeric anomaly may be a constant.** #1083's "silent collapse to 0.00064" was
  `1e-3 * sd(y)` — a deliberate, *announced* auto-suppression. Shinichi caught it with one line:
  *"sigma_eps is usually off, isn't it"*. See `docs/dev-log/2026-08-17-sigma-eps-suppression-not-a-defect.md`.
- **Never pool infrastructure failure with estimator failure.** 120 compiler-race rows were nearly
  charged to VGH's convergence rate, in the direction that would have biased the comparison.
- **A green suite proves nothing about the guard.** Mutation testing caught 2/7 realistic defects
  before a KS line was added. Make the guard fail in front of you.
- CI here enforces a **trailing-whitespace gate** — machine-generated logs and R `summary()` output
  trip it. Strip before pushing.
- The campaign driver must be **detached (PPID 1)**; agents die mid-run and the compute must not.

---

## How to resume

```bash
cd <your worktree off origin/main>
bash ~/shinichi-brain/tools/lane_preflight.sh .
git fetch origin main && git log origin/main --oneline -5
```
Toolchain: R 4.6.0 locally; `devtools::test(filter = "...")`, `devtools::document()`.
Totoro reachable via plain `ssh -o BatchMode=yes totoro` (ControlMaster socket; never triggers Duo);
cap 150 cores (D-143); campaigns never on GitHub Actions (D-50).

Classify every item above as `OWED` / `DONE` / `RETRACTED` / `PROTECTED` against the live repo
before continuing.
