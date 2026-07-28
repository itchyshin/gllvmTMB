## Structural gate for adaptive Gauss-Hermite quadrature (AGHQ) eligibility.
##
## Owned by G1.  Every function here is internal (no @export, no NAMESPACE
## edit).  Consumer: A1's `.aghq_auto_decide()` (R/aghq-control.R) reads the
## data.frame `.aghq_gate()` returns to decide "auto" routing per block.
##
## WHY THIS FILE MEASURES INSTEAD OF PATTERN-MATCHING: AGHQ's per-unit cost is
## k^(treewidth + 1). Whether a random block is affordable therefore depends
## on the conditional-independence structure of its Hessian graph, which a
## keyword whitelist cannot see -- `(1 | region)` (a partition, a cut vertex,
## +1 to treewidth, cheap) and `(1 | region) + (1 | year)` (two crossed
## groupings, treewidth ~ min(n_region, n_year), hopeless) use the same
## keywords and differ by orders of magnitude. So the gate measures the
## actual sparsity of `obj$env$spHess(obj$env$last.par, random = TRUE)`
## rather than looking at which `*()` keywords were used.
##
## METHOD
##   1. Read the random-effect Hessian sparsity pattern and map its rows/cols
##      back to named TMB parameter blocks via `names(obj$env$par)[obj$env$random]`.
##   2. Union-find the connected components of that sparsity graph (no igraph
##      dependency -- it is not in DESCRIPTION -- so this is a ~20-line
##      union-find).
##   3. For each component, upper-bound its treewidth by min-fill elimination
##      (exact treewidth is NP-hard; an upper bound is the right tool, and the
##      returned `reason` says so explicitly).
##   4. Route "quadrature" if treewidth <= threshold (default 4), else
##      "laplace". Components with identical (parameter-name signature, size,
##      treewidth, route) are folded into one output row with
##      `n_components` = how many such components were found (this is the
##      common case: a `latent(0 + trait | site)` term produces one
##      isomorphic star component per site).
##   5. HARD EXCLUSIONS override the measured route to "laplace" regardless
##      of what the measurement says (see `.aghq_gate_hard_reasons` below for
##      why measurement alone is not trustworthy for these): REML (`b_fix`
##      joins `random` with no prior term, R/fit-multi.R:4707), `equalto()`
##      (`e_eq`, dense n_obs known-V MVN), `propto()` (`p_phy`, dense
##      phylogenetic Cphy_inv), and the dedicated multi-kernel block
##      (`g_kernel` / `g_kernel_diag`, dense Ainv_kernel). NOTE: a *single*
##      named `kernel_*()` tier is desugared onto the phylo_rr machinery
##      (`g_phy`) rather than `g_kernel` (verified empirically) -- that case
##      is not named in this hard list and is caught by measurement instead,
##      because Ainv_phy_rr is generically dense enough to measure a large
##      treewidth on its own. Only the genuinely *multi*-kernel path
##      (2+ named tiers, `n_kernel_tiers > 1`) touches `g_kernel` directly.

## ---------------------------------------------------------------------------
## (1) Union-find (no igraph dependency -- not in DESCRIPTION)
## ---------------------------------------------------------------------------

.aghq_union_find <- function(n) {
  list(parent = seq_len(n), rank = integer(n))
}

.aghq_uf_find <- function(uf, x) {
  while (uf$parent[x] != x) {
    uf$parent[x] <- uf$parent[uf$parent[x]]
    x <- uf$parent[x]
  }
  x
}

.aghq_uf_union <- function(uf, x, y) {
  rx <- .aghq_uf_find(uf, x)
  ry <- .aghq_uf_find(uf, y)
  if (rx == ry) return(uf)
  if (uf$rank[rx] < uf$rank[ry]) {
    tmp <- rx; rx <- ry; ry <- tmp
  }
  uf$parent[ry] <- rx
  if (uf$rank[rx] == uf$rank[ry]) uf$rank[rx] <- uf$rank[rx] + 1L
  uf
}

## ---------------------------------------------------------------------------
## (2) Min-fill elimination-ordering upper bound on treewidth
## ---------------------------------------------------------------------------

## Exact treewidth is NP-hard; this returns an UPPER BOUND via a standard
## min-fill greedy elimination ordering (repeatedly eliminate the vertex whose
## removal adds the fewest fill-in edges, breaking ties by lowest degree).
## `size_cap` short-circuits to the trivial bound (size - 1) for components
## too large for the O(n^3) heuristic to be worth running -- those components
## are already destined for "laplace" on cost grounds, so exactness there
## buys nothing.
.aghq_treewidth_upper_bound <- function(adj, size_cap = 400L) {
  n <- length(adj)
  if (n <= 1L) return(0L)
  if (n > size_cap) return(n - 1L)
  nbr <- adj
  active <- rep(TRUE, n)
  width <- 0L
  for (step in seq_len(n)) {
    idx <- which(active)
    best_v <- idx[1]; best_fill <- Inf; best_deg <- Inf
    for (v in idx) {
      nb <- nbr[[v]]
      nb <- nb[active[nb]]
      deg <- length(nb)
      fill <- 0L
      if (deg >= 2L) {
        for (i in seq_len(deg - 1L)) {
          a <- nb[i]
          rest <- nb[(i + 1L):deg]
          fill <- fill + sum(!(rest %in% nbr[[a]]))
        }
      }
      if (fill < best_fill || (fill == best_fill && deg < best_deg)) {
        best_fill <- fill; best_deg <- deg; best_v <- v
      }
    }
    nb <- nbr[[best_v]]
    nb <- nb[active[nb]]
    width <- max(width, length(nb))
    if (length(nb) >= 2L) {
      for (i in seq_len(length(nb) - 1L)) {
        a <- nb[i]
        for (j in (i + 1L):length(nb)) {
          b <- nb[j]
          if (!(b %in% nbr[[a]])) {
            nbr[[a]] <- c(nbr[[a]], b)
            nbr[[b]] <- c(nbr[[b]], a)
          }
        }
      }
    }
    active[best_v] <- FALSE
  }
  width
}

## ---------------------------------------------------------------------------
## (3) Hard-exclusion reasons, keyed by the TMB parameter name that signals
##     the excluded structure. These fire regardless of measured treewidth --
##     see the file banner for why measurement alone is not trustworthy here
##     (a diagonal known-V still triggers `equalto()`'s general dense-V
##     mechanism, and would otherwise measure as treewidth 0 by luck of the
##     particular V passed in; verified empirically, see dev-log).
## ---------------------------------------------------------------------------

.aghq_gate_hard_dense_reasons <- c(
  e_eq = paste(
    "equalto(): dense n_obs known-covariance MVN prior (cpp:1767-1772)",
    "couples every observation into one block; not decomposable,",
    "excluded regardless of measured treewidth."
  ),
  p_phy = paste(
    "propto(): dense phylogenetic-covariance prior (Cphy_inv) couples all",
    "species into one block; not decomposable, excluded regardless of",
    "measured treewidth."
  ),
  g_kernel = paste(
    "kernel_*(): dense multi-kernel-covariance prior (Ainv_kernel,",
    "cpp:1160-1168) couples all levels into one block; not decomposable,",
    "excluded regardless of measured treewidth."
  ),
  g_kernel_diag = paste(
    "kernel_*(): dense multi-kernel-covariance prior (Ainv_kernel,",
    "cpp:1160-1168) couples all levels into one block; not decomposable,",
    "excluded regardless of measured treewidth."
  )
)

.aghq_gate_reml_reason <- paste(
  "REML: b_fix joins `random` (R/fit-multi.R:4707) with no prior term of",
  "any kind (flat/improper); AGHQ over an improper flat block is not",
  "well-posed, excluded regardless of measured treewidth."
)

## ---------------------------------------------------------------------------
## (4) The gate itself
## ---------------------------------------------------------------------------

#' Structural AGHQ eligibility gate (internal)
#'
#' Measures the connected-component structure and an upper bound on the
#' treewidth of each random-effect block in a fitted TMB object's Hessian
#' sparsity graph, and routes each to `"quadrature"` or `"laplace"`.
#'
#' @param obj A `TMB::MakeADFun()` object post-fit (e.g. `fit$tmb_obj`); its
#'   `env$last.par` must already be populated (true of any fitted model).
#' @param data The `tmb_data` list passed to `MakeADFun()` (e.g.
#'   `fit$tmb_data`); used only for the `REML`, `use_equalto`, `use_propto`
#'   hard-exclusion flags (`g_kernel`/`b_fix` membership is read directly off
#'   the parameter names, not off `data`).
#' @param threshold Maximum treewidth routed to `"quadrature"`; default 4
#'   (k^(4+1) = k^5 = 59,049 at k = 9 -- already the outer edge of an
#'   affordable per-unit cost multiplier; 5 pushes to 531,441).
#'
#' @return A data.frame with one row per distinct (parameter-name signature,
#'   size, treewidth, route) combination found among the random-effect
#'   Hessian's connected components: `block`, `size`, `n_components`,
#'   `treewidth`, `route` (`"quadrature"` | `"laplace"`), `reason`.
#' @keywords internal
.aghq_gate <- function(obj, data, threshold = 4L) {
  random_idx <- obj$env$random
  if (length(random_idx) == 0L) {
    return(data.frame(
      block = character(0), size = integer(0), n_components = integer(0),
      treewidth = integer(0), route = character(0), reason = character(0),
      stringsAsFactors = FALSE
    ))
  }

  par_names <- names(obj$env$par)
  rn <- par_names[random_idx]

  H <- obj$env$spHess(obj$env$last.par, random = TRUE)
  H <- as(H, "TsparseMatrix")
  n <- nrow(H)
  keep <- H@i != H@j & H@x != 0
  ii <- H@i[keep] + 1L
  jj <- H@j[keep] + 1L

  uf <- .aghq_union_find(n)
  for (k in seq_along(ii)) uf <- .aghq_uf_union(uf, ii[k], jj[k])
  roots <- vapply(seq_len(n), function(x) .aghq_uf_find(uf, x), integer(1))
  comp_ids <- unique(roots)

  adj_global <- vector("list", n)
  for (k in seq_along(ii)) {
    adj_global[[ii[k]]] <- c(adj_global[[ii[k]]], jj[k])
    adj_global[[jj[k]]] <- c(adj_global[[jj[k]]], ii[k])
  }

  reml_flag <- isTRUE(as.logical(data$REML))

  rows <- vector("list", length(comp_ids))
  for (m in seq_along(comp_ids)) {
    cid <- comp_ids[m]
    nodes <- which(roots == cid)
    size <- length(nodes)
    local_index <- stats::setNames(seq_along(nodes), nodes)
    adj_local <- lapply(nodes, function(g) {
      nb <- adj_global[[g]]
      unname(local_index[as.character(nb)])
    })
    names_here <- sort(unique(rn[nodes]))
    block_lab <- paste(names_here, collapse = "+")

    hard_hit <- intersect(names_here, names(.aghq_gate_hard_dense_reasons))
    is_reml_hit <- reml_flag && ("b_fix" %in% names_here)

    if (is_reml_hit || length(hard_hit) > 0L) {
      tw <- NA_integer_
      route <- "laplace"
      reason <- if (is_reml_hit) {
        .aghq_gate_reml_reason
      } else {
        .aghq_gate_hard_dense_reasons[[hard_hit[1]]]
      }
    } else {
      tw <- .aghq_treewidth_upper_bound(adj_local)
      route <- if (tw <= threshold) "quadrature" else "laplace"
      reason <- sprintf(
        paste(
          "min-fill elimination upper bound on treewidth = %d (exact",
          "treewidth is NP-hard; this is an upper bound, not exact) against",
          "threshold %d -> k^(tw+1) cost factor at k=9 is %s per unit."
        ),
        tw, threshold, format(9^(tw + 1), big.mark = ",", scientific = FALSE)
      )
    }

    rows[[m]] <- data.frame(
      block = block_lab, size = size, treewidth = tw, route = route,
      reason = reason, stringsAsFactors = FALSE
    )
  }

  df <- do.call(rbind, rows)
  agg_key <- paste(df$block, df$size, df$treewidth, df$route, sep = "\r")
  out <- do.call(rbind, lapply(split(df, agg_key), function(g) {
    data.frame(
      block = g$block[1], size = g$size[1], n_components = nrow(g),
      treewidth = g$treewidth[1], route = g$route[1], reason = g$reason[1],
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out[order(out$block), ]
}
