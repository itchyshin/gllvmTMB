# LA-MSPL SE for all other families — arc-series note

**Date:** 2026-08-16
**Branch:** `cursor/mspl-se-other-families-series`
**Base:** `origin/main` @ `fe867e40` (after [#979](https://github.com/itchyshin/gllvmTMB/pull/979) and [#978](https://github.com/itchyshin/gllvmTMB/pull/978))
**Status:** series charter only. No pin, no admit, no public SE.

This is **LA-MSPL** (Laplace integration plus a soft outer criterion).
It is not EVA, VA, or AGHQ-MSPL.

---

## What this series is

Every **non-binomial** family that is `admitted` or `planned` on
`R/mspl-registry.R` gets an SE **feasibility pin**: can the named
curvature construction be formed, and is each Hessian positive
definite?

That is the same job [#979](https://github.com/itchyshin/gllvmTMB/pull/979)
already did for Bernoulli-logit and one tiny Poisson cell. This series
does **not** rebuild that work. It repeats the pin, family by family,
for everyone else.

A pin reports, for one small ordinary fixture:

- whether \(Q_P\) (penalised tape, `fit$tmb_obj`, `estimator_id = 1`)
  can be formed;
- whether \(Q_0\) (penalty-off tape, `fit$mspl$unpenalized_tmb_obj`,
  `estimator_id = 2`, evaluated not optimised) can be formed;
- the typed status of each Hessian: `available`, `non_pd`,
  `nonfinite`, or `error`.

Non-PD stays typed. No pseudoinverse, no eigenvalue clip, no
nearest-PD, no substituting \(Q_P\) for \(Q_0\). Every attempt stays
in the denominator.

Forming a finite SE is not “MSPL has standard errors.”

---

## What this series is not

**Binomial / Bernoulli SE already exists.** Codex Lane B
(`codex/lane-b-mspl-interval-feasibility`) owns the binary interval
campaign. [#979](https://github.com/itchyshin/gllvmTMB/pull/979) already
landed the internal Bernoulli-logit pin and the tiny Poisson pin.
Do not reopen those files to “improve” them from this series.
Do not copy Lane B helpers. Do not absorb Lane B.

**Public inference stays fail-closed.** `vcov()`, `confint()`, and
`standard_errors()` keep raising
`gllvmTMB_mspl_inference_unsupported`.
`R/fit-multi.R` still sets `sd_rep <- NULL` for
`estimator == "mspl"` (around line 6423) until a later, separately
authorised **calibration** gate (Design 118). A green pin does not
open that door.

**No NEWS covered claim.** Availability is not coverage.

---

## Family roster (status from `main`)

Status words below are taken from `R/mspl-registry.R` on
`origin/main` @ `fe867e40`, plus the public prepare fence in
`R/mspl.R` (`family_id ∈ {0, 1, 2}` only).

| Family | Registry on `main` | Public `estimator="mspl"` | MSPL tape on `main` | This series |
|---|---|---|---|---|
| binomial / Bernoulli | `admitted` (point; B2 incomplete) | yes | live Jeffreys atom | **out of scope** — Lane B + #979 |
| gaussian | `admitted` (point; `oracle_local`; `se=FALSE` smoke) | yes | Hirose atom | **pin** — first admitted non-binomial |
| poisson | `planned` (`phase4_prep`; not admitted) | yes, experimental | GLM-outer \(W=\mathrm{diag}(\mu)\) | **pin beyond the #979 cell** (that cell was one tiny \(n=8,p=3\) grid; not a grid, not all-zero, not large-\(\mu\)) |
| nbinom2 | `excluded` (“waits for Phase 4 after Poisson admission”) | no — prepare rejects | fenced GLM-outer tape (#978) | listed; pin waits until the row is `planned` or `admitted` |
| nbinom1 | **na** (no row) | no | fenced GLM-outer tape (#978) | listed; pin waits |
| tweedie | **na** (no row) | no | fenced GLM-outer tape (#978) | listed; pin waits |
| Beta | **na** (no row) | no | fenced GLM-outer tape (#978) | listed; pin waits |
| Gamma | **na** (no row) | no | none | listed; pin waits; needs a planned tape first |
| lognormal | **na** (no row) | no | none | listed; pin waits; needs a planned tape first |
| student (Student-t) | **na** (no row) | no | none | listed; pin waits; needs a planned tape first |
| ordinal (`ordinal_probit`) | **na** (no row) | no | none | listed; pin waits; needs a planned tape first |
| hurdle (`delta_lognormal`, `delta_gamma`) | **na** (no row) | no | none | listed; pin waits; needs a planned tape first |

**na** means the family has no row in `.gllvmTMB_mspl_registry()` on
`main`. It is not a planned cell and not an admitted cell.

Open Phase-4 prep PRs [#972](https://github.com/itchyshin/gllvmTMB/pull/972)–[#976](https://github.com/itchyshin/gllvmTMB/pull/976)
are notes and oracles only. They do not change this table. Do not
merge them from this series.

`.gllvmTMB_mspl_curvature_pin()` on `main` is still fenced to
Bernoulli-logit and Poisson-log. Extending that fence is the
implementer’s job, not a sibling’s.

---

## Suggested wave order

1. **Wave A — public door already open.** Gaussian ordinary identity
   \(q=1\), then Poisson beyond the #979 cell (a second fixture:
   zeros, or larger \(\mu\), or \(q=2\) — one named cell per PR).
   These are the only non-binomial `admitted` / `planned` rows on
   `main`.
2. **Wave B — fenced tape exists, public door closed.** nbinom1,
   nbinom2, Beta, tweedie. A #979-style public-fit pin cannot run
   until prepare admits the family as `planned` or `admitted`. Do
   not invent a backdoor fit.
3. **Wave C — no tape.** Gamma, lognormal, student, ordinal_probit,
   hurdle. A pin is not the first artefact. A planned tape is.

One family, one PR, one tiny cell. Local only,
`OMP_NUM_THREADS=1`. No Totoro/DRAC campaign without a written
D-139 receipt.

---

## File ownership

This is the coordination contract. Parallel siblings are expected.

| Who | May write | Must not write |
|---|---|---|
| **Sibling pin lanes** (one family each) | only `tests/testthat/test-zz-mspl-<family>-se-feasibility.R` | `R/mspl-curvature-pin.R`, `R/fit-multi.R`, `R/mspl.R`, `R/mspl-registry.R`, `src/`, NEWS, Lane B, the #979 Bernoulli/Poisson zz files |
| **One implementer** | extensions to `R/mspl-curvature-pin.R` (widen the family/link fence; keep the pin unexported) | public `vcov` / `confint` / `sdreport()`; registry `planned` → `admitted`; NEWS covered |
| **Later authorised PR only** | the `R/fit-multi.R` MSPL withhold (`sd_rep <- NULL` at the estimator) | anyone in this series |

The `test-zz-` prefix is required. #979 CI failed twice when the
Bernoulli/Poisson pins ran *before*
`test-va-all-family-light-fits.R` (`delta_lognormal_log` health
gate). The VA suite is not this series; do not edit it.

Each sibling test copies the #979 shape:

- public `se=TRUE` still withholds `sd_report`;
- `vcov()` / `confint()` / `standard_errors()` still error with
  `gllvmTMB_mspl_inference_unsupported`;
- the internal pin names \(Q_P\) and \(Q_0\) separately;
- poison a silent tape swap (`estimator_id` 1 vs 2; unequal NLLs);
- accept `available` **or** `non_pd` (non-PD is a finding);
- do not export the pin.

For Wave B/C, the sibling may land the zz file as a
skip-until-planned fence. That file still belongs to the sibling.
The implementer does not write it.

---

## Hard stops

- Public `vcov()` / `confint()` / `standard_errors()` on MSPL.
- NEWS or register “covered” for any MSPL SE.
- Rebuild or rewrite the binomial / Bernoulli SE lane (Lane B or
  `test-zz-mspl-bernoulli-se-feasibility.R`).
- Edit `R/fit-multi.R` withhold from this series.
- Admit Poisson, or open the public door for nbinom1/2, Beta,
  Tweedie, Gamma, lognormal, student, ordinal, or hurdle.
- Merge #972–#976 from this series.
- Copy Codex Lane B helpers.
- `git add -A`.
- Dropbox checkout.
- Shared dirty tree
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

---

## Pointers

- Pin implementation: `R/mspl-curvature-pin.R`
- #979 twins (do not rebuild):
  `tests/testthat/test-zz-mspl-bernoulli-se-feasibility.R`,
  `tests/testthat/test-zz-mspl-poisson-se-feasibility.R`
- Estimand pick (both Hessians):
  `docs/dev-log/research/2026-08-15-mspl-se-estimand-pick.md`
- #979 after-task:
  `docs/dev-log/after-task/2026-08-15-mspl-se-feasibility-pin.md`
- Later calibration gate (not this series):
  `docs/design/118-mspl-interval-calibration-protocol.md`
- Lane map:
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`
