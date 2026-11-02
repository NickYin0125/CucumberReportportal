# M3A metadata fixture

This small wrapper runs the isolated English and Simplified Chinese Gherkin fixtures. It uses the gem's existing Cucumber runtime only; no browser, video, network, or credential setup is required.

From the repository root, run:

```sh
bundle exec ruby examples/m3a/run.rb
```

To also report to ReportPortal, configure the gem as usual and give its formatter a file output distinct from the progress formatter's STDOUT. For a pretty STDOUT transcript, set `M3A_STDOUT_FORMAT=pretty`; do not add a second formatter that also writes to STDOUT:

```sh
M3A_STDOUT_FORMAT=pretty bundle exec ruby examples/m3a/run.rb \
  --format ReportPortal::Cucumber::Formatter --out tmp/m3a-reportportal.out \
  --format json --out tmp/m3a-native.json
```

The wrapper keeps progress on STDOUT and routes the optional ReportPortal formatter to the path passed to `--out`. The wrapper explicitly requires `reportportal_cucumber`, so the formatter constant is available when the gem is installed; do not configure both formatters to write to STDOUT.

The glue checks the parsed table and JSON DocString values, including outline substitution, escaped pipes/newlines/backslashes, and the final empty table cell. The ReportPortal subprocess integration checks metadata and the emitted report topology separately.
