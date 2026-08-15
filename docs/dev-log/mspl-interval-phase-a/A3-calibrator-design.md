# A3 — Design of the simulation-calibrated interval for `estimator = "mspl"`

Slice A3 of the approved ultra-plan. **READ-ONLY design work: this document specifies, it does
not implement.** It is written to be pre-registered by A5 as it stands. Every threshold,
functional form, model-selection rule, hold-out block, and gate below is fixed **before** Phase B
runs. If Phase B data forces a change, that change is reported as a **deviation** with the
measurement that forced it — never silently absorbed.

**Inputs read in full:** `A1-mechanism-partition.md`, `A2-kosmidis-firth-primary.md`,
`A4-bca-simulated-acceleration.md`. **Repo context read:**
`docs/design/117-separation-estimability-programme.md` §§2, 4, 6.1, 6.2, 7;
`git show origin/main:docs/design/88-binary-mspl-estimator.md` (full);
the committed campaign adjudication at
`/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB/docs/dev-log/simulation-artifacts/2026-08-14-mspl-coverage-calibration-production/`
(`README.md`, `production-receipt.txt`, `method-summary.tsv`, `case-summary.tsv`).
**Source inspected for feasibility of the S1 probe:**
`/Users/z3437171/.codex/worktrees/8e9d/gllvmTMB/src/gllvmTMB.cpp` (lines 571–576, 1088–1097,
3037–3115) and `R/mspl.R` (lines 1000–1075), on branch `codex/lane-b-mspl-interval-feasibility`.

**Standing campaign constraint, quoted from the campaign's own README and binding on Phase B:**
*"this campaign must not be used to tune a method on the same seeds."* Everything below therefore
uses the 2026-08-14 archive **only for labels, definitions, and effect sizes**, never as fitting
data for the calibrator.

**Notation.** $Q_{LA}(\theta;c)=\ell_{LA}(\theta)+c\,P(\theta)$ with
$P=\tfrac12\log\det(X_*^{\mathsf T}W_g(\beta)X_*)-V_{\text{loading}}-V_{\text{covariance}}$ and
$c=c_n=2\sqrt{p_{\text{free}}/N_{\text{eff}}}$ (Design 88, *Symbolic estimator*).
$\hat\theta(c)=\arg\max_\theta Q_{LA}(\theta;c)$, $\hat\theta:=\hat\theta(c_n)$.
$H:=-\nabla^2_\theta Q_{LA}(\hat\theta;c_n)\succ0$ is the penalised observed information.
$\theta_j$ indexes a scalar target (a fixed-effect coordinate in the measured campaign).

---

## S1 — THE FENCE: detect-and-refuse for penalty-determined estimates

### S1.0 Why a fence and not a calibration

A1 §Q2 establishes that the catastrophic cell C011 (cloglog × high\_prevalence) is a **location**
failure: target 3's interval midpoint sits $-8.26$ empirical SDs from truth while its width is
*larger* than the nominal reference (`width_over_sd` 6.13 vs 3.92), and `mean_estimate` is
identical to six decimal places between the `bootstrap` and `profile` methods because both report
the same outer MSPL point. **No level map $\alpha\mapsto\alpha^*$ moves a centre.** A1 §Q3 makes
the same point arithmetically from the other side: C011 would require $\alpha^*\in[0.40,0.74]$,
3–7× the $[0.10,0.18]$ that covers ~20 of the 26 ordinary overcovering cells. C011-class estimates
are **refused, not calibrated**. This is not softened anywhere below.

### S1.1 The mechanism, and the statistic it implies

Design 88's own finiteness proof names the mechanism: *"Along every divergent fixed-effect
direction, all supported expected-information weights vanish on the affected tails; Cauchy–Binet
and full rank then give $\log\det(X_*^{\mathsf T}W_gX_*)\to-\infty$."* For cloglog,
$w(\eta)=a^2/(e^a-1)$ with $a=e^\eta$, which collapses super-exponentially as $\eta\to+\infty$ —
so under high prevalence the Jeffreys term supplies a strong downward force on $\eta$ exactly
where the likelihood is nearly flat. **The coercion that guarantees finiteness is the same
coercion that produces C011's attractor at $b_{\text{fix},3}=1.5964$** (A1 §Q5: 929/1000 outer
fits, to $\pm10^{-4}$; ranked by link 92.9% cloglog > 48.4% probit > 7.1% logit). This is
Design 117 §6.1's *"in the separated direction the likelihood is flat and the answer is the
prior"* (Rainey 2016), made concrete for this estimator.

That mechanism has an exact first-order signature. Differentiating the stationarity condition
$\nabla\ell_{LA}(\hat\theta(c))+c\,\nabla P(\hat\theta(c))=0$ with respect to $c$ and using
$c\nabla P(\hat\theta)=-\nabla\ell_{LA}(\hat\theta)$ at the optimum:

$$
S \;:=\; \frac{\partial\hat\theta}{\partial\log c}\;=\;\big[\nabla^2 Q_{LA}\big]^{-1}\nabla\ell_{LA}(\hat\theta)\;=\;-\,H^{-1}\,\nabla\ell_{LA}(\hat\theta).
$$

**The penalty sensitivity is the curvature-normalised un-penalised score at the penalised
optimum.** If the penalty did not move the estimate, $\nabla\ell_{LA}(\hat\theta)=0$ and $S=0$.
If the penalty is actively holding the estimate against a live likelihood pull — the C011
situation — $S$ is large. Orders of magnitude: in a data-determined coordinate
$H=O(N_{\text{eff}})$ and $c_n\nabla P=O(c_n)=O(\sqrt{p/N})$, so $S=O(N^{-1/2}\cdot N^{-1/2})$;
in a penalty-determined coordinate where $\|\nabla\ell_{LA}\|$ decays like $e^{-\eta}$ against a
polynomial $\nabla P$, $\hat\theta\approx-\log c_n+\text{const}$ and $|S|=O(1)$ **in raw
parameter units**, which is many standard errors. The sign also checks out against A1: at C011,
the likelihood pulls $\eta$ up (toward and past truth 2.05), the Jeffreys term pushes down, so
$\nabla\ell_{LA}(\hat\theta)>0$ and $S<0$ — increasing $c_n$ lowers $\hat\theta_3$, which is the
observed direction of the bias.

### S1.2 The probe — two computations, one shipped

**Per-target statistic (the pre-registered definition).**

$$
\hat S_j \;=\; \frac{\hat\theta_j(2c_n)-\hat\theta_j(c_n/2)}{\log 4},
\qquad
s_j \;=\; \frac{|\hat S_j|}{\sqrt{(H^{-1})_{jj}}}
$$

$s_j$ is dimensionless and reads directly as **"standard errors of movement per e-fold change in
penalty strength."** The denominator is the model-based penalised standard error, which is what
exists at fit time; note that in a pinned cell this SE is itself compressed (A1 §Q2:
`sd_estimate` 0.084 at C011 target 3 vs 0.29 at target 1), so the denominator works in the
fence's favour rather than against it.

**Route A — finite-difference probe (2 extra outer refits per fit).** Refit at $c_n/2$ and
$2c_n$, warm-started from $\hat\theta$ so the measured movement is the movement of the *same*
local optimum rather than a jump between modes. Cost: $3\times$ the point-estimate cost. This is
negligible against the interval machinery it gates (≈97 profile trace refits and 500 bootstrap
refits per fit; see S5.6) and is robust to a non-quadratic surface — which is precisely the
regime it must work in.

**Route B — curvature surrogate (≈zero extra cost).** $\hat S^{\text{surr}}=-H^{-1}\nabla\ell_{LA}(\hat\theta)$.
Both ingredients already exist under Design 88's discharged obligations: the *"penalty-off Laplace
decomposition"* obligation states *"A second ML tape is evaluated at the MSPL outer point"*, so
$\nabla\ell_{LA}(\hat\theta)$ is one AD gradient call on a tape the fit already builds; and $H$ is
the same penalised Hessian the campaign's Wald route already forms and PD-checks. The surrogate is
a strict first-order local approximation and is least trustworthy exactly where the surface is
flat.

**Weighing cost against reliability — the pre-registered choice.** **Route A is the shipped
detector.** Route B is computed alongside it on every Phase-B fit so their agreement is measured.
Pre-registered switch rule, decided once on the B0 label set and never revisited on hold-out:
*ship Route B instead of Route A only if Route B attains detection and false-refusal rates within
0.02 of Route A at the same threshold and $\mathrm{corr}(\log|\hat S|,\log|\hat S^{\text{surr}}|)\ge0.95$.*
Otherwise Route A ships and Route B is reported as a diagnostic only.

**Implementation prerequisite (verified in source, not assumed).** `c_n` is computed **inside**
C++ at `src/gllvmTMB.cpp:3056` from `DATA_INTEGER(N_eff)` and `DATA_INTEGER(p_free)`, and both are
fail-closed-validated at lines 1095–1097 against `y.size()` and the resolved design. **The probe
therefore cannot be run by perturbing existing data inputs** — it requires one additive
`DATA_SCALAR(mspl_c_n_multiplier)` (default `1.0`) multiplying `mspl_c_n`. Identity gate for that
change: at multiplier $=1.0$ the objective, gradient, and every `REPORT`ed MSPL quantity must be
**bit-identical** to the current tape. This is a small, bounded, verifiable B0 prerequisite and
changes nothing at the default.

### S1.3 The refusal rule

Three tiers, per target, on a scale anchored to **interpretation** rather than to the archive —
which is what makes them pre-registerable:

| Tier | Rule | Meaning | Consequence |
|---|---|---|---|
| `data_determined` | $s_j<0.25$ | penalty moves the estimate less than a quarter SE per e-fold | interval reported |
| `penalty_influenced` | $0.25\le s_j<1.0$ | material but sub-SE movement | interval reported, flagged |
| `penalty_determined` | $s_j\ge1.0$ | **halving/doubling the penalty moves the estimate by more than its own uncertainty** | **interval refused** |

$1.0$ and $0.25$ are fixed a priori by that reading of the statistic. Phase B **measures the
operating characteristics of this fixed rule**; it does not choose the rule. If B0 shows the fixed
thresholds have unacceptable operating characteristics (S5.4's probe gate), that is a **deviation**,
reported with the full measured ROC, and any revision happens **once**, on the calibration split,
never on hold-out.

**Three additional, independent refusals — belt and braces:**

1. **Structural (separation screen).** If Design 88's B0 `detectseparation` screen returns
   `complete` or `quasi_complete` for a block, intervals for the affected `infinite_terms` are
   refused unconditionally, whatever $s_j$ says. This is the region A2 §Q1/§Q3 shows is
   guaranteed to fail *"regardless of the nominal level"* (Kosmidis & Firth 2021, §2.2, p. 5), and
   A2 §Q2 confirms the guarantee **survives profiling** — *"also true when the penalized likelihood
   is profiled"*.
2. **Non-convergence of a probe refit.** If either perturbed refit fails to converge, refuse
   (fail-closed, consistent with Design 88's style).
3. **Calibrator out-of-range.** If the S2 map returns $\alpha^*$ at a clip boundary
   (S2.5), refuse. Because the clip is set at $0.40$ and A1 §Q3 measured C011's requirement at
   $\alpha^*\in[0.40,0.74]$, **this catches C011-class cells even if the $s_j$ probe misses them.**

**Known blind spot, stated rather than buried.** In *deep* separation the likelihood is
asymptotically flat and $\nabla\ell_{LA}(\hat\theta)\to0$, so $s_j\to0$ **despite the estimate
being entirely penalty-determined**. The probe under-detects exactly at the limit. This is why
refusal 1 is not redundant: the `detectseparation` screen catches the flat limit on the fixed
design; the $s_j$ probe catches the intermediate near-separation band where the penalty is holding
the estimate against a live pull. **Residual uncovered gap:** deep separation that exists only in
the *estimated latent* design — Design 117 §7's open research question — is caught by neither.
Marked **UNVERIFIED**; what would settle it is re-running the LP separation test on the augmented
design including fitted LVs, which Design 117 §7 states is cheap and post-fit.

### S1.4 What the user sees

Per Design 117 §6.1, the sensitivity number is reported for **every** estimate; refusal is simply
the top tier of the same report.

- A `penalty_sensitivity` table on every MSPL fit: `term`, `estimate`, `se_penalised`,
  `estimate_half_cn`, `estimate_double_cn`, `d_per_efold` ($\hat S_j$), `sensitivity` ($s_j$),
  `class`.
- `confint()` returns intervals for `data_determined` and `penalty_influenced` rows (the latter
  carrying a flag column), and `NA` for `penalty_determined` rows, with a single typed warning of
  class `gllvmTMB_mspl_penalty_determined` naming them and quoting $s_j$ and the threshold.
- If every target refuses, a typed **error**, matching Design 88's existing fail-closed contract.
- The print method surfaces the count: *"3 of 12 fixed-effect estimates are penalty-determined;
  intervals for those are not reported."*
- The message says what the number means, not just that it failed: *the estimate moved 4.2 SE when
  the penalty strength was halved and doubled — this number is the penalty's, not the data's.*

### S1.5 Can the probe be validated against the existing archive? **Partly — labels yes, statistic no.**

- **The statistic: NO.** A4 §Q4 confirms at file level that every key in the four raw files is at
  `cluster/case/outer/shard/attempt` grain and **never below it**; A1 §Q4 confirms
  `outer-fit-rows.csv` carries only `seed, status, convergence, objective, b_fix_1..3,
  elapsed_seconds, message`. There are **no gradients, no Hessians, and no refits at perturbed
  $c_n$** anywhere in the archive. $s_j$ cannot be computed retrospectively by any re-expression.
- **The labels: YES, at zero cost.** The archive fixes the disease label operationally. A1 §Q5
  gives the modal attractor values and the per-cell pinning rates (C011 $b_{\text{fix},3}$ pinned
  to $1.596400\pm10^{-4}$ in 92.9% of fits; C007 to $2.3629$ in 48.4%; C003 to $2.2761$ in 7.1%).
  Pre-registered **fit-level** label: *a fit is diseased in coordinate $j$ if $|\hat\theta_j-m_{cj}|<10^{-4}$,
  where $m_{cj}$ is the modal value of coordinate $j$ in cell $c$.* This is a per-fit label, not a
  cell-level one, so it supports a genuine per-fit ROC.
- **Therefore the probe is validated in B0 at small cost:** re-simulate the same 12 published DGP
  cells with **fresh seeds** (mandatory — see the campaign README constraint quoted at the head of
  this document), 200 datasets each, computing both probe routes and the label.
  **Cost: $12\times200\times3=7{,}200$ fits, no bootstrap, no profiling.** The C011 pinning is
  known, so the probe's detection rate on C011 versus the healthy cells is directly measurable.

**Registered prediction P2 (falsifiable at B0):** median $s_3$ orders across links at high
prevalence as cloglog > probit > logit, matching A1 §Q5's 92.9% / 48.4% / 7.1% pinning gradient.
If it does not, the mechanistic story in S1.1 is wrong and the fence must be redesigned.

---

## S2 — THE CALIBRATOR: the prepivoting map $\alpha\mapsto\alpha^*(v)$

### S2.1 What is being calibrated

The construction is evaluated not at the nominal level $\alpha=0.05$ but at a data-dependent level
$\alpha^*(v)$ chosen so that the realised coverage of the resulting interval is $0.95$. For the
penalised profile this means replacing the deviance threshold $\tfrac12\chi^2_1(1-\alpha)$
(measured constant $1.920729410347059$, A1 §Q3) by $\tfrac12\chi^2_1(1-\alpha^*)$; for the
percentile bootstrap it means taking the $\alpha^*/2$ and $1-\alpha^*/2$ empirical percentiles.
This is a **prepivoting** map in Beran's sense — a monotone reparameterisation of the nominal
level, not a change of the construction — which is why both constructions can carry the same
functional form.

### S2.2 The observable set $v$ — named honestly

All fit-time; **nothing depends on the true parameter.**

| # | Observable | Grounding |
|---|---|---|
| 1 | `link` ∈ {logit, probit, cloglog} | mechanistically graded, A1 §Q5 |
| 2 | prevalence extremeness $\pi_{\max}=\max_t\max(\hat p_t,1-\hat p_t)$, and $m_{\min}=\min_t\min(\#1_t,\#0_t)$ | A1 §Q3–Q4: `beta_shift` is the strongest continuous predictor ($p=0.019$); $\hat p_t$ is its fit-time analogue. **Both tails**, per Design 117 §2 |
| 3 | $c_n=2\sqrt{p_{\text{free}}/N_{\text{eff}}}$ | the penalty strength itself; the mechanistically relevant scalar |
| 4 | $\log N_{\text{eff}}$, $p_{\text{free}}$ | asymptotic axis; also needed to break the collinearity in #3 |
| 5 | separation-screen status ∈ {clean, quasi\_complete, complete} + `n_infinite_terms` | Design 88 §5 |
| 6 | $s_j$ — the S1 sensitivity statistic | A1 §Q4: *"No observable in the provided files distinguishes 'this cell is fine' from 'this cell is C011' at fit time."* $s_j$ is designed to be that observable |
| 7 | standardised magnitude $\|\hat\theta_j\|/\mathrm{se}_j$ | the fit-time proxy for A2's *"parameter vector with large enough components"* |
| 8 | `q`, `structure` | envelope keys (S4), not free calibrator terms unless varied |

### S2.3 What Phase B **must vary** for the map to be identifiable

A1 fact 2 is decisive: the campaign held $N_{\text{eff}}$, $p_{\text{free}}$ and $c_n$ **constant**
(one $24\times3$ fixture), so **no calibrator indexed on them can be fitted from the archive at
all.** Mandatory variation:

1. **$N_{\text{eff}}$, via number of sites** — five levels (S5.1). Without this, terms 3 and 4 are
   unidentified.
2. **Prevalence, continuously and on both tails** — seven levels spanning $\pi\in[0.03,0.97]$.
   Design 117 §2: *"A grid that stops at 0.5 finds half the effect and reports it as the whole."*
3. **All three links.**
4. **$p_{\text{free}}$ decoupled from $N_{\text{eff}}$ — mandatory, and the reason is specific.**
   For ordinary MSPL, `R/mspl.R:1036` gives $p_{\text{free}}=p_\beta+|\theta_{rr,B}|$ with
   $p_{\text{covariance}}=0$, i.e. $p_{\text{free}}\approx 2T$ for $T$ traits at $q=1$, while
   $N_{\text{eff}}=n_{\text{site}}\cdot T$. Hence
   $$c_n \;=\; 2\sqrt{p_{\text{free}}/N_{\text{eff}}}\;\approx\;2\sqrt{2/n_{\text{site}}},$$
   **a function of $n_{\text{site}}$ alone.** A grid that varies only $n_{\text{site}}$ at fixed
   $T$ therefore traces a one-dimensional curve on which $c_n$ and $N_{\text{eff}}$ are perfectly
   confounded and cannot be separated. Two dedicated arms fix this (S5.1 blocks C-ID1, C-ID2):
   one holds $N_{\text{eff}}$ fixed while $c_n$ varies, the other holds $c_n$ fixed while
   $N_{\text{eff}}$ varies. **Without these two arms the S2 map is not identifiable and Phase B
   answers a different question than the one asked.**
5. **$q\in\{1,2\}$** — Design 88 admits `latent(d = 1:2)`. If $q$ is not varied, $q=2$ is outside
   the shipped envelope (S4).

### S2.4 Functional form — simple, monotone, theory-anchored

Work on the logit scale of the level, which guarantees $\alpha^*\in(0,1)$ and makes each linear
term monotone:

$$
\operatorname{logit}\alpha^*(v)\;=\;\operatorname{logit}\alpha\;+\;h(v),
\qquad
h(v)\;=\;\gamma_0+\gamma_1 g_1(v)+\gamma_2 g_2(v)+\gamma_3 g_3(v)+\boldsymbol{\gamma}_4^{\mathsf T}g_4(v).
$$

Pre-registered ladder, fitted **strictly in this order**, each rung admitted only on the rule in
S2.5:

| Model | $h(v)$ | Why here, in this position |
|---|---|---|
| **M0** | $0$ (no calibration) | the comparator. **If M0 passes the gate, ship nothing.** |
| **M1** | $\gamma_0$ | A1 §Q3: a single global shift plausibly covers ~20/26 known overcovering cells, which cluster at $\alpha^*\in[0.10,0.18]$ regardless of link/regime once C011 is set aside. $\alpha^*\approx0.14$ ⇒ $\gamma_0\approx+1.13$. **Start here.** |
| **M2** | M1 $+\;\gamma_1 c_n$ | $g_1=c_n$, chosen so the correction **vanishes as $c_n\to0$**: Sterzinger & Kosmidis (2023) scale the soft penalty precisely so it becomes asymptotically negligible and first-order asymptotics are restored, so $\alpha^*\to\alpha$ is the theory-required limit. Registered sign $\gamma_1\ge0$. |
| **M3** | M2 $+\;\gamma_2\log\!\big(\pi_{\max}/(1-\pi_{\max})\big)$ | A1 §Q3–Q4: regime is the strongest measured term ($F=5.26$, $p=0.0021$); $\beta_{\text{shift}}$ continuous $p=0.019$. Registered sign $\gamma_2\ge0$. |
| **M4** | M3 $+\;\gamma_3\log(1+s_j)$ | the mechanistic bridge from S1: the more penalty-determined, the more the level must move. Registered sign $\gamma_3\ge0$. |
| **M5** | M4 $+$ link main effect (2 df) | **last**, because A1 §Q3 shows link's apparent excess was supplied entirely by C011 — which is refused, not calibrated. Once C011 is set aside, cloglog's remaining cells sit at $\alpha^*=0.100,0.108,0.114$, indistinguishable from logit's mean of $0.115$. |

**Registered sign constraints are load-bearing, not cosmetic.** A fitted $\gamma_k$ whose sign
contradicts the registered direction is a **failure of the mechanistic story**; the term is
**dropped**, and the contradiction is reported. Shipping a wrong-signed coefficient because it
improved fit is exactly the failure mode this pre-registration exists to prevent.

**One map or two?** Profile and percentile-bootstrap are different constructions with different
miscalibration (A1 §Q1: profile overcovers where bootstrap catastrophically undercovers, in the
*same* cells). Pre-register: fit **separate** $h_{\text{profile}}$ and $h_{\text{boot}}$, then test
whether a single shared $h$ suffices under the same admission margin. Simpler wins only if it
holds.

### S2.5 Model-selection rule, fitted in advance

- **Estimand is coverage, so fit to coverage.** Minimise
  $\sum_{\text{cells}} w_c\big(\widehat{\text{cov}}_c(\gamma)-0.95\big)^2$, where
  $\widehat{\text{cov}}_c(\gamma)$ re-evaluates the stored per-replicate interval at
  $\alpha^*(v;\gamma)$. Not a likelihood fit.
- **Selection by leave-whole-cells-out $K$-fold CV within the calibration split** ($K=8$, folds
  formed by cell, never by replicate — replicates inside a cell are not independent units of the
  calibration question).
- **Admission margin (fixed):** M$_{k+1}$ is admitted over M$_k$ only if it reduces the
  **out-of-fold maximum absolute cell coverage error** $\max_c|\widehat{\text{cov}}_c-0.95|$ by
  $\ge0.005$ **and** does not increase the mean absolute error. Ties go to the simpler model.
  **Stop at the first non-admission**; no skipping ahead to a later rung.
- **Clipping (fixed):** $\alpha^*$ is clipped to $[0.01,0.40]$. Lower bound: at $B=500$ bootstrap
  replicates the $0.5\%$ percentile is replicate $2.5$, the finest tail resolution that is
  defensible. Upper bound: A1 §Q3 measured C011's requirement at $\alpha^*\in[0.40,0.74]$, so
  **$0.40$ is the boundary between "conservatism to be calibrated" and "a location failure to be
  refused."** An $\alpha^*$ landing on either clip is a **refusal** (S1.3 refusal 3), not a
  clipped-and-reported interval.

### S2.6 Replicates per cell — making the gate decisive

The Wilson 90% two-sided half-width at $\hat p$, $n$, with $z=z_{0.95}=1.644854$:

$$
w(\hat p,n)\;=\;\frac{z}{1+z^2/n}\sqrt{\frac{\hat p(1-\hat p)}{n}+\frac{z^2}{4n^2}}.
$$

Solving $w(0.95,n)<0.015$: $n=579$ gives $w=0.015010$; $n=580$ gives $w=0.014997$. **The
requirement is $n\ge580$; Phase B registers $n=600$ replicates per cell** ($w=0.014744$).

**But the borderline class is a property of the band, not of $n$ — say so.** A1 §Q1 found 22 of 55
failures were borderline-by-Wilson-resolution-only; at $n=1000$ the half-width at $\hat p=0.95$ is
already only $0.0114$, so more replicates alone never removes the class. Any cell whose *true*
coverage lies in $[0.92,0.935]\cup[0.965,0.98]$ is a coin flip against a $\pm0.03$ equivalence
band. The honest fix is a **pre-registered three-way verdict** and a **one-shot escalation**:

| Verdict | Rule | Action |
|---|---|---|
| PASS | Wilson 90% CI $\subset[0.92,0.98]$ | — |
| FAIL | point estimate outside $[0.92,0.98]$ | — |
| INDETERMINATE | point inside, Wilson pokes out | **escalate that cell to $n=2000$, once** |

At $n=2000$, $w(0.95)=0.00804$ and $w(0.935)=0.00909$ (lower edge $0.9257>0.92$), so a cell with
true coverage $0.935$ resolves to PASS. **A cell still INDETERMINATE at $n=2000$ is recorded FAIL
(fail-closed).** The escalation is one-shot, pre-declared, and applied identically to gate cells
regardless of which way the first verdict leaned, so it cannot be gamed.

---

## S3 — THE INTERVAL CONSTRUCTION

### S3.1 Decision

> **Base construction: the level-calibrated penalised profile.** Declared fallback: the
> level-calibrated percentile bootstrap, used only on profile unavailability and flagged.
> **BCa-with-simulated-acceleration is *not* in the shipped default**; it enters Phase B as a
> pre-registered ablation arm in the skew regime only. The union CI is *not* shipped; it is
> computed as a Phase-B diagnostic so the claim "it does not help here" is measured, not asserted.

### S3.2 Why the penalised profile

1. **It is the best-measured route.** 24/36 joint gates vs bootstrap 20/36 vs Wald 9/36
   (`method-summary.tsv`).
2. **Its availability failures are an engineering defect, not a statistical one.** A1 §Q6: all 205
   profile-unavailable rows report `centre=matched` with a one-sided bracket-search failure
   (`lower=crossed`/`upper=truncated` for 55/55 of C003's; `refinement_failed` /
   `optimizer_failed` / `truncated` for C010's). The point was found; the root-finder was not.
   Fixable and verifiable.
3. **It re-levels exactly and cheaply.** Calibration is a change of the deviance threshold. The
   campaign already stores the trace (`profile-traces.csv`, 1,159,993 rows, with a `threshold`
   column measured at exactly $\tfrac12\chi^2_1(0.95)$), so **fitting the calibrator requires no
   refitting at all** provided the trace is stored densely and widely enough (S3.5).
4. **Decisive argument — it fails safe.** A1 §Q5 explains the two failure geometries: a flat ridge
   makes the profile travel far before crossing the threshold, producing a *wide* interval that
   still brackets truth (C011 profile targets 2 and 3 both at coverage 1.000); the bootstrap
   instead measures refit-to-refit dispersion, which is artificially small when 78–93% of refits
   collapse onto the same attractor, producing a *narrow* interval around a biased centre
   (coverage 0.010). **The base construction must be the one whose failure mode is over- rather
   than under-coverage**, because S1+S2 can handle conservatism and nothing rescues a narrow
   interval around a wrong centre.
5. **Calibration and the availability defect point the same way.** The dominant correction is
   $\alpha^*>\alpha$ (A1 §Q1: 26 over vs 6 under), i.e. a *lower* threshold —
   $\tfrac12\chi^2_1(0.86)=1.089$ against $1.921$ — so the crossing is nearer and bracket search
   succeeds more often. **Registered prediction P1 (falsifiable):** cell-by-cell profile
   availability under the calibrated $\alpha^*>0.05$ is $\ge$ availability at $\alpha=0.05$.
6. **A2 §Q2 is not an argument against profiling here.** Kosmidis & Firth's caveat *does* survive
   profiling — *"also true when the penalized likelihood is profiled"* — but it is an **existence**
   statement about extreme parameter regions (A2 §Q3: the paper is silent about the rest of the
   space). That region is handled by refusal (S1) and by the envelope (S4), not by the choice of
   construction. Profiling is chosen for its measured performance and its safe failure mode, and
   the shipped claim never asserts uniform validity.

### S3.3 Why percentile bootstrap is the fallback and not the base

36/36 availability — it never fails to produce an interval (`method-summary.tsv`:
`availability_min = availability_max = 1`). Its weakness is calibration, which is exactly what S2
addresses, and it re-levels for free from stored replicates. But its catastrophic mode is C011
(A1 §Q1: coverages 0.855 / 0.358 / **0.010**), which is why it cannot be the base: an unfenced
bootstrap is the construction that produced the worst number in the campaign.

### S3.4 Why BCa and the union CI do **not** earn a place in the default

**BCa (A4's route (iii)).** A4 §Q5 is explicit: BCa is *expected neutral* on the overcoverage bulk
(26 cells — a dispersion problem that reshuffling percentiles of the same over-dispersed replicate
distribution cannot fix), and targeted at boundary-skew undercoverage. After S1 refuses the three
C011 rows, the remaining addressable undercoverage is **three cells** (C007 target 2 at 0.879,
C009 target 3 at 0.906, C012 target 3 at 0.913). Against three cells stand two costs: (a) A4 §Q2
route (iii) marks the finite-difference-to-$a$ conversion formula **UNVERIFIED** — not derived from
a primary source in that pass; (b) route (iii) requires **per-fit perturbation resimulation**, on
the order of 600 extra refits per user fit (S5.5), which under D-139's usability principle is
disqualifying for a shipped default. **Therefore BCa is a pre-registered ablation arm, and it must
first clear a literature gate** (settle the conversion against Efron 1987 §6 and Hall 1992 ch. 3).
If that gate cannot be cleared, the arm is **dropped and reported as dropped**.
$\hat a_{\text{boot-skew}}$ (A4 route (ii)) is used only as a zero-cost exploratory diagnostic —
A4 §Q2 marks its equivalence to the canonical $a$ **UNVERIFIED** and it may not license a coverage
claim.

**Union CI (A2 §Q4's bonus route, Kosmidis 2007, `brglm`'s `ci.method = "union"`).** Two reasons
it is not the base. (a) It is *"slightly conservative"* by construction, and A1 §Q1 says the
dominant failure is already overcoverage 26-to-6 — it pushes the wrong way. (b) In the region it
was designed for, the ML profile is unbounded (that is what separation *means*), so the union
degenerates to an unbounded interval — which carries exactly the information S1's refusal already
carries, in a less usable form. It is nonetheless computed as a Phase-B diagnostic at near-zero
marginal cost, since the ML tape at the MSPL point is already built for the S1 surrogate.
**UNVERIFIED, carried from A2 §Q4:** whether current `brglm2::confint.brglmFit()` still exposes
`"union"` in the same form; settle by `?confint.brglmFit` in R before citing it as an adopted
construction.

### S3.5 Storage contract (this is what makes the calibrator fittable)

Per replicate per target, Phase B must store:

- the **full profile trace** over a bracket wide enough to support the whole clip range
  $\alpha^*\in[0.01,0.40]$, i.e. thresholds from $\tfrac12\chi^2_1(0.60)=0.354$ to
  $\tfrac12\chi^2_1(0.99)=3.317$. **The current bracket, built for $1.9207$, is too narrow at the
  small-$\alpha^*$ end and must be widened**;
- the **full bootstrap replicate vector** ($B=500$);
- $\hat\theta_j$, $\mathrm{se}_j$, both S1 routes' $\hat S_j$ and $s_j$, the two perturbed
  estimates, and the observable vector $v$;
- the separation-screen result and all convergence/PD flags.

Without this the calibrator cannot be fitted without re-running the campaign.

### S3.6 Availability contract

Evaluated in order, fail-closed at every step:

1. **S1 fence.** If `penalty_determined` (or any structural refusal): **no interval**; point
   estimate and sensitivity are still returned; typed condition.
2. **Calibrated penalised profile** at $\alpha^*(v)$, subject to the clip.
3. **If the profile is unavailable** after a fixed retry budget: calibrated percentile bootstrap at
   its own $\alpha^*_{\text{boot}}(v)$ (or the shared map if S2.4's shared-map test passes),
   **only if** the campaign's own $\ge475/500$ usable-refit floor is met. The result is flagged as
   a fallback.
4. **One-sided availability is not a two-sided interval.** A1 §Q6 shows the failures are one-sided.
   Pre-registered: **refuse** the two-sided interval; record the one-sided availability rate as a
   Phase-B outcome to inform a later, separately validated one-sided slice. Phase B validates
   two-sided coverage only.
5. **If both constructions fail:** refuse, typed condition.

---

## S4 — THE CLAIM BOUNDARY

### S4.1 The named regime envelope

A2 fact 3 forbids any claim of uniform validity. The claim is therefore scoped to an envelope
whose every key is **checkable at fit time**, and is fail-closed outside it. The envelope is the
intersection of Design 88's admitted contract with what Phase B actually measures:

| Axis | In the envelope | Outside ⇒ refuse |
|---|---|---|
| Family | complete, unweighted, single-trial Bernoulli | everything else (Design 88) |
| Link | logit, probit, cloglog — **all three measured, probit held out and re-validated** | any other |
| Structure | ordinary `latent(d = 1:2, unique = FALSE)` | **spatial is OUT** — the campaign was ordinary $q=1$ only and Phase B does not measure spatial |
| $q$ | $\{1,2\}$ **iff** the $q=2$ arm passes; else $\{1\}$ | $d>2$ (already fenced by Design 88) |
| Prevalence | realised, expressed as a fit-time floor: $m_{\min}=\min_t\min(\#1_t,\#0_t)$ within the measured range, both tails | beyond the measured range |
| Scale | $N_{\text{eff}}$ and $p_{\text{free}}$ within the measured rectangle, and $c_n$ within the measured range | beyond it |
| Estimability | separation screen clean **and** $s_j<1.0$ | otherwise refused per S1 |

Note the envelope is stated in **realised, observable** terms ($m_{\min}$, $c_n$, $N_{\text{eff}}$),
never in terms of true prevalence or true $\beta$ — nothing depends on the true parameter at fit
time.

### S4.2 The documentation paragraph (draft, for A5 to pre-register verbatim)

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

---

## S5 — WHAT PHASE B MUST MEASURE

### S5.1 Grid, and the hold-out declaration

Axes: link; target marginal prevalence $\pi$; $n_{\text{site}}$; traits $T$; $q$. Targets are three
trait-intercept coordinates chosen as the minimum-, median- and maximum-prevalence traits, which
generalises the campaign's `target1/2/3` and keeps the target axis interpretable as *distance from
the boundary*.

**Calibration blocks (88 cells):**

| Block | Definition | Cells |
|---|---|---:|
| C-core | link ∈ {logit, cloglog} × $\pi\in\{0.03,0.20,0.50,0.80,0.97\}$ × $n_{\text{site}}\in\{12,24,48,96\}$, $T=3$, $q=1$ | 40 |
| C-q2 | link ∈ {logit, cloglog} × $\pi\in\{0.03,0.50,0.97\}$ × $n_{\text{site}}\in\{24,96\}$, $q=2$ | 12 |
| **C-ID1** | **$N_{\text{eff}}$ fixed at 288, $c_n$ varying:** $(n_{\text{site}},T)\in\{(96,3),(48,6),(24,12)\}$ ⇒ $c_n\approx0.289,0.408,0.577$ × 2 links × 3 $\pi$ | 18 |
| **C-ID2** | **$c_n$ fixed, $N_{\text{eff}}$ varying:** $n_{\text{site}}=48$, $T\in\{3,6,12\}$ ⇒ $N_{\text{eff}}=144,288,576$ at $c_n\approx0.408$ × 2 links × 3 $\pi$ | 18 |

C-ID1 and C-ID2 are **not optional**: per S2.3 item 4, without them $c_n$ and $N_{\text{eff}}$ are
perfectly confounded and terms M2/M4 are unidentifiable.

**Hold-out blocks (44 cells) — declared here, BEFORE any fitting; never used for coefficient
fitting, model selection, or threshold tuning:**

| Block | Tests | Definition | Cells |
|---|---|---|---:|
| **H1 (link)** | generalisation across links | **all probit cells**: 5 $\pi$ × 3 $n_{\text{site}}\{24,48,96\}$ + 3 probit $q=2$ | 18 |
| **H2 (regime)** | generalisation to unseen prevalence | $\pi\in\{0.08,0.92\}$ × 2 links × 4 $n_{\text{site}}$ | 16 |
| **H3 (scale)** | **extrapolation in $N$**, the axis the shipped claim most needs | $n_{\text{site}}=192$ × 2 links × 5 $\pi$ | 10 |

**Hold-out rule (fixed):** hold-outs are **whole blocks defined by a design axis**, never random
cells. H1 is a complete link. H2 is complete prevalence levels **at both tails** (Design 117 §2).
H3 is a complete scale level. Seeds are disjoint from the calibration split and from the 2026-08-14
archive.

*Rationale for holding out probit specifically:* probit sits in the middle of A1 §Q5's pinning
gradient (48.4%, between cloglog's 92.9% and logit's 7.1%), so predicting it from logit and cloglog
is the sharpest available test of whether the calibrator's link handling is **mechanistic rather
than memorised**. Holding out cloglog instead would be an extrapolation whose failure would be
acceptable (cloglog at high prevalence is the region the fence refuses anyway) and therefore a
weaker gate.

**Replicates:** 600 per cell (S2.6), escalating **once** to 2000 for INDETERMINATE **hold-out gate
cells only** — calibration cells need a continuous fit, not a per-cell verdict, so they are not
escalated. Bootstrap $B=500$ with the campaign's $\ge475$ usable floor.

### S5.2 Phase order (so the stopping rule can fire before the budget is spent)

**B0** (probe + timing + prerequisites) → **B1** (calibration blocks; fit and select the map) →
**freeze the map** → **B2** (hold-out blocks; evaluate the gate). B2 is not launched until the map
is frozen and written down.

### S5.3 B0 — prerequisites and the probe validation

1. Implement `DATA_SCALAR(mspl_c_n_multiplier)`; **bit-identity gate at multiplier $=1.0$**.
2. Widen the profile bracket to span $[0.354, 3.317]$ in threshold (S3.5) and fix the diagnosed
   root-finding failures (A1 §Q6).
3. **Time a fit at each grid corner** — D-139 requires an estimate before a >30-min run, and B0 *is*
   the pre-run test. The campaign budget below is in fit-counts precisely because B0 owes the
   seconds-per-fit number.
4. **Probe validation:** re-simulate the 12 published DGP cells with **fresh seeds**, 200 datasets
   each, computing Route A, Route B, and the fit-level pinning label from S1.5.
   **Cost $12\times200\times3=7{,}200$ fits.**

**Pre-registered probe gate (S5.7 stopping rule applies):** at the fixed threshold $s_j\ge1.0$,
Route A must attain **detection $\ge0.90$** on labelled-diseased C011 target-3 fits and
**false-refusal $\le0.05$** on the well-identified anchors C001/C004/C005/C008 (baseline and
strong\_signal). Also reported: the full ROC, P2 (S1.1's link ordering), and the Route A / Route B
agreement that decides the switch rule in S1.2.

### S5.4 Registered predictions (falsifiable, recorded before running)

| # | Prediction | If it fails |
|---|---|---|
| **P1** | Cell-by-cell profile availability at the calibrated $\alpha^*>0.05$ is $\ge$ availability at $\alpha=0.05$ | the availability defect is not the bracket-search geometry diagnosed in A1 §Q6, and S3.2 item 5 is wrong |
| **P2** | Median $s_3$ orders cloglog > probit > logit at high prevalence, matching the 92.9/48.4/7.1% pinning gradient | S1.1's mechanism is wrong; the fence must be redesigned before B1 |
| **P3** | The $\alpha^*$ required by a cell is monotone increasing in that cell's median $s_j$ | the fence and the calibrator are not measuring the same underlying quantity; M4 is dropped |
| **P4** | $\alpha^*\to\alpha$ as $c_n\to0$ across the C-ID2 arm | the Sterzinger & Kosmidis (2023) soft-scaling rationale for M2 does not hold empirically here; M2's anchoring is void and the map must not be extrapolated in $N$ |

### S5.5 The BCa ablation

- **Literature gate first.** Settle A4 §Q2 route (iii)'s finite-difference-to-$\hat a$ conversion
  against Efron (1987 §6) and Hall (1992 ch. 3). If it cannot be settled, **the arm is dropped and
  reported as dropped** — no BCa interval is computed from an unverified conversion.
- **Scope:** a pre-declared **skew regime** subset — the two most extreme prevalence levels
  ($\pi\in\{0.03,0.97\}$) × {logit, cloglog} × $n_{\text{site}}\in\{24,48,96\}$ = **12 cells**,
  200 datasets each.
- **Design:** $K=3$ perturbation points at $\hat\theta_j\pm\delta$, $\delta=0.5\,\mathrm{se}_j$,
  with $B'=200$ refits each ⇒ **600 extra refits per fit**.
  **Cost $12\times200\times600=1{,}440{,}000$ fits.**
- **Comparison (pre-registered):** calibrated BCa vs calibrated percentile, on the same replicates,
  in those 12 cells only. **BCa is promoted into the fallback chain only if it raises the cell PASS
  rate by $\ge2$ cells of 12 *and* raises the minimum cell coverage.** Neutral or marginal ⇒ not
  promoted, and A4 §Q5's neutrality expectation is recorded as confirmed.

### S5.6 Compute budget, in fit-counts

Per outer dataset (measured from the archive: 1,159,993 profile-trace rows / 12,000 outer fits
$=96.7$ constrained refits per outer fit across 3 targets; 500 bootstrap refits per outer fit):

$$
\underbrace{1}_{\text{base}}+\underbrace{2}_{\text{S1 probe}}+\underbrace{\approx97}_{\text{profile trace}}+\underbrace{500}_{\text{bootstrap}}\;\approx\;600\ \text{fit-equivalents}
$$

(≈100 for the two identifiability arms, which carry no bootstrap.)

| Component | Cells | Reps | Fits/rep | Fits |
|---|---:|---:|---:|---:|
| B0 probe validation | 12 | 200 | 3 | 0.007 M |
| C-core + C-q2 + all hold-out (bootstrap-bearing) | 96 | 600 | 600 | 34.56 M |
| C-ID1 + C-ID2 (no bootstrap) | 36 | 600 | 100 | 2.16 M |
| Hold-out escalation (assume 20% of 44 cells, $+1400$ reps) | ~9 | 1400 | 600 | 7.39 M |
| BCa ablation | 12 | 200 | 600 | 1.44 M |
| **Total** | **132** | | | **≈ 45.6 M** |

For scale: the 2026-08-14 campaign was 6.0 M bootstrap attempts + 12,000 outer + 1.16 M trace rows
$\approx$ 7.2 M fit-equivalents. **Phase B is ≈6.4× that campaign.** DRAC job arrays (one seed per
`$SLURM_ARRAY_TASK_ID`), never GitHub Actions (D-50, and Design 88's *"Simulation campaigns run on
Totoro or DRAC, never GitHub Actions"*).

**Pre-registered reduction option, requiring Shinichi's approval (compute is his call under
D-139):** bootstrap only a pre-declared 1/3 of the datasets in each bootstrap-bearing cell, saving
$96\times400\times500=19.2$ M and bringing the total to **≈26 M**. The cost is that the *fallback's*
own coverage is then estimated at $n=200$ per cell (Wilson half-width $\approx0.025$), so the
fallback's calibration would be validated at a coarser resolution and the documentation would have
to say so. Presented as an option, not chosen unilaterally.

### S5.7 The pass/fail gate, and the stopping rule

**Gate (evaluated on H1 ∪ H2 ∪ H3 only, after the S1 fence has removed refused fits). All five must
hold:**

| # | Gate | Rationale |
|---|---|---|
| **G1** | $\ge90\%$ of hold-out cells PASS the equivalence gate {Wilson 90% $\subset[0.92,0.98]$} at $n=600$, escalated per S2.6 | the campaign's own frozen gate, unchanged |
| **G2** | **no** hold-out cell has coverage $<0.90$ | absolute floor; the C011-class guard. Non-negotiable |
| **G3** | interval availability $\ge0.95$ per hold-out cell among non-refused fits | the campaign's own availability gate |
| **G4** | refusal rate $\le0.10$ in the well-identified anchor cells ($\pi=0.50$, largest $n_{\text{site}}$) | **usability does not bend (D-139)** — a fence that refuses everything is not a deliverable |
| **G5** | every fitted $\gamma_k$ carries its registered sign (S2.4) | the mechanistic story must survive its own test |

**If the gate fails:** the construction is **not promoted**. Design 88's point-only fence stands
unchanged, and the result is written up as a negative result — Design 117 §6.3's own standard:
*"A negative result is publishable and must be reported as such."*

**Stopping rule (pre-registration discipline):**

1. **No refitting on hold-out. Ever.** The hold-out blocks are read once.
2. The **calibration split may be re-used at most once**, and only after a written deviation note
   naming exactly what changed and what measurement forced it. The used hold-out blocks are then
   **retired**; a *fresh* hold-out must be generated with fresh seeds and a fresh block declaration
   before any second gate evaluation.
3. **If the second attempt also fails:** stop. Ship Design 117 §6.1's penalty-sensitivity reporting
   alone — which §6.1 says *"is worth shipping whatever §6.3 concludes"* — keep intervals fenced,
   and publish the negative result.
4. **If the B0 probe gate (S5.3) fails:** stop before B1. A calibrator built behind a fence that
   does not detect is worse than no calibrator, because it would ship intervals on C011-class
   estimates.

---

## Appendix — claims marked UNVERIFIED, and what would settle each

| Claim | Where | What settles it |
|---|---|---|
| A4 route (iii)'s finite-difference-to-$\hat a$ conversion formula | S3.4, S5.5 | read Efron (1987 §6) and Hall (1992 ch. 3) primaries; gate the arm on it |
| $\hat a_{\text{boot-skew}}$'s asymptotic equivalence to canonical $\hat a$ | S3.4 | DiCiccio & Efron (1996 §2–3); until then, exploratory only |
| Current `brglm2::confint.brglmFit()` still exposes `ci.method = "union"` | S3.4 | `?confint.brglmFit` in R |
| Deep separation *in the estimated latent design* is caught by neither the screen nor the probe | S1.3 | re-run the LP test on the augmented design including fitted LVs (Design 117 §7 says this is cheap and post-fit) |
| $p_{\text{free}}\approx2T$ for ordinary $q=1$, hence $c_n\approx2\sqrt{2/n_{\text{site}}}$ | S2.3, S5.1 | read the exact `p_beta` + `length(theta_rr_B)` counts off a real fit at B0; the C-ID1/C-ID2 $c_n$ values in S5.1 must be recomputed from those exact counts before the grid is frozen |
| $s_j$'s magnitude at C011 (predicted large, $O(10)$) | S1.1 | B0 measures it directly |
