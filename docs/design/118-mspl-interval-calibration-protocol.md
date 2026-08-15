# Design 118 — Calibrated intervals for binary LA-MSPL: the Phase-B pre-registration protocol

**Maintained by:** Fisher (adjudication), Rose (claim discipline / closure).
**Status:** PRE-REGISTRATION PACKET, awaiting Shinichi's signature. **No compute is spent, no
code is changed, and no fence is lifted until this document is signed.** MSPL-04 in
`docs/design/35-validation-debt-register.md` remains `blocked`; that register row is edited
only after the Phase-B gate passes.

**Number-ledger check (Design 117's numbering discipline):** `tools/lane_preflight.sh` run
2026-08-15 against all refs reported **NEXT FREE = 118** (15 duplicate slots exist across
refs; `main` alone under-counts). Slot 118 is claimed by this commit.

**Provenance.** This packet is the A5 adjudication of the five Phase-A slice reports of the
approved ultra-plan "Calibrated intervals for binary LA-MSPL" (2026-08-15):

| Slice | Report (scratchpad `phase-a/`) | One-line result |
|---|---|---|
| A1 | `A1-mechanism-partition.md` | 55 joint-gate failures partition 26 OVER / 6 UNDER / 1 availability-only / 22 borderline-MCSE; C011 is a **location** failure (−8.26 SD); α\* clusters 0.10–0.18 outside C011 |
| A1b | `A1b-pinning-root-cause.md` | **INTRINSIC**: the C011 pin is the exact penalty-determined finite optimum under quasi-complete separation (analytic k=24 cloglog root 1.5964000447; stored objectives match the collapsed model to 1e-11) |
| A2 | `A2-kosmidis-firth-primary.md` | K&F 2021 coverage caveat verified against the primary; it **survives profiling**; it is an existence statement, silent on the rest of the space |
| A3 | `A3-calibrator-design.md` | The S1–S5 design adjudicated here; this packet supersedes it as the binding copy |
| A4 | `A4-bca-simulated-acceleration.md` | BCa acceleration: routes (i)/(iv)/IJ blocked (no per-unit score); route (iii) perturbation-resimulation is the one viable route, UNVERIFIED conversion formula |

The scratchpad copies are session-local; **this document is the durable, binding copy** of
everything Phase B executes against. Where this packet and A3 differ, the difference is an
**adjudicated change**, marked `[A1b-fold]` and justified in place. All other thresholds,
forms, and rules are A3's, carried verbatim.

**Standing campaign constraint** (2026-08-14 campaign README, binding): *"this campaign must
not be used to tune a method on the same seeds."* The 2026-08-14 archive is used below only
for labels, definitions, and effect sizes — never as fitting data. Every Phase-B seed is
fresh.

**Notation** (Design 88, *Symbolic estimator*): $Q_{LA}(\theta;c)=\ell_{LA}(\theta)+c\,P(\theta)$,
$P=\tfrac12\log\det(X_*^{\mathsf T}W_g(\beta)X_*)-V_{\text{loading}}-V_{\text{covariance}}$,
$c=c_n=2\sqrt{p_{\text{free}}/N_{\text{eff}}}$; $\hat\theta:=\hat\theta(c_n)$;
$H:=-\nabla^2_\theta Q_{LA}(\hat\theta;c_n)$.

---

## 0. Verdict summary, and what Shinichi must decide

### 0.1 What Phase A established

1. **The catastrophic pocket is not a bug.** A1b's verdict is **INTRINSIC (fence)**: when a
   trait's response column saturates (all ones or all zeros — quasi-complete separation), the
   MSPL loading collapses to zero, the objective separates per trait, and the intercept lands
   on the deterministic root of a univariate penalised equation. The pin is a **discrete
   family of count-attractors** — the analytic k=24 cloglog root 1.5964000447 matches the
   empirical mode to 1.3e-6, and ten predicted attractors across three links match their
   clusters to 1e-6–1e-8; stored objectives equal the collapsed-model optimum to 1e-11
   (A1b Tasks 1.2–1.3). No bound, clamp, start value, code constant, or underflow is
   involved (A1b Tasks 2–4). The estimator is doing exactly what soft penalisation is for —
   returning a finite estimate where the MLE is +∞ — and **no software change can recover
   truth 2.05 from an all-ones column**. The link ordering of the failure (cloglog 92.9% >
   probit 48.4% > logit 7.1% pinning) is fully explained by
   P(saturated column) = 0.938 / 0.525 / 0.048 at these truths (A1b Task 3) — a DGP fact,
   not a link-specific defect.
2. **Consequently the catastrophic undercoverage is a bootstrap inconsistency at the
   separation boundary**, not an interval-construction defect: parametric resamples from the
   collapsed fit re-saturate with probability ≈ 0.841, so ~78–84% of bootstrap refits land on
   the same atom and the percentile interval is a needle centred on a centre that is biased
   by construction (A1b verdict; A1 §Q2: midpoint −8.26 empirical SDs from truth at C011
   target 3, coverage 0.010).
3. **The remaining 26 overcovering cells are ordinarily calibratable**: outside C011 the
   required α\* clusters at 0.10–0.18 regardless of link/regime (A1 §Q3). C011 would need
   α\* ∈ [0.40, 0.74] — it is refused, never calibrated.
4. **No claim of uniform validity is possible.** Kosmidis & Firth (2021, §2.2, p. 5) prove
   intervals around any finite-valued penalised estimator *"will fail to cover regardless of
   the nominal level"* for sufficiently extreme true parameters, and state this is *"also
   true when the penalized likelihood is profiled"* (A2 §Q1–Q2, verified against the arXiv
   primary). The claim shipped here is therefore **regime-scoped and fence-conditional** (§4).
5. **The base construction is the level-calibrated penalised profile** (best-measured: 24/36
   gates vs bootstrap 20/36; fails safe — wide, not narrow-and-wrong; its availability
   failures are a diagnosed root-finder defect, fixable; §3). Percentile bootstrap is the
   flagged fallback, **inadmissible for saturated coordinates** `[A1b-fold]`. BCa and the
   union CI do not enter the default (§3.4).

### 0.2 Adjudication of A1b under the brief's rule

The dispatch rule was: BUG → add a fix-and-re-measure step, fence as defence-in-depth;
INTRINSIC → **fence is the primary control as designed**; UNDECIDED → conditional arms.
The verdict is INTRINSIC, so:

- **No estimator fix enters Phase B.** There is nothing to fix; changing $c_n$ or the
  penalty form merely relocates every count-attractor (A1b Task 4.4) and would force a full
  re-measure without recovering the truth. The pocket is a fence, not a tuning target
  (A1b Task 5.3).
- **Two A1b upgrades are folded into the design** (both marked `[A1b-fold]` below):
  **(i)** the danger observable is **response-column saturation itself**, certifiable
  pre-fit by the already-shipped `screen_control(separation = "fixed")` (Design 88;
  Design 117 §0 verification ledger) — so the fence's **first line is the existing screen**,
  and A3's penalty-sensitivity probe becomes the **second line** for the near-saturated
  band. This corrects A1 §Q4's "no fit-time observable distinguishes C011": no observable
  *in the stored campaign files* does, but the response matrix does, trivially.
  **(ii)** bootstrap intervals are **inadmissible for saturated coordinates** (atomic
  resampling distribution, re-saturation probability ≈ 0.84): the availability chain in
  §3.6 refuses the bootstrap fallback there categorically.

### 0.3 🔴 Decisions required from Shinichi before any compute

| # | Decision | Recommendation | Default if undecided |
|---|---|---|---|
| D1 | Sign this pre-registration (thresholds, gates, grid, stopping rule become binding) | Sign after reading §§1–5 | Phase B does not launch |
| D2 | Compute budget: full ≈45.6 M fit-equivalents vs reduced ≈26 M (bootstrap on 1/3 of datasets; §6.2) | **Reduced (≈26 M)** — the bootstrap is fallback-only and Wilson ±0.025 on its own calibration is acceptable if documented | No run (D-139) |
| D3 | Totoro/DRAC split (§6.4): B0 on Totoro now; B1/B2 as DRAC job arrays | Approve as proposed | B0 only, on Totoro |
| D4 | Saturated-coordinate semantics: refuse the interval outright vs flagged-conservative profile (§1.4) | **Refuse in the shipped default**; measure profile coverage on saturated cells as a Phase-B secondary outcome and revisit promotion after B2 | Refuse (fail-closed) |
| D5 | BCa ablation arm (1.44 M fits, behind its literature gate; §5.5) | Keep — it self-drops if the gate fails | Keep as registered |
| D6 | Owner of the two B0 code prerequisites (§7): `src/gllvmTMB.cpp` is touched by live cursor/codex MSPL lanes (preflight 2026-08-15) | Assign to one lane explicitly (D-87) | Not implemented; B0 blocked |

---

## 1. The fence (S1) — detect-and-refuse for penalty-determined estimates

### 1.0 Why a fence and not a calibration

C011 is a **location** failure: interval midpoint −8.26 empirical SDs from truth while width
exceeds the nominal reference (`width_over_sd` 6.13 vs 3.92), and `mean_estimate` identical
to six decimals between bootstrap and profile because both report the same outer MSPL point
(A1 §Q2). No level map moves a centre; C011 would need α\* ∈ [0.40, 0.74], 3–7× the bulk
(A1 §Q3). C011-class estimates are **refused, not calibrated**. Under the INTRINSIC verdict
this refusal is the **primary control** of the whole protocol, not defence-in-depth.

### 1.1 Fence line 1 `[A1b-fold]` — the structural screen (PRIMARY)

**Trigger, computable pre-fit from the data alone:** a trait response column with $k=0$ or
$k=n$ successes (saturated), or a block flagged `complete` / `quasi_complete` by Design 88's
shipped `screen_control(separation = "fixed")`. This is the region A2 §Q1–Q3 shows fails
*"regardless of the nominal level"*, the guarantee surviving profiling (A2 §Q2), and it is
the exact mechanism A1b proved: C011's pocket is 92.9%-triggered by column saturation alone
(predicted P(all-ones) 0.9384; A1b Task 3).

**Consequence:** intervals for the affected `infinite_terms` are refused unconditionally,
whatever the probe (line 2) says. The point estimate is still returned, labelled
**separation-finite / penalty-determined**. The screen catches the deep-separation limit
where the probe goes blind (see 1.3).

### 1.2 Fence line 2 — the penalty-sensitivity probe (the near-saturated band)

Differentiating the stationarity condition of $Q_{LA}$ in $\log c$ gives
$S=\partial\hat\theta/\partial\log c=-H^{-1}\nabla\ell_{LA}(\hat\theta)$: the
curvature-normalised **un-penalised score at the penalised optimum**. Zero when the data
determine the estimate; large when the penalty holds the estimate against a live likelihood
pull. Per-target statistic (pre-registered definition):

$$
\hat S_j=\frac{\hat\theta_j(2c_n)-\hat\theta_j(c_n/2)}{\log 4},
\qquad
s_j=\frac{|\hat S_j|}{\sqrt{(H^{-1})_{jj}}}
$$

— standard errors of movement per e-fold of penalty strength. In a pinned cell the
denominator is itself compressed (A1 §Q2: `sd_estimate` 0.084 at C011 target 3 vs 0.29 at
target 1), which works in the fence's favour.

- **Route A (shipped detector):** two extra outer refits at $c_n/2$ and $2c_n$, warm-started
  from $\hat\theta$. Cost 3× the point estimate — negligible against ≈600 fit-equivalents of
  interval machinery per fit (§6.1); robust on non-quadratic surfaces.
- **Route B (diagnostic):** $\hat S^{\text{surr}}=-H^{-1}\nabla\ell_{LA}(\hat\theta)$, ≈free
  — both ingredients exist under Design 88's discharged penalty-off-decomposition obligation.
  Computed alongside Route A on every Phase-B fit. **Switch rule, decided once on the B0
  label set:** ship Route B only if its detection and false-refusal rates are within 0.02 of
  Route A at the same threshold and $\mathrm{corr}(\log|\hat S|,\log|\hat S^{\text{surr}}|)\ge0.95$.

**Refusal tiers, fixed a priori by interpretation of the statistic (Phase B measures this
rule's operating characteristics; it does not choose the rule):**

| Tier | Rule | Consequence |
|---|---|---|
| `data_determined` | $s_j<0.25$ | interval reported |
| `penalty_influenced` | $0.25\le s_j<1.0$ | interval reported, flagged |
| `penalty_determined` | $s_j\ge1.0$ | **interval refused** |

### 1.3 Fence lines 3–4, and the stated blind spots

3. **Probe-refit non-convergence** → refuse (fail-closed, Design 88's style).
4. **Calibrator clip-boundary** → an $\alpha^*$ landing on either clip of $[0.01,0.40]$
   (§2.5) is a refusal, not a clipped interval. Because A1 §Q3 measured C011's requirement
   at $\alpha^*\in[0.40,0.74]$, this catches C011-class cells even if the probe misses them.

**Blind spots, stated rather than buried.** In *deep* separation
$\nabla\ell_{LA}(\hat\theta)\to0$, so $s_j\to0$ despite total penalty-determination — the
probe under-detects at exactly the limit. `[A1b-fold]` Under the INTRINSIC verdict this is
now covered by construction: the deep limit **is** column saturation, and fence line 1
catches it pre-fit; the probe's job is the intermediate band (e.g. $k=n-1$) where the screen
does not fire but the penalty still moves the estimate materially. **Residual uncovered
gap:** separation that exists only in the *estimated latent* design (Design 117 §7) is
caught by neither line — **UNVERIFIED**; what would settle it is re-running the LP test on
the augmented design including fitted LVs (cheap, post-fit, per Design 117 §7).

### 1.4 Interval semantics for saturated coordinates `[A1b-fold]`

For a fence-line-1 coordinate:

- **Bootstrap/percentile intervals are inadmissible, categorically.** The parametric
  resampling distribution is atomic (P(resample re-saturates) $=\mu_{\text{pin}}^{n}\approx0.841$
  at C011; A1b Task 5.2): the interval measures optimizer noise, not sampling uncertainty.
  The §3.6 fallback chain never falls through to bootstrap for these coordinates.
- **Shipped default (pending D4): refuse the interval**, report the labelled point estimate
  and its sensitivity number.
- **Conditional arm (pre-registered, promotion gated on Shinichi after B2):** the campaign's
  profile intervals covered 1.000 in the same cells (A1 §Q1/§Q5) — over- not under-coverage.
  Phase B records profile coverage on saturated coordinates as a **secondary outcome**; a
  flagged-conservative profile interval for saturated coordinates may be proposed for
  promotion only if that coverage is ≥0.95 in every hold-out saturated cell, and only by a
  separate maintainer decision. Nothing in the primary gate (§5.7) depends on this arm.

### 1.5 What the user sees

Per Design 117 §6.1, the sensitivity number is reported for **every** estimate; refusal is
the top tier of the same report. A `penalty_sensitivity` table on every MSPL fit (`term`,
`estimate`, `se_penalised`, `estimate_half_cn`, `estimate_double_cn`, `d_per_efold`,
`sensitivity`, `class`, `[A1b-fold]` `saturated`); `confint()` returns `NA` for refused rows
with a typed warning of class `gllvmTMB_mspl_penalty_determined` quoting $s_j$ and the
threshold; a typed error if every target refuses; the print method counts refusals; the
message explains the number (*"the estimate moved 4.2 SE when the penalty strength was
halved and doubled — this number is the penalty's, not the data's"*).

### 1.6 B0 validation of the probe — labels sharpened by A1b `[A1b-fold]`

The archive carries **no** gradients, Hessians, or perturbed-$c_n$ refits (A4 §Q4, A1 §Q4),
so $s_j$ cannot be computed retrospectively; but the disease label can now be **analytic**,
not merely empirical. Pre-registered fit-level labels for B0:

- **L1 (saturation):** trait column has $k\in\{0,n\}$ — fence line 1's own trigger;
- **L2 (attractor):** $|\hat\theta_j-r_{\text{link}}(k)|<10^{-4}$, where
  $r_{\text{link}}(k)$ is the **analytic count-attractor root** for the observed count $k$
  (A1b Task 1.2's `uniroot` construction), superseding A3's empirical modal-value label —
  dataset-independent and derived from theory rather than from the archive.

B0 re-simulates the 12 published DGP cells with **fresh seeds**, 200 datasets each, both
probe routes plus both labels: $12\times200\times3=7{,}200$ fits (§5.3). Detection/false-refusal
gates in §5.3; registered predictions P2/P5 in §5.4.

---

## 2. The calibrator (S2) — the prepivoting map $\alpha\mapsto\alpha^*(v)$

Carried from A3 §S2 unchanged except where marked. The construction is evaluated at a
data-dependent level $\alpha^*(v)$ — a monotone reparameterisation of the nominal level
(prepivoting in Beran's sense), never a change of construction. For the profile this
replaces the deviance threshold $\tfrac12\chi^2_1(1-\alpha)$ (measured constant
1.920729410347059; A1 §Q3) by $\tfrac12\chi^2_1(1-\alpha^*)$; for the bootstrap, the
$\alpha^*/2$ and $1-\alpha^*/2$ empirical percentiles.

### 2.1 The observable set $v$ — all fit-time; nothing depends on the true parameter

| # | Observable | Grounding |
|---|---|---|
| 1 | `link` ∈ {logit, probit, cloglog} | A1 §Q5 mechanistic grading |
| 2 | $\pi_{\max}=\max_t\max(\hat p_t,1-\hat p_t)$; $m_{\min}=\min_t\min(\#1_t,\#0_t)$ | A1 §Q3–Q4 (`beta_shift` p=0.019); **both tails** per Design 117 §2 |
| 3 | $c_n=2\sqrt{p_{\text{free}}/N_{\text{eff}}}$ | the penalty strength itself |
| 4 | $\log N_{\text{eff}}$, $p_{\text{free}}$ | asymptotic axis; breaks #3's collinearity |
| 5 | separation-screen status + `n_infinite_terms` | Design 88 §Public contract; `[A1b-fold]` now also fence line 1 |
| 6 | $s_j$ (§1.2) | the designed fit-time C011 discriminator |
| 7 | $\|\hat\theta_j\|/\mathrm{se}_j$ | fit-time proxy for A2's "large enough components" |
| 8 | `q`, `structure` | envelope keys (§4), not free terms unless varied |

### 2.2 What Phase B must vary for identifiability

The campaign held $N_{\text{eff}}$, $p_{\text{free}}$, $c_n$ **constant** (A1, one 24×3
fixture) — no calibrator indexed on them is fittable from the archive. Mandatory variation:
$N_{\text{eff}}$ (via sites); prevalence continuously on **both tails** ($\pi\in[0.03,0.97]$);
all three links; $q\in\{1,2\}$; and **$p_{\text{free}}$ decoupled from $N_{\text{eff}}$** —
for ordinary MSPL at $q=1$, $p_{\text{free}}\approx2T$ and $N_{\text{eff}}=n_{\text{site}}T$,
so $c_n\approx2\sqrt{2/n_{\text{site}}}$ is a function of $n_{\text{site}}$ alone: a grid
varying only $n_{\text{site}}$ confounds $c_n$ with $N_{\text{eff}}$ perfectly. The two
de-confounding arms C-ID1/C-ID2 (§5.1) are **not optional**. (The $p_{\text{free}}\approx2T$
count is **UNVERIFIED** until read off a real fit at B0; the C-ID $c_n$ values are recomputed
from exact counts before the grid freezes.)

### 2.3 Functional form — the pre-registered ladder

$\operatorname{logit}\alpha^*(v)=\operatorname{logit}\alpha+h(v)$, rungs fitted strictly in
order, each admitted only by the §2.5 rule:

| Model | $h(v)$ | Anchor |
|---|---|---|
| M0 | 0 | comparator; **if M0 passes, ship nothing** |
| M1 | $\gamma_0$ | A1 §Q3: ~20/26 overcovering cells cluster at $\alpha^*\in[0.10,0.18]$; $\alpha^*\approx0.14\Rightarrow\gamma_0\approx+1.13$ |
| M2 | + $\gamma_1c_n$ | correction vanishes as $c_n\to0$ (Sterzinger & Kosmidis 2023 soft-scaling); sign $\gamma_1\ge0$ |
| M3 | + $\gamma_2\operatorname{logit}\pi_{\max}$ | regime the strongest measured term (F=5.26, p=0.0021; A1 §Q3–Q4); sign $\gamma_2\ge0$ |
| M4 | + $\gamma_3\log(1+s_j)$ | the fence–calibrator bridge; sign $\gamma_3\ge0$ |
| M5 | + link main effect (2 df) | last: link's apparent excess was entirely C011's (refused); remaining cloglog cells sit at 0.100–0.114 vs logit 0.115 (A1 §Q3) |

**Registered signs are load-bearing:** a wrong-signed fitted $\gamma_k$ fails the
mechanistic story — the term is dropped and the contradiction reported (gate G5, §5.7).
Separate $h_{\text{profile}}$ and $h_{\text{boot}}$ are fitted first; a single shared $h$
is adopted only if it passes the same admission margin.

### 2.4 Model selection, clipping (all fixed in advance)

- Fit to **coverage**: minimise $\sum_c w_c(\widehat{\text{cov}}_c(\gamma)-0.95)^2$,
  re-evaluating stored per-replicate intervals at $\alpha^*(v;\gamma)$ — no refitting.
- Leave-whole-cells-out $K$-fold CV within the calibration split ($K=8$, folds by cell).
- **Admission margin:** M$_{k+1}$ admitted only if out-of-fold
  $\max_c|\widehat{\text{cov}}_c-0.95|$ drops by ≥0.005 **and** mean absolute error does not
  rise. Ties to the simpler model. **Stop at the first non-admission.**
- **Clip:** $\alpha^*\in[0.01,0.40]$. Lower bound: tail resolution at $B=500$. Upper bound:
  the measured boundary between calibratable conservatism and C011-class location failure
  (A1 §Q3). Landing on a clip = refusal (fence line 4).

### 2.5 Replicates and the three-way verdict

Wilson 90% half-width < 0.015 at $\hat p=0.95$ requires $n\ge580$; **Phase B registers
$n=600$ per cell** ($w=0.0147$). The borderline class is a property of the ±0.03 band, not
of $n$ (22/55 archive failures were borderline-by-resolution; A1 §Q1), so the verdict is
three-way with a **one-shot escalation**:

| Verdict | Rule | Action |
|---|---|---|
| PASS | Wilson 90% CI $\subset[0.92,0.98]$ | — |
| FAIL | point outside $[0.92,0.98]$ | — |
| INDETERMINATE | point inside, Wilson pokes out | escalate that cell to $n=2000$, **once**; still INDETERMINATE ⇒ recorded FAIL (fail-closed) |

Escalation applies to hold-out gate cells only, identically regardless of lean.

---

## 3. The interval construction (S3)

### 3.1 Decision

> **Base: the level-calibrated penalised profile.** Fallback: the level-calibrated
> percentile bootstrap — on profile unavailability only, flagged, and `[A1b-fold]` **never
> for saturated coordinates** (§1.4). BCa is a pre-registered ablation arm behind a
> literature gate, not shipped. The union CI is a Phase-B diagnostic only.

### 3.2 Why the penalised profile (adjudicated grounds)

1. Best-measured: 24/36 joint gates vs bootstrap 20/36, Wald 9/36 (`method-summary.tsv`).
2. Its 205 unavailable rows are an **engineering defect** — every one reports
   `centre=matched` with a one-sided bracket-search failure (A1 §Q6); fixed and gated in §7.
3. Re-levels exactly and cheaply from the stored trace — the calibrator needs no refits.
4. **It fails safe.** A flat ridge makes the profile wide-but-covering (C011 profile
   targets 2–3: coverage 1.000) where the bootstrap is narrow-around-a-biased-centre
   (0.010) — and `[A1b-fold]` A1b proves the bootstrap's narrowness is structural
   (atomic resampling), so the base construction must be the one whose failure mode is
   over-coverage. S1+S2 can handle conservatism; nothing rescues a needle on a wrong centre.
5. Calibration and the availability defect point the same way: the dominant correction
   $\alpha^*>\alpha$ lowers the crossing threshold (1.921 → e.g. 1.089), so bracket search
   succeeds more often (registered prediction P1).
6. A2 §Q2 does not argue against profiling here: the K&F caveat survives profiling but is an
   **existence** statement about the extreme region — which fence line 1 now refuses on the
   exact mechanism A1b established. The shipped claim never asserts uniform validity.

### 3.3 The fallback, and what does not ship

Percentile bootstrap: 36/36 availability; weakness is calibration (S2's job); catastrophic
mode is the saturation atom — excluded by §1.4. **BCa:** after fence line 1 removes C011's
rows, addressable undercoverage is three cells (C007 t2 0.879, C009 t3 0.906, C012 t3
0.913); route (iii)'s conversion formula is **UNVERIFIED** (A4 §Q2) and costs ≈600 extra
refits per user fit — disqualifying for a default under D-139. It runs as the §5.5 ablation
behind a literature gate (Efron 1987 §6; Hall 1992 ch. 3) and is dropped-and-reported if the
gate cannot be cleared. $\hat a_{\text{boot-skew}}$ (A4 route (ii)) is exploratory only,
**UNVERIFIED** equivalence. **Union CI** (Kosmidis 2007): pushes the wrong way for a 26-to-6
overcoverage-dominant failure map and degenerates to unbounded exactly where fence line 1
already refuses; computed as a diagnostic at near-zero cost. **UNVERIFIED** (A2 §Q4):
whether current `brglm2::confint.brglmFit()` still exposes `ci.method = "union"` — check
`?confint.brglmFit` before citing it as adopted.

### 3.4 Storage contract (what makes the calibrator fittable)

Per replicate per target: the full profile trace over thresholds
$[\tfrac12\chi^2_1(0.60),\tfrac12\chi^2_1(0.99)]=[0.354,3.317]$ (the current bracket, built
for 1.9207, is too narrow at the small-$\alpha^*$ end); the full bootstrap replicate vector
($B=500$); $\hat\theta_j$, $\mathrm{se}_j$, both probe routes' $\hat S_j$/$s_j$, the two
perturbed estimates, the observable vector $v$; `[A1b-fold]` the per-trait success counts
$k_t$ and saturation flags; the separation-screen result and all convergence/PD flags.

### 3.5 Availability contract (evaluated in order, fail-closed)

1. **Fence line 1** `[A1b-fold]`: saturated/screened coordinate → no interval (default
   pending D4); labelled point + sensitivity returned; typed condition.
2. **Fence lines 2–4**: `penalty_determined`, probe non-convergence, or clip-boundary →
   refuse.
3. **Calibrated penalised profile** at $\alpha^*(v)$.
4. **Profile unavailable** after a fixed retry budget → calibrated percentile bootstrap at
   its own $\alpha^*_{\text{boot}}(v)$, only if the ≥475/500 usable-refit floor is met,
   flagged as fallback — `[A1b-fold]` and only for non-saturated coordinates.
5. **One-sided availability is not a two-sided interval**: refuse the two-sided interval;
   record the one-sided rate as a Phase-B outcome for a later, separately validated slice.
6. **Both constructions fail** → refuse, typed condition.

---

## 4. The claim boundary (S4)

### 4.1 The named regime envelope — every key checkable at fit time, fail-closed outside

| Axis | In the envelope | Outside ⇒ refuse |
|---|---|---|
| Family | complete, unweighted, single-trial Bernoulli | everything else (Design 88) |
| Link | logit, probit, cloglog (probit **held out and re-validated**, §5.1) | any other |
| Structure | ordinary `latent(d = 1:2, unique = FALSE)` | **spatial is OUT** — unmeasured by Phase B |
| $q$ | $\{1,2\}$ iff the $q=2$ arm passes; else $\{1\}$ | $d>2$ (Design 88 fence) |
| Prevalence | realised fit-time floor $m_{\min}$ within the measured range, both tails | beyond it |
| Scale | $N_{\text{eff}}$, $p_{\text{free}}$ in the measured rectangle; $c_n$ in the measured range | beyond it |
| Estimability | screen clean `[A1b-fold]` (no saturated column, no `infinite_terms`) **and** $s_j<1.0$ | refused per §1 |

The envelope is stated in realised observables only — never in true parameters.

### 4.2 The documentation paragraph — pre-registered verbatim from A3 §S4.2

> **What 95% means here, and where it stops meaning it.** Confidence intervals for
> `estimator = "mspl"` are **simulation-calibrated**, not asymptotic. The nominal level is
> delivered by evaluating the penalised profile at an adjusted level $\alpha^*$ chosen so that,
> across a pre-registered simulation envelope, the realised coverage of the resulting interval is
> 0.95. That adjustment was fitted on one set of simulated regimes and validated out-of-sample on
> held-out prevalence regimes, an entirely held-out link, and a held-out sample size, all with
> independent seeds. So *95%* means: **in repeated sampling from data-generating processes inside
> the named envelope, and for estimates the penalty-sensitivity check does not refuse, about 95 of
> every 100 such intervals contain the true value.** It does not mean 95% for an arbitrary
> dataset. Outside the envelope — a different family, link, latent structure, a prevalence or a
> sample size beyond the measured range — no interval is returned. Inside it, an estimate that
> moves by more than one standard error when the penalty strength is halved and doubled is
> reported as **penalty-determined rather than data-determined**: for those, the point estimate and
> its sensitivity number are given and the interval is declined. That refusal is not conservatism
> to be tuned away. Kosmidis & Firth (2021, §2.2) show that a penalised estimator is finite for
> every dataset and so takes only finitely many values, with the consequence that for sufficiently
> extreme true parameters intervals built around it *"will fail to cover regardless of the nominal
> level"* — and they state this holds when the penalised likelihood is profiled, not only for Wald
> intervals. No calibration can repair that region; it can only be detected and declined. Finally,
> an MSPL fit is a penalised (MAP-like) point estimate, not a maximum-likelihood fit: these are
> calibrated frequentist intervals **for that estimator**, they are not comparable with intervals
> from an unpenalised fit, and they do not license likelihood-ratio testing (Design 117 §4,
> constraint 2).

**Addendum `[A1b-fold]`, one paragraph, pre-registered alongside the verbatim text:**

> A trait whose response column is saturated (all presences or all absences) is separated:
> its maximum-likelihood estimate does not exist, and the reported MSPL value is a finite,
> penalty-determined replacement whose location is set by the penalty, not the data. For
> such coordinates bootstrap intervals are never reported — resamples from the fitted model
> re-saturate with high probability, so the bootstrap measures optimizer noise rather than
> sampling uncertainty — and the interval is declined.

---

## 5. Phase-B protocol (S5)

### 5.1 Grid and hold-out declaration

Axes: link; target marginal prevalence $\pi$; $n_{\text{site}}$; traits $T$; $q$. Targets:
the minimum-, median-, and maximum-prevalence trait intercepts (distance-from-boundary
interpretation). **Calibration blocks (88 cells):**

| Block | Definition | Cells |
|---|---|---:|
| C-core | {logit, cloglog} × $\pi\in\{0.03,0.20,0.50,0.80,0.97\}$ × $n_{\text{site}}\in\{12,24,48,96\}$, $T=3$, $q=1$ | 40 |
| C-q2 | {logit, cloglog} × $\pi\in\{0.03,0.50,0.97\}$ × $n_{\text{site}}\in\{24,96\}$, $q=2$ | 12 |
| **C-ID1** | $N_{\text{eff}}=288$ fixed, $c_n$ varying: $(n_{\text{site}},T)\in\{(96,3),(48,6),(24,12)\}$ ⇒ $c_n\approx0.289,0.408,0.577$ × 2 links × 3 $\pi$ | 18 |
| **C-ID2** | $c_n\approx0.408$ fixed, $N_{\text{eff}}$ varying: $n_{\text{site}}=48$, $T\in\{3,6,12\}$ ⇒ $N_{\text{eff}}=144,288,576$ × 2 links × 3 $\pi$ | 18 |

C-ID1/C-ID2 are mandatory (§2.2); their $c_n$ values are recomputed from exact
$p_{\text{free}}$ counts at B0 before the grid freezes.

**Hold-out blocks (44 cells) — declared here, before any fitting; never used for
coefficient fitting, model selection, or threshold tuning. Whole blocks by design axis,
never random cells; seeds disjoint from the calibration split and from the 2026-08-14
archive:**

| Block | Tests | Definition | Cells |
|---|---|---|---:|
| **H1 (link)** | cross-link generalisation | **all probit cells**: 5 $\pi$ × $n_{\text{site}}\in\{24,48,96\}$ + 3 probit $q=2$ | 18 |
| **H2 (regime)** | unseen prevalence, both tails | $\pi\in\{0.08,0.92\}$ × 2 links × 4 $n_{\text{site}}$ | 16 |
| **H3 (scale)** | extrapolation in $N$ | $n_{\text{site}}=192$ × 2 links × 5 $\pi$ | 10 |

Probit is held out because it sits mid-gradient (48.4% pinning between cloglog 92.9% and
logit 7.1%; A1 §Q5 — a gradient A1b showed is the P(saturation) ordering): predicting it
from the two extremes is the sharpest test that the calibrator is mechanistic, not
memorised. Replicates: $n=600$ per cell, one-shot escalation to 2000 for INDETERMINATE
hold-out gate cells only; bootstrap $B=500$ with the ≥475 usable floor.

### 5.2 Phase order

**B0** (prerequisites, timing, probe validation) → **B1** (calibration blocks; fit and
select the map) → **freeze the map in writing** → **B2** (hold-out; evaluate the gate). B2
does not launch until the map is frozen.

### 5.3 B0 — prerequisites and the probe gate

1. Implement `DATA_SCALAR(mspl_c_n_multiplier)` with its bit-identity gate (§7.1).
2. Widen the profile bracket to thresholds $[0.354,3.317]$ and fix the diagnosed
   root-finding defects (§7.2).
3. **Time a fit at each grid corner** — D-139: B0 *is* the pre-run test; the §6 budget is in
   fit-counts precisely because B0 owes the seconds-per-fit number.
4. Read exact $p_{\text{free}}$/$N_{\text{eff}}$ counts off real fits; recompute the C-ID
   $c_n$ values; freeze the grid.
5. **Probe validation:** 12 published DGP cells, fresh seeds, 200 datasets each, Route A +
   Route B + labels L1/L2 (§1.6): 7,200 fits.

**Probe gate (stopping rule 4 applies):** at the fixed threshold $s_j\ge1.0$, Route A must
attain **detection ≥0.90** on L2-labelled C011 target-3 fits and **false-refusal ≤0.05** on
the well-identified anchors C001/C004/C005/C008. Also reported: the full ROC, the Route A/B
agreement (switch rule §1.2), and predictions P2/P5.

### 5.4 Registered predictions (recorded before running)

| # | Prediction | If it fails |
|---|---|---|
| P1 | Profile availability at calibrated $\alpha^*>0.05$ ≥ availability at 0.05, cell by cell | the availability defect is not the diagnosed bracket geometry; §3.2 item 5 wrong |
| P2 | Median $s_3$ orders cloglog > probit > logit at high prevalence (92.9/48.4/7.1 gradient) | §1.2's mechanism wrong; redesign the fence before B1 |
| P3 | Cell-required $\alpha^*$ monotone increasing in median $s_j$ | fence and calibrator measure different things; M4 dropped |
| P4 | $\alpha^*\to\alpha$ as $c_n\to0$ across C-ID2 | M2's soft-scaling anchor void; the map must not be extrapolated in $N$ |
| **P5** `[A1b-fold]` | On B0 C011 saturated (L1) datasets, the Route-A perturbed refits land at the **analytic attractor movement**: $\hat\theta_3(c_n/2)=1.715161$, $\hat\theta_3(2c_n)=1.466704$ to 4 dp (A1b Task 4.4), giving $|\hat S_3|=0.1792$ raw; the refusal $s_3\ge1$ then fires iff $\mathrm{se}_{\text{penalised},3}<0.179$, which B0 measures | the collapsed-model account of the pin is incomplete; re-open the bug branch before B1 |

P5 is the sharpest test this protocol owns: the fence's detector is predicted
**quantitatively, from theory, before a single Phase-B fit is run.**

### 5.5 The BCa ablation (behind two gates)

Literature gate first: settle route (iii)'s finite-difference-to-$\hat a$ conversion against
Efron (1987 §6) and Hall (1992 ch. 3); if it cannot be settled, the arm is **dropped and
reported as dropped**. Scope: $\pi\in\{0.03,0.97\}$ × {logit, cloglog} ×
$n_{\text{site}}\in\{24,48,96\}$ = 12 cells, 200 datasets each; $K=3$ perturbation points at
$\hat\theta_j\pm0.5\,\mathrm{se}_j$, $B'=200$ ⇒ 600 extra refits/fit ⇒ **1.44 M fits**.
Promotion into the fallback chain only if calibrated BCa beats calibrated percentile by ≥2
of 12 cell PASSes **and** raises minimum cell coverage; otherwise A4 §Q5's neutrality
expectation is recorded as confirmed.

### 5.6 The gate (evaluated on H1 ∪ H2 ∪ H3 only, after the fence removes refused fits)

| # | Gate | Rationale |
|---|---|---|
| G1 | ≥90% of hold-out cells PASS {Wilson 90% $\subset[0.92,0.98]$} at $n=600$, escalated per §2.5 | the campaign's own frozen gate |
| G2 | **no** hold-out cell coverage < 0.90 | absolute floor; the C011-class guard — non-negotiable |
| G3 | interval availability ≥0.95 per hold-out cell among non-refused fits | the campaign's availability gate |
| G4 | refusal rate ≤0.10 in well-identified anchors ($\pi=0.50$, largest $n_{\text{site}}$) | usability does not bend (D-139) |
| G5 | every fitted $\gamma_k$ carries its registered sign | the mechanism must survive its own test |

**If the gate fails:** the construction is not promoted; Design 88's point-only fence stands;
the result is written up as a negative result (Design 117 §6.3's standard).

### 5.7 Stopping rule

1. **No refitting on hold-out. Ever.** Hold-out blocks are read once.
2. The calibration split may be re-used **at most once**, only after a written deviation
   note; used hold-out blocks are then retired and a fresh hold-out (fresh seeds, fresh
   declaration) generated before any second gate evaluation.
3. Second failure ⇒ stop: ship Design 117 §6.1's penalty-sensitivity reporting alone
   (*"worth shipping whatever §6.3 concludes"*), keep intervals fenced, publish the negative
   result.
4. B0 probe-gate failure (§5.3) ⇒ stop before B1: a calibrator behind a non-detecting fence
   would ship intervals on C011-class estimates.

---

## 6. Compute request

### 6.1 Unit cost

Per outer dataset (measured from the archive: 1,159,993 trace rows / 12,000 outer fits ≈
96.7 constrained refits; 500 bootstrap refits): $1+2+{\approx}97+500\approx600$
fit-equivalents (≈100 for the C-ID arms, which carry no bootstrap).

### 6.2 Budget (fit-equivalents)

| Component | Cells | Reps | Fits/rep | Fits |
|---|---:|---:|---:|---:|
| B0 probe validation | 12 | 200 | 3 | 0.007 M |
| C-core + C-q2 + hold-out (bootstrap-bearing) | 96 | 600 | 600 | 34.56 M |
| C-ID1 + C-ID2 (no bootstrap) | 36 | 600 | 100 | 2.16 M |
| Hold-out escalation (assume ~20% of 44 cells, +1400 reps) | ~9 | 1400 | 600 | 7.39 M |
| BCa ablation | 12 | 200 | 600 | 1.44 M |
| **Total (full)** | **132** | | | **≈45.6 M** |

≈6.4× the 2026-08-14 campaign (≈7.2 M). **Reduction option (D2, Shinichi's call):**
bootstrap a pre-declared 1/3 of datasets per bootstrap-bearing cell, saving 19.2 M ⇒
**≈26 M**; cost: the *fallback's* own coverage is estimated at $n=200$/cell (Wilson ≈±0.025)
and the documentation must say so.

### 6.3 What B0 must measure before launch (D-139: estimate before you run)

Seconds-per-fit at each grid corner (converting fit-counts to core-hours), exact
$p_{\text{free}}$ counts (freezing the C-ID arms), the probe ROC + Route A/B agreement, and
predictions P2/P5. **The full B1/B2 launch request returns to Shinichi with those numbers
attached; nothing beyond B0 runs on this packet's signature alone.**

### 6.4 Placement

B0 (7,200 fits + corner timing) on **Totoro** (≤150 cores, `OPENBLAS_NUM_THREADS=1`,
D-143). B1/B2 (the ≥26 M campaign) as **DRAC job arrays**, one seed per
`$SLURM_ARRAY_TASK_ID`, keepers to `/project`; never GitHub Actions (D-50; Design 88:
*"Simulation campaigns run on Totoro or DRAC, never GitHub Actions"*).

---

## 7. Prerequisites (bounded code changes, each with its own gate)

### 7.1 `mspl_c_n_multiplier` (enables the §1.2 probe)

`c_n` is computed **inside** C++ at `src/gllvmTMB.cpp:3056` from `DATA_INTEGER(N_eff)` and
`DATA_INTEGER(p_free)`, both fail-closed-validated at lines 1095–1097 — the probe cannot be
run by perturbing existing inputs. Change: one additive `DATA_SCALAR(mspl_c_n_multiplier)`
(default 1.0) multiplying `mspl_c_n`. **Bit-identity gate:** at multiplier = 1.0 the
objective, gradient, and every `REPORT`ed MSPL quantity must be bit-identical to the current
tape. **Lane note (D6/D-87):** `src/gllvmTMB.cpp` is currently touched by live cursor/codex
MSPL lanes (preflight 2026-08-15); the implementing lane is Shinichi's assignment, not this
packet's.

### 7.2 Profile bracket-search fixes (repairs the diagnosed availability defect)

Per A1 §Q6, all 205 profile-unavailable rows report `centre=matched` with one-sided
bracket-search failures (C003: 55/55 `lower=crossed`/`upper=truncated`; C010:
`refinement_failed`/`optimizer_failed`/`truncated`). Fix the root-finder and **widen the
stored bracket** to thresholds $[0.354,3.317]$ (§3.4). Gate: each defect gets a test proven
to fail against the unfixed code; prediction P1 then measures the repair at scale.

### 7.3 What is deliberately NOT a prerequisite `[A1b-fold]`

Under the INTRINSIC verdict there is **no estimator fix, no penalty retuning, and no
re-measurement of the three undercoverage cells as a bug regression**. Any $c_n$ or
penalty-form change relocates every count-attractor and would force a full grid re-run
without recovering the truth (A1b Tasks 4.4, 5.3). The pocket is a fence, not a tuning
target.

---

## 8. Deviations ledger

Binding rule: thresholds, gates, model-selection rules, grid, and hold-out declarations
above are fixed. Any future change is recorded here as a dated deviation naming what
changed and the measurement that forced it. **(empty)**

| Date | Deviation | Forcing measurement | Approved by |
|---|---|---|---|
| — | — | — | — |

---

## Appendix — UNVERIFIED register (carried into Phase B)

| Claim | Where | What settles it |
|---|---|---|
| Route (iii)'s finite-difference-to-$\hat a$ conversion | §3.3, §5.5 | Efron (1987 §6), Hall (1992 ch. 3) primaries — the arm's literature gate |
| $\hat a_{\text{boot-skew}}$ ≡ canonical $\hat a$ | §3.3 | DiCiccio & Efron (1996 §2–3); until then exploratory only |
| `brglm2::confint.brglmFit()` still exposes `ci.method = "union"` | §3.3 | `?confint.brglmFit` in R |
| Latent-design separation caught by neither fence line | §1.3 | LP test on the augmented design incl. fitted LVs (Design 117 §7) |
| $p_{\text{free}}\approx2T$ at ordinary $q=1$, hence the C-ID $c_n$ values | §2.2, §5.1 | exact counts off a real fit at B0, before the grid freezes |
| $\mathrm{se}_{\text{penalised},3}$ at the C011 attractor (< 0.179 ⇒ probe fires) | §5.4 P5 | B0 measures it directly |
| A1b's minority non-collapsed-branch attractor account | A1b Task 4 | AGENT-INFERRED, immaterial to the verdict; optional B0 confirmation refit |

## References

- Kosmidis I, Firth D. 2021. *Biometrika* 108:71–82 (verified against arXiv:1812.01938v4; A2).
- Sterzinger P, Kosmidis I. 2023. *Statistics and Computing* 33:53 (partially checked; A2).
- Efron B. 1987. *JASA* 82:171–185; Hall P. 1992. *The Bootstrap and Edgeworth Expansion*;
  DiCiccio TJ, Efron B. 1996. *Statistical Science* 11:189–228 (per A4; gate-bearing).
- Rainey C. 2016 (via Design 117 §6.1); Kosmidis I. 2007 (union CI, via `brglm` docs; A2 §Q4).
- `docs/design/88-binary-mspl-estimator.md` (the estimator; owns the objective and fences);
  `docs/design/117-separation-estimability-programme.md` (the programme; §6.2 now points here);
  `docs/design/35-validation-debt-register.md` §16 (MSPL-04 `blocked` until the §5.6 gate passes).
