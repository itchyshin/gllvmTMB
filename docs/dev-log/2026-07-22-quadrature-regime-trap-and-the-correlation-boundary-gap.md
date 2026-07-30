# For the gllvmTMB lane — a quadrature folklore trap, and the boundary theory that does not exist (2026-07-22)

**Status: UNCOMMITTED, written by an out-of-lane session.** Nothing else in this repo was touched. Commit
it, move it, or delete it — it is a message, not a change. Written while
`claude/profile-coverage-remeasure-20260718` was live (last commit 07:31 today, 11 dirty files);
deliberately not staged so it cannot entangle that lane.

**Two companion notes exist**, both in Shinichi's vault, both also messages rather than actions:
`memory/FOR-GLLVMTMB-TEAM-short-note-2026-07-22.md` (the Phase-B2 measurement asymmetries) and
`memory/FOR-GLLVMTMB-LANE-worktree-note-2026-07-22.md` (six worktrees, 732 MB, two holding real
uncommitted work). This note is the **literature** piece; those two are the measurement and housekeeping
pieces.

**Provenance.** A curated corpus of 13 hand-verified primaries, assembled today. Every claim is cited to a
source that was **content-verified**, not merely status-verified — three sources passed `ready` while
holding a bot-block page, a bare abstract, and a scanned cover page respectively; all three were caught and
repaired or replaced. Still machine-extracted; see "verify before use".

---

## 1. The folklore trap: "one quadrature node is enough" is true — for the wrong regime

You will encounter, in the standard software literature, a clear recommendation to use a **single**
quadrature node. **Pinheiro & Bates (1995**, JCGS 4(1):12–35), the canonical adaptive-quadrature reference
for nonlinear mixed models, found in their own case studies that adaptive Gaussian quadrature with 1, 5 and
10 abscissas gave **virtually identical results**, and concluded there is

> *"little to be gained by increasing the number of abscissas past one."*

They attribute the real accuracy gain not to node count but to **centring the grid at the conditional mode
and scaling by the Hessian**, and they recommend the 1-node ("Laplacian") approximation in practice, with a
hybrid scheme — cheap LME approximation for starting values, then 1-node Laplacian refinement.

**Their case studies are continuous-response nonlinear mixed models.**

Against that, **Rabe-Hesketh, Skrondal & Pickles (2002)** report that GLMMs with **small clusters, high
intraclass correlation, and discrete (e.g. binary) responses** typically need **five or more** quadrature
points — because with a single point the log-likelihood can go **flat with respect to the covariance
parameters** and drive predicted posterior SDs to **zero**.

These do not contradict each other. **Node-count sufficiency is regime-dependent:**

| | Pinheiro & Bates regime | Rabe-Hesketh regime |
|---|---|---|
| response | continuous | **discrete / binary** |
| cluster information | ample | **small clusters, high ICC** |
| posterior for the RE | close to normal | **sharply peaked, non-normal** |
| nodes needed | 1 suffices | **5+** |
| failure if under-noded | negligible | **flat likelihood, posterior SD → 0** |

**gllvmTMB's discrete-response latent-variable models sit in the right-hand column, not the left.**

So: if any gllvmTMB documentation, vignette, NEWS entry, or design note cites Pinheiro-Bates-style "one
node is enough" — or silently inherits that assumption from the surrounding software culture — it is
importing a conclusion from a regime the package does not occupy. Worth a grep, and worth stating the
distinction explicitly wherever quadrature choice is documented.

**The mechanism, now quantified.** Liu & Pierce (1994, *Biometrika* 81(3):624–629) give the m-node
Gauss-Hermite error as **O(n^−⌊m/3 + 1⌋)**, which at m = 1 recovers Laplace's O(n⁻¹) exactly. Laplace is
formally the one-node member of the AGHQ family. And the Laplace error itself is governed by **per-cluster
information**, not total sample size: as cluster size and event counts grow the RE posterior becomes more
normal and the curvature-based approximation improves; with small clusters, dichotomous responses or large
ICC, the true posterior is sharply peaked, the curvature-based scale is **too small**, and the
approximation misses real likelihood mass near the peak (TMB paper, Kristensen et al. 2016;
Rabe-Hesketh et al. 2002).

Note gllvmTMB has **no AGHQ** — it is a TMB/Laplace fit, m = 1 by construction. That is a stated fact about
the package, not a criticism; but it means the package sits permanently at the node count that the
Rabe-Hesketh regime says is insufficient, and the honest framing of any small-cluster discrete-response
result should say so.

---

## 2. The gap that matters most: boundary theory for a correlation at ±1 does not exist in this literature

The 2026-07-22 companion note to this team argues that the Phase-B2 `phylo_unique(1 + x | species)`
binomial-logit cell's upward variance bias may be **structural** — a near-boundary 2×2 covariance whose
ρ̂ drifts toward ±1, a documented variance-inflation route. That remains the strongest surviving
structural hypothesis.

**But it cannot currently be justified by citation.** The literature was asked twice, independently:

- once against the whole 13-source corpus;
- once specifically against **Cox & Reid 1987**, the parameter-orthogonality paper, as the source most
  likely to bear on a correlation parameter near its boundary.

**Confirmed absent both times.** Zero citations returned; plain "does not address this."

What the literature *does* supply is the **variance-at-zero** case, and supplies it well. **Self & Liang
(1987)**: at a boundary, the null and alternative parameter spaces are locally approximated by **cones**,
and the LRT statistic's asymptotic distribution is that of a likelihood-ratio test between cones under a
single multivariate-normal draw — a **chi-bar-square mixture**, not a single χ². **Stram & Lee (1994)** work
out the mixtures for the Laird-Ware model:

- testing one variance component (D = 0 vs D > 0) → **50:50 mixture of χ²₀ and χ²₁**
- adding a random slope to an existing random intercept → **50:50 mixture of χ²₁ and χ²₂**
- adding k correlated random effects to q existing ones → a mixture spanning df **kq to (k+1)q**

Comparing a naive LRT to a standard χ² with df = number of added parameters is **asymptotically
conservative** — inflated p-values, elevated Type II error risk; mildly so for simple cases, substantially
for complex multi-effect additions. For one variance term the correction is equivalent to **halving** the
standard χ²₁ p-value.

**Crucially:** Stram & Lee's positive-semidefinite constraint (d²ᵢⱼ ≤ dᵢᵢdⱼⱼ) is discussed **only in terms
of the variances dᵢᵢ, dⱼⱼ going to zero — never the correlation itself hitting its boundary.** Whether the
same cone/chi-bar-square machinery extends to ρ̂ → ±1 is **not stated anywhere in this literature.**

**So the ρ̂-drift explanation needs a first-principles derivation, or a fresh literature pull outside this
corpus — it may not be assumed as an extension of Self & Liang.** That is a real piece of work, and worth
knowing before it is asserted in a design note or a manuscript.

**Practitioner-facing framing that IS citable:** Bolker et al. (2009, TREE) — zero and near-zero variance
components and singular fits typically signal a model **over-complex relative to the data**; remedies are
dropping random effects (least-interesting, or smallest-variance/largest-uncertainty first), centring
continuous covariates, or adding data/covariates/groupings. Where a correction exists, compare against the
chi-bar-square mixture; otherwise treat naive LRTs on random effects as conservative.

---

## 3. Verify before load-bearing use

All quotes and equations were machine-extracted from born-digital text-layer PDFs (confirmed not scanned),
but still machine-extracted:

- **Liu & Pierce's exponent** O(n^−⌊m/3+1⌋) — check the floor-function argument (m/3 + 1, not (m+1)/3)
  against their equation. Exponent transcription is the exact failure class this exercise has repeatedly
  caught.
- **Stram & Lee's mixture df ranges** (kq to (k+1)q) and the 50:50 proportions — check against the paper;
  their original is a scanned photocopy with visible OCR artifacts.
- **The Pinheiro & Bates quotation** is short and verbatim, but their recommendation is stated across
  several passages — read the surrounding context before citing it as a flat rule.

---

## 4. If you want more

The corpus is a registered notebook (`ada0a323-14a2-48c0-81d0-33feac988cd9`, "Learning Library #4b — REML,
quadrature and boundary asymptotics"), 13 curated sources, no auto-research; Ranga can be sent back with a
narrower question. Full distillate in the vault at `memory/ENGINEERING-NOTEBOOK.md` § "Learning Library
drip #4b" (round 1 + round-2 addendum). A separate foundations corpus (`6aa67461`, MIT OCW statistics and
probability) supplies the finite-sample sampling-distribution results — (n−1)S²/σ² ~ χ²_{n−1} with variance
2(n−1) — that make "one realized draw can sit far from the population value" a quantitative claim rather
than a rhetorical one. That is the tool the companion team note needs for its single-seed argument.
