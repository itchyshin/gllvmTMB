# Active-lane split — 2026-07-25

This coordination note prevents a new session from treating this repository as
a single writable lane.  It is a map, not a release/capability claim.

| Lane | Owner | State | Start here | Boundary |
| --- | --- | --- | --- | --- |
| 0.6 release / M5 | Claude | separate committed/pushed release worktree | `2026-07-23-codex-handover.md` | reword/RC ceremony only; no CRAN submission or final tag without Shinichi |
| Profile / Tier-2a | Claude | dirty primary checkout on `claude/profile-coverage-remeasure-20260718` | `2026-07-25-claude-handover.md` | do not overwrite its uncommitted files from another checkout |
| Eta simulation | Codex | **left in Codex** at `/private/tmp/gllvmtmb-design100-progress-oracle` on `codex/design100-progress-oracle-20260724` | Codex's local Design-100 materials | Claude must not run, edit, claim, or absorb this lane |
| Design-103 private diagnosis | Codex | closed `TECHNICAL_PARTIAL`, local-only | `/private/tmp/gllvmtmb-design103-covariance-mechanism/dev/design103-covariance-mechanism/ADJUDICATION.md` | no package/public claim; new model design needs fresh approval |
| HVT-1 high-variance truth instrument | Codex → Claude | closed private evidence arc on `codex/hvt1-high-variance-truth-oracle-20260726` | `2026-07-26-claude-handover.md` | `ORACLE_NOT_CERTIFIED`; no high-cell gap, no gate/API/EVA claim; next numerical-method arc needs Shinichi approval |
| Docs-infra / phylo-column question | Claude | pkgdown repaired and MERGED (`a900c4ae`, PR #787); CI economy open as PR #788 | `2026-07-25-claude-handover-phylo-column.md` | docs/CI only — no package source or API change; the M3 freeze (`NAMESPACE c97ae039`) stays untouched |
| **Site × Species phylo capability + peer evidence** | Claude | **CLOSED 2026-07-25.** Capability **CANCELLED** by Shinichi on evidence — no new API, `NAMESPACE c97ae039` untouched. Bug fixes + first gllvm fit-level comparators landed on `main` `a0f568d1..84ca8290`. D-43 panel **3/3 NOT-DONE**; **nothing promoted**. | `2026-07-25-claude-handover-arc-closed.md` | do not re-open the capability without a new maintainer decision; do not re-cite the retired s9 / s10 figures (see that doc's Corrections table) |
| **VA / VGH pluralism — gaussian arm** | Claude | **CLOSED + MERGED 2026-07-30** (#840, `main` @ `7ed3f238`). Gaussian is settled and was the wrong question: both engines optimise the SAME objective there, so accuracy is not well-posed, and VGH's KL protection is switched off. The logLik "advantage" was **degrees of freedom** (`2·d_ll ~ χ²₁₉`). Gaussian has **no runaway tail for either engine**. Three `dev/` engine fixes shipped. `--as-cran` 0E/0W/1N, CI green, `R/`+`src/` untouched. | `2026-07-30-claude-handover-lane-transition.md` | **TWO CLAIMS RETRACTED — do not re-cite**: `loading_absolute_thresh = 6` is binomial-gated and never fires on gaussian, so "gaussian stays under 6" is void; and the 2026-07-29 docs were wrongly accused of a category error. The pluralist route is a **NON-GAUSSIAN** proposition — do **not** build VGH for gaussian. |
| **VGH degeneracy at scale** | Claude | **NEXT ARC, chosen by Shinichi 2026-07-30. NOT YET OPENED** — needs a fresh branch + worktree off `main`, then an ultra-plan. Rationale: VGH's whole low-degeneracy case rests on ONE regime (148 binomial fits at p 6/12, q 2, n 60–200), and **VGH was never in the Totoro grid** — that grid's 0%-vs-12% belongs to `gtmb_jj`/`gllvm_va`. | scope: `2026-07-30-vgh-degeneracy-at-scale-scope.md`; brief: `2026-07-30-claude-handover-lane-transition.md` | measurement only — it sizes the engine investment and is **not** the investment. Binomial-weighted (gaussian closed, poisson a control). Totoro ≤100 cores; results LOCAL per D-50. Fire the adversarial gate BEFORE publishing. |
| **LA + AGHQ + ridge** | Claude (separate lane) | **AUDIT MERGED 2026-07-30** (#842, plus #839). Headline: *"the AGHQ integrator is correct; the AGHQ estimator is not established."* Four defects — D1/D2 filed as issues, **D3 and D4 recorded PENDING A DECISION with no owner**. | `docs/dev-log/audits/2026-07-30-aghq-ridge-verification-audit.md` | **not the VA/VGH lane's surface** — the VGH lane raised findings to it in `2026-07-30-to-la-aghq-ridge-lane-gaussian-findings.md` and changed nothing in `R/`. 🔴 **D3 needs an owner**: `τ = 2` is ON by default whenever AGHQ is on, is net-harmful or inert at every measured scale, and composes with D4 into a silently penalised MAP-not-MLE fit. |

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
