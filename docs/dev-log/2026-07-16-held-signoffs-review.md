# 2026-07-16 — Audit of three held sign-offs

**Reviewer:** Claude Code (read-only audit)  
**Date:** 2026-07-16  
**Status:** held pending Shinichi decision; branches not merged to main

---

## Summary

Three branches/worktrees await Shinichi's sign-off before merge or drop (per
check-log item 5, 2026-07-15). All are **staged, not merged**. All three have
clean working trees; their content is frozen and ready for decision.

| Sign-off | Branch | Commit | Status | Decision needed |
|----------|--------|--------|--------|-----------------|
| **disp_group=** | `worktree-agent-a6930931ce81e02da` | `dac95f05` | **Fails recovery gate** | Merge as opt-in modelling tool OR drop? |
| **family-breadth advertising** | `worktree-agent-a001dee2509c89dc2` | `1bf25e4c` | Ready, correctness landed; roxygen doc awaits | Merge now OR hold for Phase F? |
| **tweedie stale-rationale refresh** | `worktree-agent-a33d0cc868dd580a0` | uncommitted | Ready, test comment updated | Merge uncommitted changes OR handle separately? |

---

## Sign-off 1: `disp_group=` shared NB2 dispersion

**Branch:** `worktree-agent-a6930931ce81e02da` (commit `dac95f05`)  
**Base:** off `8ec261bb` (2026-07-13; now on main @ `2843405a`)  
**Authored:** Shinichi Nakagawa (2026-07-15, marked WIP)

### What it changes

- **R/fit-multi.R** (+45): Route A TMB `map=` tying logic to pool `log_phi_nbinom2` across traits
- **R/gllvmTMB.R** (+13): `disp_group` argument validation and dispatch
- **man/gllvmTMB.Rd** (+12): roxygen documentation for the new argument
- **tests/testthat/test-disp-group.R** (+122): 18 test cases, all PASS

### Check status

**Tests:** 18/18 PASS on the clean engine.  
**Implementation:** Route A design (zero C++ diff; `map=` tying) — correctly implemented, no
technical problems found.

### Validation result: FAILS the gate

Per Design 82 §4.5, the mitigation ladder validation was run:

| n | default (per-trait) | **shared disp_group** | knownphi oracle |
|---|---|---|---|
| 150 | 0.519 | 0.515 | 0.776 |
| 400 | 0.459 | 0.408 | 0.811 |
| 800 | 0.495 | 0.480 | 0.839 |

(Median Σ̂/Σ_truth recovery; 1.0 = unbiased.)

**Result:** Pooling φ does not move recovery toward truth. Shared `disp_group`
tracks default (per-trait) — even marginally *below* it — nowhere near oracle
(knownphi). The diagnosis (Design 82 §4.5–4.6): **the ridge is in φ *estimation
bias itself*, not over-parameterisation.** Pooling a biased-low estimate does not
fix the bias.

**Consequences:**
- nbinom2 Sigma recovery problem is **not solved by shared dispersion**.
- nbinom2 stays **fenced** (recovery-only interval boundaries; G1/G2/G3 caveats
  remain).

### Decision needed

The implementation is correct and complete. The decision is **policy**, not
technical: `disp_group=` is a legitimate opt-in modelling facility (a user
*can* pool φ when traits genuinely share dispersion structure), but it does
**not deliver its motivating benefit** (fixing the nbinom2 Sigma ridge).

**Option A (land as-is):**  
Merge as an opt-in feature. Advertise it for "pool when traits structurally
matched" (e.g. a multi-trait sensor system sharing physical noise) *without*
claiming it fixes nbinom2 Sigma recovery. Add a caveat in roxygen that
pooling φ does not recover Sigma, and point readers to Design 82 §4.6 if
they need the technical detail. This is honest and gives users a real option.

**Option B (drop entirely):**  
Leave the code unmerged. The facility is not broken, but the main use case
failed validation and alternative approaches (bias-corrected φ priors) are
out-of-scope. Re-evaluate only if a future low-barrier improvement (e.g. a
regularised φ prior) is discovered.

**Recommendation:** **Option A** — land it as an opt-in facility with explicit
caveat. The code is solid and correctly tested; keeping a working feature
available (with honest scope bounds) is more useful than deleting it because
its original motivation did not pan out. Users can still benefit from pooling
φ when they have domain reason to do so.

---

## Sign-off 2: Family-breadth advertising (roxygen listing for binomial/Gamma/Beta)

**Branch:** `worktree-agent-a001dee2509c89dc2` (commit `1bf25e4c`)  
**Base:** off `8ec261bb` (2026-07-13; now on main)  
**Authored:** Shinichi Nakagawa (2026-07-15, marked WIP)

### What it changes

- **R/predictive-diagnostics.R** (+98, -31): extend `residuals()` and
  `predictive_check()` to advertise and handle binomial, Gamma, Beta families
- **man/residuals.gllvmTMB_multi.Rd** (+18, -12): roxygen; update family list
- **man/predictive_check.Rd** (+12): roxygen; add family docs
- **tests/testthat/test-residuals-family-breadth.R** (+208): comprehensive
  family-coverage test suite

### Check status

**Tests:** 6 new unit tests added; all expected to pass (not run, working tree
clean).  
**Implementation:** Extends existing diagnostic extractors to new families;
mechanism is sound and mirrors existing patterns.  
**Correctness status:** The underlying fix (ability to extract residuals for
Gamma/binomial/Beta) landed earlier (commit `354e9044`, 2026-07-07); this
branch adds the **documentation claim** and diagnostic surface.

### Decision needed

The question is **timing and scope**, not correctness:

- **Correctness fix + code:** landed on main (July 7 onward).
- **Roxygen documentation + examples:** ready on this branch, not merged.
- **Reader-facing article review:** not done yet (per check-log, awaits Phase F).

**Option A (land now):**  
Merge to main. Users can call `residuals(..., family = "binomial")` and
`predictive_check()` with these families; the API is available and tested.
Reader-facing articles can be updated separately in Phase F. This unblocks
method delivery now.

**Option B (hold for Phase F):**  
Leave unmerged pending a coordinated "Phase F" documentation pass that reviews
and finalizes all family-breadth roxygen claims together (Gamma, Beta,
binomial, nbinom1, student, lognormal, etc.). Pros: single coherent pass. Cons:
delays API availability and requires coordinate with Phase F scheduling.

**Recommendation:** **Option A (merge now)** — the code is ready, tests are
solid, and users benefit from having the API available sooner. Phase F can
audit and refine the articles without re-implementing the function API.
Unblocks early adopters and allows the Phase F effort to focus on prose, not
implementation.

---

## Sign-off 3: Tweedie stays gated + stale-rationale refresh

**Branch:** `worktree-agent-a33d0cc868dd580a0` (no commit; uncommitted diff)  
**Base:** off `8ec261bb` (2026-07-13; now on main)  
**Authored:** Claude Code (2026-07-15, validated; diff prepared by Lane B)

### What it changes

**tests/testthat/test-family-slope-recovery.R** (uncommitted diff):
- **Added nbinom1 indep-slope recovery test** (lines 86-94): seed 101, heavy-gated
  (`GLLVMTMB_HEAVY_TESTS=1`). Passes on clean engine.
- **Updated header comment** (lines 4-19): clarified `#388` discipline, expanded
  tweedie gate rationale with S7 evidence, updated stale ~44% reference.

### New evidence (S7 validation, 2026-07-15)

The S7 outcome (after-task: `2026-07-15-S7-nbinom1-tweedie-slope-recovery.md`):

**nbinom1 random slope:** Recovers slope SD to ratio 1.005 (n=200, 7/8 seeds).
Already on runtime allowlist (#350); this test adds indep-slope recovery proof.

**Tweedie random slope:** Does **not** show the reported ~44% over-estimate
(recovers ~0.88–1.04 across conditions; free-p vs p-fixed agree within 0.01).
Un-gating remains blocked pending a full multi-seed campaign, but the stale
~44% magnitude reference needs correction in test comments.

### Check status

**Test updates:** ready, not merged.  
**After-task report:** written and (untracked) in the worktree.  
**Validation scope:** 8 seeds per cell, 2 cells (n ∈ {80, 200}); preliminary
but consistent finding.

### Decision needed

This is a **documentation-only decision** (the gating decision stands; tweedie
stays off the allowlist):

**Option A (land the test changes):**  
Merge the nbinom1 test and the updated header comment. Tweedie stays gated
(no change to the gate itself). The comment refresh is honest and records the
S7 finding for future readers.

**Option B (hold the test changes):**  
Keep uncommitted pending Shinichi's review of the S7 numbers. Re-evaluate after
a full Totoro/DRAC campaign (50+ seeds, per-trait bias + MCSE).

**Option C (special-case: refresh the comment only):**  
Apply just the comment update to `test-tweedie-fixed-p.R` (the NOTE lines that
currently claim ~44% over-estimate). Leave the nbinom1 test for a separate
pass, since nbinom1 itself has already landed (#350).

**Recommendation:** **Option A (merge test changes)** — the nbinom1 test is
solid and unblocked (family already approved). The updated header comment is
honest and helps future readers understand the S7 gate verdict. Both should
land. Save the full tweedie unblock decision for the Totoro campaign.

---

## Confidence notes

- **disp_group= gate result:** Solid evidence (3 n-values, 8 seeds/cell, 0
  convergence issues, clear pattern). High confidence the gate failed as
  reported.
- **family-breadth code:** Implementation mirrors existing patterns; no novel
  logic. High confidence it works.
- **tweedie S7 evidence:** 8 seeds per cell (limited but clear trend). Findings
  consistent with design expectations (gate preserved, no surprising
  improvement from p-fix). Preliminary, not a final un-gate.

---

## Next steps (for Shinichi)

1. **disp_group=:** Decide Option A (land with caveat) or Option B (drop).
2. **family-breadth:** Decide Option A (merge now) or Option B (hold for Phase F).
3. **tweedie comment:** Decide Option A (land test + comment) or Option B/C
   (defer / comment-only).

All three branches are ready to merge or drop; no further engineering work is
needed on any of them.
