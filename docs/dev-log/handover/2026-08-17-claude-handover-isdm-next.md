# Handover — iSDM: what is actually next (2026-08-17)

You are Claude (or Codex/Cursor — this is platform-neutral), picking up the iSDM
programme in gllvmTMB. Read this INSTEAD of trusting any scout that rehydrated
from `2026-08-15-claude-handover-eod.md`.

## ⚠ Supersession warning — the stale-scout trap

The 2026-08-15 handover names "a public, documented front door — not
`gllvmTMB:::.gll_isdm_fit`" as the next step. **That was DONE on 2026-08-16 and
is live.** A scout reading only the 8-15 doc will re-recommend it (this has
already happened once, on 8-17). The authoritative rehydration chain is:

1. `docs/dev-log/after-task/2026-08-16-sdm-day-closeout.md` (the day summary)
2. This document (the forward menu)
3. `docs/dev-log/handover/2026-07-25-active-lane-split.md` (multi-lane map —
   other lanes keep their own handovers; do not orphan them)

## Critical context — the shipped state (all merged, all deployed)

- Public route: `gllvmTMB()` with `family = isdm_sources(...)` (n ≥ 2 named
  sources, Poisson-log counts + Bernoulli-cloglog detection; the legacy
  two-source `list(gbif=, survey_pa=)` is the n = 2 case). PRs #1016, #1027,
  #1030, landed on main via #1031 (first CI on the programme, green).
- pkgdown "Species Distribution Models" collection, live: joint-sdm →
  rare-species/MSPL door → GBIF-only opener → designed-survey two-source →
  survey-design → multi-source → repeated-visits (+ spatial cross-link).
  Four-lens audited (#1046); Paper × Items article re-aimed; version 0.7.0
  (#1049); rare-species article (#1054); close-out (#1059).
- Evidence state: 1,200-fit gamma recovery (per-arm error flat in n_sources;
  effort ratio drives error); 1,600-fit survey-design curve (target NOT
  reached: `med_rel` 0.63 vs 0.25 at 2,250 cells; `pd_rate` 0.555);
  register rows ISDM-01/ISDM-02 both `partial`. NO calibrated intervals for
  any integrated quantity. Everything reader-facing is relative intensity.

## Next Immediate Steps (OWED — maintainer-ranked 2026-08-17)

1. **Prediction maps** (recommended first; usability axis). Probe whether
   `predict()` on an `isdm_sources()` fit returns anything defensible (which
   scale? which arm? what does `re_form` do with the shared latent field?).
   If it works: certify behaviour with tests + a map-making article completing
   the SDM collection's promise. If it doesn't: that finding scopes the API
   slice. Probe first; nothing is known about this surface.
2. **Calibrated uncertainty campaign** (the big arc). Coverage evidence for
   integrated-route SEs/intervals — same shape as the package's earlier
   interval campaigns; Totoro/DRAC, D-139-gated (estimate + pre-run test +
   approval before any full launch).
3. **Real-data flagship** — one genuine GBIF + survey dataset end-to-end.
   🔴 Needs Shinichi's taxon/system pick before scoping.

## Deferred menu (carry forward; do NOT silently drop)

All-PA declarations (needs an identification story) · packaged per-source bias
covariates (`w'δ` gating-columns → real API) · #944 source weights (simplex
design problem) · occupancy p·q extension (deliberate engine work; breaks the
cloglog coherence fence on purpose — see the repeated-visits article's boundary
section) · frontier campaign completion (10–20k cells, extrapolated only) ·
zero-provenance decision-guide article (Zuur framing; delta/hurdle vs
detection-vs-intensity) · Paper 1 spatial source separation (figure prototypes
preserved: branch `codex/isdm-range-amplitude-orthogonal`-adjacent
`codex/two-paper-global-analysis` pushed; results copied to the Dropbox
checkout's `dev/isdm-package-recovery/results/`).

## Key decisions binding this work (2026-08-16, Shinichi)

- MSPL demonstrated for rare SPECIES (SDM menu); ridge demonstrated for runaway
  LOADINGS (Paper × Items, Model Guides); remedies map to pathologies, not data
  types; ridge+MSPL is refused by design; no Site × Species MSPL duplicate.
- Paper × Items article is final as re-aimed; the two-source article is
  "…designed survey"; article 1's `pd_hessian = WARN` fit stays (do not change
  model/design/seed).
- The 5×3 keyword grid never changes. Reader surfaces carry no register codes.

## Gotchas (measured, do not relearn)

- **An unmergeable PR gets NO CI at all** — `pull_request` workflows need a
  merge ref. "Waiting for CI" on a conflicting PR waits forever.
- The ridge does NOT fix separation (measured twice: slopes 276 and 227, conv 1).
- `test-va-all-family-light-fits.R` `delta_lognormal_log` cell is
  environment-flaky (record on #1049) — a red there is not your change.
- The MSPL source-pin test (`test-mspl-poisson-phase4-oracles.R`) may still be
  red on main — MSPL lanes' issue, flagged in #1031.
- `.align_mixed_family_list()` drops attributes but keeps names — the contract
  rebuilds its map from names+laws; preserve that if touching `R/fit-multi.R`.
- Pooled recovery metrics across varying group counts manufacture findings —
  per-group metrics always (drift-ledger class).

## Protected / other lanes (do not touch)

- `codex/isdm-article-staging` — LOCAL-ONLY, +1 commit ("stage private iJSDM
  articles", Kristen's fenced drafts + staging test). Preservation/disposition
  is Shinichi's call; it is not stranded work to resume.
- `dev/isdm-package-recovery/article-staging/` + `two-paper-staging/` (fenced
  drafts; read-only inspiration) · cursor/codex MSPL loop lanes and their many
  unpushed worktree branches · the A3 campaign (parked by Shinichi).

## Environment / how to work

- Fresh worktree off current `main` for any new lane (never resume a spent
  `codex/isdm-*` branch); run `tools/lane_preflight.sh` first action.
- R toolchain local: `devtools::load_all()` needs a TMB compile (~4 min);
  probes are seconds; renders 5–70 s per article. `OPENBLAS_NUM_THREADS=1`.
- CI: single ubuntu job on PRs to main, ~37–39 min; pkgdown auto-deploys after
  main's check (or `gh workflow run pkgdown.yaml --ref main`).
- Docs-class PRs may self-merge on green per CLAUDE.md merge authority;
  anything touching `R/`, `src/`, exports, or claims waits for Shinichi.

## How to Resume

From the repo root, in your own authenticated terminal:

`claude "Read AGENTS.md and docs/dev-log/handover/2026-08-17-claude-handover-isdm-next.md. Run the handover rehydration steps, reconcile with current git state, then continue only the OWED Next Immediate Steps."`
