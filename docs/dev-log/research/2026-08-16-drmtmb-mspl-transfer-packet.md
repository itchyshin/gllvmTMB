# Transfer packet — drmTMB MSPL implementation guide

**Date:** 2026-08-16
**Purpose:** Point gllvmTMB MSPL agents at the drmTMB port guide.
**Do not** treat this as a gllvmTMB capability claim.

## Where to read / execute

| Location | Path |
|---|---|
| **Primary (drmTMB)** | `/Users/z3437171/Dropbox/Github Local/drmTMB/docs/design/225-mspl-implementation-guide.md` |
| Mirror in this repo | `docs/dev-log/research/2026-08-16-drmtmb-mspl-implementation-guide.md` |
| Brain | `projects/drmTMB/MSPL implementation guide for drmTMB.md` (shinichi-brain; also linked from `projects/drm-tmb`) |

## One-line summary

drmTMB should port LA-MSPL **discipline** (Laplace outer + soft Jeffreys/Huber penalty + registry + se=FALSE first + SE pins ≠ intervals) from gllvmTMB; it should **not** port loadings/Hirose/Poisson multivariate admit atoms. Sterzinger & Kosmidis (2023) matches drmTMB fixed-design logistic/`zi`/`hu` better than GLLVM.

## Brain decisions that bind the port

- **D-50 / D-139 / D-142 / D-143** — compute routing and approval line
- **D-149** — internal SE pins ≠ public calibrated intervals
- MSPL-interval **D-148** — do not copy gllvmTMB public-interval claim without a drmTMB pre-reg
- Lane note `FOR-DRM-LANE-2026-08-08-separation-borrowable-from-the-literature` — drmTMB is the proving ground
