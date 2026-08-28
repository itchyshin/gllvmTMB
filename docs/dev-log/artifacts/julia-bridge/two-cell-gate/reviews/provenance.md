# Independent provenance and reproducibility review

**Reviewer:** Grace (Codex; independent read-only re-review)
**Date:** 2026-08-28
**Overall verdict:** **PASS**

The load-bearing provenance defect from the first review is repaired. The
bundle now retains process receipts generated from observed shell exit values,
the exact runtime paths and environment, named stdout/stderr files, direct
GLLVM capability output, and separate generated Manifests for Julia 1.12.6 and
1.10.10. The source contract binds both receipt hashes and both runtime
Manifest hashes. The repaired evidence supports a terminal
`NO_RUN_SOURCE_CONTRACT` receipt: direct GLLVM loading succeeded, JuliaCall
qualification terminated with exit 139 under both runtimes, and no fit started.

This is a provenance verdict only. It earns no Gaussian/Poisson numerical
parity, recovery, performance, interval, structured-source, or public
promotion claim.

## Load-bearing checks

### PASS — process exits are captured rather than asserted

`capture-source-qualification.sh` runs each direct Julia qualification, stores
its observed `$?` in `direct_status`, runs the R/JuliaCall qualification, stores
its observed `$?` in `bridge_status`, and writes those values to a versioned
process receipt. It does not hard-code 139 into the capture path.

The two retained receipts report:

| Runtime | Direct GLLVM | JuliaCall qualification | Fit started |
| --- | ---: | ---: | --- |
| Julia 1.12.6 | 0 | 139 | false |
| Julia 1.10.10 | 0 | 139 | false |

The source contract binds the receipt files by SHA-256:

- Julia 1.12.6:
  `9e3b6dea458e7fcc3695e1065a7a7299c2ba6d3868007e5303e0573c38deb194`.
- Julia 1.10.10:
  `696cd060c66d1fb7ac0b00832186afd3b3d73ec34a75081e6ff24e7cf46bdaf7`.

Both hashes independently match the retained receipt files. The receipts name
the Julia executable, depot, GLLVM source directory, R library, thread
variables, qualifier script, UTC start/finish times, stdout/stderr paths, and
observed exits. Empty bridge stdout/stderr is consistent with an immediate
segmentation fault; the exit value is retained in the shell-generated receipt,
not inferred from the empty logs.

### PASS — direct GLLVM eligibility is retained

Both direct commands exited 0. Their retained stdout files identify the exact
Julia version and print `GLLVM.bridge_capabilities()`. Both outputs include
Gaussian and Poisson as admitted no-X families. Direct stderr is empty.

This separates GLLVM source/runtime admission from the JuliaCall embedding
failure and supports the terminal reason without treating direct loading as a
fit.

### PASS — no fit started

The qualification script calls `gllvm_julia_setup()` and then queries
`GLLVM.bridge_capabilities()`; it contains no model-fitting call. Both process
receipts state `fit_started=false`. `records.csv`, `verdict.rds`, and all four
attempt RDS files independently retain the same pre-fit terminal state.

The denominator is exactly 0 started / 4 planned, with the frozen IDs
`gaussian-tmb`, `gaussian-julia`, `poisson-tmb`, and `poisson-julia`. Every
planned row is retained as unavailable with `NO_RUN_SOURCE_CONTRACT`; there are
zero replacement attempts.

### PASS — both runtime dependency resolutions are retained

The exact GLLVM.jl source commit contains `Project.toml` but no source
`Manifest.toml`, so
`manifest_status = "absent_in_source_generated_at_runtime"` is accurate.
The bundle now retains two generated runtime locks:

- `GLLVM-Manifest-julia-1.12.6.toml` declares Julia 1.12.6 and hashes to
  `c019e07f5f83f6c85492b0da8760ef3870c68c3ddebef2984ac3041776d47bd9`.
- `GLLVM-Manifest-julia-1.10.10.toml` declares Julia 1.10.10 and hashes to
  `225213ebd8b329f1d39890c954a561f7350469d90fd86d6c3bbde44b948fd1fe`.

The source contract names and binds both files, and both local hashes match.

## Previously verified immutable identities

### PASS — exact source pins, trees, archives, and Project

- gllvmTMB commit
  `86e95fff170767b23980152b7d6fce9bb2207718` resolves to tree
  `4393be7730b306e310843c7621b4517cc3ad86fb`.
- Recreating `git archive --format=tar.gz --prefix=gllvmTMB/` yields
  `03053140ff39ef0945c51577acd74a1cfd87e5733cf697c7f231fb420a67d594`,
  matching the retained Totoro archive and source contract.
- GLLVM.jl commit
  `00a2d7b7024b21f55cb124bee2d2e4cf8a546b40` resolves to tree
  `8a243605516a0d660d703135acb0b1bd9a0e4f15`.
- Recreating `git archive --format=tar.gz --prefix=GLLVM.jl/` yields
  `515ae818a0c66b2dddda4306ade9643310e7531c504183e352ac598b8d1bd4b7`,
  matching the retained Totoro archive and source contract.
- The exact GLLVM.jl `Project.toml` hashes to
  `bd85aa8977102a28872fa34b019dce1ad96e50171ad52907f2f34f37d06f0128`.

### PASS — installed binary identity

The Totoro shared library at
`/home/snakagaw/gllvm_work/engine-julia-two-cell-gate-20260828/Rlib/gllvmTMB/libs/gllvmTMB.so`
hashes to
`e9a7763d0ef01cbf566829f9044a0709c7de5599d0662a3cb0ef6e15139724b4`,
matching the source contract. Installed metadata reports gllvmTMB 0.7.1,
R 4.5.3, x86_64 Linux, built at `2026-08-28 17:09:06 UTC`; the remote install
log ends with `* DONE (gllvmTMB)`.

### PASS — runtime identities

- Retained R record: R 4.5.3 on x86_64 Ubuntu 24.04.4.
- Retained JuliaCall version: 0.17.6.
- The named Totoro executables independently report Julia 1.12.6 and 1.10.10.
- Both generated Julia Manifests match their declared runtime versions and
  contract hashes.

## Verification results

The repaired focused harness passes all 75 expectations. The artifact verifier
returns:

- `G2_SOURCE_CONTRACT_OK`;
- `G3_DENOMINATOR_OK`;
- `G4_VERDICT_OK`.

The source check validates both process receipts, their receipt hashes, direct
version/family output, named runtime Manifests, and Manifest hashes.

## Remaining warnings and cleanup

### WARN — regenerate the final SHA manifest after reviews

The current `SHA256SUMS` predates the repaired process files, runtime
Manifests, updated source contract, and independent reviews. Its manifest check
therefore fails at this intermediate stage. This is expected sequencing because
this review itself must become a final member, but closeout must regenerate one
standard two-space `SHA256SUMS` over every retained artifact and then pass
`shasum -a 256 -c SHA256SUMS`. Landing before that final rehash would change
this review to FAIL.

### WARN — the direct-command receipt field abbreviates the Julia expression

Each receipt records the direct command's `-e` payload as
`using_GLLVM_bridge_capabilities`, whereas the retained capture script contains
the literal expression that was executed. The script and stdout make this
auditable in the final git commit, so this is not load-bearing. For a fully
standalone future receipt, record the literal quoted expression or bind a hash
of the capture script inside the source contract.

### WARN — compiled dependency/toolchain record is not fully in-bundle

The installed DLL hash is exact identity evidence. However,
`R-sessionInfo.txt` comes from a clean session and omits TMB, Matrix,
RcppEigen, their library paths, and compiler configuration. A read-only Totoro
audit found TMB 1.9.21, Matrix 1.7.5, and RcppEigen 0.3.4.0.2, while the full
install log remains only on Totoro. This does not weaken the observed pre-fit
JuliaCall failure, but retaining the install log and loaded dependency session
record would improve future binary reconstruction.

### WARN — repository bundle depends on the durable Totoro source archive

The two source archives remain under the Totoro run root rather than inside the
repository artifact directory. Their hashes are independently reconstructable
from the exact git objects and match the remote files. Closeout should retain
the exact Totoro run root and state its retention policy.

## Final adjudication

| Component | Verdict |
| --- | --- |
| Exact commits and trees | PASS |
| Source archive hashes | PASS |
| Project/source-Manifest treatment | PASS |
| Julia 1.12.6 runtime Manifest | PASS |
| Julia 1.10.10 runtime Manifest | PASS |
| Installed DLL identity | PASS |
| Direct GLLVM capability receipts | PASS |
| JuliaCall exit-139 receipts | PASS |
| No-fit-start evidence | PASS |
| Four-attempt denominator | PASS |
| Runtime/toolchain reconstruction detail | WARN |
| Final all-member SHA manifest | WARN pending final rehash |
| Terminal receipt proves why no fit started | **PASS** |

The earned closeout statement is: **source-qualified direct GLLVM loading, but
JuliaCall embedding unavailable with exit 139 under Julia 1.12.6 and 1.10.10;
zero of four planned fits started, so no engine-parity claim was evaluated.**
