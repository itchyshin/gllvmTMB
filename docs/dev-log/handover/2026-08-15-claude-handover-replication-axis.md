# Session Handoff: replication-axis campaign (the second frontier axis)

Meta: 2026-08-15 · from Claude · target Claude (fresh session) · milestone close

```text
🎯 GOAL
Solo platform: Claude (this session), Totoro for compute; execution authority
  already reassigned by the maintainer for this programme.
Deliverable: the SECOND axis of the recoverability frontier — does the
  amplitude-recovery frontier move with spatial replication (Matern patches
  per side), holding the truth constants fixed? Plus one bounded ride-along:
  classify the 92 runaway fits against the known loading-runaway class.
HEADLINE: effort buys identifiability (E*_pd = 1.85 [1.43, 3.17]) but NOT
  reliable amplitude recovery (median error 0.58 at E=16, PD plateau 0.68);
  the diagnosis says replication is the binding constraint — MEASURE IT.
IN PARALLEL: runaway-classification slice (are the 92 the loading-runaway
  class? does aghq_ridge move them?); P1-F1 figure fixes per Florence review.
DEFER: paper drafting (starts when both axes are measured), empirical data,
  any consumed-lineage admission, push/PR (maintainer's call), Paper 2.
DISCIPLINE: verify=ADEMP amendment reviewed before launch + byte gates on any
  new fixture + adversarial pass on the frontier claim · compute=Totoro,
  estimate-first (D-139), pre-run gate before any full campaign ·
  closure=a measured two-axis frontier statement, or a measured refutation.
LANE: codex/isdm-range-amplitude-orthogonal (or a fresh claude/ lane if the
  maintainer prefers; say which at preflight).
```

## Rehydrate (in order)

1. `dev/isdm-package-recovery/2026-08-15-frontier-campaign-results.md` — what
   is measured and what the one-seed pilot got wrong (conditional != marginal).
2. `dev/isdm-package-recovery/2026-08-15-paper1-gbif-effort-frontier-campaign-design.md`
   — the ADEMP design this arc AMENDS (do not rewrite it; append the
   replication axis as its own section with its own MCSE justification).
3. `dev/isdm-package-recovery/2026-08-15-g2g-information-check-on-frozen-paper1-fixture.md`
   §1a/§1b — the diagnosis chain and its two visible corrections.
4. `frontier-campaign/{0,1,2}_*.R` — working pipeline (bundle gates G1-G3
   exact; worker; summary+P1-F2). Totoro: `~/frontier-prerun/` has the
   compiled DLL (64 s to rebuild if purged; cpp MD5
   ca8d2104b38631164e6000e7a075aa22).
5. The brain note "ISDM programme — the destination is data integration…"
   (memory/) — now carries the campaign delta.

## Design sketch for the new axis (to be ADEMP-amended, not assumed)

Replication axis R = domain scale in Matern practical-range units per side
(current design ~6.3). Candidate levels ~ {6.3 (anchor), 9, 12, 18} at fixed
E in {1, 2, 4}: 12 cells x 200 seeds = 2,400 fits ~ 7 core-h — trivial on
Totoro. THE HARD PART is honest fixture geometry: a larger domain (or denser
cells) needs a NEW mesh + skeleton + A matrices + byte-gated generator — the
frozen 360-cell skeleton cannot be stretched. Options to weigh in the
amendment: (a) scale the domain with cell count growing proportionally
(clean, changes n too — confounds replication with sample size; handle by
also scaling species-cell support DOWN? state the confound honestly); or
(b) shrink the range (raise kappa_true) on the SAME 360-cell grid — zero new
geometry, pure replication effect, but changes the truth constants (c_ref,
lambda) — requires re-deriving the truth vector and a fresh validation gate.
Option (b) is the surgical one; recommend it, with (a) as the robustness arm
later. Decide at plan review, not by default.

## Protected / do not touch

All sealed roots (MSPDE V1-V3, SAR, FSB, G3, gauge lineage) remain immutable.
The frozen-seed generator front door stops on any seed but 86401L — new
fixtures need their own named generator files, never edits to the sealed one.
The branch remains unpushed local-only until the maintainer says otherwise.

## Open flags carried forward

- gamma under-coverage (0.79-0.89 on the PD subset) — unexamined.
- P1-F1 four Florence fixes — mechanical, unstarted.
- P2-F1 retired pending redraw.
- Board/check-log still carry no ISDM entries (handover fence on this branch).
```

Paste-ready prompt for the fresh session:

```text
cd /private/tmp/gllvmtmb-isdm-range-amplitude-chart
claude "Read docs/dev-log/handover/2026-08-15-claude-handover-replication-axis.md. Run lane preflight, rehydrate in the listed order, then /ultra-plan the replication-axis campaign per the GOAL block — ADEMP amendment first, maintainer review before any launch."
```
