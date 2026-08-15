# After Task: Gaussian MSPL Ψ uniqueness map (Arc U)

```text
🎯 GOAL
Solo platform: Cursor
Deliverable: decision note naming which Ψ the Gaussian FA theorem
targets in gllvmTMB coords, plus a pure-R oracle pin
HEADLINE: pick C — pinned-σ_ε exact-FA; ψ ≡ sd_B²
IN PARALLEL: merge #964/#965; refresh catch-up LOOP; Mission Control
DEFER: C++ tape, registry admission, NEWS, campaigns, SE/intervals
DISCIPLINE: verify=E5b oracle green · compute=local targeted ·
closure=stacked PR; STOP before C++
```

## Outcome

Arc U is closed as a **decision + oracle pin**, not as an admission.

Recommended pick: **C (pinned-σ_ε exact-FA)**. On the ordinary
complete Gaussian `latent(..., unique = TRUE)` cell, live Q7 already
maps `log_sigma_eps` off, so paper \(\Psi=\operatorname{diag}(sd_B^2)\).
Option A with free \(\sigma_\varepsilon\) is rejected (flat ridge /
Hao). Option B (\(\psi^{\mathrm{total}}\)) is deferred.

Also merged (Shinichi authorized): #964 LOOP closeout, #965 local
Bernoulli pair smoke note.

## Checks

```r
# OMP_NUM_THREADS=1, NOT_CRAN=true
testthat::test_file("tests/testthat/test-mspl-gaussian-heywood-oracles.R")
```

`git diff -- src/` must stay empty. No NEWS. Gaussian registry
rows remain `planned`.

## Follow-up

Next STOP gate: explicit Shinichi yes for C++ Gaussian MSPL tape
and/or `planned`→`admitted`. Optional cheap arcs still open:
B-complete (no admit changes), compare-local (≤30 min Bernoulli).
SE/intervals stay on PROTECTED `codex/lane-b-mspl-interval-feasibility`.

## Files

- `docs/dev-log/research/2026-08-15-mspl-gaussian-psi-uniqueness-map.md`
- `docs/dev-log/research/2026-08-15-mspl-phase3-gaussian-heywood-prep.md` (§5c)
- `tests/testthat/test-mspl-gaussian-heywood-oracles.R` (E5b)
- `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/{arcs,checkpoint}.md`
