# M3C Scenario Links Implementation Contract

Status: local implementation contract and physical ReportPortal acceptance
**PASS (2026-10-08)**; see the [live verification record](reporting-experience-m3c-live-verification.md).
This is the links slice of M3C and remains independent of the M3C
scenario-attributes opt-in.

## Configuration and Behavior

The feature defaults off. Configuration keys and environment variables are:

| Config key | Environment | Default |
| --- | --- | --- |
| `scenario_links_enabled` | `RP_SCENARIO_LINKS_ENABLED` | `false` |
| `source_url_template` | `RP_SOURCE_URL_TEMPLATE` | `nil` |
| `source_commit` | `RP_SOURCE_COMMIT` | `nil` |
| `source_root` | `RP_SOURCE_ROOT` | expanded current directory |
| `ci_run_url` | `RP_CI_RUN_URL` | `nil` |
| `tms_url_template` | `RP_TMS_URL_TEMPLATE` | `nil` |

Existing YAML/profile/environment/override precedence is retained. There is no
provider autodetection, filesystem lookup, Git invocation, or network request
in link construction. An explicit source root is expanded; the default is the
current directory at configuration load time.

The pure `Service::ScenarioLinks.build` helper returns a detached, deeply frozen
result with a description, ordered links, and safe diagnostics. It appends a
deterministic `### References` block to the existing nonblank Scenario
description only. If no configured link is valid, the original description is
returned byte-for-byte, including `nil` or an empty string. Source, CI Run, and
TMS are independently validated, so one invalid link does not suppress valid
siblings. Link changes do not change names, parameters, code references,
attributes, identity, retries, parentage, logs, or item topology.

Source templates require `{commit}`, `{path}`, and `{line}`, with no unknown
placeholders or placeholders in scheme/authority. Commit must be a 7-to-64
character hexadecimal identifier; mutable branch names are rejected and the
full immutable Git commit hash is recommended. The path is root-relative, stays
inside the configured source root, rejects traversal and invalid/control
characters, and percent-encodes individual path segments. For Scenario
Outlines, the executed Examples-row line is preferred when available; otherwise
the Scenario line is used. TMS requires `{id}` and uses only the effective
explicit test-case ID selected by the existing formatter, never the opaque
stable-v1 wire ID or a business attribute. CI Run is an explicitly configured
complete URL.

Generated links must be absolute HTTP(S) URLs with a host and safe Markdown
destination. Userinfo, unsafe credential query names, controls, malformed
escapes, whitespace, backslashes, raw Markdown/HTML delimiters, and excessive
length are rejected. Ordinary query and fragment data are preserved; inserted
path and ID data are encoded. Diagnostics contain only safe reason symbols,
never supplied IDs, paths, URLs, or exception messages. Current helper reasons
include `source_unavailable`, `ci_run_url_unsafe`, `tms_link_unavailable`, and
`link_generation_failed`; unknown formatter diagnostic values map to a fixed
generic warning. Each URL is limited to 2,048 bytes and the generated reference
block to 8,192 bytes. Unexpected optional link-generation failures preserve the
original description and must not abort reporting, including strict
ReportPortal mode.

The references use `[Label](<url>)`, fixed Source/CI Run/TMS order, and an ASCII
` | ` separator. Original M3A Scenario prose and rendered Examples tables are
not escaped, rewritten, or truncated. Generated content is bounded; no links
means no description mutation, including exact `nil`/empty preservation. When
the original description is blank, the generated References block itself is
the Scenario description; otherwise it follows the original bytes after two
newlines. Links are not emitted as a separate wire field, log, or ReportPortal
node.

## ReportPortal Description Contract

The official ReportPortal JavaScript client README documents `description` as
an optional test-item field supporting Markdown in its `startTestItem` section:
[client-javascript README, startTestItem](https://github.com/reportportal/client-javascript#starttestitem).
The section documents `description` alongside `name`, `type`, `hasStats`, and
attributes. The checked GitHub heading is `startTestItem`, whose verified
fragment is `#starttestitem`.

For the pinned UI source, the ReportPortal 5.15.3 description tooltip passes the
item description to `MarkdownViewer`:
[descriptionTooltip.jsx at 5.15.3](https://github.com/reportportal/service-ui/blob/5.15.3/app/src/pages/inside/common/infoLine/parentInfo/description/descriptionTooltip/descriptionTooltip.jsx).
That viewer applies `SimpleMDE.markdown`, sanitizes the resulting HTML with
DOMPurify, parses it, and sets rendered anchors to open in a new tab with
`noreferrer noopener`:
[markdownViewer.jsx at 5.15.3](https://github.com/reportportal/service-ui/blob/5.15.3/app/src/components/main/markdown/markdownViewer/markdownViewer.jsx).
These pinned source observations support the Markdown-description contract;
alone, they are not evidence that a live UI instance displayed or navigated
these links. The separate physical UI gate later passed on 2026-10-08, as
recorded in the [live verification record](reporting-experience-m3c-live-verification.md).

## Scope Boundary

This change does not alter Feature/Suite descriptions, action/hook descriptions,
statistics topology, identity derivation, retry grouping, attribute mapping,
status, or finalization. It does not create new request fields or logs. The
config toggle is independent: enabling attributes does not enable links, and
enabling links does not enable attributes. Full isolated-process acceptance and
its evidence are recorded in the [verification record](reporting-experience-m3c-links-verification.md).
