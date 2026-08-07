# cran-comments

> **DRAFT skeleton for gllvmTMB 0.6.1 — Path A.** First CRAN **upload** identity.
> A GitHub-only `v0.6.0` @ `c0af58d3` already used the `0.6.0` string outside CRAN;
> this draft is for **`0.6.1`**. This file is `.Rbuildignore`d. **Submission is
> Shinichi's act alone** (M5-g). Platform rows below are **TBD until exact-tag
> D-49 evidence** at the frozen `0.6.1` SHA — do **not** treat July `v0.6.0`
> receipts as tip evidence (~618 commits behind `origin/main` at Path A start).

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

`gllvmTMB` is released as **experimental** (lifecycle: experimental). Point
estimates are the supported claim. Interval coverage evidence exists only for
the documented `profile_ci_total_variance()` regime (gaussian unit-tier total
variance under named size limits; status `certified-0.94` marks regime
membership); other interval routes remain recovery-oriented or uncalibrated.
Covariance routes have focused-test evidence only. Laplace remains the package
default; AGHQ and VA stay opt-in / experimental / fenced.

## Test environments

**TBD at exact tag** (fill at S7/S8 after candidate freeze). Candidate identity
is Version `0.6.1` at the **S6 option B freeze tip** on
`cursor/cran-path-a-0.6.1-20260807` (post-`#949` `main` integrated; see
`docs/dev-log/plan-actual/2026-08-07-gllvmtmb-cran-path-a-s6-freeze-packet.md`).
Platform rows stay empty until exact-tag D-49 evidence.

Planned rows (do not invent results):

* local: macOS (Apple silicon), R version TBD — `R CMD check` on the built
  tarball with `--as-cran` and CRAN incoming feasibility enabled, **at the tag**
* GitHub Actions three-OS matrix — ubuntu-latest, macos-latest, windows-latest,
  R **release** — full suite and vignettes **at the tag**
* GitHub Actions heavy regression suite — three-OS **at the tag**
* win-builder R-devel / macbuilder — budgeted before upload (M5)

## R CMD check results

**TBD until exact-tag `--as-cran`.** Do not copy July `0.6.0` / `c0af58d3`
`0E/0W/1N` figures here as current evidence.

Expected shape for a first submission (when measured): **0 errors | 0 warnings |
1 NOTE** ("New submission"), or whatever the frozen-SHA check actually returns.

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
