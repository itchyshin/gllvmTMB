## dev/multinomial-structured/gate-check-a-proj.R
##
## Slice 3 (Design 122, 2026-08-16), GATE CHECK (run BEFORE any spatial
## admission edit landed): does the SPDE projection matrix `A_proj` align
## correctly with the multinomial K-1 contrast-row expansion?
##
## `expand_multinomial_response()` (R/gllvmTMB.R) runs at the very top of
## `gllvmTMB()`, BEFORE mesh/A_proj construction: it duplicates each
## categorical observation into K-1 contrast pseudo-trait rows via
## `data[rep(seq_len(n), each = L), , drop = FALSE]` (L = K - 1), preserving
## every other column -- including any coordinate columns -- verbatim, in
## consecutive per-site blocks. The SPDE eta contribution is applied
## per EXPANDED row (`eta(o) += (A_proj %*% omega)(o)`, src/gllvmTMB.cpp). If
## `A_proj` were built on the PRE-expansion (n_site) data, its row count and
## row-to-observation mapping would silently mismatch the post-expansion
## `data`/`n_obs` the rest of the engine uses -- an engine bug, not something
## to admit around.
##
## FINDING: this is NOT a bug. `make_mesh()` (R/mesh.R) is a pure per-row
## function of whatever coordinate data.frame it is given; `A_proj`
## (`mesh$A_st`) is validated (R/fit-multi.R, `nrow(mesh$A_st) == n_obs`,
## `n_obs` measured on the ALREADY-expanded `data`) with a LOUD, informative
## abort if it does not match -- naively building the mesh on the user's
## original per-site data (before internal expansion) fails loud rather than
## silently misaligning rows. When the mesh is built on a coordinate frame
## pre-expanded with the SAME `rep(seq_len(n), each = K - 1)` convention
## `expand_multinomial_response()` uses internally (same consecutive-block
## row order), `A_proj` aligns EXACTLY: every site's K-1 contrast rows carry
## the IDENTICAL projector row (same coordinates -> same basis weights),
## giving the intended semantic of ONE shared spatial field draw per site
## entering every one of its category-contrast linear predictors.
##
## Usage: Rscript dev/multinomial-structured/gate-check-a-proj.R
## Needs: fmesher (INLA is NOT required -- verified here; make_mesh() and the
## base SPDE engine both work without it in this environment).

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
PKG_DIR <- Sys.getenv("GLLVMTMB_DIR", file.path(.here, "..", ".."))

`%||%` <- function(a, b) if (is.null(a)) b else a

suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))

set.seed(1L)
n_site <- 40L
K <- 3L
df <- data.frame(
  site = factor(seq_len(n_site)),
  x = stats::runif(n_site), y = stats::runif(n_site),
  trait = factor("cat"),
  value = factor(sample.int(K, n_site, replace = TRUE))
)

cat("== Step 1: naive mesh built on UN-expanded (n_site) data ==\n")
mesh_naive <- make_mesh(df, c("x", "y"), cutoff = 0.12)
cat("nrow(mesh_naive$A_st):", nrow(mesh_naive$A_st), " (n_site =", n_site, ")\n")

fit1 <- tryCatch(
  gllvmTMB(value ~ 0 + trait + spatial_indep(0 + trait | coords),
           data = df, family = multinomial(), trait = "trait",
           mesh = mesh_naive),
  error = function(e) e
)
if (inherits(fit1, "error")) {
  cat("naive-mesh fit ERRORED (EXPECTED -- loud, not silent):\n  ", conditionMessage(fit1), "\n")
} else {
  cat("naive-mesh fit SUCCEEDED -- UNEXPECTED, this would need investigation as a possible silent-misalignment bug\n")
}

cat("\n== Step 2: pre-expanded mesh (each site repeated K - 1 =", K - 1L, "times) ==\n")
L <- K - 1L
idx <- rep(seq_len(n_site), each = L)
df_expanded_coords <- df[idx, , drop = FALSE]
cat("nrow(df_expanded_coords):", nrow(df_expanded_coords),
    " (n_site * (K - 1) =", n_site * L, ")\n")

mesh_pre <- make_mesh(df_expanded_coords, c("x", "y"), cutoff = 0.12)
cat("nrow(mesh_pre$A_st):", nrow(mesh_pre$A_st), "\n")

fit2 <- tryCatch(
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | coords),
    data = df, family = multinomial(), trait = "trait",
    mesh = mesh_pre
  ))),
  error = function(e) e
)
if (inherits(fit2, "error")) {
  cat("pre-expanded-mesh fit ERRORED (unexpected):\n  ", conditionMessage(fit2), "\n")
  cat("\nGATE CHECK: FAIL (see error above) -- STOP the slice.\n")
} else {
  cat("pre-expanded-mesh fit SUCCEEDED\n")
  cat("tmb_data$n_obs:", length(fit2$tmb_data$y), "\n")
  A <- fit2$tmb_data$A_proj
  cat("dim(A_proj):", paste(dim(A), collapse = " x "), "\n")
  cat("expected n_obs (n_site * L):", n_site * L, "\n")

  ## Row-alignment check: reconstruct the expansion order
  ## expand_multinomial_response() uses internally (consecutive L-row blocks,
  ## one block per original site, in original row order) and confirm every
  ## block's L rows of A_proj are IDENTICAL (same site -> same coordinates ->
  ## same basis-function weights).
  all_match <- TRUE
  mismatches <- 0L
  for (b in seq_len(n_site)) {
    rows <- ((b - 1L) * L + 1L):(b * L)
    block <- as.matrix(A[rows, , drop = FALSE])
    if (L > 1L) {
      ref <- block[1L, ]
      for (r in 2:L) {
        if (!isTRUE(all.equal(block[r, ], ref, tolerance = 1e-10))) {
          all_match <- FALSE
          mismatches <- mismatches + 1L
        }
      }
    }
  }
  cat("All within-site A_proj rows identical across K-1 contrasts:", all_match,
      " (mismatched blocks:", mismatches, "/", n_site, ")\n")

  row1_match <- isTRUE(all.equal(
    as.numeric(A[1, ]), as.numeric(mesh_pre$A_st[1, ]), tolerance = 1e-10
  ))
  cat("A_proj row 1 == mesh_pre$A_st row 1 (A_proj really is the mesh's own projector):",
      row1_match, "\n")

  verdict <- all_match && row1_match && isTRUE(nrow(A) == n_site * L)
  cat("\nGATE CHECK:", if (verdict) "PASS" else "FAIL", "\n")
  if (!verdict) {
    cat("STOP the slice -- report this as an engine bug, do not proceed with admission.\n")
  }
}
