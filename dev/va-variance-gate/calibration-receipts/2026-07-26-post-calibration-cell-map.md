# Post-calibration finite-fixture cell map

This frozen map preserves the retained local calibration receipt supplied for
the VA-R3 variance-domain runner.  It replaces the invalid nominal 4/6/10/20
grid: those numbers are observed-band labels, not the fixture's
`nominal_prior_target`.

| observed band | nominal_prior_target | seed | expected observed max projected variance |
| --- | ---: | ---: | ---: |
| 4 | 12 | 2026074012 | 4.614 |
| 6 | 50 | 2026074050 | 5.988 |
| 10 | 55 | 2026074055 | 8.674 |
| 20 | 45 | 2026074045 | 22.191 |

The predeclared acceptance bands are respectively [3, 6], [5, 7], [8, 12],
and [18, 24].  These are calibrated finite-fixture cells used to make the
campaign labels honest.  They are not an estimator guarantee and do not
justify adaptive retuning.
