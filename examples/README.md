# Examples

- [`basic/`](basic) — a stock nginx with the module loaded and a rule that
  blocks, plus a build-time assertion that the two nginx versions still match.

Every example pins the nginx version in two places, because the module is tied
to it. That duplication is deliberate and the examples assert on it rather than
trusting it.
