# Handover to Cursor — gllvmTMB VA lane, 2026-08-04

**Author:** Claude Code (solo) → **Target:** Cursor · fresh agent, no chat inherited
**Branch:** `claude/va-lane2` @ `2b1fc759` · **PUSHED** · `origin/main` untouched at `5bf18ab3`
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` (78 commits off main)

> The committed repo is the authoritative state. This file supersedes the chat.
> Deep detail lives in `docs/dev-log/handover/2026-08-04-claude-handover-arcs-fade-done.md`
> (read its `FINAL UPDATE` section first — earlier sections are superseded).

## FIRST: rehydrate and classify

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git log --oneline -10
```

Then classify every item below as **OWED / DONE / RETRACTED / PROTECTED** against actual git state
before acting. Do not trust this document over the repository.

## Landing State

| Artifact | State |
|---|---|
| `claude/va-lane2` @ `2b1fc759` | ✅ **LANDED** — pushed; remote verified via `git ls-remote` |
| `origin/main` | **PROTECTED** — `5bf18ab3`, untouched all session. Do not merge; PR is the maintainer's act |
| Full suite | ✅ 371 files, **9,286 passed, 0 failed** |
| `dev/va-speed/inventory-analysis.txt` | **CARRIED-OVER, untracked scratch.** A sub-agent's working notes, superseded by `61-sd-report-consumer-inventory.md` which IS landed. Deliberately not committed. Delete or ignore; nothing depends on it |
| Dropbox checkout `/Users/z3437171/Dropbox/Github Local/gllvmTMB` | **PROTECTED (D-112)** — different branch, 76 files apart. **Never build or edit there** |

## What this session established

**Speed does not improve on the same work.** `se = FALSE` saves **1.66–1.70×** (measured, flat in N)
but that is work *not performed* — `standard_errors()` moves the cost to point of use. The only
like-for-like speedup is `nlminb(scale=10)` at **1.11–1.13×**, and it is **not wired in**.

**🔴 The gllvm gap is VARIANCE, not a constant factor.** 8 seeds, same DGP:
gllvm min/med/max 0.086 / 0.093 / 0.294 s (spread 3.4×); ours 0.692 / 0.753 / **25.508** s
(spread **36.9×**). Seven seeds sit in a tight band; **one costs 35× our own median and reports
`status = "healthy"`.** Typical gap is **8×**, not 25×. Seed 1 is harder for both engines but gllvm
degrades 3.2× where we degrade 34× — the ill-conditioning signature.
Detail: `dev/va-speed/72-THE-GAP-IS-VARIANCE.md`.

**Arc E settled ledger claim 30 against us.** Our GH tier beats gllvm-VA on accuracy 11/12 paired
seeds (a real, properly-powered win). But **AC — the tier this arc was built on — is 6/12, a coin
flip**, and pins ψ at 0.0002 against a planted 0.6.

**Arc C killed the cheap ordinal route.** AC's ψ-collapse is a dose-response in information per
observation; an ordinal response is a single categorical draw, where AC recovers **0.0 %**. Shipping
AC-fenced would pin ψ at zero while reporting success. Build option **(b)**: family code 5 **plus**
an ordinal GH tier.

**Four claims went out and came back** — a compute estimate built on `failed_health_gate` fits, a
test that could not fail, a published closure claim refuted by an adversarial reviewer, and a
sub-agent sweep run against the wrong branch. **Check `dev/va-speed/20-CLAIMS-LEDGER.md` status
before citing any number.**

## Next Immediate Steps (OWED, in order)

1. **Measure the gllvm gap at LARGE N.** We have only measured where we are weakest — N=120 sits far
   below the VA-vs-Laplace crossover (~N≈2500), and our VA's case was always large-N. Cheap, and it
   could dissolve the problem before anyone invests in fixing it.
2. **Attack the variance, not the median.** Instrument outer-iteration counts and re-run **seed 1**
   against the other seven. ~35× iterations at similar per-iteration cost ⇒ conditioning confirmed
   ⇒ try pinning the loadings diagonal with a separate scale (the gap claim 30 names).
   **Head start:** our iteration count already exists (`R/va-r3-proto.R:1408`, `:1413`) — locating it
   is a grep. **gllvm exposes none** — that side needs a `trace` capture or an optimiser wrapper.
   Reproducer in hand: `dev/va-speed/71-split25.R`, N=120 T=10 q=1 binomial-probit, `n_trials`=6, seed 1.
3. **Treat the 8× median as unexplained, not a target.** The full cheap-lever sweep yielded 1.1×;
   five other levers are closed. 8× is not knob territory.
4. **Arc B (sandwich scoring)** — unblocked; spec fixed to family-conditional. **Open with a timed
   pilot on health-gate-passing fits**, not the retracted estimate.

## Live environment (Cursor: do not assume Claude's setup)

```sh
cd /private/tmp/gllvmtmb-va-lane2
export NOT_CRAN=true
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="standard-errors")'   # safe verify
ssh -o BatchMode=yes totoro    # 384 cores; lane ~/gllvm_work/va-lane2; budget <=150 cores
#  OPENBLAS_NUM_THREADS=1 per worker
#  ⚠ Rscript --vanilla implies --no-environ -> pass R_LIBS_USER=$HOME/R/lib or library(gllvm) fails
```

⚠ **Never stage:** the Dropbox checkout's `.claude/`, `.uinit/`, campaign `.rds`/`.csv` (D-50),
`dev/va-speed/inventory-analysis.txt`.
⚠ **Do not edit `R/` or `tests/` while a full suite runs** — that produced two artefact failures.
⚠ **Before any push:** `git rev-parse --abbrev-ref claude/va-lane2@{upstream}`; push with an
explicit refspec. 16 branches in this repo were live push traps; `tools/check-push-traps.sh` guards it.

## Open, needing the maintainer

**Whether this lane is the priority at all.** D-113 names **missing-data #332** the primary post-0.6
slice; none of these arcs is one of the six 0.7 capability tracks. Shinichi, asked whether this lane
precedes #332: *"not necessarily."*
Also open: Arc C as a build (now correctly sized to option b) · three unplumbed levers
(`multiphase`, `optimHess` polish, `sdreport` knobs) · seven per-repo `AGENTS.md` core-count refreshes
(the vault says 150; `route.py` has no write mode).

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-04-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
