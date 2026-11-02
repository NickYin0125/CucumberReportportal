# Design contracts and historical evidence

This directory preserves design decisions and **dated verification records**.
They describe the named candidate, version, toolchain, service, and date; they
are not the third-party installation path or a promise that every current
checkout/deployment was tested. Begin with the
[getting-started guide](../getting-started.md) for current consumer instructions.

Local paths under `tmp/`, `/private/tmp`, and other recorded test directories are
historical evidence locations, not downloadable public artifacts. Missing local
evidence is explicitly described rather than presented as a working repository
link. Operator role names and acceptance flags in older records refer to those
past workflows, not a requirement on an SDK consumer.

## Implementation contracts

| Capability | Contract |
| --- | --- |
| Original reporting-experience scope | [Plan](reporting-experience-v1-2.md) |
| Failure capture / diagnostics | [M2](reporting-experience-m2-implementation.md) |
| Gherkin metadata | [M3A](reporting-experience-m3a-implementation.md) |
| Stable Scenario identity | [M3B](reporting-experience-m3b-implementation.md) |
| Scenario business attributes | [M3C attributes](reporting-experience-m3c-attributes-implementation.md) |
| Source / CI / TMS links | [M3C links](reporting-experience-m3c-links-implementation.md) |
| Delivery architecture | [M4](reporting-experience-m4-implementation.md) |
| Bounded queues | [M4-A](reporting-experience-m4a-implementation.md) |
| Receipts / native hook completion | [M4-B](reporting-experience-m4b-implementation.md) |
| Durable spool | [M4-C](reporting-experience-m4c-implementation.md) |
| Controlled transaction replay | [M4-C replay](reporting-experience-m4c-replay-implementation.md) |

## Recorded verification

| Record | Scope |
| --- | --- |
| [M1](reporting-experience-m1-verification.md) | Initial diagnostics baseline |
| [M2](reporting-experience-m2-verification.md) | Local baseline and 2026-10-05 Typewords screenshot/video acceptance |
| [M3A](reporting-experience-m3a-verification.md) | Gherkin metadata candidate |
| [M3B](reporting-experience-m3b-verification.md) | Identity migration candidate |
| [M3C attributes](reporting-experience-m3c-attributes-verification.md) | Attribute mapping candidate |
| [M3C links](reporting-experience-m3c-links-verification.md) | Link validation candidate |
| [M3C live](reporting-experience-m3c-live-verification.md) | Named live metadata run |
| [M4 full regression](reporting-experience-m4-full-regression-verification.md) | Candidate regression matrix |
| [M4-B](reporting-experience-m4b-verification.md) | Receipt/native lifecycle candidate |
| [M4-C persistence](reporting-experience-m4c-persistence-verification.md) | Spool recovery candidate |
| [M4-C replay](reporting-experience-m4c-replay-verification.md) | Selected-transaction replay candidate |
| [Security](reporting-experience-security-verification-20261010.md) | 2026-10-10 diagnostic/privacy fixes |
| [External consumer](../../examples/current_sdk/verification.md) | Archived 2026-10-12 candidate consumer run, including version/environment limits |

## Source-checkout review and release records

These records live in the source repository and are not all included in the gem:

- [2026-10-12 ReportPortal 26.0.5 compatibility](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-12-reportportal-26.0.5-compatibility.md)
- [2026-10-13 Day-2 acceptance](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-13-day2-acceptance.md)
- [2026-10-13 v1.3.0 release acceptance](https://github.com/NickYin0125/CucumberReportportal/blob/main/docs/reviews/2026-10-13-v1.3.0-release-acceptance.md)
- [Production reviews directory](https://github.com/NickYin0125/CucumberReportportal/tree/main/docs/reviews)
- [Research archive](https://github.com/NickYin0125/CucumberReportportal/tree/main/docs/research)

Deployments belong to the [separate Helm operator guide](../../helm/reportportal-rich-experience/README.md).
Current SDK behavior, configuration, and interpretation of a receipt are
documented in [advanced reporting](../advanced-reporting.md).
