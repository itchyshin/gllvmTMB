# VA/EVA executable comparator receipt

Private evidence only. The VA scalar integration is an independent fixed-coordinate oracle; EVA is sealed R-versus-C++ parity only. gllvmTMB Laplace and gllvm VA/EVA are comparators only.

| Track | Call | Status | Runtime (s) |
| --- | --- | --- | ---: |
| complete_multitrial_binomial_logit | internal_va_r3 | ok | 17.849 |
| complete_multitrial_binomial_logit | gllvmTMB_laplace | ok | 0.520 |
| complete_multitrial_binomial_logit | gllvm_va | ok | 0.029 |
| sealed_bernoulli_logit | internal_eva_gate1 | evaluated_fixed_gate1_fixture | 15.685 |
| sealed_bernoulli_logit | gllvmTMB_laplace | boundary_or_invalid_for_comparison | 0.523 |
| sealed_bernoulli_logit | gllvm_eva | boundary_or_invalid_for_comparison | 0.029 |

VA scalar reference gap: 8.882e-15
EVA scalar reference gap: 4.441e-16

Manifest SHA-256: e46a96bc9bcfcb2e93682f84ef7ef90a3609236e71183b65b8adbd05b324128c
No cross-engine objective ranking was calculated. Call-level failures and boundary-invalid calls are retained in the RDS manifest.
