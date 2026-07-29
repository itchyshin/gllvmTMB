# Run record — 20k confirmatory campaign, Gaussian `Sigma_unit` diagonal profile

Companion to `2026-07-29-certificate-gate-preregistration.md`. That document is **immutable after
launch**, so the as-run parameters are recorded here instead of edited into it.

Launched 2026-07-29 from lane `claude/evidence-gap-20260729`, harness commit `90798365`.

## Invocation

```
CORES=90 NSIM=20000 NBOOT=10 FAMILY=gaussian NUNITS=150 \
  OUTDIR=/home/snakagaw/gllvm_work/profile_rescore/run20k-20260729 \
  bash dev/totoro-profile-rescore.sh grid
```

| parameter | value | note |
|---|---|---|
| reps | 20,000 per cell | as pre-registered |
| cells | gaussian d1-n150, d2-n150 | `--family`/`--n-units` filters; without them ~75% of the compute goes to cells nothing is waiting on |
| cores | 90 | Totoro is shared; the standing limit is ≤100 |
| shards | 90 rep-windows | each shard writes per cell on completion |
| `n_boot` | **10 (harness default is 100)** | see below |
| output | `run20k-20260729/` | fresh directory so the raw is unambiguous and retainable |

## Why `n_boot = 10`, and why it cannot touch the gate

Measured on Totoro before launch: the same 2 reps × 2 cells took **62 s** at `n_boot = 10`
(d1 21 s, d2 41 s) and **exceeded 120 s** at `n_boot = 100` without finishing. Bootstrap dominates
the per-rep cost.

Bootstrap is **not** the certificate route. The 2026-07-18 reconciliation established it is the
*wrong* route for `Sigma_unit_diag`; it is co-computed only as an in-run baseline. It is emitted as
**separate `ci_method` rows** (`profile`, `bootstrap`, `profile_total`, `wald_t_logsd` — confirmed
in the smoke output), computed independently per rep, so lowering `n_boot` cannot alter a single
`profile_total` value. The gate is on `profile_total`.

Paying a multi-fold wall-clock increase for a baseline already known to be the wrong route would
have been poor use of a shared machine. Recorded here so the D-43 panel sees the choice rather than
discovering it.

## Smoke evidence (pre-launch, as required)

`FAMILY=gaussian NUNITS=150 dev/totoro-profile-rescore.sh smoke`, `n_sim=2`:

- Filter worked — **2 cells, not 8**.
- Output **non-empty**: 40 rows × 60 cols per cell.
- `ci_method` values present: `profile`, `bootstrap`, `profile_total`, `wald_t_logsd`.
- Inspected past the guards on `Sigma_unit_diag` × `profile_total` (10 rows):
  `truth` finite and in range (2.1704, 3.1661, 1.5414, 3.4972), and `covered`, `converged`,
  `ci_available` all populated with **zero NAs**.

Non-empty alone would not have been sufficient — guard-blocked operations in this harness return
all-NA silently, which is why the check reads the values rather than the row count.

## Expected wall-clock

From smoke timings, ≈31 s per rep across both cells ⇒ ≈172 CPU-hours ⇒ **≈2 hours on 90 cores**.
First shard files expected ~40 min in (each shard completes its full window before writing).

## Data handling

Raw stays **LOCAL on Totoro** (D-50) at `run20k-20260729/`. **Retain it.** The entire reason this
campaign exists is that the previous raw set was lost, leaving a 3-0 CERTIFY panel that could no
longer be reproduced.
