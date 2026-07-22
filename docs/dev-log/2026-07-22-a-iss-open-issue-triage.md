# A-iss — open-issue triage (report only, no closes)

**Slice A-iss of the ultra-plan Rev 3.** Written 2026-07-22 on `claude/0.6-m1-close-20260722`
@ `509d5792`. **Report only.** Bulk GitHub closes are safety-blocked for the agent and the
maintainer runs the closeout script; nothing here was closed, relabelled, or re-milestoned.

**Scope:** all 20 open issues, triaged against the *current* 0.6 programme — Laplace-only,
M1 → M3 → M4 → M5, first CRAN release numbered 0.6.0 (D-66).

---

## Two findings that matter now

### 1. 🔴 #750 still declares "Target release: **0.6**" — the register says 0.7

`gh issue view 750` returns, verbatim: **`- Target release: **0.6**.`**

But `docs/dev-log/known-residuals-register.md` row **R-5** records the opposite as a maintainer
decision: *"2026-07-21, maintainer: **fix the doc to match the code; retarget #750 to 0.7.**"*

**The decision was taken and never applied to the issue.** The register and the public tracker
now disagree at the same moment in time — the same class of defect that withheld M1 twice, except
this instance is on a **public** surface a user or CRAN reviewer can read.

R-5's reasoning is worth restating so the retarget is not mistaken for abandonment: the #750
spatial-redraw commits (`dd80244a`..`051eb4e5`) **exist but are on a parked branch**, deliberately
not merged, to avoid touching the quarantined estate and re-minting M1's source identity. The phylo
half landed; the spatial half did not.

**Recommended (maintainer act):** edit #750's body to `Target release: 0.7`, citing R-5. One line.

### 2. 🟠 #345 gates CRAN on a capstone that is not in the 0.6 programme

`#345` (CRAN umbrella) reads: *"Sub-issues: 3-OS `--as-cran` clean; examples/vignettes;
DESCRIPTION/URLs; methods paper. **Gated on the power-study capstone.**"*

The power-study capstone is **#349 / #346**, both on the `power-study` milestone, and **neither is
part of the M1 → M3 → M4 → M5 sequence.** So the public umbrella issue states a CRAN precondition
that the live plan does not intend to satisfy before 0.6.

Either the gate is stale — plausible, since D-66 settled the first release as 0.6.0 and the plan
routes through M4/M5 without a capstone — or the 0.6 plan is missing a dependency. **This is a
scope question for the maintainer, not an agent call.** It should be resolved before M5, because
#345 is the issue a reviewer would read to understand what "CRAN ready" means here.

---

## Milestone hygiene

**Six issues sit on the stale `v0.2.0` milestone** — #332, #341, #342, #343, #347, #348 — while the
first CRAN release is **0.6.0** (D-66) and `v0.2.0` is long past. The milestone is now
uninformative: it neither schedules nor excludes.

Two others carry `power-study` (#346, #349) and one `CRAN + paper` (#345). The rest have no
milestone.

**Recommended:** re-milestone or clear the six; a milestone that names a shipped version reads as a
commitment nobody holds.

---

## Full triage

| # | Title (short) | Bearing on 0.6 | Call |
|---|---|---|---|
| 750 | Unconditional RE redraw → valid parametric bootstrap for structured Σ | **Stale target** — says 0.6, R-5 retargeted to 0.7 | 🔴 fix the body |
| 345 | [roadmap] CRAN readiness + paper | Umbrella; gates CRAN on a capstone outside the plan | 🟠 resolve the gate |
| 230 | Article surface reset and user-first tooling gate | **18-comment thread negotiating M4's gate** | read before M4 |
| 349 | [roadmap] Power-simulation capstone | Not in the 0.6 sequence; #345 gates on it | tie to #345's resolution |
| 346 | [roadmap] Simulation / coverage framework | Same | tie to #345's resolution |
| 340 | Capability matrix — live status board | Overlaps Mission Control | M4 reconciliation |
| 348 | [roadmap] Family-validation completion | stale `v0.2.0` | re-milestone |
| 347 | [roadmap] Article completion | stale `v0.2.0`; overlaps M4 | re-milestone; fold into M4 |
| 343 | [roadmap] CI / engineering health | stale `v0.2.0` | re-milestone |
| 342 | [roadmap] cluster2 — 4th grouping tier | stale `v0.2.0`; feature work | post-0.6 |
| 341 | [roadmap] Random-slope completion | stale `v0.2.0`; relates to R-6 (deferred 0.7) | post-0.6 |
| 332 | Missing-data layer — shared contract | stale `v0.2.0` | post-0.6 |
| 338 | [missing-data] Phase 3 — phylogenetic `mi()` | feature work | post-0.6 |
| 337 | [missing-data] Phase 2c — group/species `mi()` | feature work | post-0.6 |
| 336 | [missing-data] Phase 2b — obs-level `mi()` | feature work | post-0.6 |
| 361 | [kernel] Cross-lineage coevolution via `kernel_*()` | feature work | post-0.6 |
| 705 | Matrix-free + Hutchinson stochastic-trace REML | feasibility idea | post-0.6 |
| 565 | Advisory: z→t(df=g-1) Wald widening not uniformly beneficial | **advisory, touches interval claims** | note for M4 wording |
| 488 | Bridge-gate drift: R wrapper may reject julia features | audit | post-0.6 |
| 324 | Proposal: routine Pólya scout + creative-combination persona | process | post-0.6 |

**No issue blocks M1.** #750 and #345 are the only two that must be settled before the release
completes, and both are maintainer edits rather than engineering.

---

## Cross-check worth noting

**#565 is adjacent to the R-11 wording review.** It advises that z→t Wald widening is *not
uniformly beneficial* and that the coverage direction depends on parameter class (location versus
scale/dispersion). That is the same honesty boundary the R-11 strings encode, and the same one
`docs/design/75:88-90` states when it says `"covered"` never means calibrated. If the maintainer
tightens any interval wording in M4, #565 is the issue to reconcile against.

## What this triage does NOT do

- **No closes, no relabels, no milestone edits.** All are maintainer acts.
- It does not judge the technical merit of the feature issues — only their bearing on 0.6.
- It does not read #230's 18 comments in full; that thread is an M4 input and needs the
  maintainer's own reading, since it negotiates a gate rather than reporting a defect.

> Related: `docs/dev-log/known-residuals-register.md` R-5 · `docs/dev-log/plan-actual/2026-07-22-m1-plan-vs-actual.md`
> · `LOOP/checkpoint.md` §6
