source("dev/isdm-requalification/response-information/contract.R", local = TRUE)
plan <- isdm_respinfo_plan()
pilot <- isdm_respinfo_pilot_plan(plan)
isdm_respinfo_validate_plan(plan)
if (nrow(plan) != 800L || nrow(pilot) != 16L ||
    length(unique(plan$dataset_id)) != 400L ||
    !all(pilot$seed_index == 1L)) {
  stop("response information static contract counts are invalid")
}
cat("response information contract verification passed\n")
