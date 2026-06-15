# After Task: Julia Bridge Capability Drift Guard

## Goal

Make the R-side `engine = "julia"` capability ledger honest about paired-Julia
rows that are not yet admitted through `gllvmTMB`.

## Implemented

`gllvm_julia_capabilities()` now includes explicit `planned` rows for `nb1` and
`mixed-family vector`. A new live, Julia-gated test calls
`GLLVM.bridge_capabilities()` and enforces the one-way subset contract: every
R-admitted row must be supported by the paired Julia checkout, while Julia-only
fit rows must appear as planned R debt. NB1 and mixed-family vectors remain
rejected before JuliaCall in the public R bridge.

## Mathematical Contract

N/A - this is a structural bridge-governance change. It does not alter the
likelihood, parameterization, optimizer, or confidence-interval calculations.

## Files Changed

- `R/julia-bridge.R` - added planned rows and the internal live capability
  normalizer/caller.
- `tests/testthat/test-julia-bridge.R` - added NB1 planned-row assertions and
  the live subset guard.
- `man/gllvm_julia_capabilities.Rd` - regenerated for the expanded ledger.
- `NEWS.md` - documents the planned NB1/mixed-family visibility.
- `docs/dev-log/check-log.md` - records commands and evidence.

## Tests Added

One pure-R ledger extension and one live Julia-gated subset test. The pure-R
assertions catch hidden planned rows; the live guard catches R admission drift
against the paired Julia bridge surface.

## Benchmark Numbers

N/A - no fitting, likelihood, or hot-path code changed.

## R-Parity Verdict

Structural bridge parity passed. This is not a numeric log-likelihood parity
slice, but the live bridge file also reran the existing numerical bridge rows
and passed `353/353` assertions.

## JET / Allocs / Aqua Verdicts

- JET: N/A - R bridge metadata only.
- Allocs: N/A - R bridge metadata only.
- Aqua: N/A - R bridge metadata only.

## Checks Run

```sh
~/.juliaup/bin/julia --project=. test/test_bridge_capabilities.jl
```

Result in `GLLVM.jl-integration`: `9/9 pass`.

```sh
Rscript -e 'devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 15 | PASS 146`.

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

Result: `FAIL 0 | WARN 0 | SKIP 0 | PASS 353`.

```sh
Rscript -e 'devtools::document()'
```

Result: regenerated `man/gllvm_julia_capabilities.Rd`; unrelated pre-existing
unresolved roxygen links were reported in other topics.

```sh
Rscript -e 'pkgdown::check_pkgdown()'
```

Result: `No problems found`.

```sh
git diff --check
```

Result: clean.

## Consistency Audit

```sh
rg -n "nbinom1|\bnb1\b|mixed-family vector|bridge_capabilities|gllvm_julia_capabilities" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md man/gllvm_julia_capabilities.Rd
```

Result: expected hits in the R ledger, planned-row tests, NEWS, and generated
manual page.

## GitHub Issue Maintenance

No issue was opened or closed. This supports the existing `gllvmTMB#488`
bridge-gate drift lane and keeps NB1/mixed-family work visible without claiming
admission.

## What Did Not Go Smoothly

`devtools::document()` rewrote unrelated Rd files due existing roxygen state;
those unrelated generated changes were removed from this slice.

## Team Learning

The bridge ledger should track three states, not two: R-admitted, Julia-only but
planned in R, and unsupported.

## Remaining Risks

- `gllvm_julia_capabilities()` still has coarse CI columns; CI method support
  needs its own ledger before any broader interval claim.
- NB1 and mixed-family vectors are visible planned debt, not supported R bridge
  routes.

## Known Limitations

`.gllvm_julia_family("nbinom1")` and family lists still fail before JuliaCall.
This is deliberate until family mapping, dispersion labels, refit metadata,
parity rows, and CI/status behavior are validated.

## Next Command

```sh
GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'
```

## Rose Verdict

Rose verdict: PASS WITH NOTES - the R drift guard is live-tested, but NB1 and
mixed-family vectors remain planned rather than admitted through the R bridge.
