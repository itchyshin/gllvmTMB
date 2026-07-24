d98_task_plan_dir <- function() {
  candidates <- c(
    getOption("d98_design_dir"),
    file.path(getwd(), "dev", "design98-factorial-va-jj", "R"),
    getwd()
  )
  hit <- candidates[file.exists(file.path(candidates, "records.R"))]
  if (!length(hit)) {
    stop("Cannot locate Design-98 records.R", call. = FALSE)
  }
  normalizePath(hit[[1L]])
}

if (!exists("d98_create_task_input", mode = "function")) {
  source(file.path(d98_task_plan_dir(), "records.R"))
}

d98_plan_loading_free <- function(loading) {
  stopifnot(is.matrix(loading), ncol(loading) == 2L, nrow(loading) >= 2L)
  c(
    log(loading[1L, 1L]),
    loading[2L, 1L],
    log(loading[2L, 2L]),
    as.vector(t(loading[seq.int(3L, nrow(loading)), , drop = FALSE]))
  )
}

d98_plan_start <- function(label, truth) {
  traits <- length(truth$beta)
  if (nrow(truth$loading) != traits || ncol(truth$loading) != 2L) {
    d98_abort("Truth dimensions do not define a q=2 loading start")
  }
  if (identical(label, "A")) {
    return(list(
      id = "A",
      beta_rule = "empirical_logit",
      beta_offset = rep(0, traits),
      loading_free = c(log(.40), 0, log(.40), rep(0, 2L * traits - 4L))
    ))
  }
  if (identical(label, "B")) {
    beta_offset <- c(.05, -.04, .03, -.02, .01, -.05)[seq_len(traits)]
    return(list(
      id = "B",
      beta_rule = "truth_near",
      beta = truth$beta + beta_offset,
      loading_free = d98_plan_loading_free(.90 * truth$loading)
    ))
  }
  if (identical(label, "C")) {
    beta_offset <- c(.15, -.10, .05, .10, -.05, -.15)[seq_len(traits)]
    tail_pattern <- rep(
      c(.10, -.10, -.10, .10, .15, -.10, -.10, -.15),
      length.out = 2L * traits - 4L
    )
    return(list(
      id = "C",
      beta_rule = "empirical_logit",
      beta_offset = beta_offset,
      loading_free = c(log(.65), .10, log(.60), tail_pattern)
    ))
  }
  d98_abort("Unknown predeclared start: ", label)
}

d98_plan_task <- function(
  task_id,
  action,
  fixture,
  dependencies = character(),
  method = NULL,
  start = NULL,
  stage = NULL,
  dependency_policy = if (identical(action, "evaluate")) {
    "all_terminal"
  } else {
    "all_healthy"
  },
  toy = FALSE
) {
  list(
    task_id = task_id,
    action = action,
    dependencies = dependencies,
    fixture = list(
      label = fixture$label,
      n = nrow(fixture$y),
      traits = ncol(fixture$y),
      sha256 = fixture$sha256
    ),
    method = method,
    start = start,
    stage = stage,
    dependency_policy = dependency_policy,
    variational_start = list(
      mean = 0,
      chol_log_diag = log(.8),
      chol_strict_lower = 0
    ),
    wall_time_sec = if (identical(fixture$label, "high")) 3600L else 1800L,
    heartbeat_sec = 5L,
    toy_smoke = isTRUE(toy),
    scientific_action = TRUE
  )
}

d98_write_fixture_record <- function(root, fixture) {
  dir <- file.path(root, "fixtures")
  if (
    !dir.exists(dir) && !dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ) {
    d98_abort("Could not create fixture directory")
  }
  path <- file.path(dir, paste0(fixture$label, ".json"))
  d98_write_json_exclusive(
    path,
    list(
      label = fixture$label,
      n = nrow(fixture$y),
      traits = ncol(fixture$y),
      sha256 = fixture$sha256,
      y = unname(split(fixture$y, row(fixture$y))),
      created_utc = d98_now()
    )
  )
  path
}

d98_task_plan <- function(low, high, truth, toy = FALSE) {
  starts <- lapply(c("A", "B", "C"), d98_plan_start, truth = truth)
  names(starts) <- vapply(starts, `[[`, character(1), "id")
  tasks <- list()
  add <- function(task) {
    tasks[[task$task_id]] <<- task
    invisible(task)
  }

  for (fixture in list(low, high)) {
    for (start_id in names(starts)) {
      p1 <- paste("gh", fixture$label, start_id, "phase1", sep = "_")
      p2 <- paste("gh", fixture$label, start_id, "phase2", sep = "_")
      add(d98_plan_task(
        p1,
        "gh_phase1",
        fixture,
        start = starts[[start_id]],
        stage = "nlminb",
        toy = toy
      ))
      add(d98_plan_task(
        p2,
        "gh_phase2",
        fixture,
        dependencies = p1,
        start = starts[[start_id]],
        stage = "BFGS",
        toy = toy
      ))
    }
    add(d98_plan_task(
      paste("evaluate_gh", fixture$label, sep = "_"),
      "evaluate",
      fixture,
      dependencies = paste(
        "gh",
        fixture$label,
        names(starts),
        "phase2",
        sep = "_"
      ),
      method = list(kind = "GH", decision = "select_representative"),
      toy = toy
    ))
  }

  low_selection <- "evaluate_gh_low"
  fixed_phase2 <- character()
  for (method_id in c("QD", "QF", "JD", "JF")) {
    objective <- substr(method_id, 1L, 1L)
    geometry <- substr(method_id, 2L, 2L)
    p1 <- paste("fixed", tolower(method_id), "phase1", sep = "_")
    p2 <- paste("fixed", tolower(method_id), "phase2", sep = "_")
    add(d98_plan_task(
      p1,
      "fixed_local_phase1",
      low,
      dependencies = low_selection,
      method = list(id = method_id, objective = objective, geometry = geometry),
      stage = "nlminb",
      toy = toy
    ))
    add(d98_plan_task(
      p2,
      "fixed_local_phase2",
      low,
      dependencies = p1,
      method = list(id = method_id, objective = objective, geometry = geometry),
      stage = "BFGS",
      toy = toy
    ))
    fixed_phase2 <- c(fixed_phase2, p2)
  }
  add(d98_plan_task(
    "evaluate_fixed_local",
    "evaluate",
    low,
    dependencies = fixed_phase2,
    method = list(kind = "fixed_local", decision = "factorial_contrasts"),
    toy = toy
  ))

  joint_evaluations <- character()
  for (method_id in c("QD", "QF", "JD", "JF")) {
    objective <- substr(method_id, 1L, 1L)
    geometry <- substr(method_id, 2L, 2L)
    phase2_ids <- character()
    for (start_id in names(starts)) {
      p1 <- paste("va", tolower(method_id), start_id, "phase1", sep = "_")
      p2 <- paste("va", tolower(method_id), start_id, "phase2", sep = "_")
      add(d98_plan_task(
        p1,
        "va_phase1",
        low,
        start = starts[[start_id]],
        method = list(
          id = method_id,
          objective = objective,
          geometry = geometry
        ),
        stage = "nlminb",
        toy = toy
      ))
      add(d98_plan_task(
        p2,
        "va_phase2",
        low,
        dependencies = p1,
        start = starts[[start_id]],
        method = list(
          id = method_id,
          objective = objective,
          geometry = geometry
        ),
        stage = "BFGS",
        toy = toy
      ))
      phase2_ids <- c(phase2_ids, p2)
    }
    evaluation <- paste("evaluate", tolower(method_id), sep = "_")
    add(d98_plan_task(
      evaluation,
      "evaluate",
      low,
      dependencies = phase2_ids,
      method = list(id = method_id, decision = "select_representative"),
      toy = toy
    ))
    joint_evaluations <- c(joint_evaluations, evaluation)
  }
  add(d98_plan_task(
    "evaluate_all",
    "evaluate",
    low,
    dependencies = c(
      "evaluate_gh_high",
      "evaluate_fixed_local",
      joint_evaluations
    ),
    method = list(kind = "summary", decision = "dependency_valid_labels"),
    toy = toy
  ))
  lapply(tasks, function(task) {
    task$truth <- list(
      beta = as.numeric(truth$beta),
      loading = unname(split(truth$loading, row(truth$loading)))
    )
    task$start_id <- if (is.null(task$start$id)) NULL else task$start$id
    task
  })
}

d98_validate_task_plan <- function(tasks) {
  allowed_actions <- c(
    "gh_phase1",
    "gh_phase2",
    "va_phase1",
    "va_phase2",
    "fixed_local_phase1",
    "fixed_local_phase2",
    "evaluate"
  )
  if (!length(tasks) || anyDuplicated(names(tasks))) {
    d98_abort("Task plan must have unique task IDs")
  }
  if (
    !identical(
      names(tasks),
      unname(vapply(tasks, `[[`, character(1), "task_id"))
    )
  ) {
    d98_abort("Task-plan names and task_id fields disagree")
  }
  for (task in tasks) {
    if (!task$action %in% allowed_actions) {
      d98_abort("Unsupported task action: ", task$action)
    }
    if (length(setdiff(task$dependencies, names(tasks)))) {
      d98_abort(
        "Task dependency is absent from the deterministic DAG: ",
        task$task_id
      )
    }
    expected_policy <- if (identical(task$action, "evaluate")) {
      "all_terminal"
    } else {
      "all_healthy"
    }
    if (!identical(task$dependency_policy, expected_policy)) {
      d98_abort("Task has an invalid dependency policy: ", task$task_id)
    }
    if (grepl("phase2$", task$action)) {
      if (!identical(task$stage, "BFGS") || length(task$dependencies) != 1L) {
        d98_abort(
          "Phase-2 task must have one immutable phase-1 dependency: ",
          task$task_id
        )
      }
      phase1_id <- task$dependencies
      if (!grepl("phase1$", phase1_id) || !phase1_id %in% names(tasks)) {
        d98_abort("Phase-2 dependency does not name phase 1: ", task$task_id)
      }
    }
    if (grepl("phase1$", task$action) && !identical(task$stage, "nlminb")) {
      d98_abort("Phase-1 task must be the nlminb node: ", task$task_id)
    }
  }
  invisible(TRUE)
}

d98_build_task_plan <- function(root, low, high, truth, toy = FALSE) {
  d98_make_directories(root)
  d98_write_fixture_record(root, low)
  d98_write_fixture_record(root, high)
  tasks <- d98_task_plan(low, high, truth, toy = toy)
  d98_validate_task_plan(tasks)
  for (task in tasks) {
    d98_create_task_input(root, task)
  }
  list(task_ids = names(tasks), task_count = length(tasks), root = root)
}
