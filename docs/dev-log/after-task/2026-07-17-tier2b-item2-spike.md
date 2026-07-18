# After-task — Tier-2b item 2: ruling recorded + engine-capability spike (sizing, no implementation)

**Date:** 2026-07-17 · **Author:** Claude (Opus 4.8). This records the maintainer's Discussion-Checkpoint
ruling and a throwaway engine-capability spike that RE-SCOPES item 2. **No item-2 code was implemented**
(the spike fence bypass was reverted); this hands item 2 off well-sized.

## Ruling (maintainer, "as recommended")
- Parser scope: **1a narrow-first → 1b**. Reporting: **2C** — reference-invariant multiple-correlation
  scalar default, full labelled (K−1)-vector on request. Checkpoint CLEARED. Detail:
  `docs/dev-log/2026-07-17-tier2b-item2-discussion-checkpoint.md` (RULING section).

## Spike (throwaway, reverted)
Env-gated the Tier-2a fence (`GTMB_SPIKE_ALLOW_MULTINOM_LATENT`) and probed two fits:
- **A — multinomial + ORDINARY `latent(0 + trait | unit, d=2)` (single family):** **FITS and CONVERGES**
  (`conv = 0`). The softmax likelihood (fid 16) already composes with a shared latent factor in the TMB
  engine. `extract_Sigma()` then refuses ("fixed-effects-only multinomial") because it recognizes only
  the `phy` tier for a multinomial — the ordinary-latent tier is not wired on the reporting side.
- **B — mixed `list(multinomial(), gaussian())`:** fenced at `expand_multinomial_response()` (mixed-family
  abort) BEFORE the fit. The mixed-family expansion is the real remaining plumbing.

## Re-scoped item 2
- **2a-i (medium, R-side only):** the engine already fits multinomial + ordinary/structured `latent()`;
  wire `extract_Sigma()` / `extract_correlations()` to report that tier's V for a multinomial (today only
  `level="phy"`). No engine work. TDD + Rose + multi-seed; its own PR.
- **2a-ii (larger, engine/plumbing — the cross-family headline):** relax the two fences and extend
  `expand_multinomial_response()` + long-format assembly to admit a multinomial trait alongside
  other-family traits sharing one latent factor, then the 2C reporting convention. Its own PR.
- **1c stays fenced.**

## Next-session entry point
Start **2a-i** on branch `claude/multinomial-tier2b-item2` (off main). The engine already does the hard
part for the single-family case; the first PR is reporting-side wiring + tests.

## Guards honored
Discussion Checkpoint cleared before any code · spike reverted (no silent fence weakening) · fail-loud
fences preserved on main · sized honestly (what is medium vs larger) before implementing.
