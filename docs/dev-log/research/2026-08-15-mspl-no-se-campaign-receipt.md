# D-139 receipt — no LA-MSPL SE campaign is issued

**Date:** 2026-08-15
**Roles:** Gauss / Rose (item 3)
**Lane:** `cursor-mspl-se-feasibility-pin` (GOAL CLOSED)
**Status:** **NONE ISSUED.** Host = none. Minutes = 0. Totoro not
started. DRAC not started. GitHub Actions not used as a campaign
host.

**2026-08-15 amendment (B1 host fence lifted; SE unchanged):**
the SE campaign remains **NONE ISSUED**. Public `se=TRUE` still
withholds `sd_report`. Do **not** read the B1 Totoro proposal as
SE covered. B1 interval-calibration receipt (proposed
`host=Totoro`, **not launched** in that sitting):
`docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md`.

**Scanner:** NO Totoro/DRAC SE campaign. `host=none`. `minutes=0`.
Bernoulli \(Q_0\) non-PD (min eigenvalue **−0.774**) on the **#979
first cell**. Public `se=TRUE` still withholds `sd_report`. Pin ≠
calibrated SE. No remote SE job started. No `src/` edit. B1 is a
different campaign; see the B1 receipt.

**Reader:** the next conductor who might treat #979 as permission
to occupy Totoro or DRAC. It is not.

This file **is** the D-139 receipt. The empty table in
`docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md` §5
was the policy placeholder. Filling that table after a job has
started is not a receipt. Issuing this note instead of a host,
estimate, and approval **is** the receipt: no campaign runs.

---

## Verdict

No Totoro job, no DRAC array, and no GitHub Actions campaign is
authorised from the #979 pin. The local availability pin is
closed. A calibrated SE campaign is not.

---

## Why no campaign (Gauss)

Three independent stops. Any one would be enough.

1. **Bernoulli \(Q_0\) is already non-PD on the first cell.**
   #979 formed both numerical Hessians on one tiny ordinary
   \(q=1\) fixture each. Bernoulli-logit \(Q_P\) was available
   (min eigenvalue 0.226). Bernoulli-logit \(Q_0\) was
   **non-PD** (min eigenvalue **−0.774**) and was retained
   unrepaired. Poisson-log both tapes were available
   (\(Q_P\) 3.300; \(Q_0\) 2.473). A campaign that pretends
   "the SE exists" on the binary surface is measuring a matrix
   the pin already typed `non_pd`. That is the binary-lane
   lesson landing on this fixture, not a missing seed count.

2. **A pin is not a calibrated SE.** The GOAL measured
   *formation* and positive-definiteness. It did not measure
   coverage, width, or nominal 95%. Public
   `gllvmTMBcontrol(se = TRUE)` still leaves `sd_report` NULL
   (`R/fit-multi.R` withholding branch untouched). Poisson
   stays `planned`. Neither Hessian is `TMB::sdreport()`.
   Occupying Totoro to "get SEs" would convert an availability
   diagnostic into a false inference claim.

3. **The GOAL deferred the Gaussian SE campaign.** Lane
   `LOOP/GOAL.md` and `LOOP/ultra-plan.md` name
   `gaussian SE campaign` and `Totoro>30min` as HARD STOPs.
   The research ultra-plan defers `Totoro/DRAC campaign`.
   Standing 2026-08-07 Totoro permission does not repeal those
   stops.

Poisson having two usable Hessians on one cell does not lift
any of the three. It is a typed local status, not a grid
design.

---

## Receipt table (issued as empty on purpose)

| Field | Value |
|---|---|
| Status | **NONE ISSUED** |
| Host | **none** |
| Estimate (min) | **0** |
| Pre-run test + result | local #979 pin only; not a pre-run for a remote job |
| Why local pin is insufficient | it is sufficient *as a pin*; it is not a campaign design |
| Shinichi approval (quote + time) | none — no job was proposed |
| Core / array request | none |
| What happens if it overruns | not applicable; nothing started |
| Totoro started? | **no** |
| DRAC started? | **no** |
| Actions campaign? | **no** |

---

## D-50 — campaigns never on GitHub Actions

Vault `memory/DECISIONS.md` § D-50 (2026-07-12, accepted).
Simulation / recovery / power / coverage campaigns run on
**Totoro or DRAC, never GitHub Actions**, and their outputs are
never Actions artifacts. GitHub Actions here is package checks
and docs only.

A later Gaussian SE / coverage / width grid, if one is ever
G0'd, still answers "Totoro or DRAC?" — never Actions. D-50
does **not** require occupying Totoro tonight. It forbids
parking the deferred campaign on Actions. This receipt records
that the campaign was not parked anywhere.

---

## D-139 — cannot estimate → do not run

Vault `memory/DECISIONS.md` § D-139 (2026-08-10, accepted).
Every run needs a stated time guesstimate before start. Over
30 minutes needs a simulation plan, a pre-run with results
shown, and Shinichi's approval. **If you cannot estimate, that
is the finding** — say so; do not guess a remote wall-clock
and launch.

We cannot estimate a calibrated SE campaign from this pin.
The Bernoulli \(Q_0\) cell is already non-PD. The public door
still withholds `sd_report`. There is no frozen estimand,
no seed list, no coverage gate, and no written wall-clock
for a remote job. Under D-139 that absence **is** the finding,
so the remote job is not started. Minutes = 0 is not a
guesstimate for a job; it is the recorded duration of the job
that was not issued.

A ≤30 min Totoro canary is also not issued. The local pin is
already GREEN as a pin. There is no named residual that the
laptop cannot finish. "More seeds would be nice" is a
campaign, and the GOAL deferred it.

---

## What this receipt does not authorise

- A Totoro or DRAC SE, coverage, width, or nominal-95% job.
- `planned` → `admitted` for Poisson or anyone else.
- NEWS "covered".
- Public `vcov()` / `confint()` / `sdreport()` on MSPL.
- Editing `src/`.
- Repairing the non-PD Bernoulli \(Q_0\).
- Treating #979 as calibrated inference.

Next G0 (not this sitting): a multi-seed availability grid, a
Poisson admit decision, or a *written* SE campaign receipt
with host, estimate, pre-run, and approval. Until that G0,
host remains none.

## Sources

- Pin: https://github.com/itchyshin/gllvmTMB/pull/979 @ `10d6a209`
- Morning brief: `docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md`
- Compute policy: `docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md`
- D-50 / D-139: `shinichi-brain/memory/decisions`
