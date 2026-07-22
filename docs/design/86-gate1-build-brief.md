# Design 86 — Gate 1 build brief (algebra, autodiff, the bound probe)

**Status:** **CONTINGENT — NOT A GO.** This brief specifies *how to build Gate 1 the moment the
Design 86 contract is approved*. It is not approval, not a start signal, and not compute
authorisation. It exists so the coding lane is turnkey rather than re-derived. Companion to
[86-eva-sparse-binary-admission-contract.md](86-eva-sparse-binary-admission-contract.md); it adds
**no** requirement, tolerance, or claim of its own — where a number is needed it **points to the
contract** so the two cannot drift.

**Write status of this file:** it is a `docs/design/86-*.md` document, inside the Design 86 lane's
write fence. It touches no `R/`, `src/`, `tests/`, or shipped surface. It describes work that would
happen in a **separate, later, separately-approved lane**.

---

## 1. Two gates stand before any of this

Neither is self-granted; both are recorded in the contract.

1. **The contract is approved** (maintainer's act). Design 72's sequential logic binds: the proof
   precedes the code, and Gate 1 is the first rung. Until approval this brief is inert.
2. **Gate 1 itself needs no compute campaign** — it runs on tiny fixtures on a laptop — but it does
   require the frozen parameter file to *exist* for the fixtures it shares with later gates
   (contract §2.5). Its checksum is recorded at approval. Gate-4 **compute** is a *third*, separate
   approval and is out of scope here entirely.

If either gate is open, this document is read-only planning, nothing more.

---

## 2. What Gate 1 proves — and what it must not be mistaken for

Gate 1 answers exactly one question: **is the EVA objective implemented correctly, and is it
numerically well-behaved, on trivially-checkable inputs?** It is an *algebra and autodiff* gate.

It is **not**:

- a correctness anchor (that is Gate 2 — recovery on an information-rich cell);
- a Taylor-error measurement (Gate 3);
- any statement about coverage, admission, or the sparse regime (Gate 4);
- transferable to any non-Gaussian family beyond the Bernoulli-logit fixtures it tests.

Per the contract's sequential rule, **a Gate-1 pass licenses only Gate 2 to begin.** Nothing about
the estimator's fitness follows from it.

---

## 3. Build in a standalone prototype — the shipped template stays byte-unchanged

**Do not modify `src/gllvmTMB.cpp` for feasibility.** Follow the precedent already on `origin/main`:
the Design 85 R3 work lives in a *separate* template, `inst/tmb/gllvmTMB_va_r3.cpp`, with an
unexported R driver, leaving the shipped template untouched. Gate 1 does the same.

- **New TMB template** — e.g. `inst/tmb/gllvmTMB_eva.cpp` — carrying only the EVA objective of
  contract §5.1, with `random = NULL` in `MakeADFun` (the variational coordinates `a_i`, `A_i` are
  ordinary parameters — contract §4). No `method=` flag, because there is no shipped template to
  switch inside.
- **Unexported R driver** — e.g. `R/eva-proto.R`, not in `NAMESPACE`.
- The eventual one-template `DATA_INTEGER(method)` integration (the gllvm / drmTMB-160 pattern
  documented in contract §7.8) is a **graduation concern, not a feasibility concern.** It happens
  only if EVA clears Gate 4, and it is a separate design decision. Keeping the shipped template
  untouched is what makes this lane provably non-interfering with the 0.6 release.

This is the isolation model, stated concretely: separate worktree, branch off `origin/main`,
separate template, unexported R, `LOOP/` never touched. 0.6 stays Laplace-only *by construction*.

---

## 4. Deliverables

Four build units. Each cites the contract for its math; none restates it.

### D1 — A pure scalar oracle for `ell_EVA`, independent of TMB

A plain-R (no TMB, no autodiff) implementation of the Bernoulli-logit EVA objective, the closed form
in contract §5.1 **including the `+ q` per-unit KL constant**. This is the *independent* calculation
every identity check compares against, so it must share **no code** with the template. It must
implement the same numerical rules (§7): log-Cholesky `log det`/`tr`, `softplus` via
`max(x,0)+log1p(exp(-|x|))`, `v_it = ||L_i' λ_t||²` with the continuous `v→0` limit.

### D2 — The EVA objective in the prototype template (D1's target)

The §5.1 objective in `gllvmTMB_eva.cpp`, returning the negative objective for minimisation.
Loading reconstruction uses the live packed-`Lambda` unpacker convention (contract §6, §8). Honour
every numerical requirement in contract §7 — the `+q` constant (§7 / Gate-1 NO-GO), stable
`softplus` and `log det`, the small-`v` limit, and loud failure on any non-finite value.

### D3 — The AGHQ marginal bound probe at `q = 1`

A high-order adaptive Gauss–Hermite evaluation of the **exact marginal** log-likelihood
`log p(y_i)` at `q = 1` on a tiny sparse fixture, compared against `ell_EVA` on the same fixture.
This is the **only** place in the whole contract where the objective meets a true marginal
likelihood (contract §11 Gate 1). It is a **measurement, not a pass/fail gate** — its job is to
*observe* the sign of `ell_EVA − log p(y)` that §5.3 derives, in the overshoot regime `p̄ < 0.211`.
Reuse the Golub–Welsch node machinery already present in `R/va-r3-proto.R` (`.va_r3_gh_rule`);
do not re-derive quadrature.

### D4 — The bound-derivation reproduction

Gate 1 must **reproduce or refute** the §5.3 derivation, not restate it: independently confirm
`ell_EVA = L_exact − E_q[R]`, the fourth-derivative `s'''' = p(1−p)(1−6p+6p²)`, the sign flip at
`(3±√3)/6`, and the overshoot for `p̄ < 0.211`. The round-2 panel already reproduced this once by
hand; D4 makes it a checked-in, re-runnable numerical confirmation (e.g. the finite-difference check
of `s''''` and a Monte-Carlo estimate of `E_q[R]`'s sign on a sparse fixture).

---

## 5. The verification matrix

All tolerances are the contract's (§11 Gate 1, §7). This table *routes* them; it does not set them.

| Check | Fixture | Compares | Tolerance (per contract) |
|---|---|---|---|
| Gaussian exactness identity | Gaussian response, identity link | template `ell_EVA` vs exact Gaussian-VA objective | `< 1e-10` (§11 G1) |
| Bernoulli-logit objective | tiny binary fixtures | template `ell_EVA` (D2) vs scalar oracle (D1) | `< 1e-10` (§11 G1) |
| KL term, in isolation | random SPD `A_i`, `a_i` | template KL block vs `0.5[log det A − a'a − tr A + q]` | `< 1e-10` (§11 G1) |
| Returned negative-objective sign | any fixture | sign convention consistent end-to-end | exact (§11 G1 NO-GO) |
| Autodiff gradient | fixtures away from declared boundaries | template AD gradient vs central finite difference | rel. err `< 1e-5` (§11 G1) |
| Small-`v` continuity | `v → 0` sweep | value and first derivative continuous through `v = 0` | continuous (§7.2) |
| Quadrature scalar oracle | frozen `μ × v` grid | `H = 15/25/61` agreement | `< 1e-10` (§7.5) |
| Bound probe (D3) | tiny sparse `q=1` fixture | `ell_EVA` vs AGHQ `log p(y)` | **measurement, no tolerance** |
| Bound derivation (D4) | analytic + MC | `s''''` sign; `E_q[R]` sign for `p̄<0.211` | reproduces §5.3 |

---

## 6. The Gate-1 NO-GO (restated verbatim from the contract, so the runner sees it here)

Contract §11 Gate 1 NO-GO: **clipping needed for finiteness; a wrong KL sign; omitted constants —
including the `+ q` per unit in the KL term of §5.1; an inconsistent negative-objective sign; the
Gaussian identity failing; or the bound question left unresolved.**

Add the §7 hard rules that bite hardest in the sparse regime (`η` runs far negative by
construction): no direct `log(1+exp(η))`, no explicit probabilities near 0/1, no clipping of `η`, no
naive `sqrt(v)` differentiated at `v = 0`.

---

## 7. Reuse map — do not rebuild what exists

| Need | Reuse (on `origin/main`) | Provenance |
|---|---|---|
| Gauss–Hermite nodes/weights for D3 | `.va_r3_gh_rule(H)` in `R/va-r3-proto.R` | contract §5.2 / §7.8 |
| Stable `softplus` on AD tapes | `va_r3_softplus<Type>` in `inst/tmb/gllvmTMB_va_r3.cpp` | §7.8 |
| Small-`v` `softplus` expectation | `va_r3_softplus_expectation()` | §7.8 |
| log-Cholesky variational covariance | `PARAMETER_MATRIX(log_L_diag)`, `Li(k,k)=exp(...)` | §7.1 / §7.8 |
| Packed-`Lambda` unpack convention | live unpacker in `src/gllvmTMB.cpp` | §6 / §8 |

**Explicitly NOT reusable as an anchor:** the parked Phase-1 VA prototype
(`origin/claude/va-phase1-proof`). It is mean-field diagonal closed-form VA, **not EVA** — context
only (contract §11 Gate 2 box). Its `MakeADFun`-without-`random=` structure is a useful *reference
for the parameter-declaration pattern*, nothing more.

---

## 8. Platform and handoff

Live R/TMB compilation is plausibly **Codex's** lane under the sequential division (Claude plans,
Codex runs the live toolchain), but the platform is read from the runtime at the time, and whichever
tool is in-session owns it. Either way this is a **new scoped lane** with its own write grant, not
the Design 86 design lane stretching past its fence. If it is handed to Codex, this brief plus the
contract are the turnkey package; no additional context transfer should be needed.

---

## 9. Explicit non-goals of Gate 1

- No Gate 2/3/4 work; no correctness, Taylor-error, or coverage claim.
- No compute campaign; no Totoro, no DRAC.
- No `method=` argument, no export, no `NAMESPACE`, `NEWS`, `DESCRIPTION`, or vignette change.
- No modification of the shipped `src/gllvmTMB.cpp`.
- No `LOOP/` write.
- No claim that a Gate-1 pass says anything about EVA's fitness — it licenses Gate 2 and nothing
  else.

---

*This brief is contingent on the contract's approval and confers none. Approving Design 86, opening
the coding lane, and authorising Gate-4 compute are three separate maintainer acts.*
