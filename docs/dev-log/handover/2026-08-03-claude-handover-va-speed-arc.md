# Session Handoff: the VA speed arc — RE-AIMED at the probit closed form

**Meta:** 2026-08-03 · from Claude · to Claude · fresh context required
**Worktree:** `/private/tmp/gllvmtmb-va-speed`, branch `claude/va-speed-arc`, cut from `origin/main` @ `19e9cedd`
**Arc plan:** `dev/va-speed/ARC.md` · **Profile:** `dev/va-speed/PROFILE.md` · **Literature:** `dev/va-speed/LITERATURE.md`

```
🎯 GOAL — paste verbatim to set a fresh session's goal

PLATFORM: Claude Code, solo. gllvmTMB. Lane: VA speed arc.
Worktree /private/tmp/gllvmtmb-va-speed, branch claude/va-speed-arc @ origin/main 19e9cedd.
NEVER build from the Dropbox checkout (PROTECTED, D-112, ~700 commits behind).

DELIVERABLE: our VA fits the reference cell in time comparable to gllvm's WITHOUT losing
our accuracy edge. Speed is the objective; accuracy is the CONSTRAINT, not the trade.

THE TARGET (identical single-tier model, identical data, planted truth, binomial-probit,
N=250 T=20 q=1, 4 seeds):
    gllvm VA     0.70 s   rel_frob 0.359
    OUR VA      45.6  s   rel_frob 0.298   <- 65x SLOWER, 17% MORE ACCURATE
    our Laplace 114.5 s   rel_frob 0.170

HEADLINE: the profile and the literature INDEPENDENTLY agree the cost is GAUSS-HERMITE
QUADRATURE, and that the fix is to REPLACE it, not optimise around it. A closed-form probit
VA exists (Albert-Chib truncated-Gaussian, proved at GLLVM level by Hui/Warton/Ormerod/
Haapaniemi/Taskinen -- the paper gllvm itself implements). Uses only Phi/phi, TMB-native
atomics. This is an OBJECTIVE-FUNCTION SUBSTITUTION, not an architecture change.

DEPRIORITISED ON EVIDENCE: block-diagonal S (borrowing #3). The profile shows the INNER
solve is NOT the bottleneck -- nnz/dim flat (Stage 7) AND inner iteration count flat (this
profile). #3 targets a cost that is not there.

DISCIPLINE: every speed change leaves the OBJECTIVE identical (~1e-13) -- EXCEPT the
closed-form substitution, which is a DIFFERENT objective and needs its own accuracy
evidence. Interleaved timing, never a single sequential pass. n_starts must be 1, 3 or 4.
H must be 15, 25 or 61. Results LOCAL (D-50). VA fence stays SHUT; nothing promoted.
```

## Critical context

1. **Our VA is CORRECT, and more accurate than the mature reference.** It beats gllvm's VA on
   4/4 paired seeds (rel_frob 0.298 vs 0.359). Stage 7's KL agrees with a direct-algebra oracle
   to 2.26e-16, and this is now confirmed **end-to-end on recovery**, which it never had been.
   **Do not go looking for a correctness bug. There isn't one.** This is purely cost.
2. **The problem is Gauss-Hermite, measured two independent ways.**
3. **The maintainer's priority, verbatim:** *"getting correct and speedy VA will help a lot if
   we are already fitting the best algorithm to suitable distributions (families)."* VA is
   primary; EVA is secondary and conditional.
4. **Everything downstream is gated on this.** The Design 108 structured VA-vs-Laplace question
   cannot be measured at the sizes that matter, because VA does not finish there.

## The evidence that re-aimed the arc

### Profile (`dev/va-speed/PROFILE.md`) — single-tier fit, 18.3 s

| phase | s | % |
|---|---:|---:|
| `nlminb` optimisation | **16.25** | **89.0%** |
| — of which `obj$gr()` | 10.58 | 65.1% of primary (174 calls, 60.8 ms/call) |
| — of which `obj$fn()` | 5.51 | 33.9% of primary (215 calls, 25.6 ms/call) |
| `MakeADFun` taping | 0.84 | 4.6% |
| post-processing | 0.09 | 0.5% (**no `sdreport` exists in this engine at all**) |

**GH is ~75% of TOTAL wall-clock** (measured by H-node scaling: 79.8%/82.4% of each fn/gr
call at H=15). `fn`+`gr` together are 93.2% of the fit; GH is ~75-82% of that. Non-GH AD and
bookkeeping inside fn/gr is ~18%; everything else combined is ~7%.

**The decisive measurement — per-call cost scales with the number of GH nodes:**

| H | fn ms/call | gr ms/call |
|---:|---:|---:|
| 15 | 23.27 | 57.13 |
| 25 | 46.67 | 110.27 |
| 61 | 92.63 | 226.47 |

Roughly proportional to `H`. **The quadrature loop IS the per-call cost.** Remove it and the
89% bucket largely goes with it.

**Also measured:** `n_starts = 4` — the package DEFAULT — costs **3.88x** `n_starts = 1`
(72.12 s vs 18.58 s). A knob, not a fix, but a large one.

### Structured tier (Q2) — the joint/profile split, and why #3 is deprioritised

| n_tip | route | outer par | per-call (ms) |
|---:|---|---:|---:|
| 20 | joint | 680 | 0.60 |
| 600 | joint | 20,400 | **615.17** |
| 20 | profile | 32 | 1.43 |
| 600 | profile | **32** | **33.54** |

R3's `profile=` route works exactly as designed: outer parameters **constant at 32** regardless
of N. The joint route's blowup is `nlminb`'s own dense quasi-Newton over a linearly growing
coordinate vector — **not** the inner solve. The profile confirms **per-iteration cost is the
driver**, and that the inner solve is healthy: `nnz/dim` flat (Stage 7) *and* inner iteration
count flat (this profile).

**Consequence: borrowing #3 (block-diagonal `S`) targets a bottleneck that is not there.**
`ARC.md` pre-committed to this outcome — *"if the profile says the time is in a place neither
borrowing touches, the arc must re-aim rather than build them anyway."* It does; so it must.

### Literature (`dev/va-speed/LITERATURE.md`) — independent agreement

- **A closed form for probit VA EXISTS.** Albert-Chib truncated-Gaussian auxiliary variables
  (`z_ij ~ N(eta_ij, 1)`, truncated by `sign(y_ij)`), proved **at GLLVM level** by Hui, Warton,
  Ormerod, Haapaniemi & Taskinen — the paper gllvm's own VA engine implements. Their **Theorem 1**
  covers binary probit, **Theorem 3** cumulative-probit ordinal. Quoted: *"using a probit link…
  offers a fully closed form VA log-likelihood."* **No numerical integration.**
- Uses only `Phi`/`phi` — **TMB-native smooth atomics**. An objective substitution, not an
  architecture change. By contrast AIRWLS / SVI / natural gradients do **not** fit TMB's
  `MakeADFun`-then-optimise pattern as drop-ins.
- **GHQ cost is confirmed exponential in latent dimension, and NO source makes GHQ cheaper —
  every speed-up replaces it outright.** That is the same conclusion the profile reached.
- **Theorem 3 also covers ordinal probit** — Ayumi's other hard column, which Design 108 calls
  *"the hard case."*

**Honest caveat on our own proof:** the literature agrees qualitatively with Design 106
Proposition 2 but proves **no equivalent iff-theorem** for GLLVM loading structure (Goplerud et
al. prove a parallel but *distinct* result for mixed-model design nesting). Prop 2 may be
genuinely novel, or narrower than we think. Do not cite it as settled literature.

## 🔴 THE BIGGEST FINDING — a validated 39x fix already exists and is NOT the default

The full profile (landed after the first draft of this handover) found that the structured
tier's blowup is **not** GH, not TMB, not the tape, and not the inner solve. At N=1000 it is
**99.83% `nlminb`'s own outer quasi-Newton bookkeeping**, with genuine `fn()`/`gr()` work at
**0.17%** — because the DEFAULT `profile_variational = FALSE` route hands `nlminb` a parameter
vector that grows linearly with N (outer par = 34xN exactly, at every point measured).

| route | outer par | per-call scaling | at N=1000 |
|---|---|---|---|
| `profile_variational = FALSE` (**the default**) | 34xN → 34,000 | **~N^2.1** | 2,268.61 ms |
| `profile_variational = TRUE` (opt-in, Stage 7-validated) | **32, constant** | **~N^0.9** | **39x faster, gap growing** |

**The fix is already in the codebase, already correctness-validated by Stage 7, and simply
is not on by default.**

And the stated reason for keeping it off may be moot. R3's handover justified the `FALSE`
default as *"`sdreport()` across the profiled block is untested"* — but this profile confirms,
by reading the source AND by grep, that **VA-R3 has no `sdreport()` machinery at all**. The
concern is about a future SE story, not current behaviour on this path.

**ACTION: check whether `profile_variational = TRUE` can become the default for the prototype
path.** Verify the objective is unchanged, confirm the sdreport rationale really is
inapplicable, then flip it. This is the cheapest large win available and it requires no new
mathematics.

*Reconcile before trusting:* an earlier measurement in this session recorded a structured-tier
fit exceeding 3600 s **with `profile_variational = TRUE` set**, which does not sit easily
beside the profile's N^0.9 result. One of the two is missing a condition (likely T, `n_starts`,
or the GH family — the profile used `gaussian_anchor` to remove the GH confound). **Reproduce
both before building on either.**

## Next steps, in order

0. **FIRST, and cheapest — resolve the `profile_variational` default** (see the red section
   above). A validated 39x fix that needs no new mathematics. Reconcile the conflicting
   >3600 s measurement before acting.
1. **PRIMARY — implement the closed-form probit VA objective** (Albert-Chib). Read
   `LITERATURE.md` §2 first for the construction and citation. This is a new `expectation` tier
   alongside `exact`/`quadrature`/`bound` in `.va_r3_family_registry`
   (`R/va-r3-proto.R:~1148`), plus a template branch. **It is a DIFFERENT objective from the GH
   one** — it must carry its own accuracy evidence against planted truth, not inherit GH's.
2. **Verify accuracy is not lost.** The acceptance floor is `rel_frob <= 0.298` — our current
   edge over gllvm is the thing being protected. A faster VA that recovers worse than 0.298
   fails the arc.
3. **Then re-measure vs gllvm**, interleaved, on the reference cell.
4. **Then the family sweep (P0b)** — gaussian/poisson (exact) vs probit/nbinom2 (quadrature).
   The profile has largely pre-answered it, but it confirms the mechanism across families and
   is cheap.
5. **Revisit `n_starts = 4` default** (3.88x). Not a fix; a documented knob.
6. **DEFERRED:** borrowing #3 (block-diagonal `S`) — deprioritised on profile evidence, not
   abandoned. Borrowing #4 (staged warm-up) has **no literature support**; the corpus does not
   address it at all.
7. **CONDITIONAL: the EVA arm (P0c)** — see below.

## The EVA arm — approved, conditional, and NOW LIKELY SUPERSEDED

Approved by the maintainer on condition that EVA is what I claimed. **Verified in six places:**
EVA is a 2nd-order Taylor surrogate, `E[log p] ~= log p(y|mu) + (v/2) d2/deta2 log p|_mu`
(`docs/design/104-va-family-coverage.md:56`), Korhonen et al. 2023, and confirmed empirically —
not just by reading — in `docs/dev-log/2026-07-31-eva-misuse-probe.md:145`.

**But the Albert-Chib route likely supersedes it**, because EVA is a **surrogate, not a bound**
— *"it can sit either side of the truth"* — and that is not a theoretical worry:

> The 2026-07-31 misuse probe defaulted to *"we are at fault"*, checked the reconstruction
> byte-for-byte against gllvm's own `getLoadings()`, and still concluded **GENUINE METHOD
> BEHAVIOUR**: EVA's own objective scores its runaway solution (attenuation 8.8e+08) at
> **-327.4** and the **true generating parameters** at **-618.6** — preferring the degenerate
> answer by **291 nats**. And MORE restarts make it WORSE (`n.init=5` -> 3.8e+08, `n.init=10`
> -> 6.3e+08), because gllvm selects the restart with the best EVA objective and the degenerate
> mode *has* it.

Albert-Chib gives closed form **while remaining a genuine bound**. Strictly better if it holds.
**Run the EVA arm only if the closed form fails.**

**A gating question nobody has answered:** are **Ayumi's binomial columns Bernoulli or
multi-trial?** gllvm's EVA fits Bernoulli (logit and probit) but **rejects multi-trial binomial**
— measured. This matters for any EVA comparison and was never checked.

## Corrections carried forward — do not re-derive

- **`gllvm` EVA DOES fit Bernoulli**, including probit. It rejects only `Ntrials > 1`. An earlier
  claim in `PILOT-FINDINGS.md` that it "cannot fit binomial at all" was **my test error** and is
  corrected in `b9480ccf`.
- **"VA is slower than Laplace at every tested n" does NOT hold universally.** At the reference
  cell our VA is **2.4x FASTER** than our own Laplace (47 s vs 114 s). The 640-cell headline is
  configuration-dependent; do not cite it unqualified.
- **Three false alarms this session came from MY invalid arguments**, not from defects: `H = 11`
  (must be 15/25/61), `n_starts = 2` (must be 1/3/4), and `Ntrials = 6` for EVA. **Never
  conclude a capability is absent from one failed call — vary the argument first.**

## Landing state

| artifact | state |
|---|---|
| `dev/va-speed/ARC.md`, `PROFILE.md`, `LITERATURE.md` | written, **UNCOMMITTED** in the worktree |
| `dev/va-speed/*.R` profiling scripts | written, uncommitted |
| Design 108 recovery campaign | separate worktree `/private/tmp/gllvmtmb-d108-recovery`, branch `claude/d108-recovery-campaign`, **committed**, blocked on this arc |
| PR #917 (register-code guard) | **OPEN**, needs review |
| PR #915 (reader-facing jargon) | **MERGED** |

## How to resume

```sh
cd /private/tmp/gllvmtmb-va-speed
git status -sb
# Read in order: dev/va-speed/ARC.md -> PROFILE.md -> LITERATURE.md (§2 first)
NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet=TRUE)'
```

Reference measurement to reproduce before changing anything:
`/private/tmp/gllvmtmb-d108-recovery/dev/design108-recovery/pilot-results/job2f_fourway.rds`
