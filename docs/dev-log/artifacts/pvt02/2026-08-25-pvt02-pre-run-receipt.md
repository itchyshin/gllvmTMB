# PVT-02 measured local pre-run receipt — two-target update

Date: 2026-08-25

## Current two-target remeasurement

The final packet source is
`1d4e03d926f78a244257d03c3a0669549c0eceac`. Before execution, the bounded
two-replicate smoke was estimated at 1–3 minutes, with a hard stop at 5
minutes. It completed in 28.97 s wall time and wrote
`dev/pvt02/results/2026-08-25-pvt02-two-target-smoke-receipt.rds`.

The receipt retains exactly two outer rows:

- rep 50001 / seed 800050001: healthy and eligible in 19.865 s; both trait 1
  and trait 2 profiles were finite, covered their known truths, and returned
  `interval_status="route-only"` at `n_units=400`;
- rep 50002 / seed 800050002: base-fit failure in 6.134 s, retained with no
  target payload.

The raw SHA-256 is
`fcf1c3477d6c4a8c7898c39deb22848760fb967a0d7e662d285b3b3ba9e04880`.
Using the successful two-target time, 5,000 serial replicates project to 27.6
hours before overhead. This replaces the one-target timing for compute
planning, but it remains only a two-row plumbing smoke: no coverage promotion
follows.

## Historical one-target smoke (superseded)

## Frozen smoke

- Cell: Gaussian ordinary unit tier, `latent(0 + trait | unit, d = 2,
  unique = TRUE)`, `n_units = 400`, target trait 1 only.
- Estimand: `V_t = (Lambda Lambda^T)[t,t] + psi_t^2`; two-sided 95% profile
  on `log(V_t)`.
- Seed indices: 50001 and 50002; realised seeds 152002 and 152003 under
  the now-retired PVT mapping.
- Command:

```sh
Rscript --vanilla dev/pvt02/pvt02-smoke.R \
  docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-smoke-receipt.csv
```

## Measured result

Both retained attempts converged and produced finite, ordered profile bounds
that contained the profile estimate and the known truth. Per-attempt elapsed
times were 10.996 s and 9.787 s; wall time was 21.3 s. The CSV receipt retains
both rows and their `fit_converged`, `ci_failed`, `covered`, endpoint reason,
truth, estimate, bounds, seed, and runtime fields.

This verifies trait-1 plumbing, profile inversion, and receipt retention. It
does **not** estimate coverage: both rows happened to cover and the sample is
two, not 5,000.

## Historical supersession condition — now satisfied

PVT-02 now requires target traits 1 **and** 2 in every replicate. This
trait-1-only timing is therefore invalid for estimating the two-target campaign
or authorising its compute. The current two-target remeasurement above now
satisfies the required `<=30` minute timing prerequisite. It does **not**
authorise the 5,000-replicate campaign; that remote launch remains an explicit
approval gate. The fresh packet also replaces the old realised-seed formula, whose
`152002:157001` range overlaps historical programme bands: it reserves
`800050001:800055000` via `800000000 + rep_index` while retaining replicate
indices `50001:55000`.

## Timed full-run projection and stop

At the observed local median of 10.391 s per replicate, 5,000 serial
replicates would take approximately 14.4 hours before any retry/overhead.
The retained 20,000-replicate `n = 150` certificate took about 2 h 50 min on
90 Totoro cores, so even an optimistic proportional 5,000-replicate campaign
is over 30 minutes; this new `n = 400` cell can only be slower than that
baseline without further evidence.

**STOP:** `n_sim = 5000` was not launched locally, on Totoro, on DRAC, or in
GitHub Actions. The next action requires explicit approval for a Totoro
campaign under the exact resource and output envelope in the combined pre-run
receipt. The campaign must retain every requested attempt, with CI endpoint
failures counted as misses among eligible fits and base-health failures retained
in the all-attempt and availability ledgers.
