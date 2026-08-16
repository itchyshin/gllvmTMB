# nbinom1 / nbinom2 LA-MSPL admit next — packet first

**Date:** 2026-08-16
**Track:** independent E (read-mostly scout)
**Workspace:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`
**Ground truth:** `origin/main` @ `c849884f` (this sitting's Poisson-admit
worktree is behind that tip and is not the door under review)
**Status:** scout note only. No registry flip. No `src/` edit. No admit
PR. No NEWS `covered`.

**Reader:** the next MSPL conductor who arrives at the planned nbinom
door and wants to know whether either family may flip to `admitted`
tonight.

---

## Recommendation

**Packet first. Do not admit now.**

nbinom1 and nbinom2 already have a public planned door on `main`.
That door is not an admission packet. Poisson ordinary `q=1,2` being
`admitted` / `admit_packet` after G0 2026-08-16 does **not** transfer
a rate, a loading atom, a dispersion decision, or a registry flip.

A later admit PR is honest only after a #1008-shaped packet exists
**in-repo** for that family, then a Shinichi G0. No such packet exists
today. This sitting therefore does not open an admit PR, and it does
not open a prep-only PR either: the remaining holes are the packet
science, not a tiny pure-R oracle fill.

---

## What `main` already has

Public `estimator = "mspl"` accepts single-family nbinom1 / nbinom2
log ordinary `latent()` at `q=1,2`. Registry rows are `planned` /
`phase4_prep`. Evidence token is not `admit_packet` and not `covered`.
Public `se = TRUE` still withholds `sdreport()` / `vcov()` /
`confint()`. Replay: `docs/dev-log/after-task/2026-08-16-mspl-nbinom-planned-door.md`
(#1007 onto `main` after Poisson admission).

| Layer | nbinom1 (`family_id` 15) | nbinom2 (`family_id` 5) |
|---|---|---|
| Prepare fence | accepted (`fam_ids` includes 15) | accepted (`fam_ids` includes 5) |
| Registry | `nbinom1:log:ordinary:q1,q2` = `planned` | `nbinom2:log:ordinary:q1,q2` = `planned` |
| GLM-outer Jeffreys weight | PMF-summed exact \(I_\eta\) at fixed \(\varphi\); **not** quasi \(W=\mu/(1+\varphi)\) | \(W=\mu\varphi/(\varphi+\mu)\) |
| Soft rate on the live tape | **unpinned \(c=1\)** | **unpinned \(c=1\)** |
| Loading atom on the live tape | Bernoulli \(V_{\mathrm{loading}}\) (`gll_mspl_row_radial_penalty`) | same Bernoulli radial |
| Pure-R Phase-4 oracles | N1–N13 in `test-mspl-nbinom1-phase4-oracles.R` | E1–E7 in `test-mspl-nbinom2-phase4-oracles.R` |
| Live TMB/R admit twins | **absent** (those files refuse a live MSPL call) | **absent** |
| Multi-seed point smoke | **absent** | **absent** |
| Family atom helpers (`R/mspl-*-atoms.R`) | **absent** | **absent** |

The GLM-outer weights themselves are already taped in
`gll_mspl_log_weight_glm()` and pinned in the Phase-4 oracle files.
Door tests (`test-mspl-nb1-fenced-tape.R`, `test-mspl-nb2-fenced-tape.R`)
assert that a public nbinom MSPL call is legal and that the rows stay
`planned`. That is operational reachability, not Phase-4 exit.

Poisson on the same tip is a different cell:
`poisson:log:ordinary:q1,q2` = `admitted` / `admit_packet`, with
event-count \(c_P\) and event-weighted \(V_\lambda^P\) from #1008, then
G0 2026-08-16. The #990 smoke remains operational PASS / admit-evidence
FAIL and is named in the Poisson notes. nbinom did not inherit those
atoms. C++ still sends every non-Poisson GLM-outer family to
`mspl_c_n = 1` and to the Bernoulli radial.

---

## Why Poisson does not transfer

Programme constitution Phase 4
(`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`):
derive Poisson first; then treat NB1 and NB2 as separate families;
separate mean-boundary penalties from dispersion \(0\) / \(\infty\);
finite count fits are not the result. Both prep notes already kill
“Poisson worked, so NB does.”

Three transfer failures stay live on `main`:

1. **Weights.** Poisson \(W=\operatorname{diag}(\mu)\) is not NB2
   \(\mu\varphi/(\varphi+\mu)\) and not NB1 exact \(I_\eta\). Oracles
   E1 / N1–N3 already fire that contrast. The Poisson limit of a
   weight is a limit, not inheritance: NB2 recovers Poisson as
   \(\varphi\to\infty\); NB1 recovers Poisson as \(\varphi\to 0\).
2. **Rate.** Poisson \(c_P=2\sqrt{p_{\mathrm{free}}/\max(\sum y,1)}\)
   uses observed event count. NB2 information is not \(\sum y\) and
   does not double when exposure doubles (oracle E4). NB1 exact
   information is not the quasi sum \(\sum\mu/(1+\varphi)\) and is
   not \(\sum y\) (oracles N9–N10). Copying \(c_P\) is the same class
   of transplant as copying Bernoulli \(c_n\) or Gaussian \(c_N\).
3. **Loading atom.** Poisson \(V_\lambda^P\) weights the radial term
   by trait means \(\bar y_t\). The live nbinom tape does not even
   use that atom: it uses Bernoulli \(V_{\mathrm{loading}}\), which
   both prep notes prove is \(\mu\)-inert and \(\varphi\)-inert
   (N11 / E7). That is a forbidden transplant on the **current**
   door, not a future risk.

A fourth failure is the missing parameter. Poisson has no
\(\varphi\). NB2’s mean atom silently pushes \(\varphi\to\infty\)
(hostility note in
`docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`).
NB1’s mean atom *increases* as \(\varphi\to 0\) and therefore cannot
repair that boundary. Those are keep-or-drop science questions, not
Poisson leftovers.

---

## What the Poisson admit packet actually was

The honest template is #1008 + G0, not the full Phase-4 exit gate
and not the #990 smoke.

`docs/dev-log/research/2026-08-15-mspl-poisson-admit-packet.md` pinned
three objects and matched them to the live tape:

- rate \(c_P\) from event count, with all-zero floor and vanishing
  as \(\sum y\to\infty\);
- loading atom \(V_\lambda^P=\sum_t(\sqrt{1+\|\lambda_t\|^2\bar y_t}-1)\);
- unchanged GLM-outer Jeffreys \(P_J^*=\tfrac12\log\det(X_*^\top W X_*)\),
  \(W=\operatorname{diag}(\mu)\).

`tests/testthat/test-mspl-poisson-admit-packet.R` A1–A8 are the
contract: A1–A6 are pure-R pins against Bernoulli / Gaussian
transplants; A7 is a live `estimator="mspl"` fit that checks
`report$mspl_c_n`, `report$mspl_V_loading`, and
`report$mspl_logdet_information` against the R twins; A8 holds the
registry token. Helpers live in `R/mspl-poisson-atoms.R`.

G0 then flipped `planned` → `admitted` as an **experimental point**
with evidence token `admit_packet`, not `covered`, and left the #990
admit-evidence FAIL in the notes
(`docs/dev-log/after-task/2026-08-16-mspl-poisson-admit-g0.md`).
That is the bar nbinom must meet, family by family: pinned rate,
pinned loading atom, live TMB/R twins, registry still honest until
G0. It is not a licence to skip the pins because Poisson already
flipped.

---

## Honest nbinom packet (two cells, not one)

Write **two** packets. Shared prose is allowed; shared atoms are
not. NB1 and NB2 do not inherit each other’s scale or theorem.

### 1. Pinned rate \(c\)

The live door’s \(c=1\) is the same placeholder the Poisson packet
retired. An honest pin must name an information-size proxy for
**this** likelihood and reject four transplants in the same test
file: Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\),
Gaussian \(c_N=\sqrt{2/N_{\mathrm{units}}}\), Poisson \(c_P\), and
unit scale \(c=1\).

Prep notes already name the proxies a later derivation must argue
from, without pinning the formula tonight:

- **NB2:** \(\operatorname{tr}(W)=\sum_i \mu_i\varphi_i/(\varphi_i+\mu_i)\)
  or \(\lambda_{\min}(X_*^\top W X_*)\). Exposure doubling multiplies
  weights by \(2(\varphi+\mu)/(\varphi+2\mu)\in(1,2)\), not by 2.
- **NB1:** \(\sum_i \mathcal I_\eta(\mu_i,\varphi)\), the PMF-summed
  exact information. Not quasi \(\sum\mu/(1+\varphi)\), not
  \(\sum\mu\), not \(\sum y\).

All-zero / tiny-mean floors, and whether a known offset at fixed
observed \(y\) may move \(c\), need the same explicit pins Poisson
A2–A3 gave \(c_P\). AGENT-INFERRED analogy is allowed; copying
\(c_P\) and renaming the family is not.

### 2. Pinned loading atom

The live tape’s Bernoulli radial is already a kill (N11 / E7).
Poisson \(V_\lambda^P\) is also a kill unless a new argument shows
why overdispersed counts should still weight by raw \(\bar y_t\).
Hirose \(\sum S_{jj}/\psi_j\) is a type error: ordinary NB has no
free \(\Psi\), and \(\psi:=\varphi\) or \(\psi:=1/\mu\) is a rename.

A later candidate has to be coercive as \(\|\lambda_t\|\to\infty\)
on traits that carry mean information, inert (or owned by Jeffreys)
on all-zero traits, and rotation-invariant in the factor space.
Weighting the radial term by the **family** information weight
(trait-mean of NB2 \(W\) or of NB1 exact \(I_\eta\)) is the obvious
thing to evaluate. It is not pinned here. Laplace-marginal loading
coercivity remains OPEN in both prep notes; the packet must either
close that or state experimental-point status as honestly as
Poisson did.

### 3. Dispersion keep-or-drop (the Poisson packet did not need this)

- **NB2.** Mean atom \(P^*_{J,\mu}\) already moves with \(\varphi\)
  and collapses as \(\varphi\to 0\). A separate Jeffreys-on-\(\varphi\)
  atom \(P^*_{J,\varphi}=\tfrac12\log I_{\varphi\varphi}\) fights the
  Poisson limit \(\varphi\to\infty\). The packet must keep or drop
  that atom in writing. Taping \(\tfrac12\log I_{\varphi\varphi}\) on
  `log_phi_nbinom2` without \(I_{\log\varphi}=\varphi^2 I_{\varphi\varphi}\)
  is already a kill (E1). The quasi stand-in
  \(\tfrac12(\mu/(\mu+\varphi))^2\) is also a kill.
- **NB1.** Mean atom increases toward Poisson as \(\varphi\to 0\)
  (N6) and diverges as \(\varphi\to\infty\) (N7). Using the mean
  atom as a \(\varphi\to 0\) repair is a type error. A dedicated
  \(\varphi\) atom is OPEN. Quasi \(W=\mu/(1+\varphi)\) stays
  diagnostic-only.

### 4. Live TMB / R twins (Poisson A7)

Add a family-specific admit-packet test that **does** call
`gllvmTMB(..., estimator = "mspl", se = FALSE)` on a tiny ordinary
cell and checks `report$mspl_c_n`, `report$mspl_V_loading`, and
`report$mspl_logdet_information` against R twins of the **pinned**
atoms. Today’s Phase-4 oracle files still refuse that live call;
that was correct when the door was closed. It is now the missing
A7, not a virtue.

The same test must fail if the tape still reports \(c=1\) or
Bernoulli \(V_{\mathrm{loading}}\) after the pins land.

### 5. Smoke (operational vs admit-evidence)

A local `se = FALSE` multi-seed point smoke, split the way #990
was split: operational PASS is every arm finite and converged;
admit-evidence PASS is not claimed from finiteness. Constitution
Phase 4 still wants healthy-regime no-harm, labelled boundary DGPs
(which of \(\mu\to 0\), \(\varphi\to 0\), \(\varphi\to\infty\) is
active), prediction, and penalty sensitivity before a *covered*
claim. Poisson G0 did not wait for that full exit. nbinom G0 may
use the same experimental-point bar, but only after items 1–4
exist. Do not start Totoro / DRAC from this note (D-50 / D-139).

### 6. Non-transfer pins that must stay red

Keep the existing E1–E7 / N1–N13 contrasts. Add live-tape versions
once A7 exists:

- NB2 \(W\neq\mu\); NB1 exact \(I_\eta\neq\) quasi \(\neq\mu\);
- \(c\neq c_P\neq c_n\neq c_N\neq 1\);
- \(V_{\mathrm{loading}}\) is not the nbinom atom;
- \(\theta=1/\varphi\) does not turn NB2 into NB1 except at
  \(\mu=1\) (N8);
- truncated / hurdle / mixed-family nbinom stay out.

---

## Minimal PR shapes

### Admit PR — do not open

An admit PR is a registry flip of
`nbinom1:log:ordinary:q{1,2}` and/or
`nbinom2:log:ordinary:q{1,2}` from `planned` / `phase4_prep` to
`admitted` / `admit_packet`, plus the test sweep Poisson G0 did.
**Evidence for that flip is not in-repo.** Opening it tonight would
be the kill both prep notes already wrote: admission-shaped
language ahead of the Shinichi gate.

### Packet PR (the next real slice)

One family per PR unless both packets are already written. Shape,
mirroring #1008:

1. `R/mspl-nbinom2-atoms.R` **or** `R/mspl-nbinom1-atoms.R` —
   internal rate + loading + Jeffreys helpers. Do not export.
2. `src/gllvmTMB.cpp` — replace `c=1` and Bernoulli radial for
   that `mspl_family_mode` only. Do not touch Poisson \(c_P\) /
   \(V_\lambda^P\).
3. `R/mspl.R` — prepare-path rate must match the tape (today it
   already documents unpinned \(c=1\) for nbinom).
4. `tests/testthat/test-mspl-nbinom2-admit-packet.R` (or NB1) —
   A1–A8 twins: transplants fail; live fit matches; registry stays
   `planned`.
5. Research note + after-task. No NEWS. No `covered`. No public SE.

Registry stays `planned` until a later G0 PR, exactly as #1008
left Poisson.

### Prep-only PR — not opened by this sitting

A draft that only adds this note, or that only adds live A7 twins
of the **current** \(c=1\) + Bernoulli radial door, would pin a
known-bad tape. That is not a tiny oracle gap. Pure-R GLM-outer
oracles are already complete (N1–N13, E1–E7). The missing work is
to **choose** \(c\) and \(V_\lambda\), then match them. Doing that
in a scout sitting would invent the science the packet is supposed
to argue.

---

## Verdict table

| Surface | Verdict | Why |
|---|---|---|
| Planned public door on `main` | **already there** | #1007 replay; `planned` / `phase4_prep` |
| Pure-R GLM-outer weight oracles | **PASS** | N1–N13 / E1–E7; no live MSPL |
| Honest admit packet (rate + loading + \(\varphi\) keep/drop + A7) | **FAIL / absent** | \(c=1\); Bernoulli \(V_{\mathrm{loading}}\); no family helpers; no live twins |
| Multi-seed smoke | **absent** | no nbinom analogue of #990 |
| Admit tonight | **no** | packet missing; Poisson G0 does not transfer |
| Prep-only PR tonight | **no** | remaining gaps are the packet, not a tiny R fill |
| NEWS `covered` / public SE / validation-register MSPL promotion | **no** | out of scope; MSPL-01..05 stay Bernoulli-shaped |

---

## Non-claims

This note does not claim that the planned nbinom door is broken as
a compile/fit surface; door tests already allow a finite call. It
does not claim Poisson admission was a mistake. It does not pin an
nbinom rate or loading atom. It does not decide the NB2
Jeffreys-on-\(\varphi\) keep/drop. It does not authorise Totoro,
DRAC, or a GitHub Actions campaign. It does not absorb Codex Lane B.
It does not speak for truncated nbinom, hurdle, beta, or Tweedie.

## Rose boundary

- `planned` ≠ `admitted`. nbinom rows stay `phase4_prep`.
- Poisson `admitted` ≠ nbinom `admitted`.
- NB1 ≠ NB2.
- GLM-outer \(X_*^\top W X_*\) is not \(I_{LA}(\beta)\).
- Live \(c=1\) and Bernoulli \(V_{\mathrm{loading}}\) are
  placeholders / transplants, not packet pins.
- No NEWS `covered`. No public `vcov()` / `confint()`.
- This sitting edits no `R/mspl-registry.R` and no `src/`.

## Sources

- Door replay: `docs/dev-log/after-task/2026-08-16-mspl-nbinom-planned-door.md`
- NB1 prep: `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom1-prep.md`
- NB2 prep: `docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md`
- Five-atom hostility: `docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`
- Poisson packet: `docs/dev-log/research/2026-08-15-mspl-poisson-admit-packet.md`
- Poisson G0: `docs/dev-log/after-task/2026-08-16-mspl-poisson-admit-g0.md`
- Constitution Phase 4: `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- Live rate / loading dispatch: `src/gllvmTMB.cpp` (`mspl_c_n = 1` for
  non-Bernoulli, non-Poisson GLM-outer; `gll_mspl_row_radial_penalty`
  unless `mspl_family_mode == 3`)
- Registry: `R/mspl-registry.R` `planned_nb` block
