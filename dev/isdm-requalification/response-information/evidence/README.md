# Tamia retained evidence receipt

Raw retained receipts are preserved at:

```text
/project/6114083/isdm-response-information/response-information-6219a478-tamia
```

The original `/home/s/snakagaw/isdm-response-information/pilot-6219a478-tamia`
copy is retained as a non-authoritative duplicate. The `/project` copy contains
800 `attempts/task-*.rds` records, `runtime-identity.rds`, and
`attempts.sha256`. On 2026-09-01, `sha256sum -c attempts.sha256` passed for all
800 files.

- `tamia-attempts.sha256`: committed compact file-level manifest; aggregate
  SHA-256 `6ac8b1aa246f913e2403d3373d6a115542ce4b03b026fd8204f6facb732112d8`.
- `independent-summary-v3.rds`: retained only on `/project`; SHA-256
  `a9c123847ba0122b411dd7b01381abdd9f3243301842cfc1754b5c863b4f74d6`.
  It was written once by a scorer that verifies the frozen runtime source and
  harness identities and reports scoreable pair counts `50,50,50,50,50,50,48,50`.

Raw RDS files, libraries, binaries, scheduler logs, and check trees are
intentionally excluded from Git.
