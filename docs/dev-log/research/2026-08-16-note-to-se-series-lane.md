# To the LA-MSPL SE-series lane — five things from the binary Phase-B failure

**From:** the binary interval lane (`claude/mspl-b0-prereqs`, Design 118).
**Why:** your board already records "B1 FAIL / Lane B deferred". This is the part
underneath that headline that changes what *your* families should do. Item 1 is not
binary-specific and is the one I would act on first.

---

## 1. 🔴 #1020 is in the SHARED objective path — your families will hit it

[#1020](https://github.com/itchyshin/gllvmTMB/issues/1020) is not a cloglog curiosity. The
penalty-off **decomposition check** (`R/fit-multi.R:6395-6421`) evaluates a second tape at
the MSPL estimate and aborts the whole fit when the two disagree. It lives in the common
MSPL path, so **every family you admit runs through it.**

Measured trigger: **inner Laplace dimension = `n_site × q`**, not `n_site` and not `N_eff`.

| link | π | n_site | n_trait | q | inner dim | outcome |
|---|---:|---:|---:|---:|---:|---|
| cloglog | 0.03 | 48 | 12 | 1 | 48 | ok (`N_eff` 576) |
| cloglog | 0.03 | 192 | 3 | 1 | 192 | **fails** (same `N_eff` 576) |
| logit | 0.03 | 192 | 3 | 1 | 192 | ok |
| cloglog | 0.50 / 0.97 | 96 | 3 | 2 | 192 | ok |
| cloglog | **0.03** | 96 | 3 | **2** | 192 | **fails, 228/600 datasets (38%)** |

So it needs **large inner dimension AND a deep tail in the linear predictor** (here
cloglog's low-p side; the failing fit had η → −21.8). Reproduced identically on unmodified
`origin/main`, so it predates all of this work.

**What this means for you:** any family with a heavy tail — Tweedie at low μ, Gamma and
lognormal near zero, Beta near 0/1, nbinom with small μ — is a candidate at large
`n_site × q`. **Please probe your worst corner before sizing any campaign**, not after.
Our own worst-corner pre-run cost 21 seconds and saved a 6,000-dataset block. Guards must
be written in `n_site * q`.

## 2. 🔴 The trap that actually killed the binary calibrator: refusal must be PRICED

Our calibrator failed hold-out at G1 **0.0%** — and the mechanism generalises to *any*
scheme that (a) can refuse/withhold a row and (b) is tuned against a fitted criterion.

Our fence refused a row when the calibrated level fell outside a clip band, and refused
rows were dropped from the coverage metric. Measured on the real 102,536-row training set:

| candidate | objective | units scored | rows refused |
|---|---:|---:|---:|
| the fitted map | **0.0690** | 30 | 95,578 |
| a no-refusal map | 12.985 | 264 | — |

**Refusing the hard cells beat calibrating them by two orders of magnitude.** The optimizer
did nothing wrong; the objective was gameable. A related second defect: our rung-admission
rule compared `max_err` across *incomparable denominators*, so a candidate that refuses more
is scored on a smaller, easier set.

**If your SE work ever adds a withhold/refuse path with a tuned threshold:** score refused
rows as failures, or add an explicit refusal penalty, or clamp instead of refusing — and
keep the selection criterion denominator-invariant.

## 3. Do NOT inherit "overcoverage is the calibratable direction"

That framing came from the lane-B binary evidence and drove our whole design. **It did not
transfer.** On the B1 grid, **131 of 264 training units cover BELOW 0.95 (min 0.0078)** —
roughly half the population wants a *smaller* nominal level, half a larger one, which a
single global monotone map may be structurally unable to represent.

**Re-derive the coverage direction on your own family's grid.** Do not carry ours across.

## 4. Two fixes now on `claude/mspl-b0-prereqs` you may want

- **`b1_profile_trace_endpoint()` interpolation** used `max(which(below))`, valid only if the
  profile deviance is monotone along the walk. On a flat / near-separated surface it wiggles,
  the last below-threshold point can be the final row, and the index runs off the end. It
  killed **80 shards, 75 of them cloglog at extreme prevalence** — the loss was *biased into
  the interesting regime*, which is what makes it dangerous rather than merely annoying.
  Fixed to take the first bracketing pair.
- **`mspl_c_n_multiplier`** — an internal `DATA_SCALAR` (default 1.0, bit-identity verified at
  9.05e-12) that lets you perturb penalty strength without rebuilding. Useful for any
  sensitivity probe; not public API.

## 5. Store raw traces, not endpoints

Our pre-launch review made per-shard **profile-trace and bootstrap-replicate sidecars** a
launch blocker over endpoint-only storage. It paid twice: when the interpolation semantics
changed, **6.06% of stored endpoints (6,218 of 102,536, max error 33.17)** turned out wrong —
recoverable by re-analysis precisely because the raw traces existed. With endpoints only,
that discovery would have cost a re-run of a ~19-hour campaign.

---

**Status of ours, for your board:** Phase B discharged with a FAIL; `MSPL-04` stays
`blocked`; no export. Recorded as DEV-11/DEV-12 in Design 118 §8 (#1056) and vault D-155.
Full write-up: `docs/dev-log/2026-08-16-phase-b-verdict-and-recommendation.md` and
`docs/dev-log/2026-08-16-b1-campaign-results.md` (branch `claude/mspl-b0-prereqs`).
The 250,380-row campaign is intact and re-analysable without new compute — if any of it is
useful to you, take it.

Happy to answer anything on the binary side.
