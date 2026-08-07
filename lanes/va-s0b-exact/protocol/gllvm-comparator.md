# Series note — matched gllvm comparator (standing)

**Date:** 2026-08-07  
**Authority:** Shinichi standing rule for VA validation / diagnosis arcs.  
**Applies to:** S0a (forward), S0b, and later S1–S4 / diagnosis probes.

## Invariant — always 2×2 (not optional)

Every scientific absolute-first / diagnosis cell **must** report the full
**package × method** panel vs planted truth (where the DGP is known):

|  | **VA** | **LA** |
| --- | --- | --- |
| **gllvmTMB** | Our algorithm (R3 / GH / exact ELBO routes — **not** gllvm’s VA) | Package default Laplace; add **LA+tricks** as a separate arm when exploring engines |
| **gllvm** | `method = "VA"` (gllvm’s default) | `method = "LA"` |

**Always vs planted truth** when truth is available. Do **not** publish
tables that only show gllvmTMB VA vs gllvmTMB LA, or that omit either
package’s VA or LA arm when a matched fit is feasible.

### Our VA ≠ gllvm VA

Document this every time:

- **gllvmTMB VA** = this package’s variational route (`integration = "va"`):
  Design-110 GH (public H=7), exact closed forms (gaussian / poisson /
  lognormal / gamma), or hybrid — **R3 / GH / exact**, not gllvm’s
  closed-form / EVA stack.
- **gllvm VA** = Niku et al. `gllvm::gllvm(..., method = "VA")` (their
  ELBO / closed-form / hybrid-EVA path). Same *label*, different
  objective and implementation. Agreement is **not** identity.

If an arm cannot run for a family/API reason, still reserve the cell and
mark it **`N/A` with the reason** — do not silently drop the arm from the
2×2.

## Feasibility / match caveats (document every time)

| Axis | Typical match note |
| --- | --- |
| Covariance | Design 110 exact cells are loadings-only (`Σ = ΛΛ'`); gllvm `num.lv` VA is also loadings-only — matched on Ψ absence. |
| Family API | gllvm often wants string families (`"poisson"`, `"gamma"`); `Gamma(link="log")` is **rejected** (`Selected family: Gamma not permitted`). Confirmed 2026-08-07: `family="gamma"` works for both `method="VA"` and `method="LA"`. |
| Gamma shape / φ | Parameterisation may differ across packages; primary scored estimands remain β and Σ vs planted truth. |
| Laplace | **Always attempt** gllvm Laplace (`method="LA"`). If the API refuses that family, mark `gllvm_LA = N/A` with the error — do not treat “if available” as permission to skip the attempt. |
| LA+tricks (gllvmTMB only) | When exploring: `aghq = 9`, `aghq_ridge = 2` (series lock) as a **fifth** arm — does not replace default LA in Arc-2 lineage tables. |
| Seeds / DGP | Prefer identical planted draws; local probes **≤10 cores** (Shinichi 2026-08-07; was 20 — `PILOT_CORES`/`mc.cores`/`xargs -P` ≤10); one probe at a time; consolidate — do not thrash parallel jobs. |

## Active probes (2026-08-07) — coordinate, do not thrash

**Local parallelism cap: ≤10 cores** (Shinichi 2026-08-07). Prefer **Totoro**
for decisive grids. Do not overlap two `mclapply`/`xargs -P` probes.

| Dir | Role |
| --- | --- |
| `/home/snakagaw/gllvm_work/va-gllvm-h2h-4arm-022b4eab-20260807/` | **Canonical 4-arm** Totoro run (poisson+gamma, q=2/5, 8 seeds) on confirmation `022b4eab` |
| `/private/tmp/va-gllvm-h2h-4arm-20260807/totoro-results/` | Local D-50 copy of Totoro CSVs |
| `lanes/va-s0b-exact/scripts/probe-gllvm-4arm.R` | Script (VA+LA × both packages) |
| `/private/tmp/va-poisson-gllvm-probe-20260807/` | Local **VA×VA** 20-seed poisson/gamma probe (keep artefact; Σ often favours gllvmTMB VA) — not the full 2×2 |
| `/private/tmp/va-s0b-gllvm-h2h-20260807/` | Aborted sibling h2h — superseded by 4-arm Totoro |
| Totoro `…/va-gamma-la-nladder-022b4eab-20260807/` | Gamma LA n-ladder (n=120…1000, q=2); local `/private/tmp/va-gamma-la-nladder-evidence-20260807/` — recorded “0/6 healthy” used the **same FE+RE `gr()` bug**; do not cite as LA hopeless (see FE-gradient after-task) |
| `/private/tmp/va-gamma-la-h2h-20260807/` | **Gamma LA×2 H2H** (24 seeds, q=2/5, FE health post-`abaf7802`) — gllvmTMB LA **better** than gllvm LA on abs β/Σ |
| `lanes/va-s0b-exact/scripts/probe-gamma-la-h2h.R` | Gamma LA head-to-head script (FE + buggy `|g|`, paired Δ) |
| Totoro `…/va-s2-nbinom2-2x2-20260807/` | **NB2 2×2 smoke** (16 seeds, q=2); local `/private/tmp/va-s2-nbinom2-2x2-smoke-20260807/` — prefer gtmb LA; gllvm VA collapses Σ |
| `lanes/va-s2-nbinom2/scripts/probe-nbinom2-2x2-smoke.R` | NB2 4-arm smoke (+ Totoro launcher) |

**Audits:** `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md`;  
`docs/dev-log/audits/2026-08-07-va-gamma-la-h2h.md`;  
`docs/dev-log/audits/2026-08-07-va-nbinom2-2x2-smoke.md`.

### Headlines from canonical 4-arm (do not re-derive from smoke)

- Poisson `q=2`: all four arms fail abs Σ together (~0.61–0.69).
- Poisson `q=5`: gllvmTMB VA strongest on Σ; gllvm VA weaker (pass_abs 0.12).
- Gamma: **gllvm LA is not hopeless on β/Σ** (8/8; `q=5` pass_abs=1.0). Shape/φ often explodes — not a matched estimand.
- **Gamma LA×2 (24 seeds, FE health):** gllvmTMB LA **beats** gllvm LA on mean β/Σ and abs pass (q=2 pass 0.875 vs 0.542; q=5 1.00 vs 0.917). FE healthy ~0.7–0.8; buggy full-g healthy 0.
- Always report gllvm wall times (see audit table).

### Related local H2H (20 seeds; VA×VA only)

Artefact `/private/tmp/va-poisson-gllvm-probe-20260807/` (`paired-summary.csv`):
on poisson + gamma at q∈{2,5}, **gllvmTMB VA often better Σ** than gllvm VA
(paired ΔΣ negative for gllvmTMB on all four cells; pass_abs higher). Keep as
supporting colour for the locked success bar (VA ≲ gllvm); canonical ranking
still comes from the 4-arm Totoro table above.

## Success bar — LOCKED for now (Shinichi 2026-08-07)

Enough **before harder distributions**. Scientific / dual-report only — does **not** rewrite Arc-2 or the public fence.

1. **VA ≲ LA (or better):** gllvmTMB VA abs recovery (β, Σ vs planted truth) reaches **LA equivalence or better** (default LA; report LA+tricks when exploring).
2. **VA ≲ gllvm (or better):** same abs metrics vs **gllvm** on the matched 2×2 (our VA ≠ gllvm VA).
3. Dual-report reliability stays: Wilson/healthy vs abs-on-completed (secondary; not soft-PASS).

## Non-exact GH family order — **LOCKED** (Shinichi 2026-08-07)

Canonical sequence for the VA validation series after exact S0. **Do not
reorder without explicit G0.** Full ladder + gates:
`docs/dev-log/2026-08-07-va-validation-series-arc0-ultraplan.md` §C
(non-exact GH H=7 family ladder).

1. **binomial** (now — SDM / evidence-synthesis flagship with gaussian)
2. **nbinom2**
3. **betabinomial → beta**
4. **later:** tweedie / student / truncated / ordinal / delta
5. **multinomial OUT** (VA not implemented)

**Do not** start nbinom Totoro while binomial VA≲gllvm FAIL dig is in flight.
No parallel-blast; no fence change.

### HMSC — not a 5th arm yet

**`Hmsc` / Ovaskainen** = Bayesian JSDM (posterior mean ≠ MLE). Jason scout §5b + Design 87: **no HMSC validation programme** for S0/S1; later **paper / `phylo_latent + spatial_unique` capstone** only (`docs/design/05-testing-strategy.md` Phase 5.5). Do not add HMSC as a mandatory panel arm before harder dists.
