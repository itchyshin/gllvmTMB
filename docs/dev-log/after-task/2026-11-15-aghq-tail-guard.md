# q2 golden-oracle tail guard

The fixed q2 integration window had a small absolute prior-tail bound, but that bound was not necessarily small relative to a rare likelihood. A valid Bernoulli example returned a value below an independently derived lower bound. This test-helper change rejects results when the omitted-tail upper bound is too large compared with the computed in-window likelihood. It also requires plain binary response values before applying the Bernoulli bound.

The focused tests and their limits are recorded in `docs/dev-log/check-log.d/2026-11-15-aghq-tail-guard.md`. The existing AGHQ suite and package checks remain pending. Independent review checked the bound and identified the response-encoding cases added to the test. The test oracle still has no certified in-window quadrature error bound and does not compute the extreme example's full likelihood.
