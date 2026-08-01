# Tau cap selection verdict

- Input: `/home/snakagaw/gllvmtmb_tau847_54d6f366/selection/29-tau-cap-selection.csv`
- Bootstrap replicates: 5000
- Operational failure/runaway comparator: `fixed2_shipped`
- Tau-only accuracy comparator: `fixed2_pilot` (same pilot and warm start)
- Decision: **NO_CAP_PASSED_SELECTION**

Failed/nonconverged fits count as adverse in both failure and runaway rates.
Correlation MAE and loading error use successful pairs, with the retained
pair count reported beside the separate all-fit failure gate. `auto_uncapped`
is a safety control and is never selectable.
