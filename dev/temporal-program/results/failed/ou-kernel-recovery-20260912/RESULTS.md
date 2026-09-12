# Retained OU temporal--kernel recovery result

The frozen nine-cell direct-DGP campaign used
`run-ou-kernel-recovery.R` at commit `5af5fafcf`. Every fit had terminal
success, both optimizer passes accepted with code zero, and a maximum outer
gradient no larger than `6.157075e-04`.

The frozen gate fails at rate `.25`: its median relative error for the first
kernel variance is `.4711615`, above the prespecified `.35` limit. The other
two rate strata pass their frozen numerical thresholds. The full result and
summary CSVs retain all nine attempts and the original per-attempt plan files.

This is a failed named-fixture engineering gate. It does not establish OU
source-pair recovery, rate identification, interval coverage, or a broader
temporal-kernel claim. No seed, threshold, or fixture was changed after seeing
the result.
