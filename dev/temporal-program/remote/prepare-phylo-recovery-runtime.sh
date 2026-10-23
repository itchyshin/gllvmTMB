#!/usr/bin/env bash
# Build and verify one private installed-package runtime on an allocated node.
# The recovery workers only consume this exact library; they never compile it.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$script_dir/../../.." && pwd)"
: "${R_LIBS_USER_DIR:?Set a private durable R library path.}"
r_module="${R_MODULE:-r/4.5.0}"
source_commit="$(git -C "$root" rev-parse HEAD)"
test -z "$(git -C "$root" status --porcelain)"

module load "$r_module"
mkdir -p "$R_LIBS_USER_DIR"
R CMD INSTALL --library="$R_LIBS_USER_DIR" "$root"
R_LIBS_USER="$R_LIBS_USER_DIR" R_LIBS="$R_LIBS_USER_DIR${R_LIBS:+:$R_LIBS}" \
  Rscript --vanilla -e 'library(gllvmTMB); stopifnot(exists("gllvmTMB", mode = "function")); cat("TEMPORAL_PHYLO_RUNTIME_PASS\\n")'
printf 'source_commit\t%s\n' "$source_commit"
printf 'r_module\t%s\n' "$r_module"
printf 'r_library\t%s\n' "$R_LIBS_USER_DIR"
