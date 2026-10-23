# Morning brief — 2026-08-18

## ✅ DONE — Ayumi replies POSTED (all three, evidence-based, 2026-08-18 morning)

The three reply drafts to Ayumi-495/urbanisation_map **#24, #25, #23** are written,
shown to you in full last night, and approved in principle — you held them to post this
morning. Every claim in them is now TRUE on `main`:

- #24 (ridge convergence): fixed and merged (PR #1106; package issue #1092 CLOSED).
- #25 (boundary flags both tiers · `fitted()` · objective provenance): fixed and merged
  (PR #1114).
- #23: analysis guidance + both package suggestions accepted (Slice 3 in the authorized
  chain).

Posted after a verification battery re-fit her actual models with the fixed package
(all claims measured, not predicted; results: `/private/tmp/ayumi-verify/RESULTS.md`):
#24 [issuecomment-5328441775] · #25 [issuecomment-5328444624] · #23
[issuecomment-5328447533]. Two honest findings included in the replies: her ridged fit
still has `pd_hessian FALSE` at tau=2 (convergence reporting fixed ≠ curvature healthy),
and ridge_path verdicts are composition-dependent (her own point, quantified).

## The authorized overnight chain (self-merge on green, your authorization 2026-08-17)

1. **#1117** — free flat dispersion parameters in mixed-family fits (singular Hessian,
   no SEs). Per-trait pinning + mask-registry contract test. ← running first
2. **#1118** — `deviance()` silent NULL.
3. **Slice 3 (#23)** — affine-rank response screen + ridge-path workflow + the
   MSPL-vs-ridge vignette sentence.

Status as of ~07:00: **#1117 MERGED** (PR #1121; one CI-flake fixture honestly rescoped
en route) · **#1118 MERGED** (PR #1122, plus the pkgdown index fix #1114 owed) ·
**Slice 3 MERGED** (PR #1123) — the chain is COMPLETE: all three links on `main`. The adversarial-refute
stage went **4-for-4** across the day — every producer, however briefed, shipped exactly
one class-member short or one verdict-layer wrong, and the fresh-context refute caught
every one. Two NEW issues filed from the Rose sweeps with measured evidence: **#1119**
(spatial/kernel Psi never boundary-screened) and **#1120** (🔴 the nastiest: mixed-family
fits silently SWAP trait↔family on unordered character columns — the silently-wrong-model
class; worth prioritising).

## Also open for you (no rush)

- PR #1108 (#1080 dispersion naming) — CI green, awaiting review.
- PR #1107 (#1082 one NB2 worked example) — the template for seven more; reader-path
  review.
- Design 122 permanent caveat: recorded, done.
