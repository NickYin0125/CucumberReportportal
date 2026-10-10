# M4 delivery acceptance example

This is a deliberately opt-in live example, not a health check. It creates one
ReportPortal launch and one parent item, runs the two Cucumber scenarios below,
replays a JSON record and a PNG attachment to that original open item, finishes
the item/launch, and verifies that a second replay is refused without sending
or retargeting. It never starts, stops, or reconfigures infrastructure.

Do not run until Master has explicitly approved live D and C is accepted. Keep
`RP_API_KEY` only in the caller's environment or secret manager. The scripts
write mode-0600 receipts/logs under the private directory named by
`M4_LIVE_EVIDENCE_DIR`; they never copy credentials into evidence. Optional
MinIO video is caller-owned and is intentionally not configured here.

From the frozen candidate root, after approval:

```sh
umask 077
export M4_LIVE_D_APPROVED=1
export M4_LIVE_EVIDENCE_DIR="$HOME/.local/state/m4-delivery-acceptance"
export RP_ENDPOINT="http://localhost"
export RP_PROJECT="superadmin_personal"
export M4_SPOOL_CLI="$PWD/exe/reportportal-spool"
bundle exec ruby -Ilib examples/m4_delivery_acceptance/run.rb
bundle exec ruby -Ilib examples/m4_delivery_acceptance/verify.rb "$M4_LIVE_EVIDENCE_DIR/latest.json"
```

The command above is a template, not authorization to launch. The endpoint and
project are the previously observed local environment; re-check health and
authorization privately before an approved run. The runner accepts a privately
supplied `RP_API_KEY`, or reads the existing Kubernetes Secret and exchanges it
for a bearer held only in process memory.

The live feature includes a passing business scenario and a deliberately
failing assertion, with a DataTable, structured JSON, and a tiny PNG
attachment. The deterministic D integration specs must separately assert the
final-console incomplete-delivery warning when a 200 response is partial or
ambiguous while the business result passes (default exit 0). They must also
show that, with strict reporting disabled, a reporting failure does not mask an
already-failed business assertion; with strict reporting enabled, a reporting
failure may fail an otherwise-passing business scenario, but must not replace
an already-failed assertion. This live example alone is not proof of those
fault semantics or of browser acceptance.
