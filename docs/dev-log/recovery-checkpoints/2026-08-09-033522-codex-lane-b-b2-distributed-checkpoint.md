# Lane B B2 distributed-compute checkpoint

## Branch and working tree

- Branch: `codex/lane-b-mspl-20260808` in
  `/private/tmp/gllvmtmb-lane-b-mspl`.
- Upstream comparison: `origin/main`.
- The intended Lane B implementation remains uncommitted: 44 tracked files
  changed (`1,628` insertions, `139` deletions) plus the new B0/B1/B2 source,
  tests, design note, article, recovery notes, and Jeffreys header shown by
  `git status --short`.
- `git diff --check` passed immediately before this checkpoint.
- `gh pr list --state open` returned no open pull requests. Recent unrelated
  `origin/claude/experiment-integrated-sdm` commits do not own Lane B.

## Immutable campaign identity

- Totoro source HEAD: `b1341c29d174b744e45e1082379d72555b683a45`.
- Source archive SHA-256:
  `20e57093edf155a9ec14cee9c9efd7b07fe954b4937a1a524e5b98d4a7813d2d`.
- Base bundle SHA-256:
  `012bce920c64d8658bca7a9dd4b50346f10b4a67bc0380f87fae764aa4c37b42`.
- Authoritative Totoro frozen-state SHA-256:
  `1147ea898b37720e393b9acaf524675d4ca805bf497d1038291027705869db98`.
- The Nibi-generated frozen RDS decoded to an object exactly `identical()` to
  Totoro's object but had different serialization bytes. Its array was held,
  Totoro's authoritative RDS was copied into place after the exact identity
  assertion, and only then was the array released.
- Collision-free untouched-shard partition: 7,664 shards, comprising 2,072
  ordinary, 192 permutation, and 5,400 spatial shards. Four 1,916-shard lists
  were frozen and checksummed before submission. Totoro's verified xargs PID
  `3384266` is `SIGSTOP`-paused, while its already-started children continue.

## Active compute

- Totoro: root
  `/home/snakagaw/gllvmtmb_lane_b_b2_20260808_v1`; last observation was 695
  complete, 114 active, zero failed. No new shards launch while xargs remains
  stopped.
- Nibi: setup `19391101` completed; first-wave array `19391149` covers list
  indices 1--950 with `%150`. It runs from Totoro's authoritative frozen RDS.
- Rorqual: recovery setup `18702101` completed after an expected fail-closed
  bootstrap filename repair; first-wave array `18702102` covers indices
  1--950 with `%150`. At checkpoint it had 150 running, zero complete, and zero
  failed.
- Trillium: debug-partition verification setup `2075244` completed in 29
  seconds; dependent compute run `2075245` is queued. The run uses one
  192-core node and `xargs -P150`. Its project library was extracted on the
  login-side filesystem because compute nodes cannot write to that project
  mount. The prepared frozen-state hash is the authoritative Totoro hash.
- Narval: excluded. Setup `523447` trapped on an illegal instruction while
  loading a dependency built for a newer CPU target; dependent array `523448`
  was cancelled and no fit shard started. Its untouched 1,916 shards were
  redistributed without overlap: 639 each to the staged Nibi and Rorqual
  second waves and 638 to Trillium's combined list.
- Fir quasi supplement: array `53828776`, aggregate `53828777`, and keeper
  `53828788`; last observation was 390/600 complete, 30 running, zero failed.
- Fir main work-stealing partition: 600 untouched shards were removed from the
  not-yet-submitted Nibi/Rorqual second-wave lists, giving a reverified global
  union of exactly 7,664 unique IDs. Setup `53853635` completed and replaced
  its generated RDS with Totoro's authoritative bytes. The first array
  `53853636` failed closed in capability preflight because the generic array
  script overwrote the submitted `R_LIBS_USER`; it created no shard locks or
  failure receipts and was cancelled. One-core preflight `53853999` then
  verified both `public_mspl` and `harness_private_mspl_ridge`. Corrected array
  `53854008` entered the runner. A further 200 untouched shards (100 from each
  still-unsubmitted Nibi/Rorqual second wave) were moved to Fir after another
  exact 7,664-ID union check; array `53854241` was submitted. The latest
  observation was 26 complete, 199 real running locks across the two arrays,
  and zero failure receipts. A final 80 untouched shards (40 from each future
  wave) were moved after one last exact union check and submitted as array
  `53854421`. The terminal partition is now fixed: Nibi first 950 plus future
  1,165; Rorqual first 950 plus future 1,165; Fir arrays of 600, 200, and 80;
  and Trillium 2,554. These sum to exactly 7,664 unique IDs. No further
  repartitioning is planned.
- Validated Fir R-library archive SHA-256:
  `e3d579f5787bbd17529cb3d6a7567604c0173a5edd5cce72ee1cc1d526e71e0f`.
- Final queue ownership was rechecked against live Totoro state after the
  Totoro launcher was stopped. The frozen distributed list contains 7,664
  unique shard IDs (SHA-256
  `2e6868251670b28484fdeba9c1b4fb6e1548f19889149d8d93403213806cc510`),
  while Totoro owns 808 complete-or-running IDs (state-list SHA-256
  `1d65f492e8c15f8804d842dede092a94dcb18a904c4f0a732a2ddeadf602ec81`).
  Their intersection is empty and their union is exactly the full 8,472-ID
  manifest. This is the terminal ownership partition; no shard reassignment is
  permitted without regenerating and rechecking both sets.
- Trillium compute job `2075245` subsequently entered `RUNNING` on node
  `tri0113`. Its first live audit found 150 running shard locks, 64 completed
  shards, and zero failures, confirming the approved worker cap and one-thread
  runner contract.
- Fir keeper job `53855115` is dependency-held on all three main arrays. The
  keeper itself is fail-closed: it requires exactly 880 completion receipts
  and zero failure receipts before creating the archive, so scheduler
  termination alone cannot authorize collection.
- Scheduler-capacity slices from the unchanged future-list files were started
  without repartitioning ownership: Nibi job `19392658` covers v4 indices
  1--50, and Rorqual job `18703849` covers v4 indices 1--100. Each submission
  first verified the corresponding frozen list SHA-256 recorded above. Later
  submissions then used only newly available scheduler headroom: Nibi job
  `19392695` covers indices 51--100 and Rorqual job `18703998` covers indices
  101--150. Later submissions must start at index 101 on Nibi and index 151 on
  Rorqual.
- A later scheduler audit showed 91 Nibi and 241 Rorqual completions with zero
  failures. Newly freed capacity was filled from the same hash-verified lists:
  Nibi job `19392886` covers indices 101--130 and Rorqual job `18704318`
  covers indices 151--250. The next unscheduled indices are therefore 131 on
  Nibi and 251 on Rorqual.
- Exact `squeue -r` expansion later showed Nibi at 984 submitted elements and
  Rorqual at 947. Nibi was left unchanged; Rorqual job `18704493` used the
  remaining safe headroom for hash-verified indices 251--300. The next
  unscheduled Rorqual index is 301.
- A proposed Rorqual 301--400 slice was rejected pre-submission by
  `AssocMaxSubmitJobLimit`; it created no job, lock, or shard output. Exact
  expanded user state then showed 964 submitted elements and 36 available
  slots. Job `18704639` safely used 30 of those slots for indices 301--330.
  The next unscheduled Rorqual index is 331.
- With live submitted counts of 980 on Nibi and 918 on Rorqual, jobs
  `19393227` and `18704760` used measured safe headroom for Nibi indices
  131--145 and Rorqual indices 331--410. The next unscheduled indices are 146
  and 411 respectively.
- At 995 submitted elements Nibi remained unchanged. Rorqual had 38 slots
  available; job `18704950` used 30 for indices 411--440. Its next unscheduled
  index is 441.
- After an uninterrupted fitting interval, Fir reached 795/880 main and
  509/600 quasi shards; Rorqual reached 457 completions and 933 submitted
  elements. Job `18705085` used 60 of 67 available slots for future-list
  indices 441--500. The next unscheduled Rorqual index is 501.
- A local pre-merge verifier now lives at
  `/private/tmp/lane-b-verify-cluster-archive-v1.R` and parses cleanly. For
  each collected main archive it requires the authoritative frozen-RDS hash,
  the exact assigned shard cardinality and ID set, zero failure receipts, and
  successful SHA-256 verification of every raw shard against its completion
  receipt. It is an additional collection gate; the complete Totoro aggregate
  will independently reverify the merged queue.
- Collection ownership was tightened before any keeper ran. The keeper now
  builds one exact duplicate-free manifest from Fir's three assigned list
  files, or from each Nibi/Rorqual first-plus-future pair, and requires its
  count to equal `LANE_B_EXPECTED_SHARDS`. The dependency-held Fir copy was
  updated before execution. Local keeper SHA-256 is
  `25e0409a1f1d88e121234694826c0b077bc04ecff7f678c23833380169de1686`;
  pre-merge verifier SHA-256 is
  `b4a328776400ef56842467c1a4dc13ed3a9a9fbb2ffaf2cd8ee15ca375c7597a`.
- The keeper was then finalized with a Trillium scratch destination; its final
  SHA-256 is
  `63fa66505899a18f0351105fd4096da4cc62aee0616cf125f739f556e468939b`
  (superseding the earlier local hash). Trillium rejected the generic Slurm
  header before submission because it forbids per-job memory and requires the
  `def-snakagaw` allocation. A cluster-specific wrapper (SHA-256
  `8b6d2bdc18fc07b814d496cf809e9142d4f2bdb2c100c7afc011e128f8260874`)
  was therefore submitted successfully as job `2075452`, dependency-held on
  main job `2075245`; it executes the same fail-closed keeper and writes the
  verified archive to Trillium scratch.
- The same final keeper bytes were staged on Nibi and Rorqual in advance;
  neither keeper is submitted until all 2,115 assigned shards on its cluster
  have been scheduled and terminated.
- Totoro process-tree inspection separated stopped-launcher bookkeeping from
  live fits: the paused `xargs` has unreaped zombie shells, but 48 live R
  grandchildren were present and together used about 4,795 percent CPU
  (approximately one core each). They are active computations, not dead
  shells. The launcher must remain stopped and must never be resumed; terminate
  it only after those 48 owned shards finish or are explicitly reassigned.
- Fir element `53854008_562` (`spatial-S067-0044`) remained `RUNNING` about 23
  minutes after writing both its raw RDS and completion receipt. Before any
  scheduler action, the raw SHA-256
  `9c767521723d17941f3ce50d258686703ca37919f352f56fab780d9b4a80760d`
  was matched exactly to the receipt, the raw RDS was read successfully as a
  data frame, and its 80 rows matched the receipt. Only that post-save hung
  array element was then cancelled. Its authenticated evidence is unchanged;
  the fail-closed keeper still requires all 880 receipts and zero failure
  receipts.
- Fir reached all 880/880 assigned completion receipts with zero failures.
  Keeper `53855115` then failed safely in two seconds before archiving because
  the shared project destination reported `Disk quota exceeded`; no evidence
  was changed. The keeper destination was moved uniformly to each cluster's
  campaign scratch tree, producing final keeper SHA-256
  `5f16c8839bb68b5be6e5c68bd3dba96cb9947ecff2c19907eeda9ca70396aefe`.
  Those bytes were restaged on Fir, Nibi, Rorqual, and Trillium. Fir replacement
  keeper `53857686` was submitted without a dependency because the exact
  880-receipt/zero-failure gate was already satisfied.
- Fir replacement keeper `53857686` completed in 52 seconds and wrote a
  28,126,905-byte archive with SHA-256
  `4c8d910b006818b2fc25a31ce61ee1485629b4bc0d572febab5326f2fa937fc4`.
  The archive was downloaded, checksum-matched, path-safety checked, extracted
  in isolation, and passed `/private/tmp/lane-b-verify-cluster-archive-v1.R`
  for all 880 assigned shards against authoritative frozen SHA-256
  `1147ea898b37720e393b9acaf524675d4ca805bf497d1038291027705869db98`.
  A second Totoro-side check found 880 raw files, 880 completion receipts, and
  zero filename collisions. Only those raw and completion files were merged;
  the authoritative Totoro counts moved from 760 to 1,640 for both, with zero
  failure receipts. Frozen, queue, session, and summary files were not merged.
- After that merge, live capacity was 906 submitted elements on Nibi and 682
  on Rorqual. Hash-verified jobs `19394088` and `18706194` scheduled Nibi
  future-list indices 146--235 (`%90`) and Rorqual indices 501--800 (`%150`).
  The next unscheduled indices are 236 and 801 respectively.
- At live submitted counts of 982 on Nibi and 970 on Rorqual, jobs `19394178`
  and `18706496` used small safe margins for Nibi indices 236--250 and Rorqual
  indices 801--825. The next unscheduled indices are 251 and 826.
- Fir quasi completed 600/600 shards with zero failures. Aggregate `53828777`
  and keeper `53828788` both completed successfully; the strict aggregate
  returned `QUASI-PROMOTION-WITHHELD` for all six link-by-rank families. The
  49,248,349-byte archive SHA-256 is
  `6b0bd395445542cff9c14b5a1aa547415ae61de37920be7ae76d70d0158bfcda`.
  Local checksum/path checks and `lane_b_validate_quasi_summary()` passed.
  Every cell failed the frozen multistart-agreement gate; several
  probit/cloglog cells additionally had low usable rates or unhealthy
  alternate starts. The result is substantive evidence, not a pipeline
  failure, and thresholds were not changed.
- Totoro already had a one-shard partial `quasi-v1` tree. Six paths overlapped
  the completed Fir tree and four were byte-different, including the frozen
  object plus Q001 raw/receipt, so the campaigns were not mixed. With no quasi
  process active, the partial tree was moved recoverably to
  `imports/quasi-20260809/preexisting-quasi-v1-backup`; the validated Fir tree
  was installed as `quasi-v1`. Post-install counts are 600 raw, 600 complete,
  zero failed, with the strict summary present.
- Subsequent live counts were 253/2,115 complete and 947 submitted on Nibi,
  versus 1,114/2,115 complete and 661 submitted on Rorqual. Hash-verified jobs
  `19394716` and `18707706` scheduled Nibi indices 251--300 and Rorqual indices
  826--1125. The next unscheduled indices are 301 on Nibi and 1126 on Rorqual;
  only 40 Rorqual future-list IDs remain unscheduled.
- With live counts of 267 complete/983 submitted on Nibi and 1,123
  complete/952 submitted on Rorqual, jobs `19394728` and `18707928` scheduled
  Nibi indices 301--315 and the final Rorqual indices 1126--1165. Every one of
  Rorqual's 2,115 assigned shards is now scheduled. Keeper `18707978` is
  dependency-held on all 13 Rorqual array jobs and independently requires the
  exact 2,115-ID ownership manifest, 2,115 completion receipts, and zero
  failures. Nibi's next unscheduled index is 316.
- A fresh live audit found Nibi at 277/2,115 complete with 988 submitted user
  elements, Rorqual at 1,154/2,115 complete, Trillium at 326/2,554 complete,
  and zero Lane B failure receipts on all three clusters. The Nibi v4 list
  still matched SHA-256
  `d194ab585979ec06f0f08175fd66e011e47a8f6ac94d5f6f609be7b4dd3b088d`.
  Job `19394870` then used ten safe scheduler slots for the exact next indices
  316--325 (`%10`). Nibi's next unscheduled index is 326; Rorqual remains fully
  scheduled. Totoro remained at 1,640 merged raw/completion receipts, zero
  failures, and 48 running-state files; stopped launcher PID `3384266` was not
  resumed or terminated.
- After two submitted elements cleared, Nibi had 996 live submitted elements.
  The same future-list SHA was reverified and job `19394880` used only three of
  the four available slots for exact indices 326--328 (`%3`), preserving the
  strict below-1,000 account limit. Nibi's next unscheduled index is 329.
- The next live audit found Nibi at 280/2,115 complete, zero failed, and 998
  submitted elements. Job `19394926` was submitted only after re-verifying the
  same frozen future-list SHA and covers the single exact index 329 (`%1`),
  leaving 999 submitted elements at submission time. Nibi's next unscheduled
  index is 330. Rorqual was 1,163/2,115 and Trillium 329/2,554, both with zero
  failure receipts; Totoro still had 48 original running-state files.
- One more submitted element cleared at Nibi. With 281/2,115 complete, zero
  failed, and 998 submitted elements, the list hash and headroom assertions
  passed again; job `19394940` covers only exact future-list index 330 (`%1`).
  Nibi's next unscheduled index is 331.
- Nibi then reached 283/2,115 complete with zero failed and 997 submitted
  elements. The same pre-submit hash/headroom assertions passed; job
  `19394990` covers exact indices 331--332 (`%2`). Nibi's next unscheduled
  index is 333.
- At 284/2,115 complete, zero failed, and 998 submitted elements, Nibi again
  had one safe account slot. Job `19394998` passed the frozen-list and
  headroom assertions and covers only exact index 333 (`%1`). Nibi's next
  unscheduled index is 334. Concurrent counts were Rorqual 1,198/2,115 and
  Trillium 343/2,554, both zero failed; Totoro's 48 running files persisted.
- Totoro process inspection confirmed that the persistent locks are active
  computation, not idle shells: the shard R children are in `Rl` state and
  each sampled process used 99.9% CPU (for example `ordinary-O027-0001`
  through `ordinary-O027-0012`, elapsed about 4.1--4.5 hours). The paused
  xargs and wrapper shells themselves use zero CPU. No process was killed or
  reassigned.
- Nibi subsequently reached 285/2,115 complete, zero failed, and 998 submitted
  elements. The frozen-list/hash and account-headroom assertions passed; job
  `19395041` covers only exact index 334 (`%1`). Nibi's next unscheduled index
  is 335.
- At 286/2,115 complete and zero failed, Nibi again had 998 submitted user
  elements. Job `19395086` passed the same hash/headroom assertions and covers
  only exact index 335 (`%1`). Nibi's next unscheduled index is 336.
- The next audit found Nibi 288/2,115 complete, zero failed, and 997 submitted
  elements. Job `19395155` passed the same frozen-list and headroom assertions
  and covers exact indices 336--337 (`%2`). Nibi's next unscheduled index is
  338. Rorqual had reached 1,250/2,115 and Trillium 347/2,554, both zero failed.
- A narrow local Nibi feeder was then validated at
  `/private/tmp/lane-b-nibi-feeder-v1.sh`. It uses an atomic lock and next-index
  state, checks zero failure receipts and the frozen v4 list SHA on every poll
  and again immediately before submission, waits for at least ten safe slots,
  caps each batch at 50, and keeps total user elements at or below 999. Its
  first validated action found 982 submitted elements and scheduled exact
  indices 338--354 as job `19395175`; the atomic next-index state is now 355.
  The quiet managed feeder is active as exec session `84579`; do not make
  manual Nibi submissions while that session/lock is alive. Feeder evidence is
  recorded in `/private/tmp/lane-b-nibi-feeder-v1.log` and `.jobs`. The earlier
  failed background-launch attempt made no submission and changed no state.
- The feeder correctly waited at nine available slots, then at 316/2,115
  complete and 988 submitted elements reverified the frozen list and submitted
  job `19395240` for exact indices 355--365 (`%11`). Its atomic next-index state
  is now 366; managed session `84579` remains active.
- The feeder next waited at four and six slots, then at 326/2,115 complete and
  989 submitted elements reverified the same list and submitted job `19395301`
  for exact indices 366--375 (`%10`). The atomic next-index state is now 376;
  managed session `84579` remains active and zero failure receipts were seen.
- The feeder then waited through two, six, eight, and nine safe slots. At
  336/2,115 complete and 989 submitted elements it reverified the frozen list
  and submitted job `19395411` for exact indices 376--385 (`%10`). Its atomic
  next-index state is now 386; the next poll saw 337 complete, zero failed, and
  one safe slot, so it correctly waited.
- The Codex environment transition invalidated managed exec-session handle
  `84579`, but did not stop the feeder. Direct process inspection found
  `bash /private/tmp/lane-b-nibi-feeder-v1.sh` alive as PID `83639`, reparented
  to PID 1, with its lock present. The atomic state remained 386 and the log
  continued through 340 complete/995 submitted/zero failed. From here use PID
  `83639`, the lock, `.next`, `.log`, and `.jobs` as the authoritative feeder
  handles; do not restart or submit manually while that PID/lock is live.
- Feeder PID `83639` then waited through seven safe slots and, at 348/2,115
  complete and 987 submitted elements, reverified the frozen list and submitted
  job `19395646` for exact indices 386--397 (`%12`). Its atomic next-index state
  is now 398 and zero failure receipts have been observed.
- At 359/2,115 complete and 988 submitted elements, feeder PID `83639`
  reverified the frozen list and submitted job `19395836` for exact indices
  398--408 (`%11`). Its atomic next-index state is now 409; zero failure
  receipts have been observed.
- The feeder then waited through nine safe slots and, at 373/2,115 complete
  with 985 submitted elements, reverified the frozen list and submitted job
  `19396352` for exact indices 409--422 (`%14`). Its atomic next-index state is
  now 423; zero failure receipts have been observed.
- A continuation audit at 2026-08-09 12:43 UTC found feeder PID `83639` alive
  with its lock intact, next index 423, 380/2,115 Nibi completion receipts, 190
  running locks, 992 submitted user elements, and zero failure receipts. The
  feeder therefore remained the sole Nibi submission owner. Rorqual had
  1,438/2,115 complete with 251 running locks and zero failures; all shards
  remained scheduled and keeper `18707978` was dependency-held. Trillium had
  384/2,554 complete with 150 running locks and zero failures; main job
  `2075245` and dependency-held keeper `2075452` were healthy. Totoro remained
  at 1,640 merged completion receipts with zero failures. Its 48 original
  shard processes were rechecked directly: the R children were still in `Rl`
  state at 99.9% CPU, so paused launcher `3384266` remained untouched.
- At 384/2,115 Nibi completion receipts and 988 submitted user elements, feeder
  PID `83639` reverified the authoritative future-list SHA and submitted job
  `19396670` for exact indices 423--433 (`%11`). Its atomic next-index state is
  now 434. The immediately following audit found 389 complete, 181 running
  locks, 994 submitted user elements, and zero failure receipts. Concurrent
  completion counts were Rorqual 1,441 and Trillium 387, both with zero failure
  receipts; Totoro remained at 1,640 merged completions with its 48 active
  original R processes.
- One minute later Nibi had 394 completion receipts and 989 submitted user
  elements. The feeder reverified the list and submitted job `19396735` for
  exact indices 434--443 (`%10`), advancing its atomic next-index state to 444
  with zero failure receipts.
- At 407 Nibi completion receipts and 986 submitted user elements, the same
  checks passed and feeder job `19396872` scheduled exact indices 444--456
  (`%13`). The next-index state is 457; the next poll found 409 complete, 997
  submitted, and zero failures, so the feeder correctly waited.
- After waiting through at most eight safe slots, the feeder reverified the
  list at 418 complete/989 submitted and scheduled exact indices 457--466 as
  job `19397060` (`%10`). At 427 complete/989 submitted it repeated the checks
  and scheduled exact indices 467--476 as job `19397112` (`%10`). The atomic
  next-index state is now 477; zero failure receipts were observed.
- The feeder subsequently waited until 437 complete/989 submitted, then
  scheduled exact indices 477--486 as job `19397163` (`%10`). At 451
  complete/985 submitted, job `19397255` scheduled exact indices 487--500
  (`%14`). The atomic next-index state is now 501. The next two polls correctly
  waited at zero and seven safe slots; Nibi reached 458 complete with zero
  failure receipts.
- At 464 complete/986 submitted, feeder job `19397367` scheduled exact indices
  501--513 (`%13`). After correctly waiting at one and seven safe slots, it
  reached 474 complete/989 submitted and job `19397470` scheduled exact indices
  514--523 (`%10`). The atomic next-index state is now 524; the next poll found
  478 complete/996 submitted and zero failures, so the feeder waited.
- Nibi then advanced through four more authenticated batches: job `19397557`
  scheduled indices 524--534 at 485 complete/988 submitted; job `19397630`
  scheduled 535--544 at 495/989; job `19397775` scheduled 545--554 at 505/989;
  and job `19397972` scheduled 555--565 at 516/988 after correctly waiting
  through at most nine safe slots. The atomic next-index state is 566. A live
  audit found Nibi 521 complete/159 running locks, Rorqual 1,497 complete/216
  running locks, Trillium 412 complete/150 running locks, and Totoro 1,640
  complete/48 live R processes. All four failure-receipt counts were zero.
- The feeder next scheduled job `19398062` for exact indices 566--579 at 530
  complete/985 submitted, job `19398199` for 580--591 at 542/987, and job
  `19398343` for 592--602 at 553/988. Between submissions it correctly waited
  whenever headroom was below ten. The atomic next-index state is now 603; the
  next poll found 555 complete/997 submitted and zero failure receipts.
- Finalization-source audit: Totoro's immutable launch checkout has the same
  `2_summarise_lane_b_b2.R` SHA as the current worktree, but it lacks
  `4_adjudicate_lane_b_b2.R` and `lane-b-quasi-supplement.R`, and its runner
  and adjudication-helper SHAs predate the reviewed raw-receipt, permutation,
  spatial-v1, and quasi repairs. Do not modify that historical checkout.
  Before final aggregation, stage the current `inst/sim/lane-b/` directory in
  a separate Totoro finalizer directory, freeze a SHA-256 manifest, and run the
  complete aggregate plus strict adjudicator from that isolated source against
  the authoritative campaign root and installed launch runtime.
- Finalizer staging is now complete without running aggregation. A first v1
  archive was rejected because macOS provenance metadata produced Linux `._`
  companions; it must not be used. The authorized clean v2 archive is
  `/home/snakagaw/lane-b-finalizer-source-v2.tar.gz`, SHA-256
  `cf29dfd34de61226d6b7ff0674f11d2dd4eab399b51957570248f4e231164413`,
  extracted at `/home/snakagaw/gllvmtmb_lane_b_finalizer_20260809_v2` with 19
  ordinary files and zero `._` files. Its five core script SHAs match the local
  reviewed worktree exactly: summarizer `93a0d74d...`, adjudicator entrypoint
  `f6fdc6b6...`, runner `993606ac...`, adjudication helper `23738c29...`, and
  quasi helper `65b48932...`. Do not use the v1 staging directory; do not run
  v2 until the main queue is exactly 8,472/8,472 with zero failures.

## Commands and checks already completed

- Full focused and package test suites passed before distribution.
- `devtools::document()`, `pkgdown::check_pkgdown()`, affected article renders,
  the full article rebuild, isolated source installation, and a source-package
  check ending in `Status: OK` were completed before this checkpoint.
- B0 exact evidence is complete and Curie passed the launch-source receipt.
- A fresh continuation regression at 2026-08-09 12:47 UTC ran
  `devtools::test(filter = "(mspl-api|screen-separation|mspl-simulation-contract)",
  reporter = "summary", stop_on_failure = TRUE)` with one BLAS thread. It
  passed with one obsolete expected skip (`missing MSPL fails before a shard
  starts`); the API, inference fences, screening, exact ledgers, authentication,
  and B2 adjudication-contract tests were green.
- A full local package test followed with
  `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript
  --vanilla -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'`.
  It completed successfully after about 32 minutes. There were no test
  failures; declared heavy/matrix tests remained skipped, and the only two
  warnings were the pre-existing `gllvm` binary-comparator warnings about
  rows full of zeros. The run included the MSPL API, screening, simulation
  contract, inference fences, TMB/AGHQ/VA surfaces, articles, and extractors.
- `pkgdown::check_pkgdown()` then returned `No problems found`. An initial
  `pkgdown::build_articles(lazy = FALSE)` correctly exposed that the standalone
  renderer was using the previously installed package and therefore lacked
  the new `screen_control(separation = "fixed")` argument; no source/example
  was weakened. The current source namespace was loaded explicitly with
  `devtools::load_all()`, after which fresh source-backed renders of
  `articles/mspl-binary-jsdm`, `articles/pre-fit-response-screening`, and
  `articles/behavioural-syndromes` all completed successfully. The initial
  installed-package failure is retained as environment evidence, not counted
  as a green render.
- For the complete cross-article gate, the current source package was installed
  with `R CMD INSTALL --preclean` into isolated library
  `/private/tmp/gllvmtmb-pkgdown-lib.dGMmJV`. A first invocation that replaced
  the normal dependency library correctly failed on missing `assertthat`; the
  final invocation prepended the isolated library to the normal `.libPaths()`.
  It printed the installed current-source `screen_control()` signature,
  including `separation` and `separation_tolerance`, and
  `pkgdown::build_articles(lazy = FALSE)` then rendered the complete article
  set successfully, including `mspl-binary-jsdm`, `pre-fit-response-screening`,
  and `behavioural-syndromes`.
- The current B2 adjudicator passed Curie's final raw-receipt, permutation,
  spatial-v1, quasi, and fail-closed integrity reviews.
- Every DRAC setup is dependency-gated. Failed setup attempts released no fit
  jobs. Rorqual's active array reports the authoritative frozen hash and zero
  immediate failures.

## Still required

1. Complete the active Trillium run. The Fir quasi supplement is complete,
   authenticated, and installed at the authoritative Totoro root; its strict
   result is `QUASI-PROMOTION-WITHHELD` for all six link-by-rank families.
2. Let feeder PID `83639` submit the remaining Nibi future-list indices from
   423 as measured scheduler headroom appears; do not submit manually while
   its lock is alive. Rorqual is fully scheduled.
3. Collect and authenticate the Nibi, Rorqual, and Trillium keeper archives,
   then merge only verified raw shards plus completion receipts into the
   authoritative Totoro root. Fir main is already merged.
4. Let Totoro's 48 already-running owned shards finish, then terminate the
   stopped launcher without resuming it. Reassign only an explicitly
   authenticated missing shard.
5. Run the single complete aggregate and current strict adjudicator.
6. Update public claims and the validation register from the observed verdict,
   then repeat package, pkgdown, source-check, review, and three-OS CI gates.

## Next safest action

Monitor active arrays and failure receipts. Do not aggregate or adjudicate a
partial queue. Poll feeder PID `83639` and its state/log; do not submit Nibi
work manually while `/private/tmp/lane-b-nibi-feeder-v1.lock` exists.
Rorqual requires no more submissions.
Collect each keeper only after its exact-count, zero-failure dependency gate
succeeds.

## Blocking maintainer question

None. Totoro and DRAC use were explicitly authorized; all estimator, fixture,
seed, threshold, and adjudication contracts remain unchanged.
