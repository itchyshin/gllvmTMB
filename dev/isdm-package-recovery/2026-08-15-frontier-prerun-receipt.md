# Frontier campaign pre-run receipt -- PASS (awaiting launch approval)

Host Totoro, 2026-08-15, via existing ControlMaster socket (D-64). Compile of
the sealed-lineage template (cpp MD5 ca8d2104b38631164e6000e7a075aa22, matching
the bundle provenance): 64 s. Bundle gates G1-G3 all exact (0.00e+00) -- the
redraw machinery reproduces the sealed fields bitwise before any fresh draw.

Pre-run: E = 2 x 3 seeds, fields/residuals/responses redrawn per replicate.

| rep | counts | conv | fit s | ||lam_hat|| (truth 16.15) | cos | pdHess |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 904 | 0 | 5.8 | 0.154 | 0.259 | FALSE |
| 2 | 1009 | 0 | 5.7 | 0.331 | 0.063 | FALSE |
| 3 | 925 | 0 | 8.5 | 11.658 | 0.972 | TRUE |

PASS against the design gate: three non-empty rows with finite theta and
recorded SEs; ~10.2 s total per fit, 2.5x UNDER the 25 s budget; one row
inspected past the guards (full str, sign_flip and session recorded); and the
E=2 behaviour is a genuine mixture -- exactly between the pilot's E=1
(all-collapse) and E=4 (recovery), i.e. the level sits ON the frontier, which
is itself corroborating evidence for the frontier bracket. The two sqrt-NaN
warnings are the expected negative-variance diagonal on non-PD reps; SEs are
recorded NaN there and coverage is computed on the pdHess subset by design.

Revised whole-campaign estimate from measured timings: 1,600 x ~10.2 s ~ 4.5
core-h; at 100 workers ~5-8 min wall, inside the declared 45-min budget with
5x headroom. THE 1,600-FIT CAMPAIGN DOES NOT START UNTIL THE MAINTAINER
APPROVES THIS RECEIPT AGAINST THE DESIGN.
