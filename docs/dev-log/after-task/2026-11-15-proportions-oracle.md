# Check proportion interval calculations reproducibly

The proportion interval fixture now seeds its entire data generation and preserves the caller's random state. The test checks the Wald calculation and bootstrap percentile bookkeeping with explicit replicate accounting.

The former requirement that Wald and bootstrap bounds be within 0.1 is no longer asserted, with the maintainer's approval. Their observed difference remains an open scientific finding; these arithmetic checks do not establish interval coverage. The focused heavy test passed, and full integrated checks remain open.
