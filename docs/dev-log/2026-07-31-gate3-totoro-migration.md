# Gate 3 was restarted on Totoro — the record that should have been written first

**Date:** 2026-07-31. **Authority:** Shinichi Nakagawa, in session ("can you do it on totoro so it
finishes quicker??"). **Recorded by:** Claude Code. **Status:** a methodological change to a
**running pre-registered campaign**, written up *after* the fact.

## 🔴 Why this document exists at all

It was written **after** the campaign completed and after a D-43 panel flagged its absence. The
change was made, the campaign ran to completion, and the result was reported — and at no point was
the decision recorded anywhere in the repository. The panel's compliance reviewer looked for it in
`git log`, `docs/dev-log/`, `decisions.md` and the handovers, found nothing, and returned **UNCLEAR**
on that ground alone. Two live handovers still showed *"Totoro vs local"* as an open question while
the migration had in fact already happened.

That is the defect. A pre-registered campaign's execution environment is part of its evidence, and
changing it silently means a reader of the result cannot know it changed. Recorded here as a
do-not-repeat: **write the record before the change, not after the result.**

## What was changed

Gate 3 was **killed and restarted from scratch on different hardware, mid-campaign.**

| | before | after |
|---|---|---|
| machine | maintainer's Mac (20 cores) | Totoro, `snakagaw@totoro.biology.ualberta.ca` (384 cores) |
| OS | macOS 26.5.2, `aarch64-apple-darwin23` | Linux |
| R | 4.6.0 (2026-04-24) | 4.5.3 (2026-03-11) |
| workers | 14 | 96 |
| throughput | ~160 cells/h | ~1,500–2,300 cells/h |
| progress at switch | 531 / 2,160 (25%) | restarted at 0 |

The local run began **2026-07-30 18:57** and was killed on 2026-07-31 after ~15 h. Its cell files were
**not deleted** — 579 remain at `dev/va-gate3/results/cells/` — but **none of them contributed to the
delivered result.** All 2,160 delivered cells are from Totoro.

## Why a clean restart rather than resuming the remainder

The runner skips any cell whose file already exists, so resuming on Totoro would have been trivial and
much cheaper. It was rejected deliberately.

Cells complete **cheapest-first**. Resuming would therefore have put the small cells (`p=8`, `n=100`)
on macOS/R 4.6.0 and the large cells (`p=80`, `n=400`, `q=4`) on Linux/R 4.5.3 — **confounding the
execution environment with the `p`/`n`/`q` design factors themselves**, inside a frozen design whose
pass rule turns on a 0.05 difference in relative Frobenius error. A clean restart costs 15 h of
already-spent compute and buys a single-environment result.

Sunk cost was not a reason to keep going; a confounded gate would have been worthless however it came
out.

## What was verified before the switch

Recorded because these are the checks that make "same campaign, different machine" a defensible claim
rather than an assumption:

| check | result |
|---|---|
| frozen truths `truths.rds` md5, both sides | `e7219cfec23a8dada05bb35b7b1888a8` — **identical** |
| TMB template `gllvmTMB_va_r3.cpp` md5, both sides | `7d25e6430f84195bbf65230b8dc00a47` — **identical** |
| engine's own reported `source_checksum` | `7d25e6430f84195bbf65230b8dc00a47` — matches the template |
| smoke run on Totoro before launch | all 3 arms `healthy`, 4/4 starts, every metric populated |
| `truths.rds` regenerated? | **no** — the runner loads it unconditionally when present; the file was copied, not rebuilt |
| local run killed before Totoro was proven? | **no** — Totoro was launched and confirmed producing cells first |

The truths file was copied rather than regenerated deliberately: regenerating depends on the RNG
stream, and the design freezes three pre-declared `Lambda_0`.

## What was NOT verified — the honest limits

- **Template identity is necessary, not sufficient.** Identical C++ source says the *algebra* matches.
  It says nothing about compiler, BLAS or R-version differences in floating-point behaviour. The two
  environments differ in all three, and the panel demonstrated empirically that identical source and
  identical data can produce numerically different fits across these machines.
- **No cross-machine equivalence run was done.** The clean-restart argument makes one unnecessary for
  *internal* validity (every delivered cell shares one environment), but it means there is **no
  evidence about whether the Gate 3 verdict is reproducible on the Mac**. If that matters — and for a
  release gate it plausibly does — it is unmeasured.
- **The pre-registration is silent on hardware.** It freezes truths, seeds, cells, tolerances and
  denominators. It does not say the campaign must finish where it started, so this is not a literal
  violation of a stated term. It is also not something the document anticipated, which is precisely
  why it needed recording rather than a judgment call made in flight.
- **Whether 96 workers changes anything.** Per-fit work is single-threaded
  (`OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`) on both sides, and the fit budget was unchanged at
  900 s. Timeouts did occur at `p=80, n=400` on both engines. Contention effects were not measured.

## Compute doctrine — the miss that caused this

The pre-registration recorded *"Compute: **LOCAL** (D-50)"*. That misreads D-50, which says campaigns
run on **Totoro/DRAC** and *results* stay local (never GitHub artifacts). "Results stay local" was
collapsed into "run it locally", and the campaign then consumed ~15 h of a 20-core laptop next to an
idle 384-core server.

This is `FAILURE-TAXONOMY` #11 — *compute ignored until Shinichi re-reminds* — and it is the reason
this document exists at all. **Scope the compute target when the campaign is designed, not when it is
already running.**

> Related: `docs/dev-log/2026-07-30-gate3-preregistration.md` (the frozen design) ·
> `docs/dev-log/2026-07-31-gate0-scope-extension-and-s11-departure.md` ·
> `~/shinichi-brain/AGENTS.md` §Compute · `tools/totoro-setup.md`
