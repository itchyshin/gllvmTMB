# Handover: auto-d-recovery (2026-09-30)

## Done
The rank-recovery simulation for `latent(d = "auto")` is finished. Branch `claude/lane-auto-d-recovery`, in `~/local-scratch/lanes/gllvmTMB-auto-d-recovery`, holds the design, scripts, pre-run test, ridge diagnostic, recovery table and verdict. It is committed locally only: not pushed, no PR. Verdict in short: Gaussian and Poisson recommended; NB2 recommended with a floor of 16 traits; binomial (Bernoulli) not recommended. No bug found. The verdict is lane-internal and makes no public claim.

## Where truth lives
All under `docs/dev-log/lanes/auto-d-recovery/` on the branch:
- `verdict.md`: per-family verdict and findings.
- `results/recovery-table.md` and `.csv`: full table (13,789 datasets).
- `design.md`: ADEMP design and verdict rule. `prerun.md`, `ridgeoff.md`: sizing test and ridge diagnostic.
- `sim/`: scripts; seeds are in `results/grid.rds`.
- `after-task.md`: the after-task report.
- Raw per-dataset RDS files are not committed. They are on Totoro at `~/autod-recovery/` (`out/res`: 13,789 files; `ridgeoff/out/res`: 756) and in `/private/tmp/claude-503/autod-pull` on the Mac (scratch, will be purged).

## Fences kept
No edits to `R/`, `man/`, `NAMESPACE`, `NEWS.md`, `inst/`, `tests/` or `check-log.md`. The true-parity lane asked (2026-09-30) that `tests/testthat` stay untouched because the 0.7.1 CRAN release lane owns it.

## Carried over
- 11 NB n = 400 datasets, stopped at the overrun line (10:14). Their ids are in `~/autod-recovery/phaseB_missing_ids.txt` on Totoro. Resume: `cd ~/autod-recovery && R_LIBS=~/autod-recovery/lib OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 nohup Rscript 1_run.R --ids-file phaseB_missing_ids.txt --cores 11 --out out > phaseB_resume.log 2>&1 &`. The runner skips finished tasks. Expect 10 to 60 minutes per dataset. Then pull `out/res` and rerun `sim/2_summarise.R`.
- 144 ridge-off binomial datasets, all n = 400, p = 16. Ids in `~/autod-recovery/ridgeoff/missing_ids.txt`. Resume from that folder, which holds its own copy of the scripts: `cd ~/autod-recovery/ridgeoff && R_LIBS=~/autod-recovery/lib OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 nohup Rscript 1_run.R --ids-file missing_ids.txt --cores 8 --out out --binary-ridge Inf > resume.log 2>&1 &`. Ridge-off fits average about 21 s, longer in this cell.
- Lane lease: released at the end of this session. If it shows as held: `LANE_ID='claude:gllvmTMB-auto-d-recovery:71860' /Users/z3437171/shinichi-brain/tools/lane_lease.sh --release gllvmTMB-auto-d-recovery`
- Totoro: 0 lane processes running.

## Open decisions for Shinichi
(a) Should `d = "auto"` choose the criterion by family? AIC beats `bic_sites` on binomial in 8 of 18 cells; on NB, AIC is far worse (n 400, p 8, d 1: 0.52 against 0.99). One default cannot be best for both.
(b) Push the branch and open a PR, or keep it local? Any public statement about recovery waits on this.
(c) Resume the 11 NB and 144 ridge-off datasets? Neither changes the current findings; they only fill two cells of the tables.
(d) Delete Totoro `~/autod-recovery/` or keep it? It holds the raw RDS files and a private R library built because `~/R/lib` fails under R 4.6.1 (`SETLENGTH`). Deleting it loses the raw data unless the Mac copy is kept elsewhere first.

## Resume
Read `LOOP/GOAL.md`, `LOOP/checkpoint.md`, `verdict.md`, then act on the decision you choose above.
