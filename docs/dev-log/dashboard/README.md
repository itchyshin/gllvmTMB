# GLLVM Mission-Control Dashboard

This directory stores the durable source for the local `gllvmTMB` +
`GLLVM.jl` finish dashboard. The primary live copy is synced to
`/tmp/gllvm-dashboard` so the repository remains the source of truth.
If port 8770 is already held by an older local `http.server` serving
`pkgdown-site/`, the launcher also mirrors these same files into that
ignored directory as disposable output.

Start or refresh the board with:

```sh
sh tools/start-mission-control.sh --background
```

Then open:

```text
http://127.0.0.1:8770/
```

The page reads `status.json` and `sweep.json` every eight seconds.
Use `status.json` for curated operating truth and `sweep.json` for
volatile PR, workflow, issue, and run snapshots. JSON updates do not
need a version bump.

Keep `version.txt` equal to the `BUILD` constant in `index.html`.
Change both only when the HTML or JavaScript changes.

Claim rule: the board is local mission control. It is not the public
pkgdown site, CRAN readiness, or scientific coverage proof. A green PR
check does not make a bridge complete, release-ready, or validated for
power/coverage unless the matrix row names the evidence.
