# GOAL: auto-d-recovery (gllvmTMB latent(d = "auto") rank-recovery test)

## Mission
Measure how often gllvmTMB's `latent(d = "auto")` picks the true number of latent variables, on simulated data where the true rank is known, across the families and sizes a user would meet. Deliver a recovery table (proportion correct, under- and over-selection, by family, n_units, n_traits, true d and criterion), with Monte Carlo uncertainty, and a short written verdict per family on whether the default criterion (`bic_sites`) can be recommended.

## Base
The preserved branch `claude/lane-auto-d-r-20260926` (closed PR itchyshin/gllvmTMB#1324), which carries `latent(d = "auto")` and the `select_lv` guard, ridge and `bic_sites` work. Read its after-task `docs/dev-log/after-task/2026-09-27-auto-d-select-lv.md` first, and the NB re-run already reported by the earlier auto-d lane (GLLVModels.jl PR itchyshin/GLLVModels.jl#629). Extend that evidence; do not repeat it.

## Invariants
- Test only. Do not change `R/`, `man/`, `NAMESPACE`, `NEWS.md`, `inst/COPYRIGHTS` or `docs/dev-log/check-log.md`. The 0.7.1 CRAN resubmission lane owns `R/gllvmTMB.R`, `man/gllvmTMB.Rd`, `inst/COPYRIGHTS`, `NEWS.md` and `check-log.md`. If a test finds a bug, write it up with a reproducer; do not fix it here.
- Do not push to or delete `claude/lane-auto-d-r-20260926`; work on this lane's own branch.
- gllvmTMB lane kits live at `docs/dev-log/lanes/<lane>/LOOP/`: move the scaffolded kit there (git mv), fix the paths in checkpoint.md, and commit before filling it.
- Design the simulation with the simulation-design skill (ADEMP): state the data-generating process, the estimand (selected d versus true d), the conditions and the performance measures before running anything.
- Compute: Totoro (at most 150 cores; OPENBLAS_NUM_THREADS=1, cap threads at launch; existing socket). State a time estimate before every run. Over 3 hours: present the plan and a pre-run test with its results, and wait for Shinichi's approval. Never GitHub Actions for the campaign.

## Definition of done
A committed recovery table and verdict on this lane's branch, the simulation scripts and seeds that reproduce it, the pre-run test that sized it, and a handover. Any bug found has a minimal reproducer written up.

## Must stop for
Merges, pushes to shared branches, any edit to the release-owned files, public claims about recovery, runs over 3 hours, DRAC jobs.
