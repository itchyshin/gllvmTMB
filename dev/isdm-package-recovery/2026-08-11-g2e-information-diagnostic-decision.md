# G2e decision record

G2e is a separate private diagnostic because changing observation support would
violate G2d's frozen "species dimension only" design. It tests the information
mechanism before any larger campaign or model expansion.

After a separately approved smoke, classify the retained result as:

| Classification | Rule | Next action |
| --- | --- | --- |
| `SUPPORT_RESPONSIVE` | At least four of six lower profile endpoint delta-NLL values increase by at least 1 versus retained G2d, and maximum GBIF-bias absolute error decreases from 0.371326. | Design a separately approved support ladder; no campaign yet. |
| `PROFILE_LIMITED` | GBIF-bias maximum error decreases, but the profile rule above fails. | Design an orthogonal within-cell PA-replication diagnostic. |
| `NONRESPONSIVE` | Every remaining outcome, including stronger lower profile tails without a reduced GBIF-bias maximum error. | Stop; review likelihood/approximation geometry before changing design. |

The classification is a one-fixture local diagnostic, not G2d recovery evidence,
a public claim, or authority to launch Totoro.
