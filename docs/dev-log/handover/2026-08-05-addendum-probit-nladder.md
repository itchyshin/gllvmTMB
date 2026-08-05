# Addendum to the 2026-08-05 handover — probit n-ladder finished

**From:** the authoring session (now closing) → **To:** the live `claude/va-lane2` lane
**Status:** mostly CONFIRMS the handover. Three deltas, one of which is a correction you
should apply before citing a committed CSV.

Read `2026-08-05-claude-handover.md` first; this only updates it.

## 1. The campaign that was "STILL RUNNING at handover" has finished

`dev/va-usability/100-probit-stage8.R` completed at 15:15 (n=1000 took 9112 s).
All three cells + `100-probit-stage8-summary.csv` written.

| arm | n=150 | n=400 | n=1000 | verdict |
|---|---|---|---|---|
| `va_gh` | 1.135 | 1.065 | **1.025** | **CONVERGES** |
| `va_ac` | 0.508 | 0.512 | **0.508** | **PLATEAUS ≈ 0.51 — asymptotically biased** |
| `la` | 11.12 | 1.669 | 1.566 | unstable, not converging |
| `gllvm` *(as printed)* | 0.508 | 0.512 | 0.508 | ⚠ **MIS-SCORED — see §2** |

**This CONFIRMS the handover's lead.** AC is flat to three decimals across a 6.7× range in n —
a plim, not finite-sample noise, exactly as `jj` plateaus at 0.535 on logit. Only GH converges
(deviation 0.135 → 0.065 → 0.025). Nothing in the handover's guidance changes.

Also confirmed, now across the full ladder: **latent-r is flat at ~0.86–0.88 for every arm at
every n**, including the biased ones. More units do not improve per-unit scores — the
incidental-parameter point, measured rather than argued.

Cost note: GH/AC is 31× at n=150 but narrows to **9×** at n=1000 (2610 s vs 290 s).

## 2. 🔴 DELTA — the `gllvm` rows in that committed CSV are WRONG. Do not cite them.

`100-probit-stage8.R` was written **before** the scale-convention crux and still folds
`sigma.lv` into gllvm's loadings (`sweep(theta, 2, sigma.lv, "*")`). On probit
`sigma.lv ≈ 0.710`, so it shrinks the trace by ≈ 0.504 and manufactures the 0.508 that
coincidentally matches our AC.

**Corrected, gllvm is UNBIASED at every n (≈ 1.01–1.02).** The directly-measured value from
`130-crux.log` (raw `theta`, correct convention) is **trace 1.071, eta_var 0.892**.

⚠ The ≈1.01 figures are an **arithmetic reconstruction**, not a measurement — the script did
not retain `sigma.lv` per cell, so the n=150 value is applied to all three. Treat 1.071 (crux,
measured) as the citable number and the ladder's gllvm row as unusable.

**Fix is one line:** drop the `sweep()` in `100-probit-stage8.R` and re-run (or just re-score
from `dev/va-usability/raw/A2-probit-stage8_n*.rds` if the fits retain enough). It changes no
conclusion — it removes three wrong numbers from a committed CSV.

## 3. DELTA — the evidence base is PINNED to the current AC implementation

Verified at 15:20: `R/va-r3-proto.R`, `inst/tmb/`, `R/va-routing.R` are **untouched** since
`aba2d21e`, in history and working tree. So every measurement in `dev/va-usability/`
characterises the AC that currently ships, and the ladders are valid.

**But if you change the AC branch, all of it expires.** The n-ladder, the crux, the p-ladder
and the correlation grid all become historical, and must be re-run before any of those numbers
are cited again. This caveat is NOT in the main handover; treat it as binding.

## 4. Process delta worth folding into the brain

Tenth correction of the session, and a NEW shape: **a scoring convention was retracted in one
script and had already been copied into a second.** The `sigma.lv` fold was inherited from
`dev/va-speed/29-head-to-head-gllvm.R:70-73` into `70-gllvm-external-benchmark.R`, then into
`100-probit-stage8.R` before the first was corrected.

The existing note `An internal control is not a comparator` covers comparison *design*. The
missing rule is downstream: **when you retract a scoring convention, grep for every script that
copied it and fix or quarantine them in the same pass.** Worth adding to the brain as an atomic
note — not written here because this session is out of context and the note should be authored
by someone who can verify its retrieval anchor lands.

## Landing

Committed on `claude/va-lane2`. Still **UNPUSHED** — 8 commits `bf483ce4..HEAD`.
`git push origin claude/va-lane2` when the maintainer wants it. `origin/main` PROTECTED at
`5bf18ab3`, untouched.
