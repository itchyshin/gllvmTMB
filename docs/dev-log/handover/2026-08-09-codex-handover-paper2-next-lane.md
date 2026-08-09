# Session Handoff: Paper 2 integrated-distribution-model next lane

Meta: 2026-08-09 · from Codex · target Codex · Lane C predecessor
`claude/experiment-integrated-sdm` at `c56024ad`.

## Critical Context

You are Codex, picking up the next *planning and feasibility* lane after the
completed Phase C simulation campaign. Do not turn the diagram into a public
package claim or begin a broad all-insect North American fit. The immediate
goal is a small, identifiable first integrated model: one ecological process
observed through GBIF and one standardised survey source.

The repository is multi-lane. `CLAUDE.md` deliberately continues to point to
`docs/dev-log/handover/2026-07-25-active-lane-split.md`; do not replace that
pointer with this lane. Read the map before every mutation and leave all other
lanes alone.

## Goals and plan

The longer-term paper question is whether developmental mode (holometabolous
versus hemimetabolous) changes species' environmental gradients after we
separate ecology from how often people look and report. The first practical
step is not the full four-source model in the diagram. It is a two-source
prototype that establishes the data contract, identifiability conditions, and
simulation recovery needed before additional sources, traits, phylogeny, and
continental scale are credible.

The first empirical comparison must include the GBIF-only models in the earlier
diagram. Start without spatial structure, then use `spatial_indep()` as a
clearly labelled spatial sensitivity analysis. Do not start with
`spatial_latent()`. `spatial_indep()` is useful here, but is not literally the
same as GLLVM's single spatial row effect shared by every species; the next
lane must state which structure each model fits.

| Priority | Next lane output | Why it comes first |
| --- | --- | --- |
| 1 | Two-source data contract and source audit | Determines whether a model can distinguish rarity from under-observation. |
| 2 | GBIF-only comparison ladder | Establishes the simple baseline before integration. |
| 3 | Symbolic minimum model and identifiability note | Makes clear what GBIF, effort, and surveys each identify. |
| 4 | Small known-truth simulation prototype | Tests recovery before real data interpretation. |
| 5 | One-order, one-region empirical pilot | Finds data and computation problems before North America-wide scale-up. |
| 6 | Add literature, monitoring, spatial complexity, traits, and phylogeny | Only after the core model is validated. |

## What was accomplished

Phase C (#943) is complete as a reproducible developer-only misspecification
campaign. It showed that, in a shared-bias simulation, omitted recording bias
can strongly distort ecological correlation (`dD_bias=0.45218`, MCSE
`0.00220`), while A5--A6 attribution supports this narrow mechanism. It also
showed why a genuine observation model is necessary.

The result is not universal: all 32 negative R5 effects are `omega=0` controls.
The D-43 addendum preserves them and labels the global conclusion
`H_SINK_UNRESOLVED_PREREGISTRATION_SCOPE_CONFLICT`. Do not cite Phase C as
evidence that all observation bias becomes positive ecological association.

## Current Working State

- **Working:** Phase C branch is clean and pushed at `c56024ad`; no remote
  Phase C job is running.
- **Completed:** corrected pilot; 19,800 G1--G6 fits; independent audit;
  official analysis; supplement; D-43 rereview; findings and after-task report.
- **Not started:** data acquisition, source harmonisation, a real-data fit, or
  public integrated-SDM functionality.
- **Protected:** Phase A/B; C-lite; main; issues #943--#946; #944/#945 work;
  #946 closure; link-residual work; public docs and package/source changes.

## Key Decisions and Rationale

- Start with **GBIF plus one standardised survey source**, not literature and
  monitoring simultaneously. GBIF alone cannot distinguish rarity from poor
  reporting; a standardised source anchors that distinction.
- Use a long master table with grid cell, species, source, response, effort,
  date/season, protocol, and environmental covariates. Every source must map to
  the same cells and taxonomic names.
- Fit one ecological intensity per cell and species, with source-specific
  observation processes. Do not call a GBIF non-record an absence.
- Do not use occupancy or N-mixture terminology unless their required repeated
  visits, closure assumptions, and protocol metadata are actually present.
- The first empirical pilot should use one insect order, a restricted region,
  50 km equal-area cells, and a manageable species subset.

## Files Created / Modified

The Phase C diff from frozen instrument commit
`7e26e1bdb9d0f99fd67ec3a4850bcf2e28d7229b` to `c56024ad` is:

- `dev/isdm-phase-c-d43-interpretation.R`
- `dev/isdm-phase-c-findings.md`
- `dev/isdm-phase-c-pilot-v2-receipt-2026-08-09.md`
- `docs/dev-log/after-task/2026-08-09-isdm-phase-c.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/handover/2026-08-09-codex-handover-phase-c.md`
- `docs/dev-log/recovery-checkpoints/2026-08-09-0048-codex-phase-c-campaign-running.md`
- `docs/dev-log/recovery-checkpoints/2026-08-09-074602-codex-phase-c-analysis-materialized.md`
- `docs/dev-log/recovery-checkpoints/2026-08-09-075852-codex-phase-c-d43-interpretation.md`
- this handover: `docs/dev-log/handover/2026-08-09-codex-handover-paper2-next-lane.md`

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `claude/experiment-integrated-sdm` at `c56024ad` | yes | yes | none | LANDED on the Lane C remote branch; intentionally unmerged |
| Phase C Totoro/local artifacts | n/a | retained off-GitHub | none | LANDED evidence; preserve, never overwrite |
| Paper 2 implementation lane | no | no | none | OWED; create a fresh fenced branch/worktree after orientation |

`handoff_gate.sh` warned about 285 unpushed commits on unrelated historic
branches. This Lane C branch itself is clean and pushed; do not absorb or fix
those foreign branches in this lane.

## Next Immediate Steps

1. Run lane preflight and create a fresh, separately named Paper 2 feasibility
   worktree. Do not reuse the dirty Dropbox checkout or modify Phase C results.
2. Use the `ultra-plan` method for the two-source prototype. Its first question
   is which standardised survey source and insect order have enough compatible
   effort/protocol data to pair with GBIF.
3. Write a one-page data contract before downloading substantial data:
   required columns, species-name authority, grid, time window, duplicate rule,
   effort definition, and which records are allowed to represent non-detection.
4. Fit and compare the first four candidate models on the same small fixture:
   (a) GBIF-only without spatial structure; (b) GBIF-only with
   `spatial_indep()`; (c) two-source integrated model without spatial structure;
   and (d) two-source model with `spatial_indep()`. Treat (a) as the readable
   baseline and (b)/(d) as spatial sensitivity analyses. Do not use
   `spatial_latent()` in this first ladder.
5. Write the minimum model mathematically and identify the anchors: survey
   effort/replication constrains observation; GBIF contributes spatial coverage;
   ecology is shared across sources.
6. Build a known-truth simulation and require recovery of ecological maps,
   environmental slopes, and source-specific observation effects before any
   headline real-data map.
7. Only then acquire a small pilot dataset and run the live R/TMB toolchain.

## Blockers / Open Questions

- Which survey programme supplies standardised insect observations with usable
  effort and temporal metadata? This is a data-scoping decision, not yet made.
- Which insect order offers enough shared taxa between GBIF and that source?
- What time window and spatial grid retain sufficient overlap without making
  sampling effort unreasonably heterogeneous?
- Whether the full model belongs inside `gllvmTMB` or should first be a
  developer prototype remains open; do not commit to a public API before the
  simulation and data audit.

## Gotchas and Failed Approaches

- The Phase C official analyser authentically binds the frozen instrument; it
  rejects post-hoc reruns. Keep its original evidence immutable.
- Optimiser convergence flags did not diagnose poor recovery. Retain errors and
  report all-completed beside `pdHess`-restricted summaries.
- `NOT_CRAN=true` and `devtools::load_all()` are mandatory for development
  checks; `library(gllvmTMB)` can load an older installed package.
- Heavy simulation belongs on Totoro or DRAC, never GitHub Actions. Use
  `OPENBLAS_NUM_THREADS=1` and at most 150 Totoro cores.

## How to Resume

From a new Codex task, start in the intended fresh worktree and paste:

```text
Read AGENTS.md, CLAUDE.md's multi-lane snapshot, and
docs/dev-log/handover/2026-08-09-codex-handover-paper2-next-lane.md. Run
bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD", reconcile the handover
with git, and continue only the OWED two-source Paper 2 feasibility steps.
First use ultra-plan; do not rebuild Phase A/B/C, alter main, or treat the
Phase C simulation as a public integrated-SDM capability.
```

Codex owns the next lane's live R/TMB simulations and empirical pilot once
planned. Planning-side work remains data/source selection and model design.
