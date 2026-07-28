# L-BFGS-B vs nlminb: binomial (jj + gh) and higher-q gaussian_anchor

Generated 2026-07-27 18:18:33. n_starts = 1L for every cell (multi-start gate bypassed
so this isolates the optimizer route, not the health gate). T = 8 throughout.

Timing note: the shared TMB DLL was compiled once by an untimed smoke fit
before any cell in the grid was timed, so no cell below carries the cold-
compile penalty. Absolute elapsed times below are a SINGLE nlminb-then-
lbfgsb pass per cell (not repeated/medianed) -- read them as order-of-
magnitude, not a controlled speed benchmark; SAME-OPTIMUM agreement is the
point of this shard, not speed.

**CPU contamination (MEASURED):** `uptime` at the start of this run showed
a 20-core box at load average ~33-38 -- another job is using the CPU. The
single-pass grid times above are therefore NOT a clean speed comparison;
see the interleaved warm-median robustness check below for the gh tier,
which is the more trustworthy timing evidence in this document.

| family | eval_method | q | N | nlminb obj | nlminb conv | lbfgsb obj | lbfgsb conv | obj_delta | max|dpar| | agree? |
|---|---|---|---|---|---|---|---|---|---|---|
| binomial | jj | 2 | 150 | 814.8863 | 0 | 814.8863 | 0 | 2.461e-08 | 0.0002916 | YES |
| gaussian_anchor | gh | 2 | 150 | 1792.3995 | 0 | 1792.3995 | 0 | -1.502e-08 | 0.0002274 | YES |
| binomial | gh | 2 | 150 | 798.1830 | 0 | 798.1830 | 0 | -3.973e-09 | 7.545e-05 | YES |
| binomial | jj | 3 | 150 | 801.8860 | 0 | 801.8860 | 0 | -2.271e-09 | 6.879e-05 | YES |
| gaussian_anchor | gh | 3 | 150 | 2049.0858 | 0 | 2049.0858 | 0 | 5.913e-08 | 0.0001484 | YES |
| binomial | gh | 3 | 150 | 808.2958 | 0 | 808.2958 | 0 | 5.805e-08 | 0.0006149 | YES |
| binomial | jj | 2 | 400 | 2157.1089 | 0 | 2157.1089 | 0 | -2.786e-08 | 7.033e-05 | YES |
| gaussian_anchor | gh | 2 | 400 | 4869.6395 | 0 | 4869.6395 | 0 | 1.611e-07 | 0.0002451 | YES |
| binomial | gh | 2 | 400 | 2140.5327 | 0 | 2140.5327 | 0 | 4.168e-08 | 0.0001252 | YES |
| binomial | jj | 3 | 400 | 2144.9446 | 0 | 2144.9446 | 0 | 2.899e-07 | 0.0004466 | YES |
| gaussian_anchor | gh | 3 | 400 | 5221.5957 | 0 | 5221.5957 | 0 | 1.629e-07 | 0.0001606 | YES |
| binomial | gh | 3 | 400 | 2135.5719 | 0 | 2135.5719 | 0 | 1.246e-07 | 0.0002202 | YES |

Agreement thresholds (not registry-official, chosen for this shard): |obj_delta| < 0.001, max|dpar| < 0.01.

Any cell marked NO, or with a non-zero convergence code on either side, is
the important result -- read the CSV row directly rather than trusting this
summary's threshold call.

## Timing robustness check -- binomial gh tier, 3 interleaved warm reps

The gh tier is the arm we most want to speed up, so its timing gets a
second, more careful pass: 3 reps per optimizer, interleaved
(nlminb-lbfgsb-nlminb-lbfgsb-nlminb-lbfgsb) per cell, DLL already warm.
Raw per-rep numbers are in `dev/lbfgsb-default-binomial-and-q-gh-timing.csv`.
Still measured under the same CPU contention noted above -- ratios, not
absolute seconds, are the trustworthy quantity, and even the ratios can
move if load fluctuates between adjacent nlminb/lbfgsb calls.

| q | N | nlminb warm median (s) | lbfgsb warm median (s) | ratio nlminb/lbfgsb |
|---|---|---|---|---|
| 2 | 150 | 5.00 | 7.82 | 0.64x |
| 3 | 150 | 6.41 | 8.02 | 0.80x |
| 2 | 400 | 18.28 | 20.88 | 0.88x |
| 3 | 400 | 37.27 | 92.54 | 0.40x |
