# Active-lane split — 2026-07-25

This coordination note prevents a new session from treating this repository as
a single writable lane.  It is a map, not a release/capability claim.

**Refresh 2026-08-07 evening (Cursor): first CRAN upload identity is `0.7.0`.**
G0 locked: Path A `0.6.1` / `v0.6.1-rc.1` @ `6a58683c` is **PARKED/superseded for upload**
(history retained; do not force-retag). New lane
`/private/tmp/gllvmtmb-cran-0.7-20260807` · `cursor/cran-0.7-20260807` from
`origin/main` @ `d7bee2fa` (VA Arc-1 #949 **already merged**). **STOP for track pick**
before DESCRIPTION bump or D-113 implementation. Upload Shinichi-only, **not before
19 Aug 2026**. **START HERE:** `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`.

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
| **CRAN 0.7 G0** | Cursor | **G0 LOCKED** (upload identity `0.7.0`). Worktree `/private/tmp/gllvmtmb-cran-0.7-20260807` · `cursor/cran-0.7-20260807` from `origin/main` @ `d7bee2fa`. `DESCRIPTION` still `0.6.0`. **STOP for track pick** | `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-0.7-g0.md`; LOOP `lanes/gllvmtmb-cran-0.7/LOOP/` | No DESCRIPTION bump yet; no D-113 impl until pick; no upload; Laplace default; D-112 holds; portal offline 5–19 Aug |
| **CRAN Path A 0.6.1** | Cursor | **PARKED / superseded for upload.** Freeze `v0.6.1-rc.1` @ `6a58683c` retained. S7 STOPPED (PDF ≈ ERROR + galamm 404). Do not remint as CRAN 0.6.1; do not retag as 0.7 | Path A LOOP + `docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-s7-progress.md` | Historical only; carry hygiene into 0.7 lane |
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
