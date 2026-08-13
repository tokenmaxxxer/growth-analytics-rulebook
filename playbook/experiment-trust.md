---
axis: experiment-trust
rule_count_floor: 3
---

# Experiment-trust verdict rules

1. **When** an experiment's variant traffic split deviates from the
   assigned ratio, **run a Sample Ratio Mismatch (SRM) chi-square check
   before reading any effect size**, and treat a detected SRM as a hard
   stop — a skewed split invalidates the randomization assumption every
   downstream statistic depends on.
   Source: Kohavi, Tang & Xu, *Trustworthy Online Controlled
   Experiments*, Cambridge University Press (2020) — publisher page
   https://www.cambridge.org/core/books/trustworthy-online-controlled-experiments/
   (SRM chapter, fetched 2026-08-13 via search on trustworthy A/B
   testing guidance).

2. **When** an anomalous win exceeds roughly 2x the pre-registered
   expected effect, **flag it "unconfirmed, pending independent check"
   rather than reporting it as a plain result** — Twyman's law: any
   figure that looks too good is more likely a measurement artifact than
   a real effect.
   Source: Kohavi, Tang & Xu, *Trustworthy Online Controlled
   Experiments* (2020), Twyman's-law discussion — same citation as
   above.

3. **REMOVAL** — when a guardrail metric shows no statistically
   significant delta, **do not omit it from the report just because the
   primary metric won**; drop only the practice of silence, not the
   metric itself — a guardrail that is never reported cannot ever catch
   a regression it was added to catch.
   Source: Kohavi, Tang & Xu, *Trustworthy Online Controlled
   Experiments* (2020), guardrail-metric chapter — same citation as
   above.
