# Scenario Links

Scenario links are disabled unless explicitly enabled. Set them independently
from scenario business attributes:

```bash
export RP_SCENARIO_LINKS_ENABLED=true
export RP_SOURCE_URL_TEMPLATE='https://github.com/acme/app/blob/{commit}/{path}#L{line}'
export RP_SOURCE_COMMIT="$(git rev-parse HEAD)"
export RP_SOURCE_ROOT="$PWD"
export RP_CI_RUN_URL='https://ci.example.test/jobs/42'
export RP_TMS_URL_TEMPLATE='https://tms.example.test/cases/{id}'
```

The source template must contain exactly the supported placeholders
`{commit}`, `{path}`, and `{line}`. Use a full hexadecimal commit ID, not a
branch name. Paths are relative to `RP_SOURCE_ROOT`, encoded one segment at a
time, and line references use the executed Examples row for an outline where
available. CI Run is a complete explicit URL, not a template. TMS uses only the
effective explicit ID selected by the existing formatter; the stable-v1 hashed
wire ID and configured `tms` business attributes are not substituted.

Links are appended to the Scenario description in Source, CI Run, TMS order.
The original description, including Rule and Examples prose/tables, remains
unchanged. Invalid links are omitted individually. No credentials should be
placed in URLs; unsafe URLs are rejected, and their raw values are not included
in diagnostics. This is local API/request behavior documentation, not a claim of
physical ReportPortal UI acceptance.

For configuration and acceptance boundaries, see the [M3C links
implementation contract](../../docs/design/reporting-experience-m3c-links-implementation.md).
