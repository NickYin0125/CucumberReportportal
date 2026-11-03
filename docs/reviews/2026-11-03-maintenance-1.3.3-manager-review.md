# Manager Review: SDK 1.3.3 Candidate

Candidate: `68e81d3697965305438be4fa27aa98aeb4baf726`.
Baseline: released 1.3.2, `19174a5ecaf1aa9fb65480f0a21d74ed65c89a8d`.
Status: static integration, final four-cell regression and fresh live/UI
evidence reviewed; independent scoped local verdict ACCEPT. Remote CI pending.

## Scope Checks

- The gemspec, Formatter, World, runtime queue/context/lifecycle, AppLog and
  CucumberLogger have no changes relative to released 1.3.2. Ruby >=3.1 and
  Cucumber >=9,<11 remain the separate maintenance contract.
- Decision 19 remains intact. Native failure messages and frames are not newly
  redacted. Only the existing automatic HTTP/evidence sanitization paths are
  strengthened. No FailureRedactor activation is accepted.
- ERROR/FATAL presentation no longer adds Ledger decoration. This does not
  strip caller content or the pre-existing video HTML route.
- Helm, release-tooling implementation, protected branches and released tags
  remain unchanged. CI changes preserve the clean-source and identity guards.
- The final commit changes only three standalone-test subprocess environments:
  clear BUNDLER_SETUP as well as the existing Bundler flags. All assertions and
  packaged SDK inputs are identical to `1a8db4f`.

## Findings Addressed

The manager reproduced four/five-layer encoded-credential leakage outside the
older three-layer corpus. The bounded fix deliberately withholds residual
over-depth encoding, including benign data; it does not decode indefinitely.

Independent QA then rejected `b470799` for repeated plaintext Bearer schemes.
The follow-up consumes the entire prefix chain before masking the value. The
original failed run remains evidence, rather than being relabeled successful.

Testing also identified a missing jq prerequisite and incomplete standalone-test
isolation under RubyGems 3.5/Bundler 2.6.6. The latter was not Cucumber 12 mixing:
BUNDLER_SETUP reactivated the checkout's root lock after BUNDLE_GEMFILE was
cleared. Test scripts/assertions were preserved; no dependency installation was
used to conceal the unintended activation.

## Remaining Boundaries

R02 is not fixed: a passed-log filter can hide evidence on a passed After Hook.
The consolidated PNG example does not also attach the image to native HTML.
Native 1.x NUL-log and compound-argument limitations remain unchanged.

The encoded-depth and repeated-Bearer defects were independently reproduced on
released 2.0.2 too. Their separate 2.x follow-up remains open; this candidate does
not change the released tag or its historical acceptance record.

Final counts, fresh Launch IDs, visual/performance evidence and the independent
verdict belong in the companion acceptance report. Only after that gate may the
feature branch be pushed and a draft PR opened for CI. No merge or publication
is authorized by this work.

## Verified Full Regression

The manager inspected `assets/qa-1.3.3-candidate-20261103T113932Z-e485/matrix.json`:
all four cells name the final full SHA above and SDK 1.3.3. Ruby 3.1.7/3.3.12 x
Cucumber 9.2.1/10.2.0 each executed 1,878 RSpec examples, 88 independent probes,
nine release-isolation checks and one offline Cucumber scenario/three steps.
All passed with zero pending examples. Discovery and executed per-file counts
match. These results do not substitute for the independent final verdict or
remote CI.

## Reviewed Live And Performance Evidence

Fresh installed-candidate Launches 4085/4086 (Cucumber 9 plain/rich) and
4087/4088 (Cucumber 10 plain/rich) each contain five scenarios, including two
deliberate failures, 16 items, 15 logs and two unique After-owned PNG entries.
The installed example self-tests pass 13 cases on each Cucumber version; these
are controlled browser doubles, not a new real Playwright business execution.

The manager inspected browser screenshots and DOM records showing complete
raw failure messages/frames, plain ERROR presentation, response-first HTTP and
literal escaped DocString/DataTable content. Client caption badges measure
5.38:1 contrast. RP's own code-block theme measures approximately 2.65:1, so
this is not a claim of whole-page WCAG compliance. No SDK CSS workaround is
introduced for the unchanged frontend theme.

The paired benchmark retains all three alternating-order repetitions. Plain
failure p95 drops from 0.224 to 0.146 ms, and rich failure from 0.371 to 0.205 ms.
Benign HTTP plain p95 rises from 1.571 to 1.815 ms (+15.5%; median +5.2%); rich
HTTP p95 rises from 1.989 to 2.120 ms (+6.6%). These are CPU-side measurements,
not upload latency or a production throughput guarantee. No favorable rerun
replaces this result. The owner explicitly accepted the measured plain HTTP
p95 increase on 2026-11-03; this is not an upload SLA or a universal workload
guarantee. No performance optimization or favorable rerun is required.

The independent candidate-only timing also verifies existing depth-2/3/4/5
JSON-path and repeated-Bearer inputs. Direct-call p95 is 0.026-0.229 ms, excluding
fixture construction and validation. Six downstream decodes reveal no synthetic
secret. These costs are not compared to unsafe historical passthrough.

## Decision

The companion final acceptance report returns scoped local ACCEPT for the same
full SHA, with limitations and the original failed attempts retained. The
manager accepts that evidence and will execute the owner-authorized feature
push, draft PR and remote four-cell CI. No merge, tag, release or deployment
is authorized. Remote CI receipts will be recorded separately after completion.
