# Session Handoff: integrated SDM — Claude → **Codex**

Meta: 2026-08-08 · from **Claude Code** · to **Codex** · repo `gllvmTMB` · **EXPERIMENTAL LANE**
Branch **`claude/experiment-integrated-sdm`** · worktree `~/local-scratch/worktrees/gllvmtmb-isdm`
Predecessor handover: `docs/dev-log/handover/2026-08-08-claude-handover-integrated-sdm.md` (Claude→Claude).

**STATE THIS LINE when you start:**
`PLATFORM: codex | LANE: integrated-SDM experiment | FOREIGN LANE: cursor (CRAN 0.7)`

---

## 0. LANE SEPARATION — read before anything

- **Stay in the worktree.** Never work in `~/Dropbox/Github Local/gllvmTMB` — shared checkout.
- **Never touch `main`.** A CRAN 0.7 release is in flight on the Cursor lane
  (`cursor/cran-0.7-20260807`, `cursor/cran-path-a-0.6.1-20260807`).
- **Never touch VA/GH estimator internals** (`codex/va-gh-all-families` is a *different* Codex lane —
  do not conflate it with this one). This lane uses **Laplace**; the reference method does too.
- **Never `git add -A`.** Scoped staging by explicit path.
- **No PR, no merge.** This lane proves or dies in the worktree; Shinichi decides after.
- Run `bash ~/shinichi-brain/tools/lane_preflight.sh .` at orient **and again before claiming a lane**.
  Silence is weak evidence, never proof of sole ownership (D-87).

---

## 1. LANDING STATE LEDGER

| item | committed | pushed | state |
|---|---|---|---|
| `50f578b9` original handover | y | n | lane entry point |
| `68b45223` Phase A gate evidence (24k fits + harness) | y | n | **LANDED for this lane** |
| `725b6e94` after-task report + check-log entry | y | n | **LANDED** |
| `d684cf02` #946 offset admission + `link_residual` fix + tests | y | n | **LANDED, verified** |
| `76eb5e7c` wide-format probe + Phase C reuse map | y | n | **LANDED** |
| **Phase C workflow `we7vixcy2`** | — | — | 🔴 **CARRIED-OVER — RUNNING AT HANDOVER.** See §4. |
| 285 unpushed commits on `agent/*` branches | y | n | **PRE-EXISTING, NOT THIS LANE'S.** Do not land, rebase, or delete. Predates this work; provenance unknown. `handoff_gate.sh` fails on them for this reason. |
| stale `.git/index.lock` in the shared checkout | — | — | ⚠️ **REPORT to Shinichi, do NOT `rm`** (harness blocks `.git` deletions). |

Nothing is pushed. **Codex reads `origin`; to Codex this lane does not exist until the branch is
pushed.** Push it (`git push -u origin claude/experiment-integrated-sdm`) or work from the local
worktree directly — but decide deliberately, do not assume.

The shared Dropbox checkout is **2 commits behind `origin/main`** — pull before resuming anything there.

---

## 2. THE SCIENCE — settled, do not re-derive

One ecological intensity: `log μ_i = β₀ + x_i β + ξ_i`.

- **Presence-only** is a thinned point pattern; bias adds on the log scale:
  `log λ_i = log A_i + β₀ + x_i β + ξ_i + α₀ + w_i α`, observed as Poisson counts.
- **Presence/absence** is *derived*, not assumed: under a Poisson process a site of area `a_i` is
  occupied with probability `1 − exp(−a_i μ_i)`, hence `cloglog(p_i) = log a_i + β₀ + x_i β + ξ_i`.

So `β₀` and `β` are **the same parameters** in both arms. **cloglog is compulsory** — it *is* the
change-of-support; logit or probit breaks the derivation and the parameters stop being shared.

Textbook: Fithian 2015; Fletcher 2019; **Dovers, Popović & Warton 2024** *MEE* 15:191–203 (pkg
`scampr`). **Claim none of it.** The possibly-new part is **multispecies latent factors on top**, and
`dr30` (31-source sweep) confirms the gap: every integrated method treats species as independent;
every latent-factor JSDM is single-source; **none does both**.

**Poisson, not NB2, for the PO arm — and mind the reason.** Under NB2, `P(Y=0) = (1 + aμ/k)^(−k)`, so
`cloglog(p) = log k + log log(1 + aμ/k)` — not affine in `log μ`. But the *criterion* "the marginal
isn't cloglog" is **wrong**, because it equally condemns the recommended fix (a lognormal-Poisson also
has a non-cloglog marginal). The correct argument: gamma mixing is **arm-local**, so exactly one arm
is always misspecified; a *declared shared latent* `ξ` keeps `cloglog(p | ξ)` exact **conditionally**
in both arms. **Corollary: NB2 is incompatible with cloglog, not with integration** — a matched link
`p = 1 − (1 + e^η/k)^(−k)` exists. Rejecting NB2 is pragmatic, not a theorem.

---

## 3. WHAT IS DONE — measured, not assumed. Do NOT rebuild any of it.

**Phase A — THE GATE: PASSED above prevalence 0.3.** 24,000 fits, 6.43 core-hours.
Full report: `docs/dev-log/after-task/2026-08-08-isdm-gate-phase-a.md`; detail `dev/isdm-gate-findings.md`.

- `Λ` RMSE in the mixed Poisson/Bernoulli-cloglog cell is **1.03–1.17×** the all-Poisson control's
  across all 20 (n, prevalence) cells, against a **pre-registered** tolerance of 2.0.
- Where recovery is imperfect it is **weak estimability, not non-identifiability** — separated by
  instrument: n-ladder log-log slope **−0.487 (SE 0.0069)** at p=0.3 (an MLE gives −½; a
  non-identified model gives ≈0), and 14 dispersed starts land on **one** optimum (max gap 4.5e-05
  vs a 0.05 threshold).
- The soft direction is the **loading/unique-variance split**, not the loading (`λ² + ψ = const`).
- **The p=0.1 miss is NOT mixed curvature** — the all-Poisson control fails identically (−0.454).
- Permutation placebo: the Bernoulli arm moves `Λ̂` by 23–58× its MCSE, so the pass is not vacuous.

**Phase B — landed and verified.**
- **#946**: the offset gate is now keyed on **family × link**. `binomial(cloglog)` admitted;
  logit/probit/gaussian/Gamma-lognormal-Tweedie-on-log still refused. Four touch points (the issue's
  "a few lines" was wrong): a `link_id_vec` param on `gll_prepare_offset()`, the call site at
  `R/fit-multi.R:2159`, the gate at `R/offset.R:148`, and `fam_name()` so the error names the link.
  `docs/design/01-formula-grammar.md` needed a **rewrite** — it argued explicitly *against* a link gate.
- **`link_residual = "auto"` no-op fixed**: it warned that no residual is defined for a mixed-family
  trait, set `NA`, then discarded the `NA` via `na.rm = TRUE` and returned the `"none"` answer. NA now
  propagates into `diag(Σ)` and its row/column of `R`.
- All new tests **proven to fail before their fix**. Verified with `NOT_CRAN=true` — the first run
  silently **skipped** two of them on `skip_on_cran()` and reported a pass that never executed.

**Settled facts you can build on:**
- **#945 is WRONG.** A mixed-family-within-species fit **runs today**. `family_var` is a *join key*,
  not a trait mapping: point it at a non-trait column (`source`) and `family_id_vec` comes back
  length `nrow(data)`. It was **untested, not unsupported**. *Please correct the issue.*
- **Wide format WORKS too** (`76eb5e7c`) — the `traits()` expander carries `source` through, the wide
  `offset(e1,e2,…)` stacks in lockstep, and `getLV()` returns one score per **cell**. Plumbing only:
  `d=1`, `n=5`, no recovery check, NA-masking untested.
- The joint likelihood is **analytically correct**: TMB's objective matches a hand-built joint NLL to
  **1e-10 … 1e-13** at three parameter vectors.

---

## 4. 🔴 CARRIED-OVER: the Phase C workflow was RUNNING at handover

**Workflow `we7vixcy2`** (run id `wf_b705e82c-2c8`), 7 phases, 9 agents:
`Scout → Design → Build → Smoke → Run → Analyse → Verify`.
Script: `~/.claude/projects/.../workflows/scripts/isdm-phase-c-misspecification-wf_b705e82c-2c8.js`
Transcript + `journal.jsonl`: `~/.claude/projects/.../subagents/workflows/wf_b705e82c-2c8`

**Scout phase COMPLETED and its output is committed** (`76eb5e7c`): `dev/isdm-wide-format-probe.md`,
`dev/isdm-phase-c-reuse-map.md`.

**FIRST ACTION ON RESUME: establish what actually finished.** Do not assume, and do not re-run blind.
```sh
ls -la ~/local-scratch/worktrees/gllvmtmb-isdm/dev/isdm-phase-c-design.md \
       ~/local-scratch/worktrees/gllvmtmb-isdm/dev/isdm-bias-*.{R,md,rds}
```
Then read the workflow's `journal.jsonl` — it records each agent's **actual return value**, and a
cached result may itself be empty. Commit whatever landed before doing anything else; the worktree is
**outside Dropbox and not backed up**.

**What Phase C is asking, and why it matters more than Phase A.** Phase A's arms were all fitted to
data generated from *exactly* the model they assume — so "integration beats pooling" is true **by
construction**. It measures recovery, never benefit. Phase C is the honest arm: **spatially structured
recording bias correlated with the environmental predictors**, which the fitted model's per-source
constant `γ[d,j]` **structurally cannot represent**.

The headline is about the **latent factors, not the slopes**: `u_i` is site-level and so is unmodelled
recording bias, so **the factors are the natural sink for it**. Two species over-recorded in the same
places load on a common factor and get reported as positively associated — a *sampling* correlation
reported as a residual *ecological* one. Since the correlation matrix is a GLLVM's headline output,
this measurement decides how the method may be described. Tobler et al. 2019 show this **by
simulation for presence-absence**, and the driver is **species-specific** bias — so a shared bias
surface would understate it. **The presence-only case is absent from the corpus**, which is what makes
this a new result rather than due diligence.

**Two hard constraints on the design** (both cost Phase A real time):
1. `R/fit-multi.R:4976` maps `theta_diag_B` **off** — not merely floors it — when every row of a trait
   is single-trial Bernoulli. An all-binary cell can only estimate `Σ = ΛΛ'`.
2. Under a rank-1 `Σ = ΛΛ'` with `d = 1`, **every off-diagonal correlation is exactly ±1**. So the
   correlation metric is **vacuous** unless `d ≥ 2` or `ψ` is genuinely estimable. The design slice
   was told to choose `d` accordingly and justify it — **check that it did.**

---

## 5. NEXT STEPS, in order

1. **Recover and commit Phase C's partial output** (§4). Establish what ran from the journal, not from memory.
2. **Finish Phase C** — smoke must show the distortion metric *moves* between low and high bias, or
   the ladder does nothing and the campaign is pointless (that was a pre-declared NO-GO).
3. **Correct issue #945** — it records as impossible something now measured as working.
4. **Document the `family_var` contract.** This is the biggest latent API risk in the lane: pointing
   `family_var` at a non-trait column works but is **undocumented and arguably accidental**. The docs
   say "per-trait family assignments"; every pre-existing test keys it to `trait`. A maintainer could
   add a per-trait validation and silently break the integrated model. Make it a documented, tested
   contract before anything depends on it.
5. **Only then** consider real data. GBIF remains fenced.

---

## 6. MEASUREMENT DISCIPLINE — non-negotiable, and it has already caught things

- **Recovery against planted truth is the criterion. NEVER score on optimiser flags.** In Phase A,
  `convergence == 0` in **99.9%** of 24,000 fits *including* cells where recovery was demonstrably
  poor. (Sister-package figure: 83.2% of degenerate fits reported clean flags.)
- **Report MCSE with every mean.** A difference smaller than its MCSE is not a difference.
- **Paired per-seed differences**, never medians of two clouds.
- **State what is identified before scoring it.** Fithian *et al.* prove absolute intensity is not
  identified from PO alone (only `α₀ + β₀`), so score relative-up-to-a-species-constant unless a PA
  arm is present. `a = 1` is an **identifying assumption, not a convenience** — and because `β₀` is
  shared, the PO offset must be in units where the PA site area equals 1, or the mismatch is silently
  absorbed by `α₀` with no error.
- **`NOT_CRAN=true` when running tests**, or `skip_on_cran()` will report a pass that never ran.
- **Smoke first**: read the first cell's output early and abort on empty/NA.
- Score with `extract_Sigma(..., link_residual = "none")` — planted `Λ`/`ψ` live on the **ecological**
  linear predictor.

---

## 7. Environment

- **Working dir:** `~/local-scratch/worktrees/gllvmtmb-isdm`. ⚠️ **outside Dropbox, NOT backed up** — commit early.
- **Toolchain:** R 4.6.0 + TMB. Use `devtools::load_all()` — the branch carries a `#946` fix that
  **installed 0.6.0 does not have**, so `library(gllvmTMB)` would silently test the wrong code.
- **Compute:** Phase A ran locally (18 cores, 6.43 core-hours, ~28 min). Totoro (384 cores, R 4.5.3,
  socket verified live 2026-08-08) is available and needs no Duo, but for a grid this size remote
  deploy + TMB compile costs more than the run. **Never GitHub Actions (D-50).**
- **Do not stage:** anything under `src/`, anything VA/GH, anything on the CRAN path, `.Rproj.user`.

## 8. Open questions

- Phase C's `d` choice and whether the correlation metric is non-vacuous (§4 constraint 2).
- The Laplace attribution is **UNCERTAIN** for the package's real estimand: AGHQ is *structurally
  ineligible* under `unique = TRUE`, so Phase A's D7 speaks only to the `unique = FALSE` arm.
- Nothing here covers `d ≥ 2`, real data, imperfect detection `δ`, or disjoint PO/PA units.

**Collaborator note, not a blocker:** the reference paper's authors are UNSW — **Gordana Popović and
David Warton** — and Gordana is already on Shinichi's advisory-board invite list. If this lane
produces anything, that conversation happens **before any public claim**.

---

## 9. Files created / modified this session

Session diff = `git diff --name-only 50f578b9...HEAD` on `claude/experiment-integrated-sdm`.

**Package source (Phase B — the only files that change package behaviour):**
```
R/offset.R                       #946 -- link_id_vec param, family x link gate, fam_name()
R/fit-multi.R                    #946 -- the sole call site now passes link_id_vec (:2159)
R/gllvmTMB.R                     #946 -- roxygen on the `formula` param (offset docs, :50-65)
R/extract-sigma.R                link_residual="auto" NA propagation + warning text
man/gllvmTMB.Rd                  regenerated by devtools::document()
docs/design/01-formula-grammar.md  section Offsets REWRITTEN (it argued against a link gate)
tests/testthat/test-offset-support.R   4 new tests, all proven to fail before the fix
tests/testthat/test-extract-sigma.R    2 new tests (skip_on_cran -- see the NOT_CRAN gotcha)
```

**Evidence and dev artifacts (no package behaviour):**
```
dev/isdm-probe.R / -findings.md            #945 adjudication
dev/isdm-plumbing.R / -findings.md         analytic likelihood cross-check + beta recovery
dev/isdm-gate-harness.R                    THE reusable harness -- extend, do not rewrite
dev/isdm-gate-smoke.R / -findings.md
dev/isdm-gate-campaign.R  dev/isdm-gate-analyse.R
dev/isdm-gate-findings.md                  the primary Phase A artifact (50K)
dev/isdm-gate-results.rds / .csv           24,000 rows x 33 cols
dev/isdm-gate-instruments.rds              D2-D7 instrument output
dev/isdm-946-notes.md  dev/isdm-link-residual-notes.md
dev/isdm-wide-format-probe.R / .md         wide format WORKS
dev/isdm-phase-c-reuse-map.md              what Phase C can reuse
```

**Dev-log:**
```
docs/dev-log/after-task/2026-08-08-isdm-gate-phase-a.md
docs/dev-log/check-log.md                  (appended)
docs/dev-log/handover/2026-08-08-codex-handover.md   (this file)
CLAUDE.md                                  Live Phase Snapshot pointer
```

**Never stage:** anything under `src/`; anything VA/GH; anything on the CRAN 0.7 path;
`.Rproj.user`; foreign untracked files in the shared checkout.

---

## 10. REHYDRATION -- Codex-tuned

`AGENTS.md` is native to you: **read it first**, then this doc, then in order:
`docs/dev-log/after-task/2026-08-08-isdm-gate-phase-a.md` -> `dev/isdm-gate-findings.md` ->
`docs/dev-log/handover/2026-07-25-active-lane-split.md` (the multi-lane map -- this repo has
**several concurrent lanes**; that file names each lane's own current handover).

**Team mirror:** `.codex/agents/*.toml`. Relevant here -- `systems-auditor.toml` (**Rose --
mandatory before any covered claim**), `simulation-tester.toml` (Curie), `tmb-engineer.toml`
(Gauss), `reviewer.toml`, `reproducibility-engineer.toml` (Grace), `landscape-scout.toml` (Jason).

### Live environment -- you run the live toolchain, so get this exactly right

```sh
cd ~/local-scratch/worktrees/gllvmtmb-isdm      # NOT the Dropbox checkout
export NOT_CRAN=true                            # see the gotcha below; non-negotiable
Rscript --vanilla -e 'devtools::load_all("."); packageVersion("gllvmTMB")'
```

**`devtools::load_all()`, never `library(gllvmTMB)`.** The installed package is 0.6.0 and does
**not** carry this branch's `#946` fix, so `library()` silently tests the wrong code. This branch
compiles `src/gllvmTMB.cpp` via TMB on first `load_all()` -- allow a few minutes.

Targeted verification:
```sh
NOT_CRAN=true Rscript --vanilla -e '
  Sys.setenv(NOT_CRAN="true"); devtools::load_all(".", quiet=TRUE)
  testthat::test_file("tests/testthat/test-offset-support.R", reporter="summary")
  testthat::test_file("tests/testthat/test-extract-sigma.R",  reporter="summary")'
```
Expected: offset-support **75 assertions**, extract-sigma **56 assertions** (1 expected warning),
**0 failures, 0 skips**.

### Cross-tool routing -- what is YOURS

**Yours (live toolchain):** finishing the Phase C campaign (real fits, `mclapply` grids), any
`R CMD check` / `--as-cran` run, rendering, and anything needing a compiler. Phase A ran locally on
18 cores in ~28 min; Totoro (384 cores, R 4.5.3, no Duo needed -- attach via the existing
`~/.ssh/cm-*totoro*` ControlMaster) is available, but for a grid this size remote deploy plus a TMB
compile costs more than the run. **Never GitHub Actions (D-50).**

**Not yours / stays fenced:** any export, `method=`, NEWS, README, article, or
validation-debt-register promotion; any PR or merge to `main`; GBIF / real data.

---

## 11. GOTCHAS -- each of these cost real time; do not rediscover them

1. **`skip_on_cran()` reports a pass that never ran.** Under `Rscript --vanilla`, `NOT_CRAN` is
   unset, so the two new `extract-sigma` tests **skipped** -- and a skip renders as a dot in the
   summary reporter, indistinguishable from a pass. **Always `NOT_CRAN=true`.**
2. **Optimiser flags are worthless here.** `convergence == 0` in **99.9%** of 24,000 fits,
   *including* cells where recovery was demonstrably poor. Score against planted truth only.
3. **Never pass `lv = ~ ...` to `latent()`** -- gated to all-Gaussian or pure-binomial fits
   (`R/lv-predictor.R:123-132`) and aborts. Plain `latent(0 + trait | cell, d = k)` is
   family-agnostic and is what this lane uses.
4. **Set `cluster` explicitly.** The default collapses levels in a way you do not want when rows
   are duplicated per source.
5. **`unit` is the argument** (`site` is a deprecated alias). A naive call errors
   `Column site not found in data`, which looks like a wide-format defect and is not.
6. **The correlation metric is vacuous at `d = 1` under a rank-1 Sigma** -- every off-diagonal is
   exactly +-1. And an all-binary trait cannot estimate psi at all (`R/fit-multi.R:4976` maps
   `theta_diag_B` **off**, not merely floors it). Both bit Phase A's scoring design.
7. **`a = 1` is an identifying assumption, not a convenience** -- and because `b0` is shared, the PO
   offset must be in units where the PA site area equals 1, or the mismatch is silently absorbed by
   `a0` with **no error**.
8. **Generate the PO DGP on the same grid the fit uses.** Aggregating a continuous field makes
   `E[e^eta] != e^E[eta]` and attenuates `beta-hat` for reasons unrelated to whatever you are testing.

**Failed approaches -- do not retry:**
- Scoring identifiability-vs-estimability from cross-seed spread alone. It **cannot** separate them;
  a flat ridge and a sharp-but-shallow one inflate it identically. Use the n-ladder log-log slope
  and within-dataset multistart.
- A T=2, d=1 gate. `df = T(T-3)/2` = **-1**: under-identified regardless of the family question.
- Arguing structurally that wide format cannot work. It **does** -- measured (`76eb5e7c`).
- Arguing NB2-vs-cloglog from the *marginal* distribution. That criterion condemns the recommended
  fix too; the real argument is that gamma mixing is arm-local (section 2).

---

## How to resume -- one paste

Start Codex in the repo (it reads `AGENTS.md` natively) and paste:

```text
Rehydrate from docs/dev-log/handover/2026-08-08-codex-handover.md + the CLAUDE.md Live Phase
Snapshot, then continue with the Next Immediate Steps (section 5). Start at step 1: establish from
the Phase C workflow journal what actually completed, commit it, and continue Phase C from there.
Do NOT rebuild Phase A or Phase B -- both are landed and verified.
```

Then, before anything else:
```sh
cd ~/local-scratch/worktrees/gllvmtmb-isdm && bash ~/shinichi-brain/tools/lane_preflight.sh .
git log --oneline -6 && git status --short
```

---

## 12. LOOSE ENDS found on final sweep — not filed anywhere else

**(a) A latent warm-start defect for mixed-family traits. NOT FILED as an issue.**
`R/init-warmstart.R:99-113` (`single_trait_warmup`, reached via `control$init_strategy`) picks
`fam_t <- family_per_row[[rows_t[1L]]]` -- **the FIRST row's family only** -- and then fits a
univariate warm-start GLM over **all** of that trait's rows. For a trait spanning two families this
applies one family's dispersion slot to rows generated by another.

**Inert for this lane** because neither Poisson nor binomial has a `switch()` case there, so `slot`
resolves to `NA_character_` and nothing is applied. **But it is a genuine bug for any mixed trait
whose two families BOTH carry a `log_phi_*` slot** -- e.g. Gamma + nbinom2. It is also opt-in, so it
does not affect default fits. Worth filing before anyone extends per-row families beyond the
dispersion-free pair.

**(b) #945's second wrinkle is still true and untouched -- it gates #944.**
`weights` collides on the PA arm: for **binomial** rows `weights` means *number of trials*, and the
R side sets `weights_i = 1` there to avoid double-counting. So a **weighted joint likelihood cannot
currently down-weight the PA arm** -- which is exactly the arm Fletcher et al. (2019, Eq. 10) argue
should carry *more* weight. Fixing it needs a separate likelihood-weight channel or an explicit
exception. Nothing in this lane touched it.

**(c) Default starting values on a mixed-family fit are poor, though not wrong.**
The `b_fix` OLS init (`R/fit-multi.R:2801-2848`) gates on `log_link_only` and `has_multi_trial`;
a Poisson + single-trial-Bernoulli mix satisfies neither, so it falls through to a plain
`lm.fit(X_fix, y)` on **raw, untransformed `y` mixing counts and 0/1 values**. This is a
starting-value quality issue, not an objective-correctness one -- and it is **pre-existing and
general** (any Gaussian + binomial fit hits it today), not specific to per-row families. Measured
cost at toy scale: ~2 extra optimiser iterations, identical optimum. **Untested at campaign scale**,
where it is the likeliest source of any convergence trouble.

## 13. DELIBERATE OMISSIONS — declared, not forgotten

- **The D-43 completion panel never fired.** The plan said it fires once if Phase A returned a PASS
  *that would become a claim*. It passed, but **nothing public left the lane** -- no export, no NEWS,
  no article, no register row. So the panel was not triggered. **If any Phase A number is ever
  promoted to a user-facing claim, the panel must run first** (3 fresh agents, distinct lenses,
  default NOT-DONE, >=2 NOT-DONE withholds the claim).
- **Melissa's plan-vs-actual reconciliation (Phase 4.5) never ran.** Planned-vs-actual drift for this
  arc is therefore unrecorded. Known deviations, declared here instead: S1 was promoted Haiku ->
  Sonnet (it adjudicated a disputed claim rather than inventorying); the campaign ran locally rather
  than on Totoro (6.43 core-hours -- remote deploy plus a TMB compile would have cost more, and Phase
  C's design re-derives the same rule); and the gate's primary metric changed from R off-diagonals to
  Lambda recovery mid-flight, forced by the rank-1 +-1 identity found during the smoke.
- **Phase A's `d = 1` limitation.** Rotation is nearly trivial at `d = 1` (only a sign is free), so
  nothing in Phase A speaks to `d >= 2`, where the triangular constraint must be imposed before the
  eigen-spectrum means anything. Phase C's design uses `d = 2` and does **not** inherit Phase A's
  gate result -- it is a different regime.

---

## 14. GITHUB ISSUE LEDGER — read before touching any of these

**Nothing in this lane is on `main`.** Every code change lives on an unmerged branch. That makes the
issue states counter-intuitive, so they are spelled out:

| issue | what this lane did | what to do with it |
|---|---|---|
| **#945** | **REFUTED by measurement.** Its claim that a mixed-family-within-species fit "cannot be run today" is wrong; `family_var` is a join key, not a trait mapping. | **Correct the issue** with the evidence (`dev/isdm-probe-findings.md`). Do NOT close it silently -- its *second* wrinkle (the `weights`/n_trials collision, section 12b) is still live and gates #944. |
| **#946** | **IMPLEMENTED, tests green -- but worktree-only, NEVER merged to `main`.** | **DO NOT CLOSE.** An issue closed against unmerged work reads as shipped and is invisible to every user. Close only if and when this lands on `main`. |
| **#943** | Designed and pre-registered (`dev/isdm-phase-c-design.md`); harness built; **NOT smoked, NOT run**. | Continue. The NO-GO gate stands. |
| **#944** | Untouched. Section 12b explains why it is still blocked. | Open. |
| **#941** | Umbrella. Phase A + B evidence now exists but no capability is advertised. | Open. |
| **#942** | Already closed and correct. | Leave it. |

**A new issue should be filed** for the warm-start defect in section 12a. It is not covered by any
existing issue.

## 15. ARTIFACTS OUTSIDE THIS REPO

- **Brain note** (durable finding, committed to the vault):
  `~/shinichi-brain/memory/gllvm-latent-factor-survives-two-likelihood-curvatures.md` -- carries the
  five generalisable lessons, including that cross-seed spread cannot separate a flat ridge from a
  shallow one, and the corrected NB2-vs-cloglog argument.
- **The plan that produced this arc**: `~/.claude/plans/bright-honking-brook.md` -- includes the
  three-lens plan review (Fisher/Gauss/Rose) that caught the rev-1 gate design before any compute was
  spent, and the full D1-D7 instrument specifications. Outside the repo, so **Codex will not see it
  unless told**; its conclusions are reproduced in the Phase A after-task report, but the instrument
  specs are only there.
