# After-task — Design 108 Gate A Stage 7: structured phylogenetic KL

**Date:** 2026-08-02 · **Platform:** Claude Code · **Branch:** `claude/design108-stage7-phylo-kl`
**Commit:** `d4d3e4e5` · **PR:** #911 · Base: #907 (Stage 6 `509460b8` + R3 `15c7a18d`)

## 1. Goal

The last Gate-A derivation. Design 108 row 7: *"**Her phylogenetic tier being the actual model**
rather than an iid tier wearing its name. Until this lands, a two-tier VA fit is not the model she
wrote."*

This is the stage where a fit can **run, converge, and be silently wrong** — an iid tier and a
phylogenetic tier differ only in a precision matrix, and nothing in a healthy-looking fit
distinguishes them. So the arc was scoped around oracles, not smoke tests.

## 2. Implemented

**No public API change. The fence is untouched.** `structured` is lifted on the **prototype path
only**, in lockstep in `R/va-r3-proto.R` and `R/approximation-engine.R`. `provider`, `lv` and
`missing` stay refused; SPDE untouched; two precisions in one fit refused.

Design 106 §3.1 with `Q_p = Sigma_c^{-1} ⊗ A^{-1}` and `Sigma_c = I_d`, because §3.2's
standardized-field convention puts the scale in the loading:

```
KL = 0.5*[ sum_g Ainv_gg * tr(S_g)      §3.3 — needs only diag(Ainv), as DATA
         + sum_c m_.c' Ainv m_.c        §3.5a — the Laplace engine's existing block
         - n*d
         - sum_g logdet(S_g)            free from the Cholesky
         + d * log_det_A ]              §3.4 — KEPT, see below
```

Carries **no hyperparameters**, exactly as §3.2 predicts. One shared precision per fit, mirroring
the engine's single `Ainv_phy_rr`/`log_det_A_phy_rr` pair — which is what
`phylo_latent(unique = TRUE)` needs (structured low-rank **plus** structured diagonal Psi over the
same tree). Tier 0 remains the unstructured ordinary latent tier.

New DATA: `tier_structured`, `Ainv_struct`, `diag_Ainv_struct`, `log_det_A_struct`.
New R: `.va_r3_structured_precision()`, `.va_r3_phylo_structure()`, `structured=` plumbed through
validate / build_tiers / layout / make_objective / fit.

## 3a. Decisions and Rejected Alternatives

| Decision | Rationale | Rejected |
|---|---|---|
| **Both routes implemented; the caller's `Ainv` decides** | The tier's level count is `nrow(Ainv)` and nothing else. This is not a hedge — it means polytomies and non-bifurcating trees are handled **by construction** rather than by a formula | Hard-coding `n_aug = 2N-1`, which Design 106 §6.4(4) itself flags as assuming a rooted, fully-bifurcating tree |
| **`log_det_A` CARRIED, not dropped** | Constant in every parameter for a fixed tree, so it moves no derivative — but dropping it shifts the ELBO off the Laplace absolute scale and breaks Design 104 §7's sign check. For the test tree it is −17.61, not a numerical no-op | Dropping it as "a constant"; cheaper and quietly breaks a cross-engine comparison |
| **Structured tiers refuse the 1-vs-0 base sniff** | See §9 — the augmented ordering makes both arms of the sniff match. A fit that runs and is wrong | Leaving the sniff alone: it "works" for tips-only and only breaks on the route we ship |
| **The level-usage check is relaxed for structured tiers**, replaced by exact `n_levels == nrow(Ainv)` | Internal augmented nodes carry no observation by construction, so "every declared level must be used" is false for them. The replacement is stricter, not looser, and is enforced in R **and** in the template | Keeping the old check and special-casing observations |
| A new `kl_const_by_tier` report field | Smearing `0.5*d*log_det_A` across levels would keep `kl_by_level` summing to `total_kl` without a new field — at the cost of making a per-level number that is **not** a per-level quantity | Silent smearing |

## 4. Files Touched

| File | Change |
|---|---|
| `inst/tmb/gllvmTMB_va_r3.cpp` | 4 new DATA; structured-tier contract block; the structured KL in both loading paths; `kl_const_by_tier` |
| `R/va-r3-proto.R` | `.va_r3_structured_precision()`, `.va_r3_phylo_structure()`; `structured=` plumbing; 0-based index enforcement for structured tiers |
| `R/approximation-engine.R` | `structured` clause lifted in lockstep; regime string names the shared-precision case and the SPDE exclusion |
| `tests/testthat/test-va-r3-structured-phylo.R` | **new** — 11 tests / 70 assertions |
| `tests/testthat/test-va-r3-prototype.R` | template probe gains the Stage 7 DATA + **4 new negative probes**; two refusal messages updated |
| `tests/testthat/test-va-probit-adsafety.R` | hand-built TMB data list gains the Stage 7 DATA placeholders |
| `tests/testthat/test-approximation-engine.R` | two refusal messages updated (lockstep assertion preserved) |
| `docs/dev-log/after-task/2026-08-02-design108-stage7-structured-phylo-kl.md` | this report |

**Cascade: nothing else.** No roxygen changed → no `man/*.Rd`. No NEWS/README/vignette — nothing to
advertise. **Register: no new row** — Stage 7 admits nothing new to the public fence.

**Roadmap tick:** Gate A's last derivation. Gate A closed at Stage 6; Stage 7 makes the phylo tier
real. **No `ROADMAP.md` line moves** — nothing user-facing.

## 5. Checks Run

**iid reduction — literally zero.** Structured tier with `Ainv = I` vs the identical tier declared
unstructured, same parameters:

| loading shape | fn | gr (max abs) | kl_by_level (max abs) | total_kl |
|---|---|---|---|---|
| dense | **0.000e+00** | **0.000e+00** | **0.000e+00** | **0.000e+00** |
| trait-diagonal | **0.000e+00** | **0.000e+00** | **0.000e+00** | **0.000e+00** |

The test asserts 1e-14 as briefed; the measurement is exact. `kl_const_by_tier` is
`identical()` to `c(0, 0)` — `log det I = 0`, so nothing hides in the constant.

**Direct-algebra oracle.** 5-tip coalescent tree (`n_aug = 8`, `nnz(Ainv) = 20`), full dense
`Q_p = kron(I_d, Ainv)` and full block-diagonal `S`, §3.1 evaluated verbatim:
template `502.991275257824782`, R `502.991275257824668` — **abs 1.137e-13, rel 2.26e-16**.
Run for both dense and trait-diagonal structured tiers.

**Convention check.** Reconstructs `-E_q[log p]` from the KL and matches the shipped engine's own
`0.5*(n*log(2pi) + log_det_A + g'Ainv g)` summed over coordinates, plus the trace term, to 1e-10.
**The standardized convention does match the Laplace engine.**

**Inner-Hessian sparsity under `profile=`** (Poisson, T=4, q=2, dense d=2 phylo tier):

| tips | n_aug | dim | nnz | nnz/dim | tier-2 cross-level nnz | `d*nnz_lower(Ainv)` |
|---|---|---|---|---|---|---|
| 20 | 38 | 290 | 1,262 | 4.35 | 72 | 72 |
| 40 | 78 | 590 | 2,542 | 4.31 | 152 | 152 |
| 80 | 158 | 1,190 | 5,102 | 4.29 | 312 | 312 |
| 160 | 318 | 2,390 | 10,222 | **4.28** | 632 | 632 |

Without the phylo tier, `nnz/dim = 3.00` exactly at every N. The tier adds **exactly**
`d × nnz_lower(Ainv)` entries — Ainv's own pattern, in the `m` coordinates only, and nothing else.
Flat over an 8× range, so **R3's linear-in-N property survives**; sparse-Cholesky fill grew 8.54×
for 8× size.

**R3 re-verified with a structured tier** (24 tips, Gaussian, hard-driven): objectives agree to
2.1e-10, fixed params 1.5e-05, variational 5.6e-06, and **L3 — the gradient of the ORIGINAL joint
objective at the profiled solution — is 2.37e-05 (< 1e-4)**. Outer par 16 vs full 156.

**`log_det_A` behaviour.** Shifting it by δ moves the negative ELBO by exactly `0.5*d*δ` (1e-10)
and moves **no** derivative (< 1e-12).

**Regression** — 10 files, **849 assertions, 0 fail / 0 error**, 1 pre-existing skip:
prototype 477 · structured-phylo 70 (new) · profile 41 · separation 6 · mixed-family 23 ·
integration-fence 39 · probit-adsafety 114 · approximation-engine 38 · missing-response 10 ·
routing-oracle 31. Stage 6's K=1 byte-identity, Proposition 2's zero-off-diagonal allocation, the
three single-tier oracles, and R3's L3 + L7 negative control all pass **unedited** —
`test-va-r3-profile.R` is untouched (verified by diff).

## 6. Tests of the Tests

- **Autodiff was checked separately from value.** The direct-algebra oracle compares the *value*;
  a second check compares AD against central differences over the whole ragged block (< 1e-5
  relative). **A transposed sparse product would give the right value on a symmetric `Ainv` and the
  wrong derivative** — the value oracle alone cannot see that.
- **The iid reduction is the analogue of Stage 6's byte-identity**: it proves the general form
  *reduces*, which no amount of "the structured fit converged" would.
- **The sparsity claim is measured across an 8× range**, not asserted at one N. A single-N nnz
  count cannot distinguish "adds Ainv's pattern" from "adds O(N²)".
- **Four new negative probes** were added to the template-probe test for the new guards, rather
  than removing any existing probe.
- **`log_det_A` was tested by perturbation** — shift it and check what moves. That distinguishes
  "carried correctly" from "present but ignored", which a value comparison would not.

## 7a. Issue Ledger

None opened or closed. Related and open: #897.

## 8. Consistency Audit

- No grammar, keyword, or `Sigma`/`Lambda`/`psi` notation change.
- `man/*.Rd` not regenerated — no roxygen touched.
- Register unchanged — nothing new is admitted to the fence.
- Four existing test files changed: three are mechanical additions of the new DATA to hand-built
  TMB data lists; one updates two refusal messages whose reason legitimately changed. **No oracle
  edited to make anything pass.**

## 9. What Did Not Go Smoothly

1. **A silent-wrong-answer bug, found in the guard rather than the maths.** The augmented precision
   orders internal nodes first and tips last, so **every tip's 0-based index is ≥ 1 and
   ≤ n_aug − 1**. Both arms of `.va_r3_normalise_index()`'s 1-vs-0 base sniff therefore match, the
   1-based arm wins, and **every observation attaches to the wrong node**. The fit runs, converges,
   and is wrong. Structured callers must now declare 0-based; tested. This is exactly the failure
   mode this stage was scoped around, and it was in the plumbing, not the derivation.
2. **Design 106's `n_aug = 2N − 1` is wrong — it is `2N − 2`.** The builder drops the root (its
   parent term is never assembled). Verified at N = 4, 10, 50, 5397; at Ayumi's 5,397 species the
   augmented set is **10,792**, not 10,793. §6.4(4) had flagged the figure as needing verification.
3. **Design 108 row 7's "the phylo tier costs twice" is right for that tier (1.9996×) but the model
   total is 1.50×**, because the ordinary tier is unaffected. The row invites the wrong number.
4. **This report was written after the PR opened.** Stage 6's was written after its PR *merged*, and
   that was recorded as a DoD violation. This one is earlier but still not before — the standing
   fix is to put the report in the implementing agent's brief, which was not done here either.

## 10. Known Residuals

- **🔴 The statistical half of tips-only vs augmented is NOT settled.** Cost and sparsity are
  measured; **Design 106 §3.6's falsifiable prediction is untested** — that the augmented
  factorised ELBO sits *further* below the marginal likelihood, because the mean-field penalty is
  paid on every internal edge. That needs a matched ELBO-vs-Laplace comparison on a small tree,
  which is a campaign, not a test. **This is a live open question, not a footnote.**
- **No recovery or coverage evidence for the phylogenetic tier.** The liveness test is one seed with
  no truth comparison. Nothing here licenses a claim about the tier's estimates.
- The convention check compares against the engine's *formula* recomputed in R, not against a
  running shipped Laplace fit. A cross-fit fixture is a separate slice.
- Fixed-parameter SEs still **fail closed at K > 1** (inherited from Stage 6).
- Two different precisions in one fit (tree + pedigree) are refused; SPDE untouched.

**Coordinate counts** for the real envelope (q=2, two `unique = TRUE` tiers = four template tiers):

| | T=20 | T=26 | T=30 |
|---|---|---|---|
| N=5,000 tips-only | 450,000 | 570,000 | 650,000 |
| N=5,000 augmented (n_aug=9,998) | 674,910 | **854,886** | 974,870 |
| N=10,000 tips-only | 900,000 | 1,140,000 | 1,300,000 |
| N=10,000 augmented (n_aug=19,998) | 1,349,910 | **1,709,886** | 1,949,870 |

## 11. Team Learning

**Gauss** — the KL was the easy half. The derivation was done in Design 106 and transcribing it
cost far less than the plumbing around it. Watch for: a stage whose *stated* difficulty is the
mathematics and whose *actual* difficulty is index conventions — the effort estimate will be right
and allocated to the wrong place.

**Noether** — the alignment catch here is that **a symmetric matrix hides a transpose**. The value
oracle passes with the sparse product transposed; only the derivative check fails. Any oracle over
a symmetric operator needs a derivative arm, or it certifies half the implementation.

**Rose** — the received framing was inverted by measurement: the augmented route, which *looks*
1.5× more expensive, is the one that keeps the inner solve linear; tips-only is O(N²). Nobody would
have found that from the coordinate table in Design 106 §4.2. Watch for: a cost claim stated in the
units that are easy to count rather than the units that bind.

**Curie** — the guard that caught the index bug was not in the brief; it emerged from asking "what
does the augmented ordering actually look like". Watch for: a data-ordering convention imported from
another engine, where both engines are internally consistent and the *seam* is unguarded.

**Ada** — three stages in a row (4, 6, 7) have now shipped with the after-task report written after
the fact. The fix is structural, not exhortative: **put the report in the implementing agent's
brief**. It was omitted from all three.

## 12. Cross-Product Coverage

**Cross-cutting flags touched: `engine` (VA R3 template), `phylo` (structured precision),
`optimizer` (the R3 interaction).**

**COVERS.** The `phylo` flag for the VA R3 prototype's KL only: structured precision as DATA, both
tips-only and augmented routes, the shared-precision case that `phylo_latent(unique = TRUE)` needs,
and the measured interaction with R3's sparse inner solve.

**Does NOT cover** — per surface:

| Surface | Does NOT cover |
|---|---|
| **VA route, user-facing** | Structured tiers are **not reachable**. The fence is untouched; `provider`, `lv`, `missing` still refused. No export, no `method=`, no public text. |
| **Statistical validity of the route choice** | Does NOT cover Design 106 §3.6's prediction that the augmented ELBO sits further below the marginal likelihood. **Untested.** Cost is measured; correctness of the choice is not. |
| **Recovery / accuracy** | Does NOT cover recovery for the phylo tier in any regime. One seed, no truth comparison. |
| **SPDE / spatial** | Untouched. The regime string now says so explicitly. |
| **Multiple precisions** | Two different precisions in one fit (tree + pedigree) are refused, not supported. |
| **Standard errors** | Fail closed at K>1, inherited. A structured fit reports no SE. |
| **Shipped Laplace engine** | Untouched. Its `Ainv` handling and numbers are byte-unchanged; Stage 7 only *matches* its convention. |
| **GLLVM.jl (R↔Julia twin)** | No port owed — nothing became user-facing. |
| **drmTMB / sister packages** | No coupling. |
