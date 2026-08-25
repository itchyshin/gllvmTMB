# PVT-02 measured local pre-run receipt — superseded for two-target timing

Date: 2026-08-25

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

## Supersession for the two-target packet

PVT-02 now requires target traits 1 **and** 2 in every replicate. This
trait-1-only timing is therefore invalid for estimating the two-target campaign
or authorising its compute. Before any 5,000-replicate launch, run a fresh,
timed pre-run that retains both target rows and is explicitly estimated at
**30 minutes or less**. Until that receipt exists, the campaign remains
unavailable; no promotion or compute authorisation follows from this document.
The fresh packet also replaces the old realised-seed formula, whose
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
campaign after choosing its bounded core count, output directory, and
retention/checksum receipt. The campaign must retain every requested attempt,
with CI endpoint failures counted as misses in the converged denominator and
reported separately in the all-attempt ledger.
