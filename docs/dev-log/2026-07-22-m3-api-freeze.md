# M3 — source / API freeze record

**Frozen 2026-07-22** on `claude/0.6-m1-close-20260722`, on the maintainer's sign-off. This is the
only 0.6 feature-integration window; it closes here.

## 1. The freeze fingerprint

Pinned by checksum rather than asserted in prose, so later drift is **detectable** rather than a
matter of someone's recollection.

```
FREEZE_SHA           5cacf173b8d55b001ba8848ec3ea019f0d658c68
NAMESPACE  SHA-256   c97ae039f1a58346a129e988e127cc8464a401264eb530d6a7da905fd329ff46
DESCRIPTION SHA-256  2cdd822dcb3ab31e67db8cfd478db5be1af959eeadf1d89205d96abcfe362897
```

**To verify the API has not moved since the freeze**, from inside the worktree:

```sh
shasum -a 256 NAMESPACE
# c97ae039... => the surface is unchanged
```

Any other value means the API moved after the freeze and needs a new maintainer gate.

## 2. What is frozen

| Directive | Count |
|---|---:|
| `export(...)` | **153** |
| `S3method(...)` | **33** |
| `importFrom(...)` | 19 |
| `useDynLib(...)` | 1 |

`NAMESPACE` at `5cacf173` is the authoritative list; it is not duplicated here, because a duplicated
list is a second source of truth that goes stale.

**Also frozen:** the source tree, the feature list, and the permissible-claims set (§4).

### 2a. Two dot-prefixed exports are deliberate, not accidental

`.proportions_wald_ci` and `.proportions_bootstrap_ci` are exported **with `@keywords internal`** —
the standard idiom for a function that must be in the namespace for technical reasons but is not
public API. Both are documented (`man/dot-*.Rd`), neither is mentioned in any vignette, README or
NEWS, and both are consumed internally by `R/z-confint-gllvmTMB.R`. **Checked before freezing rather
than assumed.**

### 2b. Eight deprecated names remain live exports — and their warnings genuinely fire

`animal_unique` · `kernel_unique` · `phylo_unique` · `spatial_unique` · `gllvmTMB_wide` ·
`meta_known_V` · `delta_poisson_link_gamma` · `delta_poisson_link_lognormal`

Freezing commits 0.6 to carrying these. That is the correct call for a **first** CRAN release —
removing an export is a user-visible break, and there is no prior release from which users could
have migrated.

**Verified they are not silent, by the right instrument.** A bare call to
`phylo_unique(1 | sp)` emits nothing, which initially looked like a defect. It is not: the
deprecation fires during the **formula rewrite walk**, not at construction.
`.gllvmTMB_warn_unique_family_deprecated()` is invoked from **six** sites in `R/brms-sugar.R`
(2770, 3144, 3384, 3406, 3546, 3735). The code comment at `brms-sugar.R:120` records why the
mechanism is hand-rolled rather than `lifecycle::deprecate_soft()`: that function is **silent for
indirect in-package callers**, so the user would never see it in a real fit. Replaced with an
env-based one-shot `cli_warn` by maintainer decision, 2026-06-20.

**The lesson generalises:** a bare-call probe tests construction, not the path the user takes. It
would have produced a false "these are silent" finding.

## 3. What is NOT frozen — deferred, with its gate named

- **M4** — reader-facing pages, Rd, pkgdown, NEWS prose. Documentation may still change; the **API**
  may not.
- **D-41's mandatory experimental warning** is still **unverified** and gllvmTMB is **not** exempt:
  pkgdown callout, README badge, `lifecycle` experimental badges on exports, `.onAttach` message,
  and a line in the DESCRIPTION `Description`. **A release blocker for M4/M5 if absent.**
- **The claim-string class outside the five R-11 files** — `man/`, the shipped vignette, `NEWS.md`,
  `README.md`, the DESCRIPTION `Description` — was never swept. An M4 item.
- **0.7, explicitly out of scope:** EVA (cut 2026-07-21), the Design 86 feasibility lane
  (design-only, admits no capability to 0.6 under any outcome), R-6's identifiability guard, R-7 site
  (d)'s gate repair, and #750's SPDE/`phylo_diag` unconditional redraw.

## 4. Permissible claims for 0.6 — the frozen set

**May be said:**

- The package fits stacked-trait GLLVMs with phylogenetic, spatial, kernel and meta-analytic
  structure, by **Laplace approximation**, and passes `R CMD check --as-cran` cleanly on Linux,
  macOS and Windows.
- Variance-component and loading **point estimates** are the supported inferential claim.
- A route is **"covered"** when it dispatches and is dispatch-tested.

**May NOT be said — each is forbidden by a specific record:**

- That any cell is **coverage-calibrated**. `docs/design/75:96-99` forbids it, and `CI-08` records
  the gate as **FAILED** — 13 of 15 cells below 94%, only Gaussian d=1 and d=3 clearing. `CI-10` is
  0.55.
- That `"covered"` implies calibrated Wald coverage (`docs/design/75:88-90`).
- That non-Gaussian **interval** calibration is established. It is not.
- That binomial-logit phylogenetic **slope variance** recovers (R-2: over-estimated ~50–60%, 21
  seeds failing, bias not diminishing with n, test skipped).
- That `simulate()`-based intervals are valid for the **SPDE spatial tier** or `phylo_diag` (R-5:
  they fall back to conditional simulation and are too narrow — including `bootstrap_Sigma()`).
- That delta/hurdle **latent-scale correlation** is supported (FAM-17 / MIX-10: do-not-advertise).
- **EVA, in any form.** 0.6 is Laplace-only.
- **Release readiness.** Per D-49 name the rung; per D-66 it is **NOT READY, below source-clean** —
  the gap is *evidence, not capability*.

## 5. The bump invalidated M1's receipts — and the eighth chain has been earned

The version bump `0.5.0 → 0.6.0` is a **source edit**, so it **invalidated every M1 platform
receipt** — the three-OS matrix at `d13916f3`, the heavy run, and the CRAN-configuration check all
qualify a **pre-bump identity**. **By design, not a regression.**

### The eighth chain, at the bumped SHA `458dc01b`

| Check | Result |
|---|---|
| `devtools::test()` (local) | `FAILED 0 \| ERROR 0 \| SKIP 779 \| PASS 7290` — identical to pre-bump |
| Three-OS matrix `29934531169` | **SUCCESS** — `ubuntu-latest`, `macos-latest`, `windows-latest`; three `Status: OK` lines, **zero** ERROR/WARNING/NOTE |
| Heavy full-check `29934532873` | `FAIL 0 \| WARN 10 \| SKIP 103 \| PASS 13656`, `Status: OK` |
| CRAN-configuration check | **0 errors, 0 warnings, 1 NOTE, 0 unexpected.** The NOTE is *"New submission"* under incoming feasibility — allowlisted. `SHA_STABLE=TRUE`. |

**The chain is COMPLETE at `458dc01b`.** All four legs green on the bumped identity.

**The build actually produced `gllvmTMB_0.6.0.tar.gz`.** Confirmed from the log — so the bump took
effect in the *built artefact*, not merely in the source files. Checking the files alone would not
have established this.

### The heavy counts oscillated back to the certified baseline — corroborating the diagnosis

This run returned `WARN 10 | SKIP 103 | PASS 13656`, which is **exactly** the original certified
baseline at `21e04eb5`. The immediately preceding run at `d13916f3` returned `WARN 9 | SKIP 102 |
PASS 13650`.

That is independent confirmation of the mechanism recorded in `check-log.md`: the contingent sites
are **optimiser-convergence-dependent**, so the counts oscillate between runs of functionally
identical code — here, oscillating *back* to the baseline values. It further confirms the standard
derived from it: **an exact set match between two heavy runs cannot establish that an arc added no
warning site**, because the set is not a function of the code alone. `FAIL 0`, which does not vary,
is the gate.

M5 must still price its own exact-**tag** three-OS cycle; this chain qualifies the bumped branch
head, not a tag.

## 6. What this freeze does NOT authorise

No merge, no candidate freeze, no RC tag, no final tag, no CRAN submission, and no readiness or
release claim. Each remains a separate maintainer gate. **No exception is self-granted.**

> Related: `docs/dev-log/2026-07-22-m1-closing-claim.md` · `docs/dev-log/known-residuals-register.md`
> · `docs/design/75-inference-route-truth-matrix.md` · `LOOP/checkpoint.md` · PR #780
