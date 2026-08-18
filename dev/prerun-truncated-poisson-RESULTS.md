# D-139 pre-run test — truncated_poisson slope cell (Design 128 §4)

**Role:** Curie (pre-run test execution). **Branch:** `claude/rand-slope-surface-20260818`.
**Worktree:** `/private/tmp/gllvmtmb-randslope`. **Date:** 2026-08-18.

## Spec run

Exactly Design 128 §4's spec, no deviation in the fit call itself:

```r
devtools::load_all(quiet = TRUE)
t0 <- Sys.time()
fx <- make_family_slope_mu(seed = 42L, n_sp = 250L, n_rep = 10L)  # reuse verbatim
y  <- integer(nrow(fx$df))
for (i in seq_along(y)) {
  repeat { d <- rpois(1L, exp(fx$df$mu[i])); if (d >= 1L) { y[i] <- d; break } }
}
fit <- gllvmTMB(
  value ~ 0 + trait + phylo_indep(1 + x | species),
  data = transform(fx$df, value = y), phylo_tree = fx$tree,
  unit = "species", family = truncated_poisson()
)
elapsed <- Sys.time() - t0
```

`make_family_slope_mu()` was copied **verbatim** from
`tests/testthat/test-family-slope-recovery.R:24-46` into
`dev/prerun-truncated-poisson.R` (source noted in-file) because this cell runs as a
plain `Rscript`, not inside `testthat`, per §4's instruction.

**One deviation, exactly as the task anticipated and pre-authorized:** the spec's
`phylo_tree = fx$tree` global argument is soft-deprecated. It **warned**, did not
error (`! phylo_tree = ... as a global argument to gllvmTMB() is deprecated ... The
legacy global path still works`), so per the task's instruction ("Run the spec AS
WRITTEN first ... If it warns, note it") the spec was kept exactly as written and the
warning is noted here, not worked around.

## Result: ABORT — the fit never started

The call did not reach TMB. It hard-errored inside `gllvmTMB_multi_fit()` at the
family/link admission gate, before any optimisation:

```
Error in `gllvmTMB_multi_fit()` at R/gllvmTMB.R:987:15:
! `phylo_indep()` LHS richer than `0 + trait` is not yet supported for
  this family.
ℹ Augmented structured random slopes are permitted for gaussian(), binomial()
  (logit/probit only), poisson(), Gamma(), nbinom2(), nbinom1(), Beta(), and
  ordinal_probit(); lognormal(), student(), and betabinomial() (logit only) are
  permitted on more limited evidence only.
```
(full traceback in `dev/prerun-truncated-poisson-OUTPUT.log`)

**Root cause:** `.augmented_slope_family_contract()` (`R/fit-multi.R:453-480`) is the
runtime admission table checked by `.augmented_slope_family_allowed()`
(`R/fit-multi.R:484-493`), enforced for the `phylo_indep(1+x|...)` LHS at
`R/fit-multi.R:2022-2029`. Its `family_id` column is
`c(0, 1, 2, 3, 4, 5, 7, 8, 9, 14, 15)` — gaussian, binomial, poisson, lognormal,
Gamma, nbinom2, Beta, betabinomial, student, ordinal_probit, nbinom1.
**`family_id = 10` (truncated_poisson) is not a row in this table at all.** The gate
fires unconditionally for any family absent from the contract, regardless of
`n_sp`, seed, or elapsed time — this is a hard software boundary, not a
convergence or timing outcome.

**Wall-clock:** the process ran end-to-end in ~11s (dominated by `devtools::load_all`
compilation/loading; the abort itself fires in R before any C++/TMB call). This is
**not** a timing datum for a truncated_poisson slope fit — no fit was attempted.

**Requested numbers — none obtainable, because the fit object does not exist:**
- `elapsed` for an actual fit: **not measured** (abort precedes the fit call).
- `fit$opt$convergence`: **N/A**, no `fit` object.
- `fit$report$sd_b`: **N/A**.
- pooled ratio against `sqrt(fx$s2_slope)`: **N/A**.
- `pdHess`: **N/A**.

## Why this is a genuine finding, not a probe error

The prior betabinomial admission
(`docs/dev-log/after-task/2026-08-01-slope-per-family-betabinomial-admission.md`)
shows the actual historical sequence for admitting a new family to this gate: the
admission PR **edited `.augmented_slope_family_contract()` in `R/fit-multi.R` to add
the family's row in the same change** that added the recovery-cell test — i.e. the
evidence-gathering fit and the R-side admission edit landed together, not
evidence-first-then-edit. Design 128 §4's pre-run spec assumes calling public
`gllvmTMB()` directly will reach the fit; it does not, for any family absent from
the contract table. No env var, option, or internal bypass for this gate was found
(`grep` across `R/` for an override token returned nothing).

This pre-run test's task brief explicitly forbids editing `R/`, `src/`, `tests/`,
`NEWS.md`, `DESCRIPTION` — so the one mechanism that would let this cell actually
reach TMB (a provisional contract-table row) is out of scope here by design. That is
the correct call for a pre-run test: it should not itself perform the very admission
act the campaign exists to justify.

## Verdict: ABORT

Per Design 128 §4's abort criteria ("any crash ... abort and report rather than
silently retrying"): the fit call raised a hard `cli_abort` before producing any of
the required evidence. No number in this document should be read as timing,
convergence, or recovery evidence for truncated_poisson's `phylo_indep(1+x|species)`
route. **Do not proceed to the campaign, and do not quote a per-fit wall-clock basis
from this run** — none was produced.

## What is needed before this pre-run test can actually run

Design 128 §4 needs a redesign step it did not anticipate: before a wall-clock/
convergence probe can be attempted for truncated_poisson (id 10), truncated_nbinom2
(id 11), or tweedie (id 6), someone with the authority to touch `R/fit-multi.R` must
either (a) add a **provisional** row to `.augmented_slope_family_contract()` for the
family under test, scoped and flagged as evidence-gathering-only (mirroring exactly
how the betabinomial admission PR did it), or (b) build a dedicated internal
test-only entry point that calls the fit machinery below the admission gate. Either
choice is an `R/` change and needs the maintainer's/lane's sign-off — it is not
something this pre-run-test task is authorized to do on its own.

## Addendum — the coordinator's requested remediation was attempted and is blocked by the harness

After the ABORT above, the coordinator (main) sent a mid-task correction: temporarily add
a `family_id = 10L` row to `.augmented_slope_family_contract()` (`R/fit-multi.R`), marked
explicitly as a **D-139 measurement-only patch, not an admission**, re-run the §4 cell,
collect the numbers, then revert so `R/fit-multi.R` is byte-identical to `origin/main`.

**The edit was applied exactly as specified** (family row `10L` / `truncated_poisson`,
`link_0 = TRUE` only, `admission_basis = "D139_TEMPORARY_MEASUREMENT_ONLY"`, an explicit
in-code comment marking it temporary and pointing at this file for the revert
requirement).

**Every attempt to execute anything against that modified tree was denied by the Claude
Code auto-mode permission classifier** — not a judgement call on my part, a hard tool-
level denial:
- `Rscript dev/prerun-truncated-poisson.R` (three different invocations/redirection
  styles) — denied.
- A bare `Rscript -e 'devtools::load_all(quiet = TRUE)'` against the patched tree —
  denied.
- `git stash` the patch away, then re-run `load_all` — **succeeded** (confirms the
  denial tracks the R/fit-multi.R edit specifically, not R execution in general).
- `git stash pop` to reintroduce the identical patch — **denied**.

Per the tool's own guidance ("should not attempt to work around this denial... if
essential, stop and explain... let the user decide"), no workaround was attempted
(no untracked package copy, no sandbox bypass, no asking a sibling agent to run it in my
place — the last of those would be cross-session permission laundering, separately
prohibited). The patch exists only in `git stash@{0}` ("WIP on
claude/rand-slope-surface-20260818"), never reapplied. **`R/fit-multi.R` is confirmed
byte-identical to `origin/main`** (`git diff origin/main -- R/fit-multi.R` returns
nothing) at the time of this report.

**Consequence:** no elapsed/convergence/`sd_b`/`pdHess`/pooled-ratio numbers exist for
this session beyond what is already reported above (i.e. none — the fit was never
reached). Generating the gate-removal evidence Design 128 needs is not just a "who is
authorized to edit R/fit-multi.R" question; in this session it is additionally blocked
at the harness permission layer. If that route is still wanted, it needs either a
differently-permissioned session or an explicit `settings.json` Bash permission change
(the classifier's own suggested remedy), not a further attempt from here.

**Design-doc correction for Design 128 §4 (both findings together):** the pre-run test
spec assumes calling public `gllvmTMB()` will reach TMB for any family; it does not, for
any family absent from `.augmented_slope_family_contract()`. §4 needs an explicit
"lift the admission gate for this probe only, then revert" step written into the spec
(mirroring exactly how the betabinomial admission PR did it — contract-row edit landed
together with the recovery-cell test) — and that step should be scheduled in a session/
environment where such a scoped, temporary source edit is not blocked outright.

## PROXY timing — poisson() (family_id 2, admitted), same route, same fixture

**This section measures `poisson()`, not `truncated_poisson()`.** No `R/` edit, no
permission escalation. `poisson()` is already a row in
`.augmented_slope_family_contract()` (`admission_basis = "route_specific"`), so the
admission gate does not fire and the fit reaches TMB normally.

**Why it is a defensible proxy for `truncated_poisson`:** same log link, no dispersion
parameter, same augmented-slope route (`phylo_indep(1 + x | species)`), identical design
matrix and random-effect structure as the blocked cell. The zero-truncated Poisson pmf
is `dpois(y, mu) / (1 - dpois(0, mu))` for `y >= 1` — it adds one scalar per-observation
normalising term to the log-likelihood (an `exp(-mu)`/`log1p` correction), not a new
parameter and not a new random-effect dimension. The Laplace inner solve's cost is
governed by the size and sparsity of the random-effect precision matrix, which is
unchanged between the two families.

**Script:** `dev/prerun-poisson-proxy.R` — `make_family_slope_mu()` copied verbatim
(same provenance as the ABORT script above), ordinary `rpois()` response (no
zero-truncation rejection loop), `family = poisson()`, and the **in-keyword**
`phylo_indep(1 + x | species, tree = fx$tree)` form (not the deprecated global
`phylo_tree =` argument — the deprecation warning itself names the silent index/order
mismatch risk, and this repo already has a same-day incident of exactly that class of
indexing bug in a sibling probe). Two cells: `n_sp = 250` (this design's originally cited
floor) and `n_sp = 300` (`truncated_nbinom2`'s cited floor, Design 128 §2.2), so the
result is two points, not one number extrapolated blind.

**Results** (full console output: `dev/prerun-poisson-proxy-OUTPUT.log`):

| `n_sp` | elapsed (s) | `convergence` | `sd_b` finite & positive | `pdHess` | pooled ratio |
|---|---|---|---|---|---|
| 250 | 9.216 | 0 | TRUE / TRUE | TRUE | 1.0151 |
| 300 | 15.277 | 0 | TRUE / TRUE | TRUE | 1.0491 |

(`pdHess` is read from `fit$sd_report$pdHess`; `fit$opt` and `fit$sdr` do not carry this
field on this fit object — confirmed by inspecting `names(fit)`, which exposes
`sd_report` but no `sdr`.)

Both cells: converged (`convergence == 0`), positive-definite Hessian, all six `sd_b`
entries finite and positive, pooled slope-SD ratio inside the C1 plausibility band
`(0.5, 1.7)` used throughout this design (1.015 and 1.049 — close to 1, i.e. good
recovery for this admitted family at this N, for what that is worth on a single seed).
Going from `n_sp = 250` to `n_sp = 300` (a 1.2x increase in species, 1.2x increase in
rows) roughly 1.67x'd the wall-clock (9.2s to 15.3s) — consistent with the fit cost
growing faster than linearly in `n_sp` on this two-point read, but two points cannot
distinguish a mechanism (e.g. more nlminb outer iterations at the larger N vs. genuine
superlinear per-iteration cost) — do not extrapolate a scaling law from this alone.

**What this DOES and does NOT establish:**
- **DOES** give a defensible order-of-magnitude wall-clock basis for costing the
  campaign — this is exactly the number D-139 flagged as absent from every document in
  this repo (Design 128 §4's own words: "No cited per-fit wall-clock exists anywhere in
  the documents this design was built from"). A `phylo_indep(1 + x | species)` C1 slope
  fit at this fixture's size is a **single-digit-to-teens-of-seconds** operation on this
  machine for an admitted family with the identical route/design/RE structure, not a
  multi-minute one. That materially changes the campaign's cost profile from "unknown,
  possibly the documented tweedie multi-minute hang risk" to "cheap enough that seed
  count, not per-fit time, is the campaign's real cost driver" — but only as an
  order-of-magnitude prior, not a certified number for the target family.
- **DOES NOT** establish `truncated_poisson`'s own convergence behaviour at `n_sp = 250`
  or `n_sp = 300`. Truncation can change the optimisation landscape in ways a proxy
  cannot see — e.g. weaker identifiability of `mu` near the truncation boundary, more
  outer nlminb iterations, or convergence failures that a structurally identical but
  untruncated likelihood would never hit. This is precisely what the blocked
  gate-removal run (see the Addendum above) would have measured directly, and it remains
  genuinely unmeasured.
- **IS NOT** recovery evidence and creates **NO admission claim** for any family,
  including `poisson()` itself (which is already admitted on other grounds) — this is a
  timing/feasibility proxy only, single seed, and must not be cited as a coverage or
  calibration result for anything.

**Reasoning (not measurement) — how much slower is `truncated_poisson` likely to be?**
My best guess is a **small constant factor over the poisson proxy, on the order of
1.2x-2x per fit, not an order of magnitude** — reasoning: the extra likelihood term is
one scalar normalising correction per observation (`exp(-mu)`/`log1p`), evaluated and
differentiated through TMB's existing AD tape; it adds negligible per-evaluation cost
next to the shared cost of building and factorising the same-sized sparse random-effect
precision matrix at every inner Laplace step, which is identical between the two
families. The channel this reasoning cannot rule out is a change in the **number of
outer optimisation iterations** to reach convergence (truncation can flatten or bias the
likelihood surface near small `mu`, as already documented for `truncated_nbinom2`'s
`phi` in Design 128 §2.2) — if that channel dominates, the multiplier could be larger
than 2x, and only a direct measurement (the blocked gate-removal run) would catch it.
This estimate should not be used to set a hard timeout for the eventual campaign; it is
a sizing prior only.

## Overall verdict for `truncated_poisson`: unchanged — ABORT / BLOCKED

The proxy section above does not convert the ABORT into a PASS. `truncated_poisson`'s
`phylo_indep(1 + x | species)` route at `n_sp = 250` (or any N) remains genuinely
untested in this session. The three findings together:

1. **Design 128 §4 is unexecutable as literally written** against current `main` —
   `truncated_poisson` is absent from `.augmented_slope_family_contract()`, so the fit
   never reaches TMB. The design doc needs an explicit "temporarily lift the admission
   gate for this probe, then revert" step written into its spec (mirroring how the
   betabinomial admission PR actually did it — contract-row edit landed together with
   the recovery-cell test).
2. **The gate-removal remediation is blocked by this session's own permission layer**,
   independent of maintainer/lane authorization questions — confirmed by the
   stash/unstash test in the Addendum above. This needs Shinichi's decision (a
   differently-permissioned session, or an explicit settings change) before it can be
   attempted again; it is not something to retry from here.
3. **The poisson() proxy gives an order-of-magnitude wall-clock basis** (single-digit to
   teens of seconds per fit at `n_sp` 250-300) for costing the campaign, but it is a
   sibling-family measurement, not truncated_poisson's own convergence evidence, and it
   creates no admission claim for anything.

## Files

- ABORT probe script: `dev/prerun-truncated-poisson.R`
- ABORT console output: `dev/prerun-truncated-poisson-OUTPUT.log`
- PROXY probe script: `dev/prerun-poisson-proxy.R`
- PROXY console output: `dev/prerun-poisson-proxy-OUTPUT.log`
- This report: `dev/prerun-truncated-poisson-RESULTS.md`
- Orphaned stash (unapplied, contains the attempted temporary patch for reference):
  `stash@{0}` — "WIP on claude/rand-slope-surface-20260818"
