# After-task: arcG Totoro coverage grid

**Scope:** Full 9×500 ordination_uncertainty() marginal-coverage grid on Totoro.

**Outcome:** DONE — 4500/4500 RDS; pooled cov@90%=0.634, cov@95%=0.695; 1.60 core-h (under 5.0 ceiling).

**Checks:** Object counts on `per_seed_summary.csv` (4500 rows) and `results/raw/` (4500 RDS); `campaign_meta.csv` core_hours=1.598.

**Paths:** `dev/gapclose/arcG/results/`, `coverage-results.md`, `run_grid.R`, `aggregate.R`, `run-grid-totoro.sh`.

**Follow-up:** Fisher review on d=2 pdHess fraction; optional Williams §10 binned diagnostic from pooled CSV.
