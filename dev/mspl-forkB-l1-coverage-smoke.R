## ---------------------------------------------------------------------------
## L1 LOCAL COVERAGE SMOKE -- MSPL profile fork B (Design 125, ADEMP P5 gate L1)
##
## Pre-registration: docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md
## Design:           docs/design/125-mspl-profile-led-intervals.md
##
## L1 (FROZEN, G4d): on >= 1 anchor cell with n_rep in [50, 100],
##   * cov_eff Wilson band NOT entirely below 0.80,
##   * availability >= 0.90,
##   * refusal <= 0.15,
## with refusals priced INTO the coverage denominator (ADEMP P1 SIGNED default).
##
## WHAT THIS SCRIPT IS NOT
##   * Not Totoro / DRAC. Local compute only (D-50). It has no cluster path.
##   * Not a T* freeze. T* numbers are still open and this script must not
##     invent them; it evaluates L* only.
##   * Not an undraft of #1077, not public `confint` / `vcov` / `se = TRUE`,
##     not an MSPL-04 flip, not a `calibrated = TRUE` anywhere.
##   * Not fork A. It refuses to run against the penalised-tape probe
##     `.gllvmTMB_mspl_profile_feasibility()`, which is fork A by construction
##     (see its header) -- see `l1_resolve_forkB_door()` below.
##   * Not the fork-B door itself. The door is L0's deliverable and belongs to
##     the sibling lane `cursor/mspl-forkB-l0-20260818`. This script CONSUMES
##     it and will report NOT-RUN until it lands.
##
## Usage:
##   OMP_NUM_THREADS=1 NOT_CRAN=true Rscript --vanilla \
##     dev/mspl-forkB-l1-coverage-smoke.R [--n-rep=50] [--cells=anchor]
##     [--estimands=E1,E2] [--budget-min=90] [--dry-run]
##
##   --dry-run  resolve the door, build one fixture per cell, fit ONE point fit
##              per cell for timing, and stop. Produces no coverage number.
##
## Env overrides:
##   GLLVMTMB_L1_FORKB_DOOR  "name" or "pkg:::name" of the fork-B door to use,
##                           for when L0 lands under a name not guessed here.
##
## Outputs:
##   docs/dev-log/research/2026-08-18-mspl-forkB-l1-coverage-smoke.tsv
##   /tmp/mspl-forkB-l1-coverage-smoke.rds
## ---------------------------------------------------------------------------

Sys.setenv(OMP_NUM_THREADS = "1", NOT_CRAN = "true")
options(warn = 1)

ROOT <- Sys.getenv("GLLVMTMB_ROOT", unset = normalizePath("."))
source(file.path(ROOT, "dev", "mspl-forkB-l1-lib.R"))

OUT_TSV <- file.path(
  ROOT, "docs/dev-log/research/2026-08-18-mspl-forkB-l1-coverage-smoke.tsv"
)
OUT_RDS <- "/tmp/mspl-forkB-l1-coverage-smoke.rds"

## ---- arguments -------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) {
  hit <- grep(paste0("^--", flag, "="), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", flag, "="), "", hit[[1L]])
}
N_REP <- as.integer(arg_value("n-rep", "50"))
CELL_NAMES <- strsplit(arg_value("cells", "anchor"), ",")[[1L]]
ESTIMANDS <- strsplit(arg_value("estimands", "E1,E2"), ",")[[1L]]
BUDGET_S <- as.numeric(arg_value("budget-min", "90")) * 60
DRY_RUN <- "--dry-run" %in% args

if (N_REP < L1_GATE$n_rep_min || N_REP > L1_GATE$n_rep_max) {
  ## The pre-registration fixes n_rep in [50, 100] for L1. A smaller run is
  ## allowed for plumbing but must not be reported as an L1 verdict, so it is
  ## marked here and carried into the verdict block.
  message(sprintf(
    "NOTE: n_rep = %d is outside the pre-registered L1 range [%d, %d]; this run is PLUMBING ONLY and cannot produce an L1 verdict.",
    N_REP, L1_GATE$n_rep_min, L1_GATE$n_rep_max
  ))
}
N_REP_IN_PREREG <- N_REP >= L1_GATE$n_rep_min && N_REP <= L1_GATE$n_rep_max

## ---- load package ----------------------------------------------------------
cat("== load_all ==\n")
suppressMessages(pkgload::load_all(ROOT, compile = FALSE, quiet = TRUE))
cat("gllvmTMB:", as.character(utils::packageVersion("gllvmTMB")),
    "| ROOT:", ROOT, "\n")

## ---- fork-B door resolution ------------------------------------------------
##
## Fork B (ADEMP M, Design 125 s3.3) profiles the UNPENALIZED Laplace objective
## (`fit$mspl$unpenalized_tmb_obj`, estimator_id 2) with the nuisance handled at
## the MSPL point -- as opposed to fork A, which profiles the penalised tape
## (estimator_id 1).
##
## Two things this resolver must never do:
##   1. Build the door itself. That is L0's deliverable in a sibling lane, and
##      a harness that quietly implements its own estimator is measuring
##      itself.
##   2. Accept fork A as a stand-in. `.gllvmTMB_mspl_profile_feasibility()`
##      hard-refuses `unpenalized_tmb_obj` and reports
##      `objective_source = "fit$tmb_obj (penalised LA-MSPL)"`, so any door
##      reporting a penalised source is rejected below with a loud message.
l1_resolve_forkB_door <- function() {
  ns <- asNamespace("gllvmTMB")
  get_if <- function(nm) {
    if (exists(nm, envir = ns, inherits = FALSE)) get(nm, envir = ns) else NULL
  }

  override <- Sys.getenv("GLLVMTMB_L1_FORKB_DOOR", unset = "")

  ## Rehearsal escape hatch: exercise the campaign loop with a synthetic door
  ## before L0 lands. A mock run is stamped everywhere and yields NO verdict.
  if (identical(override, "mock")) {
    return(list(available = TRUE, name = "l1_mock_door()", fn = l1_mock_door(),
                mock = TRUE, how = "MOCK REHEARSAL DOOR -- produces no L1 verdict"))
  }
  if (nzchar(override)) {
    nm <- sub("^.*:::", "", override)
    fn <- get_if(nm)
    if (is.null(fn)) {
      return(list(available = FALSE, name = nm, why = sprintf(
        "GLLVMTMB_L1_FORKB_DOOR names %s, which is not in the gllvmTMB namespace",
        override
      )))
    }
    return(list(available = TRUE, name = nm, fn = fn, how = "env override"))
  }

  ## Candidate 1: a dedicated fork-B entry point.
  for (nm in c(
    ".gllvmTMB_mspl_profile_feasibility_forkB",
    ".gllvmTMB_mspl_profile_feasibility_fork_b",
    ".gllvmTMB_mspl_profile_forkB",
    ".gllvmTMB_mspl_profile_unpenalized"
  )) {
    fn <- get_if(nm)
    if (!is.null(fn)) {
      return(list(available = TRUE, name = nm, fn = fn, how = "dedicated fork-B entry point"))
    }
  }

  ## Candidate 2: the existing probe gains a fork / objective selector.
  fn <- get_if(".gllvmTMB_mspl_profile_feasibility")
  if (!is.null(fn)) {
    fml <- names(formals(fn))
    sel <- intersect(c("objective", "fork", "tape"), fml)
    if (length(sel)) {
      return(list(
        available = TRUE, name = ".gllvmTMB_mspl_profile_feasibility",
        fn = fn, selector = sel[[1L]],
        how = sprintf("existing probe with a `%s` selector", sel[[1L]])
      ))
    }
    return(list(available = FALSE, name = ".gllvmTMB_mspl_profile_feasibility", why = paste(
      "the only profile door on this tree is the fork-A penalised probe",
      "(no objective/fork/tape selector). Fork B is L0's deliverable in",
      "`cursor/mspl-forkB-l0-20260818` and has not landed."
    )))
  }

  list(available = FALSE, name = NA_character_, why = "no MSPL profile door in the namespace at all")
}

## Values a fork-B selector might plausibly take, tried in order. `Q_0` is the
## name the landed L0 door uses; the rest are fallbacks kept in case the door
## is renamed. The winning value is pinned on first success (see `.l1_selector`)
## so the campaign does not re-probe on every replicate.
L1_FORKB_SELECTOR_VALUES <- c("Q_0", "unpenalized", "forkB", "fork_b", "B", "q0")
.l1_selector_value <- new.env(parent = emptyenv())
.l1_selector_value$v <- NULL

## Call the door for one coordinate and normalise its answer into the typed
## outcome the pricing arithmetic consumes. Anything unrecognised becomes
## R-DOOR rather than a silently dropped replicate.
l1_call_door <- function(door, fit, which, level = L1_GATE$level) {
  call_it <- function(extra) {
    do.call(door$fn, c(list(fit, which = which, level = level), extra))
  }
  res <- NULL
  if (!is.null(door$selector)) {
    values <- if (!is.null(.l1_selector_value$v)) {
      .l1_selector_value$v
    } else {
      L1_FORKB_SELECTOR_VALUES
    }
    for (v in values) {
      extra <- setNames(list(v), door$selector)
      res <- tryCatch(call_it(extra), error = function(e) e)
      if (!inherits(res, "error")) {
        .l1_selector_value$v <- v
        break
      }
      ## A refusal about the TARGET (not the tape) is a real, typed answer for
      ## this coordinate -- stop probing selector values and report it, or the
      ## loop would mislabel an unsupported estimand as a broken door.
      if (grepl("profile_target|profile_family|profile_input",
                paste(class(res), collapse = " "))) {
        break
      }
    }
  } else {
    res <- tryCatch(call_it(list()), error = function(e) e)
  }

  if (inherits(res, "error")) {
    cls <- class(res)[[1L]]
    code <- if (grepl("profile_target|profile_family|profile_input", paste(class(res), collapse = " "))) {
      "R-ENV"   # the door does not admit this target / family
    } else {
      "R-DOOR"
    }
    return(list(outcome = code, two_sided = FALSE, lower = NA_real_,
                upper = NA_real_, detail = conditionMessage(res),
                objective_source = NA_character_))
  }

  src <- res$objective_source %||% NA_character_
  lo <- suppressWarnings(as.numeric(res$lower_endpoint %||% NA_real_))
  hi <- suppressWarnings(as.numeric(res$upper_endpoint %||% NA_real_))
  two_sided <- isTRUE(is.finite(lo) && is.finite(hi) && hi > lo)
  centre_ok <- identical(res$centre_status %||% NA_character_, "matched")

  ## `calibrated` must never come back TRUE from this lane's plumbing.
  if (isTRUE(res$calibrated)) {
    stop("fork-B door returned calibrated = TRUE; that is not this lane's to claim")
  }

  outcome <- if (two_sided && centre_ok) {
    "returned"
  } else if (!centre_ok) {
    "R-NAVL"    # centre did not reproduce the MLE: the path is not usable
  } else {
    "R-NAVL"    # one-sided or non-finite: one-sided success is NOT availability
  }
  list(outcome = outcome, two_sided = two_sided, lower = lo, upper = hi,
       detail = paste(res$centre_status %||% "", res$lower_status %||% "",
                      res$upper_status %||% "", collapse = "/"),
       objective_source = src,
       fork = res$design_125_fork %||% NA_character_,
       tape = res$tape %||% NA_character_,
       reference_is_maximum = res$reference_is_maximum %||% NA)
}

door <- l1_resolve_forkB_door()
cat("\n== fork-B door ==\n")
if (isTRUE(door$available)) {
  cat("  resolved:", door$name, "(", door$how, ")\n")
} else {
  cat("  NOT AVAILABLE:", door$why, "\n")
}

## ---- fitting ---------------------------------------------------------------
l1_fit <- function(dat, q = 1L) {
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)",
    as.integer(q)
  ))
  suppressMessages(gllvmTMB(
    form, data = dat, family = stats::binomial(link = "logit"),
    estimator = "mspl",
    control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE,
                              warn_runaway = FALSE)
  ))
}

CELLS <- l1_cells()
unknown <- setdiff(CELL_NAMES, names(CELLS))
if (length(unknown)) stop("unknown cell(s): ", paste(unknown, collapse = ", "))

## ---- dry run / timing calibration -----------------------------------------
##
## Runs with or without the door: one fixture and one point fit per cell, so
## the per-replicate budget is a measured number rather than a guess.
cat("\n== fixture + point-fit calibration ==\n")
calib <- list()
for (cn in CELL_NAMES) {
  cell <- CELLS[[cn]]
  fx <- l1_simulate(cell, l1_seeds(1L)[[1L]])
  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(l1_fit(fx$data, cell$q), error = function(e) e)
  el <- proc.time()[["elapsed"]] - t0
  ok <- !inherits(fit, "error")
  sat <- l1_saturated_traits(fx$data)
  cat(sprintf(
    "  %-9s n=%d T=%d prev=%.3f [%.2f, %.2f] sat=%d | fit %s %.2fs conv=%s\n",
    cell$name, cell$n_site, cell$n_trait, fx$prevalence,
    min(fx$trait_prevalence), max(fx$trait_prevalence), length(sat),
    if (ok) "ok" else "ERROR", el,
    if (ok) fit$opt$convergence else NA
  ))
  door_s <- NA_real_
  d1 <- NULL
  if (ok && isTRUE(door$available)) {
    t1 <- proc.time()[["elapsed"]]
    d1 <- l1_call_door(door, fit, which = 1L)
    door_s <- proc.time()[["elapsed"]] - t1
    cat(sprintf("    door(1) %.2fs -> %s [%s] fork=%s tape=%s ref_is_max=%s\n",
                door_s, d1$outcome, d1$detail, d1$fork %||% "NA",
                d1$tape %||% "NA", d1$reference_is_maximum %||% NA))
    cat("      src:", d1$objective_source %||% "NA", "\n")
  }
  calib[[cn]] <- list(fit_s = el, door_s = door_s, ok = ok,
                      prevalence = fx$prevalence, n_saturated = length(sat),
                      objective_source = if (!is.null(d1)) d1$objective_source else NA_character_,
                      fork = if (!is.null(d1)) d1$fork else NA_character_,
                      tape = if (!is.null(d1)) d1$tape else NA_character_,
                      reference_is_maximum = if (!is.null(d1)) d1$reference_is_maximum else NA,
                      n_coord = if (ok) sum(names(fit$opt$par) == "b_fix") else NA_integer_)
}

## Tape verification. Fork B is defined by the UNPENALIZED objective; a door
## that reports a penalised source is fork A wearing fork B's name, and
## measuring it here would put a fork-A number under an L1/fork-B heading.
## Refuse rather than relabel.
forks <- unlist(lapply(calib, `[[`, "fork"))
forks <- forks[!is.na(forks)]
if (length(forks) && !all(forks == "B")) {
  stop(sprintf(
    "resolved door self-reports Design 125 fork %s, not B. Refusing to run under an L1 fork-B heading.",
    paste(unique(forks), collapse = "/")
  ))
}
srcs <- unlist(lapply(calib, `[[`, "objective_source"))
srcs <- srcs[!is.na(srcs)]
if (isTRUE(door$available) && length(srcs)) {
  if (any(grepl("penalised|penalized", srcs, ignore.case = TRUE) &
          !grepl("unpenalised|unpenalized", srcs, ignore.case = TRUE))) {
    stop(sprintf(
      "resolved door reports a PENALISED objective source (%s). That is fork A, not fork B. Refusing to run: a fork-A measurement must not be recorded under an L1 fork-B heading.",
      paste(unique(srcs), collapse = " | ")
    ))
  }
  cat("  tape check: objective_source =", paste(unique(srcs), collapse = " | "), "\n")
} else if (isTRUE(door$available)) {
  cat("  tape check: UNVERIFIED (door reports no objective_source);",
      "any result from this run is PROVISIONAL.\n")
}
TAPE_VERIFIED <- length(srcs) > 0L

if (!isTRUE(door$available)) {
  cat("\n======== VERDICT ========\n")
  cat("L1_STATUS: NOT-RUN\n")
  cat("REASON: the fork-B profile door has not landed;",
      "L0 is a prerequisite of L1 and is owned by a sibling lane.\n")
  cat("L1_GATE: NOT EVALUATED -- no PASS and no FAIL is claimed.\n")
  cat("This harness will run unchanged once the door exists; if L0 names it\n")
  cat("something not guessed by l1_resolve_forkB_door(), set\n")
  cat("GLLVMTMB_L1_FORKB_DOOR=<name> and re-run.\n")
  saveRDS(list(status = "NOT-RUN", door = door[setdiff(names(door), "fn")],
               calibration = calib, gate = L1_GATE, when = Sys.time()), OUT_RDS)
  cat("\nwrote", OUT_RDS, "\n")
  quit(save = "no", status = 0L)
}

if (DRY_RUN) {
  cat("\n--dry-run: stopping after calibration. No coverage measured.\n")
  quit(save = "no", status = 0L)
}

## ---- budget projection -----------------------------------------------------
per_rep <- vapply(CELL_NAMES, function(cn) {
  cc <- calib[[cn]]
  n_targets <- (cc$n_coord %||% 1L) * length(ESTIMANDS)
  (cc$fit_s %||% NA_real_) + n_targets * (cc$door_s %||% NA_real_)
}, numeric(1))
projected <- sum(per_rep * N_REP, na.rm = TRUE)
cat(sprintf("\n== budget: projected %.1f min for %d rep x %d cell(s) (cap %.0f min) ==\n",
            projected / 60, N_REP, length(CELL_NAMES), BUDGET_S / 60))
if (is.finite(projected) && projected > BUDGET_S) {
  stop(sprintf(
    "projected %.1f min exceeds the %.0f min local budget. Reduce --cells or raise --budget-min deliberately; do NOT move this to Totoro (D-50, and no Totoro G0 exists).",
    projected / 60, BUDGET_S / 60
  ))
}

## ---- the campaign ----------------------------------------------------------
rows <- list()
t_all <- proc.time()[["elapsed"]]
for (cn in CELL_NAMES) {
  cell <- CELLS[[cn]]
  seeds <- l1_seeds(N_REP)
  cat(sprintf("\n==== cell %s (%s) : %d replicates ====\n", cell$name, cell$role, N_REP))
  for (i in seq_along(seeds)) {
    fx <- l1_simulate(cell, seeds[[i]])
    sat_traits <- l1_saturated_traits(fx$data)
    fit <- tryCatch(l1_fit(fx$data, cell$q), error = function(e) e)
    fit_failed <- inherits(fit, "error") ||
      !identical(as.integer(fit$opt$convergence), 0L) ||
      !all(is.finite(fit$opt$par))

    par <- if (fit_failed) NULL else fit$opt$par
    idx_beta <- if (is.null(par)) integer(0) else which(names(par) == "b_fix")
    idx_lam <- if (is.null(par)) integer(0) else which(names(par) == "theta_rr_B")
    first_loading <- if (length(idx_lam)) as.numeric(par[idx_lam[[1L]]]) else NA_real_

    for (est in ESTIMANDS) {
      idx <- switch(est, E1 = idx_beta, E2 = idx_lam, integer(0))
      truth <- switch(est, E1 = fx$beta, E2 = fx$Lambda, numeric(0))
      n_coord <- if (fit_failed) cell$n_trait else length(idx)
      for (t in seq_len(n_coord)) {
        base <- list(cell = cell$name, seed = seeds[[i]], rep = i,
                     estimand = est, coord = t, truth = truth[[t]],
                     prevalence = fx$prevalence)
        if (fit_failed) {
          rows[[length(rows) + 1L]] <- c(base, list(
            outcome = "R-FIT", covered = NA, two_sided = FALSE,
            lower = NA_real_, upper = NA_real_, estimate = NA_real_,
            detail = if (inherits(fit, "error")) conditionMessage(fit) else "non-convergence"))
          next
        }
        if (sprintf("t%d", t) %in% sat_traits) {
          rows[[length(rows) + 1L]] <- c(base, list(
            outcome = "R-SAT", covered = NA, two_sided = FALSE,
            lower = NA_real_, upper = NA_real_, estimate = NA_real_,
            detail = "trait column saturated (all-0 or all-1)"))
          next
        }
        d <- l1_call_door(door, fit, which = idx[[t]])
        est_hat <- as.numeric(par[idx[[t]]])
        lo <- d$lower; hi <- d$upper
        if (identical(est, "E2")) {
          a <- l1_sign_anchor(est_hat, lo, hi, first_loading)
          est_hat <- a$estimate; lo <- a$lower; hi <- a$upper
        }
        covered <- if (identical(d$outcome, "returned")) {
          isTRUE(truth[[t]] >= lo && truth[[t]] <= hi)
        } else {
          NA
        }
        rows[[length(rows) + 1L]] <- c(base, list(
          outcome = d$outcome, covered = covered, two_sided = d$two_sided,
          lower = lo, upper = hi, estimate = est_hat, detail = d$detail))
      }
    }
    if ((proc.time()[["elapsed"]] - t_all) > BUDGET_S) {
      stop(sprintf("HARD STOP: local budget %.0f min exceeded at rep %d of cell %s",
                   BUDGET_S / 60, i, cell$name))
    }
    if (i %% 5L == 0L) {
      cat(sprintf("  .. rep %d/%d (%.1f min elapsed)\n", i, N_REP,
                  (proc.time()[["elapsed"]] - t_all) / 60))
    }
  }
}

tab <- do.call(rbind, lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
## A rehearsal never writes to the evidence path -- the canonical TSV is where
## an L1 result lives, and a mock table sitting there would be found later by
## someone who did not read this script.
if (isTRUE(door$mock)) {
  OUT_TSV <- sub("\\.tsv$", "-REHEARSAL-MOCK.tsv", OUT_TSV)
  OUT_RDS <- sub("\\.rds$", "-REHEARSAL-MOCK.rds", OUT_RDS)
}
dir.create(dirname(OUT_TSV), recursive = TRUE, showWarnings = FALSE)
utils::write.table(tab, OUT_TSV, sep = "\t", row.names = FALSE, quote = FALSE)

## ---- report ----------------------------------------------------------------
cat("\n======== REFUSAL-PRICED SUMMARY (ADEMP P1-P3) ========\n")
verdicts <- list()
for (cn in unique(tab$cell)) {
  for (est in unique(tab$estimand)) {
    sub <- tab[tab$cell == cn & tab$estimand == est, , drop = FALSE]
    if (!nrow(sub)) next
    s <- l1_summarise(sub)
    g <- l1_gate(s)
    verdicts[[paste(cn, est)]] <- list(summary = s, gate = g)
    cat(sprintf("\n-- %s / %s (N = %d coordinate-replicates) --\n", cn, est, s$n))
    cat(sprintf("  returned %d  refused %d  covered %d\n",
                s$n_returned, s$n_refused, s$n_covered))
    cat(sprintf("  cov_ret  = %.4f  Wilson [%.4f, %.4f]  MCSE %.4f\n",
                s$cov_ret, s$cov_ret_wilson[["lower"]], s$cov_ret_wilson[["upper"]], s$mcse_ret))
    cat(sprintf("  cov_eff  = %.4f  Wilson [%.4f, %.4f]  MCSE %.4f   <- priced\n",
                s$cov_eff, s$cov_eff_wilson[["lower"]], s$cov_eff_wilson[["upper"]], s$mcse_eff))
    cat(sprintf("  refusal  = %.4f   availability = %.4f\n", s$refusal, s$availability))
    if (length(s$refusal_by_code)) {
      cat("  by code  :", paste(sprintf("%s=%d", names(s$refusal_by_code),
                                        as.integer(s$refusal_by_code)), collapse = " "), "\n")
    }
    cl <- l1_cluster_bootstrap(sub)
    if (!is.na(cl$n_clusters)) {
      cat(sprintf("  cluster  = %.4f  boot [%.4f, %.4f]  deff %.2f  (n_rep=%d)\n",
                  cl$mean, cl$lower, cl$upper, cl$design_effect, cl$n_clusters))
    }
    if (isTRUE(door$mock)) {
      cat(sprintf("  L1 verdict: NOT APPLICABLE -- mock door (gate would read %s)\n",
                  g$verdict))
    } else {
      cat(sprintf("  L1 verdict: %s (%s)\n", g$verdict, g$reason))
    }
  }
}

anchor_key <- grep("^anchor E1$", names(verdicts), value = TRUE)
cat("\n======== VERDICT ========\n")
cat("n_rep =", N_REP, "| cells =", paste(CELL_NAMES, collapse = ","),
    "| estimands =", paste(ESTIMANDS, collapse = ","), "\n")
cat("door =", door$name, "|", door$how, "\n")
if (isTRUE(door$mock)) {
  cat("L1_STATUS: REHEARSAL (mock door) -- the arithmetic above exercised the\n")
  cat("  campaign loop only. No estimator was measured, so there is no L1\n")
  cat("  verdict, no PASS and no FAIL. Re-run against the real fork-B door.\n")
} else if (!N_REP_IN_PREREG) {
  cat("L1_STATUS: PLUMBING-ONLY (n_rep outside the pre-registered [50, 100]);",
      "no L1 verdict is claimed.\n")
} else if (!length(anchor_key)) {
  cat("L1_STATUS: NOT-EVALUATED -- the anchor cell / E1 was not in this run.\n")
} else {
  g <- verdicts[[anchor_key]]$gate
  cat("L1_STATUS:", g$verdict, "on anchor/E1 --", g$reason, "\n")
  if (!isTRUE(TAPE_VERIFIED)) {
    cat("  PROVISIONAL: the door did not report an objective source, so this",
        "run did not verify it profiled the unpenalized tape.\n")
  }
}
cat("Scope: local only, binary logit, d = 1. Not Totoro. T* not frozen.\n")
cat("MSPL-04 stays blocked; #1077 stays draft; no public se / vcov / confint.\n")

saveRDS(list(status = "RUN", table = tab, verdicts = verdicts, gate = L1_GATE,
             door = door[setdiff(names(door), "fn")], n_rep = N_REP,
             cells = CELL_NAMES, estimands = ESTIMANDS,
             n_rep_in_prereg = N_REP_IN_PREREG,
             calibration = calib, when = Sys.time()), OUT_RDS)
cat("\nwrote", OUT_TSV, "\nwrote", OUT_RDS, "\nDONE\n")
