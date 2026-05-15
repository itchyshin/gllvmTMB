#!/usr/bin/env Rscript

## ---------------------------------------------------------------------------
## Provenance: lifted verbatim from the drmTMB sister package
## (`drmTMB/tools/codex-checkpoint.R`, file dated 2026-05-12) on 2026-05-15
## per the Jason persona cross-team scout (recorded in conversation log and
## the after-task report at
## `docs/dev-log/after-task/2026-05-15-codex-checkpoint-lift.md`).
##
## The script's structure (read `docs/dev-log/check-log.md` tail + recent
## `docs/dev-log/after-task/` reports + git state, write a timestamped
## Markdown checkpoint) is package-agnostic; gllvmTMB has the same
## directory layout drmTMB uses, so the lift is direct -- no path
## adaptation needed.
##
## Usage on long or interruptible agent (Codex or Claude Code) sessions:
##
##   Rscript tools/codex-checkpoint.R \
##     --goal "land Phase 1b item 3 (check_auto_residual())" \
##     --next "open the PR; await maintainer nod"
##
## Output goes under `docs/dev-log/recovery-checkpoints/`; see the README
## there for the protocol.
## ---------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

usage <- function(status = 0L) {
  cat(
    paste(
      "Usage: Rscript tools/codex-checkpoint.R [options]",
      "",
      "Create a compact Markdown checkpoint for recovering from interrupted",
      "Codex runs. By default the checkpoint is written under",
      "docs/dev-log/recovery-checkpoints/.",
      "",
      "Options:",
      "  --goal TEXT       Short goal for the checkpoint.",
      "  --next TEXT       Suggested next step after recovery.",
      "  --sections N      Number of newest check-log sections to include.",
      "                    Default: 3.",
      "  --output PATH     Write the checkpoint to PATH.",
      "  --stdout          Print the checkpoint instead of writing a file.",
      "  --help            Show this help.",
      sep = "\n"
    ),
    "\n",
    sep = ""
  )
  quit(status = status)
}

if ("--help" %in% args || "-h" %in% args) {
  usage()
}

arg_value <- function(flag, default = NULL) {
  index <- match(flag, args, nomatch = 0L)
  if (index == 0L) {
    return(default)
  }
  if (index == length(args)) {
    stop("Missing value after ", flag, call. = FALSE)
  }
  args[[index + 1L]]
}

flag_present <- function(flag) {
  flag %in% args
}

run_cmd <- function(command, args = character()) {
  out <- tryCatch(
    system2(command, args, stdout = TRUE, stderr = TRUE),
    error = function(err) {
      paste0("ERROR: ", conditionMessage(err))
    }
  )
  status <- attr(out, "status")
  if (is.null(status)) {
    status <- 0L
  }
  list(output = out, status = status)
}

as_block <- function(command, args = character(), max_lines = Inf) {
  result <- run_cmd(command, args)
  out <- result$output
  if (length(out) == 0L) {
    out <- "(no output)"
  }
  if (is.finite(max_lines) && length(out) > max_lines) {
    omitted <- length(out) - max_lines
    out <- c(out[seq_len(max_lines)], paste0("... ", omitted, " lines omitted"))
  }
  c(
    "```text",
    out,
    "```",
    if (!identical(result$status, 0L)) {
      paste0("Command exited with status ", result$status, ".")
    }
  )
}

read_file_lines <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  readLines(path, warn = FALSE)
}

latest_check_log <- function(path, sections = 3L, max_lines = 220L) {
  lines <- read_file_lines(path)
  if (length(lines) == 0L) {
    return("(check log not found)")
  }

  starts <- grep("^## [0-9]{4}-[0-9]{2}-[0-9]{2}", lines)
  if (length(starts) == 0L) {
    return(lines[seq_len(min(length(lines), max_lines))])
  }

  sections <- max(1L, sections)
  end <- if (length(starts) > sections) {
    starts[[sections + 1L]] - 1L
  } else {
    length(lines)
  }
  selected <- lines[seq_len(end)]
  if (length(selected) > max_lines) {
    selected <- c(
      selected[seq_len(max_lines)],
      paste0("... ", length(lines) - max_lines, " check-log lines omitted")
    )
  }
  selected
}

relative_path <- function(path, root) {
  normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
  root <- sub("/+$", "", normalizePath(root, winslash = "/", mustWork = FALSE))
  prefix <- paste0(root, "/")
  if (startsWith(normalized, prefix)) {
    substring(normalized, nchar(prefix) + 1L)
  } else if (identical(normalized, root)) {
    "."
  } else {
    normalized
  }
}

latest_after_tasks <- function(path, root, n = 8L) {
  if (!dir.exists(path)) {
    return("- `(after-task directory not found)`")
  }
  files <- list.files(path, pattern = "[.]md$", full.names = TRUE)
  if (length(files) == 0L) {
    return("- `(no after-task reports found)`")
  }
  info <- file.info(files)
  files <- files[order(info$mtime, decreasing = TRUE)]
  info <- file.info(files)
  files <- head(files, n)
  info <- head(info, n)
  vapply(
    seq_along(files),
    function(i) {
      lines <- read_file_lines(files[[i]])
      title <- lines[nzchar(lines)][[1L]]
      paste0(
        "- `",
        relative_path(files[[i]], root),
        "` (",
        format(info$mtime[[i]], "%Y-%m-%d %H:%M"),
        "): ",
        title
      )
    },
    character(1L)
  )
}

repo_root_cmd <- run_cmd("git", c("rev-parse", "--show-toplevel"))
repo_root <- if (
  identical(repo_root_cmd$status, 0L) && length(repo_root_cmd$output) > 0L
) {
  repo_root_cmd$output[[1L]]
} else {
  getwd()
}
setwd(repo_root)

goal <- arg_value("--goal", "Recover from an interrupted Codex run.")
next_step <- arg_value(
  "--next",
  "Inspect this checkpoint, then rerun git status and git diff before editing."
)
sections <- suppressWarnings(as.integer(arg_value("--sections", "3")))
if (is.na(sections) || sections < 1L) {
  stop("--sections must be a positive integer", call. = FALSE)
}
write_stdout <- flag_present("--stdout")
output <- arg_value("--output", NULL)
timestamp <- format(Sys.time(), "%Y-%m-%d-%H%M%S")

if (is.null(output) && !write_stdout) {
  output <- file.path(
    "docs",
    "dev-log",
    "recovery-checkpoints",
    paste0(timestamp, "-codex-checkpoint.md")
  )
}

lines <- c(
  "# Codex Recovery Checkpoint",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  paste0("Repository: `", repo_root, "`"),
  paste0("Goal: ", goal),
  paste0("Suggested next step: ", next_step),
  "",
  "## Purpose",
  "",
  "This file is a durable handoff for a long or interrupted Codex thread. The",
  "working tree is still authoritative: rerun `git status` and `git diff` before",
  "editing, testing, committing, or summarizing the package state.",
  "",
  "## Git State",
  "",
  "### Branch And Status",
  "",
  "`git status --short --branch`",
  "",
  as_block("git", c("status", "--short", "--branch"), max_lines = 120L),
  "",
  "### Changed Files",
  "",
  "`git diff --name-status`",
  "",
  as_block("git", c("diff", "--name-status"), max_lines = 160L),
  "",
  "`git ls-files --others --exclude-standard`",
  "",
  as_block(
    "git",
    c("ls-files", "--others", "--exclude-standard"),
    max_lines = 160L
  ),
  "",
  "### Diff Stat",
  "",
  "`git diff --stat`",
  "",
  as_block("git", c("diff", "--stat"), max_lines = 160L),
  "",
  "### Current Head",
  "",
  "`git log -1 --oneline`",
  "",
  as_block("git", c("log", "-1", "--oneline"), max_lines = 20L),
  "",
  "## Recent Project Evidence",
  "",
  paste0(
    "### Newest `docs/dev-log/check-log.md` Entries (",
    sections,
    " section",
    if (sections == 1L) "" else "s",
    ")"
  ),
  "",
  latest_check_log("docs/dev-log/check-log.md", sections = sections),
  "",
  "### Newest After-Task Reports",
  "",
  latest_after_tasks("docs/dev-log/after-task", repo_root),
  "",
  "## Recovery Commands",
  "",
  "Run these at the start of the next task before assuming this checkpoint is",
  "still current:",
  "",
  "```sh",
  "git status --short --branch",
  "git diff --stat",
  "git diff",
  "sed -n '1,240p' docs/dev-log/check-log.md",
  "ls -lt docs/dev-log/after-task | head",
  "```",
  "",
  "## Notes For The Next Agent",
  "",
  "- Do not treat this checkpoint as approval for broad changes.",
  "- Preserve unrelated user, Codex, or Claude Code edits.",
  "- If the diff is large, identify the smallest safe next step before editing.",
  "- If validation is stale or incomplete, report that explicitly."
)

if (write_stdout) {
  cat(paste(lines, collapse = "\n"), "\n", sep = "")
} else {
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, output, useBytes = TRUE)
  message("Wrote ", output)
}
