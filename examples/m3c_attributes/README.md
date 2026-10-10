# Scenario Business Attributes

Scenario attributes are disabled by default. Opt in and configure an allowlist
and defaults with environment variables:

```bash
export RP_SCENARIO_ATTRIBUTES_ENABLED=true
export RP_SCENARIO_ATTRIBUTE_KEYS=component,team,owner,layer,priority,browser,tms
export RP_SCENARIO_ATTRIBUTES='{"component":"payments","team":"checkout"}'
```

Add business tags at the Feature, Rule, Scenario, or Examples scope using
`@key:value`, for example `@component:payments @team:checkout`. More-specific
scopes override inherited values. Conflicting values for one key in one scope
are ignored for that scope. The allowlist excludes operational and secret keys.
The `tms` attribute comes only from the effective explicit test-case ID:
`RP_TEST_CASE_ID` wins, otherwise the formatter's existing scenario ID tag
selection applies. Existing `@tms:` identity tags still work; the attribute
mapper does not independently reselect an ID from inherited tags or configured
`tms` defaults. Other business attributes do not change scenario identity.

For example, add these tags above an existing Scenario:

```gherkin
@component:payments @team:checkout @layer:api @priority:P1 @tms:PAY-42
Scenario: Reject insufficient balance
```

After configuring the usual ReportPortal endpoint, project, and API key, run
your existing Cucumber command or explicitly enable both formatters:

```bash
bundle exec cucumber --format pretty --format ReportPortal::Cucumber::Formatter --out reportportal.out
```

The ReportPortal formatter has a separate output file so it does not compete
with `pretty` for STDOUT. These instructions configure reporting; they are not
evidence of physical ReportPortal UI acceptance.

Run the local request-capture acceptance with the repository's locked Cucumber
and WebMock; it makes no real ReportPortal request:

```bash
bundle exec rspec spec/reportportal_cucumber/cucumber/m3c_attributes_integration_spec.rb
```
