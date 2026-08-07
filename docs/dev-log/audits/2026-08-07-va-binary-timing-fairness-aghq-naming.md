# Audit — binary timing fairness + AGHQ naming (2026-08-07)

**Branch:** `codex/va-gh-all-families`  
**Fence / `auto`:** unchanged. No public claim.

---

## 1. Totoro 500×20 cloglog-vs-probit `secs` — FAIR?

### Settings card (H2H script `probe-binomial-500x20-cloglog-probit-h2h.R`)

| arm | path | H | n_starts | se | machine |
| --- | --- | ---: | ---: | --- | --- |
| `gtmb_va_gh` (both links) | private `.va_r3_fit(..., eval_method="gh")` | **7** (`PROBE_VA_H`) | **4 (default)** — script does **not** pass `n_starts` | none | Totoro |
| `gtmb_la` (both links) | public `gllvmTMB(..., integration="laplace")` | — | **1** (single fit) | **`se=FALSE`** | Totoro |

### Verdict

| Compare | Fair? | Why |
| --- | --- | --- |
| **probit GH vs cloglog GH** (139 vs 37) | **FAIR** | Same H=7, same default `n_starts=4`, same DGP recipe / seeds / host. Cloglog really finishes faster here. |
| **GH vs LA** in that table (139 / 37 vs 1.4 / 1.5) | **NOT FAIR** | GH runs **4 starts**; LA is one optimize. Do not cite as “GH is ~100× slower than LA.” |

Accuracy columns in that audit remain valid (same starts within each GH link).

---

## 2. Matched warm retime (local macOS, agent `99e91024`)

Geometry: **n=500 p=20 q=2 probit**, H=7, `se=FALSE`, DLL pre-warmed, seeds 11001–03.  
Raw: `/private/tmp/va-s1-binomial-500x20-probit-smoke-20260807/matched-retime-3seeds.csv`

| arm | mean secs | vs LA | note |
| --- | ---: | ---: | --- |
| LA | **11.8** | 1× | |
| AC `n_starts=1` | 15.9 | 1.3× | soft Σ (rf ~0.76) |
| **GH H=7 `n_starts=1`** | **45.1** | **~3.8×** | β/Σ match ns=4; health gate fails by design |
| GH H=7 `n_starts=4` | 177 | ~15× | smoke default |

**Chat line:** Totoro’s 139 vs 1.4 is mostly **n_starts=4 vs 1**. Fair GH vs LA here is **~3.8×**, not ~100×. Shinichi’s “VA≈LA” memory was **AC + collapse + n_starts=1**, not GH H=7.

---

## 3. AGHQ(+ridge) — status

### Banked accuracy (not abs-Σ rf; latent SD + ρ)

Totoro **954 fits**, binomial p=6 q=2, 30 seeds/cell (`R/fit-multi.R` MEASURED table; handover 2026-07-28): **AGHQ + ridge (`τ=2`) beats shipped Laplace on sigma and rho at every n**; runaway 50%→0% at n=100. Opt-in: `gllvmTMBcontrol(aghq = 9)` (default ridge on AGHQ path).

### Live timed smoke (agent `7fa92352`, ongoing — do not kill)

Local sequential probe `probe-la-vs-aghq-timed.R`, cell **n=400 p=8 q=2 probit**, arms LA vs `aghq=9` (+ default ridge):

| stage | LA secs | AGHQ+ridge secs | note |
| --- | ---: | ---: | --- |
| warm n=60 (untimed) | 1.8 | **83.7** | ~47× LA; warn_runaway still fired once on warm DGP |
| timed seeds 11101… | LA done fast | **still running** (~3–5+ min/seed) | summary not written yet |

**500×20 AGHQ wall:** not finished this sitting. ETA: minutes per seed (multistart + `aghq_n_adapt` up to 400). Cost story already clear vs LA/GH-ns1: **AGHQ is the slow arm**.

---

## 4. Naming — do **not** call AGHQ “LA-GH”

| Name | What it is |
| --- | --- |
| **Laplace** | Mode + Hessian approximation to the **true** integrated likelihood. |
| **AGHQ** (`aghq = k`) | Adaptive Gauss–Hermite quadrature on that **same** marginal. **k=1 nests Laplace**; k>1 is better integration, not a variational bound. Ridge (`aghq_ridge`, default 2 when AGHQ on) is a MAP penalty on loadings. |
| **VA-GH** | Variational ELBO with GH nodes on the **variational** posterior — **different objective**. |

**“LA-GH” is a bad user-facing name:** it sounds like a sibling of VA-GH and invites conflating quadrature-on-marginal with VA. Prefer **Laplace / AGHQ / VA-GH** (or “Laplace”, “AGHQ(+ridge)”, “VA-GH”).

---

## 5. Feed into binary recommendation (draft; full table when AGHQ summary lands)

1. **Link:** **probit** (cloglog loses abs Σ at 500×20: pass 5/12 vs 8/12).  
2. **Default algorithm for users:** **Laplace** — matches/edges GH on abs Σ at 500×20 (pass 0.75 vs 0.67) and is **~3.8× faster** than GH at matched `n_starts=1`.  
3. **AGHQ+ridge:** accuracy upgrade on latent SD / ρ (banked), especially small-n / runaway; expect **much slower** wall.  
4. **VA-GH H=7:** when VA is wanted; competitive abs Σ on probit; not the speed story. Keep `n_starts=4` for the health gate in production VA.  
5. **Do not advertise:** PoisG for Σ; logit GH for abs Σ; AC for magnitudes; GH-vs-LA secs without matched starts; “LA-GH” as a product name.
