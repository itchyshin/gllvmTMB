# EVA Gate-1 source manifest

This Arc is a provenance guard only.  It does not promote EVA Gate-1 or
reintroduce its files into `main`.

## Sealed source

The authoritative Gate-1 source is commit
`3b479354285a8dcd69ab43cc26d98f98e6b98041` (`research(86): seal EVA gate-1 prototype`).
The checker requires byte-for-byte equality for the following paths if they
are present in the working tree:

| Path | Sealed blob |
| --- | --- |
| `R/eva-proto.R` | `a029dbe76b127b3f9a9eca08145fbfc58546f6a4` |
| `inst/tmb/gllvmTMB_eva.cpp` | `680d7a576365e2265dcfa3f197a14a207f1aee56` |
| `docs/design/86-eva-gate1-parameters.json` | `12b0da289d65b47a858e5a3694b00bb3f79a7c90` |
| `tests/testthat/test-eva-gate1.R` | `7bcc75c290cc36c964e5b08764832efc96ad89c2` |

`check-sealed-sources.R` deliberately fails when a sealed path is absent.
That is the expected result on a branch such as current `main` that has not
carried the sealed prototype forward; it prevents an absence from being
mistaken for verified provenance.

## Current VA spine

The live VA spine is restricted to `R/va-r3-proto.R`,
`inst/tmb/gllvmTMB_va_r3.cpp`, and `tests/testthat/test-va-r3-prototype.R`.
The checker requires each to be tracked at `HEAD`, unmodified in the working
tree, and without an untracked replacement.

## Excluded widening

Commit `2392996be293401cc28e8c9bff9542b9f2d3bfe3` is prohibited input.  The
checker obtains its changed-path list directly from Git, requires its
`dev/va-bernoulli*` paths to remain absent, and rejects import references to
those paths or any Gate-2/Gate-2R runner/fixture naming in the sealed and VA
spine files.  It is read-only and exits nonzero for any failed assertion.
