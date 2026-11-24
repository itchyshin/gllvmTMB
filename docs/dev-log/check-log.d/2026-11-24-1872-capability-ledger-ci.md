# Check-log: PR #1872 capability-ledger CI correction

## Goal

Fix the validation-ledger mapping regression reported by PR #1872's Ubuntu test shards.

## Commands

    Rscript --vanilla dev/gapclose/build-capability-status.R
    Rscript --vanilla dev/gapclose/build-capability-status.R --check
    Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-gapclose-parity-ledger.R")'
    OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "paired-exact-marginal-gaussian|gapclose-parity-ledger", reporter = "summary")'
    git diff --check

## Results

The generator wrote the 82-row summary (255 mapped rows, 38 intentionally unmapped, 0 unmapped); its `--check` exited 0 with 0 unmapped register rows. The focused ledger test exited 0 with 32 passes, 0 failures, 0 warnings, and 0 skips. The combined exact-zero plus ledger test command completed successfully with exit 0. `git diff --check` passed.

## Not run

Full GitHub Actions rerun, the three-OS manual matrix, and merge are pending this correction being pushed and the current-head checks settling. No simulation, recovery, interval, or fit campaign was run. Stale-wording scans were not run because this internal R-vs-Julia capability mapping correction adds no reader-facing prose.

## Claim boundary

These checks fix the register-to-ledger accounting and verify the focused exact-zero test file locally. They do not establish full package CI, three-OS support, scientific recovery, or interval calibration.

## Paper 2 n=200 exact-zero route preflight (2026-11-24)

On Totoro, the isolated PR-head build passed a no-fit feasibility check against the frozen Paper 2 n=200 tree/network design. The structural mask supplied 2,400 observed cells for 400 units and 12 traits. The compiled route reported `exact_use_woodbury=1`, `exact_sigma_eps=0`, and `exact_has_known_V=0`. The TMB objective and gradient were finite at the initial parameter vector; the maximum absolute gradient was 2429.786, so this is a starting-point check and not a stationarity or fit result. `MakeADFun` took 13.945 s, objective evaluation 0.245 s, gradient evaluation 0.458 s, and no optimizer call occurred. Total controller wall time was 17 s, exit code 0 under the 12-minute cap. Peak RSS was not measured; Totoro had 274 GB available before launch.

Identity: PR source commit `219ef187f094e43a31f20cf66a87129e82fedb5b`; `R/exact-marginal-gaussian.R` SHA-256 `a7192e22930a602e6e98991604858f14c9b9164ad9444696c330ee501496da16`; compiled Linux DLL SHA-256 `8606b17681891dd4d1bfd23d2c31690e1748df71cd295b1634b0db3e153f53e7`; frozen design SHA-256 `76b3c65ebd379badaf838efd2b29d15911e0045eb41d496c5c9521abba9f3fb8`; no-fit driver SHA-256 `f8beed5639803ea0f09a308e61f06a7dc159599be74ee8110abd08b3dd4030f6`. Remote receipt directory: `/home/snakagaw/hsq_work/gllvmTMB-p2-zero-preflight-20261124/n200-nofit-20261124`. Attempt, stdout log, and exit receipt SHA-256: `cb571da8872b0e4983567aeb92a5835a94185e225f214fdc3101023d3f9965af`, `c270e33b3fd455cb26997902ef172a4129fcd1677fee3e1eaa3d21dd668a4988`, and `9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa`.

Exact command: `/usr/bin/timeout -k 30s 12m nice -n 19 env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 R_LIBS_USER=/home/snakagaw/hsq_work/gllvmTMB-p2-zero-preflight-20261124/lib:/home/snakagaw/R/lib GLLVM_PREFLIGHT_LIB=/home/snakagaw/hsq_work/gllvmTMB-p2-zero-preflight-20261124/lib Rscript --vanilla /home/snakagaw/hsq_work/gllvmTMB-p2-zero-preflight-20261124/n200-nofit-preflight.R`. The script intercepted the package's optimizer-construction call before `MakeADFun`, then explicitly built the TMB objective and evaluated its initial objective and gradient. This validates only model-construction and route feasibility for this frozen design; it is not recovery or optimizer evidence.

After the local bare-abort wording correction, `Rscript --vanilla -e 'devtools::test(filter = "gapclose-next-steps", reporter = "summary")'` exited 0; both `gapclose-next-steps` and `gapclose-next-steps-batch1` passed. `Rscript --vanilla dev/gapclose/count-bare-aborts.R` reported 770, matching the ratchet ceiling. These are local working-tree checks; the corrected commit has not been pushed, and the currently listed GitHub checks are still on head `219ef187f094e43a31f20cf66a87129e82fedb5b`.

Latest read-only CI refresh: the separate three-OS run `45312067003` failed on macOS, Ubuntu, and Windows at the same 772-versus-770 ratchet. In coverage run `45311068312`, shard 1 failed at the same assertion and shards 2 through 4 passed. The narrow source and evidence changes are committed locally as `3ad86e61672cec7baeba03a9506e26979d02b96d`; corrected-head CI is pending push. The local focused test and count checks passed, but no full package check has yet run on the corrected head.
