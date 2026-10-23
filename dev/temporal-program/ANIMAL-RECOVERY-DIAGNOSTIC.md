# Animal recovery optimizer diagnostic

## Question

The retained 160-series animal recovery fixture has eight terminally
successful two-pass BFGS fits whose maximum outer gradient exceeds `1e-3`.
This diagnostic asks whether a third identical BFGS pass repairs that failure.
It does not alter the frozen two-pass campaign or its thresholds.

## Design

The exact eight failed `(phi, seed)` cells were regenerated from the direct
animal DGP. Each used the same package source, starts, BFGS controls, and
two-pass setup as the retained runner, except that `optimizer_passes` was set
to three. Results are retained in
`results/animal-third-pass-diagnostic-20260909.csv`.

## Result

Two of eight cells cross the gradient gate after the third pass:

| Cell | Two-pass gradient | Third-pass gradient |
| --- | ---: | ---: |
| `phi=-.4`, seed 2609201 | 0.002523 | 0.000620 |
| `phi=.6`, seed 2609202 | 0.002108 | 0.000281 |

The other six remain above `1e-3`, with changes at numerical-noise scale.
Therefore a generic third optimizer pass does not repair the retained
campaign. The two-pass result remains the governing evidence and the animal
cell remains partial.

## Consequence

Any follow-up must be a separately named predeclared fixture or a model-level
numerical change with its own independent tests. It must retain the original
30 attempts and cannot relabel the two repaired diagnostic cells as campaign
successes.
