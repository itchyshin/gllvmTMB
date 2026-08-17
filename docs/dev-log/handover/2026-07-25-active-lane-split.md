# Active-lane split — 2026-07-25

This coordination note prevents a new session from treating this repository as
a single writable lane.  It is a map, not a release/capability claim.

**Refresh 2026-08-17 #5 (Codex to Claude): finish #1092 only; wider Ayumi programme deferred.**
The implementation worktree `/private/tmp/gllvmtmb-1092-grad` is active on
`claude/fix-1092-penalised-gradient` and carries two pushed commits:
`e51738c9` (objective-consistent ridge gradient) and `bb6d1bdc` (restore DIA-11/DIA-12).
PR [#1106](https://github.com/itchyshin/gllvmTMB/pull/1106) is open and its first CI
run is in progress; the worktree has an untracked `.check.log`. There is no #1092
check-log closure or after-task report yet. Claude owns verification, closure records,
and CI for **#1092 only**, then must stop and hand back. Ayumi #25, Ayumi #23,
Design 122 compute, and all replies to Ayumi remain deferred. All sibling lanes are
**PROTECTED**. **START HERE:**
`docs/dev-log/handover/2026-08-17-claude-handover-1092-finish.md`.

**Refresh 2026-08-17 #4 (Codex to Claude): Ayumi #23-25 bug-fix programme assigned to Claude.**
P0 is the confirmed loading-ridge objective/gradient mismatch, package
[#1092](https://github.com/itchyshin/gllvmTMB/issues/1092) / Ayumi
[#24](https://github.com/Ayumi-495/urbanisation_map/issues/24). Reuse the already-created
clean branch `claude/fix-1092-penalised-gradient` at
`/private/tmp/gllvmtmb-1092-grad`; do not create a duplicate implementation lane.
Follow sequentially with Ayumi [#25](https://github.com/Ayumi-495/urbanisation_map/issues/25)
(mapped-off Psi warning, native `fitted()`, objective provenance) and
[#23](https://github.com/Ayumi-495/urbanisation_map/issues/23) (higher-order response
dependencies, ridge-path teaching, low-loading selection correction). **No replies yet.**
Other Claude/Cursor/Codex lanes below remain **PROTECTED** and are not superseded.
**START HERE:**
`docs/dev-log/handover/2026-08-17-claude-handover-ayumi-bugfix.md`.

**Refresh 2026-08-17 #3 (Claude): the CATEGORICAL arc is CLOSED — lane retired.**
Both PRs merged: [#1057](https://github.com/itchyshin/gllvmTMB/pull/1057)
(`489162dc`, multinomial structured-dependency surface + fail-closed
admission fence) and [#1088](https://github.com/itchyshin/gllvmTMB/pull/1088)
(`c26c294c`, Mizuno-2025 paper alignment + categorical degeneracy detector).
**Nothing is owed by this lane**; it claims no files and takes nothing from
the lanes below. Multinomial screen calibrated, armed, fit-time warning
wired; **ordinal screen ships DISARMED** after five pre-registered candidates
were eliminated. 🔴 `extract_phylo_signal()` was returning H^2 = 1.0 for every
categorical trait — fixed. Follow-ups are ISSUES, not carried state:
[#1097](https://github.com/itchyshin/gllvmTMB/issues/1097) (ordinal
detection research), [#1098](https://github.com/itchyshin/gllvmTMB/issues/1098)
(binomial 25% FPR), [#1099](https://github.com/itchyshin/gllvmTMB/issues/1099)
(paper vignette). ⚠ post-merge CI was still running at merge time — verify.
**START HERE (this lane only):**
`docs/dev-log/handover/2026-08-17-claude-handover-categorical-arc.md`
(every other lane keeps its own named handover below — this entry does NOT
supersede the Cursor LA-MSPL baton immediately following.)

**Refresh 2026-08-17 #2 (Cursor): LA-MSPL overnight arc → Cursor handover.**
D-157 B1 **SIGNED PARK** (no second campaign; `MSPL-04` blocked; no
Totoro relaunch; later intervals = new construction). Point admits:
binomial / gaussian / poisson (experimental). Internal SE pins live;
public `se` withheld. CI triad docs #1075 + Poisson W G0 #1076 are
**UNSIGNED**. Profile scaffold **DRAFT** #1077 waits triad G0.
Optional: fix #1065 planned-only. **PROTECTED:** Codex Lane B.
Worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
**START HERE:** `docs/dev-log/handover/2026-08-17-cursor-handover.md`
(other lanes keep their named handovers below).

**Refresh 2026-08-17 (Cursor): B1 aftermath G0 brief filed — now SIGNED PARK (D-157).**
Historical opener for the aftermath card. Official hold-out
[#1040](https://github.com/itchyshin/gllvmTMB/pull/1040) (M0;
G1 14/132 = 10.6%). Superseded for baton by the #2 refresh above.
**SIGNED card:** `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md`.

**Refresh 2026-08-15 #9 (Cursor): Student-t + ordinal Phase-4 planned prep.**
Lane **`cursor/mspl-phase4-student-ordinal`** · WT
`/tmp/gllvmtmb-mspl-student-ordinal` · LOOP
`docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
Board **na → planned prep** for `student()` identity and
`ordinal_probit()`. **Not admitted.** No registry row. No public
door. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility`.
**START HERE:** `2026-08-15-cursor-handover-phase4-student-ordinal.md`.

**Refresh 2026-08-15 #8 (Cursor): MSPL items 1–3 KEEP PLANNED.**
Conductor sitting. Poisson admit **KEEP PLANNED** (smoke operational
PASS / admit FAIL). #988 no-SE-campaign receipt **MERGED**.
#989 SE-CI honesty and #990 Poisson point smoke opened; merge only
if CI-green and no admit. **Do not merge #972–#976.**
**PROTECTED:** `codex/lane-b-mspl-interval-feasibility`.
**START HERE:** `2026-08-15-cursor-handover-mspl-1-3.md`.

**Refresh 2026-08-15 #7 (Cursor): LA-MSPL SE pin MERGED.**
Lane **`cursor/mspl-se-feasibility-pin`** · [#979](https://github.com/itchyshin/gllvmTMB/pull/979)
squash-merged `10d6a209`. Internal both-Hessian pin on `main`.
Public `se=TRUE` still withholds; Poisson stays `planned`. #978
already on `main` (`78f6d6b6`). Do **not** merge #972–#976.
**PROTECTED:** `codex/lane-b-mspl-interval-feasibility`.
**START HERE:** `2026-08-16-cursor-handover-se-pin.md`.

**Refresh 2026-08-15 #5 (Cursor): LA-MSPL Phase-4 tapes Wave 5 closeout.**
Lane **`cursor/mspl-phase4-tapes-planned`** · WT
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` · LOOP
`docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/` · PR
[#978](https://github.com/itchyshin/gllvmTMB/pull/978) (open; not admitted).
Five C++ GLM-outer tapes; public `estimator="mspl"` is gaussian +
bernoulli + Poisson only; Poisson stays `planned`. Do **not** merge
#972–#976 from this lane. **PROTECTED:** `codex/lane-b-mspl-interval-feasibility`
(binary SE). **START HERE:** `2026-08-15-cursor-handover-phase4-tapes.md`.

**Refresh 2026-08-15 #3 (Cursor): LA-MSPL point-continue GOAL A+B+C LANDED.**
Lane **`cursor/mspl-point-programme-continue`** · WT
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` · LOOP
`docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/` · PR
[#971](https://github.com/itchyshin/gllvmTMB/pull/971) **MERGED** `cb126576`.
Gaussian multi-seed point evidence + Poisson Phase-4 `planned` rows.
Handover opener [#970](https://github.com/itchyshin/gllvmTMB/pull/970)
already on `main`. **PROTECTED:** binary SE Codex lane.

**Refresh 2026-08-15 (Cursor→Cursor): LA-MSPL catch-up + Gaussian ordinary closed on `main`.**
PRs **#963–#969** landed (Phase 2 registry, uniqueness pick C, Hirose Gaussian
`admitted`/`oracle_local`, LOOP closeouts). Closed kits:
`lanes/cursor-mspl-catchup/`, `lanes/cursor-mspl-gaussian/` — do not reopen.
**PROTECTED:** `codex/lane-b-mspl-interval-feasibility` (binary SE). Worktree
`/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` only (not Dropbox).
**START HERE:** `2026-08-15-cursor-handover.md`.

**Refresh 2026-08-08 morning (Cursor→Codex): CRAN 0.7 track pick LOCKED.**
Shinichi: keep Ada hygiene+Rose+later `0.7.0` bump; **keep #949** VA; **more testing**
(not Ada “(a) none”); first CRAN **not imminent**; portal ≥19 Aug is a floor **not** a
deadline (do not aim for first portal day). Codex owns the live toolchain.
**START HERE:** `2026-08-08-codex-handover.md`. G0 identity file remains
`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`.

**Refresh 2026-08-07 evening (Cursor): first CRAN upload identity is `0.7.0`.**
G0 locked: Path A `0.6.1` / `v0.6.1-rc.1` @ `6a58683c` is **PARKED/superseded for upload**
(history retained; do not force-retag). New lane
`/private/tmp/gllvmtmb-cran-0.7-20260807` · `cursor/cran-0.7-20260807` from
`origin/main` @ `d7bee2fa` (VA Arc-1 #949 **already merged**). Track pick was still
open that evening (now answered 2026-08-08). Upload Shinichi-only, **not before
19 Aug 2026**. **START HERE (historical G0):** `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`.

**Refresh 2026-08-07 (Cursor): VA Arc-1 merge/fence (C) shipped to main as #949.**
Worktree `/private/tmp/gllvmtmb-va-arc1-merge-fence` is **not** the 0.7 CRAN programme.
Fat evidence tip `codex/va-gh-all-families` stays donor archive.
**START HERE (VA leftover only):** `2026-08-07-cursor-handover-va-arc1-merge-fence.md`.

**Refresh 2026-08-02 #2 (Claude, end of session): Design 108 GATE A IS CLOSED.**
Stages **4** (#896, probit + tail-safe log-Phi, AD-SAFE), **6** (#907, multi-tier — closes Gate A)
and **R3** (#907, the opt-in `profile=` route) are on `main`; **Stage 7** (structured phylo KL) is
open as **#911**. R3 removed the programme's real blocker — the outer problem collapses from
`114N + 206` to **206, constant in N**, measured RSS exponent 1.70 → 0.966, so 10,000 species is
reachable. Everything remains **FENCED**: no export, no `method=`, no public claim, pending Stage 8.
🔴 **The recommended next arc is the VA-vs-Laplace recovery study, BEFORE Stages 3/5** — this
session's 4,320-fit campaign partly undercut Design 108 §0.2's own justification (silent divergence
decays with n and the ridge suppresses it), so two premises are now unvalidated.
**START HERE:** `2026-08-02-claude-handover-gate-a-closed.md`.

**Refresh 2026-08-02 (Cursor→Claude):** Design 108 Gate A Stage 2 (VA mixed-family)
**MERGED** as [#893](https://github.com/itchyshin/gllvmTMB/pull/893). Next VA stage
needs Shinichi G0 — see `2026-08-02-claude-handover.md`. Sibling [#890](https://github.com/itchyshin/gllvmTMB/pull/890)
missing-data ledger remains open and separately owned unless reassigned.

| Lane | Owner | State | Start here | Boundary |
| --- | --- | --- | --- | --- |
| **LA-MSPL overnight / intervals baton** | Cursor | **D-157 PARK SIGNED.** Triad #1075 + Poisson W #1076 **UNSIGNED**. #1077 draft waits triad G0. Optional #1065 planned-only fix. No public `se` / NEWS covered | `2026-08-17-cursor-handover.md`; cards `research/2026-08-17-mspl-ci-wald-plus-profile.md`, `research/2026-08-17-mspl-poisson-W-G0.md` | No B1 relaunch; no Design 118 recalibration; no real profile CI until triad G0; Codex Lane B **PROTECTED** |
| **LA-MSPL B1 aftermath G0** | Cursor | **SIGNED PARK (D-157).** Official gate #1040 M0 14/132 = 10.6%. Historical card; baton is the overnight row above | `docs/dev-log/research/2026-08-17-mspl-b1-aftermath-G0.md` | No promote; no second campaign; no \(n\to 2000\); `MSPL-04` stays `blocked`; Design 118 already discharged (#1056) |
| **Private two-source iSDM G2d** | Codex | **NEW PLAN-ONLY LANE (2026-08-10).** Fresh worktree `/private/tmp/gllvmtmb-isdm-g2d-six-species` · `codex/isdm-g2d-six-species`, forked locally from the closed G2c smoke branch. G2c is `G2C_SMOKE_ADMISSION_HOLD`; no campaign launched. | `2026-08-10-codex-handover-g2d.md`; then G2c after-task report and smoke decision | First task is an Ultra Plan only: six-species, nonspatial, private known-truth recovery design with the same free-Psi relative-intensity estimand. No fits, Totoro, count, spatial, source, empirical, public/API, or Issue #953 work without a new approval. |
| **LA-MSPL Student-t + ordinal Phase-4 prep** | Cursor | **PLANNED PREP** (not admitted). Notes + oracles only; no registry row; no public door | `2026-08-15-cursor-handover-phase4-student-ordinal.md`; LOOP `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/` | No admit; no NEWS covered; no `estimator=mspl` on student/ordinal; Binary SE **PROTECTED** |
| **LA-MSPL items 1–3 (smoke / SE-CI / receipts)** | Cursor | **KEEP PLANNED.** #988 MERGED. #989 + #990 open. Do not merge #972–#976. Do not admit | `2026-08-15-cursor-handover-mspl-1-3.md` | No admit; no NEWS covered; no Totoro SE campaign; Binary SE **PROTECTED** |
| **LA-MSPL SE feasibility pin** | Cursor | **CLOSED + MERGED** [#979](https://github.com/itchyshin/gllvmTMB/pull/979) `10d6a209`. Internal \(Q_P\)+\(Q_0\) pin; public SE withheld; Poisson `planned`. Do not reopen. Do not merge #972–#976 | `2026-08-16-cursor-handover-se-pin.md`; LOOP `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/` | Historical; no admit; no NEWS covered; no Codex absorb; no public `vcov()`; Binary SE **PROTECTED** |
| **LA-MSPL Phase-4 tapes** | Cursor | **GOAL LANDED** [#978](https://github.com/itchyshin/gllvmTMB/pull/978) (not admitted; CI re-running after provenance/NB1 fix). Five C++ tapes; public `mspl` = gaussian + bernoulli + Poisson. Do not merge #972–#976 from this lane | `2026-08-15-cursor-handover-phase4-tapes.md`; LOOP `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/` | Historical successor is the SE-pin lane; Poisson planned only; no NEWS covered; no public `mspl` on NB1/NB2/beta/Tweedie |
| **LA-MSPL point-continue** | Cursor | **CLOSED** — GOAL A+B+C MERGED [#971](https://github.com/itchyshin/gllvmTMB/pull/971) `cb126576`. Do not reopen | `2026-08-15-cursor-handover.md` (historical); LOOP `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/` | Historical; successor is Phase-4 tapes |
| **LA-MSPL binary SE / intervals** | Codex | **PROTECTED** private branch `codex/lane-b-mspl-interval-feasibility` @ `/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB` | classify-only; do not mutate from Cursor MSPL | No absorb/rebase/merge into point-evidence lane |
| **CRAN 0.7** | Cursor → **Codex** | **Track pick LOCKED 2026-08-08.** Worktree `/private/tmp/gllvmtmb-cran-0.7-20260807` · `cursor/cran-0.7-20260807` from `origin/main` @ `d7bee2fa`. `DESCRIPTION` still `0.6.0`. First CRAN **not imminent** — more testing first | `2026-08-08-codex-handover.md`; G0 `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`; LOOP `lanes/gllvmtmb-cran-0.7/LOOP/` | Leave-M5 + Rose + testing-debt inventory OWED; **no bump yet**; no upload; keep #949 fenced; Laplace default; D-112 holds; portal ≥19 Aug is not a deadline |
| **CRAN Path A 0.6.1** | Cursor | **PARKED / superseded for upload.** Freeze `v0.6.1-rc.1` @ `6a58683c` retained as **failure archive**. S7 STOPPED (PDF ≈ ERROR + galamm 404). Do not remint as CRAN 0.6.1; do not retag as 0.7 | Path A LOOP + `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-s7-progress.md` | Historical only; carry hygiene into 0.7 lane |
| **VA Arc-1 merge/fence (C)** | Cursor | **MERGED to main** as [#949](https://github.com/itchyshin/gllvmTMB/pull/949) @ `d7bee2fa`. Worktree `/private/tmp/gllvmtmb-va-arc1-merge-fence` is leftover — **do not use for 0.7 CRAN** | `2026-08-07-cursor-handover-va-arc1-merge-fence.md` | Keep `calibrated=FALSE` + Laplace default; no fat-tip; no soft-PASS Arc-2 |
| **VA GH all-families evidence tip** | Codex → archive | Donor-only @ `codex/va-gh-all-families` `/private/tmp/gllvmtmb-va-gh-all-families` (B truncnb2/delta_ln done). Not the merge vehicle | tip audits under `docs/dev-log/audits/2026-08-07-va-*` | Do not open PR from this tip; dirty probes/results stay local |
| **Design 108 Gate A (VA parity)** | Cursor → Claude | **Stage 1 + Stage 2 MERGED** (#891, #893). Stage 3/4 **not started** — waiting Shinichi pick | `2026-08-02-claude-handover.md`; design `docs/design/108-va-parity-programme.md` | VA stays hard-fenced; no public mixed-family claim; no VA `mi()`; do not auto-start Stage 4; fresh WT per stage |
| 0.6 release / M5 | Claude | separate committed/pushed release worktree | `2026-07-23-codex-handover.md` | reword/RC ceremony only; no CRAN submission or final tag without Shinichi |
| Profile / Tier-2a | Claude | dirty primary checkout on `claude/profile-coverage-remeasure-20260718` | `2026-07-25-claude-handover.md` | do not overwrite its uncommitted files from another checkout |
| Eta simulation | Codex | **left in Codex** at `/private/tmp/gllvmtmb-design100-progress-oracle` on `codex/design100-progress-oracle-20260724` | Codex's local Design-100 materials | Claude must not run, edit, claim, or absorb this lane |
| Design-103 private diagnosis | Codex | closed `TECHNICAL_PARTIAL`, local-only | `/private/tmp/gllvmtmb-design103-covariance-mechanism/dev/design103-covariance-mechanism/ADJUDICATION.md` | no package/public claim; new model design needs fresh approval |
| HVT-1 high-variance truth instrument | Codex → Claude | closed private evidence arc on `codex/hvt1-high-variance-truth-oracle-20260726` | `2026-07-26-claude-handover.md` | `ORACLE_NOT_CERTIFIED`; no high-cell gap, no gate/API/EVA claim; next numerical-method arc needs Shinichi approval |
| Docs-infra / phylo-column question | Claude | pkgdown repaired and MERGED (`a900c4ae`, PR #787); CI economy open as PR #788 | `2026-07-25-claude-handover-phylo-column.md` | docs/CI only — no package source or API change; the M3 freeze (`NAMESPACE c97ae039`) stays untouched |
| **Site × Species phylo capability + peer evidence** | Claude | **CLOSED 2026-07-25.** Capability **CANCELLED** by Shinichi on evidence — no new API, `NAMESPACE c97ae039` untouched. Bug fixes + first gllvm fit-level comparators landed on `main` `a0f568d1..84ca8290`. D-43 panel **3/3 NOT-DONE**; **nothing promoted**. | `2026-07-25-claude-handover-arc-closed.md` | do not re-open the capability without a new maintainer decision; do not re-cite the retired s9 / s10 figures (see that doc's Corrections table) |
| **VA / VGH pluralism — gaussian arm** | Claude | **CLOSED + MERGED 2026-07-30** (#840, `main` @ `7ed3f238`). Gaussian is settled and was the wrong question: both engines optimise the SAME objective there, so accuracy is not well-posed, and VGH's KL protection is switched off. The logLik "advantage" was **degrees of freedom** (`2·d_ll ~ χ²₁₉`). Gaussian has **no runaway tail for either engine**. Three `dev/` engine fixes shipped. `--as-cran` 0E/0W/1N, CI green, `R/`+`src/` untouched. | `2026-07-30-claude-handover-lane-transition.md` | **TWO CLAIMS RETRACTED — do not re-cite**: `loading_absolute_thresh = 6` is binomial-gated and never fires on gaussian, so "gaussian stays under 6" is void; and the 2026-07-29 docs were wrongly accused of a category error. The pluralist route is a **NON-GAUSSIAN** proposition — do **not** build VGH for gaussian. |
| **VGH degeneracy at scale** | Claude | **APPROVED by Shinichi 2026-07-30 (option a). NOT STARTED.** 🔴 **RE-AIMED: the original premise was refuted pre-flight.** 10 probe fits at n=40/p=80/q=4 give `rel_frob` 10.671/10.449 (2 of 4 seeds), `atten_F > 2` (4 of 4), `max|Λ|` 8.53–12.53 — and **`converged = TRUE` on every one** (structural: `R/va-vgh.R:603` only tests `outer < maxit`). So **VGH's convergence flag is not a health signal either** — the '98% silent' property is SHARED with Laplace, not Laplace's alone. The 0/148 held only at n≥60, p≤12, **q=2**, and `q` was never a grid column (`vgh-vs-laplace-degeneracy.R:30`, module scalar). | `2026-07-30-claude-handover-campaign-approved.md`; scope `2026-07-30-vgh-degeneracy-at-scale-scope.md` (read its READ FIRST) | Question is **where is the boundary in (n,p,q) and is the winning region worth an engine**, NOT 'does it survive'. Use in-package `.vgh_fit()`; the dev engine **cannot do multi-trial binomial**. Health = recovery vs truth ONLY. Compute ~13.5 CPU-h, local viable; **Totoro's install does NOT contain the VGH engine**. **Do NOT open an engine-building arc on the 0/148 figure.** |
| **LA + AGHQ + ridge** | Claude (separate lane) | **AUDIT MERGED 2026-07-30** (#842, plus #839). Headline: *"the AGHQ integrator is correct; the AGHQ estimator is not established."* Four defects — D1/D2 filed as issues, **D3 and D4 recorded PENDING A DECISION with no owner**. | `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md` | **not the VA/VGH lane's surface** — the VGH lane raised findings to it in `2026-07-30-to-la-aghq-ridge-lane-gaussian-findings.md` and changed nothing in `R/`. **A request to TAKE D3 is drafted at `2026-07-30-request-to-la-aghq-ridge-lane-take-D3.md`** — Shinichi is routing it. 🔴 **D3 needs an owner**: `τ = 2` is ON by default whenever AGHQ is on, is net-harmful or inert at every measured scale, and composes with D4 into a silently penalised MAP-not-MLE fit. |

Before any repository mutation, re-check `git worktree list`, `git status -sb`
in the intended worktree, and the target lane's named handover.  The active
checkout is not a safe generic workspace.

**Milestone state is NOT in this note and must be re-derived from git.** This map
records *ownership*, not progress. On 2026-07-25 a fresh session rehydrated from a
Mission Control board that still read "M4 UNDERWAY / draft PR #780" and planned
against a six-day-old picture — including a proposal to audit and cut the public
surface, which would have reopened M3's signed API freeze. It was withdrawn only
after `git` was consulted. Verified that day: M1 · M3 · M4 all CLOSED, PR #780
merged 2026-07-23, RC.1 frozen, the RC.1 review 3/3 NOT-READY with submission
WITHHELD, and the RC.2 non-CRAN closeout recorded. The rung remains **NOT READY**.

**Standing interest (Shinichi, 2026-07-25):** *"I am still interested in EVA stuff too — please remember."* EVA is **cut from 0.6 to 0.7** and **Codex-owned** (`design90`–`design98` + the eta lane); Design 85 is negative evidence and READ-ONLY, Design 86 is design-only. Picking it up is a **lane reassignment + Gate-0 scope freeze decision**, not agent initiative. Keep it on the menu; raise it with him.

**Next arc CHOSEN 2026-07-30:** the **VGH degeneracy-at-scale** measurement (row above). Shinichi's earlier ruling-out of CRAN and the paper still stands. Two items now need HIS decision rather than an agent's: **(a)** who owns **D3** from #842 — the ridge's `tau = 2` is on by default, net-harmful or inert at every scale its own audit measured, and composes with D4 into a silently penalised fit; **(b)** who owns the **scale-dependent-constants class** it shares with `loading_absolute_thresh = 6` — two lanes found the same defect family in two constants on the same day, so it falls between lanes by default.

**Codex task closed 2026-07-26 (Claude→Codex→Claude):** the variance-domain-gate question received private HVT-1 measurement evidence.  Stable band 4 is certified, but high band 20 remains `TRUTH_UNINTERPRETABLE_ADAPTIVE`; the overall decision is `ORACLE_NOT_CERTIFIED`.  The `<= 4` gate stays frozen, and there is no high-cell ELBO--truth gap.  Brief: `2026-07-26-claude-handover.md`. **Multi-trial fixtures only — Design 85 §10 prohibits Bernoulli widening and that call is Shinichi's.**

**⚠ `claude/va-implementation-20260725` is DO-NOT-MERGE** pending Shinichi's §10 decision (new formal contract / revert / park). It carries verified evidence that the VA objective is correct, alongside a Bernoulli widening that §10 forbids.
