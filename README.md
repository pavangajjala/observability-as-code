# Observability as code

[![CI](https://github.com/pavangajjala/observability-as-code/actions/workflows/ci.yml/badge.svg)](https://github.com/pavangajjala/observability-as-code/actions/workflows/ci.yml)

Datadog monitors, SLOs and dashboards generated from a service catalog with
Terraform. A team onboards a service by adding a few lines of YAML and gets
the same alerting, routing and dashboard as every other service.

```yaml
# catalog/services.yaml
checkout-api:
  team: payments
  tier: 1
  slo_target: 99.9
  notify:
    page: "@pagerduty-payments"
    channel: "@slack-payments-alerts"
  runbook_url: https://runbooks.example.com/checkout-api
  error_rate: {warning: 1, critical: 3}
```

That entry produces:

| Resource | Details |
| --- | --- |
| Error-rate monitor | per environment, thresholds from the catalog |
| p95 latency monitor | per environment |
| No-traffic monitor | production only, tier 1 only |
| Availability SLO | 30 days, production |
| Burn-rate alerts | fast burn pages, slow burn goes to the channel |
| Dashboard | golden signals, container resources, SLO and error budget |

## How alerts are routed

| Tier | Meaning | Production | Other environments |
| --- | --- | --- | --- |
| 1 | Customer-facing, revenue-critical | Pages on-call, repeats every 30 minutes | Team channel |
| 2 | Important but degradable | Team channel, repeats every 2 hours | Team channel |
| 3 | Internal or batch | Team channel, once | Team channel, once |

Routing lives in one place (`modules/service-monitors`), not in each monitor's
message, so changing the policy is one edit rather than a search across
hundreds of monitors.

## Why alert on burn rate

A threshold on error rate pages for a thirty-second blip and stays quiet
during a slow leak that uses up the month's error budget. The SLO module adds
two burn-rate alerts instead:

| Alert | Condition | Budget consumed | Action |
| --- | --- | --- | --- |
| Fast | 14.4x over 1 hour (and 5 minutes) | 2% in an hour | Page |
| Slow | 6x over 6 hours (and 30 minutes) | 5% in six hours | Ticket or channel |

The short window in each pair makes the alert clear soon after the problem
stops, instead of staying red for the whole long window.

## Layout

| Path | Contents |
| --- | --- |
| `catalog/services.yaml` | Service definitions; the file teams edit |
| `modules/service-monitors` | Error rate, latency and no-traffic monitors with tier routing |
| `modules/service-slo` | Availability SLO and burn-rate alerts |
| `modules/service-dashboard` | Standard dashboard |
| `live/` | Root configuration that expands the catalog |
| `scripts/validate_catalog.py` | Catalog checks with readable errors |

## Usage

```bash
python scripts/validate_catalog.py

export DD_API_KEY=... DD_APP_KEY=...
cd live
terraform init -backend-config=...        # your S3 backend settings
terraform plan -out tfplan
terraform apply tfplan
```

For the EU site set `datadog_api_url = "https://api.datadoghq.eu/"`.

## Checks

```bash
python -m pytest -q tests
terraform fmt -check -recursive
```

CI validates the catalog, runs the unit tests and runs `terraform validate`
on every module. Datadog itself checks monitor queries during `plan`, so the
workflow also has an optional plan job that runs when API keys are configured
for the repository.

## Status

The Terraform passes `validate` and an offline plan produces the expected
resources for the sample catalog (3 services: 11 monitors, 2 SLOs with 4
burn-rate alerts, 3 dashboards). I have not applied it to a Datadog account
from this repository, so the monitor queries have not been through Datadog's
own validation. Handles, team names and URLs in the catalog are examples.

The queries assume APM trace metrics for `http.request`; set `operation` on a
service that is instrumented differently.

## License

MIT
