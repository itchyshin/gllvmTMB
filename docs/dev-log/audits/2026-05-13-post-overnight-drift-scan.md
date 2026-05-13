# Post-overnight rebuild-canon drift scan -- 2026-05-13

**Auditor**: Claude (verification scan dispatched via Explore agent
on `main` at 25f2cbe parent).

**Trigger**: Maintainer feedback today (paraphrased): *"lots of
documentation just have old descriptions clearly Rose and Pat did not
really read each function's documentation... I want you to be a bit
more proactive than that -- Kaizen!"*

**Method**: targeted verification of the HIGH-priority drift items
called out during the deeper round-2 audit (R/ roxygen + vignettes
round-2). Each item below was grepped + read against the current
canonical model. Lines/excerpts shown are from `main` at the time
of the scan.

**Canonical model the scan checks against**

The paired four-component phylogenetic decomposition is canonical:

```r
gllvmTMB(value ~ 0 + trait
         + phylo_latent(species, d = K_phy)
         + phylo_unique(species)
         + latent(0 + trait | unit, d = K_non)
         + unique(0 + trait | unit),
         data = df_long)
```

with math `Σ_phy = Λ_phy Λ_phy^T + S_phy`, `Σ_non = Λ_non Λ_non^T +
S_non`, `Ω = Σ_phy + Σ_non`. Math notation uses `\mathbf{S}` / `s`
in user-facing prose; the legacy `U`, `U_phy`, `U_non`, `\Psi`
forms are wrong outside function-name task labels
(`compare_dep_vs_two_U()` etc., kept per PR #40).

---

## Confirmed drift (act on these)

### 1. `R/unique-keyword.R:54-58` -- contradicts canonical paired form

> *"The `phylo_latent(species, d = K)` term has no associated
> `unique()` because..."*

This text directly contradicts the paired form, where
`phylo_latent()` **requires** the paired `phylo_unique()` to
recover per-trait phylogenetic variances. The bare form is the
no-residual reduced-rank subset (see pitfalls section 5 after
PR #77 merges).

**Fix**: rewrite the relevant `@details` paragraph to describe
the paired form as canonical and bare-`phylo_latent` as the
reduced-rank subset.

### 2. `R/extract-omega.R:273` -- `phylo_unique()` framed as optional

> *"Requires `phylo_latent()` (and optionally `phylo_unique()`)
> plus..."*

`phylo_unique()` is not optional in the canonical paired form
that `extract_phylo_signal()` decomposes into `H^2 + C^2_non +
\Psi^2 = 1`. The "optional" framing predates the rebuild.

**Fix**: change `(and optionally `phylo_unique()`)` to require
the paired form. Note any documented bare-phylo_latent fallback
explicitly as a caveat, not as a co-equal mode.

### 3. `R/fit-multi.R:613, 619` -- runtime cli_inform with M1/M2 + three-piece

- Line 613: *"three-piece decomposition Omega = Sigma_phy +
  Sigma_non,shared + U"*
- Line 619: *"Compare M1 (without the `unique({species})` term)
  to M2 (with it)"*

Both are paper-internal language. The grid model is the
four-component decomposition, not three pieces. `M1` / `M2`
labels are paper-internal model names that mean nothing to users
of the package.

**Fix**:
- Rewrite the three-piece sentence as
  `\Omega = \Sigma_{phy} + \Sigma_{non}` (two pieces, each with
  its own loading-plus-diagonal split).
- Replace `M1 / M2` with the descriptive function names: "the
  unpaired form (only `phylo_latent()`)" vs "the paired form
  (`phylo_latent()` + `phylo_unique()`)".

### 4. `R/diagnose.R:112, 116, 120` -- in-prep manuscript equation refs

Lines 112, 116, 120: `(Eq. 13)`, `(Eq. 14)`, `(Eq. 15)`

Runtime output cites equation numbers from an unpublished
in-prep manuscript. The numbers may change before submission and
mean nothing to users without access to the manuscript draft.

**Fix**: drop the `(Eq. N)` suffix from each `cat()` /
`cli_inform()` line. Describe the algebraic identity in plain
language if context is needed.

### 5. `vignettes/articles/functional-biogeography.Rmd` -- `\Psi` drift

Six instances of `\boldsymbol{\Psi}_B`, `\boldsymbol{\Psi}_W`,
`\boldsymbol{\Psi}_P`, `\boldsymbol{\Psi}_R` at lines 171, 174,
468, 491, 500, 525.

**Fix**: replace each `\boldsymbol{\Psi}_X` with the
canonical `\mathbf{S}_X` (or `s_X` where a scalar is implied),
matching `Σ_X = \Lambda_X \Lambda_X^\top + \mathbf{S}_X`.

### 6. `vignettes/articles/joint-sdm.Rmd:126, 183, 279` -- paper-internal phases

> *"Phase D"*, *"Phase K"*

These are in-prep manuscript milestone labels. The article body
should describe what the phase does, not cite the milestone tag.

**Fix**: replace each `Phase D / Phase K` reference with the
descriptive content the phase represents (e.g. "the
joint-SDM extension that adds environmental fixed effects" or
similar -- depends on context at each line).

### 7. `gllvmTMB_wide()` still actively recommended in two articles

Soft-deprecated in `R/gllvmTMB-wide.R:77` (PR #65), but two
articles still present it as the standard wide-matrix entry
point:

- `vignettes/articles/response-families.Rmd:91, 94` -- "shortest
  route" for matrix workflows
- `vignettes/articles/morphometrics.Rmd:137, 163` -- presented as
  current standard

`phylogenetic-gllvm.Rmd:170` correctly frames it as "not the
right shortcut" -- use that wording as the template.

**Fix**: replace each active recommendation with the
`gllvmTMB(traits(...) ~ ..., data = df_wide)` form. Add a
one-sentence pointer that `gllvmTMB_wide()` still works for
matrices but is soft-deprecated.

### 8. `\mathbf{U}` notation in user-facing math

- `vignettes/articles/behavioural-syndromes.Rmd:342, 345` --
  `\mathbf{U}_B`, `\mathbf{U}_W` in math prose
- `R/extract-two-U-via-PIC.R:405-408, 534-535` -- roxygen
  references "U_phy" / "U_non" in returned-list documentation

**Fix**:
- Article: rewrite `\mathbf{U}_B / \mathbf{U}_W` as
  `\mathbf{S}_B / \mathbf{S}_W`.
- R/: rewrite the roxygen prose. The legacy file path
  (`extract-two-U-via-PIC.R`) and function name (`extract_two_U_via_PIC()`)
  stay -- they are task labels per PR #40. Only the math /
  prose changes.

---

## Ambiguous / needs human review

### 9. `vignettes/articles/choose-your-model.Rmd:195` -- unique() vs dep() for "full unstructured"

Line 195 recommends `+ unique(0 + trait | site)` for the "full
unstructured" case. The audit flagged this as potentially
recommending the wrong keyword (`unique()` is diagonal only;
`dep()` is the full unstructured T×T covariance).

The Explore agent did not find an explicit contradiction in
context, but the heading "full unstructured" plus the keyword
`unique()` is at minimum confusing. **Needs maintainer judgment
on whether to switch the recommendation to `dep()` or whether
the section is talking about a different decomposition step.**

### 10. `tier=` vs `level=` extractor API inconsistency

- `R/extract-sigma.R` consistently uses `level` as the argument
  name (e.g. line 392, 451-453, 456, 471).
- Roxygen prose in `R/extract-sigma.R:285` mentions *"tier"* in
  the math description.

Function signature is `level`; prose uses both. **Pick one and
sweep**. Maintainer call on whether the canonical user-facing
word is "level" or "tier".

---

## Recommended PR batching (post-merge of #74-#79)

Each batch is a coherent, reviewable unit. Names are tentative.

**Batch A: R/ paired-canon corrections (HIGH)** -- items 1, 2, 3.
Three files (`R/unique-keyword.R`, `R/extract-omega.R`,
`R/fit-multi.R`) -- all are roxygen / cli_inform prose, no
algorithmic change. Single PR, single after-task report.

**Batch B: Drop in-prep equation citations (HIGH)** -- item 4.
`R/diagnose.R` only (3 lines). Tiny PR. Pairs naturally with
batch A but kept separate so each batch's scope is obvious.

**Batch C: Article math/jargon fixes (MEDIUM)** -- items 5, 6.
`vignettes/articles/functional-biogeography.Rmd` (6 hits) +
`vignettes/articles/joint-sdm.Rmd` (3 hits). Single PR; both
are "replace paper-internal labels with descriptive content".

**Batch D: gllvmTMB_wide() recommendation cleanup (MEDIUM)** --
item 7. `morphometrics.Rmd` + `response-families.Rmd`. Single
PR. Note: `response-families.Rmd` was a Codex Tier-2 port in
PR #46; check the after-task for that PR before touching.

**Batch E: U → S notation sweep (MEDIUM)** -- item 8.
`behavioural-syndromes.Rmd` math + `R/extract-two-U-via-PIC.R`
roxygen. The function name stays.

**Batches F+ (deferred until maintainer judgment)** -- items 9
and 10.

---

## What this audit does NOT cover

- The 53 + 83 (≈136) findings from the two parallel agent audits
  dispatched earlier today are NOT all verified here. This file
  documents the HIGH-priority subset the maintainer's "Kaizen"
  feedback pointed at. The remaining MEDIUM / LOW findings
  (legacy `U` in roxygen examples, stylistic inconsistencies,
  redundant cross-refs, etc.) live in the agents' return
  messages and can be re-verified in a follow-up scan.
- The cluster/unit nesting future-scope question raised by the
  maintainer (*"I want to allow cluster and unit to be nested
  as well as crossed"*) is **future scope**; not in this audit.

---

## Status

- Drift confirmed on items 1-8.
- Items 9-10 flagged for maintainer judgment.
- PR batches A-E queued; will open one at a time as WIP allows
  (currently 6 open Claude PRs above the soft cap of 3, so
  batched fixes wait until #74-#79 merge).

---

## Addendum: `@title` reference-index sweep (Explore agent, 2026-05-13 ~18:00 MT)

Maintainer's follow-up: *"Should I also audit R/ roxygen `@title`
lines for the same jargon / framing pattern? Reference index is
what CRAN reviewers see."* Agent swept every `R/*.R` `@title`
(or first roxygen prose line where no explicit `@title`) against
the same canonical model as items 1-11 above.

**Verdict: titles are mostly clean.** Out of 37 audited files:

- **34 CLEAN** -- no jargon, no legacy notation, no soft-deprecated
  API recommendation in the title itself.
- **2 MINOR** -- `tier` wording where `level` is canonical
  (impacts pkgdown reference-index visibility, not behaviour).
- **1 MEDIUM** -- `extract_omega.R` title uses *"tiers"* and
  `extract_phylo_signal()` cites in-prep `Eq. 23-25` with `\Psi_t`
  legacy math.
- **0 HIGH** -- no title cites M1/M2/M3/M4, no title recommends
  `gllvmTMB_wide()`, no title misframes `phylo_latent()` as
  standalone-canonical, no title uses `U_phy / U_non` in prose
  context.

**MINOR**

- `R/extract-sigma.R` title: *"Extract the implied trait covariance
  / correlation at one tier"* → rewrite "tier" → "level".
- `R/extractors.R` `extract_communality()` `@return` (line 129)
  declares a returned column named *"tier"* → should match the
  canonical user-facing arg name once the maintainer settles
  `tier` vs `level`.

**MEDIUM**

- `R/extract-omega.R` `extract_Omega()` title: *"Total trait
  covariance Omega summed across requested tiers"* → drift on
  both `tiers` (legacy) and on the `phylo_unique`-as-optional
  framing (item 2 above).
- `R/extract-omega.R` `extract_phylo_signal()` roxygen cites
  in-prep equation numbers `Eq. 23-25` and uses `\Psi_t` for the
  trait-specific uniqueness. Both should follow the canonical
  conventions: drop the equation numbers and use `\mathbf{s}` /
  `\mathbf{S}` for uniqueness, with prose pointing at the same
  paired four-component decomposition.

**What this confirms**

The deeper-than-titles drift the maintainer was right to flag
(items 1-8 of this audit, plus the 136-finding round-2 agent
reports) is the larger surface; the titles themselves did *not*
get away with M1/M2 / `gllvmTMB_wide`-recommending / phylo-bare
errors. The pre-CRAN reference index will look clean once the
two MINOR + one MEDIUM titles are swept, which Batch A already
covers for `extract-omega.R` and Batch B (item #4 generalised)
covers for the equation-number citations.

**No new batch** -- the @title findings fold cleanly into the
existing Batch A (paired-canon corrections in R/) + Batch B
(drop in-prep equation citations) + the parked item #10
(tier-vs-level resolution).
