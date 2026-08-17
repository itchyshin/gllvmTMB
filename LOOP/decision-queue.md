# Decision queue — mspl-profile-led-ci

**Lane:** `claude/lane-mspl-profile-led-ci` @
`/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`  
**Updated:** 2026-08-17 (post-S2). Parks consequential decisions for Shinichi.
Empty/OPEN does **not** waive `LOOP/GOAL.md` hard stops.

**Already locked (do not re-open here):**

| Item | State |
|---|---|
| Triad Confirm | **SIGNED** 2026-08-17 (D-157 + D-12) |
| Design number | **CLAIMED 125** @ `b68b20b4` |
| Design 118 / B1 / Arc 1A | **PARKED** (D-157; Arc 1A historical) |
| #1077 tip | draft `fb44d7b5` — undraft is a **separate** gate (not Gate 3) |
| Totoro / public `se=TRUE` / live MSPL `confint` | **not-ready** until separate G0s |

**Safe meanwhile (no paste needed):** S3 note that card stays UNSIGNED; S4 Rose fence; V1 mechanical verify; C1 after-task/handover. Do **not** invent KEEP/REPLACE/PARK.

---

## OPEN GATES — paste one option under each

Reply in chat (or append `SIGNED` + the pasted line into the cited card). Defaults apply only if you stay silent.

---

### Gate 1 — Poisson \(W=\operatorname{diag}(\mu)\) KEEP / REPLACE / PARK

**State:** **UNSIGNED** card  
**Card:** `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md`  
**Why open:** Ranga (#1064) — live Poisson Jeffreys is one-sided (\(W=\mu\) vanishes at \(-\infty\), rewards \(+\infty\)). Blocks honest further SE-series doors; **orthogonal** to Design 125 binary profile-led path.  
**If silent:** treat as **PARK further SE doors** (tape unchanged; no invent).

Paste **one**:

```text
G1 KEEP. Poisson stays W=diag(mu). Name one-sided gap in admit notes. No SE door from this atom. Tape not replaced.
```

```text
G1 REPLACE. Swap Poisson W=diag(mu) for working logistic W_* (later src/ twin rematch). No public se. No door tonight.
```

```text
G1 PARK SE doors. No new SE-series doors until KEEP or REPLACE. Q0 stays reporting target. Tape unchanged. Card stays UNSIGNED until KEEP/REPLACE.
```

---

### Gate 2 — Open PR: Design 125 + Confirm + LOOP kit → `main`

**State:** OPEN / docs-only merge decision  
**On branch (ahead of `origin/main`, not yet PR’d as this kit):** Design stub
`docs/design/125-mspl-profile-led-intervals.md`, triad Confirm, ADEMP pre-reg
draft, R0/R1 notes, `LOOP/` kit, check-log — commits from `7de94fc7` through
S2 (`04c344fd` tip may move).  
**Does not include:** undraft #1077, `R/`/`src/` interval code, Totoro, NEWS covered.  
**Recommendation:** **OPEN draft docs PR** so `main` gets the Design number claim + fences; keep #1077 separate draft.

Paste **one**:

```text
G2 OPEN-DRAFT-PR. Open a draft docs PR from claude/lane-mspl-profile-led-ci for Design 125 + Confirm + LOOP/pre-reg kit to main. No undraft #1077. No R/src. No Totoro.
```

```text
G2 OPEN-READY-PR. Same kit as ready-for-review (non-draft) docs PR to main. Still no undraft #1077 / no live intervals / no Totoro.
```

```text
G2 HOLD-BRANCH. Do not open a PR yet; keep kit on claude/lane-mspl-profile-led-ci only until S3/S4/V1 close.
```

```text
G2 SQUASH-LATER. Defer PR; continue S3∥S4 on branch; open PR only after Rose fence + checkpoint refresh.
```

---

### Gate 3 — Authorize **local** profile smoke after S2

**State:** OPEN / not-ready until paste  
**Arc:** H1 (blocked on G0 in `LOOP/arcs.md`)  
**Scope if YES:** local-only L0/L1-style plumbing or tiny smoke under Design 125 binary envelope — **optional HANDS TO Codex**.  
**Still forbidden by this gate alone:** Totoro/DRAC · undraft #1077 · public `confint`/`se=TRUE` · MSPL-04 flip · NEWS covered.  
**Recommendation:** **WAIT** until Gate 4 scope + profile fork A/B/C signed; smoke without fork pick is premature.

Paste **one**:

```text
G3 WAIT. No local profile smoke yet. Finish S3/S4/V1 docs; re-ask after Gate 4 (scope + fork A/B/C) is signed. #1077 stays draft. No Totoro.
```

```text
G3 LOCAL-SMOKE-YES. Authorize local-only profile smoke (L0/L1) after S2 under Design 125 binary-first. HANDS TO Codex OK. Still NOT Totoro. Still NOT undraft #1077. Still NOT public se=TRUE.
```

```text
G3 LOCAL-SMOKE-YES-FORK-A. Same as LOCAL-SMOKE-YES, and freeze MSPL profile fork = A (penalised MSPL objective) for the smoke.
```

```text
G3 LOCAL-SMOKE-YES-FORK-B. Same as LOCAL-SMOKE-YES, and freeze MSPL profile fork = B (unpenalized Laplace at fixed MSPL nuisance) for the smoke.
```

```text
G3 NO-SMOKE. Docs-only path continues; no smoke authorization this programme until separate explicit G0.
```

---

### Gate 4 — Design 125 stub scope still TBD (sign or widen)

**State:** soft OPEN — Ada defaults recorded in Design 125 §3 + ADEMP draft; **not signed**  
**Sources:** `docs/design/125-mspl-profile-led-intervals.md`;  
`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §Open G0  
**If silent:** keep Ada defaults; do **not** widen claim set; do **not** silent-pick fork A/B/C.

#### 4a — Family / claim set

```text
G4a BINARY-FIRST. Confirm Design 125 §3.1: Bernoulli LA-MSPL first (logit local; probit/cloglog later arms). Poisson off coverage claim until G1 resolved.
```

```text
G4a WIDEN-POISSON. Explicitly add Poisson to first profile-led claim set (requires G1 KEEP or REPLACE first — not PARK alone).
```

#### 4b — Estimands

```text
G4b E1-E2-ONLY. Confirm stub estimands: E1 intercept β0t; E2 loading Λt1 (d=2 only if later signed arm). E3 = Wald(Q0) availability diagnostic only.
```

```text
G4b ADD-ESTIMAND. <name the estimand> — only if you type it; otherwise refuse silent expansion.
```

#### 4c — MSPL profile fork (do not silent-pick)

```text
G4c FORK-A. Profile penalised MSPL objective.
```

```text
G4c FORK-B. Profile unpenalized Laplace at fixed MSPL nuisance point.
```

```text
G4c FORK-C. Hybrid — only with a one-line pre-reg description of the hybrid.
```

```text
G4c FORK-DEFER. Leave A/B/C open; block Gate 3 smoke and any live profile impl until fork is picked.
```

#### 4d — Pre-reg numeric freeze (L\*/T\* / \(n_{\mathrm{rep}}\))

```text
G4d THRESHOLDS-DEFER. Keep ADEMP draft placeholders; freeze L*/T*/n_rep only when signing the pre-reg (or a successor). No Totoro from placeholders.
```

```text
G4d THRESHOLDS-SIGN-NOW. Treat current ADEMP proposed numbers as frozen for local gates (n_site∈{40,80}, T∈{4,8}, L1 cov_eff Wilson not entirely below 0.80, avail≥0.90, refusal≤0.15; T* still need explicit numbers before Totoro).
```

#### 4e — Bootstrap resampling (asymmetry arm)

```text
G4e BOOT-PARAMETRIC. Asymmetry arm = parametric bootstrap for v1 DGP; percentile; BCa ablation-only.
```

```text
G4e BOOT-CLUSTER. Asymmetry arm = unit-cluster nonparametric; percentile; BCa ablation-only.
```

```text
G4e BOOT-DEFER. Leave parametric vs cluster open until pre-reg sign; no bootstrap smoke until then.
```

---

## Not-ready (listed so they are not confused with Gates 1–4)

| Gate | Default | Unlocks only when |
|---|---|---|
| Undraft #1077 | **not-ready** | Design 125 + pre-reg signed + tests + **explicit** undraft ask |
| Live `confint(method="profile")` for MSPL | **not-ready** | Design G0 + fork + tests |
| Public `se=TRUE` / `vcov` | **not-ready** | Separate G0 (D-148/D-149) |
| Totoro / claim campaign | **not-ready** | Signed pre-reg + L1–L2 + Design 124-style admission + D-50/D-139 G0 |

---

## One-block paste (optional — fill blanks)

```text
SIGNED 2026-08-17 — mspl-profile-led-ci decision queue
G1: <KEEP | REPLACE | PARK SE doors>
G2: <OPEN-DRAFT-PR | OPEN-READY-PR | HOLD-BRANCH | SQUASH-LATER>
G3: <WAIT | LOCAL-SMOKE-YES | LOCAL-SMOKE-YES-FORK-A | LOCAL-SMOKE-YES-FORK-B | NO-SMOKE>
G4a: <BINARY-FIRST | WIDEN-POISSON>
G4b: <E1-E2-ONLY | ADD-ESTIMAND: …>
G4c: <FORK-A | FORK-B | FORK-C: … | FORK-DEFER>
G4d: <THRESHOLDS-DEFER | THRESHOLDS-SIGN-NOW>
G4e: <BOOT-PARAMETRIC | BOOT-CLUSTER | BOOT-DEFER>
Still NOT: undraft #1077 · Totoro · public se=TRUE · Design 118 reopen
```
