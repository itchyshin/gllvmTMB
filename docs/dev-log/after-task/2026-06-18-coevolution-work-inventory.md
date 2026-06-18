# After Task: Coevolution Work Inventory

## Goal

Audit the cross-lineage coevolution model work already completed and explain
why the model can be both implemented in its current one-kernel form and still
unfinished relative to the larger Paper 2 brief.

## Implemented

Added `docs/dev-log/audits/2026-06-18-coevolution-work-inventory.md` and
refreshed dashboard evidence for two material facts:

- the Design 65 one-kernel coevolution path is currently green under both fast
  and heavy local tests;
- GLLVM.jl #101 fresh PR CI and Documenter checks have completed
  successfully, clearing that evidence gate without making #489 release-ready.

## Mathematical Contract

The current implemented model is a one-kernel point-estimate workflow:

```r
kernel_latent(species, K = K_star, d = 2, name = "cross") +
  kernel_unique(species, K = K_star, name = "cross")
```

with `extract_Gamma()` returning the shared host-trait by partner-trait block.
The full Paper 2 Option B target, with independent `K_phy` and `K_non`
components, fitted or profiled `rho`, and separate `Gamma_shape` /
`Gamma_effect` quantities, is not implemented.

## Files Changed

- `docs/dev-log/audits/2026-06-18-coevolution-work-inventory.md`
- `docs/dev-log/after-task/2026-06-18-coevolution-work-inventory.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`

## Checks Run

- `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution|kernel-equivalence|example-coevolution-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 99`.
- `PATH="/opt/homebrew/bin:$PATH" GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution|kernel-equivalence|example-coevolution-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 125`.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null`
  -> valid JSON.
- `python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  -> valid JSON.
- `git diff --check` -> clean.

## Tests Of The Tests

The fast run confirms parser, extractor, fixture, and guardrail behavior. The
heavy run confirms the C0 planted-`Gamma` prototype, C2 known-`Gamma` recovery
and null comparison, sparse-versus-dense single-`W` sensitivity, C3
identifiability guardrail, and kernel equivalence.

## Consistency Audit

The audit cross-checked `R/kernel-helpers.R`, `R/kernel-keywords.R`,
`R/brms-sugar.R`, `R/fit-multi.R`, `R/extract-sigma.R`,
`tests/testthat/test-coevolution-*.R`, `tests/testthat/test-kernel-equivalence.R`,
`tests/testthat/test-example-coevolution-kernel.R`, Design 65, Design 35 rows
`KER-01`, `COE-01`, `KER-02`, `COE-02`, and `COE-03`, the coevolution article,
and prior after-task reports.

## What Did Not Go Smoothly

The term "finished" was overloaded. C0-C2 are genuinely implemented and green;
the new Paper 2 brief describes a broader future model. The dashboard also had
stale #101 in-progress wording that needed a material evidence refresh.

## Team Learning

Ada/Fisher framing: keep Option A and Option B separate. One-kernel
point-estimate coevolution is not the same as a two-kernel coevolution model
with estimated coupling and calibrated uncertainty.

## Known Limitations

No package code changed. No public article was promoted. No two-kernel engine,
in-engine `rho`, bootstrap intervals, mixed-family cross-lineage recovery, or
sparse scalability claim was added.

## Next Actions

Decide whether Paper 2 should guarantee Option A and treat Option B as a
simulation-gated extension, or whether to invest in a true arbitrary
named-kernel engine before making the manuscript model stronger.
