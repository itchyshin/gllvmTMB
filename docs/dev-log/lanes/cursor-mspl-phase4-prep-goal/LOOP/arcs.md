# Arcs — cursor-mspl-phase4-prep-goal

| ID | Status | Arc | Notes |
|---|---|---|---|
| A0 | **DONE** | LOOP kit on `cursor/mspl-phase4-prep-goal` | `77b37a7a`; pointer only on closed point-continue GOAL |
| A1 | **DONE** | Verify #971 closeout | MERGED `cb126576`; 29/29 PASS (168 expects); TSV 64/64; `src/`/`R/mspl.R` empty; Ubuntu CI pending at verify |
| A2 | **DONE** | Verify Poisson #972 | 102/102 PASS; planned/phase4_prep; no defect |
| A3 | **DONE** | Verify Tweedie #973 | 62/62 (not 51); wording fix `90a156cf` |
| A4 | **DONE** | Verify NB2 #974 | 72/72; stays excluded |
| A5 | **DONE** | Verify beta #975 | 65/65; wording `daa76352` |
| A6 | **DONE** | Verify NB1 #976 | 68/68; no nbinom1 row |
| A7 | **DONE** | Rose fence sweep | no NEWS covered; no planned→admitted; prepare `{0,1}` |
| A8 | **DONE** | After-task + Melissa + checkpoint | STOP at merge (human) |

## HARD STOP flags

- Merge #972–#976 from this lane (human only)
- Admit any family / NEWS covered / prepare widen
- SE / Codex interval lane / Totoro>30min
- Repo-root `LOOP/` / Dropbox / `git add -A`
- Force-push `main` / rebase unless CLEAN and asked
