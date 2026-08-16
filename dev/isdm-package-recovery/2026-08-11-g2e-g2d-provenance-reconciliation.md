# G2e pre-fit reconciliation of retained G2d provenance

**G2e branch:** `codex/isdm-g2e-information-diagnostic`
**G2d source branch:** `codex/isdm-g2d-six-species`
**G2d reconciled commit:** `7c8b8cc88d51d4c4ddced80507562e87bc1745bf`

## Protected prior state

G2c remains `G2C_SMOKE_ADMISSION_HOLD`. G2d remains `G2D_SMOKE_HOLD`.
Neither root is copied, changed, rerun, pooled, or reclassified by G2e.

The G2d source worktree was clean at the reconciled commit. Its retained
instrumented replacement after-task record identifies a complete ordinary
three-visit smoke with a finite objective and gradient, but all six profile
ledgers held and maximum GBIF-bias error `0.371326` exceeded the frozen `0.30`
target. The record explicitly says that no Totoro campaign is warranted.

## G2e consequence

G2e is not G2d's next retry: G2d was frozen to change species dimension only.
The new two-fold observation support therefore receives a new fixture, runner,
protocol, decision record, seed-bound root, and result namespace. Its preflight
roots begin `g2e-`; their immutable manifests are retained under the ignored
private results directory. Only the G2e support design can be interpreted from
any future G2e root.
