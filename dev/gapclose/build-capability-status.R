#!/usr/bin/env Rscript
# Build docs/design/capability-status.md -- the R-side twin of GLLVM.jl's
# docs/design/capability-status.md -- from docs/design/35-validation-debt-register.md.
#
# GENERATED FILE. Edit THIS SCRIPT, not docs/design/capability-status.md.
#
# Usage:
#   Rscript dev/gapclose/build-capability-status.R          # (re)writes the ledger
#   Rscript dev/gapclose/build-capability-status.R --check  # verify it is up to date;
#                                                            # exits non-zero + prints a
#                                                            # diff / unmapped-row list if not
#
# The register is the source of truth; this script's REGISTER_MAP is a small
# hand-curated table that says which register row(s) back which ledger
# capability. Every register row must appear either in REGISTER_MAP (mapped
# to a ledger row) or in UNMAPPED_BY_DESIGN (with a one-line reason). The
# --check mode fails loudly if a new register row shows up unmapped, so this
# script has to be re-run (and the map extended) whenever the register grows.

suppressWarnings(suppressMessages({
  args <- commandArgs(trailingOnly = TRUE)
}))
CHECK_MODE <- "--check" %in% args

# Resolve repo root: this script lives at <root>/dev/gapclose/build-capability-status.R
this_file <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
if (length(this_file) == 0) this_file <- "dev/gapclose/build-capability-status.R"
ROOT <- normalizePath(file.path(dirname(this_file), "..", ".."), mustWork = TRUE)

REGISTER_PATH <- file.path(ROOT, "docs", "design", "35-validation-debt-register.md")
OUTPUT_PATH   <- file.path(ROOT, "docs", "design", "capability-status.md")

# ---------------------------------------------------------------------------
# 1. Parse the register: every "| ID | Capability text | `status` | ..." row,
#    anywhere in the file (any section). Dynamic -- re-run to pick up edits.
# ---------------------------------------------------------------------------

read_register_rows <- function(path) {
  lines <- readLines(path, warn = FALSE)
  # An ID cell: starts the line "| <ID> |" where <ID> looks like a row id
  # (letters/digits/./- , e.g. FG-04, FAM-20A, CRAN07-AA-05B, STR-RHO-FIX).
  # The row's status is the FIRST backtick-quoted lowercase-ish word/phrase
  # after the ID+capability cells.
  # Status is usually backtick-quoted (`covered`), with arbitrary extra text
  # after it in the same cell (e.g. "`covered` (intercept); slope C1 `partial`
  # via RE-14"): pat1 only requires the backtick-quoted word to appear, it
  # does not anchor to the next "|". The 2026-08-31 "Structured source
  # strength arc" section (local candidate only, not yet promoted to the
  # ratified FG-/FAM-/... ID convention) writes status bare instead, with
  # nothing else in the cell -- pat2 catches that as a fallback, requiring the
  # bare word to be the whole cell (immediately closed by "|") so it can't
  # accidentally grab a word out of a long capability/evidence description.
  pat1 <- "^\\|\\s*([A-Za-z0-9][A-Za-z0-9.\\-]*)\\s*\\|\\s*(.*?)\\s*\\|\\s*`([a-z][a-z-]*)`"
  pat2 <- "^\\|\\s*([A-Za-z0-9][A-Za-z0-9.\\-]*)\\s*\\|\\s*(.*?)\\s*\\|\\s*([a-z][a-z-]*)\\s*\\|"

  extract <- function(pat) {
    m <- regmatches(lines, regexec(pat, lines))
    hit <- vapply(m, function(x) length(x) == 4, logical(1))
    m <- m[hit]
    data.frame(id = vapply(m, `[[`, character(1), 2),
               capability = vapply(m, `[[`, character(1), 3),
               status = vapply(m, `[[`, character(1), 4),
               stringsAsFactors = FALSE)
  }

  r1 <- extract(pat1)
  r2 <- extract(pat2)
  r2 <- r2[!(r2$id %in% r1$id), , drop = FALSE]  # pat1 takes priority
  out <- rbind(r1, r2)
  keep <- out$id != "ID"   # drop table header rows "| ID | Capability | Status |"
  out[keep, , drop = FALSE]
}

reg <- read_register_rows(REGISTER_PATH)
if (anyDuplicated(reg$id)) {
  dup <- reg$id[duplicated(reg$id)]
  stop("Register row id(s) appear more than once (table rendering artifact?): ",
       paste(unique(dup), collapse = ", "))
}
reg_status <- setNames(reg$status, reg$id)

# ---------------------------------------------------------------------------
# 2. Vocabulary map: register status word -> ledger status word.
#    covered  -> implemented
#    partial  -> scope-limited   (or point-fit-recovery, flagged per ledger row)
#    opt-in   -> scope-limited (opt-in)
#    blocked  -> planned         (or rejected, for rows the register text
#                                 itself calls "withdrawn"/deliberately refused)
#    claimed / reserved (parser-syntax vocabulary, in case it leaks in) -> planned
# ---------------------------------------------------------------------------

vocab_one <- function(status) {
  switch(status,
    covered  = "implemented",
    partial  = "scope-limited",
    "opt-in" = "scope-limited (opt-in)",
    blocked  = "planned",
    claimed  = "planned",
    reserved = "planned",
    paste0("unrecognised-status:", status)
  )
}

# Register rows whose own text says the capability is deliberately withdrawn /
# refused by decision, not merely untested. Read directly off the register
# (see dev/gapclose/B-parity-notes.md for the sourcing quotes). These force
# the ledger status to `rejected` regardless of the raw covered/partial/blocked
# word, per the B1 brief's vocabulary rule.
FORCE_REJECTED <- c(
  "CI-06" = "public nonlinear communality profile is withdrawn (FG-13 note: \"nonlinear communality/correlation/proportion profile intervals are withdrawn and blocked\")",
  "CI-07" = "public nonlinear correlation profile is withdrawn (same FG-13 note)",
  "EXT-11" = "extract_proportions() delta-family nonlinear profile is withdrawn (same FG-13 note; distinct from EXT-34's covered boundary contract)",
  "VA-08"  = "`integration = \"eva\"` is not an admitted value -- \"the EVA engine and template remain research-only\", a considered refusal, not a pending gap"
)

status_for_ids <- function(ids, point_fit_recovery = FALSE) {
  if (length(ids) == 0) return(list(status = "implemented", basis = "baseline (no dedicated register row; see note)"))
  missing_ids <- setdiff(ids, names(reg_status))
  if (length(missing_ids) > 0) {
    stop("REGISTER_MAP references register id(s) not found in the register: ",
         paste(missing_ids, collapse = ", "))
  }
  raw <- reg_status[ids]
  forced <- ids[ids %in% names(FORCE_REJECTED)]
  # Force to `rejected` only when EVERY id backing this ledger row is a
  # withdrawn/refused-by-decision row -- a row backed by several register ids
  # where only some are force-rejected keeps its normal aggregated status
  # (the withdrawal is still surfaced via the FORCE_REJECTED note in render()).
  if (length(forced) > 0 && length(forced) == length(ids)) {
    mapped <- "rejected"
  } else {
    words <- unique(vapply(raw, vocab_one, character(1)))
    if (length(words) == 1 && words == "implemented") {
      mapped <- "implemented"
    } else if (all(words %in% c("implemented", "scope-limited", "scope-limited (opt-in)"))) {
      mapped <- if (point_fit_recovery) "point-fit-recovery" else "scope-limited"
    } else if (all(words == "planned")) {
      mapped <- "planned"
    } else {
      # mixed planned + scope-limited/implemented -> report the stronger
      # (more work exists) reading, i.e. scope-limited, and let the Note
      # column carry the detail.
      mapped <- if (point_fit_recovery) "point-fit-recovery" else "scope-limited"
    }
  }
  basis <- paste0(ids, " (`", raw, "`)", collapse = "; ")
  list(status = mapped, basis = basis)
}

# ---------------------------------------------------------------------------
# 3. REGISTER_MAP: the hand-curated ledger. Each entry is one ledger row.
#    Group names mirror the Julia file's groupings per the B1 brief:
#    Response families; Covariance grid source x mode; Grouping levels;
#    Estimators; Intervals; Post-fit and extractors; Diagnostics;
#    Missing data; Integrated SDM; Bridge.
# ---------------------------------------------------------------------------

ROW <- function(name, group, ids, aliases = character(0), note = "",
                 point_fit_recovery = FALSE) {
  list(name = name, group = group, ids = ids, aliases = aliases, note = note,
       point_fit_recovery = point_fit_recovery)
}

REGISTER_MAP <- list(

  # --- Response families -----------------------------------------------
  ROW("gaussian", "Response families", c("FAM-01", "CRAN07-AA-01", "CRAN07-AA-02")),
  ROW("binomial", "Response families", c("FAM-02", "FAM-03", "FAM-04", "CRAN07-AA-06"),
      note = "Julia keeps one combined `binomial` row across links; R's register splits logit/probit/cloglog into FAM-02/03/04."),
  ROW("betabinomial", "Response families", "FAM-05"),
  ROW("poisson", "Response families", c("FAM-06", "CRAN07-AA-04")),
  ROW("nbinom1", "Response families", "FAM-07"),
  ROW("nbinom2", "Response families", c("FAM-08", "CRAN07-AA-05", "CRAN07-AA-05B")),
  ROW("Gamma", "Response families", "FAM-09"),
  ROW("beta", "Response families", "FAM-10"),
  ROW("lognormal", "Response families", "FAM-11"),
  ROW("student", "Response families", "FAM-12",
      note = "COLLISION (divergence, not a false join): both packages call this family `student`, but gllvmTMB's `student()` ESTIMATES the degrees-of-freedom `nu` per trait (`R/families.R`, `log_df_student` in gllvmTMB.cpp) while GLLVM.jl's Student-t parity is paid only at a FIXED nu on both sides -- see the parity tool's NOTED_DIVERGENCES table."),
  ROW("tweedie", "Response families", "FAM-13"),
  ROW("ordinal_probit", "Response families", "FAM-14",
      note = "COLLISION guard: this is the probit-link ordinal cumulative model only. Julia's row is the COMBINED `ordinal_probit / cumulative_logit`. The logit half (Julia's `Ordinal`) is NO LONGER a port gap as of Arc O4 -- see the `ordinal_logit` row below, FAM-24."),
  # B3-issues.md #2 (this gap; Arc O4, 2026-09-03): R previously shipped
  # ordinal_probit() only, with cumulative_logit() reserved for the
  # UNRELATED missing-predictor family, so the cumulative-LOGIT response
  # family needed a distinct name. `ordinal_logit()` is that name.
  # `Ordinal` is GLLVM.jl's own short spelling for this capability
  # (dev/gapclose/B3-issues.md:19-21, `src/families/ordinal.jl`).
  ROW("ordinal_logit", "Response families", "FAM-24",
      aliases = "Ordinal",
      note = "Closes the B3-issues.md #2 gap: the cumulative-logit ordinal response family, distinct from R's cumulative_logit() (a missing-PREDICTOR family; COLLISION guard on that row below). Link swap on ordinal_probit's (FAM-14) apparatus -- same cutpoint machinery, standard logistic CDF in place of the normal CDF; sigma_d^2 = pi^2/3 exact vs. FAM-14's exact 1."),
  ROW("truncated_poisson", "Response families", "FAM-15"),
  ROW("truncated_nbinom2", "Response families", "FAM-15"),
  ROW("truncated_nbinom1", "Response families", "FAM-16"),
  # censored_poisson MOVED here from the FAM-16 note (Arc E, issue #1244,
  # 2026-09-03) -- it now has a runtime id and matches Julia's
  # `censored_poisson` row (GLLVM.jl's ledger, "Response families" table)
  # by exact name. Right-censoring only (Julia's own v1 scope too).
  # RENUMBERED 2026-09-03: was FAM-24 / runtime id 20 until the sibling
  # ordinal_logit branch (PR #1250, merges first) was found to
  # independently claim both -- now FAM-25 / runtime id 21.
  ROW("censored_poisson", "Response families", "FAM-25"),
  ROW("delta_gamma", "Response families", "FAM-17"),
  ROW("delta_lognormal", "Response families", "FAM-17"),
  # GLLVM.jl's ledger combines all three into ONE row named exactly
  # "zip / zinb / zib" (its "## Response families" table); parity_ledger.R
  # joins by exact normalized name/alias match, so this stays ONE ledger
  # row (not three separate ones per FAM id) with that exact alias, or the
  # join silently falls through to "R-only" instead of "matched". FAM-21/
  # 22/23 are the three underlying register rows (Arc D, 2026-09-02).
  ROW("zi_poisson / zi_nbinom2 / zi_binomial (zero-inflated count families)",
      "Response families", c("FAM-21", "FAM-22", "FAM-23"),
      aliases = "zip / zinb / zib",
      note = "DIVERGENCE: gllvmTMB's zi_nbinom2 REUSES the ordinary per-trait nbinom2() dispersion (log_phi_nbinom2, one value per trait); GLLVM.jl's ZINB/ZINegBin uses ONE SHARED SCALAR NB2 dispersion r across all species (its ZINBCovFit docstring). Both `implemented`-shaped statuses describe different parameterisations, same as the `student` nu divergence above."),
  ROW("multinomial / categorical (response family)", "Response families",
      c("FAM-20", "FAM-20A", "FAM-20B", "FAM-20C", "FAM-20D", "FAM-20E", "FAM-20F"),
      aliases = "multinomial / categorical",
      note = "COLLISION guard: this is gllvmTMB's RESPONSE family `multinomial()`. Do not confuse with the unrelated `categorical` register row MIS-31, which is a missing-PREDICTOR imputation family (see the Missing data group)."),
  ROW("Mixed-family response vector", "Response families",
      c("MIX-01", "MIX-02", "MIX-03", "MIX-04", "MIX-05", "MIX-06", "MIX-07",
        "MIX-08", "MIX-09", "MIX-10")),

  # --- Covariance grid: source x mode, plus the modifier-driven slope/lv rows --
  ROW("none × indep (`indep()` / ordinary independent RE)", "Covariance grid source × mode",
      c("FG-05", "FG-07", "FG-09"),
      note = "FG-05 (`unique()` standalone) and FG-09 (`scalar()` modifier) are soft-deprecated modifier spellings of this same indep cell, per CLAUDE.md's modifier doctrine -- not separate modes."),
  ROW("none × dep (`dep()` / unstructured trait covariance)", "Covariance grid source × mode", "FG-08"),
  ROW("none × latent (`latent()` / ordinary LV GLLVM)", "Covariance grid source × mode",
      c("FG-04", "FG-06", "CRAN07-AA-03", "RE-12")),
  ROW("phylogenetic × indep (`phylo_indep()`)", "Covariance grid source × mode",
      c("FG-12", "PHY-04", "PHY-05", "PHY-11", "PHY-12", "PHY-13", "PHY-14",
        "PHY-15", "PHY-16", "RE-14", "STR-RHO-FIX", "STR-RHO-EST", "STR-RHO-WORKFLOW")),
  ROW("phylogenetic × dep (`phylo_dep()`)", "Covariance grid source × mode",
      c("PHY-05", "PHY-18")),
  ROW("phylogenetic × latent (`phylo_latent()`)", "Covariance grid source × mode",
      c("PHY-01", "PHY-02", "PHY-03", "PHY-09", "PHY-10", "PHY-17")),
  ROW("animal × indep (`animal_indep()`)", "Covariance grid source × mode",
      c("ANI-03", "ANI-11", "STR-RHO-FIX", "STR-RHO-EST", "STR-RHO-WORKFLOW")),
  ROW("animal × dep (`animal_dep()`)", "Covariance grid source × mode",
      c("ANI-04", "ANI-12")),
  ROW("animal × latent (`animal_latent()`)", "Covariance grid source × mode",
      c("ANI-01", "ANI-02", "ANI-05", "ANI-09", "ANI-10")),
  ROW("spatial × indep (`spatial_indep()`)", "Covariance grid source × mode",
      c("FG-13", "SPA-03", "SPA-04", "SPA-05", "SPA-06", "SPA-07",
        "STR-RHO-FIX", "STR-RHO-EST", "STR-RHO-WORKFLOW", "STR-RHO-SPA")),
  ROW("spatial × dep (`spatial_dep()`)", "Covariance grid source × mode",
      c("SPA-04", "SPA-10", "STR-RHO-SPA")),
  ROW("spatial × latent (`spatial_latent()`)", "Covariance grid source × mode",
      c("SPA-02", "SPA-09", "STR-RHO-SPA")),
  ROW("kernel × indep (`kernel_indep()`)", "Covariance grid source × mode",
      c("KER-02", "STR-RHO-FIX", "STR-RHO-EST", "STR-RHO-WORKFLOW")),
  ROW("kernel × dep (`kernel_dep()`)", "Covariance grid source × mode", "KER-02"),
  ROW("kernel × latent (`kernel_latent()`)", "Covariance grid source × mode",
      c("KER-02", "KER-03")),
  ROW("phylo_latent + `lv = ~ x` (Phylo Model A public intervals)", "Covariance grid source × mode",
      "LV-08"),
  ROW("Latent scores on covariates `latent(..., lv = ~ x)` ordinary", "Covariance grid source × mode",
      c("FG-18", "RE-13", "LV-01", "LV-02", "LV-03", "LV-04", "LV-05", "LV-06",
        "LV-07", "LV-09", "JUL-01A", "EXT-31")),
  ROW("Response-column slope family (`slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, `spatial_slope()`)",
      "Covariance grid source × mode",
      c("FG-19", "FG-15", "PHY-06", "ANI-06", "SPA-11", "KER-04"),
      aliases = "Response-column slope family (`slope()`, `phylo_slope()`, `animal_slope()`, `kernel_slope()`, `spatial_slope()`; Gaussian long-format, predictor-only)"),
  ROW("Internal IID column coefficients (`column_coef()`)", "Covariance grid source × mode",
      "FG-20", aliases = "Internal IID column coefficients (#1216)"),
  ROW("Column-slope covariance helpers incl. diagonal phylogenetic column slopes", "Covariance grid source × mode",
      "FG-20", aliases = "Column-slope covariance helpers incl. diagonal phylogenetic column slopes (#1196)"),
  ROW("Fixed-effect covariates `X` (shared site design)", "Covariance grid source × mode",
      c("FG-02", "MIX-01", "MIX-02", "MIS-34")),

  # --- Grouping levels (required: unit / unit_obs / cluster / cluster2) ----
  ROW("grouping level × unit", "Grouping levels",
      c("MIS-01", "MIS-02", "MIS-11", "RE-01", "RE-02", "RE-03", "RE-10", "FG-01", "FG-03")),
  ROW("grouping level × unit_obs", "Grouping levels",
      c("FG-10", "RE-04", "RE-06", "RE-07", "RE-09")),
  ROW("grouping level × cluster", "Grouping levels", "RE-08"),
  ROW("grouping level × cluster2", "Grouping levels", c("RE-05", "RE-11", "FG-11")),

  # --- Estimators ---------------------------------------------------------
  ROW("ML default (Gaussian closed-form / non-Gaussian Laplace)", "Estimators", "MIS-13"),
  ROW("REML (Gaussian pilot twin)", "Estimators", "MIS-33"),
  ROW("AGHQ estimator", "Estimators", c("MIS-35", "MIS-36"),
      note = "COLLISION (divergence, not a false join): gllvmTMB's `aghq` is a public opt-in knob (`gllvmTMBcontrol(aghq = FALSE | k | \"auto\")`); GLLVM.jl's own AGHQ-shaped kernel code (src/families/aghq_grid.jl) is internal-only and unreceipted as a public capability -- both `missing` on Julia's ledger. See the parity tool's NOTED_DIVERGENCES table for \"AGHQ shape\"."),
  ROW("VA / ELBO alternative (selected families; not R-default)", "Estimators",
      c("VA-01", "VA-02", "VA-03", "VA-04", "VA-05", "VA-06", "VA-07", "VA-08",
        "VA-09", "VA-10", "VA-11", "VA-12", "VA-13")),
  ROW("MSPL point/interval estimator (`estimator = \"mspl\"`)", "Estimators",
      c("MSPL-01", "MSPL-02", "MSPL-03", "MSPL-04", "MSPL-05"),
      note = "R-only estimator; GLLVM.jl's ledger has no MSPL row (expected to appear R-only in the parity report)."),

  # --- Intervals -----------------------------------------------------------
  ROW("Point extraction (coef / loadings / Σ_y / correlations)", "Intervals",
      c("EXT-01", "EXT-02", "EXT-03", "EXT-14", "EXT-16", "EXT-17", "EXT-18")),
  ROW("Wald intervals", "Intervals", c("CI-01", "CI-09")),
  ROW("Profile-likelihood intervals", "Intervals", c("CI-02", "CI-05", "CI-11", "CI-12")),
  ROW("Parametric bootstrap intervals", "Intervals",
      c("CI-03", "EXT-13", "EXT-20", "EXT-21", "EXT-22", "EXT-23", "EXT-24")),
  ROW("Simulation-validated coverage certificate (broad grid)", "Intervals", "CI-08"),
  ROW("Mixed-family intervals", "Intervals", "CI-10"),
  ROW("extract_correlations() methods (point / Fisher-z / Wald / bootstrap / profile)", "Intervals", "EXT-04"),
  ROW("`slope_sd_ci()` Wald log-scale augmented-slope intervals", "Intervals", "CI-14"),
  ROW("Marginal slope-SD intervals (phylo Cholesky / loadings-only augmented slope)", "Intervals", "CI-15"),
  ROW("Canonical repeatability profile", "Intervals", "CI-04"),
  ROW("Nonlinear communality profile", "Intervals", "CI-06"),
  ROW("Nonlinear correlation profile", "Intervals", "CI-07"),
  ROW("extract_proportions() delta-family nonlinear profile", "Intervals", "EXT-11"),
  ROW("extract_proportions() zero-denominator boundary / wide-format contract", "Intervals", "EXT-34"),
  ROW("Standardized-loading joint-delta inference and scale-labelled decision routes", "Intervals", "CI-13"),

  # --- Post-fit and extractors ----------------------------------------------
  ROW("Post-fit summary, comparison, and plotting extractor surface", "Post-fit and extractors",
      c("EXT-05", "EXT-06", "EXT-07", "EXT-08", "EXT-09", "EXT-10", "EXT-12",
        "EXT-15", "EXT-19", "EXT-25", "EXT-26", "EXT-27", "EXT-28", "EXT-29",
        "EXT-30", "EXT-32", "EXT-33", "EXT-35", "EXT-36", "EXT-37", "EXT-38",
        "PHY-07", "PHY-08", "ANI-07", "ANI-08", "SPA-08",
        "LAM-01", "LAM-02", "LAM-03", "LAM-04")),
  # Arc O5 (2026-09-03, issue #1242): latent-rank selection and boundary
  # likelihood-ratio inference. Julia twin: `select_lv()` <-> GLLVM.jl
  # `src/model_selection.jl`'s `select_lv()`; `chibar2_pvalue()`/
  # `variance_lrt()` <-> `src/boundary_inference.jl`'s functions of the same
  # name. One combined ledger row (mirrors the zi_* FAM-21/22/23 precedent
  # above), since the two register rows are one arc's evidence.
  ROW("select_lv() rank selection + anova() boundary likelihood-ratio test",
      "Post-fit and extractors", c("MS-01", "MS-02"),
      aliases = "select_lv / chibar2_pvalue / variance_lrt"),

  # --- Diagnostics -----------------------------------------------------------
  ROW("Diagnostics and fit-health surface", "Diagnostics",
      c("DIA-01", "DIA-02", "DIA-03", "DIA-04", "DIA-05", "DIA-06", "DIA-07",
        "DIA-08", "DIA-09", "DIA-10", "DIA-11", "DIA-12", "DIA-13", "DIA-14",
        "CRAN07-AA-07")),

  # --- Missing data ----------------------------------------------------------
  ROW("Missing responses (NA / mask)", "Missing data",
      c("MIS-21", "MIS-22", "MIS-24", "VA-03", "VA-10")),
  ROW("Missing predictor `mi()`", "Missing data",
      c("MIS-23", "MIS-25", "MIS-26", "MIS-27", "MIS-28", "MIS-29", "MIS-32", "MIS-37")),
  ROW("cumulative_logit (missing-predictor family)", "Missing data", "MIS-30",
      note = "COLLISION guard: this is R's ORDERED missing-PREDICTOR imputation family inside `mi()`/`miss_control()`. Julia's `cumulative_logit` name refers to the unrelated ordinal RESPONSE family (see the `ordinal_probit` row above) -- must not join to it."),
  ROW("categorical (missing-predictor family)", "Missing data", "MIS-31",
      note = "COLLISION guard: this is R's UNORDERED missing-PREDICTOR imputation family inside `mi()`/`miss_control()`. R's response-side unordered family is `multinomial()` (see `multinomial / categorical (response family)` above), not this row."),

  # --- Integrated SDM ----------------------------------------------------------
  ROW("Integrated two-source model admitted through public `gllvmTMB()`", "Integrated SDM", "ISDM-01",
      point_fit_recovery = TRUE),
  ROW("Multi-source integrated model (`isdm_sources()`, n_sources >= 2)", "Integrated SDM", "ISDM-02",
      point_fit_recovery = TRUE),
  ROW("`predict()` on integrated (`isdm_sources()` / two-source) fits", "Integrated SDM", "ISDM-03",
      point_fit_recovery = TRUE),
  ROW("Internal paired baseline-vs-rep3 response-information study", "Integrated SDM", "ISDM-RESP-INFO",
      note = "Internal-only investigation; not a public capability. R-only, no Julia twin expected."),

  # --- Bridge (engine = "julia") ----------------------------------------------
  ROW("Julia bridge unit-tier covariance and ordination accessors", "Bridge", "JUL-01A"),
  ROW("Lean `engine = \"julia\"` reduced-rank bridge (`GLLVM.bridge_fit`)", "Bridge", "JUL-01")
)

names(REGISTER_MAP) <- vapply(REGISTER_MAP, `[[`, character(1), "name")

# ---------------------------------------------------------------------------
# 4. Register rows that are deliberately NOT mapped to any ledger row, with a
#    written reason -- mirrors DRM.jl's parity_ledger.py precedent
#    (NOT_CAPABILITY / DELIBERATELY_NOT_PORTED).
# ---------------------------------------------------------------------------

UNMAPPED_BY_DESIGN <- c(
  "SPA-01" = "R-side SPDE mesh construction (make_mesh()); pre-fit geospatial prep, no Julia twin capability (cf. drmTMB's identical make_mesh precedent)",
  "KER-01" = "R-only cross-lineage coevolution kernel builder (make_cross_kernel()); GLLVM.jl's ledger tracks no coevolution row to compare against",
  "COE-01" = "R-only cross-lineage coevolution capability; no Julia twin row",
  "COE-02" = "R-only cross-lineage coevolution capability; no Julia twin row",
  "COE-03" = "R-only cross-lineage coevolution capability; no Julia twin row",
  "COE-04" = "R-only cross-lineage coevolution capability; no Julia twin row",
  "MET-01" = "R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin",
  "MET-02" = "R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin",
  "MET-03" = "R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin",
  "MET-04" = "R-only meta-analytic known-sampling-covariance keyword family (meta_V/block_V); no Julia twin",
  "FG-14"  = "meta_V() parser row; folds into the MET-* meta-analysis rows above, all R-only",
  "FG-17"  = "Deliberately rejected parser grammar (slash-form nesting `(1 | g1/g2)`); no Julia grammar-rejection concept to compare against",
  "FG-16"  = "R-only legacy `gllvmTMB_wide()` matrix constructor, soft-deprecated; no Julia twin",
  "MIS-03" = "R-only legacy `gllvmTMB_wide()` matrix constructor, soft-deprecated; duplicate of FG-16",
  "MIS-06" = "R S3-method ergonomics (tidy.gllvmTMB_multi()); Julia's ledger does not track print/tidy/plot as capability rows",
  "MIS-07" = "R S3-method ergonomics (predict.gllvmTMB_multi()); folded operationally into extractor/bridge rows elsewhere, not a distinct ledger row",
  "MIS-08" = "R S3-method ergonomics (print.gllvmTMB_multi()); Julia's ledger does not track this",
  "MIS-09" = "R S3-method ergonomics (plot.gllvmTMB_multi() dispatcher); Julia's ledger does not track this",
  "MIS-10" = "R-only brms-style formula sugar; a syntax convenience, not a modelling capability",
  "MIS-12" = "R-only gllvmTMBcontrol() control-object infrastructure; no Julia twin",
  "MIS-14" = "R-only argument-validation infrastructure (gllvmTMB-args.R); no Julia twin",
  "MIS-15" = "R-only profile_targets() controlled vocabulary; internal plumbing, not a capability",
  "MIS-16" = "R-side optimizer starting-value engineering (init_strategy); internal robustness measure, no Julia-comparable capability",
  "MIS-17" = "R-side optimizer starting-value engineering (phi clamp); internal robustness measure",
  "MIS-18" = "R-side optimizer starting-value engineering (start_method = res); internal robustness measure",
  "MIS-19" = "R-side optimizer starting-value engineering (start_method = indep / start_from); internal robustness measure",
  "MIS-20" = "R-side optimizer starting-value engineering (restart_history/start_provenance); internal robustness measure",
  "FAM-18" = "R-only aspirational mixture families (gamma_mix/lognormal_mix/nbinom2_mix), blocked on the R side too; no Julia twin to compare against",
  "FAM-19" = "R-only aspirational generalized-gamma family (gengamma), blocked on the R side too; no Julia twin",
  "MIS-04" = "R-only unified weight-column handling; internal plumbing, no distinct Julia-comparable capability",
  "MIS-05" = "R S3-method ergonomics (simulate.gllvmTMB_multi()); Julia's ledger does not track simulate() as a capability row",
  "MIS-38" = "API hygiene only (#1190 unused unit_obs/cluster warning) -- Julia's own ledger explicitly lists this under 'Not capability (API hygiene in 0.7.1, nothing to mirror): unused grouping-slot warnings (#1190)', so it is deliberately excluded on both sides"
)

# ---------------------------------------------------------------------------
# 5. Completeness check: every register id must be in REGISTER_MAP or
#    UNMAPPED_BY_DESIGN.
# ---------------------------------------------------------------------------

mapped_ids <- unique(unlist(lapply(REGISTER_MAP, `[[`, "ids")))
unmapped_ids <- names(UNMAPPED_BY_DESIGN)

all_accounted <- union(mapped_ids, unmapped_ids)
missing_from_map <- setdiff(reg$id, all_accounted)
stale_in_map <- setdiff(all_accounted, reg$id)  # ids referenced but not in register (typo guard)

if (length(stale_in_map) > 0) {
  stop("REGISTER_MAP / UNMAPPED_BY_DESIGN reference register id(s) that no ",
       "longer exist in the register (typo or the register was edited): ",
       paste(stale_in_map, collapse = ", "))
}

# ---------------------------------------------------------------------------
# 6. Render the ledger markdown.
# ---------------------------------------------------------------------------

GROUP_ORDER <- c(
  "Response families", "Covariance grid source × mode", "Grouping levels",
  "Estimators", "Intervals", "Post-fit and extractors", "Diagnostics",
  "Missing data", "Integrated SDM", "Bridge"
)

render <- function() {
  out <- character(0)
  add <- function(...) out <<- c(out, paste0(...))

  add("# gllvmTMB capability status (R twin of GLLVM.jl)")
  add("")
  add("GENERATED FILE -- edit `dev/gapclose/build-capability-status.R`, not this",
      " file directly. Regenerate with `Rscript dev/gapclose/build-capability-status.R`.")
  add("")
  add("Mission Control input for the R side of the gllvmTMB <-> GLLVM.jl twin",
      " board. Every row here is machine-derived from",
      " `docs/design/35-validation-debt-register.md`, the honest validation-debt",
      " ledger -- this file adds no new claims, it only translates that ledger's",
      " vocabulary into the shared R<->Julia status vocabulary GLLVM.jl's own",
      " `docs/design/capability-status.md` uses, so the two can be joined by",
      " `tools/parity_ledger.R`.")
  add("")
  add("**Provenance.** Source: `docs/design/35-validation-debt-register.md` at the",
      " commit this file was generated against. Row names are copied",
      " byte-for-byte from GLLVM.jl's ledger wherever the concept is genuinely",
      " shared (both ledgers already describe those cells in R's own",
      " vocabulary). Where the R-canonical name differs from GLLVM.jl's spelling",
      " of the same concept, the `Aliases` column carries GLLVM.jl's exact",
      " string so `tools/parity_ledger.R` still joins them.")
  add("")
  add("**Vocabulary (translated from the register's `covered / partial / opt-in /",
      " blocked` 4-state vocabulary, `docs/design/35-validation-debt-register.md`",
      " Vocabulary section):**")
  add("")
  add("- `implemented` -- register status `covered`: a test file with concrete",
      " assertions at the depth advertised.")
  add("- `scope-limited` -- register status `partial` or `opt-in`: tests exist but",
      " coverage is shallower than advertised, or the capability needs a",
      " non-default argument. `scope-limited (opt-in)` marks the opt-in case.")
  add("- `point-fit-recovery` -- a `scope-limited` row whose register text",
      " specifically scopes the evidence to point estimation / recovery, with",
      " no interval or calibration claim (used for the ISDM rows).")
  add("- `planned` -- register status `blocked` (or the parser-syntax `claimed`",
      " / `reserved` values, if either leaks into a mapped row): advertised but",
      " currently broken, undefined, or not yet built.")
  add("- `rejected` -- register status `blocked`, where the register's OWN text",
      " says the capability is withdrawn or deliberately refused by decision",
      " (not merely untested). See `FORCE_REJECTED` in the generator script for",
      " the exact quotes.")
  add("")
  add("**Known name collisions** (same token, different meaning on each side --",
      " see the row-level notes below and `tools/parity_ledger.R`'s",
      " `--check-names` mode, which asserts these never join to the wrong Julia",
      " row): `cumulative_logit`, `categorical`, `ordinal_probit` (vs Julia's",
      " combined `ordinal_probit / cumulative_logit`), `student` (nu fixed vs",
      " estimated), `aghq` (public knob vs internal kernel), `unique` (the Psi",
      " companion modifier; the bridge drops it entirely).")
  add("")

  n_rows <- 0L
  for (g in GROUP_ORDER) {
    rows <- Filter(function(r) r$group == g, REGISTER_MAP)
    if (length(rows) == 0) next
    add("## ", g)
    add("")
    add("| Capability | Status | Aliases | Register rows | Note |")
    add("|---|---|---|---|---|")
    for (r in rows) {
      n_rows <- n_rows + 1L
      st <- status_for_ids(r$ids, point_fit_recovery = r$point_fit_recovery)
      alias_txt <- if (length(r$aliases)) paste(r$aliases, collapse = "; ") else ""
      ids_txt <- if (length(r$ids)) paste(r$ids, collapse = ", ") else "(baseline)"
      note_txt <- r$note
      if (any(r$ids %in% names(FORCE_REJECTED))) {
        reasons <- FORCE_REJECTED[intersect(r$ids, names(FORCE_REJECTED))]
        note_txt <- paste0(note_txt, if (nzchar(note_txt)) " " else "",
                            "Withdrawn: ", paste(reasons, collapse = "; "), ".")
      }
      add("| ", r$name, " | ", st$status, " | ", alias_txt, " | ", ids_txt, " | ", note_txt, " |")
    }
    add("")
  }

  add("## Unmapped-by-design register rows")
  add("")
  add("Register rows deliberately NOT translated into a ledger capability row",
      " above, with a written reason each (mirrors DRM.jl's",
      " `tools/parity_ledger.py` `NOT_CAPABILITY` / `DELIBERATELY_NOT_PORTED`",
      " precedent). Every register row is accounted for either in a table above",
      " or here -- `--check` fails if a new register row is neither.")
  add("")
  add("| Register row | Reason |")
  add("|---|---|")
  for (id in sort(names(UNMAPPED_BY_DESIGN))) {
    add("| ", id, " | ", UNMAPPED_BY_DESIGN[[id]], " |")
  }
  add("")

  attr(out, "n_rows") <- n_rows
  out
}

rendered <- render()
n_rows <- attr(rendered, "n_rows")

# ---------------------------------------------------------------------------
# 7. --check vs write.
# ---------------------------------------------------------------------------

if (length(missing_from_map) > 0) {
  msg <- paste0(
    "capability-status.md generator: ", length(missing_from_map),
    " register row(s) are unmapped -- add them to REGISTER_MAP or ",
    "UNMAPPED_BY_DESIGN in dev/gapclose/build-capability-status.R:\n  ",
    paste(missing_from_map, collapse = ", ")
  )
  message(msg)
  if (CHECK_MODE) quit(status = 1L, save = "no")
}

if (CHECK_MODE) {
  if (!file.exists(OUTPUT_PATH)) {
    message("capability-status.md does not exist yet -- run without --check to create it")
    quit(status = 1L, save = "no")
  }
  committed <- readLines(OUTPUT_PATH, warn = FALSE)
  fresh <- as.character(rendered)  # strip the n_rows attribute before comparing
  if (identical(committed, fresh)) {
    if (length(missing_from_map) == 0) {
      message(sprintf("capability-status.md up to date; %d rows; 0 unmapped register rows",
                       n_rows))
      quit(status = 0L, save = "no")
    } else {
      quit(status = 1L, save = "no")  # already messaged above
    }
  } else {
    tmp <- tempfile(fileext = ".md")
    writeLines(fresh, tmp)
    message("capability-status.md is STALE -- diff (committed vs regenerated):")
    diff_out <- tryCatch(
      system2("diff", c("-u", shQuote(OUTPUT_PATH), shQuote(tmp)), stdout = TRUE, stderr = TRUE),
      error = function(e) character(0)
    )
    if (length(diff_out)) message(paste(diff_out, collapse = "\n"))
    quit(status = 1L, save = "no")
  }
} else {
  writeLines(rendered, OUTPUT_PATH)
  message(sprintf("wrote %s; %d rows; %d register rows mapped; %d unmapped-by-design; %d unmapped (should be 0)",
                   OUTPUT_PATH, n_rows, length(mapped_ids), length(unmapped_ids), length(missing_from_map)))
}
