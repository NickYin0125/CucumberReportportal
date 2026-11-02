# Final visual acceptance evidence

Status: ACCEPT for the independent visual scope (P1.6/P1.8/P1.9/P10.8/P10.10/P10.11). See the final scoped report at `../../2026-11-02-final-release-visual-acceptance.md`. This is not approval of separate release gates.

## Frozen candidate

- SDK: `/Users/nick/Documents/crr-2.0.2` (read-only).
- Branch supplied by Master: `codex/failure-redaction-2.0.2`.
- Candidate: `8f44c10533eb4d0a8eae1adcc2ed5b63ace155c7`.
- Runtime patch: `f2976d8f563ff2aada816f821dcb539f6e8dc9da`.
- Candidate HEAD independently resolved; SDK working tree clean at setup.
- ReportPortal: `http://rp-2607.localhost:18080`, project `superadmin_personal`, UI build `5.15.6`.
- Existing Edge session authenticated; no password entered or read.
- Required viewport prepared: 1100 x 780, device pixel ratio 1.
- Setup time: 2026-11-02 14:29 UTC.

## Normative sources read in full

| SDK source | SHA-256 |
| --- | --- |
| `docs/design/presentation-ledger-acceptance.md` | `1937ad7595fe818fa1182cbd8332bbff070ce9370e5ef3bfc62d0a244b7ad464` |
| `docs/design/presentation-ledger-owner-decisions.md` | `67083c3b911ca86be1ffcba7565832c800bd7302c41519301d94cb46b840fa56` |
| `docs/design/presentation-ledger-proposal.md` | `91fcd61b5e11ced7a705956ce3eb0846cd3b1e71c8f227c7fd5f78cc26f23dd0` |

Decision 27 overrides older rich ERROR examples: ERROR and FATAL stay byte-identical to plain, without rich HTML or backtrace folds. Non-error Rich accents remain subject to the criteria. R02 remains unresolved: preserve the existing API, After ownership and hook status, and document the passed-log filter interaction. No waiver of P10.8 DOM nesting is inferred.

## Planned independent checks

| Criterion | Required evidence |
| --- | --- |
| P1.6 | Fresh F14 script and bold-input exception titles; rendered literal text; scoped DOM proving no injected script/b element; screenshots and exact IDs. |
| P10.8 | Inventory of every relevant emitted details fence from fresh raw messages; blank-line checks; opened-fold DOM including exact parent chain; long HTTP bodies/headers, F18 340-line text, 25-line JSON and 48 KiB text, long DocString. |
| P10.10 | Fresh media/captions and preview modal; narrow and numeric tables; assertion/HTTP/evidence views; readable summaries and expanded content. ERROR/FATAL are evaluated under Decision 27, not the superseded rich-error example. |
| P10.11 | Computed foreground/background for PASS, FAIL, WARN and INFO decorative non-error pills; contrast calculation and screenshot. A missing tone is not silently marked passed. |

Each evidence capture will retain candidate SHA, runtime source and raw-message hashes, exact Launch/item/log IDs, URL, viewport, DOM and computed styles, and original screenshot bytes. Browser screenshots are JPEG by tool contract, so use `.jpg` rather than relabeling bytes as PNG.

Preparation ran no final fixture test. After Master's handoff, the reviewer independently inspected fresh candidate artifacts and rendered UI. `visual-check-results.json` contains 19 exact opened-fence checks, four computed contrast results, literal-title checks, and 31 byte-identical ERROR/FATAL pairs. `capture-index.json` and `asset-inventory.json` bind sources and outputs; `OWNED_FILES.txt` is the exact file list for Master's serialized staging.

No prior reviewer report or verdict was consulted. No old Launch was changed, and no alternate ReportPortal or Docker stack was used. No performance work, merge, tag, publication, push, or whole-worktree staging occurred. All owned files remain uncommitted. Browser workload is complete and the viewport override has been reset.
