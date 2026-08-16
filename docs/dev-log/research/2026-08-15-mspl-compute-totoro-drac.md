# MSPL compute — use Totoro and DRAC wisely

**Date:** 2026-08-15
**Lane:** `cursor-mspl-se-feasibility-pin`
**Retrieval:** `/ask-brain` rung 1 (`shinichi-brain` MCP `search_notes` /
`build_context` / `read_note`, `search_all_projects: true`) plus rung 3
grep of `memory/DECISIONS.md` and hub `AGENTS.md`.
**Status:** policy extract. No `src/`. No campaign launched. No commit
in this slice.

**Reader:** overnight conductor who must decide *local pin vs Totoro vs
DRAC* for the Bernoulli + Poisson `se = TRUE` feasibility pin.

Shinichi's instruction was *"use DRAC and totoro wisely"*, not *"launch
Totoro tonight."* Wisely means apply the routing table. Tonight's job
is the **local** cell of that table.

---

## 8-line policy (conductor)

1. **D-50.** Recovery / power / coverage / simulation campaigns run on
   Totoro or DRAC, **never GitHub Actions**, and their outputs are
   **never Actions artifacts** ([[DECISIONS#D-50|D-50]]; hub
   `AGENTS.md` § Compute; repo `AGENTS.md`).
2. **Host table.** Local = toy smoke / fixture / this pin. Totoro =
   no-queue CPU, **≤150 cores**, want it *now*. DRAC = frozen
   multi-seed arrays, GPU, or **>150 cores**
   ([[COMPUTE-PLAYBOOK]]; [[totoro-setup]]; [[drac-setup]]).
3. **Smoke first.** Benchmark at toy scale locally; Totoro is a
   single-cell canary *after* local tests are green; DRAC is
   claim-evidence only after the design is frozen
   ([[COMPUTE-PLAYBOOK]]; 2026-07-04 sigma-profile canary rule;
   2026-07-05 handover).
4. **Tonight = local pin.** `OMP_NUM_THREADS=1`. Availability + PD
   only. Not a campaign. Profile / bootstrap / Gaussian SE / DRAC
   arrays are out of the 30-minute local budget (lane `GOAL.md`;
   `LOOP/ultra-plan.md`; research ultra-plan §1).
5. **Totoro is wise only after** the local pin is GREEN *and* a
   written estimate is **≤30 min** *and* the job is a diagnostic
   canary, not a coverage grid. Standing 2026-08-07 Totoro permission
   does **not** repeal D-139 or this GOAL's HARD STOP.
6. **Hard cap.** No Totoro (or DRAC) job **>30 min** without a filled
   receipt in **§ Receipt** below ([[DECISIONS#D-139|D-139]]: plan +
   pre-run results + Shinichi approval). **SE campaign: NONE
   ISSUED.** **B1 interval calibration: proposed host=Totoro,
   not launched** —
   `docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md`.
7. **If you cannot estimate, that is the finding** — run a smaller
   local pre-run; do not guess a remote wall-clock and launch
   (D-139). A run that overruns its estimate **stops and re-reports**.
8. **Hygiene if a Totoro job ever starts:** `OPENBLAS_NUM_THREADS=1`,
   cap ≤150 (D-143 binds), leave processes clean (D-142), never a
   DRAC login-node fit, never a fresh Duo login (D-64).

---

## 1. D-50 — campaigns never on GitHub Actions

**Vault:** `memory/DECISIONS.md` § D-50 (2026-07-12, accepted).

GitHub Actions storage hit 90% of a 2 GB/month cap because
**gllvmTMB (9,534 artifacts)** and **drmTMB (4,632)** had been
running simulation / recovery / power / coverage campaigns *on
Actions* and retaining the outputs.

**Decision (Shinichi, 2026-07-12), standing rule to every lane:**

1. Sims / recovery / power / coverage campaigns → **Totoro or DRAC,
   NEVER GitHub Actions.** Do not add a workflow that runs a campaign
   or uploads campaign artifacts.
2. GitHub Actions = **package checks + docs ONLY**, short
   `retention-days`.
3. Before a heavy run, ask **"Totoro or DRAC?"** — the answer is not
   GitHub Actions.

Hub `AGENTS.md` restates the same: work locally, then route serious
simulations to Totoro or DRAC; campaigns and their artifacts never
use Actions. Repo `AGENTS.md` / `CLAUDE.md` encode D-50 the same way
(Totoro or DRAC, never Actions, never campaign artifacts).

**This GOAL is not a D-50 campaign.** An 8-cell local `se = TRUE`
availability pin is a smoke. D-50 forbids parking a later Gaussian
SE / coverage grid on Actions. It does **not** require occupying
Totoro tonight.

---

## 2. When Totoro vs DRAC vs local

Canonical routing: `projects/COMPUTE-PLAYBOOK.md` (built 2026-07-19;
the decision layer above the two runbooks). Hub `AGENTS.md` §
Compute is the short form.

| The job | Machine | Why (playbook) |
|---|---|---|
| Build / validate small fixtures; toy-scale smoke; a couple of n-ladder rungs that fit on a laptop | **local** | fast iteration, no round-trip |
| Quick full-fit iteration; a CPU campaign **≤150 cores**; you want it **now** with no queue | **Totoro** | 384 cores, ~1 TB, no queue, passwordless |
| Large **replicated multi-seed** campaign (coverage / recovery / power / type-I); one seed per task | **DRAC** SLURM **job array** | queue-managed provenance, scales past one box |
| **GPU** | **DRAC** (name the GPU) | Totoro has no GPU |
| **>150 cores**, multi-node, or a queued / reproducible record | **DRAC** | Totoro is shared — keep it ≤150 cores |

Rule of thumb ([[COMPUTE-PLAYBOOK]]): **Totoro = fast & now
(interactive, ≤150-core CPU); DRAC = big & reproducible (job
arrays, GPU, provenance).** When unsure and it is CPU-only and
quick, default Totoro.

**gllvmTMB row in the playbook:** Totoro for CPU coverage grids the
package already runs; DRAC for GPU parity and larger replicated
campaigns. drmTMB sibling row is the smoke-first pattern: Totoro for
a fast n-ladder or a **single-cell smoke before committing the
grid**; DRAC arrays for frozen claim evidence.

**Totoro facts** ([[totoro-setup]]): personal UAlberta lab box; no
SLURM; no Duo; shared; **150-core ceiling binds**
([[DECISIONS#D-143|D-143]] — override is an explicit per-run yes,
not an env var); pin `OPENBLAS_NUM_THREADS=1`; leave processes
clean ([[DECISIONS#D-142|D-142]]).

**DRAC facts** ([[drac-setup]]): never compute on a login node
(`sbatch` / `salloc`); `/scratch` purged ~60 d; reuse live
ControlMaster sockets, never trigger Duo
([[DECISIONS#D-64|D-64]]). Highest-leverage use is one seed per
`$SLURM_ARRAY_TASK_ID`.

**Standing Totoro permission (2026-08-07, playbook):** agents may
use Totoro to speed up sims without a per-job "Totoro go"; prefer
Totoro for heavy VA/binary D-50 campaigns; keep **local ≤10 cores**
for small smokes; do not stop local work when Totoro is also
running. This permission **does not** waive D-139, D-143, or a
GOAL that names `compute=local`.

---

## 3. Smoke-first before any remote run

The playbook's own sentence: *"benchmark at toy scale locally, then
run the real campaign on the server. Never present a laptop-scale N
as the evidence when the machine exists."* The first half is the
gate; the second half is why a later campaign belongs on Totoro or
DRAC.

Earned project pattern (brain hits, not this lane's invention):

- **2026-07-04 sigma-profile bootstrap controls:** "Use Totoro only
  for diagnostic canaries after focused local tests are green; use
  DRAC only for frozen-design claim evidence."
- **2026-07-05 Claude handover:** "Avoid broad Totoro/DRAC compute
  while local focused tests and denominator designs are still being
  refined. Totoro/DRAC are for gated calibration or multi-seed
  evidence after the route design is [fixed]."
- **2026-06-23 midterm compute scout:** Totoro first for package
  install/load, manifest parse, and tiny smoke fits. Stop before
  broad DRAC/Totoro simulations if pilot labels, MCSE, and
  denominators are not fixed.
- **Count-slope local micro-shards (2026-06-26):** kept local;
  Totoro/DRAC unused; shard pack still needed explicit human review
  before submission.
- **D-139 pre-run test:** required before any **>30 min** full run
  because a long smoking test can return the *wrong* answer;
  re-running only reproduces an artefact at higher precision.

Smoke-first for *this* pin: local `se = TRUE` fits that form
\(Q_P\) and evaluate \(Q_0\), typed
`available` / `non_pd` / `nonfinite` / `error`, every attempt in
the denominator. That *is* the smoke. A Totoro job that repeats the
same pin at more seeds is a campaign, and this GOAL defers it.

---

## 4. What THIS GOAL should do tonight

Lane
`docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/GOAL.md`:

- **DISCIPLINE:** `compute=local OMP=1`
- **DEFER:** `Totoro>30min` · gaussian SE campaign · EVA/VA/AGHQ-MSPL
- **Invariant:** "Local only; `OMP_NUM_THREADS=1`. Totoro >30 min
  is HARD STOP."
- **Finish line:** teacher + availability pin + still `planned`.
  Not calibrated inference. Not admission.

Lane `LOOP/ultra-plan.md`: profile and bootstrap are **out of the
30-minute local budget**. HARD STOPS include `Totoro >30 min` and
`gaussian SE campaign`.

Research ultra-plan
`docs/dev-log/research/2026-08-15-mspl-next-se-ultra-plan.md` §1:
`compute=local, OMP_NUM_THREADS=1, nothing over 30 min` and
**DEFER `Totoro/DRAC campaign`**.

**Tonight's correct host is the laptop.** Form the two private
Hessians on Bernoulli-logit and Poisson. Record typed status.
Leave `sdreport()` withheld. Do not occupy Totoro or DRAC.

**A Totoro job becomes wise only if all of these are true:**

1. Local pin is GREEN (construction forms; public door still
   withholds).
2. A named residual needs a **≤30 min** diagnostic canary that the
   laptop cannot finish (TMB compile contention, not "more seeds
   would be nice").
3. A time guesstimate is written *before* SSH.
4. The job is still a canary, not a coverage / width / nominal-95%
   grid (those remain deferred; they would be DRAC arrays after a
   frozen design + G0).

**DRAC is not wise tonight.** There is no frozen multi-seed
estimand, no SLURM array, no GPU, and no claim-evidence gate. Using
DRAC "because Shinichi said use it wisely" is the opposite of the
playbook.

---

## 5. Hard cap — no >30 min Totoro without a receipt here

**Vault:** [[DECISIONS#D-139|D-139]] (2026-08-10, accepted).
Shinichi: *"30 minutes for a quick check, plan approval for
anything longer."*

| Expected duration | What is required |
|---|---|
| **any** length | A stated time guesstimate, before starting. Estimate from DRAC/Totoro experience. |
| **≤ 30 min** | Just run it. A quick feasibility check must be *succinct*. |
| **> 30 min** | Simulation plan + pre-run test with results shown + Shinichi's approval before the full run. |

If you cannot estimate, that itself is the finding — say so and run
the pre-run test. A run that overruns its estimate **stops and
re-reports**.

Hub `AGENTS.md` and `AGENTS.md` § Compute: before any run >30 min,
D-139 applies. This GOAL tightens the same line into a **HARD
STOP** on Totoro >30 min.

**Lane rule for the overnight conductor:** a Totoro or DRAC job
whose estimate is **>30 min** is forbidden unless the receipt
below is filled. An empty receipt means **do not launch**.

### Receipt — Totoro / DRAC >30 min

**SE campaign: NONE ISSUED (2026-08-15).** See
`docs/dev-log/research/2026-08-15-mspl-no-se-campaign-receipt.md`.

**B1 interval calibration: PROPOSED host=Totoro, not launched
(2026-08-15).** Full table:
`docs/dev-log/research/2026-08-15-mspl-b1-totoro-receipt.md`.
Launcher (dry-run default): `dev/mspl-b1-totoro-launch.sh`.

| Field | Value |
|---|---|
| Host | **Totoro** (B1 only; SE remains none) |
| Estimate (min) | **~1,160–1,260** full B1 @ 140–150 cores (B0 0.4 s/fit-eq × 26 M ⇒ ≈2,900 core-h). Extrapolated, not a B1-measured shard. |
| Pre-run test + result | B0 Totoro 7,200/7,200 ok, 32 s wall @ 140-way (#981) |
| Why local pin is insufficient | B1 is the signed 132 × 600 grid, not the #979 Hessian pin |
| Shinichi approval (quote + time) | B1 authorized 2026-08-15 (*"Approve"*, *"Gate is open"*); Totoro host fence lifted this sitting |
| Core / array request | 140 workers, cap 150 (D-143) |
| What happens if it overruns | stop and re-report |
| Totoro started? | **no** |
| SE covered? | **no** |

Filling this table after a job has started is not a receipt.

---

## Sources (rung 1 + rung 3)

| Note | Permalink / path | Used for |
|---|---|---|
| D-50 | `shinichi-brain/memory/decisions` § D-50 | campaigns never on Actions |
| D-64 | same, § D-64 | reuse sockets; no Duo nag |
| D-139 | same, § D-139 | 30-minute line |
| D-142 | same, § D-142 | Totoro process hygiene |
| D-143 | same, § D-143 | 150-core cap binds |
| COMPUTE-PLAYBOOK | `shinichi-brain/projects/compute-playbook` | local / Totoro / DRAC table; smoke-then-campaign; 2026-08-07 standing Totoro permission |
| totoro-setup | `shinichi-brain/tools/totoro-setup` | no queue; ≤150; when vs DRAC |
| drac-setup | `shinichi-brain/tools/drac-setup` | login-node ban; job arrays |
| hub AGENTS.md | `~/shinichi-brain/AGENTS.md` § Compute + estimate-before-run | short standing rules |
| 2026-07-04 sigma-profile | brain after-task hit | Totoro = canary after local green; DRAC = frozen claim |
| 2026-07-05 handover | brain hit | no broad remote while local design is still moving |
| Lane GOAL / ultra-plan | this repo | tonight = local OMP=1; Totoro>30min HARD STOP |

No MSPL-specific Totoro campaign note exists in the brain. The
MSPL hits were this lane's own GOAL and unrelated fleet/q-series
after-tasks. That absence is why this file exists.

---

## What this note does not authorise

- Starting B1 from a sitting that only wrote the receipt.
- Gaussian SE, coverage, width, or nominal 95% as a *covered* claim.
- `planned` → `admitted`.
- Public `vcov()` / `confint()` / `sdreport()` on MSPL.
- Occupying Totoro "because standing permission exists" for the
  SE pin. B1 has its own receipt; that receipt still does not
  start the job by itself.
