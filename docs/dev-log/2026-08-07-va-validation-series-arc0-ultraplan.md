# VA validation series — Arc Card + Ultra Plan (S0 Gaussian absolute-first)

**Date:** 2026-08-07  
**Lane / worktree:** `codex/va-gh-all-families` @ `a5b34529` · `/private/tmp/gllvmtmb-va-gh-all-families`  
**Status:** **PREPARATION ONLY — stop at G0.** No campaign, code, fence, push, or PR authorised by this document.  
**Inputs:** Design 110; Arc-2 adjudication MD5 `e57f8460fd98bd0eac43b4a6c014317d`; diagnosis `/private/tmp/va-gh-h7-arc2-diagnosis-20260807.md`; family-by-family review (2026-08-07).

---

## Phase 0.25 — Prior-work sweep receipt

| Surface | Evidence ran | Finding | Call |
| --- | --- | --- | --- |
| **repo git state** | `git status -sb`; `git log --oneline -15`; `branch_drift_check.sh`; `git worktree list` | `codex/va-gh-all-families` @ `a5b34529`, clean, **137 ahead / 0 behind** `origin/main`, **unpushed**, no PR; sibling VA WTs (`va-lane2`, `va-ac-curvature`) separate | **resume this lane for planning**; do not absorb other VA lanes |
| **twin / sister** | Design 110 §2 exact routes; drmTMB D-127 (brain) is a separate package revival | Exact Gaussian/Poisson/lognormal/Gamma routes already implemented; Arc 2 already measured them | **reuse retained Totoro confirmation**; do not rebuild Gate E / Arc 1–2 |
| **brain** (`search_all_projects: true`) | MCP `search_notes` “VA validation Gaussian exact-route…” + “Design 110 VA GH H=7…”; deterministic `rg` on `memory/AGENT_LOG.md`, `DECISIONS.md`, `OPEN_QUESTIONS.md`, `journal/` for `va-gh\|H=7\|Design 110\|absolute-first` | No prior **S0 absolute-first ledger** decision; D-127 is drmTMB-only; Arc 2 closeout + diagnosis exist in-repo | **build the gap**: absolute-first protocol + Gaussian-first scientific ledger |
| **log/history grep** | `rg -in "va-gh\|H=7\|Design 110" memory/AGENT_LOG.md` (and decisions/journal) | Records automation/Fir repair and drmTMB VA second-look; **no** recorded approval to soft-PASS INCONCLUSIVE or reopen Arc 2 | **do not** reinterpret INCONCLUSIVE; **do not** re-run Arc 2 |
| **Verdict** | — | Arc 1–2 + diagnosis are DONE. Genuinely new: a **series ladder** with **S0 absolute-first** scoring that leaves frozen Arc-2 labels untouched | **reuse evidence / resume lane / build protocol+ledger gap** |

---

## ARC CARD — VA validation series (S0 first)

**Mode:** size  
**Requested outcome:** smallest credible next validation arc that retires the decisive uncertainty — Gaussian / exact-route **absolute-vs-truth** scientific sanity — plus a ladder for the series (S0→S4; M later/parallel).  
**Mechanism authority (this session):** preparation + plan only. After G0 may authorise: secondary absolute-first ledger from **retained** known-truth Totoro evidence; optional narrow Totoro compute if independence required. **Explicit exclusions:** no package `R/`/`src/` edits; no fence/threshold/default mutation; no Arc-2 re-run; no push/PR/merge/release; no GHA artifacts (D-50); do not soft-PASS INCONCLUSIVE; do not pool cells; multinomial (M) design-only / do not wait on Ranga.  
**Recommended arc (Arc 0):** **2.0–2.5 hours** wall for Gaussian absolute-first protocol + retained-evidence re-ledger + durable receipt (**reuse path**).  
**Time contract:** ceiling ~3 h for Arc 0; programme ladder is separate and not a single time box.  
**Estimate confidence:** **inferred** for protocol+writeup duration; **measured** that Gaussian absolute metrics and eligibility drivers already exist in the Arc-2 adjudication (no need to rediscover). Fresh Totoro Gaussian-only (2,000 rows) is **inferred** ~1/18 of the 36k confirmation if G0 demands independent seeds — **not** default.  
**Arc 0 outcome:** a durable absolute-first scientific ledger for `gaussian_identity` q∈{2,5} that answers “must-pass?” without changing frozen `overall_point_route_verdict = INCONCLUSIVE`.  
**State transition:** no absolute-first scientific ledger → Gaussian S0 ledger with explicit `SCIENTIFIC_PASS|FAIL|INCONCLUSIVE` under predeclared absolute-first rules; **frozen Arc-2 labels unchanged**.  
**Executable rung and evidence:** **blocked pending G0** — intervention = protocol + re-score retained confirmation/adjudication; retained evidence = MD5 `e57f8460…` + confirmation export under `/private/tmp/va-gh-h7-final-evidence/`.

### Programme capacity ladder (series; not one session)

| Order | Budget (inferred) | Outcome | Trigger / definition of done |
| --- | ---: | --- | --- |
| **Arc 0 = S0a** | 2.0–2.5 h | Gaussian absolute-first scientific ledger | Start after G0. Done when Gaussian q=2 and q=5 each have a retained absolute-first verdict + writeup; frozen INCONCLUSIVE still printed. |
| **Rung S0b** | 2–3 h | Exact-route cohort under same protocol (poisson, lognormal, gamma) | If S0a completes. Poisson q=5 expected SCIENTIFIC_PASS+RETAIN; poisson q=2 shared abs-Σ hardness; gamma reliability FAIL — honest statuses. |
| **Rung S1** | 3–6 h (+ Totoro if new fits) | Binomials NARROW absolute-first | After S0. logit/probit/cloglog; same abs-first rule. |
| **Rung S2** | design 1–2 h; compute TBD | Shared hardness (poisson q=2, trunc. poisson) | After S0/S1. Fixture vs threshold vs estimand before “fix VA.” |
| **Rung S3** | design then Totoro | Reliability cluster (LA often 0/500) | After S2. Do not select on survivors. |
| **Rung S4** | design then Totoro | GH-hard (student, ordinal, tweedie q=2, …) | After S3. |
| **M** | separate architecture | Multinomial VA | Parallel design only; do not block S0–S4. |
| Integrate/close | 0.5 h / rung | After-task + Melissa plan-actual | Always. |
| **Total capacity** | **programme, not one box** | | Size mode: execute Arc 0 only until G0 re-opens the next rung. |

### Arc 0 budget

| Segment | Minutes | Output / stop point |
| --- | ---: | --- |
| Orient | 20 | Rehydrate Design 110 §6.1, diagnosis, Gaussian rows; assert MD5 |
| Core | 70 | Write absolute-first protocol; apply to Gaussian q=2/5 from retained CSV; draft scientific ledger |
| Verify | 25 | Recompute abs β/Σ, reliability, calibration from retained columns; adversarial check that frozen overall stays INCONCLUSIVE |
| Repair reserve | 20 | Eligibility/column mismatches; path/MD5 drift |
| Closeout | 15 | Dev-log receipt + after-task stub; Arc Creation Actuals |
| **Total** | **~150** | |

**In scope:** absolute-first **secondary** adjudicator rules; Gaussian S0a ledger from retained known-truth evidence; series ladder freeze.  
**Not in this arc:** fence change; threshold change on Design 110 Arc-2 gates; re-running 36k; S1–S4 compute; multinomial build; public accuracy claim; soft-PASS.  
**Evidence used:** Arc-2 adjudication (Gaussian β RMSE 0.074/0.091; Σ rel Frob 0.399/0.372; paired elig 0.418/0.518; LA unhealthy ~48–58%; both calibrations CALIBRATED); diagnosis `LAPLACE_COMPARATOR_ELIGIBILITY_ONLY`.  
**Risk branch:** If retained confirmation export is missing or MD5 mismatches, **stop** — restore evidence or ask G0 for a Gaussian-only Totoro re-export; do not invent numbers. If G0 insists on fresh independent seeds, switch to Totoro smoke → 2,000-row Gaussian confirmation (separate budget).

**Done when:** Gaussian absolute-first ledger exists with predeclared rules, retained numbers, and explicit statement that frozen Arc-2 overall remains INCONCLUSIVE; checks cited; no fence mutation.  
**First action (after G0):** assert adjudication MD5 `e57f8460fd98bd0eac43b4a6c014317d` and open Design 110 §6.1 beside the new absolute-first protocol draft.

### Actuals (complete at close)

**Recommended / actual:** 150 / ~90 · **Requested / used:** N/A / fresh Totoro (G0) · **Rungs completed:** S0a  
**Under-run event:** compute cheaper than planned (Gaussian + reused runtime); G0 overrode reuse→fresh  
**Calibration:** S0a closed; stop at G0b before S0b  
**Metric movement:** SCIENTIFIC_PASS q=2,5 under default 0.35/0.50; Arc-2 INCONCLUSIVE unchanged  
**Result:** S0a DONE · **Next arc:** G0b — open S0b? (Shinichi)

**HAND TO ULTRA PLAN:** Arc 0 = S0a Gaussian absolute-first scientific ledger from retained Arc-2 known-truth evidence; duration ~2.0–2.5 h; outcome = durable SCIENTIFIC_* verdicts for `gaussian_identity` q∈{2,5} without mutating frozen INCONCLUSIVE or public fence; constraints = G0-gated, Totoro/DRAC only if new fits, no soft-PASS, no pool, D-50.

---

## ULTRA PLAN — Arc 0 / S0a

```
🎯 GOAL
PLATFORM: Cursor (planning session); after G0 hand execution to a fresh `/goal` loop on this worktree — do not continue a long Agent chat.
DELIVERABLE: Absolute-first VA validation protocol + Gaussian S0a scientific ledger (retained Arc-2 evidence), leaving Design 110 Arc-2 frozen labels and public fence untouched.
HEADLINE: Answer “Gaussian must pass?” scientifically (abs-vs-truth primary) without soft-passing frozen INCONCLUSIVE.
IN PARALLEL (after G0 only): (i) protocol prose, (ii) mechanical re-score script over retained CSV, (iii) Rose claim-fence scan — all read-mostly; no package mutation.
DEFER: S0b exact cohort; S1–S4 campaigns; multinomial architecture (M); fence/NEWS/register promotion; push/PR of `codex/va-gh-all-families`; any R/TMB edit.
DISCIPLINE: verify by recomputing Gaussian abs metrics from MD5-bound CSV · compute = none by default (reuse); Totoro only if G0 requires fresh seeds (D-50) · closure = after-task + Melissa plan-actual + stop for next G0 before S1.
```

**ARC PROGRAM:** size mode; Arc 0 = 2.0–2.5 h S0a; ladder S0b→S1→S2→S3→S4 (+M parallel design); integrate/close per rung; under-run → advance one rung only after explicit G0.

### WHAT THE BRAIN ALREADY KNOWS

- Design 110 freezes Arc-2 gates: paired eligibility ≥0.90, abs β RMSE ≤0.35, abs Σ rel Frob ≤0.50, ratio ≤1.25, reliability Wilson upper ≤0.10; exact cells ignore H.
- Arc 2 result: 1 PASS / 24 FAIL / 11 INCONCLUSIVE; Gaussian is INCONCLUSIVE solely on Laplace pairing starvation.
- Public fence + `calibrated=FALSE` stay; diagnosis recommends RETAIN/NARROW/INVESTIGATE by cell — Gaussian = NARROW for claims, scientific green for abs recovery.
- D-50: campaigns on Totoro/DRAC, never GHA artifacts.
- drmTMB D-127 is unrelated second-look; do not conflate.

### WHAT SHINICHI TOLD US

- Want `/arc-creation` then `ultra-plan`.
- Series of arcs to validate VA; Gaussian must-pass discussion accepted.
- Proposed series: S0 exact-route abs-first → S1 binomials NARROW → S2 shared hardness → S3 reliability → S4 GH-hard → M later/parallel.
- Default size mode; preparation + plan only until G0.

### WHAT THE TEAM RAISED

```
TEAM RAISED
  Fisher — Absolute-first is a different estimand question from paired VA/Laplace ratios; keep both ledgers · matters so INCONCLUSIVE stays honest · recommend secondary SCIENTIFIC_* labels, not threshold edits · Q: confirm abs caps stay 0.35 / 0.50 · default: keep Arc-2 caps for S0a
  Rose   — Any wording that looks like soft-PASS is a claim drift · matters for fence · recommend every S0 artefact reprint frozen overall=INCONCLUSIVE · Q: none if that rule is locked · default: lock it
  Gauss  — Exact Gaussian ELBO must recover planted truth; LA attrition is comparator pathology · recommend abs + reliability + calibration as S0 core; ratios only on matched-complete pairs as secondary · Q: require fresh seeds? · default: reuse retained confirmation
  Curie  — Known-truth only; smoke before any new Totoro job · recommend no new campaign in S0a · Q: if fresh seeds, 500×2q×VA-only vs VA+LA? · default: VA-primary abs; LA optional
  Ada    — Arc 0 = S0a reuse path; stop at G0; series ladder recorded but not executed
```

### ADA'S RECOMMENDATION

Approve **S0a reuse path** as Arc 0. Do **not** re-run Arc 2. Do **not** change Design 110 thresholds. Authorise a **secondary absolute-first ledger** document + mechanical re-score from retained evidence. Defer S0b until S0a closes.

### DECISIONS LOCKED (pending G0 confirmation)

1. Frozen Arc-2 `overall_point_route_verdict` remains authoritative for Design 110; S0 does not rewrite it.
2. INCONCLUSIVE ≠ PASS; no pooling.
3. S0 primary score = absolute known-truth recovery (+ reliability + calibration); Laplace ratios secondary on paired-complete seeds only.
4. Compute default = **reuse**; Totoro only if G0 requires independence.
5. M is out of critical path.

### Dual-report reliability (Shinichi G0 2026-08-07)

Do **not** relax Design 110 / Arc-2 reliability thresholds. For S0 scientific
ledgers, report **both**:

- **(A)** frozen Wilson / healthy → `scientific_verdict_default` (unchanged)
- **(B)** abs recovery on completed-even-if-unhealthy finishes →
  `ABS_ON_COMPLETED_*` (secondary; **not** a soft-PASS of Arc-2 / fence)

Motivating case: gamma. Protocol:
`lanes/va-s0b-exact/protocol/absolute-first.md`. Ledger:
`docs/dev-log/audits/2026-08-07-va-s0b-exact-scientific-ledger.md`.

### Standing invariant — gllvm comparator (Shinichi 2026-08-07)

**Always 2×2 (mandatory, not optional):** gllvmTMB **VA** × gllvmTMB **LA** × gllvm **VA** × gllvm **LA**, vs planted truth where possible. Document model-match caveats. **Our VA ≠ gllvm VA** (gllvmTMB = R3/GH/exact; gllvm = their `method="VA"` stack). Mark an arm `N/A` with reason only after attempting it — never silently omit.

Do not stop at gllvmTMB VA vs gllvmTMB Laplace alone. Where a matched `gllvm` fit is feasible on the same DGP / seeds, scientific ledgers and diagnosis tables must carry **both** gllvm arms. Document unique/Ψ, family-string, and shape/dispersion mismatches when models are not bit-identical. Consolidate into one table — do not thrash parallel gllvm jobs. Protocol: `lanes/va-s0b-exact/protocol/gllvm-comparator.md`.

### Compute policy (Shinichi 2026-08-07) — this VA validation lane

| Surface | Rule |
| --- | --- |
| **Local laptop** | **≤10 cores** soft cap. Soft machine — do not hammer beyond 10. |
| **Scale-out** | Prefer **Totoro** whenever more parallelism or larger probes are needed. Totoro is always available; reuse Gate-E / runtime from confirmation `022b4eab` and S0a/S0b campaign roots. |
| **D-50** | No GitHub Actions artifacts. Campaign outputs stay on Totoro + local copy under `/private/tmp`; **never stage raw evidence to git**. |
| **gllvm** | Always report gllvm performance too where feasible (standing comparator above). |
| **New campaigns** | Do **not** start a huge new campaign unless needed for open questions (gllvm compare, gamma n-ladder). Small Totoro jobs OK. |

In-flight local probes: stay ≤10 cores locally **or** move remaining heavy work to Totoro.

### Standard comparator panel + LA validation (Shinichi 2026-08-07)

**Set these standards now**, before S1 binomials / GH-hard cells. Do **not** wait for harder dists to invent the panel.

#### A — Is LA validation thin for less-used non-Gaussian?

**Yes — thin / partial at GLLVM latent campaign scale; not missing at family wiring.**

| Layer | Status | Cite |
| --- | --- | --- |
| Ordinary family recovery under **default Laplace** (package default) | Often register `covered` (e.g. FAM-06 poisson, FAM-09 gamma) | `docs/design/35-validation-debt-register.md` FAM-* |
| Deep multi-seed absolute-first LA as a **GLLVM latent comparator** (Design 110 fixture: n=120, p=8, q∈{2,5}, loadings-only) | **Thin / partial** — Gamma “0/300 healthy” **RETRACTED** as `laplace_health` FE+RE gradient bug (proxy conv∧pd ~282/300 & 214/300); Gaussian LA unhealthy ~48–58% still real under recorded gate | Arc-2 + S0b; fix `dev/va-gh-h7-campaign/run-cell.R`; after-task `2026-08-07-va-s0b-laplace-health-fe-gradient-fix.md` |
| What Arc-2 / S0 actually fitted as LA | **Default LA only** — `gllvmTMBcontrol(integration = "laplace", se = TRUE)`; **no** `aghq`, **no** `aghq_ridge`, no custom multi-start | `dev/va-gh-h7-campaign/run-cell.R` `laplace_fit()` |
| AGHQ / `aghq_ridge` as LA rescue | Measured mainly on **binomial runaway / flat-direction** regimes; MIS-36 is opt-in / partial | brain AGHQ notes; register MIS-36; **not** a multi-family Design-110 LA+AGHQ certificate |
| Unstructured VA≈LA when identifiable | **Answered and PARKED** (Design 72) — does **not** certify default-LA reliability on Design 110 fixtures | brain `gllvmTMB-va-vs-laplace-what-is-settled` |

Shinichi's insight is correct: validating VA against a **fragile default-LA comparator** without also validating (and, where needed, **rescuing**) LA leaves less-used non-Gaussian families under-tested as engines, even when FAM rows are `covered`.

#### B — Proposed standard comparator panel (pre-harder dists)

Every scientific absolute-first / diagnosis cell reports:

| Arm | Spec | Role |
| --- | --- | --- |
| **Planted truth** | Design 110 / S0 DGP | Primary oracle |
| **gllvmTMB VA** | `integration = "va"` at admitted H (exact cells: H N/A; GH cells: H ladder separately) | Primary research route |
| **gllvmTMB default LA** | `integration = "laplace"` — **same knobs as Arc-2** (no silent AGHQ) | What users get today; frozen comparator lineage |
| **gllvmTMB LA+tricks** | **(ii)** — see knobs below | Best honest LA/AGHQ effort; validates LA, not only VA |
| **gllvm VA** | Matched seeds/DGP — **always attempt** | External VA (≠ our VA) |
| **gllvm LA** | Matched seeds/DGP — **always attempt**; else `gllvm_LA = N/A` with reason | External LA |

**LA+tricks knobs (locked for this series unless G0 renames):**

1. **Primary tricks arm:** `gllvmTMBcontrol(aghq = 9, aghq_ridge = 2, se = TRUE)` — shipped AGHQ node count + opt-in ridge (ridge fires only when AGHQ is named; never silently penalises default Laplace).
2. **Starts:** use the package's AGHQ/Laplace multi-start behaviour as shipped when the control path exposes it; do **not** invent a new start policy mid-series. If a cell still starves on health, record start/health diagnostics — do not retune thresholds.
3. **Optional diagnostic split (budget-gated):** `aghq = 9` with `aghq_ridge = Inf` (unpenalised AGHQ) to separate integration gain from ridge — only when Totoro budget allows; not required for the minimum panel.
4. **Do not** replace default LA with LA+tricks in Arc-2 lineage tables; both arms stay.

**Scoring / success bar — LOCKED for now (Shinichi 2026-08-07; scientific; not a fence rewrite):**

Enough **before harder distributions** (S1+). Dual-report stays; Arc-2 / fence unchanged.

| Bar | Rule | Scope |
| --- | --- | --- |
| **VA ≲ LA (or better)** | gllvmTMB **VA** abs recovery (β, Σ) reaches **LA equivalence or better** vs planted truth among completed / abs-available seeds — compare to gllvmTMB **default LA** and, when exploring, **LA+tricks** | Primary internal engine bar |
| **VA ≲ gllvm (or better)** | Same abs metrics: our VA reaches **gllvm equivalence or better** on the matched DGP/seeds | External frequentist bar; **always 2×2** (our VA ≠ gllvm VA) |
| **Dual-report** | (A) Wilson/healthy → `scientific_verdict_default`; (B) abs-on-completed → `ABS_ON_COMPLETED_*` (secondary; **not** soft-PASS) | Reliability honesty |
| **Speed** | Report wall; never the pass rule | Secondary |
| **H** | N/A on exact-route; H ladder only for GH cells (S1+ / S4) | Exact vs GH |
| **Paired ratios** | Secondary / non-blocking for SCIENTIFIC_PASS when LA eligibility starves | Arc-2 lineage |
| **HMSC** | **Not** a 5th arm on S0/S1 standards — future/menu (paper / phylo+spatial capstone); see §E | Deferred |

#### E — HMSC (Ovaskainen / `Hmsc`) — menu item, not near-term arm

**Recommendation: later paper / bounded capstone comparator — not a drop-in 5th arm for S0–S1.**

- Brain + Jason scout (`docs/dev-log/audits/2026-07-29-jason-hmsc-cross-package-scout.md` §5b; vault note *HMSC scout (2026-07-29)*; Design 87 §“Not worth building”): **do not build a validation *programme* on `Hmsc`**. Posterior mean under MGP shrinkage ≠ MLE — disagreement is not diagnostic; agreement does not certify coverage.
- Different estimand class: **Bayesian JSDM / latent-factor Gibbs**, 4 families vs our ~32; phylo structures `Beta` not `Lambda`.
- Where it *is* worth ~1 day later: `phylo_latent + spatial_unique` capstone (`docs/design/05-testing-strategy.md` Phase 5.5) — Design 54 falsification / paper comparator, not S0 abs-first gating.
- Transferable now without installing HMSC: evidence-layer ideas already absorbed (held-out CV, known-truth fixture, block-conditional recovery — #900 etc.).

#### C — Recommended next exploration arc

**NEXT = non-exact VA series, starting S1 binomials** (Shinichi 2026-08-07 family-registry direction).

##### Exact vs non-exact split

| Bucket | Families | VA path | Series status |
| --- | --- | --- | --- |
| **Exact VA (S0)** | gaussian, poisson, Gamma, lognormal | analytic expectation | **DONE / OK to leave** — poisson/gamma OK; gamma LA beats gllvm LA; FE-health ~71–79% hygiene (`docs/dev-log/audits/2026-08-07-va-gamma-la-confidence-close.md`) |
| **Non-exact VA (GH H=7)** | binomial×3, nbinom1/2, betabinomial, beta, tweedie, student, truncated_*, ordinal_probit, delta_* (hybrid) | 1-D GH (hybrids: exact×GH) | **NEXT** — enter at binomial |
| **Out of scope** | multinomial | VA **not implemented** | design-only / M later; no VA comparisons |

Success bar unchanged: **VA ≲ LA** and **VA ≲ gllvm** (our VA ≠ gllvm VA); always 2×2; dual-report; no fence change.

##### S1 entry (binomial) — **flagship, same narrative tier as Gaussian S0a**

**Binomial (binary) is the primary applied priority alongside gaussian** for SDM /
evidence-synthesis GLLVM work (presence–absence and binary indicator maps).
Applied anchor: Ayumi urbanisation evidence map — Stage 1 probit-GLLVM +
three-package robustness (`gllvm` / `glmmTMB` / `gllvmTMB`) —
https://github.com/Ayumi-495/urbanisation_map/issues/13.

Lane: `lanes/va-s1-binomials/` — logit / probit / cloglog; abs-first + dual-report +
always 2×2; local ≤10 cores then Totoro.  
Local: public-route VA smoke `healthy`; **scientific** binomial logit 2×2 at q=2
(24 seeds, private R3 GH, campaign-aligned β/Σ) — audit
`docs/dev-log/audits/2026-08-07-va-s1-binomial-gllvm-2x2.md`.  
**q=2 headline (aligned):** gllvmTMB VA β RMSE **0.233** vs gllvm VA **0.137**
(Δ≈+0.10 **real**, not plumbing); Σ worse still (~4.9 vs ~1.0); all four arms
fail abs Σ; **VA ≲ gllvm FAIL** on this cell. q=5 needs private engine / Totoro
(public fence unchanged).  
**gllvm inventory:** Arc-2/Codex Totoro had **no** gllvm (by design). Binomial
gllvm = **new** this session. H-ladder reuse OK (H7≈H61 PASS) — do **not** re-run H.  
**Totoro gllvm 2×2 (q∈{2,5}):** `scripts/launch-totoro-s1-gllvm-2x2.sh` —
**DONE** 2026-08-07 (summary MD5 `4cf32255…`). Same β gap at q=5 (gtmb_va 0.264
vs gllvm_va 0.128). Full 3600-row S1 campaign (`launch-totoro-s1.sh`) still needs
explicit **go**. No fence / default-H change.

##### Non-exact GH H=7 family ladder — **LOCKED canonical order** (Shinichi 2026-08-07)

**Authority:** Shinichi confirmed. This is the **canonical** non-exact VA
validation sequence for gllvmTMB. **Do not reorder without explicit G0.**
Do **not** parallel-blast families. Mirror: `lanes/va-s0b-exact/protocol/gllvm-comparator.md`
§Non-exact family order; S1 entry also in `lanes/va-s1-binomials/LOOP/GOAL.md`.

Same protocol every rung: **2×2** gllvmTMB×gllvm × VA×LA vs planted truth;
H=7 default (reuse Arc-2 H-ladder evidence where the family already has H∈{5,7,9,15,61};
new H only if missing); local smoke ≤10 cores → Totoro. Private R3 VA for q=5;
**no public fence change.**

| # | Order | Family | Why (one line) | Gate |
| ---: | ---: | --- | --- | --- |
| **1** | **S1** | **binomial** logit → probit → cloglog | SDM / evidence-synthesis **flagship** with gaussian; Ayumi #13 | **NOW** (q=2 scientific done; Totoro q∈{2,5} 2×2 DONE; VA≲gllvm FAIL dig may be in flight) |
| **2** | **S1b** | **nbinom2** | Workhorse overdispersed counts in ecology / SDM; Arc-2 FAIL×2 | **STOP — no Totoro** until Shinichi go after binomial harden |
| **3a** | **S1c** | **betabinomial** | Overdispersed binary / trials; natural next after binomial | G0 after S1b |
| **3b** | **S1d** | **beta** | Continuous proportions on (0,1); after trials-binomial (`betabinomial → beta`) | G0 after S1c |
| **4** | later | **tweedie** / **student** / **truncated_*** / **ordinal_probit** / **delta_*** | Secondary GH-hard / hybrid cluster — only after 1–3 | G0 after core ladder |
| **5** | **OUT** | **multinomial** | VA **not implemented** | design-only / M; never on this ladder |

**Locked sequence (one line):**  
`binomial → nbinom2 → betabinomial → beta → (later: tweedie / student / truncated / ordinal / delta)` · `multinomial OUT`

##### Process choice (G0 2026-08-07) — **C Hybrid**

**Decision: C — Hybrid.** One short ladder spec lives in this ultraplan (order,
protocol, kill rules, compute); **execution stays continuous** on
`codex/va-gh-all-families` (thin `lanes/va-s1-*` stubs + probe → audit → Totoro).
Do **not** ultra-initialize a new “non-exact family sweep” arc before each family.

Why C (not A alone, not B):
1. **Ultra pace** — bounded slices; a full LOOP/GOAL ceremony per family (B) is
   over-arc for probe work that already has a series frame.
2. **Durable order without ceremony** — A’s “just keep typing” drifts; the
   **LOCKED** table above is the short arc doc (goals / order / STOP gates).
3. **Proper arc only when the product changes** — fence, default-H, API, or
   `calibrated=TRUE` promotion still get a real ultra-plan + G0; family probes do not.

Kill rules (unchanged): no parallel-blast; **no nbinom Totoro** until go after
binomial harden / FAIL dig; no fence edit; multinomial OUT; **no reorder without G0**.

#### D — Explicit freeze (unchanged)

- **Arc-2 frozen labels** (`overall_point_route_verdict`, cell PASS/FAIL/INCONCLUSIVE) **unchanged**.
- **Public fence + `calibrated=FALSE`** unchanged until a separate **promotion G0**.
- Dual-report (B) and LA+tricks do **not** rewrite Design 110 thresholds or soft-PASS INCONCLUSIVE.

### QUESTIONS STILL OPEN (for G0 — max 3)

**QUESTION 1** · Approve S0a reuse path (no new fits) as Arc 0?  
**WHY NOW** · Decides whether any Totoro time is spent.  
**TEAM VIEW** · Ada/Gauss/Curie: reuse.  
**RECOMMENDATION** · Yes — reuse.  
**IF YOU DO NOT MIND** · Reuse.  
**WHAT CONTINUES** · Planning artefact only until you answer.

**QUESTION 2** · Keep absolute caps β≤0.35 and Σ rel Frob≤0.50 for SCIENTIFIC_PASS?  
**WHY NOW** · Defines S0 pass rule.  
**RECOMMENDATION** · Yes — same caps, different eligibility rule (abs availability ≥0.90, **not** paired ≥0.90).  
**IF YOU DO NOT MIND** · Same caps.

**QUESTION 3** · After S0a, auto-start S0b (other exact routes) or stop for another G0?  
**RECOMMENDATION** · Stop for G0 between S0a and S0b (discussion-light later, but one checkpoint).  
**IF YOU DO NOT MIND** · Checkpoint between S0a and S0b.

---

### Absolute-first protocol (draft for G0; not executed)

For each family×rank cell under S0:

1. **Completeness** — unchanged (every planned seed represented).
2. **Reliability** — unchanged (Wilson upper ≤0.10 → PASS).
3. **Absolute recovery (PRIMARY)** — among seeds with finite VA estimates (absolute availability ≥0.90): abs β RMSE ≤0.35 and mean Σ rel Frob ≤0.50. Else FAIL if availability OK and bound crossed; INCONCLUSIVE if availability <0.90.
4. **Paired Laplace ratios (SECONDARY, non-blocking for SCIENTIFIC_PASS)** — report when paired eligibility ≥0.90; otherwise report `RATIO_NOT_ELIGIBLE` with LA fail rate — **do not** force overall SCIENTIFIC_FAIL solely from ratio ineligibility.
5. **gllvm comparator (STANDING, always 2×2)** — report **gllvmTMB VA, gllvmTMB LA, gllvm VA, gllvm LA** vs the same planted truth on matched seeds/DGP; document model-match caveats and that our VA ≠ gllvm VA. See `lanes/va-s0b-exact/protocol/gllvm-comparator.md`.
6. **Calibration** — report Arc-2 labels; do not promote `calibrated=TRUE` on the package.
7. **Frozen overall** — always reprint Design 110 Arc-2 overall verdict beside the scientific one.

**Gaussian expectation (measured from retained evidence):** SCIENTIFIC_PASS at both ranks; frozen overall remains INCONCLUSIVE.

### SLICE TABLE (post-G0 execution)

| Slice | Member | Model+effort | Bar | Dispatch | Time | Detail | Dep |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| RECON | Scout | Composer/Grok · low | Cursor Models | native | 15 m | MD5, paths, column inventory | — |
| S1 protocol | Fisher+Ada | Auto Cost / Claude · medium | Other Models | native | 40 m | Write absolute-first rules into planning/ledger doc | RECON |
| S2 rescore | Curie | Composer · medium | Cursor Models | native | 35 m | Script over retained 74-col CSV → Gaussian ledger rows | RECON |
| S3 writeup | Ada | Auto Cost · medium | Other Models | native | 25 m | Scientific ledger md + series pointer | S1,S2 |
| MECHANICAL-VERIFY | Scout | Composer · low | Cursor Models | native | 15 m | Recompute β/Σ/elig; assert frozen INCONCLUSIVE unchanged | S2,S3 |
| Rose fence | Rose | Auto Cost · medium | Other Models | native | 15 m | No soft-PASS / no fence claim drift | S3 |
| RECONCILE | Melissa | Auto Cost · low | Other Models | native | 10 m | `docs/dev-log/plan-actual/2026-08-07-va-s0a.md` | all |

**PARALLEL after G0:** {RECON} then {S1 ‖ S2} then S3 → {MECHANICAL-VERIFY ‖ Rose} → RECONCILE.  
**FAN-OUT BUDGET:** checkpoint=`va-s0a-g0` · new children ≤4/6 · scout=1 · build=2 · ceiling=0 · Luna/Composer for RECON+MECHANICAL-VERIFY.  
**LUNA SUITABILITY:** yes — RECON and MECHANICAL-VERIFY.  
**ULTRA EFFORT:** no.  
**SEARCH:** none required for S0a (corpus already in-repo); NotebookLM optional later for M.  
**ESTIMATE:** ~2.0–2.5 h · ≤4 agents · fits one `/goal` session.  
**ARC ACTUALS:** complete on this Arc Card + Melissa plan-actual.  
**REVIEW:** Rose + Fisher critique protocol before any claim-shaped sentence.  
**VERIFY:** MD5 + recomputed Gaussian metrics match diagnosis; frozen overall still INCONCLUSIVE in the ledger.  
**CONSOLIDATE:** one ledger under `docs/dev-log/audits/` (name TBD at execution) + after-task.  
**RECONCILE:** Melissa required at close.

### Stop / G0 points

| Gate | When | Blocked until |
| --- | --- | --- |
| **G0 (now)** | Before any executable rescore script lands as “campaign product”, any Totoro job, or any fence-adjacent edit | Shinichi answers Q1–Q3 |
| G0b | Before S0b | S0a closed + approval |
| G1 | Before S1 Totoro | S0 complete |
| Hard stop | Any urge to edit Design 110 thresholds or soft-PASS | Maintainer-only |

### Paste-ready `/goal` prompt (after G0 approval)

```
/goal Execute VA S0a only from docs/dev-log/2026-08-07-va-validation-series-arc0-ultraplan.md
Worktree: /private/tmp/gllvmtmb-va-gh-all-families · branch codex/va-gh-all-families @ a5b34529
Authority: absolute-first secondary ledger from retained Arc-2 evidence; no R/src fence edits; no Arc-2 re-run; no push/PR.
Done when: Gaussian q=2/5 scientific ledger + verify + after-task + Melissa plan-actual.
Stop: G0b before S0b.
```

---

## Needs Shinichi G0

~~G0 / G0b / G0c answered. Exact S0 left OK.~~

~~Process C Hybrid + non-exact family order confirmed (Shinichi 2026-08-07).~~
Order **LOCKED:** binomial → nbinom2 → betabinomial → beta → (later tweedie /
student / truncated / ordinal / delta) · multinomial OUT. No reorder without G0.

🔴 **Needs you (next rung only):**

1. **After binomial VA≲gllvm FAIL dig** — say go for **nbinom2 local→Totoro**
   (S1b). Do **not** launch nbinom Totoro until this go (do not conflict with
   in-flight binomial dig).
2. Full 3600-row S1 campaign (`launch-totoro-s1.sh`) still optional / separate go.

Until then: **no** nbinom Totoro, **no** full GH-family blast, **no** fence change.
