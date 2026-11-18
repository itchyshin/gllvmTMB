# VA(GH) H = 7 Arc 2 Totoro adjudication

The frozen confirmation completed at `2026-08-07T05:15:58Z` with an exit
receipt of `COMPLETE`, exit code 0, and exactly 36,000 verified immutable
bundles for 36,000 planned rows. The unchanged 5,520-row H ladder and the
confirmation were exported independently with the role-neutral driver at
`022b4eab`; the clean adjudicator used 5,000 paired-bootstrap replicates and
issued 36 family-by-rank verdicts.

The overall point-route result is 1 PASS (`poisson_log`, q = 5), 24 FAIL, and
11 INCONCLUSIVE. Completeness passed in every cell. Reliability was 20 PASS,
15 FAIL, and 1 INCONCLUSIVE. H = 7 stability was 16 PASS, 12 INCONCLUSIVE, and
8 `NOT_APPLICABLE` exact cells. Fixed-effect VA-Wald calibration was 20
CALIBRATED / 16 UNCALIBRATED; latent posterior-SD calibration was 15
CALIBRATED / 20 UNCALIBRATED / 1 INCONCLUSIVE.

Both stages ran on Totoro. The receipt therefore records
`h_ladder_platform=Totoro`, `confirmation_platform=Totoro`, and
`cross_platform=FALSE`. The failed Fir and Narval execution lanes contributed
no row to this denominator. The result does not change any threshold, pool any
family or rank, promote uncertainty interfaces, or alter public VA fences.

The adjacent CSV is the durable 36-row verdict and calibration table. The DCF
records the checksum chain back to both plans, Gate-E reports, native runtimes,
preflights, three-file exports, the 41,520-row input manifest, the full 74-column
verdict, and the committed adjudicator. The complete host-local evidence copy
is retained at `/private/tmp/va-gh-h7-final-evidence/totoro/`.
