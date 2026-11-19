# Check-log: character family before the temporal gate (#1804)

**Goal:** Confirm `family = "gaussian"` with `temporal_latent()` fits the same model as `family = gaussian()`, and that an unknown character name on that formula is a gllvmTMB "Unsupported family" error rather than `$ operator is invalid for atomic vectors`.

**Commands:**

    Rscript -e 'testthat::test_file("tests/testthat/test-fix-1804-character-family.R")'

R is not installed on this machine (`Rscript: command not found`). The command was not run. CI on the draft PR is the check.

**Results:** Not run locally.

**Claim boundary:** No new family, link, or default. Character names that `family_to_id()` already accepted are resolved one step earlier. Unknown names keep the existing "Unsupported family" message.
