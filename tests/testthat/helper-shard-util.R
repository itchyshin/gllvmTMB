# Pure-logic helpers for deterministic testthat sharding (GLLVMTMB_TEST_SHARD="k/N").
# Base R only, no package load -- sourced by tests/testthat.R before test_check(),
# and standalone by tests/testthat/test-shard-selection.R.

# Parse a "k/N" shard spec (1-based k of N shards). Stops on a malformed spec
# rather than silently running everything: a typo that quietly disabled sharding
# would make CI pass by running a quarter of the suite four times.
gllvm_parse_shard_spec <- function(spec) {
  parts <- strsplit(spec, "/", fixed = TRUE)[[1]]
  if (length(parts) != 2L) {
    stop("malformed GLLVMTMB_TEST_SHARD ", sQuote(spec), '; expected "k/N"', call. = FALSE)
  }
  k <- suppressWarnings(as.integer(parts[1L]))
  n <- suppressWarnings(as.integer(parts[2L]))
  if (anyNA(c(k, n))) {
    stop("malformed GLLVMTMB_TEST_SHARD ", sQuote(spec), "; k and N must be integers", call. = FALSE)
  }
  if (n < 1L) stop("GLLVMTMB_TEST_SHARD ", sQuote(spec), ": N must be >= 1", call. = FALSE)
  if (k < 1L || k > n) {
    stop("GLLVMTMB_TEST_SHARD ", sQuote(spec), ": need 1 <= k <= N", call. = FALSE)
  }
  c(k = k, n = n)
}

# 1-based indices of 1:len assigned to shard k of n, by (i - 1) %% n == k - 1.
# The n shards partition 1:len exactly -- every index lands in exactly one shard.
gllvm_shard_indices <- function(len, k, n) {
  if (len < 0L) stop("len must be >= 0", call. = FALSE)
  if (n < 1L) stop("n must be >= 1", call. = FALSE)
  if (k < 1L || k > n) stop("need 1 <= k <= n", call. = FALSE)
  if (len == 0L) return(integer(0))
  which((seq_len(len) - 1L) %% n == k - 1L)
}

# The testthat `filter` regex selecting this shard's files, or NULL for no
# sharding. testthat matches `filter` against each test file name AFTER
# stripping the "test-" prefix and the ".R" extension, so the names are stripped
# the same way here and anchored with ^(...)$ so one name cannot match another.
#
# sort(method = "radix") is deliberate and load-bearing: the default sort is
# LOCALE-DEPENDENT, so two runners with different collation would disagree about
# file ORDER and the shards would then overlap and leave gaps -- tests silently
# skipped, with every job still green. Radix order is byte order everywhere.
gllvm_shard_filter <- function(dir = "testthat",
                             spec = Sys.getenv("GLLVMTMB_TEST_SHARD", "")) {
  if (!nzchar(spec)) return(NULL)
  kn <- gllvm_parse_shard_spec(spec)
  files <- sort(list.files(dir, pattern = "^test-.*\\.[Rr]$"), method = "radix")
  if (length(files) == 0L) {
    stop("GLLVMTMB_TEST_SHARD set but no test files found in ", sQuote(dir), call. = FALSE)
  }
  idx <- gllvm_shard_indices(length(files), kn[["k"]], kn[["n"]])
  if (length(idx) == 0L) return("^$a")  # matches nothing: an empty shard runs nothing
  nm <- sub("\\.[Rr]$", "", sub("^test-", "", files[idx]))
  # Escape every non-alphanumeric character rather than enumerating regex
  # metacharacters in a bracket expression -- that is what a character class is
  # easy to get subtly wrong at, and a mis-escaped name silently selects nothing.
  paste0("^(", paste(gsub("([^A-Za-z0-9_])", "\\\\\\1", nm), collapse = "|"), ")$")
}
