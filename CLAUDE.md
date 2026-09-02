# Claude Code Instructions for gllvmTMB

This repository is shared by humans, Codex, and Claude Code. Read
`AGENTS.md` first; it is the source of truth for project rules.

## Live Phase Snapshot — 2026-08-17

> **🔴 MULTI-LANE REPO — this snapshot is NOT a single lane's status.** No one bullet
> represents the project. **The lane map is authoritative for ownership:**
> `docs/dev-log/handover/2026-07-25-active-lane-split.md`, which names EACH lane's own
> current handover. Read it before any repository mutation. Milestone state is not in
> either place and must be re-derived from `git`.

- **2026-08-20 — SDM ARTICLE SET IS LIVE; PREDICTION-UNCERTAINTY ARC AT ~45%; FOUR API
  GAPS FILED WITH MEASUREMENTS.** `main` @ `147da385`. Merged: the **reader-first SDM
  article set** ([#1180](https://github.com/itchyshin/gllvmTMB/pull/1180) — new
  `sdm-start-here` front door with a decision tree, new `unit-of-analysis`, both iSDM
  articles rewritten, vocabulary extended), the **ADREPORT marginal slope SDs**
  ([#1175](https://github.com/itchyshin/gllvmTMB/pull/1175), `src/` — Rose's seven
  CHANGES-REQUIRED items all addressed), **Design 129** (the estimand for prediction
  uncertainty at new locations, [#1183](https://github.com/itchyshin/gllvmTMB/pull/1183)),
  and three fixes (#1184 site build, #1185 nav, #1186 a routing error in the new front
  door). Site verified live BY CONTENT; local suite **FAIL 0 / PASS 16311**.
  🔴 **The maintainer's standard now governs all reader-facing work:** *"can an ecology
  graduate student read this for the first time — will it be useful?"* — plain language in
  articles AND in reports to him.
  **Four gaps filed with measurements, not opinion:**
  [#1192](https://github.com/itchyshin/gllvmTMB/issues/1192) per-source observation models
  (hand-masked bias columns fail **silently**; 34–48 h to build),
  [#1195](https://github.com/itchyshin/gllvmTMB/issues/1195) `animal_slope`/`phylo_slope`
  undiscoverable (the three syntaxes users try all refuse without naming the one that
  works), [#1196](https://github.com/itchyshin/gllvmTMB/issues/1196) **one species-varying
  slope per MODEL** — `phylo_slope(lat | trait, tree =)` fits cleanly and keys on `trait`
  directly, but two slope terms are refused outright, and
  [#1161](https://github.com/itchyshin/gllvmTMB/issues/1161) narrowed (phylogeny DOES reach
  the species axis for slopes; the gap is specific to `Sigma`).
  **Next: prediction-uncertainty implementation — READ Design 129 first**, it settles a
  three-regime split whose third regime must REFUSE rather than fall back to a prior.
  **START HERE:** `docs/dev-log/handover/2026-07-25-active-lane-split.md` (the lane map is
  authoritative — 10 lanes live), then
  `docs/dev-log/handover/2026-08-20-codex-handover.md` for this lane.

- **2026-08-17 — iSDM OWED-1 EXECUTED: predict() probed; core CERTIFIED, map surface
  SCOPED, article FENCED.** Lane `claude/isdm-predict-20260817` ran the handover's
  ranked step 1 to its prescribed fork, then survived an Opus adversarial verify
  (PASS-WITH-CORRECTIONS, all applied). Certified (16-assertion
  `test-isdm-predict.R`): in-sample `predict()` == `report$eta` (offset + all REs;
  the spatial/SPDE instance probe-measured only); **training-row**
  `type = "response"` dispatches each row's own arm inverse link;
  exact non-spatial `newdata` link-scale round-trip; in-sample `se.fit` + classed
  newdata refusal. 🔴 **Measured and NOT fixed here (Design 126 + register ISDM-03),
  three newdata defects in one function:** every RE tier except
  `rr_B`/`diag_B`/`propto` silently dropped (spatial measured: dropped sd 0.381 vs
  eta sd 0.949, an identity — reproduced on a non-isdm gaussian spatial fit) while
  printing "random effects added"; `re_form` ignored in-sample and only literal
  `~0` honoured on newdata; `newdata` + `response` applies a per-trait MODAL family
  — the wrong arm on every isdm fit (detection "probabilities" up to 2.32); plus no
  `A_proj` projection at new locations. **The map-making article is FENCED until those land** — issue texts
  drafted in Design 126 §5, filed after maintainer review. OWED-2 advanced exactly
  to its D-139 gate (`docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md`
  — 🔴 needs approval; nothing launched, D-157 honoured) and OWED-3 to a candidate
  list (`…isdm-flagship-candidates.md`, UNVERIFIED — 🔴 needs the taxon pick).
  PR #1113 (the handover itself) merged on green by this lane.
  **START HERE:** `docs/dev-log/after-task/2026-08-17-isdm-predict-probe.md`.

- **2026-08-17 — EVIDENCE/DIAGNOSTICS LANE: two questions answered, nine families
  greened, one halt missed.** Merged #1050/#1066/#1074/#1085/#1086/#1089/#1091/#1093.
  **Non-Gaussian REML is CLOSED with a pre-registered negative** (Cox-Reid worsens bias;
  binomial 7.26→10.84pp, ordinal 3.08→4.39pp; `allow_nongaussian_reml` stays opt-in,
  unpromoted). **Exact residuals 4/17→13/17 families; `simulate()` 8/17→16/17** (multi-trial
  binomial had been silently Bernoulli, #1079). Board corrected on three counts: VA restored
  across all 18 scalar cells, REML recorded as a *tested negative*, gaps box reframed to
  **0.7.0**. Compute-admission slice built (Design 124) and used for a 21,600-fit Design 122
  campaign (365 core-h). 🔴 **Its K1 halt fired on pre-run data nobody tabulated — every
  accuracy number is PROVISIONAL until #1092** (`aghq_ridge` is an R-level penalty outside
  `tmb_obj$fn()`, so `gr()` and `fit_health$max_gradient` report the wrong objective on any
  ridged fit). VA shows no demonstrated payoff over the cheap ridge; K4 fired in the
  *transfers* direction, so the motivation for a non-Laplace route survives.
  **START HERE:** `docs/dev-log/handover/2026-08-17-claude-handover.md`.

- **2026-08-17 — LA-MSPL OVERNIGHT ARC CLOSED TO CURSOR HANDOVER.** D-157 B1 **SIGNED
  PARK** (no second campaign; `MSPL-04` blocked; no Totoro relaunch; later intervals =
  new construction). Point admits: binomial / gaussian / poisson (experimental). Internal
  SE pins live; public `se` withheld. CI triad docs (#1075) + Poisson W G0 (#1076) are
  **UNSIGNED** — STOP there unless Shinichi pastes. Profile scaffold DRAFT #1077 waits
  triad G0; optional #1065 planned-only fix only. **PROTECTED:** Codex
  `codex/lane-b-mspl-interval-feasibility`. Worktree
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` (not Dropbox). **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then
  `docs/dev-log/handover/2026-08-17-cursor-handover.md` for the MSPL overnight baton
  (other lanes keep their named handovers in the split table).

- **2026-08-15 — LA-MSPL CATCH-UP + GAUSSIAN ORDINARY CLOSED; NEXT = POINT EVIDENCE LANE.**
  *(Historical kit closeout — baton superseded by 2026-08-17 overnight handover.)*
  On `main`: **#963** Phase 2 registry, **#966** uniqueness pick C, **#967** Gaussian Hirose
  `admitted`/`oracle_local`, **#968/#969** LOOP closeouts. Estimator is **LA-MSPL** (not EVA/VA,
  not AGHQ-MSPL). Closed kits `cursor-mspl-catchup` / `cursor-mspl-gaussian` — do not reopen.
  **PROTECTED:** Codex `codex/lane-b-mspl-interval-feasibility` (binary SE). Worktree only
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` (not Dropbox). **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then
  `docs/dev-log/handover/2026-08-17-cursor-handover.md` for current MSPL (historical kit
  note: `2026-08-15-cursor-handover.md`).

- **2026-08-08 — CRAN 0.7 TRACK PICK LOCKED; HANDOFF TO CODEX (LIVE TOOLCHAIN).**
  Shinichi G0 answers: **(1)** Ada default tarball — leave-M5 hygiene + Rose fence + later
  `0.7.0` bump; **keep #949** VA Arc-1 on main (fenced, `calibrated=FALSE`, Laplace default);
  do not revert VA. **(2)** INCLUDE / more testing — **not** Ada’s “(a) none”; first CRAN
  **not imminent**; Codex inventories validation-debt from the repo and proposes a concrete
  INCLUDE + test programme (do not assume #750/#332/one-slope). **(3)** Portal offline until
  **19 Aug 2026**; even after that **do not aim for first portal day**; upload Shinichi-only.
  Path A `v0.6.1-rc.1` @ `6a58683c` retained as failure archive. `DESCRIPTION` still `0.6.0`.
  Worktree `/private/tmp/gllvmtmb-cran-0.7-20260807` · `cursor/cran-0.7-20260807`.
  **START HERE:** `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then
  `docs/dev-log/handover/2026-08-08-codex-handover.md` for this lane.

- **2026-08-17 — iSDM PROGRAMME IS PUBLIC, DOCUMENTED, AND DEPLOYED; next arcs ranked.**
  The 2026-08-15 "public front door" step is DONE (#1016/#1027/#1030 → main via #1031,
  first CI green); the pkgdown Species Distribution Models collection (6 articles,
  four-lens audited) is live; version 0.7.0; Paper × Items re-aimed around
  ridge-vs-MSPL matched remedies. Register rows ISDM-01/02 stay `partial`; no
  calibrated intervals. **Do NOT rehydrate iSDM from the 2026-08-15 handover — it
  recommends work that already shipped.** Ranked next: predict()/maps probe,
  calibrated-uncertainty campaign, real-data flagship (needs Shinichi's taxon pick).
  **START HERE:** `docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md`,
  then the lane map (other lanes keep their named handovers).

- **2026-08-02 — DESIGN 108 GATE A IS CLOSED; 10,000 SPECIES IS NOW REACHABLE.**
  Stages **4** ([#896](https://github.com/itchyshin/gllvmTMB/pull/896) — tail-safe `log Phi` +
  binomial-probit, **verdict AD-SAFE**, adversarially established against a 3,744-cell break grid)
  and **6** ([#907](https://github.com/itchyshin/gllvmTMB/pull/907) — multiple unstructured tiers,
  the stage that CLOSES Gate A) are on `main`, with **R3** (same PR — the opt-in
  `profile_variational` route). **Stage 7** (structured phylogenetic KL) is open as
  [#911](https://github.com/itchyshin/gllvmTMB/pull/911).
  **R3 removed the programme's real blocker:** `MakeADFun(random = NULL)` made nlminb's workspace
  O(P^2) — measured, matching `n(n+27)/2` doubles to 2% at n=16,000 — i.e. **1,127 GB at N=5,000
  and 4,508 GB at N=10,000** for the target model. The profile route collapses the outer problem
  from `114N + 206` to **206, constant in N** (RSS exponent 1.70 → 0.966; at N=8,000 the joint
  route did not finish 3 iterations in 23 min at ≥6.4 GB, profile took 1,697 MB / 12.5 s). It is
  **opt-in and default-off** — SEs under `profile=` are untested. **EVERYTHING REMAINS FENCED:**
  no export, no `method=`, no NEWS/README/article claim. 🔴 **Recommended next arc: the
  VA-vs-Laplace recovery study, BEFORE Stages 3 and 5** — this session's 4,320-fit campaign partly
  undercut Design 108 §0.2's own justification (Laplace silent divergence decays with n, 18.1% at
  n≤150 → 0.6% at n≥1600, and `aghq_ridge = 2` suppresses it), and Stage 7 records the
  tips-vs-augmented question as statistically unsettled. Also corrected on `main`: the
  *"67% runaway"* comment (wrong arm AND no regime — it needs logit **and** p=6 together), the
  H=61 reach (**±14.4985 SD**, not ±15.7), and Design 108 §6's stale `family == 3`.
  Filed [#897](https://github.com/itchyshin/gllvmTMB/issues/897): `ordinal_probit` has **no**
  degeneracy detector (239/239 unflagged where binomial catches 272/272).
  **START HERE:** `docs/dev-log/handover/2026-08-02-claude-handover-gate-a-closed.md`.

- **2026-08-02 — CRAN IS OFF THE TABLE; EVIDENCE LANE CLOSED; CAPSTONE IS NEXT.**
  Shinichi: *"do not worry about CRAN submission — I am not intending to do so."*
  Everything CRAN-shaped is descoped (3-OS, URL/DESCRIPTION polish, submission
  prep); **#345 loses its first half and the paper is what remains**. Merged
  [#900](https://github.com/itchyshin/gllvmTMB/pull/900) (internal held-out CV
  layer + known-truth fixture + block-conditional recovery tests),
  [#901](https://github.com/itchyshin/gllvmTMB/pull/901) (glmmTMB corpus adopted;
  Design 87 latent-variable oracle map; #800 closed),
  [#903](https://github.com/itchyshin/gllvmTMB/pull/903) (validation-oracles
  article) and [#906](https://github.com/itchyshin/gllvmTMB/pull/906)
  (CI-08 audit + `bootstrap_Sigma()` `$coverage_ceiling` guard). **No new
  exports.** Two long-standing claims were found FALSE and corrected in place:
  the *"13/15 cells below 94%"* headline is a **retired gate on a
  rotation-variant `psi` proxy** (PR #364 fixed the estimand on 2026-05-31), and
  *"the exported `bootstrap_Sigma()` covered 0.78"* was **`n_boot = 10`** against
  a default of 200 — at B ≥ 200 it reaches 0.9418 (profile route 0.9491).
  `--as-cran` at `fdefbb91`: **0E/0W/2N**, the only actionable note fixed in
  [#908](https://github.com/itchyshin/gllvmTMB/pull/908) (**UNMERGED**).
  **DESCRIPTION on `main` is already `0.6.0` — the Dropbox checkout says 0.5.0
  because it is 639 commits behind; it is NOT `main`.** Next: **scope the
  power-study capstone (Design 66) as the paper's evidence chapter** — planning
  only, needs Shinichi on cells/seeds/families/gate/compute; **no campaign at
  `n_boot < 200`**. **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then
  `docs/dev-log/handover/2026-08-02-claude-handover-evidence-capstone.md` for
  this lane (other lanes keep their named handovers in the split table).

- **2026-08-02 — DESIGN 108 GATE A STAGE 2 LANDED (VA mixed-family).** PRs
  [#891](https://github.com/itchyshin/gllvmTMB/pull/891) (Stage 1 mask) and
  [#893](https://github.com/itchyshin/gllvmTMB/pull/893) (Stage 2 mixed-family +
  per-trait `log_sigma`) merged; register VA-10/VA-11 `partial`; no public claim.
  Stage 3 lognormal vs Stage 4 probit needs Shinichi G0 — do **not** auto-start.
  Dropbox `claude/profile-coverage-remeasure-20260718` stays **PROTECTED** dirty
  (D-112). Sibling [#890](https://github.com/itchyshin/gllvmTMB/pull/890) is a
  separate missing-data ledger lane. **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then
  `docs/dev-log/handover/2026-08-02-claude-handover.md` for the VA baton (other
  lanes keep their named handovers in the split table).

- **2026-08-01 — MISSING-DATA LEDGER CLOSED (#336/#337/#338).** Phase 2b/2c/3
  engines were already on `main` (MIS-27/MIS-28 `covered`). Ledger lane
  `cursor/missing-data-ledger-336-20260801` added the #336 shared-group
  independence pin and closes the open issues. Do **not** rebuild Phase 2b.
  D-112 remains **0.6 recovery-only**; do not resume coverage re-measure.
  **START HERE:** `docs/dev-log/after-task/2026-08-01-missing-data-ledger-closure.md`,
  then the lane map above. **Default next D-113 lane:** Design 107 VA
  missing-data (Ayumi); tweedie remains the alternate gap-ledger pick.

- **2026-08-01 — D-113 BETABINOMIAL C1 SLOPE ADMISSION LANDED.** PR
  [#887](https://github.com/itchyshin/gllvmTMB/pull/887) squash-merged at
  `2716f74b`: `betabinomial` `family_id` 8 now has the large-N
  (`n_sp = 200`, trials = 15) C1 augmented-slope recovery cell under #388.
  D-112 remains **0.6 recovery-only**; do not resume coverage re-measure.
  Prior Cursor handover: `docs/dev-log/handover/2026-08-01-cursor-handover.md`
  (historical for the slope closeout; its "next pick" is superseded by the
  ledger-closure note above). Missing-data #336/#332 remains on the D-113 menu
  alongside Design 108.

- **2026-07-31 (LATEST) — VA IS ROUTED AND GATE 3 HAS REPORTED.** Lane
  `claude/va-routing-20260731` (fast-forward of `claude/va-in-06-20260730`, **PR #869**).
  `gllvmTMB(control = gllvmTMBcontrol(integration = "va"))` now returns a real
  `c("gllvmTMB_va","gllvmTMB")` fit; the admission fence is reachable at last (it could never fire
  before, because `gllvmTMB()` aborted before `q`/`p`/`n`/family/link existed); and every
  likelihood-shaped method fails loudly, verified under a real `R CMD INSTALL`.
  **Gate 3 (2,160 datasets x 3 arms, run on Totoro) settled two open questions and the maintainer
  decided both: estimator = JJ, rule = R2.** `va_jj` clears the full frozen conjunction in **100% of
  q <= 2 cells under BOTH pre-declared rules**; `va_gh` was measured and **rejected**. `q = 4` was
  measured and **failed** on axis collapse at p = 8, so **the fence ships at `q <= 2`, not 4** —
  narrower than hoped and further from A3's 5+ factors, stated rather than buried.
  **`"eva"` is no longer an admitted value** of `integration`: EVA gives valid inference for the
  coefficients but not for `Lambda Lambda'`, this package's estimand — and gllvm's own EVA hits the
  identical pathology while reporting `convergence = TRUE` on 71% of blown-up fits.
  🔴 **Read the corrections before citing any Gate 3 number.** The first two reporting passes were
  BOTH wrong — a conjunction reported as its RMSE half, then an over-correction that denied a
  conclusion the evidence supports — and a 3/3 NOT-DONE panel caught them. The collapse criterion
  **cannot rank the arms**: va_gh's detector fires zero times in 6,480 rows.
  **START HERE:** `docs/dev-log/2026-07-31-gate3-result-corrected.md`, then
  `docs/design/35-validation-debt-register.md` Section 15 (VA-01..VA-09), then the lane map.
  **Needs Shinichi:** nothing blocking on this lane.

- **2026-07-30 — THE SCALE-DEPENDENT-CONSTANTS CLASS NOW HAS AN OWNER AND EVIDENCE** (this
  resolves a "Needs Shinichi" flagged twice below). 8 PRs merged (#832, #839, #842, #845, #846,
  #849, #854, #858); `R/` touched only by the #832 export. **It is a CLASS, not a bug** — ~10
  instances, 10 confirmed by fitting at 1x and 10x/0.01x — with one generative mechanism: the
  package argues from *"latent scores are standardised N(0, I)"* and then applies constants to
  **Lambda**, but standardising the latent is exactly what pushes the response scale INTO Lambda.
  **🔴 The worst instance (#851) is far broader than the loadings:** at sd(y) ~ 9268 *every*
  reported quantity is wrong — Sigma, fixed effects, logLik, and **correlations and communality
  (rel.err 1)** — with `convergence = 0` and a PD Hessian throughout. **Two fixes were built and
  WITHDRAWN** (see the handover's Gotchas; do not retry scale-Lambda-alone, and do not use
  `||Lambda||/k` as an acceptance test — use `dev/scale-equivariance-check.R`, both blocks).
  Also: **AGHQ's integrator is CORRECT** (six independent checks) while **its estimator is NOT
  established**; and **D3 is decided** — keep the ridge, fix tau (#847), because the ridge cuts
  runaway 32% -> 8% at `lam_sd = 3` even while costing sigma. New: #851, #855 (standardisation
  design, feasibility gate COMPLETE), #856 (`log_sigma_eps` is a scalar shared across all gaussian
  AND lognormal rows while every other family's dispersion is per-trait).
  **START HERE:** `docs/dev-log/handover/2026-07-30-claude-handover-scale-constant-lane.md`, then
  the lane map. **Needs Shinichi:** #856 (deliberate or incidental? it gates #855), and the
  sequencing call between #851/#855 and #847/#848.

- **2026-07-30 — SESSION CLOSED; the re-aimed degeneracy campaign is APPROVED and
  UNSTARTED.** `main` @ `bef1a5aa` (#840 + #850 merged). **🔴 The campaign's original premise was
  refuted pre-flight, by measurement:** VGH's 0/148 does **not** survive at larger q/p — at
  n=40/p=80/q=4, `rel_frob` 10.671/10.449 on 2 of 4 seeds, `atten_F > 2` on 4 of 4, `max|Λ|`
  8.53–12.53, and **`converged = TRUE` on every one** (structural — `R/va-vgh.R:603` only tests
  `outer < maxit`). **So VGH's convergence flag is no more trustworthy than Laplace's**; the "98%
  silent failure" property is **shared**, not Laplace's alone. The 0/148 held only at n≥60, p≤12,
  **q=2** — and `q` was never a grid column. **Do NOT open an engine-building arc on that figure.**
  The campaign is re-aimed to *"where is the boundary in (n,p,q), and is the winning region worth an
  engine?"* **START HERE:**
  `docs/dev-log/handover/2026-07-30-claude-handover-campaign-approved.md`, then the scope doc's READ
  FIRST section, then the lane map. **Needs Shinichi:** routing the drafted D3 request
  (`2026-07-30-request-to-la-aghq-ridge-lane-take-D3.md`), and an owner for the
  scale-dependent-constants class.

- **2026-07-30 — GAUSSIAN ARM MERGED (#840, `main` @ `7ed3f238`); the pluralist
  route is established as a NON-GAUSSIAN proposition.** On gaussian, Laplace is exact and
  the VGH ELBO is exact, so **both engines optimise the same objective** — "which estimator
  is more accurate" is not a well-posed question there, and VGH's KL-based anti-degeneracy
  mechanism is **switched off** (a tight bound means `KL = 0`). The reported VGH
  log-likelihood advantage was **degrees of freedom**: matched at 60 free parameters `d_ll`
  collapses from a median 9.96 to max 8.3e-07 over 24 cells, `2·d_ll ~ χ²₁₉` fits the whole
  distribution (KS p = 0.810 / 0.901). Gaussian also has **no loading-runaway tail for
  either engine** (59 fits, `max|Λ̂|` below each dataset's largest trait SD, ratio ≤ 0.961;
  the gaussian marginal likelihood is coercive in Λ). Also shipped: three `dev/` engine
  fixes (`d = 1` crash, stale `$elbo`, `q = 1` coverage), each with a test proven to fail
  against the defect. `--as-cran` **0E/0W/1N**; CI green; `R/` and `src/` untouched.
  **⚠ Two claims from this lane were RETRACTED** — `loading_absolute_thresh = 6` is
  **binomial-gated and never evaluates on a gaussian fit** (`R/diagnose.R:464-471`), so any
  "gaussian stays under the threshold" statement is void; and the 2026-07-29 docs were
  wrongly accused of a category error. See the handover's Retractions section before citing
  anything from this arc.
  **CONVERGENT with #842** (the AGHQ/ridge audit): across 432,000 fits `aghq = k` returns
  the Laplace warm start bit-for-bit **89.6%** on gaussian and AGHQ *"helps binomial only,
  and only at large n"* — two unrelated alternatives to Laplace, same verdict, arrived at
  independently.
  **NEXT ARC CHOSEN by Shinichi:** VGH degeneracy at scale on the non-gaussian grid, to be
  ultra-planned **in a NEW lane** (the pluralism lane is merged and closed).
  **START HERE:** `docs/dev-log/handover/2026-07-30-claude-handover-lane-transition.md`,
  then the lane map above.
  **🔴 Needs Shinichi:** D3 from #842 (the ridge's `τ = 2` is ON by default, net-harmful or
  inert at every measured scale, and composes with D4 into a silently penalised fit) has
  **no owner**; and the scale-dependent-constants class it shares with
  `loading_absolute_thresh` spans two lanes, so it falls between them by default.

- **2026-07-30 — HEYWOOD GATE MERGED (#838, `main` @ `a51ca881`); VGH
  PLURALISM LANE OPEN.** *(Superseded above: that lane is now merged as #840 — it is no
  longer "unpushed", and the gaussian arm no longer "remains".)* `check_gllvmTMB()` now reports **both faces** of a Heywood
  case: a runaway loading (`loading_runaway_thresh = 25`, plus a link-scale
  `loading_absolute_thresh = 6` judged on the unit tiers only) and a unique variance
  collapsed relative to its siblings (`psi_rel_thresh` 0.001 → **0.01**). The
  denominator is now taken over the traits being screened, so a large-scale trait from
  another family can no longer mask a binomial runaway. **`aghq_ridge` is announced in
  NEWS** — a measured 47% → 0% runaway remedy that was previously undiscoverable.
  Calibrated on ~12,400 fits across thirteen cells; `--as-cran` 0/0/1.
  **This is a BEHAVIOUR CHANGE**: fits that previously passed will now warn.
  **START HERE:** `docs/dev-log/handover/2026-07-30-claude-handover.md`, then the lane
  map `docs/dev-log/handover/2026-07-25-active-lane-split.md`.
  Open lane `claude/vgh-pluralism-20260730` (**unpushed**) carries the follow-on: VGH
  has **0/148 degenerate fits where Laplace has 50/148, 49 of them silent**, so the
  gate is a Laplace-specific patch for a pathology VA does not have. Slice 1 (a
  matched-parameterisation accuracy run) is **half done** — binomial is already matched
  because it carries no dispersion parameter; the gaussian arm remains.

- **2026-07-28 — AGHQ ENGINE LANE: BUILT, OPT-IN, DEFAULT UNCHANGED.**
  Lane `claude/aghq-engine-20260728`, 20 commits, **not pushed, no PR**.
  **START HERE:** `docs/dev-log/handover/2026-07-28-claude-handover-aghq-engine.md`,
  then the lane map `docs/dev-log/handover/2026-07-25-active-lane-split.md`.
  AGHQ ships **opt-in** (`gllvmTMBcontrol(aghq = k)`); **the default is still Laplace and
  no existing user's numbers move**. Headline: Laplace carries a flat **~21% downward
  bias that 16× more data does not touch** (its error is O(1/T), per CLUSTER), while AGHQ
  reaches **1.0021 at n = 3200**. With a weakly-informative ridge on the loadings
  (`aghq_ridge = 2`, on when AGHQ is on) it beats the shipped Laplace on **both** latent
  SD and correlations at every n tested (954 fits, Totoro). **Name the comparator** — a
  hypothetical penalised Laplace edges rho at n ≤ 200. **NOT done:** the family axis
  (binomial-only evidence), the D-43 panel, and any coverage/interval evidence.
  The invariant to re-check after ANY engine edit: **gaussian exactness ~1e-13 and
  k-independent**. Durable finding in the brain: *"AGHQ exposes a flat likelihood
  direction in GLLVMs — the runaway is bimodal, not biased."*
- **2026-07-28 (earlier, superseded by the bullet above) — AGHQ IS THE MAIN
  ENGINE.** Maintainer decision, `docs/dev-log/decisions.md` 2026-07-28: AGHQ
  becomes gllvmTMB's integration engine across all 16 families and all model
  classes, adaptive and auto-by-default. **This reverses the 2026-05-15 "stay
  Laplacian" decision**, whose grounds were sound but rested on reading the
  literature's `n_i` as sites rather than **traits per site** — the gain is large
  exactly where `T` is small. **The Arc 0 fence is LIFTED**: the 59/70
  identifiability question no longer gates the build; it becomes AGHQ's first
  acceptance test (H4). **PR #798 is MERGED** (`72c2e53d`). Lane:
  `claude/aghq-engine-20260728`, worktree
  `/private/tmp/gllvmtmb-arc0-identifiability`. Plan:
  `~/.claude/plans/starry-booping-starfish.md`.
  **Two standing corrections.** (1) *"AGHQ inherits all 16 families, phylogeny,
  spatial and missing data"* is **NOT ESTABLISHED as stated** — families and
  missing data survive; phylogeny and spatial **break** under a product rule and
  need a nested AGHQ-inside-Laplace decomposition; `REML = TRUE` is excluded
  outright. Use the narrower form recorded in `decisions.md`. (2) The AGHQ spike's
  **`1.4e-9` agreement is at ONE node, and one node IS Laplace** — it proves the
  plumbing, not the quadrature. Never cite it as evidence about `k > 1`.
- **2026-07-28 — VA/EVA + AGHQ lane (historical; see the bullet above).** **PR #799 MERGED** (`dc10fa6a`):
  a collapsed variance component could pass every check the package had
  (`near_zero_psi_unit … PASS … 0.0006826` for a component whose *variance* was
  `4.7e-7`) — now detected relative to siblings; `start_method = "res"`
  soft-deprecated on 89 fit-pairs. **PR #798 OPEN and CI-GREEN** (no API change,
  nothing exported): per-family registry (4/16 families, proven by porting
  `nbinom2` through it), **calibrated** VA standard errors (`se_profile` covers
  0.935–0.950; a block-diagonal Schur replaced a 5.45 GB dense Hessian with
  9.1 s / 220 MB at n=5397), and an Ayumi-scale second opinion (Laplace
  `rel_frob` 0.167 vs VA-GH **0.103**). **DECISION: invest in Laplace + AGHQ,
  freeze VA** — AGHQ inherits all 16 families plus the phylo/missing surface,
  whereas VA reaches 4/16 and covers 2 of Ayumi's 27 responses. The AGHQ q=2
  transfer test passed 5/5 (`c_full` 1.064; kill rule cleared). **NEXT ARC:
  settle the 59/70 identifiability question BEFORE building anything** — three
  hypotheses have died and the survivor is that those fits are well-converged
  optima of *unidentified* models, in which case no fit-side diagnostic can flag
  them and the deliverable is a warning, not a better estimator. Brief:
  `docs/dev-log/2026-07-28-morning-brief.md`; handover:
  `docs/dev-log/handover/2026-07-28-claude-handover.md`.
- **Multi-lane split:** do not assume one active writer.  The current Claude
  release/profile lanes and the remaining Codex-owned eta-simulation lane are
  separately fenced.  Do not edit or run the eta lane from Claude.
- **Current state:** Design-103 direct-GH mechanism diagnosis is privately
  closed `TECHNICAL_PARTIAL`; it produced no package/public claim.  The
  release/0.6 and profile/Tier-2a states must be re-derived from their named
  handovers before any edit.
- **2026-07-25 (latest):** the Site × Species phylo arc is **CLOSED** — capability
  **CANCELLED** by decision (no new API; the M3 freeze holds), two user-facing bug
  fixes plus the first `gllvm` fit-level comparators landed on `main`
  `a0f568d1..84ca8290`, and a D-43 panel returned **3/3 NOT-DONE** so **nothing was
  promoted**. The keyword grid was corrected to **5 × 3** across the rule files.
  **Next arc is UNCHOSEN** (not CRAN, not the paper — Shinichi reserved the choice);
  standing interest recorded in **EVA**. Handover:
  `docs/dev-log/handover/2026-07-25-claude-handover-arc-closed.md`.
- **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then the
  target-specific handover it names.

The older handoff narrative below is historical and must not override this
snapshot, the latest handover, or `AGENTS.md`.

For historical context, the former handoff was
`docs/dev-log/handover/2026-07-18-claude-handover.md` (Claude→Claude, 2026-07-18;
**the multinomial cross-family arc is SHIPPED to `main`** — item 1 matrix
`link_residual` (#758), item 2a-ii cross-family correlations +
`extract_cross_correlations()` (#761), and `unique = TRUE` default + the
`Psi = unique + link-specific` consistency fix (#762). A `multinomial()` trait now
shares a shared `latent()` factor with Gaussian/binary/count/ordinal traits and
reports genuine cross-family correlations. **NEXT arc (chosen 2026-07-18):
calibrated cross-family intervals** — attach certified-coverage uncertainty to
`extract_cross_correlations()`, closing the CI-08/CI-10 `heuristic_unvalidated`
debt (the 0.6→1.0 headline); the item-3 recovery certificate is deferred behind it.
Multi-seed always; Rose before any covered claim; compute local→Totoro (D-50).) Earlier:
`docs/dev-log/handover/2026-07-12-claude-handover-covariance.md` (Claude→Claude,
evening; the covariance-mode grammar campaign — Design 79/80, `scalar()`/
`kernel_scalar()`, `indep(1+x)` per-trait) before starting new work. Branch
`claude/release-0.5.0` is PUSHED with the doc-honesty cleanups (pages 4–6, LV +
register sweeps, reference/roxygen sweep, `validation_row` print-fix); the
`1.0.0 → 0.5.0` version correction (PR #748) is MERGED to `main`. Standing rule:
reader-facing content shows only what makes sense to the reader — no internal
register codes on any surface (articles, reference/roxygen, NEWS, printed output).
**gllvmTMB's first CRAN release is `0.6.0`, NOT 1.0 — settled 2026-07-19
(issue #772). D-42 (2026-07-11) established the principle "first release is a
0.x, NOT 1.0" and named `0.5.0`; that *number* was superseded by the 0.6
strategy, which is why the premature `v0.5.0` tag was dropped. D-42's other half
stands unchanged: 1.0 is reserved for the capability-maturity milestone (complete
surface + full story + committed-stable API), mirroring drmTMB's D-40.
`DESCRIPTION` and `NEWS.md` both read `0.6.0` as of `origin/main` @ `869e92b5` —
the earlier note that they "still read 0.5.0 and get bumped as part of the
release slice" is stale and has been removed.** The engineering (all five arcs
A–E, merged #737–#745, on `main` `e4188105`) is cross-OS verified — local
`--as-cran` 0E/0W/0N, 3-OS `R CMD check` passed, 4478 tests / 0 failures — but the
package is NOT submitted to CRAN. **The one thing NOT done — and the next session's
job — is the one-by-one human review of the pkgdown pages and the function docs
WITH Shinichi** (slow, deliberate; not a batch rewrite), where the honesty-fencing
lands (intervals framed recovery-only; delta/hurdle latent-scale correlation "do
not advertise"). The automated article cleanup is **open PR #746** (2 cut, 26
improved, pkgdown reorganised); the QG `animal-model` cut-vs-keep call is open. The
issue closeout is staged at `dev/issue-closeout-2026-07-10.sh` (Shinichi runs it —
reword its version strings to 0.6.0 first; the agent is safety-blocked from bulk
closes). CRAN submission is Shinichi's act. Toward the 1.0 maturity milestone:
Julia parity, the paper, the full coverage campaign. Earlier arc detail:
`docs/dev-log/handover/2026-07-09-claude-handover-arcs.md`; ultra-plan at
`~/.claude/plans/misty-snacking-papert.md`.
**`phylo_latent(unique=TRUE)` = structured + DIAGONAL ψ, NOT a non-phylo
ordination** (that is a second `latent` term) — a standing guard.

## Project Identity

`gllvmTMB` is a sister package to `drmTMB`, but it has a different
role:

- `drmTMB`: univariate and bivariate distributional regression.
- `gllvmTMB`: multivariate stacked-trait GLLVMs with phylogenetic
  and spatial extensions.

Keep `gllvmTMB` focused on the stacked-trait, long-format multi-
response model. Single-response models live in `glmmTMB`; spatial
single-response models live in `sdmTMB`.

For the full cross-package scope record (including `gllvm`,
`MCMCglmm`, `brms`, the decision matrix, and the "what gllvmTMB
does NOT do" section), see
[`docs/design/04-sister-package-scope.md`](docs/design/04-sister-package-scope.md).

## Syntax Rules to Preserve

- Use the canonical **5 x 3 keyword grid**: five correlation **sources**
  (none, `animal_*`, `phylo_*`, `spatial_*`, `kernel_*`) x three
  trait-covariance **modes** (`indep`, `dep`, `latent`). Every cell is a
  live keyword. Canonical surface:
  `vignettes/articles/api-keyword-grid.Rmd`.
- Structured-rho development arc (2026-08-31): canonical phylo/animal/kernel/spatial
  helpers have trailing `rho = 1`; spatial range stays separately estimated.
  New attenuation is one trait-intercept block (including folded Psi), and
  `rho = NULL` is restricted to complete replicated Gaussian observations
  without competing covariance. Source strength is separate from trait mode,
  ordinary variance components, coefficient rho, and variance-share summaries.
  Fixed attenuation and the admitted Gaussian estimator have completed their
  implementation/workflow gates. The spatial recovery study has 14 `partial`
  and 2 `blocked` cells, with no passing cell; range--rho recovery is therefore
  not a broad public claim. Contract and evidence:
  `dev/structured-rho/spatial-recovery/PLAN.md`,
  `dev/structured-rho/spatial-recovery/RESULTS.md`, and
  `.unlazy/structured-rho-spatial/GATES.md`.
- **`scalar` and `unique` are MODIFIERS, not modes.** `scalar` is
  `indep(..., common = TRUE)` (trait variances tied to one shared
  value); `unique` is `latent(..., unique = TRUE)` (the trait-diagonal
  Psi companion). Never restate the grid as "4 x 5" or list `scalar` /
  `unique` as modes -- that framing is superseded.
- The named **scalar family** (`scalar()`, `phylo_scalar()`,
  `animal_scalar()`, `spatial_scalar()`, `kernel_scalar()`) is
  **soft-deprecated** and emits a one-time warning; it fits the same
  model as `indep(..., common = TRUE)`. Likewise `unique()` /
  `*_unique()` are soft-deprecated: new standalone diagonal examples use
  `indep()` / `*_indep()`, ordinary `latent()` carries Psi by default,
  and `latent(..., unique = FALSE)` requests the old low-rank-only
  subset. Both families remain accepted compatibility syntax until their
  own removal slices land.
- Design 65's dense-kernel row (`kernel_indep()`, `kernel_dep()`,
  `kernel_latent()`) is part of the grid above, not outside it. C1 must
  stay phylo-equivalent for dense `K` inputs to less than `1e-6`.
- Ordinary `latent()` carries its diagonal Psi companion by default:
  Sigma = Lambda Lambda^T + diag(psi) (the Greek letter
  Psi; see `decisions.md` 2026-05-14 notation reversal).
  Use `latent(..., unique = FALSE)` only for the old loadings-only /
  rotation-invariant ordinary subset (`residual =` is a soft-deprecated
  alias for ordinary `latent()` only). Source-specific and kernel
  latent terms are loadings-only by default; use
  `phylo_latent(..., unique = TRUE)`,
  `animal_latent(..., unique = TRUE)`,
  `spatial_latent(..., unique = TRUE)`, or
  `kernel_latent(..., unique = TRUE)` for source-tier
  `Lambda Lambda^T + diag(psi)` decompositions.
  `unique()` / source-specific `*_unique()` /
  `kernel_unique()` remain soft-deprecated compatibility syntax; new
  standalone diagonal examples use `indep()` / `*_indep()` /
  `kernel_indep()`.
- `*_latent(..., unique = TRUE)` is the canonical source/kernel folded
  decomposition; explicit `*_latent(..., unique = FALSE) + *_unique()`
  remains accepted compatibility syntax, and duplicate
  `*_latent(unique = TRUE) + *_unique()` is an error. Standalone
  `phylo_unique` / `animal_unique` carry diagonal-only structure.
- `meta_V(V = V)` is the canonical meta-analytic
  known-sampling-covariance keyword. `meta_known_V(V = V)` is
  a deprecated alias. `block_V(study, sampling_var, rho_within)` is
  the helper that builds V.
- Wide data-frame input uses the simplified `traits(...)` LHS grammar:
  `traits(t1, t2, ...) ~ 1 + latent(1 | unit, d = K)`.
  The same shorthand covers `indep()`, `dep()`, and `spatial_*()`;
  ordinary `(1 | group)` random intercepts pass through unchanged.
  Long-format `gllvmTMB()` uses the explicit `0 + trait` /
  `(0 + trait):x` grammar. Both shapes go through one entry point:
  `gllvmTMB()`. The legacy matrix wrapper `gllvmTMB_wide(Y, ...)` is
  soft-deprecated as of 0.2.0 -- new code should use the formula API,
  and removal must not be claimed while the export remains live.
- Phase 56.3 parser work admits `phylo_unique(1 + x | species)` and
  `phylo_unique(0 + trait + (0 + trait):x | species)` as augmented-LHS
  syntax. Phase 56.4 adds Gaussian recovery, wide/long byte-identity,
  and forced-`n_lhs_cols` negative-test evidence for the anchor
  `phylo_unique` cell. Keep user-facing advertising and validation-debt
  promotion parked until the Phase 56.6 register / NEWS / article slice.

## Before Finishing Work

- Run the narrow tests you touched, then `devtools::test()` more
  broadly when practical.
- Update design docs if grammar, likelihoods, families, random
  effects, phylogenetic, spatial, or meta-analysis behaviour
  changes.
- Add or update an after-task report in `docs/dev-log/after-task/`.
- For substantial prose, apply the `prose-style-review` skill.
- Do not revert Codex or human changes unless explicitly asked.

## Collaboration Rhythm

Claude Code and Codex work sequentially, never concurrently, in this
repository. The baton can move in either direction through a landed handoff.
The usual role pattern is:

- Claude Code gathers evidence, writes read-only audits, drafts
  decisions, and identifies the smallest safe PR shape.
- The maintainer chooses the next task at a discussion checkpoint.
- Codex implements bounded code, documentation, CI, pkgdown, or
  NAMESPACE changes and records checks.
- Claude Code or Codex can review the result, but the reviewer should
  not silently expand the implementation scope.

Stop for maintainer discussion before deletions, API changes, formula
grammar changes, likelihood changes, new families, or broad article
rewrites. For the current reader-path work, examples should present
long-format and wide-format calls together unless the function is
intrinsically one shape.

After-task reports are the closure rule. Any completed task or phase
that changes project state should leave
`docs/dev-log/after-task/YYYY-MM-DD-short-topic.md` with scope,
outcome, checks, and follow-up. This mirrors the `drmTMB` team habit
and is how the shared team learns without re-reading the whole diff.

Use Shannon before handoffs with branch switches, merge-order
questions, or more than one open coordination PR. Shannon is a
read-only cross-team audit: it checks working-tree hygiene, open PRs,
file overlap, CI state, message-bus coverage, and after-task report
coverage. Shannon reports; it does not edit or merge.

### Merge authority

For the active five-macro 0.6 lane, the handoff is stricter than the general
rule below: do not merge draft PR #778 without explicit maintainer authority.

Both Claude Code and Codex may merge their own PRs when CI is green
and the PR is **low-risk**: documentation, dev-log entries, audits,
after-task reports, design docs, CI workflow tweaks, asset additions,
or individual article rewrites against an approved snippet. For
**high-risk** changes -- deletions of public exports, API changes,
formula-grammar changes, likelihood / TMB / family changes, broad
article rewrites -- the agent must ask the maintainer before merging.
The high-risk set is exactly the list above: deletions of public exports,
API changes, formula-grammar changes, likelihood / TMB / family changes,
and broad article rewrites.

### Integrate before adding

When the maintainer's input could fit an existing section in a doc or
plan file, integrate inline. Add a new section only for genuinely new
concerns. Reactive editing (every input becomes a new section) accretes
documents without improving them.

### Agent-to-agent handoffs go in the repo

When handing off a substantive task to the other agent, post a comment
addressed to them on the relevant PR, OR a directed line in
`docs/dev-log/check-log.md`. The async message bus is the repo; the
maintainer should not be the relay.

### Surface review asks explicitly

When opening a PR for maintainer review, follow up in chat with a
specific list of what the maintainer needs to check or decide. Do not
leave review items for the maintainer to discover by browsing the PR.

### Surface review touchpoints at stopping points (maintainer 2026-05-15)

At every natural stopping point -- task end, series-of-tasks end,
waiting on CI, waiting on permissions, end of a phase, before
switching context -- post a chat message that lists:

1. **Open PR links** (e.g. `https://github.com/itchyshin/gllvmTMB/pull/123`)
   that the maintainer can click to read.
2. **After-task report paths** that just landed or are about to land
   (e.g. `docs/dev-log/after-task/2026-05-15-day-recap.md`).
3. **Anything blocking** that the maintainer needs to decide or
   approve (prefixed with the 🔴 **Needs you:** chip per AGENTS.md).

The maintainer does not browse PRs on their own. The default
assumption is that if a stopping point arrives and the chat does not
surface links, the maintainer cannot review. This rule is durable and
applies to every session.

## Spatial-helper provenance and sister-package reuse

The R-side mesh and CRS helpers (`R/mesh.R`, `R/crs.R`) were substantially
rewritten against the public `fmesher` and `sf` APIs, but retain lineage from
the earlier GPL-3 `sdmTMB`-derived implementation. They preserve the
established `A_proj` and FEM (`M0/M1/M2`) interface consumed by the native TMB
likelihood. `inst/COPYRIGHTS` records the conservative attribution and pinned
source baseline. sdmTMB is not a runtime dependency. The retained
`plot_anisotropy*()` entry points now show the fitted isotropic practical
range (`sqrt(8) / kappa`) for native gllvmTMB spatial fits. Their equal axes
are labelled as the model assumption `H = I`, never as estimated anisotropy;
delta and spatiotemporal states fail clearly.

Selective reuse of A-inverse phylogenetic or further SPDE speed
modules from sister packages requires provenance notes in
`inst/COPYRIGHTS` and tests around the ported behaviour.
