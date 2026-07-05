# Consolidation Surface Audit: gllvmTMB Completion Branch

**Date**: 2026-07-04
**Branch**: `codex/r-bridge-grouped-dispersion`
**Roles**: Ada, Rose, Shannon, Grace

## Aim

Check whether the completion branch should keep adding capability or pause for
consolidation. The answer from this audit is: pause new capability work, continue
only low-risk correctness/cleanup fixes, and make the branch reviewable.

## Branch State

- `git status --short --branch`: clean before this cleanup slice.
- Branch was ahead of `origin/codex/r-bridge-grouped-dispersion` by 111 commits.
- `git log --oneline --no-merges origin/main..HEAD | wc -l`: 173 commits.
- `git diff --shortstat origin/main...HEAD`: 514 files changed, 77853
  insertions, 16023 deletions.
- `gh pr list --state open`: no open PRs reported.

## Surface Checks

```sh
Rscript --vanilla - <<'RS'
pkgload::load_all(quiet = TRUE)
ns <- asNamespace("gllvmTMB")
exp <- sort(getNamespaceExports("gllvmTMB"))
missing <- exp[!vapply(exp, exists, logical(1), envir = ns, inherits = FALSE)]
RS
```

Outcome: `tidy` was the only non-local object under `inherits = FALSE`; it is a
valid `generics::tidy` re-export and `getExportedValue("gllvmTMB", "tidy")`
works.

```sh
Rscript --vanilla - <<'RS'
lines <- readLines("NAMESPACE", warn = FALSE)
exports <- sort(sub(
  "^export\\((.*)\\)$",
  "\\1",
  grep("^export\\(", lines, value = TRUE)
))
rd_files <- list.files("man", pattern = "[.]Rd$", full.names = TRUE)
aliases <- unique(unlist(lapply(rd_files, function(f) {
  x <- readLines(f, warn = FALSE)
  hits <- grep("^\\\\alias\\{", x, value = TRUE)
  sub("^\\\\alias\\{(.*)\\}$", "\\1", hits)
})))
missing_alias <- setdiff(exports, aliases)
cat("namespace_exports", length(exports), "aliases", length(aliases), "\n")
if (length(missing_alias)) {
  cat("exports_without_alias:\n")
  cat(paste(missing_alias, collapse = "\n"), "\n")
} else {
  cat("exports_without_alias: none\n")
}
RS
```

Outcome: 153 NAMESPACE exports, 191 Rd aliases, no exported function missing an
Rd alias.

```sh
Rscript --vanilla - <<'RS'
files <- list.files("R", pattern = "[.]R$", full.names = TRUE)
rx <- "^([.A-Za-z][.A-Za-z0-9_]*)[[:space:]]*<-[[:space:]]*function[[:space:]]*[(]"
defs <- do.call(rbind, lapply(files, function(f) {
  x <- readLines(f, warn = FALSE)
  hit <- grep(rx, x)
  if (!length(hit)) return(NULL)
  mm <- regexec(rx, x[hit])
  name <- vapply(regmatches(x[hit], mm), `[`, character(1), 2)
  data.frame(name = name, file = f, line = hit, stringsAsFactors = FALSE)
}))
dup <- defs[defs$name %in% names(which(table(defs$name) > 1)), ]
cat("function_defs", nrow(defs), "duplicate_names", length(unique(dup$name)), "\n")
if (nrow(dup)) print(dup[order(dup$name, dup$file, dup$line), ], row.names = FALSE)
RS
```

Outcome: 599 scanned function definitions, 0 duplicate top-level function names.

## Decision

Do not start new public capability work from this branch before consolidation.
The exported surface and top-level definitions are not obviously broken, but the
branch is too large to keep widening safely. Treat cleanup issues as admissible
only when they are:

- local and low-risk;
- covered by a focused test or direct parse/check;
- not changing public claims, formula grammar, or interval calibration status.

## Low-Risk Fixes Selected

- Issue #703: rotated ordination plots extracted ordination twice. Fixed by
  letting `rotate_loadings()` own extraction for rotated output, while raw
  `rotation = "none"` still calls `extract_ordination()` directly. A regression
  counts calls and checks both paths extract once.
- Issue #704: a profile-refit comment claimed mixed analytic/numerical gradient
  use, but `nlminb()` is called without a gradient. Corrected the comment only;
  no optimizer change in this consolidation slice.

## What Not To Do Next

- Do not add new families, source-specific `lv`, missing-data expansion, or
  mixed-family interval claims from this branch before review packaging.
- Do not treat `pdHess = TRUE` or local focused tests as interval calibration.
- Do not push or open a PR without maintainer authorization.

## Next Best Move

Prepare a review package:

1. Summarize the 173 commits into reviewable groups.
2. Run focused tests for the changed inference/plot/bridge surfaces.
3. Run `devtools::document()`, `pkgdown::check_pkgdown()`, and
   `devtools::check(args = "--no-manual")` when the focused suite is green.
4. Refresh Mission Control only when the operating truth changes.
