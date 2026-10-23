# Integrated-JSDM point campaign terminal receipt

Date: 2026-08-29
Target: Totoro, 40 one-thread workers
Public route: `gllvmTMB(..., family = isdm_sources(...))` only

## Source qualification

The campaign used exact merged `origin/main` SHA
`c5bb0b80a0a733c6d7cb1bab826003bbaa589fe4`, tree
`655282a18631700e033319d299e686162b52be97`, package version `0.7.1`, and an
isolated Totoro install. GitHub Actions run
`https://github.com/itchyshin/gllvmTMB/actions/runs/33262647988` passed macOS
in 25m16s, Ubuntu in 34m20s, and Windows in 51m41s at that exact SHA. The
qualified source contract records the package, loaded DLL, source-file, and
installed-file hashes.

The first qualification command installed the package but then hid Totoro's
`jsonlite` dependency by setting the isolated library as the only R library.
That failure is retained in `qualification.log`. Qualification resumed without
reinstalling or overwriting a receipt, with the isolated `gllvmTMB` library
first and Totoro's dependency library second. A fresh process then returned
`ISDM_SOURCE_CONTRACT_VERIFIED`.

## Retained pre-run

The first pre-run launcher rejected the mixed-unit GNU `timeout` string before
starting a task. Its retained ledger is 14 planned, 0 started, 0 terminal, and
14 planned-not-started. The same registered task IDs 1--14 and seeds
202608001--202608014 then resumed in the same directory after confirming that
no started or terminal record existed. This was a resume of not-started work,
not a replacement attempt.

The resumed pre-run retained 14 planned, 14 started, 14 terminal, 14 returned
fits, and zero error, interruption, unavailable, or not-started records. Full
process times were 2.47--4.63 seconds. The frozen 40-worker projection was
223.2 seconds (3m43s), so Totoro production was eligible under the approved
30-minute rule.

## Production denominators

No attempt was replaced.

| Slice | Planned | Started | Terminal | Fit returned | Error | Interrupted | Unavailable | Eligible |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Ordinary nonspatial | 1,600 | 1,600 | 1,600 | 1,600 | 0 | 0 | 0 | 1,600 |
| Disconnected-support attack | 200 | 200 | 200 | 200 | 0 | 0 | 0 | 200 |
| Held-out spatial | 800 | 800 | 800 | 800 | 0 | 0 | 0 | 302 |
| **Total** | **2,600** | **2,600** | **2,600** | **2,600** | **0** | **0** | **0** | **2,102** |

The first adjudicator incorrectly marked the 200 attack terminal records as
invalid because its combined plan added ordinary-only `pair_id` and
`structure_seed` fields to the native attack specification. The raw manifest
was verified before a new adjudicator compared only immutable fields common to
the native ordinary and attack plans. The v1 receipt remains retained and is
hashed by the corrective v2 receipt. No fit, raw record, estimand, or threshold
changed.

Independent review then found two adjudication-only defects in v2: `diag()`
had dropped `Psi` dimnames, and the attack gate treated any warning as a
diagnostic. V3 reverified the 10,412-entry raw manifest, bound both prior
receipts, restored `Psi` names only through exact truth/`Sigma` order, and
excluded unrelated lifecycle warnings. Its exact source and pure helpers are
retained. V1 and v2 remain immutable negative provenance.

## Frozen verdicts

### Nonspatial recovery: FAIL

All 1,600 ordinary attempts converged, returned finite objectives, and had PD
Hessians. All ecological and source-observation coefficients passed their
bias/RMSE gates, and `Sigma` passed with median relative Frobenius error 0.139.
The programme nevertheless failed its frozen recovery gate:

- median centered-surface correlation 0.812, below 0.90;
- weak-overlap median correlation 0.757, below 0.80;
- median normalized surface RMSE 0.585, above 0.50;
- corrected `Psi` availability 1.00 for all traits, with median relative error
  0.390 for species 1 (above 0.35), 0.182 for species 2, and 0.210 for species
  3;
- two source-2 weak/full coefficient RMSE ratios were 2.025 and 2.375, above 2.

### Disconnected-support attack: COMPLETE / STRESS-ONLY

All 200 attacks returned fits. The machine v2 receipt labelled this slice
`PASS` because its operational gate accepted any warning. Independent review
found that every warning was the ordinary `latent()`/Psi lifecycle warning,
not a disconnected-support or non-identifiability diagnostic. The
diagnostic-qualified rate is therefore 0/200. Under the
approved method amendment this slice is retained as complete stress evidence,
not promotion evidence; its diagnostic gate is FAIL. The overbroad machine
label is retracted without changing a raw attempt.

### Held-out spatial point maps: FAIL

All 800 attempts returned fits, but only 302 (37.75%) met the eligible-fit
definition, below the frozen 85% availability gate. Among eligible fits, all
deterministic oracles passed: training identity and source-dispatch maximum
errors were 0, zero-offset semantics held, and every out-of-hull request emitted
the classed warning. Held-out accuracy was strong where available (median
centered-surface correlation 0.9956; median normalized RMSE 0.1144), but
available-only accuracy cannot override the all-attempt availability failure.

## Claim boundary

This campaign is retained negative evidence. It does not certify public-route
nonspatial recovery or spatial held-out point maps. The spatial FAIL blocks the
SPDE marginal-map uncertainty implementation and 4,800-attempt calibration
campaign in this programme. Thresholds were not retuned; no attempt was
replaced; no interval, structured-source, absolute-abundance, occupancy, or
detectability claim is made.

## Durable evidence

Raw attempts remain on Totoro under
`/home/snakagaw/gllvm_work/isdm-requalification/c5bb0b80/`.

| Retained artefact | SHA-256 |
|---|---|
| `receipts/source-contract.rds` | `68acbf7852b2a80b15f4c2e933809933073b8d7bd93f4785388e1bc97c9dc245` |
| `prerun-point/adjudication-resume.rds` | `8ec24b8b96b1f1148f30cedb93e7cd0ad4463d584a86ea0588385f06cf0173f1` |
| `prerun-point/manifest-resume-sha256.txt` | `071ee498f1aa9dc17383b2ba8ba2b0b19fe1491420fcc877674d617b6886c060` |
| `production-point/raw-manifest-sha256.txt` (10,412 entries) | `bfcc17994d2fc9a46c5d9f372be63ce2074629a2fe6dbd9a01df156d35e5e092` |
| `production-point/adjudication.rds` (superseded v1) | `f825495f62a215994898701e3d0038bf639053093dfa1fa5cb1db328a12b5216` |
| `production-point/adjudication-repair.rds` (v2) | `a0f45394f77dc9e26cefe15c5bad9e56b69375c5233c0a305fe033789afb4141` |
| `production-point/manifest-repair-sha256.txt` (10,421 entries) | `01a931cff918bc077724950b1d65296c34612b3d2dcc49288322eaff0013a619` |
| retained v2 adjudicator source | `641c217c3b97715b7a246bf4ed07e254c82ecfa342d4d824eaada4b6b1f2c855` |
| retained overbroad attack-gate source | `f91dc9510c18e8fe908bb1f05abcaad53a5fcbcc42adb9171a112860e2aa85d9` |
| `production-point/adjudication-v3.rds` | `32c7a9cb325d1e45f015b38b53a8722473e0a9ffc254d3f5e79fb2c6c22001ab` |
| retained v3 adjudicator source | `99d65fa98e27239460ab37ac7d5b1fc4945b291ab48baa8b83724b01a5fd18b9` |
| retained v3 pure helpers | `b1bd5be8b3e484690981e158f9055d534dece68bda7470d2bcd6b89b156eae65` |
| `production-point/v3-manifest-sha256.txt` | `b452c79c2328a88a1821bee3b1925ccd357c7af1b3dbb4ea7453509127bf9bfa` |

## Classification

- **DONE:** exact-main three-OS qualification; installed package/DLL binding;
  14-fit timing gate; 2,600 immutable point attempts; raw-manifest freeze;
  v3 native-plan and named-`Psi` adjudication; complete disconnected-support
  stress slice.
- **OWED:** a future, newly approved design that addresses nonspatial surface
  and species-1 `Psi` recovery plus strict spatial eligible-fit availability.
  This campaign cannot be reinterpreted as satisfying those gates.
- **RETRACTED:** the v1 combined-plan terminal classification for attack tasks
  and the v2 machine `PASS` label produced by accepting unrelated warnings.
  Both receipts and the exact adjudicator sources remain retained. No raw
  attempt is retracted or replaced.
- **PROTECTED:** all failed attempts and denominators; frozen thresholds;
  uncertainty and public promotion; raw evidence on Totoro; exact-source and
  lease-controlled closeout.
