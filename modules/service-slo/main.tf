locals {
  scope = "service:${var.service},env:${var.env}"
  tags  = ["service:${var.service}", "env:${var.env}", "team:${var.team}", "managed-by:terraform"]

  # Multi-window burn rates. A burn rate of 1 uses the whole 30-day error
  # budget in exactly 30 days.
  #   fast: 14.4x for 1h  = 2% of the budget gone in an hour  -> page
  #   slow:  6x  for 6h   = 5% of the budget gone in six hours -> ticket
  # The short window makes the alert clear quickly once the burn stops.
  burn_alerts = {
    fast = { rate = 14.4, long = "1h", short = "5m", handle = var.page_handle, priority = 1 }
    slow = { rate = 6, long = "6h", short = "30m", handle = var.ticket_handle, priority = 3 }
  }
}

resource "datadog_service_level_objective" "availability" {
  name        = "${var.service} availability (${var.env})"
  type        = "metric"
  description = "Share of requests to ${var.service} that complete without an error."

  query {
    numerator   = "sum:trace.${var.operation}.hits{${local.scope}}.as_count() - sum:trace.${var.operation}.errors{${local.scope}}.as_count()"
    denominator = "sum:trace.${var.operation}.hits{${local.scope}}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = var.target
    warning   = min(var.target + (100 - var.target) / 2, 99.99)
  }

  tags = local.tags
}

resource "datadog_monitor" "burn_rate" {
  for_each = { for name, alert in local.burn_alerts : name => alert if alert.handle != null }

  name = "[${var.env}] ${var.service}: error budget burning (${each.key})"
  type = "slo alert"

  query = join("", [
    "burn_rate(\"${datadog_service_level_objective.availability.id}\")",
    ".over(\"30d\").long_window(\"${each.value.long}\").short_window(\"${each.value.short}\")",
    " > ${each.value.rate}",
  ])

  message = <<-EOT
    {{#is_alert}}${var.service} in ${var.env} is burning its ${var.target}% availability error budget at more than ${each.value.rate}x the sustainable rate over the last ${each.value.long}.{{/is_alert}}
    {{#is_recovery}}Error budget burn for ${var.service} in ${var.env} is back to a sustainable rate.{{/is_recovery}}

    ${each.value.handle}
  EOT

  monitor_thresholds {
    critical = each.value.rate
  }

  priority = each.value.priority
  tags     = concat(local.tags, ["burn:${each.key}"])
}
