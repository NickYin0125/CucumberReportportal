# Automatic URL Redaction: Decode-Budget Boundary

Date: 2026-11-03 Asia/Shanghai. New review finding during the 1.3.3 backport.

## Reproduction

Against released 2.0.2's runtime, construct a synthetic JSON object containing
`password: "SYNTHETIC_DEPTH_SENTINEL"`, percent-encode it one to five times,
and use it as the path of `https://example.test/`. Call
`Automation::EvidenceRedactor#redact_url`; repeatedly decode its returned value
only in the test oracle. This performs no network request and uses no secret.

| Encoding depth | Sentinel remains after decoding output | Whole URL omitted |
| ---: | --- | --- |
| 1 | false | false |
| 2 | false | true |
| 3 | false | true |
| 4 | true | false |
| 5 | true | false |

This is outside the earlier one-to-three-layer acceptance corpus, but inside
the promised automatic sanitizer boundary. Do not relabel older results as
coverage for these additional inputs. Historical evidence and release tags stay
unchanged.

## Disposition

The 1.3.3 candidate now withholds automatic evidence if percent escapes remain
after the three-pass inspection budget, including benign or already-masked
over-depth inputs. It does not add decoding passes. Forty-six focused boundary
examples cover the limit, automatic callers and unchanged raw-log paths.
The independent tester must
verify direct and HTTP/evidence callers, controls, and unchanged raw-log paths.
The existing Decision 19 native 1.x failure-text contract is not changed.

The same correction is a **remaining 2.x follow-up**. This task does not modify
or republish v2.0.2, and its earlier scoped acceptance is not an assertion that
arbitrarily nested encoding is safe. Final 1.3.3 evidence must name the actual
candidate commit and explicitly record whether the additional boundary passes.

## Additional Independent Finding: Repeated Bearer Scheme

Independent QA on frozen candidate `b470799` found three failing checks for
`Authorization: Bearer Bearer SYNTHETIC_BEARER_SENTINEL`. The automatic text
redactor masks the second `Bearer` as if it were the token and leaves the actual
synthetic value. Structured HTTP and evidence surfaces inherit that result.
The manager independently reproduced it on released 1.3.2 and 2.0.2 as well;
this is an existing shared gap, not a new 1.x-only regression.

Candidate acceptance is blocked until a narrow correction and independent
retest pass. The first frozen run is retained as failed evidence, not replaced
or relabeled. The 2.x follow-up must include this case alongside decode-budget
exhaustion. Native 1.x failure text and arbitrary AppLog messages remain outside
the automatic sanitization route under Decision 19.
