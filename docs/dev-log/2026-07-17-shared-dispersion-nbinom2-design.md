# Design — shared / grouped NB2 dispersion (`disp_group=`) to un-fence nbinom2

**Date:** 2026-07-17 · **Status:** **DEFERRED (accepted in principle).** Maintainer decision
2026-07-17: disp_group is a legitimate parsimony option for when a per-trait NB2 φ cannot be estimated,
so we may add it later — but it is **NOT built for 0.6**. nbinom2 stays fenced / recovery-only for 0.6;
revisit as a possible **1.0** option (or sooner if a real user needs the shared-φ parsimony). This doc
is preserved as the record of what the feature would be and how it would be built.
**Graduation (only if un-deferred):** promote to `docs/design/NN-shared-dispersion.md` with an assigned
design number at sign-off; it is an engine + API change → maintainer sign-off before any C++.

## 1. Why (the problem this solves)
nbinom2 coverage/recovery is FENCED because of the well-known **NB-dispersion vs latent-variance
ridge**: the DGP uses ONE shared `phi`, but gllvmTMB estimates **one free `phi` per trait**
(over-parameterised), so the latent variance and per-trait `phi` trade off and Σ under-recovers.
Evidence (mitigation ladder, handover-recorded; to be re-confirmed in slice d): median Σ̂/truth ≈
**0.45–0.52 (default per-trait phi)**, warm-start no help, **0.78–0.82 rising with n (known phi)**.
Pooling `phi` across traits is the literature-endorsed remedy and mirrors gllvm's `disp.formula`.
Refs: `docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`;
`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md` §3 item 4.

## 2. Mechanism (CONFIRMED against src/gllvmTMB.cpp)
Today (per-trait): `src/gllvmTMB.cpp:615` `PARAMETER_VECTOR(log_phi_nbinom2)` length n_traits; the NB2
leg (fid 5) at `:2045-2047` does `int t = trait_id(o); ... - log_phi_nbinom2(t)`.

Change = one indirection through a group map:
- Add `DATA_IVECTOR(disp_group_nbinom2);` — length **n_traits**, entries in `0..(n_groups-1)`, mapping
  each trait to a phi-group.
- `log_phi_nbinom2` becomes length **n_groups (≤ n_traits)**.
- Likelihood: `... - log_phi_nbinom2(disp_group_nbinom2(t));`
- `REPORT(phi_nbinom2)` (`:2520,2529`) stays; length becomes n_groups.

**Backward compatibility is exact:** default `disp_group_nbinom2 = 0:(n_traits-1)` (identity) ⇒
per-trait phi ⇒ byte-identical to current fits. `disp_group_nbinom2 = rep(0, n_traits)` ⇒ one shared phi.

## 3. User surface
New control `disp_group=` (name TBD — see §8), default = per-trait (identity). Accepts a grouping of
traits: an integer/factor vector of length n_traits, or a one-sided formula à la gllvm `disp.formula`
(e.g. `~1` = one shared phi for all traits; `~trait_type` = pool within a covariate). R maps the spec
to the 0-based integer `disp_group_nbinom2` and sizes `log_phi_nbinom2` to n_groups.

## 4. R wiring (pointers from handover; exact lines to CONFIRM at implementation)
`R/fit-multi.R`: family/phi mapping (~L272+) assembles `log_phi_nbinom2` — size it to n_groups and add
`disp_group_nbinom2` to the TMB `data`. Control surface pattern at `R/fit-multi.R:3677 / :4524`.
Init: warm-start each group phi from the mean of its traits' current per-trait init.

## 5. Slices (ranked; b–e gated on §7)
- **(a) THIS design doc** — conflict-free, land now.
- (b) C++ group-index + map (the §2 change) + a byte-equivalence guard (identity map == current).
- (c) R wiring + `disp_group=` arg + spec→integer mapping + `gllvmTMBcontrol()`/roxygen.
- (d) **recovery validation** — re-run `dev/nbinom2-mitigation-ladder.R` with shared phi: does median
  Σ̂/truth rise toward 1 (target ≈ the known-phi 0.78–0.82+ and better)? D-43 default NOT-DONE: "it
  works" = recovery to truth, not an assertion.
- (e) coverage smoke on 1–2 nbinom2 cells (LOCAL small n_sim, or a SEPARATE Totoro/DRAC dir) — only a
  real shared-phi coverage run may claim nbinom2 coverage-certified; do NOT un-fence on recovery alone.

## 6. Correctness invariants / tests
1. **Identity-map equivalence:** `disp_group = per-trait` reproduces current nbinom2 fits to <1e-8
   (objective, phi, Σ). Required.
2. **Shared-phi recovery:** on the ladder DGP (one true phi), pooled phi recovers Σ (slice d).
3. n_groups length bookkeeping: `phi_nbinom2` REPORT, sdreport, and any phi extractor handle length
   n_groups (not hard-coded n_traits).
4. Bad-spec errors: disp_group length ≠ n_traits, or a group with no traits → clear cli error.

## 7. Sequencing / sign-off gate
- **Engine + API change → maintainer sign-off before merge** (repo Discussion-Checkpoint rule).
- Code slices (b,c) touch `src/gllvmTMB.cpp` and `R/fit-multi.R`, which are in Lane A's large
  uncommitted body → **defer b–e until that body is committed** (parallel-lane handover §1A), to avoid
  editing on top of uncommitted changes. Design (a) is safe now. Use a git worktree for isolation.

## 8. Open questions for the maintainer
1. **Arg name:** `disp_group=` (integer/factor) vs `disp.formula=` / `disp_formula=` (formula, gllvm
   parity)? Recommendation: `disp_group=` accepting a factor OR a one-sided formula, keyword-consistent
   with the existing grammar.
2. **Scope now:** nbinom2 only, or also apply the same group map to **tweedie** phi (fid 6) and
   **truncated_nbinom2** (fid 11), which share the per-trait-phi pattern? Recommendation: ship nbinom2
   first, generalise in a follow-up.
3. **Certificate interaction:** if shared phi tightens the ridge, nbinom2 could re-enter the coverage
   campaign — but that needs its own coverage run (slice e) before any un-fence claim.

## 9. What this does NOT do
Not a public un-fence of nbinom2 (that needs slice e + sign-off). Not a change to gaussian/binomial.
Not the coverage-certificate MCSE work (separate arc). DEV-ONLY until validated + signed off.
