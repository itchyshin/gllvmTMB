# Sweep: brain — MSPL next (Phase 0.25)

**Date:** 2026-08-15  
**Role:** read-only brain scout (Cursor Models bar). No `src/`. No commit.  
**Rung:** MCP `search_notes` (`search_all_projects: true`) plus Grep of
`memory/DECISIONS.md` and `memory/AGENT_LOG.md`.  
**Companion scouts:** `_sweep-shannon-mspl-next.md` (process),
`_sweep-git-mspl-next.md` (git). This file is the vault only.

Classification for the three G0 nouns: **decided in the brain** /
**open in the brain** / **absent from the brain** (repo may already
have closed it; this scout does not re-derive the repo).

## 1. Queries cited

### MCP `search_notes` (`search_all_projects: true`)

| # | Query | What it actually retrieved |
|---|---|---|
| Q1 | `"LA-MSPL interval"` | **Hit:** [[dr34-la-mspl-parallel-estimator-distilled]] (score 0.74). **Noise:** drmTMB / hsquared Wald–profile interval after-tasks (`sigma_CTmax`, Poisson `laplace_reml_interval`, small-sample t-calibration). The phrase “interval” pulled the wrong package. |
| Q2 | `"Lane B MSPL"` | **Miss on the Codex MSPL SE lane.** Top hits were `journal/2026-08-09` (drmTMB untracked MSPL files) and Mission Control “Lane B” interval-feasible *cells* (`2026-08-01-mission-control-lane-b-ref-persistence`). drmTMB “Lane: R” after-tasks dominated the rest. |
| Q3 | `"LA-MSPL"` (follow-on; Q1 was too noisy) | **Hits:** DR34; `projects/deep-research/readme`; `PROJECT-NOTEBOOKS` LA-MSPL notebook `10f82316-…`; D-141 Fir B2 PROTECTED; `ENGINEERING-NOTEBOOK` 2026 factor-analysis ingest. |
| Q4 | `"MSPL Lane B interval feasibility"` | Still Mission Control Lane B / drmTMB, not `codex/lane-b-mspl-interval-feasibility`. |
| Q5 | `"codex/lane-b-mspl-interval-feasibility"` | **No vault note under that branch name.** Closest: Mission Control `codex/lane-b-q1-preflight-admission` (a different Lane B). |
| Q6 | `"MSPL uniqueness pick C admit Hirose SE estimand"` | **No hit on pick C, Hirose `admitted`, or an MSPL SE estimand.** DR34 and `PROJECT-NOTEBOOKS` again. |
| Q7 | `"LA-MSPL interval SE estimand Wald profile"` | drmTMB / register profile-interval noise. No LA-MSPL SE estimand note. |
| Q8 | `"MSPL penalty scale c sqrt 2/n Hirose"` | `ENGINEERING-NOTEBOOK` 2026 FA paper. No Poisson `c=` decision. |

### Ledger Grep (`MSPL|Phase 4|Lane B|interval`, last 25 lines each)

**`memory/DECISIONS.md` tail-25** (lines 2863–4656 of the match list).
Load-bearing for this scout:

- **D-112** (accepted, 2026-08-01): 0.6 ships **recovery-only**
  variance-component / Sigma intervals; post-0.6 invests in
  capabilities, **not** coverage. Do not imply calibrated coverage.
- **D-135** (accepted, 2026-08-09): binomial probit/cloglog is 0.7.0.
  Design 252 §7 *“MSPL stays logit-only, even in 0.7.1”* is **not**
  overridden. MSPL itself does **not** gain probit/cloglog unless
  Shinichi says so separately.
- **D-141** (accepted, 2026-08-11): evidence-led validation pilot is
  internal cards only. **“The live LA-MSPL Fir B2 campaign remains
  PROTECTED and cannot be used as a pilot.”**
- **D-133** mentions 11 untracked files of an experimental MSPL
  estimator in `drmTMB-rose-nit` — backup/push hygiene, not a science
  decision.
- Other tail hits are **not** LA-MSPL Phase 4: ultra-plan Phase 4 /
  Phase 4.5 Melissa (sweep-receipt teeth); drmTMB random-effect-SD
  profile coverage; Mission Control **Lane B** interval-feasible
  *cells* (`codex/lane-b-e0-readiness`). Those “Lane B” and “Phase 4”
  strings are homonyms.

**`memory/AGENT_LOG.md` tail-25** produced **two** matching entries
(the live log was rolled 2026-08-14; older MSPL lines are in
`AGENT_LOG-archive`):

- **2026-08-14 — MSPL Arc 1A G0 approved.** Stacked
  `cursor/mspl-arc-1a-provenance`; do not wait on #961. **“Design 117
  and the interval-feasibility lane stay protected.”**
- **2026-08-14 daily check.** Three unpushed MSPL commits on
  `drmTMB-rose-nit` reported, **not pushed** (D-88).

Archive Grep (not requested; used only to confirm the roll):
`ENGINEERING-NOTEBOOK` 2026 FA ingest; drmTMB untracked MSPL estimator;
“3 unpushed MSPL commits.”

## 2. What the brain holds (durable)

| Note | Permalink / path | Load-bearing sentence |
|---|---|---|
| DR34 (2026-08-14, `verified-primary-plus-bounded-search`) | `shinichi-brain/projects/deep-research/dr34-la-mspl-parallel-estimator-distilled` | LA-MSPL is a **research programme** parallel to LA-ML (shared Laplace engine, different outer criterion). Evidence does **not** support a default, automatic fallback, general-family capability, **calibrated inference**, or model-comparison claim. Unit of work = `family/link × targeted boundary × covariance × parameterization`. |
| PROJECT-NOTEBOOKS | `memory/project-notebooks` row “gllvmTMB — LA-MSPL parallel-estimator programme” (`10f82316-…`) | Smoke: corpus does **not** justify general GLLVM MSPL or a default. Supports experimental **binary-logit** start + matched **Gaussian factor** anchor. Poisson / NB / ordinal / multinomial under Laplace are **absent** and need new derivations. **No-default / no-inference fences.** |
| ENGINEERING-NOTEBOOK § 2023 mixed-logistic | `memory/engineering-notebook` | Sterzinger & Kosmidis 2023: composite Jeffreys + negative-Huber; scales `c1`, `c2` “soft enough”; recommended mixed-logistic scale in DR34 is \(2\sqrt{p/n}\). MSPL coverage in *that* paper’s simulation is not a GLLVM/Laplace theorem. |
| ENGINEERING-NOTEBOOK § 2026 factor analysis | same, ingested 2026-08-10 | Sterzinger, Kosmidis & Moustaki 2026: Gaussian EFA Heywood; soft rate; proposed scale \(\sqrt{2/n}\) (DR34). Vanilla Akaike / Hirose exist but have “questionable finite-sample properties in estimation, **inference** and model selection.” Status: **UNVERIFIED beyond abstract and §1.** |
| Separation / JSDM gap | `memory/Separation in JSDMs is an unclaimed gap — and it may be what Zuur and Ieno actually found` | MSPL **does not transfer** to a design with *estimated* latent variables. That non-transfer is the research question. |
| D-112 | `memory/decisions` | Recovery-only intervals; no coverage chase. |
| D-135 | same | MSPL stays logit-only. Link generalisation ≠ MSPL-on-probit. |
| D-141 | same | Fir B2 campaign PROTECTED. |
| AGENT_LOG 2026-08-14 | `memory/agent-log` | Interval-feasibility lane stays protected. Arc 1A was the last named MSPL G0 in the live log. |

DR34’s own boundary: the durable *package* roadmap is the repo
constitution
`gllvmTMB/docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`.
**Live repository state and primary papers outrank this snapshot.**
This scout reports the vault; it does not promote the constitution
into a new brain decision.

## 3. Decided vs open — the three G0 nouns

### Admit

**Decided (brain).**

- Admission is **per cell**, not per family and not “MSPL mode”
  (DR34; constitution pointer in DR34 § Programme boundary).
- **No default, no automatic fallback, no general-family claim**
  (DR34; PROJECT-NOTEBOOKS smoke).
- Binary-logit remains the theoretically motivated *experimental*
  start; Gaussian Heywood is the first *new* proof-to-code anchor;
  Poisson is a **new derivation**, not an inheritance
  (DR34 AGENT-INFERRED sequence 1–4).
- Probit / cloglog for **MSPL** stay a separate question (D-135).
  drmTMB link generalisation does not admit gllvmTMB MSPL on those
  links.
- Fir B2 / interval-feasibility campaigns are **PROTECTED** and are
  not admission evidence (D-141; AGENT_LOG 2026-08-14).

**Open (brain).**

- Whether **Poisson** (or any count family) may flip
  `planned` → `admitted`. The vault says the route “begins as a new
  methods derivation” (DR34 absence finding). It does **not** record
  a later Shinichi yes.
- Whether NEWS may say `covered`. Brain fence is no public
  recommendation / no release promotion (DR34).
- Whether MSPL ever gains probit / cloglog (D-135: not decided
  there).

**Absent from the brain (do not invent).**

- Hirose Gaussian `admitted` / `oracle_local` as named vault IDs.
- Poisson `planned` / `phase4_prep` registry rows.
- The 2026-08-15 tapes GOAL “Nobody is admitted.”

Those are repo-lane facts. The brain’s standing rule is enough to
block an admit-without-Shinichi move; it is not a substitute for the
registry.

### `c` (penalty scale)

Two homonyms. This scout treats **`c` = soft penalty scale**.
Repo “uniqueness pick C” is a different noun (below).

**Decided (brain).**

- Gaussian factor paper: soft rate; proposed scale
  \(\sqrt{2/n}\) (DR34).
- Mixed-logistic paper: recommended scale \(2\sqrt{p/n}\); `c1`,
  `c2` must be soft enough that \(\nabla P\) vanishes relative to
  observed information (ENGINEERING-NOTEBOOK 2023; DR34).
- Scale is part of the **cell**, not a package-wide constant
  (DR34 unit of work; constitution atom 4 “penalty atom and
  asymptotic scale”).
- Do not transplant a Bernoulli or Gaussian rate onto Poisson
  (DR34 sequence 4: “exposure-aware information”; sequence 5: NB
  waits until mean and dispersion boundaries are separated).

**Open (brain).**

- The numerical `c` for **Poisson** (and every later family).
  Vault has no Poisson scale pick. “`c = 1` unpinned” is a repo
  tape fact, not a brain decision.
- Whether \(\sqrt{2/n}\) or \(2\sqrt{p/n}\) is even the right
  *form* once the design includes estimated latent variables
  (JSDM gap note: non-transfer is the question).
- Sensitivity / ablation of `c` as a falsifier is required
  (DR34 mandatory falsifiers include scale ablations) but no
  winning value is recorded.

**Absent from the brain.**

- **Uniqueness pick C** (Gaussian \(\Psi\) map, repo
  `2026-08-15-mspl-gaussian-psi-uniqueness-map.md` / #966).
  Q6 returned nothing. If a later planner says “C is closed,”
  that closure lives in the repo, not here.

### SE estimand

**Decided (brain).**

- **No calibrated-inference claim** for LA-MSPL (DR34;
  PROJECT-NOTEBOOKS “no-inference fences”).
- Package-wide interval posture remains **recovery-only**
  (D-112). Post-0.6 does not buy a coverage campaign.
- The interval-feasibility lane stays **PROTECTED** and is not
  merge-authorised from a Cursor point/tapes sitting
  (AGENT_LOG 2026-08-14; D-141 Fir B2).
- Interiority ≠ scientifically preferable; a penalty that
  forces an interior point can worsen bias when the truth is
  on the boundary (DR34 counterpoints: Chung et al.; Greenland
  & Mansournia). That blocks “finite ⇒ advertise an SE.”
- Vanilla Hirose / Akaike inference is **not** a free lunch
  even in the matched Gaussian factor model
  (ENGINEERING-NOTEBOOK 2026, UNVERIFIED past §1): judge the
  penalty by what it does to standard errors.

**Open (brain).**

- **What the SE is of.** The vault never names
  penalized-objective profile vs penalty-off curvature at the
  MSPL point vs estimator-refit bootstrap vs sandwich/Godambe
  as the LA-MSPL estimand. Those four constructions live in
  the *repo* constitution Phase 7. The brain only says:
  do not treat “an interval” as calibrated, and do not merge
  the protected lane.
- Gaussian SE and Poisson SE. No vault G0 grants either.
- Schema-v2 repeated-sampling coverage. D-112 parks the
  coverage chase; DR34 says the evidence is not there yet.
- Whether mixed-logistic MSPL’s “good coverage” in the 2023
  paper’s 10,000-replicate simulation transfers to
  Laplace-GLLVM. DR34: exact-likelihood theory does **not**
  transfer automatically to Laplace; adaptive quadrature /
  Laplace have only a weaker numerical condition, not a
  general theorem.

**Absent from the brain.**

- The branch name `codex/lane-b-mspl-interval-feasibility`.
  Q2 and Q5 did not retrieve it. “Lane B” in the vault is
  mostly **drmTMB Mission Control** interval-feasible cells
  (D-112 neighbourhood; `codex/lane-b-e0-readiness`). Do not
  cite those 152 cells as MSPL SE evidence.
- A named SE estimand for loadings vs \(\Psi\) vs \(\beta\).

## 4. Homonym traps (so the next planner does not reuse Q2)

| String | Vault meaning | Not this |
|---|---|---|
| **Lane B** | drmTMB Mission Control interval-feasible *cells*; `codex/lane-b-e0-readiness` | Codex `lane-b-mspl-interval-feasibility` (binary SE). That lane is named only as “interval-feasibility lane” in AGENT_LOG. |
| **Phase 4** | ultra-plan Phase 4 / Phase 4.5 Melissa (sweep-receipt teeth) | LA-MSPL programme Phase 4 (Poisson then NB). |
| **interval** | drmTMB RE-SD profile coverage; D-112 recovery-only Sigma language | An admitted LA-MSPL SE. |
| **c / C** | literature soft scales \(\sqrt{2/n}\), \(2\sqrt{p/n}\) | Repo uniqueness pick C. |
| **MSPL estimator files** | drmTMB `R/mspl.R` untracked on 2026-08-09 (D-133) | gllvmTMB `R/mspl.R` on this worktree. |

## 5. Receipt (Phase 0.25)

```text
QUERIES
  MCP search_notes search_all_projects=true
    "LA-MSPL interval"
    "Lane B MSPL"
    + follow-ons Q3–Q8 (cited in §1)
  Grep memory/DECISIONS.md  MSPL|Phase 4|Lane B|interval   (tail 25)
  Grep memory/AGENT_LOG.md  MSPL|Phase 4|Lane B|interval   (tail 25)

DECIDED (vault)
  admit = per-cell; no default; no general family; MSPL stays logit-only (D-135);
          Fir B2 / interval lane PROTECTED (D-141, AGENT_LOG 2026-08-14)
  c     = literature soft scales √(2/n) Gaussian-FA and 2√(p/n) mixed-logistic;
          scale is per-cell; do not transplant onto Poisson
  SE    = no calibrated-inference claim (DR34); recovery-only (D-112);
          protected lane is not a Cursor merge source

OPEN (vault)
  admit Poisson / NEWS covered / MSPL-on-probit
  Poisson (and later) numerical c
  SE estimand (which construction; which parameter; Gaussian/Poisson SE)

ABSENT (vault) — do not invent from chat
  uniqueness pick C
  Hirose admitted / oracle_local
  branch name codex/lane-b-mspl-interval-feasibility
  Phase-7 four-construction list (repo constitution only)
```

## 6. What this sitting is allowed to do

Allowed without a new G0: keep the protected interval lane
untouched; do not flip `planned` → `admitted`; do not pick a
Poisson `c` from the 2023/2026 papers; do not advertise an SE.

Needs a **new G0** (brain agrees with the tapes handover OWED
list): Poisson admit, any public `mspl` on NB1/NB2/beta/Tweedie,
Gaussian or Poisson SE, Totoro campaign, NEWS `covered`.

The brain does **not** authorise a Cursor SE slice. Q2’s “Lane B”
hits are the wrong Lane B.
