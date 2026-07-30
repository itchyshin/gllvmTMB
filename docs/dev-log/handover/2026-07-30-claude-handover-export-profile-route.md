# Claude → Claude handover — export the certified profile route

**2026-07-29.** The certificate arc is **closed and merged**. This hands over the arc the maintainer
chose next: give the certified interval route a user-facing entry point.

## Mission control

| | |
|---|---|
| **repo / branch** | gllvmTMB · lane `claude/export-profile-ci-20260729`, off `main` @ `d2a2e926` |
| **shipped today** | first certified interval (evidence), a certificate-record reconciliation, 4 instrument defects found and fixed/withdrawn |
| **claim state** | **register records the certificate; `NEWS.md` deliberately does NOT.** No public capability claim exists |
| **compute** | Totoro **idle**. Two 20k campaigns retained LOCAL (D-50) at `~/gllvm_work/profile_rescore/run20k-20260729/` and `run20k-v2-20260729/` — **do not delete**, they are the certificate's evidence |
| **START HERE** | this doc → `docs/dev-log/2026-07-29-certificate-disposition.md` |

## What is settled — do NOT re-litigate

- **The certificate: D-43 CERTIFY 3-0.** gaussian d1-n150 coverage 0.9467169 (band 0.9434896),
  d2-n150 0.9467216 (band 0.9435366), against a pre-registered `>= 0.94` gate, 20,000 reps/cell,
  fresh seeds. Full disposition in `2026-07-29-certificate-disposition.md`.
- **The gate.** 0.94, rep-level 2·MCSE band, both cells, `profile_total` on gaussian d ∈ {1,2},
  n=150. Not renegotiable in either direction — and **not retroactively tightened** by requirements
  no lens raised before the run.
- **The two v1 defects.** Seed reuse and failure accounting are verified fixed from primary sources
  by two lenses each.
- **Register, not NEWS.** Maintainer decision 2026-07-29. `CI-08` carries the evidence; its status
  stays `partial` because the route is unexported, the psi target fails, and 13/15 of its original
  cells remain below gate.
- **A third seed window is prohibited** (pre-registration v2). Two attempts is already the edge of
  seed-shopping.

## The arc: export `.profile_ci_total_variance()`

**Why it matters.** The certificate currently describes a function users cannot call. The route they
*can* call for the same estimand, `bootstrap_Sigma()`, covered **0.78** in the same campaign. So
today's work closed a gap in the *evidence* surface and none in the *capability* surface. Exporting
is the move that converts one into the other.

### What I established before handing over

**1. Follow `profile_ci_phylo_signal()`. There are three conventions in one file — pick the right one.**

| symbol | naming | actually exported? |
|---|---|---|
| `profile_ci_phylo_signal()` | no dot | **yes** — the template |
| `profile_ci_correlation()`, `profile_ci_communality()` | no dot | **no** — `@keywords internal` + `@noRd` despite public-looking names |
| `.profile_ci_total_variance()` | dot-prefixed | no |

So a public-looking name is *not* evidence of export in this file. Name the export
`profile_ci_total_variance()` and follow the phylo_signal roxygen (~22 lines) as the model.

**2. The signature is already clean and needs no wrapper.**
`(fit, tier = c("unit","unit_obs","phy","B","W"), trait_idx = NULL, level = 0.95)`, returning a
`data.frame` (`R/profile-derived.R:813`).

**3. 🔴 THE DESIGN DECISION — and the reason I stopped rather than improvising.**

The function accepts **five tiers** and any `level`. **The certificate covers exactly one tier
(`unit`), one family (gaussian), diagonal `Sigma_unit`, d ≤ 2, n ≥ 150, two-sided.** Exporting it
unfenced would advertise a capability surface far wider than the evidence — which is precisely what
this whole arc's goal forbids: *"Close the gap; do not widen the model surface."*

**The package already has the right idiom, and it is not prose.** Elsewhere it labels rows with an
`interval_status` field — `"route-only"`, uncalibrated — so calibration is *machine-visible*
(see the `MIX-10` and `EXT-04` register rows). Recommended shape:

- Export with the full argument space, but **emit `interval_status` per row**: something like
  `"certified-0.94"` only for gaussian × `tier = "unit"` × diagonal × d ≤ 2 × n ≥ 150 × two-sided,
  and `"route-only"` everywhere else.
- Roxygen states the 0.94 gate explicitly and **never** "nominal 95%".
- Carry the four fences from the disposition: two-sided only (one-sided invalid); marginal average
  that fails in the smallest-`V_t` ventile; conditional on convergence; unexported→now-exported does
  not change what was measured.

Rejected alternatives, with reasons: a narrowed wrapper that *errors* outside the certified regime
(too paternalistic — the uncertified tiers are legitimately useful for exploration); and prose-only
fencing (the failure mode this repo keeps hitting is a true-but-narrow number restated more broadly,
and prose does not survive restatement).

### Work remaining

1. `@export` + full roxygen on `profile_ci_total_variance()`; regenerate `NAMESPACE` and `man/`.
2. Implement the `interval_status` labelling.
3. Tests: the certified regime returns `"certified-0.94"`; each uncertified axis returns
   `"route-only"`; a smoke that the exported name resolves from a **loaded namespace**, not just
   `load_all()`.
4. `NEWS.md`: an entry is now appropriate — the *capability* is new. Still no coverage claim beyond
   the fenced scope, and the maintainer's register-not-NEWS decision was about the **certificate**,
   not about announcing an export. **Confirm with them before writing NEWS.**
5. Ask whether `profile_ci_correlation()` / `profile_ci_communality()` should be renamed with dots
   or exported too — a pre-existing inconsistency I deliberately did not touch.

## Gotchas paid for today

- **`rep_seed` is a function of the rep INDEX**, so re-running without `--rep-start` silently
  re-scores the same datasets. This cost a full 3-hour campaign and a WITHHELD panel. Verify seed
  disjointness **from recorded seeds** before launch, never from launcher intent.
- **`rep_seed` is also non-injective across `d`** (`+ 1000L * d`): the two certified cells share
  19,000 of 20,000 seeds. **Offset the multiplier before adding any cell** to the certificate.
- **CI cannot see the heavy tests.** 798 were skipped in the passing run, including
  `test-m3-grid-summary.R`, which asserts on `m3_summarise`. Run
  `GLLVMTMB_HEAVY_TESTS=1` explicitly; green CI is not a clean bill.
- **A failure that emits no row is invisible.** Two defects today were this: `n_failed = 0` while
  607 fits failed, and the "Gamma crash" that was a caught link error whose CSV write sat inside the
  success branch.
- **Check the primary source.** Three claims failed verification today — the handover's premise, my
  own "which docs are on `main`", and an H3-inversion drawn from one agent's analysis.
- Never push twice quickly; GitHub auto-cancels the in-flight run.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git worktree add /private/tmp/gllvmtmb-export2 claude/export-profile-ci-20260729
```

One-command resume:

```
claude "Rehydrate from docs/dev-log/handover/2026-07-30-claude-handover-export-profile-route.md, then export profile_ci_total_variance() with per-row interval_status labelling as the design section specifies."
```
