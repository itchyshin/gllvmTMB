## Seed the RNG for the duration of the calling function, then put the
## caller's global RNG state back (#1413).
##
## `set.seed(seed)` inside an exported function leaves the user's stream in
## the seed-derived state, so later `runif()` / `sample()` calls in their
## script repeat or depend on that seed. `stats::simulate()` methods and
## `residuals(type = "randomized_quantile", seed =)` restore the state; this
## helper gives the other `seed =` arguments the same behaviour.
##
## Call it once near the top of the function that owns `seed`; the restore is
## registered on that function's exit (`on.exit(add = TRUE)`), including on
## error. `seed = NULL` (or any zero-length value) is a no-op and the stream is left alone.
.gllvmTMB_local_seed <- function(seed, .envir = parent.frame()) {
  if (!length(seed)) {
    return(invisible(NULL))
  }
  genv <- globalenv()
  if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = genv, inherits = FALSE)
    restore <- bquote(assign(".Random.seed", .(old_seed), envir = globalenv()))
  } else {
    restore <- quote(
      suppressWarnings(rm(".Random.seed", envir = globalenv()))
    )
  }
  do.call(base::on.exit, list(restore, TRUE), envir = .envir)
  set.seed(seed)
  invisible(NULL)
}

## Jitter offsets for the extra multi-start restarts (#1331).
##
## Drawn under a fixed internal seed (`.gllvmTMB_local_seed()` restores the
## caller's `.Random.seed`, or removes it if it did not exist), so a default
## `n_init = 3` fit neither consumes nor depends on the user's random stream,
## and the same data and model always get the same restart sequence.
.gllvmTMB_jitter_offsets <- function(n, len, sd, seed = 1331L) {
  if (n < 1L) {
    return(list())
  }
  .gllvmTMB_local_seed(seed)
  lapply(seq_len(n), function(i) stats::rnorm(len, sd = sd))
}
