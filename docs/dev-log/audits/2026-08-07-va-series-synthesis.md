# VA validation series — working-position synthesis (2026-08-07)

**Status:** docs-only lock · **G0=1** (Shinichi approved) · **not** a fence / merge / campaign licence  
**Lane:** `codex/va-gh-all-families` @ worktree `/private/tmp/gllvmtmb-va-gh-all-families`  
**Authority:** banked audits + ultraplan + Mission Control `gllvmTMB.json` + brain receipts (#947/#948)  
**Does not:** rewrite Design 110 Arc-2 labels · flip public fence · set `calibrated=TRUE` · merge Arc-1 · start Totoro

---

## One-paragraph position

For everyday GLLVM fitting in gllvmTMB, keep **Laplace as the default engine**, with a **named AGHQ ridge only when runaway / σ–ρ need rescue**; model selection stays on **unpenalised LA** (ridge-refit the winner only if Mode-B needs it — #947 parked). On binary presence–absence, prefer **probit**; **cloglog is OK under LA/GH**, while **logit is weak for absolute Σ** and should use **JJ when VA**. On **nbinom2**, prefer **VA-GH for absolute Σ at large n** (~3× wall vs LA) and **LA for small-n / cost**. On most other measured families, **LA wins when both clear abs** — VA often recovers similarly but is much slower. **AGHQ is opt-in** for binary σ/ρ; it is **not** “LA-GH” and is **not** the S1 abs-Σ winner. Do **not** pitch PoisG / AC / gllvm closed-VA collapse as Σ recovery. Parked: #947 WAIC/CV, #948 Hui closed-form NB2 VA, multinomial VA later. Arc-2 fence and `calibrated=FALSE` stay.

---

## Locked working rules

| # | Rule | Evidence anchor |
| ---: | --- | --- |
| 1 | **LA everyday default** (+ named `aghq`/`aghq_ridge` if runaway) | LA vs AGHQ timed binary; fairness/naming audit; MC engines row |
| 2 | **MAP → select on unpenalised LA**; ridge-refit winner only if needed | #947; MC `do_not_repeat` |
| 3 | **Binary: prefer probit**; cloglog OK under LA/GH; **logit weak for abs Σ**; **JJ for VA logit** | GH n-ladder; 500×20 cloglog-vs-probit; JJ n=500; logit GH parked |
| 4 | **NB2: VA-GH preferred for abs Σ at large n (~3× cost)**; LA for small-n/cost | NB2 n-ladder + 2×2 smoke |
| 5 | **Most other families: LA when both clear**; VA ≈ recovery, often much slower | betabinomial/beta; S4 GH-hard; S0 exact |
| 6 | **AGHQ: opt-in for binary σ/ρ**; not “LA-GH”; not S1 abs winner | LA-vs-AGHQ; naming audit |
| 7 | **Don’t pitch PoisG / AC / gllvm closed-VA collapse as Σ recovery** | PoisG σ-scale; JJ vs gllvm; NB2 gllvm VA collapse |
| 8 | **Parked:** #947 WAIC/CV · #948 Hui NB2 closed VA · multinomial VA later (dr31) | AGENT_LOG; MC; DR31 |
| 9 | **No fence flip · no Arc-1 merge · no new campaign** from this writeup | G0=1 mechanism authority |

---

## Family / route digest (scientific only)

### S0 — exact VA (gaussian / poisson / gamma / lognormal)

- **Gaussian:** SCIENTIFIC_PASS abs under default 0.35/0.50; Arc-2 overall remains **INCONCLUSIVE** (LA pairing starvation). Dual-report stays.
- **Poisson / gamma:** shared abs-Σ hardness at q=2; q=5 clearer. Gamma LA “0/300 healthy” **RETRACTED** (FE+RE gate artefact). Recovery vs gllvm LA cleared for gamma LA — residual hygiene, not a stop.
- **Takeaway:** exact VA can recover; does not rewrite Arc-2 / fence.

### S1 — binary (logit / probit / cloglog)

- **Probit + GH:** best user story among GH links for abs Σ at large n / 500×20.
- **Cloglog + GH:** softer than probit on abs Σ; keep as supported link, not default pitch. Under LA/GH (not PoisG), Σ can recover with n.
- **Logit + GH:** parked as a recovery dig; **JJ for logit when VA** — good β, beats our GH on Σ, abs Σ still open at n=500.
- **AGHQ(+ridge):** wins banked σ/ρ/runaway grids; on S1 abs β/Σ LA ties or wins and is far cheaper (~5–67×). Keep opt-in.
- **Naming:** Laplace / AGHQ / VA-GH — never “LA-GH”.

### S2 — nbinom2

- Small n (≈120): shared abs fail; prefer **LA** (cheaper).
- Large n (≈1000): **VA-GH wins abs Σ** (pass_abs ~0.92 vs LA ~0.42) at ~**3×** wall.
- gllvm VA Σ collapse reconfirmed at n=120 — not our recovery target.

### S3 / S4 — betabinomial, beta, GH-hard cluster

- **Betabinomial / beta:** Σ recovers with n for gtmb; **prefer LA** for cost+accuracy when both clear (VA often 14–24× slower).
- **S4** (tweedie, student, ztpois, ordinal_probit, delta_gamma): Σ recovers with n for gtmb; ordinal hardest (clears at n=1000); VA often 20–50× slower for similar abs — **prefer LA** unless a cell-specific abs win (as NB2 large-n).
- **truncnb2 + delta_lognormal:** optional later wave only with explicit go — not implied by this synthesis.

### Closed-form traps (do not advertise as Σ recovery)

| Path | What happens | Honest use |
| --- | --- | --- |
| **PoisG cloglog** | Λ→0 / Σ collapse at every n/p tested (ours + gllvm VA) | β can look fine; **not** a Σ estimator; keep cloglog auto on GH |
| **AC (probit)** | attenuation / collapse on Design-110 grids | comparator only |
| **gllvm closed VA** (logit / NB2 / cloglog cells) | frequent Σ collapse while β OK | always 2×2; our VA ≠ gllvm VA |

---

## Why we sometimes “beat” gllvm — honest mechanisms

Do **not** claim package superiority from a single table. When gllvmTMB looks better, name the mechanism:

1. **Different VA objective** — our R3 GH / exact / JJ vs gllvm’s closed-form VA; collapse of gllvm VA on Σ is often **their objective**, not proof we are universally better.
2. **Shared DGP hardness** — when all four arms fail abs Σ together (poisson q=2, NB2 n=120), the cell is hard for everyone; “we beat gllvm” is meaningless.
3. **Size regime** — large-n recovery (NB2, ordinal, binary GH) is not a small-n win; quote n.
4. **Timing artefacts** — warm DLL vs cold TMB compile; matched `n_starts` / SE / machine (apples-to-apples note 2026-08-07). Prior “beat gllvm at large N” speed claims were **NOT ESTABLISHED** when SE/warmth mismatched (lane2 retraction).
5. **Health-gate vs recovery** — `healthy=0` under `n_starts=1` does not mean hopeless β/Σ; dual-report abs-on-completed is secondary, not a soft-PASS.
6. **Comparator caveats** — unique/Ψ, phi explosion (gamma), family-string mismatches; document before advertising.

Standing comparator: **always 2×2** (gllvmTMB VA/LA × gllvm VA/LA) vs planted truth.

---

## Explicit non-claims

- Not a public default flip to VA or AGHQ.
- Not Arc-1 merge / release readiness.
- Not soft-PASS of Arc-2 FAIL/INCONCLUSIVE cells.
- Not licence for #947/#948 builds or multinomial VA architecture.
- Not HMSC as a near-term arm (deferred paper / Phase 5.5).

---

## Audit inventory (sources for this lock)

| Topic | Path |
| --- | --- |
| Series frame | `docs/dev-log/2026-08-07-va-validation-series-arc0-ultraplan.md` |
| S0a Gaussian | `docs/dev-log/audits/2026-08-07-va-s0a-gaussian-scientific-ledger.md` |
| S0b exact | `docs/dev-log/audits/2026-08-07-va-s0b-exact-scientific-ledger.md` |
| Gamma LA close | `docs/dev-log/audits/2026-08-07-va-gamma-la-confidence-close.md` |
| Binary GH n-ladder | `docs/dev-log/audits/2026-08-07-va-binomial-gh-nladder.md` |
| cloglog vs probit 500×20 | `docs/dev-log/audits/2026-08-07-va-binomial-500x20-cloglog-vs-probit.md` |
| JJ logit n=500 | `docs/dev-log/audits/2026-08-07-va-jj-n500-beta-sigma.md` |
| LA vs AGHQ timed | `docs/dev-log/audits/2026-08-07-va-la-vs-aghq-timed-binary.md` |
| AGHQ naming | `docs/dev-log/audits/2026-08-07-va-binary-timing-fairness-aghq-naming.md` |
| PoisG collapse | `docs/dev-log/audits/2026-08-07-va-poisg-sigma-scale.md` |
| NB2 ladder | `docs/dev-log/audits/2026-08-07-va-nbinom2-nladder.md` |
| Betabinomial / beta | `…-va-betabinomial-nladder.md` / `…-va-beta-nladder.md` |
| S4 GH-hard | `docs/dev-log/audits/2026-08-07-va-s4-gh-hard-nladder.md` |
| 4-arm poisson/gamma | `docs/dev-log/audits/2026-08-07-va-gllvm-4arm-poisson-gamma.md` |
| Success bar / HMSC | `docs/dev-log/after-task/2026-08-07-va-success-bar-hmsc-defer.md` |

---

## Next G0 menu (after this lock)

1. **Stop / park series** — measurement banked; wait for a separate product G0 (fence / merge).
2. **Optional truncnb2 + delta_lognormal** wave — only if Shinichi says go.
3. **Separate Arc-1 promotion/merge G0** — not implied by ladders or this synthesis.
4. **Do not** auto-start Totoro from this document.
