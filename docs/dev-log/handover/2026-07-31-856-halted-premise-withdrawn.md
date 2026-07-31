# HALTED — #856 was closed as a false premise before this branch existed

**2026-07-31 · Claude (Fable 5) · TARGET = Shinichi · nothing merged, no PR opened, nothing at risk**

## Read this first

I built a 17-commit branch implementing a capability change for **#856**, and **you had already
closed #856 as "filed on a false premise" twenty minutes before my first commit.**

| | |
|---|---|
| #856 closed | `2026-07-31T00:29:03Z` |
| this branch's first commit | `2026-07-31T00:49:26Z` |
| PR opened | **none** — nothing is at risk of merging |
| merged | **nothing** |
| public claim moved | **none** — the `NEWS.md` entry exists on this branch only |

**Recommendation: do not merge this branch.** One commit is worth keeping on its own merits
(below); the rest should be treated as evidence, not as a change to land.

I did not discover this myself. The reconciliation agent found it while checking receipts and
escalated mid-run. I verified it directly against `gh` before acting.

## Your correction is right, and my own evidence supports it more strongly than the argument you made

Your three points, checked against what I measured rather than accepted:

1. **"It is not undocumented."** Correct — and I found this myself during the arc. I corrected
   #856's own under-count and recorded that the singleness *is* stated at
   `R/unique-keyword.R:127`. I then kept going. That is the sharper failure here: my own evidence
   contradicted the issue's framing and I filed it as a footnote instead of treating it as a
   reason to stop and re-ask.
2. **"The per-trait role is served by `theta_diag`."** Correct for the recommended
   `indep(0 + trait | g)` grammar at per-row resolution. My own probe confirmed it independently:
   in that configuration Q7 fires, `sigma_eps` is mapped off at ~1e-3·sd(y), and the per-trait
   unit variance absorbs unit and residual jointly.
3. **"The scalar is a deliberate identifiability decision."** Correct in that configuration —
   `sd_g[t]² + σ_ε²` is identified only as a sum.

**What I would add, because it strengthens your conclusion rather than weakening it.** The
adversarial review of my own implementation found that making `sigma_eps` per-trait causes real
harm on the standard layout:

- **13 of 20 simulated datasets collapse** a trait's residual SD to the zero boundary on the
  canonical one-row-per-(site,trait) joint-SDM design — every one with `convergence = 0` **and**
  `pdHess = TRUE`, so neither flag registers it. Against **0 of 20** on pre-change code.
- The existing health check missed **11 of those 13**, because `sigma_eps_thresh` is an absolute
  magnitude and the collapsed values sit just above it.
- Any trait with no Gaussian or lognormal rows gained an **exactly flat** parameter direction —
  gradient identically zero, non-PD Hessian, and a frozen `lm` start value surfacing publicly as
  an estimated residual scale marked PASS.

The shared scalar could not follow a single trait to the boundary because the other traits needed
it positive. That protection is a *side effect* of the pooling rather than a designed safeguard —
which is precisely why removing the pooling removes it. So the pooling is not merely defensible on
identifiability grounds; it is empirically protective.

## The one thing I measured that your correction does not cover

Your correction addresses the per-row-diagonal case and, in "what survives", the `latent()`-only
case. There is a third: **replicated designs.**

With two or more rows per (unit, trait) cell and `indep(0 + trait | unit)`, Q7 does **not** fire,
`sigma_eps` stays live and shared across traits, and the restriction is measurable:

| | |
|---|---|
| true per-trait residual SDs | 0.2 and 2.0 |
| fitted (shared) `sigma_eps` | **1.4292** |
| RMS of the truths — the best one scalar can represent | 1.4213 (ratio 1.006) |
| model-free within-cell estimate of each | **0.197** and **2.012** |

The per-trait information is demonstrably present in the data; the model cannot express it. That
is a real restriction in a real configuration.

**I am recording this as information, not as a reason to reopen anything.** Given the collapse
evidence above, the trade looks unfavourable: the restriction costs a compromise value in
replicated designs, while removing it costs silent boundary collapse in the more common
unreplicated ones. Your call either way, and "no action" is a defensible answer to it.

## What survives independently of #856

**Worth cherry-picking regardless — commit `16aeb208`.** `R/unique-keyword.R:127` told users that
"Gaussian / lognormal / **Gamma** fits" share one `sigma_eps`. The Gamma half has been false since
`dff9b363` (2026-07-05), which gave ordinary Gamma its own per-trait `log_phi_gamma`. Ground truth:
`src/gllvmTMB.cpp:312` restricts `sigma_eps` to family ids {0, 3}, and `R/fit-multi.R:4630` says so
directly. This is a genuine documentation defect, independent of everything above.

Worth noting *how* it survived: the gamma decoupling's own consistency audit ran the regex
`Gamma.*sigma_eps`, which matches that line, and classified the remaining hits as "intentional
boundary wording that explicitly contrasts Gaussian/lognormal `sigma_eps` with ordinary Gamma
`phi_gamma`". That line does not contrast — it asserts. The right search was run and the verdict
misread the hit.

**Also on the record, no action needed:** I posted a correction on #622
([comment](https://github.com/itchyshin/gllvmTMB/issues/622#issuecomment-5138682010)) because my
earlier comment there implied clause two of its proposed fix was an oversight. On your reading it
was correctly *not* implemented, and the follow-up says so.

## The process failure, plainly

The Phase 0.25 prior-work sweep has rows for repo git state, twin repositories, the brain index,
and external prior art. **It has no row for the live state of the issue being worked on.** I read
#856 once at orientation — it returned `state: OPEN, comments: 0` — and never re-checked across
seventeen commits and roughly two hours.

The gate was run correctly against its own template; the template has a hole. I have asked the
reconciler to tag this as drift against the *method* rather than the execution, and not to soften
it. The concrete fix is a sweep row: **re-read the issue/PR state for the subject immediately
before decomposition, and again before opening a PR.**

The second failure is not procedural and matters more: I generated evidence that contradicted the
premise — the documentation claim in point 1 — and recorded it as a correction to the issue
instead of as a reason to stop. A sweep row would not have caught that. Re-asking when your own
findings undercut the task's framing would have.

## What NOT to redo

- **Do not re-run the archaeology.** It is committed and correct as history: the scalar originally
  pooled three families, `dff9b363` decoupled gamma, and #622's clause two was never implemented.
  What was wrong was the *inference* that "never implemented" means "incidental".
- **Do not re-measure the collapse.** 13/20 vs 0/20 is measured against a recompiled pre-fix
  worktree and is in `docs/dev-log/audits/2026-07-30-856-adversarial-review.md`.
- **Do not treat the Julia twin as supporting per-trait.** I verified GLLVM.jl also uses a scalar
  (`σ_eps::Real`, `likelihood.jl:73`). The 2026-07-03 twin-review note claiming "Julia folds
  residual into `diag(psi)`" is **false** and should be corrected in that record.
- The full test suite was **stopped mid-run** once the premise collapsed — it was validating a
  change that should not land. No suite result is claimed anywhere.

## State

Branch `claude/856-sigma-eps-archaeology-20260730`, 17 commits, pushed, **no PR**. Worktree
`/private/tmp/gllvmtmb-856-sigma-eps`. A pre-fix comparison worktree the reviewer built is at
`/private/tmp/gllvmtmb-856-PREFIX` (detached at `16aeb208`, TMB recompiled) if you want to
re-derive any regression claim yourself.
