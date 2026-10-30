# R CI timeout follow-up

Main run `40489901964` reached the 75-minute job limit twice on shard 1.
On attempt 2, dependency setup ran for 46 minutes, including slow Ubuntu
package downloads. The job then ran `R CMD check` for eight minutes before
the limit. On PR run `40443072779`, the same shard completed its check in
23 minutes. The workflow now allows 120 minutes per job.

Local checks: the Actions boundary checker passed; Ruby parsed the workflow
and confirmed that the only parsed change is `timeout-minutes` from 75 to
120; `git diff --check` passed. The updated workflow has not run on GitHub.
