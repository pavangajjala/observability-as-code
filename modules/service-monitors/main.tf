locals {
  scope = "service:${var.service},env:${var.env}"
  tags  = ["service:${var.service}", "env:${var.env}", "team:${var.team}", "tier:${var.tier}", "managed-by:terraform"]

  # Only tier 1 in production pages someone. Everything else goes to the
  # team channel, so a noisy staging environment cannot wake anyone up.
  pages  = var.tier == 1 && var.env == "prod"
  target = local.pages ? "${var.notify.page} ${var.notify.channel}" : var.notify.channel

  runbook = var.runbook_url == null ? "" : "\nRunbook: ${var.runbook_url}"

  # Datadog priority: P1 is the most urgent.
  priority = local.pages ? 1 : (var.tier == 3 ? 4 : 3)

  # Tier 3 alerts once; the others repeat while the problem lasts.
  renotify_minutes = var.tier == 3 ? 0 : (local.pages ? 30 : 120)
}

resource "datadog_monitor" "error_rate" {
  name = "[${var.env}] ${var.service}: high error rate"
  type = "query alert"

  query = join("", [
    "sum(last_10m):( sum:trace.${var.operation}.errors{${local.scope}}.as_count() / ",
    "sum:trace.${var.operation}.hits{${local.scope}}.as_count() ) * 100 > ${var.error_rate.critical}",
  ])

  message = <<-EOT
    {{#is_alert}}Error rate for ${var.service} in ${var.env} is {{value}}%, above ${var.error_rate.critical}%.{{/is_alert}}
    {{#is_warning}}Error rate for ${var.service} in ${var.env} is {{value}}%, above ${var.error_rate.warning}%.{{/is_warning}}
    {{#is_recovery}}Error rate for ${var.service} in ${var.env} is back to normal.{{/is_recovery}}

    Check recent deploys and the service's error traces first.${local.runbook}

    ${local.target}
  EOT

  monitor_thresholds {
    warning  = var.error_rate.warning
    critical = var.error_rate.critical
  }

  # A service with no traffic has no error rate; that case is covered by the
  # no-traffic monitor rather than by flapping this one.
  notify_no_data      = false
  require_full_window = false
  renotify_interval   = local.renotify_minutes
  priority            = local.priority
  tags                = local.tags
}

resource "datadog_monitor" "latency" {
  name = "[${var.env}] ${var.service}: p95 latency is high"
  type = "query alert"

  query = "percentile(last_10m):p95:trace.${var.operation}{${local.scope}} > ${var.latency_p95_seconds.critical}"

  message = <<-EOT
    {{#is_alert}}p95 latency for ${var.service} in ${var.env} is {{value}}s, above ${var.latency_p95_seconds.critical}s.{{/is_alert}}
    {{#is_warning}}p95 latency for ${var.service} in ${var.env} is {{value}}s, above ${var.latency_p95_seconds.warning}s.{{/is_warning}}
    {{#is_recovery}}p95 latency for ${var.service} in ${var.env} has recovered.{{/is_recovery}}

    Look at slow traces and downstream dependencies.${local.runbook}

    ${local.target}
  EOT

  monitor_thresholds {
    warning  = var.latency_p95_seconds.warning
    critical = var.latency_p95_seconds.critical
  }

  notify_no_data      = false
  require_full_window = false
  renotify_interval   = local.renotify_minutes
  priority            = local.priority
  tags                = local.tags
}

# Zero requests usually means the service, its ingress or its DNS is down,
# which the error-rate monitor cannot see. Only worth it for tier 1 in prod,
# where traffic is expected around the clock.
resource "datadog_monitor" "no_traffic" {
  count = local.pages ? 1 : 0

  name = "[${var.env}] ${var.service}: no requests received"
  type = "query alert"

  query = "sum(last_15m):sum:trace.${var.operation}.hits{${local.scope}}.as_count() < 1"

  message = <<-EOT
    {{#is_alert}}${var.service} in ${var.env} has received no requests for 15 minutes.{{/is_alert}}
    {{#is_recovery}}${var.service} in ${var.env} is receiving requests again.{{/is_recovery}}

    Check the load balancer, DNS and whether pods are running.${local.runbook}

    ${local.target}
  EOT

  monitor_thresholds {
    critical = 1
  }

  notify_no_data      = true
  no_data_timeframe   = 30
  require_full_window = true
  renotify_interval   = local.renotify_minutes
  priority            = 1
  tags                = local.tags
}
