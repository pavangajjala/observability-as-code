variable "service" {
  description = "Service name as it appears in APM (the `service` tag)."
  type        = string
}

variable "env" {
  description = "Environment tag the monitors are scoped to."
  type        = string
}

variable "team" {
  description = "Owning team; used for tags and shown in notifications."
  type        = string
}

variable "tier" {
  description = "Service tier: 1 pages on-call, 2 notifies the team channel, 3 notifies without re-alerting."
  type        = number

  validation {
    condition     = contains([1, 2, 3], var.tier)
    error_message = "tier must be 1, 2 or 3."
  }
}

variable "notify" {
  description = "Notification handles."
  type = object({
    page    = optional(string) # for example @pagerduty-payments
    channel = string           # for example @slack-payments-alerts
  })

  validation {
    condition     = var.tier != 1 || var.notify.page != null
    error_message = "Tier 1 services must set notify.page so alerts reach on-call."
  }
}

variable "error_rate" {
  description = "Error rate thresholds in percent of requests."
  type = object({
    warning  = optional(number, 2)
    critical = optional(number, 5)
  })
  default = {}
}

variable "latency_p95_seconds" {
  description = "p95 latency thresholds in seconds."
  type = object({
    warning  = optional(number, 0.5)
    critical = optional(number, 1)
  })
  default = {}
}

variable "runbook_url" {
  description = "Link included in every notification."
  type        = string
  default     = null
}

variable "operation" {
  description = "APM operation name the trace metrics are based on."
  type        = string
  default     = "http.request"
}
